# UVM in this project — a beginner's walkthrough

If you have only written `initial`-block testbenches (like the original
`sha256_tb`), UVM can look like a lot of ceremony.  This guide maps each UVM
idea to a concrete file in this repository and follows one transaction from the
sequence all the way to the coverage report.

The short version:

> A **sequence** creates stimulus. A **driver** turns it into pin wiggles.
> A **monitor** watches the pins and publishes transactions. A **scoreboard**
> compares what happened against a golden model. **Coverage** records what was
> exercised. **SVA** checks protocol rules in parallel.

---

## 1. Why not just one big `initial` block?

The original testbench worked like this:

```systemverilog
reset_core();
feed_block(BLOCK_ABC);
check_result(256'hba78...);
```

That is perfectly fine for five vectors, but:

- every new test edits the same `initial` block,
- the checker knows only hardcoded expected values,
- there is no notion of "send 100 random messages",
- there is no coverage of what was exercised,
- one failure aborts the whole flow,
- nothing checks the protocol between blocks.

UVM splits those responsibilities into reusable components.  The DUT stays the
same; only the testbench changes.

---

## 2. The data flow in this project

```
sha256_kat_seq / sha256_random_seq
              |
              |  start_item(item)  ... finish_item(item)
              v
        uvm_sequencer  <---- handshake ---->  sha256_driver
                                                   |
                                                   |  drives sha256_if
                                                   v
                                              sha256_core (DUT)
                                                   |
                                                   |  ready_o / done_o / digest_o
                                                   v
                                             sha256_monitor
                                                   |
                                  uvm_analysis_port #(sha256_txn)
                                     /                        \
                                    v                          v
                            sha256_scoreboard           sha256_coverage
                            (golden model)              (covergroups)
```

The monitor is the only component that looks at the pins.  Everything
downstream sees the same `sha256_txn` objects, so the scoreboard and coverage
can never disagree about what happened.

---

## 3. UVM phases: who runs when

UVM calls component methods in a fixed order.  Only four matter for this
project:

| Phase | What happens here | In this project |
|---|---|---|
| `build_phase` | create children, get configuration | `sha256_env` creates agent/scoreboard/coverage; driver and monitor fetch the virtual interface; scoreboard runs the model self-test |
| `connect_phase` | connect ports/exports | agent connects driver↔sequencer, monitor→analysis port; env connects analysis port→scoreboard and coverage |
| `run_phase` | time-consuming simulation | sequences run, driver drives, monitor samples |
| `report_phase` / `final_phase` | summarize | scoreboard/coverage print counters and coverage; test prints PASS/FAIL |

`run_phase` would end immediately if nobody told UVM that work is in progress.
That is what **objections** are for.  In `sha256_base_test`:

```systemverilog
task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_test_sequence();
    phase.drop_objection(this);
endtask
```

The test raises the objection, starts a sequence, waits for it to finish, then
drops the objection.  When all objections are dropped, UVM ends `run_phase`.
If you forget the drop, the simulation hangs (the watchdog in `tb_top.sv`
catches that).

---

## 4. Factory and `config_db`

Two UVM mechanisms appear everywhere:

**Factory** — create objects through the factory, not with `new`:

```systemverilog
env = sha256_env::type_id::create("env", this);
```

This is what allows a test to substitute a different component type later
without editing the environment.

**`config_db`** — pass things down the hierarchy without global variables.
Here it carries the virtual interface from `tb_top` to the driver and monitor:

```systemverilog
// tb_top.sv
uvm_config_db#(virtual sha256_if)::set(null, "*", "vif", vif);

// sha256_driver.sv / sha256_monitor.sv
if (!uvm_config_db#(virtual sha256_if)::get(this, "", "vif", vif))
    `uvm_fatal("NO_VIF", "...")
```

If you see `NO_VIF`, the path/field name in `set` and `get` do not match, or
the `set` did not happen before `run_test()`.

---

## 5. Sequence item: what one "message" is

`tb/sha256_seq_item.svh`:

```systemverilog
rand int unsigned       n_blocks;     // 1..8
rand sha256_blk_class_e pattern;      // mixed/zero/ones/alternating
rand int unsigned       gap_cycles;   // idle clocks between blocks
rand bit                do_init;      // new message vs. chain onto previous

