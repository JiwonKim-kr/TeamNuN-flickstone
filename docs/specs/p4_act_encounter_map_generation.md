# P4-2 · Act·Encounter 카탈로그와 결정론적 노드맵 상세 명세

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 상위 승인 | `p4_run_loop.md` P4-R01~17 |
| 선행 구현 | P4-1 `RunState`·`RunNodeGraph`·`RunSnapshot` v1 |
| 후속 단계 | P4-3 편성·전투 request/outcome·라이프 경계 |
| 승인 | 2026-08-25 · 사용자 P4-G01~15 및 전체 명세 승인 |
| 구현 권한 | **있음. 승인된 P4-2 범위 구현 가능** |

## 목적

P4-1의 수동 graph 입력을 strict catalog의 Act profile과 64비트 런 seed에서 생성되는 권위 graph로 교체한다. `acts.json`은 층·slot별 노드 후보를, `encounters.json`은 전투 노드가 사용할 맵·적 배치·후속 보상 profile을 정의한다. 생성된 graph는 같은 seed와 catalog에서 byte-for-byte 같고, 모든 노드가 시작점에서 도달 가능하며 마지막 단일 보스로 이어져야 한다.

이 단계는 노드 **선택·진입**이나 실제 전투를 시작하지 않는다. P4-2의 완료 경계는 catalog v7 로드, typed act/encounter 조회, graph 생성, `RunState` 생성·snapshot 복원 시 exact graph 검증까지다.

## 정본과 선행 계약

- `docs/design/game_design.md` D-05·18·20·32, 9장, 15.3, U-09·15
- `docs/specs/p2_content_catalog.md`: strict JSON, append-only numeric/string ID pair, 원자 `DataDB`, canonical SHA-256 fingerprint
- `docs/specs/p2_maps_enemies_environment.md`: map/enemy typed definition, map `deploy_count`, slot 순서, enemy `ai_grade_id`
- `docs/specs/p3_ai_shot_selection.md`: COMMON/ELITE/BOSS AI grade와 별도 오차 substream
- `docs/specs/p4_run_loop.md` P4-R04·05·07·09·17
- `docs/specs/p4_run_state_snapshot.md` P4-S02·07·09~13

P4-1이 고정한 계약은 유지한다.

- node type: 일반 1, 엘리트 2, 상점 3, 이벤트 4, 휴식 5, 보스 6
- floor 1~16, floor당 node 1~4, 전체 node 1~192, node당 edge 1~4
- node ID는 `(floor_index, slot_index)` 순서로 1부터 연속
- edge는 정확히 다음 floor만 향하고 모든 node가 도달 가능하며 마지막 floor는 단일 BOSS
- 일반·엘리트·보스·상점·이벤트의 `content_numeric_id`는 nonzero, 휴식은 0
- `RunSnapshot` magic·schema·필드 순서는 v1 그대로 유지

## 범위

- catalog/document/fingerprint v7
- append-only ACT·ENCOUNTER·RELIC·CONSUMABLE document kind와 registry namespace
- strict `acts.json` v1·`encounters.json` v1과 typed immutable definitions
- P4-R09를 지키기 위한 빈 `relics.json` v1·`consumables.json` v1
- Act floor/slot/option profile과 integer weight 검증
- Encounter의 battle node type·map·slot 순 enemy·reward profile 검증
- 개발용 1막 5층 Act와 최소 graybox encounter records
- ELITE/BOSS AI 동작을 노출하는 graybox enemy records 2개
- 목적별 비소비 RNG를 사용한 node type/content 선택
- 층 폭에서 만드는 결정론적 adjacent-floor edge
- graph와 catalog content의 교차 검증
- 생성 graph를 사용하는 `RunState.create`와 snapshot restore exact 검증
- 독립 Python canonical/RNG/graph known-answer와 Godot narrow 검증

## 비범위

- 노드 선택, 방문·완료 history, phase 전이
- 편성, `RunBattleRequest`, `RunBattleOutcome`, 승패·라이프 차감
- reward 후보 생성·적용과 reward profile의 실제 의미
- 상점·이벤트 profile의 가격·선택지·효과
- relic·consumable record와 effect schema
- 정식 3막×10층, 35~45 encounter, 정식 엘리트·보스 설계와 밸런스
- node map UI, scene, save file I/O, Web 렌더
- 신규 이미지·폰트·음원·manifest 항목

## 용어

| 용어 | 정의 |
|---|---|
| Act profile | floor와 slot별 node 후보·가중치·content pool을 가진 불변 catalog record |
| slot option | 특정 floor/slot에서 선택 가능한 하나의 node type과 그 content pool |
| encounter | 전투 node type, map, enemy slot 배열, reward profile ID를 묶은 record |
| local profile ref | P4-5 전까지 Act 내부에서만 식별하는 SHOP/EVENT용 numeric/string pair |
| graph generation | Act profile과 run seed에서 node type/content/edge를 고정하는 순수 연산 |
| exact graph validation | 같은 catalog·act·seed로 graph를 재생성해 모든 node 필드와 edge를 비교하는 검증 |

## 승인 결정안

