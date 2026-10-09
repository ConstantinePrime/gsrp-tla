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
| `ch_pub_kemdem` | holds | ✓ holds | 43 | depth 8 | 00s |
| `ch_disp_visit` | holds | ✓ holds | 43 | depth 8 | 00s |
| `ch_disp_obs` | violated:ExposureByExit | ✗ ExposureByExit | 16 | trace 5 | 00s |
| `ch_disp_perpacket` | holds | ✓ holds | 860 | depth 14 | 00s |
| `ch_priv_cluster` | violated:NoPayloadBeforeEgress | ✗ NoPayloadBeforeEgress | 15 | trace 4 | 00s |
| `ch_priv_cluster_all` | violated:ExposureByExit | ✗ ExposureByExit | 52 | trace 6 | 00s |
| `ch_priv_node` | holds | ✓ holds | 120 | depth 12 | 00s |
| `ch_priv_ingress` | holds | ✓ holds | 860 | depth 14 | 01s |
| `ch_reach_bridge` | holds | ✓ holds | 32 | depth 7 | 00s |
| `ch_reach_nobridge` | violated:EgressReachable | ✗ EgressReachable | 9 | trace 3 | 00s |
| `ch_reducible` | violated:EgressReachable | ✗ EgressReachable | 9 | trace 3 | 00s |
| `ch_rotate_g0` | violated:temporal | ✗ temporal | 452 | trace 8 | 00s |
| `ch_rotate_g1` | holds | ✓ holds | 388 | depth 9 | 03s |
| `ch_fs` | holds | ✓ holds | 18276 | depth 19 | 01s |
| `ch_fs_window` | violated:ForwardSecrecy | ✗ ForwardSecrecy | 525 | trace 7 | 00s |
| `ch_leave_pub` | violated:PostLeave | ✗ PostLeave | 76 | trace 5 | 00s |
| `ch_leave_rekey` | holds | ✓ holds | 5620 | depth 16 | 01s |
| `am_safety` | holds | ✓ holds | 126924 | depth 20 | 01min 36s |
| `am_exposure` | holds | ✓ holds | 126924 | depth 20 | 39s |
| `am_bridge` | holds | ✓ holds | 21612 | depth 18 | 06s |
| `am_live` | holds | ✓ holds | 1356 | depth 10 | 21s |
| `ch_know_monotone` | holds | ✓ holds | 150476 | depth 20 | 23s |
| `wc_am` | violated:NoRotateLeaveInFlight | ✗ NoRotateLeaveInFlight | 55 | trace 4 | 00s |
| `wc_am_bridge` | violated:NoBadHandles | ✗ NoBadHandles | 141 | trace 4 | 00s |
| `wc_delivered` | violated:NotDelivered | ✗ NotDelivered | 25 | trace 5 | 00s |
| `wc_bridge` | violated:NoBridge | ✗ NoBridge | 15 | trace 4 | 00s |
| `wc_bad_relays` | violated:NoBadHandles | ✗ NoBadHandles | 5 | trace 2 | 00s |
| `wc_rotation` | violated:NoRotationInFlight | ✗ NoRotationInFlight | 10 | trace 3 | 00s |
| `wc_late` | violated:NoLate | ✗ NoLate | 558 | trace 7 | 00s |
| `wc_leave` | violated:NoLeaveInFlight | ✗ NoLeaveInFlight | 20 | trace 3 | 00s |
| `eg_choose_gossip` | violated:OneFacade | ✗ OneFacade | 22 | trace 3 | 00s |
| `eg_relation` | violated:OneFacade | ✗ OneFacade | 262 | trace 5 | 00s |
| `eg_hash_gossip` | holds | ✓ holds | 405 | depth 9 | 00s |
| `eg_hash_churn` | violated:OneFacade | ✗ OneFacade | 70 | trace 4 | 00s |
| `eg_consensus` | holds | ✓ holds | 14545 | depth 10 | 01s |
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
| `we_cleanup` | violated:NoStaleAfterClose | ✗ NoStaleAfterClose | 13 | trace 3 | 00s |
| `we_am_tcp` | violated:NoJoinBoundary | ✗ NoJoinBoundary | 148 | trace 4 | 00s |

## Reading the results

- **Delivery.** Read literally, the message is not delivered almost
  surely. Nobody removes the hop, link and bridge layers, so nothing is
  delivered at all (`ch_peel_pub`,
  [`finding-layer-removal.md`](finding-layer-removal.md)). And one layer
  cannot be opened by whichever ingress or egress the message reaches, so
  only some messages get through (`ch_onion_literal`,
  [`finding-multi-recipient-onion.md`](finding-multi-recipient-onion.md)).
  With the layer-removal step and either completion of the onion, every
  message is delivered almost surely (`ch_live_*`).
- **Confidentiality.** With individual egress keys, no node outside O ever
  learns the payload, even with both ingress nodes compromised and every
  link observed (`ch_pub_*`, `ch_priv_node`). Using a private cluster's key
  for the egress layer lets a non-egress member read it (`ch_priv_cluster`);
  reading the key as making every member an egress lets a compromised
  member read messages that exit elsewhere (`ch_priv_cluster_all`) —
  [`finding-private-cluster-key.md`](finding-private-cluster-key.md). For
  the ingress layer alone the cluster key is safe (`ch_priv_ingress`).
