# P1-3 · 피해 해결 / 재충돌 / 체력 / 파괴

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-20 |
| approved | 2026-08-20 · 사용자 R-01~10 전체 승인 (`다음 작업 진행`) |
| phase | P1 · 전투 루프 |
| 선행 명세 | P0-1~4, P1-1, P1-2 승인·구현·검증 완료 |
| 후속 명세 | `p1_trigger_bus_battle_result.md` |
| 구현 권한 | 승인 범위 내 구현 가능 |
| 구현 상태 | 구현·검증 완료 · 2026-08-20 |

## 목적

P0의 결정론적 원-원 충돌 사실을 P1 전투 규칙으로 해석해 체력 피해와 파괴까지 원자적으로 정산한다. 충돌 직전 속도 대소, 접근 상대속도, 질량비, 진영, 재충돌 쿨다운을 고정 순서로 처리하며, 같은 입력·시드·삽입 순서 교란·스냅샷 복원 뒤에도 같은 체력과 파괴 결과를 얻도록 한다.

R-01~10 승인 기준은 구현과 회귀 검증에 반영됐다. 이 명세 범위 밖의 `⬜ 미정` 콘텐츠·밸런스 값은 계속 미정으로 유지한다.

## 설계 정본 참조

- `docs/design/game_design.md` D-13, D-15, D-19, D-22~23, D-29~34, D-44~45, D-48
- 4.5 피해 공식, 4.8 `RESOLVE`, 5.1~5.2 공통 파괴, 7.7 중립 진영
- 14.1 결정론 원칙, 14.2 레이어 규칙, 14.4 스냅샷·리플레이
- 16장 피해·연쇄 충돌·결정론 검증
- 22.5 U-32~33
- `docs/specs/p0_collision_boundaries.md`
- `docs/specs/p0_determinism_hash_regression.md`
- `docs/specs/p1_ctb_battle_state.md` C-06~09

## 범위

- `BODY_COLLIDED`가 충돌 직전 가해 방향을 손실 없이 전달하는 P0→P1 경계
- 체력·공격력·진영·크리티컬 확률을 가진 최소 전투원 상태
- 공격력, 법선 접근 상대속도, 질량비를 사용하는 순수 피해 계산기
- 비율 증가 → 비율 감소 → 크리티컬 → 아군 → 고정 증가·감소 → 최종 정수 순서
- 피해임계 미만 무피해, 속도 동률 양방향 동시 피해
- 정렬된 기물 쌍 단위 재충돌 피해 쿨다운
- 체력 0을 P0의 공통 `BODY_DESTROYED` 사건으로 변환
- `BattleSnapshot` schema v2, 깊은 복제, 롤백, 독립 기준값과 narrow 러너

## 범위 밖

- 실제 전투 RNG 소비 순서와 0%·100% 추첨 소비 여부(U-23)
- 트리거 큐, `ON_COLLISION`, `ON_HIT`, `ON_DEATH_SELF`, `ON_KILL`, 연쇄 처치 귀속
- 승패 판정과 양 진영 동시 전멸 결과
- 개별 능력·시너지·상태이상에서 보정값을 수집하는 규칙
- 고정 체력, 부착물, 발사체, 관통, 피해 예측 UI
- 기물별 최종 스탯과 전투 간 체력 이월(U-11, U-36)

## 현재 코드에서 확인된 선행 제약

### 1. 현재 충돌 사건만으로 가해자를 복원할 수 없음

현재 `SimWorld`는 `BODY_COLLIDED`에 다음 값만 기록한다.

| 필드 | 현재 의미 |
|---|---|
| `source_body_id` | 낮은 body ID |
| `target_body_id` | 높은 body ID |
| `vector` | source에서 target으로 향하는 접촉 법선 |
| `value_a` | 충돌 직전 법선 접근 상대속도 raw |
| `value_b`, `flags` | 0 |

물리 반발 뒤 속도로는 충돌 직전 두 기물의 전체 속력 대소를 일반적으로 복원할 수 없다. 따라서 사후 속력 비교나 ID를 이용한 가해자 선택은 D-13과 결정론 계약을 위반한다.

### 2. 충돌 뒤 같은 스텝에서 기물이 이미 제거될 수 있음

한 서브스텝은 이동 → 구간 소멸 → 벽 → 원 충돌 → 벽 → 점 소멸 순이다. 충돌 사건 뒤 점 소멸 사건이 생기면 `BattleState`가 사건을 읽을 때 해당 `SimBody`는 월드에서 이미 사라졌을 수 있다. 피해 계산에 필요한 충돌 시점 질량은 사건 자체가 보존해야 한다.

