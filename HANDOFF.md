# HANDOFF — Flickstone 프로젝트 인수 문서

> 최종 갱신: 2026-08-24
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
| 현재 단계 | **P3 전투 수직 슬라이스 사람 검수 완료 — P4 제출용 Web 프리뷰 구축** |
| 물리 | Godot 내장 물리 미사용. 고정소수점 기반 자체 결정론 시뮬레이션 |
| 고정소수점 | `int64` + 소수부 16비트 (`FIX_SCALE=65,536`, Q47.16), 위치 안전 범위 ±8,192 |
| 물리 안전 범위 | 속도 ≤ 4,096, 초기 발사 ≤ 2,048, 무게 1~256, 임펄스 ≤ 2,097,152. 범위 밖 데이터는 로드·테스트 실패 |
| 고정 각도 | 한 바퀴 65,536, `0=+X`, 시계 방향. 사분면 4,096구간·4,097개 Q47.16 LUT와 선형 보간 |
| PRNG | `xoshiro128**` 4×uint32, 64비트 런 시드, 키 기반 비소비 서브스트림, rejection sampling. U-23 승인 전에는 단일값 범위·0%·100% 호출을 거부 |
| 반올림 | 최근접, 절반은 0에서 먼 방향. 암묵적 절삭·포화·조용한 clamp 금지, 오류는 실패 처리 |
| 고정 스텝 | 120Hz, 정확한 유리수 `1/120`, 시간·입력은 정수 틱, 권위 시뮬레이션 틱 폐기 금지 |
| P0 이동 감쇠 | 기본 마찰 3/2초⁻¹, 기본 배율 1, 정지 임계 1/2. 외부 가속도가 없는 틱에서만 정지 처리 |
| 존 중첩 | `zone_id` 오름차순, 마찰 배율은 순서 곱, 가속도는 순서 합. P0 override 없음, 안전 범위 초과 실패 |
| 시뮬레이션 ID | body·zone 별도 uint32, 0 무효, 월드별 단조 증가·비재사용, 안정 정렬 후 할당, 복제 시 카운터 보존 |
| SimEvent | 정수 공통 헤더·관계 ID·고정 payload, 불변 append-only 큐, sequence/cursor 정본, 동적 payload 금지 |
| 소멸 진입 | 기물 중심점 기준, 경계선 위 안전, 서브스텝 선분 검사와 최초 교차 사용 |
| P0 폴리곤 | 외곽은 시계 방향 단순 볼록 3~64정점, 내부 존은 단순 오목 허용, 비정상 데이터 로드 실패 |
| 벽 모서리 | 관입 깊이↓·edge index↑로 전 접촉 처리, 꼭짓점 전용 법선, 재검사 64회 미해소 시 실패 |
| P0 충돌값 | 반발 19/20, 반지름 8~128(기본 32), 무게 1~256(기본 64), 시험 속도 512/1,024/1,536/2,048/4,096 |
| 서브스텝 | 월드 공통 이동량/(최소 반지름/2), 1~16, 위치만 유리수 분할, 초과 시 이동 전 실패 |
| destructible | P0부터 저장·해시, 일반 파괴만 확인, 소멸은 무시, BODY_DESTROYED 공통·cause만 구분, 관리 제거 별도 |
| P0 상태 해시 | 정규 SimSnapshot 바이트의 SHA-256, 내부 32바이트·외부 소문자 64 hex, 게임 판정·RNG 재사용 금지 |
| 콘텐츠 | 지원하는 트리거·효과 원자의 조합은 데이터로 정의 |
| 작업 흐름 | `play spec` 승인 → `play build` → `play test` → `verify` → `review` |
| 승인 지점 | play spec 승인 / art lock / review — **생략 불가** |
| 에셋 정책 | P0·P1은 매니페스트에 등록한 플레이스홀더만 사용 |
| 아트·사운드 시작 | 전투 감각 승인 완료. `art lock`, `art gen`, SE는 별도 요청·승인 절차로 시작 |
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
- [x] PT-01~04 물리 감각 조정 승인·구현 — 마찰 3/2, 반발 19/20, 기준 최대 발사 속도 1,536
- [x] P1-5 fixture v2 16/256/1,000 배치 — 전승·실패 0·forced settle 0·terminal hash 일치
- [x] P1-5 회색상자 사람 수동 감각 검수 — 조준·첫 타격·충돌·반사·피해·턴 길이 “문제 없음” 승인
- [x] Godot 4.6.3 활성 `verify --full` — 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 러너 17종 PASS
- [x] P2 전체 인덱스 P2-A01~11 및 P2-1 상세 P2-C01~12 승인
- [x] P2-1 strict JSON·안정 ID·typed immutable catalog·atomic `DataDB`·SHA-256 fingerprint 구현
- [x] P2-1 독립 Python 기준 3종·Godot 4.6.3 narrow 23개 그룹·1,000회 반복 통과
- [x] P2-1 반영 Godot 활성 `verify --full` — 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 러너 18종 PASS
- [x] P2-2 효과 실행 상세 명세 초안 작성 (`docs/specs/p2_effect_resolution.md`)
- [x] P2-2 P2-E01~12 사람 승인 (`docs/specs/p2_effect_resolution.md`)
- [x] P2-2 schema v2·typed condition/selector/effect·binding registry·6개 기초 원자·transition rollback·BattleSnapshot v4 구현
- [x] P2-2 독립 Python KAT와 Godot narrow(원자성·지문 불일치·v4 복원), P2-1/P1 회귀 통과
- [x] P2-E11 승인 참조로 P1-5 terminal golden을 snapshot v4 hash로 이관 — 결과·20턴·10,699틱 불변
- [x] P2-2 반영 Godot 활성 `verify --full` — 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 러너 19종 PASS
- [x] P2-2 DAMAGE hit 사실의 다음 wave 처리와 append-only trigger/effect sequence 구현
- [x] P2-2 condition/selector 전 어휘, wave 32·record 4,096·invocation 2,048·application 8,192 경계/초과 rollback 검증
- [x] P2-2 동일 fixture 1,000회와 BattleSnapshot v4 복원·재인코딩 결정성 검증
- [x] P2-2 실제 살아 있는 body 256/257개를 사용한 selector 결과 경계·초과 fixture 통과
- [x] P2-3 catalog v3·pieces v2·abilities v3·statuses/synergies v1과 canonical fingerprint v3 구현
- [x] P2-3 상태 수명·시너지 tally·modifier 집계·CTB/피해/물리 연결·세 원자·BattleSnapshot v5 구현
- [x] P2-3 body 64·전투 4,096·transition 1,024 경계/초과 rollback과 동일 fixture 1,000회 검증
- [x] P2-S18 근거로 P1-5 terminal snapshot 골든을 v5로 이관. 결과·턴 수·sim tick은 불변
- [x] P2-3 반영 Godot 4.6.3 `verify --full` — 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 러너 20종 PASS
- [x] P2-4 동적 기물 P2-D01~27과 선택 항목 3건 승인 (`docs/specs/p2_dynamic_piece_mechanics.md`)
- [x] P2-4 catalog v4·pieces v3·abilities v4, spawn/projectile/transform/attach typed payload와 canonical fingerprint v4 구현
- [x] P2-4 runtime token·진영·수명, deterministic `SimLink` solver, 링크 충돌 예외, 변신 승계, 원본 piece 결과 보고 구현
- [x] P2-4 `BattleSnapshot` v6·`SimSnapshot` v2 단일 링크 정본, transition rollback과 링크 64·body별 8 한도 구현
- [x] P2-D26 근거로 P0 SimSnapshot v2와 P1-5 BattleSnapshot v6 골든 이관 — 전투 결과·20턴·10,699틱 불변
- [x] P2-4 독립 Python schema/fingerprint와 Godot narrow 29개 그룹, 동일 fixture 1,000회 복원 결정론 통과
- [x] P2-4 반영 Godot 4.6.3 `verify --full` — 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 러너 21종 PASS
- [x] P2-5 maps/enemies v1·catalog/abilities/fingerprint v5, 맵 기하·슬롯 안전 검사와 enemy override 구현
- [x] P2-5 `BattleSetupBuilder`, 결정론적 초기 body/zone ID, `SPAWN_ZONE` 수명·rollback, BattleSnapshot v7 구현
- [x] P2-5 독립 Python KAT와 Godot narrow 18개 그룹·1,000회 결정론, P1-5 v7 terminal golden 이관 완료
- [x] P2-5 반영 Godot 4.6.3 `verify --full` — 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 러너 22종 PASS
- [x] P2-6 최초 non-empty runtime 콘텐츠와 generic 세로 회색상자 구현 — core GDScript 변경 0개
- [x] P2-6 독립 Python·Godot 16개 기능 그룹·1,000회 제한 반복·16×2 terminal/snapshot 골든 통과
- [x] P2-6 반영 Godot 4.6.3 quick `verify --full` — 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 러너 23종 PASS
- [x] P2-6 회색상자 사람 검수 — 능력/상태/시너지/적 재사용/KILL 표시·판정과 플레이테스트 보정 반영본 승인
- [x] P3-A01~18 승인 뒤 전체 행동 복제 평가의 단일 후보 12.2초 병목 계측·충돌 기록
- [x] P3-H01~06 하이브리드 대체안 승인 및 직접/1회 벽 반사 후보·정수 휴리스틱·등급 오차 구현
- [x] enemies v2·catalog/fingerprint v6 이관, runtime 적 3종 COMMON 배정, 독립 Python 기준 검증 통과
- [x] Godot 활성 P2/P3 narrow와 quick `verify --full`, P2-6 terminal 32행 골든 재생성
- [x] 현재 runtime COMMON 적 AI의 조준·행동 사람 플레이 검수 — 사용자 확인 완료
- [x] 사용자 재승인에 따라 `vmax <= 20`에서 현재 위치 즉시 정지 후 TURN_END로 전환하는 권위 RESOLVE 컷오프 구현
- [x] P1 컷오프 경계 narrow 19개와 Godot import·main scene smoke·manifest 통과
- [x] 권위 종단값 변경에 따른 P1 narrow 16과 P2 terminal 16×2 골든 이관 — 승인 참조 `P1-vmax20-cutoff-2026-08-24`, P3 AI narrow 통과
- [x] 저속 즉시 정산의 턴 템포 사람 검수 — `vmax <= 20` 전환 사용자 확인 완료
- [x] 플레이어 발사 직후 prediction worker 중첩 완화 — P1/P2 worker `PRIORITY_LOW`, 발사 handler non-join, stale 결과 무효화 유지
- [x] P4 제출용 Web 프리뷰 WP-01~08 승인, single-thread Web preset·로컬 export·Pages workflow 구현
- [x] Neo둥근모 v1.601 번들 폰트와 OFL 라이선스 적용, HUD 한글 glyph coverage 통과
- [x] Godot 4.6.3 release Web export와 640×1,024 브라우저 첫 화면 렌더링 확인
- [ ] GitHub Pages 첫 공개 배포와 공개 URL 직접 진입 확인

