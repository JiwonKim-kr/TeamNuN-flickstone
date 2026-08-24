# P3 · 결정론적 적 AI 샷 선택 명세

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-24 |
| 승인 | 2026-08-24 · 사용자 P3-A01~18 전체 승인 (`승인해줄게`) |
| 선행 단계 | P0 결정론 물리, P1 전투·조준·피해, P2 콘텐츠·맵·상태·시너지 완료 |
| 후속 단계 | P4 런 구조, 제출용 전투 수직 슬라이스 |
| 구현 권한 | **있음. P3-A01~18 및 대체 P3-H01~06 승인 범위** |

## 목적

현재 회색상자의 최근접 적 직선 발사 공급자를 실제 적 AI로 교체한다. AI는 동일한 전투 상태에서 직접 조준·1회 벽 반사 후보를 고정 순서로 생성하고 정수 기하 휴리스틱으로 채점한다. 실제 결과는 기존 권위 시뮬레이션이 판정하며, 모든 난이도는 같은 탐색 정확도를 사용하고 최종 샷에만 등급별 오차를 주입한다.

완료 시 다음을 만족해야 한다.

1. 적이 피해·처치·아군 피해·자기 파괴·KILL 존을 고려해 납득 가능한 샷을 선택한다.
2. 같은 콘텐츠 지문·전투 상태·시드에서 플랫폼과 반복 횟수에 관계없이 같은 `LaunchCommand`를 만든다.
3. AI 평가는 권위 전투 상태와 권위 RNG를 바꾸지 않는다.
4. 웹 대상 3대3·5대5에서 적 턴 계산이 목표 300ms, 허용 상한 500ms를 만족한다.
5. 일반·정예·보스 3등급이 완벽한 최적 플레이가 아닌 서로 다른 오차를 보인다.

## 정본과 기존 계약

- `docs/design/game_design.md` D-10·17·18, 12장, U-10·41
- `docs/specs/p1_launch_aim_prediction.md`: 256방향·256 파워 단계 `LaunchCommand`
- `docs/specs/p1_ctb_battle_state.md`: AIM→RESOLVE→TURN_END→CHECK 공개 전이
- `docs/specs/p2_effect_resolution.md`: 공개 전이 뒤 `EffectResolver` 실행과 원자적 rollback
- `docs/specs/p2_status_synergy_modifiers.md`: 시너지·상태가 반영된 유효 스탯
- `docs/specs/p2_maps_enemies_environment.md`: enemy 정의와 map/KILL 존
- `docs/specs/p2_content_graybox.md`: 현재 고정 적 샷 공급자와 데이터 기반 회색상자

## 범위

- 한 행동 범위의 결정론적 후보 생성·복제 시뮬레이션·평가·정렬
- 일반·정예·보스 3개 AI 등급과 등급별 각도·파워 오차
- P2 효과 실행까지 포함하는 AI 전용 단일 행동 시뮬레이션
- KILL 경계·KILL 존과 아군 피해를 포함하는 안전 가드
- enemy schema의 `ai_grade_id`와 canonical fingerprint 상승
- P2 회색상자의 고정 공급자를 P3 AI로 교체
- 독립 기준값, narrow, 반복 결정론, 성능 벤치마크

## 비범위

- 공격형·회피형·밀어내기형 등 `ai_profile`
- 둘 이상의 미래 턴을 탐색하는 장기 계획
- 적 전용 능력 변환이나 기물별 하드코딩
- 직각 자의 비행 중 입력, 슈뢰딩거 위치 선택 등 탐색 차원을 추가하는 능력
- 좀비 감염 진행도 회피, 중립 기물을 무기로 사용하는 전략 평가
- GDExtension 이관
- AI 사고 연출, 새 이미지·VFX·SE
- 최종 밸런스와 41종 전체 enemy grade 배정

## 용어