아래 값은 2026-08-25 사용자 승인으로 확정되었다.

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P4-G01 | document kind를 `ACTS=8`, `ENCOUNTERS=9`, `RELICS=10`, `CONSUMABLES=11`, namespace를 `ACT=9`, `ENCOUNTER=10`, `RELIC=11`, `CONSUMABLE=12`로 append한다 | 기존 1~8 ID를 보존하면서 P4-R09를 한 번에 반영 | ✅ 승인 |
| P4-G02 | catalog·fingerprint format은 v7, 네 신규 document는 schema v1로 시작한다 | P4 런 콘텐츠가 fingerprint에 포함됨을 명시 | ✅ 승인 |
| P4-G03 | P4-2에서 relic/consumable document와 namespace는 도입하되 records/entries는 반드시 비운다. 실제 record는 P4-5가 document schema를 올린 뒤 승인한다 | P4-R09를 지키면서 미정 effect DSL을 선행 확정하지 않음 | ✅ 승인 |
| P4-G04 | Act는 floor→slot→option profile을 저작한다. width와 node type을 코드에 하드코딩하지 않는다 | U-15를 정식 확률로 오인하지 않고 개발 slice를 데이터로 축약 | ✅ 승인 |
| P4-G05 | option은 node type별 양의 uint32 weight와 정렬된 content ref pool을 가진다. option이 하나거나 pool이 하나면 RNG를 그리지 않고 유일값을 고른다 | `SimRng.next_below(1)` 금지와 U-23의 퇴화 범위 소비 미결을 동시에 보존 | ✅ 승인 |
| P4-G06 | `RUN_MAP_NODE_TYPE=4`, `RUN_MAP_NODE_CONTENT=5`, 미래용 `RUN_REWARD=6`, `RUN_EVENT=7`을 purpose ID로 선점한다 | 기존 battle purpose 1~3과 충돌 없이 P4-R07의 substream을 고정 | ✅ 승인 |
| P4-G07 | map 생성 RNG key는 `(seed, purpose, owner=act_numeric_id, ordinal=node_id)`다. node ID가 floor/slot을 유일하게 포함한다 | 현재 SimRng의 고정 key를 바꾸지 않고 act·floor·node를 안정적으로 포함 | ✅ 승인 |
| P4-G08 | edge는 RNG를 쓰지 않고 인접 floor의 정규화된 slot 대응과 무입력 target 보정으로 만든다 | graph 연결성을 구성으로 보장하고 난수 호출 순서를 줄임 | ✅ 승인 |
| P4-G09 | `RunState.create`의 provisional graph 인자를 제거하고 catalog·act·seed로 내부 생성한다. snapshot restore는 graph를 재생성해 exact 비교한다 | production에서 임의 graph 주입·save tampering 경로를 닫음 | ✅ 승인 |
| P4-G10 | battle option의 content ref는 실제 encounter pair와 교차 검증하고, SHOP/EVENT ref는 P4-5 전까지 `(act,node_type)` 범위의 local profile pair로만 검증한다 | 전투 참조는 지금 강하게 고정하되 events schema를 발명하지 않음 | ✅ 승인 |
| P4-G11 | Encounter의 enemy 배열 길이는 map `deploy_count`와 정확히 같고 배열 순서가 enemy slot 순서다. 같은 enemy ref 중복은 허용한다 | 기존 `BattleSetupBuilder` 입력 경계와 바로 연결 가능 | ✅ 승인 |
| P4-G12 | encounter의 `reward_profile_numeric_id`는 nonzero opaque ID로 저장하고 의미·존재 검증은 P4-4가 소유한다 | reward schema를 앞당기지 않으면서 연결 슬롯을 fingerprint에 고정 | ✅ 승인 |
| P4-G13 | 개발 Act는 5층·폭 `1/2/2/1/1`이며 1층 일반, 2층 상점/이벤트, 3층 일반/엘리트, 4층 휴식, 5층 보스를 노출한다 | 승인된 P4-R04와 P4-1 검수 구조를 그대로 데이터화 | ✅ 승인 |
| P4-G14 | ELITE/BOSS 조준 체감을 런에서도 사용하도록 스탯 추가 없이 AI grade만 2/3인 graybox enemy record를 각각 하나 append한다 | P3 승인 동작을 encounter 경로에서 재사용하고 밸런스 수치 발명 최소화 | ✅ 승인 |
| P4-G15 | P4-1 binary KAT는 새 runtime fingerprint와 실제 생성 graph로 명시 이관하되 RunSnapshot v1 layout과 roster/scalar 값은 유지한다 | P4-1의 예정된 v7 migration을 설명 가능한 변화로 제한 | ✅ 승인 |

## append-only ID와 schema 계약

### ContentIds

```text
DocumentKind
  8  ACTS
  9  ENCOUNTERS
  10 RELICS
  11 CONSUMABLES

Namespace
  9  ACT
  10 ENCOUNTER
  11 RELIC
  12 CONSUMABLE

Schema
  CATALOG_SCHEMA_VERSION       = 7
  FINGERPRINT_FORMAT_VERSION   = 7
  ACTS_SCHEMA_VERSION          = 1
  ENCOUNTERS_SCHEMA_VERSION    = 1
  RELICS_SCHEMA_VERSION        = 1
  CONSUMABLES_SCHEMA_VERSION   = 1
```

신규 파일명은 정확히 `acts.json`, `encounters.json`, `relics.json`, `consumables.json`이다. `expected_json_files()`와 `DataDB` 열거는 기존 8개에 이 4개를 더한 정확한 12개만 허용한다. `catalog.json.documents`는 registry를 포함해 kind 1~11을 각각 한 번 가져야 한다.

`id_registry.json`은 namespace 1~12를 각각 한 번 포함한다. 기존 entry의 numeric/string/state는 바꾸지 않는다. ACT·ENCOUNTER의 active pair는 record와 1:1이어야 한다. RELIC·CONSUMABLE은 P4-2에서 entries와 records가 모두 비어야 한다.

## JSON exact schema

