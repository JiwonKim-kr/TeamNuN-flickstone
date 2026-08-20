---
name: "source-command-play-spec"
description: "play spec — Flickstone 게임 기능의 구현 전 명세 초안을 만들고 미정 결정과 사람 승인 지점을 분리한다."
---

# source-command-play-spec

새 게임 기능이나 P단계 구현 명세를 작성·수정할 때 사용한다. 이 단계에서는 `src/core/` 구현을 시작하지 않는다.

## 절차

1. `AGENTS.md`, `docs/design/game_design.md`, `pipeline/commands/play.md`, `docs/command-catalog.md`를 읽는다.
2. 관련 `docs/specs/*.md`와 기존 구현·테스트를 확인해 중복과 충돌을 찾는다.
3. 세계관 규칙이 관련되면 `source-command-lore-query`로 canon 근거를 확인한다.
4. 목표, 범위, 비범위, 용어, 데이터·상태 모델, 공개 API, 결정론 규칙, 오류 계약, 파일 배치, 테스트·수용 기준을 명세한다.
5. 필요한 에셋은 P0·P1 제한에 따라 manifest 등록 플레이스홀더로 명시한다.
6. `docs/design/game_design.md`의 `⬜ 미정` 값과 새 선택지는 승인 결정 목록으로 분리하고 임의 확정하지 않는다.
7. 명세 상태를 초안으로 유지한 채 변경 요약과 결정 질문을 제시한다.
8. 사람이 전체 명세를 명시적으로 승인한 뒤에만 `status: approved`로 전환한다.

## 제한

- 승인 전에는 핵심 구현 코드를 쓰지 않는다.
- 설계 정본과 충돌하는 규칙을 조용히 덮어쓰지 않는다.
- 테스트를 구현 세부가 아니라 관찰 가능한 계약으로 작성한다.
- 승인된 범위를 넘어 후속 단계 기능을 끌어오지 않는다.
