# HANDOFF — Flickstone 프로젝트 인수 문서

> 최종 갱신: 2026-08-22
> 규칙은 `CLAUDE.md`, 명령 범위는 `docs/command-catalog.md`, 게임 설계는 `docs/design/game_design.md`를 정본으로 삼는다.

## 1. 프로젝트 한 줄 요약

원형 기물을 직접 튕기는 충돌 전투에 CTB 턴제, 기물 덱빌딩, 분기형 로그라이트 런 구조를 결합한 Godot 게임을 제작한다.

## 2. 확정된 결정 사항

| 항목 | 결정 |
|---|---|
| 프로젝트 코드명 | **Flickstone**. 정식 타이틀은 미정 |
| 엔진 | **Godot 4.6.x / GDScript** |
| 플랫폼 | **PC(Steam) 우선**. 웹은 개발 프리뷰 |
| 게임 설계 정본 | `docs/design/game_design.md` |
| 현재 단계 | **P1-5 구현·narrow 검증 완료 — 사람 감각 검수 및 장시간 회귀 대기** |
| 물리 | Godot 내장 물리 미사용. 고정소수점 기반 자체 결정론 시뮬레이션 |
| 고정소수점 | `int64` + 소수부 16비트 (`FIX_SCALE=65,536`, Q47.16), 위치 안전 범위 ±8,192 |
| 물리 안전 범위 | 속도 ≤ 4,096, 초기 발사 ≤ 2,048, 무게 1~256, 임펄스 ≤ 2,097,152. 범위 밖 데이터는 로드·테스트 실패 |
| 고정 각도 | 한 바퀴 65,536, `0=+X`, 시계 방향. 사분면 4,096구간·4,097개 Q47.16 LUT와 선형 보간 |
| PRNG | `xoshiro128**` 4×uint32, 64비트 런 시드, 키 기반 비소비 서브스트림, rejection sampling. U-23 승인 전에는 단일값 범위·0%·100% 호출을 거부 |
| 반올림 | 최근접, 절반은 0에서 먼 방향. 암묵적 절삭·포화·조용한 clamp 금지, 오류는 실패 처리 |
| 고정 스텝 | 120Hz, 정확한 유리수 `1/120`, 시간·입력은 정수 틱, 권위 시뮬레이션 틱 폐기 금지 |
| P0 이동 감쇠 | 기본 마찰 5/2초⁻¹, 기본 배율 1, 정지 임계 1/2. 외부 가속도가 없는 틱에서만 정지 처리 |
| 존 중첩 | `zone_id` 오름차순, 마찰 배율은 순서 곱, 가속도는 순서 합. P0 override 없음, 안전 범위 초과 실패 |
| 시뮬레이션 ID | body·zone 별도 uint32, 0 무효, 월드별 단조 증가·비재사용, 안정 정렬 후 할당, 복제 시 카운터 보존 |
| SimEvent | 정수 공통 헤더·관계 ID·고정 payload, 불변 append-only 큐, sequence/cursor 정본, 동적 payload 금지 |
| 소멸 진입 | 기물 중심점 기준, 경계선 위 안전, 서브스텝 선분 검사와 최초 교차 사용 |
| P0 폴리곤 | 외곽은 시계 방향 단순 볼록 3~64정점, 내부 존은 단순 오목 허용, 비정상 데이터 로드 실패 |
| 벽 모서리 | 관입 깊이↓·edge index↑로 전 접촉 처리, 꼭짓점 전용 법선, 재검사 64회 미해소 시 실패 |
| P0 충돌값 | 반발 17/20, 반지름 8~128(기본 32), 무게 1~256(기본 64), 시험 속도 512/1,024/2,048/4,096 |
| 서브스텝 | 월드 공통 이동량/(최소 반지름/2), 1~16, 위치만 유리수 분할, 초과 시 이동 전 실패 |
| destructible | P0부터 저장·해시, 일반 파괴만 확인, 소멸은 무시, BODY_DESTROYED 공통·cause만 구분, 관리 제거 별도 |
| P0 상태 해시 | 정규 SimSnapshot 바이트의 SHA-256, 내부 32바이트·외부 소문자 64 hex, 게임 판정·RNG 재사용 금지 |
| 콘텐츠 | 지원하는 트리거·효과 원자의 조합은 데이터로 정의 |
| 작업 흐름 | `play spec` 승인 → `play build` → `play test` → `verify` → `review` |
| 승인 지점 | play spec 승인 / art lock / review — **생략 불가** |
| 에셋 정책 | P0·P1은 매니페스트에 등록한 플레이스홀더만 사용 |
| 아트·사운드 시작 | 전투 감각을 검증한 다음 `art lock`, `art gen`, SE 작업 시작 |
| CI | GitHub Actions에서 Godot 4.6.3 기준 `verify --full` 실행 |

