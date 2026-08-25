# P4-5 · 유물·소모품·상점·이벤트 공통 프레임 상세 명세

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 상위 승인 | `p4_run_loop.md` P4-R01~17 |
| 선행 구현 | P4-1~3 검증 완료, P4-4 구현 완료·누적 검증 대기 |
| 후속 단계 | P4-6 축약 Act UI·저장/이어하기·자동/사람 완주 |
| 검증 정책 | P4-5 구현 중 반복 runner·대표 회귀·`verify`를 실행하지 않고 P4-6에서 누적 수행 |
| 구현 권한 | **있음. 2026-08-25 사용자 전체 승인** |

## 목적

P4-2가 Act-local pair로만 보존한 SHOP/EVENT node를 실제 strict catalog record와 원자 RunState 명령에 연결한다. 유물과 소모품의 공통 typed effect 경계를 열고, 개발 Act에서 상점 구매·이벤트 선택·소모품 사용·유물의 지속 효과를 한 번씩 관찰할 수 있게 한다.

P4-5는 정식 경제나 30~40종 유물·12~16종 소모품·15~20종 이벤트를 설계하는 단계가 아니다. `development_` record 각 1개와 제한된 run effect 4종만 승인해 여섯 node type이 모두 실행 가능한 MVP 프레임을 만든다.

완료 경계는 다음과 같다.

1. SHOP/EVENT node의 local pair가 실제 catalog record와 exact 일치한다.
2. 상점에서 유물 또는 소모품을 한 번 구매하거나 나갈 수 있다.
3. 이벤트에서 골드 또는 소모품을 받고 node를 완료할 수 있다.
4. 소모품은 MAP_CHOICE에서 한 번 소비되고, 유물은 이후 승리 골드에 계속 적용된다.
5. inventory와 SHOP/EVENT pending이 기존 RunSnapshot v2에 exact 보존된다.

사용자의 일정 지시에 따라 P4-5 단독 runner·반복·대표 회귀·`verify`는 구현 완료 조건이 아니다. 수용 기준은 삭제하지 않고 P4-6 누적 검증 부채로 기록한다. 구현 중에는 코드 리뷰와 로드 불가 방지용 최소 Godot import만 허용한다.

## 정본과 현재 구현

- `docs/design/game_design.md` D-05·09·18, 9.2·9.5·9.7, 10.1·10.4, U-04·07·08·18·42
- `docs/specs/p4_run_loop.md` P4-R04·06·07·09·15~17
- `docs/specs/p4_run_state_snapshot.md` P4-S02·06·07과 inventory/pending codec 슬롯
- `docs/specs/p4_act_encounter_map_generation.md` P4-G03·06·10·13
- `docs/specs/p4_reward_recruitment_rest_merge.md` catalog v8, RunSnapshot v2, gold·boon·원자 명령

현재 구현 상태:

- `relics.json`·`consumables.json`은 schema v1 빈 문서이며 registry namespace 11·12도 비어 있다.
- `development_act_1`의 2층은 SHOP local pair `(1, development_shop_profile)`과 EVENT local pair `(1, development_event_profile)`을 사용한다.
- RunState와 RunSnapshot v2에는 relic ID 배열과 consumable stack 배열의 바이트 슬롯이 이미 있다. 현재 RunState 검증은 두 배열이 비어 있어야 한다.
- `RunPhase.SHOP/EVENT`, `RunPendingKind.SHOP/EVENT`, `RunChoiceKind.TAKE_RELIC/TAKE_CONSUMABLE/EVENT_OPTION` 번호는 이미 선점돼 있다.
- 개발 첫 전투 승리 gold는 10이므로 2층 상점 가격을 이 범위 안에 두면 별도 debug 지급 없이 구매를 검수할 수 있다.

## 범위

- relic/consumable schema v2와 typed immutable definition
- 신규 shop/event document·namespace와 typed profile
- catalog/fingerprint v9와 Act SHOP/EVENT exact reference 검증
- 제한된 엔진 독립 `RunEffectDefinition`과 run effect kind 4종
- unique relic inventory와 consumable sorted stack mutation
- SHOP/EVENT node 진입, 고정 pending 생성, 선택 적용, node 완료
- MAP_CHOICE 소모품 사용
- 유물의 승리 골드 보너스를 P4-4 reward 준비에 연결
- SHOP/EVENT/inventory의 RunSnapshot v2 capture·restore 의미 검증
- 실패 시 원본 RunSnapshot bytes를 유지하는 후보 사본 commit
- 개발 유물·소모품·상점·이벤트 record 각 1개

## 비범위

- 정식 유물·소모품·이벤트 목록과 희귀도·드롭률
- 무작위 상점 재고, 새로고침, 판매, 기물 구매·방출, 가격 할인
- 상점에서 여러 번 구매하기와 상점 재방문
- 전투 중 소모품 사용, 소모품 대상 지정, 여러 사용 timing
- battle modifier·발사 보정·적 약화 유물
- relic 중복·레벨·강화·저주·세트 효과
- 이벤트 전투, 이벤트 RNG 분기, 라이프를 거는 선택, 해금 이벤트
- 정식 골드 경제 U-42와 node별 보상 배분 U-18 확정
- P4-6 UI·씬·SaveManager·단일 continue 파일 I/O
- 전용 P4-5 runner·fixture와 전체 catalog KAT 실행

