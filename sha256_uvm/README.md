# SHA-256 UVM Verification Environment

A complete UVM testbench around the existing SHA-256 compression core
(`rtl/sha256_core.v` and its sub-modules).  The RTL is unchanged; everything
in this repository is verification infrastructure.

The environment is **self-checking** and **coverage-driven**:

- directed NIST FIPS 180-4 known-answer tests,
- constrained-random and stress traffic,
- a reset-recovery test,
- a directed coverage-closure test,
- an independent SystemVerilog golden model in the scoreboard,
- SVA protocol/latency assertions,
- a functional coverage model,
- a Python regression runner that summarizes pass/fail and coverage.

It runs on EDA Playground (free, no installation) and locally with
Verilator + UVM (open source), Questa/ModelSim, VCS or Xcelium.

**New here? Read `START_HERE.md` first — it has the two fastest paths.**

---

## Verified result

The project was compiled and run with **Verilator 5.054 + UVM 2020.3.1**
(the exact EDA Playground bundle also compiles and runs):

```
TOTAL: 15/15 passed, 0 failed
FUNCTIONAL COVERAGE: avg 87.59%  min 70.49%  max 100.00%
```

| Test | Seed | Result | Digests checked | Mismatches | Overall coverage |
|---|---:|---|---:|---:|---:|
| `sha256_kat_test` | 1–3 | PASS | 13 | 0 | 70.5% |
| `sha256_random_test` | 1–3 | PASS | 537–598 | 0 | 92.6–92.9% |
| `sha256_stress_test` | 1–3 | PASS | 2022–2040 | 0 | 92.9–93.3% |
| `sha256_reset_test` | 1–3 | PASS | 13–15 | 0 | 78.6–84.1% |
| `sha256_closure_test` | 1–3 | PASS | 190 | 0 | **100.0%** |

The scoreboard was also deliberately fed a corrupted expected digest
(`+ERROR_INJECT=1`); it reported `DIGEST MISMATCH` and the test failed, proving
the checker is actually watching. The regression script runs this as a
negative self-check with `--selfcheck`.

Raw logs from the verified run are in `results/` (or regenerate them with the
command below).

---

## Quick start

### Option A — EDA Playground (nothing to install)

1. Open <https://edaplayground.com> and log in.
2. Set:
   - **Testbench + Design**: `SystemVerilog/Verilog`
   - **UVM / OVM**: `UVM 1.2` (or `UVM IEEE 1800.2-2017`)
   - **Tools & Simulators**: `Siemens Questa` or `Aldec Riviera Pro`
3. Paste `sim/eda_playground/design.sv` into the **Design** pane.
4. Paste `sim/eda_playground/testbench.sv` into the **Testbench** pane.
5. Set **Top module** to `tb_top`.
6. Put `+UVM_TESTNAME=sha256_kat_test` in **Run Options**, then click **Run**.

To try the other tests, change the run option:

```
+UVM_TESTNAME=sha256_random_test +NUM_ITEMS=40
+UVM_TESTNAME=sha256_stress_test +NUM_ITEMS=100
+UVM_TESTNAME=sha256_reset_test
+UVM_TESTNAME=sha256_closure_test
```

The two files are generated from the normal project sources by:

```bash
python3 scripts/make_eda_bundle.py
```

See `docs/EDA_PLAYGROUND.md` for the longer walkthrough.

### Option B — Verilator + UVM locally (open source)

You need Verilator (5.05x or newer), the UVM library, and `z3` (Verilator's
constrained-random solver).  A throwaway environment can be created without
touching the system Python:

```bash
# with conda / micromamba
conda create -n sha256-uvm -c conda-forge verilator z3-solver
conda activate sha256-uvm

git clone --depth 1 https://github.com/verilator/uvm uvm
export UVM_HOME="$PWD/uvm/src"

python3 scripts/run_regression.py \
    --sim verilator --uvm-home "$UVM_HOME" \
    --seeds 1 2 3 --selfcheck
```

If you use the same environment, `make -f sim/Makefile regression` also works.

### Option C — Questa / VCS / Xcelium

```bash
export UVM_HOME=/path/to/uvm/src

# Questa / ModelSim
python3 scripts/run_regression.py --sim questa --uvm-home "$UVM_HOME" --seeds 1 2

# VCS (uses -ntb_opts uvm-1.2; UVM_HOME not required)
python3 scripts/run_regression.py --sim vcs --seeds 1 2

# Xcelium (uses -uvm)
python3 scripts/run_regression.py --sim xrun --seeds 1 2
```

Use `--dry-run` to print the exact commands without running them.  The
Verilator path is tested; the Questa/VCS/Xcelium command templates are standard
but may need small flag adjustments for your release.

---

## Project layout