## 3. 현재 저장소 상태

- [x] 기존 TeamNuN 저장소의 `.git`과 `origin` 보존
- [x] artificer 파이프라인 작업 트리 스냅샷 이식
- [x] 이전 게임 전용 텍스트 내보내기 구현·테스트·명령 제거
- [x] Flickstone 프로젝트명과 README 적용
- [x] 게임 설계 정본 편입 및 파이프라인 경로 정합화
- [x] P0 구현 명세 4종 초안 작성
- [x] P0-1 `FixMath / FixVec2 / SimRng` 명세 승인
- [x] P0-2 `SimWorld` 명세 승인
- [x] P0-3 `원 충돌 / 벽 / 소멸 영역` 명세 승인
- [x] P0-4 `결정론 / 상태 해시 / 회귀 테스트` 명세 승인
- [x] P0-1 `FixMath / FixVec2 / FixTrigLut / SimRng` 구현 및 골든 회귀 테스트 통과
- [x] P0-2 `SimBody / SimZone / SimEvent / SimWorld` 구현 및 고정 스텝 수용 테스트 통과
- [x] P0-3 `SimPolygon / SimCollision / 벽 / 소멸 영역` 구현 및 결정론 스트레스 테스트 통과
- [x] P0-4 `SimSnapshot / SHA-256 / 골든 결정론 회귀` 구현 및 플랫폼 교차 게이트 구성
- [x] Godot 4.6.3 headless import·스모크·P0-1 수용 테스트 실행 확인
- [x] Godot 4.6.3 P0-2 ID·마찰·존·정지·복제·원자성 수용 테스트 실행 확인
- [x] Godot 4.6.3 P0-3 충돌·서브스텝·벽·소멸 수용 테스트 실행 확인
- [x] Windows Godot 4.6.x 자동 실행을 전용 로그·격리 프로필·오류창 억제 경계로 통합
- [x] P0 결정론 회귀 테스트 통과
- [x] P1 전투 루프를 5개 하위 명세로 분리한 인덱스 승인 (`docs/specs/p1_index.md`)
- [x] P1-1 CTB/BattleState C-01~09와 전체 명세 승인 (`docs/specs/p1_ctb_battle_state.md`)
- [x] P1-1 CTB/BattleState 구현, 독립 Python KAT·Godot 수용 테스트·P0 회귀·`verify --full` 통과
- [x] P1-2 발사/조준/입력 양자화/궤적 예측 L-01~09와 전체 명세 승인 (`docs/specs/p1_launch_aim_prediction.md`)
- [x] P1-2 `LaunchCommand` 6바이트 codec, 정수 조준 양자화, 무게 보정 발사 속도 구현
- [x] P1-2 권위 발사 커밋과 `BattleState` 깊은 복제 기반 순수 궤적 예측 구현
- [x] P1-2 Godot 입력·궤적선 UI 브리지 구현. 코어 상태 직접 수정 경로 없음
- [x] P1-2 독립 Python KAT·fixture와 Godot 수용 테스트 15개 통과
- [x] P1-1, P0-1~4 narrow 회귀 통과. P0-4는 1,000회 반복·입력 순열 포함
- [x] P1-2 반영 상태의 Godot 4.6.3 `verify --full` 완료 — lore 미초기화 1게이트 정상 SKIP, 나머지 통과·러너 13종 전부 통과
- [x] P1-3 피해 해결 R-01~10 승인, 구현, 독립 기준값·Godot 수용·전체 회귀 검증 완료 (`docs/specs/p1_damage_resolution.md`)
- [x] P1-4 트리거 버스/파괴 귀속/전투 결과 초안과 T-01~10 승인 결정 작성 (`docs/specs/p1_trigger_bus_battle_result.md`)
- [x] P1-4 T-01~10 전체 명세 승인 (`docs/specs/p1_trigger_bus_battle_result.md`)
- [x] P1-5 회색상자/배치 시뮬 G-01~06 승인 (`docs/specs/p1_batch_sim_graybox.md`)
- [x] P1-5 최초 프로토타입 계측: 3v3 단일 전투가 5분 제한 초과, 40턴·생존 6·총 HP 309 확인
- [x] `SimWorld.step` 롤백 비용 최적화 후 P0 상태·오류 원자성·해시 회귀 통과
- [x] 최적화 후 P1-5 baseline terminal 결과와 처리시간 측정
- [x] P1-5 core driver·batch CSV·golden·snapshot 복원·집계·repro 구현
- [x] P1-5 회색상자 scene·manifest placeholder 3종 구현, Godot import·smoke·manifest 검증
- [x] P1-5 실제 batch 256 — 256승·실패 0·terminal hash 일치
- [ ] P1-5 회색상자 사람 수동 감각 검수 (조준·충돌·피해·턴 길이)
- [ ] P1-5 실제 exhaustive 1,000 및 현재 변경 기준 `verify --full`

