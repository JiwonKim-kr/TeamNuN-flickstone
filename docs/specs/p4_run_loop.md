# P4 · 런 루프 명세 초안

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 승인 | 2026-08-25 · 사용자: P4-R01~16 및 4런으로 수정한 P4-R17 승인 |
| 단계 | 설계 로드맵 P4 · 런 루프 |
| 선행 단계 | P0 결정론 시뮬레이션, P1 전투 루프, P2 데이터 기반 콘텐츠, P3 적 AI 완료 |
| 병행 산출물 | `p4_submission_web_preview.md`의 공개 Web 프리뷰는 구현·배포 완료 |
| 구현 권한 | **P4 전체 방향 승인. P4-1부터 하위 상세 명세별 별도 승인 필요** |

## 목적

현재 한 판짜리 P2/P3 전투 수직 슬라이스를 데이터 기반 런으로 연결한다. 플레이어는 시작 로스터를 받아 분기 노드를 선택하고, 전투 전 편성을 정하고, 승패·라이프·보상·휴식·덱 변화를 다음 노드로 이어 간다. 개발용 축약 Act 1을 처음부터 보스까지 완주할 수 있어야 한다.

P4 완료는 정식 3막 밸런스 완료가 아니다. 동일한 런 코어와 데이터 스키마로 **축약 1막을 완주**하고 저장·복원·결정론 회귀를 통과하는 것을 의미한다. 정식 3막 콘텐츠 양과 밸런스는 P6가 소유한다.

## 정본과 현재 구현

- `docs/design/game_design.md` D-05·09·12·14·18·20·24~26, 3장, 7.8~7.10, 9~10장, 13~17장, U-04·07·09·11·13~18·40·42·47
- `docs/specs/p2_content_catalog.md`: strict JSON, append-only ID, typed immutable catalog, atomic `DataDB`, canonical fingerprint
- `docs/specs/p2_maps_enemies_environment.md`: map/enemy 정의와 `BattleSetupBuilder`
- `docs/specs/p2_content_graybox.md`: 현재 runtime 콘텐츠와 플레이 가능한 전투 브리지
- `docs/specs/p3_ai_shot_selection.md`: enemy의 `ai_grade_id`와 결정론적 적 발사
- `docs/specs/p4_submission_web_preview.md`: 640×1,024 Web 빌드와 Pages 배포 계약

현재 runtime에는 플레이어 기물 2종과 명시적 graybox 전용 기물 1종, COMMON/ELITE/BOSS 적 5종, 맵 1종, 개발 Act 1개와 encounter 4개가 있다. relic·consumable 문서는 P4-2에서 빈 schema만 선점했고 실제 record와 event 데이터, `RunManager`·`SaveManager`는 아직 없다.

### P4 이름 충돌

설계 로드맵은 P4를 **런 루프**로 정의하지만, 제출 일정 중 먼저 완료한 Web 프리뷰 문서도 `P4` 이름을 사용한다. 기존 커밋·문서 경로를 역사적으로 다시 쓰지 않고 아래 P4-R01로 역할을 분리하는 것이 권장안이다.

## 확정 정본에서 상속하는 기준

아래 항목은 새 결정이 아니라 기존 설계 정본을 그대로 따른다.

1. 런은 StS식 분기 노드맵이며 정식 구성은 3막×10층, 각 막 마지막 층은 보스다.
2. 노드 유형은 일반 전투·엘리트 전투·상점·이벤트·휴식·보스다.
3. 초기 보유 상한은 10, 출전 상한은 5이며 실제 출전 수는 보유 수·출전 상한·맵 슬롯 수의 최솟값이다.
4. 맵의 고정 슬롯에 어떤 기물 인스턴스를 배치할지만 플레이어가 고른다.
5. 라이프는 3에서 시작하고, 일반/보스 패배 시 −1, 엘리트 패배 시 −2이며 0에서 런 실패다. D-12에 따라 전투 후 로스터는 전원 복원된다.
6. 승리 보상에는 기물 영입이 기본 포함되며 유물·소모품·골드가 별도 보상 축이다.
7. 휴식은 라이프 1 회복과 같은 기물·같은 레벨 2개 합성 중 선택하는 구조다. 레벨 상한은 3이다.
8. 동일 런 시드와 동일한 노드·편성·보상 선택·발사 입력은 같은 런 결과를 만들어야 한다.

