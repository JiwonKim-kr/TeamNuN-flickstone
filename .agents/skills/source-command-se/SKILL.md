---
name: "source-command-se"
description: "se — Flickstone 효과음 파이프라인의 gen, attach 단계를 올바른 Codex 저장소 스킬로 연결한다."
---

# source-command-se

Flickstone 효과음을 생성하거나 게임에 연결하는 요청을 단계별 스킬로 라우팅할 때 사용한다.

## 단계 라우팅

- `gen`: `source-command-se-gen`
- `attach`: `source-command-se-attach`

세부 계약은 다음 저장소 스킬을 따른다.

- `.agents/skills/source-command-se-gen/SKILL.md`
- `.agents/skills/source-command-se-attach/SKILL.md`

단계가 없거나 불명확하면 `gen`, `attach` 중 무엇을 원하는지 묻는다. BGM은 현재 명령 계약만 있고 실행 스킬이 없으므로 구현된 것처럼 처리하지 않는다.

## 현재 단계 제한

P0·P1에는 효과음 생성·연결을 시작하지 않는다. 전투 감각이 승인된 뒤에만 이 파이프라인을 연다.

## 공통 계약

- `pipeline/commands/se.md`, `docs/command-catalog.md`, `AGENTS.md`를 우선한다.
- 생성물은 자동 검증 후 사람 검수로 넘긴다.
- manifest 변경은 반드시 `pipeline/scripts/manifest.py`를 통한다.
- 비밀값은 출력하지 않는다.
