# Resolutions of the findings

For each finding of this artifact, this document gives the amendment to
GSRP: the amended rule in the article's notation, why it was chosen over
the alternatives, what it costs, and what the model checks. The article
and the finding documents stay as published. The dissertation presents
the amended protocol and cites this document, and the rows named in it,
as the analysis behind the amendments. Headings of [GSRP] are cited as
PRA (*Path routing architecture*), DON (*Dispersion of the outer nodes*)
and CMP (*Comparison with existing protocols*).

Each resolution has a status:

- **Checked** — the rows hold with the resolution in place, and a
  mutation row shows what fails without it, within the bounds of
  [`model.md`](model.md);
- **Argued** — the proof is given here and is not model-checked.

## Summary

| | Finding | Verdict | Resolution | Rows | Status |
|---|---|---|---|---|---|
| G1 | No step removes the hop, link and bridge layers | Gap | a receiving node removes them; the carried message is invariant along the walk | `ch_peel_pub` / `ch_live_perpacket`, `ch_live_kemdem` | Checked |
| G2 | One onion layer for a set of nodes | Gap | per-packet targeting: one ingress and one egress per packet | `ch_onion_literal`, `ch_disp_visit`, `ch_disp_obs` / `ch_live_perpacket`, `ch_disp_perpacket` | Checked |
| G3 | The private-cluster key exposes the payload | Defect | the egress layer always under the egress node's key; the cluster key only for the ingress layer | `ch_priv_cluster` / `ch_priv_node`, `ch_priv_ingress`, `am_bridge` | Checked |
| G4 | The egress may be unreachable | Gap | the egress is chosen within reach of the ingress over published bridges | `ch_reach_nobridge`, `ch_reducible` / `ch_reach_bridge` | Checked; bridge repair argued |
| G5 | Key rotation drops messages in flight | Gap | epochs named in H; previous keys kept for one epoch | `ch_rotate_g0` / `ch_rotate_g1`; `ch_fs`, `ch_fs_window` | Checked; drop bound argued |
| G6 | A departed member reads later link layers | Characterisation | s_C renewed on every membership change | `ch_leave_pub` / `ch_leave_rekey` | Checked for departure; join argued |
| G7 | An eventually consistent façade table splits TCP sessions | Gap | the façade entry is committed through consensus before the first segment | `eg_choose_gossip`, `eg_hash_churn` / `eg_consensus` | Checked |
| G8 | Per-epoch tables break sessions | Gap | entries carried until FIN/RST or expiry | `eg_epoch_pub` / `eg_epoch_amd` | Checked |
| G9 | UDP entries expire under active flows | Gap | refresh on every outbound packet; τ_exp ≥ RTT | `eg_udp_pub`, `eg_udp_tight` / `eg_udp` | Checked |
| G10 | The server sees several sources per UDP flow | Characterisation | address-bound UDP flows pinned to a façade | `eg_udp_source` | Argued |

The resolutions are also checked together:

- `am_safety`, `am_exposure` and `am_bridge` (confidentiality and the
  dispersion premise) and `am_live` (delivery) switch every channel
  resolution on. They let nodes rotate and members leave while the message
  is in flight, under the strongest adversary of their kind.
- `am_tcp` switches every egress resolution on.

## G1. Layer removal

**Finding** ([`finding-layer-removal.md`](finding-layer-removal.md)). PRA
defines how a node wraps the message for the next hop: Φ^intra (a link
layer over a hop layer) inside a cluster, and Enc_{k^bridge} between
clusters. No step unwraps it. Read literally, layers accumulate, and the
egress applies its key to a link-layer ciphertext, so nothing is ever
delivered (`ch_peel_pub`).

**Resolution.**

