# P4-4 · 영입·골드·휴식·합성·보복 보상 상세 명세

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 상위 승인 | `p4_run_loop.md` P4-R01~17 |
| 선행 구현 | P4-1 `RunState`·`RunSnapshot`, P4-2 reward profile ID 슬롯, P4-3 전투 결과·라이프·REWARD handoff |
| 후속 단계 | P4-5 유물·소모품·상점·이벤트, P4-6 런 UI·저장·축약 Act 완주 |
| 승인 | **2026-08-25 사용자 전체 승인** |
| 구현 권한 | **있음. P4-RD01~18 범위 구현 가능** |
| 검증 정책 | P4-4 구현 중 대규모 검증을 실행하지 않고 P4 전체 구현 뒤 P4-6에서 통합 수행 |

## 목적

P4-3의 저장 가능한 `REWARD` handoff를 실제 런 성장으로 연결한다. 승리하면 encounter의 reward profile에서 골드와 고정된 기물 영입 후보를 만들고, 패배/DRAW 뒤 라이프가 남으면 다음 전투 1회용 보복 강화를 받는다. 휴식 node에서는 라이프 회복 또는 한 번의 기물 합성을 선택한다.

이 단계의 완료 경계는 다음과 같다.

1. 전투 결과 뒤 보상이 동일 seed·직전 편성에서 고정된다.
2. 영입·골드·보복 효과·회복·합성이 원자적으로 RunState에 반영된다.
3. 완료된 전투/휴식 node에서 다음 node 선택 또는 `ACT_COMPLETE`로 진행할 수 있다.
4. P4-5가 소유하는 유물·소모품·상점·이벤트를 발명하지 않는다.

사용자의 일정 지시에 따라 P4-4 단독 반복·회귀·`verify` 실행은 완료 조건으로 두지 않는다. 검증 부채와 최종 수용 기준은 문서에 고정하되 실제 실행은 P4-5·6 구현 뒤 한 번에 수행한다.

## 정본과 선행 계약

- `docs/design/game_design.md` D-05·09·12·14·18·24~27, 7.8·7.9, 9.2·9.6·9.7, 10.1~10.4, 14.1·14.4
- `docs/specs/p4_run_loop.md` P4-R03·06~14·16~17
- `docs/specs/p4_run_state_snapshot.md` P4-S02·04~11과 pending choice 고정 슬롯
- `docs/specs/p4_act_encounter_map_generation.md` P4-G06·09·12·15와 encounter reward profile ID
- `docs/specs/p4_formation_battle_outcome_life.md` P4-B10~17과 승리/패배 REWARD 구분
- P2 strict catalog, canonical fingerprint, status/modifier, synergy tally

그대로 유지하는 기준:

1. 중복 보유는 허용하고 roster instance ID는 제거 뒤 재사용하지 않는다.
2. 합성 결과는 두 재료 중 작은 instance ID를 승계한다.
3. 출전 수는 최소 3이며 합성으로 roster가 3기 미만이 되는 선택은 금지한다.
4. 승리 node는 이미 completed, 패배/DRAW node는 보복 보상 완료 전까지 visited·미완료다.
5. 전투 중 저장은 금지하고 node 결과 commit 뒤 저장은 허용한다.
6. 영입 후보는 직전 전투에서 활성화한 태그를 기준으로 가중한다.
7. 개발 Act에서는 roster 상한 전 영입을 강제하고 상한이면 대체 보상 없이 건너뛴다.
8. 휴식은 회복 또는 한 번의 합성만 제공하고 세 번째 선택지는 UI에서 잠금 표시한다.

## 선행 승인과의 이관 지점

### REWARD에서 직전 편성 보존

P4-3은 outcome 적용 시 deployment를 즉시 비웠다. 그러나 P4-R12의 영입 가중치는 **직전 편성**을 입력으로 요구하므로 현재 상태만으로는 정확히 재구성할 수 없다.

P4-RD06은 새 배열을 추가하지 않고 기존 `deployment_instance_ids`를 짧게 재사용한다.

- outcome commit 직후 `REWARD + pending NONE`에서는 직전 편성을 유지한다.
- `prepare_reward`가 후보와 골드를 원자적으로 고정하면서 deployment를 비운다.
- `REWARD + pending REWARD`와 reward 완료 뒤에는 deployment가 비어 있다.
- life 0 `RUN_FAILED`는 기존처럼 즉시 deployment를 비운다.

보존되는 값은 run instance ID뿐이다. HP·status·body ID·transform 등 전투 상태는 계속 폐기하므로 D-12와 충돌하지 않는다. 이 변경은 P4-B15의 handoff를 확장하고 P4-B10~14의 결과 의미는 바꾸지 않는다.

### 다음 전투 보복 효과 저장

