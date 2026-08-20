---
name: "source-command-lore"
description: "lore — Flickstone 세계관 작업의 init, query, check 단계를 올바른 Codex 저장소 스킬로 연결한다."
---

# source-command-lore

Flickstone 세계관 정본을 만들거나 조회·검사하는 요청을 단계별 스킬로 라우팅할 때 사용한다.

## 단계 라우팅

- `init`: `source-command-lore-init`
- `query`: `source-command-lore-query`
- `check`: `source-command-lore-check`

세부 계약은 다음 저장소 스킬을 따른다.

- `.agents/skills/source-command-lore-init/SKILL.md`
- `.agents/skills/source-command-lore-query/SKILL.md`
- `.agents/skills/source-command-lore-check/SKILL.md`

단계가 없거나 불명확하면 `init`, `query`, `check` 중 무엇을 원하는지 묻는다. 정본 추가·수정 요청은 저장소 명령 카탈로그에 구현된 승인 흐름이 생기기 전까지 임의 적용하지 않는다.

## 공통 계약

- `pipeline/commands/lore.md`, `docs/command-catalog.md`, `AGENTS.md`를 우선한다.
- `lore/canon/`만 사실 정본으로 취급한다.
- 정본에 없는 내용을 추측해 사실처럼 쓰지 않는다.
- 정본 쓰기는 사람의 명시적 승인 뒤에만 수행한다.