## 범위

- 엔진 비의존 `RunState`와 안정 ID를 가진 보유 기물 인스턴스
- 정규 `RunSnapshot`과 저장/복원 I/O 경계
- act·encounter·relic·consumable 데이터의 strict schema, typed definition, canonical fingerprint
- 런 시드에서 결정론적으로 만드는 층별 분기 노드맵과 안정 node ID·edge
- 일반·엘리트·상점·이벤트·휴식·보스 노드의 공통 진입/완료 상태 머신
- 로스터·출전 편성·보유/출전 상한 검증
- 기존 `BattleSetupBuilder`로 전달하는 전투 요청과 `BattleResult`를 런에 반영하는 원자적 경계
- 승패에 따른 라이프, 전투 후 복원, 다음 노드 진행
- 기물 영입 후보, 골드, 유물, 소모품, 합성의 공통 보상/인벤토리 경계
- 640×1,024에서 노드맵→편성→전투→결과/보상→다음 노드를 오가는 회색상자 UI
- 개발용 축약 Act 1 데이터와 처음부터 보스까지의 사람 플레이 검수

## 비범위

- 정식 3막 전체 콘텐츠 30층과 35~45 encounter 제작
- 유물 30~40종, 소모품 12~16종, 이벤트 15~20종의 본 제작
- 41종 전체 기물의 레벨 2·3 데이터와 최종 시작 덱
- 메타 해금, 도감 영구 저장, 승급 난이도
- 정식 경제·드롭률·승률·라이프 곡선 밸런싱
- 클라우드 저장, 여러 세이브 슬롯, 계정 동기화
- 리플레이 파일 UI와 온라인 검증
- 정식 아트·VFX·SE·튜토리얼

## 용어

| 용어 | 정의 |
|---|---|
| 런 | 시작 로스터 생성부터 라이프 0 또는 마지막 막 완료까지의 상위 세션 |
| 막(Act) | 여러 층과 마지막 보스로 이루어진 런 구간 |
| 층(Floor) | 같은 세로 단계에 놓인 선택 가능한 노드 집합 |
| 노드 | 전투·상점·이벤트·휴식 등 한 번 방문하는 런 단위 |
| 로스터 | 런에서 보유한 비토큰 기물 인스턴스 전체 |
| 편성 | 다음 전투에 출전시킬 로스터 instance ID의 순서 있는 목록 |
| encounter | map ref, enemy ref 목록, 노드 난도와 보상 profile을 묶은 데이터 |
| pending choice | 노드 완료 뒤 반드시 선택하거나 명시적으로 건너뛰어야 하는 고정 후보 집합 |
| 개발 Act | 검증 시간을 줄이기 위해 `acts.json`으로 층 수를 축약한 정식 코어 사용 데이터 |

## 권장 단계 분해

| 하위 단계 | 내용 | 완료 경계 |
|---|---|---|
| P4-1 | [`p4_run_state_snapshot.md`](p4_run_state_snapshot.md) · RunState·기물 인스턴스·RunSnapshot·원자 명령 | **구현·자동 검증 완료** · 생성/복사/오류 rollback/정규 bytes 결정론 |
| P4-2 | [`p4_act_encounter_map_generation.md`](p4_act_encounter_map_generation.md) · act·encounter catalog와 분기 노드맵 | **승인·구현·자동 검증 완료** · catalog v7, generated graph exact 복원, 전 노드 도달 가능 |
| P4-3 | [`p4_formation_battle_outcome_life.md`](p4_formation_battle_outcome_life.md) · 편성·BattleSetup 요청·전투 결과·라이프 | **승인·구현·자동 검증 완료** · 전투 승패가 정확히 한 번 런 상태에 반영됨 |
| P4-4 | 영입·골드·휴식·합성·덱 관리 | 후보 고정, 상한·중복·레벨 3 계약, 선택 rollback |
| P4-5 | 유물·소모품·상점·이벤트 공통 프레임 | 최소 승인 콘텐츠로 여섯 노드 유형을 모두 완료 가능 |
| P4-6 | 축약 Act 1 UI·저장/이어하기·배치 런 | 처음부터 보스까지 자동/사람 완주 |

