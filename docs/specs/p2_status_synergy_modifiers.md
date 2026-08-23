# P2-3 · 상태이상 / 시너지 / modifier 명세

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-24 |
| approved | 2026-08-24 · 사용자 P2-S01~20 전체 승인 (`승인 상태로 전환해`) |
| phase | P2-3 · 상태·시너지·modifier |
| 선행 단계 | P2-1 콘텐츠 카탈로그, P2-2 효과 실행 승인·구현·검증 완료 |
| 후속 단계 | P2-4 동적 기물, P2-5 맵·적·환경 |
| 구현 권한 | **P2-S01~20 승인 범위 내 구현 가능** |

## 목적

P2-2가 만든 결정론적 능력 실행 경계 위에 **지속되는 보정(modifier)** 계층을 올린다. 상태이상 인스턴스와 태그 시너지가 같은 집계 경계를 통과해 P1의 피해·CTB·물리 계약에 **입력으로만** 도달하게 하고, 그 결과가 스냅샷·롤백·리플레이에서 바이트 단위로 재현되게 한다.

P2-3은 실제 기물의 상태이상 수치나 시너지 밸런스를 만들지 않는다. 정본에서 확정된 **구조 규칙**만 구현하고, 수치와 배정은 fixture로만 검증한다.

## 정본 참조

- `docs/design/game_design.md` 4.5 피해 연산 순서, 4.7 CTB, 6장 스탯, 7.1.1~7.1.3 태그·시너지, 7.4 상태이상, 7.6.1 키워드, 7.7.1 플래그·토큰, 7.9 레벨
- `docs/specs/p2_index.md` 상태이상·시너지 경계, P1 계산 연결, 결정론·RNG·원자성, 공통 데이터 계약
- `docs/specs/p2_content_catalog.md` strict JSON, append-only ID, 원자적 카탈로그, 지문
- `docs/specs/p2_effect_resolution.md` binding·실행 순서, transition 원자성, BattleSnapshot v4
- `docs/specs/p1_damage_resolution.md` `DamageContext` 4개 modifier 입력과 연산 순서
- `docs/specs/p1_ctb_battle_state.md` phase, mutation barrier, 유효 speed 소비 지점

참조 lore: 없음. 세계관은 현재 범위 밖이며 `lore/canon/`은 초기화하지 않았다(CLAUDE.md 프로젝트 정본).

## 포함 범위

- `statuses.json` / `synergies.json` schema v1과 typed 불변 정의
- 상태 인스턴스 모델, 중첩·갱신·지속·해제 수명 규칙
- 상태 출처(source)별 병합 여부의 정본화
- 태그 계수 산정과 동결 시점, tier 활성 규칙
- 단일 modifier 집계 경계와 유효값 계산 순서·반올림·범위 정책
- 효과 원자 `APPLY_STATUS`, `REMOVE_STATUS`, `MODIFY_STAT`
- P1 `DamageContext` 4개 입력과 CTB 유효 speed 연결
- 물리 스탯(질량·반지름·마찰) 유효값의 materialize barrier
- `BattleSnapshot` schema v5, transition 원자성 확장, 공학 한도
- 독립 Python 기준값, Godot narrow, P0·P1·P2-1·P2-2 회귀, `verify --full`

## 비범위

- 실제 상태이상 수치(U-37), 태그 배정(U-11b), 시너지 세부(S-6~12), 태그 가중치 합산(U-40)
- 상태가 능력을 발동하는 축 — 화상 DoT, 냉기→빙결 승격, 감전 아군 전이
- 빙결의 「조작 불가」 의미(턴 스킵 / CT 정지), 무적(U-20), 고정 체력(U-21)
- `이상` 시너지의 부활, `체스` 국면의 파괴 카운트 게이트, `황금`의 획득 골드(P4 `RunState`)
- 신규 trigger(`ON_STATUS_APPLIED`, `ON_ZONE_ENTER`, `ON_STOP`, `ON_ALLY_DEATH`)
- `TELEPORT`, `SET_FLAG`, spawn·transform·attach·projectile·copy·무적
- 잎사귀식 자동 charge 소비(피해 해결이 상태를 소비하는 경로)
- VFX, UI, 실제 아트, 효과음

상태 발동 축을 제외하는 이유: 그것은 상태 인스턴스가 invocation owner가 되는 **새 실행 축**이며 P2-2가 고정한 `owner→ability→condition→effect` 순서를 확장한다. 수명 계약이 먼저 승인되어야 그 위에 얹을 수 있다. 화상·냉기·감전은 P2-3 승인 뒤 별도 명세에서 다룬다.

## 용어

| 용어 | 의미 |
|---|---|
| modifier | 어떤 스탯 또는 피해 입력에 더해지는 정수 기여값 |
| modifier 출처 | 기여를 공급하는 주체. P2-3에서는 시너지와 상태 2종뿐 |
| 상태 인스턴스 | `(대상, 상태, 출처)` 키로 식별되는 살아 있는 상태 기록 |
| 계수(count) | 한 태그의 시너지 계수. 전투 시작 배치에서 산정해 동결한다 |
| tier | 계수 임계값 하나와 그 임계에서 켜지는 modifier 묶음 |
| base 값 | 카탈로그·배치가 준 권위 스탯. modifier가 바꾸지 않는다 |
| 유효값 | base에 modifier를 적용한 파생값. 저장하지 않는다 |
| 재평가 시점 | 유효값이 실제로 소비되거나 materialize되는 지점 |

## 승인 결정안

