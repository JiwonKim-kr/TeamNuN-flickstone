#!/usr/bin/env python3
"""P0-2 SimBody/SimZone/SimEvent/SimWorld acceptance runner."""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

import godot_test_support


REPO_ROOT = Path(__file__).resolve().parents[2]
TEST_SCRIPT = "res://pipeline/tests/p0_sim_world_test.gd"
SKIP_GODOT_ENV = "ARTIFICER_SKIP_GODOT_TESTS"
CORE_FILES = (
    "sim_body.gd",
    "sim_zone.gd",
    "sim_event.gd",
    "sim_world.gd",
)


def _check_core_boundary(project: Path) -> list[str]:
    failures: list[str] = []
    sim_dir = project / "src" / "core" / "sim"
    for name in CORE_FILES:
        path = sim_dir / name
        if not path.is_file():
            failures.append(f"missing core file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        if re.search(r"^extends\s+(?:Node|Node2D|RigidBody2D)\b", text, re.MULTILINE):
            failures.append(f"{name}: engine Node inheritance is forbidden")
        for forbidden in ("RandomNumberGenerator", "PhysicsServer2D", "RigidBody2D"):
            if forbidden in text:
                failures.append(f"{name}: Godot API token {forbidden!r} is forbidden")

    event_path = sim_dir / "sim_event.gd"
    if event_path.is_file():
        event_text = event_path.read_text(encoding="utf-8")
        dynamic_field = re.search(
            r"^\s*var\s+\w+\s*:\s*(Dictionary|Variant|String)\b",
            event_text,
            re.MULTILINE,
        )
        if dynamic_field:
            failures.append(
                "sim_event.gd: dynamic payload field "
                f"{dynamic_field.group(1)!r} is forbidden"
            )
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=REPO_ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(argv)
    project = args.project.resolve()

    print("=" * 68)
    print("P0-2 acceptance: SimBody / SimZone / SimEvent / SimWorld")
    print(f"project: {project}")
    print("=" * 68)

    boundary_failures = _check_core_boundary(project)
    if boundary_failures:
        print("[FAIL] CORE-BOUNDARY engine-independent simulation contract")
        for failure in boundary_failures:
            print(f"  {failure}")
        print("P0_SIM_WORLD_RUNNER_RESULT: FAIL")
        return 1
    print("[PASS] CORE-BOUNDARY engine-independent simulation contract")

    if os.environ.get(SKIP_GODOT_ENV) == "1":
        print("[SKIP] GODOT-P0-2 explicitly skipped by verify --skip-godot")
        print("P0_SIM_WORLD_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0

    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        print("P0_SIM_WORLD_RUNNER_RESULT: ERROR")
        return 2

    try:
        imported = godot_test_support.run_godot(
            godot,
            project,
            "--import",
            log_name="godot-p0-sim-world-import.log",
        )
    except subprocess.TimeoutExpired:
        print("[FAIL] GODOT-IMPORT timeout", file=sys.stderr)
        return 2
    if imported.returncode != 0:
        print("[FAIL] GODOT-IMPORT")
        print((imported.stdout + imported.stderr).strip()[-4000:])
        return 2
    print("[PASS] GODOT-IMPORT")

    try:
        result = godot_test_support.run_godot(
            godot,
            project,
            "--script",
            TEST_SCRIPT,
            log_name="godot-p0-sim-world-test.log",
        )
    except subprocess.TimeoutExpired:
        print("[FAIL] GODOT-P0-2 timeout", file=sys.stderr)
        return 2

    output = result.stdout + result.stderr
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in checks:
        print(f"  {line}")
    marker_ok = "P0_SIM_WORLD_RESULT: PASS" in output
    failed_checks = [line for line in checks if line.startswith("[FAIL]")]
    if result.returncode == 0 and marker_ok and not failed_checks:
        print(f"P0_SIM_WORLD_RUNNER_RESULT: PASS ({len(checks)} grouped checks)")
        return 0

    print(
        "P0_SIM_WORLD_RUNNER_RESULT: FAIL "
        f"(exit={result.returncode}, marker={marker_ok}, failed={len(failed_checks)})"
    )
    print(output.strip()[-6000:], file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