| 용어 | 정의 |
|---|---|
| 후보 | 유효한 양자화 각도와 발사 파워로 만든 `LaunchCommand` |
| 단일 행동 평가 | 현재 AIM에서 발사해 RESOLVE·TURN_END·CHECK를 완료하고 다음 TURN_START 또는 BATTLE_END 직전까지 실행 |
| 원시 점수 | 오차 주입 전 후보 결과를 평가 함수로 계산한 `int64` |
| 안전 후보 | 행동자 자멸과 아군 파괴가 없는 후보 |
| 오차 샷 | 최상 후보에 등급별 각도·파워 델타를 더한 최종 명령 |
| 성능 게이트 | 결과에는 영향을 주지 않고 고정 후보 전체 실행 시간을 검사하는 자동 기준 |

## 승인 결정안

| ID | 결정안 | 이유 | 상태 |
|---|---|---|---|
| P3-A01 | 등급은 `COMMON=1`, `ELITE=2`, `BOSS=3`의 append-only 3종으로 고정한다 | 제출 데모와 후속 보스까지 표현하는 최소 축 | ✅ 승인 |
| P3-A02 | 세 등급은 동일한 후보 집합과 평가식을 사용하며 최종 오차만 다르다 | D-17의 난이도 계약 준수 | ✅ 승인 |
| P3-A03 | 탐색은 2단계 고정 예산이다. 1차는 16방향×4파워, 2차는 상위 4개 주변 3각도×3파워이며 중복 제거 후 총 후보는 최대 100개다 | GDScript 비용과 벽 반사 탐색의 균형 | ✅ 승인 |
| P3-A04 | 1차 각도는 4,096 간격, 파워는 `64/128/192/256`; 2차는 각도 `±2,048`, 파워 `±32`를 사용하고 `LaunchLimits` 밖은 제외한다 | 기존 양자화에 정확히 정렬되고 약·중·강·최대 샷을 포함 | ✅ 승인 |
| P3-A05 | 후보는 `(stage, parent_rank, angle, power)`의 명시 순서로 생성하고 최종 비교는 `score 내림차순 → actor 생존 → 아군 파괴 수 → angle → power` 순이다 | 컨테이너·삽입 순서 독립 결정론 | ✅ 승인 |
| P3-A06 | 후보마다 현재 행동 하나를 P2 효과까지 포함해 끝까지 실행한다. 다음 행동자의 TURN_START 효과는 실행하지 않는다 | 현재 샷의 직접 결과만 평가하고 미래 계획과 경계를 분리 | ✅ 승인 |
| P3-A07 | 점수는 아래 승인 가중치의 합이며 saturating clamp를 하지 않는다. 중간값 overflow는 AI 평가 실패다 | 조용한 보정 금지와 해석 가능한 평가 | ✅ 승인 |
| P3-A08 | 점수 우선순위는 적 처치 > 적 피해 > KILL 활용 > 아군 보호 > 행동자 생존·안전 위치다 | 사용자 승인 방향 반영 | ✅ 승인 |
| P3-A09 | 일반 오차는 각도 `[-4096,+4096]`, 파워 `[-64,+64]`; 정예는 `±2048/±32`; 보스는 `±1024/±16`이며 각각 256/8 단위의 균등 정수 델타다 | 일반은 보이는 실수, 상위 등급도 완벽하지 않은 샷 | ✅ 승인 |
| P3-A10 | 오차 RNG는 root RNG의 새 purpose `AI_SHOT_ERROR=3`, 행동자 body ID, `turn_index`로 파생하며 권위 RNG를 소비하지 않는다 | 반복·복원·후보 수 변화에도 권위 난수열 불변 | ✅ 승인 |
| P3-A11 | 오차 샷이 행동자를 파괴하거나 아군을 파괴하고 안전 후보가 존재하면 오차 크기를 절반씩 줄여 최대 3회 재검사한 뒤 원래 최상 안전 후보로 돌아간다 | 고의적 자살·대량 팀킬 방지, 결정론 유지 | ✅ 승인 |
| P3-A12 | 안전 후보가 하나도 없으면 전체 후보 중 원시 점수 최상을 사용한다 | 막힌 국면에서도 강제 무행동을 만들지 않음 | ✅ 승인 |
| P3-A13 | 벽시계 시간으로 탐색을 중단하지 않는다. 모든 클라이언트가 고정 후보를 끝까지 평가한다 | 실행 환경별 명령 불일치 방지 | ✅ 승인 |
| P3-A14 | 성능 목표는 300ms, 허용 상한은 500ms다. 500ms 초과는 테스트 실패이며 후보 수 변경은 명세 재승인을 요구한다 | 웹 제출 성능과 결정론 동시 보장 | ✅ 승인 |
| P3-A15 | `enemies.json` v2에 필수 `ai_grade_id`를 추가하고 catalog/fingerprint를 v6으로 올린다. 기존 P2 적 3종은 `COMMON`으로 이관한다 | 런타임 적이 명시적으로 난이도를 소유 | ✅ 승인 |
| P3-A16 | `BattleSnapshot` v7과 `SimSnapshot` v2는 변경하지 않는다. AI는 선택 중간 상태를 권위 상태에 저장하지 않는다 | AI 선택은 AIM 시점의 순수 파생 결과 | ✅ 승인 |
| P3-A17 | P2 회색상자는 P1 고정 공급자를 P3 AI로 교체하되 기존 600ms 발사 연출 지연은 유지한다 | 사람이 판단을 인지할 시간과 전투 결과 분리 | ✅ 승인 |
| P3-A18 | 첫 P3는 공통 평가식 하나만 제공하고 `ai_profile`과 기물별 분기는 후속 승인으로 미룬다 | 제출 범위와 회귀 표면 제한 | ✅ 승인 |

