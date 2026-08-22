# P1-4 · 트리거 버스 / 파괴 귀속 / 전투 결과

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-22 |
| approved | 2026-08-22 · 사용자 전체 명세 승인 (`P1-4는 이대로 확정`) |
| phase | P1 · 전투 루프 |
| 선행 명세 | P0-1~4, P1-1~3 승인·구현·검증 완료 |
| 후속 명세 | `p1_batch_sim_graybox.md` |
| 구현 권한 | 승인 범위 T-01~10 구현 완료 |
| 구현 상태 | **implemented · verified** · 2026-08-22 · Python KAT, Godot 4.6.3 narrow, P0/P1 회귀, `verify --full` 통과 |

## 목적

P0의 물리 사건과 P1의 전투 상태 전이를 하나의 결정론적 전투 트리거 경계로 변환하고, 체력 0·고정 체력 소진·소멸 영역 파괴를 같은 사망 사실로 정산한다. 그 결과를 이용해 처치 귀속과 `counts_for_victory` 기반 승패를 권위적으로 판정하며, 같은 시드·입력·삽입 순서 교란·스냅샷 복원 뒤에도 같은 트리거 순서와 전투 결과를 얻도록 한다.

T-01~10 권장안은 2026-08-22 사용자 전체 승인으로 구현 기준이 됐고, 후속 진행 요청에 따라 전체 범위를 구현·검증했다.

## 설계 정본 참조

- `docs/design/game_design.md` D-18, D-20, D-23, D-32, D-37~38, D-48
- 3.1 전투 내부 루프
- 4.7 CTB, 4.8 턴 상태 머신, 4.9 승패
- 5.1 파괴의 세 경로와 공통 파괴 사건
- 7.2 확정 트리거 목록, 7.7 기물 플래그와 중립 진영
- 14.1 결정론 원칙, 14.2 레이어 규칙, 14.4 스냅샷·리플레이
- 16장 트리거·연쇄 충돌·승패·결정론 검증
- 22.2 U-23 RNG 소비 순서
- `docs/specs/p1_ctb_battle_state.md` C-06~09
- `docs/specs/p1_damage_resolution.md` R-07~10

## 범위

- 확정 트리거 ID의 append-only 숫자 어휘와 불변 전투 트리거 레코드
- P0 `SimEvent`와 P1 phase 전이를 트리거로 바꾸는 발생 경계
- 같은 시점 사건의 전체 순서, 폭 우선 wave 큐, 유한 처리 한도
- 체력 0·고정 체력 소진·소멸 영역의 공통 사망 사실과 처치 귀속
- `counts_for_victory` 생존 수와 중립 제외에 따른 권위 승패 판정
- `BATTLE_END` 결과 latch와 기존 `CHECK` API의 마이그레이션
- U-23 실제 전투용 RNG의 서브스트림·소비 순서·퇴화 입력 계약
- `BattleSnapshot` schema v3, 깊은 복제, 롤백, 독립 기준값과 narrow 러너
- 능력 효과가 없는 P1에서도 관찰 가능한 최근 전이의 트리거 레코드

## 범위 밖

- 후보 트리거 `ON_ZONE_ENTER`, `ON_STOP`, `ON_ALLY_DEATH`
- 효과 원자 실행, 조건식, 능력 cooldown과 전투당 횟수
- 콘텐츠 JSON의 능력 등록·구독과 문자열 ID의 숫자 ID 변환
- 고정 체력·부착물·발사체의 실제 콘텐츠 구현
- 상태이상, 부활, 소환, 변신, 시너지의 실제 효과
- D-12/U-11 전투 종료 후 런 상태 처리와 패배 시 런 종료 정책
- P1-5 회색상자 씬, 샷 공급 정책, 배치 CSV, 교착 종료 규칙
- 실제 아트·효과음. P1은 manifest 등록 플레이스홀더만 사용한다.

## 현재 구현에서 확인된 선행 제약

### 1. P1-3은 사망 근거를 소비하면서 전투원 상태를 제거한다

`BattleState._consume_world_events()`는 `BODY_REMOVED` 또는 `BODY_DESTROYED`를 읽으면 participant, combatant, cooldown 상태를 같은 barrier에서 제거한다. P1-4가 제거 뒤의 월드나 전투원 배열만 조회하면 진영·직접 가해자·파괴 원인을 복원할 수 없다.

따라서 사망 트리거와 처치 귀속에 필요한 사실은 `SimEvent`와 제거 직전 전투원 사본에서 먼저 불변 레코드로 만들어야 한다. 파괴된 ID를 사후 조회하는 방식은 허용하지 않는다.

### 2. 현재 `CHECK` 결과는 외부 호출자가 주입한다

P1-1의 `apply_check_directive(CONTINUE|END)`는 상태 머신 뼈대를 만들기 위한 임시 경계였다. 이제 승패가 P1-4의 권위 규칙이 되므로 외부 호출자가 실제 생존 상태와 다른 `END` 또는 `CONTINUE`를 선택할 수 있어서는 안 된다.

기존 승인 API를 조용히 삭제하지 않는다. T-06에서 새 권위 API와 호환 wrapper의 검증 규칙을 승인받는다.

### 3. `BattleSnapshot`은 v2이고 트리거·결과·귀속 상태가 없다

현재 v2는 participant, combatant, 재충돌 cooldown과 내장 `SimSnapshot`만 저장한다. 다음 값은 이후 결과에 영향을 주므로 P1-4 승인 시 v3에 포함해야 한다.