`RunSnapshot` v1에는 다음 전투 1회 효과를 보존할 타입이 없다. relic·consumable 슬롯을 임시로 오용하면 P4-5의 정본과 충돌한다.

P4-RD14는 `next_battle_status_numeric_id:u32`를 RunState에 추가하고 `RunSnapshot`을 v2로 올린다. legacy v1은 이 값을 0으로 복원한다. 이 명시적 schema 상승은 P4-S02의 “후속 필드 선점” 의도와 충돌하지만, 의미가 다른 inventory/pending 슬롯을 오용하지 않는 쪽을 권장한다.

## 범위

- strict `reward_profiles.json` v1과 typed immutable `RewardProfileDefinition`
- append-only catalog/document/namespace와 canonical fingerprint v8
- encounter reward profile exact 교차 검증
- 승리 골드 자동 지급과 영입 후보 생성
- 직전 편성 활성 태그 기반 integer weight
- 고정된 `RunPendingChoice.REWARD`와 강제 영입 적용
- roster cap·instance ID·level 1 신규 instance 생성
- 패배/DRAW 보복 reward와 다음 전투 1회 상태
- `RunBattleRequest`의 opening status와 bridge 적용/소비
- 휴식 node 진입, 회복 또는 1회 합성
- 작은 instance ID 승계, level 상한 3, run counter 병합
- 개발 기물 2종의 level 2·3 graybox 데이터
- reward/rest 완료 뒤 `MAP_CHOICE` 또는 `ACT_COMPLETE`
- RunSnapshot v2와 legacy v1 decode
- 오류의 후보 사본 rollback과 first-error-wins

## 비범위

- 유물·소모품 record와 지급/사용
- 상점 가격·재고·구매·새로고침
- 이벤트 profile과 선택 효과
- 정식 경제·드롭률·보상 밸런스
- 영입 스킵·기물 방출·상한 대체 보상
- 휴식의 세 번째 선택지와 한 node 다중 합성
- 합성 고유 능력, 41종 level 2·3 정식 콘텐츠
- 용의 알/폰/도플갱어의 영구 transform
- 여러 종류의 보복 boon과 중첩
- RunManager·SaveManager·런 UI·씬·manifest
- 정식 3막 및 P4-5/6 기능
- P4-4 단독 대규모 자동 검증 실행

## 용어

| 용어 | 정의 |
|---|---|
| reward profile | 전투 승리 골드·영입 수·영입 pool·패배 보복 status를 묶은 data record |
| reward 준비 | P4-3의 `REWARD + pending NONE`에서 골드와 고정 후보를 한 번 생성하는 command |
| 직전 편성 | 방금 종료된 전투 request의 player slot 순 run instance ID 배열 |
| 활성 태그 | 직전 편성으로 P2 synergy 최소 발동 계수 2 이상에 도달한 tag |
| 미중복 수 | 같은 piece numeric ID를 여러 개 편성해도 1개로 세는 distinct piece 종류 수 |
| 보복 status | 패배/DRAW reward로 예약되어 다음 전투 한 번 동안 출전 아군에 적용되는 battle-duration status |
| 합성 가능 쌍 | 같은 piece ID·같은 level 1~2이며 catalog에 다음 level이 존재하는 두 instance |