| ID | 결정안 | 이유 | 상태 |
|---|---|---|---|
| P2-S01 | modifier 출처는 **시너지·상태 2종뿐**. `PASSIVE`는 P2-3에서도 실행하지 않고, 상시 보정은 `ON_BATTLE_START` + `APPLY_STATUS(BATTLE)`로 저작한다 | 집계 축을 3개에서 2개로 줄여 순서·재평가·스냅샷을 단순화. 새 schema 축이 필요 없음 | ✅ 승인 |
| P2-S02 | 권위 상태는 **base만** 보관하고 유효값은 저장하지 않는다. 예외는 물리 3종(P2-S13) | 캐시 무효화 버그를 원천 차단하고 스냅샷 표면을 최소화 | ✅ 승인 |
| P2-S03 | 상태 병합 키는 정의의 `merge_sources`가 정본. true면 `(대상, 상태)`, false면 `(대상, 상태, 출처)`. **최초 출처를 보존**하고 갱신이 바꾸지 않는다 | 출처 병합 여부는 상태마다 다르다. 최초 출처 고정이 정렬 키와 진단을 안정화 | ✅ 승인 |
| P2-S04 | 중첩 정책 3종 `SINGLE`/`STACKED`/`INDEPENDENT`와 `max_stacks`. **상한 초과는 상한 고정이며 실패가 아니다** | 중첩 상한은 게임 규칙이지 오류가 아니다. `INDEPENDENT`만 인스턴스 한도에서 실패 | ✅ 승인 |
| P2-S05 | 지속 축 3종 `TARGET_TURNS`/`BATTLE`/`CHARGES`, 갱신 정책 4종 `MAX`/`REPLACE`/`EXTEND`/`KEEP` | 정본의 「1턴」·「그 전투 동안」·「다음 충돌」을 모두 표현하는 최소 집합 | ✅ 승인 |
| P2-S06 | `TARGET_TURNS`는 **대상 자신의 `TURN_END` 완료 barrier**에서 1 감소하며, 부여된 턴(`applied_turn_index == turn_index`)은 감소하지 않는다. `BattleState`에 단조 `turn_index`를 추가 | 「1턴간」이 부여 즉시 소멸하지 않게 하고 전역/대상 턴 혼선을 제거 | ✅ 승인 |
| P2-S07 | 해제 경로는 만료·`REMOVE_STATUS`·대상 제거·전투 종료 4종뿐. **출처 사망은 해제 사유가 아니다.** `CHARGES`는 시간으로 줄지 않고 `REMOVE_STATUS`로만 소비한다 | 정본에 출처 연동 해제 규칙이 없다. 자동 charge 소비는 P1 피해 경로를 변이 지점으로 바꾼다 | ✅ 승인 |
| P2-S08 | 시너지 계수는 **전투 시작 배치의 비토큰 기물**로 `BATTLE_START` 완료 barrier에서 **1회 동결**한다. 역할군 기물당 1, 테마 기물당 level, 최소 발동 2, 진영별 산정 | P2 인덱스 공통 계약의 직접 구체화. 죽음의 나선과 캐시 무효화를 함께 제거 | ✅ 승인 |
| P2-S09 | 활성 tier는 `min_count` 이하인 것 **전부 누적**. `count_cap`으로 유효 계수를 제한하고 value mode는 `FLAT`/`SCALED` 2종 | 「선형 누적」과 「모인 시너지만큼 활성화」를 그대로 표현. 대체형 tier는 비범위 | ✅ 승인 |
| P2-S10 | `BOTH_FACTIONS` 시너지(`체스`)는 **진영별 계수를 각각 독립 적용해 합산**한다. 효과 대상은 태그 보유 body 전부 | 「계수는 내 배치로만, 효과는 양쪽에」를 각 진영이 자기 계수로 연 국면으로 읽음. 대안은 최댓값 1개 적용 | ✅ 승인 |
| P2-S11 | 유효값 = `(base + Σ ADD) × (10000 + Σ RATIO_BP) / 10000`, 나눗셈은 `FixMath.round_div_int` **1회**. 피해 modifier 4종은 `ADD`만, 스칼라 스탯 kind는 `ADD`·`RATIO` 모두 허용 | 가산 먼저·비율 나중으로 순서를 고정하고 반올림 지점을 1개로 줄인다 | ✅ 승인 |
| P2-S12 | 범위 정책은 kind별 정본. 전투 스탯은 `SATURATE`, **물리 스탯은 `STRICT`(범위 밖이면 실패)**. int64 overflow는 언제나 실패 | 정본의 「P0 안전 범위를 조용히 clamp하지 않는다」를 지키면서 CTB 나눗셈 안전(speed ≥ 1)을 보장 | ✅ 승인 |
| P2-S13 | 물리 스탯 modifier(`MASS_RAW`/`RADIUS_RAW`/`FRICTION_MULTIPLIER_RAW`)를 활성화하고 **`AIM→RESOLVE` barrier에서 1회 materialize**한다. `SimBody.with_physical_stats`·`SimWorld.set_body_physical_stats`를 추가하고 P0 회귀를 재실행한다 | `강철` 시너지가 무게를 요구한다. 매 tick 파생 계산은 P0 순수성·성능을 깬다. 반려 시 kind 3종은 loader 거부로 예약만 한다 | ✅ 승인 |
| P2-S14 | 신규 원자는 `APPLY_STATUS`(10)·`REMOVE_STATUS`(11)와 `MODIFY_STAT`(7) 활성화 3종. `TELEPORT`·`SET_FLAG`는 계속 거부 | P2-2가 예약한 이름을 순서대로 여는 최소 증분 | ✅ 승인 |
| P2-S15 | `MODIFY_STAT`은 **base를 되돌릴 수 없게** 바꾸며 대상은 `ATTACK`/`SPEED_STAT`/`CRITICAL_BASIS_POINTS` 3종, `ADD`만. 결과가 저작 범위를 벗어나면 실패 | 상태와 역할이 겹치지 않게 한다. 물리 base 변경은 P0 회귀 범위, 피해 modifier는 base가 없는 파생값 | ✅ 승인 |
| P2-S16 | 상태·modifier 원자는 **RNG를 소비하지 않고 새 trigger record를 만들지 않는다.** 신규 trigger는 도입하지 않는다 | 확률·연쇄가 붙기 전에 수명 계약을 먼저 고정 | ✅ 승인 |
| P2-S17 | schema 상승: catalog v3, pieces v2(`tag_refs`), abilities v3(effect kind·operation 확장), statuses v1, synergies v1, fingerprint format v3. **`tags.json`은 만들지 않고** 태그는 `id_registry.json`의 TAG namespace에 둔다 | P2-C11 exact version 정책 유지. 파일 증가를 2개로 억제 | ✅ 승인 |
| P2-S18 | `BattleSnapshot` v5에 `turn_index`, 상태 인스턴스, 동결 tally, piece identity, base 물리 스탯을 포함. v1~4는 빈 콘텐츠·상태 0개일 때만 복원 | 상태 계층 전체가 리플레이 가능해야 한다 | ✅ 승인 |
| P2-S19 | P2-E10 transition 원자성을 상태·tally·identity·base stats·`turn_index`까지 확장한다. 실패 시 호출 전과 byte-for-byte 동일 | 부분 적용된 상태는 이후 모든 전투를 오염시킨다 | ✅ 승인 |
| P2-S20 | 아래 공학 한도 표를 채택하고, runtime JSON records는 **계속 0개**로 둔다. 태그 배정·상태 수치·시너지 세부는 fixture로만 검증한다 | U-11b·U-37·S-6~12·U-20·21을 추측 확정하지 않음 | ✅ 승인 |