- latched battle result
- 다음 전투 트리거 sequence
- 마지막으로 성공한 공개 전이의 관찰 레코드
- 현재 RESOLVE의 운동 원인·처치 귀속 ledger

처리 중인 wave 큐는 성공한 공개 API 반환 시 반드시 비어 있어야 하며, 안정 snapshot에 미완료 큐를 숨기지 않는다.

### 4. `PASSIVE`는 사건 트리거와 의미가 다르다

설계 정본의 `PASSIVE`는 “상시” 규칙이고 나머지는 특정 사건의 발생 규칙이다. 능력 데이터와 modifier 집계기가 없는 P1-4에서 `PASSIVE`를 매 틱 사건처럼 큐에 넣으면 중복 적용과 무한 연쇄의 원인이 된다.

P1 인덱스의 “등록·발생 경계” 표현은 효과 원자와 콘텐츠 등록이 범위 밖이라는 문장과 충돌한다. T-01 권장안은 P1-4가 확정 어휘와 passive 재평가 barrier만 정의하고, 실제 능력 등록은 데이터 기반 능력 단계로 미룬다. 영향은 문서 경계 명확화뿐이며 기존 구현 마이그레이션은 없다.

### 5. U-23 승인 전 저수준 RNG는 퇴화 입력을 거부한다

현재 `SimRng.next_below(1)`, `chance(0, denominator)`, `chance(denominator, denominator)`는 draw 전에 `INVALID_RANGE`로 실패하고 상태를 바꾸지 않는다. T-07은 저수준 P0 계약을 바꾸지 않고 전투용 wrapper가 확정 결과를 선처리하는 방향을 제안한다.

## 용어

| 용어 | 의미 |
|---|---|
| 물리 사실 | P0 `SimEvent`. 충돌·벽 반사·파괴처럼 월드가 이미 확정한 사실 |
| 전투 트리거 | 물리 사실이나 phase 경계를 능력 시스템이 소비할 수 있는 어휘로 정규화한 불변 레코드 |
| subject | 해당 트리거의 주체. 자신의 능력이 반응할 body ID. 전역 사건은 0 |
| other | 충돌 상대·피해 대상처럼 subject와 직접 관계된 body ID. 없으면 0 |
| instigator | 처치 귀속자처럼 사건을 유발한 별도 body ID. 없으면 0 |
| barrier | mutation, 트리거 wave, 결과 판정을 모두 끝낸 뒤에만 외부에 성공을 반환하는 원자적 경계 |
| wave | 같은 원인 집합에서 생긴 레코드 묶음. 처리 중 새로 생긴 레코드는 다음 wave에만 들어감 |
| 관찰 batch | 마지막으로 성공한 공개 상태 전이가 만든 트리거 레코드의 값 사본. 효과 실행 큐와 분리 |
| 운동 원인 ledger | 현재 행동에서 각 body의 운동을 시작·전달한 root body와 진영의 결정론적 계보 |
| 전투 결과 | `ONGOING`, `PLAYER_VICTORY`, `PLAYER_DEFEAT`, `DRAW` 중 하나인 latch 상태 |

## 결정 목록 — 승인 완료

| ID | 결정 | 권장안 | 상태 |
|---|---|---|---|
| T-01 | 트리거 모델과 `PASSIVE` 경계 | 고정 레코드와 사건 트리거를 P1-4에 두고, `PASSIVE`는 큐 사건이 아닌 mutation barrier 재평가 지점으로 정의. 실제 능력 등록은 후속 데이터 단계 | ✅ 승인 · 2026-08-22 |
| T-02 | 발생 조건과 같은 시점 전체 순서 | phase barrier → 이동 전 hook → `SimEvent.sequence` → 파괴/처치 → 턴 종료 → 결과 순. 한 물리 사건 내부 우선순위도 고정 | ✅ 승인 · 2026-08-22 |
| T-03 | 연쇄 큐와 처리 한도 | 폭 우선 wave, 현재 wave 중 직접 재진입 금지, wave 32·공개 전이당 레코드 4,096 초과 시 전체 롤백 | ✅ 승인 · 2026-08-22 |
| T-04 | 연쇄·환경 처치 귀속 | 직접 충돌자와 운동 root를 분리. `ON_HIT_*`는 직접 가해자, `ON_KILL`은 victim과 적대인 운동 root. 귀속 없으면 kill 없음 | ✅ 승인 · 2026-08-22 |
| T-05 | 승패와 동시 전멸 | 중립 제외·`counts_for_victory`만 집계, 결과 latch. 동시 전멸은 별도 `DRAW`로 보존 | ✅ 승인 · 2026-08-22 |
| T-06 | `CHECK` 권위 API | `resolve_check()`가 결과를 계산. 기존 directive API는 계산 결과와 일치할 때만 성공하는 호환 wrapper로 유지 | ✅ 승인 · 2026-08-22 |
| T-07 | U-23 전투 RNG 소비 | 트리거 레코드별 비소비 서브스트림, 레코드 안에서 등록·효과 순 소비. 0%·100%·단일 후보는 결과를 바로 반환하고 draw 0회 | ✅ 승인 · 2026-08-22 |
| T-08 | snapshot·복제·legacy | BattleSnapshot v3, v1/v2 읽기 호환, legacy `BATTLE_END`는 생존 집계와 일치할 때만 복원 | ✅ 승인 · 2026-08-22 |
| T-09 | 파일·API·진단 계약 | `src/core/battle/` 값 객체·버스·결과 resolver 분리, `SimStatus` 숫자는 28/97부터 append-only | ✅ 승인 · 2026-08-22 |
| T-10 | 수용·회귀 범위 | 독립 Python KAT + Godot narrow + P0/P1 전체 narrow + Godot 활성 `verify --full` | ✅ 승인 · 2026-08-22 |

