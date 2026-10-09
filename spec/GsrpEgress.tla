----------------------------- MODULE GsrpEgress -----------------------------
(***************************************************************************)
(* GSRP egress sessions (article heading "Dispersion of the outer nodes",  *)
(* DON): the TCP facade table T_C and the UDP retranslation tables U_v,    *)
(* for one flow theta leaving one egress cluster.                          *)
(*                                                                         *)
(* Action <-> article mapping:                                             *)
(*   SendSeg    a member sends a TCP segment of theta: looks T_C up,       *)
(*              selects the facade z = F_C(theta) and inserts (theta, z)   *)
(*              if absent; z allocates the address a = Choose(A_z); the   *)
(*              segment's source is rewritten to a                         *)
(*   Gossip     RSDP merges replicas of T_C and of the membership view     *)
(*   Join       a node joins the cluster (membership churn)                *)
(*   Fin        FIN/RST: entries removed                                   *)
(*   Boundary   epoch t -> t + 1                                           *)
(*   UdpSend    an egress node sends a UDP packet of theta; inserts         *)
(*              (theta, a, d, rho, tau_exp) into U_v if absent             *)
(*   Tick, Deliver   time passes; a response returns within RTT            *)
(*                                                                         *)
(* Abstractions: one flow; a segment sent with the source rewritten to the *)
(* facade's address is delivered (network ingress filtering and TCP state  *)
(* at the facade are outside the model); F_C(theta) under "hash" is the    *)
(* largest identifier in the local membership view -- any function that   *)
(* depends on the view changes under some membership change, which is all *)
(* the churn row uses; a facade crash ends its session (no claim about     *)
(* it).                                                                    *)
(*                                                                         *)
(* Reading switches: FACADE, TABLE, CARRY, REFRESH.                        *)
(***************************************************************************)
EXTENDS Integers, FiniteSets, TLC

CONSTANTS
    MODE,     \* "tcp" / "udp"
    FACADE,   \* "hash": F_C(theta) a function of the local membership view; "choose": any member
    TABLE,    \* "gossip": replicas merged by RSDP; "consensus": inserted through consensus
    CHURN,    \* node 4 may join during the session
    EPOCHS,   \* an epoch boundary may fall inside the session
    CARRY,    \* "published": T_C, S, R are per epoch (reset); "amended": carried
    REFRESH,  \* "published": tau_exp fixed when the U_v entry is created; "amended": refreshed on use
    TauExp,   \* U_v entry valid while its age <= TauExp (t <= tau_exp)
    RTT,      \* a response arrives within RTT ticks of its packet
    MaxSeg    \* segments or packets per behaviour

ASSUME /\ MODE \in {"tcp", "udp"} /\ FACADE \in {"hash", "choose"} /\ TABLE \in {"gossip", "consensus"}
       /\ CARRY \in {"published", "amended"} /\ REFRESH \in {"published", "amended"}
       /\ TauExp \in Nat /\ RTT \in Nat \ {0} /\ MaxSeg \in Nat

Node    == 1..4
Initial == {1, 2, 3}            \* node 4 joins only with CHURN
Ports   == {1, 2}               \* A_v: external ports usable by each node

Max(S) == CHOOSE x \in S : \A y \in S : y <= x
Min(S) == CHOOSE x \in S : \A y \in S : x <= y
F(M)   == Max(M)                \* F_C(theta) under "hash"

VARIABLES
    live,     \* members of the cluster
    mem,      \* mem[v]: v's membership view
    view,     \* view[v]: facade of theta in v's replica of T_C, 0 = none
    tomb,     \* tomb[v]: v knows the session ended
    tg,       \* facade of theta in the consensus table, 0 = none
    S,        \* S[z]: port a* facade z allocated for theta, 0 = none
    sent,     \* source addresses <<z, port>> of theta's segments this session
    senders,  \* members that sent segments
    inserts,  \* local inserts into T_C replicas
    sess,     \* "open" / "closed"
    epoch,    \* 0..1
    uport,    \* uport[v]: port of v's U_v entry for theta, 0 = none
    uage,     \* uage[v]: its age
    resp,     \* responses in flight: [v, p, age]
    usrc,     \* UDP source addresses the server saw
    answered, \* responses that found their entry
    lost,     \* a response found no entry
    segs      \* segments or packets sent

vars == <<live, mem, view, tomb, tg, S, sent, senders, inserts, sess, epoch,
          uport, uage, resp, usrc, answered, lost, segs>>
udpVars == <<uport, uage, resp, usrc, answered, lost>>
tcpVars == <<live, mem, view, tomb, tg, S, sent, senders, inserts, sess, epoch>>

Init ==
    /\ live = Initial
    /\ mem = [v \in Node |-> IF v \in Initial THEN Initial ELSE {}]
    /\ view = [v \in Node |-> 0] /\ tomb = [v \in Node |-> FALSE]
    /\ tg = 0 /\ S = [v \in Node |-> 0]
    /\ sent = {} /\ senders = {} /\ inserts = 0
    /\ sess = "open" /\ epoch = 0
    /\ uport = [v \in Node |-> 0] /\ uage = [v \in Node |-> 0]
    /\ resp = {} /\ usrc = {} /\ answered = 0 /\ lost = FALSE
    /\ segs = 0

(***************************************************************************)
(* TCP                                                                     *)
(***************************************************************************)
Lookup(v) == IF TABLE = "consensus" THEN tg ELSE view[v]
Select(v) == IF FACADE = "hash" THEN {F(mem[v])} ELSE live

SendSeg(v) ==
    /\ MODE = "tcp" /\ sess = "open" /\ v \in live /\ segs < MaxSeg
    /\ \E z \in (IF Lookup(v) # 0 THEN {Lookup(v)} ELSE Select(v)) :
           /\ IF TABLE = "consensus"
              THEN tg' = z /\ UNCHANGED <<view, inserts>>
              ELSE /\ view' = [view EXCEPT ![v] = z]
                   /\ inserts' = IF view[v] = 0 THEN inserts + 1 ELSE inserts
                   /\ UNCHANGED tg
           /\ \E p \in (IF S[z] # 0 THEN {S[z]} ELSE Ports) :
                  /\ S' = [S EXCEPT ![z] = p]
                  /\ sent' = sent \cup {<<z, p>>}
    /\ senders' = senders \cup {v}
    /\ segs' = segs + 1
    /\ UNCHANGED <<live, mem, tomb, sess, epoch>> /\ UNCHANGED udpVars

Merge(a, b) == IF a = 0 THEN b ELSE IF b = 0 THEN a ELSE Min({a, b})

Gossip(u, v) ==
    /\ u # v /\ u \in live /\ v \in live
    /\ LET t == tomb[v] \/ tomb[u] IN
       /\ tomb' = [tomb EXCEPT ![v] = t]
       /\ view' = [view EXCEPT ![v] = IF t THEN 0 ELSE Merge(view[v], view[u])]
    /\ mem' = [mem EXCEPT ![v] = @ \cup mem[u]]
    /\ <<view', tomb', mem'>> # <<view, tomb, mem>>
    /\ UNCHANGED <<live, tg, S, sent, senders, inserts, sess, epoch, segs>> /\ UNCHANGED udpVars

Join ==
    /\ MODE = "tcp" /\ CHURN /\ 4 \notin live
    /\ live' = live \cup {4}
    /\ mem' = [mem EXCEPT ![4] = live \cup {4}]
    /\ UNCHANGED <<view, tomb, tg, S, sent, senders, inserts, sess, epoch, segs>> /\ UNCHANGED udpVars

Fin ==
    /\ MODE = "tcp" /\ sess = "open" /\ segs > 0
    /\ sess' = "closed"
    /\ tomb' = [v \in Node |-> tomb[v] \/ S[v] # 0]     \* the facade sees FIN/RST
    /\ S' = [v \in Node |-> 0]
    /\ tg' = 0
    /\ view' = [v \in Node |-> IF S[v] # 0 THEN 0 ELSE view[v]]
    /\ UNCHANGED <<live, mem, sent, senders, inserts, epoch, segs>> /\ UNCHANGED udpVars

Boundary ==
    /\ MODE = "tcp" /\ EPOCHS /\ epoch = 0 /\ sess = "open"
    /\ epoch' = 1
    /\ IF CARRY = "published"
       THEN /\ view' = [v \in Node |-> 0] /\ S' = [v \in Node |-> 0] /\ tg' = 0
       ELSE UNCHANGED <<view, S, tg>>
    /\ UNCHANGED <<live, mem, tomb, sent, senders, inserts, sess, segs>> /\ UNCHANGED udpVars

(***************************************************************************)
(* UDP                                                                     *)
(***************************************************************************)
UdpSend(v) ==
    /\ MODE = "udp" /\ v \in Initial /\ segs < MaxSeg
    /\ \E p \in (IF uport[v] # 0 THEN {uport[v]} ELSE Ports) :
           /\ uport' = [uport EXCEPT ![v] = p]
           /\ uage' = IF uport[v] = 0 \/ REFRESH = "amended" THEN [uage EXCEPT ![v] = 0] ELSE uage
           /\ usrc' = usrc \cup {<<v, p>>}
           /\ resp' = resp \cup {[v |-> v, p |-> p, age |-> 0]}
    /\ segs' = segs + 1
    /\ UNCHANGED <<answered, lost>> /\ UNCHANGED tcpVars

\* One tick; a response cannot be older than RTT, so time waits for it.
Tick ==
    /\ MODE = "udp"
    /\ \A r \in resp : r.age < RTT
    /\ uage' = [v \in Node |-> IF uport[v] # 0 /\ uage[v] <= TauExp THEN uage[v] + 1 ELSE uage[v]]
    /\ uport' = [v \in Node |-> IF uport[v] # 0 /\ uage[v] + 1 > TauExp THEN 0 ELSE uport[v]]
    /\ resp' = {[r EXCEPT !.age = @ + 1] : r \in resp}
    /\ (resp # {} \/ \E v \in Node : uport[v] # 0)       \* no idle ticks
    /\ UNCHANGED <<usrc, answered, lost, segs>> /\ UNCHANGED tcpVars

Deliver(r) ==
    /\ MODE = "udp" /\ r \in resp /\ r.age >= 1
    /\ resp' = resp \ {r}
    /\ IF uport[r.v] = r.p THEN answered' = answered + 1 /\ UNCHANGED lost
                           ELSE lost' = TRUE /\ UNCHANGED answered
    /\ UNCHANGED <<uport, uage, usrc, segs>> /\ UNCHANGED tcpVars

Next ==
    \/ \E v \in Node : SendSeg(v) \/ UdpSend(v)
    \/ \E u, v \in Node : MODE = "tcp" /\ Gossip(u, v)
    \/ Join \/ Fin \/ Boundary \/ Tick
    \/ \E r \in resp : Deliver(r)

Fairness == \A u, v \in Node : WF_vars(MODE = "tcp" /\ Gossip(u, v))

Spec == Init /\ [][Next]_vars /\ Fairness

(***************************************************************************)
(* Properties                                                              *)
(***************************************************************************)
TypeOK ==
    /\ live \subseteq Node /\ view \in [Node -> Node \cup {0}] /\ tg \in Node \cup {0}
    /\ S \in [Node -> Ports \cup {0}] /\ sess \in {"open", "closed"} /\ epoch \in 0..1
    /\ uport \in [Node -> Ports \cup {0}] /\ lost \in BOOLEAN /\ segs \in 0..MaxSeg

\* DON: "a cluster must maintain a single facade node for the duration of a
\* TCP session" -- every segment leaves with one source (z*, a*).
OneFacade == sess = "open" => Cardinality(sent) <= 1

\* A response to any source the session used reaches a facade that holds
\* the session (S_z*[theta] = a*, R_z*[theta] = rho).
ReturnPath == sess = "open" => \A a \in sent : S[a[1]] = a[2]

\* After FIN/RST every replica eventually drops theta.
Cleanup == (sess = "closed") ~> (\A v \in live : view[v] = 0)

\* A UDP response arriving within RTT finds its entry and return path.
UdpReturn == ~lost

\* DON: dispersion "should appear seamless for the initiator and recipient".
UdpSourceStable == Cardinality(usrc) <= 1

(***************************************************************************)
(* Witnesses: each must be violated.                                       *)
(***************************************************************************)
NoMultiSender       == Cardinality(senders) <= 1
NoConcurrentOpen    == inserts <= 1
NoUdpAnswer         == answered = 0
NoJoin              == 4 \notin live
NoBoundaryInSession == ~(epoch = 1 /\ sess = "open" /\ segs > 0)
=============================================================================
