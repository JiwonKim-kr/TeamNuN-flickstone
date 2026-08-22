#!/usr/bin/env python3
"""Independent known-answer checks for the P1-4 trigger contract."""
from __future__ import annotations

import json
import struct
from pathlib import Path

from p0_rng_reference import derive_state

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "pipeline/tests/fixtures/p1_trigger_vectors.json"
RECORD_HEX = "2a0000000300050004001100000000000000170000000b00000016000000210000000000650000000000000036ffffffffffffff2f010000000000006cfefffffffffffff9010000000000005e0200000000000007000000"
DERIVED_STATE = (0xE5024EEA, 0x39CDD8BD, 0x89C69B0B, 0xDE880ABC)


def pack_record(values: list[int]) -> bytes:
    return struct.pack("<IHHHqIIIIHqqqqqqI", *values)


def resolve_result(player_alive: int, enemy_alive: int) -> int:
    if player_alive and enemy_alive:
        return 0
    if player_alive:
        return 1
    if enemy_alive:
        return 2
    return 3


def breadth_first_counts(max_wave: int) -> list[int]:
    waves = [[0]]
    output: list[int] = []
    while waves:
        wave = waves.pop(0)
        output.extend(wave)
        if wave[0] + 1 < max_wave:
            waves.append([wave[0] + 1])
    return output


def main() -> int:
    data = json.loads(FIXTURE.read_text(encoding="utf-8"))
    actual_hex = pack_record(data["record_values"]).hex()
    if actual_hex != RECORD_HEX or data["record_hex"] != RECORD_HEX:
        print("[FAIL] trigger record little-endian KAT")
        return 1
    results = [resolve_result(*pair) for pair in data["alive_pairs"]]
    if results != data["results"] or results != [3, 2, 1, 0]:
        print("[FAIL] battle result truth table")
        return 1
    if breadth_first_counts(32) != list(range(32)):
        print("[FAIL] 32-wave breadth-first boundary")
        return 1
    derived = derive_state(0x01234567, 0x89ABCDEF, 1, 17, 42)
    if derived != DERIVED_STATE or [f"{word:08x}" for word in derived] != data["derived_state"]:
        print("[FAIL] record-keyed RNG derivation KAT")
        return 1
    print("[PASS] P1-4 independent trigger/result/RNG KAT")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