## 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P4-RD01 | `reward_profiles.json`을 document kind 12, namespace 13으로 append하고 catalog/fingerprint를 v8로 올린다 | P4-G12의 opaque reward ID를 데이터 주도로 해소 | ✅ 승인 |
| P4-RD02 | 개발 profile 1/2/3을 normal/elite/boss로 고정하고 승리 골드를 각각 10/20/30, 영입 후보 수 2, pool을 `baduk_stone`·`bottle_cap`으로 둔다 | 경제 최종값이 아닌 빠른 graybox 진행값이며 기존 runtime 2종만 재사용 | ✅ 승인 |
| P4-RD03 | 승리 골드는 `prepare_reward`에서 자동 지급하고 `GAIN_GOLD` 선택지를 만들지 않는다. 영입만 pending 선택으로 남긴다 | “기물 영입 기본 포함 + 골드”를 한 선택으로 오인하지 않게 하고 중복 지급 방지 | ✅ 승인 |
| P4-RD04 | roster가 cap 미만이면 서로 다른 후보 2개 중 하나를 반드시 영입한다. cap이면 골드만 지급하고 영입 pending 없이 reward를 자동 완료한다 | P4-R13의 강제 영입·상한 시 skip 계약 구현 | ✅ 승인 |
| P4-RD05 | 후보 weight는 `1 + Σ(후보와 일치하는 활성 태그별 직전 편성 미중복 piece 수)`이며 weighted without replacement로 choice 순서를 만든다 | P4-R12의 태그 가중식을 모호성 없이 정수화 | ✅ 승인 |
| P4-RD06 | outcome 직후 REWARD/pending NONE에서만 기존 deployment 배열에 직전 편성을 보존하고 reward 준비 성공 시 비운다 | 별도 last-deployment snapshot 필드 없이 가중치 입력 보존 | ✅ 승인 |
| P4-RD07 | reward RNG는 `RUN_REWARD=6`, owner=`act_numeric_id`, ordinal=`node_id`의 비소비 stream을 쓰고 pending ordinal은 직전 request sequence다 | UI 재조회·저장 복원·다른 RNG draw와 독립 | ✅ 승인 |
| P4-RD08 | 영입 instance는 level 1·빈 counter로 `next_piece_instance_id`를 받고 성공 commit에서만 checked 증가한다 | 중복 보유와 ID 비재사용 보장 | ✅ 승인 |
| P4-RD09 | 합성 counter는 kind별 두 값의 `max`를 승계한다. 합으로 부풀리지 않고 더 진행된 이력을 잃지 않는다 | KILLS·BATTLES_SURVIVED 양쪽에 적용 가능한 최소 일반 규칙 | ✅ 승인 |
| P4-RD10 | 개발 2종의 L2/L3은 L1 대비 HP·공격력만 +25%/+50%로 반올림하고 나머지 스탯·태그·능력은 유지한다 | 합성이 실제 강화로 보이게 하되 신규 능력 설계를 피함 | ✅ 승인 |
| P4-RD11 | REST pending은 회복과 합성 mode 두 entry만 저장한다. 세 번째 잠금은 P4-6 UI가 비권위 표시하고 snapshot entry로 만들지 않는다 | P4-R14 준수와 pending 8개 ceiling 유지 | ✅ 승인 |
| P4-RD12 | 회복은 life<max일 때만 +1, 합성은 caller가 지정한 exact 두 instance를 검증해 한 번만 수행한다. 둘 다 불가능하면 REST를 자동 완료한다 | 모든 합성 쌍을 pending에 열거해 ceiling을 넘기는 문제 방지 | ✅ 승인 |
| P4-RD13 | 패배/DRAW reward는 `TAKE_REVENGE=8` 한 entry이며 수락 시 다음 전투 모든 아군에게 battle-duration `development_revenge`를 적용한다. 효과는 주는 피해 +25%다 | U-14를 기존 status/modifier 경계로 가장 작게 구현 | ✅ 승인 |
| P4-RD14 | RunState에 `next_battle_status_numeric_id`를 추가하고 RunSnapshot v2 끝에 u32로 저장한다. legacy v1은 0으로 복원한다 | 보복 효과의 저장·이어하기 정본 확보 | ✅ 승인 |
| P4-RD15 | `begin_battle`은 boon을 request에 복사한 뒤 RunState에서 소비하고, bridge는 build된 첫 행동 전 상태의 player initial body 모두에 self-source status를 원자 적용한다 | pre-battle save 재시작은 같은 boost를 만들고 한 battle에만 적용 | ✅ 승인 |
| P4-RD16 | 일반/엘리트 reward와 REST 완료는 completed 뒤 `MAP_CHOICE`, boss 승리는 `ACT_COMPLETE`로 간다. boss 패배/DRAW 보복 수락은 예외적으로 같은 boss의 `FORMATION`으로 직접 돌아가 재도전한다 | outgoing edge가 없는 boss에서 남은 라이프와 보복 boon이 무효가 되는 교착 방지 | ✅ 승인 |
| P4-RD17 | 모든 공개 command는 후보 사본에서 catalog·phase·choice·overflow를 검증한 뒤 한 번에 commit한다 | 기존 run 원자성·first-error-wins 유지 | ✅ 승인 |
| P4-RD18 | P4-4/5 구현 중 runner·반복·대표 회귀·`verify` 실행을 생략하고, P4-6에서 P4-1~6 narrow·4런·`verify --demo`를 묶어 수행한다. 구현 중에는 코드 리뷰와 로드 불가 방지용 최소 import만 허용한다 | 시간 제약에 따라 검증 중복을 없애고 빠른 전체 루프 구현 우선 | ✅ 승인 |

## reward profile 데이터

### append-only ID

```text
ContentIds.DocumentKind.REWARD_PROFILES = 12
ContentIds.Namespace.REWARD_PROFILE = 13
ContentIds.REWARD_PROFILES_FILE = "reward_profiles.json"
ContentIds.REWARD_PROFILES_SCHEMA_VERSION = 1
ContentIds.CATALOG_SCHEMA_VERSION = 8
ContentIds.FINGERPRINT_FORMAT_VERSION = 8
```

`expected_json_files()`는 기존 12개에 `reward_profiles.json`을 더한 정확한 13개다. `catalog.json.documents`와 `id_registry.json`은 active reward profile pair를 exact 포함한다.

