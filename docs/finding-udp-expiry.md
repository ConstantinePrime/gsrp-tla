# Finding: UDP entries expire under active flows

Verdict: **Gap** in DON, plus an implicit condition. Rows `eg_udp_pub`,
`eg_udp_tight` (violated) and `eg_udp` (holds) of `spec/GsrpEgress.tla`.
A second **Gap**, the server seeing several sources per flow, is row
`eg_udp_source`.

## The published text

DON: "If v must send a UDP packet for flow θ to destination d and no
mapping exists for (θ, d), then it should choose a ∈ A_v, τ_exp and insert
them"; stale entries are dropped by U_v(t) ← {… : t ≤ τ_exp}. τ_exp is set
when the entry is created, and no rule refreshes it on use. The purpose
DON gives, "to drop stale unused records", suggests that use should keep
an entry alive; the stated rule does not do so, and the amendment makes
it do so.

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

`UdpReturn` is violated although τ_exp covers the response delay: a flow
that lives longer than τ_exp can lose responses.

## Proposed amendment

> τ_exp is refreshed on every packet of the flow (as NAT tables do), and
> τ_exp ≥ RTT.

With refresh, `UdpReturn` holds (`eg_udp`); with τ_exp < RTT it fails even
with refresh (`eg_udp_tight`), so the second condition is necessary too.

## Gap: the server sees several sources

`eg_udp_source`: packets of one UDP flow leave through several egress
nodes, so the server sees several source addresses for one flow. The
article requires that "the dispersion of the traffic should appear
seamless for the initiator and recipient", and DON that "the retranslation
must work seamlessly for the application server, and the protocol should
not expect any additional integration from the outside perspective". This
holds only for UDP protocols that do not bind a session to the client's
address. The amendment ([`resolutions.md`](resolutions.md), G10) pins the
flows of protocols that do, such as QUIC and DTLS, to a façade like a TCP
session. That reuses the façade discipline the TCP rows check; the
expiry-based cleanup of a pinned UDP flow is argued, not checked.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G9.