bit [511:0] blocks[$];                // actual payload
```

The constraints define the legal stimulus space:

```systemverilog
constraint c_n_blocks { n_blocks inside {[1:8]}; }
constraint c_gap {
    gap_cycles dist { 0 := 80, [1:3] := 15, [4:12] := 5 };
}
```

`post_randomize()` fills the 512-bit payload.  Random payloads use `$urandom`;
the class / gap / length decisions are made by the constrained solver.

The `blocks` queue can hold more than 8 entries when a directed sequence builds
a long message (the coverage-closure test sends 40 blocks, and the 1M-'a' test
sends 15,626).  Constraints only apply when `randomize()` is called.

---

## 6. Sequence → sequencer → driver

A sequence does not touch pins.  It creates items and hands them to a
sequencer:

```systemverilog
item = sha256_seq_item::type_id::create("item");
start_item(item);
if (!item.randomize()) `uvm_fatal("RAND", "randomization failed")
finish_item(item);
```

On the other side, the driver runs forever:

```systemverilog
forever begin
    seq_item_port.get_next_item(req);
    drive_item(req);
    seq_item_port.item_done();
end
```

The handshake is:

1. `start_item` waits until the sequencer is free.
2. `finish_item` sends the item to the driver and blocks until `item_done`.
3. The driver calls `get_next_item`, drives the pins, waits for `done_o`, then
   calls `item_done`.
4. Only then does the sequence continue to the next item.

This is why a sequence can contain hundreds of messages without any manual
timing code.

### Driver timing (important)

`tb/sha256_driver.svh` changes signals on **negedge**:

```systemverilog
task drive_one_block(bit [511:0] blk);
    wait_ready();                 // returns at a negedge with ready_o == 1
    vif.block_i       = blk;
    vif.block_valid_i = 1'b1;
    @(negedge vif.clk);           // hold across exactly one posedge
    vif.block_valid_i = 1'b0;
endtask
```

The monitor samples on **posedge**, so it sees exactly the values the DUT
samples and there is no race.  (A clocking block would also work, but this
explicit convention behaves the same on every simulator.)

The core's latency is 68 clocks.  `done_o` and `ready_o` are high in the same
cycle, so the next block can be accepted immediately — this gives
back-to-back blocks.  The driver's `wait_done()` waits one extra negedge after
seeing `done_o`, so the monitor gets to sample the final digest before the item
ends.  Without that extra edge the last digest of a test can be lost.

`init_i` is pulsed for one clock before an item when `do_init` is set.  This is
how each item becomes a separate SHA-256 message starting from the NIST IV.
When `do_init == 0`, the core keeps chaining, which is how the random test
creates messages longer than 8 blocks.

---

## 7. Monitor and analysis ports

`tb/sha256_monitor.svh` runs one forever loop:

```systemverilog
@(posedge vif.clk);
if (!vif.rst_n)          publish RESET;
if (vif.init_i)          publish INIT;
if (vif.done_o)          publish DIGEST;
if (valid && ready)      publish BLOCK;
```

Each event is a `sha256_txn` written to:

```systemverilog
uvm_analysis_port #(sha256_txn) ap;
ap.write(t);
```

An analysis port can be connected to any number of subscribers.  In
`sha256_env::connect_phase`:

```systemverilog
agent.ap.connect(sb.imp);
agent.ap.connect(cov.analysis_export);
```

`sb.imp` is a `uvm_analysis_imp`; `cov` is a `uvm_subscriber`.  Both receive
every transaction, in order.

The monitor also measures:

- `latency = done cycle - accept cycle` (must be 68),
- `gap = accept cycle - previous done cycle` (0 means back-to-back),
- the 1-based block index in the current message.

Those fields drive coverage.

---

## 8. Scoreboard: why a block-level model?

`tb/sha256_model_pkg.sv` is an independent, behavioural SHA-256:

- arrays and `for` loops, not the DUT's registers/FSM,
- FIPS 180-4 padding helper,
- a self-test that hashes the fixed NIST blocks and checks every digest.