> On receipt over a link (u, v), v removes the link layer, then the hop
> layer of u — keys KS(s_C(t), ·) in a private cluster, the pairwise link
> key in a public one — or, over a bridge, the bridge layer
> k^bridge_{i→j}(t). The carried message M_τ is the same at every step of
> the walk; only its wrapping W_τ = Φ_{S_τ→S_{τ+1}}(M_τ) travels on the
> wire, and M_{τ+1} = M_τ.

**Alternatives.** Peeling all the hop layers at the egress, as onion
layers, would need the client to know the hops, but the walk is random.
Per-hop wrapping is link encryption, and it is removed per hop.

In a private cluster every member derives every hop and link key from
s_C, so these layers protect only against non-members. The confidentiality
of the payload rests on the egress layer (G3).

**Checked.**

- `ch_peel_pub`: the published reading fails — no delivery.
- `ch_live_perpacket`, `ch_live_kemdem`: every message is delivered.
- `ch_pub_perpacket`, `ch_pub_kemdem`: the payload stays hidden from every
  non-egress node, with both ingress nodes compromised and every link
  observed.

## G2. Multi-recipient onion

**Finding**
([`finding-multi-recipient-onion.md`](finding-multi-recipient-onion.md)).
H carries one encapsulation for every node of I and O. But a layer
encrypted once opens with only one of the independently encapsulated
keys, and the ingress or egress that the message reaches may be the wrong
one (`ch_onion_literal`).

**Resolution.**

> For each packet the client draws an ingress x ∼ ι_t over I and an egress
> y ∼ ε_t over O. It encapsulates the ingress layer for x only and the
> egress layer for y only, and sends the packet to x. The walk continues
> until it reaches y; any other egress node forwards the packet like a
> relay. ε_t ∈ Δ(O) is the client's egress dispersion distribution.

|I|, |O| ≥ k then bounds the sets the dispersion draws from over many
packets, not the recipients of one packet.

**Alternatives.** The other completion is KEM-DEM: one content key per
layer, encapsulated for every node of the set.

- Both completions deliver (`ch_live_*`), and both keep the payload from
  non-egress nodes (`ch_pub_*`).
- KEM-DEM breaks the premise of CMP's Φ_N = Σ X_i F_i, that a compromised
  egress sees only the traffic that exits through it:
  - a compromised egress reads every packet that passes through it
    (`ch_disp_visit`);
  - in a private cluster, with an observer, it also reads packets that
    never touch it (`ch_disp_obs`).
- Per-packet targeting keeps the premise (`ch_disp_perpacket`) and makes
  it exact: the client chooses w_i = ε_t(i), and E[F_i] = w_i.
- Per-packet targeting also shrinks H from |I| + |O| encapsulations to
  two.

**Cost.** The walk ends at one node instead of at the first egress it
meets, so it is longer. By Kac's formula, the stationary walk returns to y
after 1/π_C(y) steps on average, and to the set O after 1/π_C(O). This is
argued, not measured.

**Checked.**

- `ch_onion_literal`: the published reading fails.
- `ch_live_perpacket`: per-packet targeting delivers.
- `ch_disp_perpacket`: the dispersion premise holds.
- `ch_disp_visit`, `ch_disp_obs`: the premise fails under KEM-DEM.
- `am_exposure`: the premise holds with every resolution on, while nodes
  rotate and members leave.

## G3. Private-cluster key

**Finding**
([`finding-private-cluster-key.md`](finding-private-cluster-key.md)). PRA
lets a client use a private cluster's public key "instead of individual
keys". Sealing the egress layer under it lets every member of the egress
cluster read the payload, including relays that are not egress nodes. In
`ch_priv_cluster`, non-egress member 3 knows the payload as soon as the
message enters the cluster. This fails under every reading in which
members hold the cluster's secret key.

**Resolution.**

> The egress layer is always sealed under the individual KEM key
> PK^kem_y(t) of the egress node y. In a private cluster, the client may
> seal the ingress layer under the cluster's public key.

