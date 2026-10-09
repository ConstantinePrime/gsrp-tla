# Finding: one onion layer for a set of ingress or egress nodes

Verdict: **Gap** in PRA, with two completions. Rows `ch_onion_literal`
(violated); `ch_live_perpacket`, `ch_live_kemdem`, `ch_pub_perpacket`,
`ch_pub_kemdem`, `ch_disp_perpacket`, `ch_disp_visit` (hold);
`ch_disp_obs` (violated) of `spec/GsrpChannel.tla`.

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

`Delivered` is violated: a message is delivered only when dispatch and
the walk happen to reach the node the layer was sealed for, so delivery is
not almost sure. The same happens at the egress when the walk reaches the
other egress first.

## Two completions

- **Per-packet targeting** (`ONION = "per_packet"`): each packet's header
  targets one ingress and one egress chosen from I and O; the client sends
  to that ingress and the walk continues until that egress. Dispersion over
  O comes from choosing per packet.
- **KEM-DEM** (`ONION = "kem_dem"`): one content key per layer, encapsulated
  for every node of the set; any of them opens the layer. Following PRA's
  transition operator, which sends a message at any u ∈ O to Srv, the walk
  exits at the first egress it reaches.

Both deliver every message (`ch_live_perpacket`, `ch_live_kemdem`) and keep
the payload from every non-egress node, even with both ingress nodes
compromised and a global observer (`ch_pub_perpacket`, `ch_pub_kemdem`).

## How they compare on the dispersion premise

CMP models the adversary's view as Φ_N = Σ X_i F_i: a compromised egress i
sees the share F_i of traffic that exits through it. `ExposureByExit`
checks that premise.

- **Against CMP's adversary, a set B of compromised relays, both keep
  it.** Per-packet targeting holds (`ch_disp_perpacket`), and so does
  KEM-DEM (`ch_disp_visit`): a compromised egress sees a message only
  when the walk reaches it, and then the message exits there.
- **With a global passive observer as well, only per-packet targeting
  keeps it.** In a private cluster, a compromised egress derives every
  link key from s_C. Under KEM-DEM it can open the egress layer of any
  packet it observes, so with the observer it reads messages that never
  touch it (`ch_disp_obs`: 1 → 4, exit at 4, node 3 compromised). Under
  per-packet targeting the egress layer is sealed for the targeted egress
  alone (`ch_disp_perpacket` holds against the same adversary).
- **Who sets F_i.** Under per-packet targeting the client sets the shares
  directly: w_i = ε_t(i). Under KEM-DEM they are the walk's first-hitting
  distribution over O, which the client does not choose.

## The cost of per-packet targeting

The ingress and every relay that strips a link layer see the egress
header H_eg, so they learn which egress the packet is for. The
multi-recipient header of KEM-DEM does not reveal that. The model has no
unlinkability property, so this cost is stated, not checked. A key-private
KEM, where the egress finds its packet by trial decapsulation with no
explicit target in H_eg, would remove it.

## Proposed amendment

> The client encapsulates each packet's ingress and egress layers for one
> ingress and one egress, chosen per packet from I and O; the walk carries
> the packet to that egress.

This completes PRA consistently with the analysis in CMP, and makes the
shares w_i the client's choice. KEM-DEM is the alternative if the
egress's identity must be hidden from relays and no global observer is in
the threat model.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G2.
