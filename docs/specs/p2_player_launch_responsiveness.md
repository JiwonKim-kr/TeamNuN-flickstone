# P2 · 플레이어 발사 응답성

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 작성 | 2026-08-24 |
| 승인 | 2026-08-24 · 사용자: LR-01~05 권장안대로 진행 |
| 선행 계약 | P1 조준·궤적 예측, P2 콘텐츠 회색상자 |

## 문제

플레이어가 드래그를 놓은 직후 실제 RESOLVE와 이미 실행 중인 궤적 예측 worker가 겹칠 수 있다. `_clear_aim()`은 queue와 cache만 무효화하며 실행 중인 `Thread`를 중단하거나 기다리지 않는다. 적은 AI 계산을 발사 전에 동기적으로 끝내므로 같은 중첩 경로를 사용하지 않는다.

## 목표

- 마우스를 놓은 프레임에 권위 발사를 즉시 commit한다.
- 발사 후 실제 RESOLVE의 프레임 시간을 궤적 예측보다 우선한다.
- 예측 결과 폐기, 원본 상태 불변, 발사 command와 권위 결과는 유지한다.

## 범위

- P1/P2 회색상자의 prediction worker 우선순위와 수명 계측
- 발사 직후 stale prediction worker가 존재해도 RESOLVE가 먼저 실행되는 계약
- queue invalidation과 scene exit join 회귀

## 비범위

- 발사 속도·질량 공식, AI 파워, 물리 tick, `vmax` 컷오프 변경
- 궤적 길이 240틱·표본 수·표시 모양 변경
- 강제 thread 종료 또는 권위 시뮬레이션의 비결정론화

## 승인 결정안

| ID | 결정 | 상태 |
|---|---|---|
| LR-01 | prediction worker는 `Thread.PRIORITY_LOW`로 시작해 메인 RESOLVE를 우선한다 | ✅ 승인 |
| LR-02 | 발사 요청은 worker 종료를 기다리지 않고 현재 프레임에 commit한다 | ✅ 승인 |
| LR-03 | 발사 시 queue session을 무효화해 늦게 끝난 결과를 UI에 반영하지 않는다 | 기존 계약 유지 |
| LR-04 | worker 강제 종료는 사용하지 않고 scene exit에서만 `wait_to_finish()`로 회수한다 | ✅ 승인 |
| LR-05 | HUD 디버그 상시 표시는 넣지 않고 자동 테스트에서 worker 중첩 계약을 검증한다 | ✅ 승인 |

## 대안과 영향

- 발사 전에 `wait_to_finish()`: 물리 중첩은 없지만 마우스를 놓은 뒤 최대 예측 240틱 계산만큼 입력 정지가 생겨 비권장.
- 예측 tick 축소: 응답성은 좋아지지만 궤적 정보량과 기존 P1 계약을 바꾸므로 비권장.
- 취소 토큰 추가: 가장 강한 제어지만 core predictor API와 동기화 복잡도가 커 현재 수직 슬라이스에는 과도함.

## 수용 기준

1. P1/P2 worker가 낮은 우선순위로 시작한다.
2. 실행 중 worker가 있어도 발사 요청 handler는 join하지 않고 권위 발사를 commit한다.
3. stale 결과는 session/generation 불일치로 화면에 나타나지 않는다.
4. 원본 `BattleState`, 발사 command, terminal golden은 바뀌지 않는다.
5. P1 launch narrow, P2 content quick, import·smoke·manifest가 통과한다.

## 대상 파일

- `src/ui/battle/p1_graybox_battle.gd`
- `src/ui/battle/p2_content_graybox.gd`
- `src/ui/battle/trajectory_prediction_queue.gd`
- `pipeline/tests/p1_launch_aim_prediction_test.gd`
- `pipeline/tests/p2_content_graybox_test.gd`
- `HANDOFF.md`

신규 에셋과 manifest 변경은 없다.
