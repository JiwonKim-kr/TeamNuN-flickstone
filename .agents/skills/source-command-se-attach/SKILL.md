---
name: "source-command-se-attach"
description: "se attach — 검증된 Flickstone 효과음을 브리지 계층에서 이벤트에 연결하고 manifest·플레이 테스트를 검증한다."
---

# source-command-se-attach

전투 감각 승인 뒤 생성·검증된 효과음을 게임 이벤트에 연결할 때 사용한다.

## 절차

1. `AGENTS.md`, `pipeline/commands/se.md`, `docs/command-catalog.md`를 읽는다.
2. 대상 효과음, manifest ID, 발생 이벤트, 중복 재생·쿨다운 규칙을 확인한다.
3. 가능한 경우 먼저 dry-run으로 연결 계획과 실제 데이터 영향 범위를 보여준다.
4. 런타임 브리지나 프레젠테이션 계층에서 효과음을 연결한다. `src/core/sim/`은 오디오 API를 알지 못하게 유지한다.
5. manifest 변경은 `pipeline/scripts/manifest.py`로만 수행한다.
6. `source-command-play-test`로 import, 참조, 이벤트 발생, 누락 자원 오류를 확인한다.
7. 변경 목록과 검증 결과를 사람 검수로 제시한다.

## 안전 규칙

- 실제 데이터나 외부 서비스에 영향을 주는 변경은 dry-run과 사람 승인을 우선한다.
- probe에 실패한 파일을 연결하지 않는다.
- 시뮬레이션 결과나 결정론 해시에 오디오 상태를 섞지 않는다.
- P0·P1에서는 실행하지 않는다.
