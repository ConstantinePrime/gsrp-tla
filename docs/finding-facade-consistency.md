# Finding: the façade table gives a TCP session two sources

Verdict: **Gap** in DON. Rows `eg_relation`, `eg_choose_gossip`,
`eg_hash_churn` (violated) and `eg_hash_gossip`, `eg_consensus` (hold) of
`spec/GsrpEgress.tla`.

## The published text

DON: "a cluster must maintain a single façade node for the duration of a
TCP session". When a member sends a segment of flow θ it "looks up
(θ, z⋆) ∈ T_C(t) from the cluster-wide shared state"; if absent it
selects z⋆ = F_C(θ) and inserts it. T_C(t) ⊆ Θ × C is a relation, kept
in "the cluster-wide shared state", which PRA maintains through RSDP; for
private clusters the article calls that process "BFT-compliant
consensus". How T_C is replicated is not said, so the model takes two
readings: a linearisable table, and replicas merged by gossip.

## Counterexamples

**Linearisable table, lookup then insert** (`eg_relation`, F_C any
member). DON's steps 1 and 2 are a lookup followed by an insert. Even when
every operation on T_C is linearisable, as consensus makes it, two
members can both find θ absent before either inserts. Trace
`traces/eg_relation.trace.txt`:

| State | Action | pending choice | T_C | sent |
|---|---|---|---|---|
| 1 | Init | ⟨0, 0, 0, 0⟩ | {} | {} |
| 2 | LookupRel(1) | ⟨1, 0, 0, 0⟩ | {} | {} |
| 3 | LookupRel(2) | ⟨1, 2, 0, 0⟩ | {} | {} |
| 4 | SendSeg(1) | ⟨0, 2, 0, 0⟩ | {(θ, 1)} | {(1, 1)} |
| 5 | SendSeg(2) | ⟨0, 0, 0, 0⟩ | {(θ, 1), (θ, 2)} | {(1, 1), (2, 1)} |

T_C ends with two façades for θ, and the server sees two sources for one
connection. So the gap does not depend on how weakly T_C is replicated.

**Replicas merged by gossip.**

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

> Façade selection for a new flow is one atomic insert-if-absent of
> (θ, z⋆, a⋆), committed through the cluster's consensus before the first
> segment leaves; members use only the committed entry.

With selection as one committed insert-if-absent, `OneFacade` and
`ReturnPath` hold even with a freely chosen façade and churn
(`eg_consensus`). The model represents the commit as an atomic register
written in the sending step. That shows what consensus must provide, a
linearisable insert-if-absent completed before the segment is sent; it
does not check a consensus protocol (RSDP's own properties are the
subject of its own artifact). Witnesses
`we_session` and `we_concurrent_open` show that sessions span several
senders and that concurrent opens occur.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G7.
