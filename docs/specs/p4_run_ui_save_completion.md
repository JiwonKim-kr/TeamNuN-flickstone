# P4-6 · 축약 Act UI·저장/이어하기·자동 완주 상세 명세 초안

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-25 |
| 상위 승인 | `p4_run_loop.md` P4-R01~17 |
| 선행 구현 | P4-1~3 검증 완료, P4-4~5 구현 완료·누적 검증 대기 |
| 후속 단계 | 사람 Act 완주 승인, P4 종료 기록, 정식 릴리즈 검증 프로필 |
| 검증 정책 | 데모 P4 종료는 quick 4런과 표적 milestone 사례를 사용하고 16-seed 전수는 정식 릴리즈로 이연 |
| 승인 | 2026-08-25 · 사용자 P4-F01~20 및 전체 명세 승인 |
| 구현 권한 | **있음. 승인된 P4-6 범위 구현 가능** |
| 구현 상태 | **구현·데모 자동 검증 완료 · 사람 Act/저장/Web 검수 대기** |

## 목적

P4-1~5의 엔진 비의존 런 코어를 실제 640×1,024 플레이 경로로 연결한다. 사용자는 새 런을 시작하거나 단일 continue 슬롯을 불러오고, 노드 선택→편성→전투→보상/상점/이벤트/휴식→보스를 거쳐 개발 Act를 완주할 수 있어야 한다.

이 단계는 다음 네 경계를 함께 닫는다.

1. `ACT_COMPLETE`를 개발 런의 terminal `RUN_COMPLETE`로 확정한다.
2. 전투 중 저장 없이 노드 경계에서 복구 가능한 단일 continue 저장을 제공한다.
3. 기존 P2/P3 전투 화면을 런 요청/결과 브리지에 연결한다.
4. P4-4~5에서 이연한 검증을 포함해 자동 4런, 대표 회귀, 실제 렌더와 Web 플레이를 확인한다.

P4-6은 정식 메뉴·튜토리얼·접근성·3막 콘텐츠를 확정하는 단계가 아니다. 신규 아트 없이 기존 폰트·도형·문자 placeholder를 사용한다.

## 정본과 현재 구현

- `docs/design/game_design.md` D-05·09·12·14·18·20·24~26, 9~10장, 13~17장, U-16·47
- `docs/specs/p4_run_loop.md` P4-R01~17
- `docs/specs/p4_run_state_snapshot.md`: 원자 `RunState`, `RunSnapshot` v1/v2 codec
- `docs/specs/p4_act_encounter_map_generation.md`: 5층 `development_act_1`과 node graph
- `docs/specs/p4_formation_battle_outcome_life.md`: 편성, `RunBattleRequest/Outcome`, life
- `docs/specs/p4_reward_recruitment_rest_merge.md`: reward, roster, rest, merge, boon
- `docs/specs/p4_relic_consumable_shop_event.md`: catalog/fingerprint v9, inventory, SHOP/EVENT
- `docs/specs/p4_submission_web_preview.md`: 640×1,024 Web export와 Pages 배포 계약

현재 `scenes/main.tscn`은 독립 `p2_content_graybox.tscn`을 표시한다. `RunBattleBridge`는 구현돼 있지만 이를 호출하는 `RunManager`, `SaveManager`, 런 UI는 없다. `RunPhase.RUN_COMPLETE` 값은 선점돼 있으나 `RunState` 구조 검증과 `RunSnapshot.capture/restore`가 아직 활성화하지 않았다.

## 범위

- 개발 Act 완료 command와 `RUN_COMPLETE` snapshot 활성화
- 파일 I/O 오류를 결정론 simulation 오류와 분리하는 저장 상태 값 객체
- `user://` 단일 continue 파일의 검증 후 교체·backup 복구
- 저장 성공 뒤에만 활성 런을 교체하는 `RunManager` transaction
- 새 런, 이어하기, 노드 진입, 편성, 전투 outcome, 선택지, 소모품, terminal의 UI 연결
- 기존 P2/P3 전투 controller의 독립 검수 모드와 런 모드 분리
- 640×1,024 세로형 런 회색상자 씬과 `main.tscn` 진입점 교체
- P4-4~6 narrow, snapshot/save KAT, 자동 quick 4런
- P0~P3 대표 회귀, `verify --demo`, import/smoke/manifest, Web export
- 사람용 두 대표 경로와 저장/재시작 검수 절차

