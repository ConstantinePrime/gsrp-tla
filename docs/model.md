# GSRP model: scope, abstractions and properties

Two TLA⁺ modules check the qualitative claims of M. Kotov, S. Toliupa,
*Group State Routing Protocol (Mycelia): a new model for distributed
network coordination*, Science-based technologies 4(68), 2025 ([GSRP]).
The article has no numbered sections; references use its headings: *Path
routing architecture* (PRA), *Dispersion of the outer nodes* (DON),
*Comparison with existing protocols* (CMP).

## Verdict classes

Every row of [`results.md`](results.md) supports one verdict:

- **Holds** — checked within the stated bounds;
- **Defect** — fails under every reasonable reading of the text;
- **Gap** — the literal reading fails, a completion consistent with the
  text holds; the completion is the proposed amendment;
- **Characterisation** — not claimed by the article; the model measures it.

Where the text admits several readings, each is a constant and its
literal reading is a row of its own. Witness rows negate the scenario a
passing row relies on and must be violated, so no passing row is vacuous.

## What TLC can and cannot check

TLC has no probabilities. Out of scope: the correlation probabilities of
CMP (f², Nym's bound, E[Φ_N] = β, Pr(Φ_N = 1) = β^{n_O}, the
Kullback–Leibler tail bound), convergence of the walk to π_C, and latency.
Two qualitative statements they rest on are in scope:

- **Almost-sure delivery.** For a finite Markov chain, reaching a target
  set with probability 1 is equivalent to the target being reachable from
  every state reachable from the start, and to reaching it under strong
  fairness of every transition (Baier & Katoen, *Principles of Model
  Checking*, 2008, ch. 10). `EgressReachable` checks the first form,
  `Delivered` (strong fairness on every walk transition) the second.
- **The premise of Φ_N = Σ X_i F_i.** The formula assumes that a
  compromised egress i observes exactly the share F_i of the traffic that
  exits through it. `ExposureByExit` checks when that holds.

## `spec/GsrpChannel.tla` — one message, client to server

### Protocol steps (PRA)

| Action | Article |
|---|---|
| `Dispatch` | S₁ ∼ ι_t over I, M₁ = M₀ = (H, Q) |
| `Ingress` | Decaps(SK_x, c_x^in), Dec_k(AD, M), or drop |
| `Move` | S_{τ+1} ∼ P_C (Φ^intra: link layer over hop layer) or Q_{i→j} (Enc_{k_bridge}) |
| `Exit` | Decaps(SK_y, c_y^eg), Dec_k(AD, M); M = m, S = Srv |
| `Rotate` | per-entity epoch: a node's KEM key pair changes |
| `Leave` | a member leaves a private cluster |
| `LateCompromise` | the exit node is compromised after rotating |

### Symbolic cryptography

Terms are records; encryption is perfect (Dolev–Yao). `Enc(k, b)` is AEAD,
`Kem(s, k)` an encapsulation of k opened with secret key s, `Msg(H, Q)` the
pair (H, Q). Keys: node KEM keys SK(v, e); for a private cluster c its
KEM key CSK(c, e) and shared secret s_C = SC(c, e), from which every member
derives the hop keys KS(s_C, u‖hop) and link keys KS(s_C, u‖v‖link);
pairwise long-term link keys in public clusters; bridge keys; fresh content
keys. `Know(S)` is the closure of S under opening ciphertexts with known
keys, opening encapsulations with known secret keys, splitting `Msg`, and
deriving hop and link keys from a known s_C.

### Adversary

`Bad` is a set of compromised nodes with their keys and everything they
received; `OBSERVER = "global"` adds a passive observer of every overlay
link. `LATE = "exit"` compromises the exit node after it rotated, giving
the attacker the keys it then holds but not its past plaintexts (honest
nodes erase). There is no active network attacker: the article's adversary
is a set of compromised relays, B ⊆ V. The egress → Srv hop is outside the
overlay and not observed.

### Scenarios (k = 2)

| Scenario | Clusters | I, O | Walk support |
|---|---|---|---|
| `pub` | C1 = {1,2,3,4} public | I = {1,2}, O = {3,4} | complete on C1 |
| `priv` | C1 = {1,2,3,4} private | as `pub` | as `pub` |
| `bridge` | C1 = {1,2} public, C2 = {3,4,5} private | I = {1,2}, O = {4,5} | complete inside each; bridge 2 → 3 (3 is not an egress) |
| `nobridge` | as `bridge` | as `bridge` | no bridge |
| `reducible` | as `pub` | as `pub` | {1,2} and {3,4} not connected |

### Readings and switches (published reading first)

