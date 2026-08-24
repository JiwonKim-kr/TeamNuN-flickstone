#!/usr/bin/env python3
"""Validate Web preset/Pages contracts and export when templates are available."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pages.yml").read_text(encoding="utf-8")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    preview_server = (ROOT / "pipeline/scripts/serve_web.py").read_text(encoding="utf-8")
    legacy_workflow = ROOT / ".github/workflows/deploy-web.yml"
    required_preset = ('name="Web"', 'platform="Web"', 'variant/thread_support=false', 'export_path="build/web/index.html"')
    required_workflow = (
        "actions/configure-pages@v5",
        "actions/upload-pages-artifact@v3",
        "actions/deploy-pages@v4",
        "pages: write",
        "id-token: write",
    )
    if not all(token in preset for token in required_preset):
        print("[FAIL] WEB preset contract")
        return 1
    if (
        not all(token in workflow for token in required_workflow)
        or "pull_request:" in workflow
        or "enablement: true" in workflow
        or legacy_workflow.exists()
    ):
        print("[FAIL] Pages workflow permission/trigger contract")
        return 1
    if 'renderer/rendering_method="gl_compatibility"' not in project:
        print("[FAIL] Web compatibility renderer contract")
        return 1
    if not all(mime in preview_server for mime in ('".js": "application/javascript"', '".wasm": "application/wasm"')):
        print("[FAIL] Web preview server MIME contract")
        return 1
    print("[PASS] WEB static preset, renderer, and Pages workflow contracts")
    templates = ROOT / "pipeline/artifacts/godot-4.6.3/templates/4.6.3.stable/web_nothreads_release.zip"
    godot = os.environ.get("GODOT_BIN", "godot")
    if not templates.is_file():
        print(f"[SKIP] WEB export template unavailable: {templates}")
        return 0
    command = [sys.executable, str(ROOT / "pipeline/scripts/web_export.py"), "--project", str(ROOT), "--godot", godot]
    result = subprocess.run(command, cwd=ROOT, text=True, encoding="utf-8", errors="replace")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
