---------------------------- MODULE GsrpChannel ----------------------------
(***************************************************************************)
(* One GSRP message from client A to server Srv: onion construction,       *)
(* ingress, random walk inside and between clusters, egress. Checks        *)
(* confidentiality, delivery and the key/epoch lifecycle.                  *)
(*                                                                         *)
(* Action <-> article mapping (headings of the GSRP article: PRA = Path    *)
(* routing architecture):                                                  *)
(*   Dispatch   S_1 ~ iota_t over I, M_1 = M_0 = (H, Q)            (PRA)   *)
(*   Ingress    Decaps(SK_x, c_x^in), Dec, or drop                 (PRA)   *)
(*   Move       S_{tau+1} ~ P_C or Q_{i->j}; Phi^intra (link layer over    *)
(*              hop layer) or Enc_{k_bridge}                       (PRA)   *)
(*   Exit       Decaps(SK_y, c_y^eg), Dec, M = m, S = Srv          (PRA)   *)
(*   Rotate     per-entity epoch: a node's KEM key pair changes    (PRA)   *)
(*   Leave      a member leaves a private cluster                          *)
(*   LateCompromise   the exit node is compromised after rotating          *)
(*                                                                         *)
(* Cryptography is symbolic (Dolev-Yao): terms are records, perfect        *)
(* encryption, Know(S) is the closure of S under opening ciphertexts with  *)
(* known keys, decapsulating with known secret keys, splitting messages,   *)
(* and deriving hop/link keys from a known cluster secret s_C.             *)
(*                                                                         *)
(* Abstractions: one message; no active network attacker (the article's    *)
(* adversary is a set B of compromised relays, optionally with a passive   *)
(* observer of every overlay link); the egress -> Srv hop is outside the   *)
(* overlay and not observed; keys of public-cluster links are pairwise and *)
(* long-term; epochs 0..1; the walk is nondeterministic, with strong       *)
(* fairness standing for probability (finite chains: almost-sure          *)
(* reachability = reachability under strong fairness of every transition). *)
(*                                                                         *)
(* Reading switches (each published reading is a .cfg row):                *)
(*   PEEL, ONION, KEYS, GRACE, REKEY_ON_LEAVE                              *)
(***************************************************************************)
EXTENDS Integers, FiniteSets, Sequences, TLC

CONSTANTS
    SCENARIO,        \* "pub", "priv", "bridge", "bridge_all", "nobridge", "reducible"
    PEEL,            \* "published": receivers keep the hop layers; "amended": they remove them
    ONION,           \* "literal", "per_packet", "kem_dem" (see Layer)
    KEYS,            \* key of the onion layers in a private cluster: "node" (individual),
                     \* "cluster" (cluster key for both), "ingress" (cluster key for the
                     \* ingress layer only; resolution)
    GRACE,           \* 0 / 1: previous-epoch secret keys kept after rotation
    REKEY_ON_LEAVE,  \* private-cluster secret renewed when a member leaves
    OBSERVER,        \* "none" / "global": passive observer of every overlay link
    ALLOW_ROTATE,    \* nodes may rotate their KEM keys (once each)
    ALLOW_LEAVE,     \* a member may leave a private cluster (once)
    Bad,             \* compromised nodes
    LATE,            \* "none" / "exit": compromise the exit node after delivery and rotation
    MaxHops,         \* walk bound, used only when PEEL = "published" (layers grow)
    HISTORY          \* record net, seen, netAfter; FALSE for rows that check only delivery

ASSUME /\ PEEL \in {"published", "amended"} /\ ONION \in {"literal", "per_packet", "kem_dem"}
       /\ KEYS \in {"node", "cluster", "ingress"} /\ GRACE \in {0, 1}
       /\ OBSERVER \in {"none", "global"}
       /\ LATE \in {"none", "exit"} /\ HISTORY \in BOOLEAN

(***************************************************************************)
(* Scenarios (k = 2: |I|, |O| >= 2)                                        *)
(*   pub        C1 = {1,2,3,4} public, I = {1,2}, O = {3,4}, complete      *)
(*   priv       the same cluster, private                                  *)
(*   bridge     C1 = {1,2} public, C2 = {3,4,5} private, I = {1,2},        *)
(*              O = {4,5}, complete inside each, bridge 2 -> 3             *)
(*   bridge_all as bridge, but O = C2: the whole egress cluster is egress  *)
(*   nobridge   as bridge without the bridge                               *)
(*   reducible  as pub, but the support of P_C splits into {1,2}, {3,4}    *)
(***************************************************************************)
TwoClusters == SCENARIO \in {"bridge", "bridge_all", "nobridge"}
Node     == IF TwoClusters THEN 1..5 ELSE 1..4
Clusters == IF TwoClusters THEN ("C1" :> {1, 2}) @@ ("C2" :> {3, 4, 5}) ELSE ("C1" :> {1, 2, 3, 4})
Private  == CASE SCENARIO = "priv" -> {"C1"} [] TwoClusters -> {"C2"} [] OTHER -> {}
I == {1, 2}
O == CASE SCENARIO = "bridge_all" -> {3, 4, 5} [] TwoClusters -> {4, 5} [] OTHER -> {3, 4}

Complete(S) == {<<u, v>> \in S \X S : u # v}
Bridge  == IF SCENARIO \in {"bridge", "bridge_all"} THEN {<<2, 3>>} ELSE {}
Support == IF SCENARIO = "reducible" THEN {<<1, 2>>, <<2, 1>>, <<3, 4>>, <<4, 3>>}
           ELSE UNION {Complete(Clusters[c]) : c \in DOMAIN Clusters} \cup Bridge

ClusterOf(v) == CHOOSE c \in DOMAIN Clusters : v \in Clusters[c]

(***************************************************************************)
(* Terms                                                                   *)
(***************************************************************************)
Mn(a, b) == IF a < b THEN a ELSE b
Min(S)   == CHOOSE x \in S : \A y \in S : x <= y
Mx(a, b) == IF a < b THEN b ELSE a

SK(v, e)         == [t |-> "key", k |-> "sk", n |-> v, e |-> e]      \* node KEM secret key
CSK(c, e)        == [t |-> "key", k |-> "csk", c |-> c, e |-> e]     \* private cluster KEM secret key
SC(c, e)         == [t |-> "key", k |-> "sc", c |-> c, e |-> e]      \* cluster shared secret s_C(t)
Hop(c, e, u)     == [t |-> "key", k |-> "hop", c |-> c, e |-> e, n |-> u]   \* KS(s_C, u || hop)
Link(c, e, u, v) == [t |-> "key", k |-> "link", c |-> c, e |-> e, a |-> u, b |-> v]
PLink(u, v)      == [t |-> "key", k |-> "plink", a |-> Mn(u, v), b |-> Mx(u, v)]  \* pairwise
Br(u, v)         == [t |-> "key", k |-> "br", a |-> u, b |-> v]      \* bridge key, B_{i->j}
CK(l, n)         == [t |-> "key", k |-> "ck", l |-> l, n |-> n]      \* fresh content key
Pay              == [t |-> "m"]                                      \* the payload m

Enc(k, b) == [t |-> "enc", key |-> k, body |-> b]
Kem(s, k) == [t |-> "kem", sec |-> s, key |-> k]     \* encapsulation of k, opened with s
Msg(h, q) == [t |-> "msg", h |-> h, q |-> q]         \* (H, Q)

Parts(x, S) ==
    CASE x.t = "enc" -> IF x.key \in S THEN {x.body} ELSE {}
      [] x.t = "kem" -> IF x.sec \in S THEN {x.key} ELSE {}
      [] x.t = "msg" -> x.h \cup {x.q}
      [] x.t = "key" /\ x.k = "sc" ->
             {Hop(x.c, x.e, u) : u \in Clusters[x.c]}
               \cup {Link(x.c, x.e, p[1], p[2]) : p \in Complete(Clusters[x.c])}
      [] OTHER -> {}
RECURSIVE Know(_)
Know(S) == LET S2 == S \cup UNION {Parts(x, S) : x \in S} IN IF S2 = S THEN S ELSE Know(S2)

(***************************************************************************)
(* Onion (PRA): egress layer inside ingress layer. The article puts an     *)
(* encapsulation for every x in I and y in O into H but decrypts with k_x  *)
(* or k_y directly; independent encapsulations yield different keys.       *)
(*   literal     H encapsulates a separate key for each node; the layer is *)
(*               sealed under the key of one node chosen at build time;    *)
(*               other nodes fail to decrypt and drop                      *)
(*   per_packet  H targets one ingress and one egress per packet           *)
(*   kem_dem     one content key, encapsulated for every node of the set   *)
(***************************************************************************)
Sec(l, v) == IF (KEYS = "cluster" \/ (KEYS = "ingress" /\ l = "in")) /\ ClusterOf(v) \in Private
             THEN CSK(ClusterOf(v), 0) ELSE SK(v, 0)

Layer(l, S, star, inner) ==
    CASE ONION = "literal"    -> Msg({Kem(Sec(l, v), CK(l, v)) : v \in S}, Enc(CK(l, star), inner))
      [] ONION = "per_packet" -> Msg({Kem(Sec(l, star), CK(l, 0))}, Enc(CK(l, 0), inner))
      [] ONION = "kem_dem"    -> Msg({Kem(Sec(l, v), CK(l, 0)) : v \in S}, Enc(CK(l, 0), inner))

Onion(x, y) == Layer("in", I, x, Layer("eg", O, y, Pay))

VARIABLES
    xs, ys,      \* ingress and egress chosen at build time (literal, per_packet)
    stage,       \* "client", "ingress", "walk", "done", "dropped"
    pos,         \* node holding the message (0: client or server)
    cur,         \* the term the holder has
    hops,        \* moves so far (bounded only for PEEL = "published")
    net,         \* every term sent on an overlay link            (history)
    seen,        \* seen[v]: terms v received                     (history)
    ep,          \* ep[v]: KEM epoch of node v
    ret,         \* ret[v]: epochs whose secret key v still holds
    cep,         \* cep[c]: epoch of private cluster c's keys
    departed,    \* nodes that left their cluster
    leaver,      \* the node that left, 0 if none
    leaverKeys,  \* keys the leaver held when it left
    netAfter,    \* terms sent after the leave                    (history)
    lateKeys,    \* keys the attacker took from the exit node, {} if none
    exitNode     \* egress the message left through, 0 if none

vars == <<xs, ys, stage, pos, cur, hops, net, seen, ep, ret, cep, departed, leaver,
          leaverKeys, netAfter, lateKeys, exitNode>>

Members(c) == Clusters[c] \ departed
CRet(c)    == IF GRACE = 1 THEN {e \in {cep[c] - 1, cep[c]} : e >= 0} ELSE {cep[c]}

NodeKeys(v) ==
    {SK(v, e) : e \in ret[v]}
      \cup UNION {{CSK(c, e), SC(c, e)} : <<c, e>> \in {p \in Private \X (0..1) :
                                                        v \in Members(p[1]) /\ p[2] \in CRet(p[1])}}
      \cup {PLink(v, w) : w \in {u \in Node : ClusterOf(u) = ClusterOf(v) /\ ClusterOf(v) \notin Private
                                                /\ u # v}}
      \cup {Br(b[1], b[2]) : b \in {d \in Bridge : v \in {d[1], d[2]}}}

KeysOf(v) == Know(NodeKeys(v))

Wrap(u, v, x) ==
    LET c == ClusterOf(u) IN
    IF <<u, v>> \in Bridge THEN Enc(Br(u, v), x)
    ELSE IF c \in Private THEN Enc(Link(c, cep[c], u, v), Enc(Hop(c, cep[c], u), x))
    ELSE Enc(PLink(u, v), x)

RECURSIVE Peel(_, _)
Peel(ks, x) == IF x.t = "enc" /\ x.key \in ks THEN Peel(ks, x.body) ELSE x

CanOpen(v, x) ==
    /\ x.t = "msg" /\ x.q.t = "enc"
    /\ \E e \in x.h : e.sec \in KeysOf(v) /\ e.key = x.q.key

\* PRA's transition operator sends a message at any u in O to Srv. Under the
\* literal reading and KEM-DEM the walk therefore exits at the first egress
\* it reaches; under per-packet targeting, at the targeted egress.
MustExit(y) == y \in O /\ (ONION \in {"literal", "kem_dem"} \/ (ONION = "per_packet" /\ y = ys))
CanExit(y)  == y \in O /\ (ONION # "per_packet" \/ y = ys)

\* Under kem_dem the build-time choice of xs and ys plays no role (Leave
\* aside), so one value each keeps the state space small.
Init ==
    /\ xs \in (IF ONION = "kem_dem" THEN {1} ELSE I)
    /\ ys \in (IF ONION = "kem_dem" THEN {Min(O)} ELSE O)
    /\ stage = "client" /\ pos = 0 /\ cur = Onion(xs, ys) /\ hops = 0
    /\ net = {} /\ seen = [v \in Node |-> {}]
    /\ ep = [v \in Node |-> 0] /\ ret = [v \in Node |-> {0}]
    /\ cep = [c \in DOMAIN Clusters |-> 0]
    /\ departed = {} /\ leaver = 0 /\ leaverKeys = {} /\ netAfter = {}
    /\ lateKeys = {} /\ exitNode = 0

\* net, seen and netAfter are history variables: no action reads them, so a
\* row that checks only delivery drops them (HISTORY = FALSE), which keeps
\* the state space -- and the liveness check -- small without changing any
\* behaviour of the protocol.
Send(v, x) ==
    IF HISTORY
    THEN /\ net' = net \cup {x}
         /\ seen' = [seen EXCEPT ![v] = @ \cup {x}]
         /\ netAfter' = IF leaver # 0 THEN netAfter \cup {x} ELSE netAfter
    ELSE UNCHANGED <<net, seen, netAfter>>

Dispatch ==
    /\ stage = "client"
    /\ \E x \in (IF ONION = "per_packet" THEN {xs} ELSE I) :
           /\ Send(x, cur)
           /\ pos' = x /\ stage' = "ingress"
    /\ UNCHANGED <<xs, ys, cur, hops, ep, ret, cep, departed, leaver, leaverKeys, lateKeys, exitNode>>

Ingress ==
    /\ stage = "ingress"
    /\ IF CanOpen(pos, cur)
       THEN stage' = "walk" /\ cur' = cur.q.body
       ELSE stage' = "dropped" /\ UNCHANGED cur
    /\ UNCHANGED <<xs, ys, pos, hops, net, seen, ep, ret, cep, departed, leaver, leaverKeys,
                   netAfter, lateKeys, exitNode>>

Move(u, v) ==
    /\ stage = "walk" /\ pos = u /\ <<u, v>> \in Support /\ v \notin departed
    /\ ~MustExit(u)
    /\ PEEL = "amended" \/ hops < MaxHops
    /\ LET w == Wrap(u, v, cur) IN
       /\ Send(v, w)
       /\ cur' = IF PEEL = "amended" THEN Peel(KeysOf(v), w) ELSE w
    /\ pos' = v
    /\ hops' = IF PEEL = "published" THEN hops + 1 ELSE hops
    /\ UNCHANGED <<xs, ys, stage, ep, ret, cep, departed, leaver, leaverKeys, lateKeys, exitNode>>

Exit(y) ==
    /\ stage = "walk" /\ pos = y /\ CanExit(y)
    /\ IF CanOpen(y, cur)
       THEN /\ stage' = "done" /\ cur' = cur.q.body /\ exitNode' = y /\ pos' = 0
       ELSE /\ stage' = "dropped" /\ UNCHANGED <<cur, exitNode, pos>>
    /\ UNCHANGED <<xs, ys, hops, net, seen, ep, ret, cep, departed, leaver, leaverKeys,
                   netAfter, lateKeys>>

\* A rotation while the message is on its way (after Dispatch), or after
\* delivery (for the late compromise).
Rotate(v) ==
    /\ ALLOW_ROTATE /\ ep[v] = 0 /\ stage # "client"
    /\ ep' = [ep EXCEPT ![v] = 1]
    /\ ret' = [ret EXCEPT ![v] = IF GRACE = 1 THEN {0, 1} ELSE {1}]
    /\ UNCHANGED <<xs, ys, stage, pos, cur, hops, net, seen, cep, departed, leaver, leaverKeys,
                   netAfter, lateKeys, exitNode>>

Leave(z) ==
    /\ ALLOW_LEAVE /\ leaver = 0 /\ z \notin {xs, ys, pos}
    /\ ClusterOf(z) \in Private
    /\ leaver' = z /\ departed' = {z} /\ leaverKeys' = NodeKeys(z)
    /\ cep' = IF REKEY_ON_LEAVE THEN [cep EXCEPT ![ClusterOf(z)] = @ + 1] ELSE cep
    /\ UNCHANGED <<xs, ys, stage, pos, cur, hops, net, seen, ep, ret, netAfter, lateKeys, exitNode>>

LateCompromise ==
    /\ LATE = "exit" /\ stage = "done" /\ ep[exitNode] = 1 /\ lateKeys = {}
    /\ lateKeys' = NodeKeys(exitNode)
    /\ UNCHANGED <<xs, ys, stage, pos, cur, hops, net, seen, ep, ret, cep, departed, leaver,
                   leaverKeys, netAfter, exitNode>>

Next ==
    \/ Dispatch \/ Ingress \/ LateCompromise
    \/ \E e \in Support : Move(e[1], e[2])
    \/ \E y \in O : Exit(y)
    \/ \E v \in Node : Rotate(v) \/ Leave(v)

Fairness ==
    /\ WF_vars(Dispatch) /\ WF_vars(Ingress)
    /\ \A e \in Support : SF_vars(Move(e[1], e[2]))
    /\ \A y \in O : SF_vars(Exit(y))

Spec == Init /\ [][Next]_vars /\ Fairness

\* The same behaviours without fairness, for rows that check only safety
\* properties stated as actions (fairness adds nothing there and makes TLC
\* build the liveness graph).
SafetySpec == Init /\ [][Next]_vars

(***************************************************************************)
(* Properties                                                              *)
(***************************************************************************)
TypeOK ==
    /\ xs \in I /\ ys \in O
    /\ stage \in {"client", "ingress", "walk", "done", "dropped"}
    /\ pos \in Node \cup {0} /\ exitNode \in O \cup {0}
    /\ ep \in [Node -> 0..1] /\ cep \in [DOMAIN Clusters -> 0..1]
    /\ departed \subseteq Node /\ leaver \in Node \cup {0}

KnowNode(v) == Know(NodeKeys(v) \cup seen[v])

\* A compromised node keeps every key it ever held: secret keys of past
\* epochs, the keys it had when it left, cluster keys of every epoch it was
\* a member for. So the coalition's knowledge only grows.
EverKeys(b) ==
    NodeKeys(b) \cup {SK(b, e) : e \in 0..ep[b]}
      \cup (IF b = leaver THEN leaverKeys ELSE {})
      \cup UNION {{CSK(p[1], p[2]), SC(p[1], p[2])} :
                    p \in {q \in Private \X (0..1) : b \in Clusters[q[1]] /\ b \notin departed
                                                    /\ q[2] <= cep[q[1]]}}
KnowBad     == Know(UNION {EverKeys(b) \cup seen[b] : b \in Bad}
                    \cup (IF OBSERVER = "global" THEN net ELSE {}))

\* PRA: "no intermediary cluster or relay node can see the payload before it
\* reaches the end of the secure channel".
NoPayloadBeforeEgress == \A v \in Node \ O : Pay \notin KnowNode(v)

\* Coalition form: the payload needs a compromised egress.
PayloadNeedsEgress == Pay \in KnowBad => Bad \cap O # {}

\* Premise of Phi_N = sum X_i F_i (CMP): a compromised egress sees exactly
\* the traffic that exits through it. Checked when the message has left:
\* the coalition's knowledge only grows (EverKeys, net, seen), so an
\* exposure at any earlier state is still there at completion.
ExposureByExit == stage = "done" => (Pay \in KnowBad => exitNode \in Bad)

\* The justification of ExposureByExit, checked: the coalition's keys and
\* the terms it has received never shrink. Know is a closure, monotone in
\* its argument, so what the coalition knows never shrinks either.
BadKeys  == UNION {EverKeys(b) : b \in Bad}
BadSeen  == UNION {seen[b] : b \in Bad} \cup (IF OBSERVER = "global" THEN net ELSE {})
KnowledgeMonotone == [][BadKeys \subseteq BadKeys' /\ BadSeen \subseteq BadSeen']_vars

RECURSIVE ReachFrom(_, _, _)
ReachFrom(R, S, k) == IF k = 0 THEN S ELSE ReachFrom(R, S \cup {e[2] : e \in {f \in R : f[1] \in S}}, k - 1)
Openers == IF ONION = "kem_dem" THEN O ELSE {ys}

\* Almost-sure delivery, graph form.
EgressReachable ==
    stage = "walk" =>
        Openers \cap ReachFrom({e \in Support : e[2] \notin departed}, {pos}, Cardinality(Node)) # {}

\* Almost-sure delivery, fairness form.
Delivered == <>(stage = "done")

\* PRA: keys are "forward secure".
ForwardSecrecy == lateKeys # {} => Pay \notin Know(lateKeys \cup net)

\* Not claimed: a member that left cannot open layers sealed after it left.
PostLeave == leaver # 0 => \A x \in netAfter : x.t = "enc" => x.key \notin Know(leaverKeys)

(***************************************************************************)
(* Witnesses: each must be violated.                                       *)
(***************************************************************************)
NotDelivered       == stage # "done"
NoBridge           == ~\E x \in net : x.t = "enc" /\ x.key.k = "br"
NoBadHandles       == \A b \in Bad : seen[b] = {}
NoRotationInFlight == ~(stage \in {"ingress", "walk"} /\ \E v \in Node : ep[v] = 1)
NoLate             == lateKeys = {}
NoLeaveInFlight    == ~(leaver # 0 /\ netAfter # {})
NoRotateLeaveInFlight == ~(stage \in {"ingress", "walk"} /\ leaver # 0 /\ \E v \in Node : ep[v] = 1)
=============================================================================