### 3.1 P1-2 현재 작업 기록

구현된 코어:

- `LaunchLimits`: 승인된 각도·파워·속도·예측 상수
- `LaunchCommand`: `schema_version:uint16 + angle:uint16 + power_step:uint16` little-endian codec
- `AimQuantizer`: 256개 LUT 방향 후보의 정수 내적 비교, 256단계 파워 양자화
- `LaunchVelocitySolver`: 기준 속도 1,024, 절대상한 2,048, `sqrt(64 / mass)` 보정
- `TrajectoryPredictor`: 원본 `BattleState`를 바꾸지 않는 사본 시뮬레이션, 첫 기물 충돌·두 번째 벽 반사·정지·소멸·240틱 잘림 처리
- `TrajectoryPoint`·`TrajectoryPrediction`: 최대 64개 값 사본과 사건 marker
- `SimStatus`: Code 22~24, Operation 83~89 append-only 추가

구현된 UI·검증 경계:

- `AimInputAdapter`: 카메라 변환 결과를 Q47.16 최근접·절반은 0에서 먼 방향으로 정수화하고 immutable command signal만 방출
- `TrajectoryLineAdapter`: 코어 예측을 renderer용 위치·marker 값 사본으로 변환
- `run_p1_launch_aim_prediction.py`: `verify --full` 자동 발견 narrow runner
- `p1_launch_reference.py`·`p1_launch_vectors.json`: codec·파워·무게별 속도의 독립 기준값

### 3.2 P1-4 현재 작업 기록

- P1-3 사건 소비 시 파괴된 participant/combatant가 즉시 제거되므로, P1-4가 사망·처치 근거를 제거 전에 불변 레코드로 보존해야 하는 구현 제약을 확인했다.
- 확정 TriggerId, 물리·phase 발생 경계, 같은 시점 전체 순서, 폭 우선 wave와 유한 처리 한도를 T-01~03으로 분리했다.
- 직접 충돌 가해자와 행동의 운동 root를 분리한 연쇄·환경 처치 귀속, `counts_for_victory`/중립 제외 승패, 동시 전멸 결과를 T-04~05로 분리했다.
- 외부 directive가 승패를 주입하는 P1-1 임시 API를 권위 `resolve_check()`와 검증 wrapper로 전환하는 migration을 T-06으로 제안했다.
- U-23은 record별 비소비 서브스트림과 전투 wrapper의 0%·100%·단일 후보 무소비 처리로 제안했다. 저수준 P0 `SimRng` 계약은 바꾸지 않는다.
- `BattleSnapshot` v3, append-only 진단, 독립 Python KAT·Godot narrow·전체 회귀를 T-08~10으로 분리했다.
- P1 인덱스의 “능력 등록”은 효과·콘텐츠 데이터가 없는 P1-4 범위와 충돌하므로, 실제 등록을 후속 데이터 기반 능력 단계로 미루는 수정안을 T-01 승인 항목에 명시했다.
- T-01~10 전체를 구현했다. 고정 트리거 레코드, wave/record 한도 버스, phase·물리 사건 변환, 운동 root 귀속, 권위 승패, record별 RNG, BattleSnapshot v3와 v1/v2 호환을 포함한다.
- `SimStatus` Code 28~31 / Operation 97~103을 append-only로 추가하고 P1-4 narrow runner와 독립 Python KAT를 `verify --full` 자동 발견에 편입했다.
- portable Godot 4.6.3으로 P1-4 narrow, P1-1~3, P0 narrow와 1,000회 결정론 반복을 통과했다. Godot 활성 `verify --full`도 게이트 5개 중 lore 미초기화 1개 SKIP, 러너 15종 전체 PASS로 완료했다.

