#!/usr/bin/env python3
"""Independent P2-1 parser, schema, canonical-byte, and fingerprint KAT."""
from __future__ import annotations

import json
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "scripts"))
from content_catalog import ContentError, load_catalog, strict_load_bytes  # noqa: E402

FIXTURES = ROOT / "pipeline" / "tests" / "fixtures"
CATALOG_FIXTURES = FIXTURES / "p2_content_catalog"
VECTORS = FIXTURES / "p2_content_catalog_vectors.json"


def _expect_failure(data: bytes, label: str) -> None:
    try:
        strict_load_bytes(data)
    except ContentError:
        return
    raise AssertionError(f"strict parser accepted {label}")


def main() -> int:
    vectors = json.loads(VECTORS.read_text(encoding="utf-8"))
    runtime = load_catalog(ROOT / "src" / "core" / "data")
    valid_a = load_catalog(CATALOG_FIXTURES / "valid_a")
    reordered = load_catalog(CATALOG_FIXTURES / "valid_reordered")
    valid_b = load_catalog(CATALOG_FIXTURES / "valid_b")

    empty_bytes = bytes.fromhex(vectors["empty_runtime"]["canonical_hex"])
    assert hashlib.sha256(empty_bytes).hexdigest() == vectors["empty_runtime"]["fingerprint"]
    assert runtime.fingerprint.hex() == "aa7758ad0ccbb5ef73fe66f162b004243b3410a536c559e7ff584139267e7ee1"
    assert (
        len(runtime.pieces), len(runtime.abilities), len(runtime.statuses),
        len(runtime.synergies), len(runtime.maps), len(runtime.enemies),
        len(runtime.acts), len(runtime.encounters),
    ) == (6, 3, 2, 2, 1, 5, 1, 4)
    assert valid_a.fingerprint.hex() == vectors["valid_a"]["fingerprint"]
    assert valid_b.fingerprint.hex() == vectors["valid_b"]["fingerprint"]
    assert valid_a.compatibility_bytes == reordered.compatibility_bytes
    assert valid_a.fingerprint == reordered.fingerprint
    assert valid_a.fingerprint != valid_b.fingerprint

    valid_numbers = strict_load_bytes(b'{"min":-9223372036854775808,"max":9223372036854775807,"negative_zero":-0}')
    assert valid_numbers == {"min": -(1 << 63), "max": (1 << 63) - 1, "negative_zero": 0}
    for label, data in {
        "duplicate": b'{"x":1,"x":2}',
        "trailing_comma": b'{"x":1,}',
        "decimal": b'{"x":1.0}',
        "exponent": b'{"x":1e2}',
        "leading_zero": b'{"x":01}',
        "positive_overflow": b'{"x":9223372036854775808}',
        "negative_overflow": b'{"x":-9223372036854775809}',
        "raw_newline": b'{"x":"a\nb"}',
        "comment": b'{"x":1//x\n}',
        "nan": b'{"x":NaN}',
        "bom": b'\xef\xbb\xbf{}',
        "invalid_utf8": b'{"x":"\xff"}',
        "lone_surrogate": b'{"x":"\\ud800"}',
    }.items():
        _expect_failure(data, label)

    _expect_failure(("[" * 33 + "0" + "]" * 33).encode(), "depth")
    _expect_failure(("[" + ",".join("0" for _ in range(4097)) + "]").encode(), "array_limit")
    _expect_failure(json.dumps("x" * 4097).encode(), "string_limit")

    for directory in ("invalid_missing_reference", "invalid_extra_file"):
        try:
            load_catalog(CATALOG_FIXTURES / directory)
        except ContentError:
            pass
        else:
            raise AssertionError(f"invalid fixture accepted: {directory}")

    print("[PASS] P2-1-PY-STRICT parser rejects non-standard and lossy inputs")
    print("[PASS] P2-1-PY-SCHEMA registry, references, ranges, and document set")
    print("[PASS] P2-1-PY-CANONICAL order-independent bytes and SHA-256 KAT")
    print("P2_CONTENT_CATALOG_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ContentError, OSError) as exc:
        print(f"P2_CONTENT_CATALOG_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
