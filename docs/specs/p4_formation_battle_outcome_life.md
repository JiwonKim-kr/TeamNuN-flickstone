# P4-3 · 편성·전투 요청/결과·라이프 상세 명세

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 상위 승인 | `p4_run_loop.md` P4-R01~17 |
| 선행 구현 | P4-1 `RunState`·`RunSnapshot` v1, P4-2 Act·Encounter·결정론적 graph |
| 후속 단계 | P4-4 영입·골드·휴식·합성·전투 후 reward 처리 |
| 승인 | 2026-08-25 · 사용자 P4-B01~17 및 전체 명세 승인 |
| 구현 권한 | **있음. 승인된 P4-3 범위 구현 가능** |
| 구현 | 2026-08-25 · 완료 및 데모 자동 검증 통과 |

## 목적

P4-2의 전투 node를 실제 데이터 기반 전투 한 판과 연결한다. 플레이어가 도달 가능한 전투 node를 고르고, 로스터 instance를 맵의 고정 player slot 순서로 편성하면, 불변 `RunBattleRequest`가 기존 `BattleSetupBuilder` 입력을 고정한다. terminal `BattleState`에서는 불변 `RunBattleOutcome`만 만들 수 있고, 그 결과는 같은 request에 대해 정확히 한 번만 `RunState`에 반영한다.

이 단계가 소유하는 런 결과는 전투 전후 phase, node 방문/완료 사실, 출전 instance의 런 카운터, D-12 전원 복원 경계, 난도별 라이프 차감이다. 승리 영입과 패배 보복형 보상의 **내용과 선택 적용**은 P4-4가 소유한다. P4-3은 그 사실을 잃지 않는 저장 가능한 `REWARD` 경계까지만 만든다.

## 정본과 선행 계약

- `docs/design/game_design.md` D-03·04·12·14·18·20·24~26, 3.1, 4.9, 7.8, 9.2·9.6, 10.1·10.4, 14.1·14.4
- `docs/specs/p1_trigger_bus_battle_result.md` T-04 처치 귀속, T-05 terminal `BattleResult`
- `docs/specs/p2_dynamic_piece_mechanics.md` 초기 비토큰 body의 원본 piece 보고와 전투 내 transform 경계
- `docs/specs/p2_maps_enemies_environment.md` P2-M13·14·21과 `BattleSetupBuilder`
- `docs/specs/p4_run_loop.md` P4-R03·06·07·10·11·16·17
- `docs/specs/p4_run_state_snapshot.md` P4-S02·05~11과 phase별 불변식
- `docs/specs/p4_act_encounter_map_generation.md` P4-G06·09·11~15

선행 계약 중 다음은 그대로 유지한다.

1. run instance ID와 battle body ID는 서로 다른 ID 축이다.
2. encounter의 `enemy_refs[index]`는 enemy slot `index`이며 의미 순서다.
3. 초기 body 순서는 현재 장애물 0개에서 player slot 오름차순 뒤 enemy slot 오름차순이다.
4. `BattleResult`는 `PLAYER_VICTORY`, `PLAYER_DEFEAT`, `DRAW`를 구분하며 P4가 DRAW의 런 의미를 정한다.
5. `RunSnapshot`은 전투 중 저장하지 않되, 확정 편성 직후와 전투 결과 commit 직후 상태를 저장할 수 있어야 한다.

### 선행 승인과의 충돌

P2-M21은 player와 enemy 배치 수를 모두 map `deploy_count`와 정확히 같게 요구한다. 반면 D-14·9.2는 실제 출전 수를 `min(출전 상한, 보유 수, 맵 슬롯 수)`로 확정했다. 합성으로 보유 수가 줄어드는 P4에서는 player가 map `deploy_count`보다 적을 수 있으므로 두 계약을 동시에 만족할 수 없다.

P4-B03은 이 충돌을 공개적으로 이관한다. D-03의 전투당 최소 3기는 유지해 player는 `3..deploy_count`, enemy는 계속 정확히 `deploy_count`를 요구한다. 따라서 예상 출전 수가 3 미만인 편성은 만들 수 없고 P4-4의 합성도 로스터를 3기 미만으로 줄이는 선택을 비활성화해야 한다. 기존 3대3 fixture의 결과와 body ID는 바뀌지 않으며, player가 map 정원보다 적은 유효 3~4기 입력을 새로 여는 방향으로 P2 narrow 계약을 이관한다.

## 범위

- 도달 가능한 battle node 선택과 `MAP_CHOICE → FORMATION`
- 순서 있는 run instance 편성과 map player slot 대응
- 불변 `RunBattlePlayerEntry`, `RunBattleEnemyEntry`, `RunBattleRequest`
- run seed에서 battle seed를 만드는 비소비 파생 규칙
- request에서 기존 `BattleDeploymentEntry`와 `BattleState` 조립
- 전투 전체의 초기 비토큰 body별 누적 처치 tally
- `BattleSnapshot` v8과 legacy v1~7 복원
- 불변 `RunBattlePlayerFact`, `RunBattleOutcome`
- terminal 결과·생존·처치 사실의 request 교차 검증
- `BATTLES_SURVIVED`, `KILLS` 런 카운터 갱신
- 승패/DRAW별 node 완료 사실과 난도별 라이프 차감
- D-12의 HP·status·link·token·transform 비이월
- FORMATION·REWARD·RUN_FAILED의 `RunSnapshot` v1 활성화
- node/편성/request/outcome 실패의 원자 rollback
- 독립 Python request/seed/snapshot known-answer와 Godot narrow 검증

