#!/usr/bin/env python3
"""Small independent integer reference for the approved P1-1 CTB rules."""
from __future__ import annotations

from dataclasses import dataclass, replace
import json
from pathlib import Path

THRESHOLD = 10_000


@dataclass(frozen=True)
class Participant:
    body_id: int
    faction: int
    speed: int
    ct: int = 0
    has_turn: bool = True


def select(items: list[Participant], now: int, last_faction: int) -> tuple[list[Participant], int, int]:
    active = [item for item in items if item.has_turn]
    if not active:
        raise ValueError("no eligible actor")
    delta = 0 if any(item.ct >= THRESHOLD for item in active) else min(
        (THRESHOLD - item.ct + item.speed - 1) // item.speed for item in active
    )
    advanced = [replace(item, ct=item.ct + item.speed * delta) if item.has_turn else item for item in items]
    opposite = 2 if last_faction == 1 else 1 if last_faction == 2 else 0
    ready = [item for item in advanced if item.has_turn and item.ct >= THRESHOLD]
    actor = min(
        ready,
        key=lambda item: (
            -(item.ct - THRESHOLD),
            -item.speed,
            0 if item.faction == opposite else 1,
            item.body_id,
        ),
    )
    return advanced, now + delta, actor.body_id


def sequence(items: list[Participant], count: int) -> list[int]:
    now = 0
    last = 0
    result: list[int] = []
    local = list(items)
    for _ in range(count):
        local, now, actor_id = select(local, now, last)
        actor = next(item for item in local if item.body_id == actor_id)
        local = [replace(item, ct=item.ct - THRESHOLD) if item.body_id == actor_id else item for item in local]
        last = actor.faction
        result.append(actor_id)
    return result


def forced_damp(raw: int) -> int:
    sign = -1 if raw < 0 else 1
    value = abs(raw) * 3
    quotient, remainder = divmod(value, 4)
    if remainder * 2 >= 4:
        quotient += 1
    return sign * quotient


def self_check() -> None:
    tied = [Participant(i, 1 if i <= 3 else 2, 100, THRESHOLD) for i in range(1, 7)]
    assert sequence(tied, 6) == [1, 4, 2, 5, 3, 6]
    advanced, _, actor = select([Participant(1, 1, 64, 9990)], 0, 0)
    assert actor == 1 and advanced[0].ct == 10054
    assert forced_damp(4096 << 16) == (4096 << 16) * 3 // 4


def check_fixture(path: Path) -> None:
    payload = json.loads(path.read_text(encoding="utf-8"))
    tied = [Participant(i, 1 if i <= 3 else 2, 100, THRESHOLD) for i in range(1, 7)]
    assert payload["schema"] == 1
    assert payload["ct_threshold"] == THRESHOLD
    assert payload["complete_tie_3v3"] == sequence(tied, 6)
    overshoot = payload["overshoot"]
    advanced, _, _ = select([Participant(1, 1, overshoot["speed"], overshoot["ct"])], 0, 0)
    assert advanced[0].ct == overshoot["ready_ct"]
    assert advanced[0].ct - THRESHOLD == overshoot["after_action_ct"]
    damping = payload["forced_damping"]
    assert forced_damp(damping["max_speed_raw"]) == damping["damped_raw"]


if __name__ == "__main__":
    self_check()
    check_fixture(Path(__file__).with_name("fixtures") / "p1_ctb_vectors.json")
    print("P1_CTB_REFERENCE_RESULT: PASS")
