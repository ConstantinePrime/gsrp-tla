# GSRP model: results

TLC 2.19 of 08 August 2024 (rev 5a47802, release v1.7.4, the
`tla2tools.jar` the Makefile fetches and checks), OpenJDK 21, Linux, one
worker. With one worker breadth-first search is exact: counterexamples are
shortest and depths are true diameters, so the numbers below reproduce.
Liveness counterexamples (`violated:temporal`) are lassos found by TLC's
liveness checker and need not be shortest. Logs: `logs/<row>.log`;
counterexamples cited in the docs: `traces/`.

The table is generated from the logs by `python3 tools/check.py --md`;
*Expected* comes from the row table in `tools/gen_models.py`. A ✗ in
*Result* is a violated property: expected for mutations, published
readings found wanting, characterisations and witnesses.

| Row | Expected | Result | Distinct states | Depth / trace | Time |
|---|---|---|---|---|---|
| `ch_peel_pub` | violated:temporal | ✗ temporal | 1020 | trace 6 | 00s |
| `ch_onion_literal` | violated:temporal | ✗ temporal | 40 | trace 4 | 00s |
| `ch_live_perpacket` | holds | ✓ holds | 28 | depth 5 | 00s |
| `ch_live_kemdem` | holds | ✓ holds | 9 | depth 5 | 00s |
| `ch_pub_perpacket` | holds | ✓ holds | 860 | depth 14 | 00s |
| `ch_pub_kemdem` | holds | ✓ holds | 21171 | depth 23 | 05s |
| `ch_disp_visit` | violated:ExposureByExit | ✗ ExposureByExit | 54 | trace 6 | 00s |
| `ch_disp_obs` | violated:ExposureByExit | ✗ ExposureByExit | 22 | trace 5 | 00s |
| `ch_disp_perpacket` | holds | ✓ holds | 860 | depth 14 | 00s |
| `ch_priv_cluster` | violated:NoPayloadBeforeEgress | ✗ NoPayloadBeforeEgress | 15 | trace 4 | 00s |
| `ch_priv_node` | holds | ✓ holds | 120 | depth 12 | 00s |
| `ch_priv_ingress` | holds | ✓ holds | 860 | depth 14 | 01s |
| `ch_reach_bridge` | holds | ✓ holds | 32 | depth 7 | 00s |
| `ch_reach_nobridge` | violated:EgressReachable | ✗ EgressReachable | 9 | trace 3 | 00s |
| `ch_reducible` | violated:EgressReachable | ✗ EgressReachable | 9 | trace 3 | 00s |
| `ch_rotate_g0` | violated:temporal | ✗ temporal | 512 | trace 8 | 00s |
| `ch_rotate_g1` | holds | ✓ holds | 448 | depth 9 | 04s |
| `ch_fs` | holds | ✓ holds | 18336 | depth 19 | 01s |
| `ch_fs_window` | violated:ForwardSecrecy | ✗ ForwardSecrecy | 585 | trace 7 | 00s |
| `ch_leave_pub` | violated:PostLeave | ✗ PostLeave | 76 | trace 5 | 00s |
| `ch_leave_rekey` | holds | ✓ holds | 5620 | depth 16 | 01s |
| `am_safety` | holds | ✓ holds | 128000 | depth 20 | 01min 35s |
| `am_exposure` | holds | ✓ holds | 128000 | depth 20 | 37s |
| `am_bridge` | holds | ✓ holds | 23136 | depth 18 | 06s |
| `am_live` | holds | ✓ holds | 1600 | depth 10 | 26s |
| `wc_delivered` | violated:NotDelivered | ✗ NotDelivered | 25 | trace 5 | 00s |
| `wc_bridge` | violated:NoBridge | ✗ NoBridge | 15 | trace 4 | 00s |
| `wc_bad_relays` | violated:NoBadHandles | ✗ NoBadHandles | 5 | trace 2 | 00s |
| `wc_rotation` | violated:NoRotationInFlight | ✗ NoRotationInFlight | 26 | trace 3 | 00s |
| `wc_late` | violated:NoLate | ✗ NoLate | 618 | trace 7 | 00s |
| `wc_leave` | violated:NoLeaveInFlight | ✗ NoLeaveInFlight | 20 | trace 3 | 00s |
| `eg_choose_gossip` | violated:OneFacade | ✗ OneFacade | 22 | trace 3 | 00s |
| `eg_hash_gossip` | holds | ✓ holds | 405 | depth 9 | 00s |
| `eg_hash_churn` | violated:OneFacade | ✗ OneFacade | 70 | trace 4 | 00s |
| `eg_consensus` | holds | ✓ holds | 14545 | depth 10 | 00s |
| `eg_epoch_pub` | violated:OneFacade | ✗ OneFacade | 72 | trace 4 | 00s |
| `eg_epoch_amd` | holds | ✓ holds | 810 | depth 10 | 00s |
| `eg_cleanup` | holds | ✓ holds | 405 | depth 9 | 00s |
| `eg_udp` | holds | ✓ holds | 4810 | depth 14 | 00s |
| `eg_udp_pub` | violated:UdpReturn | ✗ UdpReturn | 2363 | trace 8 | 00s |
| `eg_udp_tight` | violated:UdpReturn | ✗ UdpReturn | 186 | trace 5 | 00s |
| `eg_udp_source` | violated:UdpSourceStable | ✗ UdpSourceStable | 9 | trace 3 | 00s |
| `am_tcp` | holds | ✓ holds | 29090 | depth 11 | 01s |
| `we_session` | violated:NoMultiSender | ✗ NoMultiSender | 9 | trace 3 | 00s |
| `we_concurrent_open` | violated:NoConcurrentOpen | ✗ NoConcurrentOpen | 21 | trace 3 | 00s |
| `we_udp_resp` | violated:NoUdpAnswer | ✗ NoUdpAnswer | 52 | trace 4 | 00s |
| `we_join` | violated:NoJoin | ✗ NoJoin | 8 | trace 2 | 00s |
| `we_epoch` | violated:NoBoundaryInSession | ✗ NoBoundaryInSession | 15 | trace 3 | 00s |