### `reward_profiles.json` v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "development_normal_reward",
      "victory_gold": 10,
      "recruit_choice_count": 2,
      "recruit_pool_refs": [
        {"numeric_id": 1, "id": "baduk_stone"},
        {"numeric_id": 2, "id": "bottle_cap"}
      ],
      "revenge_status_ref": {"numeric_id": 2, "id": "development_revenge"}
    }
  ]
}
```

profile 2 `development_elite_reward`와 profile 3 `development_boss_reward`는 같은 pool·choice count·revenge status를 사용하고 `victory_gold`만 각각 20·30이다.

exact key와 domain:

1. record는 numeric ID 엄격 오름차순이며 active registry pair와 1:1이다.
2. `victory_gold`는 0~1,000,000의 정수다. RunState 적용 시 uint32 checked add를 다시 수행한다.
3. `recruit_choice_count`는 1~8이며 pool 크기 이하다.
4. pool은 numeric ID 엄격 오름차순·유일한 1~64개 active piece ref다.
5. pool piece는 non-token이고 level 1이 존재해야 한다.
6. `revenge_status_ref`는 active status pair이며 duration kind `BATTLE`, modifier가 하나 이상이어야 한다.
7. 모든 encounter의 `reward_profile_numeric_id`는 active profile pair를 가리켜야 한다.

### `development_revenge`

`statuses.json` schema 1에 numeric ID 2를 append한다.

```text
stack policy: SINGLE
max stacks: 1
duration: BATTLE
refresh: KEEP
merge sources: true
modifier: DAMAGE_OUTGOING_RATIO_BONUS ADD +2500 basis points
```

전투 종료와 함께 status가 폐기되므로 D-12와 일치한다. 중첩은 지원하지 않는다.

## 개발 기물 level 2·3

schema를 올리지 않고 `pieces.json`의 기존 level 배열에 append한다.

| piece | L1 HP/ATK | L2 HP/ATK | L3 HP/ATK |
|---|---:|---:|---:|
| baduk_stone | 100 / 20 | 125 / 25 | 150 / 30 |
| bottle_cap | 90 / 24 | 113 / 30 | 135 / 36 |

- speed, mass, radius, friction, critical, ability refs는 각 L1과 같다.
- level 배열은 1·2·3 연속이다.
- +25%에서 정확히 .5인 bottle cap HP는 프로젝트 반올림 원칙에 따라 113이다.
- 이 값은 P4 개발 graybox용이며 정식 41종 level 수치·고유 효과를 확정하지 않는다.

## 영입 후보 생성

### 입력

- current phase `REWARD`
- pending `NONE`
- life > 0
- current node는 battle node이며 visited
- deployment에는 방금 전투의 exact run instance ID가 slot 순으로 남아 있음
- completed 포함 여부로 승리/패배를 구분

### 활성 태그와 weight

1. deployment instance를 piece ID·level로 해석한다.
2. P2 시너지 tally 규칙으로 태그별 계수를 계산한다. 테마는 level, 역할군은 instance당 1을 기여한다.
3. 계수 2 이상인 tag만 활성으로 본다.
4. 각 활성 tag마다 그 tag를 가진 서로 다른 `piece_numeric_id` 수를 센다. 같은 piece 중복은 1이다.
5. 후보 piece의 tag마다 해당 활성 tag의 미중복 수를 더한다.

```text
weight(candidate) = 1
for tag in candidate.tags numeric ID order:
  if tag is active:
    weight += distinct deployed piece count with tag
```

모든 합산은 uint64 의미 범위에서 checked하고 `SimRng.range_u32`가 받는 범위로 검증한다. 후보는 pool numeric ID 순으로 만든 뒤 weighted draw 결과 순서로 pending에 저장한다. 한 번 뽑은 piece는 같은 화면에서 제거해 중복 choice를 금지한다.

현재 pool이 정확히 두 종이고 choice도 2개라 두 후보는 항상 모두 나오며 RNG는 표시 순서만 바꾼다. 알고리즘은 pool 확장 뒤에도 코드 변경 없이 작동한다.

### pending payload

```text
pending kind: REWARD
source_node_id: current node
generation_ordinal: next_transition_sequence - 1

각 recruit entry:
choice_kind_id = RECRUIT_PIECE
primary_numeric_id = candidate piece ID
secondary_numeric_id = 0
amount = 1
cost = 0
enabled = true
```

골드는 pending entry가 아니다. reward 준비 성공 상태의 RunState.gold에 이미 반영되어 있다.

## reward 상태 전이

```text
REWARD + pending NONE
  ├─ 승리, roster < cap ─ prepare_reward → REWARD + recruit pending
  ├─ 승리, roster = cap ─ prepare_reward → gold 지급 → node 종료
  └─ 패배/DRAW         ─ prepare_reward → REWARD + revenge pending

REWARD + recruit pending
  └─ choose_reward(choice_id) → level 1 instance 추가 → node 종료

