# P5-DZ · encounter 기반 턴 시작 데미지 존

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 단계 | P5 전투 가독성 폴리시 · P2 환경 존 확장 |
| 선행 조건 | P2-5 존·`SPAWN_ZONE`, P2-6 runtime 회색상자, P3 AI, P4-3 전투 요청 구현·검증 완료 |
| 구현 권한 | **있음.** 2026-08-25 사용자가 P5-DZ01~12와 본문 전체를 승인 |

## 목적

현재 제출 콘텐츠의 중앙 KILL 존을 즉사 구덩이가 아니라 **기물 자신의 턴 시작 시 피해를 받는 데미지 존**으로 교체한다. 맵 바닥과 위험 영역을 분리하여 같은 맵에서도 encounter 또는 능력에 따라 존 위치·개수·지속시간을 바꿀 수 있게 한다.

플레이어는 발사 뒤 기물이 데미지 존에 조금이라도 걸쳐 멈췄는지 확인하고, 다음 행동 순서가 오기 전에 탈출시키거나 상대를 밀어 넣는 판단을 한다. 이동 중 존을 통과하는 것만으로는 피해를 받지 않는다.

## 기존 승인 계약과의 관계

이 명세는 기존 KILL 엔진 기능을 삭제하거나 D-06·07·23·39를 폐기하지 않는다.

| 기존 계약 | 처리 |
|---|---|
| `SimWorld` KILL 경계·KILL 존과 P0 결정론 회귀 | 그대로 보존 |
| P2-M03의 “주기 피해 존 비범위” | 이 명세 승인 시 **턴 시작 피해만** 별도 확장 |
| P2-G09의 runtime 중앙 KILL 존 | 제출 콘텐츠에서 제거하고 encounter 데미지 존으로 대체 |
| P3 KILL 평가·안전 가드 | 코드와 fixture는 보존. 제출 runtime에 KILL 존이 없어 해당 점수는 자연스럽게 0 |
| P4 kill tally의 KILL 원인 처리 | 보존. 데미지 존 사망은 환경 피해이며 어느 기물의 kill로도 집계하지 않음 |

즉사 KILL 콘텐츠는 향후 특수 이벤트·엘리트에서 다시 사용할 수 있다. 이번 변경은 **현재 runtime 콘텐츠에서만 제외**하는 재승인이다.

## 포함 범위

- 기물 원과 존 폴리곤의 접촉·겹침 판정
- 현재 행동자의 `TURN_START` 환경 피해
- 겹친 모든 존의 `zone_id` 오름차순 개별 피해
- encounter가 소유하는 초기 데미지 존
- `SPAWN_ZONE`으로 생성되는 데미지 존과 기존 수명 계약 재사용
- 환경 피해 사망·trigger 경계·원자적 rollback
- encounter/ability/catalog/fingerprint 및 BattleSnapshot 상승
- 회색상자 중앙 KILL 존의 데미지 존 이관
- 맵 바닥과 분리된 데미지 존 placeholder/렌더 레이어
- 독립 기하 기준값, narrow, 결정론, P0~P4 회귀, `verify --demo`

## 비범위

- KILL 엔진 코드·기존 fixture 삭제
- 데미지 존의 이동·회전·크기 변화 애니메이션
- 매 물리 tick 피해, 진입 즉시 피해, 턴 종료 피해
- 피해량 확률·크리티컬·공격자 스탯·진영별 피해량
- 데미지 존 전용 능력 trigger 신설
- AI가 미래 정지 위치를 예측해 데미지 존을 전략적으로 이용하는 기능
- 맵 바닥 실제 아트, 기물 실제 아트, `art lock`·`art gen`·`art reskin`
- KILL 존이 다시 등장하는 특수 encounter 제작

## 용어

| 용어 | 정의 |
|---|---|
| 데미지 존 | `turn_start_damage > 0`인 전투 계층의 존 효과 |
| 접촉 | 기물 원의 내부 또는 원주가 존 폴리곤 내부·경계와 한 점 이상 겹치는 상태 |
| 초기 데미지 존 | 맵이 아니라 encounter가 전투 시작 시 배치하는 절대 좌표 존 |
| 설치 데미지 존 | `SPAWN_ZONE`이 대상 위치 기준 로컬 폴리곤으로 만든 존 |
| 환경 피해 | 공격자 body가 없고 존 ID가 원인인 정확한 고정 피해 |