## 후보 생성

### 1차 거친 격자

- 각도: `0, 4096, ... 61440`의 16개
- 파워: `64, 128, 192, 256`의 4개
- 총 64개

### 2차 정밀 격자

1차 점수 상위 4개 각각에 대해 다음 조합을 만든다.

- 각도: 부모 각도 `-2048, 0, +2048` (`& 0xFFFF` 순환)
- 파워: 부모 파워 `-32, 0, +32`
- 유효 범위 밖 파워 제거
- 1차·2차 전체에서 동일 `(angle,power)` 중복 제거

최종 후보 수는 64~100개다. 후보 수 자체와 최종 정렬 결과를 테스트 골든에 기록한다.

## 단일 행동 시뮬레이션

각 후보는 다음 순서로 평가한다.

1. 평가 전 `BattleSnapshot` bytes를 캡처한다.
2. `BattleState.copy()`로 로컬 상태를 만든다.
3. `LaunchVelocitySolver.commit()` 후 발생한 trigger를 `EffectResolver`로 처리한다.
4. RESOLVE 동안 `advance_resolve()`와 각 공개 전이 뒤 effect resolution을 반복한다.
5. TURN_END와 CHECK를 완료하고 각 공개 전이 뒤 effect resolution을 수행한다.
6. `TURN_START` 또는 `BATTLE_END`에 도달하면 중단한다. 다음 TURN_START는 완료하지 않는다.
7. 전후 combatant, participant, world body, trigger 결과로 점수를 만든다.
8. 원본 `BattleSnapshot` bytes가 평가 후에도 같음을 검사한다.

후보 하나의 실패는 조용히 최저 점수로 바꾸지 않는다. 잘못된 상태·deadlock·effect 실패는 전체 AI 선택을 실패시키고 호출자가 진단을 표시한다.

## 평가 함수

모든 항목은 행동자 진영을 기준으로 계산한다.

| 항목 | 계산 | 가중치 |
|---|---|---:|
| 적 적용 피해 | 후보 전후 적 HP 감소 합 | `+100 × HP` |
| 적 파괴 | 전후 살아 있는 적 감소 | `+100,000 × 수` |
| KILL 파괴 | 적 `ON_DEATH_SELF` cause가 KILL boundary/zone | 추가 `+25,000 × 수` |
| 아군 적용 피해 | 후보 전후 아군 HP 감소 합 | `-150 × HP` |
| 아군 파괴 | 전후 살아 있는 아군 감소 | `-150,000 × 수` |
| 행동자 파괴 | 행동자가 후보 종료 전에 제거 | 추가 `-300,000` |
| 행동자 위험 위치 | 생존 행동자 중심에서 가장 가까운 KILL 폴리곤까지 거리가 반지름 2배 미만 | `0~-20,000` 선형 |

