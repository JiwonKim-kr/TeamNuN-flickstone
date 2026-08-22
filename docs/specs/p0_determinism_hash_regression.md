# P0-4 · 상태 해시 / 결정론 회귀

| 항목 | 값 |
|---|---|
| status | **approved** |
| approved | 2026-08-18 · 사용자 승인 |
| phase | P0 · 결정론적 시뮬레이션 코어 |
| 선행 명세 | P0-1~3 승인·구현 |
| 후속 명세 | P1 전투 루프 명세 |

## 목적

월드 상태를 정규 순서와 고정 폭 바이트로 직렬화하고 안정된 해시를 계산해, 같은 시드와 입력이 반복 실행·삽입 순서 교란·지원 플랫폼 사이에서 완전히 같은 결과를 내는지 자동 검증한다. 버그 리포트와 향후 리플레이의 최소 재현 단위를 정의한다.

## 설계 정본 참조

- `docs/design/game_design.md` D-10, D-18, D-29~D-45
- 4.6 입력 양자화
- 12.2 AI 사본의 별도 RNG 스트림
- 14.1 결정론 원칙
- 14.4 리플레이
- 16장 결정론·관통·교착 테스트
- 17장 P0 완료 판정

## 범위

- 정규화된 `SimSnapshot`과 스키마 버전
- 플랫폼 독립 바이트 인코딩과 SHA-256 상태 해시
- P0용 시드·양자화 입력 시퀀스 포맷
- 골든 시나리오와 틱별 해시 픽스처
- 반복 실행·삽입 순서 교란·필드 민감도·복원 후 진행 회귀
- Linux·Windows 플랫폼 교차 회귀
- 실패 시 재현 가능한 최소 로그와 골든 갱신 절차

## 대상 파일

- `src/core/sim/sim_snapshot.gd`
- `src/core/sim/sim_state_hash.gd`
- `pipeline/tests/p0_determinism_test.gd`
- `pipeline/tests/run_p0_determinism.py`
- `pipeline/tests/fixtures/p0_scenarios.json`
- `pipeline/tests/fixtures/p0_golden_hashes.json`
- `.github/workflows/verify.yml`

## 확정된 결정

- 상태 해시는 표준 **SHA-256**이다.
- 입력은 정규 인코딩된 `SimSnapshot` 바이트 전체다.
- 내부 결과는 32바이트, 로그·골든 픽스처는 소문자 64자리 16진수다.
- 각 안정 틱 경계의 스냅샷을 독립 해시해 최초 불일치 틱을 식별한다. 이전 틱 해시를 다음 틱 입력에 연결하지 않는다.
- Godot 범용 `hash()`, Dictionary·String 런타임 해시를 사용하지 않는다.
- `src/core/sim`에는 순수 GDScript SHA-256을 두고 테스트 어댑터에서만 `HashingContext.HASH_SHA256`와 Python `hashlib.sha256`으로 교차 검증한다.
- 상태 해시는 회귀 검증 전용이며 게임 판정, RNG 시드·서브시드, 콘텐츠 ID에 재사용하지 않는다.

## 확정된 P0-4 계약

아래 내용은 D-45의 해시 규격과 함께 2026-08-18 사용자 승인으로 확정되었다.

### 1. 정규 바이트 인코딩

