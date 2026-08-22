# P1-5 · 회색상자 전투 / 배치 시뮬 / P1 결정론 회귀

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-22 |
| approved | 2026-08-22 · 사용자 진행 승인; 2026-08-23 · 플레이 씬 세로 배치 및 PT-01~04 승인 |
| phase | P1 · 전투 루프 |
| 선행 명세 | P0-1~4, P1-1~4 승인·구현·검증 완료 |
| 후속 단계 | P2 콘텐츠 기반 · P3 AI |
| 구현 권한 | **있음 — G-01~06 승인 범위** |

## 목적

개별 능력과 P3 AI 없이 공통 스탯만으로 플레이어 팀과 적 팀의 전투를 승패까지 진행한다. 같은 시드·초기 상태·샷 공급 입력은 반복 실행, body 삽입 순서 교란, `BattleSnapshot` 복원 뒤에도 같은 전투 결과·CSV 행·최종 상태 해시를 만들어야 한다. 사람이 직접 조작할 수 있는 manifest 등록 회색상자 씬과, 다수 전투를 headless로 실행하는 배치 러너를 함께 제공해 P1 완료와 이후 밸런싱의 기준선을 만든다.

## 설계 정본 참조

- `docs/design/game_design.md` D-02, D-03, D-10, D-18, D-29~49
- 3.1 전투 내부 루프
- 4.6 발사, 4.7 CTB, 4.8 상태 머신, 4.9 승패
- 14장 결정론·레이어·스냅샷 계약
- 16장 결정론·교착·전투 길이·배치 시뮬
- 17장 P1 완료 판정과 배치 시뮬 타협 불가 항목
- `docs/specs/p1_index.md` P1-5 경계와 P1 전체 완료 판정
- `docs/specs/p1_ctb_battle_state.md` C-02, C-06~08
- `docs/specs/p1_launch_aim_prediction.md` L-01~10
- `docs/specs/p1_damage_resolution.md` R-01~10
- `docs/specs/p1_trigger_bus_battle_result.md` T-01~10

## 범위

- 공통 스탯만 사용하는 P1 회귀용 3대3 encounter fixture
- 사람이 드래그 조준해 한 전투를 끝까지 확인하는 회색상자 씬
- P3 AI와 분리된 단순 결정론적 batch shot supplier
- fixture 검증, 전투 실행, snapshot hash, CSV 출력
- 동일 입력 반복·삽입 순서 교란·snapshot 복원 결정론 회귀
- 실패 시 최초 불일치나 교착을 재현하는 JSON artifact
- 게임별 narrow runner와 `verify --full` 자동 편입
- manifest 등록 `PLACEHOLDER_` 전장·기물·조준 표식

## 범위 밖

- P3 최적 샷 탐색, 등급별 오차, 사고 시간 예산
- 능력·상태이상·시너지·유물·소모품·콘텐츠 JSON 실행기
- 정식 맵 크기, 정식 슬롯 수, 41종 기물 스탯
- 콘텐츠별 승률 목표나 P6 밸런스 판정
- DRAW의 로그라이트 상위 처리(D-12/U-11)
- 실제 아트, 이펙트, 효과음, BGM
- art lock/gen/reskin과 SE gen/attach

## 용어

| 용어 | 의미 |
|---|---|
| graybox fixture | P1 계약 검증만을 위한 고정 encounter. 정식 콘텐츠·밸런스값이 아님 |
| shot supplier | 현재 안정 상태를 받아 한 개의 `LaunchCommand` 또는 forced-no-launch를 반환하는 순수 정책 |
| battle case | seed, fixture ID, 삽입 순서 variant, snapshot restore 지점을 포함한 한 번의 전투 실행 |
| terminal hash | terminal `BattleSnapshot.encode()` 전체 바이트의 SHA-256 소문자 64자리 hex |
| repro artifact | 실패 case를 단독 재실행할 수 있는 정수 전용 JSON |
| infrastructure failure | `SimStatus` 오류, RESOLVE deadlock, turn limit, fixture 오류, CSV 쓰기 실패. 정상 `BattleResult`와 구분 |

