# FPGA Implementation of SHA-256 Hash Algorithm

A hardware implementation of the SHA-256 (Secure Hash Algorithm 2, 256-bit) cryptographic hash function on a Xilinx Zynq-7000 FPGA (`xc7z010clg400-1`), targeting the Digilent Zybo Z7-10 development board.

The design follows the [NIST FIPS 180-4](https://www.nist.gov/federal-information-processing-standards-fips) specification and implements a hardware round-function architecture with dedicated combinational modules for the Σ0, Σ1, σ0, σ1, Maj, and Ch sub-functions, a 16-word circular shift-register message schedule, and a 64-round iterative compression core exposed through a board-level wrapper.

> Author: Shashwat Saha — 3rd Year B.Tech. Electrical Engineering, IIT Mandi

---

## Highlights

- ✅ Verified against all **5 NIST FIPS 180-4 test vectors** (simulation + hardware)
- ⚡ **98 MHz** operation (MMCM-derived from the onboard 125 MHz oscillator)
- 📦 **15.4% LUTs**, **11.5% flip-flops**, **7% I/O** utilization on the xc7z010clg400-1
- ⏱️ Worst-case setup slack of **+0.618 ns**, zero failing timing endpoints
- 🔋 **134 mW** total on-chip power (Vivado power estimator)
- 🧪 On-board verification via **Vivado Integrated Logic Analyser (ILA)**, confirming bit-exact digest output
- 🧮 **MATLAB behavioural model** used as a golden software reference for RTL verification

## Architecture

The design is decomposed into five Verilog modules that map directly onto the round-function architecture:

| Module | Description |
|---|---|
| `sha256_functions.v` | Combinational sub-modules: `Sigma0`, `Sigma1`, `sigma0`, `sigma1`, `Ch`, `Maj` |
| `sha256_schedule.v` | 16-word circular shift register with combinational σ0/σ1 message-schedule expansion |
| `sha256_round.v` | One fully combinational iteration of the round function (T1/T2 adder chains, 8 output wires) |
| `sha256_core.v` | Registered FSM controller: `ST_IDLE → ST_LOAD → ST_ROUND (×64) → ST_ACCUM → ST_DONE` |
| `sha256_top.v` | Board-level wrapper — button-driven FSM, LED digest display, block I/O |

Each 512-bit message block is processed in **68 clock cycles**, giving a throughput of ≈738 Mbit/s for back-to-back blocks at 98 MHz.


## Getting Started

### Prerequisites
- Xilinx Vivado Design Suite (used with default synthesis/implementation strategies)
- Digilent Zybo Z7-10 board (Zynq-7000, `xc7z010clg400-1`, speed grade −1)
- MATLAB (optional, for re-running the behavioural golden-reference model)

### Build & Program
1. Open Vivado and create/import the project using the sources and constraints.
2. Run Synthesis → Implementation → Generate Bitstream.
3. Program the Zybo Z7-10 over JTAG using the Vivado Hardware Manager.
4. Use the onboard push-button to trigger a hash computation; the least-significant nibble of the digest is shown on LEDs LD0–LD3.
5. (Optional) Attach the Vivado ILA to `digest_o`, `done_o`, `ready_o`, and `block_valid_i` to capture the full 256-bit digest on-chip.

### Simulation
Run the provided testbench against the five NIST FIPS 180-4 known-answer test vectors plus any custom strings. All vectors should report `PASS`.

## Verification Summary

| Input | Digest (hex) | Result |
|---|---|---|
| `""` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `"abc"` | `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` | PASS |
| 56-char NIST vector | `248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1` | PASS |
| `"hello"` | `2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824` | PASS |
| `"The quick brown fox jumps over the lazy dog"` | `d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592` | PASS |
| `"The quick brown fox jumps over the lazy dog."` | `ef537f25c895bfa782526529a9b63d97aa631564d5d789c2b765448c8635fb6c` | PASS |

Hardware verification on the Zybo Z7-10 reproduced the `"abc"` digest bit-exactly via the Vivado ILA.

## Results Summary

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

## References

1. NIST, "Secure Hash Standard (SHS)," FIPS PUB 180-4, Aug. 2015.
2. U. Banerjee et al., "An Energy-Efficient Reconfigurable DTLS Cryptographic Engine for Securing Internet-of-Things Applications," *IEEE J. Solid-State Circuits*, vol. 54, no. 8, pp. 2339–2352, Aug. 2019.
3. D. R. Stinson and M. B. Paterson, *Cryptography: Theory and Practice*, 4th ed. CRC Press, 2018.
4. Xilinx Inc., "Zynq-7000 SoC Technical Reference Manual," UG585 (v1.13), Feb. 2023.
5. Digilent Inc., "Zybo Z7 Reference Manual," Rev. B, 2018.

