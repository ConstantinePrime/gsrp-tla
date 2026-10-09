# Finding: one onion layer for a set of ingress or egress nodes

Verdict: **Gap** in PRA, with two completions that differ on the
dispersion premise of CMP. Rows `ch_onion_literal` (violated);
`ch_live_perpacket`, `ch_live_kemdem`, `ch_pub_perpacket`, `ch_pub_kemdem`
(hold); `ch_disp_perpacket` (holds), `ch_disp_visit`, `ch_disp_obs`
(violated) of `spec/GsrpChannel.tla`.

## The published text

PRA: the client chooses ingress and egress sets with |I|, |O| ≥ k and
builds a nested onion "using respective public keys of chosen nodes for
the I and O". The ingress node "locates its encapsulation c_x^in ∈ H",
derives k_x^in = Decaps(SK_x, c_x^in) and computes Dec_{k_x^in}(AD, M); the
egress does the same with c_y^eg. The client picks the ingress afterwards,
S₁ ∼ ι_t over I.

Independent encapsulations yield independent keys. A layer encrypted once
can be decrypted with only one of them, yet H carries one encapsulation
per node and any node of the set may receive the message.

## Counterexample (literal reading)

`ch_onion_literal`: the layer is sealed under the key of one node chosen
when the onion is built; a node that cannot decrypt drops the message, as
PRA prescribes for the ingress. Trace `traces/ch_onion_literal.trace.txt`:

| State | Action | stage | pos | Comment |
|---|---|---|---|---|
| 1 | Init | client | — | ingress layer sealed for node 1 |
| 2 | Dispatch | ingress | 2 | ι_t picks node 2 |
| 3 | Ingress | dropped | 2 | 2 decapsulates its own key, which does not open the layer |

`Delivered` is violated; the same happens at the egress when the walk
reaches the other egress first.

## Two completions

- **Per-packet targeting** (`ONION = "per_packet"`): each packet's header
  targets one ingress and one egress chosen from I and O; the client sends
  to that ingress and the walk continues until that egress. Dispersion over
  O comes from choosing per packet.
- **KEM-DEM** (`ONION = "kem_dem"`): one content key per layer, encapsulated
  for every node of the set; any of them opens the layer.

Both deliver every message (`ch_live_perpacket`, `ch_live_kemdem`) and keep
the payload from every non-egress node, even with both ingress nodes
compromised and a global observer (`ch_pub_perpacket`, `ch_pub_kemdem`).

## They differ on the dispersion premise

CMP models the adversary's view as Φ_N = Σ X_i F_i: a compromised egress i
sees the share F_i of traffic that exits through it. `ExposureByExit`
checks that premise.

- Per-packet targeting keeps it, even in a private cluster with a
  compromised egress and a global observer (`ch_disp_perpacket`, holds).
- KEM-DEM breaks it in two ways. A compromised egress reads a message that
  only passes through it (`ch_disp_visit`: 1 → 3 → 4, exit at 4, node 3
  compromised). In a private cluster, a compromised egress that derives the
  link keys from s_C and is helped by an observer reads messages that never
  touch it (`ch_disp_obs`: 1 → 4, exit at 4, node 3 compromised). Under
  KEM-DEM a single compromised egress sees close to all of the flow, not
  its share F_i.

## Proposed amendment

> The client encapsulates each packet's ingress and egress layers for one
> ingress and one egress, chosen per packet from I and O; the walk carries
> the packet to that egress.

This completes PRA consistently with the analysis in CMP. KEM-DEM is an
alternative only if CMP's per-egress share model is restated for it.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G2.