REWARD + revenge pending
  └─ choose_reward(choice_id) → next battle status 예약
       ├─ 일반/엘리트 → completed 추가 → MAP_CHOICE
       └─ final boss   → incomplete 유지 → 같은 boss FORMATION
```

`prepare_reward`는 한 번만 성공한다. pending이 이미 있거나 reward가 끝난 상태에서 재호출하면 원본 bytes를 유지하고 실패한다.

### 골드

- 승리에서만 profile의 `victory_gold`를 자동 가산한다.
- 패배/DRAW는 골드를 주지 않는다.
- uint32 overflow는 reward 전체를 rollback한다.
- roster cap으로 영입이 생략돼도 골드는 지급한다.
- 기존 `RunChoiceKind.GAIN_GOLD=4`는 P4-5 이벤트/상점의 명시적 선택용 예약값으로 남긴다.

### 영입

- 선택 entry가 현재 pending의 enabled recruit entry와 exact 일치해야 한다.
- roster cap을 선택 시점에 다시 검사한다.
- 새 instance는 selected piece, level 1, 빈 counter를 갖는다.
- instance ID는 `_next_piece_instance_id`이며 성공 후보에서만 +1한다.
- roster는 instance ID 오름차순을 유지한다.
- 영입 스킵 command는 없다.

## 패배/DRAW 보복 reward

pending entry:

```text
choice_kind_id = TAKE_REVENGE(8)
primary_numeric_id = development_revenge status numeric ID
secondary_numeric_id = 0
amount = 1
cost = 0
enabled = true
```

수락하면:

1. `next_battle_status_numeric_id`가 0인지 확인한다.
2. profile의 status pair와 exact 일치하는지 확인한다.
3. status ID를 RunState에 저장한다.
4. 일반/엘리트면 current node를 completed에 추가하고, final boss면 incomplete로 유지한다.
5. pending과 직전 deployment를 비운다.
6. 일반/엘리트는 `MAP_CHOICE`, final boss는 같은 node의 `FORMATION`으로 전환한다.

같은 battle에서 기존 boon은 `begin_battle` 때 이미 소비되므로 보복 reward끼리 중첩되지 않는다. 사이에 SHOP/EVENT/REST를 지나더라도 boon은 다음 실제 battle까지 유지된다.

## 다음 전투 boon 연결

### RunBattleRequest 이관

```text
opening_status_numeric_id: uint32   # 0 또는 active battle-duration status
```

request create/copy/getter와 build exact 검증에 포함한다.

`RunState.begin_battle` 성공 후보는 다음 순서를 따른다.

1. FORMATION save에 있는 boon ID를 catalog와 exact 검증한다.
2. request에 boon ID를 복사한다.
3. candidate RunState의 boon ID를 0으로 만든다.
4. request sequence와 phase를 기존 P4-B04대로 commit한다.

실패하면 boon은 소비되지 않는다. 같은 FORMATION save를 다시 열면 같은 boon을 가진 같은 request가 나온다.

### BattleState 적용

`RunBattleBridge.build_state`는 기존 exact build가 성공한 뒤, 첫 player 행동이 commit되기 전에 다음을 수행한다.

- opening status 0이면 아무것도 하지 않는다.
- nonzero면 request player initial body ID 오름차순으로 각 body에 1 stack을 적용한다.
- source body는 target 자신으로 기록한다.
- status 적용 전체는 BattleState 후보 사본에서 원자적으로 수행한다.
- trigger를 새로 emit하지 않는다.
- 결과 status는 BattleSnapshot v8의 기존 status section에 정상 저장된다.

boon은 P4 전투 bridge에서만 적용한다. 일반 P2 fixture의 `BattleSetupBuilder` 호출에는 영향이 없다.

## 휴식 node

### 진입

`RunState.choose_rest_node(catalog, node_id, status) -> bool`

P4-3 node reachability helper를 재사용해 다음 floor·edge·미방문을 확인한다. node type은 REST, content ID는 0이어야 한다. 성공 후보는 node를 visited에 넣고 phase REST, current node/floor를 고정한다.

pending은 두 mode entry를 가진다.

| choice ID | kind | amount | enabled |
|---:|---|---:|---|
| 1 | RECOVER_LIFE | 1 | `life < max_life` |
| 2 | MERGE_PIECES | 1 | 유효 합성 쌍 존재 및 `roster_count - 1 >= 3` |

두 entry의 primary/secondary/cost는 0이다. 실제 합성 instance ID는 command 입력이며 pending에 모든 조합을 열거하지 않는다. 두 mode가 모두 disabled면 node를 즉시 completed 처리하고 pending을 남기지 않는다.

### 공개 command

```text
RunState.resolve_rest(catalog, choice_id,
                      first_instance_id,
                      second_instance_id,
                      status) -> bool