모든 object는 아래 key set만 허용한다. number는 strict JSON integer이며 bool은 JSON bool만 허용한다. 누락·추가 key와 암묵 변환은 전체 catalog load 실패다. 아래에서 순서 무관으로 지정한 배열은 loader가 안정 key로 정규화하고, 의미 순서 배열은 저작 순서를 보존한다.

### `acts.json` v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "development_act_1",
      "is_development": true,
      "floors": [
        {
          "floor_index": 1,
          "slots": [
            {
              "slot_index": 0,
              "options": [
                {
                  "node_type_id": 1,
                  "weight": 1,
                  "content_refs": [
                    {"numeric_id": 1, "id": "development_normal_mixed"},
                    {"numeric_id": 2, "id": "development_normal_pair"}
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

Exact key set:

| 객체 | exact keys |
|---|---|
| root | `schema_version`, `records` |
| act | `numeric_id`, `id`, `is_development`, `floors` |
| floor | `floor_index`, `slots` |
| slot | `slot_index`, `options` |
| option | `node_type_id`, `weight`, `content_refs` |
| content ref | `numeric_id`, `id` |

정규 규칙:

1. act record의 저작 순서는 무관하다. loader는 numeric ID 오름차순으로 정규화한 후보에서 중복을 거부한다.
2. `floors`는 `floor_index` 1부터 연속이며 2~16개다.
3. 각 floor의 `slots`는 `slot_index` 0부터 연속이며 1~4개다.
4. 각 slot은 option 1~6개를 가진다. 저작 순서는 무관하고 내부 정규 배열은 `node_type_id` 오름차순·유일하다.
5. `weight`는 1~`UINT32_MAX`, slot의 합은 1~`UINT32_SPACE(4,294,967,296)`다. 합은 checked int64로 계산한다.
6. 첫 floor는 slot 1개이고 NORMAL_BATTLE option만 허용한다.
7. 마지막 floor는 slot 1개이고 BOSS option만 허용한다.
8. 중간 floor에서 BOSS를 금지한다. NORMAL/ELITE/SHOP/EVENT/REST는 profile이 허용한 slot에서만 나온다.
9. NORMAL/ELITE/BOSS option의 `content_refs`는 1~32개이며 active encounter pair와 exact 일치하고 encounter의 `node_type_id`도 같아야 한다.
10. SHOP/EVENT option의 `content_refs`는 1~32개다. 각 ref는 nonzero uint32와 유효 string ID이며 `(act_numeric_id,node_type_id)` 안에서 numeric/string 양쪽이 1:1이다. P4-2에서는 외부 document를 참조하지 않는다.
11. REST option의 `content_refs`는 정확히 빈 배열이다. 생성 node의 content ID는 0이다.
12. content ref 저작 순서는 무관하다. 내부 정규 배열은 numeric ID 오름차순·유일하며 numeric/string 불일치와 같은 string의 다른 numeric ID를 거부한다.
13. `is_development=true`인 act는 전체 profile에서 여섯 node type을 모두 한 번 이상 노출해야 한다. 이 조건은 정식 act의 확률·quota 규칙이 아니다.

### `encounters.json` v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "development_normal_mixed",
      "node_type_id": 1,
      "map_ref": {"numeric_id": 1, "id": "graybox_pit_arena"},
      "enemy_refs": [
        {"numeric_id": 1, "id": "enemy_baduk_stone"},
        {"numeric_id": 2, "id": "enemy_bottle_cap"},
        {"numeric_id": 3, "id": "enemy_graybox_striker"}
      ],
      "reward_profile_numeric_id": 1
    }
  ]
}
```

Exact key set:

| 객체 | exact keys |
|---|---|
| root | `schema_version`, `records` |
| encounter | `numeric_id`, `id`, `node_type_id`, `map_ref`, `enemy_refs`, `reward_profile_numeric_id` |
| map/enemy ref | `numeric_id`, `id` |

정규 규칙:

1. encounter record 저작 순서는 무관하다. 내부 배열은 numeric ID 오름차순이며 active ENCOUNTER registry pair와 1:1이다.
2. `node_type_id`는 NORMAL_BATTLE, ELITE_BATTLE, BOSS 중 하나다. SHOP/EVENT/REST를 금지한다.
3. `map_ref`는 active MAP pair와 exact 일치한다.
4. `enemy_refs` 수는 참조 map의 `deploy_count`와 정확히 같고 3~5개다.
5. enemy ref는 active ENEMY pair와 exact 일치한다. 배열 index가 enemy slot index이며 순서는 의미가 있다.
6. 같은 enemy ref의 중복을 허용한다. loader는 enemy 배열을 정렬하지 않는다.
7. `reward_profile_numeric_id`는 1~`UINT32_MAX`다. P4-2에서는 존재하는 reward record와 교차 검증하지 않는다.
8. encounter node type과 포함 enemy의 AI grade를 강제로 같게 만들지 않는다. 개발 record는 P4-G14의 grade 2/3 enemy를 사용하지만 정식 구성 규칙은 U-09·10의 후속 승인 사항이다.

### `relics.json`·`consumables.json` v1

두 파일은 P4-2에서 정확히 아래 형태만 허용한다.

```json
{"schema_version": 1, "records": []}
```

non-empty records, 추가 root key, 해당 namespace의 active/retired entry는 실패한다. P4-5가 effect·stack·timing을 승인할 때 schema migration과 typed definition을 함께 정한다. P4-2는 ID-only 가짜 record나 코드 하드코딩 effect를 만들지 않는다.

## typed immutable 데이터 모델

```text
ActContentRef
  numeric_id: uint32
  string_id: String

ActNodeOptionDefinition
  node_type_id: uint16
  weight: uint32
  content_refs[]: ActContentRef, numeric ID sorted

ActNodeSlotDefinition
  slot_index: uint16
  options[]: ActNodeOptionDefinition, node type sorted

ActFloorDefinition
  floor_index: uint16
  slots[]: ActNodeSlotDefinition, slot index sorted

ActDefinition
  id_ref: ContentIdRef
  is_development: bool
  floors[]: ActFloorDefinition, floor index sorted

EncounterDefinition
  id_ref: ContentIdRef
  node_type_id: uint16
  map_ref: ContentIdRef
  enemy_refs[]: ContentIdRef, slot order
  reward_profile_numeric_id: uint32
```

모든 `copy()`는 깊은 사본을 반환한다. 외부에 내부 배열·Dictionary를 노출하지 않는다. lookup은 numeric ID 정렬 배열의 binary search를 쓰고 실패 시 기본 record를 반환하지 않는다.

`ContentCatalog`는 다음 불변 조회를 추가한다.

```text
act_count() -> int
act_at(index, status) -> ActDefinition
act_by_numeric_id(id, status) -> ActDefinition
act_by_string_id(id, status) -> ActDefinition

encounter_count() -> int
encounter_at(index, status) -> EncounterDefinition
encounter_by_numeric_id(id, status) -> EncounterDefinition
encounter_by_string_id(id, status) -> EncounterDefinition

relic_count() -> int                 # P4-2에서는 0
consumable_count() -> int            # P4-2에서는 0
```

`DataDB`는 act/encounter numeric lookup adapter만 추가한다. core 정의와 generator는 `Node`·파일 I/O를 사용하지 않는다.

## catalog 조립·검증 순서

```text
1) 파일 집합·catalog document exact 검증
2) registry namespace 1~12·append-only pair 검증
3) 기존 status/synergy/ability/piece/enemy/map typed 후보 조립
4) encounter exact parse
5) encounter map/enemy pair·deploy_count 교차 검증
6) act exact parse
7) act battle option → encounter pair·node type 교차 검증
8) act SHOP/EVENT local profile pair와 개발 Act coverage 검증
9) relic/consumable empty document·namespace 검증
10) canonical v7 bytes와 SHA-256 fingerprint 계산
11) 모든 단계 성공 후에만 DataDB catalog 교체
```

어느 단계에서 실패해도 기존 `DataDB` catalog와 fingerprint는 유지된다. P2의 first-error-wins `ContentStatus`를 그대로 쓴다.

## canonical compatibility bytes v7

기존 `FLICKCAT` little-endian writer를 확장한다.

```text
magic "FLICKCAT"
fingerprint_format_version u16 = 7
catalog_schema_version     u16 = 7
registry_schema_version    u16 = 1
namespace_count            u16 = 12
namespace sections         1..12
document_count             u16 = 10   # registry 제외, pieces..consumables
existing document sections 2..7
acts section               kind 8, schema 1
encounters section         kind 9, schema 1
relics empty section       kind 10, schema 1, count 0
consumables empty section  kind 11, schema 1, count 0
```

Act section:

```text
u32 record_count
repeat act numeric ID order:
  u32 numeric_id
  utf8 string_id
  u8  is_development (0/1)
  u16 floor_count
  repeat floor index order:
    u16 floor_index
    u16 slot_count
    repeat slot index order:
      u16 slot_index
      u16 option_count
      repeat node type order:
        u16 node_type_id
        u32 weight
        u16 content_ref_count
        repeat numeric ID order:
          u32 numeric_id
          utf8 string_id
