# Finding: the choice of I and O does not ensure the egress is reachable

Verdict: **Gap** in PRA; the irreducibility assumption is confirmed
necessary. Rows `ch_reach_nobridge`, `ch_reducible` (violated) and
`ch_reach_bridge` (holds) of `spec/GsrpChannel.tla`.

## The published text

PRA requires each P_C to be aperiodic and irreducible on its support, so
the walk inside a cluster reaches every member. Between clusters the walk
follows Q_{i→j}, but "the edges between the clusters may not be set up
initially, there is no requirement for clusters to maintain stable
connections". The client chooses I and O with |I|, |O| ≥ k; no condition
relates O to the clusters reachable from I.

## Counterexample

Scenario `nobridge`: C1 = {1, 2} holds I, C2 = {3, 4, 5} holds O, and no
inter-cluster link exists. Trace `traces/ch_reach_nobridge.trace.txt`:

| State | Action | stage | pos |
|---|---|---|---|
| 1 | Init | client | — |
| 2 | Dispatch | ingress | 1 |
| 3 | Ingress | walk | 1 |

In state 3 no egress can be reached from node 1: `EgressReachable` is
violated, which for a finite chain means the message is delivered with
probability 0.

`ch_reducible` removes irreducibility instead: the support of P_C splits
into {1, 2} and {3, 4}, and the walk starting at an ingress never reaches
an egress. The article's irreducibility assumption is therefore necessary.

## Proposed amendment

> The client chooses O among nodes reachable from I's cluster over the
> support of the inter-cluster kernels (or establishes the bridges before
> dispatch).

With a bridge 2 → 3, `EgressReachable` and `Delivered` hold
(`ch_reach_bridge`); witness `wc_bridge` shows the message crossing it.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G4.
