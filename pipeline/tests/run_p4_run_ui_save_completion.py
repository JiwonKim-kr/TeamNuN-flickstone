#!/usr/bin/env python3
"""P4-6 run completion, persistence transaction, and route narrow runner."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path

import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST_SCRIPT = "res://pipeline/tests/p4_run_ui_save_completion_test.gd"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(argv)
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("[SKIP] GODOT-P4-6 explicitly skipped by verify --skip-godot")
        print("P4_RUN_UI_SAVE_COMPLETION_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}")
        return 2
    project = args.project.resolve()
    base = godot_test_support.run_godot(
        godot, project, "--script", TEST_SCRIPT,
        log_name="godot-p4-run-ui-save-completion.log", timeout=90,
    )

    def quick(case: tuple[int, int]):
        seed, route = case
        return godot_test_support.run_godot(
            godot, project, "--script", TEST_SCRIPT, "--",
            f"--quick-seed={seed}", f"--quick-route={route}",
            log_name=f"godot-p4-run-quick-{seed}-{route}.log", timeout=360,
        )

    cases = [(seed, route) for seed in (1, 2) for route in (0, 1)]
    with ThreadPoolExecutor(max_workers=4) as executor:
        quick_results = list(executor.map(quick, cases))
    results = [base, *quick_results]
    output = "\n".join(result.stdout + result.stderr for result in results)
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in checks:
        print(line)
    if all(result.returncode == 0 and "P4_RUN_UI_SAVE_COMPLETION_RESULT: PASS" in result.stdout + result.stderr for result in results) and not any(line.startswith("[FAIL]") for line in checks):
        print(f"P4_RUN_UI_SAVE_COMPLETION_RUNNER_RESULT: PASS ({len(checks)} grouped checks)")
        return 0
    print(output[-16000:])
    print("P4_RUN_UI_SAVE_COMPLETION_RUNNER_RESULT: FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
