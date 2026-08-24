#!/usr/bin/env python3
"""P1-1 CTB/BattleState acceptance runner."""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

import godot_test_support
import p1_ctb_reference

ROOT = Path(__file__).resolve().parents[2]
TEST = "res://pipeline/tests/p1_ctb_battle_state_test.gd"
CORE = (
    "battle_limits.gd", "battle_participant.gd", "battle_mutation_request.gd",
    "ctb_preview_entry.gd", "ctb_scheduler.gd", "resolve_pacing_policy.gd", "battle_state.gd", "battle_snapshot.gd",
)


def static_checks(project: Path) -> list[str]:
    failures: list[str] = []
    for name in CORE:
        path = project / "src" / "core" / "battle" / name
        if not path.is_file():
            failures.append(f"missing: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        if re.search(r"^extends\s+(?:Node|Node2D|SceneTree)\b", text, re.MULTILINE):
            failures.append(f"{name}: engine inheritance forbidden")
        for token in ("RandomNumberGenerator", "PhysicsServer2D", "RigidBody2D"):
            if token in text: failures.append(f"{name}: forbidden token {token}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    project = args.project.resolve()
    failures = static_checks(project)
    if failures:
        print("\n".join(f"[FAIL] {item}" for item in failures))
        return 1
    print("[PASS] P1-1 core boundary")
    p1_ctb_reference.self_check()
    p1_ctb_reference.check_fixture(project / "pipeline" / "tests" / "fixtures" / "p1_ctb_vectors.json")
    print("[PASS] independent Python KAT and fixture")
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("P1_CTB_BATTLE_STATE_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    imported = godot_test_support.run_godot(godot, project, "--import", log_name="godot-p1-ctb-import.log")
    if imported.returncode:
        print((imported.stdout + imported.stderr)[-8000:], file=sys.stderr); return 2
    result = godot_test_support.run_godot(godot, project, "--script", TEST, log_name="godot-p1-ctb-test.log")
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if line.startswith(("[PASS]", "[FAIL]")): print(f"  {line}")
    if result.returncode == 0 and "P1_CTB_BATTLE_STATE_RESULT: PASS" in output:
        print("P1_CTB_BATTLE_STATE_RUNNER_RESULT: PASS")
        return 0
    print(output[-8000:], file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