## 용어

| 용어 | 정의 |
|---|---|
| run effect | 전투 바깥 RunState 값에 적용되는 제한된 typed 원자 |
| unique relic | 같은 numeric ID를 한 런에서 최대 하나만 보유하는 지속 아이템 |
| consumable stack | 같은 consumable ID의 보유 수량을 하나의 정렬 record로 저장한 값 |
| shop offer | 고정 item ref·수량·가격을 가진 상점 선택지 |
| event option | 0개 또는 1개의 run effect를 가진 고정 이벤트 선택지 |
| leave option | 아이템·골드 변화 없이 node만 완료하는 명시적 선택지 |

## 선행 계약과 충돌 점검

### P4-G03 relic/consumable 빈 schema 이관

P4-G03은 P4-5가 실제 effect를 승인할 때 relic/consumable document schema를 올리도록 명시했다. 따라서 records만 v1에 채우지 않고 두 문서를 schema v2로 올린다. 기존 document kind 10·11과 namespace 11·12는 그대로 유지한다.

### P4-G10 Act-local SHOP/EVENT pair 이관

현재 pair는 graph fingerprint와 node content ID를 선점했지만 외부 record가 아니다. P4-5는 숫자와 문자열을 바꾸지 않고 각각 SHOP·EVENT registry pair와 실제 record로 승격한다. 같은 seed의 graph node/edge/type/content numeric ID는 유지된다.

### P4-S02와 RunSnapshot v2

relic ID와 consumable stack은 P4-1부터 snapshot에 선점돼 있다. P4-5는 새 RunState 권위 필드를 추가하지 않으므로 RunSnapshot을 v3로 올리지 않는다. P4-4의 trailing next-battle status를 포함한 **v2 layout을 그대로 사용**한다.

### 설계 정본의 미정 항목

아래 권장값은 `development_` MVP record에만 적용한다.

- 유물 1종·소모품 1종·이벤트 1종은 U-04·07·08의 정식 목록을 해소하지 않는다.
- 5/10 gold 가격과 +5 gold 효과는 U-42 정식 경제 수치가 아니다.
- fixed stock 2개와 node당 구매 1회는 U-18 정식 상점 규칙이 아니다.
- MAP_CHOICE 사용 timing과 stack 3은 개발 slice 승인값이며 정식 소모품 전체 규칙은 후속 재승인할 수 있다.

## 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P4-I01 | document kind `SHOPS=13`, `EVENTS=14`, namespace `SHOP=14`, `EVENT=15`를 append하고 catalog/fingerprint를 v9로 올린다 | Act-local pair를 실제 strict catalog ref로 승격 | ✅ 승인 |
| P4-I02 | relic/consumable 기존 kind·namespace는 유지하고 schema만 v1→v2로 올린다. relic inventory는 ID sorted unique로 고정한다 | P4-G03과 선점된 snapshot 배열을 그대로 활용 | ✅ 승인 |
| P4-I03 | run effect는 `GAIN_GOLD`, `RECOVER_LIFE`, `GAIN_CONSUMABLE`, `VICTORY_GOLD_BONUS` 네 kind만 연다 | MVP 네 경로에 필요한 최소 원자이며 battle effect 과설계 방지 | ✅ 승인 |
| P4-I04 | relic은 effect 정확히 1개, consumable은 effect 정확히 1개, event option은 effect 0~1개만 가진다 | 다중 effect 순서·부분 성공 문제를 현재 단계에서 제거 | ✅ 승인 |
| P4-I05 | 개발 유물 `development_bounty_ledger`는 이후 승리 gold에 고정 +5를 더한다 | 전투 bridge 변경 없이 지속 유물 효과를 눈으로 확인 가능 | ✅ 승인 |
| P4-I06 | 개발 소모품 `development_life_flask`는 max stack 3이며 MAP_CHOICE에서 life +1로 사용한다. max life에서는 사용 실패하고 소모하지 않는다 | 라이프 장기 자원과 연결되며 전투 중 저장·대상 지정이 불필요 | ✅ 승인 |
| P4-I07 | 개발 상점은 현상금 장부 1개 10 gold, 생명 플라스크 1개 5 gold와 항상 활성인 나가기 선택을 고정 제시한다 | 첫 승리 10 gold만으로 구매 경로를 바로 검수하고 무자금 교착 방지 | ✅ 승인 |
| P4-I08 | 상점은 구매 또는 나가기 한 번 뒤 즉시 완료한다. 재고 RNG·새로고침·판매·다중 구매는 두지 않는다 | 5층 MVP의 선택 경계를 최소화 | ✅ 승인 |
| P4-I09 | `LEAVE_SHOP=9`를 RunChoiceKind 끝에 append한다 | disabled offer만 남은 상점에서도 명시적으로 진행 가능 | ✅ 승인 |
| P4-I10 | 개발 이벤트는 `gold +5`, `life flask +1`, `그냥 나가기` 세 option을 고정 제시한다 | gold·inventory effect와 no-op 완료 경계를 한 profile에서 검수 | ✅ 승인 |
| P4-I11 | SHOP/EVENT pending은 node 진입 시 한 번 만들고 `generation_ordinal=next_transition_sequence`를 저장한다. fixed profile이므로 RNG draw는 없다 | UI 재진입·snapshot restore에서 후보 불변, 퇴화 RNG 호출 방지 | ✅ 승인 |
| P4-I12 | item 획득 가능 여부와 현재 gold로 offer/option의 enabled를 계산하고 pending 저장 뒤에는 해당 phase에서 다른 inventory command를 금지한다 | 화면 표시와 실제 적용의 stale 차이를 제거 | ✅ 승인 |
| P4-I13 | relic 중복, consumable max stack, gold overflow, max-life 회복은 선택 전체를 rollback한다. disabled choice 적용도 실패한다 | first-error-wins와 snapshot 원자성 유지 | ✅ 승인 |
| P4-I14 | SHOP/EVENT 완료는 node를 completed에 추가하고 MAP_CHOICE/current node 0으로 돌아가며, 예약된 revenge boon은 유지한다 | 비전투 node가 다음 실제 battle boon을 소비하지 않게 함 | ✅ 승인 |
| P4-I15 | 유물 gold 보너스는 P4-4 `prepare_reward`에서 relic ID 오름차순으로 합산해 base victory gold와 함께 checked 지급한다 | 별도 후처리 command 없이 중복 지급 방지 | ✅ 승인 |
| P4-I16 | RunSnapshot v2 layout을 유지하고 SHOP/EVENT capture·restore 및 non-empty inventory 의미 검증만 연다 | 선점 슬롯 재사용과 불필요한 migration 방지 | ✅ 승인 |
| P4-I17 | 모든 definition/command는 generic Dictionary API 없이 typed getter와 의미별 공개 method를 사용한다 | content ID별 코드 분기와 UI 직접 mutation 차단 | ✅ 승인 |
| P4-I18 | P4-5 구현 중 runner·반복·대표 회귀·`verify`를 생략하고 최소 import만 수행한다. P4-6에서 catalog v9 KAT, P4-1~5 narrow, quick 4런과 `verify --demo`를 누적 실행한다 | 승인된 시간 제약과 검증 부채의 명시적 관리 | ✅ 승인 |

