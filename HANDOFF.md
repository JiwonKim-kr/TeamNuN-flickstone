# HANDOFF — Flickstone 프로젝트 인수 문서

> 최종 갱신: 2026-08-20
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
| 현재 단계 | **P1-2 발사/조준 구현·narrow 회귀 완료 — `verify --full` 재개 대기** |
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
- [ ] P1-2 반영 상태의 `verify --full` 5게이트 — 장시간 실행 중 사용자 요청으로 중단, 다음 작업에서 재개

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

남은 작업:

1. `verify --full`을 Godot 4.6.3 활성 상태로 다시 실행한다.
2. 전체 5게이트가 통과하면 P1-2를 `implemented · verified`로 문서화한다.
3. `git diff --check`와 최종 변경 파일 목록을 확인하고 관련 없는 변경이 섞이지 않았는지 점검한다.
4. 사용자 검수 결과를 보고한다. 커밋은 사용자가 요청하거나 구현 결과를 승인한 경우에만 수행한다.
5. 다음 단계는 P1-3 피해 해결 명세 초안이다. U-32·U-33 피해 수치와 재충돌 규칙의 별도 승인이 필요하며 승인 전 구현하지 않는다.

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
