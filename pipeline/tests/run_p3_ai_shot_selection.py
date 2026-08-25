#!/usr/bin/env python3
from __future__ import annotations
import argparse, os, subprocess, sys
from pathlib import Path
import godot_test_support

ROOT = Path(__file__).resolve().parents[2]

def check_review_mode_contract(project: Path) -> bool:
    controller_path = project / "src/ui/battle/p2_content_graybox.gd"
    controller = controller_path.read_text(encoding="utf-8")
    required_fragments = {
        "COMMON default": "var _ai_review_grade_id: int = AiGrade.Value.COMMON",
        "COMMON key": "KEY_F1, KEY_7:",
        "ELITE key": "KEY_F2, KEY_8:",
        "BOSS key": "KEY_F3, KEY_9:",
        "COMMON selection": "select_ai_review_grade(AiGrade.Value.COMMON)",
        "ELITE selection": "select_ai_review_grade(AiGrade.Value.ELITE)",
        "BOSS selection": "select_ai_review_grade(AiGrade.Value.BOSS)",
        "AI selector override": "if _run_mode else _ai_review_grade_id",
        "run grade source": "enemy.ai_grade_id()",
        "HUD grade": '"P3 AI 검수 %s',
        "grade assignment": "_ai_review_grade_id = grade_id",
        "same-board restart": "\t_restart()",
    }
    missing = [name for name, fragment in required_fragments.items() if fragment not in controller]
    if missing:
        print(
            "[FAIL] P3-REVIEW-MODE missing UI contract: " + ", ".join(missing),
            file=sys.stderr,
        )
        return False
    print("[PASS] P3-REVIEW-MODE COMMON/ELITE/BOSS controls and restart contract")
    return True

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
    if not check_review_mode_contract(project):
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
