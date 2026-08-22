#!/usr/bin/env python3
"""P1-5 graybox case, CSV, golden, and snapshot-restore runner."""
from __future__ import annotations
import argparse, os, re, subprocess, sys
from pathlib import Path
import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline/scripts"))
from p1_batch_sim import BatchRow, golden_value, load_fixture, read_goldens, update_goldens, write_csv

TEST = "res://pipeline/tests/p1_batch_sim_graybox_test.gd"
FIXTURE = ROOT / "pipeline/tests/fixtures/p1_graybox_cases.json"
GOLDENS = ROOT / "pipeline/tests/fixtures/p1_graybox_goldens.json"
ROW_RE = re.compile(r"P1_BATCH_ROW:(\d+),(\d+),(\d+),(\d+),(\d+),(\d+),([0-9a-f]{64})")

def run_case(godot: str, project: Path, fixture_id: str, case) -> BatchRow:
    arguments = ["--script", TEST, "--", f"--seed-hi={case.seed_hi}", f"--seed-lo={case.seed_lo}", f"--restore-after-turn={case.restore_after_turn}"]
    if case.insertion_variant == 1: arguments.append("--reverse")
    result = godot_test_support.run_godot(godot, project, *arguments, log_name=f"godot-p1-batch-case-{case.case_id}.log", timeout=900)
    output = result.stdout + result.stderr
    match = ROW_RE.search(output)
    if result.returncode or "P1_BATCH_SIM_GRAYBOX_RESULT: PASS" not in output or match is None:
        print(output[-12000:], file=sys.stderr); raise RuntimeError(f"case {case.case_id} failed")
    values = match.groups()
    print(next(line for line in output.splitlines() if line.startswith("[PASS] P1-5-BASELINE")))
    return BatchRow(1, "narrow", case.case_id, fixture_id, case.seed_hi, case.seed_lo, case.insertion_variant, case.restore_after_turn, int(values[0]), int(values[1]), int(values[2]), int(values[3]), int(values[4]), forced_settle_count=int(values[5]), terminal_hash=values[6])

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--case-id", type=int, action="append")
    parser.add_argument("--narrow", action="store_true", help="run every checked-in case")
    parser.add_argument("--output-csv", type=Path)
    parser.add_argument("--update-goldens", action="store_true")
    parser.add_argument("--approval-ref")
    args = parser.parse_args()
    project = args.project.resolve()
    for name in ("p1_graybox_fixture.gd", "p1_deterministic_shot_supplier.gd", "p1_battle_driver.gd", "p1_battle_report.gd"):
        text = (project / "src/core/battle" / name).read_text(encoding="utf-8")
        for token in ("extends Node", "RandomNumberGenerator", "FileAccess", "JSON"):
            if token in text: print(f"[FAIL] {name}: forbidden {token}"); return 1
    reference = subprocess.run([sys.executable, str(project / "pipeline/tests/p1_batch_reference.py")], cwd=project, text=True, capture_output=True)
    print(reference.stdout.strip())
    if reference.returncode: print(reference.stderr, file=sys.stderr); return 1
    fixture_id, cases = load_fixture(project / FIXTURE.relative_to(ROOT))
    selected_ids = {item.case_id for item in cases} if args.narrow else set(args.case_id or [1])
    selected = [item for item in cases if item.case_id in selected_ids]
    if len(selected) != len(selected_ids): print("[FAIL] unknown case id", file=sys.stderr); return 2
    if args.update_goldens and (os.environ.get("CI") or not args.approval_ref): print("[FAIL] golden update requires --approval-ref and is forbidden in CI", file=sys.stderr); return 2
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1": print("P1_BATCH_SIM_GRAYBOX_RUNNER_RESULT: PASS (Godot skipped explicitly)"); return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None: print("[FAIL] Godot unavailable", file=sys.stderr); return 2
    imported = godot_test_support.run_godot(godot, project, "--import", log_name="godot-p1-batch-import.log")
    if imported.returncode: print((imported.stdout + imported.stderr)[-12000:], file=sys.stderr); return 2
    try: rows = [run_case(godot, project, fixture_id, item) for item in selected]
    except RuntimeError as exc: print(f"[FAIL] {exc}", file=sys.stderr); return 1
    if args.update_goldens:
        update_goldens(project / GOLDENS.relative_to(ROOT), rows, args.approval_ref or "", ci=False)
    else:
        expected = read_goldens(project / GOLDENS.relative_to(ROOT))
        for row in rows:
            if expected.get(row.case_id) != golden_value(row): print(f"[FAIL] golden mismatch case {row.case_id}", file=sys.stderr); return 1
    if args.output_csv: write_csv(args.output_csv, rows)
    turns = sorted(row.turn_count for row in rows)
    print(f"P1_BATCH_SUMMARY battles={len(rows)} victory={sum(row.result == 1 for row in rows)} defeat={sum(row.result == 2 for row in rows)} draw={sum(row.result == 3 for row in rows)} failures=0 turns_min={turns[0]} turns_median={turns[(len(turns)-1)//2]} turns_max={turns[-1]} sim_ticks={sum(row.sim_tick_count for row in rows)} forced={sum(row.forced_settle_count > 0 for row in rows)}")
    print("P1_BATCH_SIM_GRAYBOX_RUNNER_RESULT: PASS"); return 0

if __name__ == "__main__": raise SystemExit(main())
