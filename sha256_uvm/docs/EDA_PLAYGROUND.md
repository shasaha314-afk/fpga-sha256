# Running this UVM project on EDA Playground

EDA Playground gives you a free UVM-capable simulator in the browser.  The
project is split into two generated files so it fits the site's **Design** and
**Testbench** panes.

## 1. Generate the bundle

From the project root:

```bash
python3 scripts/make_eda_bundle.py
```

This writes:

- `sim/eda_playground/design.sv` — the four RTL files
- `sim/eda_playground/testbench.sv` — interface, model package, all UVM
  components, SVA and `tb_top`

The testbench file is self-contained; the `.svh` includes are expanded, so you
do not need to configure an include path.

## 2. Create the playground

1. Go to <https://edaplayground.com> and log in.
2. In the left pane set:
   - **Testbench + Design**: `SystemVerilog/Verilog`
   - **UVM / OVM**: `UVM 1.2`  
     (`UVM IEEE 1800.2-2017` and newer should also work)
   - **Tools & Simulators**: `Siemens Questa 2025.2` or
     `Aldec Riviera Pro 2025.04`
3. Paste `design.sv` into the **Design** pane (right side).
4. Paste `testbench.sv` into the **Testbench** pane (left side).
5. Set **Top module** to `tb_top` if the field is available.
6. In **Run Options** enter:

   ```
   +UVM_TESTNAME=sha256_kat_test
   ```

7. Click **Run** (Ctrl+Enter).

Expected tail of the log:

```
[MODEL PASS] reference model and padding helper match NIST FIPS 180-4 vectors
SHA256_COVERAGE block=28.12 digest=83.33 event=100.00 overall=70.49
SHA256_SCOREBOARD blocks=13 checked=13 passed=13 failed=0 inits=9 resets=1
SHA256_TEST_RESULT: PASS
```

## 3. Run the other tests

Change only the **Run Options** string:

| Test | Run Options |
|---|---|
| NIST vectors | `+UVM_TESTNAME=sha256_kat_test` |
| Random | `+UVM_TESTNAME=sha256_random_test +NUM_ITEMS=40` |
| Stress | `+UVM_TESTNAME=sha256_stress_test +NUM_ITEMS=80` |
| Reset recovery | `+UVM_TESTNAME=sha256_reset_test` |
| Coverage closure (100%) | `+UVM_TESTNAME=sha256_closure_test` |
| 1M × 'a' (slow) | `+UVM_TESTNAME=sha256_million_a_test +WATCHDOG_MS=500` |

Free EDA Playground runs have a 60-second limit.  The first five tests finish
well within it.  The 1M-'a' test runs 15,626 blocks and may exceed the limit on
a slow shared server, so it is opt-in.

## 4. Seeing waves

Add to **Compile Options**:

```
+define+DUMP_WAVES
```

and tick **Open EPWave after run**.  The testbench dumps `sha256_uvm.vcd`.
Waves are useful for the 68-cycle latency: trigger on `vif.done_o` and look
back 68 clocks to the `block_valid_i && ready_o` handshake.

## 5. Common setup mistakes

| Problem | Fix |
|---|---|
| `Cannot find include file "uvm_macros.svh"` | Set the **UVM / OVM** drop-down; the UVM library was not selected |
| `Cannot find include file "sha256_..."` | You are using the project files instead of the generated bundle; either use `sim/eda_playground/*.sv` or add all files and set the include path |
| `Top module not found` / elaboration picks the wrong module | Set **Top module** to `tb_top` |
| Test does not run / `RNTST` missing | Put `+UVM_TESTNAME=...` in **Run Options**, not **Compile Options** |
| Random test fails immediately with `randomization failed` | The simulator's constraint solver rejected an item; try the KAT test first to separate UVM setup from randomization |
| Simulation hits the 60 s limit | Reduce `+NUM_ITEMS`, or run the million-'a' test locally |

## 6. Sharing

EDA Playground's **Share** tab creates a persistent link containing the code
and the last log.  Use that link if you want to send the running environment to
someone else.
