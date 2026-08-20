# P1-2 · 발사 / 조준 / 입력 양자화 / 궤적 예측

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-20 |
| approved | 2026-08-20 · 사용자 승인 |
| phase | P1 · 전투 루프 |
| 선행 명세 | `p1_index.md` 승인, `p1_ctb_battle_state.md` 승인·구현·검증 완료 |
| 후속 명세 | `p1_damage_resolution.md` |
| 구현 권한 | 승인 범위 내 구현 가능 |
| 구현 상태 | **implemented · narrow verified · full verification deferred** · 2026-08-20 |

## 목적

Godot의 포인터 입력을 결정론적인 정수 `LaunchCommand`로 양자화하고, 같은 명령으로 권위 발사와 읽기 전용 궤적 예측을 수행한다. 조준 취소·최소 파워 미달·잘못된 입력은 CT, phase, 월드, RNG를 바꾸지 않으며, 리플레이와 P3 AI가 화면 좌표 없이 같은 명령 계약을 재사용할 수 있게 한다.

## 설계 정본 참조

- `docs/design/game_design.md` D-10, D-29~34, D-46~48
- 4.6 발사, 4.8 턴 상태 머신
- 12장 AI의 후보 샷 사본 시뮬레이션 경계
- 13.1 조준·취소·예상 궤적선
- 14.1 결정론·입력 양자화·고정 각도
- 22.5 U-32 물리 수치
- `docs/specs/p1_ctb_battle_state.md` C-06·08·09

## 범위

- 화면/월드 드래그를 엔진 독립 정수 입력으로 넘기는 UI 브리지 경계
- 드래그 방향과 길이를 각도·파워 정수 명령으로 양자화
- 불변 `LaunchCommand` 생성·검증·복제
- 승인된 최대 속도와 무게 보정으로 Q47.16 초기 속도 산출
- `BattleState.commit_launch_velocity()`를 사용하는 권위 발사 커밋
- 깊은 복제한 전투 상태에서 같은 명령을 사용하는 읽기 전용 궤적 예측
- 벽 반사·첫 동적 기물 충돌·정지·소멸의 예측 종료/표시 계약
- 조준 취소와 최소 파워 미달의 상태 불변 계약
- 리플레이·P3 AI가 재사용할 명령 바이트 형식과 확장 경계

## 범위 밖

- 비숍·룩 등 기물별 조준 각도 제한과 각도 스냅 정책
- 비행 중 추가 입력과 입력 시점 tick 기록
- 피해·체력·크리티컬·파괴 귀속
- 능력·상태이상·트리거가 발사 수치를 바꾸는 규칙
- P3 AI 후보 탐색과 평가 함수
- 최종 화면 레이아웃·카메라·튜토리얼·진동
- 실제 아트·효과음
- P1-5 회색상자 전투 씬과 최종 플레이스홀더 배치

## 용어와 좌표 경계

- `pointer_screen`: Godot UI가 관찰한 화면 좌표. 비권위 float가 존재할 수 있다.
- `pointer_world_raw`: UI 브리지가 카메라 변환 뒤 최근접·절반은 0에서 먼 방향으로 Q47.16 정수화한 전투 월드 좌표.
- `drag_vector`: `actor_center - pointer_world`; 당긴 방향의 반대로 발사한다는 설계 정본을 그대로 표현한다.
- `LaunchCommand`: 양자화된 `angle`과 `power_step`만 가진 엔진 독립 불변 명령.
- `authoritative launch`: `LaunchCommand`를 속도로 풀어 실제 `BattleState`에 커밋하는 경로.
- `prediction`: BattleState 깊은 복제본에 같은 명령을 커밋해 관찰 결과만 반환하는 경로.

화면 좌표, 카메라 transform, 렌더 보간값은 권위 상태나 스냅샷에 포함하지 않는다. 리플레이와 네트워크 입력은 `pointer_screen`이나 드래그 픽셀이 아니라 `LaunchCommand` 정규 바이트를 저장한다.

## 확정된 선행 계약