이 문서는 P4 전체 인덱스 역할을 겸한다. **전체 초안 승인만으로 하위 단계의 `src/core/` 구현 권한을 열지 않고, P4-1부터 상세 명세를 별도 승인한다.**

## 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P4-R01 | 기존 Web 프리뷰는 역사적 파일명을 유지하되 문서상 `P4-W · 제출/배포 보조 트랙`으로 분류하고, 로드맵 P4는 런 루프만 뜻한다 | 파일·커밋 재작성 없이 번호 충돌 해소 | ✅ 승인 |
| P4-R02 | 위 P4-1~6으로 나누고 하위 상세 명세마다 별도 승인한다 | 저장·콘텐츠·전투·UI를 한 번에 바꾸는 회귀 위험 축소 | ✅ 승인 |
| P4-R03 | D-12는 **매 전투 종료 후 파괴 포함 전원 부활·HP 완전 복원**으로 확정한다. 상태·전투 scope 값은 폐기하고 레벨·런 카운터만 유지한다 | 라이프를 유일한 장기 소모 자원으로 유지하며 현재 D-24·휴식 계약과 가장 잘 맞음 | ✅ 승인 |
| P4-R04 | P4 완료용 개발 Act는 1막 5층, 1층 일반 전투·5층 보스 고정으로 한다. 중간 층 분기는 데이터로 일반/엘리트/상점/이벤트/휴식을 노출한다 | 정본 9.7의 권장 축약이며 1회 검수 시간을 제한 | ✅ 승인 |
| P4-R05 | 노드맵은 층별 profile을 입력으로 생성하는 DAG다. node ID는 floor→slot 순으로 배정하고 edge는 다음 층만 향하며, 모든 노드는 시작에서 도달하고 보스로 이어져야 한다 | 안정 ID·분기 선택·검증 가능한 생성 계약 | ✅ 승인 |
| P4-R06 | 런 코어는 `Node`/파일 I/O 없는 `src/core/run/`에 두고, 모든 공개 명령은 사본에서 검증한 뒤 한 번에 commit한다 | 기존 P0~P3 원자성·엔진 분리 원칙 유지 | ✅ 승인 |
| P4-R07 | 노드맵·encounter·reward·event는 `RUN_*` purpose ID와 `(act, floor, node, visit/choice ordinal)`로 파생한 비소비 RNG를 쓴다. UI 조회·재진입은 후보를 다시 뽑지 않는다 | 조회 순서·저장 복원·후보 수 변화가 다른 난수열을 오염시키지 않음 | ✅ 승인 |
| P4-R08 | 보유 기물은 content piece ID와 분리된 run instance ID를 1부터 단조 증가·비재사용한다. level과 런 카운터는 instance에 붙고 token은 로스터에 들어오지 않는다 | 중복 보유·합성·용의 알/폰 카운터의 안정 정본 | ✅ 승인 |
| P4-R09 | `acts.json`, `encounters.json`, `relics.json`, `consumables.json`과 registry namespace를 append-only로 추가하고 catalog/fingerprint를 v7로 올린다. `events.json`은 P4-5 상세 명세에서 포함 여부를 확정한다 | 현재 catalog/DataDB 원자 로드를 재사용하고 event DSL 과설계를 방지 | ✅ 승인 |
| P4-R10 | 전투 진입은 불변 `RunBattleRequest`, 귀환은 불변 `RunBattleOutcome`으로만 연결한다. 동일 node의 outcome은 정확히 한 번만 적용 가능하다 | UI가 RunState/BattleState를 직접 교차 수정하는 경로 차단 | ✅ 승인 |
| P4-R11 | 개발 시작 로스터는 `baduk_stone` 3개 + `bottle_cap` 3개, 보유 상한 10·출전 상한 5를 사용한다. 현재 맵에서는 슬롯 제한으로 3개를 편성한다 | 신규 기물 수치를 만들지 않고 중복·편성·시너지 선택을 검수 | ✅ 승인 |
| P4-R12 | 개발 영입은 runtime 로스터용 2종에서 중복 허용 후보 2개를 만들고 하나를 선택한다. weight는 `1 + 후보와 일치하는 활성 태그별 직전 편성 미중복 수`의 합으로 한다 | 10.2의 비례·다중 태그 원칙을 최소 정수식으로 구체화 | ✅ 승인 |
| P4-R13 | 개발 Act의 보유 상한 도달 전에는 영입을 강제하고, 상한이면 영입을 건너뛰되 대체 보상은 주지 않는다. 정식 스킵/방출/대체 보상은 후속 승인으로 남긴다 | 6→최대 9개인 5층 slice에서는 정상 경로에 영향 없이 overflow를 명시 처리 | ✅ 승인 |
| P4-R14 | 휴식은 P4에서 라이프 회복 또는 **한 번의** 합성만 제공하고 3번째 선택지는 잠금 표시한다. 최대 라이프에서는 회복을 비활성화한다 | 미정 선택지를 발명하지 않고 확정된 두 축만 검수 | ✅ 승인 |
| P4-R15 | P4-5는 graybox 전용 유물·소모품·이벤트를 각 1개 이상 별도 상세 승인해 상점/이벤트 경로를 작동시킨다. 정식 목록으로 간주하지 않는다 | 데이터/효과 연결은 검증하되 콘텐츠 제작 범위 폭발 방지 | ✅ 승인 |
| P4-R16 | 저장은 단일 continue 슬롯만 제공한다. 노드 진입 전·노드 결과 commit 후에 원자 저장하고 전투 중 저장은 하지 않는다 | 첫 저장 경계를 작게 유지하고 중간 BattleSnapshot 결합을 연기 | ✅ 승인 |
| P4-R17 | 일상 검증은 고정 2 seeds×대표 2 route의 **4런**, 단계 종료는 16 seeds×모든 고정 route profile을 사용한다. 1,000회는 RunState/graph/snapshot 순수 결정론에만 적용한다 | 시간 제약에 맞춰 일반 검증을 더 줄이면서 결정론 핵심과 단계 종료 범위는 유지 | ✅ 승인 |