## 결정 사항

| ID | 결정 | 상태 |
|---|---|---|
| P5-DZ01 | runtime 기준 피해는 **존 하나당 정확히 15**다 | ✅ 사용자 선택 · 2026-08-25 |
| P5-DZ02 | 중심점이 아니라 **기물 원이 존 폴리곤과 조금이라도 맞닿으면** 판정한다. 접선 접촉도 포함한다 | ✅ 사용자 선택 · 2026-08-25 |
| P5-DZ03 | 처리 순서는 **환경 피해 → 생존 시 `ON_TURN_START` → AIM**이다 | ✅ 사용자 선택 · 2026-08-25 |
| P5-DZ04 | 여러 존이 겹치면 `zone_id` 오름차순으로 **각 존의 피해를 각각 적용**한다 | ✅ 사용자 선택 · 2026-08-25 |
| P5-DZ05 | 기존 KILL 기능과 테스트는 유지하되 **현재 runtime 콘텐츠에서만 제외**한다 | ✅ 사용자 선택 · 2026-08-25 |
| P5-DZ06 | 맵은 중립 바닥·경계·슬롯을 소유하고, 초기 데미지 존의 위치·형태는 encounter가 소유한다 | ✅ 승인 · 2026-08-25 |
| P5-DZ07 | `SPAWN_ZONE` payload에 `turn_start_damage`를 추가하고 기존 `duration_turns`·rollback·zone ID를 재사용한다 | ✅ 승인 · 2026-08-25 |
| P5-DZ08 | 첫 데미지 존은 순수 피해 영역이다. `KILL`, 마찰 변경, 가속도와 한 존에서 함께 저작하면 로드 실패한다 | ✅ 승인 · 2026-08-25 |
| P5-DZ09 | 환경 피해 15는 공격력·크리티컬·주는/받는 피해 modifier를 거치지 않는 **정확한 고정값**이다 | ✅ 승인 · 2026-08-25 |
| P5-DZ10 | 환경 피해는 공격자와 `ON_HIT_DEAL`이 없고, 사망 시 `ON_DEATH_SELF`는 발생하되 `ON_KILL`·kill tally는 발생하지 않는다 | ✅ 승인 · 2026-08-25 |
| P5-DZ11 | 첫 runtime encounter는 기존 중앙 사각형 `(224,464)~(416,560)`을 데미지 존으로 재사용한다 | ✅ 승인 · 2026-08-25 |
| P5-DZ12 | 첫 구현에서 P3 AI의 데미지 존 전략 평가는 추가하지 않는다. 권위 턴 시작 피해만 양 진영에 동일 적용한다 | ✅ 승인 · 2026-08-25 |

## 접촉 판정

`SimPolygon.overlaps_circle(center, radius_raw, status)` 순수 질의를 추가한다.

1. 중심점 분류가 `INSIDE` 또는 `BOUNDARY`면 접촉이다.
2. 중심점이 `OUTSIDE`면 각 폴리곤 변의 최근접점까지 고정소수점 거리를 계산한다.
3. 최소 거리가 `radius_raw` **이하**면 접촉이다. 정확히 같은 접선도 피해를 받는다.
4. 오목 폴리곤도 모든 변을 검사하므로 같은 규칙을 쓴다.
5. float, epsilon, Godot 물리 API를 사용하지 않는다.

거리 계산은 기존 `MapGeometryValidator`와 `SimCollision`의 `wide dot → projection clamp → SimPolygon.unit_ratio_raw → FixVec2.length_raw` 순서를 한 공용 순수 함수로 통합한다. 판정은 현재 `TURN_START` 안정 경계의 body 위치·반지름만 읽으며 이동 궤적과 이전 위치를 보지 않는다.

## 턴 시작 처리

`BattleState.complete_turn_start()`의 원자적 transition 안에서 다음 순서를 사용한다.

```text
1. 기존 pending mutation barrier 적용
2. 현재 actor participant·combatant·body 확인
3. DamageZoneState를 zone_id 오름차순으로 순회
4. actor 원과 접촉한 존마다 HP -15
5. 각 피해 뒤 사망 확인. 사망하면 남은 존 피해를 중단
6-a. 생존: ON_TURN_START 발생·효과 정산 → AIM
6-b. 사망: ON_TURN_START 없음 → missing actor interrupt → TURN_END → CHECK
```