```

Encounter section:

```text
u32 record_count
repeat encounter numeric ID order:
  u32 numeric_id
  utf8 string_id
  u16 node_type_id
  u32 map_numeric_id
  utf8 map_string_id
  u16 enemy_ref_count
  repeat authored slot order:
    u32 enemy_numeric_id
    utf8 enemy_string_id
  u32 reward_profile_numeric_id
```

JSON object key 순서와 act/encounter record·floor·slot·option·content ref 저작 배열 순서는 fingerprint에 영향을 주지 않는다. loader가 명시 key로 정렬해 canonical array를 만든다. encounter `enemy_refs` 순서만 battle slot 의미가 있으므로 바꾸면 fingerprint가 달라진다.

## 개발 runtime records

### enemy append

기존 ENEMY 1~3은 바꾸지 않고 다음 active pair와 `enemies.json` schema v2 record를 append한다.

| numeric ID | string ID | base piece | AI grade | override |
|---:|---|---|---:|---|
| 4 | `graybox_elite_baduk_stone` | `baduk_stone` | 2 ELITE | `{}` |
| 5 | `graybox_boss_graybox_striker` | `graybox_striker` | 3 BOSS | `{}` |

둘 다 `graybox_` 접두사를 사용하며 정식 적·밸런스 record가 아니다. HP/공격/속도/물리 수치는 base piece level 1을 그대로 쓴다.

### encounters

| ID | string ID | type | map | enemy slot 0→2 | reward profile |
|---:|---|---|---|---|---:|
| 1 | `development_normal_mixed` | NORMAL | `graybox_pit_arena` | enemy 1, 2, 3 | 1 |
| 2 | `development_normal_pair` | NORMAL | `graybox_pit_arena` | enemy 2, 1, 2 | 1 |
| 3 | `development_elite_pair` | ELITE | `graybox_pit_arena` | enemy 4, 2, 4 | 2 |
| 4 | `development_boss_pair` | BOSS | `graybox_pit_arena` | enemy 5, 4, 5 | 3 |

reward profile 1~3은 P4-4가 의미를 정하기 전까지 opaque다. P4-2 테스트가 골드·영입·유물을 지급하지 않는다.

### `development_act_1`

| floor | slots | option과 content pool |
|---:|---:|---|
| 1 | 1 | slot 0: NORMAL weight 1, encounters `[1,2]` |
| 2 | 2 | slot 0: SHOP weight 1, local profile `(1, development_shop_profile)`; slot 1: EVENT weight 1, local profile `(1, development_event_profile)` |
| 3 | 2 | slot 0: NORMAL weight 1, encounters `[1,2]`; slot 1: ELITE weight 1, encounter `[3]` |
| 4 | 1 | slot 0: REST weight 1, empty content pool |
| 5 | 1 | slot 0: BOSS weight 1, encounter `[4]` |

이 profile은 node 유형 구조를 고정하고 seed가 floor 1·3의 NORMAL encounter만 바꾸게 한다. weighted multi-type 선택은 별도 test fixture에서 검증한다. U-15의 정식 출현 확률로 승격하지 않는다.

## graph 생성 알고리즘

### 1. node ID와 profile 순회

Act의 floor를 1부터, 각 floor의 slot을 0부터 순회한다. 각 slot마다 node ID를 1부터 하나씩 부여한다. 입력은 이미 loader가 정규화한 불변 typed definition이어야 하며 generator가 Dictionary를 순회하지 않는다.

### 2. node type 선택

slot option이 하나면 RNG를 만들거나 draw하지 않고 그 option을 선택한다.

option이 둘 이상이면:

```text
rng = SimRng.derive(seed_hi, seed_lo,
                    RUN_MAP_NODE_TYPE,
                    act_numeric_id,
                    node_id)
