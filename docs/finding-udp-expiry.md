# Finding: UDP entries expire under active flows

Verdict: **Gap** in DON, plus an implicit condition. Rows `eg_udp_pub`,
`eg_udp_tight` (violated) and `eg_udp` (holds) of `spec/GsrpEgress.tla`;
characterisation `eg_udp_source`.

## The published text

DON: "If v must send a UDP packet for flow θ to destination d and no
mapping exists for (θ, d), then it should choose a ∈ A_v, τ_exp and insert
them"; stale entries are dropped by U_v(t) ← {… : t ≤ τ_exp}. τ_exp is set
when the entry is created and never refreshed on use.

## Counterexample

`eg_udp_pub` (`REFRESH = "published"`, τ_exp = RTT = 2). Trace
`traces/eg_udp_pub.trace.txt`:

| State | Action | entry of node 1 (port, age) | responses in flight | Comment |
|---|---|---|---|---|
| 1 | Init | — | — | |
| 2 | UdpSend(1) | (1, 0) | r₁ | entry created |
| 3 | Tick | (1, 1) | r₁ | |
| 4 | UdpSend(1) | (1, 1) | r₁, r₂ | entry reused, not refreshed |
| 5 | Tick | (1, 2) | r₁, r₂ | |
| 6 | Deliver r₁ | (1, 2) | r₂ | returned |
| 7 | Tick | expired | r₂ | age 3 > τ_exp |
| 8 | Deliver r₂ | — | — | no entry: the response is lost |

`UdpReturn` is violated although τ_exp covers the response delay: any flow
that lives longer than τ_exp loses responses.

## Proposed amendment

> τ_exp is refreshed on every packet of the flow (as NAT tables do), and
> τ_exp ≥ RTT.

With refresh, `UdpReturn` holds (`eg_udp`); with τ_exp < RTT it fails even
with refresh (`eg_udp_tight`), so the second condition is necessary too.

## Characterisation: the server sees several sources

`eg_udp_source`: packets of one UDP flow leave through several egress
nodes, so the server sees several source addresses for one flow. DON's
"seamless for the initiator and recipient" therefore holds only for UDP
protocols that do not bind a session to the client's address.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G9.
