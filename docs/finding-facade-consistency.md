# Finding: an eventually consistent façade table gives a TCP session two sources

Verdict: **Gap** in DON. Rows `eg_choose_gossip`, `eg_hash_churn`
(violated) and `eg_hash_gossip`, `eg_consensus` (hold) of
`spec/GsrpEgress.tla`.

## The published text

DON: "a cluster must maintain a single façade node for the duration of a
TCP session". When a member sends a segment of flow θ it "looks up
(θ, z⋆) ∈ T_C(t) from the cluster-wide shared state"; if absent it
selects z⋆ = F_C(θ) and inserts it. The cluster state is RSDP's, which is
eventually consistent: replicas converge by gossip, and two members may
look θ up before either insert has reached the other.

## Counterexamples

`eg_choose_gossip` (F_C any member, gossip). Trace
`traces/eg_choose_gossip.trace.txt`:

| State | Action | view | sent |
|---|---|---|---|
| 1 | Init | ⟨0, 0, 0, 0⟩ | {} |
| 2 | SendSeg(1) | ⟨1, 0, 0, 0⟩ | {(1, 1)} |
| 3 | SendSeg(2) | ⟨1, 2, 0, 0⟩ | {(1, 1), (2, 1)} |

Member 2 sends before the replicas merge and selects a second façade: the
server sees two sources for one connection and resets it.

`eg_hash_churn` (F_C a function of the membership view). Trace
`traces/eg_hash_churn.trace.txt`: member 1 selects F({1,2,3}) = 3; node 4
joins; node 4 selects F({1,2,3,4}) = 4 — sources (3, 1) and (4, 1). Any
F_C that depends on the membership view changes under some membership
change, so the same holds for every such function. Without churn the
function gives one façade (`eg_hash_gossip`, holds).

## Proposed amendment

> Façade selection for a new flow goes through the cluster's consensus
> (private clusters already run one for s_C); members use the agreed entry.

With selection through consensus, `OneFacade` and `ReturnPath` hold even
with a freely chosen façade and churn (`eg_consensus`). Witnesses
`we_session` and `we_concurrent_open` show that sessions span several
senders and that concurrent opens occur.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G7.