- HP가 15 이하이면 0으로 만든다. 음수 HP를 만들지 않는다.
- 다섯 존과 접촉하고 충분한 HP가 있으면 총 75 피해를 순서대로 받는다.
- 두 번째 존에서 사망하면 세 번째 이후 존은 존재하지 않는 target에 적용하지 않는다.
- 피해 중 하나라도 실패하면 HP·body·participant·trigger·zone state·RNG를 호출 전 bytes로 복원한다.
- 환경 피해로 actor가 사망해도 전역 `TURN_END` 경계와 `turn_index` 증가는 정상 실행되어 상태·설치 존 수명이 멈추지 않는다. 제거된 actor의 능력 binding은 없으므로 actor의 `ON_TURN_END` 능력은 발동하지 않는다.

환경 피해는 별도 공격자가 없으므로 `ON_HIT_DEAL`을 발생시키지 않는다. P5-DZ10에 따라 일반 파괴 사건과 `ON_DEATH_SELF`만 재사용한다. UI는 현재 actor HP 변화와 접촉한 `zone_id` 목록으로 데미지 팝업을 표시한다. 데미지 존 전용 신규 능력 trigger는 이 명세 범위에 추가하지 않는다.

## 데이터 계약

### encounters.json v2

각 encounter exact key set에 `damage_zones`를 추가한다.

```json
{
  "numeric_id": 1,
  "id": "development_normal_mixed",
  "node_type_id": 1,
  "map_ref": {"numeric_id": 1, "id": "graybox_pit_arena"},
  "enemy_refs": [],
  "reward_profile_numeric_id": 1,
  "damage_zones": [
    {
      "local_id": 1,
      "turn_start_damage": 15,
      "duration_turns": 0,
      "vertices": [
        {"x_raw": 14680064, "y_raw": 30408704},
        {"x_raw": 27262976, "y_raw": 30408704},
        {"x_raw": 27262976, "y_raw": 36700160},
        {"x_raw": 14680064, "y_raw": 36700160}
      ]
    }
  ]
}
```

- encounter 정점은 map 논리 좌표의 절대값이다.
- `local_id`는 encounter 안에서 0이 아닌 고유 uint32이며 canonical encode와 초기 생성은 오름차순이다.
- `turn_start_damage`는 양의 int64다. 첫 runtime 콘텐츠는 정확히 15만 사용한다.
- `duration_turns=0`은 전투 종료까지 영구다. 1~1,024는 기존 전역 `TURN_END` 수명 규칙을 쓴다.
- 폴리곤은 기존 존과 같은 단순 3~64정점·위치 안전 범위 규칙을 쓴다.
- damage zone은 map 경계 내부에 있어야 한다. 다른 존·슬롯·body와의 겹침은 허용한다.
- 동일 map을 참조하는 encounter마다 `damage_zones`를 다르게 저작하거나 빈 배열로 둘 수 있다.

### abilities.json v6 · SPAWN_ZONE

기존 `zone` payload exact key set에 `turn_start_damage`를 추가한다.

```json
"zone": {
  "flags": 0,
  "friction_multiplier_raw": 65536,
  "acceleration_x_raw": 0,
  "acceleration_y_raw": 0,
  "turn_start_damage": 15,
  "offset_x_raw": 0,
  "offset_y_raw": 0,
  "vertices": [],
  "duration_turns": 2
}
```

- `turn_start_damage=0`이면 기존 물리 존이다.
- `turn_start_damage>0`이면 P5-DZ08에 따라 `flags=0`, 마찰 1.0, 가속 `(0,0)`만 허용한다.
- 대상 위치 + offset + 로컬 정점 합성, 수명, 요청 정렬, rollback 한도는 P2-M11~12를 그대로 쓴다.

### runtime 이관

- `maps.json`의 `graybox_pit_arena.zones`를 빈 배열로 바꾼다.
- 현재 네 development encounter 각각이 중앙 데미지 존을 명시한다.
- 이후 encounter별 위치 변경은 map 파일을 바꾸지 않고 `encounters.json`만 수정한다.
- KILL enum·flags·loader 지원은 유지한다.

## 상태와 안정 ID

신규 불변 값 객체:

