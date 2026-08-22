#!/usr/bin/env python3
"""PT-01~04 launch reach and collision-energy acceptance runner."""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST = "res://pipeline/tests/p1_physics_tuning_test.gd"
CORE = (
    ROOT / "src/core/sim/sim_world.gd",
    ROOT / "src/core/sim/sim_collision.gd",
    ROOT / "src/core/battle/launch_limits.gd",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    project = args.project.resolve()
    failures: list[str] = []
    for source in CORE:
        path = project / source.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        if re.search(r"^extends\s+(?:Node|Node2D|SceneTree)\b", text, re.MULTILINE):
            failures.append(f"{path.name}: engine inheritance forbidden")
        for token in ("RandomNumberGenerator", "PhysicsServer2D", "RigidBody2D"):
            if token in text:
                failures.append(f"{path.name}: forbidden token {token}")
    if failures:
        print("\n".join(f"[FAIL] {item}" for item in failures))
        return 1
    print("[PASS] P1 physics tuning core boundary")
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("P1_PHYSICS_TUNING_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] Godot unavailable: {args.godot!r}", file=sys.stderr)
        return 2
    imported = godot_test_support.run_godot(
        godot, project, "--import", log_name="godot-p1-physics-tuning-import.log"
    )
    if imported.returncode:
        print((imported.stdout + imported.stderr)[-12000:], file=sys.stderr)
        return 2
    result = godot_test_support.run_godot(
        godot, project, "--script", TEST,
        log_name="godot-p1-physics-tuning-test.log", timeout=180
    )
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if line.startswith(("[PASS]", "[FAIL]")):
            print(f"  {line}")
    if result.returncode == 0 and "P1_PHYSICS_TUNING_RESULT: PASS" in output:
        print("P1_PHYSICS_TUNING_RUNNER_RESULT: PASS")
        return 0
    print(output[-12000:], file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