## 비범위

- 승리 reward 후보 생성·영입·골드·유물·소모품 지급
- 패배 보복형 효과의 종류·강도·중첩과 실제 적용
- REWARD에서 다음 `MAP_CHOICE`로 나가는 command
- SHOP·EVENT·REST node 진입과 완료
- boss reward 뒤 ACT/RUN 완료 판정
- 용의 알 부화 transform과 폰 승급 수치·transform
- token이 낸 처치를 소유 run instance에 재귀 귀속하는 규칙
- 전투 중 save, 전투 리플레이 파일, 씬/UI/manifest
- 정식 3막·정식 encounter·밸런스 수치
- U-03 정적 장애물. 활성화 시 초기 body ID offset을 별도 이관해야 함

## 용어

| 용어 | 정의 |
|---|---|
| battle node | NORMAL_BATTLE, ELITE_BATTLE, BOSS 중 하나인 node |
| 예상 출전 수 | `min(deployment_capacity, roster_count, map.deploy_count)` |
| 편성 순서 | 배열 index가 player slot index가 되는 run instance ID 목록 |
| request sequence | 전투 요청을 한 런 안에서 식별하는 단조 증가 uint32 |
| initial body | `BattleSetupBuilder`가 전투 시작 시 만든 비토큰 body |
| kill tally | initial body가 `ON_KILL` subject가 된 누적 횟수 |
| player fact | 한 출전 run instance의 terminal 생존 여부와 누적 처치 수 |
| 결과 commit | 검증된 outcome을 사본 RunState에 전부 적용한 뒤 한 번에 원본과 교체하는 경계 |

## 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P4-B01 | `MAP_CHOICE`에서 다음 floor의 도달 가능한 미방문 battle node만 선택하고, 성공 시 node를 visited에 넣어 `FORMATION`으로 전이한다 | 이미 지나간 node 재진입과 edge 무시를 막고 graph를 권위 경로로 사용 | ✅ 승인 |
| P4-B02 | 예상 출전 수는 정본대로 `min(deployment_capacity, roster_count, map.deploy_count)`이며, 편성은 그 수와 정확히 같은 고유 instance ID 배열이다 | 좁은 맵·보유 감소·출전 상한을 한 식으로 처리 | ✅ 승인 |
| P4-B03 | P2-M21을 명시 이관해 player deployment는 `3..map.deploy_count`, enemy deployment는 계속 정확히 `map.deploy_count`로 한다. player slot은 0부터 연속이며 예상 출전 수 3 미만은 실패한다 | D-03의 최소 3기를 지키면서 D-14의 좁은 출전 상한·로스터 감소를 지원 | ✅ 승인 |
| P4-B04 | `begin_battle`만 next transition sequence를 request에 배정하고 checked 증가한다. phase/sequence commit과 request 생성은 원자적이며 FORMATION 재시작은 같은 pre-battle save에서 같은 request를 만든다 | outcome 중복·stale 적용을 막고 crash 재시작 결정론 유지 | ✅ 승인 |
| P4-B05 | `RUN_BATTLE_SEED=8`, owner=`act_numeric_id`, ordinal=`node_id`의 파생 stream 첫 두 u32를 battle `seed_hi/seed_lo`로 쓴다 | node별 독립 seed이며 UI 조회·이전 battle draw 수의 영향을 받지 않음 | ✅ 승인 |
| P4-B06 | request는 fingerprint, sequence, act/node/encounter/map, battle seed, slot별 player instance/piece/level과 enemy ref를 깊은 불변 값으로 보존한다 | battle 조립 입력과 run 귀환 매핑의 단일 정본 | ✅ 승인 |
| P4-B07 | P4 전투는 `RunBattleBridge.build_state(request, catalog)`가 기존 `BattleSetupBuilder`를 호출하는 경로만 허용하고, request를 다시 catalog·encounter와 exact 검증한다 | 조작된 request와 씬의 직접 배치 조립을 차단 | ✅ 승인 |
| P4-B08 | 초기 비토큰 body별 nonzero 누적 처치 수를 `BattleKillTally`로 보존하고 `BattleSnapshot` v8에 넣는다. `ON_KILL`이 확정되는 같은 transition에서 checked 증가한다 | terminal `BattleResult`만으로는 폰의 런 누적 처치를 복원할 수 없는 현재 공백 해소 | ✅ 승인 |
| P4-B09 | outcome은 request와 terminal BattleState를 exact 대조해 만들며, player fact는 편성 slot 순서로 instance/body/survived/kills를 가진다 | body 제거·중복 piece·transform 뒤에도 run instance 귀속을 잃지 않음 | ✅ 승인 |
| P4-B10 | 출전 instance의 `BATTLES_SURVIVED`는 terminal 생존 시 최대 5까지 +1, 파괴 시 0으로 reset한다. `KILLS`는 승패와 무관하게 tally를 checked 가산한다. 미출전 instance는 둘 다 유지한다 | 7.8의 용의 알 연속 생존과 폰 런 누적 처치를 직접 구현 | ✅ 승인 |
| P4-B11 | D-12에 따라 outcome에서 HP·status·link·token·current transform을 RunState로 복사하지 않는다. 다음 전투는 run piece의 원본 content ID·level max HP로 새 body를 만든다 | 라이프를 유일한 장기 소모 자원으로 유지 | ✅ 승인 |
| P4-B12 | `PLAYER_VICTORY`는 life 불변, `PLAYER_DEFEAT`와 `DRAW`는 normal/boss −1, elite −2다. 차감은 0에서 포화하고 0이면 즉시 `RUN_FAILED`다 | D-24와 P1의 사실 보존형 DRAW를 런 정책으로 연결 | ✅ 승인 |
| P4-B13 | 승리 node는 outcome commit 때 completed가 된다. life가 남은 패배/DRAW node는 visited·미완료 상태로 `REWARD`에 남고, P4-4의 보복 reward 완료 때 completed가 된다 | reward 구현 전에도 승패 사실을 별도 필드 없이 snapshot에 보존 | ✅ 승인 |
| P4-B14 | 패배/DRAW 후 life가 남으면 해당 node는 재시도하지 않고, P4-4 보복 reward 뒤 그 node의 기존 outgoing edge 선택권을 그대로 가진다 | U-14 보복을 ‘다음 전투 강화’로 작동시키며 같은 전투 반복을 피함 | ✅ 승인 |
| P4-B15 | outcome commit 직후 `REWARD`의 pending은 `NONE`이다. P4-4가 completed 여부로 승리/패배를 구분해 승리 reward 또는 보복 reward를 고정 생성한다 | 미정 보상 내용을 P4-3이 발명하지 않으면서 저장 가능한 handoff 제공 | ✅ 승인 |
| P4-B16 | RunSnapshot v1 layout은 유지하고 MAP_CHOICE 외 FORMATION·REWARD·RUN_FAILED capture/restore를 연다. BATTLE capture는 계속 실패한다 | P4-R16 저장 시점을 지키며 불필요한 run schema 상승 방지 | ✅ 승인 |
| P4-B17 | 일상 검증은 normal/elite/boss/DRAW 대표 4 battle, 순수 state request/outcome/snapshot 1,000회, 대표 P1~P4 회귀와 `verify --demo`로 제한한다. 16-seed 전체 route는 P4-6 단계 종료에서 수행한다 | 데모 일정의 빠른 반복과 P4-R17의 순수 결정론 강도를 함께 유지 | ✅ 승인 |