### 3.1 P1-2 현재 작업 기록

구현된 코어:

- `LaunchLimits`: 승인된 각도·파워·속도·예측 상수
- `LaunchCommand`: `schema_version:uint16 + angle:uint16 + power_step:uint16` little-endian codec
- `AimQuantizer`: 256개 LUT 방향 후보의 정수 내적 비교, 256단계 파워 양자화
- `LaunchVelocitySolver`: 기준 속도 1,536, 절대상한 2,048, `sqrt(64 / mass)` 보정
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

완료 판정:

1. 세로 회색상자에서 드래그·예상 궤적·첫 타격·충돌·반사·피해·턴 길이 사람 검수를 통과했다.
2. fixture v2 16/256/1,000 배치가 실패·교착·강제 정산 없이 끝났다.
3. 현재 변경 기준 Godot 활성 `verify --full`이 통과했다.
4. P1 전체 완료 조건을 충족했으며 다음 구현 단계는 P2 콘텐츠 기반 또는 P3 AI다.

### 3.3 P1-5 성능·구현 진행 기록

- 최초 세로 3열 대형은 40턴까지 200초 이상, 생존 6·총 HP 309였고 단일 전투가 300초 제한을 넘었다.
- `SimWorld.step()` 실패 복구는 기존 불변 값 객체를 공유하는 얕은 배열 스냅샷으로 변경했다. 공개 `SimWorld.copy()`의 깊은 복제 계약은 유지한다.
- `BattleState.advance_resolve()`도 롤백 전용 구조 스냅샷과 내부 transaction world copy를 사용한다. 권위 상태에 대한 공개 깊은 복제·snapshot schema는 바꾸지 않는다.
- P0 SimWorld 원자성·깊은 복제, P0 충돌 원자성·결정론, P1 CTB phase rollback, P1 피해·파괴 rollback·snapshot continuation이 최적화 뒤 통과했다.
- 승인 문서에 초기 좌표가 지정되지 않았으므로 전장·3대3·스탯·power를 유지한 중앙 근접 대칭 대형을 사용한다. 목적은 동일 물리에서 무충돌 이동 턴을 줄이는 것이다.
- PT-01~04 이전 v1 최적화·근접 대형 baseline은 52턴·17,171틱·123,480ms에 `PLAYER_VICTORY`로 끝났고 terminal hash는 `ea819aa9acc94f2cf115d7446fd05da76fbe396cadb8c1405715e5f5ff7b3df6`이었다.
- PT-01~04 이전 v1 시점의 Godot 활성 `verify --full`은 P0 1,000회 반복 도중 중단된 이력이 있었다. 현재 기준 전체 PASS 결과는 아래 v2 완료 기록으로 대체한다.
- P1-5 fixture schema v1 검증, RFC 4180 UTF-8 LF CSV writer, 승인 참조가 필요한 golden 갱신과 CI 갱신 거부를 구현했다.
- v1 기준·역순 삽입·10턴 snapshot round-trip 3개 case는 모두 52턴·17,171틱·동일 terminal hash로 PASS했다. 일반 실행의 체크인 golden 비교도 PASS했다.
- 초기 구현 증분은 3-case였으며, 아래 단계에서 승인된 narrow 16개와 집계·repro 경계로 확장했다.
- v1의 3-case 증분을 16-case narrow로 확장했다. 4 workers 실행에서 16승, 각 52턴·17,171틱·동일 terminal hash, 총 274,736틱, forced settle 0으로 PASS했다.
- observer 집계는 기준 case에서 player damage 293, enemy damage 300, damage 파괴 5, 경계/존 파괴 0을 기록했고 observer 적용 전 terminal hash를 유지했다.
- 병렬 runner는 case ID 정렬, worker 1~16 제한, `--keep-going`, 실패 CSV 행, numeric code/operation과 저장소 상대 repro 경로를 지원한다.
- 승인 실행량 16/256/1,000은 `narrow`/`batch`/`exhaustive` 모드로 확장되며 실제 세 모드 실행을 모두 완료했다.
- `placeholder_gen.py`로 아군 P·적군 E·조준 `>` PNG를 만들고 `manifest.py add`로 3개 entry를 등록했다. 전장 바닥·벽은 승인대로 `Polygon2D`/`Line2D`만 사용한다.
- `scenes/p1_graybox_battle.tscn`과 `src/ui/battle/p1_graybox_battle.gd`를 추가하고 메인 씬에 연결했다. 3대3 진영, 현재 actor 강조, 아군 드래그 발사, 조준선·권위 예측 궤적, P1 전용 결정론 적 샷, 재시작을 제공한다.
- 씬 추가 뒤 Godot 4.6.3 headless import·main scene smoke·manifest 3-entry 정합성이 모두 PASS했다.
- v1 씬 추가 뒤 P1-5 16-case narrow를 재실행했다. 16승·실패 0, 각 52턴·17,171틱, 총 274,736틱, forced settle 0으로 PASS했다.
- v1 P1-5 256-case batch를 4 workers로 완료했다. 256승·실패 0, 각 52턴·17,171틱, 총 4,395,776틱, terminal hash 1종, forced settle 0으로 PASS했다. 이 값은 아래 v2 결과로 대체되었다.
- 수동 플레이 씬을 640×1,024 세로 전장으로 분리하고 enemy 위·player 아래에 3명씩 충분한 간격으로 배치했다. HUD 경로·입력 처리와 궤적 예측을 프레임 예산 기반 비동기 처리로 정리해 초기 정지와 드래그 렉을 해소했다.
- PT-01~04로 기본 마찰 5/2→3/2, 반발 17/20→19/20, 기준 최대 발사 속도 1,024→1,536을 적용하고 회귀 fixture를 `p1_graybox_v2`로 올렸다. 절대상한 2,048과 피해 기준속도 1,024는 유지했다.
- fixture v2 narrow 16은 16승·실패 0·총 171,184틱, batch 256은 256승·실패 0·총 2,738,944틱, exhaustive 1,000은 1,000승·실패 0·총 10,699,000틱이다. 전부 20턴·10,699틱, forced settle 0으로 일치했다. P2-E11 snapshot v4 이관 뒤 terminal hash는 `0afb130f4dff9ae87ef51cd19c26ccdc15fc4c29444d4c2393deb4f255079574`다(이전 v3 hash `ba0a6c315abbb4502400ed3ab473bf0e1cac0eaa57d9b381142ba2f8cdda68a3`).
- P0 상태 해시 1,000회 반복과 Godot 4.6.3 활성 `verify --full`을 완료했다. 게이트 #1~4 PASS, lore canon 미초기화 #5 정상 SKIP, 자동 발견 러너 17종 PASS다. Windows에서는 `-X utf8`이 아니라 하위 프로세스에 전파되는 `$env:PYTHONUTF8='1'`을 사용해야 한다.
- 사용자가 세로 회색상자를 직접 플레이하고 발사·반사·충돌·피해 반응에 “문제 없음”으로 전투 감각을 승인했다.