| Constant | Values | Text it decides |
|---|---|---|
| `PEEL` | `"published"` / `"amended"` | PRA never says who removes the Φ^intra hop/link layers or the bridge layer; amended: the receiver does |
| `ONION` | `"literal"` / `"per_packet"` / `"kem_dem"` | H holds an encapsulation for every x ∈ I and y ∈ O, but the layer is decrypted with k_x or k_y directly. `literal`: sealed under one node's key, others drop. `per_packet`: one ingress and one egress per packet, the walk continues to that egress. `kem_dem`: one content key encapsulated for every node of the set |
| `KEYS` | `"cluster"` / `"node"` / `"ingress"` | PRA: "with private structures a client can use the cluster public key instead of individual keys". `node`: individual keys for both layers; `ingress`: the cluster key for the ingress layer only (resolution G3) |
| `GRACE` | 0 / 1 | previous-epoch secret keys kept after a rotation |
| `REKEY_ON_LEAVE` | `FALSE` / `TRUE` | s_C renewed when a member leaves |
| `OBSERVER` | `"none"` / `"global"` | adversary strength |
| `HISTORY` | `TRUE` / `FALSE` | record `net`, `seen`, `netAfter`; no action reads them, so delivery-only rows drop them |
| `ALLOW_ROTATE`, `ALLOW_LEAVE`, `LATE`, `Bad` | | lifecycle events and adversary |

Full design (BASE): amended layer removal, per-packet onion, node keys,
`GRACE = 1`, no observer, no rotation, no leave, `Bad = {}`, `HISTORY`.
The amended readings are the base because under the literal ones nothing
is delivered, which would make every other row vacuous.

The resolved protocol (`am_*` rows) adds the cluster key for the ingress
layer, `REKEY_ON_LEAVE = TRUE`, rotation and departure in flight, and the
strongest adversary of each kind: both ingress nodes and a global observer
(`am_safety`); an egress and the observer (`am_exposure`); a non-egress
member of the egress cluster and the observer (`am_bridge`); and delivery
(`am_live`). `am_tcp` is its egress counterpart. See
[`resolutions.md`](resolutions.md).

### Properties

| Name | Kind | Formalises |
|---|---|---|
| `NoPayloadBeforeEgress` | invariant | PRA: "no intermediary cluster or relay node can see the payload before it reaches the end of the secure channel" — for every node v ∉ O |
| `PayloadNeedsEgress` | invariant | coalition form: the payload needs a compromised egress |
| `ExposureByExit` | invariant | premise of Φ_N (CMP): once the message has left, a coalition knows the payload only if the exit node is compromised. Checked at completion: knowledge only grows and every behaviour can be extended to an exit |
| `EgressReachable` | invariant | almost-sure delivery, graph form |
| `Delivered` | liveness | almost-sure delivery, strong fairness on every walk transition |
| `ForwardSecrecy` | invariant | PRA: keys are "forward secure" |
| `PostLeave` | invariant | not claimed: a member that left cannot open layers sealed after it left |

## `spec/GsrpEgress.tla` — egress sessions (DON)

One flow θ leaves a cluster of three members (a fourth may join).

| Action | Article |
|---|---|
| `SendSeg` | a member sends a TCP segment: looks T_C up; if absent selects z = F_C(θ) and inserts (θ, z); z allocates a = Choose(A_z); the source is rewritten to (z, a) |
| `Gossip` | RSDP merges replicas of T_C and of the membership view (eventually consistent; conflicting entries resolved to the smaller identifier) |
| `Join` | membership churn |
| `Fin` | FIN/RST: entries removed |
| `Boundary` | epoch t → t + 1 |
| `UdpSend` | an egress node sends a UDP packet; inserts (θ, a, d, ρ, τ_exp) into U_v if absent |
| `Tick`, `Deliver` | time; a response arrives within RTT ticks |

| Constant | Values (published first) | Text it decides |
|---|---|---|
| `FACADE` | `"choose"` / `"hash"` | F_C(θ): any member, or a function of the local membership view (the model uses the largest identifier; any function of the view changes under some membership change) |
| `TABLE` | `"gossip"` / `"consensus"` | how the "cluster-wide shared state" is kept |
| `CARRY` | `"published"` / `"amended"` | T_C(t), S(t), R(t) per epoch, or carried until FIN/RST/expiry |
| `REFRESH` | `"published"` / `"amended"` | τ_exp fixed when the U_v entry is created, or refreshed on use |
| `CHURN`, `EPOCHS` | booleans | a join, an epoch boundary during the session |
| `TauExp`, `RTT`, `MaxSeg` | 2, 2, 3 | an entry is valid while its age ≤ TauExp (t ≤ τ_exp) |

| Property | Formalises |
|---|---|
| `OneFacade` | DON: "a cluster must maintain a single façade node for the duration of a TCP session" — one source (z, a) per open session |
| `ReturnPath` | a response to any source the session used reaches a façade that holds the session |
| `Cleanup` | after FIN/RST every replica eventually drops θ (liveness, weak fairness on gossip) |
| `UdpReturn` | a UDP response arriving within RTT finds its entry and return path |
| `UdpSourceStable` | DON: dispersion "should appear seamless for the initiator and recipient" — one source per UDP flow |

Assumption, not checked: a segment sent by one member with the source
rewritten to the façade's address is delivered (network ingress filtering
and the TCP state at the façade are outside the model). A façade crash
ends its sessions; the article makes no claim about it.

Small-scope argument: every property concerns one flow, and flows share no
state except tables keyed by θ, so one flow suffices; races need two
senders and churn a further node.

## Not covered

- Interactions between the two modules: key rotation (channel) and table
  epochs (egress) use separate epoch notions; a TCP session's onion traffic
  is not modelled in `GsrpEgress`.
- Overlapping cluster membership (|M(v)| > 1), multiple messages and
  flows, active network attackers, timing analysis.
