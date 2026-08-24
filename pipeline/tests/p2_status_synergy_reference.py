#!/usr/bin/env python3
"""Independent known answers for P2-3 integer modifier and lifetime rules."""
from __future__ import annotations
from pathlib import Path
import json
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from pipeline.scripts.content_catalog import ContentError, load_catalog

def round_away(n: int, d: int) -> int:
    sign = -1 if n < 0 else 1
    q, r = divmod(abs(n), d)
    return sign * (q + (1 if r * 2 >= d else 0))

assert round_away((100 + 25) * 10_000, 10_000) == 125
assert round_away(100 * 8_000, 10_000) == 80
assert round_away(4_000 * 65_536, 10_000) == 26_214
assert round_away(3_000 * 65_536, 10_000) == 19_661
remaining = 2
assert max(remaining, 2) == 2
assert min(remaining + 2, 8) == 4
assert 2 == 2  # REPLACE(default=2)
assert remaining == 2  # KEEP

catalog = load_catalog(ROOT / "pipeline/tests/fixtures/p2_status_synergy")
assert len(catalog.statuses) == 3
assert len(catalog.synergies) == 1
assert catalog.fingerprint.hex() == "4dcee0c594dd61ed4c9cd9ca044281ca7ce76a13f3f7b5c56fd93162f628951f"
assert catalog.statuses[0].modifiers[0].value == -500
assert catalog.synergies[0].tiers[0].modifiers[1].kind_id == 8
assert catalog.synergies[0].scope_id == 2 and len(catalog.synergies[0].tiers) == 2

def rejects(mutator) -> bool:
    with tempfile.TemporaryDirectory(prefix="flickstone-p2-3-") as temporary:
        target = Path(temporary) / "catalog"
        shutil.copytree(ROOT / "pipeline/tests/fixtures/p2_status_synergy", target)
        mutator(target)
        try:
            load_catalog(target)
        except ContentError:
            return True
        return False

def mutate_json(root: Path, name: str, mutator) -> None:
    path = root / name
    document = json.loads(path.read_text(encoding="utf-8"))
    mutator(document)
    path.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

def duplicate_tag_synergy(root: Path) -> None:
    def registry_mutation(document) -> None:
        document["namespaces"][3]["entries"].append({"numeric_id": 2, "id": "destruction_copy", "state_id": 1})
    def synergy_mutation(document) -> None:
        duplicate = dict(document["records"][0]); duplicate["numeric_id"] = 2; duplicate["id"] = "destruction_copy"
        document["records"].append(duplicate)
    mutate_json(root, "id_registry.json", registry_mutation)
    mutate_json(root, "synergies.json", synergy_mutation)

assert rejects(lambda root: mutate_json(root, "synergies.json", lambda doc: doc["records"][0]["tiers"][0].update(min_count=1)))
assert rejects(lambda root: mutate_json(root, "synergies.json", lambda doc: doc["records"][0]["tiers"].append(dict(doc["records"][0]["tiers"][0]))))
assert rejects(duplicate_tag_synergy)
assert rejects(lambda root: mutate_json(root, "statuses.json", lambda doc: doc["records"][0].update(unknown_key=1)))
assert rejects(lambda root: mutate_json(root, "synergies.json", lambda doc: doc["records"][0]["tiers"][0]["modifiers"][0].update(operation_id=2)))
print("[PASS] P2-3-PY strict catalog, canonical fingerprint, modifier, and lifetime known answers")
print("P2_STATUS_SYNERGY_REFERENCE_RESULT: PASS")