- 해시 입력은 ASCII 도메인 prefix `FLICKSIM\0` 9바이트, `snapshot_schema_version:uint16`, 아래 payload 순서로 구성한다. P0 버전은 `1`이다.
- 모든 다중 바이트 정수는 **little-endian 고정 폭**으로 기록한다. signed 값은 2의 보수, unsigned 값은 지정 범위를 검사한다.
- `bool`은 `uint8`의 `0` 또는 `1`만 허용한다. enum은 계약에 명시된 `uint16` 또는 `uint32` 폭을 사용한다.
- Q47.16 값은 변환된 문자열이나 소수가 아니라 저장 중인 raw `int64`를 기록한다. `FixVec2`는 `x:int64` 뒤 `y:int64` 순서다.
- 가변 목록은 `count:uint32` 뒤 요소를 기록한다. 정렬 정본이 있는 목록은 인코딩 전에 정렬하고 중복 키를 실패 처리한다.
- 패딩, 플랫폼 정렬, BOM, 줄바꿈, 로캘 변환은 없다.
- 문자열이 이후 스키마에 필요하면 `byte_length:uint32 + 유효한 UTF-8 바이트`로 기록하며 NUL 종단·BOM·해시 중 정규화를 하지 않는다. P0 v1 스냅샷에는 동적 문자열이 없다.
- float, Variant, Dictionary, Object 참조와 플랫폼 기본 `var_to_bytes()` 직렬화는 금지한다.
- 필드 추가·삭제·폭·순서·의미 변경은 스키마 버전을 올리고 골든을 다시 승인해야 한다. 알 수 없는 버전은 실패한다.

### 2. 안정 스냅샷 경계와 필드 순서

스냅샷은 최초 틱 전 또는 `SimWorld.step()`의 이동·충돌·소멸·이벤트 정산이 모두 끝난 틱 경계에서만 만든다. 서브스텝 도중이나 대기 중인 생성·제거 요청이 있으면 실패한다.

| 순서 | 구역 | 필드와 정렬 |
|---|---|---|
| 1 | 월드 | `tick:int64`, `root_seed:uint64`, 기본 마찰·정지 속도·반발계수 raw `int64`, `next_body_id:uint32`, `next_zone_id:uint32` |
| 2 | RNG 스트림 | count 뒤 `(purpose_id:uint16, owner_id:uint32, ordinal:uint32)` 오름차순. 각 스트림의 상태 4×`uint32`, 소비 횟수 `uint64` |
| 3 | 외곽 경계 | 존재 여부 `bool`, 존재 시 `boundary_type:uint16`, vertex count, 정점의 `FixVec2`를 저장 순서대로 기록 |
| 4 | 존 | count 뒤 `zone_id` 오름차순. `id:uint32`, `flags:uint32`, 마찰 raw `int64`, 가속도 `FixVec2`, vertex count와 정점 |
| 5 | 본체 | count 뒤 `body_id` 오름차순. `id:uint32`, `alive:bool`, `destructible:bool`, 위치·속도 `FixVec2`, 반지름·무게·마찰 배율 raw `int64` |
| 6 | 이벤트 큐 | `cursor:uint32`, `next_sequence:uint32`, count 뒤 sequence 오름차순. D-38의 모든 고정 필드를 선언된 순서로 기록 |

- `root_seed:uint64`는 코어 내부에서 상·하위 `uint32` 두 워드로 다루고 바이트 인코딩에서만 8바이트 little-endian으로 합친다.
- 외곽·존 정점은 검증된 시계 방향/저장 순서를 유지하며 해시 단계에서 회전·역순 정규화하지 않는다. 같은 도형의 입력 정규화는 로더 책임이다.
- 이벤트 큐는 소비 전후를 구분하기 위해 소비된 항목도 포함한 전체 큐, cursor, 다음 sequence를 모두 기록한다.
- v1에 열거하지 않은 미래 상태는 조용히 누락하지 않는다. 향후 계산 결과에 영향을 주는 필드가 생기면 스키마 버전을 올린다.

### 3. P0 입력·시나리오 포맷