## 상태 모델 후보

### RunState

```text
RunState
  content_fingerprint: 32 bytes
  seed_hi, seed_lo: uint32
  phase_id: RunPhase
  act_numeric_id: uint32
  current_floor: uint16
  current_node_id: uint32
  visited_node_ids[]: uint32 sorted
  completed_node_ids[]: uint32 sorted
  life, max_life: uint16
  gold: uint32
  roster[]: RunPieceInstance sorted by instance_id
  deployment_instance_ids[]: uint32 ordered by slot
  relic_refs[]: ContentIdRef sorted
  consumable_stacks[]: RunInventoryStack sorted
  run_counters[]: RunCounter sorted by owner/type
  pending_choice: RunPendingChoice
  next_piece_instance_id: uint32
  transition_sequence: uint32
```

`RunPhase` 후보:

```text
INVALID → MAP_CHOICE → FORMATION → BATTLE → REWARD
                    ↘ SHOP / EVENT / REST
REWARD·SHOP·EVENT·REST → MAP_CHOICE
BATTLE → RUN_FAILED
BOSS REWARD → ACT_COMPLETE → MAP_CHOICE 또는 RUN_COMPLETE
```

- phase에 맞지 않는 명령은 실패하며 상태를 바꾸지 않는다.
- 현재 node와 pending choice는 동시에 둘 이상의 미완료 작업을 갖지 않는다.
- `RunState`는 `ContentCatalog` 참조를 보관하지 않고 ID·fingerprint·런 값만 저장한다.
- UI 표시 문자열과 번역 텍스트는 snapshot·hash에 넣지 않는다.