### 3. 피해 권위 상태는 P0가 아니라 전투 스냅샷 소유

P0 `SimBody`는 물리 상태만 소유한다. 체력, 공격력, 크리티컬 확률, 재충돌 쿨다운은 전투 결과에 영향을 주므로 `BattleState`와 `BattleSnapshot`에 포함한다. D-48에 따라 P0 `SimSnapshot`의 바이트 레이아웃은 바꾸지 않는다.

## 결정 목록 — 승인 완료

| ID | 결정 | 권장안 | 상태 |
|---|---|---|---|
| R-01 | P0 충돌 사실 확장과 회귀 비용 | 기존 고정 레이아웃의 `value_b`·`flags`에 질량 쌍·속력 대소 저장, P0 golden 재고정 | ✅ 승인 · 2026-08-20 |
| R-02 | 피해 전투원 상태 소유권 | 별도 `BattleCombatant`, 물리 body·CTB participant와 body ID로 결합 | ✅ 승인 · 2026-08-20 |
| R-03 | P1 최소 스탯 표현 | HP·공격력 정수 1~1,000,000, 크리티컬 0~10,000 bp | ✅ 승인 · 2026-08-20 |
| R-04 | U-32 피해 계수 | 기준속도 1,024, 임계속도 64, 질량지수 1/2, 질량비 1/2~2 | ✅ 승인 · 2026-08-20 |
| R-05 | U-33 크리티컬 | 2배, 비율 감소 뒤·아군 보정 전; P1-3 자동 판정은 0%만 허용 | ✅ 승인 · 2026-08-20 |
| R-06 | 아군·중립 규칙 | 같은 비중립 진영만 1/2, 중립은 항상 전액 | ✅ 승인 · 2026-08-20 |
| R-07 | 재충돌 쿨다운 | 12 물리 틱, 실제 피해가 성립한 쌍만 등록 | ✅ 승인 · 2026-08-20 |
| R-08 | 동률·동일 스텝 정산 | 속력 완전 동률은 양방향 동시 적용, 사건 sequence 순 처리 | ✅ 승인 · 2026-08-20 |
| R-09 | 체력 0 공통 파괴 | `CauseId.DAMAGE=3`과 `SimWorld.destroy_body()` append-only 확장 | ✅ 승인 · 2026-08-20 |
| R-10 | 스냅샷·API·수용 규격 | BattleSnapshot v2, v1 읽기 호환, P1-3 narrow + P0 회귀 | ✅ 승인 · 2026-08-20 |

## R-01 권장안 · 충돌 사실과 P0 호환성

### 고정 payload

`BODY_COLLIDED`의 기존 필드 수와 `SimSnapshot` schema v1 레이아웃은 유지한다.

| 필드 | P1-3 의미 |
|---|---|
| `source_body_id` | 낮은 body ID |
| `target_body_id` | 높은 body ID |
| `value_a` | 충돌 직전 `v_imp` Q47.16 raw, 양수 |
| `value_b` 하위 uint32 | source 질량 Q47.16 raw |
| `value_b` 상위 uint32 | target 질량 Q47.16 raw |
| `flags & 0x2` | `FLAG_COLLISION_SOURCE_FASTER` |
| `flags & 0x4` | `FLAG_COLLISION_TARGET_FASTER` |
| 두 속력 flag 모두 0 | 속력 제곱이 정확히 같음 |
| 두 속력 flag 모두 1 | 잘못된 사건, 전투 정산 실패 |

속력 비교는 제곱근을 구하지 않고 충돌 응답을 적용하기 전 `vx² + vy²`의 wide 정수값을 비교한다. 질량은 승인된 P0 범위 때문에 각각 uint32에 안전하게 들어가며, packed 값 전체도 양의 int64 범위 안에 있다.

### 승인 시 발생하는 기준값 변경

레이아웃은 그대로지만 기존 충돌 사건의 `value_b`와 `flags`가 0에서 실제 값으로 바뀐다. 따라서 다음을 승인된 마이그레이션으로 처리해야 한다.

- `pipeline/tests/fixtures/p0_golden_hashes.json`의 충돌 포함 기준값 재생성
- P0 충돌 사건 payload 테스트 추가
- P0-2~4 narrow와 1,000회 결정론 반복 재실행
- P1-1·P1-2 narrow와 `verify --full` 재실행
- 변경 전·후 해시를 혼용하지 않도록 fixture 버전 기록