## 데이터 계약

### statuses.json schema v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "chill",
      "stack_policy_id": 2,
      "max_stacks": 3,
      "duration_kind_id": 1,
      "default_duration": 2,
      "max_duration": 8,
      "refresh_policy_id": 1,
      "merge_sources": true,
      "modifiers": [
        {"kind_id": 2, "operation_id": 2, "value_mode_id": 2, "value": -500}
      ]
    }
  ]
}
```

### synergies.json schema v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "destruction",
      "tag_ref": {"numeric_id": 1, "id": "destruction"},
      "tag_kind_id": 1,
      "scope_id": 1,
      "count_cap": 5,
      "tiers": [
        {
          "min_count": 2,
          "modifiers": [
            {"kind_id": 4, "operation_id": 1, "value_mode_id": 2, "value": 1000}
          ]
        }
      ]
    }
  ]
}
```

- exact key set을 사용한다. unknown/missing key는 catalog 전체 실패다.
- `records`는 `numeric_id` 오름차순으로 정규화하고 배열 저작 순서는 의미가 없다.
- `tiers`는 `min_count` 오름차순이어야 하며 중복 `min_count`는 실패다.
- `min_count`는 2 이상이다. 정본의 최소 발동 계수를 loader가 강제한다.
- 한 태그에 시너지 정의는 최대 1개다. 중복은 실패다.
- `pieces.json` v2는 `tag_refs` 배열을 추가하며 `numeric_id` 오름차순·중복 금지다.
- `modifiers[].value`는 부호 있는 정수다. 둔화·경감은 음수로 저작한다.

### enum ID

모든 ID는 append-only다. `0`은 INVALID다.

ModifierKind:

| 값 | 이름 | 단위 | 정책 | 유효 범위 |
|---:|---|---|---|---|
| 1 | `ATTACK` | 정수 | SATURATE | 1 ~ 1,000,000 |
| 2 | `SPEED_STAT` | 정수 | SATURATE | 1 ~ 2,000 |
| 3 | `CRITICAL_BASIS_POINTS` | bp | SATURATE | 0 ~ 10,000 |
| 4 | `DAMAGE_OUTGOING_RATIO_BONUS` | bp | SATURATE | 0 ~ 100,000 |
| 5 | `DAMAGE_INCOMING_RATIO_REDUCTION` | bp | SATURATE | 0 ~ 10,000 |
| 6 | `DAMAGE_FIXED_INCREASE` | 정수 | SATURATE | 0 ~ 1,000,000 |
| 7 | `DAMAGE_FIXED_REDUCTION` | 정수 | SATURATE | 0 ~ 1,000,000 |
| 8 | `MASS_RAW` | Q47.16 | **STRICT** | `SimLimits` 질량 범위 |
| 9 | `RADIUS_RAW` | Q47.16 | **STRICT** | `SimLimits` 반지름 범위 |
| 10 | `FRICTION_MULTIPLIER_RAW` | Q47.16 | **STRICT** | 0 이상 |

kind 4~7은 base가 없다. base 0에서 시작하는 순수 파생값이며 `RATIO` 연산을 허용하지 않는다.

| enum | 값 |
|---|---|
| ModifierOperation | 1 `ADD`, 2 `RATIO_BASIS_POINTS` |
| ValueMode | 1 `FLAT`, 2 `SCALED` (상태는 stack 수, 시너지는 유효 계수에 비례) |
| StackPolicy | 1 `SINGLE`, 2 `STACKED`, 3 `INDEPENDENT` |
| DurationKind | 1 `TARGET_TURNS`, 2 `BATTLE`, 3 `CHARGES` |
| RefreshPolicy | 1 `MAX`, 2 `REPLACE`, 3 `EXTEND`, 4 `KEEP` |
| TagKind | 1 `ROLE`, 2 `THEME` |
| SynergyScope | 1 `OWN_FACTION`, 2 `BOTH_FACTIONS` |
| EffectKind 추가 | 7 `MODIFY_STAT`(활성화), 10 `APPLY_STATUS`, 11 `REMOVE_STATUS` |

### 공학 한도

