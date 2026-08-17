#!/usr/bin/env python3
"""Independent Python reference and checked-fixture tool for P0 SimRng."""
from __future__ import annotations

import argparse
import json
import struct
from dataclasses import dataclass
from pathlib import Path


U32_MASK = 0xFFFF_FFFF
U32_SPACE = 0x1_0000_0000
DOMAIN_FSR1 = 0x3152_5346

# Published-in-repository known answers. These intentionally do not come from
# build_fixture(): changing the implementation and regenerating the fixture in
# one edit must still trip an independently reviewed anchor.
DIRECT_KAT_INITIAL_STATE = (0x0000_0001, 0x0000_0002, 0x0000_0003, 0x0000_0004)
DIRECT_KAT_OUTPUTS = (
    0x0000_2D00,
    0x0000_0000,
    0x005A_7080,
    0x0438_9D80,
    0x7919_9D9B,
    0x6196_3B24,
    0x4CB9_B57A,
    0xDE9D_7431,
    0xDE45_8F35,
    0xFDCE_1A54,
    0x1422_DCBD,
    0x7FB4_D43B,
    0xD533_4125,
    0x7792_B516,
    0xE6AF_25FC,
    0x3BB2_F7D2,
)
FSR1_KAT_INPUT = (
    0x0123_4567,
    0x89AB_CDEF,
    0x0000_1234,
    0x89AB_CDEF,
    0x1020_3040,
)
FSR1_KAT_STATE = (0x6435_482F, 0x5F3E_0CD0, 0x19AA_9E59, 0xF9D9_06B7)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FIXTURE = REPO_ROOT / "pipeline" / "tests" / "fixtures" / "p0_rng_vectors.json"


def u32(value: int) -> int:
    return value & U32_MASK


def rotl32(value: int, shift: int) -> int:
    shift &= 31
    return u32((value << shift) | (value >> (32 - shift))) if shift else u32(value)


def fmix32(value: int) -> int:
    value = u32(value)
    value ^= value >> 16
    value = u32(value * 0x85EB_CA6B)
    value ^= value >> 13
    value = u32(value * 0xC2B2_AE35)
    value ^= value >> 16
    return u32(value)


def murmurhash3_x86_128(data: bytes, seed: int = 0) -> tuple[int, int, int, int]:
    """Byte-oriented MurmurHash3 x86_128 reference implementation."""
    c1, c2, c3, c4 = 0x239B_961B, 0xAB0E_9789, 0x38B3_4AE5, 0xA1E3_8B93
    h1 = h2 = h3 = h4 = u32(seed)
    block_count = len(data) // 16

    for block_index in range(block_count):
        k1, k2, k3, k4 = struct.unpack_from("<4I", data, block_index * 16)

        k1 = u32(k1 * c1)
        k1 = rotl32(k1, 15)
        k1 = u32(k1 * c2)
        h1 ^= k1
        h1 = rotl32(h1, 19)
        h1 = u32(h1 + h2)
        h1 = u32(h1 * 5 + 0x561C_CD1B)

        k2 = u32(k2 * c2)
        k2 = rotl32(k2, 16)
        k2 = u32(k2 * c3)
        h2 ^= k2
        h2 = rotl32(h2, 17)
        h2 = u32(h2 + h3)
        h2 = u32(h2 * 5 + 0x0BCA_A747)

        k3 = u32(k3 * c3)
        k3 = rotl32(k3, 17)
        k3 = u32(k3 * c4)
        h3 ^= k3
        h3 = rotl32(h3, 15)
        h3 = u32(h3 + h4)
        h3 = u32(h3 * 5 + 0x96CD_1C35)

        k4 = u32(k4 * c4)
        k4 = rotl32(k4, 18)
        k4 = u32(k4 * c1)
        h4 ^= k4
        h4 = rotl32(h4, 13)
        h4 = u32(h4 + h1)
        h4 = u32(h4 * 5 + 0x32AC_3B17)

    tail = data[block_count * 16 :]
    k1 = k2 = k3 = k4 = 0
    # Fall-through switch from the reference, expressed as length thresholds.
    if len(tail) >= 15:
        k4 ^= tail[14] << 16
    if len(tail) >= 14:
        k4 ^= tail[13] << 8
    if len(tail) >= 13:
        k4 ^= tail[12]
        k4 = u32(k4 * c4)
        k4 = rotl32(k4, 18)
        k4 = u32(k4 * c1)
        h4 ^= k4
    if len(tail) >= 12:
        k3 ^= tail[11] << 24
    if len(tail) >= 11:
        k3 ^= tail[10] << 16
    if len(tail) >= 10:
        k3 ^= tail[9] << 8
    if len(tail) >= 9:
        k3 ^= tail[8]
        k3 = u32(k3 * c3)
        k3 = rotl32(k3, 17)
        k3 = u32(k3 * c4)
        h3 ^= k3
    if len(tail) >= 8:
        k2 ^= tail[7] << 24
    if len(tail) >= 7:
        k2 ^= tail[6] << 16
    if len(tail) >= 6:
        k2 ^= tail[5] << 8
    if len(tail) >= 5:
        k2 ^= tail[4]
        k2 = u32(k2 * c2)
        k2 = rotl32(k2, 16)
        k2 = u32(k2 * c3)
        h2 ^= k2
    if len(tail) >= 4:
        k1 ^= tail[3] << 24
    if len(tail) >= 3:
        k1 ^= tail[2] << 16
    if len(tail) >= 2:
        k1 ^= tail[1] << 8
    if len(tail) >= 1:
        k1 ^= tail[0]
        k1 = u32(k1 * c1)
        k1 = rotl32(k1, 15)
        k1 = u32(k1 * c2)
        h1 ^= k1

    length = len(data)
    h1 ^= length
    h2 ^= length
    h3 ^= length
    h4 ^= length
    h1 = u32(h1 + h2 + h3 + h4)
    h2 = u32(h2 + h1)
    h3 = u32(h3 + h1)
    h4 = u32(h4 + h1)
    h1, h2, h3, h4 = fmix32(h1), fmix32(h2), fmix32(h3), fmix32(h4)
    h1 = u32(h1 + h2 + h3 + h4)
    h2 = u32(h2 + h1)
    h3 = u32(h3 + h1)
    h4 = u32(h4 + h1)
    return h1, h2, h3, h4