## 비범위

- 정식 3막, 정식 시작 덱, seed 자동 생성 UX, 난이도 선택
- 여러 저장 슬롯, 클라우드 동기화, save migration, 전투 중 save
- save 암호화·압축·사용자 편집 방지·플랫폼 간 동기화
- 정식 메인 메뉴, 옵션, 튜토리얼, 키 재설정, 패드/모바일 전용 조작
- 정식 노드맵 아트, 아이콘, VFX, SE, BGM
- 전투 리플레이나 발사 입력 로그 저장
- P5 메타 진행, P6 전체 밸런스와 정식 release exhaustive 검증

## 선행 계약 충돌과 재승인 지점

### P4-R17 단계 종료 검증량

P4-R17은 일상 검증을 2 seeds×2 routes의 4런으로 제한하면서도 **단계 종료는 16 seeds×모든 고정 route profile**로 승인했다. 이후 사용자는 현재 작업이 데모이므로 정식 릴리즈 전에는 오래 걸리는 검증을 간소화하거나 생략하도록 지시했다.

P4-F19는 최신 일정 지시를 P4-6에 반영해 다음처럼 이관하는 권장안이다.

- 데모 P4 종료: quick 4런 + 기능별 표적 milestone 사례 + 대표 회귀 + 실제 Web 플레이
- 정식 릴리즈: 16 seeds×모든 고정 route profile + `verify --full` + 플랫폼 전수

영향은 검증 실행량뿐이다. 게임 규칙, 저장 형식, RNG, catalog fingerprint, 자동 4런의 입력 정책은 바뀌지 않는다. 다만 4개 quick route 밖에서만 드러나는 밸런스·교착 회귀를 P4 종료 시점에 잡는 확률은 낮아진다. 이 변경은 승인된 P4-R17의 문구를 수정하므로 P4-F19를 별도 재승인해야 한다.

### 파일 교체의 플랫폼 원자성

Godot의 `user://` backend가 모든 native/Web 플랫폼에서 OS 수준 atomic rename을 보장한다고 가정하지 않는다. 이 명세의 “원자 저장”은 **부분 바이트를 유효 save로 채택하지 않고, 검증된 새 파일 또는 검증된 이전 backup 중 하나로 복구하는 논리적 원자성**을 뜻한다.