| 항목 | 한도 |
|---|---:|
| body당 상태 인스턴스 | 64 |
| 전투 전체 상태 인스턴스 | 4,096 |
| 상태당 `max_stacks` | 99 |
| `TARGET_TURNS` 지속 | 1 ~ 1,024 |
| `CHARGES` 지속 | 1 ~ 99 |
| 상태 정의당 modifier | 8 |
| 시너지 정의당 tier | 16 |
| tier당 modifier | 8 |
| 기물당 `tag_refs` | 8 |
| 태그 계수 상한 | 64 |
| transition당 상태 변경 | 1,024 |
| 상태·시너지 정의 수 | 기존 record 4,096 유지 |

한도 초과는 전체 load 또는 transition 실패다. truncate·일부 skip·자동 분할하지 않는다. 계수 상한 64는 공학 한도이며 정본 7.1.2의 밸런스 상한(`count_cap`)과 별개다.

## 상태 수명

### 인스턴스 필드

| 필드 | 형 | 비고 |
|---|---|---|
| `status_numeric_id` | u32 | |
| `target_body_id` | u32 | |
| `source_body_id` | u32 | 최초 부여자. 갱신이 바꾸지 않는다 |
| `stacks` | u16 | 1 ~ `max_stacks` |
| `remaining` | u32 | 남은 턴 또는 charge. `BATTLE`은 0 고정 |
| `applied_turn_index` | u32 | 부여 시점의 전역 턴 번호 |
| `application_sequence` | u32 | append-only 부여 순번 |

정렬 키는 `(target_body_id, status_numeric_id, source_body_id, application_sequence)`다. `merge_sources = true`인 상태는 `source_body_id`가 최초값으로 고정되므로 키가 안정적이다.

### 중첩과 갱신

같은 병합 키로 재부여할 때의 동작:

| `stack_policy_id` | stacks | remaining |
|---|---|---|
| `SINGLE` | 항상 1 | `refresh_policy_id` 적용 |
| `STACKED` | `min(기존 + 부여량, max_stacks)` | `refresh_policy_id` 적용 |
| `INDEPENDENT` | 병합하지 않고 새 인스턴스 | 새 인스턴스는 `default_duration` |

`refresh_policy_id`:

| 값 | 새 `remaining` |
|---|---|
| `MAX` | `max(기존 남은, default_duration)` |
| `REPLACE` | `default_duration` |
| `EXTEND` | `min(기존 남은 + default_duration, max_duration)` |
| `KEEP` | 기존 유지 |

- `max_stacks` 상한 초과분은 **버린다.** 실패가 아니며 진단도 남기지 않는다.
- `INDEPENDENT`는 body당 64 또는 전체 4,096 한도에 걸리면 transition 전체 실패다.
- 갱신은 `applied_turn_index`를 **갱신 시점 값으로 다시 쓴다.** 그래야 갱신된 턴에 곧바로 닳지 않는다.
- 갱신은 `application_sequence`를 바꾸지 않는다. 정렬 안정성이 우선이다.

### 지속과 해제

| 지속 축 | 감소 시점 |
|---|---|
| `TARGET_TURNS` | 대상 자신의 `TURN_END` 완료 barrier. `applied_turn_index < turn_index`인 인스턴스만 1 감소 |
| `BATTLE` | 감소하지 않는다 |
| `CHARGES` | 시간으로 감소하지 않는다. `REMOVE_STATUS`만 소비한다 |

해제 경로는 4종뿐이다.

1. `remaining`이 0에 도달 — 감소가 일어난 그 barrier 안에서 제거한다.
2. `REMOVE_STATUS` 원자.
3. 대상 body 제거 — 그 body의 전 인스턴스를 제거한다.
4. `BATTLE_END` 진입 — 전 인스턴스를 제거한다.

- **출처 body의 사망·제거는 해제 사유가 아니다.** 정본에 출처 연동 해제 규칙이 없다.
- 제거는 modifier 기여를 즉시 잃게 하며, 다음 소비 지점부터 반영된다.
- 대상이 이미 없는 상태를 제거하려는 시도는 **성공한 무효과**다.

## 시너지 집계

### 계수 산정

`SynergyTallyBuilder`는 `BATTLE_START` 완료 barrier에서 진영별 계수를 산정하고 동결한다.

```text
for identity in 배치 identity (body_id 오름차순):
    if identity.is_token: continue
    for tag_ref in piece_definition(identity).tag_refs (numeric_id 오름차순):
        기여 = 1                     if tag_kind_id == ROLE
        기여 = identity.level        if tag_kind_id == THEME
        tally[(tag, identity.faction)] += 기여
```

- 중복 기물은 각각 센다. 토큰은 계수에 포함하지 않는다.
- 계수 2 미만인 `(태그, 진영)` 항목은 tally에서 제외한다.
- tally는 `(tag_numeric_id, faction_id)` 오름차순 불변 배열이다.
- 계수는 전투 중 **재산정하지 않는다.** 파괴·변신·토큰 생성이 계수를 바꾸지 않는다.
- identity가 없는 body는 태그 0개로 취급한다. 런타임 생성 body의 identity 등록은 P2-4 소관이다.

### 효과 적용

한 body에 대한 시너지 기여는 다음으로 결정한다.

```text
for (tag, faction, count) in tally:
    if scope_id == OWN_FACTION and body.faction != faction: continue
    if tag not in body.tag_refs: continue
    유효계수 = min(count, count_cap)
    for tier in tiers where tier.min_count <= 유효계수:
        for modifier in tier.modifiers:
            기여 = modifier.value                    if FLAT
            기여 = modifier.value × 유효계수          if SCALED
```

- `BOTH_FACTIONS`는 진영 필터를 건너뛴다. 양쪽 진영이 같은 태그의 tally를 가지면 **둘 다 독립 적용해 합산한다**(P2-S10).
- 토큰은 tally에 없지만 태그를 가지면 효과를 받는다. 정본 7.7.1과 정합한다.
- `min_count` 이하인 tier는 전부 활성이며 기여는 누적한다.

