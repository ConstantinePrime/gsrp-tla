#!/usr/bin/env python3
"""Compare each row's TLC verdict in logs/<row>.log with models/expect.tsv.

Usage: python3 tools/check.py [--md] [row ...]   (default: every row with a log)

Prints one line per row; with --md, a Markdown table for docs/results.md.
Exit status 1 if a verdict differs from the expectation, or a named row has
no log. A difference is something to investigate, never a reason to edit
expect.tsv by hand: the expectations come from tools/gen_models.py.
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))


def verdict(text):
    if 'Model checking completed. No error has been found.' in text:
        return 'holds'
    m = re.search(r'Error: Invariant (\w+) is violated', text)
    if m:
        return 'violated:' + m.group(1)
    if 'Error: Temporal properties were violated.' in text:
        return 'violated:temporal'
    return 'error'


def stats(text):
    """(distinct states, depth or trace length, time)"""
    found = re.findall(r'([\d,]+) distinct states found', text)
    states = found[-1] if found else '-'
    depth = re.search(r'The depth of the complete state graph search is (\d+)', text)
    trace = re.findall(r'^State (\d+):', text, re.M)
    if trace:
        length = 'trace %s' % max(int(t) for t in trace)
    elif depth:
        length = 'depth %s' % depth.group(1)
    else:
        length = '-'
    t = re.search(r'Finished in (.+?) at', text)
    return states, length, t.group(1) if t else '-'


def main(argv):
    md = '--md' in argv
    argv = [a for a in argv if a != '--md']
    expect = {}
    with open(os.path.join(ROOT, 'models', 'expect.tsv')) as f:
        for line in f:
            row, module, exp = line.rstrip('\n').split('\t')
            expect[row] = exp
    rows = argv or [r for r in expect if os.path.exists(os.path.join(ROOT, 'logs', r + '.log'))]
    bad = 0
    if md:
        print('| Row | Expected | Result | Distinct states | Depth / trace | Time |')
        print('|---|---|---|---|---|---|')
    for row in rows:
        path = os.path.join(ROOT, 'logs', row + '.log')
        if row not in expect or not os.path.exists(path):
            print('%-20s %s' % (row, 'unknown row' if row not in expect else 'no log'))
            bad += 1
            continue
        text = open(path).read()
        got = verdict(text)
        states, length, took = stats(text)
        ok = got == expect[row]
        bad += not ok
        if md:
            mark = ('✓ ' if got == 'holds' else '✗ ') + got.replace('violated:', '')
            print('| `%s` | %s | %s%s | %s | %s | %s |'
                  % (row, expect[row], mark, '' if ok else ' **(differs)**', states, length, took))
        else:
            print('%-20s %-4s expected %-30s got %-30s states %-10s %-10s %s'
                  % (row, 'ok' if ok else 'DIFF', expect[row], got, states, length, took))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