- 적 파괴 보너스는 적 HP 감소 점수와 함께 적용한다.
- 아군 파괴 패널티는 아군 HP 감소와 함께 적용한다.
- KILL 파괴 추가점은 위험 지형 활용을 보이되 일반 처치보다 절대 우선하지 않게 한다.
- 중립 기물은 P3 첫 범위에서 점수 0이며 몸체로서 물리에는 참여한다.
- 확률 효과는 평가용 파생 RNG에서 실행한 결정 결과가 아니라 정수 기댓값으로 평가해야 한다. P3 fixture는 확률 능력이 없는 P2 runtime 콘텐츠로 이 경계를 먼저 검증하고, 확률 효과 일반화는 해당 콘텐츠 승인과 함께 확장한다.

## 오차 주입과 안전 가드

1. 원시 점수 최상 후보를 고른다.
2. 등급별 파생 RNG로 각도·파워 델타를 하나씩 생성한다.
3. 각도는 16비트 순환하고 파워는 유효 발사 범위로 제한한다.
4. 오차 샷을 단일 행동 시뮬레이션으로 재검사한다.
5. 안전하지 않으면 델타를 0 방향으로 절반 반올림해 최대 3회 재검사한다.
6. 모두 안전하지 않으면 최상 안전 후보, 안전 후보가 없으면 원시 최상 후보를 사용한다.

오차 주입은 원시 후보 순위나 평가 점수를 바꾸지 않는다. UI는 AI가 사용한 등급만 표시할 수 있으며 원시 최적 샷을 노출하지 않는다.

## 데이터·API

### enum과 데이터

```text
AiGrade.INVALID = 0
AiGrade.COMMON = 1
AiGrade.ELITE = 2
AiGrade.BOSS = 3
```

`enemies.json` v2 record exact key set에 `ai_grade_id`를 추가한다. fixture를 포함한 모든 enemy record는 명시값을 가져야 하며 누락·미지원 값은 catalog 전체 load 실패다.

### 공개 API 후보

```gdscript
AiShotSelector.command_for(
    state: BattleState,
    grade_id: int,
    status: SimStatus
) -> LaunchCommand

AiShotEvaluator.evaluate(
    state: BattleState,
    command: LaunchCommand,
    status: SimStatus
) -> AiShotEvaluation
```

`AiShotEvaluation`은 초기화 여부, 점수, 적/아군 피해·파괴 수, KILL 파괴 수, 행동자 생존, 최종 위치 위험 점수를 가진 불변 값 객체다. 후보 목록과 벤치마크 시간은 권위 snapshot에 저장하지 않는다.

## 결정론·오류 계약

- 각도·파워·점수·가중치는 정수만 사용한다.
- Dictionary 순회 결과를 정렬 근거로 사용하지 않는다.
- AI 평가용 복사 상태의 trigger/effect/RNG는 원본 상태를 소비하지 않는다.
- 동일 입력 1,000회, participant/body 삽입 순서 교란, snapshot 복원 뒤 같은 command bytes와 evaluation tuple을 요구한다.
- AI 선택 도중 오류가 나면 무작위·최근접·무행동 fallback을 하지 않는다.
- 신규 `SimStatus.Code`와 `Operation`은 기존 마지막 값 뒤에 append-only로 추가한다.
- 성능 시간은 리포트에만 사용하고 명령 선택·RNG·점수에 절대 입력하지 않는다.

## 성능 계약

- 기준 장면: P2 runtime 3대3과 제출 목표 5대5 fixture
- 측정: release/debug 두 프로필을 구분하고, 워밍업 뒤 연속 20회 중앙값과 최댓값 기록
- 수용: 배포 대상 Web release에서 중앙값 300ms 이하, 최댓값 500ms 이하
- 로컬 headless 수치는 회귀 추세로 기록하되 Web release 결과를 최종 게이트로 사용
- 초과 시 순서: 고정 후보 예산 축소 재승인 → 결정론적 조기 가지치기 별도 승인 → GDExtension 검토

## 수용 기준

