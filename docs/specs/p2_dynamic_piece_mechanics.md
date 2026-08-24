# P2-4 · 동적 기물 — 생성 / 변신 / 부착 명세

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-24 |
| approved | 2026-08-24 · 사용자 P2-D01~27 전체 승인 + 선택 3건 결정 |
| phase | P2-4 · 동적 기물 |
| 선행 단계 | P2-1 카탈로그, P2-2 효과 실행, P2-3 상태·시너지·modifier 승인·구현·검증 완료 |
| 후속 단계 | P2-5 맵·적·환경 (병렬 가능) |
| 구현 권한 | **P2-D01~27 승인 범위 내 구현 가능** |
| 구현 상태 | **승인 범위 구현·검증 완료** |

## 목적

전투 중에 **기물이 생기고, 다른 기물로 바뀌고, 서로 묶이는** 세 축을 결정론적으로 연다. P1이 이미 가진 런타임 body 생성·제거 골격과 P2-3의 상태·identity 계층을 콘텐츠 효과에 연결해, 판 위의 기물 집합이 전투 도중 변해도 스냅샷·롤백·리플레이가 바이트 단위로 재현되게 한다.

P2-4는 실제 기물의 소환 수치나 부착 감각값을 만들지 않는다. 구조 규칙만 구현하고 수치는 fixture로만 검증한다.

## 정본 참조

- `docs/design/game_design.md` 4.2 물리 표현, 4.3 이동·마찰, 4.4 충돌 해결, 4.7 CTB
- 7.6.2 부착, 7.6.3 변신, 7.6.3.1 감염, 7.7.1 기물 플래그 축·토큰, 7.7.2 중립 기물, 7.8 런 스케일 카운터
- 14.1 결정론, 14.4 리플레이
- 22장 미결 U-03, U-12, U-26, U-29, U-31, U-38, U-39
- `docs/specs/p2_index.md` 동적 기물 원자 경계, 공통 런타임 상태 모델, 결정론·RNG·원자성
- `docs/specs/p1_ctb_battle_state.md` D-37 런타임 body ID 배정, mutation barrier, phase
- `docs/specs/p2_effect_resolution.md` 실행 순서, transition 원자성
- `docs/specs/p2_status_synergy_modifiers.md` 상태 수명, `BattlePieceIdentity`, 동결 tally

참조 lore: 없음. 세계관은 현재 범위 밖이며 `lore/canon/`은 초기화하지 않았다.

## 포함 범위

- 효과 원자 `SPAWN_PIECE`, `SPAWN_PROJECTILE`, `TRANSFORM_PIECE`, `ATTACH`
- 런타임 생성 body의 identity·토큰·진영·수명(`expire`) 계약
- 변신 승계 규칙 — 체력 비율, CT 환산, 상태·링크 유지, 진영 불변, 반지름 겹침 보정
- 부착 링크 모델과 `src/core/sim/` 구속 solver, 링크 쌍 충돌 예외
- ability document schema v4의 effect payload
- `BattleSnapshot` schema v6, transition 원자성 확장, 공학 한도
- 독립 Python 기준값, Godot narrow, P0·P1·P2-1~3 회귀, `verify --full`

## 비범위

- `COPY_ABILITY` — U-12(개수 상한·중복·지속 범위)가 미정이다. 별도 승인 후 후속 명세
- `SPAWN_ZONE`, `SPAWN_OBSTACLE` — P2-5 맵·환경이 소유한다 (본 명세 착수 시 확정)
- 도플갱어의 변신 예외(체력 유지·태그 상속·레벨 1 고정) — U-31과 복사 계약에 의존
- 좀비 감염 수치와 세대 증가폭(U-26), 폰 승급 처치 수(U-39), 부착 관성·거리 수치(U-38)
- 런 스코프 지속 — 변신 원복, 용의 알 카운터, 폰 누적 처치는 P4 `RunState` 소유
- U-03 미승인 신규 정적 장애물 충돌형
- 사거리·시간 기반 소멸(드래곤 숨결의 사거리), 관통, 충격파, 가속 키워드
- 신규 trigger, VFX, UI, 실제 아트, 효과음

`COPY_ABILITY`를 제외하는 이유: 복사는 능력 소유 그래프를 런타임에 바꾸며 P2-2가 고정한 immutable `AbilityRegistry` binding을 흔든다. U-12가 상한·중복·지속을 정하기 전에는 어떤 binding 수명이 맞는지 정할 수 없다.

## 용어

| 용어 | 의미 |
|---|---|
| 런타임 body | 전투 시작 배치가 아니라 능력으로 생성된 body |
| 토큰 | 런타임 body 중 시너지 계수에서 제외되는 것. 정본 7.7.1 |
| expire | 체력과 무관하게 body를 판에서 없애는 수명 조건 |
| 링크 | 앵커 body와 부착 body를 묶는 위치 구속 |
| 앵커 | 링크의 기준이 되는 쪽 body |
| 부착체 | 링크에 끌려가는 쪽 body |
| 앵커 지점 | 링크가 실제로 연결되는 좌표. 앵커 중심이 아니다 |
| 변신 | body의 piece 원형을 바꾸되 진영·위치·속도·상태·링크를 승계하는 것 |

## 승인 결정안

