# Group State Routing Protocol (Mycelia) — TLA⁺ Specifications

Mechanised verification, with the TLC model checker, of the qualitative
claims of M. Kotov, S. Toliupa, *Group State Routing Protocol (Mycelia): a
new model for distributed network coordination*, Science-based
technologies 4(68), 2025 ([GSRP]).

The article is checked as published. Where a claim fails, the
counterexample and a proposed amendment are documented, and the amendment
is checked in the same model. Where the text admits several readings, each
is a switch, and the literal one is a row of its own.
[`docs/resolutions.md`](docs/resolutions.md) collects the amendments into
the resolved protocol and checks them together. The article's
headings are cited as PRA (*Path routing architecture*), DON (*Dispersion
of the outer nodes*) and CMP (*Comparison with existing protocols*).

## Summary

- **48 TLC runs, all with their expected verdict** (21 hold; 27 are
  violated as intended: mutations, published readings found wanting,
  characterisations and witnesses). `make quick` reproduces them in about
  4 minutes.
- **What holds.**
  - With individual egress keys, no node outside the egress set learns
    the payload, even with both ingress nodes compromised and every link
    observed.
  - Every message is delivered almost surely once two things are in
    place: per-hop layers are removed, and each packet targets one ingress
    and one egress (G1, G2). This also needs an irreducible kernel and a
    reachable egress.
  - Keys are forward secure once the grace period has passed.
  - FIN/RST cleans up the session tables.
- **What does not, as published.**
  - One **Defect**: sealing the egress layer under a private cluster's
    key lets a member that is not an egress node read the payload.
  - Seven **Gaps**:
    - read literally, no message is delivered, because nobody removes the
      per-hop layers, and because one onion layer cannot be opened by
      whichever ingress or egress the message reaches;
    - the choice of ingress and egress sets does not ensure the egress is
      reachable;
    - key rotation drops messages in flight;
    - an eventually consistent façade table gives one TCP session two
      sources;
    - per-epoch tables break sessions at the boundary;
    - UDP entries expire while the flow is active.
  - Characterisations:
    - KEM-DEM breaks the dispersion premise of the comparison (CMP), and
      per-packet targeting keeps it;
    - the grace period is the forward-secrecy window;
    - a departed member reads link layers until the cluster secret is
      renewed;
    - the server sees several sources per UDP flow.
- **Resolved.** [`docs/resolutions.md`](docs/resolutions.md) gives each
  finding an amendment (G1–G10). With all of them on, while nodes rotate
  keys and members leave mid-flight:
  - the payload needs a compromised egress;
  - exposure goes only through the exit node;
  - every message is delivered;
  - a TCP session keeps one source across churn and an epoch boundary.

  Rows: `am_safety`, `am_exposure`, `am_bridge`, `am_live`, `am_tcp`.
- **Out of scope.** The probabilities of CMP: TLC has none. The model
  checks the qualitative conditions they rest on.

## Claims

| Claim | Source | Rows | Verdict |
|---|---|---|---|
| The message is delivered | PRA | `ch_peel_pub`, `ch_onion_literal` / `ch_live_perpacket`, `ch_live_kemdem` | **Gap** ×2; holds with layer removal and a multi-recipient completion |
| No relay sees the payload before the end of the channel | PRA | `ch_pub_perpacket`, `ch_pub_kemdem`, `ch_priv_node`, `ch_priv_ingress` / `ch_priv_cluster` | Holds with individual egress keys (the cluster key may seal the ingress layer); **Defect** with the private-cluster key for the egress layer |
| A compromised egress sees only the traffic exiting through it (premise of Φ_N) | CMP | `ch_disp_perpacket` / `ch_disp_visit`, `ch_disp_obs` | Characterisation: holds for per-packet targeting, not for KEM-DEM |
| The walk reaches an egress almost surely | PRA | `ch_reach_bridge` / `ch_reach_nobridge`, `ch_reducible` | **Gap** in the choice of O; irreducibility necessary |
| Delivery across per-entity epochs | PRA | `ch_rotate_g0` / `ch_rotate_g1` | **Gap**; holds with a grace period |
| Keys are forward secure | PRA | `ch_fs` / `ch_fs_window` | Holds after the grace period; the window equals it |
| A departed member reads no later traffic | not claimed | `ch_leave_pub` / `ch_leave_rekey` | Characterisation: only with rekey on departure |
| One façade per TCP session | DON | `eg_choose_gossip`, `eg_hash_churn` / `eg_hash_gossip`, `eg_consensus` | **Gap**; holds with selection through consensus |
| Sessions survive epochs | DON | `eg_epoch_pub` / `eg_epoch_amd` | **Gap**; holds with carried tables |
| UDP responses return | DON | `eg_udp_pub`, `eg_udp_tight` / `eg_udp` | **Gap**; holds with refresh and τ_exp ≥ RTT |
| Dispersion is seamless for the recipient | DON | `eg_udp_source` | Characterisation: the server sees several sources per UDP flow |
| Entries are cleaned up after FIN/RST | DON | `eg_cleanup` | Holds |
| The resolved protocol, every amendment together | [`docs/resolutions.md`](docs/resolutions.md) | `am_safety`, `am_exposure`, `am_bridge`, `am_live`, `am_tcp` | Holds |