## 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P4-F01 | P4-6은 catalog schema/fingerprint v9와 `RunSnapshot` v2를 유지한다 | UI·저장은 새 콘텐츠가 아니며 불필요한 골든 이관 방지 | ✅ 승인 |
| P4-F02 | `RunState.complete_development_run(catalog, status)`는 `ACT_COMPLETE`이면서 현재 act가 `is_development=true`일 때만 `RUN_COMPLETE`로 원자 전환한다 | 3막 전환 규칙을 발명하지 않고 개발 Act terminal만 닫음 | ✅ 승인 |
| P4-F03 | `RUN_COMPLETE`는 boss node/floor와 roster/inventory/gold/life를 보존하고 pending/deployment/boon은 비운 terminal snapshot이다 | 결과 화면·재현에 필요한 런 사실 보존 | ✅ 승인 |
| P4-F04 | 저장 오류는 `RunSaveStatus`로 분리하고 simulation/content 오류의 numeric code·operation·detail을 중첩 보존한다 | 파일 시스템 실패와 잘못된 snapshot을 UI에서 구분 | ✅ 승인 |
| P4-F05 | 단일 슬롯은 `user://continue_run.bin`, 임시는 `.tmp`, 이전본은 `.bak`을 사용한다 | P4-R16의 한 슬롯과 crash recovery를 작은 표면으로 구현 | ✅ 승인 |
| P4-F06 | 저장은 temp 쓰기→close→exact 재읽기/restore 검증→old backup→temp commit→backup 정리 순서다 | 손상·fingerprint mismatch·중단된 쓰기를 유효 save로 채택하지 않음 | ✅ 승인 |
| P4-F07 | 시작 시 target이 없고 유효 backup이 있으면 복구하며 stale temp는 채택하지 않는다. 손상 target은 자동 삭제하지 않는다 | 사용자 데이터 손실 없이 진단과 수동 새 런 선택 제공 | ✅ 승인 |
| P4-F08 | 저장 payload는 별도 envelope 없이 canonical `RunSnapshot.encode()` bytes 그대로다 | 중복 version/fingerprint 형식 제거 | ✅ 승인 |
| P4-F09 | 모든 저장 동반 명령은 `active copy → core command → candidate save → active 교체`로 실행한다 | save 실패 때 메모리와 디스크의 마지막 확정 경계 유지 | ✅ 승인 |
| P4-F10 | node 진입 직전 현재 `MAP_CHOICE`를 저장하고, 편성 확정 직후·전투 직전 FORMATION을 저장하며, 전투 중에는 저장하지 않는다 | P4-R16을 phase별로 구체화하고 crash 시 전투 전 재시작 허용 | ✅ 승인 |
| P4-F11 | 전투 terminal outcome 적용과 reward 준비를 하나의 candidate에서 수행한 뒤 REWARD 또는 terminal을 저장한다. 실패 시 BATTLE 원본과 outcome을 메모리에 남겨 재시도한다 | 결과 중복 적용과 저장 실패 후 전투 유실 방지 | ✅ 승인 |
| P4-F12 | reward/shop/event/rest 완료와 MAP_CHOICE 소모품 사용 뒤 저장한다. terminal save는 새 런이 성공적으로 대체할 때까지 유지한다 | node 결과 commit과 최근 런 결과를 모두 복구 가능하게 유지 | ✅ 승인 |
| P4-F13 | `RunManager` autoload가 활성 런·catalog 사본·in-flight request/outcome을 소유하고 UI는 core를 직접 mutate하지 않는다 | 씬 교체와 저장 transaction의 단일 조정자 | ✅ 승인 |
| P4-F14 | 시작 로스터는 initial key 1~3=`baduk_stone`, 4~6=`bottle_cap`, 전부 L1로 고정한다 | 기존 P4 fixture와 같은 6기 개발 덱 사용 | ✅ 승인 |
| P4-F15 | seed 입력은 정확히 16자리 hex이며 기본값은 `0000000000000001`이다. 앞 8자/뒤 8자를 hi/lo uint32로 해석한다 | OS 시간 난수 없이 재현 가능한 개발 UI 제공 | ✅ 승인 |
| P4-F16 | 기존 battle scene은 standalone 검수 모드와 run 모드를 나눈다. run 모드는 P3 grade override·restart를 끄고 encounter `ai_grade_id`를 사용하며 terminal outcome을 정확히 한 번 emit한다 | 기존 전투 검수 보존과 정식 런 규칙 혼입 방지 | ✅ 승인 |
| P4-F17 | `main.tscn`은 640×1,024 `run_graybox.tscn`으로 전환하고, 전투 중에는 런 패널을 숨겨 전투 viewport 전체를 사용한다 | Pages의 세로 화면과 기존 전투 조작 영역 겹침 방지 | ✅ 승인 |
| P4-F18 | quick 자동 완주는 production core/AI와 결정론적 player shot supplier를 사용하며 결과·보상을 debug 주입하지 않는다 | 실제 연결 경로에서 terminal 도달 검증 | ✅ 승인 |
| P4-F19 | **P4-R17 변경:** 데모 P4 종료는 2 seeds×2 routes=4런과 표적 milestone로 제한하고 16-seed 전수·`verify --full`은 정식 릴리즈로 이연한다 | MVP 시간 제약 반영. route 밖 교착 탐지 범위 감소를 수용 | ✅ 재승인 |
| P4-F20 | 자동 검증 통과만으로 P4를 종료하지 않고, 두 대표 경로·저장 재시작·Web 렌더에 대한 사람 승인을 마지막 gate로 둔다 | 조작 이해도와 레이아웃은 자동 검사만으로 판단 불가 | ✅ 승인 |

## RUN_COMPLETE 계약

### 신규 status 번호

append-only `SimStatus` 번호를 다음처럼 추가한다.

```text
Code.INVALID_RUN_COMPLETION = 80
Operation.RUN_COMPLETE = 173
```

`complete_development_run`의 선행 조건은 다음과 같다.

