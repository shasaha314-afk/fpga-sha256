#!/usr/bin/env python3
"""
SHA-256 UVM regression runner
=============================

Builds the testbench once, runs every test/seed pair, parses the UVM log and
the functional-coverage lines, and writes a pass/fail + coverage summary.

Tested locally with:
    python3 scripts/run_regression.py --sim verilator --uvm-home ~/uvm/src

Also supports Questa/ModelSim, VCS and Xcelium.  Use --dry-run to print the
exact commands before running them.

Examples
--------
    # one seed, all default tests
    python3 scripts/run_regression.py --sim verilator --uvm-home /path/to/uvm/src

    # five seeds, include the slow 1,000,000 x 'a' vector
    python3 scripts/run_regression.py --seeds 1 2 3 4 5 --include-slow

    # only selected tests
    python3 scripts/run_regression.py --tests sha256_kat_test,sha256_reset_test

    # prove the scoreboard catches a corrupted digest (expected failure)
    python3 scripts/run_regression.py --selfcheck

Exit status is 0 only if every requested test passed.
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SIM_DIR = PROJECT_ROOT / "sim"
TB_DIR = PROJECT_ROOT / "tb"
DEFAULT_UVM_CANDIDATES = [
    PROJECT_ROOT / "third_party" / "uvm" / "src",
    PROJECT_ROOT / "uvm" / "src",
    Path.home() / "uvm" / "src",
]

# ---------------------------------------------------------------------------
# Test definitions
# ---------------------------------------------------------------------------
@dataclass
class TestDef:
    name: str
    plusargs: list[str] = field(default_factory=list)
    slow: bool = False


TESTS: dict[str, TestDef] = {
    "sha256_kat_test": TestDef("sha256_kat_test"),
    "sha256_random_test": TestDef("sha256_random_test", ["NUM_ITEMS=100"]),
    "sha256_stress_test": TestDef("sha256_stress_test", ["NUM_ITEMS=300"]),
    "sha256_reset_test": TestDef("sha256_reset_test"),
    "sha256_closure_test": TestDef("sha256_closure_test"),
    "sha256_million_a_test": TestDef(
        "sha256_million_a_test", ["WATCHDOG_MS=500"], slow=True
    ),
}
DEFAULT_TEST_ORDER = [
    "sha256_kat_test",
    "sha256_random_test",
    "sha256_stress_test",
    "sha256_reset_test",
    "sha256_closure_test",
]

# ---------------------------------------------------------------------------
# Log parsing
# ---------------------------------------------------------------------------
COV_RE = re.compile(
    r"SHA256_COVERAGE\s+block=([0-9.]+)\s+digest=([0-9.]+)\s+"
    r"event=([0-9.]+)\s+overall=([0-9.]+)"
)
SB_RE = re.compile(
    r"SHA256_SCOREBOARD\s+blocks=(\d+)\s+checked=(\d+)\s+passed=(\d+)\s+"
    r"failed=(\d+)\s+inits=(\d+)\s+resets=(\d+)"
)
UVM_ERR_RE = re.compile(r"UVM_ERROR\s*:\s*(\d+)")
UVM_FATAL_RE = re.compile(r"UVM_FATAL\s*:\s*(\d+)")


@dataclass
class RunResult:
    test: str
    seed: int
    passed: bool
    returncode: int
    uvm_errors: int = 0
    uvm_fatals: int = 0
    sva_failures: int = 0
    blocks: int = 0
    checked: int = 0
    failed_checks: int = 0
    block_cov: float = 0.0
    digest_cov: float = 0.0
    event_cov: float = 0.0
    overall_cov: float = 0.0
    log: Path | None = None
    note: str = ""


def parse_log(text: str) -> dict:
    out: dict = {
        "uvm_errors": 0,
        "uvm_fatals": 0,
        "sva_failures": text.count("SVA_FAIL"),
        "blocks": 0,
        "checked": 0,
        "failed": 0,
        "block_cov": 0.0,
        "digest_cov": 0.0,
        "event_cov": 0.0,
        "overall_cov": 0.0,
        "passed_marker": False,
        "failed_marker": False,
    }

    m = COV_RE.search(text)
    if m:
        (out["block_cov"], out["digest_cov"], out["event_cov"],
         out["overall_cov"]) = (float(x) for x in m.groups())

    m = SB_RE.search(text)
    if m:
        out["blocks"] = int(m.group(1))
        out["checked"] = int(m.group(2))
        out["failed"] = int(m.group(4))

    # The report summary may contain several "UVM_ERROR : N" lines; take max.
    for m in UVM_ERR_RE.finditer(text):
        out["uvm_errors"] = max(out["uvm_errors"], int(m.group(1)))
    for m in UVM_FATAL_RE.finditer(text):
        out["uvm_fatals"] = max(out["uvm_fatals"], int(m.group(1)))

    out["passed_marker"] = "SHA256_TEST_RESULT: PASS" in text
    out["failed_marker"] = "SHA256_TEST_RESULT: FAIL" in text
    return out


# ---------------------------------------------------------------------------
# Simulator backends
# ---------------------------------------------------------------------------
class Backend:
    name = "base"

    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.build_log: Path | None = None

    def build(self) -> bool:
        raise NotImplementedError

    def run_cmd(self, test: TestDef, seed: int, extra: list[str]) -> list[str]:
        raise NotImplementedError

    def run(self, test: TestDef, seed: int, extra: list[str], timeout: int,
            log_path: Path) -> int:
        cmd = self.run_cmd(test, seed, extra)
        with log_path.open("w") as log:
            log.write("$ " + " ".join(cmd) + "\n\n")
            log.flush()
            try:
                proc = subprocess.run(
                    cmd,
                    cwd=PROJECT_ROOT,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    timeout=timeout,
                )
                return proc.returncode
            except subprocess.TimeoutExpired:
                log.write(f"\n*** TIMEOUT after {timeout}s ***\n")
                return 124
            except FileNotFoundError as exc:
                log.write(f"\n*** COMMAND NOT FOUND: {exc} ***\n")
                return 127


class VerilatorBackend(Backend):
    name = "verilator"

    def __init__(self, args):
        super().__init__(args)
        self.exe = SIM_DIR / "obj_dir" / "sha256_sim"

    def build(self) -> bool:
        uvm_home = self.args.uvm_home
        if not uvm_home:
            print("ERROR: --uvm-home (or $UVM_HOME) is required for Verilator")
            return False

        cmd = [
            self.args.verilator, "--binary", "--timing",
            "-j", str(self.args.jobs), "-Wno-fatal",
            "--top-module", "tb_top",
            "--timescale", "1ns/1ps",
            f"+incdir+{uvm_home}",
            f"+incdir+{TB_DIR}",
            "+define+UVM_NO_DPI",
            "+define+VERILATOR",
            str(Path(uvm_home) / "uvm_pkg.sv"),
            "-f", str(SIM_DIR / "files.f"),
            "--Mdir", str(SIM_DIR / "obj_dir"),
            "-o", "sha256_sim",
        ]
        if self.args.waves:
            cmd[1:1] = ["--trace", "+define+DUMP_WAVES"]

        self.build_log = self.args.run_dir / "build_verilator.log"
        print("Building Verilator model ...")
        print("  $ " + " ".join(cmd))
        if self.args.dry_run:
            return True
        with self.build_log.open("w") as log:
            proc = subprocess.run(
                cmd, cwd=PROJECT_ROOT, stdout=log, stderr=subprocess.STDOUT
            )
        if proc.returncode != 0:
            print(f"BUILD FAILED -- see {self.build_log}")
            _print_tail(self.build_log)
            return False
        return True

    def run_cmd(self, test: TestDef, seed: int, extra: list[str]) -> list[str]:
        cmd = [
            str(self.exe),
            f"+UVM_TESTNAME={test.name}",
            "+UVM_VERBOSITY=UVM_LOW",
            f"+verilator+seed+{seed}",
        ] + _plusargs(test.plusargs + extra)
        return cmd


class QuestaBackend(Backend):
    name = "questa"

    def __init__(self, args):
        super().__init__(args)
        self.work = PROJECT_ROOT / "sim" / "work_questa"

    def build(self) -> bool:
        uvm_home = self.args.uvm_home
        if not uvm_home:
            print("ERROR: --uvm-home (or $UVM_HOME) is required for Questa")
            return False

        cmds = [
            ["vlib", str(self.work)],
            [
                "vlog", "-sv", "-work", str(self.work),
                f"+incdir+{TB_DIR}", f"+incdir+{uvm_home}",
                str(Path(uvm_home) / "uvm_pkg.sv"),
                "-f", str(SIM_DIR / "files.f"),
            ],
        ]
        self.build_log = self.args.run_dir / "build_questa.log"
        print("Building Questa model ...")
        with self.build_log.open("w") as log:
            for cmd in cmds:
                print("  $ " + " ".join(cmd))
                log.write("$ " + " ".join(cmd) + "\n")
                log.flush()
                if self.args.dry_run:
                    continue
                proc = subprocess.run(
                    cmd, cwd=PROJECT_ROOT, stdout=log, stderr=subprocess.STDOUT
                )
                if proc.returncode != 0:
                    print(f"BUILD FAILED -- see {self.build_log}")
                    _print_tail(self.build_log)
                    return False
        return True

    def run_cmd(self, test, seed, extra):
        return [
            "vsim", "-c", "-work", str(self.work), "tb_top",
            "-do", "run -all; quit -f",
            f"+UVM_TESTNAME={test.name}",
            "+UVM_VERBOSITY=UVM_LOW",
            "-sv_seed", str(seed),
        ] + _plusargs(test.plusargs + extra)


class VcsBackend(Backend):
    name = "vcs"

    def __init__(self, args):
        super().__init__(args)
        self.exe = PROJECT_ROOT / "sim" / "simv"

    def build(self) -> bool:
        cmd = [
            "vcs", "-full64", "-sverilog", "-timescale=1ns/1ps",
            "-ntb_opts", "uvm-1.2",
            f"+incdir+{TB_DIR}",
            "-f", str(SIM_DIR / "files.f"),
            "-top", "tb_top",
            "-o", str(self.exe),
        ]
        self.build_log = self.args.run_dir / "build_vcs.log"
        print("Building VCS model ...")
        print("  $ " + " ".join(cmd))
        if self.args.dry_run:
            return True
        with self.build_log.open("w") as log:
            proc = subprocess.run(
                cmd, cwd=PROJECT_ROOT, stdout=log, stderr=subprocess.STDOUT
            )
        if proc.returncode != 0:
            print(f"BUILD FAILED -- see {self.build_log}")
            _print_tail(self.build_log)
            return False
        return True

    def run_cmd(self, test, seed, extra):
        return [
            str(self.exe),
            f"+UVM_TESTNAME={test.name}",
            "+UVM_VERBOSITY=UVM_LOW",
            f"+ntb_random_seed={seed}",
        ] + _plusargs(test.plusargs + extra)


class XrunBackend(Backend):
    name = "xrun"

    def build(self) -> bool:
        cmd = [
            "xrun", "-64bit", "-sv", "-uvm",
            f"+incdir+{TB_DIR}",
            "-f", str(SIM_DIR / "files.f"),
            "-top", "tb_top",
            "-elaborate",
        ]
        self.build_log = self.args.run_dir / "build_xrun.log"
        print("Building Xcelium model ...")
        print("  $ " + " ".join(cmd))
        if self.args.dry_run:
            return True
        with self.build_log.open("w") as log:
            proc = subprocess.run(
                cmd, cwd=PROJECT_ROOT, stdout=log, stderr=subprocess.STDOUT
            )
        if proc.returncode != 0:
            print(f"BUILD FAILED -- see {self.build_log}")
            _print_tail(self.build_log)
            return False
        return True

    def run_cmd(self, test, seed, extra):
        return [
            "xrun", "-R",
            f"+UVM_TESTNAME={test.name}",
            "+UVM_VERBOSITY=UVM_LOW",
            "-svseed", str(seed),
        ] + _plusargs(test.plusargs + extra)


BACKENDS = {
    "verilator": VerilatorBackend,
    "questa": QuestaBackend,
    "vcs": VcsBackend,
    "xrun": XrunBackend,
}


def detect_simulator() -> str | None:
    if shutil.which("verilator"):
        return "verilator"
    if shutil.which("vsim") and shutil.which("vlog"):
        return "questa"
    if shutil.which("vcs"):
        return "vcs"
    if shutil.which("xrun"):
        return "xrun"
    return None


# ---------------------------------------------------------------------------
# Helpers / reporting
# ---------------------------------------------------------------------------
def _print_tail(path: Path, lines: int = 25) -> None:
    try:
        text = path.read_text(errors="replace").splitlines()
        print("\n".join(text[-lines:]))
    except OSError:
        pass


def _fmt_row(cols: list[str], widths: list[int]) -> str:
    return "  ".join(c.ljust(w) for c, w in zip(cols, widths))


def _plusargs(items: list[str]) -> list[str]:
    """Simulator plusargs need a leading '+' (TestDef holds them bare)."""
    return [a if a.startswith("+") else "+" + a for a in items]


def write_summary(results: list[RunResult], args) -> None:
    run_dir: Path = args.run_dir
    passed = sum(1 for r in results if r.passed)
    failed = len(results) - passed

    # ---- CSV -------------------------------------------------------------
    with (run_dir / "summary.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "test", "seed", "result", "returncode", "uvm_errors", "uvm_fatals",
            "sva_failures", "blocks", "checked", "mismatches",
            "block_cov", "digest_cov", "event_cov", "overall_cov", "log",
        ])
        for r in results:
            w.writerow([
                r.test, r.seed, "PASS" if r.passed else "FAIL", r.returncode,
                r.uvm_errors, r.uvm_fatals, r.sva_failures, r.blocks,
                r.checked, r.failed_checks, f"{r.block_cov:.2f}",
                f"{r.digest_cov:.2f}", f"{r.event_cov:.2f}",
                f"{r.overall_cov:.2f}", r.log.name if r.log else "",
            ])

    # ---- Markdown --------------------------------------------------------
    with (run_dir / "summary.md").open("w") as f:
        f.write(f"# SHA-256 UVM regression\n\n")
        f.write(f"- Date: {datetime.now().isoformat(timespec='seconds')}\n")
        f.write(f"- Simulator: `{args.sim}`\n")
        f.write(f"- Seeds: {', '.join(str(s) for s in args.seeds)}\n")
        f.write(f"- Tests: {len(results)} runs, **{passed} passed, {failed} failed**\n\n")
        f.write("| Test | Seed | Result | Blocks | Checked | Mismatches | "
                "Block cov | Digest cov | Event cov | Overall |\n")
        f.write("|---|---:|---|---:|---:|---:|---:|---:|---:|---:|\n")
        for r in results:
            f.write(
                f"| {r.test} | {r.seed} | {'PASS' if r.passed else 'FAIL'} | "
                f"{r.blocks} | {r.checked} | {r.failed_checks} | "
                f"{r.block_cov:.1f}% | {r.digest_cov:.1f}% | "
                f"{r.event_cov:.1f}% | {r.overall_cov:.1f}% |\n"
            )
        if results:
            avg = sum(r.overall_cov for r in results) / len(results)
            f.write(f"\nAverage functional coverage: **{avg:.2f}%**\n")

    # ---- Console ---------------------------------------------------------
    header = ["TEST", "SEED", "RESULT", "BLOCKS", "CHECKED", "ERRORS",
              "BLOCK%", "DIGEST%", "EVENT%", "OVERALL%"]
    widths = [26, 5, 7, 7, 8, 7, 7, 8, 7, 9]
    print()
    print("-" * 108)
    print(_fmt_row(header, widths))
    print("-" * 108)
    for r in results:
        print(_fmt_row([
            r.test, str(r.seed), "PASS" if r.passed else "FAIL",
            str(r.blocks), str(r.checked), str(r.uvm_errors + r.sva_failures),
            f"{r.block_cov:.1f}", f"{r.digest_cov:.1f}",
            f"{r.event_cov:.1f}", f"{r.overall_cov:.1f}",
        ], widths))
    print("-" * 108)
    print(f"TOTAL: {passed}/{len(results)} passed, {failed} failed")

    if results:
        covs = [r.overall_cov for r in results if r.checked > 0]
        if covs:
            print(f"FUNCTIONAL COVERAGE: avg {sum(covs)/len(covs):.2f}%  "
                  f"min {min(covs):.2f}%  max {max(covs):.2f}%")
    print(f"Results written to: {run_dir}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Build and run the SHA-256 UVM regression",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument("--sim", default="auto",
                   choices=["auto", *BACKENDS.keys()],
                   help="simulator backend (default: auto-detect)")
    p.add_argument("--uvm-home", default=os.environ.get("UVM_HOME"),
                   help="path to the UVM src/ directory (or set $UVM_HOME)")
    p.add_argument("--verilator", default=shutil.which("verilator") or "verilator",
                   help="verilator executable")
    p.add_argument("--seeds", nargs="+", type=int, default=[1],
                   help="random seeds (default: 1)")
    p.add_argument("--tests", default="default",
                   help="comma-separated test names, 'default', or 'all'")
    p.add_argument("--include-slow", action="store_true",
                   help="include sha256_million_a_test")
    p.add_argument("--timeout", type=int, default=300,
                   help="per-run timeout in seconds (default: 300)")
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 4,
                   help="parallel build jobs (default: all cores)")
    p.add_argument("--waves", action="store_true",
                   help="Verilator: build with --trace and dump VCD")
    p.add_argument("--selfcheck", action="store_true",
                   help="run one KAT with +ERROR_INJECT=1 and expect it to FAIL")
    p.add_argument("--dry-run", action="store_true",
                   help="print commands without building or running")
    p.add_argument("--run-dir", default=None,
                   help="results directory (default: results/<timestamp>)")
    return p.parse_args(argv)


def select_tests(args) -> list[TestDef]:
    if args.tests == "all":
        names = list(TESTS.keys())
    elif args.tests == "default":
        names = list(DEFAULT_TEST_ORDER)
        if args.include_slow:
            names.append("sha256_million_a_test")
    else:
        names = [n.strip() for n in args.tests.split(",") if n.strip()]
    unknown = [n for n in names if n not in TESTS]
    if unknown:
        raise SystemExit(f"Unknown test(s): {', '.join(unknown)}\n"
                         f"Known: {', '.join(TESTS)}")
    return [TESTS[n] for n in names]


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    if args.sim == "auto":
        detected = detect_simulator()
        if not detected:
            print("ERROR: no supported simulator found on PATH "
                  "(verilator, vsim+vlog, vcs, xrun)")
            return 2
        args.sim = detected

    if not args.uvm_home:
        for cand in DEFAULT_UVM_CANDIDATES:
            if (cand / "uvm_pkg.sv").exists():
                args.uvm_home = str(cand)
                break
    if args.uvm_home:
        args.uvm_home = str(Path(args.uvm_home).expanduser().resolve())
        if not (Path(args.uvm_home) / "uvm_pkg.sv").exists():
            print(f"ERROR: uvm_pkg.sv not found in --uvm-home {args.uvm_home}")
            return 2

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    args.run_dir = Path(args.run_dir) if args.run_dir else (
        PROJECT_ROOT / "results" / stamp
    )
    if not args.dry_run:
        args.run_dir.mkdir(parents=True, exist_ok=True)

    tests = select_tests(args)
    results: list[RunResult] = []

    print("=" * 108)
    print(" SHA-256 UVM regression")
    print(f" simulator : {args.sim}")
    print(f" uvm home  : {args.uvm_home or '(simulator built-in)'}")
    print(f" tests     : {', '.join(t.name for t in tests)}")
    print(f" seeds     : {', '.join(str(s) for s in args.seeds)}")
    print("=" * 108)

    backend: Backend = BACKENDS[args.sim](args)
    if not backend.build():
        return 2
    if args.dry_run:
        print("Dry run: build command shown above; no simulation was run.")
        return 0

    total = len(tests) * len(args.seeds)
    idx = 0
    for test in tests:
        for seed in args.seeds:
            idx += 1
            label = f"{test.name} seed={seed}"
            print(f"[{idx}/{total}] {label} ... ", end="", flush=True)
            log_path = args.run_dir / f"{test.name}_seed{seed}.log"
            rc = backend.run(test, seed, [], args.timeout, log_path)
            text = log_path.read_text(errors="replace") if log_path.exists() else ""
            parsed = parse_log(text)

            passed = (
                rc == 0
                and parsed["passed_marker"]
                and not parsed["failed_marker"]
                and parsed["uvm_errors"] == 0
                and parsed["uvm_fatals"] == 0
                and parsed["sva_failures"] == 0
                and parsed["checked"] > 0
                and parsed["failed"] == 0
            )
            note = ""
            if rc == 124:
                note = "timeout"
            elif rc == 127:
                note = "command not found"
            elif parsed["failed_marker"]:
                note = "test reported FAIL"

            results.append(RunResult(
                test=test.name, seed=seed, passed=passed, returncode=rc,
                uvm_errors=parsed["uvm_errors"],
                uvm_fatals=parsed["uvm_fatals"],
                sva_failures=parsed["sva_failures"],
                blocks=parsed["blocks"], checked=parsed["checked"],
                failed_checks=parsed["failed"],
                block_cov=parsed["block_cov"],
                digest_cov=parsed["digest_cov"],
                event_cov=parsed["event_cov"],
                overall_cov=parsed["overall_cov"],
                log=log_path, note=note,
            ))
            status = "PASS" if passed else "FAIL"
            extra = f" [{note}]" if note else ""
            print(f"{status}{extra}  checked={parsed['checked']}  "
                  f"cov={parsed['overall_cov']:.1f}%")

    # ------------------------------------------------------------------
    # Negative self-check: prove the scoreboard detects a bad digest.
    # ------------------------------------------------------------------
    selfcheck_ok = True
    if args.selfcheck:
        print("\nNegative self-check: KAT + intentionally corrupted expected digest ... ",
              end="", flush=True)
        log_path = args.run_dir / "selfcheck_error_inject.log"
        rc = backend.run(TESTS["sha256_kat_test"], 1, ["ERROR_INJECT=1"],
                         args.timeout, log_path)
        text = log_path.read_text(errors="replace") if log_path.exists() else ""
        detected = bool(re.search(r"DIGEST MISMATCH", text)) and \
            "SHA256_TEST_RESULT: FAIL" in text
        selfcheck_ok = detected
        print("PASS (mismatch detected)" if detected
              else "FAIL (scoreboard did not detect the error)")

    write_summary(results, args)

    failed = sum(1 for r in results if not r.passed)
    if args.selfcheck and not selfcheck_ok:
        failed += 1
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