| ID | 결정안 | 이유 | 상태 |
|---|---|---|---|
| P2-D01 | 런타임 생성 body는 **언제나 `is_token = true`**이며 시너지 계수에 들어가지 않는다 | 정본 7.7.1의 토큰 정의(「전투 중 능력으로 생성된 기물」)에서 직접 따라온다. U-29를 추측하지 않고 정의로 해소 | ✅ 승인 |
| P2-D02 | 생성 body의 진영은 piece 정의가 중립이면 중립, 아니면 **owner 진영을 상속**한다. effect가 진영을 지정하지 않는다 | 족쇄·손은 중립, 해골·분신·총알은 소환자 편이라는 정본 표를 데이터로 표현 | ✅ 승인 |
| P2-D03 | 생성 body의 level은 **항상 1**이다. owner level을 상속하지 않는다 | 토큰은 합성 대상이 아니고 계수에도 안 들어간다. 레벨 3 소환자의 토큰이 강해질 근거가 정본에 없다 | ✅ 승인 |
| P2-D04 | `SPAWN_PIECE`는 속도 0으로, `SPAWN_PROJECTILE`은 방향·속력을 지정해 생성한다. 그 외 의미는 동일하다 | 정본 7.7.1의 「발사체와 소환체를 별도 개념으로 두지 않는다」를 지키면서 저작 의도를 이름으로 드러냄 | ✅ 승인 |
| P2-D05 | 생성 위치는 owner 기준 오프셋으로만 지정한다. 외곽 경계 밖이면 **실패**, `KILL` 존 안이면 허용하고 다음 정산에서 즉사한다 | 절대 좌표 저작은 맵마다 깨진다. 소멸 영역 즉사는 정본 5.1 그대로 | ✅ 승인 |
| P2-D06 | 생성·변신으로 다른 body와 겹치면 **4.4 겹침 보정을 1회 적용**하고 피해를 주지 않는다 | 정본 7.6.3의 반지름 변화 규칙을 생성에도 동일 적용해 경로를 하나로 유지 | ✅ 승인 |
| P2-D07 | `expire` 축은 `NONE`/`AFTER_TURNS`/`AFTER_COLLISIONS`/`ON_LINK_RELEASE` 4종이며 piece 정의가 소유한다. 턴 감소는 **전역 `TURN_END`** 기준이다 | 토큰은 `has_turn = false`일 수 있어 자기 턴 기준을 쓸 수 없다. 정본 7.7.1의 expire 예 4종을 모두 덮는다 | ✅ 승인 |
| P2-D08 | **expire 소멸은 `ON_DEATH_SELF`를 발생시키지 않는다.** 파괴(체력 0·소멸 영역)만 발생시킨다 | 정본 D-23의 파괴 정의에 수명 종료가 없다. 토큰 소멸마다 사망 트리거가 터지면 안 된다 | ✅ 승인 |
| P2-D09 | 누적 카운터(감염 포인트, 세대, 발동 횟수)는 **P2-3 상태의 `stacks`로 표현**하고 새 카운터 축이나 새 원자를 만들지 않는다 | 변신이 상태를 전부 유지하므로 「누적 카운터 전부 유지」가 자동 충족된다. 정본 7.3 밖의 원자를 발명하지 않음 | ✅ 승인 |
| P2-D10 | 변신은 체력 비율 `max(1, floor(새최대 × 현재/최대))`, CT는 아군 `min`·적 `max` 환산, 상태·링크·카운터 유지, 진영·위치·속도 승계로 고정한다 | 정본 7.6.3이 전부 확정한 규칙의 직역 | ✅ 승인 |
| P2-D11 | `transformable = false` 대상에 대한 변신은 **성공한 무효과**다. 실패가 아니다 | 정본은 「대상이 되지 않는다」고 했지 오류라 하지 않았다. 중립을 때린 좀비가 매번 전투를 죽이면 안 된다 | ✅ 승인 |
| P2-D12 | 변신의 **지속 범위는 P2-4가 다루지 않는다.** 전투 내 변신만 구현하고 원본 piece ID를 `BattleResult`에 보고한다 | 영구·1전투·파괴까지의 원복은 D-12/U-11 미정이며 P4 `RunState` 소유 | ✅ 승인 |
| P2-D13 | 링크는 앵커 지점 3종(`SURFACE_FOLLOW`/`FIXED_POINT`/`CONTACT_POINT`)을 갖는다. 기물이 회전하지 않으므로 뒤 두 종은 **월드 고정 오프셋**으로 같은 식을 쓴다 | 정본 7.6.2의 「고정점 방향은 월드 기준 고정」에서 따라오는 단순화 | ✅ 승인 |
| P2-D14 | 구속 solver는 `src/core/sim/`의 **substep 루프 안**, 원-원 접촉 해결과 두 번째 벽 해결 사이에서 링크 ID 오름차순으로 순차 실행한다 | tick 끝에 한 번만 보정하면 부착체가 벽을 관통할 수 있다. 정본의 링크 ID 순차 해결을 그대로 둔다 | ✅ 승인 |
| P2-D15 | 링크에 참여한 body의 속도는 tick 종료 시 **위치 변화량 ÷ DT로 역산**한다. 정지 임계 판정은 그 뒤에 적용한다 | 정본 7.6.2의 속도 역산 규칙. 끌려온 족쇄가 4.5의 가해자 판정을 그대로 타게 한다 | ✅ 승인 |
| P2-D16 | 링크 쌍끼리는 **충돌 응답·피해가 없고 관통도 막는다.** 제3자·벽과는 정상 충돌한다 | 정본 7.6.2 충돌 판정 표 그대로 | ✅ 승인 |
| P2-D17 | 링크 해제는 지속 턴 만료·양쪽 중 하나의 제거·능력 취소 3종뿐이다. **앵커가 사라져도 부착체는 판에 남는다** | 정본 7.6.2 앵커 소멸 표 그대로. 부착 강도는 해제 불가 | ✅ 승인 |
| P2-D18 | ability schema v4로 올리고 effect에 kind별 exact key set인 **typed payload**를 추가한다. catalog v4, fingerprint format v4 | spawn·attach·transform은 `value_a`/`value_b` 두 칸으로 표현할 수 없다 | ✅ 승인 |
| P2-D19 | `BattleSnapshot` v6에 동적 기물 상태를 포함하고, 아래 공학 한도를 채택한다. 링크와 `next_link_id`의 단일 정본 배치는 P2-D26을 따른다. runtime JSON records는 **계속 0개** | 동적 기물 계층 전체가 리플레이 가능해야 한다. 실제 기물 수치를 발명하지 않음 | ✅ 승인 |
| P2-D20 | `transform`·`attach` payload의 exact key, owner 역할, anchor mode별 제약, spawn 방향 영벡터 실패 계약을 아래와 같이 고정한다 | loader와 effect resolver가 같은 입력을 서로 다르게 해석하지 않게 한다 | ✅ 승인 |
| P2-D21 | pieces v3에 `spawnable`과 `spawn_faction_mode_id`를 추가한다. 생성 body는 `INHERIT_OWNER` 또는 `NEUTRAL` 규칙으로 진영을 얻는다 | P2-D02의 「중립 정의」와 생성 가능 여부를 실제 데이터 축으로 만든다 | ✅ 승인 |
| P2-D22 | spawn은 level 1 능력 binding을 받고 transform은 목적 piece level 1 binding으로 교체한다. 현재 transition registry는 동결하고 다음 public transition부터 새 binding을 사용한다 | 실행 중 registry가 바뀌는 순서 의존성을 막는다 | ✅ 승인 |
| P2-D23 | transform·attach는 local transactional state에 즉시 반영하고 spawn은 record queue 소진 뒤 mutation barrier에서 원자 반영한다. spawn body는 같은 transition selector에 보이지 않는다 | 기존 effect 순서와 P1 body ID barrier를 함께 보존한다 | ✅ 승인 |
| P2-D24 | expire·link에 `applied_turn_index`를 두고 생성·부착한 같은 `TURN_END`에서는 수명을 줄이지 않는다. `ON_LINK_RELEASE`는 실제 링크 이력이 생긴 뒤 마지막 링크 해제 때만 발동한다 | 적용 즉시 1턴이 사라지는 문제와 미부착 body의 즉시 만료를 막는다 | ✅ 승인 |
| P2-D25 | 기존 `battle_result(): int`를 유지하면서 immutable `BattleResult` 보고 객체에 초기 비토큰 body의 원본 piece ID를 body ID 순으로 제공한다 | P1 호환성을 유지하고 P4 원복 입력을 명시한다 | ✅ 승인 |
| P2-D26 | 링크와 `next_link_id`의 정본은 `SimWorld`/`SimSnapshot` 하나다. `BattleSnapshot`은 이를 중복 저장하지 않고 expire·원본·runtime spawn count만 추가한다 | 복원 시 두 링크 배열이 어긋나는 이중 정본을 없앤다 | ✅ 승인 |
| P2-D27 | spawn·transform overlap은 body ID 순으로 positional correction 1회와 wall correction 1회를 적용하고, 잔여 overlap·경계 이탈이면 전체 transition을 실패시킨다 | 「보정 1회」의 정확한 종료·실패 의미를 결정론적으로 고정한다 | ✅ 승인 |

