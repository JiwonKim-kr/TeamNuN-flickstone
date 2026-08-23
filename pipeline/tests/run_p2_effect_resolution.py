#!/usr/bin/env python3
"""P2-2 typed effect resolution narrow runner."""
from __future__ import annotations
import argparse, os, subprocess, sys
from pathlib import Path
import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST = "res://pipeline/tests/p2_effect_resolution_test.gd"

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(); project = args.project.resolve()
    reference = subprocess.run([sys.executable, str(project / "pipeline/tests/p2_effect_resolution_reference.py")], cwd=project, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=300)
    print(reference.stdout.strip())
    if reference.returncode: print(reference.stderr.strip(), file=sys.stderr); print("P2_EFFECT_RESOLUTION_RUNNER_RESULT: FAIL"); return 1
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1": print("P2_EFFECT_RESOLUTION_RUNNER_RESULT: PASS (Godot skipped explicitly)"); return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None: print("[FAIL] Godot unavailable", file=sys.stderr); return 2
    imported = godot_test_support.run_godot(godot, project, "--import", log_name="godot-p2-effect-resolution-import.log")
    if imported.returncode: print((imported.stdout + imported.stderr)[-12000:], file=sys.stderr); return 2
    result = godot_test_support.run_godot(godot, project, "--script", TEST, log_name="godot-p2-effect-resolution-test.log", timeout=300)
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if line.startswith(("[PASS]", "[FAIL]")): print(line)
    if result.returncode == 0 and "P2_EFFECT_RESOLUTION_RESULT: PASS" in output: print("P2_EFFECT_RESOLUTION_RUNNER_RESULT: PASS"); return 0
    print(output[-12000:], file=sys.stderr); print("P2_EFFECT_RESOLUTION_RUNNER_RESULT: FAIL"); return 1

if __name__ == "__main__": raise SystemExit(main())
