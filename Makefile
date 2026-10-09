TLA2TOOLS = tla2tools.jar
TLA2TOOLS_URL = https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar
TLA2TOOLS_SHA256 = 936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
JAVA_OPTS = -XX:+UseParallelGC -Xmx8g
# One worker keeps breadth-first search exact: shortest counterexamples and
# true depths, so the numbers in docs/results.md reproduce. Override with
# WORKERS=auto for speed; verdicts and distinct-state counts do not change.
WORKERS = 1

include models/rows.mk

.PHONY: all quick check models clean $(ROWS)

quick: $(QUICK)
	python3 tools/check.py $(QUICK)

all: $(ROWS)
	python3 tools/check.py $(ROWS)

check:
	python3 tools/check.py

models:
	python3 tools/gen_models.py

$(TLA2TOOLS):
	curl -sL -o $@ $(TLA2TOOLS_URL)
	echo "$(TLA2TOOLS_SHA256)  $@" | sha256sum -c -

# Each row re-checks the jar, copies its cfg next to its module, runs TLC
# and keeps the log. TLC exits nonzero on a violation; `tee` keeps make
# going, and tools/check.py compares the verdict with the expected one.
# TLC unpacks its standard modules into java.io.tmpdir; a directory per row
# keeps parallel rows (make -j) from reading each other's half-written copy.
$(ROWS): %: $(TLA2TOOLS)
	@echo "$(TLA2TOOLS_SHA256)  $(TLA2TOOLS)" | sha256sum -c --quiet -
	@mkdir -p logs spec/states/$*.tmp; mod=$($*_MODULE); \
	cp models/$*.cfg spec/$*.cfg; \
	cd spec && java $(JAVA_OPTS) -Djava.io.tmpdir=states/$*.tmp -cp ../$(TLA2TOOLS) tlc2.TLC \
	    -workers $(WORKERS) -metadir states/$* -config $*.cfg $$mod.tla | tee ../logs/$*.log; \
	rm -f $*.cfg; rm -rf states/$* states/$*.tmp

clean:
	rm -rf spec/states spec/*.cfg