- 내부 각도는 `uint16` 의미의 0~65,535이며 `0=+X`, 화면 기준 시계 방향이다.
- Q47.16, 고정 각도 LUT, 최근접·절반은 0에서 먼 방향 반올림을 사용한다.
- P0·P1 초기 발사 절대상한은 2,048 논리 단위/초다.
- `BattleState`는 AIM에서만 0이 아닌 최종 Q47.16 속도를 받는다.
- 성공한 발사 커밋만 CT 10,000 차감, `last_acted_faction` 갱신, RESOLVE 전이를 한 트랜잭션으로 수행한다.
- 취소·검증 실패·0속도·상한 초과는 AIM과 전체 권위 상태를 유지한다.
- 예측은 BattleState·SimWorld·RNG·pending mutation을 바꾸거나 소비하지 않는다.
- P1-2에는 피해와 능력 효과가 없으므로 예측은 P0 물리와 P1-1 RESOLVE만 진행한다.

## 상태와 데이터 모델

### LaunchCommand

| 필드 | 형식 | 의미 |
|---|---|---|
| `angle` | `uint16` 의미, 저장 `int64` | 양자화된 고정 각도 |
| `power_step` | `uint16` 의미, 저장 `int64` | 0~`POWER_STEPS`의 양자화 파워 |

- 생성 뒤 필드를 바꾸지 않는다.
- Dictionary·Variant·Object payload·float·문자열을 사용하지 않는다.
- 정규 바이트는 `schema_version:uint16`, `angle:uint16`, `power_step:uint16`의 little-endian 6바이트다.
- schema v1은 L-01~03 승인 뒤 확정한다. 알 수 없는 version과 trailing bytes는 실패한다.
- P1-2 발사 직후 명령은 이미 월드 속도에 반영되므로 BattleSnapshot에 중복 저장하지 않는다. P1-5 리플레이 입력열이 명령 바이트를 소유한다.

### AimQuantizationInput

엔진 독립 양자화 경계는 아래 정수 값만 받는다.

| 필드 | 형식 | 의미 |
|---|---|---|
| `actor_center` | `FixVec2` | 권위 SimBody 중심의 값 사본 |
| `pointer_world` | `FixVec2` | UI 브리지에서 정수화한 포인터 월드 좌표 |

별도 가변 객체로 영구 저장하지 않고 순수 함수 입력으로만 사용한다. actor 중심은 렌더 보간 위치가 아니라 AIM 안정 경계의 SimBody 위치다.

### TrajectoryPoint

| 필드 | 형식 | 의미 |
|---|---|---|
| `sample_index` | `uint16` | 0부터 증가하는 출력 순서 |
| `simulation_tick_offset` | `uint16` | 발사 커밋 뒤 경과한 시뮬 tick |
| `position` | `FixVec2` | 현재 행동자 중심의 정수 위치 |
| `marker` | append-only `uint16` enum | 일반·벽 반사·기물 충돌·정지·소멸·잘림 |
| `related_body_id` | `uint32` | 기물 충돌 상대, 없으면 0 |

배열은 `sample_index` 순서의 값 사본이며 내부 SimBody·SimEvent 참조를 노출하지 않는다.

### TrajectoryPrediction

- 양자화된 명령 사본
- 정렬된 `TrajectoryPoint` 값 배열
- 실행한 simulation tick 수
- 관찰한 벽 반사 수
- 종료 이유 enum
- `truncated` bool

예측 결과는 파생 캐시이며 스냅샷·상태 해시·RNG에 포함하지 않는다.

## 결정 목록 — 승인 대기

| 순서 | 결정 | 권장안 | 상태 |
|---|---|---|---|
| L-01 | 명령 표현과 정규 바이트 | `angle:uint16` + `power_step:uint16`, schema v1 6바이트 | ✅ 승인 |
| L-02 | 최대 드래그 거리와 파워 단계 | 192 논리 단위, 256단계 | ✅ 승인 |
| L-03 | 최소 파워와 각도 양자화 | 32/256(12.5%), 각도 간격 256(1.40625°) | ✅ 승인 |
| L-04 | 최대 발사 속도 | 기준 최대 1,024, 절대상한 2,048 | ✅ 승인 |
| L-05 | 무게 보정 | 기준무게 64, `sqrt(64 / mass)` | ✅ 승인 |
| L-06 | 양자화·속도 산출 반올림과 동률 | 공통 최근접/절반 0에서 멀리, 방향 동률은 시계 방향 후보 | ✅ 승인 |
| L-07 | 궤적 예측 범위 | 최대 240틱, 첫 기물 충돌 또는 2번째 벽 반사 뒤 종료 | ✅ 승인 |
| L-08 | 궤적 점 샘플링 | 시작점 + 4틱마다 + 사건점, 최대 64점 | ✅ 승인 |
| L-09 | 대상 파일·API·수용 규격 | 아래 최종안 | ✅ 승인 |