ticket = rng.next_below(sum_weight)
누적 weight가 ticket을 처음 초과하는 option 선택
```

option은 node type 오름차순이다. `sum_weight`는 2~`UINT32_SPACE`다. rejection sampling은 기존 `SimRng` 구현을 그대로 쓴다.

### 3. content 선택

- REST는 content ID 0이다.
- 다른 type의 content pool이 하나면 draw 없이 그 ref의 numeric ID를 쓴다.
- 둘 이상이면 `RUN_MAP_NODE_CONTENT`, owner=act ID, ordinal=node ID로 별도 substream을 만들고 `next_below(pool_count)` 결과 index를 쓴다.

node type과 content가 서로 다른 purpose를 쓰므로 option 수·weight 변경이 content draw를 소비하거나 다른 node의 결과를 바꾸지 않는다.

### 4. adjacent-floor edge

현재 floor 폭을 `A`, 다음 floor 폭을 `B`라 한다. 모든 나눗셈은 nonnegative int floor division이다.

```text
1) 각 source slot s=0..A-1:
     target = floor(s * B / A)
     edge s→target 추가

2) 각 target slot t=0..B-1을 오름차순 검사:
     incoming이 없으면
       source = floor(t * A / B)
       edge source→t 추가

3) source별 target node ID를 오름차순 정렬·중복 제거
```

폭이 1~4이므로 source outgoing은 1~4다. 모든 source는 다음 floor로 나가고 모든 target은 이전 floor에서 들어오므로 첫 floor에서 전 노드가 도달 가능하고 모든 노드가 마지막 boss로 이어진다. 마지막 floor에는 edge를 만들지 않는다.

개발 Act 폭 `1/2/2/1/1`의 exact edge는 다음과 같다.

```text
node IDs: floor1 [1], floor2 [2,3], floor3 [4,5], floor4 [6], floor5 [7]
edges:
  1 → [2,3]
  2 → [4]
  3 → [5]
  4 → [6]
  5 → [6]
  6 → [7]
  7 → []
```

### 5. 최종 구조 검증

모든 node를 만든 뒤 기존 `RunNodeGraph.create`의 6단계 검증을 반드시 다시 통과시킨다. generator는 일부 node나 부분 graph를 성공값으로 반환하지 않는다.

## graph content와 exact 검증

`RunMapGenerator.validate_exact(catalog, act_id, seed_hi, seed_lo, graph, status)`는 다음 순서로 검사한다.

1. catalog와 act ref가 initialized/active인지 확인한다.
2. 전달 graph의 기존 P4-1 구조 불변식을 확인한다.
3. 같은 catalog·act·seed로 expected graph를 새로 생성한다.
4. floor count, node count, 각 node의 ID/floor/slot/type/content, edge count와 edge ID를 순서대로 exact 비교한다.
5. 하나라도 다르면 첫 node ID와 다른 field 값을 진단하고 실패한다.

catalog fingerprint가 같고 graph exact 검증까지 통과해야만 `RunState` 생성·restore가 성공한다. SHOP/EVENT local profile은 현재 act option pool membership으로 검증되며 P4-5에서 실제 profile catalog 검증을 추가한다.

## 공개 API 변경

```text
RunMapGenerator.generate(catalog, act_numeric_id,
                         seed_hi, seed_lo, status) -> RunNodeGraph
RunMapGenerator.validate_exact(catalog, act_numeric_id,
                               seed_hi, seed_lo, graph, status) -> bool

RunState.create(catalog, act_numeric_id,
                seed_hi, seed_lo, initial_pieces, status) -> RunState
