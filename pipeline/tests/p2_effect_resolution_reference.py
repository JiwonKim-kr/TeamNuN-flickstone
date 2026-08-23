#!/usr/bin/env python3
"""Independent P2-2 ordering and six-effect known-answer reference."""
from __future__ import annotations
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline/scripts"))
from content_catalog import load_catalog

def main() -> int:
    catalog = load_catalog(ROOT / "pipeline/tests/fixtures/p2_effect_resolution")
    abilities = tuple(sorted(catalog.abilities, key=lambda item: item.numeric_id))
    assert tuple(item.numeric_id for item in abilities) == (1, 2, 3, 4, 5, 6, 7, 8)
    hp, max_hp, ct, velocity_x, velocity_y = 100, 100, 0, 0, 0
    applications: list[tuple[int, int, int]] = []
    for ability in abilities[:6]:
        assert ability.trigger_id == (3 if ability.numeric_id == 1 else 5)
        assert all(condition.kind_id == 1 or condition.kind_id == 3 for condition in ability.conditions)
        for effect_index, effect in enumerate(ability.effects):
            if effect.kind_id == 1: hp = max(0, hp - effect.value_a)
            elif effect.kind_id == 2: hp = min(max_hp, hp + effect.value_a)
            elif effect.kind_id == 3: velocity_x += effect.value_a
            elif effect.kind_id == 4: velocity_x -= effect.value_a
            elif effect.kind_id == 5: ct += effect.value_a
            elif effect.kind_id == 6: velocity_x += effect.value_a; velocity_y += effect.value_b
            else: raise AssertionError(f"unsupported effect {effect.kind_id}")
            applications.append((ability.numeric_id, effect_index, effect.kind_id))
    assert (hp, ct, velocity_x, velocity_y) == (95, 100, 100, 0)
    assert applications == [(1, 0, 1), (2, 0, 2), (3, 0, 3), (4, 0, 4), (5, 0, 5), (6, 0, 6)]
    print("[PASS] P2-2-PY-SCHEMA catalog v2 typed effect fixture")
    print("[PASS] P2-2-PY-ORDER owner/ability/effect deterministic order")
    print("[PASS] P2-2-PY-EFFECT six-effect known-answer")
    print("P2_EFFECT_RESOLUTION_REFERENCE_RESULT: PASS")
    return 0

if __name__ == "__main__":
    try: raise SystemExit(main())
    except (AssertionError, OSError, ValueError) as exc:
        print(f"P2_EFFECT_RESOLUTION_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr); raise SystemExit(1)