## 결정 목록 — 승인 완료

| ID | 결정 | 권장안 | 상태 |
|---|---|---|---|
| G-01 | batch shot supplier와 입력 fixture | 가장 가까운 적의 중심을 향해 power step 192로 발사. 거리 동률은 body ID. 적이 없거나 유효 명령 생성 실패만 forced-no-launch. fixture는 정수 전용 schema v1 | ✅ 승인 |
| G-02 | 회색상자 encounter 값 | P1 회귀 fixture로만 3대3, 직사각형 WALL 전장 1,024×640, 반지름 32·무게 64, HP 100·공격 20, 속도 80/100/125를 양 팀 대칭 배치 | ✅ 승인 |
| G-03 | 실행량·종료 경계 | narrow 16전투, 기본 batch 256전투, exhaustive 1,000전투. 전투당 128턴 한도. core `RESOLVE_DEADLOCK` 또는 turn limit는 정상 결과로 접지 않고 실패 | ✅ 승인 |
| G-04 | CSV schema와 집계 | 아래 고정 열 순서, RFC 4180, UTF-8 LF, 정수/고정 enum만 사용. stdout 요약에 결과 분포·턴 중앙값·강제 정산·실패 수 | ✅ 승인 |
| G-05 | P1 terminal golden | 승인된 fixture의 case별 result·turn·tick·terminal hash를 JSON으로 체크인. PT-01~03 물리 기준 변경은 fixture v2와 새 golden으로 구분. 명시적 갱신 플래그와 승인 참조 필수, CI 갱신 금지 | ✅ 재승인 |
| G-06 | 씬·플레이스홀더 범위 | 전장 1, 아군/적 기물 각 1종, aim marker 1종의 PNG placeholder만 생성·manifest 등록. 플레이 씬은 640×1,024 세로 전장에 enemy 위·player 아래 3명씩 배치. 효과음 없음 | ✅ 재승인 |

G-02의 전장 크기·3대3·HP·공격은 정식 D-03/U-34/U-36 값을 확정하지 않는다. PT-01~03 기본 물리 변경 뒤 fixture ID를 `p1_graybox_v2`로 올려 제품 데이터와 분리한다. 향후 정식 콘텐츠가 정해져도 이 P1 회귀 fixture는 호환성 기준으로 유지한다. G-06의 수동 플레이 전용 `p1_graybox_portrait_playtest_v1`은 회귀 fixture와 골든에 사용하지 않지만 PT-01~03 기본 물리는 공유한다. CT 속도는 변경하지 않는다.

v2의 기준 전투가 20턴에 종료되므로 snapshot 복원 지점은 종료 전 `1/2/5/8/10/12/15턴`을 사용한다. 종료 이후 복원을 요청해 검사를 건너뛰는 fixture는 허용하지 않는다.

## G-01 권장안 · shot supplier와 fixture

### 순수 shot supplier

배치 실행은 현재 actor마다 다음 순서로 명령을 만든다.

1. 현재 actor와 적대인 살아 있는 participant를 body ID 오름차순으로 수집한다.
2. actor 중심과 후보 중심의 거리 제곱이 가장 작은 적을 고른다. 동률은 낮은 body ID다.
3. `drag = actor.position - target.position` 방향을 사용해 당구식 조작과 동일한 발사 방향을 만든다.
4. `AimQuantizer`로 각도를 양자화하고 power step은 192로 고정한다.
5. `LaunchVelocitySolver`가 만든 유효 속도를 `BattleState.commit_launch_velocity()`로 제출한다.
6. 적대 후보가 없으면 CHECK가 이미 terminal이어야 한다. terminal이 아닌데 후보가 없으면 fixture/state 오류다.
7. 정확히 같은 위치라 방향을 만들 수 없거나 승인 API가 명령을 거부하면 조용히 다른 샷을 찾지 않고 해당 case를 실패시킨다. forced-no-launch는 actor가 mutation으로 사라진 승인된 interruption 경로에만 사용한다.

