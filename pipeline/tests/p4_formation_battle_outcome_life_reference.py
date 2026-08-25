#!/usr/bin/env python3
"""Independent P4-3 battle-seed known-answer test."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "tests"))

from p0_rng_reference import Xoshiro128StarStar, derive_state  # noqa: E402


def main() -> int:
    rng = Xoshiro128StarStar(list(derive_state(17, 29, 8, 1, 1)))
    assert (rng.next_u32(), rng.next_u32()) == (3874717381, 1837807032)
    for _ in range(1000):
        repeat = Xoshiro128StarStar(list(derive_state(17, 29, 8, 1, 1)))
        assert (repeat.next_u32(), repeat.next_u32()) == (3874717381, 1837807032)
    separated = Xoshiro128StarStar(list(derive_state(17, 29, 8, 1, 2)))
    assert (separated.next_u32(), separated.next_u32()) != (3874717381, 1837807032)
    print("[PASS] P4-3-PY-BATTLE-SEED independent FSR1 KAT")
    print("[PASS] P4-3-PY-DETERMINISM 1000 repeats and node separation")
    print("P4_FORMATION_BATTLE_OUTCOME_LIFE_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"P4_FORMATION_BATTLE_OUTCOME_LIFE_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