```
sha256_uvm/
├── rtl/
│   ├── sha256_core.v          # DUT (unchanged)
│   ├── sha256_functions.v     # Σ0, Σ1, σ0, σ1, Ch, Maj
│   ├── sha256_round.v         # one combinational round
│   └── sha256_schedule.v      # 16-word circular schedule
├── tb/
│   ├── sha256_if.sv           # interface + driver/monitor modports
│   ├── sha256_model_pkg.sv    # golden SHA-256 model + FIPS padding + selftest
│   ├── sha256_uvm_pkg.sv      # package that includes the .svh files below
│   ├── sha256_txn.svh         # monitor -> scoreboard/coverage event
│   ├── sha256_seq_item.svh    # constrained-random item
│   ├── sha256_sequences.svh   # KAT, random, stress, reset, closure, 1M-'a'
│   ├── sha256_driver.svh      # block-level driver
│   ├── sha256_monitor.svh     # passive monitor + timing measurements
│   ├── sha256_scoreboard.svh  # reference-model scoreboard
│   ├── sha256_coverage.svh    # functional coverage
│   ├── sha256_agent.svh       # driver + sequencer + monitor
│   ├── sha256_env.svh         # agent + scoreboard + coverage
│   ├── sha256_tests.svh       # UVM tests
│   ├── sha256_sva.sv          # protocol/latency assertions
│   └── tb_top.sv              # clock, DUT, interface, run_test
├── sim/
│   ├── files.f                # compile order
│   ├── Makefile
│   └── eda_playground/        # generated two-file EDA Playground bundle
├── scripts/
│   ├── run_regression.py      # build + run + parse + summarize
│   └── make_eda_bundle.py     # regenerate the EDA Playground files
├── docs/
│   ├── UVM_GUIDE.md           # beginner-oriented walkthrough of this TB
│   ├── EDA_PLAYGROUND.md      # click-by-click instructions
│   └── RESULTS.md             # verified regression evidence
└── results/                   # timestamped logs, summary.csv, summary.md
```

---

## DUT interface

| Signal | Direction | Meaning |
|---|---|---|
| `clk` | in | clock |
| `rst_n` | in | asynchronous active-low reset |
| `init_i` | in | one-cycle pulse: reload the NIST IV (new message) |
| `block_valid_i` | in | one-cycle pulse: `block_i` is valid |
| `block_i[511:0]` | in | one 512-bit message block |
| `ready_o` | out | high when the core can accept a block |
| `done_o` | out | one-cycle pulse: `digest_o` is valid |
| `digest_o[255:0]` | out | current chained hash state |

Timing:

```
accepted block ──68 clocks──> done_o + ready_o + digest_o
```

The next block may be presented in the cycle where `done_o`/`ready_o` are high,
giving back-to-back throughput.  `init_i` between messages reloads the IV;
without `init_i` the core keeps chaining, which is exactly how multi-block
messages work.

---

## UVM architecture

```
                 +---------------------------------------------+
                 |              sha256_env                     |
                 |                                             |
  sequence ----> |  agent                                      |
                 |   +---------+   +---------+   +---------+   |
                 |   | driver  |   | monitor |   | score-  |   |
                 |   +----+----+   +----+----+   | board   |   |
                 |        |             |        +----+----+   |
                 |        v             |             ^        |
                 |   sha256_if          +--- txn ---->+        |
                 |        |             |             |        |
                 |   +----+----+        +-------> +---+----+   |
                 |   | sha256_ |                  | cover- |   |
                 |   | core    |                  | age    |   |
                 |   +---------+                  +--------+   |
                 +---------------------------------------------+
```

- **Sequence item** carries 1–8 blocks plus constrained properties
  (`n_blocks`, payload class, gap, `do_init`).
- **Driver** waits for `ready_o`, pulses `block_valid_i` for one clock, and
  waits for `done_o`.  It owns `rst_n`.
- **Monitor** samples the interface on posedge, publishes reset/init/block/digest
  events, and measures latency and inter-block gaps.
- **Scoreboard** mirrors the hash chaining with an independent behavioural
  model.  Every accepted block queues the digest it must produce 68 clocks
  later; every `done_o` compares the full 256-bit value.  This checks **every
  intermediate digest**, not just the final message digest.
- **Coverage** receives the same event stream and samples three covergroups.
- **SVA** independently checks the 68-cycle latency, ready/done protocol,
  one-cycle pulses and block stability.

See `docs/UVM_GUIDE.md` for a beginner-oriented explanation of how the pieces
fit together and how to add a test.

---

## Tests

| Test | What it does |
|---|---|
| `sha256_kat_test` | NIST vectors: empty, `abc`, `hello`, fox, fox with period, the 56-byte 2-block NIST vector, plus 55/64/130-byte padding boundaries. 13 block digests. |
| `sha256_random_test` | 100 constrained-random messages (1–8 blocks; zero/ones/alternating/mixed payloads; random gaps; 90% start a new message, 10% chain onto the previous one). |
| `sha256_stress_test` | 300 messages of 4–8 blocks with heavier gaps. |
| `sha256_reset_test` | Resets the core ~20 clocks into a compression, then verifies the next `abc` and five random messages are correct. |
| `sha256_closure_test` | Directed coverage closure: 40-block messages for each payload class, explicit short/medium/long gaps, and all message-length bins. 190 digests; 100% coverage. |
| `sha256_million_a_test` | NIST 1,000,000 × `a` vector (15,626 blocks). Slow/opt-in with `--include-slow`. |