## 상태 전이

```text
MAP_CHOICE
  └─ choose_battle_node(node_id) ─→ FORMATION (visited, current node 고정)

FORMATION
  ├─ set_deployment(instance_ids) ─→ FORMATION (확정 편성 교체)
  └─ begin_battle() ──────────────→ BATTLE (request sequence 소비)

BATTLE
  ├─ PLAYER_VICTORY ──────────────→ REWARD (completed, life 유지, pending NONE)
  ├─ DEFEAT/DRAW, life > 0 ───────→ REWARD (visited·미완료, life 차감, pending NONE)
  └─ DEFEAT/DRAW, life = 0 ───────→ RUN_FAILED (visited·미완료, pending NONE)
```

P4-3에는 REWARD를 소비하는 command가 없다. 구현 fixture는 outcome commit과 snapshot roundtrip에서 멈춘다. P4-4가 다음 전이를 추가한다.

```text
REWARD 승리     → reward 선택 완료 → MAP_CHOICE 또는 boss 후속 phase
REWARD 패배/DRAW → 보복 reward 완료 → completed 추가 → MAP_CHOICE
```

## battle node 선택

`RunState.choose_battle_node(catalog, node_id, status) -> bool`

검증 순서:

1. initialized state, catalog initialized, fingerprint exact, phase `MAP_CHOICE`
2. node ID가 graph에 존재하고 미방문인지 확인
3. 기대 floor 계산
   - completed가 비어 있으면 floor 1
   - 아니면 completed 중 가장 높은 floor의 유일한 마지막 완료 node를 찾아 `floor+1`
4. node floor가 기대 floor와 같은지 확인
5. floor 1이 아니면 마지막 완료 node의 `next_node_ids`에 node가 있는지 확인
6. node type이 NORMAL/ELITE/BOSS인지 확인
7. node content가 실제 encounter이고 encounter node type이 node type과 같은지 확인
8. encounter map과 enemy refs가 현재 catalog에서 다시 유효한지 확인
9. 후보 사본에 visited/current floor/current node/FORMATION을 적용하고 전체 검증 뒤 commit

P4-3에서 SHOP/EVENT/REST를 선택하면 `INVALID_PHASE`로 실패하며 상태 bytes를 유지한다. P4-5가 같은 reachability helper를 재사용해 각 phase를 연다.

visited/completed 배열은 node ID 엄격 오름차순을 유지한다. graph node ID가 floor 순 연속이므로 append가 가능하더라도 구현은 정렬 불변식을 검증하고 암묵 가정에 기대지 않는다.

