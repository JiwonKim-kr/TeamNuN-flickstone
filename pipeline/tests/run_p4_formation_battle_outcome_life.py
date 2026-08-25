#!/usr/bin/env python3
"""P4-3 formation, battle request/outcome, and life runner."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST_SCRIPT = "res://pipeline/tests/p4_formation_battle_outcome_life_test.gd"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(argv)
    project = args.project.resolve()
    reference = subprocess.run(
        [sys.executable, str(project / "pipeline/tests/p4_formation_battle_outcome_life_reference.py")],
        cwd=project, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=60,
    )
    print(reference.stdout.strip())
    if reference.returncode != 0:
        print(reference.stderr.strip(), file=sys.stderr)
        print("P4_FORMATION_BATTLE_OUTCOME_LIFE_RUNNER_RESULT: FAIL")
        return 1
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("[SKIP] GODOT-P4-3 explicitly skipped by verify --skip-godot")
        print("P4_FORMATION_BATTLE_OUTCOME_LIFE_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    result = godot_test_support.run_godot(godot, project, "--script", TEST_SCRIPT, log_name="godot-p4-formation-battle-outcome-life.log", timeout=300)
    output = result.stdout + result.stderr
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in checks: print(line)
    if result.returncode == 0 and "P4_FORMATION_BATTLE_OUTCOME_LIFE_RESULT: PASS" in output and not any(line.startswith("[FAIL]") for line in checks):
        print(f"P4_FORMATION_BATTLE_OUTCOME_LIFE_RUNNER_RESULT: PASS ({len(checks)} grouped checks)")
        return 0
    print(output.strip()[-16000:], file=sys.stderr)
    print("P4_FORMATION_BATTLE_OUTCOME_LIFE_RUNNER_RESULT: FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
