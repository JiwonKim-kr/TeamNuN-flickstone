#!/usr/bin/env python3
"""P1-5 graybox case, CSV, golden, and snapshot-restore runner."""
from __future__ import annotations
import argparse, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline/scripts"))
from p1_batch_sim import BatchRow, expand_cases, golden_value, load_fixture, read_goldens, update_goldens, write_csv, write_repro

TEST = "res://pipeline/tests/p1_batch_sim_graybox_test.gd"
FIXTURE = ROOT / "pipeline/tests/fixtures/p1_graybox_cases.json"
GOLDENS = ROOT / "pipeline/tests/fixtures/p1_graybox_goldens.json"
ROW_RE = re.compile(r"P1_BATCH_ROW:" + ",".join([r"(\d+)"] * 11) + r",([0-9a-f]{64})")
FAILURE_RE = re.compile(r"P1_BATCH_FAILURE:(\d+),(\d+)")

class CaseFailure(RuntimeError):
    def __init__(self, message: str, case, code: int, operation: int, repro: str):
        super().__init__(message); self.case = case; self.code = code; self.operation = operation; self.repro = repro

def run_case(godot: str, project: Path, fixture_id: str, batch_id: str, case) -> BatchRow:
    arguments = ["--script", TEST, "--", f"--seed-hi={case.seed_hi}", f"--seed-lo={case.seed_lo}", f"--restore-after-turn={case.restore_after_turn}"]
    if case.insertion_variant == 1: arguments.append("--reverse")
    result = godot_test_support.run_godot(godot, project, *arguments, log_name=f"godot-p1-batch-case-{case.case_id}.log", timeout=900)
    output = result.stdout + result.stderr
    match = ROW_RE.search(output)
    if result.returncode or "P1_BATCH_SIM_GRAYBOX_RESULT: PASS" not in output or match is None:
        failure = FAILURE_RE.search(output)
        repro = project / f"pipeline/artifacts/p1_batch/repro_{case.case_id}.json"
        code = int(failure.group(1)) if failure else 0; operation = int(failure.group(2)) if failure else 0
        write_repro(repro, fixture_id, case, "godot_case", code, operation)
        relative = str(repro.relative_to(project)).replace("\\", "/")
        print(output[-12000:], file=sys.stderr); raise CaseFailure(f"case {case.case_id} failed; repro={relative}", case, code, operation, relative)
    values = match.groups()
    print(next(line for line in output.splitlines() if line.startswith("[PASS] P1-5-BASELINE")))
    return BatchRow(1, batch_id, case.case_id, fixture_id, case.seed_hi, case.seed_lo, case.insertion_variant, case.restore_after_turn, int(values[0]), int(values[1]), int(values[2]), int(values[3]), int(values[4]), player_damage=int(values[5]), enemy_damage=int(values[6]), damage_destroyed=int(values[7]), kill_boundary_destroyed=int(values[8]), kill_zone_destroyed=int(values[9]), forced_settle_count=int(values[10]), terminal_hash=values[11])

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--case-id", type=int, action="append")
    parser.add_argument("--narrow", action="store_true", help="deprecated alias for --mode narrow")
    parser.add_argument("--mode", choices=("narrow", "batch", "exhaustive"), default="narrow")
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    parser.add_argument("--keep-going", action="store_true")
    parser.add_argument("--output-csv", type=Path)
    parser.add_argument("--update-goldens", action="store_true")
    parser.add_argument("--approval-ref")
    args = parser.parse_args()
    if args.narrow: args.mode = "narrow"
    if args.jobs < 1 or args.jobs > 16: print("[FAIL] --jobs must be 1..16", file=sys.stderr); return 2
    if args.update_goldens and (args.case_id or args.mode != "narrow"):
        print("[FAIL] golden update requires the complete narrow case set", file=sys.stderr); return 2
    project = args.project.resolve()
    for name in ("p1_graybox_fixture.gd", "p1_deterministic_shot_supplier.gd", "p1_battle_driver.gd", "p1_battle_report.gd"):
        text = (project / "src/core/battle" / name).read_text(encoding="utf-8")
        for token in ("extends Node", "RandomNumberGenerator", "FileAccess", "JSON"):
            if token in text: print(f"[FAIL] {name}: forbidden {token}"); return 1
    reference = subprocess.run([sys.executable, str(project / "pipeline/tests/p1_batch_reference.py")], cwd=project, text=True, capture_output=True)
    print(reference.stdout.strip())
    if reference.returncode: print(reference.stderr, file=sys.stderr); return 1
    fixture_id, cases = load_fixture(project / FIXTURE.relative_to(ROOT))
    if args.case_id:
        selected_ids = set(args.case_id); selected = [item for item in cases if item.case_id in selected_ids]
        if len(selected) != len(selected_ids): print("[FAIL] unknown case id", file=sys.stderr); return 2
        batch_id = "selected"
    else:
        count = {"narrow": 16, "batch": 256, "exhaustive": 1000}[args.mode]
        selected = expand_cases(cases, count)
        batch_id = args.mode
    if args.update_goldens and (os.environ.get("CI") or not args.approval_ref): print("[FAIL] golden update requires --approval-ref and is forbidden in CI", file=sys.stderr); return 2
    if os.environ.get("ARTIFICER_SKIP_GODOT_TESTS") == "1": print("P1_BATCH_SIM_GRAYBOX_RUNNER_RESULT: PASS (Godot skipped explicitly)"); return 0
    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None: print("[FAIL] Godot unavailable", file=sys.stderr); return 2
    imported = godot_test_support.run_godot(godot, project, "--import", log_name="godot-p1-batch-import.log")
    if imported.returncode: print((imported.stdout + imported.stderr)[-12000:], file=sys.stderr); return 2
    rows: list[BatchRow] = []
    failures: list[str] = []
    with ThreadPoolExecutor(max_workers=min(args.jobs, len(selected))) as pool:
        futures = {pool.submit(run_case, godot, project, fixture_id, batch_id, item): item for item in selected}
        for future in as_completed(futures):
            try: rows.append(future.result())
            except CaseFailure as exc:
                failures.append(str(exc))
                if args.keep_going:
                    rows.append(BatchRow(1, batch_id, exc.case.case_id, fixture_id, exc.case.seed_hi, exc.case.seed_lo, exc.case.insertion_variant, exc.case.restore_after_turn, 0, 0, 0, 0, 0, failure_code=exc.code, failure_operation=exc.operation, repro_file=exc.repro))
                if not args.keep_going:
                    for pending in futures: pending.cancel()
                    break
    if failures and not args.keep_going:
        print("\n".join(f"[FAIL] {item}" for item in failures), file=sys.stderr); return 1
    rows.sort(key=lambda item: item.case_id)
    if failures:
        if args.output_csv: write_csv(args.output_csv, rows)
        print("\n".join(f"[FAIL] {item}" for item in failures), file=sys.stderr)
        print(f"P1_BATCH_SUMMARY battles={len(rows)} victory={sum(row.result == 1 for row in rows)} defeat={sum(row.result == 2 for row in rows)} draw={sum(row.result == 3 for row in rows)} failures={len(failures)} turns_min=0 turns_median=0 turns_max=0 sim_ticks={sum(row.sim_tick_count for row in rows)} forced={sum(row.forced_settle_count > 0 for row in rows)}")
        print("P1_BATCH_SIM_GRAYBOX_RUNNER_RESULT: FAIL"); return 1
    if args.update_goldens:
        for line in update_goldens(project / GOLDENS.relative_to(ROOT), rows, args.approval_ref or "", ci=False): print(line)
    else:
        expected = read_goldens(project / GOLDENS.relative_to(ROOT))
        for row in rows:
            if row.failure_code != 0: continue
            golden_id = ((row.case_id - 1) % len(cases)) + 1
            actual = golden_value(row); actual["case_id"] = golden_id
            if expected.get(golden_id) != actual:
                repro = project / f"pipeline/artifacts/p1_batch/repro_{row.case_id}.json"
                case = next(item for item in selected if item.case_id == row.case_id)
                write_repro(repro, fixture_id, case, "golden_compare", 34, 108)
                print(f"[FAIL] golden mismatch case {row.case_id}; repro={repro.relative_to(project)}", file=sys.stderr); return 1
    if args.output_csv: write_csv(args.output_csv, rows)
    turns = sorted(row.turn_count for row in rows)
    minimum = turns[0] if turns else 0; median = turns[(len(turns)-1)//2] if turns else 0; maximum = turns[-1] if turns else 0
    print(f"P1_BATCH_SUMMARY battles={len(rows)} victory={sum(row.result == 1 for row in rows)} defeat={sum(row.result == 2 for row in rows)} draw={sum(row.result == 3 for row in rows)} failures={len(failures)} turns_min={minimum} turns_median={median} turns_max={maximum} sim_ticks={sum(row.sim_tick_count for row in rows)} forced={sum(row.forced_settle_count > 0 for row in rows)}")
    print("P1_BATCH_SIM_GRAYBOX_RUNNER_RESULT: PASS"); return 0

if __name__ == "__main__": raise SystemExit(main())