## 편성 계약

`RunState.set_deployment(catalog, instance_ids, status) -> bool`

1. phase가 FORMATION이고 current node가 유효한 battle node여야 한다.
2. current encounter의 map을 조회한다.
3. `expected_count = min(deployment_capacity, roster_count, map.deploy_count)`를 checked 계산한다.
4. expected count는 D-03에 따라 3 이상이어야 한다. 3 미만이면 node 진입 상태를 바꾸지 않고 실패한다.
5. 입력 수는 expected count와 정확히 같아야 한다.
6. 각 ID는 nonzero이고 roster에 존재하며 중복되지 않아야 한다.
7. 배열 index가 player slot index다. instance ID 정렬은 하지 않는다.
8. 기존 편성은 후보 사본에서 통째로 교체하며 부분 성공이 없다.

같은 instance 집합이라도 순서가 다르면 다른 편성이고 request bytes도 달라진다. getter는 이 의미 순서를 그대로 복사한다.

## 불변 요청 값 객체

### RunBattlePlayerEntry

```text
slot_index: uint16, 0부터 연속
expected_body_id: uint32
run_instance_id: uint32
piece_numeric_id: uint32
level: uint16
```

### RunBattleEnemyEntry

```text
slot_index: uint16, 0부터 연속
expected_body_id: uint32
enemy_numeric_id: uint32
```

### RunBattleRequest

```text
content_fingerprint: 32 bytes
request_sequence: uint32
act_numeric_id: uint32
node_id: uint32
node_type_id: uint16
encounter_numeric_id: uint32
map_numeric_id: uint32
battle_seed_hi, battle_seed_lo: uint32
players[]: RunBattlePlayerEntry, slot order
enemies[]: RunBattleEnemyEntry, slot order
```

- player 수는 3~map deploy count, enemy 수는 map deploy count다.
- 현재 U-03 장애물이 0개이므로 player expected body ID는 `slot+1`, enemy expected body ID는 `player_count+slot+1`이다.
- request는 string ID를 저장하지 않는다. bridge가 numeric ID를 catalog의 typed ref로 바꿀 때 active pair를 재검증한다.
- generic Dictionary/Variant payload와 공개 setter를 두지 않는다.
- `copy()`와 모든 entry getter는 깊은 사본이다.

## battle seed와 request sequence

`RunRandomPurpose.RUN_BATTLE_SEED = 8`을 append한다. 기존 4~7을 바꾸지 않는다.

```text
rng = SimRng.derive(run_seed_hi, run_seed_lo,
                    RUN_BATTLE_SEED,
                    act_numeric_id,
                    node_id)
battle_seed_hi = rng.next_u32()
battle_seed_lo = rng.next_u32()
```

동일 run seed·act·node는 같은 battle seed를 만든다. 다른 node, map 생성 draw, UI 조회 횟수, 이전 전투 턴 수는 영향을 주지 않는다. 두 word가 모두 0이어도 `SimWorld`의 승인 계약대로 유효하다.

`begin_battle` 성공 전 `_next_transition_sequence`가 request sequence다. 성공 후보에서만 checked +1하고 phase를 BATTLE로 바꾼다. 실패한 request 생성·catalog 검증·sequence overflow는 sequence와 phase를 유지한다.

pre-battle save는 **확정 deployment가 있는 FORMATION**에서 캡처한다. 그 save를 다시 열어 `begin_battle`하면 같은 sequence와 battle seed가 나온다.

## 공개 전투 브리지

```text
RunState.choose_battle_node(catalog, node_id, status) -> bool
RunState.set_deployment(catalog, instance_ids, status) -> bool
RunState.begin_battle(catalog, status) -> RunBattleRequest
RunState.apply_battle_outcome(catalog, outcome, status) -> bool

RunBattleBridge.build_state(request, catalog, status) -> BattleState
RunBattleBridge.outcome_from(request, battle_state, status) -> RunBattleOutcome
```

`RunState.begin_battle`은 후보 request를 전부 만든 뒤 후보 RunState의 phase/sequence를 검증하고 한 번에 commit한다. `RunBattleBridge.build_state`는 request를 직접 신뢰하지 않고 다음을 exact 확인한다.

1. fingerprint와 catalog
2. encounter/node type/map/enemy slot 배열
3. player piece/level과 catalog 존재·비token
4. slot 연속성, expected body ID, 양 진영 수
5. 각 entry를 `BattleDeploymentEntry`로 변환
6. `BattleSetupBuilder.build` 호출
7. 생성 state의 fingerprint, piece origin, 초기 participant/body ID 대응

scene이나 autoload는 `BattleSetupBuilder`를 직접 호출해 P4 전투를 만들지 않는다.

### P2-M21 이관 뒤 BattleSetupBuilder

`BattleSetupBuilder.build`의 player 검증을 아래로 바꾼다.

- player count: 3~`map.deploy_count`
- player slot: 정확히 `0..player_count-1`
- enemy count: 정확히 `map.deploy_count`
- enemy slot: 정확히 `0..deploy_count-1`

중간 slot을 비우는 sparse deployment는 금지한다. 기존 full deployment는 body 순서·snapshot·terminal 결과가 변하지 않아야 한다.

