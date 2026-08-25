#!/usr/bin/env python3
"""Validate Web preset/Pages contracts and export when templates are available."""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIEWPORT_WIDTH = 640.0
VIEWPORT_HEIGHT = 1024.0


def _node_block(scene: str, node_name: str) -> str:
    match = re.search(
        rf'^\[node name="{re.escape(node_name)}"[^\n]*\]\n(?P<body>.*?)(?=^\[node |\Z)',
        scene,
        flags=re.MULTILINE | re.DOTALL,
    )
    return match.group("body") if match else ""


def _scalar(block: str, property_name: str) -> float | None:
    match = re.search(rf'^{re.escape(property_name)} = (-?\d+(?:\.\d+)?)$', block, re.MULTILINE)
    return float(match.group(1)) if match else None


def _vector(block: str, property_name: str) -> tuple[float, float] | None:
    match = re.search(
        rf'^{re.escape(property_name)} = Vector2\((-?\d+(?:\.\d+)?), (-?\d+(?:\.\d+)?)\)$',
        block,
        re.MULTILINE,
    )
    return (float(match.group(1)), float(match.group(2))) if match else None


def _validate_portrait_layout(scene: str) -> list[str]:
    failures: list[str] = []
    backdrop = _node_block(scene, "Backdrop")
    battlefield = _node_block(scene, "Battlefield")
    hud = _node_block(scene, "Hud")
    backdrop_size = (_scalar(backdrop, "offset_right"), _scalar(backdrop, "offset_bottom"))
    battlefield_position = _vector(battlefield, "position")
    battlefield_scale = _vector(battlefield, "scale")
    hud_rect = (
        _scalar(hud, "offset_left"),
        _scalar(hud, "offset_top"),
        _scalar(hud, "offset_right"),
        _scalar(hud, "offset_bottom"),
    )
    if backdrop_size != (VIEWPORT_WIDTH, VIEWPORT_HEIGHT):
        failures.append(f"Backdrop must cover 640x1024 viewport: {backdrop_size}")
    if battlefield_position is None or battlefield_scale is None:
        failures.append("Battlefield position/scale is missing")
    else:
        left, top = battlefield_position
        right = left + VIEWPORT_WIDTH * battlefield_scale[0]
        bottom = top + VIEWPORT_HEIGHT * battlefield_scale[1]
        if min(left, top) < 0.0 or right > VIEWPORT_WIDTH or bottom > VIEWPORT_HEIGHT:
            failures.append(f"Battlefield exceeds portrait viewport: {(left, top, right, bottom)}")
    if any(value is None for value in hud_rect):
        failures.append("HUD rectangle is incomplete")
    else:
        left, top, right, bottom = hud_rect
        assert left is not None and top is not None and right is not None and bottom is not None
        if left < 0.0 or top < 0.0 or right > VIEWPORT_WIDTH or bottom > VIEWPORT_HEIGHT:
            failures.append(f"HUD exceeds portrait viewport: {hud_rect}")
        if battlefield_position is not None and bottom > battlefield_position[1]:
            failures.append(f"HUD overlaps Battlefield: hud_bottom={bottom}, battlefield_top={battlefield_position[1]}")
    return failures


def main() -> int:
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    workflow = (ROOT / ".github/workflows/pages.yml").read_text(encoding="utf-8")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/p2_content_graybox.tscn").read_text(encoding="utf-8")
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
    required_viewport = (
        "window/size/viewport_width=640",
        "window/size/viewport_height=1024",
        'window/stretch/mode="canvas_items"',
    )
    if not all(token in project for token in required_viewport):
        print("[FAIL] WEB portrait viewport contract")
        return 1
    layout_failures = _validate_portrait_layout(scene)
    if layout_failures:
        for failure in layout_failures:
            print(f"[FAIL] WEB portrait layout: {failure}")
        return 1
    if not all(mime in preview_server for mime in ('".js": "application/javascript"', '".wasm": "application/wasm"')):
        print("[FAIL] Web preview server MIME contract")
        return 1
    print("[PASS] WEB preset, portrait layout, renderer, and Pages workflow contracts")
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