```text
EncounterDamageZoneDefinition(local_id, damage, duration_turns, vertices)
DamageZoneState(zone_id, turn_start_damage)
```

- initial world zone ID는 `map zone local_id 오름차순 → encounter damage zone local_id 오름차순`으로 배정한다.
- 기존 map만 사용하고 encounter damage zone이 없으면 P2-M19의 zone ID 결과가 변하지 않는다.
- runtime `SPAWN_ZONE`은 모든 initial zone 뒤에서 기존 monotonic `next_zone_id`를 쓴다.
- `DamageZoneState`는 map/encounter/설치 출처와 무관하게 `zone_id` 오름차순이다.
- 설치 존의 수명은 기존 `ZoneSpawnState`가 계속 소유하며, damage 여부와 피해량만 `DamageZoneState`가 소유한다.
- 존 제거 시 양쪽 상태가 같은 barrier에서 함께 제거된다.

## snapshot·schema·fingerprint

- encounters v2, abilities v6, catalog v8, fingerprint format v8로 상승한다.
- maps v1, enemies v2, pieces v3, SimSnapshot v2, RunSnapshot v1은 유지한다.
- `BattleSnapshot`은 v9로 상승해 `DamageZoneState`를 저장하고 legacy v1~8은 빈 목록으로 복원한다.
- RunSnapshot 구조는 같지만 content fingerprint가 바뀌므로 KAT bytes/hash를 승인 참조와 함께 이관한다.
- P2-6 terminal golden은 즉사 존 제거로 전투 결과·턴 수가 바뀔 수 있다. 변경 전후를 비교하고 새 규칙으로 설명되지 않는 차이는 실패다.

BattleSnapshot v9는 v8 kill tally 뒤, SimSnapshot 길이 앞에 다음을 append한다.

```text
u32 damage_zone_count
repeat zone_id ascending:
  u32 zone_id
  i64 turn_start_damage
```

decode는 count `<=64`, zone ID 0 금지·유일·엄격 오름차순, damage `>0`, 복원된 SimWorld의 동일 zone 존재를 검증한다.

## 렌더·에셋 경계

맵 바닥 이미지에는 데미지 존·기물·HUD·문자를 굽지 않는다. 회색상자는 runtime 데이터의 같은 폴리곤으로 별도 overlay를 만든다.

| manifest 후보 ID | placeholder 요구 | 사용 지점 |
|---|---|---|
| `art:zones/turn_start_damage` | 64×64 RGBA 반복 타일, 위험 방향 문양, 읽을 수 있는 문자 없음 | `scenes/p2_content_graybox.tscn::Battlefield/MapVisuals` |

- `play build`에서는 `PLACEHOLDER_turn_start_damage.png`를 만들고 `manifest.py`로 등록한다.
- 렌더는 폴리곤을 마스크로 사용하고 월드 좌표 기준 UV로 타일을 반복한다.
- 접촉 판정은 texture alpha나 렌더 크기를 읽지 않고 core polygon만 사용한다.
- 실제 아트 생성·교체는 스타일 선택과 `art lock` 뒤 별도 `art gen`·`art reskin` 승인으로 진행한다.

## P3 AI 영향

첫 구현에서는 하이브리드 AI가 미래 정지 위치를 정확히 예측하지 않으므로 데미지 존 점수를 새로 넣지 않는다. AI와 플레이어 모두 실제 자기 턴 시작에 같은 권위 피해를 받는다.

- 기존 KILL 방향 위험·처치 점수와 회귀는 보존한다.
- runtime에 KILL 존이 없으므로 제출 장면에서는 해당 점수가 0이다.
- 데미지 존을 의도적으로 이용하거나 피하는 AI는 정지 위치 근사가 승인된 후속 명세로 분리한다.

## 오류 계약

- strict JSON·unknown key·범위·폴리곤 오류는 catalog 전체를 원자적으로 거부한다.
- encounter zone이 map 경계 밖이거나 유효하지 않으면 `ENCOUNTER_VALIDATE`에서 실패한다.
- world zone과 `DamageZoneState` 등록·제거가 불일치하면 transition 전체를 rollback한다.
- 존재하지 않는 actor/body/combatant, 손상된 snapshot zone 참조, damage 0 이하는 명확히 실패한다.
- 중첩 존을 truncate·합산·최댓값 하나로 자동 보정하지 않는다.
- append-only `ContentStatus.FieldId`, `SimStatus.Code/Operation`, `SimEvent.CauseId`는 기존 마지막 값 뒤에만 추가한다.