### RunPieceInstance

```text
instance_id: uint32
piece_numeric_id: uint32
level: uint8
counters[]: (counter_kind_id:uint16, value:int64) sorted
```

- 같은 piece ID를 여러 instance가 가질 수 있다.
- 합성은 같은 piece ID·같은 level 두 instance를 제거하고, 작은 instance ID를 결과가 승계하며 다른 ID는 재사용하지 않는다.
- 편성은 살아 있는 battle body ID가 아니라 run instance ID를 저장한다.
- battle body와 run instance의 대응은 `RunBattleRequest`가 별도 안정 매핑으로 제공한다.

### RunNodeGraph

```text
RunNode
  node_id: uint32
  floor_index: uint16
  slot_index: uint16
  node_type_id: uint16
  content_numeric_id: uint32
  next_node_ids[]: uint32 sorted
```

- graph는 런 시작 시 한 번 생성해 snapshot에 값으로 저장한다.
- node ID는 0을 금지하고 floor→slot 순으로 단조 배정한다.
- edge는 다음 floor만 가리키며 중복·자기 참조·고립 node를 금지한다.
- 마지막 floor는 단일 BOSS node이고 outgoing edge가 없다.

## 데이터 후보

### `acts.json`

- act ID, production/development 여부
- floor 수와 마지막 boss floor
- 층별 node 수, 허용 node type과 integer weight/quota
- encounter/reward/event profile ref
- graph generation engineering limit

### `encounters.json`

- encounter ID와 node difficulty type
- map ref
- slot 순서의 enemy ref 3~5개
- 기본 reward profile ref
- 같은 enemy ref의 중복 허용

### `relics.json` / `consumables.json`

- append-only ID와 표시용 string ID
- 공통 effect profile ref 또는 P4-5에서 승인할 제한된 run effect 원자
- stack/unique 여부와 engineering limit
- 전투 modifier로 연결할 경우 문자열 분기 대신 typed effect ID 사용

개별 graybox record와 exact key set은 P4-2/P4-5 상세 명세에서 승인한다. 이 인덱스는 효과 수치나 경제 가격을 확정하지 않는다.

## 공개 API 후보

```text
RunState.create(catalog, act_id, seed_hi, seed_lo, start_roster, status) -> RunState
RunState.copy() -> RunState
RunState.choose_node(node_id, status) -> bool
RunState.set_deployment(instance_ids, map_id, status) -> bool
RunState.apply_battle_outcome(outcome, status) -> bool
RunState.choose_reward(choice_id, status) -> bool
RunState.resolve_rest(command, status) -> bool
RunState.resolve_shop(command, status) -> bool
RunState.resolve_event(command, status) -> bool

RunMapGenerator.generate(catalog, act_id, seed_hi, seed_lo, status) -> RunNodeGraph
RunRewardGenerator.generate(state, profile, status) -> RunPendingChoice

RunBattleBridge.request_for(state, catalog, status) -> RunBattleRequest
RunBattleBridge.outcome_from(request, battle_state, status) -> RunBattleOutcome

RunSnapshot.capture(state, status) -> RunSnapshot
RunSnapshot.encode(status) -> PackedByteArray
RunSnapshot.decode(bytes, status) -> RunSnapshot
RunSnapshot.restore_state(catalog, status) -> RunState
```

`RunManager`와 `SaveManager` autoload는 위 core API와 파일 I/O를 조정할 뿐 규칙을 소유하지 않는다. 씬은 명령 객체를 전달하고 값 사본을 읽어 렌더한다.