1. 64개 1차 후보와 최대 36개 정밀 후보가 명시 순서·중복 제거 계약을 지킨다.
2. 직접 충돌보다 벽 반사가 더 높은 피해·처치를 만들면 AI가 벽 반사를 선택한다.
3. 처치 후보가 단순 고피해 후보보다 높은 점수를 얻는다.
4. 비슷한 공격 결과라면 아군 피해·자멸·KILL 위험이 낮은 후보를 고른다.
5. 적을 KILL 존으로 제거하는 샷이 추가 점수를 얻는다.
6. 상태·시너지 modifier와 P2 effect가 후보 결과에 반영된다.
7. COMMON·ELITE·BOSS가 같은 원시 최적 후보에서 승인 범위의 서로 다른 오차를 만든다.
8. 안전 후보가 있으면 오차 때문에 행동자가 자멸하거나 아군이 파괴되는 최종 명령을 내지 않는다.
9. AI 평가 전후 원본 BattleSnapshot bytes가 같다.
10. AI error substream 사용 전후 권위 RNG 상태와 이후 전투 확률 결과가 같다.
11. 동일 fixture 1,000회, 삽입 순서 교란, 중간 snapshot 복원에서 command bytes·evaluation tuple이 같다.
12. enemy v2/catalog v6/fingerprint v6가 Godot와 독립 Python canonical reference에서 일치한다.
13. 기존 P2 적 3종은 COMMON으로 로드되고 P2 회색상자에서 P3 AI를 사용한다.
14. 3대3·5대5 Web release 벤치마크가 목표·상한을 보고하고 최댓값 500ms를 넘지 않는다.
15. P0·P1·P2 narrow와 Godot 활성 `verify --full`이 통과한다.
16. 사람이 일반 AI의 가끔 보이는 실수, 정예의 벽 반사/KILL 활용, 보스의 비완벽성을 플레이 검수한다.

## 대상 파일

### 신규 후보

```text
docs/specs/p3_ai_shot_selection.md
src/core/battle/ai_grade.gd
src/core/battle/ai_shot_evaluation.gd
src/core/battle/ai_shot_evaluator.gd
src/core/battle/ai_shot_selector.gd
pipeline/tests/p3_ai_shot_selection_test.gd
pipeline/tests/p3_ai_shot_selection_reference.py
pipeline/tests/run_p3_ai_shot_selection.py
pipeline/tests/fixtures/p3_ai_shot_selection/
```

### 수정 후보

```text
AGENTS.md
HANDOFF.md
docs/design/game_design.md
src/core/battle/battle_random.gd
src/core/sim/sim_status.gd
src/core/data/enemy_definition.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/content_limits.gd
src/core/data/catalog.json
src/core/data/enemies.json
pipeline/tests/fixtures/p2_*/enemies.json
src/ui/battle/p2_content_graybox.gd
```

실제 구현 전 `rg`로 모든 enemy fixture를 다시 열거하고 schema 상승 대상 누락을 금지한다. `BattleSnapshot`과 `SimSnapshot`은 변경 대상이 아니다.

## 필요 에셋

신규 에셋과 매니페스트 변경 없음. AI 판단과 등급은 기존 HUD의 텍스트로만 검수한다.

## 구현 순서 — 전체 승인 뒤

1. enemy v2/catalog·fingerprint v6와 독립 canonical reference를 구현한다.
2. AI grade·평가 결과 값 객체와 단일 행동 evaluator를 구현한다.
3. 고정 2단계 후보 생성·정렬과 오차 substream·안전 가드를 구현한다.
4. positive/negative/boundary, 1,000회 결정론, snapshot·RNG 불변 narrow를 통과시킨다.
5. P2 회색상자를 P3 selector에 연결하고 3대3 플레이 검수를 진행한다.
6. 제출 목표 5대5 fixture와 Web release 성능을 측정한다.
7. 관련 narrow 뒤 Godot 활성 `verify --full`을 실행한다.
8. 사람 검수 승인 후 AGENTS/HANDOFF/P3 상태를 갱신한다.

## 승인 기록

P3-A01~18은 2026-08-24 승인되었다. 구현 중 계측으로 전체 행동 복제 방식의 성능 충돌이 확인된 뒤, 이를 대체하는 P3-H01~06도 같은 날 추가 승인되었다.

