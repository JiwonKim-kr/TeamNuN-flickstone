#!/usr/bin/env python3
from __future__ import annotations
import csv, json, tempfile
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from p1_batch_sim import BatchRow, CSV_COLUMNS, load_fixture, update_goldens, write_csv

ROOT = Path(__file__).resolve().parents[2]
fixture_id, cases = load_fixture(ROOT / "pipeline/tests/fixtures/p1_graybox_cases.json")
assert fixture_id == "p1_graybox_v1" and len(cases) == 3
row = BatchRow(1, "reference", cases[0].case_id, fixture_id, cases[0].seed_hi, cases[0].seed_lo, 0, 0, 1, 52, 17171, 1, 0, terminal_hash="a" * 64)
with tempfile.TemporaryDirectory() as directory:
    output = Path(directory) / "rows.csv"; write_csv(output, [row])
    raw = output.read_bytes(); assert b"\r\n" not in raw and raw.endswith(b"\n")
    assert next(csv.reader(output.read_text(encoding="utf-8").splitlines())) == CSV_COLUMNS
    try: update_goldens(Path(directory) / "g.json", [row], "", ci=False)
    except ValueError: pass
    else: raise AssertionError("empty approval ref accepted")
    try: update_goldens(Path(directory) / "g.json", [row], "P1-5", ci=True)
    except ValueError: pass
    else: raise AssertionError("CI golden update accepted")
print("[PASS] P1-5 fixture/CSV/golden independent contract")
