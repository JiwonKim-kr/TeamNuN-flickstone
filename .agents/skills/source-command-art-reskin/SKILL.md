---
name: "source-command-art-reskin"
description: "art reskin — 검증된 Flickstone 아트로 플레이스홀더를 교체하고 씬·manifest·플레이 테스트를 검증한다."
---

# source-command-art-reskin

승인·검증된 실제 아트를 게임 씬에 연결할 때 사용한다. 전투 감각 승인, art lock, art gen이 모두 완료되어야 한다.

## 절차

1. `AGENTS.md`, `pipeline/commands/art.md`, `docs/command-catalog.md`를 읽는다.
2. 변경 대상 씬, 플레이스홀더, 대체 에셋과 manifest 상태를 확인한다.
3. 가능한 경우 먼저 dry-run으로 변경 계획과 실제 데이터 영향 범위를 보여준다.
4. 저장소의 reskin 스크립트를 사용해 플레이스홀더를 실제 에셋으로 교체한다. 수동 문자열 치환을 피한다.
5. manifest 변경은 `pipeline/scripts/manifest.py`로만 수행한다.
6. Godot import와 `source-command-play-test`를 실행해 로딩·참조·표시를 확인한다.
7. 변경 목록, 검증 결과, 되돌릴 수 있는 범위를 사람 검수로 제시하고 최종 승인을 받는다.

## 안전 규칙

- 실제 데이터나 외부 서비스에 영향을 주는 변경은 dry-run과 사람 승인을 우선한다.
- 생성되지 않았거나 probe에 실패한 에셋을 연결하지 않는다.
- `src/core/`의 시뮬레이션 코드를 수정하지 않는다.
- manifest를 직접 편집하지 않는다.
