# P4-1 · RunState·기물 인스턴스·RunSnapshot 상세 명세

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 상위 승인 | `p4_run_loop.md` P4-R01~17 |
| 선행 계약 | P0 결정론·SHA-256, P2 strict catalog/fingerprint, P4-R03 D-12 전투 후 전원 복원 |
| 후속 단계 | P4-2 act·encounter catalog와 결정론적 노드맵 생성 |
| 승인 | 2026-08-25 · 사용자 P4-S01~13 및 전체 명세 승인 |
| 구현 권한 | **있음. 승인된 P4-1 범위 구현 가능** |

## 목적

런의 나머지 시스템이 공유할 최소 권위 상태를 먼저 고정한다. 중복 보유 기물은 콘텐츠 ID와 분리된 안정 run instance ID를 가지며, 레벨과 런 스케일 카운터를 전투 밖에서 보존한다. `RunState`의 모든 권위 필드는 엔진 독립 정규 바이트로 캡처·복원할 수 있어야 한다.

P4-1은 노드 생성·전투 연결·보상 적용을 구현하지 않는다. 대신 P4-2~5가 같은 `RunSnapshot` v1에 값을 채울 수 있도록 graph·pending choice·inventory의 **고정 타입과 바이트 슬롯**까지 정의한다. P4-1 runtime 상태에서는 아직 소유 단계가 오지 않은 섹션을 비워 둔다.

## 정본과 선행 구현

- `docs/design/game_design.md` D-05·12·18·24~26, 7.8·7.9, 9.2·9.6, 14.1·14.4
- `docs/specs/p4_run_loop.md` P4-R03·06~10·16~17과 상태 모델 후보
- `docs/specs/p2_content_catalog.md`: `ContentCatalog`, strict JSON, numeric/string ID pair, fingerprint
- `docs/specs/p2_dynamic_piece_mechanics.md`: battle identity의 원본 piece ID와 token 경계
- `docs/specs/p1_ctb_battle_state.md`: 별도 도메인 snapshot, little-endian exact consumption, 안정 경계 capture
- `src/core/sim/sim_status.gd`: append-only numeric 진단과 first-error-wins
- `src/core/sim/sim_state_hash.gd`: 프로젝트 소유 SHA-256
- `src/core/battle/battle_snapshot.gd`: `FLICKBTL\0` snapshot codec의 구현 기준

## 범위

- append-only `RunPhase`, `RunNodeType`, `RunCounterKind`, `RunPendingKind`, `RunChoiceKind`
- 초기 중복 기물 요청 `RunPieceInit`
- 불변 값 객체 `RunCounter`, `RunPieceInstance`, `RunNode`, `RunNodeGraph`
- 미래 단계용 고정 값 객체 `RunChoiceEntry`, `RunPendingChoice`, `RunConsumableStack`
- 엔진·파일 I/O 비의존 `RunState` 생성·깊은 복사·읽기 API
- 정규 little-endian `RunSnapshot` v1 capture·encode·decode·restore
- 현재 catalog fingerprint와 roster piece/level 교차 검증
- snapshot bytes의 프로젝트 SHA-256와 독립 Python known-answer
- creation/copy/codec/restore 실패의 원본 불변성과 공학 한도

## 비범위

- act·encounter JSON과 catalog v7 이관
- seed에서 node graph를 만드는 `RunMapGenerator`
- node 선택·phase 전이·편성 명령
- `RunBattleRequest`·`RunBattleOutcome`과 D-12 실제 전투 정산
- reward 생성·영입·합성·gold 변경
- relic·consumable·event 효과와 inventory mutation
- `RunManager`·`SaveManager` autoload와 파일 시스템 저장
- UI·씬·manifest·에셋
- 이전 RunSnapshot migration. P4-1이 최초 schema다.

## 용어

| 용어 | 정의 |
|---|---|
| content ID | catalog 안에서 piece 종류를 식별하는 append-only numeric ID |
| instance ID | 한 런에서 중복 기물 각각을 식별하는 uint32 ID. 제거 뒤 재사용하지 않음 |
| initial key | 시작 로스터 요청의 저작 순서와 무관하게 instance ID를 배정하기 위한 양의 uint32 안정 키 |
| run counter | 특정 기물 instance에 붙어 전투를 넘어 유지되는 0 이상의 정수 카운터 |
| graph | 런 시작 시 고정되어 snapshot에 값으로 보존되는 층·노드·edge 집합 |
| pending choice | reward/shop/event/rest가 제시한, 재조회해도 바뀌지 않는 고정 후보 집합 |
| next sequence | 아직 쓰이지 않은 다음 ID/transition 번호. 항상 1 이상 |

## 승인 결정안