## L-01 권장안 · 명령 표현과 정규 바이트

권장안:

1. `LaunchCommand`는 `angle`과 `power_step`만 저장한다.
2. 마우스 위치·드래그 거리·계산된 속도·무게는 저장하지 않는다.
3. `angle`은 0~65,535, `power_step`은 0~256이다.
4. 정규 명령 바이트는 magic 없이 `schema_version:uint16=1`, `angle:uint16`, `power_step:uint16` 순서의 6바이트다.
5. replay container가 향후 명령 종류와 tick/turn 메타데이터를 감싸며, LaunchCommand 자체는 한 발사의 최소 payload만 유지한다.

이유:

- 화면 해상도와 카메라가 달라도 같은 명령을 재생할 수 있다.
- 최종 속도를 저장하면 향후 무게 공식 변경 뒤 명령 의미가 갈라지고, 드래그를 저장하면 UI 배율에 결합된다.
- 명령 schema를 별도로 두면 BattleSnapshot과 P0 SimSnapshot을 올릴 필요가 없다.

대안:

- 최종 속도 벡터 저장: 재생은 단순하지만 승인된 발사 공식을 우회하고 데이터 변조 검증이 약해진다.
- 드래그 벡터 저장: 입력 감각 분석에는 좋지만 해상도·카메라 계약까지 replay 호환성에 포함된다.

## L-02 권장안 · 드래그와 파워 단계

권장 상수:

| 상수 | 값 |
|---|---:|
| `MAX_DRAG_DISTANCE_RAW` | `192 * FixMath.SCALE` |
| `POWER_STEPS` | 256 |

계산:

```text
drag = actor_center - pointer_world
drag_length = integer_sqrt(dot(drag, drag))
clamped_length = min(drag_length, MAX_DRAG_DISTANCE_RAW)
power_step = round_nearest_away(clamped_length * 256 / MAX_DRAG_DISTANCE_RAW)
```

- `min`은 설계 정본의 명시적 파워 clamp다.
- 최대 거리 밖 드래그는 방향만 갱신하고 파워 256을 유지한다.
- `drag_length=0`은 명령 생성 실패가 아니라 power 0의 비커밋 조준 값으로 반환할 수 있다. 권위 발사 시도는 L-03 최소 파워 검사에서 실패한다.

이유:

- 192는 표준 전장 긴 변 약 1,000의 19.2%라 마우스 조작 범위가 과도하게 길지 않다.
- 256단계는 명령이 작고 축·절반·1/8 값을 정확히 표현하면서 사람 입력에 충분히 촘촘하다.

승인 후 실제 화면 픽셀 체감은 P1-5 회색상자에서 검수하며, 논리 거리 변경은 replay 명령 의미에 영향을 주므로 재승인이 필요하다.

## L-03 권장안 · 최소 파워와 각도 양자화

권장 상수:

| 상수 | 값 |
|---|---:|
| `MIN_POWER_STEP` | 32 |
| `ANGLE_STEP` | 256 |
| 방향 후보 수 | 256 |

- `power_step < 32`는 발사 불가다. 상태는 AIM에 남고 CT·월드·RNG가 바뀌지 않는다.
- 우클릭·ESC 취소와 최소 파워 미달은 구분한다. 취소는 성공한 무변경 입력이고, 발사 시도 미달은 `INVALID_LAUNCH_COMMAND` 실패다.
- 방향은 `0, 256, 512, ... 65,280` 중 하나다.
- 입력 drag와 각 후보 `FixTrigLut.direction(angle)`의 내적이 최대인 후보를 고른다.
- 정확히 같은 최대 내적 후보가 둘이면 drag에서 시계 방향 쪽 후보를 고른다. wrap 경계에서 65,280과 0이 동률이면 0을 고른다.
- float `atan2`, Godot `Vector2.angle()`, 플랫폼 삼각함수를 사용하지 않는다.

이유:

- 1.40625°는 축·45°·90°를 정확히 포함하며 256후보 전수 비교 비용이 조준 변경 시 한 번으로 제한된다.
- 기존 고정 사인 LUT만으로 독립 참조를 만들 수 있고 역삼각함수 구현을 새 정본으로 만들지 않는다.
- 12.5% 최소 파워는 작은 실수 드래그를 막으면서 약한 샷을 허용한다.