## 전투 연결과 D-12 계약

1. FORMATION에서 map slot 수와 run instance ID를 검증한다.
2. `RunBattleRequest`는 node ID, encounter/map/enemy refs, player piece/level/slot, battle seed, request sequence를 고정한다.
3. 기존 `BattleSetupBuilder`가 request를 `BattleState`로 만든다.
4. BATTLE_END 전에는 outcome 생성이 실패한다.
5. outcome은 request ID, battle result, run instance별 처치/생존/승계 counter 사실을 가진다.
6. `apply_battle_outcome`은 동일 request 중복 적용을 거부한다.
7. 승리면 reward, 패배면 node 난도별 life 차감과 보복형 pending 상태로 전이한다.
8. P4-R03에 따라 모든 roster instance는 다음 전투에서 level 기준 max HP로 새 body를 만들며 전투 status/link/token/HP를 이월하지 않는다.
9. life가 0이면 reward나 다음 node를 열지 않고 RUN_FAILED로 끝난다.

패배 보복 효과의 구체 내용은 U-14이며 P4-3 상세 명세의 별도 승인 항목이다. 구체 효과가 승인되기 전에는 단순 플래그를 조용히 무효 처리하지 않는다.

## 결정론·원자성 계약

- 런 규칙은 정수·안정 ID·명시 정렬만 사용한다.
- 런 RNG는 프로젝트 소유 `SimRng` 파생 규칙을 재사용하고 Godot RNG·시간·컨테이너 순서에 의존하지 않는다.
- 후보 생성은 먼저 안정 key 순으로 전체 후보를 만들고, integer weight 선택 뒤 결과를 저장한다.
- 화면을 다시 열거나 같은 getter를 여러 번 호출해도 RNG와 후보가 바뀌지 않는다.
- 잘못된 node·편성·reward·합성·구매·outcome은 first-error-wins로 실패하고 호출 전 `RunSnapshot` bytes를 유지한다.
- 콘텐츠 fingerprint가 다르면 save/restore와 battle outcome 적용을 거부한다. 자동 migration은 별도 승인 전 제공하지 않는다.
- 정규 배열은 node ID, instance ID, content numeric ID, counter key 순으로 각각 명시 정렬한다.
- 런 상태 hash는 검증/리플레이용이며 게임 판정이나 RNG seed로 재사용하지 않는다.

## 저장 계약 후보

- `RunSnapshot` v1은 magic, schema version, content fingerprint, 모든 RunState 권위 필드, graph, pending choice, trailing-byte 검사를 포함한다.
- core encoder/decoder는 FileAccess를 호출하지 않는다.
- `SaveManager`는 user data의 임시 파일을 완전히 쓴 뒤 교체하고, 실패하면 직전 정상 save를 보존한다.
- 로드 시 손상·지원하지 않는 version·fingerprint 불일치를 서로 다른 진단으로 보고한다.
- 전투 시작 직전 save는 FORMATION의 확정 deployment와 request sequence를 보존한다. P4-R16에 따라 전투 중 저장은 지원하지 않는다.
- Web 저장은 Godot user data 경로를 사용하며 Pages URL path 변경에 따른 영속성 보장은 P4 비범위다.

## 오류·한도 후보

상세 enum 숫자는 P4-1/P4-2에서 현재 마지막 값 뒤에 append-only로 배정한다.

| 분류 | 최소 오류 |
|---|---|
| 콘텐츠 | invalid act/encounter/item schema, missing ref, impossible graph profile, unsupported node/effect kind |
| 런 상태 | invalid phase/node/route/deployment, roster/capacity/level violation, duplicate outcome, pending choice mismatch |
| 생성 | node/edge limit, no eligible encounter/reward, weight overflow, RNG derivation failure |
| 저장 | unsupported schema, truncated/corrupt bytes, trailing bytes, fingerprint mismatch, atomic write failure |

권장 engineering ceiling은 정식 gameplay 상한과 분리한다.