## modifier 집계와 유효값

### 순회 순서

정수 덧셈은 교환법칙이 성립하므로 순서가 결과를 바꾸지 않는다. 그러나 **overflow first-error 보고**가 순서에 의존하므로 아래를 고정한다.

```text
출처 종류: SYNERGY(1) → STATUS(2)
  SYNERGY: (tag_numeric_id, faction_id, tier index, modifier index)
  STATUS:  (status_numeric_id, source_body_id, application_sequence, modifier index)
```

### 유효값 계산

kind마다 두 누적기를 따로 모은 뒤 한 번만 결합한다.

```text
1) sum_add   = Σ (operation == ADD 인 기여)
2) sum_ratio = Σ (operation == RATIO_BASIS_POINTS 인 기여)      # bp 가산 합
3) value     = base + sum_add                                   # checked int64
4) value     = round_div_int(value × (10000 + sum_ratio), 10000) # 반올림은 여기 1회뿐
5) value     = 정책 적용 (SATURATE 또는 STRICT)
```

- **가산이 먼저, 비율이 나중이다.** 순서를 바꾸면 같은 데이터가 다른 결과를 낸다.
- 반올림은 4단계의 `FixMath.round_div_int` **한 번뿐**이다. 규칙은 기존 half-away-from-zero다.
- `SCALED` 곱셈(`value × stacks`, `value × 유효계수`)은 `FixMath.multiply_int`로 checked 계산한다.
- kind 4~7은 `base = 0`이고 `sum_ratio`가 항상 0이다.
- `SATURATE`는 유효 범위로 포화하며 실패하지 않는다. `STRICT`는 범위를 벗어나면 실패한다.
- int64 overflow는 정책과 무관하게 언제나 실패다.

### P1 피해 연결

`DamageContext` 생성 시 아래를 채운다. **P1의 연산 순서는 바꾸지 않는다.**

| `DamageContext` 입력 | 소유자 | 값 |
|---|---|---|
| `attacker_attack` | 가해자 | 유효 `ATTACK` |
| `critical_applied` | 가해자 | 유효 `CRITICAL_BASIS_POINTS` 판정 결과 |
| `outgoing_ratio_bonus_raw` | 가해자 | `FixMath.from_ratio(Σ kind4 bp, 10000)` |
| `incoming_ratio_reduction_raw` | 피해자 | `FixMath.from_ratio(Σ kind5 bp, 10000)` |
| `fixed_increase` | 가해자 | 유효 `DAMAGE_FIXED_INCREASE` |
| `fixed_reduction` | 피해자 | 유효 `DAMAGE_FIXED_REDUCTION` |
| `attacker_mass_raw` / `victim_mass_raw` | 각자 | materialize된 world body 질량 |

- bp → Q47.16 변환은 **합산 뒤 한 번만** 한다. 기여별로 변환하면 합이 달라진다.
- 크리티컬 배율 2배와 적용 위치는 P1 승인값을 유지한다. `무법자`의 추가 50%는 S-9 승인 전 적용하지 않는다.

### 재평가 시점

| 소비 지점 | kind | 시점 |
|---|---|---|
| CTB 행동자 선택·예보 | `SPEED_STAT` | 스케줄러 입력 participant 사본을 만들 때 순수 계산 |
| 충돌 피해 해결 | 1·3·4·5·6·7 | `DamageContext` 생성 시 순수 계산 |
| 물리 tick | 8·9·10 | `AIM → RESOLVE` 전이 barrier에서 world body에 1회 materialize |

- 권위 participant·combatant는 언제나 base를 보관한다. 스케줄러에 넘기는 사본만 유효 speed를 갖는다.
- 물리 3종은 `RESOLVE` 동안 불변이다. `RESOLVE` 중 발생한 상태 변경은 **그 `RESOLVE`에는 반영되지 않고 다음 `RESOLVE`부터** 반영된다.
- base 물리 스탯은 `BattleState`가 body별로 따로 보관하며 materialize가 덮어쓰지 않는다.
- 빈 카탈로그·상태 0개·tally 0개이면 materialize는 base와 동일한 값을 쓴다. P0·P1 골든은 변하지 않는다.

### 계산 예시

가해자 body 3(base attack 100, base speed 100), 피해자 body 7.

| 출처 | kind | operation | mode | value | 기여 |
|---|---|---|---|---:|---:|
| 상태 A (stacks 3) | `ATTACK` | ADD | FLAT | 10 | +10 |
| 상태 B (stacks 3) | `ATTACK` | ADD | SCALED | 5 | +15 |
| 상태 C (감전) | `SPEED_STAT` | RATIO | FLAT | −2000 | −20% |
| 시너지 `파괴` 계수 4 | kind 4 | ADD | SCALED | 1000 | +4000 bp |
| 시너지 `제어` 계수 3 (피해자) | kind 5 | ADD | SCALED | 1000 | +3000 bp |

```text
attack   = round_div_int((100 + 25) × 10000, 10000) = 125
speed    = round_div_int((100 + 0)  ×  8000, 10000) =  80
outgoing = from_ratio(4000, 10000) = 26214      # 4000×65536/10000 = 26214.4 → 26214
incoming = from_ratio(3000, 10000) = 19661      # 3000×65536/10000 = 19660.8 → 19661
```

P1은 이 값을 받아 기존 순서(비율 → 크리티컬 → 아군 → 고정 → 반올림 → `max(1)`)로 계산한다.

## 효과 원자 의미

### APPLY_STATUS (10)