1. catalog와 state가 initialized이고 fingerprint가 일치한다.
2. phase는 정확히 `ACT_COMPLETE`다.
3. 현재 act definition의 `is_development`가 true다.
4. 현재 node는 act 마지막 floor의 유일한 BOSS이고 completed node ID에 포함된다.
5. life는 1 이상이고 pending/deployment가 비었으며 next-battle boon이 0이다.

성공 시 phase만 `RUN_COMPLETE`로 바꾸고 나머지 정규 상태를 보존한다. 실패 시 호출 전 `RunSnapshot` 가능한 바이트가 유지된다. 정식 non-development act의 다음 act 이동이나 전체 런 완료는 후속 명세 전까지 실패한다.

`RunState._validate_structure`, `copy`, `RunSnapshot.capture/decode/restore`는 `RUN_COMPLETE`를 terminal phase로 허용한다. codec layout과 version은 바뀌지 않는다.

## 저장 상태와 단일 슬롯

### `RunSaveStatus`

`RunSaveStatus`는 `RefCounted` 값 객체이며 first-error-wins다.

```text
Code
  OK = 0
  NOT_FOUND = 1
  IO_ERROR = 2
  SNAPSHOT_REJECTED = 3
  REPLACE_FAILED = 4

Operation
  NONE = 0
  PROBE = 1
  READ = 2
  WRITE_TEMP = 3
  VERIFY_TEMP = 4
  ROTATE_OLD = 5
  COMMIT_TEMP = 6
  RECOVER_BACKUP = 7
  CLEANUP = 8
```

필드는 `code`, `operation`, `detail_a`, `detail_b`, `sim_code`, `sim_operation`, `sim_detail_a`, `sim_detail_b`다. 파일 경로나 OS 문자열을 결정론 snapshot에 넣지 않는다. UI는 numeric 값과 짧은 한글 설명을 함께 표시한다.

`NOT_FOUND`는 이어할 런이 없다는 정상 진단이며 손상과 구분한다. `SNAPSHOT_REJECTED`는 bytes 읽기는 성공했지만 exact EOF, codec version, content fingerprint 또는 복원 구조 검증이 실패한 경우다.

### `SaveManager` 공개 경계

```gdscript
probe_continue(catalog: ContentCatalog, status: RunSaveStatus) -> int
save_continue(state: RunState, catalog: ContentCatalog, status: RunSaveStatus) -> bool
load_continue(catalog: ContentCatalog, status: RunSaveStatus) -> RunState
```

`probe_continue` 결과는 `MISSING`, `VALID`, `INVALID`의 정수 enum이다. probe와 load는 target을 변경하지 않는다. startup cleanup/recovery만 stale temp와 backup을 다룬다.

### 저장 절차

1. `RunSnapshot.capture(candidate)` 후 canonical bytes를 만든다.
2. 기존 stale temp를 제거할 수 없으면 실패한다.
3. temp를 truncate 모드로 열어 전체 bytes를 쓰고 flush·close한다.
4. temp를 다시 exact 읽어 현재 catalog로 decode/restore하고 bytes 재인코딩이 원본과 같은지 확인한다.
5. target이 있으면 기존 backup을 제거한 뒤 target을 backup으로 옮긴다.
6. temp를 target으로 옮긴다.
7. 6이 실패하면 target 부재를 확인하고 backup을 target으로 되돌린다.
8. 성공 target을 한 번 더 probe한 뒤 backup을 정리한다.

각 단계 실패는 마지막으로 검증된 target 또는 backup을 남긴다. target과 backup이 모두 유효하더라도 target을 우선한다. target이 손상됐다는 이유만으로 backup을 자동 덮어쓰지 않는다. 사용자가 새 런을 확정하면 동일 절차로 새 snapshot이 단일 슬롯을 대체한다.

## 저장 경계와 transaction

| 동작 | 저장 대상 | 실패 시 |
|---|---|---|
| 새 런 생성 | 첫 `MAP_CHOICE` | 기존 continue와 활성 런 유지 |
| 이어하기 | 쓰기 없음 | 활성 런 유지, 진단 표시 |
| node 진입 | 진입 전 `MAP_CHOICE` | node에 들어가지 않음 |
| 편성 확정/전투 시작 | deployment가 든 `FORMATION` | BATTLE로 전환하지 않음 |
| 전투 outcome | outcome 적용+reward 준비 후 `REWARD`, `ACT_COMPLETE`, `RUN_FAILED` 후보 | 활성 BATTLE과 outcome 유지, retry 제공 |
| reward/shop/event/rest 완료 | 다음 `MAP_CHOICE` 또는 `ACT_COMPLETE` 후보 | 기존 phase 유지 |
| 소모품 사용 | 변경된 `MAP_CHOICE` | 소비하지 않음 |
| 개발 Act 완료 | `RUN_COMPLETE` | `ACT_COMPLETE` 유지 |

