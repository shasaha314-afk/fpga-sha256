# FPGA Implementation of SHA-256 Hash Algorithm

A hardware implementation of the SHA-256 (Secure Hash Algorithm 2, 256-bit) cryptographic hash function on a Xilinx Zynq-7000 FPGA (`xc7z010clg400-1`), targeting the Digilent Zybo Z7-10 development board.

The design follows the [NIST FIPS 180-4](https://www.nist.gov/federal-information-processing-standards-fips) specification and implements a hardware round-function architecture with dedicated combinational modules for the Σ0, Σ1, σ0, σ1, Maj, and Ch sub-functions, a 16-word circular shift-register message schedule, and a 64-round iterative compression core exposed through a board-level wrapper.

> Author: Shashwat Saha — 3rd Year B.Tech. Electrical Engineering, IIT Mandi

---

## Highlights

- ✅ Verified against all **NIST FIPS 180-4 test vectors** (simulation + on-chip hardware)
- 🛡️ **Industry-Grade UVM 1.2 Verification Suite** with SystemVerilog golden model, SVA protocol assertions, and **100% coverage closure**
- ⚡ **98 MHz** operation (MMCM-derived from the onboard 125 MHz oscillator)
- 📦 **15.4% LUTs**, **11.5% flip-flops**, **7% I/O** utilization on the xc7z010clg400-1
- ⏱️ Worst-case setup slack of **+0.618 ns**, zero failing timing endpoints
- 🔋 **134 mW** total on-chip power (Vivado power estimator)
- 🧪 On-board verification via **Vivado Integrated Logic Analyser (ILA)**, confirming bit-exact digest output
- 🧮 **Independent Reference Models**: MATLAB behavioural model + pure SystemVerilog algorithmic golden model

---

## Architecture

The design is decomposed into five Verilog modules that map directly onto the round-function architecture:

| Module | Description |
|---|---|
| `sha256_functions.v` | Combinational sub-modules: `Sigma0`, `Sigma1`, `sigma0`, `sigma1`, `Ch`, `Maj` |
| `sha256_schedule.v` | 16-word circular shift register with combinational σ0/σ1 message-schedule expansion |
| `sha256_round.v` | One fully combinational iteration of the round function (T1/T2 adder chains, 8 output wires) |
| `sha256_core.v` | Registered FSM controller: `ST_IDLE → ST_LOAD → ST_ROUND (×64) → ST_ACCUM → ST_DONE` |
| `sha256_top_pynq.v` | Board-level wrapper — button-driven FSM, LED digest display, block I/O |

Each 512-bit message block is processed in **exactly 68 clock cycles**, giving a throughput of ≈738 Mbit/s for back-to-back blocks at 98 MHz.

---

## UVM 1.2 Verification Environment (`sha256_uvm/`)

A self-checking, coverage-driven **UVM 1.2** testbench environment is included in the `sha256_uvm/` directory, providing industry-standard verification for the core:

### Verification Architecture
- **Independent Algorithmic Golden Model** (`tb/sha256_model_pkg.sv`): Pure SystemVerilog implementation of NIST FIPS 180-4. It computes reference digests dynamically on the fly without using the hardware RTL.
- **Layered UVM Components**: Clock-synchronized `sha256_driver`, passive `sha256_monitor`, and a scoreboard (`sha256_scoreboard`) comparing hardware outputs bit-for-bit against the golden model.
- **Protocol Assertions (SVA)** (`tb/sha256_sva.sv`): Cycle-accurate SystemVerilog assertions checking that computation latency is **exactly 68 clocks**, `ready_o` drops during computation, and `block_i` remains stable throughout processing.
- **Functional Coverage** (`tb/sha256_coverage.svh`): Comprehensive covergroups monitoring block counts, multi-block chains, hash bit distributions, and event transitions.

### Regression Results

| Test | Description | Result | Digests Checked | Mismatches | Coverage |
|---|---|:---:|---:|---:|---:|
| `sha256_kat_test` | NIST FIPS 180-4 Known-Answer Tests | **PASS** | 13 | 0 | 70.5% |
| `sha256_random_test` | Constrained-random message lengths & data | **PASS** | 537–598 | 0 | 92.8% |
| `sha256_stress_test` | Back-to-back block throughput bursts | **PASS** | 2022–2040 | 0 | 93.1% |
| `sha256_reset_test` | Mid-computation reset recovery | **PASS** | 13–15 | 0 | 82.4% |
| `sha256_closure_test`| Directed coverage closure sequence | **PASS** | 190 | 0 | **100.0%** |

*Note: Deliberate fault injection (`+ERROR_INJECT=1`) was tested; the scoreboard immediately flagged `DIGEST MISMATCH` and failed the simulation, proving the checker is fully active.*

### How to Run UVM Simulations

#### Option A: AMD Vivado GUI / CLI
In an open Vivado project targeting this core, run in the Tcl Console:
```tcl
source add_sim_uvm.tcl
```
Then click **Run Behavioral Simulation**. To select a specific test, set `xsim.simulate.xsim.more_options` in Simulation Settings (e.g., `-testplusarg UVM_TESTNAME=sha256_kat_test` or `-testplusarg UVM_TESTNAME=sha256_closure_test`).

#### Option B: EDA Playground (Browser, No Install)
1. Open [edaplayground.com](https://edaplayground.com)
2. Select **SystemVerilog/Verilog**, **UVM 1.2**, and simulator **Siemens Questa** or **Aldec Riviera Pro**.
3. Paste `sha256_uvm/sim/eda_playground/design.sv` into the **Design** pane and `sha256_uvm/sim/eda_playground/testbench.sv` into the **Testbench** pane.
4. Set top module to `tb_top` and put `+UVM_TESTNAME=sha256_kat_test` in **Run Options**. Click **Run**.

#### Option C: Python Regression Runner (Verilator / Questa / VCS)
```bash
cd sha256_uvm
python3 scripts/run_regression.py --sim verilator --uvm-home "$UVM_HOME" --seeds 1 2 3 --selfcheck
```

---

## FPGA Build & Implementation

### Prerequisites
- AMD Xilinx Vivado Design Suite (tested on 2025.1 and earlier)
- Digilent Zybo Z7-10 board (Zynq-7000, `xc7z010clg400-1`, speed grade −1)
- MATLAB (optional, for behavioural model verification)

### Build & Program
1. Open Vivado and import the RTL sources (`sha256_*.v`) and constraints (`sha256_constraints.xdc`).
2. Run **Synthesis** → **Implementation** → **Generate Bitstream**.
3. Program the Zybo Z7-10 over JTAG using the Vivado Hardware Manager.
4. Use the onboard push-button to trigger hash computation; the least-significant nibble of the digest is displayed on LEDs LD0–LD3.
5. (Optional) Attach the Vivado ILA to `digest_o`, `done_o`, `ready_o`, and `block_valid_i` to capture the full 256-bit digest in hardware.

---

## Post-Implementation Results (xc7z010clg400-1)

| Metric | Value |
|---|---|
| LUTs | 2,711 (15.40%) |
| Flip-Flops | 4,055 (11.52%) |
| BRAM | 7.5 (12.50%) |
| I/O | 7 (7.00%) |
| DSP48 | 0 (0.00%) |
| Clock frequency | 98 MHz |
| Worst-case setup slack | +0.618 ns |
| Max operating frequency | ≈104 MHz |
| Total on-chip power | 134 mW |
| Latency per block | 68 cycles (≈0.694 µs) |
| Throughput | ≈738 Mbit/s |

---

## References

1. NIST, "Secure Hash Standard (SHS)," FIPS PUB 180-4, Aug. 2015.
2. U. Banerjee et al., "An Energy-Efficient Reconfigurable DTLS Cryptographic Engine for Securing Internet-of-Things Applications," *IEEE J. Solid-State Circuits*, vol. 54, no. 8, pp. 2339–2352, Aug. 2019.
3. D. R. Stinson and M. B. Paterson, *Cryptography: Theory and Practice*, 4th ed. CRC Press, 2018.
4. Xilinx Inc., "Zynq-7000 SoC Technical Reference Manual," UG585 (v1.13), Feb. 2023.
5. Digilent Inc., "Zybo Z7 Reference Manual," Rev. B, 2018.