### 3.4 P2-1 콘텐츠 카탈로그 구현 기록

- 권위 JSON은 Godot `JSON.parse()`가 아니라 프로젝트 소유 strict parser가 처리한다. UTF-8/BOM, duplicate key, trailing comma, raw control, decimal/exponent, int64 overflow와 공학 한도를 로드 단계에서 거부한다.
- `catalog.json`, `id_registry.json`, `pieces.json`, `abilities.json` 네 파일만 허용한다. 현재 runtime piece/ability record는 승인대로 0개다.
- `ContentCatalogBuilder`는 registry의 숫자/문자열 ID 쌍, active/retired 상태, P1 trigger와 P0/P1 수치 범위, piece→ability 참조를 검증하고 숫자 ID 순서의 불변 사본만 공개한다.
- `DataDB`는 전체 parse/build/fingerprint 성공 뒤에만 catalog 참조를 교체한다. 실패 reload 뒤 직전 catalog와 fingerprint가 유지되는 회귀를 통과했다.
- schema v2 fingerprint KAT는 runtime empty `9b652d19da0c1d2f93497ca815be2a6829ebbf940a0a4f2acc121a5caafa3384`, fixture A `c1e5fd5197611ede7d7e3061bc112f466a0faf0a4203a94a04994dca7149f415`, authoritative-change B `57cdae1e59c301efea2c3ad69ae4876c015d1233623754eec914b1fa7330d059`이다.
- P2-1 narrow와 기존 P0/P1 전체 회귀가 통과했다. P2-E01~12 승인 뒤 P2-2 핵심 구현과 첫 통합 검증까지 완료했다.

