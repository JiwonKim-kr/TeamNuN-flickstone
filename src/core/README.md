# src/core/ — 게임 핵심 로직

사람이 승인한 spec 없이 수정 금지 영역.
변경 커밋에는 승인된 spec 문서 경로를 명시한다 (docs/conventions.md 참조).

- `sim/`: 엔진 독립 고정소수점 물리, PRNG, 이벤트, P0 스냅샷.
- `battle/`: `sim/` 공개 API만 사용하는 CTB와 전투 상태·전투 스냅샷.
- 의존 방향은 `battle -> sim` 단방향이며 두 계층 모두 Node·SceneTree·입력·렌더 API를 사용하지 않는다.
- 발사 입력은 불변 `LaunchCommand`로 양자화하며, 권위 발사와 궤적 예측은 같은 속도 계산기를 사용한다.
- 궤적은 `BattleState` 깊은 복제에서만 진행하는 파생값이며 원본 전투 상태나 RNG를 소비하지 않는다.
