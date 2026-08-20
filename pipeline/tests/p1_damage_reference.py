#!/usr/bin/env python3
"""Independent fixed-point reference for the approved P1-3 damage formula."""
from __future__ import annotations

import json
import math
from pathlib import Path

SCALE = 1 << 16
REFERENCE_SPEED_RAW = 1024 * SCALE
THRESHOLD_SPEED_RAW = 64 * SCALE
WEIGHT_MIN_RAW = SCALE // 2
WEIGHT_MAX_RAW = SCALE * 2


def round_div(numerator: int, denominator: int) -> int:
    if denominator == 0:
        raise ZeroDivisionError
    sign = -1 if (numerator < 0) != (denominator < 0) else 1
    quotient, remainder = divmod(abs(numerator), abs(denominator))
    if 2 * remainder >= abs(denominator):
        quotient += 1
    return sign * quotient


def mul_raw(left: int, right: int) -> int:
    return round_div(left * right, SCALE)


def div_raw(left: int, right: int) -> int:
    return round_div(left * SCALE, right)


def sqrt_raw(value: int) -> int:
    scaled = value * SCALE
    lower = math.isqrt(scaled)
    return lower + (1 if 2 * (scaled - lower * lower) >= 2 * lower + 1 else 0)


def resolve(
    *,
    attack: int,
    victim_hp: int,
    attacker_mass_raw: int,
    victim_mass_raw: int,
    impact_speed_raw: int,
    friendly: bool = False,
    critical: bool = False,
    outgoing_bonus_raw: int = 0,
    incoming_reduction_raw: int = 0,
    fixed_increase: int = 0,
    fixed_reduction: int = 0,
) -> tuple[int, int, int]:
    if impact_speed_raw < THRESHOLD_SPEED_RAW:
        return 0, 0, 0
    weight_raw = min(
        WEIGHT_MAX_RAW,
        max(WEIGHT_MIN_RAW, sqrt_raw(div_raw(attacker_mass_raw, victim_mass_raw))),
    )
    value_raw = attack * SCALE
    value_raw = mul_raw(value_raw, div_raw(impact_speed_raw, REFERENCE_SPEED_RAW))
    value_raw = mul_raw(value_raw, weight_raw)
    value_raw = mul_raw(value_raw, SCALE + outgoing_bonus_raw)
    value_raw = mul_raw(value_raw, SCALE - incoming_reduction_raw)
    if critical:
        value_raw = round_div(value_raw * 2, 1)
    if friendly:
        value_raw = round_div(value_raw, 2)
    value_raw += fixed_increase * SCALE
    value_raw -= fixed_reduction * SCALE
    resolved = max(1, round_div(value_raw, SCALE))
    return weight_raw, resolved, min(victim_hp, resolved)


def self_check() -> None:
    assert round_div(3, 2) == 2 and round_div(-3, 2) == -2
    assert resolve(
        attack=100,
        victim_hp=999,
        attacker_mass_raw=64 * SCALE,
        victim_mass_raw=64 * SCALE,
        impact_speed_raw=1024 * SCALE,
    ) == (SCALE, 100, 100)
    assert resolve(
        attack=100,
        victim_hp=999,
        attacker_mass_raw=64 * SCALE,
        victim_mass_raw=64 * SCALE,
        impact_speed_raw=63 * SCALE,
    ) == (0, 0, 0)


def check_fixture(path: Path) -> None:
    root = json.loads(path.read_text(encoding="utf-8"))
    assert root["schema_version"] == 1
    for item in root["vectors"]:
        actual = resolve(
            attack=item["attack"],
            victim_hp=item["victim_hp"],
            attacker_mass_raw=item["attacker_mass_units"] * SCALE,
            victim_mass_raw=item["victim_mass_units"] * SCALE,
            impact_speed_raw=item["impact_speed_units"] * SCALE,
            friendly=item.get("friendly", False),
            critical=item.get("critical", False),
            outgoing_bonus_raw=item.get("outgoing_bonus_raw", 0),
            incoming_reduction_raw=item.get("incoming_reduction_raw", 0),
            fixed_increase=item.get("fixed_increase", 0),
            fixed_reduction=item.get("fixed_reduction", 0),
        )
        assert list(actual) == item["expected"], (item["id"], actual)
