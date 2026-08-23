#!/usr/bin/env python3
"""P2-1 strict JSON, typed catalog, atomic DataDB, and fingerprint runner."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

import godot_test_support

ROOT = Path(__file__).resolve().parents[2]
TEST_SCRIPT = "res://pipeline/tests/p2_content_catalog_test.gd"
SKIP_GODOT_ENV = "ARTIFICER_SKIP_GODOT_TESTS"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args(argv)
    project = args.project.resolve()

    reference = subprocess.run(
        [sys.executable, str(project / "pipeline/tests/p2_content_catalog_reference.py")],
        cwd=project,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=300,
    )
    print(reference.stdout.strip())
    if reference.returncode != 0:
        print(reference.stderr.strip(), file=sys.stderr)
        print("P2_CONTENT_CATALOG_RUNNER_RESULT: FAIL")
        return 1

    for path in sorted((project / "src/core/data").glob("*.gd")):
        text = path.read_text(encoding="utf-8")
        for forbidden in ("extends Node", "FileAccess", "DirAccess", "JSON.parse"):
            if forbidden in text:
                print(f"[FAIL] {path.name}: forbidden core-data dependency {forbidden}")
                return 1
    print("[PASS] P2-1-ARCH data definitions remain Node/FileAccess/JSON independent")

    project_text = (project / "project.godot").read_text(encoding="utf-8")
    autoload_entry = 'DataDB="*res://src/core/autoload/data_db.gd"'
    if "[autoload]" not in project_text or autoload_entry not in project_text:
        print("[FAIL] P2-1-C09 DataDB autoload registration is missing")
        return 1
    print("[PASS] P2-1-C09 DataDB autoload registration")

    if os.environ.get(SKIP_GODOT_ENV) == "1":
        print("[SKIP] GODOT-P2-1 explicitly skipped by verify --skip-godot")
        print("P2_CONTENT_CATALOG_RUNNER_RESULT: PASS (Godot skipped explicitly)")
        return 0

    godot = godot_test_support.resolve_executable(args.godot)
    if godot is None:
        print(f"[FAIL] GODOT-BIN executable not found: {args.godot!r}", file=sys.stderr)
        return 2
    version = godot_test_support.run_version(godot)
    version_text = (version.stdout or version.stderr).strip()
    if version.returncode != 0 or not version_text.startswith("4.6"):
        print(f"[FAIL] GODOT-VERSION expected 4.6.x, actual={version_text!r}")
        return 2
    print(f"[PASS] GODOT-VERSION {version_text}")

    imported = godot_test_support.run_godot(
        godot, project, "--import", log_name="godot-p2-content-catalog-import.log"
    )
    if imported.returncode != 0:
        print((imported.stdout + imported.stderr).strip()[-12000:], file=sys.stderr)
        return 2
    print("[PASS] GODOT-IMPORT")

    result = godot_test_support.run_godot(
        godot,
        project,
        "--script",
        TEST_SCRIPT,
        log_name="godot-p2-content-catalog-test.log",
        timeout=300,
    )
    output = result.stdout + result.stderr
    checks = [line for line in output.splitlines() if line.startswith(("[PASS]", "[FAIL]"))]
    for line in checks:
        print(f"  {line}")
    failed = [line for line in checks if line.startswith("[FAIL]")]
    if result.returncode == 0 and "P2_CONTENT_CATALOG_RESULT: PASS" in output and not failed:
        print(f"P2_CONTENT_CATALOG_RUNNER_RESULT: PASS ({len(checks)} grouped checks)")
        return 0
    print(output.strip()[-12000:], file=sys.stderr)
    print("P2_CONTENT_CATALOG_RUNNER_RESULT: FAIL")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