def derive_state(
    seed_hi: int,
    seed_lo: int,
    purpose_id: int,
    owner_id: int,
    ordinal: int,
) -> tuple[int, int, int, int]:
    words = (DOMAIN_FSR1, seed_lo, seed_hi, purpose_id, owner_id, ordinal)
    key = struct.pack("<6I", *words)
    hash_seed = 0
    while True:
        state = murmurhash3_x86_128(key, hash_seed)
        if any(state):
            return state
        hash_seed += 1
        if hash_seed > U32_MASK:
            raise RuntimeError("could not derive a non-zero state")


@dataclass
class Xoshiro128StarStar:
    state: list[int]
    draw_count: int = 0

    def next_u32(self) -> int:
        s0, s1, s2, s3 = self.state
        result = u32(rotl32(u32(s1 * 5), 7) * 9)
        shifted = u32(s1 << 9)
        s2 = u32(s2 ^ s0)
        s3 = u32(s3 ^ s1)
        s1 = u32(s1 ^ s2)
        s0 = u32(s0 ^ s3)
        s2 = u32(s2 ^ shifted)
        s3 = rotl32(s3, 11)
        self.state = [s0, s1, s2, s3]
        self.draw_count += 1
        return result

    def next_below(self, bound: int) -> int:
        # U-23 has not decided the consumption rule for a degenerate range.
        # Match the runtime API by rejecting bound=1 until that rule is approved.
        if not 2 <= bound <= U32_SPACE:
            raise ValueError("bound must be in 2..2^32 while U-23 is pending")
        limit = U32_SPACE - (U32_SPACE % bound)
        while True:
            value = self.next_u32()
            if value < limit:
                return value % bound


def check_known_answers() -> tuple[str, object, object] | None:
    """Return the first implementation/anchor mismatch, if one exists."""
    direct_rng = Xoshiro128StarStar(list(DIRECT_KAT_INITIAL_STATE))
    direct_actual = tuple(direct_rng.next_u32() for _ in DIRECT_KAT_OUTPUTS)
    if direct_actual != DIRECT_KAT_OUTPUTS:
        for index, (expected, actual) in enumerate(zip(DIRECT_KAT_OUTPUTS, direct_actual)):
            if expected != actual:
                return (
                    f"$.known_answers.xoshiro128starstar.outputs[{index}]",
                    _hex32(expected),
                    _hex32(actual),
                )

    derived_actual = derive_state(*FSR1_KAT_INPUT)
    if derived_actual != FSR1_KAT_STATE:
        for index, (expected, actual) in enumerate(zip(FSR1_KAT_STATE, derived_actual)):
            if expected != actual:
                return (
                    f"$.known_answers.fsr1.state[{index}]",
                    _hex32(expected),
                    _hex32(actual),
                )
    return None


def _hex32(value: int) -> str:
    return f"{value:08x}"


def _hex64(value: int) -> str:
    return f"{value:016x}"


def _vector_case(name: str, initial_state: tuple[int, ...]) -> dict[str, object]:
    rng = Xoshiro128StarStar(list(initial_state))
    outputs = [_hex32(rng.next_u32()) for _ in range(1_000)]
    return {
        "name": name,
        "initial_state": [_hex32(word) for word in initial_state],
        "outputs": outputs,
        "final_state": [_hex32(word) for word in rng.state],
        "draw_count": _hex64(rng.draw_count),
    }