### 3.5 P2-2 효과 실행 구현 기록

- ability/catalog schema v2와 독립 Python canonical reference를 추가하고 P2-1 fixture/runtime empty catalog를 명시적으로 v2로 이관했다.
- immutable binding registry, typed condition·selector·effect 정의와 6개 원자(`DAMAGE`, `HEAL`, `KNOCKBACK`, `PULL`, `MODIFY_CT`, `MODIFY_VELOCITY`)를 copy-on-write resolver로 구현했다.
- 중복 binding, 잘못된 trigger, 콘텐츠 지문 불일치에서 원본 상태가 바뀌지 않는 rollback 회귀와 BattleSnapshot v1 호환/v4 재인코딩 회귀를 통과했다.
- runtime piece/ability records, scene, asset, manifest는 변경하지 않았다.
- effect가 만든 hit 사실의 next-wave drain, condition/selector 전 어휘, wave/record/invocation/application 경계·초과 rollback과 1,000회 resolver/snapshot 반복을 명시적 수용 테스트로 고정했다.
- 실제 1 아군 + 256/257 적군 상태를 구성해 selector 결과 256 성공과 257 초과 실패를 직접 검증했다. P2-2 승인 수용 범위는 완료되었다.
- P2-3 승인 범위 구현이 완료되었다. runtime piece/ability/status/synergy records는 후속 콘텐츠 승인 전까지 계속 비어 있다.