남은 작업:

1. Godot 편집기 또는 실행 파일로 `scenes/main.tscn`을 열고 아군 P 기물 드래그, 예상 궤적, 충돌·피해·턴 길이를 사람이 검수한다.
2. 실제 `exhaustive` 1,000을 실행해 장시간 결정론 결과를 확정한다. (`batch` 256 완료)
3. 현재 P1-5 씬 변경을 포함한 Godot 활성 `verify --full`을 완료한다.
4. 위 결과와 사람 검수 결정을 반영해 P1 전체 완료 여부를 판정한다.

### 3.3 P1-5 성능·구현 진행 기록

- 최초 세로 3열 대형은 40턴까지 200초 이상, 생존 6·총 HP 309였고 단일 전투가 300초 제한을 넘었다.
- `SimWorld.step()` 실패 복구는 기존 불변 값 객체를 공유하는 얕은 배열 스냅샷으로 변경했다. 공개 `SimWorld.copy()`의 깊은 복제 계약은 유지한다.
- `BattleState.advance_resolve()`도 롤백 전용 구조 스냅샷과 내부 transaction world copy를 사용한다. 권위 상태에 대한 공개 깊은 복제·snapshot schema는 바꾸지 않는다.
- P0 SimWorld 원자성·깊은 복제, P0 충돌 원자성·결정론, P1 CTB phase rollback, P1 피해·파괴 rollback·snapshot continuation이 최적화 뒤 통과했다.
- 승인 문서에 초기 좌표가 지정되지 않았으므로 전장·3대3·스탯·power를 유지한 중앙 근접 대칭 대형을 사용한다. 목적은 동일 물리에서 무충돌 이동 턴을 줄이는 것이다.
- 최적화·근접 대형 baseline은 52턴·17,171틱·123,480ms에 `PLAYER_VICTORY`로 끝났고 terminal hash는 `ea819aa9acc94f2cf115d7446fd05da76fbe396cadb8c1405715e5f5ff7b3df6`이다.
- Godot 활성 `verify --full`은 P1-5 baseline 이전 단계와 P0 결정론 골든·N=9·삽입 순열까지 PASS를 확인했다. 이후 P0 1,000회 반복이 24분을 초과해 이번 실행은 중단했으며 전체 PASS 체크는 아직 미완료다.
- P1-5 fixture schema v1 검증, RFC 4180 UTF-8 LF CSV writer, 승인 참조가 필요한 golden 갱신과 CI 갱신 거부를 구현했다.
- 기준·역순 삽입·10턴 snapshot round-trip 3개 case는 모두 52턴·17,171틱·동일 terminal hash로 PASS했다. 일반 실행의 체크인 golden 비교도 PASS했다.
- 초기 구현 증분은 3-case였으며, 아래 단계에서 승인된 narrow 16개와 집계·repro 경계로 확장했다.
- 위 3-case 증분을 16-case narrow로 확장했다. 4 workers 실행에서 16승, 각 52턴·17,171틱·동일 terminal hash, 총 274,736틱, forced settle 0으로 PASS했다.
- observer 집계는 기준 case에서 player damage 293, enemy damage 300, damage 파괴 5, 경계/존 파괴 0을 기록했고 observer 적용 전 terminal hash를 유지했다.
- 병렬 runner는 case ID 정렬, worker 1~16 제한, `--keep-going`, 실패 CSV 행, numeric code/operation과 저장소 상대 repro 경로를 지원한다.
- 승인 실행량 16/256/1,000은 `narrow`/`batch`/`exhaustive` 모드로 확장된다. 1,000 case 생성 계약은 독립 테스트를 통과했지만 실제 장시간 실행은 아직 미완료다.
- `placeholder_gen.py`로 아군 P·적군 E·조준 `>` PNG를 만들고 `manifest.py add`로 3개 entry를 등록했다. 전장 바닥·벽은 승인대로 `Polygon2D`/`Line2D`만 사용한다.
- `scenes/p1_graybox_battle.tscn`과 `src/ui/battle/p1_graybox_battle.gd`를 추가하고 메인 씬에 연결했다. 3대3 진영, 현재 actor 강조, 아군 드래그 발사, 조준선·권위 예측 궤적, P1 전용 결정론 적 샷, 재시작을 제공한다.
- 씬 추가 뒤 Godot 4.6.3 headless import·main scene smoke·manifest 3-entry 정합성이 모두 PASS했다.
- 씬 추가 뒤 P1-5 16-case narrow를 재실행했다. 16승·실패 0, 각 52턴·17,171틱, 총 274,736틱, forced settle 0으로 PASS했다.
- P1-5 256-case batch를 4 workers로 완료했다. 256승·실패 0, 각 52턴·17,171틱, 총 4,395,776틱, terminal hash 1종, forced settle 0으로 PASS했다. 결과 CSV는 `.gitignore` 대상 `pipeline/artifacts/p1_batch/batch_256.csv`에 있다.