```

- 회복 선택은 두 instance ID가 모두 0이어야 하며 life를 정확히 1 올린다.
- 합성 선택은 서로 다른 두 nonzero instance ID를 요구한다.
- 성공하면 한 action만 적용하고 REST를 완료한다.
- disabled·stale choice, 잘못된 pair, overflow는 state를 바꾸지 않는다.

P4-6 UI는 세 번째 비활성 슬롯을 “잠김”으로 그리지만 core pending과 snapshot에는 넣지 않는다.

## 합성

검증 순서:

1. phase REST, pending REST, MERGE entry enabled
2. roster 수 4 이상이며 합성 뒤에도 3 이상
3. 두 instance가 존재하고 서로 다름
4. piece numeric ID와 level이 같음
5. level은 1 또는 2이고 target level이 catalog에 존재
6. target level content가 현재 fingerprint에 포함됨
7. counter kind별 max 병합
8. 작은 instance ID를 target level로 교체
9. 큰 instance ID 제거
10. `next_piece_instance_id` 유지
11. 전체 RunState 검증 뒤 commit

counter 병합 예:

```text
left  KILLS=3, BATTLES_SURVIVED=1
right KILLS=5, BATTLES_SURVIVED=0
result KILLS=5, BATTLES_SURVIVED=1
```

0인 counter는 record로 저장하지 않는다. unknown counter kind는 기존 RunPieceInstance 검증에서 실패한다.

## node 완료와 phase

reward/rest 성공 뒤 공통 helper가 처리한다.

```text
if current node is final BOSS and battle result was victory:
  phase = ACT_COMPLETE
  current floor/node = completed boss 유지
elif current node is final BOSS and reward was revenge:
  phase = FORMATION
  current floor/node = same visited, incomplete boss 유지
else:
  phase = MAP_CHOICE
  current floor = 0
  current node = 0
```

- 일반/엘리트 보복과 REST current node를 completed에 sorted unique로 추가한다. 승리 battle은 이미 포함되어 있어 exact 확인만 한다.
- deployment와 pending을 비운다.
- boon은 보복 선택에서만 nonzero가 될 수 있다.
- 마지막 boss 패배 뒤 life가 남은 경우 boss node는 completed에 넣지 않는다. 보복 boon을 예약한 채 같은 node의 FORMATION으로 돌아가므로 다음 시도 전에 편성을 다시 고를 수 있다.

### 보스 패배 충돌 권장안

P4-B14는 패배 node를 재시도하지 않는다고 승인했지만 final boss는 outgoing edge가 없다. 그대로면 life가 남아도 진행 불가능하다.

P4-RD16의 세부 예외로 다음을 권장한다.

- 일반/엘리트 패배: 보복 완료 후 completed, 다음 edge 진행.
- 보스 패배/DRAW에서 life>0: 보복 완료 후 boss를 completed에 넣지 않고 같은 boss의 `FORMATION`으로 직접 돌아가 재도전한다.
- 예약된 revenge status는 재도전 battle에 적용한다.
- boss 승리만 `ACT_COMPLETE`다.

이는 P4-B14의 “같은 전투 반복 금지”에 대한 명시적 예외이므로 별도 승인 없이는 구현하지 않는다. 대안은 보스 패배 즉시 run 실패지만 D-24의 보스 −1과 남은 라이프 의미를 약화하므로 권장하지 않는다.

## RunState phase 불변식 이관

| phase | current node | deployment | pending | boon |
|---|---|---|---|---:|
| MAP_CHOICE | 0 | empty | NONE | 0 또는 active status ID |
| FORMATION | battle node | empty 또는 확정 편성 | NONE | 0 또는 active status ID |
| BATTLE | battle node | 확정 편성 | NONE | 0 |
| REWARD handoff | battle node | 직전 편성 | NONE | 0 |
| REWARD prepared | battle node | empty | REWARD | 0 |
| REST | rest node | empty | REST | 유지 |
| ACT_COMPLETE | 승리 completed boss | empty | NONE | 0 |
| RUN_FAILED | visited battle node | empty | NONE | 0 |

- REWARD handoff는 `next_transition_sequence >= 2`이고 deployment가 방금 request 수와 일치해야 한다.
- pending REWARD가 생긴 뒤 deployment는 반드시 empty다.
- 패배 reward 준비 여부는 completed membership과 pending entry kind로 구분한다.
- boss battle 시작 시 boon을 소비하므로 `ACT_COMPLETE`에는 남은 boon이 없다.

## RunSnapshot v2

```text
magic: FLICKRUN\0
schema_version:u16 = 2
v1 fields and sections unchanged
pending choice section
next_battle_status_numeric_id:u32
exact EOF
```

- decoder는 v1과 v2를 허용한다.
- v1은 `next_battle_status_numeric_id=0`으로 복원한다.
- legacy v1을 capture하면 v2를 출력한다.
- v2 nonzero status는 현재 catalog active pair, duration BATTLE, modifier 존재를 restore에서 검증한다.
- BATTLE capture 금지는 유지한다.
- catalog v8 fingerprint가 다르면 기존대로 migration 없이 실패한다.
- P4-1/2/3 RunSnapshot known-answer는 실행이 재개되는 P4-6에서 v2로 명시 이관한다.

## 공개 API

```text
RewardProfileDefinition.create(...)
ContentCatalog.reward_profile_count()
ContentCatalog.reward_profile_at(index, status)
ContentCatalog.reward_profile_by_numeric_id(id, status)

