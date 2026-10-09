# Finding: per-epoch façade tables break sessions at the epoch boundary

Verdict: **Gap** in DON. Rows `eg_epoch_pub` (violated) and `eg_epoch_amd`
(holds) of `spec/GsrpEgress.tla`.

## The published text

DON indexes the session tables by epoch: T_C(t), S_{z⋆}(t)[θ] = a⋆,
R_{z⋆}(t)[θ] = ρ_θ. Entries are removed on FIN/RST or expiry; nothing
says they survive the move from epoch t to t + 1. Read as written, the
tables of epoch t + 1 start empty.

The text also points the other way: removal "at t > τ_exp", and the UDP
rule U_v(t) ← {… : t ≤ τ_exp}, only make sense if entries persist while t
advances. The two readings are an ambiguity, and the literal one is the
row of its own; the amendment states the reading under which sessions
work.

## Counterexample

`eg_epoch_pub` (`EPOCHS`, `CARRY = "published"`). Trace
`traces/eg_epoch_pub.trace.txt`:

| State | Action | epoch | S (ports) | sent |
|---|---|---|---|---|
| 1 | Init | 0 | ⟨0, 0, 0, 0⟩ | {} |
| 2 | SendSeg(1) | 0 | ⟨0, 0, 1, 0⟩ | {(3, 1)} |
| 3 | Boundary | 1 | ⟨0, 0, 0, 0⟩ | {(3, 1)} |
| 4 | SendSeg(1) | 1 | ⟨0, 0, 2, 0⟩ | {(3, 1), (3, 2)} |

The façade is the same node, but it allocates a fresh port after the
reset: the server sees a new source mid-connection. `OneFacade` is
violated.

## Proposed amendment

> Session entries are carried across epochs until FIN/RST or expiry.

With carried tables `OneFacade` and `ReturnPath` hold (`eg_epoch_amd`);
witness `we_epoch` shows a boundary falling inside a session.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G8.