| ID | 결정안 | 이유 | 상태 |
|---|---|---|---|
| P4-S01 | 새 status 클래스를 만들지 않고 `SimStatus`에 run code 61~67과 operation 134~147을 append한다 | 결정 상태의 공통 first-error-wins·SHA-256 경계를 재사용 | ✅ 승인 |
| P4-S02 | RunSnapshot v1은 P4-2~5에서 쓸 graph·pending choice·relic·consumable 슬롯까지 처음부터 포함한다. P4-1 restore는 아직 소유 단계가 아닌 pending/inventory가 비어 있어야 통과한다 | 상위 P4의 “모든 RunState 권위 필드” 계약을 지키며 매 하위 단계 schema 상승을 피함 | ✅ 승인 |
| P4-S03 | 초기 instance ID는 `RunPieceInit.initial_key` 오름차순으로 1부터 배정한다. 요청 배열 순서를 교란해도 같은 ID가 되며 initial key는 snapshot에 저장하지 않는다 | 중복 piece도 안정적으로 식별하고 저작 배열 순서 의존 제거 | ✅ 승인 |
| P4-S04 | 합성은 P4-4에서 두 instance 중 작은 ID를 결과가 승계하고 큰 ID를 제거한다. `next_piece_instance_id`는 감소하지 않는다 | P4-R08의 ID 안정성·비재사용을 구체화 | ✅ 승인 |
| P4-S05 | 첫 run counter enum은 `BATTLES_SURVIVED=1`, `KILLS=2`다. 값은 1 이상만 저장하고 조회 시 없는 counter를 0으로 본다 | 용의 알·폰 요구를 일반 어휘로 표현하고 0 record의 이중 정본 방지 | ✅ 승인 |
| P4-S06 | phase는 `MAP_CHOICE=1`, `FORMATION=2`, `BATTLE=3`, `REWARD=4`, `SHOP=5`, `EVENT=6`, `REST=7`, `ACT_COMPLETE=8`, `RUN_COMPLETE=9`, `RUN_FAILED=10`으로 선점한다 | 이후 단계가 snapshot enum 번호를 바꾸지 않게 함 | ✅ 승인 |
| P4-S07 | node type은 일반=1, 엘리트=2, 상점=3, 이벤트=4, 휴식=5, 보스=6으로 고정한다. node ID는 floor→slot 순의 연속 uint32다 | P4-R05와 UI/fixture의 공통 정수 어휘 | ✅ 승인 |
| P4-S08 | 신규 RunState는 life/max life 3, gold 0, roster cap 10, deployment cap 5, phase MAP_CHOICE, next transition sequence 1로 시작한다 | D-24와 P4-R11의 초기값을 한 경계에서 고정 | ✅ 승인 |
| P4-S09 | RunSnapshot prefix는 ASCII `FLICKRUN\0` 9바이트, schema는 1, 정수는 little-endian이며 전체 trailing byte를 금지한다 | Sim/Battle snapshot과 분리된 도메인·독립 KAT 확보 | ✅ 승인 |
| P4-S10 | snapshot은 content fingerprint 32바이트를 저장하고 restore 시 현재 catalog와 byte-for-byte 비교한다. 불일치는 migration 없이 실패한다 | 콘텐츠 변경 뒤 잘못된 run 의미 복원 방지 | ✅ 승인 |
| P4-S11 | P4-1 capture/restore는 실제 생성 가능한 `MAP_CHOICE`만 활성화한다. 후속 단계가 각 phase를 열어도 P4-R16에 따라 `BATTLE` capture는 계속 거부한다 | 미구현 phase를 유효 상태로 오인하거나 전투 중 저장을 지원하는 것처럼 보이는 문제 방지 | ✅ 승인 |
| P4-S12 | P4-1 fixture는 승인된 5층 구조를 수동 graph로 만들고 현재 runtime의 `baduk_stone` 3개·`bottle_cap` 3개를 초기 key 1~6으로 넣는다 | 신규 콘텐츠 없이 graph·중복 instance·현재 fingerprint를 함께 검증 | ✅ 승인 |
| P4-S13 | 같은 fixture create/copy/snapshot/restore를 1,000회 반복하고 입력 배열 permutation 24개를 검사한다. P4-1에는 플레이 4런을 적용하지 않는다 | P4-R17의 순수 결정론 1,000회와 일반 런 검증의 소유권을 분리 | ✅ 승인 |

## enum 계약

모든 값은 append-only이며 0은 `INVALID`다.

```text
RunPhase
  INVALID=0
  MAP_CHOICE=1
  FORMATION=2
  BATTLE=3
  REWARD=4
  SHOP=5
  EVENT=6
  REST=7
  ACT_COMPLETE=8
  RUN_COMPLETE=9
  RUN_FAILED=10

RunNodeType
  INVALID=0
  NORMAL_BATTLE=1
  ELITE_BATTLE=2
  SHOP=3
  EVENT=4
  REST=5
  BOSS=6

RunCounterKind
  INVALID=0
  BATTLES_SURVIVED=1
  KILLS=2

RunPendingKind
  INVALID=0
  NONE=1
  REWARD=2
  SHOP=3
  EVENT=4
  REST=5

RunChoiceKind
  INVALID=0
  RECRUIT_PIECE=1
  TAKE_RELIC=2
  TAKE_CONSUMABLE=3
  GAIN_GOLD=4
  RECOVER_LIFE=5
  MERGE_PIECES=6
  EVENT_OPTION=7
```