## Reading the results

- **Delivery.** Read literally, no message is delivered: nobody removes the
  hop, link and bridge layers (`ch_peel_pub`,
  [`finding-layer-removal.md`](finding-layer-removal.md)), and one layer
  cannot be opened by whichever ingress or egress the message reaches
  (`ch_onion_literal`,
  [`finding-multi-recipient-onion.md`](finding-multi-recipient-onion.md)).
  With the layer-removal step and either completion of the onion, every
  message is delivered almost surely (`ch_live_*`).
- **Confidentiality.** With individual egress keys, no node outside O ever
  learns the payload, even with both ingress nodes compromised and every
  link observed (`ch_pub_*`, `ch_priv_node`). Using a private cluster's key
  for the egress layer lets a non-egress member read it (`ch_priv_cluster`,
  [`finding-private-cluster-key.md`](finding-private-cluster-key.md)); for
  the ingress layer alone it is safe (`ch_priv_ingress`).
- **Dispersion (CMP).** The premise that a compromised egress sees only the
  traffic exiting through it holds for per-packet targeting
  (`ch_disp_perpacket`) and fails for KEM-DEM (`ch_disp_visit`,
  `ch_disp_obs`). The probabilities of CMP are outside TLC's scope; this is
  the qualitative condition they need.
- **Reachability.** Irreducibility of P_C is necessary (`ch_reducible`); in
  addition the client's choice of O must be reachable from I
  (`ch_reach_nobridge`,
  [`finding-egress-reachability.md`](finding-egress-reachability.md)).
- **Keys.** Per-entity rotation drops messages in flight unless the previous
  key is kept for a grace period (`ch_rotate_*`); the grace period is
  exactly the forward-secrecy window (`ch_fs`, `ch_fs_window`,
  [`finding-key-rotation.md`](finding-key-rotation.md)). A member that leaves
  a private cluster reads its link layers until s_C is renewed
  (`ch_leave_pub`); renewing on departure closes it (`ch_leave_rekey`).
- **Egress sessions (DON).** An eventually consistent façade table gives a
  TCP session two sources (`eg_choose_gossip`, `eg_hash_churn`); selection
  through consensus fixes it (`eg_consensus`,
  [`finding-facade-consistency.md`](finding-facade-consistency.md)). Tables
  must survive the epoch boundary (`eg_epoch_*`,
  [`finding-epoch-tables.md`](finding-epoch-tables.md)). UDP entries must be
  refreshed on use and outlive the response delay (`eg_udp*`,
  [`finding-udp-expiry.md`](finding-udp-expiry.md)); the server sees several
  sources per UDP flow (`eg_udp_source`). Cleanup after FIN/RST holds
  (`eg_cleanup`).
- **The resolved protocol.** With every amendment on, while nodes rotate
  and members leave, the payload needs a compromised egress (`am_safety`,
  `am_bridge`), exposure goes only through the exit node (`am_exposure`),
  every message is delivered (`am_live`), and a TCP session keeps one
  source across churn and an epoch boundary (`am_tcp`). Each amendment's
  rationale, alternatives and cost:
  [`resolutions.md`](resolutions.md).
- Every passing row is backed by a witness showing that the scenario it
  relies on occurs (`wc_*`, `we_*`).

## Reproducing

`make quick` runs every row in about 4 minutes and ends with
`tools/check.py`, which exits non-zero if any verdict differs from its
expectation. `make <row>` or `./run.sh <row>` runs one row. The
configurations are generated by `python3 tools/gen_models.py` from one
table; regenerate them rather than editing them, so rows stay comparable.