- `value_a`: 상태 numeric ID. active 정의여야 한다.
- `value_b`: 부여 stack 수. 1 이상 `max_stacks` 이하.
- `operation_id`: 0 고정.
- 지속은 언제나 정의의 `default_duration`을 쓴다. **effect가 지속을 override하지 않는다.**
- `source_body_id`는 언제나 invocation owner다. 시스템 출처 상태는 P2-3에 없다.
- 대상이 이미 사망했으면 `INVALID_EFFECT_TARGET`으로 실패한다. P2-2 `HEAL`과 같은 규칙이다.
- owner와 대상이 같아도 허용한다. 진영 제한은 condition·selector 책임이다.
- RNG를 소비하지 않고 새 trigger record를 만들지 않는다.

### REMOVE_STATUS (11)

- `value_a`: 상태 numeric ID. **0은 금지**한다. 전체 해제 원자는 두지 않는다.
- `value_b`: 제거 stack 수. 0이면 인스턴스 전체 제거, 1 이상이면 그만큼 감소하고 0 이하가 되면 제거한다.
- `operation_id`: 0 고정.
- 대상에게 해당 상태가 없으면 **성공한 무효과**다. 조건 어휘 없이 조건부 해제를 저작할 수 있어야 한다.
- 인스턴스가 여럿이면 정렬 키 오름차순으로 앞에서부터 `value_b`를 소진한다.
- `CHARGES` 상태의 소비도 이 원자로만 한다.

### MODIFY_STAT (7)

- `value_a`: ModifierKind. `ATTACK`·`SPEED_STAT`·`CRITICAL_BASIS_POINTS` 3종만 허용한다.
- `value_b`: 더할 정수. 0은 금지한다.
- `operation_id`: 1(`ADD`) 고정. `RATIO`는 허용하지 않는다.
- **base 값을 직접 바꾸며 되돌릴 수 없다.** 상태와 역할이 겹치지 않는다.
- 결과가 base 저작 범위를 벗어나면 실패한다. `ATTACK` 1~1,000,000, `SPEED_STAT` 50~200, 크리티컬 0~10,000.
- 물리 3종과 피해 modifier 4종은 대상이 아니다. 각각 P0 회귀 범위와 순수 파생값이기 때문이다.

## 상태 모델과 공개 API

신규 immutable/typed 객체:

```text
StatusModifierDefinition
StatusDefinition
SynergyTierDefinition
SynergyDefinition
ModifierKind
ModifierContribution
ModifierAggregate
ModifierResolver
StatusInstance
StatusCollection
SynergyTally
BattlePieceIdentity
BattleBaseBodyStats
```

공개 경계:

```text
ModifierResolver.build(catalog, status) -> ModifierResolver

SynergyTallyBuilder.build(
    catalog, identities: Array[BattlePieceIdentity], status
) -> SynergyTally

ModifierResolver.aggregate(
    state, body_id, kind_id, status
) -> ModifierAggregate

EffectiveStats.resolve(
    base_value, aggregate, kind_id, status
) -> int

BattleState.attach_content(
    catalog, identities, bindings, status
) -> bool
```

- `attach_content`는 `BATTLE_START` phase에서만 호출할 수 있고 1회만 성공한다.
- `BattleState`는 불변 `ModifierResolver`, identity 배열, 동결 tally, 상태 컬렉션, base 물리 스탯을 보관한다.
- 상태 컬렉션은 정렬된 불변 사본만 노출한다. 내부 배열이나 Dictionary를 반환하지 않는다.
- `EffectResolutionReport`에 상태 변경 요약(적용·갱신·제거 수)을 append-only로 추가한다.

## snapshot과 호환성

- `BattleSnapshot.SCHEMA_VERSION`을 5로 올린다.
- 추가 섹션: `turn_index`(u32), `next_status_sequence`(u32), 상태 인스턴스, 동결 tally, piece identity, base 물리 스탯.
- 상태 인스턴스는 정렬 키 오름차순으로 인코딩한다.
- tally는 `(tag_numeric_id, faction_id)` 오름차순, identity는 `body_id` 오름차순으로 인코딩한다.
- restore는 현재 카탈로그 지문이 일치할 때만 성공하며 `ModifierResolver`를 카탈로그에서 재구성한다.
- v1~4 snapshot은 빈 카탈로그·상태 0개·tally 0개·identity 0개를 명시적으로 제공한 경우에만 복원한다.
- schema v5 decode 뒤 re-encode는 동일 bytes여야 한다.

## 오류 계약

신규 `SimStatus` code(append-only, 42부터):

- `INVALID_STATUS_DEFINITION`
- `INVALID_STATUS_INSTANCE`
- `STATUS_LIMIT_EXCEEDED`
- `INVALID_MODIFIER_DEFINITION`
- `MODIFIER_RANGE_VIOLATION`
- `INVALID_SYNERGY_TALLY`
- `INVALID_PIECE_IDENTITY`

신규 operation(append-only, 115부터):

- `STATUS_APPLY`
- `STATUS_REMOVE`
- `STATUS_EXPIRE`
- `SYNERGY_TALLY_BUILD`
- `MODIFIER_AGGREGATE`
- `EFFECTIVE_STAT_RESOLVE`
- `BATTLE_PHYSICAL_STATS_APPLY`
- `BATTLE_PIECE_IDENTITY_READ`

`ContentStatus`에는 statuses/synergies/pieces v2 field ID를 append-only로 추가한다. first-error-wins이며 `detail_a`는 body 또는 태그 ID, `detail_b`는 상태 ID 또는 kind ID로 operation별 고정 쌍을 쓴다. OS 문자열·JSON 문자열 ID·절대 경로는 결정론 오류에 넣지 않는다.

## 대상 파일

신규:

