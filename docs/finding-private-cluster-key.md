# Finding: the private-cluster key exposes the payload inside the egress cluster

Verdict: **Defect** in PRA. Rows `ch_priv_cluster`, `ch_priv_cluster_all`
(violated) and `ch_priv_node`, `ch_priv_ingress` (hold) of
`spec/GsrpChannel.tla`.

## The published text

PRA: "With private structures a client can use the cluster public key
instead of individual keys for every node". And: "This guarantees that no
intermediary cluster or relay node can see the payload before it reaches
the end of the secure channel."

The secret key behind a cluster public key is held by the cluster's
members, as the shared secret s_C is (PRA: maintained through the
cluster's consensus). The egress set O is a subset of the cluster.

## Counterexample

Scenario `bridge`: C1 = {1, 2} public, C2 = {3, 4, 5} private,
O = {4, 5}, bridge 2 → 3; the egress layer is sealed under C2's key
(`KEYS = "cluster"`). Trace `traces/ch_priv_cluster.trace.txt`:

| State | Action | stage | pos | Comment |
|---|---|---|---|---|
| 1 | Init | client | — | ingress 2, egress 4 |
| 2 | Dispatch | ingress | 2 | |
| 3 | Ingress | walk | 2 | |
| 4 | Move | walk | 3 | 3 removes the bridge layer and holds (H_eg, Q); H_eg's encapsulation opens with C2's key, which 3 holds |

In state 4 node 3 — a relay, not an egress — knows the payload:
`NoPayloadBeforeEgress` is violated. Threshold decryption among the egress
nodes, which the article does not mention, would avoid it.

## The other reading: every member is an egress

One could read the cluster key as making the whole egress cluster the
egress set, O = C2. Then no relay inside C2 is a non-egress, and
`NoPayloadBeforeEgress` holds vacuously. What fails instead is the premise
of CMP's dispersion analysis, that a compromised egress sees only the
traffic that exits through it. `ch_priv_cluster_all` (scenario
`bridge_all`, O = {3, 4, 5}, node 3 compromised; trace
`traces/ch_priv_cluster_all.trace.txt`):

| State | Action | stage | pos | Comment |
|---|---|---|---|---|
| 1 | Init | client | — | ingress 2, egress 4 |
| 2 | Dispatch | ingress | 2 | |
| 3 | Ingress | walk | 2 | |
| 4 | Move | walk | 3 | 3 opens the egress layer with C2's key |
| 5 | Move | walk | 4 | |
| 6 | Exit | done | — | the message exits at 4, but 3 knows the payload |

`ExposureByExit` is violated. So the cluster key breaks one of the
article's two claims under either reading: the confidentiality claim if
O ⊂ C, the dispersion premise if O = C.

## Proposed amendment

> The egress layer is always sealed under the individual key of the egress
> node; the cluster key may be used for the ingress layer.

With individual keys `NoPayloadBeforeEgress` holds (`ch_priv_node`). With
the cluster key for the ingress layer only (`KEYS = "ingress"`), it holds
too, and so does `PayloadNeedsEgress`, with both ingress nodes compromised
and a global observer (`ch_priv_ingress`): a member that opens the ingress
layer finds only the egress layer, sealed for the egress node. With every
resolution on, a compromised non-egress member of the egress cluster never
learns the payload (`am_bridge`). Alternatives and rationale:
[`resolutions.md`](resolutions.md), G3.