## append-only ID와 schema 계약

```text
DocumentKind
  13 SHOPS
  14 EVENTS

Namespace
  14 SHOP
  15 EVENT

Schema
  CATALOG_SCHEMA_VERSION       = 9
  FINGERPRINT_FORMAT_VERSION   = 9
  RELICS_SCHEMA_VERSION        = 2
  CONSUMABLES_SCHEMA_VERSION   = 2
  SHOPS_SCHEMA_VERSION         = 1
  EVENTS_SCHEMA_VERSION        = 1
```

신규 파일명은 정확히 `shops.json`, `events.json`이다. `expected_json_files()`는 `catalog.json`을 포함한 정확히 15개 파일만 허용한다. `catalog.json.documents`는 kind 1~14를 각각 한 번 가져야 하고 `id_registry.json`은 namespace 1~15를 각각 한 번 포함한다.

기존 ID·string ID·state를 바꾸지 않는다. 신규 active pair는 다음과 같다.

| namespace | numeric ID | string ID |
|---|---:|---|
| RELIC 11 | 1 | `development_bounty_ledger` |
| CONSUMABLE 12 | 1 | `development_life_flask` |
| SHOP 14 | 1 | `development_shop_profile` |
| EVENT 15 | 1 | `development_event_profile` |

namespace 13 REWARD_PROFILE은 그대로 유지한다. run effect kind는 authored record가 아니라 append-only 코드 enum이므로 registry namespace를 만들지 않는다.

## run effect 계약

### enum

```text
RunEffectKind
  INVALID=0
  GAIN_GOLD=1
  RECOVER_LIFE=2
  GAIN_CONSUMABLE=3
  VICTORY_GOLD_BONUS=4
```

### 값 객체

```text
RunEffectDefinition
  kind_id: uint16
  primary_numeric_id: uint32
  amount: int64
```

| kind | primary | amount | 허용 위치 | 의미 |
|---|---:|---:|---|---|
| GAIN_GOLD | 0 | 1~1,000,000 | event | 현재 gold에 checked 가산 |
| RECOVER_LIFE | 0 | 정확히 1 | consumable | 현재 life가 max보다 작을 때 +1 |
| GAIN_CONSUMABLE | active consumable ID | 1~max stack | event | 정렬 stack 생성 또는 checked 증가 |
| VICTORY_GOLD_BONUS | 0 | 1~1,000,000 | relic | 승리 reward gold에 매번 고정 가산 |

효과 위치별 allowlist를 벗어나면 catalog load가 실패한다. 효과 kind별 primary/amount domain을 조용히 보정하지 않는다. P4-5 effect는 모두 비확률이며 `RUN_EVENT=7` substream을 소비하지 않는다.

## JSON exact schema

모든 object는 표의 exact key만 허용한다. 정수는 strict JSON integer, bool은 JSON bool만 허용한다. numeric/string ref는 active registry pair와 exact 일치해야 한다.

### `relics.json` v2

```json
{
  "schema_version": 2,
  "records": [
    {
      "numeric_id": 1,
      "id": "development_bounty_ledger",
      "effect": {
        "kind_id": 4,
        "primary_numeric_id": 0,
        "amount": 5
      }
    }
  ]
}
```