**Why the ingress layer may use the cluster key.** The ingress layer
hides the inner header and the egress layer on the client–ingress link. A
member that opens it learns (H_eg, Q), which it cannot open. This keeps
PRA's simplification, one key to fetch per private cluster, where it is
safe, and drops it where it is not.

**Alternatives.** Threshold decryption of the egress layer among O would
restore the cluster key for the egress layer. It needs a threshold KEM
and an interaction between egress nodes for every packet, and the article
mentions neither.

**Checked.**

- `ch_priv_cluster`: the published reading fails.
- `ch_priv_node`: individual keys hold.
- `ch_priv_ingress`: the cluster key for the ingress layer holds, with
  both ingress nodes compromised and every link observed.
- `am_bridge`: with every resolution on, a compromised non-egress member
  of the egress cluster never learns the payload.

## G4. Egress reachability

**Finding**
([`finding-egress-reachability.md`](finding-egress-reachability.md)).
Irreducibility of P_C makes every member of a cluster reachable inside it,
but nothing relates O to the clusters reachable from I. Inter-cluster
edges "may not be set up initially". With no link between the clusters of
I and O, the walk never reaches an egress: delivery has probability 0
(`ch_reach_nobridge`). `ch_reducible` confirms that irreducibility is
necessary too.

**Resolution.**