RunRewardGenerator.generate_victory(state, catalog, profile, status)
  -> RunPendingChoice

RunState.prepare_reward(catalog, status) -> bool
RunState.choose_reward(catalog, choice_id, status) -> bool
RunState.choose_rest_node(catalog, node_id, status) -> bool
RunState.resolve_rest(catalog, choice_id,
                      first_instance_id, second_instance_id,
                      status) -> bool
RunState.next_battle_status_numeric_id() -> int

RunBattleRequest.opening_status_numeric_id() -> int
BattleState.apply_run_opening_status(player_body_ids,
                                     status_numeric_id,
                                     status) -> bool
```

generic Dictionary payload와 공개 setter를 추가하지 않는다. 값/배열 getter는 깊은 사본이다.

## 결정론·원자성

- reward/rest 계층은 `RefCounted`이며 Node·Time·FileAccess·Godot RNG를 사용하지 않는다.
- reward pool·tag·roster는 numeric ID/instance ID 안정 순서로 순회한다.
- 의미 순서인 직전 deployment와 choice draw 결과는 정렬하지 않는다.
- RNG는 reward 준비 성공 후보에서만 사용하며 getter/UI 재조회는 소비하지 않는다.
- pending이 생성된 뒤 재추첨 API는 없다.
- prepare/choose/rest/merge/begin/boon apply는 각각 전체 후보 사본 commit이다.
- gold, next instance ID, counter, snapshot length는 checked 연산한다.
- 오류 뒤 capture 가능한 state는 호출 전 RunSnapshot bytes가 유지된다.
- fingerprint·snapshot hash를 RNG seed나 판정에 사용하지 않는다.

## 공학 한도

| 항목 | 한도 |
|---|---:|
| reward profile record | 256 |
| profile recruit pool | 1~64 |
| recruit choice | 1~8 |
| victory gold/profile | 0~1,000,000 |
| run gold | uint32 |
| pending entry | 기존 8 |
| merge per REST | 1 |
| piece level | 1~3 |
| roster | gameplay 10, engineering 64 |
| next battle status | 0 또는 status ID 1개 |

한도 초과는 truncate·clamp하지 않는다. life 회복은 max life에서 비활성이고, `BATTLES_SURVIVED`의 기존 5 포화는 P4-3 계약을 유지한다.

## 진단 계약

### ContentStatus append

```text
Operation.REWARD_PROFILE_VALIDATE = 16

FieldId.VICTORY_GOLD = 103
FieldId.RECRUIT_CHOICE_COUNT = 104
FieldId.RECRUIT_POOL_REFS = 105
FieldId.REVENGE_STATUS_REF = 106
```

기존 content code를 재사용하고 번호를 재배정하지 않는다.

### SimStatus append

```text
Code.INVALID_RUN_REWARD = 73
Code.INVALID_RUN_MERGE = 74
Code.INVALID_RUN_BOON = 75

