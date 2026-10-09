# Finding: nobody removes the hop, link and bridge layers

Verdict: **Gap** in PRA. Rows `ch_peel_pub` (violated) and
`ch_live_perpacket`, `ch_live_kemdem` (hold) of `spec/GsrpChannel.tla`.

## The published text

PRA defines the intra-cluster propagation operator
Φ^intra_{u→v}(M) = Enc_{k^link_(u,v)}(AD, Enc_{k^hop_u}(AD ‖ u ‖ v, M)) and
the walk M_{τ+1} = Φ^intra_{S_τ→S_{τ+1}}(M_τ); between clusters
M_{τ+1} = Enc_{k^bridge}(AD, M_τ). At the egress y,
M_{τ+1} = Dec_{k^eg_y}(AD, M_τ). No step removes a link, hop or bridge
layer, so literally every hop adds layers, and the egress applies its key
to a ciphertext sealed under a link key.

## Counterexample

`ch_peel_pub` (`PEEL = "published"`, scenario `pub`, per-packet onion with
ingress 1 and egress 3). Full trace: `traces/ch_peel_pub.trace.txt`.

| State | Action | stage | pos | Comment |
|---|---|---|---|---|
| 1 | Init | client | — | onion built for ingress 1, egress 3 |
| 2 | Dispatch | ingress | 1 | |
| 3 | Ingress | walk | 1 | 1 removes the ingress layer |
| 4 | Move | walk | 3 | 3 holds Enc(link(1,3), (H_eg, Q)) |
| 5 | Exit | dropped | 3 | the top term is a link-layer ciphertext, not (H_eg, Q): decryption fails |

`Delivered` is violated: the behaviour stutters in `dropped` forever.

## Proposed amendment

> On receipt over a link (u, v), v removes the link layer, the hop layer of
> u and, over a bridge, the bridge layer, before it processes or forwards
> the message.

In a private cluster v derives both keys from s_C; in a public cluster the
link key is the one negotiated with u. With the step (`PEEL = "amended"`)
every message is delivered (`ch_live_perpacket`, `ch_live_kemdem`) and the
payload stays hidden from every non-egress node (`ch_pub_perpacket`,
`ch_pub_kemdem`).

Because every member of a private cluster derives every hop and link key,
these layers protect only against non-members; this is what makes
`ch_disp_obs` possible ([`finding-multi-recipient-onion.md`](finding-multi-recipient-onion.md)).

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G1.