## T-01 권장안 · 고정 트리거 모델

### TriggerId

숫자는 승인 뒤 append-only로 고정한다.

```text
INVALID = 0
PASSIVE = 1
ON_BATTLE_START = 2
ON_TURN_START = 3
ON_LAUNCH = 4
ON_HIT_DEAL = 5
ON_HIT_TAKE = 6
ON_ALLY_COLLIDE = 7
ON_WALL_BOUNCE = 8
ON_MOVING = 9
ON_DEATH_SELF = 10
ON_KILL = 11
ON_TURN_END = 12
ON_BATTLE_END = 13
```

- 후보 트리거는 P1-4 enum에 예약값으로 넣지 않는다.
- 기존 숫자를 바꾸거나 재사용하지 않고 새 확정 트리거만 끝에 추가한다.
- `PASSIVE`는 능력 등록 어휘에는 남지만 `BattleTriggerRecord`로 매 틱 enqueue하지 않는다.
- `BattleTriggerRecord.create()`는 `PASSIVE`를 record trigger ID로 받으면 `INVALID_TRIGGER_RECORD`로 실패한다.
- passive modifier의 순수 재평가 지점은 전투 시작, 런타임 spawn/remove가 commit된 mutation barrier, 향후 변신·상태 변경 barrier다. P1-4에는 능력 데이터가 없으므로 실제 modifier 적용은 하지 않는다.

### BattleTriggerRecord

레코드는 `RefCounted` 불변 값 객체이고 Dictionary·Variant·문자열 payload를 쓰지 않는다.

| 필드 | 형식 | 의미 |
|---|---|---|
| `sequence` | uint32, 1 이상 | 전투별 단조 증가·비재사용 관찰 순서 |
| `wave` | uint16 | 최초 사실은 0, 연쇄 생성은 이전 wave + 1 |
| `trigger_id` | uint16 | 위 append-only `TriggerId` |
| `phase` | uint16 | 레코드가 확정된 `BattleState.Phase` |
| `tick` | int64, 0 이상 | 물리 사실 tick. phase 전용 사건은 현재 world tick |
| `source_sim_sequence` | uint32 | 근거 `SimEvent.sequence`, phase 사건은 0 |
| `subject_body_id` | uint32 | 트리거 주체. 전역 사건은 0 |
| `other_body_id` | uint32 | 상대·피해 대상. 없으면 0 |
| `instigator_body_id` | uint32 | 처치 귀속자 등 별도 원인. 없으면 0 |
| `cause_id` | uint16 | 파괴 원인은 `SimEvent.CauseId`, 아니면 0 |
| `position` | `FixVec2` | 접촉·파괴 위치. 해당 없으면 zero |
| `vector` | `FixVec2` | 법선·속도처럼 트리거별로 고정한 벡터. 해당 없으면 zero |
| `value_a` | int64 | 트리거별 첫 고정 payload |
| `value_b` | int64 | 트리거별 둘째 고정 payload |
| `flags` | uint32 | 트리거별 bool bit. 미사용 bit는 0 |

레코드는 이미 제거된 body ID를 참조할 수 있다. ID는 상관키이지 생존 보장이 아니다. 소비자는 레코드의 진영·피해량처럼 필요한 고정 사실을 사후 body 조회로 복원하지 않는다.

### 발생 레코드와 능력 invocation 분리

P1-4의 레코드는 “이 트리거에 해당하는 사실이 발생했다”는 자극이다. 아직 어떤 기물이 어떤 ability를 등록했는지 알지 못하므로 ability별 invocation을 만들지 않는다. 후속 데이터 기반 능력 단계가 다음 안정 순서로 레코드와 등록을 결합한다.

```text
trigger record sequence
→ owner body_id
→ content ability numeric ID
→ effect index
```

이 분리는 P1-4에 임시 ability ID나 테스트 전용 subscriber를 영구 API로 남기지 않는다. 승인되면 P1 인덱스의 “등록·발생 경계”를 “어휘·발생·관찰 경계”로 고친다.

## T-02 권장안 · 발생 조건과 전체 순서

### phase와 물리 경계