## L-04~05 권장안 · 초기 속도와 무게 보정

권장 상수:

| 상수 | 값 |
|---|---:|
| `BASE_MAX_LAUNCH_SPEED_RAW` | `1024 * FixMath.SCALE` |
| `ABSOLUTE_LAUNCH_SPEED_RAW` | `2048 * FixMath.SCALE` |
| `REFERENCE_MASS_RAW` | `64 * FixMath.SCALE` |

권장 공식:

```text
power_raw = round(power_step * FixMath.SCALE / 256)
base_speed = BASE_MAX_LAUNCH_SPEED_RAW * power_raw
mass_ratio = REFERENCE_MASS_RAW / actor.mass_raw
weight_factor = sqrt(mass_ratio)
uncapped_speed = base_speed * weight_factor
speed = min(uncapped_speed, ABSOLUTE_LAUNCH_SPEED_RAW)
velocity = FixTrigLut.direction(angle) * speed
```

- 각 곱·나눗셈·제곱근은 기존 checked Q47.16 헬퍼를 사용한다.
- mass는 P0 승인 범위 1~256만 허용한다.
- 상한 초과를 데이터 오류로 보는 일반 규칙과 달리, 이 `min`은 설계 정본 4.6의 명시적 발사 공식이다.
- 최종 속도는 0이 아니고 `SimLimits.is_launch_speed_valid()`를 만족해야 한다.
- 기준 무게 64의 full power는 1,024, 무게 256은 512, 무게 16은 절대상한 2,048이 된다.

이유:

- 기준 속도 1,024는 P0 검증 벡터의 중간값이고, 가벼운 기물에만 2,048 상한 여유를 준다.
- 제곱근 보정은 무게 4배가 속도 1/2이 되어 선형 역비례보다 극단 차이를 줄인다.
- 기준 무게 64는 P0 기본값과 일치한다.

이 값들은 U-32 일부를 P1 회색상자 기준으로 해소한다. P1-5 플레이테스트에서 변경 제안은 가능하지만, 변경 시 fixture·replay 명령 의미·회귀 범위를 함께 제시하고 재승인한다.

## L-06 권장안 · 반올림과 방향 동률

- 파워 비율, 무게 비율, 제곱근, 속도, 방향 성분은 D-33의 최근접·절반은 0에서 먼 방향을 사용한다.
- 양수 power step의 정확한 절반은 큰 step으로 간다.
- 음수 속도 성분의 정확한 절반은 절댓값이 큰 음수로 간다.
- 방향 후보 내적 동률은 L-03의 시계 방향 후보 규칙이 D-31 화면 각도 증가 방향과 일치한다.
- 정규화한 drag를 다시 float로 만들지 않는다. 방향은 선택된 LUT 단위 벡터가 유일한 정본이다.
- overflow나 중간 범위 초과는 자동 clamp하지 않고 실패하며 권위 상태를 유지한다.

## L-07~08 권장안 · 궤적 예측 범위와 표시

### 순수 예측 절차

1. source가 AIM이고 현재 행동자·월드가 유효한지 확인한다.
2. `BattleState.copy(status)`로 지역 사본을 만든다.
3. LaunchCommand를 속도로 풀고 지역 사본의 `commit_launch_velocity()`를 호출한다.
4. 최대 240번 `advance_resolve()`를 호출한다.
5. actor 위치와 P0 이벤트를 값 사본으로 관찰해 점·marker를 만든다.
6. 아래 종료 조건을 처음 만족하면 예측을 끝낸다.

종료 우선순위:

1. 현재 행동자의 `BODY_DESTROYED`
2. 현재 행동자가 포함된 첫 `BODY_COLLIDED`
3. 두 번째 `BODY_HIT_WALL`
4. actor 정지 또는 BattleState가 TURN_END 진입
5. 240 tick 도달

- 같은 step에 사건이 여럿이면 P0 event sequence가 정본이다.
- 첫 기물 충돌 뒤의 연쇄 결과는 표시하지 않는다. P1-3 피해·파괴를 아직 예측할 수 없고, 상대 기물 반응까지 긴 선으로 보여주면 확정 결과처럼 오해할 수 있기 때문이다.
- 벽은 최대 두 번 반사까지 표시한다.
- 240 tick은 120Hz 기준 2초이며 그 전에 멈추지 않으면 마지막 점을 `TRUNCATED`로 표시한다.

### 점 샘플링