### 3.6 P2-3 상태·시너지·modifier 구현 기록

- catalog v3는 6개 strict JSON 문서와 append-only ID registry를 원자적으로 로드하며, 독립 Python과 Godot canonical bytes/fingerprint가 일치한다.
- 상태는 정렬된 불변 인스턴스로 보관한다. `SINGLE`/`STACKED`/`INDEPENDENT`, 네 refresh 정책, source 병합, `TARGET_TURNS`/`BATTLE`/`CHARGES`, 네 해제 경로를 구현했다.
- 시너지 tally는 비토큰 초기 배치에서 진영별로 동결하며, 토큰은 계수에서 제외하되 효과는 받는다. `BOTH_FACTIONS`, 누적 tier, count cap을 fixture로 검증했다.
- 유효값은 ADD 합산 뒤 RATIO bp를 한 번 반올림한다. CTB는 사본의 유효 speed를 사용하고, 물리 3종은 `AIM→RESOLVE`에서만 materialize한다.
- 피해 경로는 유효 공격·치명타·비율·고정 modifier를 P1 `DamageContext`에 연결한다. 치명타는 `(purpose=2, attacker body ID, collision sequence)` 비소비 서브스트림으로 판정한다.
- `APPLY_STATUS`·`REMOVE_STATUS`·`MODIFY_STAT`, 상태 변경 리포트, transition rollback, Snapshot v5와 fingerprint mismatch 복원을 구현했다.
- P2-3 narrow, P2-1/P2-2, P0/P1 회귀와 Godot 4.6.3 `verify --full` 자동 발견 러너 20종이 통과했다.