| 트리거 | 발생 조건 | subject / other | payload |
|---|---|---|---|
| `ON_BATTLE_START` | 최초 battle-start mutation/passive barrier 성공 뒤, 첫 CTB actor 선택 전 정확히 1회 | 0 / 0 | 모두 0 |
| `ON_TURN_START` | actor가 확정되고 turn-start barrier가 성공한 뒤 AIM 진입 직전 | actor / 0 | 모두 0 |
| `ON_LAUNCH` | 유효 launch velocity가 commit되어 actor가 실제 발사된 직후 | actor / 0 | `vector = launch velocity` |
| `ON_MOVING` | 성공할 각 `SimWorld.step()` 직전, 속도 벡터가 0이 아닌 살아 있는 body마다 | body / 0 | `position = step 직전 위치`, `vector = step 직전 velocity` |
| `ON_ALLY_COLLIDE` | 같은 비중립 faction 두 combatant의 `BODY_COLLIDED`마다 양쪽 방향 1개씩 | 각 body / 상대 | `position/vector = 접점/subject→other 법선`, `value_a = impact speed raw` |
| `ON_HIT_DEAL` | P1-3에서 실제 적용 피해가 1 이상인 방향 | attacker / victim | `position/vector = 접점/attacker→victim 법선`, `value_a/b = applied/resolved damage` |
| `ON_HIT_TAKE` | 위 실제 적용 피해의 반대 관점 | victim / attacker | 같은 접점, deal과 반대 법선, 같은 피해값 |
| `ON_WALL_BOUNCE` | `BODY_HIT_WALL`마다 | body / 0 | `position/vector = 접점/법선`, `value_a/b = edge index/접근속도 raw` |
| `ON_DEATH_SELF` | 모든 `BODY_DESTROYED`. 체력 0·고정 체력·소멸 원인 동일 | destroyed body / 0 | `position/vector = 파괴 직전 위치/속도`, cause 보존 |
| `ON_KILL` | 적대 진영 victim의 파괴에 유효 귀속자가 있을 때 | credited killer / victim | death와 같은 위치·속도·cause, `instigator = direct attacker` |
| `ON_TURN_END` | RESOLVE 정지와 turn-end mutation/trigger barrier가 끝난 뒤 CHECK 직전 | 마지막 actor / 0 | 모두 0 |
| `ON_BATTLE_END` | terminal result가 latch된 뒤 정확히 1회 | 0 / 0 | `value_a = BattleResult` |

`ON_HIT_*`를 모든 저속 접촉에 발생시키는 대안은 피해임계 아래 진동이 효과를 반복시키고 “가해/피해”의 P1-3 의미와 어긋나므로 권장하지 않는다. `ON_ALLY_COLLIDE`는 이름 그대로 물리 접촉 사실이라 실제 피해 여부와 무관하다.

### 한 원인 안의 우선순위

서로 다른 phase barrier는 상태 머신의 호출 순서가 정본이다. 같은 barrier 안에서는 다음 키로 정렬하고 그 뒤 `sequence`를 부여한다.

```text
(tick,
 source_sim_sequence,
 trigger_priority,
 subject_body_id,
 other_body_id,
 instigator_body_id,
 local_ordinal)
```

`trigger_priority`는 다음 순서로 고정한다.

```text
ON_BATTLE_START
ON_TURN_START
ON_LAUNCH
ON_MOVING
ON_ALLY_COLLIDE
ON_HIT_DEAL
ON_HIT_TAKE
ON_WALL_BOUNCE
ON_DEATH_SELF
ON_KILL
ON_TURN_END
ON_BATTLE_END
```

- P0 `SimEvent.sequence`가 서로 다른 물리 원인의 선후를 먼저 결정한다. body ID가 앞선다는 이유로 나중 물리 사건을 추월하지 않는다.
- 속력 동률 양방향 피해는 낮은 attacker body ID 방향부터 `ON_HIT_DEAL`·`ON_HIT_TAKE` 한 쌍을 만들되, P1-3의 동시 HP 적용은 바꾸지 않는다.
- 한 `BODY_DESTROYED`에서는 `ON_DEATH_SELF`를 먼저, 같은 파괴의 `ON_KILL`을 뒤에 둔다. 둘 다 같은 wave의 불변 사실이며, 아직 효과가 없으므로 P1-4 자체 결과에는 순서 외 차이가 없다.
- `BODY_REMOVED`는 관리 제거이므로 사망·처치 트리거를 만들지 않는다.
- 실패한 public transition은 레코드와 다음 sequence를 포함해 호출 전 상태로 되돌린다.

## T-03 권장안 · 폭 우선 wave와 유한 처리

`BattleTriggerBus`는 현재 wave를 소비하는 동안 생긴 새 레코드를 별도 next-wave buffer에만 넣는다. 현재 배열에 append해 같은 루프에서 재귀 처리하거나 handler가 bus를 직접 다시 호출하는 방식은 금지한다.

```text
wave 0: phase 또는 P0 사실에서 생성
  → 안정 정렬 후 모두 처리
wave 1: wave 0 처리로 생성
  → 안정 정렬 후 모두 처리
...
```

P1-4에는 효과 실행기가 없으므로 실제 전투 경로는 wave 0만 만든다. 버스의 wave API와 합성 fixture로 연쇄 계약을 먼저 검증해 후속 효과 시스템이 같은 경계를 재사용한다.

권장 안전 한도:

| 한도 | 값 | 초과 처리 |
|---|---:|---|
| 한 public transition의 최대 wave 수 | 32 | `TRIGGER_LIMIT_EXCEEDED`, transition 전체 롤백 |
| 한 public transition의 최대 레코드 수 | 4,096 | 동일 |
| trigger sequence | uint32 1~`0xFFFFFFFF` | 다음 값이 없으면 `COUNTER_EXHAUSTED`, 전체 롤백 |

한도는 밸런스값이 아니라 무한 연쇄와 메모리 폭주를 막는 공학 안전선이다. 향후 정상 콘텐츠가 한도를 요구하면 콘텐츠 fixture, snapshot 크기, 최악 실행시간 회귀를 제시하고 재승인한다.

성공한 public transition은 처리 큐를 비우고 그 호출에서 확정된 record만 `last_trigger_batch` 값 사본으로 교체한다. 외부 관찰은 `record_count/record_at` 읽기만 제공하며 효과 처리 cursor를 움직이지 않는다.

## T-04 권장안 · 파괴와 처치 귀속

### 공통 사망 사실

다음 경로는 모두 `BODY_DESTROYED` 하나를 근거로 같은 `ON_DEATH_SELF`를 만든다.