def build_fixture() -> dict[str, object]:
    seed_hi, seed_lo = 0x0123_4567, 0x89AB_CDEF
    purpose_id, owner_id, ordinal = 0x1234, 0x89AB_CDEF, 0x1020_3040
    derived = derive_state(seed_hi, seed_lo, purpose_id, owner_id, ordinal)

    rejection_rng = Xoshiro128StarStar([1, 2, 3, 4])
    for _ in range(7):
        rejection_rng.next_u32()
    rejection_pre_state = tuple(rejection_rng.state)
    rejection_pre_count = rejection_rng.draw_count
    accepted = rejection_rng.next_below(0x8000_0001)

    return {
        "schema_version": 1,
        "algorithm": "xoshiro128starstar-1.1",
        "derivation": "murmurhash3-x86-128-fsr1",
        "direct_state": _vector_case("state-00000001-00000002-00000003-00000004", (1, 2, 3, 4)),
        "derived_stream": {
            "root_seed": "0123456789abcdef",
            "purpose_id": "1234",
            "owner_id": "89abcdef",
            "ordinal": "10203040",
            **_vector_case("fsr1-reference-stream", derived),
        },
        "rejection_case": {
            "bound": "80000001",
            "pre_state": [_hex32(word) for word in rejection_pre_state],
            "pre_draw_count": _hex64(rejection_pre_count),
            "accepted": _hex32(accepted),
            "post_state": [_hex32(word) for word in rejection_rng.state],
            "post_draw_count": _hex64(rejection_rng.draw_count),
        },
    }


def render_fixture() -> str:
    return json.dumps(build_fixture(), ensure_ascii=False, indent=2) + "\n"


_MISSING = object()


def _first_json_mismatch(
    expected: object,
    actual: object,
    path: str = "$",
) -> tuple[str, object, object] | None:
    """Locate the first deterministic, depth-first JSON value mismatch."""
    if type(expected) is not type(actual):
        return path, expected, actual
    if isinstance(expected, dict):
        assert isinstance(actual, dict)
        for key, expected_value in expected.items():
            child_path = f"{path}.{key}"
            if key not in actual:
                return child_path, expected_value, _MISSING
            mismatch = _first_json_mismatch(expected_value, actual[key], child_path)
            if mismatch is not None:
                return mismatch
        for key, actual_value in actual.items():
            if key not in expected:
                return f"{path}.{key}", _MISSING, actual_value
        return None
    if isinstance(expected, list):
        assert isinstance(actual, list)
        for index, expected_value in enumerate(expected):
            child_path = f"{path}[{index}]"
            if index >= len(actual):
                return child_path, expected_value, _MISSING
            mismatch = _first_json_mismatch(expected_value, actual[index], child_path)
            if mismatch is not None:
                return mismatch
        if len(actual) > len(expected):
            return f"{path}[{len(expected)}]", _MISSING, actual[len(expected)]
        return None
    if expected != actual:
        return path, expected, actual
    return None


def _format_json_value(value: object) -> str:
    if value is _MISSING:
        return "<missing>"
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def _print_mismatch(prefix: str, mismatch: tuple[str, object, object]) -> None:
    path, expected, actual = mismatch
    print(prefix)
    print(f"  path: {path}")
    print(f"  expected: {_format_json_value(expected)}")
    print(f"  actual: {_format_json_value(actual)}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, default=DEFAULT_FIXTURE)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args(argv)
    fixture = args.fixture.resolve()

    anchor_mismatch = check_known_answers()
    if anchor_mismatch is not None:
        _print_mismatch("[FAIL] RNG implementation differs from fixed known answers", anchor_mismatch)
        return 1

    expected_data = build_fixture()
    expected = render_fixture()
    if args.write:
        fixture.parent.mkdir(parents=True, exist_ok=True)
        fixture.write_text(expected, encoding="utf-8", newline="\n")
        print(f"wrote RNG fixture: {fixture}")
        return 0
    if not fixture.exists():
        print(f"[FAIL] RNG fixture is missing: {fixture}")
        return 1
    try:
        actual_data = json.loads(fixture.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"[FAIL] RNG fixture is not readable JSON: {fixture}")
        print("  path: $")
        print("  expected: valid fixture JSON")
        print(f"  actual: {exc}")
        return 1
    fixture_mismatch = _first_json_mismatch(expected_data, actual_data)
    if fixture_mismatch is not None:
        _print_mismatch(
            f"[FAIL] RNG fixture differs from the independent reference: {fixture}",
            fixture_mismatch,
        )
        return 1
    print(f"[PASS] RNG fixture matches the independent reference: {fixture}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
