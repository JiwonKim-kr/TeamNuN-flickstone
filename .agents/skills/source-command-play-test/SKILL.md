---
name: "source-command-play-test"
description: "play test — Flickstone Godot 프로젝트의 import·headless·게임별 테스트를 안전한 공용 러너로 실행하고 결과를 보고한다."
---

# source-command-play-test

플레이 구현을 읽기 전용으로 검증하거나 재현할 때 사용한다.

## 절차

1. `AGENTS.md`, `pipeline/commands/play.md`, `docs/command-catalog.md`를 읽는다.
2. 대상 프로젝트와 테스트 범위를 확인한다. 요청이 없으면 저장소 기본 프로젝트와 관련 narrow runner를 사용한다.
3. 저장소의 공용 Godot 프로세스 경계를 통해 import와 headless 테스트를 실행한다. raw Godot subprocess를 새로 만들지 않는다.
4. 게임별 `pipeline/tests/run_*.py`를 먼저 실행하고 필요하면 `pipeline/scripts/verify.py --full`로 확장한다.
5. 요청된 경우에만 스크린샷 검증을 수행한다.
6. import, 스크립트 파싱, narrow 테스트, 통합 게이트별 결과와 로그 위치를 요약한다.

## 제한

- 소스, manifest, canon, 실제 데이터를 수정하지 않는다.
- 테스트 실패를 숨기기 위해 fixture나 기대값을 갱신하지 않는다.
- Windows 네이티브 오류 창을 막기 위한 저장소의 격리 로그·APPDATA 계약을 우회하지 않는다.
- 비밀값을 출력하지 않는다.
