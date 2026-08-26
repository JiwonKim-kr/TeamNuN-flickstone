#!/usr/bin/env python3
"""P5 submission first-play and five-minute-flow narrow runner."""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST_SCENE = "res://pipeline/tests/p5_first_play_five_minute_flow_test.tscn"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(argv)
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("P5_FIRST_PLAY_FIVE_MINUTE_FLOW_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    result = godot_test_support.run_godot(
        godot,
        args.project.resolve(),
        TEST_SCENE,
        log_name="godot-p5-first-play-five-minute-flow.log",
        timeout=120,
    )
    output = result.stdout + result.stderr
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in checks:
        print(line)
    if result.returncode == 0 and "P5_FIRST_PLAY_FIVE_MINUTE_FLOW_RESULT: PASS" in output and not any(line.startswith("[FAIL]") for line in checks):
        print(f"P5_FIRST_PLAY_FIVE_MINUTE_FLOW_RUNNER_RESULT: PASS ({len(checks)} checks)")
        return 0
    print(output[-16000:], file=sys.stderr)
    print("P5_FIRST_PLAY_FIVE_MINUTE_FLOW_RUNNER_RESULT: FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