## 데이터 계약

### pieces.json schema v3 추가 필드

```json
{
  "spawnable": true,
  "spawn_faction_mode_id": 1,
  "expire_kind_id": 3,
  "expire_value": 5,
  "attach_anchor_mode_id": 2,
  "attach_anchor_offset_x_raw": 0,
  "attach_anchor_offset_y_raw": -2097152
}
```

- `expire_kind_id`가 `NONE`이면 `expire_value`는 0이어야 한다.
- `spawn_faction_mode_id`는 `INHERIT_OWNER` 또는 `NEUTRAL`이며 effect가 진영을 덮어쓰지 않는다.
- spawn effect는 `spawnable = true`인 정의만 참조할 수 있다. transform 목적지는 이 필드의 제한을 받지 않는다.
- `NEUTRAL` 정의는 `has_turn = false`, `counts_for_victory = false`여야 한다.
- `attach_*`는 이 기물이 **부착체로 쓰일 때**의 기본값이며 `ATTACH` payload가 덮어쓸 수 있다.
- 기존 v2 필드와 `tag_refs`는 그대로 유지한다.

### abilities.json schema v4 — effect payload

```json
{
  "kind_id": 12,
  "selector": {"kind_id": 1, "relation_id": 0, "limit": 1},
  "value_a": 0,
  "value_b": 0,
  "operation_id": 0,
  "spawn": {
    "piece_ref": {"numeric_id": 7, "id": "skeleton"},
    "offset_x_raw": 3145728,
    "offset_y_raw": 0,
    "speed_raw": 0,
    "direction_mode_id": 1
  }
}
```

`transform` exact payload:

```json
{
  "transform": {
    "piece_ref": {"numeric_id": 8, "id": "fixture_transform_target"}
  }
}
```

`attach` exact payload:

```json
{
  "attach": {
    "owner_role_id": 1,
    "anchor_mode_id": 1,
    "anchor_offset_x_raw": 0,
    "anchor_offset_y_raw": 0,
    "attach_distance_raw": 0,
    "inertia_basis_points": 5000,
    "duration_turns": 2
  }
}
```

| effect kind | 필수 payload | 금지 payload |
|---|---|---|
| `SPAWN_PIECE`(12) | `spawn` (`speed_raw` = 0) | `attach`, `transform` |
| `SPAWN_PROJECTILE`(13) | `spawn` (`speed_raw` > 0) | `attach`, `transform` |
| `TRANSFORM_PIECE`(14) | `transform` | `spawn`, `attach` |
| `ATTACH`(15) | `attach` | `spawn`, `transform` |
| 기존 1~11 | 없음 | 전부 |

