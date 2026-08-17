# P0-2 · SimWorld 상태와 고정 스텝

| 항목 | 값 |
|---|---|
| status | **approved** |
| approved | 2026-08-18 · 사용자 승인 |
| phase | P0 · 결정론적 시뮬레이션 코어 |
| 선행 명세 | `p0_fix_math_rng.md` 승인·구현 |
| 후속 명세 | `p0_collision_boundaries.md` |

## 목적

Godot 노드와 분리된 순수 데이터 세계에서 원형 기물의 위치·속도·마찰·지형 가속도를 고정 스텝으로 갱신한다. 복제 가능한 최소 시뮬레이션 상태를 만들어 AI 사본 실행과 회귀 테스트의 기반을 제공한다.

## 설계 정본 참조

- `docs/design/game_design.md` 4.2 기물의 물리 표현
- 4.3 이동과 마찰
- 4.8 `RESOLVE` 상태
- 8장 맵·환경 요소
- 12장 AI 사본 시뮬레이션
- 14.2 레이어 규칙, 14.3 디렉터리 구조

## 범위

- 안정된 정수 ID를 가진 `SimBody`
- 폴리곤과 효과 데이터를 가진 `SimZone`
- 본체·존·시드·현재 스텝을 소유하는 `SimWorld`
- 고정 스텝의 마찰, 지형 가속도, 위치 갱신, 정지 임계 처리
- ID 오름차순 처리와 깊은 복제
- P0용 최소 이벤트 큐 인터페이스

## 대상 파일

- `src/core/sim/sim_body.gd`
- `src/core/sim/sim_zone.gd`
- `src/core/sim/sim_event.gd`
- `src/core/sim/sim_world.gd`
- `pipeline/tests/p0_sim_world_test.gd`
- `pipeline/tests/run_p0_sim_world.py`

## 상태 계약

P0의 `SimBody`가 시뮬레이션에 저장하는 핵심 물리 상태는 `id`, `position`, `velocity`다. 반지름·무게·마찰 배율·생존 상태처럼 계산에 필요한 값은 정수 기반 설정으로 보유할 수 있으나 회전·스프라이트·Godot 노드 참조는 저장하지 않는다.

## 수용 기준

1. `SimBody`, `SimZone`, `SimEvent`, `SimWorld`는 `Node`를 상속하지 않고 Godot API를 호출하지 않는다.
2. 같은 본체들을 다른 삽입 순서로 추가해도 각 스텝은 ID 오름차순으로 처리되어 최종 상태가 같다.
3. 매 고정 스텝은 정본 4.3의 순서대로 유효 마찰 → 속도 감쇠 → 지형 가속도 → 위치 → 정지 임계를 적용한다.
4. 시뮬레이션 계산은 P0-1의 고정소수점·벡터 API만 사용한다.
5. 월드 복제본을 진행해도 원본의 본체·존·RNG·이벤트 큐가 변하지 않는다.
6. 중복 ID, 존재하지 않는 ID 제거, 유효하지 않은 반지름·무게를 명시적으로 거부한다.
7. 0개·1개·다수 본체와 존 중첩 상태를 headless 테스트로 검증한다.
8. 정지 임계 아래의 속도는 정확히 0이 되어 무한 미끄러짐을 만들지 않는다.
9. `run_p0_sim_world.py`가 `verify --full`에서 자동 발견되고 실패한 스텝과 본체 ID를 출력한다.
10. `SimEvent`는 고정 필드만 가진 불변 레코드이며 Dictionary·Variant·문자열 payload를 사용하지 않는다.
11. 이벤트 sequence·소비 cursor·다음 sequence가 월드 복제에서 보존되고 원본과 복제본의 소비 상태가 서로 영향을 주지 않는다.
12. type/cause enum 골든 테이블 검사로 기존 번호의 변경·재사용을 탐지한다.

## 확정된 결정

- 기본 시뮬레이션 120Hz
- `DT_NUM=1` / `DT_DEN=120`의 정확한 유리수
- 모든 시간·입력 시점은 정수 틱
- 권위 시뮬레이션 틱 폐기 금지. 렌더 accumulator와 보간은 시뮬레이션 밖에서 처리
- 기본 마찰 `5/2초⁻¹`, 기본 기물·지형 마찰 배율 1, 기본 틱당 감쇠율 `47/48`
- 정지 임계 `1/2 논리 단위/초`. 속도 제곱을 `1/4`과 비교하고 현재 틱 외부 가속도가 0일 때만 정지 처리
- 위 값은 P0 회색상자 초기값이며 이후 `balance.json`에서 조정
- 포함된 존을 `zone_id` 오름차순으로 정렬
- 마찰은 기본→기물→정렬된 존 배율 순서로 곱하고, 가속도는 같은 존 순서로 벡터 합산
- 마찰 배율 0 허용, P0 우선순위·override 미지원
- 최종 `유효마찰 × DT`는 `0 이상 1 미만`. 가속도 합산도 안전 범위를 넘어서는 안 되며 위반 시 실패
- 가속도 합이 정확히 0일 때만 정지 임계 판정. `KILL` 존은 P0-3 정산에서 우선 처리
- `body_id`와 `zone_id`는 별도 uint32 네임스페이스, 0은 무효
- 각 월드에서 1부터 단조 증가하고 제거 후 재사용하지 않음
- 초기 요청은 안정 `spawn_key`, 런타임 요청은 `(틱, 원인 body_id, event_type_id, 이벤트 내 순번)`으로 정렬 후 할당
- 복제·스냅샷은 다음 ID 카운터까지 보존. 외부 ID 지정은 복원·테스트 전용
- 콘텐츠 문자열 ID와 숫자 시뮬레이션 ID를 분리하고 uint32 초과는 실패
- `SimEvent` 순서 필드: `tick:int64`, `substep:uint16`, `sequence:uint32`, `type_id:uint16`
- 관계 필드: `source_body_id:uint32`, `target_body_id:uint32`, `zone_id:uint32`, `cause_id:uint16`; 대상 없음은 0
- payload 슬롯: `position:FixVec2`, `vector:FixVec2`, `value_a:int64`, `value_b:int64`, `flags:uint32`; 미사용 값은 0
- Dictionary·Variant·문자열 payload 금지, append 후 수정 금지
- sequence가 큐 순서의 정본이며 소비자는 cursor만 이동. 스냅샷은 큐·cursor·다음 sequence를 보존
- type/cause enum은 append-only, sequence 초과는 실패
- P0-2 타입: `BODY_ADDED`, `BODY_REMOVED`, `BODY_STOPPED`; P0-3에서 충돌·벽·파괴 타입 추가

P0-2의 사전 기술 결정과 명세 전체가 승인되었다. 승인된 대상 파일과 수용 기준 범위에서 구현할 수 있다.

## 범위 밖

- 원-원·벽 충돌과 서브스텝
- 소멸·피해·파괴 트리거 정산
- CTB, 조준, 렌더 보간
- 실제 맵·기물 콘텐츠 JSON

## 필요 에셋

없음.
