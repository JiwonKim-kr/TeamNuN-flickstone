#!/usr/bin/env python3
"""P0-4 canonical snapshot, SHA-256, and determinism acceptance runner."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import godot_test_support


REPO_ROOT = Path(__file__).resolve().parents[2]
TEST_SCRIPT = "res://pipeline/tests/p0_determinism_test.gd"
SCENARIO_REL = Path("pipeline/tests/fixtures/p0_scenarios.json")
GOLDEN_REL = Path("pipeline/tests/fixtures/p0_golden_hashes.json")
FAILURE_REL = Path("pipeline/artifacts/determinism_failure")
SKIP_GODOT_ENV = "ARTIFICER_SKIP_GODOT_TESTS"
SNAPSHOT_RE = re.compile(
    r"^P0_SNAPSHOT\|([a-z0-9_]+)\|(\d+)\|([0-9a-f]{64})\|([0-9a-f]+)$"
)
SCENARIO_ID_RE = re.compile(r"^[a-z0-9_]+$")
SEED_RE = re.compile(r"^[0-9a-f]{16}$")
DEMO_CI_PROFILE = "demo"
DEMO_REPEAT_COUNT = "20"
DEMO_PERMUTATION_COUNT = "3"


def _ci_quick_profile_error(env: dict[str, str]) -> str | None:
    """Reject accidental weakening of CI outside the approved demo profile."""
    if not env.get("CI") or env.get("P0_ALLOW_QUICK") != "1":
        return None
    if env.get("FLICKSTONE_CI_PROFILE") != DEMO_CI_PROFILE:
        return "CI quick mode requires FLICKSTONE_CI_PROFILE=demo"
    if env.get("P0_REPEAT_COUNT") != DEMO_REPEAT_COUNT:
        return f"demo CI requires P0_REPEAT_COUNT={DEMO_REPEAT_COUNT}"
    if env.get("P0_PERMUTATION_COUNT") != DEMO_PERMUTATION_COUNT:
        return f"demo CI requires P0_PERMUTATION_COUNT={DEMO_PERMUTATION_COUNT}"
    return None


def _reject_float(value: str) -> None:
    raise ValueError(f"JSON float is forbidden in P0 fixtures: {value}")


def _load_integer_json(path: Path) -> dict[str, Any]:
    loaded = json.loads(
        path.read_text(encoding="utf-8"),
        parse_int=int,
        parse_float=_reject_float,
        parse_constant=_reject_float,
    )
    if not isinstance(loaded, dict):
        raise ValueError(f"root must be an object: {path}")
    return loaded


def _validate_scenarios(root: dict[str, Any]) -> list[dict[str, Any]]:
    if type(root.get("schema_version")) is not int or root.get("schema_version") != 1:
        raise ValueError("p0_scenarios schema_version must be 1")
    scenarios = root.get("scenarios")
    if not isinstance(scenarios, list) or len(scenarios) != 6:
        raise ValueError("p0_scenarios must contain exactly six scenarios")
    seen: set[str] = set()
    for scenario in scenarios:
        if not isinstance(scenario, dict):
            raise ValueError("scenario must be an object")
        scenario_id = scenario.get("scenario_id")
        seed = scenario.get("seed")
        ticks = scenario.get("ticks")
        if not isinstance(scenario_id, str) or not SCENARIO_ID_RE.fullmatch(scenario_id):
            raise ValueError(f"invalid ASCII scenario_id: {scenario_id!r}")
        if scenario_id in seen:
            raise ValueError(f"duplicate scenario_id: {scenario_id}")
        seen.add(scenario_id)
        if not isinstance(seed, str) or not SEED_RE.fullmatch(seed):
            raise ValueError(f"{scenario_id}: seed must be 16 lowercase hex digits")
        if type(ticks) is not int or ticks < 0:
            raise ValueError(f"{scenario_id}: ticks must be a non-negative integer")
        inputs = scenario.get("inputs")
        if not isinstance(inputs, list):
            raise ValueError(f"{scenario_id}: inputs must be an array")
        previous: tuple[int, int] | None = None
        for item in inputs:
            if not isinstance(item, dict):
                raise ValueError(f"{scenario_id}: input must be an object")
            tick = item.get("tick")
            sequence = item.get("sequence")
            body_id = item.get("body_id")
            angle = item.get("angle")
            power = item.get("power_raw")
            if not all(type(value) is int for value in (tick, sequence, body_id, angle, power)):
                raise ValueError(f"{scenario_id}: all input fields must be integers")
            key = (tick, sequence)
            if tick < 0 or tick >= ticks or previous is not None and key <= previous:
                raise ValueError(f"{scenario_id}: inputs are not strictly ordered at {key}")
            if not 0 < sequence <= 0xFFFFFFFF or not 0 < body_id <= 0xFFFFFFFF:
                raise ValueError(f"{scenario_id}: input uint32 field out of range")
            if not 0 <= angle <= 0xFFFF or not 0 <= power <= 65536:
                raise ValueError(f"{scenario_id}: angle or power out of range")
            previous = key
    return scenarios


def _check_core_boundary(project: Path) -> list[str]:
    failures: list[str] = []
    sim_dir = project / "src" / "core" / "sim"
    for name in ("sim_snapshot.gd", "sim_state_hash.gd"):
        path = sim_dir / name
        if not path.is_file():
            failures.append(f"missing core file: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        if re.search(r"^extends\s+(?:Node|Node2D)\b", text, re.MULTILINE):
            failures.append(f"{name}: simulation core must not inherit Node")
        for token in ("HashingContext", "var_to_bytes(", "RandomNumberGenerator"):
            if token in text:
                failures.append(f"{name}: forbidden core token {token!r}")
    return failures


def _parse_snapshots(output: str) -> dict[str, list[tuple[str, bytes]]]:
    parsed: dict[str, list[tuple[str, bytes]]] = {}
    for line in output.splitlines():
        match = SNAPSHOT_RE.fullmatch(line.strip())
        if not match:
            continue
        scenario_id, tick_text, reported_hash, encoded_hex = match.groups()
        tick = int(tick_text)
        encoded = bytes.fromhex(encoded_hex)
        if len(encoded) < 27 or encoded[:9] != b"FLICKSIM\0":
            raise ValueError(f"{scenario_id} tick {tick}: invalid canonical prefix")
        if int.from_bytes(encoded[9:11], "little", signed=False) != 2:
            raise ValueError(f"{scenario_id} tick {tick}: invalid schema version bytes")
        encoded_tick = int.from_bytes(encoded[11:19], "little", signed=True)
        if encoded_tick != tick:
            raise ValueError(
                f"{scenario_id} tick {tick}: canonical tick decoded as {encoded_tick}"
            )
        python_hash = hashlib.sha256(encoded).hexdigest()
        if python_hash != reported_hash:
            raise ValueError(
                f"{scenario_id} tick {tick}: pure/Godot hash {reported_hash} "
                f"!= Python hashlib {python_hash}"
            )
        records = parsed.setdefault(scenario_id, [])
        if tick != len(records):
            raise ValueError(
                f"{scenario_id}: snapshot ticks must be contiguous; "
                f"expected {len(records)}, got {tick}"
            )
        records.append((reported_hash, encoded))
    return parsed


def _failure_artifacts(
    project: Path,
    scenario: dict[str, Any],
    tick: int,
    expected: str,
    actual: str,
    snapshot: bytes,
) -> None:
    target = project / FAILURE_REL
    target.mkdir(parents=True, exist_ok=True)
    scenario_id = str(scenario["scenario_id"])
    reproduction = {
        "scenario": scenario,
        "first_mismatch_tick": tick,
        "expected_hash": expected,
        "actual_hash": actual,
    }
    (target / f"{scenario_id}.json").write_text(
        json.dumps(reproduction, ensure_ascii=True, indent=2) + "\n",
        encoding="utf-8",
    )
    (target / f"{scenario_id}-tick-{tick}.bin").write_bytes(snapshot)


def _golden_payload(
    scenarios: list[dict[str, Any]],
    records: dict[str, list[tuple[str, bytes]]],
    approval_ref: str,
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "approval_ref": approval_ref,
        "scenarios": {
            str(scenario["scenario_id"]): {
                "seed": scenario["seed"],
                "step_hashes": [item[0] for item in records[str(scenario["scenario_id"])]],
            }
            for scenario in scenarios
        },
    }


def _print_update_summary(old: dict[str, Any], new: dict[str, Any]) -> None:
    old_scenarios = old.get("scenarios", {})
    for scenario_id, item in new["scenarios"].items():
        before = old_scenarios.get(scenario_id, {}).get("step_hashes", [])
        after = item["step_hashes"]
        changed = [
            index
            for index in range(max(len(before), len(after)))
            if index >= len(before) or index >= len(after) or before[index] != after[index]
        ]
        first = "none" if not changed else str(changed[0])
        old_final = "<missing>" if not before else before[-1]
        new_final = "<missing>" if not after else after[-1]
        print(
            f"[GOLDEN] {scenario_id}: first_changed_tick={first} "
            f"old_final={old_final} new_final={new_final} changed={len(changed)}"
        )


def _compare_goldens(
    project: Path,
    scenarios: list[dict[str, Any]],
    records: dict[str, list[tuple[str, bytes]]],
    goldens: dict[str, Any],
) -> list[str]:
    failures: list[str] = []
    expected_scenarios = goldens.get("scenarios")
    if goldens.get("schema_version") != 1 or not isinstance(expected_scenarios, dict):
        return ["p0_golden_hashes schema is invalid"]
    for scenario in scenarios:
        scenario_id = str(scenario["scenario_id"])
        actual_records = records.get(scenario_id, [])
        expected_item = expected_scenarios.get(scenario_id)
        if not isinstance(expected_item, dict):
            failures.append(f"{scenario_id}: missing golden scenario")
            continue
        expected = expected_item.get("step_hashes")
        if not isinstance(expected, list):
            failures.append(f"{scenario_id}: step_hashes is not an array")
            continue
        actual = [item[0] for item in actual_records]
        if len(expected) != len(actual):
            failures.append(
                f"{scenario_id}: expected {len(expected)} hashes, got {len(actual)}"
            )
            continue
        for tick, (expected_hash, actual_hash) in enumerate(zip(expected, actual)):
            if expected_hash == actual_hash:
                continue
            failures.append(
                f"scenario={scenario_id} seed={scenario['seed']} "
                f"first_mismatch_tick={tick} expected={expected_hash} actual={actual_hash} "
                f"godot={os.environ.get('GODOT_BIN', 'godot')} os={sys.platform}"
            )
            _failure_artifacts(
                project,
                scenario,
                tick,
                str(expected_hash),
                actual_hash,
                actual_records[tick][1],
            )
            break
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=REPO_ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--update-goldens", action="store_true")
    parser.add_argument("--approval-ref", default="")
    args = parser.parse_args(argv)
    project = args.project.resolve()

    print("=" * 72)
    print("P0-4 acceptance: canonical snapshot / SHA-256 / determinism")
    print(f"project: {project}")
    print("=" * 72)

    try:
        scenario_root = _load_integer_json(project / SCENARIO_REL)
        scenarios = _validate_scenarios(scenario_root)
        goldens = _load_integer_json(project / GOLDEN_REL)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"[FAIL] FIXTURE-CONTRACT {exc}", file=sys.stderr)
        return 1
    print("[PASS] FIXTURE-CONTRACT integer-only scenario schema")

    failures = _check_core_boundary(project)
    if failures:
        for failure in failures:
            print(f"[FAIL] CORE-BOUNDARY {failure}")
        return 1
    print("[PASS] CORE-BOUNDARY project-owned engine-independent hash")

    if args.update_goldens:
        if os.environ.get("CI"):
            print("[FAIL] golden updates are forbidden in CI", file=sys.stderr)
            return 2
        if os.environ.get("P0_ALLOW_QUICK") == "1":
            print("[FAIL] golden updates require the exhaustive determinism gate", file=sys.stderr)
            return 2
        approval_ref = args.approval_ref.strip()
        if not approval_ref:
            print("[FAIL] --approval-ref is required for golden updates", file=sys.stderr)
            return 2
        if not goldens.get("scenarios") and approval_ref != "P0-4":
            print("[FAIL] initial golden approval reference must be P0-4", file=sys.stderr)
            return 2
    elif args.approval_ref:
        print("[FAIL] --approval-ref is valid only with --update-goldens", file=sys.stderr)
        return 2

    quick_profile_error = _ci_quick_profile_error(dict(os.environ))
    if quick_profile_error is not None:
        print(f"[FAIL] {quick_profile_error}", file=sys.stderr)
        return 2

    if os.environ.get(SKIP_GODOT_ENV) == "1":
        print("[SKIP] GODOT-P0-4 explicitly skipped by verify --skip-godot")
        print("P0_DETERMINISM_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0

    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    try:
        imported = godot_test_support.run_godot(
            godot,
            project,
            "--import",
            log_name="godot-p0-determinism-import.log",
        )
        result = godot_test_support.run_godot(
            godot,
            project,
            "--script",
            TEST_SCRIPT,
            log_name="godot-p0-determinism-test.log",
            timeout=3600,
        )
    except subprocess.TimeoutExpired:
        print("[FAIL] GODOT-P0-4 timeout", file=sys.stderr)
        return 2
    if imported.returncode != 0:
        print("[FAIL] GODOT-IMPORT")
        print((imported.stdout + imported.stderr).strip()[-8000:])
        return 2
    print("[PASS] GODOT-IMPORT")

    output = result.stdout + result.stderr
    profile_lines = [
        line for line in output.splitlines() if line.startswith("[INFO] DET-PROFILE")
    ]
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in profile_lines + checks:
        print(f"  {line}")
    if result.returncode != 0 or "P0_DETERMINISM_RESULT: PASS" not in output:
        print("P0_DETERMINISM_RUNNER_RESULT: FAIL (Godot contract tests)")
        print(output.strip()[-12000:], file=sys.stderr)
        return 1

    try:
        records = _parse_snapshots(output)
    except ValueError as exc:
        print(f"[FAIL] PYTHON-SHA256 {exc}", file=sys.stderr)
        return 1
    for scenario in scenarios:
        scenario_id = str(scenario["scenario_id"])
        expected_count = int(scenario["ticks"]) + 1
        if len(records.get(scenario_id, [])) != expected_count:
            print(
                f"[FAIL] {scenario_id}: expected {expected_count} emitted snapshots, "
                f"got {len(records.get(scenario_id, []))}",
                file=sys.stderr,
            )
            return 1
        expected_seed = int(str(scenario["seed"]), 16).to_bytes(8, "little")
        if any(encoded[19:27] != expected_seed for _, encoded in records[scenario_id]):
            print(f"[FAIL] {scenario_id}: root seed endian/width mismatch", file=sys.stderr)
            return 1
    print("[PASS] PYTHON-SHA256 every emitted snapshot matches hashlib")

    if args.update_goldens:
        updated = _golden_payload(scenarios, records, args.approval_ref.strip())
        _print_update_summary(goldens, updated)
        (project / GOLDEN_REL).write_text(
            json.dumps(updated, ensure_ascii=True, indent=2) + "\n",
            encoding="utf-8",
        )
        print("P0_DETERMINISM_RUNNER_RESULT: PASS (goldens updated)")
        return 0

    golden_failures = _compare_goldens(project, scenarios, records, goldens)
    if golden_failures:
        for failure in golden_failures:
            print(f"[FAIL] GOLDEN {failure}")
        print("P0_DETERMINISM_RUNNER_RESULT: FAIL")
        return 1
    print("[PASS] GOLDEN all six tick-by-tick sequences match")
    print(f"P0_DETERMINISM_RUNNER_RESULT: PASS ({len(checks)} grouped Godot checks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