| 객체 | exact keys |
|---|---|
| root | `schema_version`, `records` |
| relic | `numeric_id`, `id`, `effect` |
| effect | `kind_id`, `primary_numeric_id`, `amount` |

- record는 numeric ID 오름차순·유일이며 RELIC active pair와 1:1이다.
- P4-5 relic effect는 `VICTORY_GOLD_BONUS`만 허용한다.
- 모든 relic은 unique다. 중복·stack field를 schema에 두지 않는다.

### `consumables.json` v2

```json
{
  "schema_version": 2,
  "records": [
    {
      "numeric_id": 1,
      "id": "development_life_flask",
      "max_stack": 3,
      "use_phase_id": 1,
      "effect": {
        "kind_id": 2,
        "primary_numeric_id": 0,
        "amount": 1
      }
    }
  ]
}
```

| 객체 | exact keys |
|---|---|
| root | `schema_version`, `records` |
| consumable | `numeric_id`, `id`, `max_stack`, `use_phase_id`, `effect` |
| effect | 위와 동일 |

- record는 CONSUMABLE active pair와 1:1이다.
- `max_stack`은 1~65,535, `use_phase_id`는 P4-5에서 정확히 MAP_CHOICE(1)다.
- P4-5 consumable effect는 `RECOVER_LIFE`만 허용한다.

### `shops.json` v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "development_shop_profile",
      "offers": [
        {
          "offer_id": 1,
          "item_kind_id": 1,
          "item_ref": {"numeric_id": 1, "id": "development_bounty_ledger"},
          "count": 1,
          "cost": 10
        },
        {
          "offer_id": 2,
          "item_kind_id": 2,
          "item_ref": {"numeric_id": 1, "id": "development_life_flask"},
          "count": 1,
          "cost": 5
        }
      ]
    }
  ]
}
```

`RunShopItemKind`은 `RELIC=1`, `CONSUMABLE=2`다.

| 객체 | exact keys |
|---|---|
| root | `schema_version`, `records` |
| shop | `numeric_id`, `id`, `offers` |
| offer | `offer_id`, `item_kind_id`, `item_ref`, `count`, `cost` |
| item ref | `numeric_id`, `id` |

- profile은 SHOP active pair와 1:1이다.
- offer는 1~7개, `offer_id`는 1부터 연속이다. 배열 순서는 offer ID 의미 순서다.
- RELIC offer는 active relic ref, count 정확히 1을 요구한다.
- CONSUMABLE offer는 active consumable ref, count 1~해당 max stack을 요구한다.
- cost는 1~1,000,000이다. 같은 `(item_kind,item_id)` 중복 offer를 금지한다.
- 8번째 pending 슬롯은 자동 생성되는 LEAVE_SHOP이 사용한다.

### `events.json` v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "development_event_profile",
      "options": [
        {
          "option_id": 1,
          "effects": [
            {"kind_id": 1, "primary_numeric_id": 0, "amount": 5}
          ]
        },
        {
          "option_id": 2,
          "effects": [
            {"kind_id": 3, "primary_numeric_id": 1, "amount": 1}
          ]
        },
        {
          "option_id": 3,
          "effects": []
        }
      ]
    }
  ]
}
```

| 객체 | exact keys |
|---|---|
| root | `schema_version`, `records` |
| event | `numeric_id`, `id`, `options` |
| option | `option_id`, `effects` |
| effect | 위와 동일 |

- profile은 EVENT active pair와 1:1이다.
- option은 1~8개, option ID는 1부터 연속이며 배열 순서를 보존한다.
- effects는 0~1개다. 빈 배열은 명시적 no-op leave option이며 항상 적용 가능하다.
- effect는 `GAIN_GOLD` 또는 `GAIN_CONSUMABLE`만 허용한다.
- profile마다 최소 하나의 항상 적용 가능한 빈 option을 요구해 overflow/full-stack 교착을 막는다.

## typed immutable 데이터 모델

```text
RelicDefinition
  id_ref: ContentIdRef
  effect: RunEffectDefinition

ConsumableDefinition
  id_ref: ContentIdRef
  max_stack: uint16
  use_phase_id: uint16
  effect: RunEffectDefinition

ShopOfferDefinition
  offer_id: uint16
  item_kind_id: uint16
  item_ref: ContentIdRef
  count: uint16
  cost: uint32

ShopDefinition
  id_ref: ContentIdRef
  offers[]: ShopOfferDefinition, offer ID order

EventOptionDefinition
  option_id: uint16
  has_effect: bool
  effect: RunEffectDefinition when present

EventDefinition
  id_ref: ContentIdRef
  options[]: EventOptionDefinition, option ID order
```

모든 object는 `RefCounted`, immutable getter, deep `copy()`를 사용한다. 내부 배열·Dictionary를 노출하지 않는다. generic payload Dictionary나 content string ID 분기를 런 명령에 두지 않는다.

`ContentCatalog`와 `DataDB`는 다음 typed lookup을 추가한다.

```text
relic_count / relic_at / relic_by_numeric_id / relic_by_string_id
consumable_count / consumable_at / consumable_by_numeric_id / consumable_by_string_id
shop_count / shop_at / shop_by_numeric_id / shop_by_string_id
event_count / event_at / event_by_numeric_id / event_by_string_id
```

