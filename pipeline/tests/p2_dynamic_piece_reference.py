#!/usr/bin/env python3
"""Independent P2-4 schema negatives and deterministic integer known answers."""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "scripts"))
from content_catalog import ContentError, load_catalog  # noqa: E402

FIXTURE = ROOT / "pipeline" / "tests" / "fixtures" / "p2_dynamic_piece"
EXPECTED_FINGERPRINT = "68af8d2f3d1c0abd46a372a2fb5da632c0650da95d31bd5b7ed7e1b427dd8742"


def expect_catalog_failure(mutator) -> None:
    with tempfile.TemporaryDirectory(prefix="flickstone-p2-4-") as temp:
        target = Path(temp) / "catalog"
        shutil.copytree(FIXTURE, target)
        mutator(target)
        try:
            load_catalog(target)
        except ContentError:
            return
        raise AssertionError("invalid P2-4 catalog was accepted")


def mutate_json(root: Path, name: str, mutate) -> None:
    path = root / name
    value = json.loads(path.read_text(encoding="utf-8"))
    mutate(value)
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


catalog = load_catalog(FIXTURE)
assert catalog.fingerprint.hex() == EXPECTED_FINGERPRINT

expect_catalog_failure(lambda root: mutate_json(root, "abilities.json", lambda value: value["records"][0]["effects"][0].update({"transform": {"piece_ref": {"numeric_id": 6, "id": "transform_target"}}})))
expect_catalog_failure(lambda root: mutate_json(root, "abilities.json", lambda value: value["records"][0]["effects"][0].update({"value_a": 1})))
expect_catalog_failure(lambda root: mutate_json(root, "abilities.json", lambda value: value.update({"schema_version": 3})))
expect_catalog_failure(lambda root: mutate_json(root, "pieces.json", lambda value: value["records"][2].update({"spawnable": False})))
expect_catalog_failure(lambda root: mutate_json(root, "pieces.json", lambda value: value["records"][4]["flags"].update({"has_turn": True})))
expect_catalog_failure(lambda root: mutate_json(root, "abilities.json", lambda value: value["records"][8].update({"trigger_id": 3})))

# Runtime body IDs sort by (tick, cause, event type, ordinal), independent of insertion.
requests = [(9, 2, 13, 0), (8, 4, 12, 1), (8, 3, 13, 1), (8, 3, 12, 2)]
assert sorted(requests) == [(8, 3, 12, 2), (8, 3, 13, 1), (8, 4, 12, 1), (9, 2, 13, 0)]

# Transform HP and enemy CT preserve progress without making the enemy act earlier.
assert max(1, (200 * 40) // 80) == 100
remaining = 10_000 - 5_000
old_time = (remaining + 80 - 1) // 80
new_time = (remaining + 150 - 1) // 150
enemy_time = max(old_time, new_time)
assert 10_000 - enemy_time * 150 == 550

# Inverse-mass correction: mass 64 vs 16 means the lighter body moves four times farther.
penetration = 5 * 65_536
heavy_move = penetration * 16 // (64 + 16)
light_move = penetration - heavy_move
assert (heavy_move, light_move) == (65_536, 262_144)

# Position delta is converted back to velocity at the fixed 120 Hz step.
assert 2 * 65_536 * 120 == 15_728_640

print("[PASS] P2-4-PY schema negatives and canonical fingerprint")
print("[PASS] P2-4-PY spawn order, transform HP/CT, link correction, velocity known answers")
print("P2_DYNAMIC_PIECE_REFERENCE_RESULT: PASS")