- tick 0의 actor 중심을 첫 점으로 넣는다.
- 이후 4 simulation ticks마다 actor 중심을 넣는다. 기본 균등점은 최대 61개다.
- 벽·충돌·소멸·정지 사건 위치는 4틱 경계와 무관하게 사건점으로 넣는다.
- 같은 tick·같은 위치의 균등점과 사건점이 겹치면 사건점 하나만 남긴다.
- 전체 상한은 64점이다. 사건점을 넣기 위해 상한을 넘으면 가장 가까운 직전 일반점을 제거하되 시작점과 사건점은 제거하지 않는다.
- 결과 배열은 시간·event sequence 순이며 UI가 임의 재정렬하지 않는다.

### 표시 계약

- 일반 구간: 실선 또는 점선. 최종 스타일은 UI 명세로 미룬다.
- 벽 반사: 반사 marker 접근 가능.
- 첫 기물 충돌: 상대 `body_id`와 충돌 marker 접근 가능.
- 정지·소멸·잘림: 서로 다른 marker enum을 제공한다.
- 피해량·승패·능력 발동 가능성을 표시하지 않는다.

## UI 브리지 계약

`src/ui/battle/aim_input_adapter.gd`는 Godot 입력을 소유하지만 코어 상태를 직접 설정하지 않는다.

- AIM에서 현재 조작 가능한 PLAYER 참여자일 때만 좌클릭 press를 받는다.
- press 시 권위 actor 중심을 잡고, move마다 포인터를 월드 좌표로 변환해 정수화한다.
- quantized LaunchCommand가 직전 값과 달라졌을 때만 예측을 다시 요청한다.
- release 시 최소 파워 이상 명령만 외부 battle controller에 불변 값으로 전달한다.
- 우클릭·ESC는 `cancel_aim()` 요청으로 변환하며 press/move 캐시를 지운다.
- RESOLVE 등 다른 phase로 바뀌면 진행 중 드래그를 폐기한다.
- UI가 `BattleState`의 phase, CT, actor, world를 직접 수정하지 않는다.
- 카메라 변환 실패, 화면 밖 좌표, NaN/Inf는 정수화 전에 거부하고 명령을 만들지 않는다.

`src/ui/battle/trajectory_line_adapter.gd`는 `TrajectoryPrediction` 값 사본만 읽는다. 실제 선 색·두께·텍스처는 P1-5 또는 후속 UI 명세 범위다.

## 공개 API 권장안

### LaunchCommand

- `LaunchCommand.create(angle, power_step, status) -> LaunchCommand`
- `LaunchCommand.decode(bytes, status) -> LaunchCommand`
- `is_initialized() -> bool`
- `angle() -> int`
- `power_step() -> int`
- `encode(status) -> PackedByteArray`
- `copy() -> LaunchCommand`

### AimQuantizer

- `AimQuantizer.quantize(actor_center, pointer_world, status) -> LaunchCommand`
- `AimQuantizer.preview_power_step(actor_center, pointer_world, status) -> int`
- 두 함수는 순수 계산이며 RNG·월드·BattleState를 받지 않는다.

### LaunchVelocitySolver

- `LaunchVelocitySolver.solve(command, actor_body, status) -> FixVec2`
- `LaunchVelocitySolver.commit(state, command, status) -> bool`
- `commit`은 임시 계산 성공 뒤 P1-1 `commit_launch_velocity()`를 정확히 한 번 호출한다.

### TrajectoryPredictor

- `TrajectoryPredictor.predict(state, command, status) -> TrajectoryPrediction`
- 원본 state의 capture 가능한 정규 바이트가 호출 전후 완전히 같아야 한다.

### UI adapter

- `begin_aim(pointer_screen)`
- `update_aim(pointer_screen)`
- `release_aim(pointer_screen)`
- `cancel_aim()`
- 구체적 signal 이름과 Node 생명주기는 구현 시 Godot 정적 타입으로 정하되 코어 API로 취급하지 않는다.

## 오류와 원자성

### SimStatus append-only 제안

기존 마지막 `Code.RESOLVE_DEADLOCK=21`, `Operation.BATTLE_SNAPSHOT_RESTORE=82` 뒤에 추가한다.

| Code | 값 |
|---|---:|
| `INVALID_LAUNCH_COMMAND` | 22 |
| `INVALID_AIM_INPUT` | 23 |
| `PREDICTION_LIMIT_EXCEEDED` | 24 |

