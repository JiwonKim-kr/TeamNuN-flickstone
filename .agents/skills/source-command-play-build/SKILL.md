---
name: "source-command-play-build"
description: "play build — 승인된 Flickstone 명세 범위에서 유지보수 가능한 코드·플레이스홀더·회귀 테스트를 구현하고 검증한다."
---

# source-command-play-build

승인된 게임 기능 명세를 구현할 때 사용한다.

## 선행 조건

1. `AGENTS.md`, `docs/design/game_design.md`, `pipeline/commands/play.md`, `docs/command-catalog.md`를 읽는다.
2. 대상 `docs/specs/*.md`가 `status: approved`인지 확인한다. 승인되지 않았거나 `⬜ 미정` 동작이 필요한 경우 구현을 중단하고 결정으로 올린다.
3. 현재 worktree의 사용자 변경을 확인하고 보존한다.

## 구현 원칙

- 엔진 독립 시뮬레이션은 `src/core/sim/`에 두고 `Node`를 상속하거나 Godot API를 호출하지 않는다.
- 고정소수점 산술, 프로젝트 소유 PRNG, 고정 시뮬레이션 스텝, 안정 ID, 명시적으로 정렬된 순회를 사용한다.
- 공개 계약과 내부 구현을 분리하고, 한 클래스에 단계를 과도하게 결합하지 않는다.
- 실패는 release에서도 관찰 가능한 명시적 상태·결과 계약으로 처리한다.
- P0·P1 시각 자원은 `pipeline/scripts/placeholder_gen.py`로 만든 읽기 쉬운 플레이스홀더만 사용한다.
- manifest 쓰기는 항상 `pipeline/scripts/manifest.py`를 통한다.
- 관련 없는 리팩터링과 승인 범위 밖 기능은 포함하지 않는다.

## 절차

1. 명세의 대상 파일과 테스트 경계를 정하고 최소 구현 순서를 세운다.
2. 유지보수성과 새 기능 확장을 고려해 작은 책임 단위로 구현한다.
3. 필요한 플레이스홀더를 생성하고 manifest에 등록한다.
4. 게임별 narrow runner를 `pipeline/tests/run_*.py`로 추가하거나 갱신한다.
5. narrow 테스트를 먼저 실행한다.
6. Godot이 있으면 활성화한 상태로 `pipeline/scripts/verify.py --full`을 실행한다. Windows에서는 `PYTHONUTF8=1`을 사용한다.
7. 구현 범위, 설계 선택, 테스트 결과, 남은 승인 결정을 보고한다.

## 커밋

사용자가 커밋을 요청하거나 구현 결과를 승인한 경우에만 저장소 관례에 맞춰 커밋한다. 커밋 본문에는 구현 근거가 된 명세 경로를 남긴다.