`NONE`은 유효한 pending 상태이므로 `INVALID`와 구분한다. P4-1에서 `RunPendingChoice`는 `NONE`만 RunState에 들어갈 수 있다. 나머지 값은 codec 구조와 enum 번호만 고정하고 P4-4/P4-5가 의미 검증·mutation을 연다.

## 공학 한도

P4 전체 승인 ceiling을 사용한다. gameplay 상한과 별개다.

| 항목 | 한도 |
|---|---:|
| snapshot bytes | 16 MiB |
| act당 floor | 16 |
| floor당 node | 4 |
| run 전체 node | 192 |
| node당 outgoing edge | 4 |
| roster instance | 64 |
| deployment instance | 16 |
| instance당 run counter | 16 |
| relic 보유 ID | 64 |
| consumable stack record | 32 |
| pending choice entry | 8 |
| life/max life | 1~1,024 engineering range |
| gold | 0~uint32 max |

현재 gameplay 생성값은 life 3, roster cap 10, deployment cap 5다. P4-1은 정식 최대 상한 U-17을 확정하지 않으며 저장 필드와 engineering ceiling만 둔다.

## 값 객체

### RunPieceInit

```text
initial_key: uint32 > 0
piece_numeric_id: uint32 > 0
level: uint16, 1~3이며 실제 PieceDefinition에 존재
counters: RunCounter[], kind_id 오름차순
```

- create 입력 배열은 정렬되지 않아도 된다.
- `initial_key` 중복은 실패한다.
- piece ref는 현재 catalog에 존재하고 `is_token=false`여야 한다.
- 같은 piece ID·level의 여러 요청은 허용한다.
- 시작 로스터 수는 1~10이다. P4-1 fixture는 정확히 6개다.

### RunCounter

```text
kind_id: uint16
value: int64 > 0
```

- kind ID는 P4-1에서 1~2만 허용한다.
- 같은 instance 안에서 kind 중복을 금지한다.
- 0은 record로 저장하지 않는다. `counter_value(kind)`가 record 없음에 0을 반환한다.
- 감소로 0이 된 counter는 P4 후속 mutation에서 배열에서 제거한다.
- 음수와 int64 overflow를 거부한다.

### RunPieceInstance

```text
instance_id: uint32 > 0
piece_numeric_id: uint32 > 0
level: uint16
counters: RunCounter[], kind_id 오름차순
```

- RunState 배열은 instance ID 엄격 오름차순이다.
- instance ID 0, 중복, 역순, `next_piece_instance_id` 이상을 거부한다.
- current HP, status, attach/link, transform target, battle body ID, token은 저장하지 않는다.
- D-12에 따라 다음 전투 body는 catalog의 해당 level 최대 HP로 새로 만든다.

### RunConsumableStack

```text
consumable_numeric_id: uint32 > 0
count: uint16 > 0
```

- 배열은 numeric ID 엄격 오름차순이며 중복·0 count를 금지한다.
- P4-1 RunState에서는 배열이 비어 있어야 한다. P4-5가 catalog ref와 소지/stack 규칙을 활성화한다.

### RunChoiceEntry

```text
choice_id: uint16, 1부터 연속
choice_kind_id: uint16
primary_numeric_id: uint32
secondary_numeric_id: uint32
amount: int64
cost: uint32
enabled: bool
```

고정 슬롯의 의미는 choice kind별 상세 명세가 소유한다. P4-1은 타입·필드 폭·정렬만 고정하고 payload를 해석하거나 적용하지 않는다. Dictionary·Variant·문자열 payload는 금지한다.

### RunPendingChoice

```text
pending_kind_id: uint16
source_node_id: uint32
generation_ordinal: uint32
entries: RunChoiceEntry[], choice_id 오름차순
```

- `NONE`은 source/ordinal 0과 빈 entries만 허용한다.
- 다른 kind는 source node와 ordinal이 1 이상이고 entry가 1~8개여야 한다.
- P4-1 RunState는 `NONE`만 허용한다. codec은 구조적으로 유효한 다른 kind를 decode/re-encode할 수 있지만 restore는 해당 단계가 활성화되기 전 실패한다.

## RunNode와 RunNodeGraph

### RunNode

```text
node_id: uint32 > 0
floor_index: uint16, 1-based
slot_index: uint16, 0-based
node_type_id: uint16
content_numeric_id: uint32
next_node_ids: uint32[], 오름차순
```

