#!/usr/bin/env python3
"""P1-2 launch, aim quantization, and trajectory prediction runner."""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import godot_test_support
import p1_launch_reference

ROOT = Path(__file__).resolve().parents[2]
TEST = "res://pipeline/tests/p1_launch_aim_prediction_test.gd"
CORE = (
    "launch_limits.gd", "launch_command.gd", "aim_quantizer.gd",
    "launch_velocity_solver.gd", "trajectory_point.gd",
    "trajectory_prediction.gd", "trajectory_predictor.gd",
)


def static_checks(project: Path) -> list[str]:
    failures: list[str] = []
    forbidden = ("RandomNumberGenerator", "PhysicsServer2D", "RigidBody2D", "atan2", "Vector2.angle(", "angle_to(")
    for name in CORE:
        path = project / "src" / "core" / "battle" / name
        if not path.is_file():
            failures.append(f"missing: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        if re.search(r"^extends\s+(?:Node|Node2D|SceneTree)\b", text, re.MULTILINE):
            failures.append(f"{name}: engine inheritance forbidden")
        for token in forbidden:
            if token in text:
                failures.append(f"{name}: forbidden token {token}")
    status_text = (project / "src" / "core" / "sim" / "sim_status.gd").read_text(encoding="utf-8")
    for value in range(83, 90):
        if f"= {value}" not in status_text:
            failures.append(f"missing append-only operation {value}")
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
    print("[PASS] P1-2 deterministic core boundary")
    p1_launch_reference.self_check()
    p1_launch_reference.check_fixture(project / "pipeline" / "tests" / "fixtures" / "p1_launch_vectors.json")
    print("[PASS] independent Python KAT and fixture")
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("P1_LAUNCH_AIM_PREDICTION_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    imported = godot_test_support.run_godot(godot, project, "--import", log_name="godot-p1-launch-import.log")
    if imported.returncode:
        print((imported.stdout + imported.stderr)[-12000:], file=sys.stderr)
        return 2
    result = godot_test_support.run_godot(godot, project, "--script", TEST, log_name="godot-p1-launch-test.log")
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if line.startswith(("[PASS]", "[FAIL]")):
            print(f"  {line}")
    if result.returncode == 0 and "P1_LAUNCH_AIM_PREDICTION_RESULT: PASS" in output:
        print("P1_LAUNCH_AIM_PREDICTION_RUNNER_RESULT: PASS")
        return 0
    print(output[-12000:], file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