## catalog 조립·canonical v9

조립 순서:

```text
1) exact file set·catalog document·registry namespace 1~15
2) 기존 P2~P4-4 documents와 typed records
3) relic schema v2 parse와 run effect context 검증
4) consumable schema v2 parse와 run effect/ref 검증
5) shop profile → relic/consumable exact ref 검증
6) event profile → consumable exact ref 검증
7) encounter/reward와 기존 graph content 검증
8) act SHOP/EVENT ref → 실제 shop/event pair·record exact 검증
9) active registry coverage
10) canonical v9 bytes와 SHA-256 계산
11) 모든 단계 성공 후에만 DataDB catalog 교체
```

canonical prefix:

```text
magic "FLICKCAT"
fingerprint_format_version u16 = 9
catalog_schema_version     u16 = 9
registry_schema_version    u16 = 1
namespace_count            u16 = 15
namespace sections         1..15
document_count             u16 = 13   # registry 제외, pieces..events
document sections          kind 2..14
```

- relic/consumable section은 schema 2와 typed record를 encode한다.
- reward profile은 기존 kind 12 schema 1 순서를 유지한다.
- shop kind 13, event kind 14를 뒤에 append한다.
- object key 순서와 record 저작 순서는 fingerprint에 영향을 주지 않는다.
- shop offer와 event option은 ID 의미 순서이므로 loader가 ID를 검증해 정규화한다.
- 정확한 v9 fingerprint와 canonical KAT는 설계값이 아니라 구현 파생값이며 P4-6 누적 검증 기록에 남긴다.

## RunState inventory 계약

### relic

- `_relic_numeric_ids`는 active relic ID 엄격 오름차순·유일이다.
- 보유 수는 `RunLimits.MAX_RELICS=64` 이하다.
- 같은 relic 재획득은 실패하고 gold를 차감하지 않는다.
- relic은 run 종료까지 유지되며 소비·판매 API가 없다.

### consumable

- `_consumable_stacks`는 consumable numeric ID 엄격 오름차순이다.
- stack record는 최대 32개, count는 1~definition max stack이다.
- 첫 획득은 sorted 위치에 record를 삽입하고 이후 획득은 checked 증가한다.
- count가 0이 되면 record를 제거해 zero stack의 이중 정본을 금지한다.

### 공통

- inventory는 MAP_CHOICE·FORMATION·BATTLE·REWARD·SHOP·EVENT·REST·terminal phase에서 보존된다.
- inventory mutation은 SHOP resolve, EVENT resolve, MAP_CHOICE consumable use에서만 일어난다.
- 예약된 revenge boon은 inventory command와 무관하며 비전투 node를 지나도 유지된다.

## SHOP 상태와 명령

### 진입

```text
RunState.choose_shop_node(catalog, node_id, status) -> bool
```

P4-3/P4-4와 같은 next-floor reachability, 미방문, node type SHOP, active shop profile ref를 검증한다. 성공 후보는 node를 visited에 넣고 phase/current floor/current node를 SHOP으로 고정하며 deployment를 비운다.

pending entry:

| 항목 | offer entry | leave entry |
|---|---|---|
| choice ID | offer ID | offer_count+1 |
| kind | TAKE_RELIC 또는 TAKE_CONSUMABLE | LEAVE_SHOP |
| primary | item numeric ID | 0 |
| secondary | 0 | 0 |
| amount | count | 0 |
| cost | authored cost | 0 |
| enabled | 현재 gold·inventory로 구매 가능 | 항상 true |

pending kind는 SHOP, source는 current node, generation ordinal은 `next_transition_sequence`다. fixed offer이므로 RNG draw나 stock reroll이 없다.

### 해결

```text
RunState.resolve_shop(catalog, choice_id, status) -> bool
```

1. SHOP phase와 pending source/ordinal/profile exact를 검증한다.
2. selected entry가 enabled이고 profile offer 또는 leave와 exact 일치하는지 확인한다.
3. 구매면 후보 사본에서 gold를 차감하고 item을 추가한다.
4. leave면 inventory/gold를 바꾸지 않는다.
5. node를 completed에 추가하고 pending/current node를 비워 MAP_CHOICE로 commit한다.

상점 node에서는 consumable 사용 등 별도 mutation을 금지하므로 pending enabled가 생성 뒤 stale해지지 않는다. resolve 재호출·다른 choice·disabled 구매는 실패하고 원본을 유지한다.

## EVENT 상태와 명령

### 진입

```text
RunState.choose_event_node(catalog, node_id, status) -> bool
```

next-floor reachability, 미방문, node type EVENT, active event profile ref를 검증한다. 성공 후보는 EVENT phase와 fixed pending을 만든다.

EVENT_OPTION payload:

```text
choice_id = authored option_id
primary_numeric_id = effect kind_id, effect 없음은 0
secondary_numeric_id = effect primary_numeric_id, effect 없음은 0
amount = effect amount, effect 없음은 0
cost = 0
enabled = 현재 state에서 effect 전체 적용 가능
```

빈 effect option은 항상 enabled다. gold overflow나 consumable full stack이면 해당 effect option만 disabled다.

### 해결

```text
RunState.resolve_event(catalog, choice_id, status) -> bool
```

