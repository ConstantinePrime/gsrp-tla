# Finding: per-entity key rotation drops messages in flight

Verdict: **Gap** in PRA, and a measured trade-off with forward secrecy.
Rows `ch_rotate_g0` (violated), `ch_rotate_g1` (holds), `ch_fs` (holds),
`ch_fs_window` (violated) of `spec/GsrpChannel.tla`.

## The published text

PRA: epochs are "specific to the entity in context, be it user, cluster or
relay node"; each node keeps per-epoch KEM key pairs; the client takes
public keys from the map RSDP provides; derived keys are "forward secure".
Nothing says how long a node keeps the secret key of a past epoch, or how
a message sealed under it is handled after the node rotates.

## Counterexample

`ch_rotate_g0` (`ALLOW_ROTATE`, `GRACE = 0`: a rotated node keeps only the
new key). Trace `traces/ch_rotate_g0.trace.txt`; the essential steps:

| Step | Action | Comment |
|---|---|---|
| 1 | Init | onion sealed under the epoch-0 public key of ingress 1 |
| 3 | Dispatch | the message reaches ingress 1 |
| 6 | Rotate(1) | node 1 moves to epoch 1 and erases its epoch-0 secret key |
| 7 | Ingress | Decaps fails: the message is dropped |

(The trace also rotates nodes 2–4; those steps do not matter.)
`Delivered` is violated.

## Proposed amendment

> A node keeps the secret key of the previous epoch for one epoch after
> rotating (and H names the epoch of each encapsulation).

With `GRACE = 1`, and at most one rotation per node while a message is in
flight, every message is delivered (`ch_rotate_g1`).

## The trade-off

The grace period is exactly the forward-secrecy window:

- `ch_fs` (`GRACE = 0`): the observer records all traffic, the message
  exits through node 3, node 3 rotates and is then compromised. The
  payload cannot be recovered: `ForwardSecrecy` holds.
- `ch_fs_window` (`GRACE = 1`): the same, but node 3 still holds its
  epoch-0 key, and the recorded traffic yields the payload (trace
  `traces/ch_fs_window.trace.txt`, 7 states).

Witnesses `wc_rotation` and `wc_late` show that a rotation during flight
and the late compromise both occur.

The amendment in the context of the resolved protocol — rationale,
alternatives, cost and the rows that check it with every other
resolution on: [`resolutions.md`](resolutions.md), G5.