### 3.7 P2-4 동적 기물 구현 기록

- `SPAWN_PIECE`·`SPAWN_PROJECTILE`·`TRANSFORM_PIECE`·`ATTACH`를 exact-key typed payload로 추가했다. 생성 body는 token·level 1이며 piece metadata에 따라 owner 또는 neutral 진영을 사용한다.
- `NONE`·`AFTER_TURNS`·`AFTER_COLLISIONS`·`ON_LINK_RELEASE` 수명과 최초 링크 epoch를 구현했다. expire 제거는 사망 trigger를 만들지 않는다.
- `SimLink`는 링크 ID 순서로 anchor point와 surface-follow를 해결하고, 링크 쌍 충돌을 제외한다. 역질량 겹침 보정과 solver 뒤 속도 역산도 고정소수점·안정 정렬로 처리한다.
- 변신은 body ID·진영·위치·속도·상태·링크를 유지하며 HP 비율과 CT를 환산한다. level 1 binding은 다음 public transition부터 적용하고 원본 piece ID는 immutable battle result report에 남긴다.
- 링크와 `next_link_id`는 `SimSnapshot` v2만 소유하고 `BattleSnapshot` v6은 이를 한 번만 포함한다. 생성·변신·부착 실패는 공개 transition 전체를 원자적으로 롤백한다.
- fixture catalog fingerprint는 `68af8d2f3d1c0abd46a372a2fb5da632c0650da95d31bd5b7ed7e1b427dd8742`다. 29개 grouped check와 snapshot restore 1,000회가 통과했다.
- P2-D26 승인 참조로 P0 상태 골든과 P1-5 terminal 골든을 새 snapshot schema로 이관했다. P1-5 결과·20턴·10,699틱은 유지되며 terminal hash는 `66f52e03a8f825e93ccf9787ac959cd4f1c99d625fe88a0858f0c9f11c7bde49`다.
- runtime piece/ability records는 실제 콘텐츠 승인 전까지 비어 있으며 fixture에만 동적 기물 수치를 둔다.

