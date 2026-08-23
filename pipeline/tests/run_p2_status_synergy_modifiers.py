#!/usr/bin/env python3
"""P2-3 status, synergy, modifier, and snapshot v5 runner."""
from __future__ import annotations
import argparse, os, subprocess, sys
from pathlib import Path
import godot_test_support

ROOT = Path(__file__).resolve().parents[2]

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(); project = args.project.resolve()
    reference = subprocess.run([sys.executable, str(project / "pipeline/tests/p2_status_synergy_reference.py")], cwd=project, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=300)
    print(reference.stdout.strip())
    if reference.returncode != 0: print(reference.stderr.strip(), file=sys.stderr); return 1
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1": print("P2_STATUS_SYNERGY_RUNNER_RESULT: PASS (Godot skipped explicitly)"); return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None: print("Godot executable not found", file=sys.stderr); return 2
    result = godot_test_support.run_godot(godot, project, "--script", "res://pipeline/tests/p2_status_synergy_modifiers_test.gd", timeout=300, log_name="godot-p2-status-synergy.log")
    print((result.stdout + result.stderr).strip())
    ok = result.returncode == 0 and "P2_STATUS_SYNERGY_MODIFIERS_RESULT: PASS" in result.stdout
    print("P2_STATUS_SYNERGY_RUNNER_RESULT: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1

if __name__ == "__main__": raise SystemExit(main())