이 정책은 충돌·예측 점수·벽 반사·아군 피해를 평가하지 않는다. 따라서 P3 AI의 품질 계약이나 콘텐츠 승률에 재사용하지 않는다.

### 입력 fixture schema v1

`pipeline/tests/fixtures/p1_graybox_cases.json`은 JSON number 대신 범위가 검증된 정수만 허용한다.

```json
{
  "schema_version": 1,
  "fixture_id": "p1_graybox_v2",
  "boundary": [[0, 0], [1024, 0], [1024, 640], [0, 640]],
  "combatants": [
    {
      "stable_key": 10,
      "faction": 1,
      "position": [337, 320],
      "speed_stat": 80,
      "radius": 32,
      "mass": 64,
      "hp": 100,
      "attack": 20
    }
  ],
  "cases": [
    {"case_id": 1, "seed_hi": 0, "seed_lo": 1, "insertion_variant": 0, "restore_after_turn": 0}
  ]
}
```

- 모든 논리 단위는 정수이며 loader가 Q47.16으로 명시 변환한다.
- faction은 append-only `BattleParticipant.Faction` 숫자다.
- stable key 정렬 뒤 body ID를 할당한다. insertion variant는 입력 배열 순서만 교란하고 안정 키는 바꾸지 않는다.
- `restore_after_turn=0`은 복원 없음, 양수는 해당 turn 완료 후 capture→encode→decode→restore를 한 번 수행한다.
- fixture의 unknown key, 중복 stable key, 범위 밖 값, 비대칭 팀 구성은 자동 보정하지 않고 실패한다.

## G-02 권장안 · 회색상자 encounter

- 전장: 좌상단 원점 `(0,0)`, 1,024×640 직사각형, WALL 경계, 내부 zone·장애물 없음
- 출전: player 3, enemy 3. D-03의 확정 범위 안에서 최소값을 사용한다.
- 위치: 양 팀을 X축 대칭으로 배치하며 어떤 원도 겹치거나 벽에 닿지 않는다.
- 공통 물리: 반지름 32, 무게 64, 기본 마찰·반발계수는 P0 승인값
- 공통 전투: HP 100, 공격 20, critical 0
- 속도: 각 팀에 80/100/125 한 기씩 배치
- player만 사람이 조작 가능하며 batch에서는 양 진영 모두 같은 shot supplier를 사용한다.
- `counts_for_victory=true`, `has_turn=true`; neutral은 이 fixture에 넣지 않는다.

양 팀의 스탯과 배치를 대칭으로 두는 이유는 P1 회귀가 콘텐츠 우열보다 순서·시드·삽입 교란에 민감하게 반응하도록 하기 위해서다. 이 값으로 재미나 최종 전투 길이를 확정하지 않는다.

## G-03 권장안 · 실행량과 종료

| 모드 | 전투 수 | 목적 |
|---|---:|---|
| narrow | 16 | PR·로컬 빠른 수용 검사 |
| default batch | 256 | CSV와 분포 확인 |
| exhaustive | 1,000 | `verify --full` 및 골든 결정론 게이트 |

- 한 전투는 최대 128번의 행동 commit을 허용한다.
- RESOLVE 한 번의 960+240 tick 계약은 P1-1을 그대로 사용한다.
- `BattleResult` terminal이면 정상 종료한다. `DRAW`도 정상 core 결과로 CSV에 별도 기록한다.
- 128턴 뒤 `ONGOING`이면 `TURN_LIMIT` infrastructure failure다. 승패로 변환하지 않는다.
- `RESOLVE_DEADLOCK`, `SimStatus` 실패, 잘못된 phase, snapshot 불일치는 즉시 해당 case 실패다.
- 배치 전체는 첫 결정론 불일치에서 중단하고 repro artifact를 남긴다. 독립적인 정상 case 통계 실행은 `--keep-going`을 명시한 경우만 계속한다.
- 실행시간 wall-clock은 권위 결과나 CSV 골든에 넣지 않는다.

## G-04 권장안 · CSV 계약

고정 열 순서:

```text
schema_version,batch_id,case_id,fixture_id,seed_hi,seed_lo,insertion_variant,restore_after_turn,result,turn_count,sim_tick_count,player_alive,enemy_alive,player_damage,enemy_damage,damage_destroyed,kill_boundary_destroyed,kill_zone_destroyed,forced_settle_count,terminal_hash,failure_code,failure_operation,repro_file
```

- UTF-8, LF, RFC 4180 quoting, header 정확히 1회
- enum과 boolean은 숫자로 기록한다. locale 숫자·float·시간 문자열을 금지한다.
- damage는 `ON_HIT_DEAL.value_a`, 파괴 원인은 `ON_DEATH_SELF.cause_id`로 집계해 observer가 전투 상태를 바꾸지 않게 한다.
- terminal hash는 `BattleSnapshot.encode()` 전체 바이트를 프로젝트 SHA-256으로 계산한다.
- 정상 행은 failure code/operation 0과 빈 repro file을 사용한다.
- 실패 행은 result=`ONGOING`, 실패 code/operation과 저장소 상대 repro 경로를 기록한다.
- stdout 요약은 전투 수, 결과별 수, 실패 수, 턴 min/median/max, sim tick 합계, forced settle 사용 전투 수를 출력한다. median은 정렬한 정수 배열에서 짝수 개면 아래쪽 중앙값을 사용한다.

## G-05 권장안 · P1 golden과 재현

체크인 파일:

```text
pipeline/tests/fixtures/p1_graybox_goldens.json
```

case별 고정 필드:

```text
case_id, result, turn_count, sim_tick_count, terminal_hash
```

- 일반 실행과 CI는 fixture를 수정하지 않는다.
- 갱신은 `run_p1_batch_sim_graybox.py --update-goldens --approval-ref <승인-ID>`로만 가능하다.
- `CI` 환경에서는 갱신 플래그를 거부한다.
- 승인 참조가 비어 있으면 실패한다. 최초 생성은 `P1-5`만 허용한다.
- 갱신 전후 case별 result, turn, tick, hash 차이를 출력한다.
- 코드·명세·case fixture·golden 변경은 같은 리뷰 단위에 둔다.
- 불일치 시 첫 case의 seed, insertion variant, restore turn, 기대·실제 값과 repro JSON을 출력한다.

repro artifact는 `pipeline/artifacts/p1_batch/repro_<case_id>.json`에 기록하며 `.gitignore` 대상이다. fixture 원문 전체를 복사하지 않고 fixture ID·case 필드·실패 단계·마지막 성공 snapshot bytes의 hex 또는 참조 경로를 포함한다.

## 상태·API 경계

권장 신규 책임:

```text
P1GrayboxFixtureLoader     정수 JSON 검증과 BattleState 생성 입력 변환
P1DeterministicShotSupplier  안정 상태 → LaunchCommand
P1BattleDriver            phase API만 사용해 한 전투를 terminal/실패까지 진행
P1BattleReport            고정 집계 값 객체
P1BatchCsvWriter          report 배열 → 고정 CSV
```

- fixture loader와 battle driver는 `src/core/battle/`에 둔다. Node·씬·파일 I/O를 호출하지 않는다.
- JSON 읽기, CSV 파일 쓰기, CLI 인자, artifact 경로는 `pipeline/` runner 책임이다.
- 회색상자 렌더와 마우스 입력은 `src/ui/battle/`과 scene adapter에 둔다.
- driver는 `BattleState`의 승인된 공개 phase API만 호출한다. `_world`나 내부 배열에 접근하지 않는다.
- batch supplier와 수동 조작은 모두 `AimQuantizer`→`LaunchVelocitySolver`→`commit_launch_velocity` 계약을 사용한다.
- 새 결정 상태가 필요하지 않도록 supplier와 report는 입력 상태에서 순수 파생한다. 필요해지면 `BattleSnapshot` schema 변경 승인부터 다시 받는다.

## 오류 계약 제안

P1-5 승인 시 현재 append-only 마지막 값 뒤에 추가한다.