## 전투 누적 처치 ledger

현재 `BattleState.trigger_record_*`는 마지막 transition batch만 제공한다. terminal 시점에는 이전 턴의 `ON_KILL`이 사라질 수 있으므로 P4가 이를 합산해서 추측하면 안 된다.

### BattleKillTally

```text
body_id: uint32
kill_count: uint32 > 0
```

- 배열은 body ID 엄격 오름차순이며 0 count record를 저장하지 않는다.
- 대상 body ID는 `_piece_origins`에 있는 초기 비토큰 body만 허용한다.
- `_process_destroy_event`가 적대 faction 처치를 확정해 `ON_KILL`을 emit하는 같은 transition에서 subject body tally를 checked +1한다.
- 귀속자가 이미 파괴됐어도 T-04에 따라 tally를 유지한다.
- token body가 subject이면 run owner 규칙이 없으므로 tally에 넣지 않는다. trigger 자체는 그대로 발생한다.
- transition backup/copy/restore가 tally를 포함하며 실패 시 이전 tally로 rollback한다.

공개 읽기 API:

```text
BattleState.kill_tally_count() -> int
BattleState.kill_tally_at(index, status) -> BattleKillTally
BattleState.kill_count_for_body(body_id) -> int
```

## BattleSnapshot v8

`BattleSnapshot.SCHEMA_VERSION = 8`, 기존 v7 gate는 `ZONE_SCHEMA_VERSION = 7`로 이름을 분리한다. legacy v1~7 decode를 유지하며 v1~7은 빈 kill tally로 복원한다.

v8은 v7의 zone spawn section 뒤, `sim_length` 앞에 다음을 추가한다.

```text
u32 kill_tally_count
repeat kill_tally_count:
  u32 body_id
  u32 kill_count
u32 sim_length
bytes sim_snapshot_v2
```

decode는 count `<= piece_origin_count`, body ID nonzero·엄격 오름차순, count nonzero, origin 실제 존재를 검사한다. legacy snapshot을 capture하면 v8 bytes를 낸다. `SimSnapshot` v2와 P0 hash golden은 바꾸지 않는다.

P1~P3 BattleSnapshot KAT는 terminal 결과·turn/tick·SimSnapshot bytes가 불변임을 먼저 확인한 뒤 설명 가능한 v8 bytes/hash로 이관한다.

## 불변 outcome 값 객체

### RunBattlePlayerFact

```text
slot_index: uint16
expected_body_id: uint32
run_instance_id: uint32
survived: bool
kills: uint32
```

### RunBattleOutcome

```text
content_fingerprint: 32 bytes
request_sequence: uint32
act_numeric_id: uint32
node_id: uint32
node_type_id: uint16
battle_result: uint16 terminal only
player_facts[]: RunBattlePlayerFact, slot order
```

`outcome_from` 검증 순서:

1. request·battle state initialized, fingerprint exact
2. battle phase `BATTLE_END`, result terminal, pending mutation 없음
3. request의 initial body ID마다 `BattlePieceOrigin.original_piece_numeric_id`가 request piece/base piece와 일치
4. 살아 있는 participant body ID 집합을 안정 오름차순으로 작성
5. 각 player expected body ID의 생존 여부를 집합에서 확인
6. `kill_count_for_body`를 읽어 player fact 작성
7. player fact가 request의 slot/instance/body와 exact 일치하는지 최종 검증

outcome은 current HP, status, transform target, enemy 생존 목록, trigger 배열을 보관하지 않는다. P4-3 런 정산에 필요한 최소 사실만 가진다.

## outcome 적용과 정확히 한 번

`RunState.apply_battle_outcome`은 후보 사본에서 아래 순서로 수행한다.

1. phase가 BATTLE인지 확인
2. `outcome.request_sequence == next_transition_sequence - 1`
3. fingerprint/act/node/node type이 current state와 exact 일치
4. fact 수·slot·instance가 확정 deployment와 exact 일치
5. player fact별 run counter 후보 계산
6. result와 node type으로 life 후보 계산
7. deployment를 비움
8. 승리면 current node를 completed에 추가하고 REWARD
9. 패배/DRAW에서 life>0이면 completed에 넣지 않고 REWARD
10. 패배/DRAW에서 life=0이면 RUN_FAILED
11. pending NONE과 전체 phase 불변식 검증
12. 한 번에 원본 commit

성공하면 phase가 더는 BATTLE이 아니므로 같은 outcome 재적용은 `INVALID_PHASE`로 실패한다. sequence가 같더라도 다른 node·instance fact를 가진 stale/변조 outcome은 commit 전에 실패한다.

## 런 카운터

### BATTLES_SURVIVED

- 출전했고 `survived=true`: 기존값 +1, 최대 5에서 포화
- 출전했고 `survived=false`: record 제거, 조회값 0
- 미출전: 유지
- 승리/패배/DRAW 모두 같은 규칙

5 도달 시 용의 알을 실제 드래곤으로 바꾸는 것은 콘텐츠 transform 승인 범위이며 P4-3에서 수행하지 않는다. P4-3은 카운터 사실만 보존한다.

### KILLS

