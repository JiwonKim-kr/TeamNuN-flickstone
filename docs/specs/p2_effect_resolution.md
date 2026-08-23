# P2-2 · 효과 실행 / 조건 / 대상 선택 명세

| 항목 | 값 |
|---|---|
| status | **draft** |
| drafted | 2026-08-23 |
| phase | P2-2 · 효과 실행 |
| 선행 단계 | P2-1 콘텐츠 카탈로그 승인·구현·검증 완료 |
| 후속 단계 | P2-3 상태이상·시너지·modifier |
| 구현 권한 | **없음 — P2-E01~12 전체 사람 승인 뒤 `approved` 전환 필요** |

## 목적

P1의 불변 `BattleTriggerRecord`와 P2-1의 typed catalog 사이에 결정론적 능력 실행 경계를 만든다. 같은 catalog fingerprint, 전투 상태, trigger record에서 같은 invocation·대상·효과·새 trigger wave와 같은 `BattleSnapshot`을 만들어야 한다.

P2-2는 실제 제품 기물이나 밸런스 수치를 만들지 않는다. 테스트 fixture의 능력만으로 조건·selector·기초 효과 실행·전체 transition rollback을 검증한다.

## 정본 참조

- `docs/design/game_design.md` 7.2 트리거, 7.3 효과 원자, 14.1 결정론, 14.4 리플레이
- `docs/specs/p2_index.md` 능력 실행 순서, 결정론·RNG·원자성, P2-2 경계
- `docs/specs/p2_content_catalog.md` strict JSON, append-only ID, immutable catalog, fingerprint
- `docs/specs/p1_trigger_bus_battle_result.md` wave·record 한도와 trigger record 의미
- `docs/specs/p1_damage_resolution.md` HP·파괴·처치 귀속 경계

## 포함 범위

- ability document schema v2의 condition·selector·effect typed 표현
- 기존 P1 trigger 13종에 대한 능력 binding과 invocation 정렬
- 순수 condition 평가와 안정 ID 기반 body selector
- `DAMAGE`, `HEAL`, `KNOCKBACK`, `PULL`, `MODIFY_CT`, `MODIFY_VELOCITY` 6개 원자
- effect가 만든 사실을 다음 trigger wave로 전달하는 경계
- transition 전체의 실패 원자성과 RNG rollback
- content fingerprint와 능력 binding을 포함하는 `BattleSnapshot` schema v4
- 독립 Python 기준값, Godot narrow, P0·P1 회귀, `verify --full`

## 비범위

- 실제 runtime piece/ability records와 제품 밸런스 수치
- 신규 trigger `ON_ZONE_ENTER`, `ON_STOP`, `ON_ALLY_DEATH`
- `MODIFY_STAT`, `TELEPORT`, `SET_FLAG`
- 상태 원자 `APPLY_STATUS`, `REMOVE_STATUS`
- spawn·transform·attach·projectile·zone·obstacle
- extra launch, aim constraint, mid-flight input, copy, invulnerability
- 시너지·상태 지속시간·modifier 재평가
- VFX, UI, 실제 아트, 효과음

`MODIFY_STAT`은 P2-3의 유효 modifier 정본과 barrier가 필요하다. `TELEPORT`는 겹침·벽·존·소멸·연속충돌 의미가 필요하고, `SET_FLAG`는 CTB·승패·token 불변식을 바꾼다. 세 원자는 이름만 예약하고 P2-2 loader에서는 지원하지 않는 effect로 실패한다.

## 용어

| 용어 | 의미 |
|---|---|
| owner | ability를 소유한 살아 있는 body ID |
| invocation | 한 trigger record와 한 owner ability의 실행 단위 |
| subject/other/instigator | P1 trigger record의 관계 ID |
| condition | 상태를 바꾸지 않고 invocation 실행 여부만 판정하는 typed 규칙 |
| selector | 상태를 바꾸지 않고 정렬된 body ID 사본을 만드는 typed 규칙 |
| effect | 대상 하나에 적용되는 최소 상태 변경 |
| transition | 공개 phase API 한 번 안에서 trigger drain·능력·새 wave·barrier까지의 전체 작업 |

## 승인 결정안