```text
Code:
  INVALID_GRAYBOX_FIXTURE = 32
  BATTLE_TURN_LIMIT = 33
  BATCH_DETERMINISM_MISMATCH = 34
  INVALID_BATTLE_REPORT = 35

Operation:
  GRAYBOX_FIXTURE_LOAD = 104
  BATTLE_SHOT_SUPPLY = 105
  BATTLE_DRIVER_ADVANCE = 106
  BATTLE_REPORT_CREATE = 107
  BATCH_COMPARE = 108
```

CSV 파일 시스템 오류는 Python runner의 종료 코드 2와 stderr 경로로 보고하며 결정론 `SimStatus`에 OS 오류 문자열을 넣지 않는다.

## 파일 배치 제안

신규:

```text
docs/specs/p1_batch_sim_graybox.md
src/core/battle/p1_graybox_fixture.gd
src/core/battle/p1_deterministic_shot_supplier.gd
src/core/battle/p1_battle_driver.gd
src/core/battle/p1_battle_report.gd
src/ui/battle/p1_graybox_battle.gd
scenes/p1_graybox_battle.tscn
pipeline/scripts/p1_batch_sim.py
pipeline/tests/p1_batch_sim_graybox_test.gd
pipeline/tests/p1_batch_reference.py
pipeline/tests/run_p1_batch_sim_graybox.py
pipeline/tests/fixtures/p1_graybox_cases.json
pipeline/tests/fixtures/p1_graybox_goldens.json
```

수정:

```text
src/core/sim/sim_status.gd
scenes/main.tscn
pipeline/manifest.json       # manifest.py 경유만 허용
docs/specs/p1_index.md
docs/design/game_design.md   # 승인 결정을 D 항목으로 반영할 때만
AGENTS.md
HANDOFF.md
```

## 필요 플레이스홀더

| manifest ID | 파일 | 요구 | 사용 지점 |
|---|---|---|---|
| `art:sprites/p1_graybox_player_piece` | `assets/art/sprites/p1_graybox/PLACEHOLDER_player_piece.png` | 32×32 이상 RGBA, `P` 글리프, 아군 색 | `scenes/p1_graybox_battle.tscn::Battlefield/Pieces` |
| `art:sprites/p1_graybox_enemy_piece` | `assets/art/sprites/p1_graybox/PLACEHOLDER_enemy_piece.png` | 32×32 이상 RGBA, `E` 글리프, 적군 색 | 같은 노드 |
| `art:ui/p1_graybox_aim_marker` | `assets/art/ui/p1_graybox/PLACEHOLDER_aim_marker.png` | 투명 RGBA, 조준 방향 판독 가능 | `scenes/p1_graybox_battle.tscn::Battlefield/AimLayer` |

전장 바닥과 벽은 `Polygon2D`/`Line2D` 기본 도형으로 표현해 이미지 에셋을 추가하지 않는다. placeholder 이미지는 `placeholder_gen.py`, manifest 등록은 `manifest.py add`로만 수행한다.

## 수용 기준