- `CauseId.DAMAGE`: HP 0
- 향후 고정 체력 소진: 공통 `destroy_body()`로 들어오며 별도 append-only cause만 추가 가능
- `CauseId.KILL_BOUNDARY` / `KILL_ZONE`: 소멸 영역

파괴 원인은 디버깅·귀속 입력일 뿐 트리거 종류를 나누지 않는다. `destructible:false` 소멸도 동일하다.

### 직접 가해자와 처치 귀속자를 분리하는 이유

설계 정본은 A가 적 B를 날려 B가 적 C와 충돌하면 피해 계산에는 B 자신의 공격력을 사용한다고 확정했다. 이것은 `ON_HIT_DEAL`의 subject가 B라는 뜻이지만, 플레이어의 한 행동에서 시작된 연쇄 처치 공로까지 B에게 줘야 한다는 뜻은 아니다.

직접 가해자만 처치자로 쓰면 B와 C가 같은 enemy faction이라 `ON_KILL`이 사라지고, A의 연쇄 처치 카운터도 올라가지 않는다. 권장안은 피해 사실과 행동 원인 계보를 분리한다.

### BattleMotionCredit

현재 RESOLVE 행동 동안 body별 운동 root를 저장한다.

| 필드 | 형식 | 의미 |
|---|---|---|
| `body_id` | uint32 | 현재 운동 원인을 가진 body |
| `root_body_id` | uint32 | 이 운동 계보를 시작한 body |
| `root_faction` | uint16 | root 제거 뒤에도 남는 시작 시점 faction 사실 |
| `source_sim_sequence` | uint32 | 마지막 전달 근거 `BODY_COLLIDED.sequence`. launch는 0 |
| `tick` | int64 | 마지막 전달 tick |

- 배열은 `body_id` 오름차순이다.
- 유효 launch commit 시 actor의 root를 actor 자신으로 기록한다.
- 충돌에서 P1-3의 빠른 쪽을 직접 attacker, 느린 쪽을 victim으로 본다. victim은 `attacker.root`가 있으면 그 root를, 없으면 attacker 자신을 새 root로 받는다.
- 속력 완전 동률은 양쪽의 충돌 전 root 사본에서 두 방향을 동시에 계산한다. 낮은 ID를 먼저 적용해 상대의 갱신된 root를 다시 전달하지 않는다.
- 전달은 실제 `BODY_COLLIDED`가 생긴 접촉이면 피해임계 미만이어도 일어난다. `ON_HIT_*`는 실제 피해 1 이상일 때만 생긴다는 T-02와 구분한다.
- 벽 반사는 root를 유지한다. zone acceleration처럼 명시적 instigator가 없는 환경 운동은 새 root를 만들지 않는다.
- 향후 효과가 속도를 직접 부여할 때는 그 효과의 instigator root를 명시적으로 전달해야 한다. 0이면 기존 root를 조용히 추측하지 않는다.
- ledger는 새 행동의 launch/forced-no-launch commit 직전에 비우고, 그 행동 안에서만 유효하다.

### 처치 판정

- `ON_HIT_DEAL`과 `ON_HIT_TAKE`는 항상 P1-3의 직접 attacker/victim을 사용한다.
- 피해나 소멸로 victim이 파괴되면 먼저 victim의 현재 motion root를 처치 후보로 본다.
- root가 없으면 직접 피해 attacker를 후보로 쓴다. 환경 파괴는 후보 0이다.
- 후보의 보존된 faction과 victim의 제거 전 faction이 player↔enemy일 때만 `ON_KILL`을 만든다.
- A가 적 B를 날려 B가 적 C에게 치명 피해를 주면 hit subject는 B지만 C의 kill subject는 A다.
- A가 B를 밀친 뒤 B가 벽·구덩이·장외로 파괴돼도 B의 kill subject는 A다.
- 적 B가 자신의 턴에 출발해 같은 진영 C를 파괴하면 B와 C는 적대가 아니므로 kill trigger는 없다.
- 귀속자가 같은 물리 사건에서 먼저 또는 함께 파괴돼도 처치 레코드는 보존한다. body 생존 여부로 이미 확정된 귀속을 취소하지 않는다.
- 귀속 없는 자가 파괴, neutral 파괴, 아군 오사에는 `ON_KILL`이 없다. `ON_DEATH_SELF`는 항상 있다.

향후 고정 체력·효과 파괴 API는 명시적 `instigator_body_id`와 그 root 사실을 받을 수 있다. 명시값과 motion ledger가 모두 있으면 더 오래 이어진 root 계보를 우선하되, 정확한 효과별 전달은 해당 효과 명세에서 승인한다.

## T-05 권장안 · 승패와 동시 전멸

### BattleResult

```text
ONGOING = 0
PLAYER_VICTORY = 1
PLAYER_DEFEAT = 2
DRAW = 3
```

CHECK에서 turn-end trigger와 mutation barrier가 모두 끝난 안정 상태를 body ID 오름차순으로 한 번 순회한다.

```text
player_alive = 살아 있는 participant 중
               faction == PLAYER and counts_for_victory
enemy_alive  = 살아 있는 participant 중
               faction == ENEMY and counts_for_victory

player_alive > 0 and enemy_alive > 0 → ONGOING
player_alive > 0 and enemy_alive == 0 → PLAYER_VICTORY
player_alive == 0 and enemy_alive > 0 → PLAYER_DEFEAT
player_alive == 0 and enemy_alive == 0 → DRAW
```

