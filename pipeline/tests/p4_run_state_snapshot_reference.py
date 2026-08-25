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
EXPECTED_FINGERPRINT = "16df0d24ed90733b2f5f8b3761fd37830154e550c74fc00adba3a9445fa07167"
EXPECTED_HEX = "464c49434b52554e00010016df0d24ed90733b2f5f8b3761fd37830154e550c74fc00adba3a9445fa07167110000001d00000001000100000000000000000003000300000000000a00050007000000010000000500070000000100000001000000010001000000020002000000030000000200000002000000030001000000010004000000030000000200010004000100000001000500000004000000030000000100010000000100060000000500000003000100020003000000010006000000060000000400000005000000000001000700000007000000050000000600040000000000000000000000000006000000010000000100000001000000020000000100000001000000030000000100000001000000040000000200000001000000050000000200000001000000060000000200000001000000000000000000010000000000000000000000"
EXPECTED_SHA256 = "8c8671cd39afe6defc986644d56122315cd6191d03793416620d2fbf95f87c04"


def encode_fixture() -> bytes:
    catalog = load_catalog(RUNTIME)
    fingerprint = catalog.fingerprint
    assert fingerprint.hex() == EXPECTED_FINGERPRINT
    out = bytearray(b"FLICKRUN\0")
    out += struct.pack("<H", 1)
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
    assert struct.unpack_from("<H", encoded, 9)[0] == 1
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