| Operation | 값 |
|---|---:|
| `LAUNCH_COMMAND_CREATE` | 83 |
| `LAUNCH_COMMAND_ENCODE` | 84 |
| `LAUNCH_COMMAND_DECODE` | 85 |
| `AIM_QUANTIZE` | 86 |
| `LAUNCH_VELOCITY_SOLVE` | 87 |
| `LAUNCH_COMMIT` | 88 |
| `TRAJECTORY_PREDICT` | 89 |

- 최소 파워 미달·잘못된 angle/power·0 drag 발사 시도는 `INVALID_LAUNCH_COMMAND`.
- 포인터 정수화 실패·없는 actor 중심·범위 밖 좌표는 `INVALID_AIM_INPUT`.
- 승인 상한을 넘는 점·tick·event 처리 요청은 `PREDICTION_LIMIT_EXCEEDED`.
- 예측의 정상 240틱 잘림은 오류가 아니라 `truncated=true` 결과다.
- first-error-wins를 유지한다.
- 실패한 권위 commit은 phase, actor, CT, 월드, RNG, event cursor, pending mutation을 바꾸지 않는다.
- 실패한 예측은 미초기화 중립 결과를 반환하고 원본을 바꾸지 않는다.

## 결정론과 스냅샷

- 양자화·속도 산출·예측에는 float와 RNG가 없다.
- 방향 후보는 angle 오름차순, P0 event는 sequence 순으로 처리한다.
- prediction은 source BattleState 깊은 복제만 진행한다.
- UI 캐시 hit/miss는 결과와 권위 상태에 영향을 주지 않는다.
- P1-2는 BattleSnapshot schema v1을 올리지 않는다. 명령은 commit 전 외부 입력이고, commit 뒤에는 속도가 P0 SimSnapshot에 이미 포함된다.
- P1-5 replay fixture는 LaunchCommand bytes와 해당 턴 식별자를 저장한다.
- 향후 능력이 발사 수치를 수정하면 LaunchVelocitySolver에 명시적 modifier 입력을 추가하고 명령 schema 또는 battle snapshot 영향 여부를 별도 승인한다.

## 대상 파일 권장안

### 새 전투 코어

| 파일 | 책임 |
|---|---|
| `src/core/battle/launch_limits.gd` | L-02~08 상수와 범위 검사 |
| `src/core/battle/launch_command.gd` | 불변 명령, schema v1 codec |
| `src/core/battle/aim_quantizer.gd` | drag→angle/power 순수 정수 양자화 |
| `src/core/battle/launch_velocity_solver.gd` | power·무게→Q47.16 속도와 BattleState commit |
| `src/core/battle/trajectory_point.gd` | 불변 궤적 점과 marker |
| `src/core/battle/trajectory_prediction.gd` | 불변 예측 결과 |
| `src/core/battle/trajectory_predictor.gd` | BattleState 사본 예측 |

### P1-1 호환 확장

| 파일 | 변경 |
|---|---|
| `src/core/sim/sim_status.gd` | Code 22~24, Operation 83~89 append |
| `src/core/battle/battle_limits.gd` | 변경 없음. CTB 상수와 launch 상수를 분리 |
| `src/core/battle/battle_state.gd` | 기존 공개 `commit_launch_velocity` 재사용, 계약 변경 없음 |
| `src/core/battle/battle_snapshot.gd` | schema v1 변경 없음, 회귀 테스트만 추가 |
| `src/core/README.md` | 입력 명령·예측 파생값 책임 설명 |

### UI 브리지

| 파일 | 책임 |
|---|---|
| `src/ui/battle/aim_input_adapter.gd` | Godot pointer/camera → 정수 world 입력·cancel/commit 요청 |
| `src/ui/battle/trajectory_line_adapter.gd` | 예측 값 사본을 선/marker 데이터로 변환 |

### 테스트와 독립 참조

| 파일 | 책임 |
|---|---|
| `pipeline/tests/p1_launch_aim_prediction_test.gd` | headless 수용 테스트 |
| `pipeline/tests/run_p1_launch_aim_prediction.py` | 정적 경계·Python KAT·Godot 실행 |
| `pipeline/tests/p1_launch_reference.py` | 각도 후보·파워·sqrt 무게·명령 bytes 독립 참조 |
| `pipeline/tests/fixtures/p1_launch_vectors.json` | 경계 벡터·명령 bytes·속도·예측 marker fixture |

