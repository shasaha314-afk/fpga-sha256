# Start here

This zip contains a complete UVM verification environment for the SHA-256
compression core.

## What is inside

- `rtl/` — the SHA-256 core (unchanged) and its sub-modules
- `tb/` — the UVM testbench: driver, monitor, scoreboard, sequences, SVA, coverage
- `sim/eda_playground/` — two ready-to-paste files for EDA Playground
- `scripts/run_regression.py` — runs tests and summarizes pass/fail + coverage
- `docs/UVM_GUIDE.md` — beginner walkthrough of every UVM component
- `docs/EDA_PLAYGROUND.md` — click-by-click browser instructions
- `docs/RESULTS.md` — verified regression results
- `results/` — logs from the verified 15/15 run

Full details are in `README.md`.

## Fastest way: EDA Playground (no installation)

1. Go to <https://edaplayground.com> and log in.
2. Select:
   - **Testbench + Design**: `SystemVerilog/Verilog`
   - **UVM / OVM**: `UVM 1.2`
   - **Tools & Simulators**: `Siemens Questa` or `Aldec Riviera Pro`
3. Paste `sim/eda_playground/design.sv` into the **Design** pane.
4. Paste `sim/eda_playground/testbench.sv` into the **Testbench** pane.
5. Set **Top module** to `tb_top`.
6. In **Run Options** put:

   ```
   +UVM_TESTNAME=sha256_kat_test
   ```

7. Click **Run**.

Expected ending:

```
SHA256_SCOREBOARD blocks=13 checked=13 passed=13 failed=0 ...
SHA256_TEST_RESULT: PASS
```

Other tests (change only the Run Options):

```
+UVM_TESTNAME=sha256_random_test +NUM_ITEMS=40
+UVM_TESTNAME=sha256_stress_test +NUM_ITEMS=100
+UVM_TESTNAME=sha256_reset_test
+UVM_TESTNAME=sha256_closure_test
```

More detail: `docs/EDA_PLAYGROUND.md`.

## Local regression: Verilator + UVM

```bash
conda create -n sha256-uvm -c conda-forge verilator z3-solver
conda activate sha256-uvm

git clone --depth 1 https://github.com/verilator/uvm uvm
export UVM_HOME="$PWD/uvm/src"

cd sha256_uvm
python3 scripts/run_regression.py \
    --sim verilator --uvm-home "$UVM_HOME" \
    --seeds 1 2 3 --selfcheck
```

The script builds once, runs every test/seed pair, and writes
`results/<timestamp>/summary.csv` and `summary.md`.

Useful options:

```bash
--tests sha256_kat_test,sha256_closure_test
--include-slow          # adds the 1,000,000 x 'a' vector
--selfcheck            # proves the scoreboard detects a corrupted digest
--dry-run              # print simulator commands only
```

## Questa / VCS / Xcelium

```bash
export UVM_HOME=/path/to/uvm/src
python3 scripts/run_regression.py --sim questa --uvm-home "$UVM_HOME" --seeds 1 2
python3 scripts/run_regression.py --sim vcs --seeds 1 2
python3 scripts/run_regression.py --sim xrun --seeds 1 2
```

The Verilator flow is tested. The commercial command templates are standard but
may need small release-specific flag changes.

## What to read first

1. `START_HERE.md` (this file)
2. `README.md` — architecture, tests, results
3. `docs/UVM_GUIDE.md` — if you are new to UVM
4. `docs/EDA_PLAYGROUND.md` — if you just want to click Run

## Verified result

```
TOTAL: 15/15 passed, 0 failed
FUNCTIONAL COVERAGE: avg 87.59%  min 70.49%  max 100.00%
```

`sha256_closure_test` reaches 100% functional coverage in every seed.