- **Dispersion (CMP).** The premise that a compromised egress sees only the
  traffic exiting through it holds for both completions of the onion
  against CMP's adversary, compromised relays (`ch_disp_perpacket`,
  `ch_disp_visit`). With a global passive observer in a private cluster,
  KEM-DEM loses it (`ch_disp_obs`), and per-packet targeting keeps it
  (`ch_disp_perpacket`). The probabilities of CMP are outside TLC's scope;
  this is the qualitative condition they need. Checking it when the
  message has left is enough, because the adversary's knowledge only grows
  (`ch_know_monotone`).
- **Reachability.** Irreducibility of P_C is necessary (`ch_reducible`); in
  addition the client's choice of O must be reachable from I
  (`ch_reach_nobridge`,
  [`finding-egress-reachability.md`](finding-egress-reachability.md)).
- **Keys.** Per-entity rotation drops messages in flight unless the
  previous key is kept for a grace period (`ch_rotate_*`). For
  `GRACE` ∈ {0, 1}, the grace period is the forward-secrecy window of the
  payload against a later compromise of the exit node's KEM key (`ch_fs`,
  `ch_fs_window`, [`finding-key-rotation.md`](finding-key-rotation.md)). A
  member that leaves a private cluster reads its link layers until s_C is
  renewed (`ch_leave_pub`); renewing on departure closes it
  (`ch_leave_rekey`).
- **Egress sessions (DON).** Looking θ up and then inserting a façade, as
  DON writes it, gives a TCP session two sources even on a linearisable
  table (`eg_relation`), and so does a table kept by gossip
  (`eg_choose_gossip`, `eg_hash_churn`). One committed insert-if-absent
  fixes it (`eg_consensus`,
  [`finding-facade-consistency.md`](finding-facade-consistency.md)).
  Tables must survive the epoch boundary (`eg_epoch_*`,
  [`finding-epoch-tables.md`](finding-epoch-tables.md)). UDP entries must
  be refreshed on use and outlive the response delay (`eg_udp*`,
  [`finding-udp-expiry.md`](finding-udp-expiry.md)). The server sees
  several sources per UDP flow (`eg_udp_source`), which is not the
  "seamless" dispersion the article requires for address-bound protocols.
  Cleanup after FIN/RST holds (`eg_cleanup`).
- **The resolved protocol.** With every amendment on, while each node
  rotates at most once and one member (not the packet's own ingress,
  egress or holder) leaves:
  - the payload needs a compromised egress (`am_safety`, `am_bridge`);
  - exposure goes only through the exit node (`am_exposure`);
  - every message is delivered (`am_live`, in one private cluster);
  - a TCP session keeps one source across a join and an epoch boundary
    (`am_tcp`).

  Each amendment's rationale, alternatives and cost:
  [`resolutions.md`](resolutions.md).
- **Witnesses.** Each passing safety row is backed by a witness showing
  that the event it relies on occurs, in the row's own scenario or, for
  the dispersion and confidentiality rows, the base one. Liveness rows
  need none: they hold only if every behaviour delivers.

  | Passing rows | Backed by |
  |---|---|
  | `ch_pub_perpacket`, `ch_pub_kemdem`, `ch_priv_ingress` | `wc_bad_relays` (a compromised node handles the message) |
  | `ch_priv_node` | `wc_bridge` (the message reaches member 3 over the bridge) |
  | `ch_disp_perpacket`, `ch_disp_visit` | `wc_delivered` (the message exits) |
  | `ch_rotate_g1`, `ch_fs` | `wc_rotation`, `wc_late` |
  | `ch_leave_rekey` | `wc_leave` |
  | `ch_know_monotone` | `wc_rotation`, `wc_leave` |
  | `am_safety`, `am_exposure`, `am_live` | `wc_am` (a rotation and a departure in flight) |
  | `am_bridge` | `wc_am_bridge` (compromised member 3 handles the message) |
  | `eg_hash_gossip`, `eg_consensus` | `we_session`, `we_concurrent_open` |
  | `eg_epoch_amd` | `we_epoch` |
  | `eg_cleanup` | `we_cleanup` (a replica still holds θ after FIN/RST) |
  | `eg_udp` | `we_udp_resp` |
  | `am_tcp` | `we_am_tcp` (a join and a boundary inside a session) |

## Reproducing

`make quick` runs every row in about 4 minutes and ends with
`tools/check.py`, which exits non-zero if any verdict differs from its
expectation, if a row has no log, or if a log is stale: each log's first
line records the SHA-256 of the module, the configuration and the jar it
was run with. `make <row>` or `./run.sh <row>` runs one row. The
configurations are generated by `python3 tools/gen_models.py` from one
table; regenerate them rather than editing them, so rows stay comparable.
`WORKERS=auto make quick` is faster. Verdicts do not change, nor do the
state counts of rows that hold. A violated row stops wherever a worker
first meets the violation, so its count and trace may differ.
