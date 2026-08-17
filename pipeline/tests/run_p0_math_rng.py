#!/usr/bin/env python3
"""P0-1 FixMath/FixVec2/fixed-trig/SimRng acceptance runner."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

import godot_test_support
import p0_rng_reference


REPO_ROOT = Path(__file__).resolve().parents[2]
TEST_SCRIPT = "res://pipeline/tests/p0_math_rng_test.gd"
SKIP_GODOT_ENV = "ARTIFICER_SKIP_GODOT_TESTS"


def _run_python_stage(command: list[str], label: str) -> bool:
    try:
        result = subprocess.run(
            command,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=300,
        )
    except subprocess.TimeoutExpired:
        print(f"[FAIL] {label}: timeout")
        return False
    if result.returncode != 0:
        print(f"[FAIL] {label}")
        print((result.stdout + result.stderr).strip()[-2000:])
        return False
    print(f"[PASS] {label}")
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=REPO_ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(argv)
    project = args.project.resolve()

    print("=" * 68)
    print("P0-1 acceptance: FixMath / FixVec2 / FixTrigLut / SimRng")
    print(f"project: {project}")
    print("=" * 68)

    fixture = project / "pipeline" / "tests" / "fixtures" / "p0_rng_vectors.json"
    fixture_ok = p0_rng_reference.main(["--fixture", str(fixture)]) == 0
    if fixture_ok:
        print("[PASS] PY-RNG-REFERENCE checked fixture matches independent Python")
    else:
        print("[FAIL] PY-RNG-REFERENCE checked fixture mismatch")

    lut_ok = _run_python_stage(
        [sys.executable, str(project / "src" / "tools" / "generate_fix_trig_lut.py"), "--check"],
        "PY-LUT-REPRO generated LUT is byte-for-byte current",
    )
    if not fixture_ok or not lut_ok:
        print("P0_MATH_RNG_RUNNER_RESULT: FAIL")
        return 1

    if os.environ.get(SKIP_GODOT_ENV) == "1":
        print("[SKIP] GODOT-P0-1 explicitly skipped by verify --skip-godot")
        print("P0_MATH_RNG_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0

    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        print("P0_MATH_RNG_RUNNER_RESULT: ERROR")
        return 2

    try:
        version = godot_test_support.run_version(godot)
    except subprocess.TimeoutExpired:
        print("[FAIL] GODOT-VERSION timeout", file=sys.stderr)
        return 2
    version_text = (version.stdout or version.stderr).strip()
    if version.returncode != 0 or not version_text.startswith("4.6"):
        print(f"[FAIL] GODOT-VERSION expected 4.6.x, actual={version_text!r}")
        return 2
    print(f"[PASS] GODOT-VERSION {version_text}")

    try:
        imported = godot_test_support.run_godot(
            godot,
            project,
            "--import",
            log_name="godot-p0-math-rng-import.log",
        )
    except subprocess.TimeoutExpired:
        print("[FAIL] GODOT-IMPORT timeout", file=sys.stderr)
        return 2
    if imported.returncode != 0:
        print("[FAIL] GODOT-IMPORT")
        print((imported.stdout + imported.stderr).strip()[-3000:])
        return 2
    print("[PASS] GODOT-IMPORT")

    try:
        result = godot_test_support.run_godot(
            godot,
            project,
            "--script",
            TEST_SCRIPT,
            log_name="godot-p0-math-rng-test.log",
        )
    except subprocess.TimeoutExpired:
        print("[FAIL] GODOT-P0-1 timeout", file=sys.stderr)
        return 2

    output = result.stdout + result.stderr
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in checks:
        print(f"  {line}")
    marker_ok = "P0_MATH_RNG_RESULT: PASS" in output
    failed_checks = [line for line in checks if line.startswith("[FAIL]")]
    if result.returncode == 0 and marker_ok and not failed_checks:
        print(f"P0_MATH_RNG_RUNNER_RESULT: PASS ({len(checks)} grouped checks)")
        return 0

    print(
        "P0_MATH_RNG_RUNNER_RESULT: FAIL "
        f"(exit={result.returncode}, marker={marker_ok}, failed={len(failed_checks)})"
    )
    if not checks:
        print(output.strip()[-4000:], file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