## 대상 파일 후보

신규:

```text
src/core/data/encounter_damage_zone_definition.gd
src/core/battle/damage_zone_state.gd
pipeline/schemas/p5-encounters-v2.schema.json
pipeline/schemas/p5-abilities-v6.schema.json
pipeline/tests/p5_turn_start_damage_zones_test.gd
pipeline/tests/p5_turn_start_damage_zones_reference.py
pipeline/tests/run_p5_turn_start_damage_zones.py
pipeline/tests/fixtures/p5_turn_start_damage_zones/**
assets/art/zones/PLACEHOLDER_turn_start_damage.png
```

수정 후보:

```text
docs/design/game_design.md
docs/specs/p2_maps_enemies_environment.md
docs/specs/p2_content_graybox.md
docs/specs/p3_ai_shot_selection.md
docs/specs/p5_art_direction.md
AGENTS.md
HANDOFF.md
src/core/sim/sim_polygon.gd
src/core/sim/sim_world.gd
src/core/sim/sim_event.gd
src/core/sim/sim_status.gd
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_status.gd
src/core/data/encounter_definition.gd
src/core/data/zone_spawn_payload_definition.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/encounters.json
src/core/data/maps.json
src/core/data/catalog.json
src/core/data/abilities.json
src/core/battle/battle_setup_builder.gd
src/core/battle/battle_state.gd
src/core/battle/battle_snapshot.gd
src/core/battle/battle_mutation_request.gd
src/core/battle/effect_resolver.gd
src/core/run/run_battle_bridge.gd
src/ui/battle/p2_content_graybox.gd
pipeline/manifest.json
pipeline/tests/fixtures/p2_*/**
pipeline/tests/fixtures/p3_*/**
pipeline/tests/fixtures/p4_*/**
```

매니페스트 쓰기는 `pipeline/scripts/manifest.py`만 사용한다. `src/core/` 변경 커밋 본문에는 이 승인된 명세 경로를 적는다.

## 수용 기준

1. 중심이 존 밖이어도 원주가 내부·경계에 닿으면 피해를 받고, 거리 `radius+1 raw`이면 받지 않는다.
2. 중심이 내부·경계에 있으면 피해를 받는다.
3. 볼록·오목 폴리곤과 꼭짓점·변 접선에서 독립 정수 기준값과 Godot 결과가 일치한다.
4. 이동 중 존을 통과해도 피해가 없고 자기 `TURN_START` 안정 경계에서만 피해를 받는다.
5. 존 하나와 접촉하면 HP가 정확히 15 감소한 뒤 `ON_TURN_START`가 발생한다.
6. 세 존과 겹치면 zone ID 순서로 15씩 세 번, 총 45 피해를 받는다.
7. 두 번째 존에서 사망하면 세 번째 존 피해와 `ON_TURN_START`가 발생하지 않는다.
8. 환경 피해 사망은 `ON_DEATH_SELF`와 일반 승패 판정을 발생시키되 `ON_KILL`·kill tally는 증가시키지 않는다.
9. 환경 피해 사망 턴도 TURN_END·CHECK와 설치 존 수명을 정상 진행한다.
10. encounter 두 개가 같은 map을 참조하면서 서로 다른 damage zone 배열을 가져도 각각 정확한 위치에 생성된다.
11. map의 zones가 비어 있어도 encounter damage zone이 초기 world와 렌더에 나타난다.
12. `SPAWN_ZONE` damage 15·duration 0/1/1,024 경계와 설치 턴 제외 수명이 기존 계약대로 동작한다.
13. damage와 KILL/마찰/가속 결합, 0·음수 damage, 2/65정점, 경계 밖, 중복 local ID가 각각 로드 실패한다.
14. 겹친 존을 입력 배열 순서와 무관하게 zone ID 순서로 처리하고 1,000회 같은 snapshot hash를 낸다.
15. 피해·사망·존 등록·존 제거 중 주입 실패가 전체 turn-start transition을 byte-for-byte rollback한다.
16. encounters v2·abilities v6·catalog/fingerprint v8 canonical bytes가 독립 Python KAT와 일치한다.
17. BattleSnapshot v9가 damage zone을 exact 복원하고 v1~8을 빈 damage zone 목록으로 복원한다.
18. RunSnapshot v1은 구조를 유지하며 새 fingerprint KAT로 명시적으로 이관한다.
19. 기존 P0 KILL 경계·KILL 존, P2 `SPAWN_ZONE`, P3 KILL AI fixture가 그대로 통과한다.
20. 회색상자에서 기물이 중앙 데미지 존에 조금 걸친 상태와 완전히 들어간 상태 모두 다음 자기 턴에 피해 15를 받는다.
21. 64×64 RGBA placeholder가 manifest 정합성을 통과하고 overlay와 판정 폴리곤의 좌표가 같다.
22. 관련 narrow 뒤 Godot 4.6.3 `PYTHONUTF8=1 python pipeline/scripts/verify.py --demo`가 통과한다.

