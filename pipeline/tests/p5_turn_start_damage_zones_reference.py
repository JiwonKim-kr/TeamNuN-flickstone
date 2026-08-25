#!/usr/bin/env python3
"""Independent integer known answers for P5 circle/polygon contact."""
from __future__ import annotations

SCALE = 65_536


def rect_overlaps_circle(left: int, top: int, right: int, bottom: int, x: int, y: int, radius: int) -> bool:
    closest_x = min(max(x, left), right)
    closest_y = min(max(y, top), bottom)
    dx = x - closest_x
    dy = y - closest_y
    return dx * dx + dy * dy <= radius * radius


def main() -> int:
    rect = (0, 0, 100 * SCALE, 100 * SCALE)
    radius = 32 * SCALE
    assert rect_overlaps_circle(*rect, 50 * SCALE, 50 * SCALE, radius)
    assert rect_overlaps_circle(*rect, 132 * SCALE, 50 * SCALE, radius)
    assert not rect_overlaps_circle(*rect, 132 * SCALE + 1, 50 * SCALE, radius)
    assert rect_overlaps_circle(*rect, 100 * SCALE, 100 * SCALE, radius)
    print("[PASS] P5-DZ-PY integer inside/boundary/tangent/outside KAT")
    print("P5_TURN_START_DAMAGE_ZONES_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