대안인 “반발 뒤 속도로 역산”은 충돌 구현 세부에 전투 계층을 결합하고 접선 성분·다중 접촉에서 취약하므로 채택하지 않는다. 전투 계층에 질량을 중복 저장하는 안도 물리 질량 변경 시 두 권위값이 어긋나므로 채택하지 않는다.

## R-02~03 권장안 · 최소 전투원 상태

### BattleCombatant

`BattleCombatant`는 불변 값 객체이며 body ID 오름차순 배열로 보관한다.

| 필드 | 형식·범위 | 의미 |
|---|---|---|
| `body_id` | uint32, 1 이상 | `SimBody` 상관키 |
| `faction` | PLAYER / ENEMY / NEUTRAL | 피해 진영 판정 |
| `current_hp` | int64, 0~`max_hp` | 현재 체력. 0은 barrier 내부 파괴 대기 상태 |
| `max_hp` | int64, 1~1,000,000 | P1 안전 상한 |
| `attack` | int64, 1~1,000,000 | 피해 공식 정수 계수 |
| `critical_basis_points` | uint16, 0~10,000 | 10,000분율 크리티컬 확률 |

- combatant가 있으면 같은 body ID의 살아 있는 `SimBody`가 있어야 한다.
- 같은 ID에 `BattleParticipant`도 있으면 faction이 같아야 한다.
- neutral combatant는 participant 없이 존재할 수 있다.
- combatant가 없는 body는 물리 충돌은 하지만 피해를 주거나 받지 않는 장애물이다.
- 새 전투원 생성 시 HP는 1 이상이어야 하며, HP 0은 사건 정산 중에만 존재한다. 안정 snapshot은 HP 0 combatant를 허용하지 않는다.
- P1-3의 전투 통합 경로는 `critical_basis_points == 0`만 받는다. 1 이상은 R-05/U-23 경계 오류로 거부하고 상태를 바꾸지 않는다.

HP·공격력 상한은 밸런스값이 아니라 고정소수점 중간값과 테스트 비용을 제한하는 공학 안전선이다. U-36의 실제 기물 수치를 확정하지 않는다.

`BattleParticipant`에 전투 스탯을 합치지 않는다. 중립 장애물·토큰처럼 CTB에 참여하지 않지만 피해에는 참여하는 기물을 지원하고, P1-1 CTB codec과 책임을 불필요하게 바꾸지 않기 위해서다.

## R-04~06 권장안 · 피해 공식

### P1 기준 상수

| 상수 | 권장값 | 이유 |
|---|---:|---|
| `DAMAGE_REFERENCE_SPEED_RAW` | 1,024 × `FIX_SCALE` | 피해 기준속도. PT-03 발사 속도 상향 뒤에도 피해 체감을 함께 높이기 위해 유지 |
| `DAMAGE_THRESHOLD_SPEED_RAW` | 64 × `FIX_SCALE` | 기준속도의 1/16, 저속 떨림과 의미 있는 접촉 분리용 초기값 |
| 질량지수 | 1/2 | 넓은 1~256 질량 범위를 제곱근으로 완화 |
| `WEIGHT_RATIO_MIN_RAW` | 1/2 × `FIX_SCALE` | 가벼운 가해자의 피해가 소멸하지 않게 제한 |
| `WEIGHT_RATIO_MAX_RAW` | 2 × `FIX_SCALE` | 무거운 가해자의 배율 폭주 제한 |
| `FRIENDLY_DAMAGE` | 1/2 | game design 러프값 채택 |
| `CRITICAL_DAMAGE` | 2/1 | 전역 기본 크리티컬 배율 제안 |

### 순수 계산 입력

`DamageCalculator.resolve(context, status)`는 월드·RNG·BattleState를 수정하지 않는다. `DamageContext`는 다음 값을 받는다.

- attacker/victim body ID, attack, mass raw
- `v_imp_raw`
- 같은 비중립 진영 여부
- `critical_applied: bool`
- `outgoing_ratio_bonus_raw`, `incoming_ratio_reduction_raw`
- `fixed_increase`, `fixed_reduction`

P1-3 자동 충돌 경로의 modifier 값은 모두 0이다. 필드는 공식과 P2 확장 경계를 시험하기 위해서만 존재하며 능력·시너지 집계는 범위 밖이다.

### 고정 연산 순서