> RSDP publishes, with P_C(t), the support of the inter-cluster kernels:
> the bridges ℬ_{i→j}(t) in place. The client chooses O so that every
> node the walk can reach from an ingress in I can reach every egress in
> O over that support. When a bridge endpoint leaves its cluster, the
> bridge is re-established with another member before it is used again
> (PRA's on-demand bridge setup).

**Why this is the right condition.** In a finite Markov chain, the walk
from x hits y with probability 1 iff y is reachable from every state
reachable from x. So the condition is exactly almost-sure delivery, and
it is what `EgressReachable` checks in every reachable state. The client
already chooses I and O from RSDP's view, so the only cost is publishing
the bridge map.

**Checked.**

- `ch_reach_nobridge`: no bridge — fails.
- `ch_reducible`: P_C not irreducible — fails.
- `ch_reach_bridge`: `EgressReachable` and `Delivered` hold with a bridge.
- `wc_bridge`: the message does cross the bridge (witness).

The re-establishment of a bridge after its endpoint leaves is argued. The
model's bridges are fixed.

## G5. Key rotation

**Finding** ([`finding-key-rotation.md`](finding-key-rotation.md)).
Epochs are per entity, and nothing says how long a node keeps a past
epoch's secret key. A node that rotates while a packet sealed under its
old key is in flight drops the packet (`ch_rotate_g0`).

**Resolution.**

> Every encapsulation in H names its epoch: (x, t_x, c_x) and
> (y, t_y, c_y). A node keeps the KEM secret key of epoch t − 1
> throughout epoch t and erases it when t + 1 begins. A private cluster
> keeps s_C(t − 1) in the same way. The client encapsulates under the key
> of the current epoch in RSDP's map.

**Delivery.** A packet is delivered if the node that opens it rotates at
most once while the packet is in flight (`ch_rotate_g1`). A packet that
outlives two rotations of that node is dropped. How often that happens
depends on the epoch length, as follows (argued).

- Inside a finite irreducible chain, y is reached from any node within r
  steps with probability at least ε > 0, for some r and ε.
- Hence Pr(T > n·r) ≤ (1 − ε)^n for the hitting time T.
- With epochs at least L steps long, a packet is dropped with probability
  at most (1 − ε)^⌊L/r⌋, which decreases exponentially in the epoch
  length.
- The transport layer retransmits the rest.

**Forward secrecy.** The grace period is the forward-secrecy window. A key
of epoch t is erased when t + 2 begins. A compromise after that reveals
nothing of traffic sealed under it (`ch_fs`, which models the state after
the grace period ends). A compromise within the window reveals that
traffic (`ch_fs_window`). PRA's "forward secure" therefore holds with a
window of up to two epochs from encapsulation. The epoch length trades
dropped packets against the width of that window.

**Alternatives.**

- *No grace period:* a window of one epoch, but every rotation drops the
  packets in flight.
- *Per-message keys or puncturable encryption:* a smaller window at the
  cost of per-node state. Outside the scope of the article.

**Checked.**

- `ch_rotate_g0`: no grace period — fails.
- `ch_rotate_g1`: one-epoch grace period — holds.
- `ch_fs`: forward secrecy after the grace period — holds.
- `ch_fs_window`: within the grace period — fails, measuring the window.
- `wc_rotation`, `wc_late`: a rotation in flight and the late compromise
  do occur (witnesses).
- `am_live`: delivery with every resolution on, while nodes rotate and
  members leave.

The bound on dropped packets is argued.

## G6. Membership changes in a private cluster

**Finding** (not claimed by the article). A member that leaves a private
cluster keeps s_C(t). Until the next epoch it can open the link and hop
layers of traffic sent after it left (`ch_leave_pub`).

**Resolution.**

> The cluster renews s_C on every membership change, a departure or a
> join, through its consensus, which starts a new cluster epoch.

Link and hop layers protect against non-members, and a departed member is
one. Renewal on a join gives the symmetric property: a new member cannot
open link layers recorded before it joined. The same rule is used in
group key agreement, where every addition or removal starts a new epoch
[RFC 9420]. The cost is one consensus round per membership change, which
RSDP already runs for the change itself. The payload was never at stake,
because it is sealed under an individual key (G3).

**Checked.**

- `ch_leave_pub`: no renewal — fails.
- `ch_leave_rekey`: renewal on departure — holds.
- `wc_leave`: traffic is sent after the member left (witness).
- `am_safety`, `am_exposure`: with every resolution on.

The join case is argued; the model has departures only.

## G7. Façade consistency

**Finding**
([`finding-facade-consistency.md`](finding-facade-consistency.md)). DON
looks the façade of flow θ up in T_C(t), "the cluster-wide shared state",
and inserts F_C(θ) if it is absent. RSDP state is eventually consistent:

- two members that look θ up before either insert reaches the other
  select different façades (`eg_choose_gossip`);
- a façade computed from the membership view changes under churn
  (`eg_hash_churn`).

**Resolution.**

> The façade entry of a new flow, (θ, z⋆, a⋆), is committed through the
> cluster's consensus (RSDP) before the first segment of θ leaves the
> cluster. z⋆ allocates a⋆ ← Choose(A_{z⋆}) and the entry is proposed.
> Concurrent proposals for θ are resolved by consensus, and the first
> committed entry wins. Members rewrite every segment of θ to (z⋆, a⋆)
> from the committed entry and never select a façade themselves.

The entry carries a⋆ because members rewrite the source port as well as
the address (DON), while in the article S_{z⋆} is local to z⋆. The model
abstracts this by letting every member read S.

**Why consensus.** Any rule a member evaluates on its own replica fails:

- a free choice fails under concurrent opens;
- any function of the membership view changes under some membership
  change.

Every cluster already runs RSDP, so consensus is the smallest change
within the article's design. It costs one consensus round when a TCP flow
opens, added once per connection to the handshake latency.

**Alternative** (argued, not checked). The client pins the façade: it
chooses z⋆ for θ, sends the SYN through z⋆ (per-packet targeting, G2),
learns a⋆ from the reply, and names (z⋆, a⋆) in the egress layer of every
later packet. With one writer, the client, the entry is consistent
without consensus. The cost is that a⋆ travels back to the client.

**Checked.**

- `eg_choose_gossip`: free choice over gossip — fails.
- `eg_hash_churn`: a function of the membership view, with churn — fails.
- `eg_hash_gossip`: the same function without churn — holds.
- `eg_consensus`: consensus, with free choice and churn — holds.
- `we_session`, `we_concurrent_open`: sessions span several senders, and
  concurrent opens occur (witnesses).
- `am_tcp`: with G8 as well.

## G8. Tables across epochs

**Finding** ([`finding-epoch-tables.md`](finding-epoch-tables.md)). DON
indexes T_C(t), S_{z⋆}(t) and R_{z⋆}(t) by epoch. Read as written, the
tables of epoch t + 1 start empty, and a session that crosses the
boundary gets a new source port (`eg_epoch_pub`).

**Resolution.**

> Session entries are carried from epoch t to t + 1, and removed only on
> FIN/RST or expiry.

**Checked.**

- `eg_epoch_pub`: per-epoch tables — fail.
- `eg_epoch_amd`: carried tables — hold.
- `we_epoch`: a boundary does fall inside a session (witness).
- `am_tcp`: with every egress resolution on.

## G9. UDP entry expiry

**Finding** ([`finding-udp-expiry.md`](finding-udp-expiry.md)). τ_exp is
set when the U_v entry is created and never refreshed. A flow that lives
longer than τ_exp loses responses (`eg_udp_pub`). With τ_exp < RTT, it
loses them even with refresh (`eg_udp_tight`).

**Resolution.**

> Every outbound packet of θ refreshes the τ_exp of its entry, and τ_exp
> exceeds the longest expected response delay (RTT plus server
> processing).

This is NAT practice [RFC 4787]. REQ-6 requires outbound refresh. REQ-5
requires a UDP mapping timer of at least two minutes and recommends five
minutes or more.

**Checked.**

- `eg_udp_pub`: no refresh — fails.
- `eg_udp_tight`: τ_exp < RTT — fails.
- `eg_udp`: refresh and τ_exp ≥ RTT — holds.
- `we_udp_resp`: a response does return (witness).

## G10. UDP flows bound to an address

**Finding** (characterisation). Per-packet dispersion over egress nodes
makes the server see several source addresses for one UDP flow
(`eg_udp_source`). DON's "seamless for the initiator and recipient" holds
only for UDP protocols that do not bind a session to the client's
address.

**Resolution.**

> UDP flows are dispersed per packet only for protocols that do not bind
> state to the source address. Flows of protocols that do — QUIC, which
> treats a packet from a new address as a possible migration and
> validates the new path [RFC 9000, §8.2, §9], or DTLS — are pinned to a
> façade like a TCP session (G7, G8) and expire by τ_exp instead of
> FIN/RST. The initiator knows the application protocol and marks θ
> accordingly.

*Argued.* The façade rows check the table discipline for one flow
regardless of transport. The expiry-based cleanup of a pinned UDP flow is
not checked.

## Assumptions the resolutions make explicit

The model leaves out these points (see [`model.md`](model.md)). The
dissertation should state them as assumptions:

- **Source rewriting.** DON has a member send a segment with the façade's
  address. Networks that filter spoofed sources at ingress drop such
  packets unless the egress nodes share the façade's network [RFC 2827;
  RFC 3704]. GSRP therefore assumes that the egress nodes of a cluster can
  send with each other's addresses. Where they cannot, a TCP flow exits
  through its façade alone, dispersion of TCP is per flow, and F_i in CMP
  counts flows rather than packets.