Godot import가 생성하는 `.uid`는 함께 추적한다. P1-2에는 씬·런타임 JSON·이미지·오디오가 없다.

## 구현 순서 권장안

L-01~09와 명세 전체가 승인되면 다음 순서로 구현한다.

1. `LaunchLimits`, SimStatus append, `LaunchCommand` codec과 Python KAT
2. `AimQuantizer`와 각도/파워 경계 벡터
3. `LaunchVelocitySolver`와 P1-1 원자 commit 회귀
4. `TrajectoryPoint`·`TrajectoryPrediction`·`TrajectoryPredictor`
5. UI 입력/선 어댑터와 headless 계약 테스트
6. P1-2 narrow → P1-1 narrow → P0-1~4 narrow
7. Godot 활성 `verify --full`

각 단계는 앞 단계가 통과한 뒤 진행한다. 새 미정 동작이 드러나면 임의 확정하지 않고 영향·이전 비용·fixture·회귀 범위를 제시해 재승인을 받는다.

## 수용 기준 권장안

### 정적·enum·codec

- 새 battle 코어는 Node·SceneTree·입력·렌더·내장 물리·비결정 RNG를 사용하지 않는다.
- UI adapter만 Godot Input·Camera·Canvas API를 사용한다.
- LaunchCommand 6바이트 KAT, malformed/truncated/version/trailing 거부.
- 기존 SimStatus 0~82와 새 83~89 enum 골든.

### 양자화

- 0°, 45°, 90°, 180°, 270° 축과 각 sector 경계 양쪽.
- 정확한 방향 동률의 시계 방향 선택과 65,535→0 wrap.
- drag 0, 최소 바로 아래/정확히 최소/최대/최대 초과.
- 화면 입력 삽입 빈도와 무관하게 같은 최종 정수 pointer가 같은 명령을 냄.
- float·Godot atan2 금지 정적 검사.

### 속도와 commit

- mass 1, 16, 64, 256 × power 32, 128, 256 골든.
- 기준 mass64/full power 속도 1,024, mass16/full power 2,048, mass256/full power 512.
- 최종 벡터 방향·크기와 P0 2,048 상한.
- 최소 미달·잘못된 command·잘못된 phase의 BattleSnapshot bytes 불변.
- 성공 commit이 CT를 정확히 한 번 차감하고 RESOLVE로 전이.

### 예측

- 예측 전후 원본 BattleSnapshot bytes·RNG·event cursor·pending 완전 동일.
- 예측 첫 속도가 권위 commit 속도와 동일.
- 빈 공간 정지, 첫 기물 충돌, 1·2회 벽 반사, 소멸, 240틱 잘림.
- 시작점·4틱 균등점·사건점과 64점 상한.
- 같은 명령의 반복·BattleSnapshot 복원 뒤 예측 bytes 동일.
- 예측 경로의 각 점이 같은 command로 실제 진행한 actor 위치와 해당 tick까지 일치.

### UI 경계

- AIM 이외 phase 입력 무시.
- 조작 불가·적·없는 actor 입력 거부.
- 우클릭·ESC 취소가 CT와 권위 상태를 바꾸지 않음.
- quantized command가 바뀔 때만 prediction 재요청.
- UI가 BattleState setter나 mutable world 원본을 받지 않음.

### 통합

- `run_p1_launch_aim_prediction.py`가 `verify --full`에 자동 발견된다.
- P1-1과 P0 골든·narrow가 수정 없이 통과한다.
- BattleSnapshot schema v1과 P0 SimSnapshot schema v1 bytes가 바뀌지 않는다.

## 필요 에셋

없음. P1-2는 명령·수학·예측과 UI 브리지 계약만 구현한다. 실제 조준선과 marker의 플레이스홀더 배치·manifest 등록은 P1-5 회색상자 씬에서 수행한다.

## 승인 기록

2026-08-20 사용자가 L-01~09 권장안과 명세 전체를 승인하고 구현을 요청했다.

## 구현 기록

2026-08-20 승인 범위의 코어·UI 브리지·독립 기준값·Godot narrow runner 구현을 완료했다. P1-2 수용 테스트 15개, P1-1, P0-1~4 narrow 회귀가 통과했으며 P0-4는 1,000회 반복과 입력 순열 검사를 포함한다. `verify --full`은 장시간 실행 중 사용자 요청으로 중단했으므로 다음 작업에서 전체 검증부터 재개한다.