- `NEUTRAL`은 `counts_for_victory`가 false라는 생성 규칙과 별개로 집계에서 명시적으로 제외한다.
- `has_turn`, `controllable`, combatant 보유 여부는 승패 집계 조건이 아니다.
- core `BattleState.create()`는 isolated fixture와 후속 동적 구성을 위해 시작부터 한쪽이 0인 상태도 허용한다. P1-5 encounter validator가 실제 회색상자 전투의 양 진영 초기 보유를 검사하며, `resolve_check()`는 현재 사실대로 즉시 terminal 결과를 낸다.
- terminal 결과는 정확히 한 번 latch한다. `BATTLE_END`에서는 actor ID 0이며 추가 turn·launch·mutation을 받지 않는다.
- `ON_BATTLE_END`는 결과 latch 뒤 생성한다. D-12 런 상태 변경은 이 record를 관찰하는 상위 계층의 후속 책임이다.

동시 전멸을 즉시 승리나 패배로 접어 넣지 않고 `DRAW`로 보존하는 이유는 결정론 코어가 사실을 잃지 않게 하기 위해서다. P1-5 표시·배치 결과에도 별도 값으로 노출한다. 로그라이트 런에서 DRAW를 패배로 취급할지는 D-12/U-11 결정 때 상위 계층에서 정하며 P1-4 core result를 바꾸지 않는다.

## T-06 권장안 · CHECK API 마이그레이션

새 권위 API:

```text
BattleState.resolve_check(status) -> bool
BattleState.battle_result() -> BattleResult
```

`resolve_check()`는 다음을 하나의 원자적 transition으로 수행한다.

1. phase가 `CHECK`이고 pending mutation/trigger queue가 없는지 검사한다.
2. 승패를 계산한다.
3. `ONGOING`이면 다음 actor를 선택하고 `TURN_START`로 간다.
4. terminal이면 result를 latch하고 `ON_BATTLE_END`를 처리한 뒤 `BATTLE_END`로 간다.
5. 성공한 trigger batch를 공개한다.

기존 승인 API는 삭제하지 않고 deprecated compatibility wrapper로 남긴다.

```text
apply_check_directive(CONTINUE, status)
    → 실제 계산이 ONGOING일 때만 resolve_check()와 동일

apply_check_directive(END, status)
    → 실제 계산이 terminal일 때만 resolve_check()와 동일
```

directive와 계산 결과가 다르면 `INVALID_BATTLE_RESULT`로 실패하고 전 상태가 불변이다. 새 게임 코드와 테스트는 `resolve_check()`만 사용한다. wrapper 제거는 별도 major schema/API 승인 없이는 하지 않는다.

## T-07 권장안 · U-23 전투 RNG 소비

### 레코드별 서브스트림

전역 가변 RNG 하나를 모든 능력이 공유하면 앞 능력의 조건 추가가 뒤 능력의 결과를 바꾼다. P1-4는 실제 전투 효과와 AI 평가를 분리한다는 D-32를 확장해, 각 trigger record가 자체 실제 전투 서브스트림을 갖는 안을 권장한다.

```text
root = BattleState가 소유한 SimWorld root RNG derivation key
purpose_id = BattleRandom.PURPOSE_TRIGGER_EFFECT (권장 숫자 1)
owner_id = subject_body_id (전역 trigger는 0)
ordinal = BattleTriggerRecord.sequence
```

- 파생은 부모를 소비하지 않는다.
- purpose 0은 root factory 전용이므로 사용하지 않는다. 숫자 1을 실제 전투 trigger effect에 먼저 배정하고 재사용하지 않는다.
- 한 record 안에서는 향후 ability numeric ID 오름차순, effect index 오름차순으로 같은 child stream을 소비한다.
- rejection sampling이 여러 raw draw를 쓰면 그 수 전체가 child draw count에 반영된다.
- 다음 record는 별도 child stream이므로 앞 record의 효과 수·rejection 횟수 변화에 영향받지 않는다.
- AI 평가 사본은 다른 purpose ID를 사용하므로 권위 전투 stream과 결과를 공유하지 않는다.
- `sequence`와 world root derivation key가 snapshot에 있으므로 성공한 transition 사이에 별도 child RNG 상태를 저장하지 않는다.
- 한 record의 처리 도중 snapshot capture는 금지한다. 실패하면 child와 BattleState transition 전체를 버린다.

### 퇴화 입력

전투 wrapper는 다음을 draw 전에 처리한다.

| 호출 | 결과 | RNG 소비 |
|---|---|---:|
| `chance(0, denominator>0)` | false | 0 |
| `chance(denominator, denominator)` | true | 0 |
| `next_index(1)` | 0 | 0 |
| 그 외 유효 범위·확률 | `SimRng` rejection/chance 계약 | 실제 raw draw 수 |

저수준 `SimRng`의 기존 거부 계약은 유지한다. 따라서 P0 fixture와 HANDOFF의 “U-23 전에는 거부” 문구는 전투 wrapper 도입 시 “저수준 API는 계속 거부, 승인된 전투 wrapper만 확정 결과를 무소비 처리”로 보강한다.

0%·100%도 의무적으로 한 draw를 소비하는 대안은 결과에 필요 없는 난수 소비를 만들고 record별 서브스트림 격리의 이점을 줄이므로 권장하지 않는다.

## T-08 권장안 · BattleSnapshot schema v3

encoder는 v3만 쓰고 decoder는 v1, v2, v3를 읽는다. 기존 participant/combatant/cooldown 레이아웃은 바꾸지 않고, v3 전투 필드를 내장 `SimSnapshot` 앞에 추가한다.