- **The façade's own stack.** The façade opened no socket for θ, so its
  TCP stack would reset the server's segments. GSRP must take them below
  the stack.
- **Probabilities.** Out of scope for TLC: CMP's correlation
  probabilities, convergence to π_C, and latency. The resolutions keep the
  qualitative conditions those rest on: dispersion through the exit only
  (G2, G3), and almost-sure delivery (G4, G5).

## The resolved protocol

**Client, for each packet of flow θ:**

1. Choose I and O with |I|, |O| ≥ k such that O is reachable from I (G4).
   Draw x ∼ ι_t over I and y ∼ ε_t over O (G2).
2. (k_y, c_y) ← Encaps(PK^kem_y(t_y)); Q = Enc_{k_y}(AD, m);
   H_eg = (y, t_y, c_y) (G3, G5).
3. (k_x, c_x) ← Encaps(PK_x), where PK_x is x's KEM key of epoch t_x, or
   its cluster's public key if that cluster is private (G3).
   M = (H_in, Enc_{k_x}(AD, (H_eg, Q))), with H_in = (x, t_x, c_x). Send M
   to x.

**Node v, on receiving over a link (u, v):**

4. Remove the link, hop or bridge layer (G1), using the keys of epoch t,
   or t − 1 during the grace period (G5).