```text
src/core/data/status_modifier_definition.gd
src/core/data/status_definition.gd
src/core/data/synergy_tier_definition.gd
src/core/data/synergy_definition.gd
src/core/data/statuses.json
src/core/data/synergies.json
src/core/battle/modifier_kind.gd
src/core/battle/modifier_contribution.gd
src/core/battle/modifier_aggregate.gd
src/core/battle/modifier_resolver.gd
src/core/battle/effective_stats.gd
src/core/battle/status_instance.gd
src/core/battle/status_collection.gd
src/core/battle/synergy_tally.gd
src/core/battle/synergy_tally_builder.gd
src/core/battle/battle_piece_identity.gd
src/core/battle/battle_base_body_stats.gd
pipeline/schemas/p2-statuses-v1.schema.json
pipeline/schemas/p2-synergies-v1.schema.json
pipeline/schemas/p2-pieces-v2.schema.json
pipeline/schemas/p2-abilities-v3.schema.json
pipeline/schemas/p2-catalog-v3.schema.json
pipeline/tests/p2_status_synergy_modifiers_test.gd
pipeline/tests/p2_status_synergy_reference.py
pipeline/tests/run_p2_status_synergy_modifiers.py
pipeline/tests/fixtures/p2_status_synergy/**
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
src/core/battle/effect_resolver.gd
src/core/battle/effect_resolution_report.gd
src/core/sim/sim_status.gd
src/core/sim/sim_body.gd
src/core/sim/sim_world.gd
pipeline/tests/fixtures/p2_content_catalog/**
pipeline/tests/fixtures/p2_effect_resolution/**
docs/specs/p2_index.md
AGENTS.md
HANDOFF.md
```

`src/core/sim/sim_body.gd`·`sim_world.gd` 수정은 **P2-S13 승인 시에만** 한다. 반려되면 물리 3종은 loader 거부로 예약만 하고 두 파일은 건드리지 않는다. 씬·UI·에셋·매니페스트는 수정하지 않는다.

## 필요 에셋

없음. runtime records는 비어 있고 모든 상태·시너지 정의는 headless test fixture에만 존재한다. 매니페스트 등록 대상이 없다.

## 수용 기준

1. statuses/synergies/pieces v2/abilities v3/catalog v3 schema가 exact key·type·version·enum·range·배열 한도를 검증한다.
2. `min_count` 2 미만, tier `min_count` 중복, 한 태그 시너지 2개, unknown key가 각각 load 실패한다.
3. 피해 modifier 4종에 `RATIO` 연산을 저작하면 load 실패한다.
4. `SINGLE`·`STACKED`·`INDEPENDENT` 각각의 재부여 결과 stacks와 인스턴스 수가 표대로 나온다.
5. `max_stacks` 초과 부여가 상한으로 고정되고 **실패하지 않는다.**
6. `MAX`·`REPLACE`·`EXTEND`·`KEEP` 네 갱신 정책의 `remaining`이 표대로 나온다.
7. `merge_sources = true`에서 출처가 다른 재부여가 한 인스턴스로 병합되고 `source_body_id`가 최초값으로 유지된다.
8. `merge_sources = false`에서 출처가 다른 부여가 인스턴스를 분리하고 정렬 키 순서가 안정적이다.
9. 부여된 턴의 `TURN_END`에서 `remaining`이 감소하지 않고, 다음 대상 턴의 `TURN_END`에서 1 감소한다.
10. 갱신은 `applied_turn_index`를 갱신하고 `application_sequence`는 바꾸지 않는다.
11. `BATTLE`은 감소하지 않고 `CHARGES`는 `REMOVE_STATUS`로만 줄어든다.
12. 만료·`REMOVE_STATUS`·대상 제거·`BATTLE_END` 4경로가 인스턴스를 제거하고, **출처 사망은 제거하지 않는다.**
13. 없는 상태의 `REMOVE_STATUS`가 성공한 무효과이며 상태·RNG·한도를 소비하지 않는다.
14. 시너지 계수가 비토큰·중복 각각 +1·역할군 1·테마 level·최소 2·진영별 규칙대로 산정된다.
15. 계수가 `BATTLE_START`에서 동결되고 이후 파괴·토큰 생성이 계수를 바꾸지 않는다.
16. 토큰이 계수에는 없지만 태그 시너지 효과는 받는다.
17. `BOTH_FACTIONS` 시너지가 양 진영 body에 적용되고 진영별 계수가 독립 합산된다.
18. `min_count` 이하 tier가 전부 누적되고 `count_cap`이 유효 계수를 제한한다.
19. 유효값이 `(base + Σ ADD) × (10000 + Σ RATIO) / 10000` 순서로 계산되고 반올림이 정확히 1회 일어난다.
20. bp 합을 먼저 합산한 뒤 한 번 변환한 결과가 기여별 변환 합과 다른 경우를 KAT로 고정한다.
21. `SATURATE` kind가 범위 밖에서 포화하고, `STRICT` kind가 범위 밖에서 실패하며 상태를 바꾸지 않는다.
22. 유효 speed가 CTB 선택·예보에 반영되지만 권위 participant의 base는 변하지 않는다.
23. 물리 3종이 `RESOLVE` 진입 barrier에서만 materialize되고 `RESOLVE` 중 상태 변경이 그 `RESOLVE`에 영향을 주지 않는다.
24. `APPLY_STATUS`·`REMOVE_STATUS`·`MODIFY_STAT`의 invalid 대상·범위·overflow에서 원본 상태와 RNG가 불변이다.
25. `MODIFY_STAT`이 base를 바꾸고 저작 범위를 벗어나면 실패하며, 물리·피해 kind는 loader가 거부한다.
26. 상태·modifier 원자가 RNG draw 0회이고 새 trigger record를 만들지 않는다.
27. body당 64·전체 4,096·transition당 1,024 상태 변경의 경계값과 초과값이 각각 성공·실패한다.
28. 상태 변경 도중 실패하면 상태·tally·identity·base stats·`turn_index`·RNG가 byte-for-byte 복원된다.
29. `BattleSnapshot` v5가 신규 섹션을 encode/decode/restore하고 재인코딩 bytes가 같다.
30. 지문이 다른 카탈로그로 v5를 복원하면 전투 상태를 바꾸지 않고 명시적 mismatch로 실패한다.
31. 빈 카탈로그·상태 0개에서 기존 P0·P1·P2 snapshot bytes·terminal 결과·golden이 승인된 migration 외에 변하지 않는다.
32. 독립 Python reference가 수명·계수·집계·반올림·snapshot 섹션의 known-answer를 계산한다.
33. 같은 fixture 1,000회와 중간 snapshot restore가 같은 final bytes/hash를 만든다.
34. JSON 배열 순서·body 삽입 순서를 교란해도 상태 정렬·계수·집계 결과가 같다.
35. `run_p2_status_synergy_modifiers.py`가 `verify --full`에 자동 발견된다.
36. P2-2·P2-1 narrow, P1-1~5, P0 narrow·결정론 회귀가 통과한다.
37. Godot 4.6.3 활성 `PYTHONUTF8=1 python pipeline/scripts/verify.py --full`이 통과한다.