### 3.8 P2-5 맵·적·환경 구현 기록

- maps v1·enemies v1을 strict catalog v5에 편입하고 MAP/ENEMY registry, canonical fingerprint v5, 카탈로그 최대 반지름 기반 맵·슬롯 검증을 구현했다.
- 적은 non-token base piece level 1을 참조하고 whitelist override만 적용한다. `BattleSetupBuilder`는 배치를 진영·슬롯 순으로 정규화해 초기 존과 player → enemy body ID를 결정론적으로 배정한다.
- `SPAWN_ZONE`은 대상 로컬 좌표 합성, transition당 16·전투당 32·총 64존 한도, 설치 턴 제외 수명과 영구 존, 전체 rollback을 지원한다.
- `BattleSnapshot` v7이 설치 존 ID·남은 턴·설치 턴을 저장한다. v1~6은 빈 설치 존으로 복원하고 v7로 다시 캡처한다.
- fixture fingerprint는 `880b30f660e8355d7ff56bb8aa7ad64bef6fb726409f7f175725aa179b0edcea`다. runtime maps/enemies records는 비어 있으며 정적 장애물은 U-03 승인 전까지 거부한다.
- P1-5 terminal 결과·20턴·10,699틱은 유지되며 v7 terminal hash는 `8e822066ae3c4b2fb9ad817cf543db4e8e0f7a7eb4e14018cb99f971b935c0ac`다.

### 3.9 P2-6 콘텐츠 회색상자 구현 기록

- runtime catalog에 `baduk_stone`, `bottle_cap`, P4 명시적 풀 전용 `graybox_striker`, 능력·상태 각 1종, 시너지 2종, 적 3종, KILL 존 맵 1종을 등록했다. canonical fingerprint는 `f721ffce47ff27324a92dd8c9564e75463113fd5adb10ee7ebb388889511cf0e`다.
- `P2ContentBattleDriver`는 `BattleState`의 각 public transition 직후 기존 `EffectResolver`를 호출하는 generic 합성 경계다. `src/core/**/*.gd`를 바꾸거나 콘텐츠 문자열 ID별 동작을 넣지 않았다.
- `p2_content_graybox.tscn`은 map JSON의 WALL·3+3 슬롯·KILL 존을 세로 화면에 표시하고, player 슬롯 기물 순환·drag launch·비동기 궤적·enemy deterministic shot·상태/시너지/CTB 표시를 제공한다.
- 기존 P1 placeholder 3종만 재사용했고 P2 `requested_by`는 `manifest.py add-requested-by`로 등록했다. 신규 art/SE 파일은 없다.
- 기본 검증 프로필은 두 프리셋 seed 0과 snapshot 복원만 실행한다. `--profile milestone`은 기본·stacked 각 16시드 전체와 체크인 골든 32행을 검사한다.
- 마일스톤에서 기본 프리셋은 전 시드 적 승리·5턴·1,644틱, stacked는 전 시드 적 승리·16턴·7,794틱이었다. 1,000회 3-transition 결정론과 중간 snapshot 복원도 일치했다.
- 사용자가 플레이테스트 보정 반영본을 직접 실행해 사람 검수 시나리오 1~7, 중심선 궤적 표시, 적 발사 최소 지연, RESOLVE 안전 표시, 좌측 HUD 배치를 승인했다. P2-6 및 P2 단계 완료 조건을 모두 충족했다.