- 출전 instance: 기존값 + `player_fact.kills`, int64 checked
- kills 0이면 기존값 유지
- 미출전: 유지
- 승리/패배/DRAW와 생존 여부에 관계없이 확정 처치는 보존

token의 kill을 소환자에게 귀속하는 규칙은 승인 전 추측하지 않는다. 초기 player body가 transform된 뒤 같은 body ID로 낸 kill은 정상 집계된다.

## D-12 복원 경계

`RunState`는 전투 전과 후 모두 다음 값만 보존한다.

- run instance ID
- 원본 player piece numeric ID
- level
- run counter

다음 값은 outcome에 없고 전투 종료와 함께 폐기한다.

- current/max HP의 전투 사본
- status와 modifier
- CT, cooldown, trigger/effect sequence
- attach/link, zone, projectile, token
- current transform target과 battle body ID

다음 전투 `RunBattleRequest`는 RunPieceInstance의 원본 piece ID·level을 다시 읽고 `BattleSetupBuilder`가 max HP body를 새로 만든다. 파괴된 기물을 roster에서 제거하지 않는다.

## 라이프와 패배 node 처리

| node type | 승리 | 패배/DRAW |
|---|---:|---:|
| NORMAL_BATTLE | 0 | −1 |
| ELITE_BATTLE | 0 | −2 |
| BOSS | 0 | −1 |

- 차감량이 현재 life보다 크면 0으로 포화한다.
- life 0은 `RUN_FAILED`; reward와 다음 node를 열지 않는다.
- life가 남으면 `REWARD`로 가되 node는 미완료다. 이 한 비트가 패배 보복 reward의 입력이다.
- P4-4가 보복 reward를 완료하면 node를 completed에 넣고 해당 node의 outgoing edge로 다음 floor를 고른다.
- failed node 자체를 재시도하지 않는다.

승리 node는 outcome commit 때 completed다. P4-4는 completed battle node의 encounter `reward_profile_numeric_id`로 승리 reward를 만들고 완료 뒤 다음 floor를 연다.

## RunState·RunSnapshot v1 활성화

RunSnapshot 바이트 layout과 schema 1은 유지한다. P4-3은 기존 필드만 사용해 다음 phase를 capture/restore 가능하게 한다.

| phase | current node | deployment | visited/completed | pending | capture |
|---|---|---|---|---|---|
| MAP_CHOICE | 0 | empty | 완료 경로 | NONE | 허용 |
| FORMATION | battle node | expected count 확정 | visited / 미완료 | NONE | 허용 |
| BATTLE | battle node | expected count 확정 | visited / 미완료 | NONE | **금지** |
| REWARD 승리 | battle node | empty | visited + completed | NONE | 허용 |
| REWARD 패배 | battle node | empty | visited / 미완료 | NONE | 허용 |
| RUN_FAILED | battle node | empty | visited / 미완료 | NONE | 허용 |

P4-1의 다음 제한을 이관한다.

- `_phase_id == MAP_CHOICE` 고정 제거, 위 phase별 구조 검증으로 교체
- `_next_transition_sequence == 1` 고정 제거, 1 이상이며 활성 request 규칙을 만족
- visited/completed/deployment empty 고정 제거
- `copy()`는 BATTLE 포함 모든 유효 phase를 깊게 복사 가능
- `capture()`만 BATTLE을 명시 거부
- restore는 FORMATION/REWARD/RUN_FAILED를 의미 검증하고 BATTLE snapshot은 decode돼도 restore 거부

REWARD의 `pending NONE`은 P4-3 결과 handoff에서만 유효하다. P4-4가 reward 후보를 생성하면 기존 `pending REWARD` 불변식을 활성화한다.

## 결정론·원자성

- run/battle bridge 값 객체는 `RefCounted`이며 Node·Time·FileAccess·Godot RNG를 호출하지 않는다.
- node/instance/body/kill tally 배열은 명시한 안정 순서를 사용한다.
- 의미 순서인 deployment, encounter enemy, player fact 배열은 정렬하지 않는다.
- getter, copy, validate, snapshot capture는 RNG를 소비하지 않는다.
- battle seed는 node별 파생 stream이고 request 외부의 RNG 상태를 저장하지 않는다.
- node 선택, 편성 교체, begin, outcome apply는 후보 사본을 완전히 검증한 뒤 한 번에 commit한다.
- kill tally 증가는 BattleState transition backup에 포함한다.
- 오류 뒤 RunSnapshot 가능 phase는 호출 전 bytes가 유지되고, BATTLE은 `BattleSnapshot` bytes 비교로 rollback을 검증한다.
- fingerprint, snapshot hash, terminal hash를 RNG seed나 게임 판정으로 재사용하지 않는다.
- first-error-wins를 지키고 bridge가 하위 `SimRng`·`BattleSetupBuilder` 오류를 덮어쓰지 않는다.

## 공학 한도

| 항목 | 한도 |
|---|---:|
| player request entry | 3~5 gameplay, 16 engineering |
| enemy request entry | map deploy count 3~5 |
| battle kill tally | 초기 비토큰 body 수 이하, 현재 최대 10 |
| body별 kill count | uint32 |
| request sequence | 1~uint32 max, 다음 값 overflow 전 실패 |
| battles survived | 0~5 |
| run kills | 0~int64 max |
| outcome player fact | request player 수와 exact |