## 구현 순서 — 전체 승인 뒤 적용

1. statuses/synergies schema와 독립 Python reference·negative fixture를 먼저 고정한다.
2. typed 상태·시너지 정의와 catalog canonical v3, 지문 format v3를 구현한다.
3. `ModifierKind`·`ModifierAggregate`·`EffectiveStats`의 순수 계산과 반올림 KAT를 통과시킨다.
4. `SynergyTallyBuilder`와 동결 tally, `BattlePieceIdentity`를 구현한다.
5. 상태 인스턴스 수명(중첩·갱신·지속·해제)과 `turn_index` barrier를 구현한다.
6. 3개 원자를 작은 checked 함수로 구현하고 transition rollback에 편입한다.
7. `DamageContext` 4입력과 CTB 유효 speed 연결을 구현한다.
8. (P2-S13 승인 시) 물리 스탯 materialize barrier와 `SimBody`/`SimWorld` 추가 API를 구현하고 P0 회귀를 재실행한다.
9. `BattleSnapshot` v5 섹션을 구현하고 재인코딩 일치를 확인한다.
10. 수명·집계·한도·rollback·snapshot 수용 테스트를 통과시킨다.
11. P2-2, P2-1, P1, P0 회귀 뒤 Godot 활성 `verify --full`을 실행한다.
12. 구현·검증 결과를 P2 인덱스·AGENTS·HANDOFF에 기록한다.

## 승인된 선택 항목

2026-08-24 전체 명세 승인으로 아래 권고안을 채택했다.

| 항목 | 선택지 | 권고 |
|---|---|---|
| P2-S10 `체스` 양 진영 적용 방식 | ① 진영별 독립 적용 후 합산 ② 진영별 계수 중 최댓값 1개만 적용 | ① — 「선형 누적」과 「상대도 그대로 가져간다」에 더 가깝다. 국면 효과가 비범위라 지금은 production 영향이 없다 |
| P2-S13 물리 스탯 modifier 활성화 | ① 이번에 활성화(`src/core/sim/` 2파일 추가 API + P0 회귀) ② 예약만 하고 후속 명세로 이월 | ① — `강철` 시너지가 무게를 요구하고, 미루면 P2-6에서 같은 논의를 다시 연다 |
| `MODIFY_STAT`의 `SPEED_STAT` 범위 | ① 저작 범위 50~200 강제 ② 런타임 전용 범위 별도 승인 | ① — 정본 D-21의 「속도는 쉽게 바뀌지 않는다」와 정합. 완화가 필요해지면 그때 근거와 함께 올린다 |

아래는 P2-3이 **확정하지 않고 미결로 유지**하는 정본 항목이다. 구현을 막지 않으며 fixture로 우회한다.

U-11b 태그 배정 · U-20 무적 면역 · U-21 고정 체력 계수 · U-36 기물 스탯 · U-37 상태이상 수치 · U-40 태그 가중치 합산 · S-6 `지원` 누적 여부 · S-7 `원소` 효과 수치 · S-8 `용` 강화 수치 · S-9 `무법자` 크리티컬 · S-10 진영 적용 범위 · S-11 킹 불멸 · S-12 퀸 참조 범위

## 승인 기록

P2-S01~20은 2026-08-24 사용자 지시 `승인 상태로 전환해`로 한 묶음 승인되었다. 구현은 이 명세의 fixture-only 범위와 명시된 비범위를 넘지 않는다.

> [review 승인 2026-08-24] 사람 검수 승인.

## 구현·검증 기록

- catalog v3, pieces v2, abilities v3, statuses/synergies v1과 canonical fingerprint v3를 구현했다. runtime status/synergy records는 승인대로 비어 있다.
- 상태 수명·정렬·중첩·갱신·해제, 진영별 동결 tally, 누적 tier/count cap, 단일 modifier 집계 경계를 구현했다.
- `APPLY_STATUS`·`REMOVE_STATUS`·`MODIFY_STAT`, CTB 유효 speed, P1 피해 입력과 결정적 치명타, `AIM→RESOLVE` 물리 materialize를 연결했다.
- BattleSnapshot v5, content fingerprint mismatch, body 64·전투 4,096·transition 1,024 한도와 byte-for-byte rollback을 검증했다.
- 독립 Python canonical reference와 Godot narrow가 일치하며, 동일 fixture 1,000회, P0/P1/P2 회귀, Godot 4.6.3 `verify --full` 자동 발견 러너 20종이 통과했다.
- P1-5 terminal hash는 P2-S18 Snapshot v5 승인 마이그레이션으로 `b7ebf05c0ad30200f95582b6f9774b1e11341471f9aeef293fb1f0c87d5569a2`로 갱신했다. 전투 결과 1, 20턴, 10,699 sim tick은 변하지 않았다.