```

P4-1의 public `RunState.create(catalog, act_numeric_id, graph, ...)`는 provisional test seam이므로 P4-2에서 위 signature로 교체한다. arbitrary graph를 받는 production factory는 남기지 않는다.

`RunSnapshot.decode`는 계속 content-independent 구조만 검사한다. `RunSnapshot.restore_state`가 fingerprint 확인 뒤 act 존재와 exact generated graph 검증을 추가한다. `RunState.validate(catalog, status)`도 같은 검증을 수행한다. `copy`는 검증된 graph를 깊게 복제할 뿐 RNG 상태를 저장하거나 소비하지 않는다.

## 결정론·원자성

- graph generator와 typed definitions는 `RefCounted`이며 `Node`, `Time`, `FileAccess`, Godot RNG를 호출하지 않는다.
- root/default stream을 순차 소비하지 않는다. 모든 선택은 explicit derived substream이다.
- graph 자체에 RNG state/draw count를 저장하지 않는다. seed와 catalog가 권위 입력이다.
- getter·UI preview·snapshot capture·copy·validate는 RNG를 소비하지 않는다.
- node type과 content 선택은 다른 purpose를 사용하고 node마다 다른 ordinal을 사용한다.
- authoring 배열 순서는 loader에서 canonical key로 정규화한다. encounter enemy slot 배열만 의미 순서를 유지한다.
- generate/validate/create/restore 실패는 입력 catalog·graph·snapshot과 기존 RunState를 바꾸지 않는다.
- generator는 실패한 중간 RNG draw나 일부 node를 외부에 노출하지 않는다.
- 같은 seed여도 다른 act numeric ID는 다른 substream key를 쓴다.
- hash·fingerprint는 RNG seed로 재사용하지 않는다.

## 공학 한도

| 항목 | 한도 |
|---|---:|
| Act record | 3 |
| Act당 floor | 2~16 |
| floor당 slot | 1~4 |
| slot당 option | 1~6 |
| option당 content ref | 0~32, REST만 0 허용 |
| option weight | 1~`UINT32_MAX` |
| slot weight 합 | 1~`UINT32_SPACE` |
| 전체 generated node | 192 |
| node당 edge | 1~4, final boss만 0 |
| Encounter record | 4,096 |
| encounter enemy ref | 참조 map `deploy_count`, 3~5 |
| Relic record | P4-2에서 0, 미래 engineering ceiling 256 |
| Consumable record | P4-2에서 0, 미래 engineering ceiling 256 |

Act record 한도 3은 정식 3막을 수용하는 현재 engineering ceiling이다. floor 수·폭·확률은 gameplay 정식값이 아니며 P6 또는 별도 승인으로 확장할 수 있다.

## 진단 계약

기존 enum 번호를 바꾸지 않고 끝에만 append한다.

### ContentStatus

Operation:

| 값 | 이름 |
|---:|---|
| 14 | `ACT_VALIDATE` |
| 15 | `ENCOUNTER_VALIDATE` |

FieldId:

| 값 | 이름 |
|---:|---|
| 91 | `IS_DEVELOPMENT` |
| 92 | `FLOORS` |
| 93 | `FLOOR_INDEX` |
| 94 | `SLOTS` |
| 95 | `SLOT_INDEX` |
| 96 | `OPTIONS` |
| 97 | `NODE_TYPE_ID` |
| 98 | `WEIGHT` |
| 99 | `CONTENT_REFS` |
| 100 | `MAP_REF` |
| 101 | `ENEMY_REFS` |
| 102 | `REWARD_PROFILE_NUMERIC_ID` |

기존 `UNSUPPORTED_SCHEMA`, `UNKNOWN_KEY`, `MISSING_KEY`, `INVALID_ID`, `DUPLICATE_ID`, `MISSING_REFERENCE`, `INVALID_DOMAIN`, `CATALOG_LIMIT`, `FINGERPRINT_ERROR`를 재사용한다.

### SimStatus

Code:

| 값 | 이름 |
|---:|---|
| 68 | `INVALID_RUN_ACT` |
| 69 | `RUN_MAP_GENERATION_FAILED` |

Operation:

| 값 | 이름 |
|---:|---|
| 148 | `RUN_MAP_GENERATE` |
| 149 | `RUN_MAP_SELECT` |
| 150 | `RUN_GRAPH_CONTENT_VALIDATE` |

세부값:

| operation | detail_a | detail_b |
|---|---|---|
| map generate | act numeric ID 또는 node ID | floor/slot 또는 실패 단계 |
| map select | node ID | purpose ID 또는 읽은 bound |
| graph content validate | node ID, act 자체면 0 | expected/actual type 또는 content ID |

RNG primitive 실패는 기존 SimStatus code/operation을 first-error로 보존한다. generator가 이를 `RUN_MAP_GENERATION_FAILED`로 덮어쓰지 않는다.

## RunSnapshot v1 이관

P4-2는 `RunSnapshot.SCHEMA_VERSION=1`, `FLICKRUN\0`, 필드 순서, little-endian, trailing-byte 금지를 바꾸지 않는다.

P4-1 KAT fixture는 다음 이유로 bytes가 바뀐다.

1. catalog v7 runtime fingerprint가 snapshot prefix에 들어간다.
2. placeholder content ID 1001~1007이 runtime encounter/local profile ID로 교체된다.
3. 수동 complete-bipartite graph가 승인된 edge 생성 결과로 교체된다.

seed `hi=17, lo=29`, 초기 roster key 1~6, life/gold/cap/phase/sequence 등 나머지 scalar와 roster 값은 유지한다. 새 full hex·SHA-256은 구현 전에 독립 Python writer가 먼저 계산하고 Godot이 일치해야 하며, 구현 기록에 derived known-answer를 남긴다. 이 hash는 설계 선택값이 아니므로 승인 표의 미정 항목이 아니다.

## 대상 파일

### 신규

```text
docs/specs/p4_act_encounter_map_generation.md
src/core/data/act_content_ref.gd
src/core/data/act_node_option_definition.gd
src/core/data/act_node_slot_definition.gd
src/core/data/act_floor_definition.gd
src/core/data/act_definition.gd
src/core/data/encounter_definition.gd
src/core/data/acts.json
src/core/data/encounters.json
src/core/data/relics.json
src/core/data/consumables.json
src/core/run/run_random_purpose.gd
src/core/run/run_map_generator.gd
pipeline/tests/p4_act_encounter_map_generation_test.gd
pipeline/tests/p4_act_encounter_map_generation_reference.py
pipeline/tests/run_p4_act_encounter_map_generation.py
pipeline/tests/fixtures/p4_act_encounter/**
pipeline/schemas/p4-acts-v1.schema.json
pipeline/schemas/p4-encounters-v1.schema.json
```

### 수정

```text
docs/specs/p4_run_loop.md
docs/specs/p4_run_state_snapshot.md
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_status.gd
src/core/data/content_catalog.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/catalog.json
src/core/data/id_registry.json
src/core/data/enemies.json
src/core/autoload/data_db.gd
src/core/sim/sim_status.gd
src/core/run/run_state.gd
pipeline/scripts/content_catalog.py
pipeline/tests/p4_run_state_snapshot_test.gd
pipeline/tests/p4_run_state_snapshot_reference.py
pipeline/tests/p2_content_catalog_test.gd
pipeline/tests/p2_content_catalog_reference.py
pipeline/tests/p2_content_graybox_test.gd
pipeline/tests/p2_content_graybox_reference.py
pipeline/tests/p3_ai_shot_selection_reference.py
pipeline/tests/run_p2_content_graybox.py
pipeline/tests/fixtures/p2_*/**
pipeline/tests/fixtures/p2_content_catalog_vectors.json
AGENTS.md
HANDOFF.md
```

현재 builder로 로드되는 기존 P2 fixture는 exact file-set 계약 때문에 네 파일과 namespace 9~12를 모두 추가해야 한다. P2 전용 fixture의 run documents는 빈 records로 구조 이관하고 기존 piece/ability/status/synergy/map/enemy 의미는 바꾸지 않는다. runtime fingerprint를 직접 검사하는 P2/P3 runner와 golden은 v7 derived 값으로 명시 이관한다. 의도적으로 과거 unsupported schema를 검사하는 negative fixture는 기대 실패 의미를 유지한다.

## 필요 에셋

없음. P4-2는 headless core와 JSON만 수정한다. 신규 scene·이미지·폰트·음원·manifest 등록을 하지 않는다.

## 수용 기준

1. document kind 8~11, namespace 9~12, ContentStatus/SimStatus 신규 enum이 기존 마지막 값 뒤에 append된다.
2. catalog v7이 정확히 12개 JSON 파일과 kind 1~11 document를 요구하고 누락·추가·중복을 거부한다.
3. ACT/ENCOUNTER active·retired registry pair의 record 누락·불일치가 전체 load 실패한다.
4. P4-2의 RELIC/CONSUMABLE namespace·records가 비어 있고 non-empty 입력은 실패한다.
5. acts/encounters의 unknown/missing key, 잘못된 type/bool/int/string ID/schema가 각각 실패한다.
6. floor count 1/17, floor gap·duplicate, slot −1/4, slot gap·duplicate가 각각 실패한다.
7. option 0/7개, duplicate node type, weight 0/`UINT32_SPACE`, slot weight 합 `UINT32_SPACE+1`이 실패한다.
8. 첫 floor 다중 slot·비NORMAL, 마지막 floor 다중 slot·비BOSS, 중간 BOSS가 실패한다.
9. REST non-empty content, non-REST empty content, duplicate/mismatched local profile pair가 실패한다.
10. 없는 encounter, numeric/string mismatch, option과 encounter node type mismatch가 실패한다.
11. 없는 map/enemy pair와 enemy 수가 map deploy_count보다 작거나 큰 encounter가 실패한다.
12. encounter enemy 중복은 통과하고 배열 순서가 typed 조회와 canonical bytes에 유지된다.
13. 개발 Act가 여섯 node type 중 하나를 노출하지 않으면 실패하고 같은 profile의 `is_development=false`는 일반 schema 규칙으로 통과한다.
14. canonical v7 Godot bytes와 SHA-256이 독립 Python known-answer와 일치한다.
15. object key, record/floor/slot/option/content ref 저작 순서를 교란해도 fingerprint가 같고 encounter enemy slot 순서를 바꾸면 달라진다.
16. invalid reload 뒤 기존 DataDB catalog와 fingerprint가 그대로 유지된다.
17. runtime catalog가 act 1, encounter 4, enemy 5, relic 0, consumable 0을 typed 조회한다.
18. 같은 catalog·act·seed graph가 1,000회 같은 node/edge/type/content와 RunSnapshot bytes를 만든다.
19. weighted multi-option fixture가 독립 Python과 같은 option/content를 선택하고 서로 다른 node가 substream을 공유하지 않는다.
20. 단일 option·단일 content pool은 RNG draw 없이 통과하고 `next_below(1)`을 호출하지 않는다.
21. 개발 Act graph가 node ID 1~7, floor width `1/2/2/1/1`, exact edge `1→[2,3], 2→[4], 3→[5], 4→[6], 5→[6], 6→[7], 7→[]`를 가진다.
22. 폭 조합 A/B 1~4의 16개 fixture 모두 source outgoing, target incoming, edge ceiling을 만족한다.
23. 모든 generated node가 첫 floor에서 도달 가능하고 단일 final boss로 이어진다.
24. 다른 seed가 별도 multi-option fixture에서 최소 하나의 node type 또는 content를 다르게 만든다.
25. graph content ID를 구조-valid 다른 값으로 손상한 snapshot은 decode되더라도 restore exact 검증에서 실패한다.
26. graph edge를 다른 유효 next-floor edge로 손상한 snapshot도 restore에서 실패한다.
27. 없는/retired act, catalog fingerprint mismatch, generation 실패가 미초기화 RunState를 반환하고 입력을 바꾸지 않는다.
28. P4-1 KAT가 새 v7 fingerprint/generated graph로 명시 이관되고 RunSnapshot schema·roster·scalar는 유지된다.
29. P0 RNG/SHA, P1 BattleSnapshot, P2 catalog/maps, P3 AI, P4-1 snapshot 대표 narrow가 회귀 통과한다.
30. P4-2 일상 검증은 독립 Python + Godot narrow + `verify --demo`로 끝낸다. 4런·실제 렌더·`verify --full`은 아직 요구하지 않는다.

## 구현 순서 — 전체 승인 뒤

1. append-only ID/schema/limits와 strict Python parser·canonical writer fixture를 먼저 고정한다.
2. relic/consumable empty contract와 act/encounter negative schema matrix를 만든다.
3. typed immutable act/encounter objects와 catalog lookup을 구현한다.
4. encounter→map/enemy, act→encounter/local profile 교차 검증을 atomic builder에 추가한다.
5. canonical v7 bytes/fingerprint와 runtime records를 구현하고 독립 KAT를 맞춘다.
6. `RunRandomPurpose`와 weighted selection, content selection을 구현한다.
7. 16개 floor-width edge fixture와 `RunMapGenerator` 전체 검증을 구현한다.
8. `RunState.create`를 generated graph 경계로 바꾸고 restore exact graph 검증을 추가한다.
9. P4-1 snapshot full KAT를 새 fingerprint/graph로 이관한다.
10. schema/canonical/atomicity/RNG/edge/1,000회 narrow를 통과시킨다.
11. P0~P4-1 대표 회귀와 `verify --demo`를 실행한다.
12. 구현·검증 결과를 P4 인덱스·P4-1·AGENTS·HANDOFF에 기록한다.

## 승인 기록과 후속 미결

2026-08-25 사용자는 P4-G01~15와 이 문서 전체를 승인하고 구현 진입을 지시했다. 다음 경계를 승인 기준선으로 고정한다.

- P4-R09를 지키기 위해 relic/consumable **빈 문서만 먼저** catalog v7에 넣는 방식
- SHOP/EVENT를 P4-5 전까지 Act-local profile pair로 보존하는 방식
- P4-1의 arbitrary graph create seam을 제거하고 restore에서 generated graph exact 비교를 하는 방식
- 개발용 ELITE/BOSS enemy 2개를 AI grade만 달리해 append하는 방식

이 명세는 U-09의 정식 35~45 encounter 구성, U-10 적 스케일, U-15 정식 층별 확률·분기 폭, U-18 reward 분배를 확정하지 않는다. P4의 개발 slice 값은 `development_`/`graybox_` ID로만 격리한다.

## 구현·검증 기록

2026-08-25 승인 범위 구현과 데모 검증을 완료했다.

- catalog/fingerprint v7과 document kind 8~11, namespace 9~12를 append했다. runtime fingerprint는 `ed6dd1319f158a539ffe4bc89bce965ea1061586b1e462a7e211bb8f0f561e3e`다.
- immutable Act/Encounter 계층, strict builder/독립 Python loader, canonical encoder, `DataDB` typed lookup을 구현했다. relic/consumable records와 namespace는 P4-2 계약대로 비어 있다.
- runtime에는 5층 `development_act_1`, encounter 4개, 기존 piece를 재사용하는 ELITE/BOSS enemy 2개를 추가했다. graph는 node 1~7과 edge `1→[2,3], 2→[4], 3→[5], 4→[6], 5→[6], 6→[7], 7→[]`를 만든다.
- `RunMapGenerator`는 node별 type/content substream과 무난수 edge 구성을 사용한다. 단일 option/pool은 RNG를 그리지 않으며 weighted 합 `UINT32_SPACE` 경계가 통과한다.
- `RunState.create`의 임의 graph 인자를 제거했고 snapshot restore/validate가 catalog·act·seed로 graph를 재생성해 exact 비교한다.
- 독립 Python schema negative/KAT와 Godot 8개 grouped check, graph 1,000회, P4-1 snapshot 17개 grouped check·1,000회·입력 순열 24개가 통과했다. `RunSnapshot` v1 이관 KAT는 331 bytes, SHA-256 `73ea51d49acb0fc2b1f2b1d696241dcf724937653e42d1249d63d66f9ff34797`다.
- P2 catalog·status/synergy·dynamic piece·maps/enemies와 P3 AI 대표 회귀가 통과했다. P2 terminal quick은 현재 snapshot hash를 restore exact로 비교하고, catalog-only fingerprint 이관 시 데모 profile에서는 승인된 gameplay 필드만 기존 32행 golden의 seed-0과 비교한다. 정식 release profile은 16×2 exact hash 갱신/검증을 유지한다.
- Godot 4.6.3 `verify --demo`는 import·smoke·naming·manifest 게이트와 대표 러너 8종이 모두 통과했고, lore 미초기화 게이트만 정책대로 SKIP이다.
- 신규 scene·UI·asset·manifest는 없다. P4-2는 headless 단계이므로 4런·렌더 검수를 요구하지 않는다.