| ID | 결정안 | 이유 | 상태 |
|---|---|---|---|
| P2-E01 | 신규 trigger 없이 P1 확정 13종만 binding | 후보 trigger의 payload·발생 시점을 추측하지 않음 | ⬜ 승인 필요 |
| P2-E02 | ability schema v2는 ordered `conditions`와 `effects`; effect가 selector를 소유 | effect index 저작 순서를 정규 실행 순서로 보존 | ⬜ 승인 필요 |
| P2-E03 | 조건은 `ALWAYS`, 관계 ID 존재·생존, 진영 관계, HP basis-points 비교만 활성화 | 상태·거리 DSL을 선점하지 않는 최소 유용 집합 | ⬜ 승인 필요 |
| P2-E04 | selector는 관계 ID 4종, 전체 아군/적, 가장 가까운 아군/적만 활성화 | 안정 ID 정렬과 거리 동률을 완전히 정의 가능 | ⬜ 승인 필요 |
| P2-E05 | 첫 원자는 DAMAGE/HEAL/KNOCKBACK/PULL/MODIFY_CT/MODIFY_VELOCITY 6종 | P1 공개 상태로 표현 가능 | ⬜ 승인 필요 |
| P2-E06 | MODIFY_STAT/TELEPORT/SET_FLAG는 후속 명세까지 loader 거부 | P2-3·4 계약 선점 방지 | ⬜ 승인 필요 |
| P2-E07 | 원자 수치는 정수/Q47.16 raw, overflow·범위 밖은 clamp 없이 실패 | 기존 결정론·오류 계약 유지 | ⬜ 승인 필요 |
| P2-E08 | owner→ability ID→condition index→target ID→effect index; 새 사실은 다음 wave | P2 인덱스 정본 순서 구체화 | ⬜ 승인 필요 |
| P2-E09 | invocation 2,048, effect application 8,192, selector result 256 한도 | P1 32 wave/4,096 record와 별도 폭발 방지 | ⬜ 승인 필요 |
| P2-E10 | 공개 transition 전체 copy-on-write 후 단일 commit, 실패 시 RNG 포함 완전 rollback | 부분 적용과 재진입 방지 | ⬜ 승인 필요 |
| P2-E11 | BattleSnapshot v4에 fingerprint·binding·effect sequence를 포함하고 v1~3은 빈 catalog에서만 복원 | 콘텐츠 호환성과 기존 snapshot 진단 보존 | ⬜ 승인 필요 |
| P2-E12 | runtime JSON records는 계속 0개, non-empty 능력은 test fixture에만 둠 | 실제 콘텐츠·밸런스 발명 방지 | ⬜ 승인 필요 |

## 데이터 계약

### ability document schema v2

```json
{
  "schema_version": 2,
  "records": [
    {
      "numeric_id": 1,
      "id": "test:ability/on_hit_damage",
      "trigger_id": 5,
      "conditions": [
        {"kind_id": 1, "relation_id": 0, "value_a": 0, "value_b": 0}
      ],
      "effects": [
        {
          "kind_id": 1,
          "selector": {"kind_id": 3, "relation_id": 2, "limit": 1},
          "value_a": 10,
          "value_b": 0,
          "operation_id": 0
        }
      ]
    }
  ]
}
```

- exact key set을 사용한다. unknown/missing key는 catalog 전체 실패다.
- condition/effect/selector 배열의 저작 순서는 보존한다.
- record와 ability ref는 기존처럼 numeric ID 오름차순으로 정규화한다.
- schema v1 ability를 v2 catalog에서 묵시적으로 빈 effect로 변환하지 않는다.
- catalog schema는 요구 ability document version 변경 때문에 v2로 올린다.
- fingerprint format은 typed record가 확장되므로 v2로 올린다.

### enum ID

모든 ID는 append-only다. `0`은 INVALID 또는 미사용이다.

ConditionKind:

| 값 | 이름 | 의미 |
|---:|---|---|
| 1 | `ALWAYS` | 항상 참 |
| 2 | `RELATION_EXISTS` | 지정 관계 ID가 0이 아니고 전투에 존재 |
| 3 | `RELATION_ALIVE` | 지정 관계 body가 현재 살아 있음 |
| 4 | `RELATION_IS_ALLY` | owner와 같은 비중립 faction |
| 5 | `RELATION_IS_ENEMY` | owner와 다른 비중립 faction |
| 6 | `HP_AT_MOST_BASIS_POINTS` | 현재 HP/max HP가 value_a 이하 |
| 7 | `HP_AT_LEAST_BASIS_POINTS` | 현재 HP/max HP가 value_a 이상 |

RelationId:

| 값 | 이름 |
|---:|---|
| 1 | `OWNER` |
| 2 | `SUBJECT` |
| 3 | `OTHER` |
| 4 | `INSTIGATOR` |

SelectorKind:

| 값 | 이름 | 결과 |
|---:|---|---|
| 1 | `OWNER` | owner 0~1개 |
| 2 | `SUBJECT` | subject 0~1개 |
| 3 | `OTHER` | other 0~1개 |
| 4 | `INSTIGATOR` | instigator 0~1개 |
| 5 | `ALL_ALLIES` | owner와 같은 비중립 faction의 살아 있는 body |
| 6 | `ALL_ENEMIES` | owner와 다른 비중립 faction의 살아 있는 body |
| 7 | `NEAREST_ALLY` | owner 제외 가장 가까운 아군 0~1개 |
| 8 | `NEAREST_ENEMY` | 가장 가까운 적 0~1개 |

EffectKind:

| 값 | 이름 |
|---:|---|
| 1 | `DAMAGE` |
| 2 | `HEAL` |
| 3 | `KNOCKBACK` |
| 4 | `PULL` |
| 5 | `MODIFY_CT` |
| 6 | `MODIFY_VELOCITY` |
| 7 | `MODIFY_STAT` (예약·거부) |
| 8 | `TELEPORT` (예약·거부) |
| 9 | `SET_FLAG` (예약·거부) |

### 공학 한도

| 항목 | 한도 |
|---|---:|
| ability당 condition | 16 |
| ability당 effect | 32 |
| selector 결과 | 256 body |
| transition invocation | 2,048 |
| transition effect application | 8,192 |
| P1 trigger wave | 기존 32 유지 |
| transition trigger record | 기존 4,096 유지 |

한도 초과는 전체 load 또는 transition 실패다. truncate·일부 skip·자동 분할하지 않는다.

## binding과 실행 순서

`AbilityRegistry.bind(catalog, bindings, status)`는 `(owner_body_id, ability_numeric_id)` 오름차순 불변 배열을 만든다.

- owner는 현재 participant·combatant·world body에 모두 존재해야 한다.
- ability ref는 active catalog definition이어야 한다.
- 같은 owner의 중복 ability ID는 load/bind 실패다.
- 죽거나 제거된 owner의 이후 invocation은 생성하지 않는다.
- `ON_DEATH_SELF`는 record 생성 시점의 제거 전 binding snapshot으로만 실행할 수 있다.
- `PASSIVE`는 event가 아니며 P2-3 modifier resolver 전까지 binding만 검증하고 실행하지 않는다.

한 trigger transition의 정본 순서:

```text
record wave → record sequence
  → owner body_id
  → ability numeric_id
  → condition index
  → effect index
      → selector가 만든 target body_id 오름차순
      → target별 effect application
  → 새 trigger record는 다음 wave
```

P2 인덱스의 축 나열 중 `target→effect index`는 여러 effect의 저작 의미를 뒤섞을 수 있다. 본 초안은 ability effect 배열을 먼저 보존하고 각 effect 안의 대상을 정렬하는 것으로 구체화한다. 이 차이는 P2-E08 승인에 명시적으로 포함한다.

## condition 의미

- 모든 condition은 index 오름차순 AND다.
- 하나라도 false이면 invocation은 성공한 무효과다.
- false·빈 selector는 RNG와 effect/application 한도를 소비하지 않는다.
- 관계 ID 0은 `RELATION_EXISTS`에서는 false이고, 그 외 관계 조건에서는 실행 오류다.
- HP 비교는 `current_hp * 10000`과 `max_hp * basis_points`를 checked int64 비교한다. basis points는 0~10,000이다.
- neutral은 ally/enemy 어느 쪽에도 포함하지 않는다.
- condition은 상태, trigger sequence, RNG를 바꾸지 않는다.