Operation.RUN_REWARD_GENERATE = 159
Operation.RUN_REWARD_PREPARE = 160
Operation.RUN_REWARD_CHOOSE = 161
Operation.RUN_REST_CHOOSE = 162
Operation.RUN_REST_RESOLVE = 163
Operation.RUN_PIECE_MERGE = 164
Operation.RUN_BOON_APPLY = 165
```

phase는 `INVALID_PHASE`, fingerprint는 `CONTENT_FINGERPRINT_MISMATCH`, ID overflow는 `COUNTER_EXHAUSTED`, snapshot 구조는 기존 code를 재사용한다.

## 대상 파일

### 신규 후보

```text
docs/specs/p4_reward_recruitment_rest_merge.md
src/core/data/reward_profile_definition.gd
src/core/data/reward_profiles.json
src/core/run/run_reward_generator.gd
```

### 수정 후보

```text
src/core/data/content_ids.gd
src/core/data/content_status.gd
src/core/data/content_catalog.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/catalog.json
src/core/data/id_registry.json
src/core/data/encounters.json               # ID 값 불변, profile ref exact 검증만 강화
src/core/data/statuses.json
src/core/data/pieces.json
src/core/run/run_choice_kind.gd
src/core/run/run_state.gd
src/core/run/run_snapshot.gd
src/core/run/run_battle_request.gd
src/core/run/run_battle_bridge.gd
src/core/battle/battle_state.gd
src/core/sim/sim_status.gd
docs/specs/p4_run_loop.md
AGENTS.md
HANDOFF.md
```

P4-4 전용 runner·fixture 파일은 지금 만들지 않고 P4-6 통합 검증 작업에 포함한다. 구현 중 최소 import에서 Godot가 `.uid`를 생성하면 해당 source와 함께 기록한다.

## 필요 에셋

없음. P4-4는 core와 runtime JSON만 변경한다. P4-6 UI는 기존 폰트·도형 graybox를 사용하며 새 파일 에셋이 필요할 때만 별도 manifest 계약을 따른다.

## 최종 수용 기준 — 실행은 P4 전체 구현 뒤

아래 기준은 생략이 아니라 P4-6에 누적할 검증 부채다.

1. reward profile exact schema, active pair, pool/status/encounter ref 오류가 atomic catalog load 실패다.
2. canonical bytes와 fingerprint v8이 독립 Python reference와 일치한다.
3. normal/elite/boss profile이 10/20/30 gold와 exact pool/status를 반환한다.
4. 같은 seed·node·직전 편성은 같은 pending bytes와 choice 순서를 만든다.
5. getter·화면 재진입·snapshot restore가 reward RNG를 바꾸지 않는다.
6. 활성 tag·미중복 piece 수·다중 tag weight가 승인 식과 일치한다.
7. 영입은 중복 보유를 허용하고 새 instance ID를 단조 증가시키며 cap에서 skip된다.
8. reward 준비·선택 재호출과 stale/disabled choice가 원본 snapshot을 유지한다.
9. gold overflow가 reward 전체를 rollback하고 패배에는 gold가 없다.
10. outcome 직후 REWARD snapshot이 직전 deployment를 보존하고 pending 생성 뒤 비운다.
11. 보복 status가 다음 battle player initial body에만 적용되고 그 다음 battle에는 남지 않는다.
12. pre-battle FORMATION save 복원이 같은 boon request를 만들고 begin 실패는 boon을 보존한다.
13. RunSnapshot v2 roundtrip과 legacy v1→v2 recapture가 exact다.
14. 회복 max-life disable, 합성 가능/불가 pair, 3기 최소 roster가 적용된다.
15. 합성은 작은 ID, target level, counter별 max, next ID 비감소를 지킨다.
16. baduk/bottle L2·L3가 exact HP/ATK와 나머지 L1 속성을 가진다.
17. REST 한 action 뒤 완료되고 두 action 불가 시 자동 완료된다.
18. 일반/엘리트 패배 후 보복을 받고 outgoing edge의 다음 node로 진행한다.
19. boss 승리만 ACT_COMPLETE이며 승인된 boss 패배 예외가 정확히 작동한다.
20. 모든 invalid phase/content/choice/merge/boon 실패가 후보 사본 rollback을 지킨다.
21. P4-1~4 narrow, catalog/fingerprint KAT, P1~P3 대표 회귀가 통과한다.
22. P4-5·6 구현 뒤 quick 4런과 Godot 4.6.3 `verify --demo`가 통과한다.
23. `verify --full`, 16-seed 전체 route, 플랫폼 교차 결정론은 정식 release profile에서 수행한다.

## 빠른 구현 순서 — 전체 승인 뒤

1. reward profile enum/schema/typed definition/catalog/fingerprint v8을 구현한다.
2. runtime profile 3개, revenge status, 두 기물 L2·L3를 추가한다.
3. P4-3 REWARD handoff가 직전 deployment를 잠시 보존하도록 이관한다.
4. reward weight/generator와 prepare/choose command를 구현한다.
5. RunSnapshot v2와 next-battle boon을 구현한다.
6. request/bridge에 opening status 소비·적용을 연결한다.
7. REST 진입·회복·합성·node 완료 command를 구현한다.
8. 로드 불가를 막는 최소 import만 확인하고 구현 상태를 **검증 대기**로 기록한다.
9. P4-5·6을 계속 구현한 뒤 누적 수용 기준을 통합 실행한다.

## 승인 기록

2026-08-25 사용자는 다음 결정을 묶어 전체 승인하고 구현 진입을 지시했다.

1. P4-RD01~05: reward profile v8, 10/20/30 gold, 2종 강제 영입, tag weight
2. P4-RD06~08: 직전 deployment handoff 이관, reward RNG, instance 생성
3. P4-RD09~12: counter max 병합, L2/L3 수치, REST mode와 1회 합성
4. P4-RD13~15: +25% 보복 status, RunSnapshot v2, 다음 battle 소비/적용
5. P4-RD16: node 완료와 **boss 패배 재도전 예외**
6. P4-RD17~18: 원자성 및 P4 전체 완료 뒤 통합 검증 이연
7. 전체 상세 명세와 구현 진입