At time zero the scoreboard calls `sha256_selftest()`.  If the model or the
padding helper is wrong, the scoreboard raises:

```
UVM_ERROR ... [MODEL] golden model self-test failed
```

so a broken model cannot silently "agree" with a broken DUT.

The scoreboard mirrors the DUT's chaining state:

```systemverilog
SHA256_EV_BLOCK:  predicted = model.update(t.block);
                  exp_q.push_back(predicted);
SHA256_EV_DIGEST: expected = exp_q.pop_front();
                  if (t.digest !== expected) `uvm_error(...)
```

This queues one prediction per accepted block, not one per message.  The
result: **every intermediate digest is checked**, including the digest after
each block of a multi-block message.  The original testbench checked only the
final digest.

`init_i` and reset both:

```systemverilog
model.reset();     // back to the NIST IV
exp_q.delete();    // drop in-flight predictions
```

That is why the reset test can abort a compression halfway and still pass: the
scoreboard discards the orphan prediction instead of reporting a false
mismatch.

The `+ERROR_INJECT=N` plusarg flips one expected bit.  The regression script
runs this negative test to prove the scoreboard actually detects mismatches.

---

## 9. Functional coverage

`tb/sha256_coverage.svh` is a `uvm_subscriber #(sha256_txn)`.  It copies fields
from the transaction into covergroup sample variables and calls `sample()`.

Three groups:

1. **block**: payload class, block position, gap, class × position cross.
2. **digest**: 68-clock latency, message length, digest parity.
3. **event**: reset / init / block / digest observed.

Only the correct 68-clock latency is a legal bin.  A different latency simply
misses the bin (and trips the SVA); it does not create a fake "late" bin that
can never be covered.

The random test reaches ~93%.  `sha256_closure_test` is a directed sequence
that sends 40-block messages of each payload class plus explicit gaps and
lengths; it reaches 100%.  This is the normal coverage-closure workflow:
random first, then directed corner cases for the holes.

`report_phase` prints:

```
SHA256_COVERAGE block=100.00 digest=100.00 event=100.00 overall=100.00
```

The Python regression runner parses this line.  It is intentionally simple and
simulator-independent.

---

## 10. SVA

`tb/sha256_sva.sv` is a separate module connected to the same interface in
`tb_top.sv`.  It does not rely on UVM.  The main checks:

```systemverilog
// accepted block -> done exactly 68 clocks later
(block_valid_i && ready_o) |-> ##68 done_o;

// ready stays low during the compression
(block_valid_i && ready_o) |-> ##[1:67] !ready_o;

// done and ready coincide; done is a one-cycle pulse
done_o |-> ready_o;
done_o |=> !done_o;

// payload is stable while the block is compressed
(block_valid_i && ready_o) |-> ##1 ((block_i == $past(block_i))[*67]);
```

Failures print `SVA_FAIL`, which the regression parser counts even though the
message does not use UVM severities.

There are also `cover property` statements for single block, done,
back-to-back and init events.  Simulators that support assertion coverage will
include them in their native coverage report.

---

## 11. Running one test and reading the log

```bash
# Verilator example
./sim/obj_dir/sha256_sim +UVM_TESTNAME=sha256_kat_test +UVM_VERBOSITY=UVM_LOW
```

Useful lines:

```
[RNTST] Running test sha256_kat_test...
[MODEL PASS] reference model and padding helper match NIST FIPS 180-4 vectors
[KAT] sent "abc" (3 bytes -> 1 block(s))
[SB] blocks=13 checked=13 passed=13 failed=0 inits=9 resets=1 unexpected=0
SHA256_SCOREBOARD blocks=13 checked=13 passed=13 failed=0 inits=9 resets=1
SHA256_COVERAGE block=28.12 digest=83.33 event=100.00 overall=70.49
SHA256_TEST_RESULT: PASS
```

A real failure looks like:

```
UVM_ERROR ... [SB] DIGEST MISMATCH at cycle 1234 (block #2)
  input    = ...
  got      = ...
  expected = ...
SHA256_TEST_RESULT: FAIL (uvm_errors=2 uvm_fatals=0)
```

Start with the first `UVM_ERROR`, not the summary count.  The input block,
cycle and both digests are in the message.