node 진입 중 생성되는 SHOP/EVENT/REST pending은 autosave하지 않는다. 앱이 그 화면에서 종료되면 진입 직전 MAP_CHOICE에서 다시 시작하며, 비소비 파생 규칙 때문에 같은 pending이 재생성된다. REWARD 후보는 전투를 다시 요구하지 않도록 outcome과 함께 준비해 저장한다.

## `RunManager` 조정자

### 소유 상태

- 현재 catalog의 불변 사본
- 마지막으로 저장까지 성공한 활성 `RunState`
- BATTLE 동안의 불변 `RunBattleRequest`
- terminal 전투 뒤 저장 재시도용 불변 `RunBattleOutcome`
- 마지막 `RunSaveStatus` 사본

`RunManager`는 `DataDB` 뒤에 autoload된다. `_ready()`에서 임의로 새 런을 만들지 않고 save probe만 수행한다.

### 공개 command

```gdscript
start_new_development_run(seed_hi: int, seed_lo: int,
        sim_status: SimStatus, save_status: RunSaveStatus) -> bool
continue_run(sim_status: SimStatus, save_status: RunSaveStatus) -> bool
has_active_run() -> bool
state_copy(status: SimStatus) -> RunState
enter_node(node_id: int, sim_status: SimStatus, save_status: RunSaveStatus) -> bool
set_deployment(instance_ids: Array[int], sim_status: SimStatus,
        save_status: RunSaveStatus) -> bool
begin_battle(sim_status: SimStatus, save_status: RunSaveStatus) -> RunBattleRequest
accept_battle_outcome(outcome: RunBattleOutcome, sim_status: SimStatus,
        save_status: RunSaveStatus) -> bool
retry_battle_outcome_commit(sim_status: SimStatus,
        save_status: RunSaveStatus) -> bool
choose_pending(choice_id: int, first_instance_id: int, second_instance_id: int,
        sim_status: SimStatus, save_status: RunSaveStatus) -> bool
use_consumable(consumable_numeric_id: int, sim_status: SimStatus,
        save_status: RunSaveStatus) -> bool
complete_run(sim_status: SimStatus, save_status: RunSaveStatus) -> bool
```

`enter_node`와 `choose_pending`은 node/phase를 보고 승인된 `RunState`의 정확한 typed command로 dispatch한다. UI가 `RunState` 내부 배열을 수정하거나 phase를 직접 설정하는 API는 제공하지 않는다.

### signal

```gdscript
signal state_changed(state: RunState)
signal battle_requested(request: RunBattleRequest)
signal persistence_failed(status: RunSaveStatus)
```

signal payload는 사본이다. 성공 command는 active commit 뒤 `state_changed`를 한 번 emit한다. 전투 요청은 FORMATION save와 BATTLE transition이 성공한 뒤 한 번 emit한다.

## 새 런과 seed

개발 UI는 act numeric ID 1과 다음 roster를 사용한다.

| initial key | piece | level | 예상 instance ID |
|---:|---|---:|---:|
| 1~3 | `baduk_stone` numeric ID 1 | 1 | 1~3 |
| 4~6 | `bottle_cap` numeric ID 2 | 1 | 4~6 |

UI seed는 공백 없는 ASCII hex 16자리만 받는다. 대소문자는 허용하고 표시 시 소문자로 정규화한다. `0000000000000001`은 `(seed_hi=0, seed_lo=1)`이다. 잘못된 입력은 RunState를 만들지 않고 field 옆에 오류를 표시한다.

이 값은 개발 재현 입력이며 U-16 정식 시작 덱과 U-47 정식 메뉴/seed UX를 확정하지 않는다.

## 전투 화면 run mode

기존 `p2_content_graybox` controller에 다음 외부 경계를 추가한다.