```text
if v_imp < 64:
    no_damage
else:
    weight_ratio = clamp(sqrt(attacker_mass / victim_mass), 1/2, 2)
    value = attack * (v_imp / 1024) * weight_ratio
    value *= 1 + outgoing_ratio_bonus
    value *= 1 - incoming_ratio_reduction
    if critical_applied: value *= 2
    if same_non_neutral_faction: value *= 1/2
    value += fixed_increase
    value -= fixed_reduction
    resolved_damage = max(1, round_half_away_from_zero(value))
    applied_damage = min(victim_current_hp, resolved_damage)
```

- 모든 소수 연산은 기존 `FixMath` Q47.16 checked API만 사용한다.
- `outgoing_ratio_bonus_raw >= 0`, `0 <= incoming_ratio_reduction_raw <= ONE_RAW`만 허용한다.
- 임계 미만이면 modifier나 최소 피해 1을 적용하지 않고 정확히 0이다.
- 임계 이상이면 고정 감소로 결과가 0 이하가 되어도 최소 1이다.
- 크리티컬은 비율 보정에 포함하므로 고정 증가·감소를 증폭하지 않는다.
- 같은 faction이라도 `NEUTRAL`끼리는 아군이 아니다. neutral이 낀 모든 방향은 전액이다.

## R-07~08 권장안 · 재충돌과 사건 정산

### 쿨다운 ledger

`DamagePairCooldown`은 `(low_body_id, high_body_id, next_allowed_tick)`을 저장한다.

- 키는 항상 `low < high`로 정규화하고 사전식 오름차순으로 저장한다.
- `event.tick < next_allowed_tick`이면 물리 반발만 남기고 피해를 건너뛴다.
- 실제로 1 이상의 피해가 한 방향 이상 성립한 뒤 `next_allowed_tick = event.tick + 12`로 기록한다.
- 임계 미만, combatant 누락, 이미 HP 0인 기물이 낀 충돌은 쿨다운을 만들거나 갱신하지 않는다.
- 제거·파괴된 body가 낀 항목은 같은 barrier에서 제거한다.

12틱은 120Hz 기준 0.1초인 P1 초기값이다. 체감 조정이 필요하면 승인된 기준값과 러너 fixture를 함께 바꾼다.

### 사건 순서와 동률

1. 한 `SimWorld.step()`이 만든 기존 사건 개수를 경계로 고정한다.
2. `SimEvent.sequence` 오름차순으로 그 경계까지 소비한다.
3. 비동률은 빠른 쪽 한 방향만 계산한다.
4. 속력 제곱 완전 동률은 두 방향 피해를 사건 직전 HP에서 먼저 계산한 뒤 동시에 적용한다.
5. HP가 0이 된 combatant는 즉시 `pending_destroy`로 표시하고, 같은 스텝의 뒤 사건에서 피해를 주거나 받지 않는다.
6. 기존 사건 중 소멸·관리 제거가 먼저 그 body를 없앴다면 해당 원인의 `BODY_DESTROYED`/`BODY_REMOVED`를 우선 보존한다.
7. 기존 사건 소비가 끝난 뒤 아직 월드에 남은 `pending_destroy`를 body ID 오름차순으로 공통 피해 파괴 API에 넘긴다.
8. 새로 생긴 파괴 사건을 이어 소비한 뒤 barrier를 끝낸다.

동률 양방향 피해는 순차 HP 차감이 아니다. 낮은 ID가 먼저 죽었다는 이유로 높은 ID의 같은 충돌 피해가 사라지지 않으며, 둘 다 치명상이면 둘 다 파괴된다. 양 진영 동시 전멸의 승패 판정은 P1-4가 담당한다.

## R-09 권장안 · 공통 파괴 경로

P0 enum과 API를 append-only로 확장한다.

```text
SimEvent.CauseId.DAMAGE = 3
SimWorld.destroy_body(body_id, cause_body_id, status) -> bool
```

`destroy_body()`의 계약은 다음과 같다.

- body가 존재하고 `destructible == true`일 때만 성공한다.
- 성공 시 body를 제거하고 `BODY_DESTROYED` 하나를 append한다.
- 사건의 source는 파괴된 body, target은 직접 피해를 준 body, cause는 `DAMAGE`, zone은 0이다.
- position과 vector에는 파괴 직전 위치와 속도를 기록한다.
- 실패는 first-error-wins이며 월드와 전투 상태를 원자적으로 롤백한다.
- P1-3 combatant는 생성 시 destructible body에만 연결할 수 있으므로 HP 0 파괴 거부는 정상 흐름에서 발생하지 않는다.

