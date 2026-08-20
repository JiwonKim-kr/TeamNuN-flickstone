---
name: "source-command-play"
description: "play — Flickstone 게임 기능 작업의 spec, build, test 단계를 올바른 Codex 저장소 스킬로 연결한다."
---

# source-command-play

Flickstone 플레이 기능을 명세·구현·검증하는 요청을 단계별 스킬로 라우팅할 때 사용한다.

## 단계 라우팅

- `spec`: `source-command-play-spec`
- `build`: `source-command-play-build`
- `test`: `source-command-play-test`

세부 계약은 다음 저장소 스킬을 따른다.

- `.agents/skills/source-command-play-spec/SKILL.md`
- `.agents/skills/source-command-play-build/SKILL.md`
- `.agents/skills/source-command-play-test/SKILL.md`

단계가 없거나 불명확하면 `spec`, `build`, `test` 중 무엇을 원하는지 묻는다. 승인되지 않은 명세를 곧바로 구현하지 않는다.

## 공통 계약

- `docs/design/game_design.md`, 관련 `docs/specs/*.md`, `pipeline/commands/play.md`, `AGENTS.md`를 우선한다.
- 엔진 독립 시뮬레이션은 `src/core/sim/`에 두고 Node·Godot API와 분리한다.
- P0·P1에는 manifest 등록 플레이스홀더만 사용한다.
- 고정소수점, 프로젝트 PRNG, 고정 스텝, 안정 ID, 명시적 정렬을 유지한다.
