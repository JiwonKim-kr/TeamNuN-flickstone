#!/usr/bin/env python3
"""P2-6 runtime content, data-driven graybox, determinism, and batch runner."""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
from pathlib import Path

import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST_SCRIPT = "res://pipeline/tests/p2_content_graybox_test.gd"
GOLDEN = ROOT / "pipeline" / "tests" / "fixtures" / "p2_content_graybox_goldens.json"
FINGERPRINT = "f556a6e8c162e62ad2df3a90ab006f52aeefecbadc204f1f204307aaf124965f"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument(
        "--profile",
        choices=("quick", "milestone"),
        default=os.environ.get("FLICKSTONE_P2_CONTENT_PROFILE", "quick"),
        help="quick checks seed 0 for each preset; milestone checks the full 16x2 terminal matrix",
    )
    parser.add_argument("--update-goldens", action="store_true")
    parser.add_argument("--approval-ref")
    args = parser.parse_args(argv)
    if args.update_goldens and (
        args.profile != "milestone" or not args.approval_ref or os.environ.get("CI")
    ):
        print("[FAIL] golden update requires milestone, --approval-ref, and non-CI", file=sys.stderr)
        return 2
    project = args.project.resolve()

    reference = subprocess.run(
        [sys.executable, str(project / "pipeline/tests/p2_content_graybox_reference.py")],
        cwd=project,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=300,
    )
    print(reference.stdout.strip())
    if reference.returncode != 0:
        print(reference.stderr.strip(), file=sys.stderr)
        print("P2_CONTENT_GRAYBOX_RUNNER_RESULT: FAIL")
        return 1

    controller = (project / "src/ui/battle/p2_content_graybox.gd").read_text(encoding="utf-8")
    p1_controller = (project / "src/ui/battle/p1_graybox_battle.gd").read_text(encoding="utf-8")
    forbidden_ids = ("baduk_stone", "bottle_cap", "graybox_striker", "graybox_opening_haste", "graybox_haste")
    if any(value in controller for value in forbidden_ids):
        print("[FAIL] P2-6-ARCH graybox controller contains content-ID-specific behavior")
        return 1
    print("[PASS] P2-6-ARCH controller has no content-ID-specific branch")
    for label, source in (("P1", p1_controller), ("P2", controller)):
        launch_handler = source.split("func _on_launch_requested", 1)[1].split("func _clear_aim", 1)[0]
        if "Thread.PRIORITY_LOW" not in source or "wait_to_finish" in launch_handler:
            print(f"[FAIL] P2-6-PREDICTION-PRIORITY-{label} low-priority/non-join contract missing")
            return 1
    print("[PASS] P2-6-PREDICTION-PRIORITY P1/P2 low-priority worker and non-join launch")

    manifest = json.loads((project / "pipeline/manifest.json").read_text(encoding="utf-8"))
    expected_requests = {
        "art:sprites/p1_graybox_player_piece": "scenes/p2_content_graybox.tscn::Battlefield/Pieces",
        "art:sprites/p1_graybox_enemy_piece": "scenes/p2_content_graybox.tscn::Battlefield/Pieces",
        "art:ui/p1_graybox_aim_marker": "scenes/p2_content_graybox.tscn::Battlefield/AimLayer",
    }
    entries = {entry["id"]: entry for entry in manifest["entries"]}
    for entry_id, path in expected_requests.items():
        requests = entries.get(entry_id, {}).get("requested_by", [])
        if {"kind": "scene_node", "path": path} not in requests:
            print(f"[FAIL] P2-6-MANIFEST missing requested_by: {entry_id} -> {path}")
            return 1
    print("[PASS] P2-6-MANIFEST existing placeholders declare P2 consumers")

    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1":
        print("[SKIP] GODOT-P2-6 explicitly skipped by verify --skip-godot")
        print("P2_CONTENT_GRAYBOX_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0

    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    result = godot_test_support.run_godot(
        godot,
        project,
        "--script",
        TEST_SCRIPT,
        log_name="godot-p2-content-graybox.log",
        timeout=300,
    )
    output = result.stdout + result.stderr
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in checks:
        print(line)
    failed = [line for line in checks if line.startswith("[FAIL]")]
    if result.returncode != 0 or "P2_CONTENT_GRAYBOX_RESULT: PASS" not in output or failed:
        print(output.strip()[-20000:], file=sys.stderr)
        print("P2_CONTENT_GRAYBOX_RUNNER_RESULT: FAIL (narrow)")
        return 1

    def run_case(preset: str, seed_index: int, restore_after_turn: int) -> tuple[str, int, int, dict, str]:
        case_result = godot_test_support.run_godot(
            godot,
            project,
            "--script",
            TEST_SCRIPT,
            "--",
            f"--terminal-case={preset}:{seed_index}:{restore_after_turn}",
            log_name=f"godot-p2-content-graybox-{preset}-{seed_index}-{restore_after_turn}.log",
            timeout=300,
        )
        case_output = case_result.stdout + case_result.stderr
        row_line = next((line for line in case_output.splitlines() if line.startswith("P2_CONTENT_GRAYBOX_CASE:")), "")
        row = json.loads(row_line.split(":", 1)[1]) if row_line else {}
        if case_result.returncode != 0 or not row:
            return preset, seed_index, restore_after_turn, {}, case_output[-12000:]
        return preset, seed_index, restore_after_turn, row, ""

    seed_indices = range(16) if args.profile == "milestone" else range(1)
    print(f"[INFO] P2-6 terminal profile: {args.profile}")
    cases = [(preset, seed_index, 0) for preset in ("default", "stacked") for seed_index in seed_indices]
    cases.extend((preset, 0, 1) for preset in ("default", "stacked"))
    case_results: list[tuple[str, int, int, dict, str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(run_case, *case) for case in cases]
        for future in concurrent.futures.as_completed(futures):
            case_results.append(future.result())
    failed_cases = [item for item in case_results if not item[3]]
    if failed_cases:
        for preset, seed_index, restore_after_turn, _row, diagnostic in failed_cases:
            print(f"[FAIL] P2-6-TERMINAL-CASE {preset}/{seed_index}/restore={restore_after_turn}", file=sys.stderr)
            print(diagnostic, file=sys.stderr)
        print("P2_CONTENT_GRAYBOX_RUNNER_RESULT: FAIL (terminal batch)")
        return 1
    normal = {(preset, seed_index): row for preset, seed_index, restore, row, _ in case_results if restore == 0}
    restored = {(preset, seed_index): row for preset, seed_index, restore, row, _ in case_results if restore > 0}
    restore_ok = all(restored[(preset, 0)] == normal[(preset, 0)] for preset in ("default", "stacked"))
    terminal_label = "16X2" if args.profile == "milestone" else "QUICK-2"
    print(f"[PASS] P2-6-TERMINAL-{terminal_label}-SNAPSHOT-RESTORE" if restore_ok else "[FAIL] P2-6-TERMINAL snapshot restore changed row")
    rows = [normal[(preset, seed_index)] for preset in ("default", "stacked") for seed_index in seed_indices]
    if args.update_goldens:
        payload = {
            "schema_version": 1,
            "fingerprint": FINGERPRINT,
            "approval_ref": args.approval_ref,
            "rows": rows,
        }
        GOLDEN.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"[PASS] P2-6-GOLDEN updated approval_ref={args.approval_ref}")
    if not GOLDEN.is_file():
        print(f"[FAIL] P2-6-GOLDEN missing: {GOLDEN}")
        if args.profile == "milestone":
            print("P2_CONTENT_GRAYBOX_CANDIDATE_GOLDEN:" + json.dumps({"schema_version": 1, "fingerprint": FINGERPRINT, "rows": rows}, ensure_ascii=False, separators=(",", ":")))
        return 1
    golden = json.loads(GOLDEN.read_text(encoding="utf-8"))
    golden_rows = golden.get("rows", [])
    golden_map = {(row.get("preset"), row.get("seed_index")): row for row in golden_rows}
    expected_keys = {(preset, seed_index) for preset in ("default", "stacked") for seed_index in range(16)}
    def gameplay_row(row: dict) -> dict:
        return {key: value for key, value in row.items() if key != "terminal_hash"}
    rows_match = all(
        golden_map.get((row["preset"], row["seed_index"])) == row
        if args.profile == "milestone"
        else gameplay_row(golden_map.get((row["preset"], row["seed_index"]), {})) == gameplay_row(row)
        for row in rows
    )
    golden_ok = (
        golden.get("schema_version") == 1
        and golden.get("fingerprint") == FINGERPRINT
        and len(golden_rows) == 32
        and set(golden_map) == expected_keys
        and rows_match
    )
    golden_label = "16x2 exact" if args.profile == "milestone" else "seed-0 gameplay subset (snapshot hash refresh deferred)"
    print(f"[PASS] P2-6-GOLDEN {golden_label} terminal rows" if golden_ok else "[FAIL] P2-6-GOLDEN terminal rows changed")
    if not golden_ok and args.profile == "milestone":
        print("P2_CONTENT_GRAYBOX_CANDIDATE_GOLDEN:" + json.dumps({"schema_version": 1, "fingerprint": FINGERPRINT, "rows": rows}, ensure_ascii=False, separators=(",", ":")))
    if restore_ok and golden_ok:
        print(f"P2_CONTENT_GRAYBOX_RUNNER_RESULT: PASS ({len(checks) + 2} grouped checks)")
        return 0
    print(output.strip()[-20000:], file=sys.stderr)
    print("P2_CONTENT_GRAYBOX_RUNNER_RESULT: FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