- payload는 kind와 정확히 짝이 맞아야 한다. 불일치·누락·초과 key는 catalog 전체 실패다.
- `value_a`/`value_b`/`operation_id`는 이 4종에서 전부 0이어야 한다. payload가 값을 소유한다.
- schema v3 ability를 v4에서 묵시적으로 빈 payload로 해석하지 않는다.
- `owner_role_id = ANCHOR`면 ability owner가 anchor, selector target이 attached이고 `ATTACHED`면 반대다.
- 같은 두 body의 링크는 역할 방향과 관계없이 중복이다.
- `SURFACE_FOLLOW`는 두 offset이 0이어야 한다. `FIXED_POINT`는 payload offset을 월드 고정 오프셋으로 사용한다.
- `CONTACT_POINT`는 두 offset이 0이어야 하고 body 충돌 trigger에서만 허용한다. 실행 시 `record.position - anchor.position`을 저장한다.
- `SPAWN_PIECE`는 `speed_raw = 0`, `direction_mode_id = OWNER_VELOCITY`를 canonical 값으로 강제하고 방향 벡터를 평가하지 않는다.
- `SPAWN_PROJECTILE`의 산출 방향이 영벡터면 `INVALID_SPAWN_REQUEST`로 transition 전체가 실패한다.

### enum ID

모든 ID는 append-only다. `0`은 INVALID다.

| enum | 값 |
|---|---|
| EffectKind 추가 | 12 `SPAWN_PIECE`, 13 `SPAWN_PROJECTILE`, 14 `TRANSFORM_PIECE`, 15 `ATTACH` |
| ExpireKind | 1 `NONE`, 2 `AFTER_TURNS`, 3 `AFTER_COLLISIONS`, 4 `ON_LINK_RELEASE` |
| AnchorMode | 1 `SURFACE_FOLLOW`, 2 `FIXED_POINT`, 3 `CONTACT_POINT` |
| SpawnDirectionMode | 1 `OWNER_VELOCITY`, 2 `OWNER_TO_TARGET`, 3 `RECORD_VECTOR` |
| LinkRole | 1 `ANCHOR`, 2 `ATTACHED` |
| SpawnFactionMode | 1 `INHERIT_OWNER`, 2 `NEUTRAL` |

`TELEPORT`(8)·`SET_FLAG`(9)·`COPY_ABILITY`는 계속 loader 거부다.

### 공학 한도

| 항목 | 한도 |
|---|---:|
| 전투당 런타임 생성 body | 256 |
| transition당 spawn 요청 | 64 |
| transition당 변신 | 64 |
| 같은 body의 transition당 변신 | 1 |
| 전투당 링크 | 64 |
| body당 링크 | 8 |
| 링크 지속 턴 | 1 ~ 1,024 |
| `AFTER_TURNS` expire | 1 ~ 1,024 |
| `AFTER_COLLISIONS` expire | 1 ~ 255 |
| 부착 거리 raw | 0 ~ 반지름 상한 |
| 부착 관성 basis points | 1 ~ 10,000 |
| spawn 오프셋 거리 raw | 0 ~ 반지름 상한 × 8 |

한도 초과는 전체 load 또는 transition 실패다. truncate·일부 skip·자동 분할하지 않는다.

## 런타임 생성

### 생성 절차

```text
1) piece 정의를 조회하고 spawnable인지 검증
2) 진영 결정 — NEUTRAL 정의면 중립, INHERIT_OWNER면 owner 진영 (P2-D02·D21)
3) level 1 스탯으로 SimBody·BattleParticipant·BattleCombatant 템플릿 구성
4) 위치 = owner 위치 + payload 오프셋. 외곽 경계 밖이면 실패
5) 속도 = SPAWN_PIECE면 0, SPAWN_PROJECTILE이면 방향 × speed_raw
6) 현재 transition의 dynamic spawn queue에 넣는다
7) 모든 record queue 소진 뒤 barrier에서 D-37 순서로 body_id 배정
8) SimBody·participant·combatant·identity·base stats·expire·level 1 ability binding을 함께 등록
9) body ID 순 positional correction 1회와 wall correction 1회. 잔여 overlap·경계 이탈이면 실패
```

- ID 배정은 P1의 `(tick, cause_body_id, event_type_id, ordinal)` 정렬을 그대로 쓴다. 새 정렬 축을 만들지 않는다.
- `event_type_id`는 effect kind, `ordinal`은 transition 내 spawn 순번이다.
- 생성된 body는 CT 0에서 시작한다. 과거 추상 시간을 소급하지 않는다(D-46).
- 시너지 계수는 `BATTLE_START`에서 동결되어 있으므로 생성이 계수를 바꾸지 않는다. 태그가 있으면 효과는 받는다.
- 생성 body는 같은 transition의 selector에 보이지 않는다. 새 ability binding도 다음 public transition부터 활성화된다.
- 하나의 spawn 요청이라도 실패하면 barrier 이전 state로 transition 전체를 rollback한다. 성공 반환 시 pending spawn·mutation·event가 0이어야 한다.

### expire

| kind | 감소·판정 시점 |
|---|---|
| `NONE` | 없음 |
| `AFTER_TURNS` | 적용한 turn보다 뒤의 전역 `TURN_END` 완료 barrier에서 1 감소, 0이면 제거 |
| `AFTER_COLLISIONS` | 벽·기물 충돌 1건마다 1 감소, 0이면 제거. 링크 쌍 충돌은 응답이 없으므로 세지 않는다 |
| `ON_LINK_RELEASE` | 최소 한 번 링크된 뒤 참여 중이던 마지막 링크가 해제될 때 제거 |

- 제거는 기존 `queue_participant_removal` barrier 경로를 쓴다.
- **expire 제거는 파괴가 아니다.** `ON_DEATH_SELF`도 `BODY_DESTROYED`도 발생시키지 않고 `BODY_REMOVED`만 남긴다.
- 제거된 body의 상태 인스턴스와 링크는 P2-3·본 명세 규칙대로 함께 제거된다.
- 승패 판정은 `counts_for_victory`를 따르므로 토큰 소멸이 전투를 끝내지 않는다.
- `ExpireState`는 `applied_turn_index`와 `has_linked`를 보존한다. 생성·부착이 일어난 같은 `TURN_END`는 남은 턴을 소비하지 않는다.
- `AFTER_COLLISIONS`는 실제 발행된 body·wall collision fact만 센다. overlap 보정과 링크 쌍 skip은 세지 않는다.

