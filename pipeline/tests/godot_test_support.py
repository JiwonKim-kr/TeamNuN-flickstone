#!/usr/bin/env python3
"""Shared subprocess support for repository-owned headless Godot test runners."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


DEFAULT_TIMEOUT_SECONDS = 300


def resolve_executable(candidate: str) -> str | None:
    found = shutil.which(candidate)
    if found is not None:
        return found
    path = Path(candidate)
    if path.is_file():
        return str(path.resolve())
    return None


def run_godot(
    executable: str,
    project: Path,
    *arguments: str,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> subprocess.CompletedProcess[str]:
    log_dir = project / "pipeline" / "artifacts"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / "godot-headless.log"
    return subprocess.run(
        [
            executable,
            "--headless",
            "--path",
            str(project),
            "--log-file",
            str(log_path),
            *arguments,
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def run_version(executable: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [executable, "--version"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