```gdscript
signal run_battle_finished(outcome: RunBattleOutcome)

start_run_battle(request: RunBattleRequest,
        catalog: ContentCatalog, status: SimStatus) -> bool
leave_run_mode() -> void
```

run mode 규칙:

1. `RunBattleBridge.build_state`만으로 초기 `BattleState`를 만든다.
2. P3 등급 순환/override와 `R` 재시작을 비활성화한다.
3. 적의 `ai_grade_id`는 request가 가리키는 catalog enemy definition을 따른다.
4. player의 drag/power 입력과 trajectory UI는 현재 승인된 조작감을 유지한다.
5. terminal `BATTLE_END`에서 `RunBattleBridge.outcome_from`을 정확히 한 번 호출하고 signal을 한 번 emit한다.
6. outcome 저장 실패 overlay 중에는 추가 입력과 scene 종료를 막고 manager retry만 허용한다.
7. standalone scene 직접 실행 시 기존 P3 검수용 등급 전환과 restart를 유지한다.

## 640×1,024 런 회색상자 UI

### 공통 배치

- root 기준 640×1,024, `canvas_items` stretch
- 바깥 여백 16px
- 상단 정보 영역 `x=16..624`, `y=16..112`
- 내용 영역 `x=16..624`, `y=128..928`
- 하단 action/status 영역 `x=16..624`, `y=944..1008`
- 전투 phase에서는 런 상단·하단을 숨기고 battle scene이 전체 viewport를 사용
- 색만으로 node/활성 상태를 구분하지 않고 유형 문자와 button label을 함께 사용

### phase별 화면

| phase/상태 | 필수 표시와 입력 |
|---|---|
| 시작 | seed, `새 런`, valid save일 때 `이어하기`, invalid save 진단 |
| MAP_CHOICE | act/floor/life/gold, seed/fingerprint 축약, 도달 가능한 node button만 활성, roster/inventory 요약, 사용 가능한 flask |
| FORMATION | roster instance ID·piece·level·counter, map slot 순서, 정확한 출전 수, 편성 확정 |
| BATTLE | 기존 battle UI 전체 화면, 런용 grade/restart control 숨김 |
| REWARD | 전투 결과·life 변화, 고정 후보와 skip/복수 instance 입력이 필요한 경우의 선택 |
| SHOP | offer 이름·가격·보유 gold·비활성 이유, leave |
| EVENT | option 번호와 효과 요약, leave 포함 |
| REST | life 회복, 유효한 같은 piece/level instance pair, 불가능 선택 비활성 |
| ACT_COMPLETE | boss 결과와 `런 완료` command |
| RUN_COMPLETE/RUN_FAILED | terminal 요약, seed, 완료 node, roster/inventory, `새 런` |
| 저장 실패 | code/operation과 retry 또는 시작 화면 복귀. 손상 save 자동 삭제 없음 |

`scenes/main.tscn`은 런 회색상자를 진입점으로 바꾸되 `scenes/p2_content_graybox.tscn` 직접 실행은 유지한다. 새 bitmap/audio asset은 만들지 않으므로 manifest 신규 entry는 없다.

## 자동 완주 runner

### quick 4런

고정 seed 2개 각각에 아래 route 2개를 적용한다.

1. `NORMAL → SHOP → NORMAL → REST → BOSS`
2. `NORMAL → EVENT → ELITE → REST → BOSS`

route는 node ID 하드코딩 대신 floor와 node type으로 선택하고, 동일 type이 여러 개면 node ID가 작은 것을 고른다.

### 자동 입력 정책

- 편성: 살아 있는 roster instance ID 오름차순에서 필요한 수만 선택
- player 발사: 기존 결정론적 shot supplier, enemy 발사: production P3 AI
- reward: enabled choice 중 choice ID 최소, 없으면 승인된 skip
- shop: 살 수 있는 relic→consumable→leave 순, 같은 kind면 offer ID 최소
- event: consumable 획득→gold→leave 순, option ID로 tie-break
- consumable: MAP_CHOICE에서 `life < max_life`일 때 numeric ID 최소를 한 번 사용
- rest: life 회복 가능 시 recover, 아니면 `(low instance ID, high instance ID)` 사전식 최소 merge pair
- ACT_COMPLETE: `complete_development_run`