| 항목 | 권장 ceiling |
|---|---:|
| act | 3 |
| act당 floor | 16 |
| floor당 node | 4 |
| run 전체 node | 192 |
| node당 outgoing edge | 4 |
| roster instance | 64 |
| deployment | 16 |
| relic 종류/보유 | 256 / 64 |
| consumable 종류/stack record | 256 / 32 |
| pending choice | 8 |
| instance별 run counter | 16 |

보유 상한과 출전 상한의 정식 최대치는 U-17 승인 전 이 engineering ceiling을 gameplay 값으로 노출하지 않는다.

## UI 회색상자 후보

- 상단: 현재 막/층, 라이프, 골드, seed, content fingerprint 축약
- 노드맵: 현재 도달 가능한 노드만 선택 가능하고 노드 유형은 색+문자/형태로 함께 구분
- 편성: 로스터 instance, piece, level, tag, 활성 시너지와 map slot 순서 표시
- 결과/보상: 전투 결과와 life 변화, 고정된 reward 후보, 선택 완료 여부
- 휴식: 회복 가능 여부와 합성 가능한 정확한 instance 쌍 표시
- 저장: 이어하기/새 런, 손상·fingerprint 불일치 진단
- 기존 전투 화면은 재사용하되 P3 검수용 등급 override는 정식 런 경로에서 비활성화하고 encounter enemy의 `ai_grade_id`를 사용

신규 정식 아트는 요구하지 않는다. 노드와 아이템은 기존 폰트·도형·문자 placeholder로 표현하며, 새 파일 에셋이 필요해지면 `PLACEHOLDER_` 접두사로 생성하고 `manifest.py`를 통해 등록한다.

## 대상 파일 후보

### P4-1~4

```text
src/core/run/run_phase.gd
src/core/run/run_piece_instance.gd
src/core/run/run_counter.gd
src/core/run/run_state.gd
src/core/run/run_snapshot.gd
src/core/run/run_node.gd
src/core/run/run_node_graph.gd
src/core/run/run_map_generator.gd
src/core/run/run_pending_choice.gd
src/core/run/run_reward_generator.gd
src/core/run/run_battle_request.gd
src/core/run/run_battle_outcome.gd
src/core/run/run_battle_bridge.gd
src/core/data/act_definition.gd
src/core/data/encounter_definition.gd
src/core/data/acts.json
src/core/data/encounters.json
src/core/autoload/run_manager.gd
src/core/autoload/save_manager.gd
```

### P4-5~6

```text
src/core/data/relic_definition.gd
src/core/data/consumable_definition.gd
src/core/data/relics.json
src/core/data/consumables.json
scenes/run_graybox.tscn
scenes/run/run_map.tscn
scenes/run/run_roster.tscn
scenes/run/run_reward.tscn
src/ui/run/*.gd
pipeline/tests/p4_*.gd
pipeline/tests/p4_*_reference.py
pipeline/tests/run_p4_*.py
pipeline/tests/fixtures/p4_*/**
```

공통 수정 후보:

```text
project.godot
scenes/main.tscn
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_status.gd
src/core/data/content_catalog.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/catalog.json
src/core/data/id_registry.json
src/ui/battle/p2_content_graybox.gd 또는 재사용 가능한 battle scene/controller
AGENTS.md
HANDOFF.md
docs/design/game_design.md
```

## 수용 기준

