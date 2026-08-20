---
name: "source-command-art"
description: "art — Flickstone 아트 파이프라인의 concept, lock, gen, reskin 단계를 올바른 Codex 저장소 스킬로 연결한다."
---

# source-command-art

Flickstone의 아트 작업을 단계별 스킬로 라우팅할 때 사용한다.

## 단계 라우팅

- `concept`: `source-command-art-concept`
- `lock`: `source-command-art-lock`
- `gen`: `source-command-art-gen`
- `reskin`: `source-command-art-reskin`

세부 계약은 각각 다음 저장소 스킬을 따른다.

- `.agents/skills/source-command-art-concept/SKILL.md`
- `.agents/skills/source-command-art-lock/SKILL.md`
- `.agents/skills/source-command-art-gen/SKILL.md`
- `.agents/skills/source-command-art-reskin/SKILL.md`

단계가 없거나 불명확하면 `concept`, `lock`, `gen`, `reskin` 중 무엇을 원하는지 묻는다. 임의로 다음 단계까지 연속 실행하지 않는다.

## 현재 단계 제한

P0·P1에는 manifest 등록 플레이스홀더만 사용한다. 전투 감각이 승인되기 전에는 `lock`, `gen`, `reskin`을 실행하지 않고 현재 제한을 알린다.

## 공통 계약

- `pipeline/commands/art.md`, `docs/command-catalog.md`, `AGENTS.md`를 우선한다.
- 생성물은 자동 검증 후 사람 검수로 넘긴다.
- manifest 변경은 반드시 `pipeline/scripts/manifest.py`를 통한다.
- 비밀값은 출력하지 않는다.
- 사람 승인 전에는 승인 지점의 변경을 적용하지 않는다.
