#!/usr/bin/env python3
"""Copy the counterexample in logs/<row>.log to traces/<row>.trace.txt.

Usage: python3 tools/trace.py <row> [row ...]
Copies from TLC's "Error:" line to the end of the trace (the line that
reports the states generated), so a trace file reads on its own.
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))


def main(rows):
    if not rows:
        print(__doc__.strip())
        return 2
    os.makedirs(os.path.join(ROOT, 'traces'), exist_ok=True)
    for row in rows:
        lines = open(os.path.join(ROOT, 'logs', row + '.log')).read().splitlines()
        starts = [i for i, l in enumerate(lines) if l.startswith('Error:')]
        if not starts:
            print('%s: no counterexample in the log' % row)
            return 1
        start = starts[0]
        end = next((i for i in range(start, len(lines))
                    if re.match(r'^[\d,]+ states generated', lines[i])), len(lines))
        with open(os.path.join(ROOT, 'traces', row + '.trace.txt'), 'w') as f:
            f.write('\n'.join(lines[start:end]).rstrip() + '\n')
        print('traces/%s.trace.txt: %d lines' % (row, end - start))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