## 변신

### 승계 규칙

| 항목 | 처리 |
|---|---|
| 체력 | `max(1, floor(새최대 × 현재HP / 기존최대))`, checked int64 |
| 최대 체력·공격력·크리티컬 | 새 piece level 1 값 |
| 속도 스탯 | 새 piece 값 |
| CT | 아래 환산식 |
| 질량·반지름·마찰 | 새 piece 값. base 물리 스탯을 교체한다 |
| 상태 인스턴스 | 전부 유지 |
| 링크 | 전부 유지. 앵커·부착체 역할도 유지 |
| 진영·`is_token` | 불변 |
| 위치·속도 | 승계 |
| identity | `piece_numeric_id`만 교체, `body_id`·level·진영·토큰 플래그는 유지 |
| ability binding | 목적 piece level 1 `ability_refs`로 교체. 다음 public transition부터 활성 |

CT 환산:

```text
잔여        = CT_THRESHOLD - CT
남은시간_전 = ceil_div(잔여, 이전속도)
남은시간_후 = ceil_div(잔여, 새속도)
아군: 목표 = min(남은시간_전, 남은시간_후)
적  : 목표 = max(남은시간_전, 남은시간_후)
CT_new = clamp(CT_THRESHOLD - 목표 × 새속도, 0, CT_THRESHOLD)
```

- 중립은 턴이 없으므로 CT 환산을 건너뛴다.
- 모든 나눗셈은 P0 `FixMath`의 checked 정수 연산이며 반올림 방향을 `ceil_div_int`로 고정한다.
- `CT >= CT_THRESHOLD`인 현재 행동자를 변신시켜도 행동자 지위는 바뀌지 않는다.

### 제약

- `transformable = false`이면 성공한 무효과다(P2-D11).
- 같은 transition 안에서 같은 body를 두 번 변신시킬 수 없다. 두 번째는 실패다.
- 자기 자신 piece로의 변신은 성공한 무효과다.
- 반지름이 커져 겹치면 겹침 보정 1회, 피해 없음.
- transform은 effect 순서대로 local transactional state에 즉시 반영하되 현재 transition의 immutable `AbilityRegistry`는 바꾸지 않는다.
- body ID 순 positional correction 1회와 wall correction 1회 뒤 잔여 overlap·경계 이탈이면 `INVALID_TRANSFORM_REQUEST`로 전체 rollback한다.
- 최초 배치 비토큰 body의 원본 piece numeric ID를 body별 append-only 이력으로 보관하고 immutable `BattleResult`에 보고한다. 제거된 body도 보고하며 runtime token은 제외한다. 실제 원복은 P4 소관이다.

## 부착

### 링크 레코드

| 필드 | 형 | 비고 |
|---|---|---|
| `link_id` | u32 | 전투 내 append-only |
| `anchor_body_id` | u32 | |
| `attached_body_id` | u32 | 앵커와 달라야 한다 |
| `anchor_mode_id` | u8 | `SURFACE_FOLLOW`/`FIXED_POINT`/`CONTACT_POINT` |
| `anchor_offset` | FixVec2 | 뒤 두 모드에서만 사용. 월드 고정 |
| `attach_distance_raw` | i64 | 표면 간 거리. 0이면 밀착 |
| `inertia_basis_points` | u16 | 1 ~ 10,000 |
| `remaining_turns` | u32 | 전역 `TURN_END`에서 감소 |
| `applied_turn_index` | u32 | 생성된 같은 `TURN_END` 감소 방지 |

정렬 키는 `link_id` 오름차순이다. 같은 두 body의 중복 링크는 anchor·attached 방향과 관계없이 생성 실패다.

### 구속 solver

`src/core/sim/`의 substep 루프에 삽입한다.

```text
_move_bodies
_settle_segment_kills
_resolve_walls
_resolve_circle_contacts
_resolve_links          ← 신규
_resolve_walls
_settle_point_kills
```

link_id 오름차순으로 하나씩:

```text
앵커지점 = SURFACE_FOLLOW ? 앵커위치 + 정규화(부착체위치 - 앵커위치) × 앵커반지름
                          : 앵커위치 + anchor_offset
목표거리 = 부착체반지름 + attach_distance_raw
오차     = |부착체위치 - 앵커지점| - 목표거리
방향     = 정규화(부착체위치 - 앵커지점)

보정앵커 = 오차 × 앵커질량역비   × inertia
보정부착 = 오차 × 부착체질량역비 × inertia
앵커위치   += 방향 × 보정앵커
부착체위치 -= 방향 × 보정부착
```

- 질량 역비는 4.4의 겹침 보정과 같은 식(`상대질량 / 질량합`)을 재사용한다.
- 앵커지점 정규화에서 길이가 0이면 보정을 건너뛴다. 실패가 아니다.
- 모든 연산은 checked Q47.16이며 위치 안전 범위를 벗어나면 실패한다.

tick 종료 시, 링크에 참여한 body만:

```text
속도 = (tick 종료 위치 - tick 시작 위치) × DT_DEN / DT_NUM
```

그 뒤 정지 임계 판정을 적용한다(P2-D15).

### 충돌 예외

- 링크로 묶인 두 body 사이에는 임펄스·피해·재충돌 쿨다운 갱신이 전부 없다.
- 관통은 구속이 막는다. 접촉 해결을 건너뛰는 것이지 겹침을 허용하는 것이 아니다.
- 부착체와 제3자·벽 사이는 정상 충돌이며 피해도 정상 발생한다.
- 중립 부착체는 정본 7.7.2대로 아군 감소 없이 전액 피해를 준다.

### 해제

1. `remaining_turns`가 0에 도달 — 적용 turn보다 뒤의 전역 `TURN_END` barrier에서 해제
2. 앵커 또는 부착체가 제거·파괴 — 링크만 끊기고 **남은 쪽은 판에 남는다**
3. 능력 취소 — `ATTACH`를 만든 invocation이 같은 transition에서 실패하면 롤백으로 사라진다

