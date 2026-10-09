#!/usr/bin/env bash
# Usage: ./run.sh <row> [extra TLC flags]    -- one row outside make
# WORKERS (default 1) and JAVA_OPTS (default -Xmx8g) are read from the environment.
set -euo pipefail
cd "$(dirname "$0")"
row="${1:?usage: ./run.sh <row> [TLC flags]}"; shift
mod=$(awk -F'\t' -v r="$row" '$1 == r {print $2}' models/expect.tsv)
[ -n "$mod" ] || { echo "unknown row: $row" >&2; exit 2; }
[ -f tla2tools.jar ] || make tla2tools.jar
mkdir -p logs "spec/states/$row.tmp"
cp "models/$row.cfg" "spec/$row.cfg"
( cd spec && java -XX:+UseParallelGC ${JAVA_OPTS:--Xmx8g} -Djava.io.tmpdir="states/$row.tmp" \
      -cp ../tla2tools.jar tlc2.TLC -workers "${WORKERS:-1}" -metadir "states/$row" "$@" \
      -config "$row.cfg" "$mod.tla" ) | tee "logs/$row.log" || true
rm -f "spec/$row.cfg"; rm -rf "spec/states/$row" "spec/states/$row.tmp"
python3 tools/check.py "$row"
