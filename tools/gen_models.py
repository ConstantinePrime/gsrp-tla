#!/usr/bin/env python3
"""Generate models/*.cfg, models/expect.tsv and models/rows.mk from ROWS.

Every configuration is a row of one table, so rows stay comparable: a row
states only what it changes from its module's BASE. Run from anywhere:
    python3 tools/gen_models.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', 'models'))

# Full design: the amended readings, because under the literal ones nothing
# is delivered and every other row would be vacuous. Each published reading
# is exercised by its own row.
BASE = {
    'GsrpChannel': dict(SCENARIO='"pub"', PEEL='"amended"', ONION='"per_packet"', KEYS='"node"',
                        GRACE=1, REKEY_ON_LEAVE='FALSE', OBSERVER='"none"',
                        ALLOW_ROTATE='FALSE', ALLOW_LEAVE='FALSE', Bad='{}', LATE='"none"',
                        MaxHops=6, HISTORY='TRUE'),
    'GsrpEgress': dict(MODE='"tcp"', FACADE='"hash"', TABLE='"gossip"', CHURN='FALSE',
                       EPOCHS='FALSE', CARRY='"amended"', REFRESH='"amended"',
                       TauExp=2, RTT=2, MaxSeg=3),
}

C, E = 'GsrpChannel', 'GsrpEgress'
HOLDS = 'holds'
TEMPORAL = 'violated:temporal'


def viol(name):
    return 'violated:' + name


CONF = ['TypeOK', 'NoPayloadBeforeEgress', 'PayloadNeedsEgress']
LIVE = dict(HISTORY='FALSE')      # delivery-only rows drop the history variables


def live(**kw):
    d = dict(LIVE)
    d.update(kw)
    return d

# (row, module, overrides, invariants, properties, expected, comment)
ROWS = [
    # --- GsrpChannel ---
    ('ch_peel_pub', C, live(PEEL='"published"'), ['TypeOK'], ['Delivered'], TEMPORAL,
     'Published: receivers never remove the hop/link layers. Expect no delivery.'),
    ('ch_onion_literal', C, live(ONION='"literal"'), ['TypeOK'], ['Delivered'], TEMPORAL,
     'Published: H encapsulates a key per node but the layer is sealed under one\n'
     'node\'s key; dispatch or the walk reaches another node, which drops.'),
    ('ch_live_perpacket', C, live(), ['TypeOK', 'EgressReachable'], ['Delivered'], HOLDS,
     'Full design (per-packet targets): every message is delivered.'),
    ('ch_live_kemdem', C, live(ONION='"kem_dem"'), ['TypeOK', 'EgressReachable'], ['Delivered'],
     HOLDS, 'KEM-DEM completion: every message is delivered.'),
    ('ch_pub_perpacket', C, dict(Bad='{1, 2}', OBSERVER='"global"'), CONF, [], HOLDS,
     'Full design, both ingress nodes compromised, global observer: the payload\n'
     'is never exposed.'),
    ('ch_pub_kemdem', C, dict(ONION='"kem_dem"', Bad='{1, 2}', OBSERVER='"global"'), CONF,
     [], HOLDS, 'KEM-DEM completion, same adversary.'),
    ('ch_disp_visit', C, dict(ONION='"kem_dem"', Bad='{3}'), ['TypeOK', 'ExposureByExit'], [],
     HOLDS,
     'KEM-DEM, egress 3 compromised, CMP\'s adversary (relays only): the walk exits at\n'
     'the first egress it reaches, so 3 reads only what exits through it.'),
    ('ch_disp_obs', C, dict(SCENARIO='"priv"', ONION='"kem_dem"', Bad='{3}', OBSERVER='"global"'),
     ['TypeOK', 'ExposureByExit'], [], viol('ExposureByExit'),
     'KEM-DEM, private cluster, egress 3 compromised plus a global passive observer\n'
     '(beyond CMP\'s adversary): 3 derives every link key from s_C and reads messages\n'
     'that never touch it.'),
    ('ch_disp_perpacket', C, dict(SCENARIO='"priv"', Bad='{3}', OBSERVER='"global"'),
     ['TypeOK', 'ExposureByExit'], [], HOLDS,
     'Per-packet completion, same adversary: exposure only through the exit node.'),
    ('ch_priv_cluster', C, dict(SCENARIO='"bridge"', KEYS='"cluster"'),
     ['TypeOK', 'NoPayloadBeforeEgress'], [], viol('NoPayloadBeforeEgress'),
     'Egress layer under the private cluster key: non-egress member 3 opens it.'),
    ('ch_priv_cluster_all', C, dict(SCENARIO='"bridge_all"', KEYS='"cluster"', Bad='{3}'),
     ['TypeOK', 'ExposureByExit'], [], viol('ExposureByExit'),
     'Cluster key, read with O = C2 (every member an egress): no relay is a\n'
     'non-egress, but egress 3 reads a message that exits at another egress.'),
    ('ch_priv_node', C, dict(SCENARIO='"bridge"'), ['TypeOK', 'NoPayloadBeforeEgress'], [], HOLDS,
     'Egress layer under individual node keys.'),
    ('ch_priv_ingress', C, dict(SCENARIO='"priv"', KEYS='"ingress"', Bad='{1, 2}',
                                OBSERVER='"global"'), CONF, [], HOLDS,
     'Resolution: private cluster key for the ingress layer only, egress layer under\n'
     'the egress node\'s key; both ingress nodes compromised, global observer.'),
    ('ch_reach_bridge', C, live(SCENARIO='"bridge"'), ['TypeOK', 'EgressReachable'], ['Delivered'],
     HOLDS, 'Egress cluster reachable over the bridge.'),
    ('ch_reach_nobridge', C, dict(SCENARIO='"nobridge"'), ['TypeOK', 'EgressReachable'], [],
     viol('EgressReachable'),
     'No inter-cluster link; nothing in the client\'s choice of I and O prevents it.'),
    ('ch_reducible', C, dict(SCENARIO='"reducible"'), ['TypeOK', 'EgressReachable'], [],
     viol('EgressReachable'), 'P_C not irreducible: the walk is trapped in {1, 2}.'),
    ('ch_rotate_g0', C, live(ALLOW_ROTATE='TRUE', GRACE=0), ['TypeOK'], ['Delivered'], TEMPORAL,
     'A node rotates its KEM key while the message is in flight; no grace period.'),
    ('ch_rotate_g1', C, live(ALLOW_ROTATE='TRUE'), ['TypeOK'], ['Delivered'], HOLDS,
     'Same with the previous epoch\'s key kept for one epoch.'),
    ('ch_fs', C, dict(ALLOW_ROTATE='TRUE', GRACE=0, OBSERVER='"global"', LATE='"exit"'),
     ['TypeOK', 'ForwardSecrecy'], [], HOLDS,
     'Exit node compromised after rotating, observer recorded everything.'),
    ('ch_fs_window', C, dict(ALLOW_ROTATE='TRUE', OBSERVER='"global"', LATE='"exit"'),
     ['TypeOK', 'ForwardSecrecy'], [], viol('ForwardSecrecy'),
     'Same with GRACE = 1: within the grace window the old key is still there.'),
    ('ch_leave_pub', C, dict(SCENARIO='"priv"', ALLOW_LEAVE='TRUE'), ['TypeOK', 'PostLeave'], [],
     viol('PostLeave'), 'A member leaves; s_C is renewed only at the epoch boundary.'),
    ('ch_leave_rekey', C, dict(SCENARIO='"priv"', ALLOW_LEAVE='TRUE', REKEY_ON_LEAVE='TRUE'),
     ['TypeOK', 'PostLeave'], [], HOLDS, 'Same with s_C renewed on departure.'),
    # --- the resolved protocol: every amendment on together ---
    ('am_safety', C, dict(SCENARIO='"priv"', KEYS='"ingress"', REKEY_ON_LEAVE='TRUE',
                          ALLOW_ROTATE='TRUE', ALLOW_LEAVE='TRUE', Bad='{1, 2}',
                          OBSERVER='"global"'), CONF + ['PostLeave'], [], HOLDS,
     'Resolved protocol, private cluster: rotation and departure in flight, both\n'
     'ingress nodes compromised, global observer.'),
    ('am_exposure', C, dict(SCENARIO='"priv"', KEYS='"ingress"', REKEY_ON_LEAVE='TRUE',
                            ALLOW_ROTATE='TRUE', ALLOW_LEAVE='TRUE', Bad='{3}',
                            OBSERVER='"global"'), ['TypeOK', 'ExposureByExit', 'PostLeave'], [],
     HOLDS, 'Resolved protocol, same events, egress 3 compromised: exposure only through\n'
     'the exit node.'),
    ('am_bridge', C, dict(SCENARIO='"bridge"', KEYS='"ingress"', REKEY_ON_LEAVE='TRUE',
                          ALLOW_ROTATE='TRUE', ALLOW_LEAVE='TRUE', Bad='{3}',
                          OBSERVER='"global"'), CONF, [], HOLDS,
     'Resolved protocol across the bridge: non-egress member 3 of the egress cluster\n'
     'compromised, global observer.'),
    ('am_live', C, live(SCENARIO='"priv"', KEYS='"ingress"', REKEY_ON_LEAVE='TRUE',
                        ALLOW_ROTATE='TRUE', ALLOW_LEAVE='TRUE'),
     ['TypeOK', 'EgressReachable'], ['Delivered'], HOLDS,
     'Resolved protocol: every message is delivered despite rotation and departure.'),
    ('ch_know_monotone', C, dict(SCENARIO='"priv"', Bad='{3}', GRACE=0, ALLOW_ROTATE='TRUE',
                                 ALLOW_LEAVE='TRUE', REKEY_ON_LEAVE='TRUE', SPEC='SafetySpec'),
     ['TypeOK'], ['KnowledgeMonotone'], HOLDS,
     'The coalition\'s knowledge only grows, even when its egress rotates without grace\n'
     'or leaves: compromised nodes keep the keys they held (premise of ExposureByExit).'),
    ('wc_am', C, live(SCENARIO='"priv"', KEYS='"ingress"', REKEY_ON_LEAVE='TRUE',
                      ALLOW_ROTATE='TRUE', ALLOW_LEAVE='TRUE'),
     ['NoRotateLeaveInFlight'], [], viol('NoRotateLeaveInFlight'),
     'Witness for am_*: a rotation and a departure both happen while the message is\n'
     'in flight.'),
    ('wc_am_bridge', C, dict(SCENARIO='"bridge"', KEYS='"ingress"', REKEY_ON_LEAVE='TRUE',
                             ALLOW_ROTATE='TRUE', ALLOW_LEAVE='TRUE', Bad='{3}',
                             OBSERVER='"global"'), ['NoBadHandles'], [], viol('NoBadHandles'),
     'Witness for am_bridge: compromised member 3 handles the message.'),
    ('wc_delivered', C, live(), ['NotDelivered'], [], viol('NotDelivered'),
     'Witness: the message reaches Srv.'),
    ('wc_bridge', C, dict(SCENARIO='"bridge"'), ['NoBridge'], [], viol('NoBridge'),
     'Witness: the message crosses the bridge.'),
    ('wc_bad_relays', C, dict(Bad='{1, 2}'), ['NoBadHandles'], [], viol('NoBadHandles'),
     'Witness: a compromised node handles the message.'),
    ('wc_rotation', C, dict(ALLOW_ROTATE='TRUE'), ['NoRotationInFlight'], [],
     viol('NoRotationInFlight'), 'Witness: a rotation happens while the message is in flight.'),
    ('wc_late', C, dict(ALLOW_ROTATE='TRUE', GRACE=0, OBSERVER='"global"', LATE='"exit"'),
     ['NoLate'], [], viol('NoLate'), 'Witness: the late compromise happens.'),
    ('wc_leave', C, dict(SCENARIO='"priv"', ALLOW_LEAVE='TRUE'), ['NoLeaveInFlight'], [],
     viol('NoLeaveInFlight'), 'Witness: traffic is sent after the member left.'),

    # --- GsrpEgress ---
    ('eg_choose_gossip', E, dict(FACADE='"choose"'), ['TypeOK', 'OneFacade'], [],
     viol('OneFacade'), 'Facade chosen freely, T_C kept by gossip: two members open theta.'),
    ('eg_relation', E, dict(TABLE='"relation"', FACADE='"choose"'), ['TypeOK', 'OneFacade'], [],
     viol('OneFacade'),
     'T_C linearisable (as under consensus), but lookup and insert are separate steps,\n'
     'as DON writes them: two members both find theta absent and insert two facades.'),
    ('eg_hash_gossip', E, {}, ['TypeOK', 'OneFacade', 'ReturnPath'], [], HOLDS,
     'Facade a function of the membership view, no churn.'),
    ('eg_hash_churn', E, dict(CHURN='TRUE'), ['TypeOK', 'OneFacade'], [], viol('OneFacade'),
     'Same with a join during the session: membership views differ.'),
    ('eg_consensus', E, dict(TABLE='"consensus"', FACADE='"choose"', CHURN='TRUE'),
     ['TypeOK', 'OneFacade', 'ReturnPath'], [], HOLDS,
     'Facade selection through the cluster\'s consensus, with churn.'),
    ('eg_epoch_pub', E, dict(EPOCHS='TRUE', CARRY='"published"'), ['TypeOK', 'OneFacade'], [],
     viol('OneFacade'), 'Tables per epoch: the session crosses the boundary.'),
    ('eg_epoch_amd', E, dict(EPOCHS='TRUE'), ['TypeOK', 'OneFacade', 'ReturnPath'], [], HOLDS,
     'Tables carried until FIN/RST/expiry.'),
    ('eg_cleanup', E, {}, ['TypeOK'], ['Cleanup'], HOLDS,
     'After FIN/RST every replica drops theta.'),
    ('eg_udp', E, dict(MODE='"udp"'), ['TypeOK', 'UdpReturn'], [], HOLDS,
     'UDP, tau_exp refreshed on use, TauExp >= RTT.'),
    ('eg_udp_pub', E, dict(MODE='"udp"', REFRESH='"published"'), ['TypeOK', 'UdpReturn'], [],
     viol('UdpReturn'), 'Published: tau_exp fixed at creation; a later packet\'s response is lost.'),
    ('eg_udp_tight', E, dict(MODE='"udp"', TauExp=1), ['TypeOK', 'UdpReturn'], [],
     viol('UdpReturn'), 'TauExp < RTT: the entry expires before the response.'),
    ('eg_udp_source', E, dict(MODE='"udp"'), ['TypeOK', 'UdpSourceStable'], [],
     viol('UdpSourceStable'),
     'Published: "seamless for the recipient"; the server sees several sources for one\n'
     'UDP flow.'),
    ('am_tcp', E, dict(TABLE='"consensus"', FACADE='"choose"', CHURN='TRUE', EPOCHS='TRUE'),
     ['TypeOK', 'OneFacade', 'ReturnPath'], [], HOLDS,
     'Resolved egress: selection through consensus, tables carried across the epoch,\n'
     'free choice of facade, a join during the session.'),
    ('we_session', E, {}, ['NoMultiSender'], [], viol('NoMultiSender'),
     'Witness: two members send segments of one session.'),
    ('we_concurrent_open', E, dict(FACADE='"choose"'), ['NoConcurrentOpen'], [],
     viol('NoConcurrentOpen'), 'Witness: two members insert theta into their replicas.'),
    ('we_udp_resp', E, dict(MODE='"udp"'), ['NoUdpAnswer'], [], viol('NoUdpAnswer'),
     'Witness: a UDP response is returned.'),
    ('we_join', E, dict(CHURN='TRUE'), ['NoJoin'], [], viol('NoJoin'), 'Witness: node 4 joins.'),
    ('we_epoch', E, dict(EPOCHS='TRUE'), ['NoBoundaryInSession'], [], viol('NoBoundaryInSession'),
     'Witness: an epoch boundary falls inside a session.'),
    ('we_cleanup', E, {}, ['NoStaleAfterClose'], [], viol('NoStaleAfterClose'),
     'Witness for eg_cleanup: a replica still holds theta after FIN/RST.'),
    ('we_am_tcp', E, dict(TABLE='"consensus"', FACADE='"choose"', CHURN='TRUE', EPOCHS='TRUE'),
     ['NoJoinBoundary'], [], viol('NoJoinBoundary'),
     'Witness for am_tcp: a join and an epoch boundary both fall inside a session.'),
]

# Rows left out of `make quick` (none so far; long rows go here).
SLOW = set()


def cfg_text(module, overrides, invs, props, expected, comment):
    consts = dict(BASE[module])
    consts.update(overrides)
    spec = consts.pop('SPEC', 'Spec')       # a row may name another specification
    lines = ['\\* ' + l for l in comment.split('\n')]
    lines.append('\\* Expected: ' + expected)
    lines.append('SPECIFICATION ' + spec)
    lines.append('CONSTANTS')
    for k, v in consts.items():
        lines.append('    %s = %s' % (k, v))
    lines.append('INVARIANTS')
    lines.extend('    ' + i for i in invs)
    if props:
        lines.append('PROPERTIES')
        lines.extend('    ' + p for p in props)
    lines.append('CHECK_DEADLOCK FALSE')
    return '\n'.join(lines) + '\n'


def main():
    os.makedirs(OUT, exist_ok=True)
    names = [r[0] for r in ROWS]
    assert len(names) == len(set(names)), 'duplicate row name'
    expect, mk = [], []
    for name, module, ov, invs, props, exp, comment in ROWS:
        assert set(ov) <= set(BASE[module]) | {'SPEC'}, (name, set(ov) - set(BASE[module]))
        with open(os.path.join(OUT, name + '.cfg'), 'w') as f:
            f.write(cfg_text(module, ov, invs, props, exp, comment))
        expect.append('%s\t%s\t%s' % (name, module, exp))
        mk.append('%s_MODULE = %s' % (name, module))
    with open(os.path.join(OUT, 'expect.tsv'), 'w') as f:
        f.write('\n'.join(expect) + '\n')
    with open(os.path.join(OUT, 'rows.mk'), 'w') as f:
        f.write('# generated by tools/gen_models.py\n')
        f.write('ROWS = %s\n' % ' '.join(names))
        f.write('QUICK = %s\n' % ' '.join(n for n in names if n not in SLOW))
        f.write('\n'.join(mk) + '\n')
    print('wrote %d configurations to %s' % (len(ROWS), OUT))


if __name__ == '__main__':
    main()