해제 자체는 속도를 바꾸지 않는다. 마지막 tick의 역산 속도를 그대로 유지한다.
`ON_LINK_RELEASE` body는 첫 성공 링크 때 `has_linked = true`가 되고 마지막 링크가 해제될 때만 expire한다.

## 상태 모델과 공개 API

신규 immutable/typed 객체:

```text
AttachLink
AttachLinkCollection
SpawnPayloadDefinition
TransformPayloadDefinition
AttachPayloadDefinition
ExpireState
DynamicSpawnRequest
```

공개 경계:

```text
SimWorld.add_link(link, status) -> void
SimWorld.remove_link(link_id, status) -> void
SimWorld.link_count() -> int
SimWorld.link_at(index, status) -> AttachLink

BattleState.queue_dynamic_spawn(request, status) -> bool
BattleState.transform_body(body_id, piece_definition, status) -> bool
BattleState.attach(anchor_id, attached_id, payload, status) -> bool
BattleState.link_collection_copy() -> AttachLinkCollection
BattleState.ability_registry(status) -> AbilityRegistry
BattleState.battle_result_report() -> BattleResult
```

- `SimWorld`는 링크를 값 객체 배열로 보관하고 step 롤백에 포함한다.
- 링크는 `body_id`만 참조한다. `SimWorld`가 콘텐츠 정의를 알지 않는다.
- 변신은 `PieceDefinition`을 받되 `BattleState`가 typed 값만 꺼내 쓴다.
- `AttachLinkCollection`은 `SimWorld` 링크의 typed read-only projection이며 별도 정본을 만들지 않는다.
- 기존 `battle_result() -> int`는 유지한다. `battle_result_report()`의 immutable 항목은 `body_id`, `original_piece_numeric_id`이며 body ID 오름차순이다.
- effect transition 시작 시 전달 registry와 `BattleState` binding을 대조한다. 다르면 명시적 실패이며 호출자는 매 public transition `ability_registry()`로 최신 registry를 얻는다.

## snapshot과 호환성

- `BattleSnapshot.SCHEMA_VERSION`을 6으로 올린다.
- `SimSnapshot.SCHEMA_VERSION`을 2로 올리고 링크 배열과 `next_link_id`를 추가한다. 이것이 링크 상태의 단일 정본이다.
- `BattleSnapshot` 추가 섹션: body별 expire 상태, body별 원본 piece numeric ID, 런타임 생성 body 수. 링크와 `next_link_id`는 내장 `SimSnapshot` 외에 중복하지 않는다.
- 링크는 `link_id` 오름차순, expire·원본 piece는 `body_id` 오름차순으로 인코딩한다.
- `SimSnapshot` v1은 링크 0개, `next_link_id = 1`로 복원한다. `BattleSnapshot` v1~5는 expire·원본·runtime spawn 상태가 없는 것으로 복원한다.
- schema v6 decode 뒤 re-encode는 동일 bytes여야 한다.

## 오류 계약

신규 `SimStatus` code(append-only, 49부터):

- `INVALID_ATTACH_LINK`
- `DUPLICATE_ATTACH_LINK`
- `ATTACH_LIMIT_EXCEEDED`
- `INVALID_SPAWN_REQUEST`
- `SPAWN_LIMIT_EXCEEDED`
- `INVALID_TRANSFORM_TARGET`
- `INVALID_TRANSFORM_REQUEST`
- `TRANSFORM_LIMIT_EXCEEDED`

신규 operation(append-only, 123부터):

- `WORLD_ADD_LINK`
- `WORLD_REMOVE_LINK`
- `WORLD_RESOLVE_LINKS`
- `BATTLE_DYNAMIC_SPAWN`
- `BATTLE_TRANSFORM`
- `BATTLE_ATTACH`
- `BATTLE_EXPIRE`

`ContentStatus`에는 pieces v3·abilities v4 payload field ID를 append-only로 추가한다. first-error-wins이며 `detail_a`는 body 또는 link ID, `detail_b`는 piece ID 또는 effect index로 operation별 고정 쌍을 쓴다.

## 대상 파일

신규:

```text
src/core/data/spawn_payload_definition.gd
src/core/data/transform_payload_definition.gd
src/core/data/attach_payload_definition.gd
src/core/sim/sim_link.gd
src/core/battle/attach_link_collection.gd
src/core/battle/expire_state.gd
src/core/battle/dynamic_spawn_request.gd
src/core/battle/dynamic_piece_resolver.gd
pipeline/schemas/p2-pieces-v3.schema.json
pipeline/schemas/p2-abilities-v4.schema.json
pipeline/schemas/p2-catalog-v4.schema.json
pipeline/tests/p2_dynamic_piece_mechanics_test.gd
pipeline/tests/p2_dynamic_piece_reference.py
pipeline/tests/run_p2_dynamic_piece_mechanics.py
pipeline/tests/fixtures/p2_dynamic_piece/**
```

수정:

```text
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_status.gd
src/core/data/content_catalog.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/piece_definition.gd
src/core/data/catalog.json
src/core/data/pieces.json
src/core/battle/ability_effect_definition.gd
src/core/battle/battle_state.gd
src/core/battle/battle_snapshot.gd
src/core/battle/battle_limits.gd
src/core/battle/battle_result.gd
src/core/battle/effect_resolver.gd
src/core/battle/effect_resolution_report.gd
src/core/sim/sim_status.gd
src/core/sim/sim_world.gd
src/core/sim/sim_snapshot.gd
src/core/sim/sim_collision.gd
src/core/sim/sim_limits.gd
pipeline/tests/fixtures/p2_content_catalog/**
pipeline/tests/fixtures/p2_effect_resolution/**
pipeline/tests/fixtures/p2_status_synergy/**
docs/specs/p2_index.md
AGENTS.md
HANDOFF.md
```