- node 배열은 `(floor_index, slot_index)` 순이며 node ID는 그 순서대로 정확히 1부터 연속이다.
- 같은 floor에서 slot index는 0부터 연속이다.
- 일반·엘리트·보스는 encounter ID 후보인 nonzero content ID를 요구한다.
- 상점·이벤트는 profile ID 후보인 nonzero content ID를 요구한다.
- 휴식은 content ID 0만 허용한다.
- 마지막 floor 이외의 node는 다음 floor를 향한 edge가 1~4개다.
- 마지막 boss는 edge가 없다.

### RunNodeGraph

```text
floor_count: uint16
nodes: RunNode[], floor→slot 순
```

검증 순서:

1. floor 1~16, node 1~192, floor별 1~4개를 검사한다.
2. floor와 slot이 비거나 중복되지 않고 node ID가 1부터 연속인지 검사한다.
3. edge가 중복 없이 정렬됐고 정확히 다음 floor의 실제 node만 가리키는지 검사한다.
4. 첫 floor의 모든 node를 시작점으로 전방 순회해 모든 node가 도달 가능한지 검사한다.
5. 마지막 floor가 단일 BOSS이고 이전 모든 node에서 그 boss로 도달 가능한지 역방향으로 검사한다.
6. node type과 content ID 조합을 검사한다.

P4-1은 graph 구조만 검증한다. content ID가 실제 act/encounter/profile catalog record인지 확인하는 책임은 P4-2/P4-5가 같은 restore 경계에 추가한다.

### P4-1 수동 fixture graph

```text
floor 1: #1 NORMAL_BATTLE
             ├→ #2 SHOP ─┬→ #4 NORMAL_BATTLE ─┐
             └→ #3 EVENT ┴→ #5 ELITE_BATTLE ──┤
floor 4:                                  #6 REST
                                              ↓
floor 5:                                  #7 BOSS
```

정확한 edge:

```text
1 → [2,3]
2 → [4,5]
3 → [4,5]
4 → [6]
5 → [6]
6 → [7]
7 → []
```

content ID는 test fixture에서 node 1~5·7에 각각 독립 nonzero 값을 쓰고 REST만 0을 사용한다. 이 숫자는 production encounter/profile ID를 선점하지 않는다.

## RunState v1

```text
content_fingerprint: 32 bytes
seed_hi, seed_lo: uint32
phase_id: RunPhase
act_numeric_id: uint32
current_floor: uint16
current_node_id: uint32
life, max_life: uint16
gold: uint32
roster_capacity, deployment_capacity: uint16
next_piece_instance_id: uint32
next_transition_sequence: uint32
graph: RunNodeGraph
visited_node_ids: uint32[], 오름차순
completed_node_ids: uint32[], 오름차순
roster: RunPieceInstance[], instance ID 오름차순
deployment_instance_ids: uint32[], slot 순서
relic_numeric_ids: uint32[], 오름차순·유일
consumable_stacks: RunConsumableStack[], numeric ID 오름차순
pending_choice: RunPendingChoice
```

### 신규 상태

P4-2 이관 뒤 `RunState.create(catalog, act_numeric_id, seed_hi, seed_lo, initial_pieces, status)`는 catalog의 Act profile로 graph를 내부 생성하고 다음 값을 만든다.

- catalog fingerprint 사본
- phase `MAP_CHOICE`
- current floor/node 0
- life/max life `3/3`, gold 0
- roster/deployment cap `10/5`
- graph 사본
- visited/completed/deployment/relic/consumable 빈 배열
- pending `NONE`
- initial key 순 instance ID 1~N
- next piece instance ID `N+1`
- next transition sequence `1`

`act_numeric_id`는 P4-1에서 nonzero만 검사한다. P4-2가 catalog act ref 검증을 추가한다.

### 공통 불변식

- content fingerprint는 정확히 32바이트다.
- root seed 두 word는 uint32 범위이며 all-zero seed도 유효하다. 실제 RNG 파생은 P4-2가 소유한다.
- life는 0~max life, max life는 1~1,024다.
- roster capacity는 1~64, deployment capacity는 1~16이며 deployment capacity는 roster capacity 이하다.
- roster 수는 capacity 이하고, deployment ID는 roster에 존재하며 중복되지 않는다.
- visited/completed node는 graph에 존재하며 completed는 visited의 부분집합이다.
- current node 0 또는 graph의 실제 node다.
- next piece ID와 next transition sequence는 1 이상이고 기존 최대값보다 크다.
- relic/consumable은 P4-1에서 비어 있고 pending은 `NONE`이다.

### phase별 불변식

P4-1 생성 상태는 MAP_CHOICE만 만든다. 아래 불변식은 v1 codec에 선점하며 후속 단계가 명령을 구현한다.

