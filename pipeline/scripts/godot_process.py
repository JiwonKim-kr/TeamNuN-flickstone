#!/usr/bin/env python3
"""Safe subprocess boundary for repository-owned Godot invocations.

Godot 4.6.x can crash on Windows when its default ``user://logs`` destination
is not writable. Automated runs therefore always provide an absolute log file
inside the project artifact directory. Windows native-error dialogs are also
suppressed for the child so a crash becomes a normal non-zero result instead
of an orphaned modal window.

Only stdlib is used so this module is available to every pipeline command and
temporary repository clone.
"""
from __future__ import annotations

import contextlib
import ctypes
import os
import re
import shutil
import signal
import subprocess
import tempfile
import threading
from collections.abc import Iterator, Mapping, Sequence
from pathlib import Path


DEFAULT_TIMEOUT_SECONDS = 300
WINDOWS_ACCESS_VIOLATION = 0xC000_0005

_SEM_FAILCRITICALERRORS = 0x0001
_SEM_NOGPFAULTERRORBOX = 0x0002
_SEM_NOOPENFILEERRORBOX = 0x8000
_ERROR_MODE_LOCK = threading.Lock()
_WINDOWS_RESERVED_NAMES = {
    "CON", "PRN", "AUX", "NUL",
    *(f"COM{i}" for i in range(1, 10)),
    *(f"LPT{i}" for i in range(1, 10)),
}


def _prefer_direct_windows_editor(path: Path, platform: str | None = None) -> Path:
    """Avoid the ``*_console.exe`` launcher when its direct sibling exists.

    The official console executable is a small launcher around the real editor
    executable. Running the direct child keeps timeout/interrupt cleanup under
    Python's control; redirected stdout/stderr still works for headless runs.
    ``platform`` exists to make this rule contract-testable on every OS.
    """
    platform = os.name if platform is None else platform
    if platform != "nt" or not path.name.lower().endswith("_console.exe"):
        return path
    direct_name = path.name[: -len("_console.exe")] + ".exe"
    direct = path.with_name(direct_name)
    return direct if direct.is_file() else path


def resolve_executable(candidate: str) -> str | None:
    """Resolve a Godot command/path and normalize a Windows console launcher."""
    found = shutil.which(candidate)
    path = Path(found) if found is not None else Path(candidate)
    if not path.is_file():
        return None
    return str(_prefer_direct_windows_editor(path.resolve()))


def artifact_log_path(project: Path, log_name: str = "godot-headless.log") -> Path:
    """Return a writable, ignored, project-local absolute engine log path."""
    name = Path(log_name)
    if (
        not log_name
        or name.name != log_name
        or name.suffix.lower() != ".log"
        or re.fullmatch(
            r"[A-Za-z0-9][A-Za-z0-9._-]*\.log", log_name, re.IGNORECASE
        ) is None
        or log_name.split(".", 1)[0].upper() in _WINDOWS_RESERVED_NAMES
    ):
        raise ValueError(f"log_name must be a file name, got {log_name!r}")
    log_dir = project.resolve() / "pipeline" / "artifacts" / "godot"
    log_dir.mkdir(parents=True, exist_ok=True)
    return (log_dir / log_name).resolve()


def build_headless_command(
    executable: str,
    project: Path,
    *arguments: str,
    log_name: str = "godot-headless.log",
) -> list[str]:
    """Build the canonical headless command used by repository automation."""
    return [
        executable,
        "--headless",
        "--path",
        str(project.resolve()),
        "--log-file",
        str(artifact_log_path(project, log_name)),
        *arguments,
    ]


@contextlib.contextmanager
def suppress_windows_error_dialogs() -> Iterator[None]:
    """Make a newly spawned native child inherit a no-dialog error policy.

    Windows error mode is process-global. Callers must therefore keep this
    context around ``Popen`` only, never around the child's whole lifetime.
    The lock prevents concurrent spawns from restoring each other's state.
    """
    if os.name != "nt":
        yield
        return

    with _ERROR_MODE_LOCK:
        try:
            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel32.GetErrorMode.argtypes = []
            kernel32.GetErrorMode.restype = ctypes.c_uint
            kernel32.SetErrorMode.argtypes = [ctypes.c_uint]
            kernel32.SetErrorMode.restype = ctypes.c_uint
        except (AttributeError, OSError):
            yield
            return

        requested = (
            _SEM_FAILCRITICALERRORS
            | _SEM_NOGPFAULTERRORBOX
            | _SEM_NOOPENFILEERRORBOX
        )
        previous = int(kernel32.GetErrorMode())
        kernel32.SetErrorMode(previous | requested)
        try:
            yield
        finally:
            kernel32.SetErrorMode(previous)


