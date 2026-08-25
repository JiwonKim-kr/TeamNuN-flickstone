#!/usr/bin/env python3
"""Independent P4-2 Act/Encounter catalog and deterministic run-map KAT."""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "scripts"))
sys.path.insert(0, str(ROOT / "pipeline" / "tests"))

from content_catalog import ActDefinition, Catalog, load_catalog  # noqa: E402
from p0_rng_reference import Xoshiro128StarStar, derive_state  # noqa: E402

RUNTIME = ROOT / "src" / "core" / "data"
EXPECTED_FINGERPRINT = "ed6dd1319f158a539ffe4bc89bce965ea1061586b1e462a7e211bb8f0f561e3e"
EXPECTED_GRAPH = (
    (1, 1, 0, 1, 1, (2, 3)),
    (2, 2, 0, 3, 1, (4,)),
    (3, 2, 1, 4, 1, (5,)),
    (4, 3, 0, 1, 1, (6,)),
    (5, 3, 1, 2, 3, (6,)),
    (6, 4, 0, 5, 0, (7,)),
    (7, 5, 0, 6, 4, ()),
)


def _mutate(file_name: str, callback) -> bool:
    with tempfile.TemporaryDirectory(prefix="flickstone-p4-map-") as temporary:
        fixture = Path(temporary) / "data"
        shutil.copytree(RUNTIME, fixture)
        path = fixture / file_name
        value = json.loads(path.read_text(encoding="utf-8"))
        callback(value)
        path.write_text(json.dumps(value, separators=(",", ":")), encoding="utf-8")
        try:
            load_catalog(fixture)
        except (OSError, ValueError):
            return False
        return True


def _pick_index(seed_hi: int, seed_lo: int, purpose: int, act_id: int, node_id: int, bound: int) -> int:
    if bound == 1:
        return 0
    rng = Xoshiro128StarStar(list(derive_state(seed_hi, seed_lo, purpose, act_id, node_id)))
    return rng.next_below(bound)


def generate_graph(act: ActDefinition, seed_hi: int, seed_lo: int) -> tuple[tuple[int, int, int, int, int, tuple[int, ...]], ...]:
    starts: list[int] = []
    next_node_id = 1
    for floor in act.floors:
        starts.append(next_node_id)
        next_node_id += len(floor.slots)
    nodes: list[tuple[int, int, int, int, int, tuple[int, ...]]] = []
    for floor_offset, floor in enumerate(act.floors):
        source_width = len(floor.slots)
        for slot in floor.slots:
            node_id = starts[floor_offset] + slot.slot_index
            if len(slot.options) == 1:
                option = slot.options[0]
            else:
                ticket = _pick_index(seed_hi, seed_lo, 4, act.numeric_id, node_id, slot.total_weight)
                cumulative = 0
                option = slot.options[-1]
                for candidate in slot.options:
                    cumulative += candidate.weight
                    if ticket < cumulative:
                        option = candidate
                        break
            if option.node_type_id == 5:
                content_id = 0
            else:
                ref_index = _pick_index(seed_hi, seed_lo, 5, act.numeric_id, node_id, len(option.content_refs))
                content_id = option.content_refs[ref_index].numeric_id
            edges: tuple[int, ...] = ()
            if floor_offset + 1 < len(act.floors):
                target_width = len(act.floors[floor_offset + 1].slots)
                first_target = slot.slot_index * target_width // source_width
                targets = [first_target]
                for target_slot in range(target_width):
                    has_incoming = any(source_slot * target_width // source_width == target_slot for source_slot in range(source_width))
                    if not has_incoming and target_slot * source_width // target_width == slot.slot_index:
                        targets.append(target_slot)
                edges = tuple(starts[floor_offset + 1] + target for target in sorted(set(targets)))
            nodes.append((node_id, floor.floor_index, slot.slot_index, option.node_type_id, content_id, edges))
    return tuple(nodes)


def main() -> int:
    catalog: Catalog = load_catalog(RUNTIME)
    assert catalog.fingerprint.hex() == EXPECTED_FINGERPRINT
    assert (len(catalog.acts), len(catalog.encounters), len(catalog.enemies)) == (1, 4, 5)
    graph = generate_graph(catalog.acts[0], 17, 29)
    if not EXPECTED_GRAPH:
        print("P4_MAP_REFERENCE_GRAPH=" + json.dumps(graph, separators=(",", ":")))
        return 3
    assert graph == EXPECTED_GRAPH
    for _ in range(1000):
        assert generate_graph(catalog.acts[0], 17, 29) == EXPECTED_GRAPH
    assert generate_graph(catalog.acts[0], 18, 29) != EXPECTED_GRAPH
    assert tuple(encounter.numeric_id for encounter in catalog.encounters) == (1, 2, 3, 4)
    assert tuple(encounter.node_type_id for encounter in catalog.encounters) == (1, 1, 2, 6)
    invalid_mutations = (
        ("acts.json", lambda value: value["records"][0].update({"unknown": 1})),
        ("acts.json", lambda value: value["records"][0]["floors"][1].update({"floor_index": 3})),
        ("acts.json", lambda value: value["records"][0]["floors"][1]["slots"][1].update({"slot_index": 0})),
        ("acts.json", lambda value: value["records"][0]["floors"][0]["slots"][0]["options"][0].update({"weight": 0})),
        ("acts.json", lambda value: value["records"][0]["floors"][3]["slots"][0]["options"][0].update({"content_refs": [{"numeric_id": 1, "id": "rest_profile"}]})),
        ("acts.json", lambda value: value["records"][0]["floors"][2]["slots"][1]["options"][0].update({"node_type_id": 1})),
        ("acts.json", lambda value: value["records"][0]["floors"][1]["slots"][1]["options"][0].update({"node_type_id": 2, "content_refs": [{"numeric_id": 3, "id": "development_elite_pair"}]})),
        ("encounters.json", lambda value: value["records"][0]["enemy_refs"].pop()),
        ("encounters.json", lambda value: value["records"][2].update({"node_type_id": 1})),
        ("relics.json", lambda value: value["records"].append({"numeric_id": 1})),
    )
    assert all(not _mutate(file_name, callback) for file_name, callback in invalid_mutations)
    print("[PASS] P4-2-PY-CATALOG v7 Act/Encounter normalized content")
    print("[PASS] P4-2-PY-NEGATIVE exact keys, indices, refs, coverage, and empty future docs")
    print("[PASS] P4-2-PY-GRAPH independent exact node/content/edge KAT")
    print("[PASS] P4-2-PY-DETERMINISM 1000 repeats and seed separation")
    print("P4_ACT_ENCOUNTER_MAP_GENERATION_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError) as exc:
        print(f"P4_ACT_ENCOUNTER_MAP_GENERATION_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
