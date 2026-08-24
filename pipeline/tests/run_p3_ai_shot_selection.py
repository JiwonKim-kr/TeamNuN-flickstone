#!/usr/bin/env python3
from __future__ import annotations
import argparse, os, subprocess, sys
from pathlib import Path
import godot_test_support

ROOT = Path(__file__).resolve().parents[2]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    project = args.project.resolve()
    reference = subprocess.run(
        [sys.executable, str(project / "pipeline/tests/p3_ai_shot_selection_reference.py")],
        cwd=project, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=300,
    )
    print(reference.stdout.strip())
    if reference.returncode != 0:
        print(reference.stderr.strip(), file=sys.stderr)
        return 1
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("[SKIP] GODOT-P3 explicitly skipped")
        return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print("[FAIL] GODOT-BIN executable not found", file=sys.stderr); return 2
    result = godot_test_support.run_godot(godot, project, "--script", "res://pipeline/tests/p3_ai_shot_selection_test.gd", log_name="godot-p3-ai.log", timeout=300)
    output = result.stdout + result.stderr
    for line in output.splitlines():
        if line.startswith(("[PASS]", "[FAIL]", "P3_AI_BENCHMARK_MS:")): print(line)
    ok = result.returncode == 0 and "P3_AI_SHOT_SELECTION_RESULT: PASS" in output
    if not ok: print(output[-20000:], file=sys.stderr)
    print("P3_AI_SHOT_SELECTION_RUNNER_RESULT: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1

if __name__ == "__main__": raise SystemExit(main())