## selector 의미

- selector 후보는 살아 있고 world·participant·combatant에 모두 존재하는 body만 포함한다.
- 결과는 body ID 오름차순이며 중복이 없다.
- `limit`은 0이면 전체, 1~256이면 정렬 결과 앞에서 해당 수만 사용한다.
- `NEAREST_*`는 owner 중심 간 squared distance raw를 checked 계산하고 거리 동률은 낮은 body ID다.
- 관계 selector의 ID가 0이면 빈 결과다. 0이 아닌데 제거되어 있으면 실행 오류다.
- owner가 제거된 record에서 `ON_DEATH_SELF` selector OWNER는 effect 대상으로 사용할 수 없으며 빈 결과다. record 관계 사실은 condition에서 조회할 수 있다.
- random selector는 P2-2에 포함하지 않는다.

## 효과 원자 의미

### DAMAGE

- `value_a`: 1 이상 정수 직접 피해.
- P1 충돌 피해 공식·critical·friendly reduction을 다시 적용하지 않는다.
- 현재 HP에서 checked subtract하고 0 아래는 0으로 고정한다.
- HP 0이면 P1 공통 damage destroy 요청을 사용하고 source owner를 처치 root로 기록한다.
- 실제 적용 피해로 `ON_HIT_DEAL`/`ON_HIT_TAKE`를 다음 wave에 생성한다.
- owner와 target이 같아도 허용한다. 진영 제한은 condition/selector 책임이다.

### HEAL

- `value_a`: 1 이상 정수 회복량.
- `min(max_hp, current_hp + value_a)`로 적용하며 overflow는 min 계산 전 checked add 실패다.
- HP 0 또는 이미 제거된 body를 부활시키지 않는다.
- 실제 회복 0은 성공한 무효과다.
- P2-2에는 heal trigger가 없으므로 새 trigger를 만들지 않는다.

### KNOCKBACK / PULL

- `value_a`: 1 이상 Q47.16 raw 속도 크기.
- owner→target 단위 방향에 속도 delta를 더한다. `PULL`은 방향을 반전한다.
- 두 중심이 같으면 record vector가 0이 아닐 때 그 방향을 사용하고, 둘 다 0이면 실행 실패다.
- P0 `FixVec2` checked normalize·속도 상한을 사용한다.
- 위치를 즉시 바꾸거나 충돌을 즉시 step하지 않는다. 다음 권위 resolve tick이 물리를 처리한다.
- `MODIFY_VELOCITY`와 같은 effect index 순서로 누적된다.

### MODIFY_CT

- `value_a`: signed CT delta.
- target은 turn participant여야 한다.
- checked add 결과는 0 이상, `BattleLimits.CT_THRESHOLD * 2` 이하만 허용한다.
- 현재 actor를 바꾸거나 진행 중 action을 취소하지 않는다. 다음 actor 선택 barrier에서 반영한다.

### MODIFY_VELOCITY

- `value_a`, `value_b`: Q47.16 raw X/Y delta.
- target 현재 속도에 checked add한다.
- P0 속도 안전 상한을 넘으면 transition 전체 실패다.
- 0,0은 성공한 무효과다.

## trigger wave와 원자성

- P1 record는 발생 transition의 wave 0에서 시작한다.
- effect가 만든 record는 현재 record의 `wave + 1`이다.
- 새 record sequence는 기존 append-only `next_trigger_sequence`를 사용한다.
- 현재 handler에 재진입하지 않는다.
- P1의 32 wave/4,096 record 또는 P2 application 한도를 넘으면 실패한다.
- transition 시작 시 `BattleState`, registry runtime state, effect RNG 상태를 rollback 사본으로 만든다.
- 모든 condition·selector·effect·barrier가 성공한 뒤 한 번만 commit한다.
- 실패하면 HP, CT, world, pending mutation, trigger records/sequence, motion credit, RNG와 effect counters가 호출 전과 byte-for-byte 같아야 한다.

P2-2의 condition/selector/effect는 확률을 사용하지 않는다. 다만 resolver는 P1 record별 비소비 서브스트림을 입력으로 받는 API를 고정해 후속 확률 condition/effect가 권위 root RNG를 소비하지 않게 한다.