자동화는 UI click이 아니라 `RunManager`와 production battle driver 경계를 호출한다. 발사 입력만 자동 공급하며 `BattleResult`, life, reward, gold, inventory를 직접 쓰지 않는다. 각 런은 `RUN_COMPLETE` 또는 `RUN_FAILED` terminal에 도달해야 하며 교착/step ceiling은 실패다.

실패 artifact는 seed, route, act/floor/node, phase, last simulation code/operation, canonical RunSnapshot bytes 또는 capture 불가 시 마지막 pre-battle snapshot, SHA-256을 포함한다.

## 누적 검증

### P4-4~6 narrow

1. P4-4 reward/영입/상한/중복/합성/보복 boon의 성공·실패 rollback
2. P4-5 catalog v9 Python/Godot canonical fingerprint, SHOP/EVENT/inventory effect
3. P4-1~3 fixture의 catalog v9 fingerprint·snapshot 기대값 이관
4. `RUN_COMPLETE` capture/copy/encode/decode/restore exact bytes와 legacy v1 복원 유지
5. temp partial write, corrupt/trailing, fingerprint mismatch, rotate/commit 실패와 backup recovery
6. 새 런 저장 실패, node 진입 실패, battle outcome 저장 retry의 메모리/파일 transaction
7. 동일 seed/route의 quick 4런 terminal snapshot/hash 반복 일치
8. graph/RunState/RunSnapshot 순수 경로 1,000회 결정론

### 데모 대표 회귀

- P0 deterministic snapshot/hash quick
- P1 battle snapshot/terminal 대표 fixture
- P2 catalog/runtime graybox 대표 fixture
- P3 COMMON/ELITE/BOSS shot selection narrow
- Godot import, smoke, manifest
- Web export artifact/COOP·COEP service worker 계약
- `verify --demo`에 P4 completion runner 추가

P4-F19 승인 시 P4-6에서는 `verify --full`, 16 seeds×모든 route, 전체 플랫폼 전수를 실행하지 않는다. 이 항목은 삭제하지 않고 정식 릴리즈 checklist와 `HANDOFF.md`에 검증 부채로 남긴다.

## 사람 검수 절차

### 경로 A

1. seed 기본값으로 새 런 시작
2. 일반 전투→상점→일반 전투→휴식→보스
3. 상점 구매, 보상 영입, 휴식 회복 또는 합성 확인
4. boss 뒤 RUN_COMPLETE와 terminal 요약 확인

### 경로 B

1. 두 번째 고정 seed로 새 런 시작
2. 일반 전투→이벤트→엘리트→휴식→보스
3. 이벤트 효과, 엘리트 life 변화, 소모품 사용 확인

### 저장/렌더

1. FORMATION 저장 뒤 앱 종료/재실행, 같은 편성 화면·deployment 복원
2. REWARD 저장 뒤 앱 종료/재실행, 같은 후보와 선택 가능 상태 복원
3. 전투 도중 강제 종료 후 마지막 FORMATION에서 재개
4. 640×1,024 native와 Pages에서 node button, 편성, 전투 drag, 선택지, footer가 잘리거나 겹치지 않음
5. terminal save에서 이어하기가 최근 결과를 보여주고 새 런이 성공한 뒤에만 교체됨

## 대상 파일

신규 후보:

```text
src/core/run/run_save_status.gd
src/core/autoload/save_manager.gd
src/core/autoload/run_manager.gd
scenes/run_graybox.tscn
src/ui/run/run_graybox.gd
pipeline/tests/p4_run_ui_save_completion_test.gd
pipeline/tests/p4_run_ui_save_completion_reference.py
pipeline/tests/run_p4_run_ui_save_completion.py
pipeline/tests/fixtures/p4_run_ui_save_completion/**
```

수정 후보:

```text
src/core/sim/sim_status.gd
src/core/run/run_state.gd
src/core/run/run_snapshot.gd
src/ui/battle/p2_content_graybox.gd
scenes/p2_content_graybox.tscn
scenes/main.tscn
project.godot
pipeline/scripts/verify.py
pipeline/tests/p4_* fixture/reference
docs/specs/p4_run_loop.md
AGENTS.md
HANDOFF.md
```

UI가 커지면 `src/ui/run/` 아래 panel script 또는 `scenes/run/` 아래 subscene으로 분리할 수 있다. 이는 승인된 화면/command 경계를 바꾸지 않는 구현 상세다.