한도 초과는 truncate·포화하지 않는다. 예외는 gameplay 규칙으로 명시한 life 0 포화와 battles survived 5 포화뿐이다.

## 진단 계약

기존 번호를 바꾸지 않고 append한다.

### SimStatus.Code

| 값 | 이름 |
|---:|---|
| 70 | `INVALID_RUN_BATTLE_REQUEST` |
| 71 | `INVALID_RUN_BATTLE_OUTCOME` |
| 72 | `INVALID_BATTLE_KILL_TALLY` |

phase 불일치는 기존 `INVALID_PHASE`, sequence overflow는 `COUNTER_EXHAUSTED`, fingerprint는 `CONTENT_FINGERPRINT_MISMATCH`, deployment 구조는 `INVALID_DEPLOYMENT`를 재사용한다.

### SimStatus.Operation

| 값 | 이름 |
|---:|---|
| 151 | `RUN_NODE_CHOOSE` |
| 152 | `RUN_DEPLOYMENT_SET` |
| 153 | `RUN_BATTLE_REQUEST_CREATE` |
| 154 | `RUN_BATTLE_BEGIN` |
| 155 | `RUN_BATTLE_BUILD` |
| 156 | `RUN_BATTLE_OUTCOME_CREATE` |
| 157 | `RUN_BATTLE_OUTCOME_APPLY` |
| 158 | `BATTLE_KILL_TALLY_UPDATE` |

| operation | detail_a | detail_b |
|---|---|---|
| node choose | requested node ID | expected floor 또는 source node ID |
| deployment set | actual count 또는 instance ID | expected count 또는 slot index |
| request create/begin | request sequence | node ID |
| battle build | node/encounter ID | map 또는 slot |
| outcome create/apply | request sequence | result/node/instance ID |
| kill tally | body ID | previous/new count |

## 대상 파일

### 신규

```text
src/core/run/run_battle_player_entry.gd
src/core/run/run_battle_enemy_entry.gd
src/core/run/run_battle_request.gd
src/core/run/run_battle_player_fact.gd
src/core/run/run_battle_outcome.gd
src/core/run/run_battle_bridge.gd
src/core/battle/battle_kill_tally.gd
pipeline/tests/p4_formation_battle_outcome_life_test.gd
pipeline/tests/p4_formation_battle_outcome_life_reference.py
pipeline/tests/run_p4_formation_battle_outcome_life.py
```

### 수정

```text
src/core/run/run_state.gd
src/core/run/run_snapshot.gd
src/core/run/run_random_purpose.gd
src/core/battle/battle_state.gd
src/core/battle/battle_snapshot.gd
src/core/battle/battle_setup_builder.gd
src/core/sim/sim_status.gd
pipeline/tests/p1_trigger_bus_battle_result_test.gd
pipeline/tests/p2_maps_enemies_environment_test.gd
docs/specs/p4_run_loop.md
AGENTS.md
```

실제 구현 중 기존 golden 이관으로 수정되는 P1~P3 fixture 파일은 결과 불변 확인 뒤 구현 기록에 정확히 남긴다.

## 필요 에셋

없음. strict runtime JSON record와 manifest 항목을 추가하지 않는다. 현재 개발 Act·encounter·map·enemy·piece를 그대로 사용한다.

## 수용 기준

1. 도달 불가·이전 floor·재방문·비전투 node 선택이 state를 바꾸지 않는다.
2. 도달 가능한 battle node 선택이 visited/current/FORMATION을 정확히 고정한다.
3. 편성 수·중복·없는 instance·순서가 검증되고 순서 변경은 request mapping을 바꾼다.
4. roster나 출전 상한이 map deploy count보다 작아도 player 3~deploy count가 조립되고 enemy는 계속 full deployment다. 예상 수 3 미만은 원자 실패한다.
5. 기존 full 3대3 P2 setup의 body ID, 시작 snapshot, terminal 결과가 승인 이관 외에 변하지 않는다.
6. 동일 run seed·act·node는 1,000회 같은 battle seed/request를 만든다.
7. 다른 node는 독립 battle seed를 만들고 UI/getter 호출은 seed를 바꾸지 않는다.
8. begin 실패는 phase와 next sequence를 유지하고 성공은 정확히 한 번 sequence를 증가시킨다.
9. request 변조 fingerprint/node/encounter/map/player/enemy/level/slot이 build 전에 거부된다.
10. request에서 만든 BattleState의 초기 body와 run instance mapping이 exact다.
11. direct, motion-root, KILL zone 처치가 초기 player body tally에 누적된다.
12. 파괴된 killer의 이미 확정된 kill tally가 terminal까지 남는다.
13. token kill은 trigger에는 남지만 run tally에 임의 귀속되지 않는다.
14. BattleSnapshot v8 roundtrip이 kill tally를 보존하고 legacy v1~7은 빈 tally로 복원된다.
15. terminal 전 outcome 생성, request와 다른 BattleState, pending mutation 상태가 거부된다.
16. outcome player fact가 편성 slot·instance·body·생존·kill을 exact 보존한다.
17. 생존 출전 기물의 BATTLES_SURVIVED가 최대 5까지 오르고 파괴 시 0이 된다.
18. KILLS가 승패·생존과 무관하게 가산되고 미출전 기물 counter는 유지된다.
19. 전투 HP/status/link/token/transform이 RunState나 다음 request로 이월되지 않는다.
20. normal/boss 패배와 DRAW는 life −1, elite는 −2, 승리는 불변이다.
21. life 0은 reward 없이 RUN_FAILED이며 0 아래로 내려가지 않는다.
22. 승리는 completed REWARD, life가 남은 패배는 미완료 REWARD로 구분된다.
23. 같은 outcome 두 번째 적용과 stale sequence 적용이 호출 전 상태를 유지한다.
24. FORMATION·REWARD·RUN_FAILED RunSnapshot v1 capture/restore bytes가 exact다.
25. BATTLE capture/restore는 계속 거부된다.
26. malformed request/outcome/tally/snapshot count와 overflow가 bounded time에 실패한다.
27. 독립 Python이 battle seed와 RunSnapshot/BattleSnapshot 이관 bytes·SHA-256에 동의한다.
28. normal/elite/boss/DRAW 대표 4 battle이 같은 final result, life, counter, snapshot hash를 재현한다.
29. P1 trigger/result, P2 setup/dynamic, P3 AI, P4-1/2 대표 회귀가 통과한다.
30. Godot 4.6.3 `verify --demo`가 통과한다. `verify --full`과 16-seed route는 P4-6 milestone에서 실행한다.

