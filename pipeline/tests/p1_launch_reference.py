#!/usr/bin/env python3
"""Independent P1-2 command, quantization, and launch-speed reference."""
from __future__ import annotations

import json
import math
from pathlib import Path

SCALE = 1 << 16
ANGLE_STEP = 256
POWER_STEPS = 256
MAX_DRAG_RAW = 192 * SCALE
BASE_SPEED_RAW = 1536 * SCALE
ABSOLUTE_SPEED_RAW = 2048 * SCALE
REFERENCE_MASS_RAW = 64 * SCALE


def round_div(numerator: int, denominator: int) -> int:
    if denominator == 0:
        raise ZeroDivisionError
    sign = -1 if (numerator < 0) != (denominator < 0) else 1
    q, r = divmod(abs(numerator), abs(denominator))
    if 2 * r >= abs(denominator):
        q += 1
    return sign * q


def sqrt_nearest(value: int) -> int:
    lower = math.isqrt(value)
    return lower + (1 if 2 * (value - lower * lower) >= 2 * lower + 1 else 0)


def sqrt_raw(value_raw: int) -> int:
    return sqrt_nearest(value_raw * SCALE)


def power_step(length_raw: int) -> int:
    if length_raw >= MAX_DRAG_RAW:
        return POWER_STEPS
    return round_div(length_raw * POWER_STEPS, MAX_DRAG_RAW)


def encode_command(angle: int, power: int) -> bytes:
    if angle < 0 or angle > 0xFFFF or angle % ANGLE_STEP or power < 0 or power > POWER_STEPS:
        raise ValueError("invalid command")
    return (1).to_bytes(2, "little") + angle.to_bytes(2, "little") + power.to_bytes(2, "little")


def speed_raw(power: int, mass_units: int) -> int:
    power_raw = round_div(power * SCALE, POWER_STEPS)
    base = round_div(BASE_SPEED_RAW * power_raw, SCALE)
    ratio = round_div(REFERENCE_MASS_RAW * SCALE, mass_units * SCALE)
    weighted = round_div(base * sqrt_raw(ratio), SCALE)
    return min(weighted, ABSOLUTE_SPEED_RAW)


def self_check() -> None:
    assert round_div(3, 2) == 2 and round_div(-3, 2) == -2
    assert power_step(24 * SCALE) == 32
    assert encode_command(0, 256).hex() == "010000000001"
    assert speed_raw(256, 16) == 2048 * SCALE
    assert speed_raw(256, 64) == 1536 * SCALE
    assert speed_raw(256, 256) == 768 * SCALE


def check_fixture(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    for item in data["commands"]:
        assert encode_command(item["angle"], item["power_step"]).hex() == item["hex"]
    for item in data["powers"]:
        assert power_step(item["drag_raw"]) == item["power_step"]
    for item in data["speeds"]:
        assert speed_raw(item["power_step"], item["mass_units"]) == item["speed_raw"]