```text
battle_result:u16
next_trigger_sequence:u32

last_trigger_count:u32
for sequence ascending:
    sequence:u32
    wave:u16
    trigger_id:u16
    phase:u16
    tick:i64
    source_sim_sequence:u32
    subject_body_id:u32
    other_body_id:u32
    instigator_body_id:u32
    cause_id:u16
    position_x_raw:i64
    position_y_raw:i64
    vector_x_raw:i64
    vector_y_raw:i64
    value_a:i64
    value_b:i64
    flags:u32

motion_credit_count:u32
for body_id ascending:
    body_id:u32
    root_body_id:u32
    root_faction:u16
    source_sim_sequence:u32
    tick:i64

sim_snapshot_length:u32
sim_snapshot_bytes[sim_snapshot_length]
```

- v1/v2의 nonterminal phase는 `ONGOING`, next sequence 1, 빈 trigger batch와 빈 ledger로 복원한다.
- v1/v2 `BATTLE_END`는 현재 participant 생존 집계가 terminal일 때만 그 결과로 복원한다. 양쪽이 살아 있는데 외부 directive로 끝낸 legacy state는 의미를 정직하게 복원할 수 없으므로 `INVALID_SNAPSHOT`이다.
- v1/v2 `CHECK`와 RESOLVE snapshot은 빈 귀속 ledger 때문에 미래 결과가 달라질 수 있다. legacy snapshot 복원은 P1-4 기능이 비활성인 호환 모드가 아니라, 복원 시점부터 새 규칙을 적용한다. 정확한 중간 RESOLVE replay가 필요한 fixture는 v3로 재생성한다.
- v3 capture는 pending mutation, 미소비 P0 event, 처리 중 trigger wave가 모두 없을 때만 성공한다.
- copy, snapshot round-trip, 실패 롤백은 result, next sequence, last batch, ledger를 빠짐없이 보존한다.

v3 도입은 P0 `SimSnapshot` schema v1과 golden bytes를 바꾸지 않는다. P1-1~3 `BattleSnapshot` fixture와 legacy 수용 테스트만 영향을 받는다.

## T-09 권장안 · 파일, 공개 API, 진단

### 파일 배치

새 파일:

```text
src/core/battle/battle_trigger_id.gd
src/core/battle/battle_trigger_record.gd
src/core/battle/battle_trigger_bus.gd
src/core/battle/battle_motion_credit.gd
src/core/battle/battle_result.gd
src/core/battle/battle_result_resolver.gd
src/core/battle/battle_random.gd
pipeline/tests/p1_trigger_bus_battle_result_test.gd
pipeline/tests/p1_trigger_reference.py
pipeline/tests/run_p1_trigger_bus_battle_result.py
pipeline/tests/fixtures/p1_trigger_vectors.json
```

수정 파일:

```text
src/core/battle/battle_state.gd
src/core/battle/battle_snapshot.gd
src/core/battle/battle_limits.gd
src/core/sim/sim_status.gd
docs/specs/p1_index.md
HANDOFF.md
```

`src/core/sim/sim_event.gd`의 기존 type/cause 번호나 레이아웃은 바꾸지 않는다. 향후 고정 체력 파괴 원인이 필요할 때만 별도 승인으로 cause를 append한다.

### 공개 읽기 API

```text
BattleState.battle_result() -> int
BattleState.trigger_record_count() -> int
BattleState.trigger_record_at(index, status) -> BattleTriggerRecord
BattleState.next_trigger_sequence() -> int
BattleState.resolve_check(status) -> bool
```

- record getter는 값 사본을 반환하고 내부 배열 alias를 노출하지 않는다.
- index 오류는 release-safe `SimStatus`를 latch하고 중립 레코드를 반환한다.
- bus와 motion-credit mutation API는 `BattleState` 내부 전용이다.
- observer가 record를 읽거나 읽지 않는 선택은 시뮬 상태와 RNG를 바꾸지 않는다.

### append-only 진단 ID 권장안

현재 마지막 `SimStatus.Code`는 27, `Operation`은 96이다. 승인 시 다음 번호부터 명시값으로 추가한다.

```text
Code:
  INVALID_TRIGGER_RECORD = 28
  TRIGGER_LIMIT_EXCEEDED = 29
  INVALID_MOTION_CREDIT = 30
  INVALID_BATTLE_RESULT = 31

Operation:
  TRIGGER_RECORD_CREATE = 97
  TRIGGER_ENQUEUE = 98
  TRIGGER_DRAIN = 99
  BATTLE_TRIGGER_READ = 100
  BATTLE_MOTION_CREDIT = 101
  BATTLE_RESULT_RESOLVE = 102
  BATTLE_RANDOM = 103
```

새 ID는 중간 삽입·암묵 순번·재사용을 금지한다.

### 원자성

트리거 발생, 귀속 갱신, 결과 판정, RNG child 사용이 포함된 public mutation은 다음 패턴을 지킨다.

1. 호출 전 authoritative state의 깊은 작업 사본을 만든다.
2. 작업 사본에서 P0 step, 피해, trigger wave, mutation barrier, 결과 판정을 모두 수행한다.
3. `SimStatus`가 끝까지 OK이고 처리 큐가 비었을 때만 원본에 commit한다.
4. 실패하면 phase, world, HP, cooldown, result, sequence, batch, ledger가 모두 호출 전과 같아야 한다.

release에서 제거되는 `assert`를 실패 계약으로 사용하지 않는다.

## T-10 권장안 · 테스트와 수용 기준

### 독립 Python 기준값