1. 승인된 신규 JSON exact schema와 append-only registry가 잘못된 key/type/range/ref를 atomic catalog load 실패로 처리한다.
2. Godot canonical bytes/fingerprint가 독립 Python known-answer와 일치하고 저작 배열 순서 교란 계약을 지킨다.
3. 같은 seed·act에서 node/edge/type/content ID가 1,000회와 snapshot 복원 뒤 일치한다.
4. 생성 graph의 모든 node가 시작에서 도달 가능하고 마지막 단일 boss로 이어지며 edge는 다음 층만 향한다.
5. 다른 seed가 최소 한 fixture에서 다른 유효 graph 또는 node content를 만든다.
6. roster instance ID는 단조 증가·비재사용이고 중복 piece 보유와 정렬 독립성을 유지한다.
7. 편성은 보유 instance만 한 번씩 사용하고 출전/맵 슬롯 상한과 slot 순서를 지킨다.
8. 같은 node·편성에서 `RunBattleRequest`와 초기 `BattleSnapshot` bytes가 반복·복원 뒤 같다.
9. 전투 outcome은 terminal battle에서만 만들어지고 같은 request에 정확히 한 번 적용된다.
10. 일반/엘리트/보스 패배 life 차감과 life 0 종료가 승인된 D-12/D-24 계약을 지킨다.
11. 전투 종료 뒤 HP·상태·token·link와 run level/counter의 이월 경계가 승인안과 일치한다.
12. reward 후보는 동일 입력에서 고정되고 UI 재조회가 RNG나 결과를 바꾸지 않는다.
13. 영입·상한·중복·합성이 원자 적용되고 합성 결과 level·instance ID가 승인 계약을 지킨다.
14. 휴식·상점·이벤트·유물·소모품의 최소 graybox 경로가 각자 한 번 이상 성공·실패 경계를 검증한다.
15. 모든 invalid phase/choice/outcome/content/save 실패에서 호출 전 RunSnapshot bytes가 유지된다.
16. RunSnapshot v1 encode/decode/restore가 exact bytes, 손상·trailing·fingerprint mismatch를 검증한다.
17. 전투 전과 node commit 후 저장에서 앱 재시작 뒤 같은 화면·후보·경로로 이어진다.
18. quick 4런이 강제 debug 조작 없이 terminal에 도달하고 실패 시 seed·route·snapshot repro를 남긴다.
19. milestone route가 개발 Act의 여섯 node 유형과 승리/패배/life 0/act clear를 모두 덮는다.
20. P0~P3 대표 narrow, Web export 계약, Godot import/smoke/manifest가 통과한다.
21. 640×1,024 Web 화면에서 노드 선택·편성·발사·보상·휴식·저장/이어하기가 잘리거나 겹치지 않는다.
22. 사람이 축약 Act 1을 처음부터 보스까지 완주하고 분기·성장·라이프 판단이 이해되는지 승인한다.

## 구현·검증 순서 — 전체 및 하위 명세 승인 뒤

1. P4-1 RunState/instance/snapshot 상세 명세와 독립 binary KAT를 먼저 승인·구현한다.
2. P4-2 catalog v7 act/encounter와 graph 생성 상세 명세를 승인·구현한다.
3. P4-3 편성·battle request/outcome·D-12/life 경계를 연결한다.
4. P4-4 영입·gold·휴식·합성·로스터 명령을 구현한다.
5. P4-5 최소 relic/consumable/shop/event record와 effect 경계를 별도 승인한다.
6. P4-6 5층 개발 Act, run UI, 단일 continue save, 자동 완주 runner를 연결한다.
7. 각 단계 narrow 뒤 P0~P3 대표 회귀를 실행하고, 데모 기간 일상 검증은 `verify --demo`를 사용한다.
8. 단계 종료에서 milestone route·실제 렌더·Web 플레이를 확인한다.
9. 사람 Act 1 완주 승인 뒤 P4 런 루프 완료를 기록한다.

## 승인·후속 결정 기록

2026-08-25 사용자는 시간 제약에 따라 P4-R17의 일상 검증을 8런에서 **4런**으로 줄이고, 그 외 P4-R01~16 및 P4-R17의 milestone·순수 결정론 범위를 승인했다. 이로써 P4 전체 방향과 P4-1~6 분해는 승인되었다.

P4-R15의 개별 graybox 유물·소모품·이벤트 효과와 U-14 보복 효과는 이 승인에 포함되지 않는다. P4-1부터 각 하위 상세 명세를 별도 작성·승인한 뒤 해당 `src/core/` 구현에 들어간다.