| phase | current node | deployment | pending | 추가 조건 |
|---|---:|---|---|---|
| MAP_CHOICE | 0 | empty | NONE | terminal이 아니고 다음 floor가 남음 |
| FORMATION | battle node | empty 또는 유효 편성 | NONE | node는 visited, 미완료 |
| BATTLE | battle node | non-empty | NONE | capture 금지 |
| REWARD | completed battle node | empty | REWARD | life > 0 |
| SHOP | shop node | empty | SHOP 또는 NONE | node는 visited, 미완료/완료 상태와 일치 |
| EVENT | event node | empty | EVENT 또는 NONE | 동일 |
| REST | rest node | empty | REST 또는 NONE | 동일 |
| ACT_COMPLETE | completed boss | empty | NONE | boss는 현재 act 마지막 node |
| RUN_COMPLETE | completed boss | empty | NONE | 후속 act 없음은 P4-2가 검증 |
| RUN_FAILED | 0 또는 visited battle node | empty | NONE | life = 0 |

P4-1 restore는 실제로 생성 가능한 MAP_CHOICE 상태만 승인한다. 다른 phase의 구조 규칙은 codec에서 확인하되 state restore 활성화는 해당 소유 단계에서 연다.

## 공개 API

```text
RunPieceInit.create(initial_key, piece_numeric_id, level, counters, status)
RunCounter.create(kind_id, value, status)
RunPieceInstance.restore(instance_id, piece_numeric_id, level, counters, status)

RunNode.create(node_id, floor_index, slot_index, node_type_id,
               content_numeric_id, next_node_ids, status)
RunNodeGraph.create(floor_count, nodes, status)

RunChoiceEntry.create(choice_id, choice_kind_id, primary_numeric_id,
                      secondary_numeric_id, amount, cost, enabled, status)
RunPendingChoice.none()
RunPendingChoice.create(kind_id, source_node_id, generation_ordinal, entries, status)
RunConsumableStack.create(consumable_numeric_id, count, status)

RunState.create(catalog, act_numeric_id, seed_hi, seed_lo,
                initial_pieces, status) -> RunState
RunState.copy(status) -> RunState
RunState.is_initialized() -> bool
RunState.<scalar getters>()
RunState.graph_copy() -> RunNodeGraph
RunState.roster_at(index, status) -> RunPieceInstance
RunState.roster_by_instance_id(id, status) -> RunPieceInstance
RunState.deployment_instance_id_at(index, status) -> int
RunState.counter_value(instance_id, kind_id, status) -> int

RunSnapshot.capture(state, status) -> RunSnapshot
RunSnapshot.encode(status) -> PackedByteArray
RunSnapshot.decode(bytes, status) -> RunSnapshot
RunSnapshot.restore_state(catalog, status) -> RunState
```

- 배열·객체 getter는 불변 사본을 반환한다.
- generic dictionary getter와 공개 generic setter를 두지 않는다.
- 후속 mutation은 의미가 분명한 command method로 RunState에 추가하고, 후보 사본 검증 성공 뒤 한 번에 commit한다.
- `restore` 이름의 값 객체 생성자는 검증된 snapshot decoder와 테스트 fixture만 사용한다.

## RunSnapshot v1 정규 바이트

모든 정수는 little-endian이다. `u16`, `u32`, `i64` 이외의 암묵적 Variant 직렬화를 사용하지 않는다.

| 순서 | 필드 |
|---:|---|
| 1 | magic `FLICKRUN\0` 9 bytes |
| 2 | `schema_version:u16 = 1` |
| 3 | `content_fingerprint:32 bytes` |
| 4 | `seed_hi:u32`, `seed_lo:u32` |
| 5 | `phase_id:u16` |
| 6 | `act_numeric_id:u32`, `current_floor:u16`, `current_node_id:u32` |
| 7 | `life:u16`, `max_life:u16`, `gold:u32` |
| 8 | `roster_capacity:u16`, `deployment_capacity:u16` |
| 9 | `next_piece_instance_id:u32`, `next_transition_sequence:u32` |
| 10 | graph section |
| 11 | visited node section |
| 12 | completed node section |
| 13 | roster section |
| 14 | deployment section |
| 15 | relic section |
| 16 | consumable section |
| 17 | pending choice section |
| 18 | exact EOF |

### graph section

```text
floor_count:u16
node_count:u32
repeat node_count:
  node_id:u32
  floor_index:u16
  slot_index:u16
  node_type_id:u16
  content_numeric_id:u32
  next_count:u16
  next_node_ids[next_count]:u32
```

### node history sections

```text
visited_count:u32
visited_node_ids[visited_count]:u32
completed_count:u32
completed_node_ids[completed_count]:u32
```

### roster section

```text
roster_count:u32
repeat roster_count:
  instance_id:u32
  piece_numeric_id:u32
  level:u16
  counter_count:u16
  repeat counter_count:
    counter_kind_id:u16
    value:i64
```

### deployment·inventory sections