5. If v = x and M still has its ingress layer: decapsulate c_x, decrypt,
   or drop.
6. If v = y: decapsulate c_y with SK^kem_y(t_y), decrypt, and send m to
   Srv through the egress tables (items 9–10).
7. Otherwise: choose S_{τ+1} ∼ P_{C(v)}(t)[v, ·], or a bridge by
   Q_{i→j}(t), and send Φ_{v→S_{τ+1}}(M) or Enc_{k^bridge}(AD, M).

**Keys:**

8. Keep the previous epoch's KEM secret keys and s_C for one epoch (G5).
   Renew s_C on every membership change (G6).

**Egress:**

9. TCP, and UDP flows bound to an address: a committed entry
   (θ, z⋆, a⋆) (G7, G10), carried across epochs (G8), removed on FIN/RST
   or expiry.
10. Other UDP flows: an entry per egress node, refreshed by every
    outbound packet, with τ_exp above the response delay (G9).

## What the resolutions do not cover

- **Bounds.**
  - One message, followed through two epochs, at most one departure, and
    each node rotating at most once.
  - Clusters of four or five nodes, with k = 2.
  - One flow at the egress, with at most three segments or packets.
- **Adversary.** Passive network adversary only, and fixed sets of
  compromised nodes, except for the late compromise of the exit node.
- **Dynamics.** Bridges are fixed, and a façade crash ends its session
  (no claim about it).

## For the dissertation

A paragraph that introduces the amendments:

> Further analysis of the protocol with a formal model, checked with the
> TLC model checker (artifact `gsrp-tla`, tag `v1`), showed that the
> description in [GSRP] needs several amendments before the protocol
> delivers messages and keeps its confidentiality claims:
>
> - a step that removes the per-hop layers;
> - per-packet choice of one ingress and one egress, which also makes the
>   per-egress traffic shares of the correlation analysis exact;
> - the egress layer sealed under the egress node's own key, since the
>   private-cluster key exposes the payload to every member of the egress
>   cluster;
> - a choice of egress reachable from the ingress;
> - keys kept for one epoch after rotation, which bounds the
>   forward-secrecy window;
> - renewal of the cluster secret on membership changes;
> - façade selection through the cluster's consensus;
> - session tables carried across epochs;
> - refresh of UDP entries on use.
>
> Each amendment is checked in the model, separately and together. Without
> each of them, the model exhibits a counterexample.

## References

- [GSRP] M. Kotov, S. Toliupa. *Group State Routing Protocol (Mycelia): a
  new model for distributed network coordination*. Science-based
  technologies 4(68), 2025.
- [RFC 2827] P. Ferguson, D. Senie. *Network Ingress Filtering: Defeating
  Denial of Service Attacks which employ IP Source Address Spoofing*
  (BCP 38), 2000.
- [RFC 3704] F. Baker, P. Savola. *Ingress Filtering for Multihomed
  Networks* (BCP 84), 2004.
- [RFC 4787] F. Audet, C. Jennings. *Network Address Translation (NAT)
  Behavioral Requirements for Unicast UDP* (BCP 127), 2007.
- [RFC 9000] J. Iyengar, M. Thomson. *QUIC: A UDP-Based Multiplexed and
  Secure Transport*, 2021.
- [RFC 9420] R. Barnes et al. *The Messaging Layer Security (MLS)
  Protocol*, 2023.
