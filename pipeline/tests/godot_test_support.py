#!/usr/bin/env python3
"""Test-facing compatibility wrapper for the shared Godot process boundary."""
from __future__ import annotations

import sys
import subprocess
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
import godot_process  # noqa: E402


DEFAULT_TIMEOUT_SECONDS = godot_process.DEFAULT_TIMEOUT_SECONDS


def resolve_executable(candidate: str) -> str | None:
    return godot_process.resolve_executable(candidate)


def run_godot(
    executable: str,
    project: Path,
    *arguments: str,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
    log_name: str = "godot-test.log",
) -> subprocess.CompletedProcess[str]:
    return godot_process.run_headless(
        executable,
        project,
        *arguments,
        timeout=timeout,
        log_name=log_name,
    )


def run_version(executable: str) -> subprocess.CompletedProcess[str]:
    return godot_process.run_version(executable)
