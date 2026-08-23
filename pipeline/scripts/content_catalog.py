#!/usr/bin/env python3
"""Independent P2-1 strict catalog validator and canonical fingerprint CLI."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

FILE_MAX_BYTES = 4 * 1024 * 1024
CATALOG_MAX_BYTES = 16 * 1024 * 1024
JSON_MAX_DEPTH = 32
JSON_MAX_NODES = 262_144
JSON_MAX_OBJECT_MEMBERS = 128
JSON_MAX_ARRAY_ITEMS = 4_096
JSON_MAX_STRING_BYTES = 4_096
RECORD_MAX_COUNT = 4_096
ABILITY_REFS_MAX_COUNT = 32
INT64_MIN = -(1 << 63)
INT64_MAX = (1 << 63) - 1
UINT32_MAX = (1 << 32) - 1
ID_RE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")

EXPECTED_FILES = {
    "catalog.json",
    "id_registry.json",
    "pieces.json",
    "abilities.json",
}
DOCUMENTS = {
    1: ("id_registry.json", 1),
    2: ("pieces.json", 1),
    3: ("abilities.json", 2),
}


class ContentError(ValueError):
    pass


def _reject_float(value: str) -> int:
    raise ContentError(f"NON_INTEGER_NUMBER:{value}")


def _reject_constant(value: str) -> int:
    raise ContentError(f"JSON_SYNTAX:{value}")


def _parse_int(value: str) -> int:
    parsed = int(value, 10)
    if not INT64_MIN <= parsed <= INT64_MAX:
        raise ContentError(f"INTEGER_OVERFLOW:{value}")
    return parsed


def _object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    if len(pairs) > JSON_MAX_OBJECT_MEMBERS:
        raise ContentError("JSON_LIMIT:object_members")
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContentError(f"DUPLICATE_KEY:{key}")
        result[key] = value
    return result


def _validate_tree(value: Any, depth: int = 1, count: list[int] | None = None) -> None:
    if count is None:
        count = [0]
    if depth > JSON_MAX_DEPTH:
        raise ContentError("JSON_LIMIT:depth")
    count[0] += 1
    if count[0] > JSON_MAX_NODES:
        raise ContentError("JSON_LIMIT:nodes")
    if isinstance(value, str):
        try:
            encoded = value.encode("utf-8")
        except UnicodeEncodeError as exc:
            raise ContentError("JSON_SYNTAX:surrogate") from exc
        if len(encoded) > JSON_MAX_STRING_BYTES:
            raise ContentError("JSON_LIMIT:string")
    elif isinstance(value, list):
        if len(value) > JSON_MAX_ARRAY_ITEMS:
            raise ContentError("JSON_LIMIT:array")
        for item in value:
            _validate_tree(item, depth + 1, count)
    elif isinstance(value, dict):
        for key, item in value.items():
            _validate_tree(key, depth + 1, count)
            _validate_tree(item, depth + 1, count)
    elif not (value is None or isinstance(value, (bool, int))):
        raise ContentError(f"INVALID_TYPE:{type(value).__name__}")


def strict_load_bytes(data: bytes) -> Any:
    if data.startswith(b"\xef\xbb\xbf"):
        raise ContentError("INVALID_UTF8:BOM")
    try:
        text = data.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise ContentError("INVALID_UTF8") from exc
    try:
        result = json.loads(
            text,
            object_pairs_hook=_object_pairs,
            parse_int=_parse_int,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
            strict=True,
        )
    except json.JSONDecodeError as exc:
        raise ContentError(f"JSON_SYNTAX:{exc.lineno}:{exc.colno}") from exc
    _validate_tree(result)
    return result


def _exact(obj: Any, keys: set[str], label: str) -> dict[str, Any]:
    if not isinstance(obj, dict):
        raise ContentError(f"INVALID_TYPE:{label}")
    actual = set(obj)
    if actual != keys:
        missing = sorted(keys - actual)
        extra = sorted(actual - keys)
        raise ContentError(f"KEY_SET:{label}:missing={missing}:extra={extra}")
    return obj


def _integer(value: Any, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ContentError(f"INVALID_TYPE:{label}")
    return value


def _string_id(value: Any, label: str) -> str:
    if not isinstance(value, str) or ID_RE.fullmatch(value) is None:
        raise ContentError(f"INVALID_ID:{label}")
    return value


def _u32(value: Any, label: str) -> int:
    result = _integer(value, label)
    if not 1 <= result <= UINT32_MAX:
        raise ContentError(f"INVALID_ID:{label}")
    return result


@dataclass(frozen=True)
class Entry:
    namespace_id: int
    numeric_id: int
    string_id: str
    state_id: int


@dataclass(frozen=True)
class Condition:
    kind_id: int
    relation_id: int
    value_a: int
    value_b: int


@dataclass(frozen=True)
class Selector:
    kind_id: int
    relation_id: int
    limit: int


@dataclass(frozen=True)
class Effect:
    kind_id: int
    selector: Selector
    value_a: int
    value_b: int
    operation_id: int


@dataclass(frozen=True)
class Ability:
    numeric_id: int
    string_id: str
    trigger_id: int
    conditions: tuple[Condition, ...]
    effects: tuple[Effect, ...]


@dataclass(frozen=True)
class Ref:
    numeric_id: int
    string_id: str


@dataclass(frozen=True)
class Level:
    level: int
    max_hp: int
    attack: int
    speed_stat: int
    mass_raw: int
    radius_raw: int
    friction_multiplier_raw: int
    critical_basis_points: int
    ability_refs: tuple[Ref, ...]


@dataclass(frozen=True)
class Piece:
    numeric_id: int
    string_id: str
    flags: tuple[bool, bool, bool, bool, bool]
    levels: tuple[Level, ...]


@dataclass(frozen=True)
class Catalog:
    entries: tuple[Entry, ...]
    pieces: tuple[Piece, ...]
    abilities: tuple[Ability, ...]
    compatibility_bytes: bytes
    fingerprint: bytes


class Writer:
    def __init__(self) -> None:
        self.data = bytearray()

    def u8(self, value: int) -> None:
        self.data += struct.pack("<B", value)

    def u16(self, value: int) -> None:
        self.data += struct.pack("<H", value)

    def u32(self, value: int) -> None:
        self.data += struct.pack("<I", value)

    def i64(self, value: int) -> None:
        self.data += struct.pack("<q", value)

    def string(self, value: str) -> None:
        encoded = value.encode("utf-8")
        self.u16(len(encoded))
        self.data += encoded


def canonical_bytes(
    entries: tuple[Entry, ...], pieces: tuple[Piece, ...], abilities: tuple[Ability, ...]
) -> bytes:
    writer = Writer()
    writer.data += b"FLICKCAT"
    writer.u16(2)
    writer.u16(2)
    writer.u16(1)
    writer.u16(8)
    for namespace_id in range(1, 9):
        selected = [item for item in entries if item.namespace_id == namespace_id]
        writer.u16(namespace_id)
        writer.u32(len(selected))
        for entry in selected:
            writer.u32(entry.numeric_id)
            writer.string(entry.string_id)
            writer.u8(entry.state_id)
    writer.u16(2)
    writer.u16(2)
    writer.u16(1)
    writer.u32(len(pieces))
    for piece in pieces:
        writer.u32(piece.numeric_id)
        writer.string(piece.string_id)
        flags = sum((1 << index) for index, enabled in enumerate(piece.flags) if enabled)
        writer.u32(flags)
        writer.u8(len(piece.levels))
        for level in piece.levels:
            writer.u8(level.level)
            for value in (
                level.max_hp,
                level.attack,
                level.speed_stat,
                level.mass_raw,
                level.radius_raw,
                level.friction_multiplier_raw,
                level.critical_basis_points,
            ):
                writer.i64(value)
            writer.u16(len(level.ability_refs))
            for ref in level.ability_refs:
                writer.u32(ref.numeric_id)
                writer.string(ref.string_id)
    writer.u16(3)
    writer.u16(2)
    writer.u32(len(abilities))
    for ability in abilities:
        writer.u32(ability.numeric_id)
        writer.string(ability.string_id)
        writer.u16(ability.trigger_id)
        writer.u16(len(ability.conditions))
        for condition in ability.conditions:
            writer.u16(condition.kind_id)
            writer.u16(condition.relation_id)
            writer.i64(condition.value_a)
            writer.i64(condition.value_b)
        writer.u16(len(ability.effects))
        for effect in ability.effects:
            writer.u16(effect.kind_id)
            writer.u16(effect.selector.kind_id)
            writer.u16(effect.selector.relation_id)
            writer.u16(effect.selector.limit)
            writer.i64(effect.value_a)
            writer.i64(effect.value_b)
            writer.u16(effect.operation_id)
    return bytes(writer.data)


def _load_file(root: Path, name: str) -> Any:
    path = root / name
    try:
        data = path.read_bytes()
    except OSError as exc:
        raise ContentError(f"IO_ERROR:{name}") from exc
    if len(data) > FILE_MAX_BYTES:
        raise ContentError(f"FILE_TOO_LARGE:{name}")
    return strict_load_bytes(data)


def load_catalog(root: Path) -> Catalog:
    root = root.resolve()
    actual = {path.name for path in root.iterdir() if path.is_file() and path.suffix.lower() == ".json"}
    if actual != EXPECTED_FILES:
        raise ContentError(f"DOCUMENT_SET:missing={sorted(EXPECTED_FILES-actual)}:extra={sorted(actual-EXPECTED_FILES)}")
    total = sum((root / name).stat().st_size for name in EXPECTED_FILES)
    if total > CATALOG_MAX_BYTES:
        raise ContentError("CATALOG_LIMIT:bytes")

    catalog = _exact(_load_file(root, "catalog.json"), {"schema_version", "documents"}, "catalog")
    if _integer(catalog["schema_version"], "catalog.schema_version") != 2:
        raise ContentError("UNSUPPORTED_SCHEMA:catalog")
    documents = catalog["documents"]
    if not isinstance(documents, list) or len(documents) != 3:
        raise ContentError("INVALID_DOMAIN:documents")
    seen_documents: set[int] = set()
    for raw in documents:
        doc = _exact(raw, {"kind_id", "file_name", "schema_version"}, "document")
        kind_id = _integer(doc["kind_id"], "document.kind_id")
        if kind_id in seen_documents or kind_id not in DOCUMENTS:
            raise ContentError("DUPLICATE_ID:document")
        if (doc["file_name"], _integer(doc["schema_version"], "document.schema_version")) != DOCUMENTS[kind_id]:
            raise ContentError("INVALID_DOMAIN:document")
        seen_documents.add(kind_id)
    if seen_documents != set(DOCUMENTS):
        raise ContentError("MISSING_KEY:document")

    registry = _exact(_load_file(root, "id_registry.json"), {"schema_version", "namespaces"}, "registry")
    if _integer(registry["schema_version"], "registry.schema_version") != 1:
        raise ContentError("UNSUPPORTED_SCHEMA:registry")
    namespaces = registry["namespaces"]
    if not isinstance(namespaces, list) or len(namespaces) != 8:
        raise ContentError("INVALID_DOMAIN:namespaces")
    entries: list[Entry] = []
    numeric_keys: set[tuple[int, int]] = set()
    string_keys: set[tuple[int, str]] = set()
    seen_namespaces: set[int] = set()
    for raw_namespace in namespaces:
        namespace = _exact(raw_namespace, {"namespace_id", "entries"}, "namespace")
        namespace_id = _integer(namespace["namespace_id"], "namespace_id")
        raw_entries = namespace["entries"]
        if namespace_id not in range(1, 9) or namespace_id in seen_namespaces:
            raise ContentError("DUPLICATE_ID:namespace")
        if not isinstance(raw_entries, list) or len(raw_entries) > RECORD_MAX_COUNT:
            raise ContentError("CATALOG_LIMIT:entries")
        if namespace_id > 2 and raw_entries:
            raise ContentError("INVALID_DOMAIN:inactive_namespace")
        seen_namespaces.add(namespace_id)
        for raw_entry in raw_entries:
            item = _exact(raw_entry, {"numeric_id", "id", "state_id"}, "entry")
            numeric_id = _u32(item["numeric_id"], "entry.numeric_id")
            string_id = _string_id(item["id"], "entry.id")
            state_id = _integer(item["state_id"], "entry.state_id")
            if state_id not in (1, 2):
                raise ContentError("INVALID_ID:state")
            if (namespace_id, numeric_id) in numeric_keys or (namespace_id, string_id) in string_keys:
                raise ContentError("DUPLICATE_ID:entry")
            numeric_keys.add((namespace_id, numeric_id))
            string_keys.add((namespace_id, string_id))
            entries.append(Entry(namespace_id, numeric_id, string_id, state_id))
    if seen_namespaces != set(range(1, 9)):
        raise ContentError("MISSING_KEY:namespace")
    entries.sort(key=lambda item: (item.namespace_id, item.numeric_id))
    by_numeric = {(item.namespace_id, item.numeric_id): item for item in entries}
    by_string = {(item.namespace_id, item.string_id): item for item in entries}

    def active_pair(namespace_id: int, numeric_id: int, string_id: str) -> Entry:
        numeric = by_numeric.get((namespace_id, numeric_id))
        string = by_string.get((namespace_id, string_id))
        if numeric is None or numeric is not string or numeric.state_id != 1:
            raise ContentError(f"MISSING_REFERENCE:{namespace_id}:{numeric_id}:{string_id}")
        return numeric

    abilities_doc = _exact(_load_file(root, "abilities.json"), {"schema_version", "records"}, "abilities")
    if _integer(abilities_doc["schema_version"], "abilities.schema_version") != 2:
        raise ContentError("UNSUPPORTED_SCHEMA:abilities")
    ability_records = abilities_doc["records"]
    if not isinstance(ability_records, list) or len(ability_records) > RECORD_MAX_COUNT:
        raise ContentError("CATALOG_LIMIT:abilities")
    abilities: list[Ability] = []
    ability_ids: set[int] = set()
    ability_strings: set[str] = set()
    for raw in ability_records:
        item = _exact(raw, {"numeric_id", "id", "trigger_id", "conditions", "effects"}, "ability")
        numeric_id = _u32(item["numeric_id"], "ability.numeric_id")
        string_id = _string_id(item["id"], "ability.id")
        trigger_id = _integer(item["trigger_id"], "ability.trigger_id")
        active_pair(2, numeric_id, string_id)
        if numeric_id in ability_ids or string_id in ability_strings:
            raise ContentError("DUPLICATE_ID:ability")
        if not 1 <= trigger_id <= 13:
            raise ContentError("INVALID_DOMAIN:trigger")
        conditions_raw = item["conditions"]
        if not isinstance(conditions_raw, list) or len(conditions_raw) > 16:
            raise ContentError("CATALOG_LIMIT:conditions")
        conditions: list[Condition] = []
        for raw_condition in conditions_raw:
            condition = _exact(raw_condition, {"kind_id", "relation_id", "value_a", "value_b"}, "condition")
            kind_id = _integer(condition["kind_id"], "condition.kind_id")
            relation_id = _integer(condition["relation_id"], "condition.relation_id")
            value_a = _integer(condition["value_a"], "condition.value_a")
            value_b = _integer(condition["value_b"], "condition.value_b")
            if not 1 <= kind_id <= 7 or not 0 <= relation_id <= 4:
                raise ContentError("INVALID_DOMAIN:condition")
            if kind_id == 1 and (relation_id != 0 or value_a != 0 or value_b != 0):
                raise ContentError("INVALID_DOMAIN:always")
            if kind_id != 1 and relation_id == 0:
                raise ContentError("INVALID_DOMAIN:relation")
            if kind_id in (6, 7) and (not 0 <= value_a <= 10_000 or value_b != 0):
                raise ContentError("INVALID_DOMAIN:hp_condition")
            conditions.append(Condition(kind_id, relation_id, value_a, value_b))
        effects_raw = item["effects"]
        if not isinstance(effects_raw, list) or len(effects_raw) > 32:
            raise ContentError("CATALOG_LIMIT:effects")
        effects: list[Effect] = []
        for raw_effect in effects_raw:
            effect = _exact(raw_effect, {"kind_id", "selector", "value_a", "value_b", "operation_id"}, "effect")
            selector_raw = _exact(effect["selector"], {"kind_id", "relation_id", "limit"}, "selector")
            selector = Selector(_integer(selector_raw["kind_id"], "selector.kind_id"), _integer(selector_raw["relation_id"], "selector.relation_id"), _integer(selector_raw["limit"], "selector.limit"))
            effect_kind = _integer(effect["kind_id"], "effect.kind_id")
            value_a = _integer(effect["value_a"], "effect.value_a")
            value_b = _integer(effect["value_b"], "effect.value_b")
            operation_id = _integer(effect["operation_id"], "effect.operation_id")
            if not 1 <= effect_kind <= 6 or not 1 <= selector.kind_id <= 8 or selector.relation_id != 0 or not 0 <= selector.limit <= 256 or operation_id != 0:
                raise ContentError("INVALID_DOMAIN:effect")
            if effect_kind in (1, 2, 3, 4) and (value_a <= 0 or value_b != 0):
                raise ContentError("INVALID_DOMAIN:effect_values")
            effects.append(Effect(effect_kind, selector, value_a, value_b, operation_id))
        ability_ids.add(numeric_id)
        ability_strings.add(string_id)
        abilities.append(Ability(numeric_id, string_id, trigger_id, tuple(conditions), tuple(effects)))
    abilities.sort(key=lambda item: item.numeric_id)
    ability_by_id = {item.numeric_id: item for item in abilities}

    pieces_doc = _exact(_load_file(root, "pieces.json"), {"schema_version", "records"}, "pieces")
    if _integer(pieces_doc["schema_version"], "pieces.schema_version") != 1:
        raise ContentError("UNSUPPORTED_SCHEMA:pieces")
    piece_records = pieces_doc["records"]
    if not isinstance(piece_records, list) or len(piece_records) > RECORD_MAX_COUNT:
        raise ContentError("CATALOG_LIMIT:pieces")
    pieces: list[Piece] = []
    piece_ids: set[int] = set()
    piece_strings: set[str] = set()
    for raw in piece_records:
        item = _exact(raw, {"numeric_id", "id", "flags", "levels"}, "piece")
        numeric_id = _u32(item["numeric_id"], "piece.numeric_id")
        string_id = _string_id(item["id"], "piece.id")
        active_pair(1, numeric_id, string_id)
        if numeric_id in piece_ids or string_id in piece_strings:
            raise ContentError("DUPLICATE_ID:piece")
        flags_raw = _exact(item["flags"], {"has_turn", "destructible", "transformable", "counts_for_victory", "is_token"}, "flags")
        flag_names = ("has_turn", "destructible", "transformable", "counts_for_victory", "is_token")
        if any(not isinstance(flags_raw[name], bool) for name in flag_names):
            raise ContentError("INVALID_TYPE:flag")
        flags = tuple(flags_raw[name] for name in flag_names)
        levels_raw = item["levels"]
        if not isinstance(levels_raw, list) or not 1 <= len(levels_raw) <= 3:
            raise ContentError("INVALID_DOMAIN:levels")
        levels: list[Level] = []
        for index, raw_level in enumerate(levels_raw, 1):
            level = _exact(raw_level, {"level", "max_hp", "attack", "speed_stat", "mass_raw", "radius_raw", "friction_multiplier_raw", "critical_basis_points", "ability_refs"}, "level")
            values = {name: _integer(level[name], f"level.{name}") for name in ("level", "max_hp", "attack", "speed_stat", "mass_raw", "radius_raw", "friction_multiplier_raw", "critical_basis_points")}
            if values["level"] != index:
                raise ContentError("INVALID_DOMAIN:level_sequence")
            if not 1 <= values["max_hp"] <= 1_000_000 or not 1 <= values["attack"] <= 1_000_000:
                raise ContentError("INVALID_DOMAIN:stat")
            if not 50 <= values["speed_stat"] <= 200:
                raise ContentError("INVALID_DOMAIN:speed")
            if not 65_536 <= values["mass_raw"] <= 16_777_216:
                raise ContentError("INVALID_DOMAIN:mass")
            if not 524_288 <= values["radius_raw"] <= 8_388_608:
                raise ContentError("INVALID_DOMAIN:radius")
            if values["friction_multiplier_raw"] < 0 or not 0 <= values["critical_basis_points"] <= 10_000:
                raise ContentError("INVALID_DOMAIN:ratio")
            refs_raw = level["ability_refs"]
            if not isinstance(refs_raw, list) or len(refs_raw) > ABILITY_REFS_MAX_COUNT:
                raise ContentError("CATALOG_LIMIT:ability_refs")
            refs: list[Ref] = []
            ref_ids: set[int] = set()
            for raw_ref in refs_raw:
                ref = _exact(raw_ref, {"numeric_id", "id"}, "ability_ref")
                ref_numeric = _u32(ref["numeric_id"], "ability_ref.numeric_id")
                ref_string = _string_id(ref["id"], "ability_ref.id")
                active_pair(2, ref_numeric, ref_string)
                ability = ability_by_id.get(ref_numeric)
                if ability is None or ability.string_id != ref_string:
                    raise ContentError("MISSING_REFERENCE:ability")
                if ref_numeric in ref_ids:
                    raise ContentError("DUPLICATE_ID:ability_ref")
                ref_ids.add(ref_numeric)
                refs.append(Ref(ref_numeric, ref_string))
            refs.sort(key=lambda ref: ref.numeric_id)
            levels.append(Level(ability_refs=tuple(refs), **values))
        piece_ids.add(numeric_id)
        piece_strings.add(string_id)
        pieces.append(Piece(numeric_id, string_id, flags, tuple(levels)))
    pieces.sort(key=lambda item: item.numeric_id)

    for entry in entries:
        if entry.state_id != 1:
            continue
        if entry.namespace_id == 1 and entry.numeric_id not in piece_ids:
            raise ContentError("MISSING_REFERENCE:piece_definition")
        if entry.namespace_id == 2 and entry.numeric_id not in ability_ids:
            raise ContentError("MISSING_REFERENCE:ability_definition")

    entries_tuple = tuple(entries)
    pieces_tuple = tuple(pieces)
    abilities_tuple = tuple(abilities)
    encoded = canonical_bytes(entries_tuple, pieces_tuple, abilities_tuple)
    return Catalog(entries_tuple, pieces_tuple, abilities_tuple, encoded, hashlib.sha256(encoded).digest())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--canonical-hex", action="store_true")
    args = parser.parse_args(argv)
    try:
        catalog = load_catalog(args.root)
    except (ContentError, OSError) as exc:
        print(f"CONTENT_CATALOG_RESULT: FAIL {exc}", file=sys.stderr)
        return 1
    if args.canonical_hex:
        print(f"canonical_hex={catalog.compatibility_bytes.hex()}")
    print(f"fingerprint={catalog.fingerprint.hex()}")
    print(f"pieces={len(catalog.pieces)} abilities={len(catalog.abilities)} registry_entries={len(catalog.entries)}")
    print("CONTENT_CATALOG_RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
