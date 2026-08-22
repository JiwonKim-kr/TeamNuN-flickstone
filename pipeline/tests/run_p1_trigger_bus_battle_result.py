#!/usr/bin/env python3
"""P1-4 trigger bus, motion credit, RNG, snapshot, and result runner."""
from __future__ import annotations

import argparse
import os
import re
import sys
import subprocess
from pathlib import Path

import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST = "res://pipeline/tests/p1_trigger_bus_battle_result_test.gd"
CORE = (
    "battle_trigger_id.gd", "battle_trigger_record.gd", "battle_trigger_bus.gd",
    "battle_motion_credit.gd", "battle_result.gd", "battle_result_resolver.gd",
    "battle_random.gd", "battle_state.gd", "battle_snapshot.gd",
)


def static_checks(project: Path) -> list[str]:
    failures: list[str] = []
    forbidden = (
        "RandomNumberGenerator",
        "PhysicsServer2D",
        "RigidBody2D",
        "randf(",
        "randi(",
        "extends Node",
    )
    battle = project / "src" / "core" / "battle"
    for name in CORE:
        path = battle / name
        if not path.is_file():
            failures.append(f"missing: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            if token in text:
                failures.append(f"{name}: forbidden token {token}")

    trigger_path = battle / "battle_trigger_id.gd"
    if trigger_path.is_file():
        trigger_text = trigger_path.read_text(encoding="utf-8")
        expected = (
            "PASSIVE",
            "ON_BATTLE_START",
            "ON_TURN_START",
            "ON_LAUNCH",
            "ON_HIT_DEAL",
            "ON_HIT_TAKE",
            "ON_ALLY_COLLIDE",
            "ON_WALL_BOUNCE",
            "ON_MOVING",
            "ON_DEATH_SELF",
            "ON_KILL",
            "ON_TURN_END",
            "ON_BATTLE_END",
        )
        for value, name in enumerate(expected, 1):
            if not re.search(rf"^\s*{name}\s*=\s*{value},\s*$", trigger_text, re.MULTILINE):
                failures.append(f"trigger id mismatch: {name}={value}")

    status_path = project / "src" / "core" / "sim" / "sim_status.gd"
    status_text = status_path.read_text(encoding="utf-8")
    for contract in (
        "INVALID_TRIGGER_RECORD = 28",
        "TRIGGER_LIMIT_EXCEEDED = 29",
        "INVALID_MOTION_CREDIT = 30",
        "INVALID_BATTLE_RESULT = 31",
        "TRIGGER_RECORD_CREATE = 97",
        "BATTLE_RANDOM = 103",
    ):
        if contract not in status_text:
            failures.append(f"missing append-only diagnostic: {contract}")
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
    print("[PASS] P1-4 deterministic core boundary")

    reference = subprocess.run(
        [sys.executable, str(project / "pipeline/tests/p1_trigger_reference.py")],
        cwd=project, text=True, capture_output=True,
    )
    print(reference.stdout.strip())
    if reference.returncode:
        print(reference.stderr, file=sys.stderr)
        return 1

    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("P1_TRIGGER_BUS_BATTLE_RESULT_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0

    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    imported = godot_test_support.run_godot(
        godot, project, "--import", log_name="godot-p1-trigger-import.log"
    )
    if imported.returncode:
        print((imported.stdout + imported.stderr)[-12000:], file=sys.stderr)
        return 2
    result = godot_test_support.run_godot(
        godot, project, "--script", TEST, log_name="godot-p1-trigger-test.log"
    )
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if line.startswith(("[PASS]", "[FAIL]")):
            print(f"  {line}")
    if result.returncode == 0 and "P1_TRIGGER_BUS_BATTLE_RESULT_RESULT: PASS" in output:
        print("P1_TRIGGER_BUS_BATTLE_RESULT_RUNNER_RESULT: PASS")
        return 0
    print(output[-12000:], file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