- 최대 후보 100개와 2단계 격자
- 평가 가중치
- 등급별 오차 범위
- 300ms 목표 / 500ms 상한
- enemy schema v2와 catalog/fingerprint v6 이관

아래 값은 현재 승인 기준이며 변경 시 재승인이 필요하다.

## 구현 중 성능 충돌 기록 — 재승인 필요

2026-08-24 P3-A01~18 승인 뒤 가장 먼저 P2 runtime 3대3 상태에서 단일 후보의 전체 행동 평가를 Godot 4.6.3로 계측했다.

- 후보 1개: **12,203ms**
- 승인 목표/상한: 300ms / 500ms
- 100개 전체 탐색은 60초 후에도 완료되지 않아 수동 중단

병목은 후보 개수보다 후보 하나가 P2 효과를 포함해 `advance_resolve()`를 반복할 때 매 tick 권위 rollback용 상태 전체 복사·효과 정산을 수행하는 구조다. 후보 수만 축소해도 500ms 상한을 달성할 수 없다.

따라서 P3-A03·06·14의 조합은 현재 GDScript 권위 API로 구현 불가능하며, 아래 중 하나의 사람 재승인 전에는 구현을 계속하지 않는다.

1. **권장: 하이브리드 휴리스틱 AI.** 직접 조준·1회 벽 반사 후보를 기하학적으로 채점하고 전체 전투 복제 시뮬레이션은 하지 않는다. 결정론·500ms·등급별 오차는 유지하지만 D-17의 정확한 결과 예측을 P3 제출 범위에서 완화한다.
2. speculative 전용 비원자 고속 시뮬레이션 경로를 새로 만든다. 권위 rollback과 별도 구현이 되어 회귀·유지보수 위험이 크다.
3. `SimWorld`/전투 평가를 GDExtension으로 이관한다. 웹 호환성과 일정 위험이 가장 크다.

현재 추가된 AI 코어는 컴파일되지만 성능 계약 미충족으로 미완료 상태다. runtime enemy schema와 플레이 씬은 아직 변경하지 않았다.

### 승인된 대체안

2026-08-24 사용자가 권장 하이브리드 AI 변경안을 승인했다. 아래 결정은 충돌하는 P3-A03·04·06·07의 전체 복제 평가 부분을 대체한다. 나머지 P3-A01~18은 유지한다.

| ID | 대체 결정 | 상태 |
|---|---|---|
| P3-H01 | 후보는 살아 있는 적을 향한 직접 조준과 각 외곽 벽에 적 위치를 반사한 1회 bank 조준으로 만든다 | ✅ 승인 |
| P3-H02 | 파워는 `64/128/192/256`, 후보는 target body ID→직접/edge index→power 순으로 생성하고 `(angle,power)` 중복을 제거해 최대 100개로 제한한다 | ✅ 승인 |
| P3-H03 | 전체 물리·효과 복제 대신 정수 ray의 첫 충돌 대상, 공격력×power 근사 피해, 처치, 아군 차폐, KILL 존 방향 위험을 채점한다 | ✅ 승인 |
| P3-H04 | 평가 결과는 권위 판정이 아닌 선택용 휴리스틱이며 실제 피해·승패는 기존 P0~P2 권위 전투가 결정한다 | ✅ 승인 |
| P3-H05 | 결정론, 등급별 오차, 안전 가드, 300ms 목표·500ms 상한은 유지한다 | ✅ 승인 |
| P3-H06 | 정확한 전체 결과 예측과 다중 반사·장기 계획은 제출 이후 speculative 고속 경로 또는 GDExtension 검토로 이관한다 | ✅ 승인 |

하이브리드 구현은 동일 P2 3대3 상태에서 실제 `command_for()` 1회가 **302~336ms**로 500ms 상한을 통과했다. 독립 Python 기준, Godot P3 narrow, P2-6 1,000회·16×2 terminal/snapshot 골든 이관, Godot 4.6.3 quick `verify --full`도 통과했다. 남은 완료 조건은 등급별 행동에 대한 사람 플레이 검수다.