target은 P1-4가 직접 충돌 가해 사실을 읽을 상관키일 뿐이다. 넉백 소유자 추적, 연쇄 처치 귀속, `ON_KILL` 대상 결정은 P1-4 승인 전에는 해석하지 않는다.

## R-10 권장안 · 상태, codec, API

### BattleSnapshot schema v2

encoder는 v2를 쓰고 decoder는 v1과 v2를 읽는다. v1은 combatant·cooldown이 없는 damage-disabled legacy 상태로 복원한다.

v2 정규 바이트는 기존 v1 헤더·participant 뒤에 다음을 추가하고 마지막에 기존 P0 snapshot bytes를 둔다.

```text
combatant_count:u32
for body_id ascending:
    body_id:u32
    faction:u16
    current_hp:i64
    max_hp:i64
    attack:i64
    critical_basis_points:u16

cooldown_count:u32
for (low_body_id, high_body_id) lexicographic ascending:
    low_body_id:u32
    high_body_id:u32
    next_allowed_tick:i64

sim_snapshot_length:u32
sim_snapshot_bytes
```

snapshot 캡처는 기존 조건에 더해 미처리 damage event와 `pending_destroy`가 없는 안정 barrier에서만 허용한다. combatant와 cooldown은 깊게 복제하며, 복원 시 body 존재·faction 일치·HP 범위·정렬·중복·cooldown tick을 모두 검증한다.

### 공개 API 권장안

```text
BattleCombatant.create(...)
BattleCombatant.create_unassigned(...)
BattleCombatant.restore(...)
BattleCombatant.with_current_hp(...)

DamageCalculator.resolve(context, status) -> DamageResult

BattleState.create_with_combatants(world, participants, combatants, status)
BattleState.restore_with_combatants(..., combatants, cooldowns, status)
BattleState.combatant_count()
BattleState.combatant_at(index, status)
BattleState.combatant_by_body_id(body_id, status)
BattleState.cooldown_count()
BattleState.cooldown_at(index, status)
BattleState.queue_combatant_body_spawn(body, participant_or_null, combatant, ...)

SimEvent.collision_source_mass_raw(status)
SimEvent.collision_target_mass_raw(status)
SimEvent.collision_speed_order(status)
SimWorld.destroy_body(body_id, cause_body_id, status)
```

기존 `BattleState.create`, `restore`, `queue_body_spawn`은 P1-1 호환용 damage-disabled 경로로 유지한다. 기본 HP·공격력을 임의 생성하지 않는다.

### SimStatus append-only 제안

```text
Code.INVALID_COMBATANT = 25
Code.INVALID_DAMAGE_CONTEXT = 26
Code.INVALID_COLLISION_FACT = 27

Operation.COMBATANT_CREATE = 90
Operation.DAMAGE_CONTEXT_CREATE = 91
Operation.DAMAGE_RESOLVE = 92
Operation.COLLISION_FACT_READ = 93
Operation.BATTLE_DAMAGE_EVENT = 94
Operation.BATTLE_COOLDOWN_UPDATE = 95
Operation.WORLD_DESTROY_BODY = 96
```

기존 번호는 재정렬하거나 재사용하지 않는다.

## 대상 파일 권장안

### 새 전투 코어

- `src/core/battle/battle_combatant.gd`
- `src/core/battle/damage_context.gd`
- `src/core/battle/damage_result.gd`
- `src/core/battle/damage_calculator.gd`
- `src/core/battle/damage_pair_cooldown.gd`
- `src/core/battle/damage_limits.gd`

### 호환 확장

- `src/core/sim/sim_collision.gd`
- `src/core/sim/sim_event.gd`
- `src/core/sim/sim_world.gd`
- `src/core/sim/sim_status.gd`
- `src/core/battle/battle_state.gd`
- `src/core/battle/battle_snapshot.gd`

### 테스트와 기준값

- `pipeline/tests/p1_damage_resolution_test.gd`
- `pipeline/tests/p1_damage_resolution_test.gd.uid`
- `pipeline/tests/p1_damage_reference.py`
- `pipeline/tests/fixtures/p1_damage_vectors.json`
- `pipeline/tests/run_p1_damage_resolution.py`
- 충돌 payload를 직접 확인하는 기존 P0 테스트 보강
- `pipeline/tests/fixtures/p0_golden_hashes.json` 승인된 기준값 갱신