```text
deployment_count:u16
deployment_instance_ids[deployment_count]:u32

relic_count:u16
relic_numeric_ids[relic_count]:u32

consumable_count:u16
repeat consumable_count:
  consumable_numeric_id:u32
  stack_count:u16
```

### pending choice section

```text
pending_kind_id:u16
source_node_id:u32
generation_ordinal:u32
entry_count:u16
repeat entry_count:
  choice_id:u16
  choice_kind_id:u16
  primary_numeric_id:u32
  secondary_numeric_id:u32
  amount:i64
  cost:u32
  enabled:u8   # 0 or 1
```

P4-1 capture는 initialized RunState, 완전한 구조 검증, phase가 MAP_CHOICE, 활성화되지 않은 섹션이 empty임을 요구한다. 실패 시 빈 bytes와 미초기화 snapshot을 반환하고 RunState를 바꾸지 않는다. 후속 단계가 phase를 활성화해도 BATTLE capture 금지는 유지한다.

decoder는 count를 읽은 직후 ceiling과 `remaining/min_record_size`를 함께 검사한다. 잘린 데이터·과대 count·잘못된 bool·정렬/중복 위반·unknown enum·trailing bytes를 기본값으로 보정하지 않는다.

## 복원과 fingerprint

1. decode는 content 존재 여부를 모른 채 바이트 구조와 domain ceiling만 검증한다.
2. restore는 현재 `ContentCatalog`가 initialized인지 확인한다.
3. snapshot fingerprint와 catalog fingerprint 32바이트를 exact 비교한다.
4. roster의 각 piece ID를 catalog에서 찾고 token이 아니며 level이 존재하는지 확인한다.
5. graph content ref, act ref, relic/consumable ref, pending payload의 의미 검증은 각 소유 단계에서 같은 restore 경계에 추가한다.
6. 모든 검증이 끝난 뒤에만 initialized RunState를 반환한다.

P4-1 이전 RunSnapshot은 존재하지 않으므로 legacy decode가 없다. unknown version은 `UNSUPPORTED_SCHEMA`다. 미래 schema가 생기면 구버전 지원·migration 여부를 해당 명세에서 승인한다.

P4-2에서 catalog v7로 fingerprint가 바뀌면 P4-1 fixture의 승인 fingerprint·전체 hex·SHA known-answer를 새 catalog 기준으로 명시 이관한다. RunSnapshot schema와 필드 순서는 바꾸지 않으며, 설명되지 않은 roster·graph 값 변화가 있으면 이관을 중단한다.

## 결정론·원자성

- `RunState`와 값 객체는 `RefCounted`만 사용하며 `Node`, `Time`, `FileAccess`, Godot RNG를 호출하지 않는다.
- 입력 배열은 안정 key로 정렬하거나 정렬된 입력을 검증한 뒤 저장한다.
- Dictionary 순회를 snapshot·ID 배정·hash 입력에 사용하지 않는다.
- instance ID, node ID, next sequence는 uint32 의미 범위에서 checked 증가한다.
- copy는 graph·roster·counter·choice 배열을 깊게 복제한다.
- create/copy/capture/decode/restore 실패는 입력 객체와 기존 state를 바꾸지 않는다.
- 동일 의미를 여러 바이트로 표현하지 않는다: zero counter·zero stack을 저장하지 않고 정규 배열은 엄격 정렬한다.
- 상태 비교 정본은 RunSnapshot bytes다. 회귀 표시는 `SimStateHash.hex_digest(snapshot_bytes, status)`의 SHA-256을 재사용하되 hash를 게임 판정·RNG seed로 쓰지 않는다.

## 진단 계약

`SimStatus`의 기존 번호를 바꾸지 않고 append한다.

### Code

| 값 | 이름 |
|---:|---|
| 61 | `INVALID_RUN_STATE` |
| 62 | `INVALID_RUN_PIECE_INSTANCE` |
| 63 | `INVALID_RUN_COUNTER` |
| 64 | `INVALID_RUN_NODE` |
| 65 | `INVALID_RUN_GRAPH` |
| 66 | `INVALID_RUN_CHOICE` |
| 67 | `RUN_LIMIT_EXCEEDED` |

기존 `INVALID_ARGUMENT`, `DUPLICATE_ID`, `NOT_FOUND`, `COUNTER_EXHAUSTED`, `UNSUPPORTED_SCHEMA`, `INVALID_SNAPSHOT`, `INVALID_PHASE`, `CONTENT_FINGERPRINT_MISMATCH`를 의미가 같은 곳에서 재사용한다.

### Operation