- `p0_scenarios.json`은 `schema_version=1`, ASCII `scenario_id`, 16자리 소문자 hex 런 시드, 초기 월드, 정수 입력 목록, 실행 틱 수를 가진다.
- JSON은 사람이 읽는 픽스처일 뿐 해시 입력이 아니다. 물리 값은 모두 Q47.16 raw 정수이며 JSON float를 금지한다.
- 입력 레코드는 `tick:int64`, `sequence:uint32`, `body_id:uint32`, `angle:uint16`, `power_raw:int64` 순이며 `(tick, sequence)`가 엄격히 증가해야 한다.
- `power_raw`는 P0 테스트용 Q47.16 정규 파워 `0~65,536`이다. 입력은 해당 틱의 `step()` 직전에 적용한다.
- P0 테스트 어댑터만 `speed = power × 2,048`로 발사 속도를 만들며 무게 보정은 하지 않는다. 이는 입력 민감도 검사용 계약이고 P1의 최대 드래그·최소 파워·실제 발사 밸런스를 확정하지 않는다.
- 입력 `tick=0`은 초기 해시를 만든 다음 0→1 틱을 진행하기 직전에 적용한다.

### 4. 골든 시나리오

`Q(n)=n×65,536`이다. 표의 좌표·속도는 읽기 쉬운 논리 단위로 표기하고 JSON 픽스처에는 대응하는 Q47.16 raw 정수를 기록한다. 별도 표기가 없으면 seed=`0123456789abcdef`, 반지름 Q(32), 무게 Q(64), 기물 마찰 Q(1), `destructible=true`, 반발 19/20, 기본 마찰 3/2초⁻¹, 정지 속도 Q(1/2)를 쓴다 (PT-01~02 재승인). 공통 WALL 판은 화면 기준 시계 방향 `(-512,-512)→(512,-512)→(512,512)→(-512,512)`다.

| ID | 초기값·입력 | 실행 |
|---|---|---|
| `circle_head_on` | body 1 `pos=(-256,0)`, body 2 `pos=(256,0)`. tick 0에 body 1 `(angle=0, power=Q(1/2))`, body 2 `(angle=32768, power=Q(1/4))` | 240틱 |
| `circle_chain` | body 1/2/3 `pos=(-320,0),(-96,0),(128,0)`. tick 0에 body 1 `(angle=0, power=Q(1))` | 240틱 |
| `wall_corner` | body 1 `pos=(0,0)`. tick 0에 `(angle=8192, power=Q(1))`로 우하단 꼭짓점 동시 접촉 | 240틱 |
| `kill_boundary` | 공통 판을 KILL로 변경. body 1 `pos=(256,0)`. tick 0에 `(angle=0, power=Q(1/2))` | 120틱 |
| `kill_zone` | 공통 WALL 판, KILL zone 1 `(-64,-96)→(64,-96)→(64,96)→(-64,96)`. body 1 `pos=(-256,0)`. tick 0에 `(angle=0, power=Q(1/2))` | 120틱 |
| `substep_tunnel` | WALL 판 `(-1024,-512)→(1024,-512)→(1024,512)→(-1024,512)`. radius Q(8)인 body 1 `pos=(-512,0), vel=(4096,0)`, body 2 `pos=(0,0), vel=(0,0)` | 120틱, 최초 N=9 |

- 각 시나리오는 초기 tick 0과 매 진행 틱의 독립 SHA-256을 저장하므로 `step_hashes` 길이는 `실행 틱 수+1`이다.
- `circle_chain`은 같은 프로세스에서 1,000회 반복해 모든 틱 해시가 일치해야 한다.
- 각 시나리오는 기준 삽입 순서, 역순, 고정 permutation seed `5eed5eed00000004`로 만든 30개 순서를 합쳐 32개 삽입 변형을 검사한다.
- `circle_head_on`의 첫 입력에서 angle `+1`, power raw `+1`, tick `0→1`을 각각 단독 변경하면 기준과 다른 최종 해시가 나와야 한다.
- 스냅샷의 각 직렬화 필드를 하나씩 변경하는 민감도 테스트와 snapshot→restore→120틱 진행 비교를 별도로 수행한다.

### 5. 골든 해시 갱신 절차

