#!/usr/bin/env python3
"""P1-5 graybox baseline and deterministic core boundary."""
from __future__ import annotations
import argparse, os, sys
from pathlib import Path
import godot_test_support
ROOT = Path(__file__).resolve().parents[2]
TEST = "res://pipeline/tests/p1_batch_sim_graybox_test.gd"

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    for name in ("p1_graybox_fixture.gd", "p1_deterministic_shot_supplier.gd", "p1_battle_driver.gd", "p1_battle_report.gd"):
        text = (args.project / "src/core/battle" / name).read_text(encoding="utf-8")
        for token in ("extends Node", "RandomNumberGenerator", "FileAccess", "JSON"):
            if token in text: print(f"[FAIL] {name}: forbidden {token}"); return 1
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1": print("P1_BATCH_SIM_GRAYBOX_RUNNER_RESULT: PASS (Godot skipped explicitly)"); return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None: print("[FAIL] Godot unavailable", file=sys.stderr); return 2
    imported = godot_test_support.run_godot(godot, args.project, "--import", log_name="godot-p1-batch-import.log")
    if imported.returncode: print((imported.stdout + imported.stderr)[-12000:], file=sys.stderr); return 2
    result = godot_test_support.run_godot(godot, args.project, "--script", TEST, log_name="godot-p1-batch-test.log", timeout=900)
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if line.startswith(("[PASS]", "[FAIL]", "P1_BATCH_ROW:")): print(line)
    if result.returncode == 0 and "P1_BATCH_SIM_GRAYBOX_RESULT: PASS" in output:
        print("P1_BATCH_SIM_GRAYBOX_RUNNER_RESULT: PASS"); return 0
    print(output[-12000:], file=sys.stderr); return 1

if __name__ == "__main__": raise SystemExit(main())
