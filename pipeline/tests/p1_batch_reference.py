#!/usr/bin/env python3
from __future__ import annotations
import csv, json, tempfile
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from p1_batch_sim import BatchRow, CSV_COLUMNS, expand_cases, load_fixture, update_goldens, write_csv, write_repro

ROOT = Path(__file__).resolve().parents[2]
fixture_path = ROOT / "pipeline/tests/fixtures/p1_graybox_cases.json"
fixture_id, cases = load_fixture(fixture_path)
assert fixture_id == "p1_graybox_v2" and len(cases) == 16
assert len(expand_cases(cases, 16)) == 16
assert len(expand_cases(cases, 256)) == 256
assert len(expand_cases(cases, 1000)) == 1000
row = BatchRow(1, "reference", cases[0].case_id, fixture_id, cases[0].seed_hi, cases[0].seed_lo, 0, 0, 1, 52, 17171, 1, 0, terminal_hash="a" * 64)
with tempfile.TemporaryDirectory() as directory:
    invalid = json.loads(fixture_path.read_text(encoding="utf-8"))
    invalid["combatants"][1]["position"] = invalid["combatants"][0]["position"]
    invalid_path = Path(directory) / "invalid.json"; invalid_path.write_text(json.dumps(invalid), encoding="utf-8")
    try: load_fixture(invalid_path)
    except ValueError: pass
    else: raise AssertionError("overlapping fixture accepted")
    output = Path(directory) / "rows.csv"; write_csv(output, [row])
    raw = output.read_bytes(); assert b"\r\n" not in raw and raw.endswith(b"\n")
    assert next(csv.reader(output.read_text(encoding="utf-8").splitlines())) == CSV_COLUMNS
    try: update_goldens(Path(directory) / "g.json", [row], "", ci=False)
    except ValueError: pass
    else: raise AssertionError("empty approval ref accepted")
    try: update_goldens(Path(directory) / "g.json", [row], "P1-5", ci=True)
    except ValueError: pass
    else: raise AssertionError("CI golden update accepted")
    changes = update_goldens(Path(directory) / "g.json", [row], "P1-5", ci=False)
    assert len(changes) == 1 and "old=null" in changes[0] and "new=" in changes[0]
    repro = Path(directory) / "repro.json"
    write_repro(repro, fixture_id, cases[0], "golden_compare", 34, 108)
    payload = json.loads(repro.read_text(encoding="utf-8"))
    assert payload["failure_code"] == 34 and payload["failure_operation"] == 108
print("[PASS] P1-5 fixture/CSV/golden independent contract")