## 수용 기준

1. non-development act, 잘못된 phase/node/life에서 run 완료가 실패하고 원본 snapshot bytes가 유지된다.
2. 유효 개발 boss 결과만 `ACT_COMPLETE → RUN_COMPLETE`가 되고 v2 exact restore된다.
3. 손상·trailing·다른 fingerprint save가 `SNAPSHOT_REJECTED`로 구분되고 자동 삭제되지 않는다.
4. temp 검증 실패와 replace 실패에서 이전 valid continue가 복구된다.
5. 새 런·node 결과 command는 save 성공 뒤에만 active state를 교체한다.
6. 전투 중 save 파일을 만들지 않고 강제 재시작은 같은 FORMATION snapshot으로 돌아온다.
7. battle outcome은 같은 request에 정확히 한 번 적용되고 save 실패 뒤 retry해도 중복 counter/life/reward가 없다.
8. run mode가 encounter `ai_grade_id`를 사용하고 P3 override/restart를 노출하지 않는다.
9. 여섯 node type 모두 UI에서 진입·완료할 수 있고 불가능한 선택은 이유와 함께 비활성화된다.
10. quick 4런이 debug 결과 주입 없이 terminal에 도달하고 동일 입력 반복의 terminal bytes/hash가 같다.
11. P4-4~5 이연 narrow와 catalog v9 독립 KAT가 통과한다.
12. 순수 graph/RunState/RunSnapshot 1,000회가 동일하다.
13. P0~P3 대표 회귀와 `verify --demo`, import/smoke/manifest, Web export가 통과한다.
14. native와 Pages 640×1,024에서 UI가 잘리거나 전투 입력을 가리지 않는다.
15. 사람이 두 대표 경로, 저장 재시작, boss 완료를 확인하고 P4 종료를 승인한다.

## 승인 후 구현 순서

1. `RUN_COMPLETE`와 save status/manager narrow를 먼저 구현한다.
2. `RunManager` transaction과 시작 roster/seed를 연결한다.
3. battle controller run mode와 outcome retry 경계를 연결한다.
4. 런 회색상자 UI와 main scene을 연결한다.
5. P4-4~6 fixture/reference를 catalog v9로 누적 이관한다.
6. narrow→quick 4런→1,000회 순수 결정론→대표 회귀→`verify --demo`를 실행한다.
7. native 640×1,024와 Web export 렌더를 확인한다.
8. 사람 검수 대기 상태로 기록하고, 승인 뒤에만 P4 완료를 기록한다.

## 승인 기록

2026-08-25 사용자는 P4-F01~20과 전체 상세 명세를 승인했다. P4-F19에 따라 기존 P4-R17의 데모 단계 종료 검증량은 quick 4런과 표적 milestone로 이관하고, 16 seeds×모든 route profile 및 `verify --full`은 정식 릴리즈 검증 부채로 남긴다.

## 구현 기록

2026-08-25 `RUN_COMPLETE`, `RunSaveStatus`, 단일 슬롯 `SaveManager`, 저장 성공 뒤 active state를 교체하는 `RunManager`, 기존 전투의 run mode, 640×1,024 런 graybox와 main 진입점을 구현했다. catalog v9 이관 뒤 현재 fingerprint는 `f556a6e8c162e62ad2df3a90ab006f52aeefecbadc204f1f204307aaf124965f`다.

표적 저장/복원·손상 진단·교체·manager route 검사와 production core/P3 AI 기반 2 seeds×2 routes quick 4런이 통과했다. 누적 검증 중 P3 안전 재시도의 각도 양자화 이탈과 P4 revenge boon 적용 phase 불일치를 발견해 각각 승인 계약 안에서 수정했다. Godot 4.6.3 import·main smoke·manifest와 640×1,024 native screenshot도 통과했다. 데모 대표 러너 10종은 통합 `--skip-godot` 집계와 영향 Godot narrow를 조합해 모두 통과했으며, 중복 장시간 `--full`과 16-seed 전수는 실행하지 않았다.

자동 검증만으로 P4를 닫지 않는다. 두 대표 경로, 저장/재시작, Pages Web 렌더는 P4-F20에 따라 사람 검수 대기다.