selected entry와 profile option을 exact 비교하고 후보 사본에 effect를 적용한다. 성공하면 node를 completed에 추가해 MAP_CHOICE로 돌아간다. 선택은 한 번뿐이며 이벤트 재진입·재추첨 API는 없다.

## 소모품 사용

```text
RunState.use_consumable(catalog, consumable_numeric_id, status) -> bool
```

- phase는 정확히 MAP_CHOICE, current node 0, pending NONE이어야 한다.
- active consumable definition과 보유 stack count를 확인한다.
- `use_phase_id`와 effect allowlist를 다시 확인한다.
- life가 max면 실패하며 stack을 줄이지 않는다.
- 후보 사본에서 life +1을 적용한 뒤 stack을 1 감소하고 0이면 record를 제거한다.
- boon, roster, graph, node history, next transition sequence는 바꾸지 않는다.

P4-6 UI는 MAP_CHOICE에서 보유 소모품과 사용 가능 여부를 표시한다. 전투 중·FORMATION·SHOP·EVENT·REST에서는 버튼을 비활성화하고 core 명령도 실패한다.

## 유물과 승리 reward 연결

P4-4 `prepare_reward`의 승리 gold 계산을 다음처럼 확장한다.

```text
bonus = 0
for relic_id in relic_numeric_ids ascending:
  definition = catalog.relic(relic_id)
  effect must be VICTORY_GOLD_BONUS
  bonus = checked_add(bonus, effect.amount)

award = checked_add(profile.victory_gold, bonus)
candidate.gold = checked_add(candidate.gold, award)
```

- 패배/DRAW에는 victory gold와 relic bonus가 없다.
- reward 준비 성공 후보에서 한 번만 지급된다.
- bonus overflow는 base gold와 pending 생성까지 포함한 reward 전체를 rollback한다.
- `development_bounty_ledger`는 획득 뒤의 전투 승리부터 +5를 적용하며 과거 reward를 소급하지 않는다.

## phase·node 완료 불변식

| phase | current node | deployment | pending | inventory | boon |
|---|---|---|---|---|---|
| MAP_CHOICE | 0 | empty | NONE | 허용 | 유지 가능 |
| SHOP | SHOP node, visited·미완료 | empty | SHOP | 허용 | 유지 가능 |
| EVENT | EVENT node, visited·미완료 | empty | EVENT | 허용 | 유지 가능 |
| 다른 기존 phase | 기존 P4-4 계약 | 기존 계약 | 기존 계약 | 허용 | 기존 계약 |

- SHOP/EVENT resolve 성공 시 current node가 completed에 sorted unique로 추가된다.
- current floor/node는 0, pending NONE, phase MAP_CHOICE가 된다.
- `next_transition_sequence`는 전투 request sequence이므로 비전투 node에서 증가시키지 않는다.
- SHOP/EVENT content ID는 현재 Act option membership과 실제 catalog profile 양쪽에 exact 일치해야 한다.

## RunSnapshot v2 이관

바이트 layout과 schema 번호는 바꾸지 않는다.

```text
relic_count:u16
relic_numeric_ids[relic_count]:u32 sorted unique

consumable_count:u16
repeat:
  consumable_numeric_id:u32 sorted
  stack_count:u16 > 0

pending choice section
next_battle_status_numeric_id:u32
exact EOF
```

변경되는 restore 의미:

1. relic ID는 active relic record여야 한다.
2. consumable ID는 active definition이고 count가 max stack 이하여야 한다.
3. SHOP/EVENT phase와 pending payload를 source profile과 exact 비교한다.
4. SHOP/EVENT capture를 허용한다. BATTLE capture 금지는 유지한다.
5. legacy v1 decode는 boon 0으로 유지하며 inventory는 현재 v9 fingerprint/definition 검증을 통과해야 한다.

catalog v9 fingerprint 변경 때문에 v8 snapshot은 자동 migration하지 않는다. schema가 같더라도 fingerprint mismatch는 기존 계약대로 실패한다.

## 결정론·원자성

- 모든 core type은 `RefCounted`이며 `Node`, `Time`, `FileAccess`, Godot RNG를 호출하지 않는다.
- fixed shop/event profile은 RNG를 소비하지 않는다. getter·UI 재진입·snapshot capture도 draw가 없다.
- catalog record, relic ID, consumable stack은 numeric ID 안정 순서로 순회한다.
- shop offer와 event option은 연속 authored ID 순서를 정본으로 사용한다.
- 모든 공개 command는 RunState 후보 사본에서 전체 검증·checked mutation 후 한 번에 commit한다.
- gold·life·stack·count overflow를 clamp하지 않는다.
- content numeric ID별 `match`나 string ID별 특수 분기를 금지하고 effect kind로만 동작한다.
- invalid phase/node/ref/choice/cost/effect/inventory는 first-error-wins이며 호출 전 snapshot bytes를 유지한다.
- fingerprint와 snapshot hash를 RNG seed나 게임 판정에 사용하지 않는다.

## 공학 한도