Python reference는 Godot 구현을 import하거나 fixture 생성과 검사를 같은 함수로 공유하지 않는다. 최소 고정 KAT:

- TriggerId 숫자와 record little-endian 필드 바이트
- 동일 입력 record의 정렬 키와 sequence 부여
- 3-wave 폭 우선 합성 연쇄
- 32 wave 성공, 33번째 wave 실패
- 4,096 record 성공, 4,097번째 실패
- motion-credit 전달과 chained collision 귀속
- player/enemy/neutral 생존 조합별 result
- record별 RNG 파생 key, 0%·100%·단일 후보 draw 0회, rejection draw count
- BattleSnapshot v3 고정 bytes와 malformed length/enum 거부

### Godot narrow 수용 기준

1. `ON_BATTLE_START`가 actor 선택 전 한 번, `ON_TURN_START`가 actor별 한 번 발생한다.
2. aim 취소·유효하지 않은 launch는 트리거와 sequence를 바꾸지 않는다.
3. 유효 launch는 `ON_LAUNCH` 뒤 RESOLVE로 들어간다.
4. `ON_MOVING`은 step 직전 속도 비영 body ID 오름차순이고 정지 body에는 없다.
5. 같은 진영 충돌은 양쪽 `ON_ALLY_COLLIDE`, 실제 피해 방향은 `ON_HIT_DEAL` 뒤 `ON_HIT_TAKE`다.
6. 속력 동률 양방향 피해가 ID 안정 순서를 갖고 HP 동시 적용을 유지한다.
7. 한 P0 event의 벽·파괴 trigger가 source `SimEvent.sequence`를 보존한다.
8. HP 0, kill boundary, kill zone이 모두 `ON_DEATH_SELF`를 만들고 관리 제거는 만들지 않는다.
9. A→B 밀침 뒤 B 장외는 A kill, A→B→C 연쇄 피해의 C kill은 B, 귀속 없는 자가 파괴는 kill 없음이다.
10. 귀속자가 같은 step에 죽어도 이미 확정된 `ON_KILL`이 사라지지 않는다.
11. neutral과 `counts_for_victory=false` 기물은 승패에 영향이 없다.
12. 한쪽 0은 승리/패배, 양쪽 0은 DRAW이고 result는 재호출로 바뀌지 않는다.
13. directive wrapper가 실제 결과와 다르면 상태 전체가 불변이다.
14. wave/record/sequence 한도 초과와 잘못된 record는 first-error-wins이며 transition 전체가 롤백된다.
15. observer 읽기 유무가 state, result, RNG에 영향을 주지 않는다.
16. copy와 v3 snapshot round-trip 뒤 같은 입력은 같은 record bytes와 결과를 낸다.
17. v1/v2 legacy 복원 규칙과 잘못된 legacy terminal snapshot 거부를 검증한다.
18. participant·combatant 삽입 순서를 교란해도 trigger 순서와 snapshot hash가 같다.

### 회귀 순서

```text
1. Python P1-4 reference/KAT
2. Godot P1-4 narrow
3. P1-3 damage narrow
4. P1-2 launch narrow
5. P1-1 BattleState narrow
6. P0-1~4 narrow와 1,000회 결정론 반복
7. Godot 활성 pipeline/scripts/verify.py --full
```

`run_p1_trigger_bus_battle_result.py`는 `pipeline/tests/run_*.py` 규칙으로 자동 발견돼야 한다. Windows 실행은 `PYTHONUTF8=1`과 공용 Godot process helper를 사용한다.

## 구현 순서 — 전체 승인 뒤 적용

1. immutable record/result/credit 값 객체와 append-only enum·진단을 추가한다.
2. 독립 Python KAT와 fixture를 먼저 고정한다.
3. 효과 실행과 분리된 `BattleTriggerBus` wave·limit·atomic API를 구현한다.
4. P1-3 사건 소비 전에 진영·피해·파괴 사실을 capture하고 trigger로 변환한다.
5. motion-credit ledger와 공통 파괴 정산을 연결한다.
6. 권위 result resolver와 `resolve_check()`를 연결하고 compatibility wrapper를 검증한다.
7. `BattleRandom`의 record별 substream과 퇴화 입력 wrapper를 구현한다.
8. `BattleSnapshot` v3, copy, legacy decoder를 구현한다.
9. narrow → 영향받은 P0/P1 회귀 → `verify --full` 순으로 검증한다.

## 필요 에셋

없음. 이 명세는 엔진 독립 전투 코어와 테스트만 다룬다. P1-5 회색상자에서도 manifest 등록 `PLACEHOLDER_` 자산만 사용하며 art lock/gen/reskin과 SE gen/attach는 시작하지 않는다.

## 승인 요청 순서

전체 명세를 한 번에 승인할 수도 있지만, 구현 위험이 큰 순서대로 다음처럼 결정하는 것을 권장한다.

1. T-01 트리거 레코드와 `PASSIVE`/능력 등록 경계
2. T-02 발생 조건·전체 순서
3. T-03 wave·처리 한도
4. T-04 처치 귀속
5. T-05 동시 전멸과 결과
6. T-06 CHECK API migration
7. T-07 U-23 RNG 소비
8. T-08 snapshot/legacy
9. T-09 파일·진단·원자성
10. T-10 수용·회귀와 전체 명세

T-01~10은 2026-08-22 전체 승인됐다. 이후 새 증거로 수정이 필요하면 충돌, 영향, 마이그레이션 비용, 회귀 범위를 제시하고 재승인을 받는다.
