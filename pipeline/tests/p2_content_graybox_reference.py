#!/usr/bin/env python3
"""Independent P2-6 runtime package, schema, geometry, and fingerprint checks."""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "scripts"))
from content_catalog import ContentError, load_catalog  # noqa: E402

RUNTIME = ROOT / "src" / "core" / "data"
EXPECTED_FINGERPRINT = "f556a6e8c162e62ad2df3a90ab006f52aeefecbadc204f1f204307aaf124965f"


def mutate(file_name: str, callback) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="flickstone-p2-graybox-") as temporary:
        fixture = Path(temporary) / "data"
        shutil.copytree(RUNTIME, fixture)
        path = fixture / file_name
        value = json.loads(path.read_text(encoding="utf-8"))
        callback(value)
        path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        try:
            catalog = load_catalog(fixture)
        except ContentError as exc:
            return False, str(exc)
        return True, catalog.fingerprint.hex()


def mutate_package(callback) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="flickstone-p2-graybox-package-") as temporary:
        fixture = Path(temporary) / "data"
        shutil.copytree(RUNTIME, fixture)
        callback(fixture)
        try:
            catalog = load_catalog(fixture)
        except ContentError as exc:
            return False, str(exc)
        return True, catalog.fingerprint.hex()


def set_enemy_radius_and_slot(root: Path, slot_x_raw: int) -> None:
    enemies_path = root / "enemies.json"
    enemies = json.loads(enemies_path.read_text(encoding="utf-8"))
    enemies["records"][0]["override"]["radius_raw"] = 48 * 65536
    enemies_path.write_text(json.dumps(enemies, separators=(",", ":")), encoding="utf-8")
    maps_path = root / "maps.json"
    maps = json.loads(maps_path.read_text(encoding="utf-8"))
    maps["records"][0]["player_slots"][0].update({"x_raw": slot_x_raw, "y_raw": 700 * 65536})
    maps_path.write_text(json.dumps(maps, separators=(",", ":")), encoding="utf-8")


def reverse_canonical_records(root: Path) -> None:
    registry = root / "id_registry.json"
    registry_value = json.loads(registry.read_text(encoding="utf-8"))
    registry_value["namespaces"].reverse()
    for namespace in registry_value["namespaces"]:
        namespace["entries"].reverse()
    registry.write_text(json.dumps(registry_value, separators=(",", ":")), encoding="utf-8")
    for name in ("pieces.json", "abilities.json", "statuses.json", "synergies.json", "maps.json", "enemies.json", "acts.json", "encounters.json"):
        path = root / name
        value = json.loads(path.read_text(encoding="utf-8"))
        value["records"].reverse()
        path.write_text(json.dumps(value, separators=(",", ":")), encoding="utf-8")


def main() -> int:
    catalog = load_catalog(RUNTIME)
    assert catalog.fingerprint.hex() == EXPECTED_FINGERPRINT
    assert [piece.string_id for piece in catalog.pieces] == ["baduk_stone", "bottle_cap", "graybox_striker"]
    assert [ability.string_id for ability in catalog.abilities] == ["graybox_opening_haste"]
    assert [status.string_id for status in catalog.statuses] == ["graybox_haste", "development_revenge"]
    assert [synergy.string_id for synergy in catalog.synergies] == ["destruction", "steel"]
    assert [item.string_id for item in catalog.enemies] == ["enemy_baduk_stone", "enemy_bottle_cap", "enemy_graybox_striker", "graybox_elite_baduk_stone", "graybox_boss_graybox_striker"]
    assert [item.string_id for item in catalog.maps] == ["graybox_pit_arena"]
    assert [len(piece.levels) for piece in catalog.pieces] == [3, 3, 1]

    with tempfile.TemporaryDirectory(prefix="flickstone-p2-graybox-order-") as temporary:
        reordered = Path(temporary) / "data"
        shutil.copytree(RUNTIME, reordered)
        reverse_canonical_records(reordered)
        assert load_catalog(reordered).fingerprint.hex() == EXPECTED_FINGERPRINT

    ok, _ = mutate("id_registry.json", lambda value: value["namespaces"][0]["entries"].append(dict(value["namespaces"][0]["entries"][0])))
    assert not ok
    ok, _ = mutate("abilities.json", lambda value: value["records"][0]["effects"][0].update({"value_a": 99}))
    assert not ok
    ok, _ = mutate("statuses.json", lambda value: value["records"][0].update({"default_duration": 0}))
    assert not ok
    ok, _ = mutate("enemies.json", lambda value: value["records"][0]["override"].update({"unknown": 1}))
    assert not ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["player_slots"][0].update({"x_raw": 320 * 65536, "y_raw": 512 * 65536}))
    assert not ok

    radius = 32 * 65536
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["player_slots"][0].update({"x_raw": radius + 1, "y_raw": 700 * 65536}))
    assert ok
    ok, _ = mutate("maps.json", lambda value: value["records"][0]["player_slots"][0].update({"x_raw": radius, "y_raw": 700 * 65536}))
    assert not ok

    enemy_radius = 48 * 65536
    ok, _ = mutate_package(lambda root: set_enemy_radius_and_slot(root, enemy_radius + 1))
    assert ok
    ok, _ = mutate_package(lambda root: set_enemy_radius_and_slot(root, enemy_radius))
    assert not ok

    destruction = catalog.synergies[0]
    steel = catalog.synergies[1]
    assert destruction.count_cap == 5 and destruction.tiers[0].modifiers[0].value == 1000
    assert steel.count_cap == 8 and [item.value for item in steel.tiers[0].modifiers] == [2, 327680]

    print("[PASS] P2-6-PY-RUNTIME exact package IDs and P4-approved roster levels")
    print("[PASS] P2-6-PY-CANONICAL reordered registry/records preserve fingerprint")
    print("[PASS] P2-6-PY-NEGATIVE-BOUNDARY references, overrides, KILL slots, and max-radius edge")
    print("P2_CONTENT_GRAYBOX_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ContentError, OSError) as exc:
        print(f"P2_CONTENT_GRAYBOX_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