Every test is self-checking through the scoreboard and SVA.  A failure appears
as `UVM_ERROR`, `DIGEST MISMATCH`, `SVA_FAIL`, or `SHA256_TEST_RESULT: FAIL`.

---

## Functional coverage

`tb/sha256_coverage.svh` defines:

- `sha256_block_cg`
  - payload class (mixed / all-zero / all-ones / alternating)
  - block position in the message (1, 2, 3, 4–8, 9–32, 33+)
  - gap since previous `done_o` (0, 1–5, 6–20, 21+)
  - cross: payload class × block position
- `sha256_digest_cg`
  - latency (only the architecturally correct 68-clock bin is legal)
  - message length in blocks (1, 2, 3, 4–8, 9–32, 33+)
  - digest parity (even/odd)
- `sha256_event_cg`
  - reset / init / block / digest events observed

`report_phase` prints a machine-readable line:

```
SHA256_COVERAGE block=100.00 digest=100.00 event=100.00 overall=100.00
```

The regression script parses that line into `summary.csv` / `summary.md`.
`sha256_closure_test` is the directed test that closes the model to 100%.
A shorter random-only run intentionally reports lower coverage; that is normal.

---

## Regression runner

`scripts/run_regression.py` builds once, runs each test × seed, parses the log,
and writes:

- `results/<timestamp>/<test>_seed<N>.log`
- `results/<timestamp>/summary.csv`
- `results/<timestamp>/summary.md`

Console summary:

```
TEST                        SEED   RESULT   BLOCKS   CHECKED   ERRORS   BLOCK%   DIGEST%   EVENT%   OVERALL%
sha256_kat_test             1      PASS     13       13        0        28.1     83.3      100.0    70.5
...
TOTAL: 15/15 passed, 0 failed
FUNCTIONAL COVERAGE: avg 87.59%  min 70.49%  max 100.00%
```

Useful options:

```bash
--sim verilator|questa|vcs|xrun|auto
--uvm-home /path/to/uvm/src
--seeds 1 2 3
--tests sha256_kat_test,sha256_closure_test
--include-slow
--selfcheck          # prove the scoreboard catches a corrupted digest
--timeout 300
--waves              # Verilator: --trace + VCD
--dry-run
```

Exit code is 0 only when every requested test passes (and the self-check, when
requested, detects the injected error).

---

## Differences from the original directed testbench

| Original `sha256_tb` | This environment |
|---|---|
| one `initial` block with hardcoded vectors | reusable UVM components and sequences |
| checks only the final digest after all blocks | checks **every** block digest via a reference model |
| no randomization | constrained-random payloads, lengths, gaps, chaining |
| no reset testing | reset mid-compression + recovery |
| no coverage | 3 covergroups with cross coverage, 100% closure test |
| no protocol checks | SVA latency/ready/done/payload assertions |
| manual pass/fail counting | regression runner + CSV/Markdown summaries |
| one simulator flow | EDA Playground, Verilator, Questa, VCS, Xcelium |

The RTL in `rtl/` is copied unchanged from the original project.

---

## Notes and limitations

- **UVM version**: compatible with UVM 1.2 and IEEE 1800.2-2020.  On EDA
  Playground choose `UVM 1.2` (or 2017/2020).
- **Verilator**: constrained randomization needs `z3` on `PATH` at *runtime*,
  not just at build time.  `+verilator+seed+<n>` seeds each run.
- **EDA Playground**: the generated `testbench.sv` is self-contained, so the
  UVM include path is the only external dependency.
- **The 1M-'a' test** is deliberately excluded from the default regression
  because it is 15,626 blocks (~1.06M clocks).  Run it with `--include-slow`.
- **Code coverage** is not collected by the Python script; this project reports
  functional coverage.  Commercial simulators can add `-coverage`/`-cm` and
  their native coverage reports on top.
- The core has no back-pressure: `ready_o` is low for the whole 68-cycle
  compression.  The driver therefore waits for `ready_o` rather than modeling a
  FIFO.
- SVA failures are emitted with `$error("SVA_FAIL: ...")` so the regression
  parser can count them without depending on a simulator-specific assertion
  format.

---

## Regenerating the EDA Playground bundle

After editing any file under `tb/`, run:

```bash
python3 scripts/make_eda_bundle.py
```

Then re-copy `sim/eda_playground/design.sv` and
`sim/eda_playground/testbench.sv` into EDA Playground.