1. fixture loader가 schema/version/unknown key/정수 범위/중복 stable key/겹침/벽 접촉/진영 비대칭을 거부한다.
2. shot supplier가 같은 상태에서 같은 target·angle·power·launch bytes를 만들며 observer 호출 순서에 영향을 받지 않는다.
3. 거리 동률은 낮은 target body ID로 해소되고 actor/target 삽입 순서를 교란해도 같다.
4. batch driver가 승인 phase API만 사용해 전투를 `PLAYER_VICTORY`, `PLAYER_DEFEAT`, `DRAW` 중 하나로 끝낸다.
5. turn limit와 core deadlock은 정상 result로 변환되지 않고 재현 가능한 infrastructure failure가 된다.
6. 기준 case, 역순 삽입, 고정 permutation이 result·turn·tick·terminal hash까지 일치한다.
7. 지정 turn의 snapshot round-trip 뒤 진행이 무복원 case와 동일하다.
8. 동일 case 1,000회 반복의 CSV 결정 필드와 terminal hash가 모두 일치한다.
9. CSV header·열 순서·UTF-8 LF·정수 enum·RFC 4180 quoting이 고정된다.
10. damage·파괴 집계 observer를 켜거나 꺼도 terminal state와 hash가 같다.
11. 최초 불일치나 실패는 case ID, seed, variant, restore turn, code/operation, repro 경로를 보고한다.
12. golden 갱신은 명시적 플래그·승인 참조·전후 요약 없이는 실행되지 않고 CI에서 거부된다.
13. 회색상자 씬에서 3대3 기물, 진영, 현재 actor, 드래그 조준선과 예상 궤적을 사람이 구분할 수 있다.
14. 모든 이미지가 `PLACEHOLDER_` 접두사와 manifest entry를 가지며 게이트 #3·#4를 통과한다.
15. P1-5 narrow 뒤 P1-1~4와 P0 narrow·1,000회 결정론 회귀가 통과한다.
16. Godot 활성 `pipeline/scripts/verify.py --full`이 통과한다.
17. 사람이 회색상자 전투를 직접 플레이해 조준·충돌·피해·턴 길이의 감각을 승인하거나 조정 항목을 기록한다.

## 구현 순서

1. 독립 Python reference와 fixture/golden schema를 먼저 고정한다.
2. fixture 값 객체·loader와 오류 계약을 구현한다.
3. pure shot supplier와 battle driver/report를 구현한다.
4. Godot narrow에서 단일 전투·교란·snapshot 복원·한도 실패를 검증한다.
5. batch CLI·CSV·repro·golden 갱신 게이트를 구현한다.
6. `placeholder_gen.py`로 플레이스홀더를 만들고 `manifest.py`로 등록한다.
7. 회색상자 scene/UI adapter를 구성하고 수동 플레이를 확인한다.
8. narrow → P1-1~4 → P0 → exhaustive → `verify --full` 순서로 검증한다.
9. 사람 전투 감각 검수 뒤 P1 전체 완료 여부를 판정한다.

## 승인 기록

다음 여섯 결정은 2026-08-22 사용자 진행 지시로 한 묶음 승인되었다.

1. G-01 가장 가까운 적·power 192 shot supplier와 정수 fixture schema
2. G-02 정식 콘텐츠와 분리된 대칭 3대3 회귀 encounter 값
3. G-03 narrow 16 / batch 256 / exhaustive 1,000 / turn limit 128
4. G-04 CSV 고정 열과 집계 규칙
5. G-05 terminal golden·명시적 갱신 승인 절차
6. G-06 플레이스홀더 3종과 scene 범위

승인 범위 밖 변경은 별도 재승인을 받는다.

## 구현·검증 기록

2026-08-23 PT-01~04 물리 기준선과 세로 플레이테스트 배치를 반영해 P1-5 최종 검증을 완료했다.

- 회귀 fixture는 `p1_graybox_v2`, 수동 세로 전장은 `p1_graybox_portrait_playtest_v1`로 분리했다. 수동 전장은 640×1,024에서 enemy 위·player 아래 3명씩 배치한다.
- terminal golden 승인 참조는 `P1-physics-tuning-PT-01-04-2026-08-23`이며, 기준 전투는 `PLAYER_VICTORY`, 20턴, 10,699틱, terminal hash `ba0a6c315abbb4502400ed3ab473bf0e1cac0eaa57d9b381142ba2f8cdda68a3`이다.
- narrow 16: 16승, 실패 0, 총 171,184틱, forced settle 0.
- batch 256: 256승, 실패 0, 총 2,738,944틱, forced settle 0.
- exhaustive 1,000: 1,000승, 실패 0, 총 10,699,000틱, forced settle 0.
- P0 1,000회 결정론 회귀와 Godot 4.6.3 활성 `verify --full`의 자동 발견 러너 17종이 모두 통과했다. lore canon 미초기화 게이트만 정상 SKIP이다.
- 사용자가 직접 드래그 발사·충돌·반사·피해·턴 길이를 검수하고 “문제 없음”으로 승인했다. 이로써 P1 전체 완료 조건 1~7을 충족한다.