---

## 12. How to add a new test

Suppose you want a "single all-zero block" test.

1. **Add a sequence** (or reuse `sha256_closure_seq`'s `send_blocks` style):

```systemverilog
class sha256_zero_seq extends uvm_sequence #(sha256_seq_item);
    `uvm_object_utils(sha256_zero_seq)

    task body();
        sha256_seq_item item = sha256_seq_item::type_id::create("item");
        start_item(item);
        item.blocks.delete();
        item.blocks.push_back('0);
        item.n_blocks   = 1;
        item.do_init    = 1'b1;
        item.gap_cycles = 0;
        item.label      = "one all-zero block";
        finish_item(item);
    endtask
endclass
```

2. **Add a test**:

```systemverilog
class sha256_zero_test extends sha256_base_test;
    `uvm_component_utils(sha256_zero_test)

    task run_test_sequence();
        sha256_zero_seq seq = sha256_zero_seq::type_id::create("seq");
        seq.start(env.agent.sqr);
    endtask
endclass
```

3. Add both files/includes in the right order (`sha256_sequences.svh`, then
   `sha256_tests.svh` is already included from `sha256_uvm_pkg.sv`).
4. Add the test name to `TESTS` / `DEFAULT_TEST_ORDER` in
   `scripts/run_regression.py` if you want it in the regression.
5. Run `python3 scripts/make_eda_bundle.py` if you use EDA Playground.

No scoreboard changes are needed: every block is checked automatically.

---

## 13. How to add a coverage bin

In `sha256_coverage.svh`, add a field and a coverpoint, then assign it in
`write()`.  Example: track whether a message used `init_i`:

```systemverilog
bit cov_used_init;
covergroup cg_digest;
    cp_used_init: coverpoint cov_used_init {
        bins yes = {1};
        bins no  = {0};
    }
endgroup
```

But note: `sha256_txn` must carry the information first.  Add the field to
`sha256_txn.svh`, fill it in `sha256_monitor.svh`, then sample it.  This
"transaction schema" is the contract between monitor, scoreboard and coverage.

---

## 14. Common problems

| Symptom | Likely cause |
|---|---|
| `UVM_FATAL [NO_VIF]` | `config_db::set` path/field mismatch or `run_test()` before `set` |
| Simulation ends at time 0 | a test forgot `raise_objection` (or dropped it immediately) |
| `[RAND] ... randomization failed` | no solver available (Verilator needs `z3` on `PATH`) or an over-constrained item |
| `done_o with no outstanding block` | DUT produced `done_o` without an accepted block; check reset/init sequencing |
| `prediction(s) left un-checked` | a test ended before the last `done_o` was observed; the driver's extra negedge in `wait_done` prevents this |
| Coverage stuck at 0% | covergroup never sampled; check the monitor is connected to the coverage subscriber |
| `SVA_FAIL` in the log but `UVM_ERROR: 0` | SVA uses `$error`, not UVM; the regression script counts `SVA_FAIL` separately |
| EDA Playground compile error on `uvm_macros.svh` | the UVM drop-down was not set, or the file was pasted into the wrong pane |

---

## 15. File-to-concept map

| Concept | File |
|---|---|
| DUT pins | `tb/sha256_if.sv` |
| Golden model / padding | `tb/sha256_model_pkg.sv` |
| Stimulus object | `tb/sha256_seq_item.svh` |
| Stimulus scenarios | `tb/sha256_sequences.svh` |
| Pin driving | `tb/sha256_driver.svh` |
| Pin sampling | `tb/sha256_monitor.svh` |
| Checking | `tb/sha256_scoreboard.svh` |
| Coverage | `tb/sha256_coverage.svh` |
| Agent / env | `tb/sha256_agent.svh`, `tb/sha256_env.svh` |
| Tests + objections | `tb/sha256_tests.svh` |
| Assertions | `tb/sha256_sva.sv` |
| Clock / DUT / `run_test` | `tb/tb_top.sv` |
| Regression + reports | `scripts/run_regression.py` |

Once these fifteen files make sense, you have seen the core of a typical
block-level UVM environment: sequences, driver, monitor, scoreboard, coverage,
assertions and a regression flow.