## 수용 기준 권장안

### 공식과 경계값

- 임계속도 63.999…는 0, 정확히 64는 피해가 발생한다.
- 질량비 1:1, 1:4, 4:1과 clamp 밖 입력이 독립 Python 기준값과 일치한다.
- 비율·크리티컬·아군·고정·half-away·최소 1 순서를 각각 구분하는 벡터가 있다.
- neutral 대 neutral과 neutral 대 양 진영은 아군 1/2를 적용하지 않는다.
- 자동 전투 경로의 비영 크리티컬 확률은 상태 무변경 오류다.

### 충돌과 체력

- source가 빠름, target이 빠름, 완전 동률 세 경우가 충돌 직전 속력으로 판정된다.
- 동률 치명상은 양쪽 HP를 동시에 0으로 만들고 body ID 순 파괴 사건을 낸다.
- 같은 쌍은 11틱까지 재피해가 없고 12틱째 다시 피해를 준다.
- 임계 미만 접촉은 cooldown을 소모하지 않는다.
- 연쇄 충돌은 사건 sequence 순으로 처리하며 HP 0 기물은 뒤 사건에서 제외된다.
- 충돌 직후 소멸 영역에 들어간 기물은 기존 소멸 cause를 보존하고 정산이 실패하지 않는다.

### 파괴와 원자성

- HP 0은 `BODY_REMOVED`가 아니라 `BODY_DESTROYED/DAMAGE`를 정확히 한 번 낸다.
- target body ID는 직접 가해자이고 P1-3에서 처치 소유자로 재해석하지 않는다.
- 잘못된 collision payload, overflow, 파괴 실패는 world·HP·cooldown·phase·RNG를 모두 롤백한다.

### 복제·스냅샷·결정론

- 깊은 복제 뒤 원본과 복제본의 HP·cooldown이 서로 alias되지 않는다.
- v1 snapshot을 damage-disabled 상태로 읽고, v2 encode/decode/restore가 의미론적으로 왕복한다.
- 같은 입력 1,000회, combatant·body 삽입 순서 교란, 중간 snapshot 복원 후 진행의 결과 바이트가 일치한다.
- 갱신된 P0 golden, P0-1~4, P1-1~3 narrow가 모두 통과한다.
- 마지막으로 Godot 활성 `pipeline/scripts/verify.py --full`이 통과한다.

## 구현 순서 권장안

1. R-01 승인 후 충돌 사실 payload와 P0 회귀를 먼저 구현·재고정한다.
2. `DamageLimits`, `BattleCombatant`, 순수 `DamageCalculator`와 독립 기준값을 구현한다.
3. cooldown ledger와 BattleState 사건 정산을 원자적으로 결합한다.
4. `destroy_body()` 공통 파괴 경로를 연결한다.
5. BattleSnapshot v2와 v1 읽기 호환을 구현한다.
6. P1-3 narrow 뒤 영향받은 P0/P1 narrow를 실행한다.
7. Godot 활성 `verify --full`로 마무리한다.

## 필요 에셋

없음. P1 placeholder 정책을 유지하며 art/SE 파이프라인을 실행하지 않는다.

## 승인 기록

2026-08-20 사용자 지시 `다음 작업 진행`을 직전 응답에서 요청한 R-01~10 전체 승인으로 반영했다. P0 충돌 payload 의미 확장과 golden hash 재고정, P1 피해 수치, 동률·동일 스텝 정산을 이 구현의 기준선으로 사용한다.

## 구현·검증 기록

- `BattleCombatant`, 순수 `DamageCalculator`, pair cooldown ledger, `BattleState` 사건 정산과 공통 피해 파괴 경로를 구현했다.
- `BattleSnapshot` encoder를 schema v2로 올리고 schema v1 damage-disabled 읽기 호환을 유지했다.
- 독립 Python 기준값과 Godot P1-3 narrow에서 공식 경계, payload 검증, 쿨다운, 동시 파괴, rollback, snapshot, 삽입 순서와 1,000회 반복을 검증했다.
- R-01 승인 참조 `P1-3-R-01`로 P0 golden을 재고정했다. 충돌 시나리오 3종만 바뀌고 wall/kill 시나리오 3종은 유지됐다.
- Godot 활성 `pipeline/scripts/verify.py --full` 결과: 게이트 5개 중 lore 미초기화 1개 정상 SKIP, 나머지 통과, 전체 테스트 러너 14종 통과.