| 값 | 이름 |
|---:|---|
| 134 | `RUN_PIECE_INIT_CREATE` |
| 135 | `RUN_PIECE_INSTANCE_CREATE` |
| 136 | `RUN_COUNTER_CREATE` |
| 137 | `RUN_NODE_CREATE` |
| 138 | `RUN_GRAPH_CREATE` |
| 139 | `RUN_CHOICE_CREATE` |
| 140 | `RUN_PENDING_CHOICE_CREATE` |
| 141 | `RUN_STATE_CREATE` |
| 142 | `RUN_STATE_COPY` |
| 143 | `RUN_STATE_VALIDATE` |
| 144 | `RUN_SNAPSHOT_CAPTURE` |
| 145 | `RUN_SNAPSHOT_ENCODE` |
| 146 | `RUN_SNAPSHOT_DECODE` |
| 147 | `RUN_SNAPSHOT_RESTORE` |

`detail_a/detail_b`는 operation별로 고정한다.

| operation | detail_a | detail_b |
|---|---|---|
| piece init/instance | initial key 또는 instance ID | piece numeric ID |
| counter | owner instance ID, 없으면 0 | counter kind ID |
| node | node ID | floor 또는 참조 node ID |
| graph | 실제 count/node ID | ceiling/이전 ID |
| choice | choice ID | choice kind ID |
| state validate | phase 또는 instance ID | 위반 값 |
| snapshot decode | reader offset | remaining bytes 또는 읽은 count |
| snapshot restore | snapshot 값 | catalog/기대값 |

first-error-wins를 지키며 문자열 오류를 권위 상태나 golden에 넣지 않는다.

## 대상 파일

### 신규

```text
docs/specs/p4_run_state_snapshot.md
src/core/run/run_phase.gd
src/core/run/run_node_type.gd
src/core/run/run_counter_kind.gd
src/core/run/run_pending_kind.gd
src/core/run/run_choice_kind.gd
src/core/run/run_limits.gd
src/core/run/run_piece_init.gd
src/core/run/run_counter.gd
src/core/run/run_piece_instance.gd
src/core/run/run_node.gd
src/core/run/run_node_graph.gd
src/core/run/run_choice_entry.gd
src/core/run/run_pending_choice.gd
src/core/run/run_consumable_stack.gd
src/core/run/run_state.gd
src/core/run/run_snapshot.gd
pipeline/tests/p4_run_state_snapshot_test.gd
pipeline/tests/p4_run_state_snapshot_reference.py
pipeline/tests/run_p4_run_state_snapshot.py
pipeline/tests/fixtures/p4_run_state_snapshot/**
```

### 수정

```text
src/core/sim/sim_status.gd
AGENTS.md
HANDOFF.md
docs/specs/p4_run_loop.md
```

`project.godot`, `DataDB`, runtime JSON, scene, UI, asset, manifest는 바꾸지 않는다.

## 필요 에셋

없음. P4-1은 headless core와 fixture만 추가한다.

## 수용 기준

1. 새 enum의 숫자가 명세와 일치하고 기존 `SimStatus` 번호가 불변이다.
2. initial key 배열 순서를 교란해도 instance ID·roster·snapshot bytes가 같다.
3. initial key 0/중복, piece ID 0/누락, token piece, 없는 level, 빈/11개 시작 roster가 각각 실패한다.
4. 같은 piece·level의 중복 3개가 서로 다른 연속 instance ID를 얻는다.
5. roster는 instance ID 엄격 오름차순이고 next instance ID가 기존 최대보다 크다.
6. counter kind·값·정렬·중복·16/17개 경계가 검증되며 zero counter의 별도 표현이 없다.
7. 승인 fixture graph가 통과하고 node ID·floor·slot·edge의 정규 순서를 만든다.
8. floor/node/width/edge ceiling의 경계와 초과가 각각 통과·실패한다.
9. 잘못된 floor gap·slot gap·역방향/건너뛰기 edge·중복 edge·없는 target·고립 node·boss 다중/누락·boss outgoing이 각각 실패한다.
10. node type과 content ID의 허용 조합이 검증된다.
11. pending NONE의 zero-field 계약이 통과하고 잘못된 NONE payload가 실패한다.
12. future pending entry의 연속 choice ID·known kind·bool·8/9개 경계가 codec 구조에서 검증된다.
13. 신규 RunState가 life 3, gold 0, cap 10/5, MAP_CHOICE, next transition 1과 빈 미래 섹션을 가진다.
14. RunState가 current HP·battle body ID·status·token을 저장하지 않고 D-12 경계를 침범하지 않는다.
15. copy 뒤 사본의 내부 배열을 테스트 helper로 교란해도 원본 snapshot bytes가 유지된다.
16. `FLICKRUN\0` v1 전체 fixture bytes와 SHA-256이 독립 Python known-answer와 일치한다.
17. encode→decode→encode와 restore→capture→encode가 exact byte-for-byte 일치한다.
18. magic·version·각 scalar·count·record·bool 손상, 모든 절단 위치, trailing bytes가 실패한다.
19. count bomb가 allocation 전에 ceiling/remaining 검사로 실패한다.
20. 다른 catalog fingerprint와 restore하면 `CONTENT_FINGERPRINT_MISMATCH`이며 snapshot은 변하지 않는다.
21. catalog에 없는 piece, token piece, 없는 level을 가진 구조-valid snapshot이 restore에서 실패한다.
22. P4-1 capture/restore는 MAP_CHOICE만 통과하고 다른 phase는 실패한다. 후속 단계 활성화 뒤에도 BATTLE capture는 계속 실패한다.
23. 같은 fixture create/copy/decode/restore 1,000회가 같은 bytes/hash를 만든다.
24. initial input permutation 24개가 같은 bytes/hash를 만든다.
25. 독립 Python reference와 Godot narrow가 모두 통과하고 `run_p4_run_state_snapshot.py`가 verify에서 자동 발견된다.
26. P0 SHA/snapshot, P1 BattleSnapshot, P2 content fingerprint, P3 AI 대표 narrow가 회귀 통과한다.
27. 데모 정책의 `verify --demo`가 통과한다. P4-1에는 UI·플레이 4런·스크린샷 검수를 요구하지 않는다.