### 3.4 다음 작업 실행 명령

Windows PowerShell에서 먼저 `$env:PYTHONUTF8='1'`을 설정한다.

```powershell
# 빠른 씬/manifest 확인
python pipeline/scripts/play_test.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P1-5 결정론 회귀
python pipeline/tests/run_p1_batch_sim_graybox.py --mode narrow --jobs 4 --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
python pipeline/tests/run_p1_batch_sim_graybox.py --mode batch --jobs 4 --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
python pipeline/tests/run_p1_batch_sim_graybox.py --mode exhaustive --jobs 4 --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# 최종 통합 게이트
python pipeline/scripts/verify.py --full --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
```

## 4. 구현 우선순위

### P0 — 결정론적 시뮬레이션 코어

1. `FixMath`·`FixVec2`·`SimRng`
2. `SimBody`·`SimZone`·`SimWorld`
3. 원-원 충돌·마찰·벽 반사·소멸 영역
4. 상태 직렬화·해시·동일 시드 회귀 테스트

### P1 — 전투 루프

드래그 조준, 궤적선, CTB, 피해 공식, 트리거 버스, 승패 판정, 배치 시뮬 러너를 구현한다. 실제 아트 없이 플레이스홀더로 전투 감각을 검증한다.

### P2 이후

데이터 주도 콘텐츠 기반 → 적 AI → 런 루프 → 아트·사운드 폴리시 → 배치 시뮬 기반 밸런싱 순서로 진행한다. 세부 완료 조건은 설계 정본 17장을 따른다.

## 5. 구현 형태 가이드

- 기능 코드는 승인된 `docs/specs/*.md` 범위 안에서만 작성한다.
- 핵심 로직은 `src/core/`, 런타임 데이터는 `src/core/data/`에 둔다.
- AI가 명세·구현·검토를 돕고, JSON 검증·이미지 후처리·오디오 정규화 같은 기계 작업은 `pipeline/scripts/`가 담당한다.
- 매니페스트 읽기·쓰기는 `pipeline/scripts/manifest.py`를 거친다.
- `pipeline/tests/run_*.py` 자동 발견 규칙을 이용해 게임 전용 회귀 러너를 추가한다.

## 6. 프로젝트 정책

1. **이미지 생성**: 전투 감각이 확정되기 전에는 실행하지 않는다. 이후 컨셉 승인과 스타일 잠금을 거쳐 생성한다.
2. **사운드 생성**: P0·P1 완료 후 착수한다. ElevenLabs SFX와 jsfxr를 이벤트 성격에 따라 선택한다.
3. **장르·스타일 분리**: 로그라이트·픽셀아트 관련 값은 설계 문서·스타일 가이드·매니페스트 데이터로 표현하고 범용 파이프라인 스크립트에 하드코딩하지 않는다.
4. **결정론 우선**: 모든 시뮬레이션 순회 순서, RNG 소비 순서, 입력 양자화와 고정 스텝을 명시적으로 고정한다.
5. **데이터 주도 범위**: 기존 트리거와 효과 원자로 표현 가능한 콘텐츠는 코드 수정 없이 추가한다. 새로운 원자가 필요한 콘텐츠는 코어 확장 명세를 먼저 승인한다.
6. **승인 결정 재검토**: 새 증거·구현 제약·더 나은 구조가 드러나면 기존 승인에 매몰되지 않고 변경안과 영향·전환 비용·회귀 범위를 제시한다. 사람의 재승인 전에는 승인 결정을 조용히 바꾸지 않는다.

## 7. 작업 환경 준비 체크리스트

- [x] Godot 4.6.3 headless 실행 확인
- [x] Python 설치 확인
- [x] Node/npm 설치 확인
- [ ] ffmpeg/ffprobe 설치
- [ ] Scenario 계정과 API 키 준비 — 아트 단계에서만 필요
- [ ] ElevenLabs API 키 준비 — 사운드 단계에서만 필요
- [ ] API 키는 `.env`로 관리하고 저장소에 커밋하지 않기
