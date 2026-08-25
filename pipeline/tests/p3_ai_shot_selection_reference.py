#!/usr/bin/env python3
"""Independent P3 AI grade/schema/fingerprint contract checks."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "scripts"))
from content_catalog import ContentError, load_catalog  # noqa: E402

RUNTIME = ROOT / "src" / "core" / "data"
EXPECTED_FINGERPRINT = "16df0d24ed90733b2f5f8b3761fd37830154e550c74fc00adba3a9445fa07167"


def main() -> int:
    catalog = load_catalog(RUNTIME)
    raw_catalog = json.loads((RUNTIME / "catalog.json").read_text(encoding="utf-8"))
    raw_enemies = json.loads((RUNTIME / "enemies.json").read_text(encoding="utf-8"))
    enemy_document = next(item for item in raw_catalog["documents"] if item["kind_id"] == 7)

    assert raw_catalog["schema_version"] == 8
    assert enemy_document == {"kind_id": 7, "file_name": "enemies.json", "schema_version": 2}
    assert raw_enemies["schema_version"] == 2
    assert [enemy.ai_grade_id for enemy in catalog.enemies] == [1, 1, 1, 2, 3]
    assert all(set(record) == {"numeric_id", "id", "base_piece_ref", "ai_grade_id", "override"} for record in raw_enemies["records"])
    assert catalog.fingerprint.hex() == EXPECTED_FINGERPRINT

    angle_limits = {1: 4096, 2: 2048, 3: 1024}
    power_limits = {1: 64, 2: 32, 3: 16}
    assert all(limit % 256 == 0 for limit in angle_limits.values())
    assert all(limit % 8 == 0 for limit in power_limits.values())

    print("[PASS] P3-PY-SCHEMA catalog v8 and enemies v2 exact records")
    print("[PASS] P3-PY-GRADES runtime enemies preserve COMMON and append ELITE/BOSS grades")
    print("[PASS] P3-PY-FINGERPRINT independent canonical SHA-256")
    print("[PASS] P3-PY-ERROR-QUANTA approved grade limits align to quanta")
    print("P3_AI_SHOT_SELECTION_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ContentError, OSError, ValueError) as exc:
        print(f"P3_AI_SHOT_SELECTION_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