씬·UI·에셋·매니페스트는 수정하지 않는다.

## 필요 에셋

없음. runtime records는 비어 있고 모든 동적 기물 정의는 headless test fixture에만 존재한다. 매니페스트 등록 대상이 없다.

## 수용 기준

1. pieces v3·abilities v4·catalog v4 schema가 exact key·payload 짝·범위·한도를 검증한다.
2. payload가 kind와 불일치하거나 `value_a`/`value_b`/`operation_id`가 0이 아니면 load 실패한다.
3. schema v3 ability를 v4에서 묵시적으로 해석하지 않는다.
4. 생성 body가 `is_token = true`로 identity에 등록되고 시너지 계수를 바꾸지 않는다.
5. 태그를 가진 토큰이 동결 tally의 시너지 효과를 받는다.
6. 중립 piece 정의는 중립으로, 그 외는 owner 진영으로 생성된다.
7. 생성 body의 level이 owner level과 무관하게 항상 1이다.
8. `SPAWN_PIECE`가 속도 0으로, `SPAWN_PROJECTILE`이 지정 방향·속력으로 생성한다.
9. 외곽 경계 밖 오프셋 생성이 실패하고, `KILL` 존 내부 생성은 성공한 뒤 즉사한다.
10. 생성·변신 겹침이 보정 1회로 해소되고 피해가 발생하지 않는다.
11. 런타임 body ID가 D-37의 `(tick, cause, event_type, ordinal)` 순서로 배정된다.
12. `AFTER_TURNS`·`AFTER_COLLISIONS`·`ON_LINK_RELEASE` 세 expire가 각각 정확한 시점에 body를 제거한다.
13. expire 제거가 `ON_DEATH_SELF`와 `BODY_DESTROYED`를 발생시키지 않고 `BODY_REMOVED`만 남긴다.
14. 링크 쌍 충돌은 `AFTER_COLLISIONS` 카운터를 소비하지 않는다.
15. 변신 후 체력이 `max(1, floor(새최대 × 비율))`이고 회복 수단이 되지 않는다.
16. 변신 CT가 아군은 늦어지지 않고 적은 빨라지지 않는 방향으로 환산된다.
17. 변신이 상태 인스턴스·링크·identity의 body_id·진영·토큰 플래그를 전부 보존한다.
18. `transformable = false` 대상 변신이 성공한 무효과이며 상태를 바꾸지 않는다.
19. 같은 transition 내 같은 body의 두 번째 변신이 실패하고 전체 rollback된다.
20. 링크가 `link_id` 오름차순으로 순차 해결되고 삽입 순서를 교란해도 결과가 같다.
21. 세 앵커 모드가 각각 표면 밀착·월드 고정 오프셋·충돌점 고정을 만든다.
22. 가벼운 쪽이 더 많이 끌려가고 질량 역비가 4.4 겹침 보정과 같은 식을 쓴다.
23. 링크 쌍 사이에 임펄스·피해·쿨다운 갱신이 없고 관통도 발생하지 않는다.
24. 부착체가 제3자·벽과는 정상 충돌하고 중립 부착체가 전액 피해를 준다.
25. 링크 참여 body의 속도가 위치 변화량에서 역산되고 정지 임계가 그 뒤에 적용된다.
26. 끌려온 부착체가 4.5의 가해자 판정으로 피해를 낸다.
27. 앵커 제거 시 부착체가 판에 남고 링크만 끊긴다.
28. 지속 턴 만료 해제가 전역 `TURN_END`에서 일어나고 속도를 바꾸지 않는다.
29. 생성 256·transition당 spawn 64·변신 64·링크 64·body당 링크 8의 경계값과 초과값이 각각 성공·실패한다.
30. spawn·변신·부착 도중 실패하면 world·링크·상태·identity·expire·RNG가 byte-for-byte 복원된다.
31. 네 원자가 RNG draw 0회이고 신규 trigger를 만들지 않는다.
32. `BattleSnapshot` v6과 `SimSnapshot` 신규 섹션이 encode/decode/restore되고 재인코딩 bytes가 같다.
33. 링크 0개·런타임 생성 0개일 때 기존 P0·P1·P2 snapshot bytes·terminal 결과·golden이 승인된 migration 외에 변하지 않는다.
34. 독립 Python reference가 생성 순서·CT 환산·체력 비율·구속 보정·속도 역산의 known-answer를 계산한다.
35. 같은 fixture 1,000회와 중간 snapshot restore가 같은 final bytes/hash를 만든다.
36. `run_p2_dynamic_piece_mechanics.py`가 `verify --full`에 자동 발견된다.
37. P2-3·P2-2·P2-1 narrow, P1-1~5, P0 narrow·결정론·충돌 경계 회귀가 통과한다.
38. Godot 4.6.3 활성 `PYTHONUTF8=1 python pipeline/scripts/verify.py --full`이 통과한다.
39. transform·attach exact payload와 owner role·anchor mode 조합의 positive/negative fixture가 모두 계약대로 load된다.
40. `spawnable = false`, 중립 flag 불일치, projectile 영벡터 방향이 각각 load 또는 transition의 지정 오류로 실패한다.
41. spawn·transform 이후 level 1 ability binding이 다음 public transition부터 적용되고 현재 transition registry는 불변이다.
42. 생성·부착된 같은 `TURN_END`에서 수명이 감소하지 않고 다음 전역 `TURN_END`부터 감소한다.
43. 링크 이력이 없는 `ON_LINK_RELEASE` body는 제거되지 않고 최초 링크 뒤 마지막 해제에서만 제거된다.
44. 기존 `battle_result(): int`와 신규 immutable result report가 함께 동작하고 제거된 초기 비토큰 body의 원본 piece를 보고하되 runtime token은 제외한다.
45. 링크·`next_link_id`가 SimSnapshot에 한 번만 인코딩되며 BattleSnapshot 복원 뒤 이중 정본 불일치가 존재하지 않는다.
46. overlap 1회 보정 뒤 잔여 겹침·경계 이탈이 spawn·transform 지정 오류로 전체 rollback된다.