| 항목 | 한도 |
|---|---:|
| relic definition | 256 |
| consumable definition | 256 |
| shop profile | 256 |
| event profile | 256 |
| 보유 relic | 기존 64 |
| consumable stack record | 기존 32 |
| consumable count/stack | definition별 1~65,535 |
| shop offer/profile | 1~7 |
| event option/profile | 1~8 |
| effect/item 또는 option | relic·consumable 정확히 1, event 0~1 |
| effect amount | kind별 위 domain, gold 계열 최대 1,000,000 |
| offer cost | 1~1,000,000 |
| pending entry | 기존 8 |

## 진단 계약

기존 번호를 바꾸지 않고 끝에 append한다.

### ContentStatus Operation

```text
17 RELIC_VALIDATE
18 CONSUMABLE_VALIDATE
19 SHOP_VALIDATE
20 EVENT_VALIDATE
21 RUN_EFFECT_VALIDATE
```

### ContentStatus FieldId

```text
107 MAX_STACK_COUNT
108 USE_PHASE_ID
109 EFFECT
110 PRIMARY_NUMERIC_ID
111 AMOUNT
112 OFFERS
113 OFFER_ID
114 ITEM_KIND_ID
115 ITEM_REF
116 COUNT
117 COST
118 OPTION_ID
```

기존 `EFFECT_KIND_ID=33`, `EFFECTS=32`, `OPTIONS=96`은 의미가 같은 위치에서 재사용한다.

### SimStatus Code

```text
76 INVALID_RUN_INVENTORY
77 INVALID_RUN_SHOP
78 INVALID_RUN_EVENT
79 INVALID_RUN_EFFECT
```

### SimStatus Operation

```text
166 RUN_EFFECT_APPLY
167 RUN_INVENTORY_VALIDATE
168 RUN_SHOP_CHOOSE
169 RUN_SHOP_RESOLVE
170 RUN_EVENT_CHOOSE
171 RUN_EVENT_RESOLVE
172 RUN_CONSUMABLE_USE
```

detail은 command 기준으로 고정한다.

| operation | detail_a | detail_b |
|---|---|---|
| effect apply | effect kind | primary ID 또는 amount |
| inventory validate | item numeric ID | count 또는 ceiling |
| shop choose/resolve | node ID 또는 choice ID | profile/offer ID |
| event choose/resolve | node ID 또는 choice ID | profile/option ID |
| consumable use | consumable ID | 현재 count 또는 life |

## 공개 API

```text
RunEffectDefinition.create(kind_id, primary_numeric_id, amount, status)

RelicDefinition / ConsumableDefinition / ShopOfferDefinition /
ShopDefinition / EventOptionDefinition / EventDefinition
  create(..., ContentStatus)
  copy()
  typed getters

RunState.choose_shop_node(catalog, node_id, status) -> bool
RunState.resolve_shop(catalog, choice_id, status) -> bool
RunState.choose_event_node(catalog, node_id, status) -> bool
RunState.resolve_event(catalog, choice_id, status) -> bool
RunState.use_consumable(catalog, consumable_numeric_id, status) -> bool
```

generic `resolve_nonbattle(Dictionary)`나 inventory setter를 제공하지 않는다. UI는 pending과 catalog의 불변 사본을 읽고 위 의미별 command만 호출한다.

## 대상 파일

### 신규

```text
docs/specs/p4_relic_consumable_shop_event.md
src/core/data/run_effect_definition.gd
src/core/data/relic_definition.gd
src/core/data/consumable_definition.gd
src/core/data/shop_offer_definition.gd
src/core/data/shop_definition.gd
src/core/data/event_option_definition.gd
src/core/data/event_definition.gd
src/core/data/shops.json
src/core/data/events.json
src/core/run/run_effect_kind.gd
src/core/run/run_shop_item_kind.gd
```

### 수정

```text
docs/specs/p4_run_loop.md
src/core/data/relics.json
src/core/data/consumables.json
src/core/data/acts.json                 # pair 값은 유지, external ref 검증만 승격
src/core/data/catalog.json
src/core/data/id_registry.json
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_status.gd
src/core/data/content_catalog.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/autoload/data_db.gd
src/core/run/run_choice_kind.gd
src/core/run/run_state.gd
src/core/run/run_snapshot.gd
src/core/sim/sim_status.gd
pipeline/scripts/content_catalog.py
AGENTS.md
HANDOFF.md
```

P4-5 전용 runner·fixture·JSON schema 파일과 기존 fixture의 catalog v9 이관은 P4-I18에 따라 P4-6 누적 검증 작업에 포함한다. production loader와 독립 Python catalog parser는 구현 시 함께 v9로 올려 런타임 계약이 갈라지지 않게 한다.

## 필요 에셋

없음. P4-5는 core와 runtime JSON만 변경한다. P4-6 graybox UI는 item string ID와 기존 폰트·도형을 사용한다. 신규 파일 이미지·음원이 필요해질 때만 별도 승인과 manifest 계약을 따른다.

## 수용 기준 — P4-6 누적 실행