Out of scope, because TLC has no probabilities: the correlation
probabilities of CMP (f², Nym's bound, E[Φ_N] = β, β^{n_O}, the
Kullback–Leibler tail bound), convergence to π_C, latency. The model
checks the qualitative conditions they rest on (see `docs/model.md`).

## Documentation

| Document | Content |
|---|---|
| [`docs/model.md`](docs/model.md) | what the modules model and abstract, readings, adversary, properties |
| [`docs/results.md`](docs/results.md) | every row's verdict and numbers, and how to read them |
| [`docs/finding-layer-removal.md`](docs/finding-layer-removal.md) | nobody removes the hop, link and bridge layers |
| [`docs/finding-multi-recipient-onion.md`](docs/finding-multi-recipient-onion.md) | one onion layer for a set of nodes; two completions and the dispersion premise |
| [`docs/finding-private-cluster-key.md`](docs/finding-private-cluster-key.md) | the cluster key exposes the payload inside the egress cluster |
| [`docs/finding-egress-reachability.md`](docs/finding-egress-reachability.md) | the choice of I and O does not ensure reachability |
| [`docs/finding-key-rotation.md`](docs/finding-key-rotation.md) | rotation drops messages in flight; the forward-secrecy window |
| [`docs/finding-facade-consistency.md`](docs/finding-facade-consistency.md) | an eventually consistent façade table splits TCP sessions |
| [`docs/finding-epoch-tables.md`](docs/finding-epoch-tables.md) | per-epoch tables break sessions at the boundary |
| [`docs/finding-udp-expiry.md`](docs/finding-udp-expiry.md) | UDP entries expire under active flows |
| [`docs/resolutions.md`](docs/resolutions.md) | every finding's resolution: the amended rule, alternatives, cost, checks; the resolved protocol |

## Files

| Path | Content |
|---|---|
| `spec/GsrpChannel.tla` | one message from client to server: onion, walk, symbolic attacker knowledge, key epochs |
| `spec/GsrpEgress.tla` | egress sessions: TCP façade table, UDP tables |
| `tools/gen_models.py` | the row table: generates `models/*.cfg`, `models/expect.tsv`, `models/rows.mk` |
| `tools/check.py` | compares every log's verdict with its expectation; `--md` prints the results table |
| `tools/trace.py` | copies a counterexample from a log to `traces/` |
| `models/`, `logs/`, `traces/` | configurations, TLC output of the reported runs, cited counterexamples |
| `Makefile`, `run.sh` | one target per row, `quick`, `all`; one row outside make |

## Running

Requires Java 11 or later, GNU make and Python 3. The Makefile downloads
TLC (`tla2tools.jar`, release v1.7.4, TLC 2.19) and checks its SHA-256.

```bash
make quick                 # every row, about 4 min, then the verdict check
make ch_priv_cluster       # one row
./run.sh eg_hash_churn     # one row outside make
python3 tools/check.py     # verdicts of the existing logs
```

Runs use one worker so that counterexamples are shortest and the numbers in
`docs/results.md` reproduce (`WORKERS=auto` overrides).

## Citing

Cite the tag `v1`, not `main`.