def _terminate_process_tree(
    process: subprocess.Popen[str], *, process_group: bool
) -> None:
    """Best-effort cleanup for the exact child tree owned by this runner."""
    if process.poll() is not None:
        return
    if os.name == "nt":
        # This also covers the rare console-launcher/shim fallback where the
        # direct child has already started the real Godot process.
        creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        try:
            subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
                check=False,
                creationflags=creationflags,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass
    elif process_group:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except (ProcessLookupError, OSError):
            pass
    try:
        process.kill()
    except (ProcessLookupError, OSError):
        pass


def run_captured(
    command: Sequence[str],
    *,
    timeout: int,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    process_group: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run a child with UTF-8 capture, bounded lifetime, and no crash UI."""
    cmd = list(command)
    with suppress_windows_error_dialogs():
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            start_new_session=process_group and os.name != "nt",
        )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        _terminate_process_tree(process, process_group=process_group)
        stdout, stderr = process.communicate()
        raise subprocess.TimeoutExpired(
            cmd, timeout, output=stdout, stderr=stderr
        ) from None
    except BaseException:
        _terminate_process_tree(process, process_group=process_group)
        process.communicate()
        raise
    return subprocess.CompletedProcess(cmd, process.returncode, stdout, stderr)


@contextlib.contextmanager
def isolated_project_environment(
    project: Path,
    base_environment: Mapping[str, str] | None = None,
    *,
    platform: str | None = None,
) -> Iterator[dict[str, str]]:
    """Yield a child-only writable Windows profile and remove it afterward.

    Godot uses APPDATA and LOCALAPPDATA for ``user://`` and cache paths on
    Windows. Other platforms retain their normal environment because this
    workaround targets the Windows engine fault without changing their user
    data semantics. ``platform`` is injectable for platform-neutral tests.
    """
    child_env = dict(os.environ if base_environment is None else base_environment)
    platform = os.name if platform is None else platform
    if platform != "nt":
        yield child_env
        return

    runtime_parent = (
        project.resolve() / "pipeline" / "artifacts" / "godot" / "runtime"
    )
    runtime_parent.mkdir(parents=True, exist_ok=True)
    runtime_dir = Path(tempfile.mkdtemp(prefix="run-", dir=runtime_parent))
    appdata_dir = runtime_dir / "appdata"
    localappdata_dir = runtime_dir / "localappdata"
    appdata_dir.mkdir()
    localappdata_dir.mkdir()
    child_env["APPDATA"] = str(appdata_dir)
    child_env["LOCALAPPDATA"] = str(localappdata_dir)
    try:
        yield child_env
    finally:
        shutil.rmtree(runtime_dir, ignore_errors=True)


def run_headless(
    candidate: str,
    project: Path,
    *arguments: str,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
    log_name: str = "godot-headless.log",
) -> subprocess.CompletedProcess[str]:
    """Resolve and run Godot headless with the canonical safe boundary."""
    executable = resolve_executable(candidate)
    if executable is None:
        raise FileNotFoundError(candidate)

    command = build_headless_command(
        executable, project, *arguments, log_name=log_name
    )
    with isolated_project_environment(project) as child_env:
        result = run_captured(
            command,
            timeout=timeout,
            cwd=project.resolve(),
            env=child_env,
            process_group=True,
        )
    if result.returncode != 0:
        engine_log = artifact_log_path(project, log_name)
        diagnostic = f"[godot_process] engine log: {engine_log}"
        result.stderr = f"{result.stderr.rstrip()}\n{diagnostic}\n"
    return result


def run_version(
    candidate: str, timeout: int = 30
) -> subprocess.CompletedProcess[str]:
    executable = resolve_executable(candidate)
    if executable is None:
        raise FileNotFoundError(candidate)
    return run_captured([executable, "--version"], timeout=timeout)


def describe_returncode(returncode: int) -> str:
    """Add a stable diagnostic for Windows native access violations."""
    if (returncode & 0xFFFF_FFFF) == WINDOWS_ACCESS_VIOLATION:
        return f"{returncode} (Windows access violation 0xC0000005)"
    return str(returncode)
