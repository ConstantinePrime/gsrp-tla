# Group State Routing Protocol (Mycelia): verification with TLA⁺

This repository uses a computer to check whether the Group State Routing
Protocol (GSRP, also called Mycelia) behaves as its article claims. GSRP
carries a client's traffic to a server through groups of relay nodes,
spreading the traffic over many exit points so that no single compromised
node sees much of it. The repository was built for a PhD dissertation. It
contains:

- a precise model of the protocol, written in TLA⁺;
- 55 checks run with the TLC model checker, each with the result it was
  expected to give and the result it gave;
- for every claim that does not hold as published, a concrete example of
  what goes wrong, a proposed fix, and a check of the fix;
- everything needed to run the checks again and get the same numbers.

The article: M. Kotov, S. Toliupa, *Group State Routing Protocol (Mycelia):
a new model for distributed network coordination*, Science-based
technologies 4(68), 2025 ([GSRP]). It has no numbered sections, so this
repository refers to its headings:

- **PRA**: *Path routing architecture*, how a message travels;
- **DON**: *Dispersion of the outer nodes*, how traffic leaves the
  network;
- **CMP**: *Comparison with existing protocols*, the probabilistic
  security analysis.

## Contents

1. [The results at a glance](#1-the-results-at-a-glance)
2. [Background](#2-background): the protocol, model checking, the kinds
   of check
3. [What was checked, and what came out](#3-what-was-checked-and-what-came-out)
4. [What these checks do not cover](#4-what-these-checks-do-not-cover)
5. [Running the checks yourself](#5-running-the-checks-yourself)
6. [Repository layout and further reading](#6-repository-layout-and-further-reading)
7. [Citing](#7-citing)

## 1. The results at a glance

All 55 checks gave the result they were expected to give.

**What holds**

- **Confidentiality.** When the egress layer is sealed with each exit
  node's own key, no node other than an exit node ever learns the message.
  This holds even when both entry nodes are compromised and an observer
  records every link.
- **Delivery.** Once findings 1 and 2 below are fixed, every message is
  delivered with probability 1, provided the client picks exit nodes the
  walk can reach (finding 4).
- **Forward secrecy.** After the key-rotation grace period has passed, a
  later theft of the exit node's key does not reveal past messages.
- **Clean-up.** A TCP session's table entries are removed after it closes.

**What does not hold as published: nine findings**

| # | Finding | Kind | In one sentence |
|---|---|---|---|
| 1 | Layer removal | Gap | No step removes the encryption added at each hop, so a message is never delivered. |
| 2 | One layer for many nodes | Gap | The client's onion layer can be opened by only one node of the entry or exit set, but the message may reach another one, which drops it. |
| 3 | Private-cluster key | Defect | Sealing the message for a whole private cluster lets a relay that is not an exit node read it. |
| 4 | Reachability | Gap | Nothing makes sure the exit nodes the client picks can be reached from its entry nodes. |
| 5 | Key rotation | Gap | A node that changes its key while a message is on its way drops that message. |
| 6 | Façade table | Gap | One TCP session can end up with two façade nodes, so the server sees two sources and resets the connection. |
| 7 | Tables across epochs | Gap | Read literally, session tables are emptied at each epoch, which breaks sessions that span the boundary. |
| 8 | UDP expiry | Gap | A UDP table entry expires while the flow is still active, and responses are lost. |
| 9 | Several UDP sources | Gap | The server sees one UDP flow coming from several addresses, which is not "seamless" for protocols that bind a session to an address. |

A **Defect** fails under every reasonable reading of the article. A **Gap**
fails when the text is read literally, but works once a missing rule is
added. That missing rule is the proposed fix.

Three further observations concern things the article does not claim:

- **Two ways to complete the onion** (finding 2) both protect the
  dispersion premise of CMP against compromised relays. Only one of them
  also protects it against an observer of every link.
- **Rotation grace period.** How long a node keeps its old key is exactly
  how long a later key theft can still expose old messages.
- **Departed members.** A member that leaves a private cluster can read
  link encryption until the cluster's shared secret is renewed.

**Every finding has a fix, and the fixes were checked together.**
[`docs/resolutions.md`](docs/resolutions.md) gives each fix, why it was
chosen over the alternatives, and what it costs. With all fixes in place,
and while nodes change keys and a member leaves during a message's
journey:

- the message is read only if an exit node is compromised;
- a compromised exit node sees only the messages that leave through it;
- every message is delivered;
- a TCP session keeps one source across a membership change and an epoch
  boundary.

One fix, for UDP flows bound to an address (finding 9), is argued rather
than checked.

## 2. Background

### 2.1 The protocol in brief

**Relays and clusters.** Relay nodes are grouped into **clusters**. A
cluster is either:

- **public**: neighbours agree a separate key for each link;
- **private**: members run a consensus protocol to hold one shared
  secret, from which each member computes the keys for every link and
  hop in the cluster.

Inside a cluster, a message moves by a **random walk**. At each step the
node holding it passes it to a neighbour chosen at random, following a
transition kernel that the article requires to be irreducible and
aperiodic. To move between clusters, a node hands the message across a
**bridge** to a node of another cluster.

**Sending a message.** The client:

1. picks a set of **entry (ingress) nodes** and a set of **exit (egress)
   nodes**, at least k of each, so that no single node is predictable;
2. encrypts the message for the exit nodes (the *egress layer*), then
   wraps that for the entry nodes (the *ingress layer*);
3. sends this *onion* to an entry node.

The entry node removes the ingress layer. The message then walks through
the network, wrapped in an extra layer of link encryption on every hop.
When it reaches an exit node, that node removes the egress layer and
forwards the plain message to the server.

**Keys** change per **epoch**, and each node, user and cluster has its
own epochs.

**Leaving the network** (DON). Because different packets leave through
different exit nodes, the server would see one conversation coming from
several addresses. The article handles the two transport protocols
differently:

- **UDP.** Each exit node keeps a table that maps a flow to an external
  port, so responses can be routed back. Entries expire after a time
  τ_exp.
- **TCP.** A connection must appear to come from one address. The cluster
  keeps a table that names one **façade** node per connection. Any member
  that sends a packet of that connection rewrites its source address to
  the façade's.

**The security argument** (CMP) compares GSRP with Tor, I2P and Nym. It
assumes that a compromised exit node sees exactly the share of the traffic
that leaves through it, and computes probabilities of exposure from
there.

### 2.2 Model checking with TLA⁺ and TLC

**TLA⁺** is a language for describing a system as a state machine: a set
of variables, the states the system can start in, and the steps that can
change them.

**TLC**, the model checker, takes a small, concrete instance of such a
model and visits **every** state the system can reach. It checks the
properties you give it in each of those states. Two kinds of property are
used here:

- an **invariant** must be true in every reachable state, for example "no
  relay that is not an exit node knows the message";
- a **liveness property** says that something eventually happens, for
  example "the message is delivered".

When a property fails, TLC prints a **counterexample**: the exact sequence
of steps that leads to the failure. You can follow it one step at a time.

**Two things need explaining for this protocol.**

- **Cryptography is treated as perfect** (the Dolev–Yao model). Messages
  are symbolic terms. A node or attacker can open an encrypted term only
  if it holds the key, and the model computes everything an attacker can
  learn from what it has seen and the keys it holds.
- **TLC has no probabilities**, yet the article claims delivery "almost
  surely", meaning with probability 1. For a random walk on finitely many
  states, delivery with probability 1 is equivalent to delivery in every
  run where any step that keeps being possible eventually happens (called
  *strong fairness*; Baier & Katoen, *Principles of Model Checking*,
  ch. 10). The delivery checks use that equivalence. The probability
  formulas of CMP themselves are outside what TLC can check.

TLC checks small instances exhaustively. It does not prove that a property
holds for networks of every size. "Holds" therefore means "holds in every
case of the stated size", and section 4 lists the sizes.

### 2.3 The two models

- **`spec/GsrpChannel.tla`, the channel model.** It follows one message
  from the client to the server: onion construction, the entry node, the
  random walk, bridges, the exit node, key rotation, a member leaving,
  and an attacker.
  - The **attacker** is a set of compromised nodes. It knows every key
    they have ever held and everything they have received.
  - Optionally, a **global observer** also records every message on every
    link.
  - In one setting the exit node is compromised **later**, after it has
    changed its key.
- **`spec/GsrpEgress.tla`, the egress model.** It follows one flow
  leaving one cluster:
  - the TCP façade table, kept in one of three ways (section 3.6);
  - a node joining the cluster;
  - an epoch boundary;
  - the UDP tables, with expiry and a response delay.

The channel model runs on six small example networks:

| Name | Clusters | Entry nodes | Exit nodes | Walk |
|---|---|---|---|---|
| `pub` | one public cluster of nodes 1–4 | 1, 2 | 3, 4 | any node to any node |
| `priv` | the same cluster, private | 1, 2 | 3, 4 | as `pub` |
| `bridge` | public cluster {1, 2}, private cluster {3, 4, 5} | 1, 2 | 4, 5 | inside each cluster, plus a bridge 2 → 3 |
| `bridge_all` | as `bridge` | 1, 2 | 3, 4, 5 | as `bridge` |
| `nobridge` | as `bridge` | 1, 2 | 4, 5 | no bridge |
| `reducible` | as `pub` | 1, 2 | 3, 4 | {1, 2} and {3, 4} not connected |

### 2.4 Checks, and the four kinds of check

A **check** is one TLC run: one model, one set of settings, the properties
to test, and the result expected. The other documents call a check a
*row*, because each is one row of the table in
[`tools/gen_models.py`](tools/gen_models.py). That table generates the
configuration files in `models/` and the list of expected results in
`models/expect.tsv`. [`tools/check.py`](tools/check.py) compares each
TLC output with its expected result.

| Kind | What it does | Expected result |
|---|---|---|
| **Claim check** | Tests a claim of the article as published, or under one reading of an ambiguous passage. | As claimed, or fails where a finding was made. |
| **Mutation check** | Removes a condition the article relies on, to show the condition matters. | Fails. |
| **Fix check** | Switches the proposed fixes on. | Holds. |
| **Witness check** | Asserts that some interesting event never happens, such as "a compromised node never handles the message". | Fails, which proves the event does happen in that setting. This guards against a check that passes only because nothing interesting ever happens. |

Check names start with the area they belong to:

- `ch_` for the channel;
- `eg_` for the egress side;
- `am_` for the fixes checked all together;
- `wc_` and `we_` for witnesses.

Of the 55 checks, 23 are expected to hold and 32 to fail:

- 12 published readings that fail (the findings);
- 5 mutations and measurements;
- 15 witnesses.

All 55 gave their expected result.

## 3. What was checked, and what came out

Each subsection gives the article's claim, explains how it was checked,
and gives the result. The check names are listed so you can find their
output in `logs/` and their numbers in [`docs/results.md`](docs/results.md).

### 3.1 Delivery (PRA) — Findings 1 and 2, Gaps

**The claim.** The message travels from the client through the network
and reaches the server.

**Finding 1: nobody removes the per-hop layers.** On every hop the article
wraps the message in link encryption, and in a private cluster also in a
per-hop layer. Between clusters it adds a bridge layer. No step takes
these layers off. Read literally, they pile up, and the exit node tries
its key on a message that is still wrapped in link encryption:

| Step | What happens |
|---|---|
| 1 | the client builds the onion for entry node 1 and exit node 3 |
| 2 | the client sends it to node 1 |
| 3 | node 1 removes the ingress layer |
| 4 | node 1 passes it to node 3, adding a link layer |
| 5 | node 3 is the exit, but the outer layer is link encryption, not the egress layer; it cannot decrypt, and drops the message |

**Fix 1.** A node that receives a message removes the link layer, the
per-hop layer and any bridge layer before doing anything else. The
message underneath is unchanged along the whole walk; only its per-hop
wrapping changes.

**Finding 2: one layer, many possible recipients.** The client encrypts
the ingress layer "using respective public keys of chosen nodes", one
for each of the entry nodes. Keys made separately are different keys, so
a layer encrypted once can be opened with only one of them. Yet the
client picks the entry node after building the onion, and the walk may
reach either exit node first:

| Step | What happens |
|---|---|
| 1 | the ingress layer is sealed for node 1 |
| 2 | the client happens to send the message to node 2 |
| 3 | node 2's key does not open the layer; node 2 drops the message |

Some messages still get through, by luck, so delivery is not certain.

**Fix 2.** For every packet, the client picks **one** entry node and
**one** exit node, and seals the layers for those two only. The walk
continues until it reaches that exit node; other exit nodes pass the
packet on like any relay. This is *per-packet targeting*.

The other natural completion is KEM-DEM: one key per layer, encrypted
separately for every node of the set. It also delivers, and it was
checked too. The choice between them is explained in section 3.3.

| Check | What it tests | Result |
|---|---|---|
| `ch_peel_pub` | delivery, with layers never removed | fails, as expected: nothing is delivered |
| `ch_onion_literal` | delivery, with one layer for a set of nodes | fails, as expected: delivery is not certain |
| `ch_live_perpacket` | delivery with fixes 1 and 2 | holds |
| `ch_live_kemdem` | delivery with fix 1 and KEM-DEM | holds |
| `wc_delivered` | witness: a message does reach the server | occurs |

### 3.2 Confidentiality (PRA) — Finding 3, Defect

**The claim.** "This guarantees that no intermediary cluster or relay node
can see the payload before it reaches the end of the secure channel." The
article also allows a shortcut: "With private structures a client can use
the cluster public key instead of individual keys for every node."

**With individual keys, the claim holds.** No node outside the exit set
learns the message, even when both entry nodes are compromised and an
observer records every link (`ch_pub_perpacket`, `ch_pub_kemdem`,
`ch_priv_node`).

**With the cluster key, it fails.** Every member of a private cluster
holds the cluster's secret key, including members that are not exit
nodes. In the `bridge` network the exit nodes are 4 and 5, inside private
cluster {3, 4, 5}:

| Step | What happens |
|---|---|
| 1 | the client seals the egress layer with cluster {3, 4, 5}'s public key |
| 2–3 | entry node 2 receives the message and removes its layer |
| 4 | node 2 sends it over the bridge to node 3; node 3 removes the bridge layer and opens the egress layer with the cluster key |

Node 3 is a relay, not an exit node, and it now knows the message.

One could read the shortcut as making every member of the cluster an exit
node. Then no relay inside the cluster is a non-exit, but a compromised
member reads messages that leave through a different exit node. That
breaks the security argument of CMP instead (`ch_priv_cluster_all`).
Either way, one of the article's claims fails, so this is a Defect.

**Fix 3.** The egress layer is always sealed with the chosen exit node's
own key. The cluster key may still be used for the ingress layer: a
member that opens it finds only the egress layer, which it cannot open.
This keeps the article's shortcut where it is safe.

| Check | What it tests | Result |
|---|---|---|
| `ch_pub_perpacket`, `ch_pub_kemdem` | individual keys; both entry nodes compromised; every link observed | holds |
| `ch_priv_node` | individual keys, `bridge` network | holds |
| `ch_priv_cluster` | cluster key for the egress layer | fails, as expected: node 3 reads the message |
| `ch_priv_cluster_all` | cluster key, every member an exit node | fails, as expected: a member reads a message that leaves elsewhere |
| `ch_priv_ingress` | cluster key for the ingress layer only | holds |
| `wc_bad_relays`, `wc_bridge` | witnesses: a compromised node handles the message; the message crosses the bridge | both occur |

### 3.3 Dispersion, the premise of CMP — an observation

**The premise.** CMP's formula Φ_N = Σ X_i F_i assumes that a compromised
exit node *i* sees exactly the share F_i of traffic that leaves through
it, and nothing else. The check `ExposureByExit` tests this: once a
message has left, the attacker knows it only if the node it left through
is compromised.

**The two completions of finding 2 compared.**

- **Against the article's attacker**, a set of compromised relays, both
  completions keep the premise (`ch_disp_perpacket`, `ch_disp_visit`).
- **With a global observer added**, in a private cluster, only per-packet
  targeting keeps it. Under KEM-DEM every exit node can open every
  packet's egress layer, and in a private cluster every member can strip
  the link layers. A compromised exit node that sees the observer's
  recordings can therefore read packets that never pass through it
  (`ch_disp_obs`).

**Why per-packet targeting was chosen:**

- it keeps the premise in both settings;
- the client sets each exit node's share of the traffic directly;
- the header carries two encryptions instead of one per node.

**Its cost.** The entry node and the relays see which exit node a packet
is going to. The model does not measure anonymity, so this cost is
stated, not checked.

| Check | What it tests | Result |
|---|---|---|
| `ch_disp_perpacket` | per-packet targeting; private cluster; compromised exit node 3; global observer | holds |
| `ch_disp_visit` | KEM-DEM; compromised exit node 3; no observer | holds |
| `ch_disp_obs` | KEM-DEM; private cluster; compromised exit node 3; global observer | fails: node 3 reads a message that leaves through node 4 |
| `ch_know_monotone` | the attacker never forgets what it knows, so checking the premise when the message has left misses nothing | holds (150,476 states) |

### 3.4 Reaching an exit node (PRA) — Finding 4, Gap

**The claim.** The walk inside a cluster is irreducible, so it reaches
every member. Between clusters, though, "the edges between the clusters
may not be set up initially". Nothing relates the client's choice of exit
nodes to the clusters its entry nodes can reach.

**What goes wrong.** In the `nobridge` network, the entry nodes are in one
cluster and the exit nodes in another, with no link between them. Once the
entry node has taken the message, no exit node can ever be reached, so
the message is delivered with probability 0.

The irreducibility the article requires is also necessary. If the walk
inside a cluster splits into two parts (`reducible`), the walk can be
trapped away from the exit nodes.

**Fix 4.** The network's shared state publishes which bridges exist. The
client picks exit nodes that every node the walk can reach from the entry
nodes can in turn reach. For a finite random walk, this is exactly the
condition for delivery with probability 1. If a bridge's endpoint leaves
its cluster, the bridge is set up again with another member, using the
article's own on-demand bridge setup. That last part is argued, not
checked: the model's bridges are fixed.

| Check | What it tests | Result |
|---|---|---|
| `ch_reach_nobridge` | exit nodes in an unconnected cluster | fails, as expected |
| `ch_reducible` | a walk that is not irreducible | fails, as expected |
| `ch_reach_bridge` | exit nodes reachable over a bridge | holds; every message is delivered |

### 3.5 Keys and epochs (PRA) — Finding 5, Gap, and two observations

**Finding 5: rotation drops messages in flight.** Every node changes its
key pair at the start of each of its epochs. The article does not say how
long a node keeps its previous key. If it erases the old key at once:

| Step | What happens |
|---|---|
| 1 | the onion is sealed with entry node 1's current key |
| 2 | the client sends it to node 1 |
| 6 | node 1 starts a new epoch and erases its old key |
| 7 | node 1 cannot open the layer, and drops the message |

(Steps 3–5 are other nodes rotating, which does not matter.)

**Fix 5.** Each layer names the epoch of the key it was sealed with. A
node keeps its previous key, and a private cluster its previous shared
secret, for one more epoch. With that, a message is delivered as long as
the node that opens it changes keys at most once while it is travelling.
A message that outlives two key changes is still dropped. The chance of
that falls exponentially with the length of an epoch; this bound is
argued in [`docs/resolutions.md`](docs/resolutions.md), not checked.

**Observation: the grace period is the forward-secrecy window.** The
longer a node keeps old keys, the longer a later theft of its keys can
expose old messages. The checks compare the two settings the model
covers:

- with no grace period, a theft after the key change reveals nothing
  (`ch_fs`);
- with a one-epoch grace period, a theft within that epoch reveals the
  message (`ch_fs_window`).

This is forward secrecy of the message against theft of the exit node's
key. The article also calls the per-link keys derived from a cluster's
shared secret "forward secure". The model renews that secret only when a
member leaves, so that part is not checked.

**Observation: departed members.** A member that leaves a private cluster
still holds the shared secret, and can read the link encryption of later
traffic until the secret is renewed (`ch_leave_pub`). Renewing the secret,
and the cluster key, whenever membership changes closes this
(`ch_leave_rekey`). The message itself was never at risk, because it is
sealed with the exit node's own key.

| Check | What it tests | Result |
|---|---|---|
| `ch_rotate_g0` | rotation with no grace period | fails, as expected: a message is dropped |
| `ch_rotate_g1` | rotation with a one-epoch grace period | holds |
| `ch_fs` | theft of the exit node's key after its old key is gone | holds: nothing revealed |
| `ch_fs_window` | the same, inside the grace period | fails: the message is revealed |
| `ch_leave_pub` | a member leaves; the secret is not renewed | fails: it reads later link layers |
| `ch_leave_rekey` | the same, with the secret renewed on departure | holds |
| `wc_rotation`, `wc_late`, `wc_leave` | witnesses: a rotation during flight, the late theft, and traffic after a departure all happen | all occur |

### 3.6 TCP sessions (DON) — Findings 6 and 7, Gaps

**The claim.** "A cluster must maintain a single façade node for the
duration of a TCP session." When a member sends a packet of a connection,
it looks the connection up in the cluster's shared table. If there is no
entry, it picks a façade node and inserts it.

**Finding 6: two façades for one connection.** The model tries three ways
of keeping the table:

1. **A consistent (linearisable) table, used as the article describes:
   look up, then insert.** Members 1 and 2 both look the connection up
   and find nothing. Each picks a façade and inserts it, so the table now
   holds two façades, and the server sees two sources and resets the
   connection (`eg_relation`). This happens even though every single
   table operation is consistent: the lookup and the insert are separate
   steps.
2. **Copies that synchronise later (gossip).** The same happens, more
   easily (`eg_choose_gossip`).
3. **A façade computed from the member list.** Each member computes the
   façade as, for example, the member with the highest number. Then a
   node that joins changes the answer: member 1 computes 3, node 4 joins
   and computes 4 (`eg_hash_churn`). Any rule based on the member list
   breaks under some membership change.

**Fix 6.** The façade entry, including the external port, is created by a
single "insert if absent" operation, agreed by the cluster's consensus
before the connection's first packet leaves. Members only use the agreed
entry. In the model this is an atomic operation (`eg_consensus`). That
shows what consensus must provide; it does not check a consensus protocol
itself.

**Finding 7: tables across epochs.** The article indexes the session
tables by epoch. Read literally, a new epoch starts with empty tables, and
a connection that spans the boundary is given a new port midway
(`eg_epoch_pub`). The article's own expiry rule suggests entries should
persist, so this is an ambiguity in the text.

**Fix 7.** Entries carry over to the next epoch, and are removed only when
the connection closes or expires.

| Check | What it tests | Result |
|---|---|---|
| `eg_relation` | consistent table, lookup then insert | fails, as expected: two façades |
| `eg_choose_gossip` | gossip, free choice of façade | fails, as expected |
| `eg_hash_churn` | façade from the member list, with a join | fails, as expected |
| `eg_hash_gossip` | façade from the member list, no join | holds |
| `eg_consensus` | one agreed insert-if-absent, free choice, with a join | holds |
| `eg_epoch_pub` | tables emptied at the epoch boundary | fails, as expected |
| `eg_epoch_amd` | tables carried over | holds |
| `eg_cleanup` | after the connection closes, every copy of the table drops it | holds |
| `we_session`, `we_concurrent_open`, `we_join`, `we_epoch`, `we_cleanup` | witnesses: several senders in one session; two members opening at once; a join; a boundary inside a session; a stale copy right after closing | all occur |

### 3.7 UDP flows (DON) — Findings 8 and 9, Gaps

**Finding 8: entries expire under active flows.** An exit node keeps, for
each UDP flow, an entry with an expiry time τ_exp set when the entry is
created. Nothing renews it when the flow keeps sending. With
τ_exp = RTT = 2 time units:

| Step | What happens |
|---|---|
| 1 | the exit node sends packet 1 and creates the entry |
| 2 | one time unit passes |
| 3 | it sends packet 2, reusing the entry without renewing it |
| 4–5 | time passes; the response to packet 1 returns |
| 6 | the entry expires |
| 7 | the response to packet 2 arrives, finds no entry, and is lost |

**Fix 8.** Every outgoing packet renews its entry's expiry, as home
routers (NAT) do. RFC 4787 requires this renewal and an expiry of at
least two minutes. τ_exp must also exceed the time a response can take:
with τ_exp shorter than the response delay, responses are lost even with
renewal (`eg_udp_tight`).

**Finding 9: several sources per flow.** Packets of one UDP flow leave
through different exit nodes, so the server sees several source addresses
for one flow (`eg_udp_source`). The article requires the dispersion to
"appear seamless for the initiator and recipient". That holds for
protocols that do not care about the source address, but not for those
that do, such as QUIC and DTLS.

**Fix 9.** Flows of protocols that bind a session to an address are
pinned to a façade node, exactly like a TCP connection. This reuses the
checked façade rules; the expiry of a pinned UDP flow is argued, not
checked.

| Check | What it tests | Result |
|---|---|---|
| `eg_udp_pub` | expiry fixed at creation | fails, as expected: a response is lost |
| `eg_udp_tight` | renewal, but τ_exp shorter than the response delay | fails, as expected |
| `eg_udp` | renewal, and τ_exp at least the response delay | holds |
| `eg_udp_source` | one source address per UDP flow | fails: several sources |
| `we_udp_resp` | witness: a response does come back | occurs |

### 3.8 All fixes together — holds

These checks switch every fix on at once, and let nodes rotate keys and a
member leave while the message is travelling:

- each node rotates at most once;
- one member leaves, never the packet's own entry node, exit node or
  current holder.

| Check | Network and attacker | Property | States explored | Result |
|---|---|---|---|---|
| `am_safety` | `priv`; both entry nodes compromised; every link observed | no non-exit node and no attacker without an exit node learns the message; a departed member reads nothing new | 126,924 | holds |
| `am_exposure` | `priv`; exit node 3 compromised; every link observed | a compromised exit node sees only what leaves through it | 126,924 | holds |
| `am_bridge` | `bridge`; non-exit member 3 of the exit cluster compromised; every link observed | the message stays hidden | 21,612 | holds |
| `am_live` | `priv`; no attacker | every message is delivered | 1,356 | holds |
| `am_tcp` | egress model; agreed insert-if-absent; a join and an epoch boundary | one façade per connection, responses route back | 29,090 | holds |
| `wc_am`, `wc_am_bridge`, `we_am_tcp` | witnesses for the above | a rotation and a departure in flight; the compromised member handles the message; a join and a boundary inside a session | — | all occur |

## 4. What these checks do not cover

- **Probabilities.** TLC has no probabilities. The exposure formulas of
  CMP (f², Nym's bound, the expectation of Φ_N, β^{n_O}, the
  Kullback–Leibler tail bound), how fast the walk mixes, and latency are
  not checked. The model checks the qualitative conditions they rely on:
  exposure only through the exit node, and delivery with probability 1.
- **Size.**
  - The channel model follows one message, over two key epochs, with each
    node rotating at most once and at most one member leaving.
  - Its clusters have four or five nodes, with at least k = 2 entry and
    exit nodes.
  - The egress model follows one flow, with at most three packets and one
    node joining.
- **The attacker.** It is passive: it does not inject, drop or alter
  packets. The compromised nodes are fixed at the start, except the late
  theft of the exit node's keys.
- **Anonymity.** Who can link which client to which server is not
  modelled. The anonymity cost of per-packet targeting (section 3.3) is
  stated, not measured.
- **Consensus.** It is modelled as an atomic operation, not as a
  protocol.
- **Regular epochs of a cluster's shared secret** are not modelled; the
  secret changes only when a member leaves.
- **Bridges** are fixed. A façade node that crashes ends its sessions; the
  article makes no claim about that case.
- **Two assumptions of the article's design** are outside any model and
  should be stated in the dissertation:
  - **Sending with the façade's address.** This needs networks that do not
    filter spoofed source addresses (BCP 38, RFC 2827), or exit nodes in
    the same network as the façade.
  - **The façade's own operating system** must not reset a connection it
    did not open itself.

## 5. Running the checks yourself

**You need** Java 11 or later, GNU make and Python 3. The first run
downloads TLC (`tla2tools.jar`, release v1.7.4, TLC version 2.19) and
checks that its SHA-256 checksum is the pinned one. Every later run checks
it again before starting TLC.

**Run everything:**

```bash
make quick                 # all 55 checks, about 4 minutes
```

The last line printed should be `55/55 rows ok`. The slowest checks are
`am_safety` and `am_exposure`, at about 1.5 minutes and 40 seconds.

**Run one check:**

```bash
make ch_priv_cluster       # through make
./run.sh ch_priv_cluster   # or directly; also verifies the jar
```

**Check existing results without running TLC:**

```bash
python3 tools/check.py     # compares every log with its expected result
```

For each check this prints `ok` or `DIFF`, the expected and actual result,
the number of states explored, and the run time. It exits with an error
if any result differs, a log is missing, or a log is **stale**. Each log
starts with a line recording the checksums of the model, the configuration
and the TLC jar it was produced with. A log whose inputs have changed
since is reported as stale.

**Where the results are:**

- `logs/<check>.log` is the raw TLC output for each check.
- `traces/` holds the counterexamples the documents cite, copied from the
  logs with `python3 tools/trace.py <check>`.
- [`docs/results.md`](docs/results.md) has the table of every check, with
  states explored, depth and run time.

Runs use one worker thread. That makes counterexamples as short as
possible and the numbers exactly reproducible. `WORKERS=auto make quick`
is faster and gives the same verdicts. Checks that hold also give the
same state counts; checks that fail may stop at a different point.

## 6. Repository layout and further reading

| Path | What it is |
|---|---|
| `spec/GsrpChannel.tla` | the channel model (sections 3.1–3.5) |
| `spec/GsrpEgress.tla` | the egress model (sections 3.6–3.7) |
| `tools/gen_models.py` | the table of all checks; generates `models/` |
| `tools/check.py` | compares results with expectations; `--md` prints the results table |
| `tools/trace.py` | copies a counterexample from a log into `traces/` |
| `models/` | generated TLC configurations and the list of expected results |
| `logs/`, `traces/` | TLC output of the reported runs, and the cited counterexamples |
| `Makefile`, `run.sh` | run checks through make, or one at a time |

| Document | Read it for |
|---|---|
| [`docs/resolutions.md`](docs/resolutions.md) | each fix in the article's notation: why this fix, the alternatives, the cost, the corrected protocol as one procedure, and a paragraph for the dissertation |
| [`docs/results.md`](docs/results.md) | the full results table, and which witness backs which check |
| [`docs/model.md`](docs/model.md) | exactly what the models contain, what they leave out, and how the attacker is modelled |
| [`docs/finding-layer-removal.md`](docs/finding-layer-removal.md) | Finding 1 in full |
| [`docs/finding-multi-recipient-onion.md`](docs/finding-multi-recipient-onion.md) | Finding 2 in full, and the comparison of the two completions |
| [`docs/finding-private-cluster-key.md`](docs/finding-private-cluster-key.md) | Finding 3 in full |
| [`docs/finding-egress-reachability.md`](docs/finding-egress-reachability.md) | Finding 4 in full |
| [`docs/finding-key-rotation.md`](docs/finding-key-rotation.md) | Finding 5 in full, and the forward-secrecy window |
| [`docs/finding-facade-consistency.md`](docs/finding-facade-consistency.md) | Finding 6 in full |
| [`docs/finding-epoch-tables.md`](docs/finding-epoch-tables.md) | Finding 7 in full |
| [`docs/finding-udp-expiry.md`](docs/finding-udp-expiry.md) | Findings 8 and 9 in full |

## 7. Citing

Cite the tag `v1` rather than the `main` branch, so that readers see the
exact models, logs and numbers described here.
