#!/usr/bin/env python3
"""Independent P4-1 RunSnapshot v1 binary known-answer checks."""
from __future__ import annotations

import hashlib
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "scripts"))
from content_catalog import load_catalog  # noqa: E402
sys.path.insert(0, str(ROOT / "pipeline" / "tests"))
from p4_act_encounter_map_generation_reference import generate_graph  # noqa: E402

RUNTIME = ROOT / "src" / "core" / "data"
EXPECTED_FINGERPRINT = "8067a487ceb0ef2d721a3a985d8c5b7c0d8185cd4f52ce30c9d8cb59fd68edca"
EXPECTED_HEX = "464c49434b52554e0002008067a487ceb0ef2d721a3a985d8c5b7c0d8185cd4f52ce30c9d8cb59fd68edca110000001d00000001000100000000000000000003000300000000000a0005000700000001000000050007000000010000000100000001000100000002000200000003000000020000000200000003000100000001000400000003000000020001000400010000000100050000000400000003000000010001000000010006000000050000000300010002000300000001000600000006000000040000000500000000000100070000000700000005000000060004000000000000000000000000000600000001000000010000000100000002000000010000000100000003000000010000000100000004000000020000000100000005000000020000000100000006000000020000000100000000000000000001000000000000000000000000000000"
EXPECTED_SHA256 = "1cd25f0fb2f5202a57e10f959c6cfa90c57ada377013edc7dd9206251b981e80"


def encode_fixture() -> bytes:
    catalog = load_catalog(RUNTIME)
    fingerprint = catalog.fingerprint
    assert fingerprint.hex() == EXPECTED_FINGERPRINT
    out = bytearray(b"FLICKRUN\0")
    out += struct.pack("<H", 2)
    out += fingerprint
    out += struct.pack(
        "<IIHIHIHHIHHII",
        17, 29, 1, 1, 0, 0, 3, 3, 0, 10, 5, 7, 1,
    )
    nodes = generate_graph(catalog.acts[0], 17, 29)
    out += struct.pack("<HI", 5, len(nodes))
    for node_id, floor, slot, kind, content_id, edges in nodes:
        out += struct.pack("<IHHHIH", node_id, floor, slot, kind, content_id, len(edges))
        out += b"".join(struct.pack("<I", edge) for edge in edges)
    out += struct.pack("<II", 0, 0)  # visited, completed
    roster = [(1, 1), (2, 1), (3, 1), (4, 2), (5, 2), (6, 2)]
    out += struct.pack("<I", len(roster))
    for instance_id, piece_id in roster:
        out += struct.pack("<IIHH", instance_id, piece_id, 1, 0)
    out += struct.pack("<HHH", 0, 0, 0)  # deployment, relics, consumables
    out += struct.pack("<HIIH", 1, 0, 0, 0)  # pending NONE
    out += struct.pack("<I", 0)  # next battle status numeric ID
    return bytes(out)


def main() -> int:
    encoded = encode_fixture()
    encoded_hex = encoded.hex()
    digest = hashlib.sha256(encoded).hexdigest()
    if not EXPECTED_HEX or not EXPECTED_SHA256:
        print(f"P4_REFERENCE_HEX={encoded_hex}")
        print(f"P4_REFERENCE_SHA256={digest}")
        return 3
    assert encoded_hex == EXPECTED_HEX
    assert digest == EXPECTED_SHA256
    assert len(encoded) < 16 * 1024 * 1024
    assert encoded[:9] == b"FLICKRUN\0"
    assert struct.unpack_from("<H", encoded, 9)[0] == 2
    print("[PASS] P4-1-PY-FINGERPRINT current catalog fingerprint")
    print("[PASS] P4-1-PY-BINARY exact little-endian fixture bytes")
    print("[PASS] P4-1-PY-SHA256 independent full snapshot KAT")
    print("P4_RUN_STATE_SNAPSHOT_REFERENCE_RESULT: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError) as exc:
        print(f"P4_RUN_STATE_SNAPSHOT_REFERENCE_RESULT: FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