- 일반 테스트와 CI는 픽스처를 절대 수정하지 않는다. 갱신은 명시적 `run_p0_determinism.py --update-goldens --approval-ref <승인 항목>`으로만 가능하다.
- 최초 생성의 승인 참조는 `P0-4`, 이후에는 먼저 승인된 설계 결정 번호 또는 명세 변경 참조를 요구한다. 빈 참조와 작업 트리의 미승인 임시값은 거부한다.
- 갱신 명령은 시나리오별 최초 변경 틱, 이전·새 최종 해시, 변경된 틱 수를 출력한다. 코드·명세·시나리오·골든 변경은 같은 리뷰 단위에 둔다.
- 골든만 바꿔 실패를 없애는 변경은 허용하지 않는다. 리뷰에는 계약 변경 이유와 출력된 전후 해시를 남긴다.
- CI에는 갱신 플래그나 자동 커밋 경로를 두지 않는다. 체크인된 골든과 새 실행 결과가 다르면 항상 실패한다.

### 6. CI 구성

- 기존 Ubuntu `verify` job은 `verify --full`을 통해 P0-4 러너와 체크인된 골든을 검사한다.
- 기존 job을 OS matrix로 바꾸지 않고, 의존성이 작은 별도 `determinism-windows` job을 `windows-latest`에 추가한다.
- Windows job은 checkout, Python 3.12, Godot 4.6.3만 준비하고 `run_p0_determinism.py`를 직접 실행한다. Node·ffmpeg·시각 테스트는 설치하지 않는다.
- 두 OS는 동일한 `p0_golden_hashes.json`과 순수 GDScript SHA-256 결과를 비교한다. Python 참조 해시도 각 job에서 검사한다.
- 실패 시 콘솔에 scenario ID, seed, Godot·OS, 최초 불일치 tick, 기대·실제 해시를 출력하고 최소 재현 JSON과 실제 snapshot bytes를 `pipeline/artifacts/determinism_failure/`에 남긴다.

## 수용 기준

1. SHA-256 구현은 공개 표준 벡터, Godot `HashingContext`, Python `hashlib`와 모두 일치한다.
2. 스냅샷은 Dictionary 순회·로캘·줄바꿈·JSON 키 순서·플랫폼 기본 직렬화에 의존하지 않는다.
3. 모든 정수 폭·엔디언·bool·목록 count·필드 순서가 v1 계약과 일치하며 범위 밖 값과 알 수 없는 버전을 실패 처리한다.
4. `circle_chain`을 1,000회 실행한 모든 틱 해시가 일치한다.
5. 여섯 골든 시나리오의 기준·역순·고정 30개 permutation이 모두 같은 틱별 해시를 낸다.
6. 입력 angle·power·tick의 단일 변경은 기준과 다른 최종 해시를 낸다.
7. 각 P0 상태 필드 민감도 검사에서 단일 필드 변경이 해시 입력과 결과에 반영된다.
8. snapshot→restore의 정규 바이트가 원본과 같고 양쪽을 120틱 더 진행한 틱별 해시도 같다.
9. 골든 불일치는 scenario ID, seed, 최초 불일치 tick, 기대·실제 해시와 재현 파일을 남긴다.
10. `run_p0_determinism.py`가 `verify --full`에서 자동 발견된다.
11. Ubuntu 전체 verify와 별도 Windows 결정론 job이 동일한 골든을 통과한다.
12. 골든 갱신은 명시적 플래그·승인 참조·전후 요약 없이는 실행되지 않으며 CI에서 갱신할 수 없다.

## 승인 결과

- 정규 인코딩, 스냅샷 필드, 입력 포맷, 여섯 골든 시나리오, 갱신 절차, 별도 Windows CI job을 한 묶음으로 승인했다.
- 승인된 대상 파일과 수용 기준 범위에서 P0-4를 구현하고 최초 골든 해시를 생성할 수 있다.

## 범위 밖

- 전체 런 리플레이 파일과 버전 마이그레이션
- 네트워크 동기화와 비동기 PvP
- AI 탐색 결과 검증
- 피해·CTB·능력·런 상태 해시
- P1 실제 드래그 거리·최소 파워·무게 보정 발사 공식

## 필요 에셋

없음.