## 구현 순서 — 전체 승인 뒤

1. 불변 request/entry/fact/outcome 값 객체와 append-only 진단을 추가한다.
2. node reachability와 FORMATION/편성 command를 후보 사본 commit으로 구현한다.
3. battle seed/request sequence와 `begin_battle`을 구현한다.
4. P2-M21 player-count 이관과 bridge build exact 검증을 구현한다.
5. BattleKillTally, transition rollback, BattleSnapshot v8/legacy를 구현한다.
6. terminal outcome 변환과 request 교차 검증을 구현한다.
7. counter·life·completed/phase outcome commit을 구현한다.
8. RunState phase 불변식과 RunSnapshot v1 capture/restore 활성화를 구현한다.
9. 독립 Python KAT와 Godot narrow를 먼저 통과시킨다.
10. 대표 P1~P4 회귀와 `verify --demo`를 실행한다.
11. 구현·검증 결과와 이관된 golden을 P4 인덱스·AGENTS에 기록한다.

## 승인 요청

구현 전 다음 묶음의 승인이 필요하다.

1. P4-B01~07: node 선택·편성·request·P2-M21 player-count 이관
2. P4-B08~11: 누적 처치 ledger·snapshot v8·런 카운터·D-12
3. P4-B12~16: DRAW/라이프·패배 node 진행·reward handoff·RunSnapshot phase
4. P4-B17: 데모 검증 범위
5. 전체 상세 명세와 구현 진입

특히 P4-B03은 기존 P2-M21, P4-B14는 game design U-14의 “패배 node 다음 진행” 미정을 바꾸는 재승인 지점이다. 둘을 승인하지 않으면 구현값을 추측하지 않고 P4-3을 대기 상태로 둔다.

## 구현·검증 기록

- 불변 `RunBattleRequest`/entry와 `RunBattleOutcome`/fact, `RunBattleBridge`, append-only 진단 및 `RUN_BATTLE_SEED=8`을 구현했다. node 선택·편성·request sequence/seed 생성·terminal outcome 적용은 후보 사본 검증 뒤 원자적으로 commit한다.
- `BattleSetupBuilder`의 player deployment를 승인된 `3..map.deploy_count`로 이관했다. enemy는 계속 map 정원과 정확히 같고 양쪽 slot은 0부터 연속이다. 기존 3대3 fixture의 body 순서는 유지된다.
- 초기 비토큰 body별 누적 처치를 `BattleKillTally`로 기록하고 transition rollback에 포함했다. `BattleSnapshot`은 v8로 올렸으며 legacy v1~7은 빈 tally로 복원한 뒤 v8로 재캡처한다.
- 승패·DRAW별 라이프 차감, 출전 기물의 `BATTLES_SURVIVED`/`KILLS`, D-12 전원 복원 경계, 승리 completed 및 패배 미완료 `REWARD`, life 0 `RUN_FAILED`, FORMATION·REWARD·RUN_FAILED RunSnapshot v1 저장을 구현했다. BATTLE 저장 금지는 유지된다.
- 독립 Python seed KAT와 1,000회 반복, Godot 15개 grouped check, P1 trigger/result·P2 setup/dynamic·P3 AI·P4-1/2 대표 회귀가 통과했다. Godot 4.6.3 `verify --demo`는 기본 게이트와 대표 러너 9종을 모두 통과했고 lore 미초기화 게이트만 정상 SKIP했다.
- 데모 프로필은 P0 반복 20회·순열 3종을 로컬/CI child runner에 동일하게 전달한다. `verify --full`과 16-seed 전체 route는 승인된 P4-B17에 따라 P4-6 단계 종료로 이연했다.