1. document kind 13~14, namespace 14~15, effect/item/choice/status enum이 기존 끝에 append된다.
2. catalog v9이 정확한 15개 JSON 파일, kind 1~14, namespace 1~15를 요구한다.
3. relic/consumable v1 non-empty와 v2 unknown/missing/type/range/ref 오류가 atomic load 실패한다.
4. shop/event의 local pair, active registry pair, actual record가 numeric/string 양쪽 exact 일치한다.
5. effect context allowlist와 kind별 primary/amount domain 위반이 실패한다.
6. relic/consumable/shop/event typed copy·lookup이 내부 배열을 노출하지 않는다.
7. canonical v9 Godot bytes/fingerprint가 독립 Python KAT와 일치한다.
8. record/key 순서 교란은 fingerprint를 바꾸지 않고 offer/option 의미 변경은 바꾼다.
9. invalid reload 뒤 기존 DataDB catalog와 fingerprint가 유지된다.
10. runtime이 relic·consumable·shop·event 각각 1개와 exact 수치/refs를 조회한다.
11. SHOP node 진입이 10/5 gold offer와 leave를 exact pending으로 고정한다.
12. gold 부족, relic 보유, consumable full stack에서 해당 offer만 disabled이고 leave는 enabled다.
13. relic 구매는 gold 10을 차감하고 sorted unique inventory에 한 번만 추가한다.
14. consumable 구매는 gold 5를 차감하고 stack을 생성/증가시키며 max를 넘지 않는다.
15. leave는 gold/inventory를 바꾸지 않고 node만 완료한다.
16. EVENT node가 gold +5, flask +1, leave 세 option을 exact pending으로 만든다.
17. event gold overflow·full stack option은 disabled이며 leave로 항상 진행 가능하다.
18. event resolve가 effect를 한 번만 적용하고 node를 완료한다.
19. MAP_CHOICE life flask 사용이 life +1, stack −1을 적용하고 zero stack을 제거한다.
20. max life·미보유·다른 phase 사용 실패가 item을 소비하지 않는다.
21. 현상금 장부 획득 뒤 승리 reward가 normal/elite/boss base에 정확히 +5를 더한다.
22. 패배/DRAW와 장부 획득 전 과거 승리에는 relic bonus가 없다.
23. gold/stack overflow와 duplicate relic이 관련 command 전체를 rollback한다.
24. SHOP/EVENT 완료와 소모품 사용이 revenge boon·next transition sequence를 바꾸지 않는다.
25. non-empty inventory와 SHOP/EVENT pending이 RunSnapshot v2 roundtrip/restore 뒤 exact다.
26. legacy v1은 boon 0으로 복원되고 v9 catalog 의미 검증을 따른다.
27. BATTLE capture 금지는 유지되고 SHOP/EVENT capture가 열린다.
28. 모든 stale/disabled/wrong phase/node/profile/choice 실패에서 호출 전 snapshot bytes가 유지된다.
29. P4-1~5 narrow, catalog/fingerprint KAT, P1~P3 대표 회귀가 통과한다.
30. quick 4런과 Godot 4.6.3 `verify --demo`가 P4-6에서 통과한다.
31. milestone route가 SHOP·EVENT 양쪽과 relic 구매·consumable 획득/사용을 한 번 이상 덮는다.
32. `verify --full`, exhaustive repeats와 플랫폼 교차 결정론은 정식 release profile에서 수행한다.

## 빠른 구현 순서 — 전체 승인 뒤

1. append-only enum·schema·diagnostic과 production Python parser/canonical v9를 먼저 맞춘다.
2. run effect와 relic/consumable typed definition·runtime record를 구현한다.
3. shop/event typed profile과 Act local pair의 external exact ref 검증을 구현한다.
4. ContentCatalog/DataDB lookup과 canonical v9 section을 연결한다.
5. RunState의 inventory 의미 검증·효과 적용 helper를 연다.
6. SHOP/EVENT 진입·pending·resolve와 소모품 사용 command를 구현한다.
7. P4-4 승리 gold에 relic bonus를 연결한다.
8. RunSnapshot v2의 SHOP/EVENT capture와 inventory/pending restore gate를 연다.
9. 최소 Godot import와 코드 리뷰만 수행하고 구현 상태를 P4-6 누적 검증 대기로 기록한다.
10. P4-6 UI·save·runner를 구현한 뒤 수용 기준을 묶어서 실행한다.

## 승인 기록

2026-08-25 사용자가 P4-I01~18과 전체 명세를 승인했다. catalog v9, 개발용 콘텐츠 값, 상점·이벤트 고정 선택, RunSnapshot v2 유지와 P4-6 누적 검증 이연을 구현 기준으로 고정한다.

## 구현 기록

2026-08-25 catalog/fingerprint v9, relic/consumable schema v2, shop/event schema v1과 typed immutable model을 구현했다. 개발 현상금 장부·생명 플라스크·고정 상점·고정 이벤트를 runtime JSON에 추가하고, Act local pair를 실제 catalog record와 exact 검증하도록 승격했다.

RunState에는 SHOP/EVENT 진입·고정 pending·원자 resolve, sorted unique relic, bounded consumable stack, MAP_CHOICE 소모품 사용과 승리 reward 유물 보너스를 연결했다. RunSnapshot v2 layout은 유지하면서 non-empty inventory 및 SHOP/EVENT capture·restore 의미 검증을 열었다.

독립 Python production parser의 runtime v9 로드와 최소 Godot 4.6.3 import/headless 시작은 통과했다. P4-5 전용 runner, canonical cross-KAT, quick 4런, 대표 회귀와 `verify --demo`는 P4-I18에 따라 P4-6 누적 검증 대기로 남긴다.