### 3.10 P3 하이브리드 적 AI 구현 기록

- 최초 승인안의 후보별 P2 전체 행동 복제는 단일 후보가 약 12,203ms여서 500ms 상한과 양립하지 않았다. 사용자가 승인한 P3-H01~06에 따라 직접 조준과 외곽 벽 1회 bank 후보를 정수 기하 휴리스틱으로 평가하고, 실제 피해·승패는 기존 P0~P2 권위 시뮬레이션이 계속 판정한다.
- COMMON/ELITE/BOSS는 같은 원시 후보·평가식을 사용하고 `AI_SHOT_ERROR=3` 파생 RNG의 각도/파워 오차만 달라진다. 안전 가드는 위험한 오차를 세 번 축소한 뒤 최상 안전 후보로 복귀한다.
- `enemies.json` v2의 필수 `ai_grade_id`, catalog/fingerprint v6을 도입했다. 현재 runtime 적 3종은 COMMON이며 fingerprint는 `89340a848cea8b0ec2b688243a16945bb6e071d6f28e9948e6cefe04e0d011f3`이다.
- 독립 Python schema/fingerprint/등급 계약, Godot P3 narrow, P2-6 1,000회·16×2 terminal/snapshot 골든 이관, Godot 4.6.3 quick `verify --full`이 통과했다. 로컬 headless 선택은 약 302~336ms였다. 남은 P3 완료 조건은 COMMON/ELITE/BOSS 행동에 대한 사람 플레이 검수다.

### 3.11 다음 작업 실행 명령

Windows PowerShell에서 먼저 `$env:PYTHONUTF8='1'`을 설정한다.

```powershell
# MVP 단위 작업용 quick 통합 — P0 반복만 20회·순열 3회로 축소
$env:P0_ALLOW_QUICK='1'
$env:P0_REPEAT_COUNT='20'
$env:P0_PERMUTATION_COUNT='3'
python pipeline/scripts/verify.py --full --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
Remove-Item Env:P0_ALLOW_QUICK,Env:P0_REPEAT_COUNT,Env:P0_PERMUTATION_COUNT

# 빠른 씬/manifest 확인
python pipeline/scripts/play_test.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P2-1 콘텐츠 카탈로그 narrow
python pipeline/tests/run_p2_content_catalog.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P2-3 상태·시너지·modifier narrow
python pipeline/tests/run_p2_status_synergy_modifiers.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P2-4 동적 기물 narrow
python pipeline/tests/run_p2_dynamic_piece_mechanics.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P2-5 맵·적·환경 narrow
python pipeline/tests/run_p2_maps_enemies_environment.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P2-6 콘텐츠 회색상자 narrow (일상 quick / 단계 종료 milestone)
python pipeline/tests/run_p2_content_graybox.py --profile quick --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
python pipeline/tests/run_p2_content_graybox.py --profile milestone --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P3 하이브리드 적 AI narrow
python pipeline/tests/run_p3_ai_shot_selection.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# P1-5 결정론 회귀
python pipeline/tests/run_p1_batch_sim_graybox.py --mode narrow --jobs 4 --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
python pipeline/tests/run_p1_batch_sim_graybox.py --mode batch --jobs 4 --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
python pipeline/tests/run_p1_batch_sim_graybox.py --mode exhaustive --jobs 4 --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe

# 최종 통합 게이트
python pipeline/scripts/verify.py --full --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
```

단위 작업에서는 영향받은 narrow 뒤 quick 통합을 사용한다. P0 골든 갱신·단계 종료·릴리스·CI에서는 quick 환경변수를 제거하고 1,000회 정밀 게이트를 유지한다.

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
