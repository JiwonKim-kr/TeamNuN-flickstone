#!/usr/bin/env python3
"""Create and validate the approved Godot 4.6.3 single-thread Web export."""
from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

import godot_process

ROOT = Path(__file__).resolve().parents[2]
VERSION = "4.6.3"
TEMPLATE_VERSION = "4.6.3.stable"
WEB_TEMPLATES = ("web_nothreads_debug.zip", "web_nothreads_release.zip")


def _default_templates(project: Path) -> Path:
    return project / "pipeline/artifacts/godot-4.6.3/templates" / TEMPLATE_VERSION


def _validate_output(output: Path) -> list[str]:
    failures: list[str] = []
    if not output.is_file() or output.stat().st_size == 0:
        return [f"missing or empty HTML: {output}"]
    stem = output.stem
    required = [output.with_name(f"{stem}.{suffix}") for suffix in ("js", "wasm", "pck")]
    html = output.read_text(encoding="utf-8", errors="replace")
    for path in required:
        if not path.is_file() or path.stat().st_size == 0:
            failures.append(f"missing or empty export file: {path}")
        elif path.name not in html and path.suffix in (".js", ".pck"):
            failures.append(f"HTML does not reference {path.name}")
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--templates", type=Path)
    parser.add_argument("--output", type=Path, default=Path("build/web/index.html"))
    args = parser.parse_args(argv)
    project = args.project.resolve()
    executable = godot_process.resolve_executable(args.godot)
    if executable is None:
        print(f"[FAIL] Godot executable not found: {args.godot}", file=sys.stderr)
        return 2
    version = godot_process.run_version(executable)
    if version.returncode != 0 or not version.stdout.strip().startswith(VERSION):
        print(f"[FAIL] Godot {VERSION} required: {version.stdout.strip()}", file=sys.stderr)
        return 2
    templates = (args.templates or _default_templates(project)).resolve()
    for template_name in WEB_TEMPLATES:
        if not (templates / template_name).is_file():
            print(f"[FAIL] Web export template missing: {templates / template_name}", file=sys.stderr)
            return 2
    output = args.output if args.output.is_absolute() else project / args.output
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with godot_process.isolated_project_environment(project) as child_env:
        child_template_dir = Path(child_env["APPDATA"]) / "Godot/export_templates" / TEMPLATE_VERSION if os.name == "nt" else Path.home() / ".local/share/godot/export_templates" / TEMPLATE_VERSION
        child_template_dir.parent.mkdir(parents=True, exist_ok=True)
        child_template_dir.mkdir(parents=True, exist_ok=True)
        for template_name in WEB_TEMPLATES:
            shutil.copy2(templates / template_name, child_template_dir / template_name)
        command = godot_process.build_headless_command(
            executable, project, "--export-release", "Web", str(output), log_name="godot-web-export.log"
        )
        result = godot_process.run_captured(command, timeout=600, cwd=project, env=child_env, process_group=True)
    if result.returncode != 0:
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        print(f"[FAIL] Godot Web export exit={result.returncode}", file=sys.stderr)
        return 1
    failures = _validate_output(output)
    if failures:
        for failure in failures:
            print(f"[FAIL] {failure}", file=sys.stderr)
        return 1
    print(f"[PASS] WEB_EXPORT Godot={VERSION} output={output.relative_to(project)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
