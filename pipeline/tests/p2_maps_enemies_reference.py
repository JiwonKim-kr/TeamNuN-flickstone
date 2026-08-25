#!/usr/bin/env python3
"""Independent P2-5 maps, enemies, canonical v5, and geometry known answers."""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "scripts"))
from content_catalog import ContentError, load_catalog  # noqa: E402

FIXTURE = ROOT / "pipeline" / "tests" / "fixtures" / "p2_maps_enemies"
EXPECTED = "d103ee1c2f313c34cc90e00c38e401ac7a3a2b8aa1af69cd8d4303842338bfe5"


def mutate(file_name: str, callback) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="flickstone-p2-maps-") as temporary:
        root = Path(temporary) / "fixture"
        shutil.copytree(FIXTURE, root)
        path = root / file_name
        value = json.loads(path.read_text(encoding="utf-8"))
        callback(value)
        path.write_text(json.dumps(value, separators=(",", ":")), encoding="utf-8")
        try:
            catalog = load_catalog(root)
        except ContentError as exc:
            return False, str(exc)
        return True, catalog.fingerprint.hex()


def main() -> int:
    catalog = load_catalog(FIXTURE)
    assert catalog.fingerprint.hex() == EXPECTED
    assert len(catalog.maps) == 1 and [zone.local_id for zone in catalog.maps[0].zones] == [2, 10]
    assert len(catalog.enemies) == 1 and catalog.enemies[0].override.presence_mask == 0x93

    ok, reordered = mutate("maps.json", lambda value: value["records"][0]["zones"].reverse())
    assert ok and reordered == EXPECTED
    ok, slot_reordered = mutate("maps.json", lambda value: value["records"][0]["player_slots"].reverse())
    assert ok and slot_reordered != EXPECTED
    ok, _ = mutate("enemies.json", lambda value: value["records"][0]["override"].update({"unknown": 1}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["player_slots"][0].update({"x_raw": 40 * 65536}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["boundary_vertices"].reverse())
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0].update({"boundary_vertices": value["records"][0]["boundary_vertices"][:2]}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0].update({"boundary_vertices": value["records"][0]["boundary_vertices"] * 17}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["zones"][0].update({"local_id": 0}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["zones"][0].update({"local_id": value["records"][0]["zones"][1]["local_id"]}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["zones"][0].update({"flags": 1}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["obstacles"].append({"reserved": True}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0].update({"deploy_count": 2}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0].update({"deploy_count": 6}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["player_slots"][0].update({"x_raw": 256 * 65536, "y_raw": 304 * 65536}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["player_slots"][0].update({"x_raw": 400 * 65536, "y_raw": 96 * 65536}))
    assert ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["player_slots"][0].update({"x_raw": 500 * 65536, "y_raw": 96 * 65536}))
    assert not ok
    ok, _ = mutate("enemies.json", lambda value: value["records"][0]["override"].update({"max_hp": 0}))
    assert not ok
    ok, _ = mutate("enemies.json", lambda value: value["records"][0]["override"].update({"radius_raw": 128 * 65536}))
    assert not ok
    ok, _ = mutate("abilities.json", lambda value: value["records"][0]["effects"][0]["zone"].update({"vertices": value["records"][0]["effects"][0]["zone"]["vertices"][:2]}))
    assert not ok
    ok, _ = mutate("abilities.json", lambda value: value["records"][0]["effects"][0]["zone"].update({"duration_turns": 1024}))
    assert ok
    ok, _ = mutate("abilities.json", lambda value: value["records"][0]["effects"][0]["zone"].update({"duration_turns": 1025}))
    assert not ok
    ok, changed_presence = mutate("enemies.json", lambda value: value["records"][0]["override"].pop("max_hp"))
    assert ok and changed_presence != EXPECTED
    ok, changed_ability_presence = mutate("enemies.json", lambda value: value["records"][0]["override"].pop("ability_refs"))
    assert ok and changed_ability_presence != EXPECTED

    print("[PASS] P2-5-PY-SCHEMA maps/enemies exact records and override whitelist")
    print("[PASS] P2-5-PY-GEOMETRY boundary, clearance, slots, and zone limits")
    print("[PASS] P2-5-PY-CANONICAL v5 ordering and override presence mask KAT")
    print("P2_MAPS_ENEMIES_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ContentError, OSError) as exc:
        print(f"P2_MAPS_ENEMIES_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