## 상태 모델과 공개 API

신규 immutable/typed 객체:

```text
AbilityConditionDefinition
AbilitySelectorDefinition
AbilityEffectDefinition
AbilityDefinition v2
AbilityBinding
AbilityRegistry
EffectApplication
EffectResolutionReport
```

공개 경계:

```text
AbilityRegistry.bind(catalog, owner_bindings, status) -> AbilityRegistry
AbilityRegistry.abilities_for_trigger(owner_body_id, trigger_id, status) -> Array[AbilityDefinition]

AbilityConditionEvaluator.matches(state, owner_body_id, record, condition, status) -> bool
AbilityTargetSelector.select(state, owner_body_id, record, selector, status) -> Array[int]

EffectResolver.resolve_transition(
    state: BattleState,
    registry: AbilityRegistry,
    records: Array[BattleTriggerRecord],
    content_fingerprint: PackedByteArray,
    status: SimStatus
) -> EffectResolutionReport
```

`EffectResolutionReport`는 적용 invocation/effect 수와 다음 wave record 사본만 제공한다. mutable `BattleState` 내부 배열이나 Dictionary를 반환하지 않는다.

P1 phase 공개 API는 trigger batch를 만든 직후 P2 resolver hook을 호출한다. content registry가 비어 있으면 byte-for-byte P1 동작을 유지하는 빠른 경로다.

## snapshot과 호환성

- `BattleSnapshot.SCHEMA_VERSION`을 4로 올린다.
- 32-byte content fingerprint를 포함한다.
- binding은 `(owner_body_id:u32, ability_numeric_id:u32)` 오름차순으로 인코딩한다.
- 다음 effect application sequence와 승인된 resolver counter를 인코딩한다.
- 처리 중 transition은 capture할 수 없다.
- restore 시 현재 catalog fingerprint가 다르면 `CONTENT_FINGERPRINT_MISMATCH`로 실패한다.
- v1~3 snapshot은 empty runtime catalog fingerprint와 binding 0개를 명시적으로 제공한 경우에만 복원한다.
- schema v4 decode 뒤 re-encode는 동일 bytes여야 한다.

## 오류 계약

기존 `ContentStatus`에는 schema v2 load 오류를 append-only field/operation으로 추가한다. 전투 실행 오류는 `SimStatus` append-only code/operation을 사용한다.

신규 SimStatus code 후보:

- `INVALID_ABILITY_BINDING`
- `INVALID_EFFECT_DEFINITION`
- `INVALID_EFFECT_TARGET`
- `EFFECT_LIMIT_EXCEEDED`
- `EFFECT_APPLICATION_FAILED`
- `CONTENT_FINGERPRINT_MISMATCH`

신규 operation 후보:

- `ABILITY_BIND`
- `ABILITY_CONDITION_EVALUATE`
- `ABILITY_TARGET_SELECT`
- `EFFECT_RESOLVE_TRANSITION`
- `EFFECT_APPLY`
- `CONTENT_SNAPSHOT_VALIDATE`

first-error-wins이며 `detail_a`에는 owner/target, `detail_b`에는 ability ID/effect index 중 operation별 고정 쌍을 기록한다. OS 문자열, JSON 문자열 ID, 절대 경로는 결정론 오류에 넣지 않는다.

## 대상 파일

신규:

```text
docs/specs/p2_effect_resolution.md
src/core/battle/ability_condition_definition.gd
src/core/battle/ability_selector_definition.gd
src/core/battle/ability_effect_definition.gd
src/core/battle/ability_binding.gd
src/core/battle/ability_registry.gd
src/core/battle/ability_condition_evaluator.gd
src/core/battle/ability_target_selector.gd
src/core/battle/effect_application.gd
src/core/battle/effect_resolution_report.gd
src/core/battle/effect_resolver.gd
pipeline/schemas/p2-abilities-v2.schema.json
pipeline/tests/p2_effect_resolution_test.gd
pipeline/tests/p2_effect_resolution_reference.py
pipeline/tests/run_p2_effect_resolution.py
pipeline/tests/fixtures/p2_effect_resolution/**
```

수정:

```text
src/core/data/ability_definition.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_status.gd
src/core/data/catalog.json
src/core/data/abilities.json
src/core/battle/battle_state.gd
src/core/battle/battle_snapshot.gd
src/core/battle/battle_limits.gd
src/core/sim/sim_status.gd
pipeline/schemas/p2-catalog-v2.schema.json
pipeline/tests/fixtures/p2_content_catalog/**
docs/specs/p2_index.md
AGENTS.md
HANDOFF.md
```

P2-2는 `src/core/sim/` 구현, scene, UI, asset, manifest를 수정하지 않는다.

## 필요 에셋

없음. runtime records는 비어 있고 모든 positive ability는 headless test fixture에만 존재한다.

## 수용 기준

1. ability/catalog schema v2가 exact key/type/version/enum/range/array 한도를 검증한다.
2. schema v1을 묵시적으로 v2로 해석하거나 unknown effect를 skip하지 않는다.
3. binding과 invocation이 owner ID→ability ID→condition/effect index 순서를 지킨다.
4. condition false와 빈 selector는 성공한 무효과이며 RNG·application 한도를 소비하지 않는다.
5. 관계 selector, 전체 진영 selector, nearest selector가 stable body ID 결과를 낸다.
6. body insertion과 JSON record/reference 순서를 교란해도 invocation과 target 순서가 같다.
7. DAMAGE가 직접 피해·공통 파괴·처치 root·다음 wave hit trigger를 정확히 만든다.
8. HEAL이 생존 target만 max HP까지 회복하고 부활시키지 않는다.
9. KNOCKBACK/PULL이 checked 고정소수점 방향과 속도 상한을 지킨다.
10. MODIFY_CT가 승인 범위와 actor 불변 계약을 지킨다.
11. MODIFY_VELOCITY가 effect 순서대로 누적되고 overflow 시 전체 실패한다.
12. 6개 원자의 invalid target·range·overflow에서 원본 상태와 RNG가 불변이다.
13. 새 trigger가 다음 wave에서만 실행되고 32 wave/4,096 record 한도를 넘으면 전체 rollback된다.
14. 2,048 invocation, 8,192 application, selector 256의 경계값과 초과값이 각각 성공/실패한다.
15. empty runtime catalog에서 기존 P0·P1 snapshot bytes·terminal 결과·golden이 승인된 migration 외에는 변하지 않는다.
16. BattleSnapshot v4가 fingerprint·binding·sequence를 copy/encode/decode/restore하고 재인코딩 bytes가 같다.
17. 잘못된 fingerprint restore가 전투 상태를 바꾸지 않고 명시적 mismatch로 실패한다.
18. 독립 Python reference가 ordering, selector, 6개 effect, snapshot section의 known-answer를 계산한다.
19. 같은 fixture 1,000회와 중간 snapshot restore가 같은 final bytes/hash를 만든다.
20. game-specific runner `run_p2_effect_resolution.py`가 `verify --full`에 자동 발견된다.
21. P2-1 narrow, P1-1~5, P0 narrow·결정론 회귀가 통과한다.
22. Godot 4.6.3 활성 `PYTHONUTF8=1 python pipeline/scripts/verify.py --full`이 통과한다.

## 구현 순서 — 전체 승인 뒤 적용

1. schema v2와 독립 Python reference/negative fixture를 먼저 고정한다.
2. typed condition·selector·effect definition과 catalog canonical v2를 구현한다.
3. immutable binding registry와 순수 condition/selector를 구현한다.
4. 6개 effect application을 작은 checked 함수로 구현한다.
5. next-wave drain과 transition 전체 rollback을 연결한다.
6. BattleSnapshot v4 fingerprint·binding·sequence를 구현한다.
7. effect별 narrow와 ordering·limit·rollback·snapshot 수용 테스트를 통과시킨다.
8. P2-1, P1, P0 회귀 뒤 Godot 활성 `verify --full`을 실행한다.
9. 구현·검증 결과를 P2 인덱스·AGENTS·HANDOFF에 기록한다.

## 승인 요청

P2-E01~12는 한 묶음 승인 대상이다. 승인 전에는 이 문서를 `draft`로 유지하고 `src/core/` 구현을 시작하지 않는다.
