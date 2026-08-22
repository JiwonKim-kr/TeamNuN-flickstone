#!/usr/bin/env python3
"""Deterministic P1-5 fixture, CSV, golden, and repro boundary."""
from __future__ import annotations

import csv
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

CSV_COLUMNS = (
    "schema_version,batch_id,case_id,fixture_id,seed_hi,seed_lo,"
    "insertion_variant,restore_after_turn,result,turn_count,sim_tick_count,"
    "player_alive,enemy_alive,player_damage,enemy_damage,damage_destroyed,"
    "kill_boundary_destroyed,kill_zone_destroyed,forced_settle_count,"
    "terminal_hash,failure_code,failure_operation,repro_file"
).split(",")
FIXTURE_KEYS = {"schema_version", "fixture_id", "boundary", "combatants", "cases"}
CASE_KEYS = {"case_id", "seed_hi", "seed_lo", "insertion_variant", "restore_after_turn"}
COMBATANT_KEYS = {"stable_key", "faction", "position", "speed_stat", "radius", "mass", "hp", "attack"}


@dataclass(frozen=True)
class BattleCase:
    case_id: int
    seed_hi: int
    seed_lo: int
    insertion_variant: int
    restore_after_turn: int


@dataclass(frozen=True)
class BatchRow:
    schema_version: int
    batch_id: str
    case_id: int
    fixture_id: str
    seed_hi: int
    seed_lo: int
    insertion_variant: int
    restore_after_turn: int
    result: int
    turn_count: int
    sim_tick_count: int
    player_alive: int
    enemy_alive: int
    player_damage: int = 0
    enemy_damage: int = 0
    damage_destroyed: int = 0
    kill_boundary_destroyed: int = 0
    kill_zone_destroyed: int = 0
    forced_settle_count: int = 0
    terminal_hash: str = ""
    failure_code: int = 0
    failure_operation: int = 0
    repro_file: str = ""


def _exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        raise ValueError(f"{label} keys mismatch: {sorted(set(value) ^ expected)}")