## 구현 순서

1. enum·limits·진단 번호와 독립 Python binary writer/negative KAT를 먼저 고정한다.
2. counter·piece init/instance 불변 값 객체와 초기 key ID 배정을 구현한다.
3. node·graph 타입과 6단계 구조 검증을 구현한다.
4. pending choice·consumable의 고정 codec 타입을 구현하되 P4-1 state에서는 비활성으로 둔다.
5. RunState 생성·깊은 복사·조회·전체 불변식 검증을 구현한다.
6. RunSnapshot v1 capture/encode/decode/restore와 fingerprint 검증을 구현한다.
7. 전체 fixture hex/SHA, 손상/한도, 1,000회, 24 permutation narrow를 통과시킨다.
8. P0~P3 대표 narrow와 `verify --demo`를 실행한다.
9. 구현·검증 결과를 P4 인덱스·AGENTS·HANDOFF에 기록한다.

## 승인 기록

2026-08-25 사용자는 P4-S01~13과 전체 상세 명세를 승인하고 구현 진입을 지시했다. `RunSnapshot` v1 future 슬롯, initial key 기반 instance ID, 작은 ID 합성 승계, generic run counter 계약을 승인 기준선으로 고정한다.

## 구현·검증 기록

2026-08-25 승인 범위 구현과 자동 검증을 완료했다.

- `src/core/run/`에 append-only enum, limits, 불변 값 객체, 6단계 graph 검증, `RunState`, `RunSnapshot` v1을 추가했다.
- 현재 catalog의 non-token piece/level 및 fingerprint를 create/restore 경계에서 검증한다. P4-1 state는 `MAP_CHOICE`와 빈 pending/inventory만 복원하며 전투 상태를 저장하지 않는다.
- 독립 Python writer와 Godot codec이 동일한 339-byte `FLICKRUN\0` v1을 만들고 SHA-256 `e2120285dd7abfe00d085413b4a4f4244591f7e98c03fa3e1626d58e8996dd64`에 일치한다.
- Godot narrow 17개 grouped check에서 전체 절단 위치, scalar/record/count/bool 손상, count bomb, trailing bytes, fingerprint·piece·level restore 거부, future pending codec/restore gate를 확인했다.
- 동일 fixture create/copy/decode/restore 1,000회와 initial input permutation 24개가 동일 bytes/hash를 만들었다.
- P0 quick snapshot/SHA, P1 BattleSnapshot, P2 content fingerprint, P3 AI 대표 narrow가 통과했다.
- Godot 4.6.3 승인 quick 환경의 `verify --demo`가 기본 게이트와 대표 러너 8종 모두 통과했다. canon 미초기화에 따른 lore 기계 검사는 정책대로 SKIP이다.
- `project.godot`, `DataDB`, runtime JSON, scene, UI, asset, manifest는 변경하지 않았다. 실제 4런·스크린샷 검수는 P4-1 범위가 아니다.

### P4-2 이관 기록

2026-08-25 P4-2 승인 구현에서 provisional graph 주입 seam을 제거했다. `RunState.create`는 catalog·act·seed로 graph를 생성하고, restore/validate는 저장 graph와 재생성 graph를 exact 비교한다. catalog v7 fingerprint와 개발 Act graph를 반영한 `RunSnapshot` v1 KAT는 331 bytes, SHA-256 `73ea51d49acb0fc2b1f2b1d696241dcf724937653e42d1249d63d66f9ff34797`이며 snapshot schema와 run scalar/roster 계약은 바뀌지 않았다.

2026-08-25 P5-DZ catalog/fingerprint v8 이관에서도 `RunSnapshot` v1 구조와 331-byte 길이는 유지되었다. 새 콘텐츠 지문을 반영한 현재 SHA-256은 `8c8671cd39afe6defc986644d56122315cd6191d03793416620d2fbf95f87c04`다.