## 구현 순서 — 전체 명세 승인 뒤

1. 독립 circle-polygon 접촉 KAT와 schema fixture를 먼저 고정한다.
2. `SimPolygon.overlaps_circle`과 접선 경계를 구현한다.
3. encounter damage zone·ability payload·catalog/fingerprint v8을 구현한다.
4. encounter 초기 zone 조립과 `DamageZoneState` 등록·수명을 구현한다.
5. 원자적 turn-start 다중 피해·환경 사망을 구현한다.
6. BattleSnapshot v9·legacy 복원과 RunSnapshot fingerprint 이관을 구현한다.
7. runtime map/encounter와 회색상자 overlay placeholder를 이관한다.
8. P0 KILL·P2 zone·P3 AI·P4 run 회귀와 새 1,000회 결정론을 통과시킨다.
9. Godot 4.6.3 `verify --demo`와 사람 플레이 검수를 진행한다.
10. 검수 승인 뒤 아트 컨셉을 중립 맵 바닥과 데미지 존 overlay로 분리한다.

## 승인 기록

P5-DZ01~05는 2026-08-25 사용자가 직접 선택했다. 같은 날 사용자가 권장안 P5-DZ06~12와 본문 전체를 승인하여 구현 기준선을 고정했다.

## 구현·검증 기록

2026-08-25 승인 범위를 구현했다.

- runtime map의 KILL 존을 제거하고 네 development encounter가 중앙 15-damage zone을 소유하도록 이관했다.
- circle/polygon 접촉, 턴 시작 다중 피해, 환경 사망 귀속, 설치 존 수명·rollback, BattleSnapshot v9와 legacy v1~8 복원을 구현했다.
- abilities v6·encounters v2·catalog/fingerprint v8의 strict loader와 Godot/Python canonical encoder를 이관했다. 현재 runtime fingerprint는 `16df0d24ed90733b2f5f8b3761fd37830154e550c74fc00adba3a9445fa07167`다.
- 331-byte RunSnapshot v1은 구조를 유지하며 SHA-256 `8c8671cd39afe6defc986644d56122315cd6191d03793416620d2fbf95f87c04`로 이관했다.
- 독립 기하 KAT와 Godot P5-DZ 9개 그룹, P2-6 quick 22개 그룹·1,000회 결정성·두 seed-0 terminal gameplay 회귀가 통과했다.
- Godot 4.6.3 `verify --demo`는 기본 게이트 4 PASS, lore 미초기화 1 정책 SKIP, 대표 러너 9종 PASS로 완료했다.
- 정식 release용 P2-6 16×2 exact terminal 골든 갱신과 사람 플레이 검수는 후속 체크사항이다.

## P4-5/6 병합 이관 기록

2026-08-25 원격 P5-DZ 구현을 P4-5/6 런 루프와 병합했다. 두 브랜치가 각각 추가한 문서 집합을 모두 보존하기 위해 catalog/fingerprint를 v10으로 상승시켰으며, P5-DZ의 abilities v6·encounters v2·BattleSnapshot v9 동작은 변경하지 않았다. 통합 runtime fingerprint는 `68a8bc7f39ba0bc8d80c4ab097e09fc6c901ecdf7f020f8d3c5f2112f9d0e078`, 335-byte RunSnapshot v2 KAT SHA-256은 `f7d9ad1ed82658bf30cabe2d0eeb5227597f359b74afa814a0a4c2c113f346e2`다.