## 구현 순서 — 전체 승인 뒤 적용

1. pieces v3·abilities v4 payload schema와 독립 Python reference·negative fixture를 먼저 고정한다.
2. typed payload 정의와 catalog canonical v4, fingerprint v4를 구현한다.
3. `SimLink`와 `SimWorld` 링크 저장·롤백·스냅샷을 구현하고 solver 없이 P0 회귀를 통과시킨다.
4. `_resolve_links`와 충돌 예외, 속도 역산을 구현하고 P0 충돌 경계 회귀를 재실행한다.
5. 런타임 생성 경로와 identity·토큰 등록, 겹침 보정을 구현한다.
6. expire 4종과 제거 경로를 구현한다.
7. 변신 승계와 CT 환산을 구현한다.
8. 네 원자를 effect resolver의 transition rollback에 편입한다.
9. `BattleSnapshot` v6·`SimSnapshot` v2 단일 링크 정본을 구현하고 재인코딩 일치를 확인한다.
10. 생성·변신·부착·한도·rollback·snapshot 수용 테스트를 통과시킨다.
11. P2-3, P2-2, P2-1, P1, P0 회귀 뒤 Godot 활성 `verify --full`을 실행한다.
12. 구현·검증 결과를 P2 인덱스·AGENTS·HANDOFF에 기록한다.

3~4단계를 나눈 이유: 링크 저장만 넣은 상태에서 P0 골든이 그대로인지 먼저 확인해야, solver가 골든을 바꿨을 때 원인이 solver임을 단정할 수 있다.

## 승인된 선택 항목

아래 3건은 초안 제시 뒤 사람이 직접 결정했다. 본문의 부착 해제·expire·변신 절은 이 결정과 일치한다.

| 항목 | 선택지 | 결정 |
|---|---|---|
| 부착 지속 턴이 끝났을 때 부착체가 남는 속도 (정본 7.6.2 ⬜) | ① 마지막 역산 속도 유지 ② 속도 0으로 초기화 | **① 마지막 역산 속도 유지.** 휘두르다 놓으면 날아가는 것이 「채찍처럼」이라는 설계 의도에 맞다 |
| `AFTER_COLLISIONS`가 세는 충돌 범위 | ① 벽·기물 모두, 링크 쌍 제외 ② 기물 충돌만 | **① 벽·기물 모두, 링크 쌍 제외.** 정본 7.6.1 고정 체력과 같은 기준이며 U-21과는 별개 축이다 |
| 변신 시 원본 piece ID 보고 위치 | ① `BattleResult`에 body별 배열 ② snapshot에만 두고 결과에는 넣지 않음 | **① `BattleResult`.** P4가 원복을 구현하려면 전투 결과에서 읽을 수 있어야 한다 |

이 결정으로 정본 7.6.2의 ⬜ 「부착 지속 턴이 끝났을 때 부착체가 남는 속도를 갖는지」가 해소되었다. 설계 정본 본문 반영은 별도 문서 정합 변경으로 처리한다.

아래는 P2-4가 **확정하지 않고 미결로 유지**하는 정본 항목이다. 구현을 막지 않으며 fixture로 우회한다.

U-03 장애물 종류 · U-12 복사 규칙 · U-26 좀비 세대 증가폭 · U-29 닌자 분신(P2-D01이 정의로 해소) · U-31 도플갱어 예외 · U-38 부착 관성·거리 수치 · U-39 폰 승급 처치 수 · D-12/U-11 전투 종료 후 처리

## 추가 승인 결정

P2-D20~27은 초기 승인 뒤 구현 가능성 점검에서 발견된 exact payload, spawn metadata, binding 활성 시점, mutation barrier, lifetime epoch, result 보고, snapshot 정본, overlap 종료 조건을 닫는다. 기존 P2-D01~19의 의도를 바꾸지 않으며 충돌하는 저장 위치·실행 시점은 최신 결정인 P2-D20~27을 우선한다.

## 승인 기록

P2-D01~19는 2026-08-24 사용자 지시로 한 묶음 승인되었고, 승인된 선택 항목 3건은 같은 지시에서 ①·①·①로 결정되었다. 같은 날 사용자가 구현 보완안 P2-D20~27을 일괄 승인했다. 구현은 이 명세의 fixture-only 범위와 명시된 비범위를 넘지 않는다. 특히 `COPY_ABILITY`, `SPAWN_ZONE`, `SPAWN_OBSTACLE`, 도플갱어 변신 예외, 런 스코프 지속은 본 승인에 포함되지 않는다.

> [review 승인 2026-08-24] 사람 검수 승인.

## 구현·검증 기록

- catalog v4·pieces v3·abilities v4와 canonical fingerprint v4, 네 동적 효과의 exact-key typed payload를 구현했다.
- runtime token·진영·level 1 binding·수명, deterministic `SimLink` solver와 링크 쌍 충돌 예외, 변신 HP/CT/상태/링크 승계, immutable 원본 piece 결과 보고를 구현했다.
- 링크 정본은 `SimSnapshot` v2에 한 번만 저장하고 `BattleSnapshot` v6이 이를 포함한다. 공개 transition의 생성·변신·부착 실패는 전체 rollback된다.
- 독립 Python schema/fingerprint와 Godot 29개 grouped check, snapshot 복원 1,000회, P0/P1/P2 회귀 및 Godot 4.6.3 `verify --full` 러너 21종을 통과했다.
- P2-D26 승인 참조로 P0 상태 골든과 P1-5 terminal 골든을 새 snapshot schema로 이관했다. P1-5 결과·20턴·10,699틱은 유지되었다.
- 실제 runtime piece/ability records는 비어 있고, 동적 기물 수치는 fixture에만 존재한다.