def _integer(value: Any, label: str, low: int, high: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < low or value > high:
        raise ValueError(f"{label} must be integer {low}..{high}")
    return value


def load_fixture(path: Path) -> tuple[str, list[BattleCase]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict): raise ValueError("fixture root must be object")
    _exact_keys(data, FIXTURE_KEYS, "fixture")
    if data["schema_version"] != 1 or data["fixture_id"] != "p1_graybox_v2": raise ValueError("unsupported fixture identity")
    boundary = data["boundary"]
    if boundary != [[0, 0], [1024, 0], [1024, 640], [0, 640]]: raise ValueError("unexpected approved boundary")
    combatants = data["combatants"]
    if not isinstance(combatants, list) or len(combatants) != 6: raise ValueError("fixture must contain 6 combatants")
    stable_keys: set[int] = set(); faction_counts = {1: 0, 2: 0}
    validated: list[tuple[int, int, int, int, int]] = []
    for index, item in enumerate(combatants):
        if not isinstance(item, dict): raise ValueError(f"combatants[{index}] must be object")
        _exact_keys(item, COMBATANT_KEYS, f"combatants[{index}]")
        key = _integer(item["stable_key"], "stable_key", 1, 0xFFFFFFFF)
        if key in stable_keys: raise ValueError("duplicate stable_key")
        stable_keys.add(key)
        faction = _integer(item["faction"], "faction", 1, 2); faction_counts[faction] += 1
        position = item["position"]
        if not isinstance(position, list) or len(position) != 2: raise ValueError("position must be [x,y]")
        x = _integer(position[0], "position.x", 33, 991); y = _integer(position[1], "position.y", 33, 607)
        if item["radius"] != 32 or item["mass"] != 64 or item["hp"] != 100 or item["attack"] != 20: raise ValueError("combatant constants mismatch")
        speed = _integer(item["speed_stat"], "speed_stat", 50, 200)
        validated.append((faction, x, y, item["radius"], speed))
    if faction_counts != {1: 3, 2: 3}: raise ValueError("fixture must be symmetric 3v3")
    for left_index, left in enumerate(validated):
        for right in validated[left_index + 1:]:
            if (left[1] - right[1]) ** 2 + (left[2] - right[2]) ** 2 <= (left[3] + right[3]) ** 2:
                raise ValueError("combatant circles overlap or touch")
    players = [(x, y, speed) for faction, x, y, _, speed in validated if faction == 1]
    enemies = [(x, y, speed) for faction, x, y, _, speed in validated if faction == 2]
    if (
        sorted((item[0], item[1]) for item in players) != sorted((1024 - item[0], item[1]) for item in enemies)
        or sorted(item[2] for item in players) != [80, 100, 125]
        or sorted(item[2] for item in enemies) != [80, 100, 125]
    ):
        raise ValueError("fixture teams must be X-axis symmetric with speeds 80/100/125")
    cases: list[BattleCase] = []; case_ids: set[int] = set()
    if not isinstance(data["cases"], list) or not data["cases"]: raise ValueError("cases must be non-empty")
    for index, item in enumerate(data["cases"]):
        if not isinstance(item, dict): raise ValueError(f"cases[{index}] must be object")
        _exact_keys(item, CASE_KEYS, f"cases[{index}]")
        case = BattleCase(*(_integer(item[key], f"cases[{index}].{key}", 0 if key != "case_id" else 1, 0xFFFFFFFF if key not in ("insertion_variant", "restore_after_turn") else (1 if key == "insertion_variant" else 127)) for key in ("case_id", "seed_hi", "seed_lo", "insertion_variant", "restore_after_turn")))
        if case.case_id in case_ids: raise ValueError("duplicate case_id")
        case_ids.add(case.case_id); cases.append(case)
    return data["fixture_id"], cases


def expand_cases(cases: list[BattleCase], count: int) -> list[BattleCase]:
    if len(cases) != 16 or count not in (16, 256, 1000):
        raise ValueError("approved batch sizes require 16 fixture cases and count 16/256/1000")
    result: list[BattleCase] = []
    for index in range(count):
        template = cases[index % len(cases)]
        result.append(BattleCase(index + 1, template.seed_hi, template.seed_lo, template.insertion_variant, template.restore_after_turn))
    return result


def write_csv(path: Path, rows: list[BatchRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=CSV_COLUMNS, lineterminator="\n")
        writer.writeheader()
        for row in rows: writer.writerow(asdict(row))


def golden_value(row: BatchRow) -> dict[str, Any]:
    return {key: getattr(row, key) for key in ("case_id", "result", "turn_count", "sim_tick_count", "terminal_hash")}


def read_goldens(path: Path) -> dict[int, dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1 or not isinstance(data.get("cases"), list): raise ValueError("invalid golden schema")
    return {item["case_id"]: item for item in data["cases"]}


def update_goldens(path: Path, rows: list[BatchRow], approval_ref: str, *, ci: bool) -> list[str]:
    if ci or not approval_ref: raise ValueError("golden update requires approval-ref and is forbidden in CI")
    previous = read_goldens(path) if path.is_file() else {}
    payload = {"schema_version": 1, "approval_ref": approval_ref, "cases": [golden_value(row) for row in sorted(rows, key=lambda item: item.case_id)]}
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    changes: list[str] = []
    for item in payload["cases"]:
        old = previous.get(item["case_id"])
        changes.append(f"GOLDEN case={item['case_id']} old={json.dumps(old, sort_keys=True)} new={json.dumps(item, sort_keys=True)}")
    return changes


def write_repro(path: Path, fixture_id: str, case: BattleCase, stage: str, failure_code: int, failure_operation: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": 1, "fixture_id": fixture_id, **asdict(case),
        "failure_stage": stage, "failure_code": failure_code,
        "failure_operation": failure_operation, "last_snapshot_hex": "",
    }
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
