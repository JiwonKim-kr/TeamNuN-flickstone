# P1-1 · CTB / BattleState

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-20 |
| approved | 2026-08-20 · 사용자 전체 승인 |
| phase | P1 · 전투 루프 |
| 선행 명세 | P0-1~4 승인·구현, `p1_index.md` 승인 |
| 후속 명세 | `p1_launch_aim_prediction.md` |
| 구현 권한 | 승인됨. 사용자 별도 구현 요청 전까지 착수 대기 |

## 목적

물리 시뮬레이션과 분리된 전투 상태에서 CTB가 다음 행동자를 결정하고, 전투가 `TURN_START → AIM → RESOLVE → TURN_END → CHECK` 순서로 진행되는 엔진 독립 골격을 정의한다. 이후 발사·피해·트리거·승패가 같은 상태 소유권과 결정론 규칙 위에 결합되도록 한다.

## 설계 정본 참조

- `docs/design/game_design.md` D-13, D-20~21, D-46~48
- 3.1 전투 내부 루프
- 4.7 CTB, 4.8 턴 상태 머신
- 7.7 기물 플래그 축과 중립 기물
- 14.1 결정론 원칙, 14.2 레이어 규칙, 14.3 디렉터리 구조
- `docs/specs/p0_sim_world.md`
- `docs/specs/p0_determinism_hash_regression.md`

## 범위

- 전투 참여자의 안정된 `body_id` 연결과 P1 최소 플래그
- 기물별 속도 스탯과 CT 상태
- 다음 행동 시점의 정수 계산과 행동자 선택
- 런타임 참여자 추가·제거를 견디는 스케줄러 경계
- 전투 단계와 현재 행동자의 단일 권위 상태
- `SimWorld` 물리 해결 진입·종료를 위한 전이 경계
- 깊은 복제와 향후 정규 스냅샷에 포함할 결정 상태 식별
- release에서도 관찰 가능한 오류와 실패 전 상태 불변 계약

## 범위 밖

- 마우스 좌표, 드래그 거리, 입력 양자화, 발사 속도와 궤적선
- 충돌 피해, 체력 감소, 크리티컬, 파괴 정산
- 능력 효과와 트리거 실행
- 승패 조건의 실제 판정과 전투 후 런 상태
- 개별 기물·적·상태이상 콘텐츠 JSON
- P3 AI 샷 평가
- 실제 아트와 효과음

## 확정된 선행 계약

- CTB 속도 스탯은 실제 물리 속도와 무관하다.
- CTB 시간은 `SimWorld.tick()` 및 물리 해결에 걸린 초와 무관한 추상 정수 시간이다.
- 전투 시작 시 기존 참여자의 CT는 0이다.
- 행동 후에는 CT를 임계값만큼 빼며 0으로 강제 초기화하지 않는다.
- 물리 해결 중에는 CT가 증가하지 않는다.
- 중립 기물은 `has_turn=false`이며 CTB에 참여하지 않는다.
- 런타임에 참여자가 추가·제거될 수 있고, 전투 숫자 ID는 P0의 안정 `body_id`를 참조한다.
- 모든 참여자 순회와 외부 관찰 목록은 `body_id` 오름차순을 정본으로 한다.
- `AIM` 취소는 CT를 바꾸지 않는다.

## 확정 데이터와 소유권

### BattleParticipant

전투 계층은 P0 `SimBody`에 전투 규칙을 직접 추가하지 않고, `body_id`로 연결되는 별도 참여자 상태를 소유한다.

| 필드 | 형식 | 계약 상태 |
|---|---|---|
| `body_id` | 의미상 `uint32`, 저장 `int64` | P0 안정 ID 재사용, 0 금지 |
| `faction` | `uint16` append-only 정수 enum | `INVALID=0`, `PLAYER=1`, `ENEMY=2`, `NEUTRAL=3` |
| `has_turn` | bool | 정본 7.7에서 확정 |
| `controllable` | bool | 정본 7.7에서 확정 |
| `counts_for_victory` | bool | 정본 7.7에서 확정 |
| `speed_stat` | 정수 | 기본 범위 50~200, 기본값 100 |
| `ct` | 비음수 `int64` | 임계값 10,000과 C-01 산술 계약 |

- 배열은 항상 `body_id` 오름차순으로 저장한다.
- `body_id` 중복, 대응하는 `SimBody` 부재, 잘못된 플래그 조합은 전투 시작 전에 실패한다.
- P1-3의 체력·공격력 등은 이 상태의 확장 또는 별도 전투 스탯 객체로 추가한다. P1-1 구현이 P0 `SimBody` 레이아웃을 변경하지 않는다.

### BattleState

단일 전투의 권위 상태는 최소한 아래 값을 소유한다.

- 현재 phase
- 현재 행동자 `body_id` 또는 무효값 0
- 추상 CT 시간
- 정렬된 참여자 상태
- 연결된 `SimWorld`의 깊은 사본 가능한 소유권
- 다음 단계에서 추가할 전투 이벤트 cursor와 결과 상태의 확장 지점

phase enum 번호와 정확한 phase 진입 API는 C-06 계약을 따른다. 외부 UI는 읽기 전용 getter와 불변 명령 객체만 사용하며 내부 배열 참조를 받지 않는다.

## 확정 상태 전이 요약

```text
BATTLE_START
  → 다음 행동 시점 계산
TURN_START
  → 현재 행동자 확정
AIM
  → 취소: AIM 유지, 권위 상태 불변
  → 유효 발사 확정: CT 차감 후 RESOLVE
RESOLVE
  → SimWorld를 고정 스텝으로 진행
  → 모든 활성 본체 정지: TURN_END
TURN_END
  → CHECK
CHECK
  → P1-4 판정 전까지 다음 턴/전투 종료 분기 경계만 제공
```

- P1-1은 승패를 판정하지 않는다. 테스트에서는 CHECK 이후 `continue`를 명시적으로 주입해 다음 행동자를 검증한다.
- `SimWorld.step()` 실패 또는 전투 상태 불변식 위반 시 호출 전체를 원복하고 `SimStatus`에 기록한다. 런타임 진행은 중단하되 오류 전용 phase로 바꾸지 않는다.
- RESOLVE 시간 예산과 강제 정산은 C-07 계약을 따른다.

## 확정 공개 책임 요약

정확한 이름과 반환 형식은 C-09 5~8절에서 확정했다. 아래는 그 책임 경계의 요약이다.

- 참여자 목록을 검증해 전투를 생성한다.
- 현재 phase·행동자·추상 CT 시간·정렬된 참여자 사본을 조회한다.
- 전투 시작 또는 CHECK 계속 경계에서 다음 행동자를 계산해 `TURN_START`로 전이한다.
- 턴 시작 규칙 정산을 완료한 별도 호출로 `TURN_START`에서 `AIM`으로 전이한다.
- 유효 발사 명령을 원자적으로 커밋해 CT를 차감하고 `RESOLVE`로 전이한다.
- AIM 취소를 상태 변경 없이 처리한다.
- RESOLVE에서 정확히 한 `SimWorld.step()`만 전진한다.
- CHECK 결과를 외부 전투 규칙으로부터 받아 다음 턴 또는 종료 경계로 전이한다.
- 전체 전투 상태를 깊은 복제한다.

UI가 phase, CT 또는 현재 행동자를 직접 설정하는 setter는 두지 않는다.

## 결정론·오류 공통 계약

- CT·속도·추상 시간은 float 없이 정수로 저장·계산한다.
- 다음 행동 계산은 반복적인 1틱 루프가 아니라 정수식으로 즉시 점프한다.
- 나눗셈의 올림·내림과 동률 처리를 이름 있는 프로젝트 헬퍼로 명시한다.
- Dictionary 순회와 정렬되지 않은 외부 입력을 권위 순서로 사용하지 않는다.
- 검증 실패, 정수 범위 초과, phase 위반, 없는 행동자 참조는 release-safe status에 first-error-wins로 기록한다.
- 실패한 공개 호출은 참여자 CT, 현재 행동자, phase, 추상 시간, `SimWorld`를 호출 전 상태로 유지한다.
- phase와 오류 enum 번호는 append-only다.
- P1의 결정 상태는 P1-5에서 정규 스냅샷·상태 해시 범위를 확정하기 전까지 P0 schema v1에 조용히 추가하지 않는다.

## 결정 목록

| 순서 | 결정 | 상태 |
|---|---|---|
| C-01 | CT 표현·임계값·점프 계산·행동 차감 시점 | **approved** · 2026-08-20 사용자 승인 |
| C-02 | 속도 스탯 지원 범위와 P1 회색상자 기준값 | **approved** · 2026-08-20 사용자 승인 |
| C-03 | 같은 추상 시점 동시 도달의 행동자 우선순위 | **approved** · 2026-08-20 사용자 승인 |
| C-04 | 런타임 추가 참여자의 초기 CT | **approved** · 2026-08-20 사용자 승인 |
| C-05 | CTB 예보 개수와 예보 계산·동률 표시 | **approved** · 2026-08-20 사용자 승인 |
| C-06 | phase enum·전이 API·발사 없는 턴 확장점 | **approved** · 2026-08-20 사용자 승인 |
| C-07 | RESOLVE 최대 틱·강제 감속·교착 오류 경계 | **approved** · 2026-08-20 사용자 승인 |
| C-08 | 전투 상태 복제·스냅샷의 P1-1 최소 필드 | **approved** · 2026-08-20 사용자 승인 |
| C-09 | 대상 파일·공개 API·수용 테스트 최종안 | **approved** · 2026-08-20 사용자 승인 |

## C-01 확정 · CT 표현과 진행

2026-08-20 사용자 승인으로 아래 규격을 확정했다.

1. `ct`와 추상 CT 시간은 비음수 `int64`, `speed_stat`은 양의 정수로 저장한다.
2. 공통 행동 임계값은 `CT_THRESHOLD = 10,000`으로 둔다.
3. 준비된 참여자가 없을 때 다음 시간 점프를 참여자별로 계산한다.

```text
remaining_i = CT_THRESHOLD - ct_i
ticks_i     = ceil(remaining_i / speed_i)
delta       = min(ticks_i)
ct_i       += speed_i × delta   # has_turn인 생존 참여자 전부
abstract_time += delta
```

4. 이미 `ct >= CT_THRESHOLD`인 참여자가 있으면 `delta=0`이며 시간을 전진하지 않는다.
5. 현재 행동자 선택과 AIM 진입만으로는 CT를 차감하지 않는다.
6. 유효 발사를 확정해 AIM에서 RESOLVE로 넘어가는 호출이 `ct -= CT_THRESHOLD`를 같은 원자적 변경으로 수행한다.
7. 취소·무효 발사·명령 검증 실패는 CT와 추상 시간을 바꾸지 않는다.
8. CT는 0으로 리셋하지 않고 초과분을 보존한다.
9. C-02의 최종 상한은 `speed_stat <= CT_THRESHOLD`를 만족해야 한다. 따라서 한 번의 시간 점프 뒤 차감한 행동자가 즉시 다시 준비 상태가 되는 다중 행동은 생기지 않는다.
10. `ceil` 계산과 곱셈은 범위 검사 후 수행하며 실패 시 어떤 CT도 갱신하지 않는다.

### 확정 이유

- 10,000 단위는 이후 초기 CT·CT 증감 효과를 5%·10%·20%·25%·50% 같은 비율로 정수 표현할 여유가 있다. 속도 보정의 반올림 규칙은 해당 효과 명세에서 별도로 고정한다.
- 속도가 임계값의 약수가 아니어도 초과분을 보존해 장기 평균 행동 빈도가 왜곡되지 않는다.
- AIM 진입이 아니라 유효 발사 확정 때만 차감하므로 조준 취소의 CT 불변 계약과 직접 맞는다.
- 실제 CT 틱을 반복하지 않아 느린 기물이 있어도 계산량이 늘지 않는다.

### 확정 예시

- `ct=9,990`, `speed=64`이면 `delta=1`, 준비 CT는 `10,054`, 발사 확정 후 CT는 `54`다.
- `ct=0`, `speed=100`이면 `delta=100` 뒤 정확히 `10,000`으로 준비되고 발사 확정 후 0이다.
- 둘 이상의 참여자가 같은 시점에 준비되면 C-03 규칙이 행동자를 고르며, 선택되지 않은 참여자의 초과 CT는 그대로 보존한다.

## C-02 확정 · 속도 범위와 회색상자 값

2026-08-20 사용자 승인으로 아래 규격을 확정했다.

### 1. 데이터에 저장하는 기본 속도

- `speed_stat`은 단위 없는 양의 정수다. float와 Q47.16을 사용하지 않는다.
- 콘텐츠·fixture에 저장할 수 있는 기본 속도 범위는 **50~200**이다.
- 기본값은 **100**이다.
- 50 미만, 200 초과, 0, 음수, 정수가 아닌 값은 자동 보정하지 않고 전투 생성 전에 실패한다.
- 기본 속도 범위는 기물 데이터의 저자 범위다. P1-1에는 속도 버프·디버프가 없으므로 저장값과 스케줄러 입력값이 같다.

### 2. P1 회색상자 시험값

P1 회색상자 참여자는 아래 세 값만 사용한다.

| 등급 | `speed_stat` | CT 0에서 첫 준비까지 | 기준 100 대비 행동률 |
|---|---:|---:|---:|
| 느림 | 80 | 125 추상 틱 | 0.8배 |
| 기준 | 100 | 100 추상 틱 | 1배 |
| 빠름 | 125 | 80 추상 틱 | 1.25배 |

- 최소·최대 경계 50과 200은 수용 테스트와 스트레스 fixture에서만 사용한다.
- 회색상자 팀 구성은 속도 효과만 고립해 볼 수 있도록 나머지 공통 스탯이 같은 참여자를 사용한다.
- 이 세 값은 P1 전투 감각 검증용 초기값이며 41종 기물의 최종 스탯을 확정하지 않는다.

### 3. 향후 속도 변경과의 경계

- P2의 상태이상·능력·`MODIFY_STAT`이 만드는 유효 속도와 반올림 규칙은 해당 명세에서 별도로 승인한다.
- 향후 유효 속도는 C-01 안전 불변식 `1 <= effective_speed <= CT_THRESHOLD`를 만족해야 하며 범위 밖 결과를 조용히 clamp하지 않는다.
- 기본 속도와 유효 속도를 같은 필드에 덮어쓰지 않는다. 전투 상태는 원본 기본값과 계산된 유효값을 구분할 확장 지점을 둔다.
- P1-1 스케줄러 공개 경계는 검증된 현재 유효 속도만 읽고, 버프·디버프의 합성 방법을 알지 않는다.

### 확정 이유

- 50~200은 기준 100의 0.5~2배라 속도가 기물 정체성이면서도 한 기본 기물이 다른 기본 기물보다 네 배 넘게 행동하는 범위를 막는다.
- 80/100/125는 행동 간격이 각각 125/100/80으로 정확히 나뉘어 초기 골든과 사람이 읽는 로그가 단순하다.
- 느림 80은 기준 대비 20% 감소, 빠름 125는 기준 대비 행동률 25% 증가라 세 등급의 차이가 분명하지만 한두 턴 안에 행동 기회를 잃을 정도로 벌어지지 않는다.
- 데이터 기본값과 향후 유효값을 분리하면 상태이상 추가 시 원본을 잃거나 효과 해제 후 값이 떠도는 문제를 피할 수 있다.

### 확정 경계 테스트

- 50, 80, 100, 125, 200의 첫 준비 시점과 장기 행동 횟수 비교
- 49와 201, 0, 음수의 생성 실패와 전체 전투 상태 불변
- 같은 입력에서 80/100/125 참여자의 삽입 순서를 바꿔도 CT와 준비 집합이 동일
- 속도 외 모든 값이 같은 회색상자 전투에서 행동 횟수가 `80 < 100 < 125` 순서를 유지

## C-03 확정 · 동시 도달 우선순위

2026-08-20 사용자 승인으로 아래 규격을 확정했다.

### 1. 준비 집합

- C-01의 시간 점프가 끝난 뒤 `ct >= CT_THRESHOLD`인 모든 `has_turn=true` 생존 참여자를 준비 집합으로 만든다.
- 이미 준비된 참여자가 남아 있으면 `delta=0`으로 같은 추상 시간에서 다음 행동자를 선택한다.
- 준비 집합은 매 선택 시 `body_id` 오름차순으로 수집한 뒤 아래 비교 키를 적용한다. 컨테이너 삽입 순서는 사용하지 않는다.

### 2. 비교 순서

행동자는 아래 우선순위를 앞에서부터 적용해 하나를 고른다.

1. **CT 초과분 내림차순**: `ct - CT_THRESHOLD`가 큰 참여자 우선
2. **속도 내림차순**: 초과분이 같으면 `speed_stat`이 큰 참여자 우선
3. **진영 교대**: 초과분과 속도가 모두 같은 player/enemy 후보가 있으면 직전 행동 진영의 반대편 우선
4. **body ID 오름차순**: 위 조건까지 같으면 작은 `body_id` 우선

초과분은 같은 정수 CT 틱에 임계값을 넘었더라도 그 틱 안에서 더 먼저 준비된 정도를 나타낸다. 속도는 초과분까지 같은 경우에만 추가 우선권을 준다.

### 3. 완전 동률의 진영 교대

- `BattleState`는 `last_acted_faction`을 결정 상태로 저장한다.
- 전투 시작 시 값은 `ENEMY`로 초기화해 첫 player/enemy 완전 동률에서는 player가 먼저 행동한다.
- 행동을 소비한 유효 발사가 확정될 때 현재 행동자의 진영으로 갱신한다.
- 후보가 한 진영에만 있으면 진영 교대 규칙을 적용하지 않고 그 진영 안에서 `body_id`가 작은 참여자를 고른다.
- player와 enemy가 아닌 진영은 P1 범위 밖이다. neutral은 `has_turn=false`라 후보가 될 수 없다.
- 진영 교대는 초과분 또는 속도가 다른 후보를 앞지르지 않는다. 더 빨리 준비되었거나 더 빠른 기물의 CTB 이득을 보존한다.

### 4. 상태·복제 계약

- `last_acted_faction`은 BattleState 깊은 복제와 P1 결정론 스냅샷 대상이다.
- AIM 진입·취소·무효 발사·실패한 발사는 값을 바꾸지 않는다.
- 현재 행동자가 RESOLVE 중 파괴되어도 이미 소비한 행동의 진영 기록은 유지한다.
- 런타임 참여자 추가·제거로 `body_id`가 비어도 비교 결과는 남은 후보만으로 다시 계산한다.

### 확정 이유

- 단순 ID 순서는 초기 ID가 진영별로 묶인 경우 같은 속도의 한 팀 전체가 먼저 행동하는 영구 편향을 만든다.
- 진영 교대를 완전 동률에만 적용하면 같은 속도 팀은 player/enemy가 번갈아 행동하면서도 속도와 CT 초과분의 의미를 침범하지 않는다.
- 비소비 RNG나 별도 initiative permutation이 없어 리플레이 입력과 RNG 소비 순서를 늘리지 않는다.
- 최종 `body_id` 비교가 남아 있어 모든 입력에서 행동자가 정확히 하나로 결정된다.

### 확정 예시

- 모두 CT 10,000·속도 100이고 ID가 player 1,2,3 / enemy 4,5,6이면 첫 준비 묶음은 `1 → 4 → 2 → 5 → 3 → 6`이다.
- player 1의 초과 CT가 20이고 enemy 4가 0이면 직전 진영과 무관하게 player 1이 먼저다.
- 초과 CT가 같은 player 1 속도 100 / enemy 4 속도 125이면 enemy 4가 먼저다.
- 같은 진영의 완전 동률은 작은 `body_id`가 먼저다.

### 확정 경계 테스트

- 진영별로 묶인 ID와 교차 배정 ID가 같은 비교 규칙을 따름
- 완전 동률 3대3에서 player/enemy가 가능한 동안 교대함
- 초과분 차이가 진영 교대보다 우선함
- 초과분 동률에서 속도 차이가 진영 교대보다 우선함
- 취소·실패·복제·복원 후 `last_acted_faction`이 변하거나 유실되지 않음
- 한 진영 전멸·참여자 제거·neutral 혼재 상태에서도 유일한 후보를 선택함

## C-04 확정 · 런타임 추가 참여자의 초기 CT

2026-08-20 사용자 승인으로 아래 규격을 확정했다.

### 1. 초기 CT

- 전투 시작 후 새로 추가된 `has_turn=true` 참여자의 초기 CT는 항상 **0**이다.
- 이미 흐른 `abstract_time`만큼 CT를 소급 충전하지 않는다. 참여자는 활성화된 시점부터 자기 속도로 충전한다.
- `has_turn=false` 참여자도 저장 CT는 0으로 고정하며 스케줄러가 증가시키지 않는다.
- P1에는 초기 CT override나 백분율 정책을 두지 않는다. 0이 아닌 초기 CT가 필요한 능력은 후속 효과 원자 명세에서 이름 있는 정책으로 별도 승인한다.

### 2. 활성화 경계

- 전투 계층의 참여자 추가 요청은 즉시 참여자 배열을 바꾸지 않고 pending 큐에 기록한다.
- 요청은 P0의 생성 정렬 키 `(요청 tick, 원인 body_id, event_type_id, 이벤트 내 ordinal)`로 정렬한다.
- C-09 재승인 보완에 따라 런타임 `BODY_ADDED`는 할당 ID와 함께 이 요청 키를 기존 고정 payload 슬롯에 기록한다. 참여자 요청은 네 필드가 정확히 일치하는 이벤트로만 ID를 배정받으며, 비참여자 spawn이 섞여도 순서 추측에 의존하지 않는다.
- 대응 `SimBody`가 P0 월드에서 안정 ID를 배정받은 뒤에만 `BattleParticipant`를 만들 수 있다.
- RESOLVE에서는 `SimWorld.step()`이 끝난 뒤 P0 이벤트를 sequence 순으로 소비하는 **post-step mutation barrier**에서 `BODY_ADDED`와 참여자 추가를 함께 반영한다.
- 같은 스텝의 뒤쪽 충돌·벽·파괴 이벤트를 전투 계층이 해석하기 전에 새 참여자 상태가 존재해야 한다.
- RESOLVE 밖에서 생기는 런타임 추가도 다음 권위 작업 전에 C-06이 확정한 phase별 mutation barrier를 거친다.
- mutation barrier는 정렬된 요청 묶음을 원자적으로 반영하고 최종 참여자 배열을 `body_id` 오름차순으로 저장한다.
- 현재 행동자는 AIM 진입부터 CHECK까지 잠겨 있으므로, 중간에 활성화된 새 참여자는 현재 행동에 끼어들지 않고 다음 행동자 계산부터 후보가 된다.

### 3. 실패와 중복 계약

- body ID 0, 이미 등록된 body ID, 대응 `SimBody` 부재, 잘못된 속도·플래그, 중복 생성 키는 전체 정산 실패다.
- mutation barrier 묶음 중 하나라도 실패하면 추가·제거·CT·phase·현재 행동자·월드를 모두 장벽 전 상태로 유지한다.
- 같은 묶음에서 같은 body ID를 제거하고 다시 추가하는 것은 ID 재사용으로 간주해 실패한다.
- P0에서 파괴·제거된 ID는 새 참여자에 재사용하지 않는다.
- `counts_for_victory` 여부와 관계없이 `has_turn=true`면 같은 CT 0 규칙을 쓴다.

### 4. 기존 참여자의 특수 변화

- 변신은 새 참여자 추가가 아니며 같은 `body_id`와 CT를 유지한다. 정본 7.6.3의 속도 변경 CT 환산은 P2 변신 명세에서 처리한다.
- 부활이 기존 body ID를 되살리는지 새 body ID를 만드는지는 능력 명세 범위다. 새 ID라면 C-04의 CT 0을 적용한다.
- `EXTRA_LAUNCH`, 턴 당김, CT 증감은 참여자 생성이 아니며 이 규칙으로 표현하지 않는다.
- `has_turn=false → true` 변경도 단순 필드 변경으로 허용하지 않는다. 후속 명세에서 명시 정책이 생기기 전에는 새 참여자 등록과 같은 검증 경계를 요구한다.

### 확정 이유

- CT 0은 생성 직후 즉시 행동하거나 현재 준비 묶음에 끼어드는 소환 연쇄를 막는다.
- 과거 추상 시간을 소급하지 않아 전투 초반 생성과 후반 생성의 첫 행동 대기 규칙이 같다.
- post-step mutation barrier는 물리 계산 중 배열 변경을 막으면서도 같은 스텝의 후속 충돌 이벤트가 새 기물의 진영·전투 스탯을 조회할 수 있게 한다.
- 초기 CT override를 P1에 열지 않으면 콘텐츠가 임의 숫자로 선턴을 얻는 우회로를 만들지 않는다.

### 확정 예시

- 추상 시간 350에 속도 100 참여자가 활성화되면 CT 0으로 시작하고 추상 시간 450에 처음 준비된다.
- RESOLVE 중 생성 요청된 속도 125 참여자는 대응 `BODY_ADDED` post-step 장벽에서 CT 0으로 활성화되고, 다음 스케줄에서 80 추상 틱을 기다린다.
- CT 10,000으로 이미 준비된 기존 참여자가 있으면 새 참여자는 CT 0이므로 그 준비 묶음에 끼어들지 않는다.
- `has_turn=false`인 발사체·부착물은 CT 0을 유지하며 예보와 행동자 후보에 나타나지 않는다.

### 확정 경계 테스트

- 서로 다른 요청 삽입 순서가 같은 생성 키 정렬·body ID·CT 0 결과를 냄
- mutation barrier 전까지 pending 참여자가 스케줄러와 외부 참여자 조회에 노출되지 않음
- `BODY_ADDED` 처리 뒤 같은 스텝의 충돌 이벤트가 새 참여자 상태를 조회할 수 있음
- 같은 mutation barrier의 요청 순서와 최종 body ID 정렬이 고정됨
- 중복 ID·중복 키·없는 SimBody·잘못된 속도 하나가 전체 정산을 원복함
- has_turn false 참여자의 CT가 장시간 진행 후에도 0이고 예보에서 제외됨
- 복제본의 pending 큐를 정산해도 원본 큐와 참여자 상태가 변하지 않음

## C-05 확정 · CTB 예보 개수와 계산·동률 표시

2026-08-20 사용자 승인으로 아래 규격을 확정했다.

### 1. 노출 개수와 현재 행동자

- 플레이 화면은 현재 행동자를 별도로 표시하고, 그 뒤의 **향후 행동 10회**를 CTB 예보로 노출한다. 현재 행동자는 10회에 포함하지 않는다.
- 10회는 P1 전장의 최대 참여자 수 5대5에서 한 번의 명목상 순환을 확인할 수 있는 기본 길이다. 실제 순서는 속도와 잔여 CT를 따르므로 같은 참여자가 10회 안에 반복될 수 있다.
- 코어의 읽기 전용 예보 API는 테스트·도구를 위해 `count` 1~32를 받는다. 0 또는 33 이상은 상태를 바꾸지 않고 명시적으로 실패한다.
- 런타임 UI의 기본 요청값은 10으로 고정한다. 목표 해상도와 최종 배치는 별도 UI 명세에서 정하되 10개 항목의 순서와 동률 관계는 접근 가능해야 한다.
- `BATTLE_END` 또는 유효한 다음 스케줄이 없는 상태에서는 성공한 빈 예보를 반환한다.

### 2. 예보 계산 계약

- 예보는 권위 상태의 지역 사본만 전진하는 **순수 읽기 계산**이다. `BattleState`, 참여자 CT, 현재 행동자, `last_acted_faction`, phase, pending mutation, `SimWorld`, RNG를 바꾸거나 소비하지 않는다.
- 각 예보 항목은 C-01의 정수 시간 점프와 임계값 차감, C-03의 동률 우선순위를 그대로 반복해 계산한다. 별도 근사식·float·UI 전용 정렬을 두지 않는다.
- 예보에서 행동 하나를 소비할 때 지역 사본의 해당 CT에서 `CT_THRESHOLD`를 빼고 `last_acted_faction`을 그 행동자의 진영으로 갱신한다.
- `TURN_START`와 `AIM`에서는 현재 행동자가 결국 유효 행동을 소비한다고 가정해 그 행동의 CT 차감과 진영 갱신을 지역 사본에 먼저 적용한 뒤, 다음 행동부터 10회를 계산한다.
- `RESOLVE`, `TURN_END`, `CHECK`에서는 현재 행동의 CT가 이미 차감된 상태를 기준으로 다음 행동부터 계산한다. P1-4가 전투 종료를 확정하면 예보는 빈 목록이 된다.
- 예보는 계산 시점의 참여자·속도·CT가 유지된다는 조건부 스케줄이다. 미래 충돌 결과, 파괴, 생성, 속도 변경, 능력·트리거, AI 선택을 추측하지 않는다.
- 권위 상태 변경 또는 mutation barrier 정산 뒤에는 새 상태에서 다시 계산한다. P1-1 코어는 오래된 예보 캐시를 소유하지 않는다.

### 3. 항목 형식과 동률 표시

각 예보 항목은 최소한 아래 읽기 전용 값을 가진다.

| 필드 | 형식 | 의미 |
|---|---|---|
| `order_index` | 0부터 시작하는 정수 | C-03까지 적용된 최종 직렬 순서 |
| `body_id` | 의미상 `uint32` | 예보 행동자 |
| `faction` | append-only 정수 enum | 표시용 진영 |
| `ready_at_abstract_time` | 비음수 `int64` | 해당 행동자가 준비되는 절대 추상 시점 |
| `simultaneous_group` | 0부터 시작하는 정수 | 같은 준비 시점인 연속 항목의 묶음 번호 |
| `is_simultaneous` | bool | 같은 묶음에 둘 이상이 있는지 여부 |

- 같은 `ready_at_abstract_time`에 행동하는 연속 항목은 같은 `simultaneous_group`을 가진다.
- UI는 이 항목들을 묶음선·스택·`동시` 표식 중 하나로 시각적으로 연결하되, 묶음 내부는 C-03으로 결정된 직렬 순서를 그대로 표시한다.
- 동률을 무작위·불확정 상태처럼 표시하지 않는다. 실제 권위 행동 순서는 언제나 하나로 결정된다.
- 예보용 구조는 내부 참여자 참조나 가변 배열을 노출하지 않으며, 호출자가 수정해도 전투 상태가 바뀌지 않는 값 사본이다.

### 4. 갱신과 phase 경계

- 참여자 추가·제거, CT·유효 속도 변경, 유효 행동 소비, `last_acted_faction` 변경 뒤의 다음 조회는 갱신된 예보를 반환한다.
- RESOLVE 도중 생성·파괴 요청은 C-04 post-step mutation barrier 전까지 예보에 반영하지 않고, 장벽의 원자적 정산 뒤 반영한다.
- AIM 취소는 권위 상태를 바꾸지 않으므로 같은 예보를 반환한다.
- 실패한 발사·phase 전이·mutation barrier는 호출 전 상태와 같은 예보를 반환해야 한다.
- `CHECK`에서 P1-4 결과가 아직 주입되지 않았더라도 P1-1은 현재 참여자가 유지된다는 조건으로 예보를 계산한다. 전투 종료 결과가 주입되는 순간 빈 목록으로 바뀐다.

### 확정 이유

- 10회는 최대 10기 전투에서 다음 한 순환을 한눈에 보면서도 빠른 기물의 반복 행동을 숨기지 않는다.
- 코어 범위를 32로 제한하면 배치 도구가 더 긴 패턴을 검사할 수 있으면서 잘못된 무제한 요청의 계산량을 막는다.
- 실제 스케줄러와 같은 규칙을 지역 사본에 적용하면 표시와 권위 행동 순서가 갈라지는 별도 예보 구현을 피할 수 있다.
- 절대 추상 시점과 동률 묶음을 함께 노출하면 UI가 정확한 순서와 `동시 준비`를 모두 설명할 수 있다.
- 조건부 예보임을 명시하면 미래 피해·파괴·소환을 추측하는 복잡성을 P1-1에 섞지 않고, 해당 사건 뒤 즉시 재계산할 수 있다.

### 확정 예시

- 현재 행동자가 player 1이고, 그 뒤 같은 시점에 enemy 4와 player 2가 준비되면 현재 행동자 표시는 player 1, 예보 첫 묶음은 C-03 순서로 정렬된 enemy 4와 player 2다.
- 속도 80/100/125 참여자를 예보할 때 빠른 참여자가 10회 안에 반복되면 그대로 두며, 각 `ready_at_abstract_time`은 C-01 정수 계산 결과와 일치한다.
- 추상 시간 350의 C-04 신규 속도 100 참여자는 장벽 전에는 보이지 않고, 정산 뒤 CT 0 상태로 예보 계산에 포함된다.
- AIM 취소 전후의 예보 값은 바이트 단위로 같다.

### 확정 경계 테스트

- count 1·10·32 성공, 0·33 실패와 권위 상태 불변
- 예보 전후 BattleState·SimWorld·RNG·pending 큐의 정규 상태가 완전히 같음
- 예보 반복 결과가 실제로 같은 수의 유효 행동을 진행한 행동자·추상 시점과 일치함
- 완전 동률 3대3의 묶음 번호와 C-03 직렬 순서가 삽입 순서와 무관함
- 현재 행동자를 제외한 첫 항목과 가상 CT 차감·진영 갱신이 실제 다음 행동과 일치함
- 참여자 추가·제거와 mutation barrier 전후에만 예보가 바뀜
- 깊은 복제본의 예보가 원본과 같고, 한쪽 진행이 다른 쪽 예보를 바꾸지 않음
- 전투 종료 상태는 빈 예보를 반환하고 유효한 빈 전투와 오류를 구분함

## C-06 확정 · phase enum과 전이 API

2026-08-20 사용자 승인으로 아래 규격을 확정하고 앞부분의 상태 전이·오류 상태 초안을 이 규격으로 정리했다.

### 1. phase 번호

phase는 아래 명시값을 사용한다. 기존 값은 재정렬·재사용하지 않고 새 phase만 뒤에 추가한다.

| 이름 | 값 | 의미 |
|---|---:|---|
| `INVALID` | 0 | 미초기화·생성 실패 객체. 정상 전투에서는 관찰되지 않음 |
| `BATTLE_START` | 1 | 전투 시작 규칙과 향후 `ON_BATTLE_START` 처리 경계 |
| `TURN_START` | 2 | 행동자 확정 뒤 향후 `ON_TURN_START` 처리 경계 |
| `AIM` | 3 | 플레이어 조준 또는 AI 명령 대기 |
| `RESOLVE` | 4 | 고정 스텝 물리와 post-step 정산 |
| `TURN_END` | 5 | 향후 `ON_TURN_END`와 파괴 정산 경계 |
| `CHECK` | 6 | P1-4 승패 판정 결과 주입 경계 |
| `BATTLE_END` | 7 | 종료된 전투의 terminal 상태 |

- 일시정지·연출 대기·카메라 이동은 권위 phase가 아니라 UI·브리지 상태다.
- 오류는 phase로 표현하지 않는다. 호출자 소유 `SimStatus`에 기록하고 마지막 정상 phase를 유지한다.
- `INVALID`와 `BATTLE_END`에서는 권위 전이 명령을 받지 않는다. `BATTLE_END`의 조회·복제·스냅샷만 허용한다.

### 2. 안정 phase와 현재 행동자

- 성공적으로 생성된 전투는 `BATTLE_START`, `current_actor_body_id=0`에서 시작한다.
- `BATTLE_START`, `BATTLE_END`에서는 현재 행동자 ID가 0이다.
- `TURN_START`와 `AIM`의 현재 행동자는 대응하는 `has_turn=true` 참여자와 살아 있는 `SimBody`여야 한다.
- `RESOLVE`, `TURN_END`, `CHECK`에서는 현재 행동자 ID를 방금 소비한 턴의 안정 식별자로 유지한다. 행동자가 RESOLVE 중 파괴·제거되면 참여자 배열에 없어도 ID를 CHECK까지 보존한다.
- 현재 행동자는 다음 행동자 선택 호출에서만 설정하고, `CHECK → TURN_START` 또는 `BATTLE_START → TURN_START` 이외의 전이에서 다른 ID로 바꾸지 않는다.
- `CHECK`에서 다음 턴 계속이 확정되면 이전 ID를 지우고 다음 행동자를 같은 원자적 호출에서 선택한다. 전투 종료면 ID를 0으로 만든다.

### 3. 허용 전이와 명령 책임

| 명령 책임 | 허용 source | 성공 target | 핵심 계약 |
|---|---|---|---|
| 전투 시작 처리 완료 | `BATTLE_START` | `TURN_START` | 시작 mutation barrier 정산 후 C-01·C-03으로 첫 행동자 선택 |
| 턴 시작 처리 완료 | `TURN_START` | `AIM` | 턴 시작 정산 뒤 현재 행동자 유효성 재검증, CT 미차감 |
| 조준 취소 | `AIM` | `AIM` | 성공한 무변경 호출. CT·phase·월드·예보 불변 |
| 유효 발사 커밋 | `AIM` | `RESOLVE` | P1-2 명령 검증·월드 속도 적용·CT 차감·직전 진영 갱신을 한 트랜잭션으로 커밋 |
| 강제 무발사 턴 소비 | `TURN_START` 또는 `AIM` | `RESOLVE` 또는 `TURN_END` | 아래 4절의 시스템 전용 확장점 |
| 물리 해결 전진 | `RESOLVE` | `RESOLVE` 또는 `TURN_END` | 안정 상태면 0틱으로 종료, 아니면 정확히 1회 step과 post-step 정산 뒤 정지 여부 판정 |
| 턴 종료 처리 완료 | `TURN_END` | `CHECK` | 턴 종료 mutation barrier까지 원자 정산 후 판정 경계 진입 |
| 판정 결과 `CONTINUE` | `CHECK` | `TURN_START` | 이전 행동자 해제, 다음 행동 시점 점프·선택을 원자 실행 |
| 판정 결과 `END` | `CHECK` | `BATTLE_END` | 종료 결과는 P1-4가 소유하고 P1-1은 phase와 현재 행동자만 닫음 |

- 모든 phase는 외부에서 조회할 수 있는 안정 경계다. 한 공개 호출이 `TURN_START → AIM → RESOLVE`처럼 둘 이상의 규칙 경계를 건너뛰지 않는다.
- P1-1 테스트는 `CHECK`에 `CONTINUE` 또는 `END`를 직접 주입한다. P1-4 구현 후에는 판정기가 같은 경계를 호출하며 UI가 결과를 정하지 않는다.
- `CONTINUE`인데 다음 행동 가능 참여자가 없으면 조용히 종료하지 않고 실패한다. 종료 판단은 P1-4만 소유한다.
- `RESOLVE`의 최대 틱·강제 감속·교착 판정은 C-07에서 고정한다.

### 4. 발사 없는 턴 확장점

- P1 플레이 입력에는 임의 `PASS`를 두지 않는다. AIM 취소는 턴 소비가 아니라 같은 AIM 상태 유지다.
- 향후 빙결·행동 불가·발사 대체 규칙을 위해 battle-rules 계층만 호출하는 `강제 무발사 턴 소비` 경계를 둔다. UI 브리지는 이 명령을 노출하지 않는다.
- 강제 무발사도 유효한 턴 소비이므로 현재 참여자의 CT에서 `CT_THRESHOLD`를 빼고 `last_acted_faction`을 갱신한다.
- `ON_LAUNCH`는 발생하지 않지만 `ON_TURN_START`와 `ON_TURN_END` 경계는 정상적으로 지난다.
- 턴 시작 효과 등으로 움직이는 본체나 정산할 물리 작업이 남아 있으면 `RESOLVE`로, 전부 정지했고 pending 물리 작업이 없으면 `TURN_END`로 간다.
- 어떤 상태·능력이 이 경계를 사용하는지는 해당 후속 명세에서 별도 승인한다. 특히 7.4의 빙결이 턴 스킵인지 CT 정지인지는 이 결정으로 확정하지 않는다.
- 현재 행동자가 턴 소비 전에 파괴·제거된 경우는 강제 무발사와 다르다. CT 차감과 `last_acted_faction` 갱신 없이 현재 턴을 중단하고, 남은 물리 작업 유무에 따라 `RESOLVE` 또는 `TURN_END`로 보낸다. 같은 TURN_START에서 대체 행동자를 즉시 뽑지 않는다.
- `EXTRA_LAUNCH`는 CTB의 새 턴이나 강제 무발사로 표현하지 않는다. 구체적 추가 발사 큐와 상한은 후속 능력 명세에서 정한다.

### 5. mutation barrier 위치

P1-1에서 권위 participant·world 변경 요청을 반영할 수 있는 지점은 아래뿐이다.

1. `BATTLE_START` 처리를 완료하고 첫 행동자를 고르기 직전
2. `TURN_START` 규칙 처리를 완료하고 AIM 또는 강제 무발사로 나가기 직전
3. 각 `SimWorld.step()` 뒤 P0 이벤트를 sequence 순으로 소비하는 post-step 경계
4. `TURN_END` 규칙 처리를 완료하고 CHECK로 가기 직전
5. `CHECK` 결과를 반영하고 다음 행동자를 고르거나 전투를 닫기 직전

- 장벽 밖 요청은 pending 상태로만 존재하고 참여자 조회·스케줄러·예보에 노출되지 않는다.
- 장벽 정산, 현재 phase 불변식 확인, CT 차감 또는 스케줄러 선택, target phase 설정은 해당 공개 호출의 단일 트랜잭션이다.
- 요청 하나라도 실패하면 장벽과 phase 전이를 모두 커밋하지 않는다.
- 향후 트리거 버스는 임의 callback으로 코어 상태를 바꾸지 않고, 안정 순서의 명령·이벤트를 만든 뒤 위 장벽에서만 반영한다.

### 6. 오류와 재시도 계약

- source phase가 다른 명령, 없는 현재 행동자, 이미 소비한 턴 재커밋, 잘못된 판정 값은 `SimStatus`에 숫자 진단을 남기고 실패한다.
- 실패한 전이 호출은 phase, 현재 행동자, CT, 추상 시간, `last_acted_faction`, participant·pending 큐, `SimWorld`를 호출 전 상태로 유지한다.
- 오류 전용 phase를 두지 않는다. 이는 앞부분 초안의 “오류 상태로 고정”을 P0의 release-safe status·prepare-then-commit 방식에 맞게 구체화한 수정이다.
- 권위 진행 중 오류를 받은 런타임·테스트 러너는 새 status로 같은 명령을 무작정 재시도하지 않고 진행을 중단해 진단을 보고한다. 복구가 필요하면 마지막으로 검증된 복제·스냅샷에서 새 전투 상태를 만든다.
- `SimStatus.Code`와 `Operation`의 P1 숫자는 C-09 3절의 명시값을 기존 값 뒤에 append한다.

### 확정 이유

- phase를 트리거 처리 경계마다 유지하면 P1-4를 붙일 때 기존 전이를 다시 쪼개지 않아도 된다.
- 현재 행동자 ID를 CHECK까지 유지하면 충돌 중 파괴된 행동자의 턴 종료·처치 원인을 안정적으로 참조할 수 있다.
- 강제 무발사와 AIM 취소를 분리하면 상태이상에 의한 턴 소비가 플레이어 입력의 무료 취소와 섞이지 않는다.
- 오류를 gameplay phase로 만들지 않으면 실패 전 상태 불변 계약과 P0 status 패턴을 보존하면서, 러너가 진단을 누락하지 않게 할 수 있다.
- mutation barrier를 다섯 지점으로 제한하면 트리거·생성·파괴가 배열 순회 중간에 권위 상태를 바꾸지 않는다.

### 확정 예시

- 정상 한 턴은 `BATTLE_START(1) → TURN_START(2) → AIM(3) → RESOLVE(4) → TURN_END(5) → CHECK(6) → TURN_START(2)`로 진행한다.
- AIM에서 취소를 여러 번 호출해도 phase 3, CT, 현재 행동자, 예보가 변하지 않는다.
- TURN_START에서 시스템이 강제 무발사를 확정하고 모든 본체가 정지 상태면 CT와 직전 진영만 소비한 뒤 바로 TURN_END로 간다.
- 강제 무발사 전에 턴 시작 효과가 본체에 속도를 부여했다면 RESOLVE로 들어가 정상 정지 과정을 거친다.
- 현재 행동자가 RESOLVE 중 파괴되면 participant 목록에서는 제거되지만 `current_actor_body_id`는 TURN_END와 CHECK에서 유지되고, CHECK 계속 처리 때 다음 ID로 교체된다.
- RESOLVE에서 TURN_END 전이 직후 잘못된 추가 step 호출은 실패하고 틱과 phase를 바꾸지 않는다.

### 확정 경계 테스트

- phase enum 골든 번호와 append-only 검사
- 허용 전이 전체와 각 명령의 잘못된 source phase 교차표
- 전이 실패 전후 전투·월드 정규 상태의 완전 동일성
- BATTLE_START와 CHECK 계속의 다음 행동자 선택 결과가 C-01·C-03과 일치함
- 현재 행동자 설정·잠금·RESOLVE 중 제거·CHECK 해제 규칙
- AIM 취소 반복과 유효 발사 단 한 번 소비
- 강제 무발사의 CT·직전 진영 소비, `ON_LAUNCH` 미발생 확장 계약, 정지/이동 분기
- 턴 소비 전 행동자 제거가 CT·직전 진영을 갱신하지 않고 대체 행동자를 즉시 뽑지 않음
- 각 mutation barrier 직전·직후의 pending 노출과 실패 원복
- BATTLE_END terminal 상태의 조회·복제 허용과 모든 권위 명령 거부

## C-07 확정 · RESOLVE 시간 예산과 강제 정산

2026-08-20 사용자 승인으로 설계 정본 4.8의 미정값인 물리 해결 최대 시간과 강제 감속 규격을 아래처럼 확정했다.

### 1. 정지 완료 조건

RESOLVE는 아래 조건을 모두 만족한 안정 장벽에서만 완료된다.

1. 월드에 남아 있는 모든 물리 본체의 속도가 정확히 `FixVec2.zero()`다. `has_turn`, 진영, destructible 여부와 무관하며 발사체·중립 본체도 포함한다.
2. P0 world와 전투 계층에 반영 대기 중인 생성·제거·속도 변경이 없다.
3. 현재 step에서 생성된 P0 이벤트와 전투 이벤트가 안정 순서로 모두 소비·정산되었다.
4. 현재 해결 모드의 다음 step에서 즉시 속도를 만들, 억제되지 않은 지속 가속 원천이 없다.

- 개별 `BODY_STOPPED` 이벤트 개수로 완료를 추정하지 않고, post-step mutation barrier 뒤 `body_id` 오름차순으로 전역 조건을 직접 검사한다.
- 속도가 모두 0이어도 가속 존·지속 능력처럼 다음 정상 step에 다시 움직일 원천이 있으면 정상 정지로 보지 않는다. 강제 정산에서는 그 모드가 명시적으로 억제한 연속 가속을 완료 방해 원천으로 세지 않는다.
- RESOLVE 진입 직후 이미 완료 조건을 만족하면 `SimWorld.step()`을 호출하지 않고 0틱으로 `TURN_END`에 진입한다.

### 2. 정상 해결 예산

- 정상 RESOLVE 최대치는 **960 simulation ticks**, 즉 120Hz 기준 정확히 **8초**다.
- `normal_resolve_ticks`는 해당 행동에서 성공적으로 커밋된 `SimWorld.step()` 횟수다. RESOLVE 진입 시 0으로 초기화한다.
- 매 호출은 C-06대로 최대 한 step만 처리한다. 960틱을 프레임에 맞추려고 묶거나 버리지 않는다.
- 각 정상 step은 P0 물리·P1 피해·트리거·mutation barrier를 모두 처리한 뒤 정지 조건을 검사한다.
- 960번째 정상 step 뒤에도 완료되지 않으면 오류로 끝내지 않고 다음 step부터 명시적인 `FORCED_SETTLE` 모드로 전환한다.

### 3. 강제 정산 규격

- 강제 정산 최대치는 **240 simulation ticks**, 즉 추가 **2초**다. 정상과 합친 권위 예산은 최대 1,200틱·10초다.
- 매 강제 step 시작 시 `body_id` 오름차순으로 모든 비영 속도에 **3/4**를 한 번 곱한다.
- 곱셈은 Q47.16의 공통 최근접·절반 0에서 먼 방향 규칙을 사용하며 조용한 clamp나 float를 쓰지 않는다.
- 그 뒤 P0의 마찰·이동·충돌·벽·소멸 계산과 P1 피해·이벤트 정산을 정상적으로 수행한다.
- 가속 존과 매 step 능력처럼 지속적으로 속도를 새로 만드는 **연속 가속 원천은 강제 정산 동안 억제**한다. 충돌·파괴·트리거가 만드는 이산 사건과 이미 대기 중인 명령은 버리지 않고 안정 순서로 처리한다.
- 강제 정산은 속도를 즉시 0으로 덮어쓰는 hard stop이 아니다. 매 step의 실제 위치·충돌·피해 결과는 권위 상태에 남는다.
- P0 `SimWorld.step()`의 기본 계약과 P0 골든은 바꾸지 않는다. P1 전투 계층은 C-09 7절의 `step_with_acceleration_mode(SUPPRESS, status)` 경계를 통해 forced-settle 정책을 선택한다.
- 강제 정산 진입은 오류가 아니지만 `forced_settle_used=true`로 기록해 플레이테스트와 배치 시뮬에서 빈도를 집계한다.

### 4. 예산 소진과 교착 오류

- `forced_resolve_ticks`는 성공적으로 커밋된 강제 step 횟수이며 0~240 범위다.
- 240번째 강제 step 뒤 정지하면 정상적으로 TURN_END로 간다.
- 240 step을 모두 커밋했는데도 완료 조건을 만족하지 않으면 상태를 임의 정지시키거나 TURN_END로 넘기지 않는다.
- 그 다음 해결 호출은 step 전에 `RESOLVE_DEADLOCK`으로 실패하며 전투와 월드를 바꾸지 않는다. phase는 `RESOLVE`, 카운터는 정상 960·강제 240인 마지막 검증 상태를 유지한다.
- 런타임은 해당 전투 진행을 중단하고 진단을 표시한다. P1-5 배치 러너는 시드·입력·phase·카운터, 최초 비정지 `body_id`와 속도, pending 이벤트·변경 수를 재현 자료로 남긴다.
- 실패 진단의 첫 비정지 본체는 `body_id`가 가장 작은 항목이다. 본체가 모두 정지했지만 지속 가속이나 pending 작업이 원인이면 종류 ID와 가장 작은 owner ID를 기록한다.
- 정상 P1 데이터와 회색상자 시나리오는 강제 정산 240틱 안에 100% 정지해야 한다. 교착 오류는 허용 가능한 게임 결과가 아니라 테스트 실패다.

### 5. 카운터와 관찰 상태

BattleState는 한 행동의 해결 결과를 아래 값으로 노출한다.

| 필드 | 의미 |
|---|---|
| `normal_resolve_ticks` | 정상 모드에서 커밋한 step 수, 0~960 |
| `forced_resolve_ticks` | 강제 정산에서 커밋한 step 수, 0~240 |
| `forced_settle_used` | 한 번이라도 강제 정산에 진입했는지 |

- 새 launch 또는 물리 해결이 필요한 강제 무발사 턴을 커밋할 때 세 값을 0·0·false로 초기화한다.
- 0틱 무발사 종료는 세 값이 0·0·false인 완료 결과를 만든다.
- 값은 RESOLVE를 벗어나 TURN_END·CHECK에서도 직전 행동의 관찰 결과로 유지하고 다음 해결 진입 때 교체한다.
- 세 값은 결정론 상태이므로 깊은 복제와 C-08의 P1 스냅샷에 포함한다. UI는 진행 표시보다 개발용 진단·배치 통계에 우선 사용한다.

### 6. 권위 순서와 원자성

한 해결 호출은 아래 순서를 따른다.

1. source phase, 카운터, pending 상태 검증
2. 현재 상태가 이미 정지 완료인지 검사
3. 강제 모드라면 정렬된 속도 3/4 감쇠와 연속 가속 억제 정책 준비
4. 임시 월드에서 정확히 한 `SimWorld.step()` 실행
5. P0 이벤트 소비 → 향후 피해·트리거 → C-04 participant mutation 순으로 post-step barrier 정산
6. 카운터 증가와 정지 완료 재검사
7. 계속 RESOLVE, 강제 모드 진입, 또는 TURN_END를 한 번에 커밋

- 어느 단계에서든 산술·물리·이벤트·mutation 실패가 나면 해당 호출의 감속, step, 이벤트 cursor, 카운터와 phase를 모두 원복한다.
- 강제 감속은 RNG를 사용하지 않으며 순회·반올림·이벤트 순서는 정상 모드와 같은 결정론 규칙을 따른다.
- 강제 정산 중에도 소멸·파괴·승패 후보 사건은 무시하지 않는다. 승패 자체는 TURN_END 뒤 CHECK에서 P1-4가 판정한다.

### 확정 이유

- 기본 마찰 47/48에서 속도 2,048이 정지 임계 1/2 아래로 내려가는 이론 시간은 약 3.3초다. 8초 정상 예산은 여러 차례 반사·연쇄 충돌·지형 효과를 허용하면서 비정상 장기 턴을 구분할 여유가 있다.
- 3/4 추가 감쇠는 승인된 최대 속도 4,096도 연속 가속이 없다면 약 32틱 안에 정지 임계 아래로 낮춘다. 240틱은 이산 충돌·트리거 정산을 포함한 안전 여유다.
- hard stop 대신 짧은 강제 정산 구간을 실제로 시뮬레이션하면 마지막 충돌·소멸·피해를 잃지 않는다.
- 그래도 멈추지 않는 상태를 명시적 오류로 처리하면 무한 루프와 콘텐츠 결함을 조용히 정상 전투로 위장하지 않는다.
- 강제 정산 사용량을 상태로 남기면 8초·3/4 값이 실제 플레이에서 과도한지 P1-5 데이터로 재검토할 수 있다.

### 확정 예시

- 정상 발사가 397틱에 전역 정지하면 `397/0/false`를 남기고 TURN_END로 간다.
- 960번째 정상 step 뒤에도 한 기물이 움직이면 `960/0/true`가 되고, 다음 호출부터 속도 3/4 감쇠를 적용한다.
- 강제 18번째 step 뒤 정지하면 `960/18/true`를 남기고 TURN_END로 간다.
- 모든 속도가 0이지만 가속 존 안에 본체가 있으면 정상 정지로 보지 않는다. 960틱 뒤 강제 정산에서 연속 가속을 억제해 정지시킨다.
- 강제 240틱 뒤에도 이산 트리거가 계속 속도를 만들면 다음 호출이 교착 오류를 내고 `RESOLVE`, `960/240/true` 상태를 보존한다.

### 확정 경계 테스트

- RESOLVE 진입 시 이미 정지한 0틱 종료와 SimWorld tick 불변
- 959·960 정상 tick 경계와 강제 감속이 정확히 961번째 step부터 적용됨
- 속도 3/4 Q47.16 반올림 골든과 body 삽입 순서 교란 동일성
- 기본 속도 512·1,024·2,048와 안전 한계 4,096의 정상 또는 강제 정지 결과
- 마찰 0·가속 존·다중 반사·연쇄 충돌에서 최대 1,200틱 내 종료
- 강제 모드의 연속 가속 억제와 이산 충돌·파괴·이벤트 보존
- 240 강제 tick 소진 뒤 다음 호출의 교착 오류와 전체 상태 불변
- step·이벤트·mutation 실패 시 속도·위치·cursor·카운터·phase 원복
- 원본·깊은 복제본의 정상→강제 전환 tick과 최종 결과 일치
- `forced_settle_used` 비율을 배치 러너가 전투·행동별로 집계할 수 있음

## C-08 확정 · 깊은 복제와 P1 전투 스냅샷

2026-08-20 사용자 승인으로 P0 `SimSnapshot` schema v1을 유지하면서 P1-1 결정 상태를 독립적으로 복제·직렬화하는 경계를 아래처럼 확정했다.

### 1. 깊은 복제와 스냅샷의 역할 분리

- `BattleState` 깊은 복제는 AI 사본 실행, 트랜잭션 준비, 테스트 분기에 사용한다. 공개 호출이 끝난 어느 안정 경계에서든 만들 수 있고 pending 요청까지 전부 복제한다.
- `BattleSnapshot`은 저장·복원·상태 해시를 위한 불변 정규 상태다. 모든 mutation barrier가 끝나 pending 요청이 없는 안정 경계에서만 캡처한다.
- 깊은 복제는 런타임 객체 그래프를 보존하고, 스냅샷은 승인된 고정 폭 필드만 보존한다. 둘을 같은 범용 직렬화나 `duplicate(true)`에 맡기지 않는다.
- `SimStatus`는 호출자 소유 진단이므로 깊은 복제와 스냅샷에 포함하지 않는다.
- CTB 예보는 C-05의 파생값이므로 저장하지 않고 복원된 권위 상태에서 다시 계산한다.

### 2. 깊은 복제 계약

`BattleState.copy(status)`의 책임은 아래와 같으며, 공개 이름과 반환 형식은 C-09 6절을 따른다.

- phase, 현재 행동자 ID, 추상 CT 시간, `last_acted_faction`을 값 복제한다.
- 모든 `BattleParticipant`와 내부 배열을 새 객체·새 배열로 만들고 `body_id` 오름차순을 유지한다.
- C-07의 정상·강제 RESOLVE 카운터와 `forced_settle_used`를 복제한다.
- C-04의 pending 참여자 추가·제거 요청은 안정 키와 참여자 템플릿을 포함해 새 객체로 복제한다.
- 연결된 `SimWorld`는 `SimWorld.copy(status)`로 깊게 복제해 body·zone·RNG·이벤트 큐와 cursor·다음 ID·P0 pending 요청을 보존한다.
- 원본과 복제본 사이에 가변 participant, request, world, body, zone, RNG, event 배열 참조를 공유하지 않는다.
- 복제 실패는 미초기화 중립 `BattleState`를 반환하고 원본을 바꾸지 않는다. 부분 복제 객체를 진행 가능한 상태로 노출하지 않는다.

### 3. 독립 `BattleSnapshot` 선택

- P0 `SimSnapshot`의 `FLICKSIM\0`, `SCHEMA_VERSION=1`, 바이트 순서와 골든 해시는 변경하지 않는다.
- P1은 `src/core/battle/battle_snapshot.gd`의 별도 `BattleSnapshot`을 사용한다.
- P1-1 전투 스냅샷의 도메인 prefix는 ASCII **`FLICKBTL\0` 9바이트**, schema version은 **1**이다.
- `BattleSnapshot`은 정규 P0 `SimSnapshot.encode()` 결과를 길이와 함께 포함한다. P0 내부 필드를 다시 전투 계층에서 직렬화하지 않는다.
- 정규 책임은 capture, encode, 길이 제한 decode, restore 네 경계로 분리한다. 내장 P0 바이트를 복원하기 위해 같은 schema를 검증하는 `SimSnapshot` decode 경계를 추가하되 기존 P0 capture·encode 바이트는 바꾸지 않는다.
- 향후 P1-3 체력이나 P1-4 트리거 큐처럼 결정 결과에 영향을 주는 필드가 추가되면 BattleSnapshot schema를 올린다. P0 world 필드가 바뀌지 않으면 P0 schema는 올리지 않는다.
- 알 수 없는 BattleSnapshot 버전, 알 수 없는 내장 P0 버전, 필드 누락·초과·뒤쪽 잉여 바이트는 자동 기본값으로 복원하지 않고 실패한다.
- P1-5 상태 해시는 이 전체 정규 바이트를 SHA-256 입력으로 사용할 수 있다. C-08은 해시 골든과 갱신 절차까지 승인하지 않으며 그 부분은 P1-5에 남긴다.

이 선택으로 `p1_index.md` P1-5의 “P0 schema v1과 분리할지” 미정은 **별도 BattleSnapshot으로 분리**하는 방향으로 해소했고 인덱스 정본에 반영했다.

### 4. schema v1 정규 바이트 순서

모든 다중 바이트 값은 P0와 같은 little-endian 고정 폭이며 bool은 0 또는 1의 `uint8`이다.

| 순서 | 구역 | 필드 |
|---|---|---|
| 1 | 헤더 | `FLICKBTL\0` 9바이트, `battle_schema_version:uint16=1` |
| 2 | 전투 공통 | `phase:uint16`, `current_actor_body_id:uint32`, `abstract_time:int64`, `last_acted_faction:uint16` |
| 3 | 직전/현재 RESOLVE | `normal_resolve_ticks:uint32`, `forced_resolve_ticks:uint32`, `forced_settle_used:uint8` |
| 4 | 참여자 | `count:uint32` 뒤 `body_id` 오름차순 요소 |
| 5 | 내장 월드 | `sim_snapshot_byte_length:uint32` 뒤 P0 `SimSnapshot` 정규 바이트 전체 |

참여자 요소의 필드 순서는 아래와 같다.

| 순서 | 필드 | 폭·계약 |
|---|---|---|
| 1 | `body_id` | `uint32`, 0 금지 |
| 2 | `faction` | `uint16`, C-09 append-only 명시값 |
| 3 | `has_turn` | `uint8` bool |
| 4 | `controllable` | `uint8` bool |
| 5 | `counts_for_victory` | `uint8` bool |
| 6 | `speed_stat` | `uint16`, C-02 저자 범위 50~200 |
| 7 | `ct` | 비음수 `int64` |

- Dictionary, Variant, Object 참조, 문자열, float, 패딩, 플랫폼 기본 `var_to_bytes()`를 사용하지 않는다.
- participant를 캡처 전에 정렬해 입력 순서를 숨기지 않는다. BattleState 자체가 이미 정렬 정본이어야 하며 순서가 틀리면 캡처 실패다.
- P1-1에는 battle 전용 RNG·체력·피해·트리거·승패 결과가 없으므로 v1에 빈 예약 슬롯을 두지 않는다. 후속 권위 필드는 새 schema에서 명시적으로 추가한다.

### 5. 캡처 가능 경계

- `INVALID`를 제외한 `BATTLE_START`, `TURN_START`, `AIM`, `RESOLVE`, `TURN_END`, `CHECK`, `BATTLE_END`에서 캡처할 수 있다.
- RESOLVE에서는 한 step과 post-step 이벤트·mutation 정산이 전부 커밋된 호출 사이에서만 캡처한다. 서브스텝이나 전이 호출 중간은 외부에 노출하지 않는다.
- P0 world pending 생성 요청, C-04 battle pending 요청, 처리되지 않은 P0/전투 이벤트가 하나라도 있으면 캡처에 실패한다.
- 캡처 실패는 미초기화 중립 `BattleSnapshot`을 반환하고 BattleState와 event cursor를 바꾸지 않는다.
- 캡처 성공 뒤 원본 전투를 진행해도 스냅샷 바이트와 스냅샷이 돌려주는 값 사본은 바뀌지 않는다.

### 6. 복원 검증과 교차 불변식

복원은 임시 객체 그래프 전체를 만든 뒤 아래 조건을 모두 확인하고 한 번에 성공 상태를 반환한다.

- magic·schema·길이·정수 범위·bool 값이 정확하다.
- 내장 P0 바이트가 독립 `SimSnapshot` 검증과 복원을 통과한다.
- participant가 body ID 오름차순이고 중복·0이 없으며 각 저장 필드가 C-02와 플래그 계약을 만족한다.
- `has_turn=false` 참여자의 CT는 0이다.
- `BATTLE_START`와 `BATTLE_END`의 현재 행동자 ID는 0이다.
- `TURN_START`와 `AIM`의 현재 행동자는 저장 participant와 복원된 살아 있는 SimBody 양쪽에 존재한다.
- `RESOLVE`, `TURN_END`, `CHECK`의 현재 행동자는 0이 아니다. C-06에 따라 RESOLVE 중 제거된 과거 행동자 ID는 participant·world에 없어도 허용한다.
- 정상 RESOLVE 틱은 0~960, 강제 틱은 0~240이다. `forced_settle_used=true`면 정상 틱은 항상 960이다.
- `forced_settle_used=false`면 강제 틱은 0이다. 강제 틱이 양수면 `forced_settle_used=true`다.
- `forced_settle_used=true`이면서 강제 틱이 0인 전환 직후 상태는 phase가 RESOLVE일 때만 허용한다.
- 모든 현재 participant는 대응하는 살아 있는 SimBody를 가진다. 반대로 발사체·장애물·중립 물체 등 모든 SimBody가 BattleParticipant일 필요는 없다.

- 검증 실패는 미초기화 중립 `BattleState`를 반환하며 부분 world나 participant를 노출하지 않는다.
- 복원 성공 직후 다시 캡처한 바이트는 원본 스냅샷과 완전히 같아야 한다.
- P1-1보다 새 schema로 옮길 때 누락 필드를 0으로 추측하는 자동 migration은 두지 않는다. 필요한 migration은 해당 schema 변경 명세에서 승인한다.

### 7. 결정 상태 포함·제외 요약

| 상태 | 깊은 복제 | BattleSnapshot v1 |
|---|---:|---:|
| phase·현재 행동자·추상 시간·직전 진영 | 포함 | 포함 |
| participant 전체와 CT·속도·플래그 | 포함 | 포함 |
| C-07 RESOLVE 카운터·강제 정산 여부 | 포함 | 포함 |
| SimWorld 전체·RNG·P0 이벤트 cursor | 포함 | 내장 SimSnapshot으로 포함 |
| world·battle pending 요청 | 포함 | 제외, 존재하면 캡처 실패 |
| CTB 예보 | 제외, 재계산 | 제외, 재계산 |
| SimStatus 진단 | 제외 | 제외 |
| UI 드래그·카메라·연출·캐시 | 제외 | 제외 |
| 미래 체력·트리거·승패 결과 | 해당 명세에서 추가 | schema 상승 후 추가 |

### 확정 이유

- 복제에 pending 요청을 포함하면 트랜잭션과 AI 사본이 원본의 다음 장벽 결과를 정확히 재현할 수 있다.
- 정규 스냅샷은 pending이 없는 장벽으로 제한해 “요청 중간 상태”의 직렬화 규격을 영구 호환 계약으로 만들지 않는다.
- P0 바이트를 그대로 내장하면 검증된 물리 직렬화를 중복 구현하지 않고 P0 골든도 보존한다.
- BattleSnapshot을 별도 도메인으로 두면 P1-3·4의 전투 필드 증가가 P0 물리 전용 도구와 AI 사본의 P0 schema를 불필요하게 깨지 않는다.
- 빈 예약 필드 대신 schema를 올리면 새 상태를 해시에서 실수로 누락하거나 오래된 복원기가 조용히 기본값을 채우는 일을 막는다.

### 확정 예시

- AIM 상태 스냅샷을 복원하면 같은 현재 행동자와 미차감 CT로 돌아오며 C-05 예보가 원본과 같다.
- RESOLVE 960/18/true 상태의 스냅샷을 복원하면 다음 호출도 강제 정산 19번째 step을 실행한다.
- 현재 행동자가 RESOLVE 중 제거된 CHECK 스냅샷은 그 ID가 participant에 없어도 복원되고, CONTINUE에서 다음 행동자로 교체된다.
- pending 생성 요청이 있는 깊은 복제본은 원본과 같은 다음 장벽 결과를 내지만, 같은 상태의 BattleSnapshot 캡처는 실패한다.
- BattleSnapshot 안의 P0 구간은 같은 시점의 `SimSnapshot.encode()` 바이트와 정확히 같다.

### 확정 경계 테스트

- 모든 phase에서 깊은 복제 후 원본·사본 독립 진행과 가변 참조 비공유
- world·battle pending 요청이 있는 복제의 동일 정산 결과
- pending·미소비 이벤트가 있는 캡처 실패와 전체 상태 불변
- 허용 phase별 capture→encode→decode→restore→encode 바이트 동일성
- magic·version·길이·bool·enum·ID·정렬·카운터 변조의 개별 실패
- 모든 저장 필드의 단일 변경이 정규 바이트를 바꾸는 민감도 검사
- participant 입력 삽입 순서 교란 뒤 같은 정본 바이트
- RESOLVE 중 현재 행동자 제거 예외와 TURN_START/AIM의 존재 요구
- 내장 P0 바이트 추출값과 독립 SimSnapshot 바이트 일치
- P0 골든·복원 회귀가 수정 없이 그대로 통과

## C-09 확정 · 구현 경계와 최종 수용 규격

2026-08-20 사용자 승인으로 C-01~08을 실제 코드 경계로 옮길 대상 파일, enum, 공개 API와 수용 테스트를 아래처럼 확정했다. 같은 날 문서 전체가 승인되었으며, 구현은 사용자 별도 요청 뒤 시작한다.

### 1. C-04 재승인 보완 확정 · spawn 요청과 BODY_ADDED 상관키

C-04 승인 뒤 P0 구현을 API 수준에서 대조한 결과, 현재 `BODY_ADDED` 이벤트에는 할당된 body ID만 있고 원래 spawn 키가 없다. 참여자 spawn과 발사체 같은 비참여자 spawn이 같은 장벽에 섞이면 어느 요청에 어느 ID가 배정됐는지 전투 계층이 안전하게 연결할 수 없다.

이를 해결하기 위해 C-04를 아래처럼 보완한다.

- 런타임 `BODY_ADDED`는 기존 고정 payload 슬롯에 원래 요청 키를 함께 기록한다.

| SimEvent 필드 | 런타임 BODY_ADDED 의미 |
|---|---|
| `tick` | 요청 tick |
| `source_body_id` | 새로 할당된 body ID |
| `target_body_id` | 원인 body ID |
| `value_a` | 원인 event type ID (`uint16` 범위) |
| `value_b` | event 내 ordinal (`uint32` 범위) |
| `flags` bit 0 | `RUNTIME_SPAWN_KEY_PRESENT` |

- 초기 배치의 BODY_ADDED는 flag 0과 기존 0 payload를 유지한다.
- 전투 pending participant 요청은 `(tick, target_body_id, value_a, value_b)`가 정확히 일치하는 런타임 BODY_ADDED만 소비해 `source_body_id`를 배정한다.
- 일치 요청이 없는 런타임 BODY_ADDED는 발사체·장애물 같은 비참여자 본체로 허용한다.
- 하나의 요청에 이벤트가 없거나 둘 이상이 일치하면 mutation barrier 전체를 원복한다.
- P0 이벤트 레코드의 필드 폭·바이트 순서는 바뀌지 않는다. 기존에 0이던 고정 슬롯에 append-only 의미를 부여하므로 `SimSnapshot` schema v1과 기존 P0 골든은 유지한다.
- `SimWorld.commit_pending_spawns(status)`를 추가해 RESOLVE 밖의 C-06 장벽에서도 tick을 진행하지 않고 정렬·ID 할당·BODY_ADDED 생성을 원자 실행할 수 있게 한다. 기존 `step()`도 같은 내부 경계를 재사용한다.

이 보완은 승인된 CT 0·정렬 키·post-step 장벽 규칙을 바꾸지 않고, 요청과 안정 ID 사이의 누락된 증거만 추가한다. C-09 승인으로 이 C-04 보완도 재승인되었다.

### 2. enum과 상수 명시값

기존 enum 값은 그대로 두고 아래 값만 명시적으로 append한다.

#### BattleParticipant.Faction

| 이름 | 값 |
|---|---:|
| `INVALID` | 0 |
| `PLAYER` | 1 |
| `ENEMY` | 2 |
| `NEUTRAL` | 3 |

- `has_turn=true`와 `counts_for_victory=true`는 PLAYER·ENEMY에만 허용한다.
- `controllable=true`는 PLAYER이면서 `has_turn=true`인 참여자에만 허용한다.
- NEUTRAL은 세 플래그가 모두 false여야 한다.
- PLAYER·ENEMY의 비참여 전투 객체는 `has_turn=false`, `controllable=false`, `counts_for_victory=false`로 둘 수 있다.

#### BattleState

- `Phase`: C-06의 `INVALID=0`, `BATTLE_START=1`, `TURN_START=2`, `AIM=3`, `RESOLVE=4`, `TURN_END=5`, `CHECK=6`, `BATTLE_END=7`.
- `CheckDirective`: `INVALID=0`, `CONTINUE=1`, `END=2`.

#### SimWorld.ContinuousAccelerationMode

| 이름 | 값 |
|---|---:|
| `INVALID` | 0 |
| `APPLY` | 1 |
| `SUPPRESS` | 2 |

기존 `SimWorld.step(status)`는 항상 APPLY를 사용한다. P1 강제 정산만 명시적으로 SUPPRESS를 요청한다.

#### BattleLimits

| 상수 | 값 |
|---|---:|
| `CT_THRESHOLD` | 10,000 |
| `BASE_SPEED_MIN` | 50 |
| `BASE_SPEED_MAX` | 200 |
| `BASE_SPEED_DEFAULT` | 100 |
| `PREVIEW_DEFAULT_COUNT` | 10 |
| `PREVIEW_MAX_COUNT` | 32 |
| `NORMAL_RESOLVE_MAX_TICKS` | 960 |
| `FORCED_RESOLVE_MAX_TICKS` | 240 |
| `FORCED_DAMPING_NUMERATOR` | 3 |
| `FORCED_DAMPING_DENOMINATOR` | 4 |

### 3. SimStatus append-only 진단

기존 마지막 값 `Code.INVALID_SNAPSHOT=17`, `Operation.WORLD_RESTORE=58` 뒤에 아래 값을 추가한다.

#### Code

| 이름 | 값 |
|---|---:|
| `INVALID_BATTLE_STATE` | 18 |
| `INVALID_PHASE` | 19 |
| `NO_ELIGIBLE_ACTOR` | 20 |
| `RESOLVE_DEADLOCK` | 21 |

기존 `INVALID_ARGUMENT`, `INVALID_RANGE`, `DUPLICATE_ID`, `NOT_FOUND`, `UNSUPPORTED_SCHEMA`, `INVALID_SNAPSHOT`은 같은 의미로 재사용한다.

#### Operation

| 이름 | 값 |
|---|---:|
| `SNAPSHOT_DECODE` | 59 |
| `WORLD_COMMIT_SPAWNS` | 60 |
| `WORLD_QUIESCENCE` | 61 |
| `WORLD_STEP_POLICY` | 62 |
| `PARTICIPANT_CREATE` | 63 |
| `CTB_SELECT` | 64 |
| `CTB_PREVIEW` | 65 |
| `BATTLE_CREATE` | 66 |
| `BATTLE_COPY` | 67 |
| `BATTLE_STATE_READ` | 68 |
| `BATTLE_QUEUE_MUTATION` | 69 |
| `BATTLE_MUTATION_BARRIER` | 70 |
| `BATTLE_START_COMPLETE` | 71 |
| `BATTLE_TURN_START_COMPLETE` | 72 |
| `BATTLE_AIM_CANCEL` | 73 |
| `BATTLE_ACTION_COMMIT` | 74 |
| `BATTLE_ACTOR_INTERRUPT` | 75 |
| `BATTLE_RESOLVE_ADVANCE` | 76 |
| `BATTLE_TURN_END_COMPLETE` | 77 |
| `BATTLE_CHECK_APPLY` | 78 |
| `BATTLE_SNAPSHOT_CAPTURE` | 79 |
| `BATTLE_SNAPSHOT_ENCODE` | 80 |
| `BATTLE_SNAPSHOT_DECODE` | 81 |
| `BATTLE_SNAPSHOT_RESTORE` | 82 |

- `INVALID_PHASE`는 `detail_a=actual phase`, `detail_b=단일 expected phase 또는 허용 phase bitmask`를 사용한다.
- `RESOLVE_DEADLOCK`은 `detail_a=최초 blocker body/owner ID`, `detail_b=총 resolve ticks`를 사용한다.
- enum 골든 테스트는 기존 0~58과 새 59~82 전체를 검사한다.

### 4. 대상 파일

#### 새 전투 코어

| 파일 | 책임 |
|---|---|
| `src/core/battle/battle_limits.gd` | C-01·02·05·07 상수와 범위 검사 |
| `src/core/battle/battle_participant.gd` | 불변 참여자, unassigned runtime template, CT 갱신 사본 |
| `src/core/battle/battle_mutation_request.gd` | spawn·제거 안정 키와 선택적 participant template |
| `src/core/battle/ctb_preview_entry.gd` | C-05 불변 예보 항목 |
| `src/core/battle/ctb_scheduler.gd` | C-01·03 순수 선택과 C-05 지역 사본 예보 |
| `src/core/battle/battle_state.gd` | C-04·06·07 장벽, phase, world 소유와 트랜잭션 |
| `src/core/battle/battle_snapshot.gd` | C-08 capture·encode·decode·restore |

#### P0 호환 확장

| 파일 | 변경 |
|---|---|
| `src/core/sim/sim_event.gd` | runtime BODY_ADDED flag와 상관키 payload 계약 |
| `src/core/sim/sim_world.gd` | pending spawn 독립 commit, 가속 APPLY/SUPPRESS step, quiescence 조회 |
| `src/core/sim/sim_status.gd` | 위 append-only Code·Operation |
| `src/core/sim/sim_snapshot.gd` | schema v1 바이트의 길이 제한 decode. 기존 encode 불변 |
| `src/core/README.md` | `sim`과 `battle` 책임·의존 방향 문서화 |

#### 수용 테스트와 독립 참조

| 파일 | 책임 |
|---|---|
| `pipeline/tests/p1_ctb_battle_state_test.gd` | headless 관찰 계약 수용 테스트 |
| `pipeline/tests/run_p1_ctb_battle_state.py` | boundary 검사, 독립 참조, Godot import·테스트 실행 |
| `pipeline/tests/p1_ctb_reference.py` | 작은 정수 CTB·강제 감속·BattleSnapshot Python 참조 |
| `pipeline/tests/fixtures/p1_ctb_vectors.json` | 승인 벡터와 정규 BattleSnapshot bytes |

Godot `.uid` 파일은 import가 생성한 경우 함께 추적하되 명세의 논리 대상 파일로 세지 않는다. P1-1에는 씬·런타임 JSON·이미지·오디오가 없다.

### 5. BattleParticipant 공개 API

- `create(body_id, faction, has_turn, controllable, counts_for_victory, speed_stat, status)`는 CT 0의 초기 참여자를 만든다.
- `create_unassigned(faction, has_turn, controllable, counts_for_victory, speed_stat, status)`는 C-04 runtime spawn template을 만든다.
- `assigned_copy(body_id, status)`는 unassigned template에 안정 ID를 부여하고 CT 0을 유지한다.
- `restore(body_id, faction, has_turn, controllable, counts_for_victory, speed_stat, ct, status)`는 검증된 BattleSnapshot 복원에서만 사용한다.
- `copy()`와 `with_ct(ct, status)`는 새 객체를 반환한다.
- `body_id`, `faction`, 세 flag, `speed_stat`, `ct`는 getter로만 노출하고 setter와 가변 내부 참조는 두지 않는다.

### 6. BattleState 공개 API

정확한 GDScript 인자 타입은 구현에서 정적 표기하며, 아래 이름과 책임을 안정 표면으로 고정한다.

#### 생성·조회·복제

- `BattleState.create(world, participants, status) -> BattleState`
- `is_initialized() -> bool`
- `phase()`, `current_actor_body_id()`, `abstract_time()`, `last_acted_faction()`
- `participant_count()`, `participant_at(index, status)`, `participant_by_body_id(body_id, status)`는 값 사본 반환
- `normal_resolve_ticks()`, `forced_resolve_ticks()`, `forced_settle_used()`
- `world_copy(status) -> SimWorld`; mutable world 원본은 외부에 반환하지 않음
- `copy(status) -> BattleState`
- `preview(count, status) -> Array[CtbPreviewEntry]`

생성은 입력 world와 participant를 깊게 복제한다. world pending 요청이 없고 P0 event cursor가 끝에 있어야 하며, 참여자 중 `has_turn=true`가 하나 이상이어야 한다.

#### mutation 요청

- `queue_body_spawn(body_template, participant_template_or_null, cause_body_id, event_type_id, ordinal, status) -> bool`
- `queue_participant_removal(body_id, cause_body_id, event_type_id, ordinal, status) -> bool`

BattleState가 소유한 world에 대한 런타임 spawn·관리 제거는 이 경계를 사용한다. 요청은 즉시 공개 participant 배열을 바꾸지 않고 C-06 장벽에서만 반영된다.

- spawn과 관리 제거는 하나의 pending 목록에서 `(tick, cause_body_id, event_type_id, ordinal)`로 정렬하며 요청 종류가 달라도 같은 키를 두 번 쓸 수 없다.
- BattleState는 요청 시점에 내부 SimWorld pending 큐를 직접 바꾸지 않는다. 장벽에서 정렬된 요청을 하나씩 처리한다.
- spawn 요청 하나를 SimWorld에 queue한 뒤 즉시 `commit_pending_spawns`해 BODY_ADDED 상관키를 검증하고, 제거 요청은 해당 body 제거와 participant 제거를 같은 항목에서 처리한다. 따라서 혼합 요청의 P0 event sequence도 정렬 키 순서와 같다.
- 장벽 중 하나라도 실패하면 이미 처리한 앞 요청의 world·event cursor·participant 변경까지 모두 원복한다.

#### phase 전이

- `complete_battle_start(status) -> bool`
- `complete_turn_start(status) -> bool`
- `cancel_aim(status) -> bool`
- `commit_launch_velocity(launch_velocity, status) -> bool`
- `commit_forced_no_launch(status) -> bool`
- `interrupt_missing_current_actor(status) -> bool`
- `advance_resolve(status) -> bool`
- `complete_turn_end(status) -> bool`
- `apply_check_directive(directive, status) -> bool`

`commit_launch_velocity`는 P1-2가 계산한 최종 Q47.16 속도만 받는다. P1-1은 normal mode에서 world가 정지했고 pending 작업이 없으며 현재 행동자 속도가 0인지 먼저 검증한다. 새 속도가 0이 아니며 P1 발사 절대상한 2,048 이하이면 현재 행동자 본체 적용, CT 차감, 직전 진영 갱신, RESOLVE 전이를 같은 트랜잭션으로 커밋한다. 드래그·파워·무게 공식과 최소 파워는 P1-2 소유다.

`commit_forced_no_launch`는 battle-rules 계층용이며 UI 어댑터가 노출하지 않는다. `interrupt_missing_current_actor`는 현재 행동자가 실제로 participant 또는 world에서 사라진 경우에만 성공하므로 임의 턴 스킵 우회로가 되지 않는다.

### 7. SimWorld 호환 확장 API

- 기존 `step(status)`의 동작과 바이트 결과는 그대로 유지한다.
- `commit_pending_spawns(status) -> bool`은 tick을 늘리지 않고 현재 pending spawn을 안정 정렬·할당·이벤트 생성한다.
- `step_with_acceleration_mode(mode, status) -> bool`은 APPLY 또는 SUPPRESS를 명시한다. 기존 `step`은 APPLY wrapper다.
- `is_quiescent(mode, status) -> bool`은 비영 속도와 해당 mode에서 유효한 지속 zone 가속을 검사한다. battle pending·event 정산은 BattleState가 추가 검사한다.
- SUPPRESS는 zone의 연속 가속 합만 0으로 취급한다. 마찰·충돌·벽·소멸·이벤트는 바꾸지 않는다.
- C-07의 속도 3/4 사전 감쇠는 BattleState가 임시 world의 body ID 순서로 적용한 뒤 SUPPRESS step을 호출한다.

### 8. BattleSnapshot 공개 API

- `BattleSnapshot.capture(state, status) -> BattleSnapshot`
- `BattleSnapshot.decode(bytes, status) -> BattleSnapshot`
- `is_initialized() -> bool`
- `encode(status) -> PackedByteArray`
- `restore_state(status) -> BattleState`

`SimSnapshot.decode(bytes, status) -> SimSnapshot`도 같은 exact-consumption 규칙을 사용한다. decoder는 선언된 count·길이에 상한을 먼저 검사해 잘린 입력, 과대 할당, trailing bytes를 거부한다.

테스트 전용 필드 변조는 gameplay 공개 setter가 아니라 테스트 파일 안의 byte mutation helper로 수행한다. 프로덕션 snapshot 객체에는 `copy_for_test`나 schema setter를 새로 노출하지 않는다.

### 9. 독립 참조와 fixture 고정

- Python 참조는 C-01 시간 점프·C-03 비교키·C-05 예보·C-07 3/4 반올림·C-08 byte layout을 작은 정수 구현으로 독립 계산한다.
- fixture 생성 전에 코드에 고정한 최소 KAT를 먼저 검사해 구현과 fixture를 동시에 잘못 재생성해도 통과하지 못하게 한다.
- 최소 KAT는 완전 동률 3대3의 `1→4→2→5→3→6`, `ct=9,990/speed=64`의 `10,054→54`, 최대 속도 4,096의 강제 감속 경계, 한 개 participant BattleSnapshot의 전체 hex를 포함한다.
- runner는 구조적 JSON 최초 불일치 path와 expected/actual을 출력하고 `--project`, `--godot`을 지원한다.
- fixture 갱신은 일반 테스트가 수행하지 않는다. C-08 schema 변경 승인 참조가 있는 명시적 update 옵션만 허용하며 전후 byte 길이와 SHA-256을 출력한다.

### 10. 수용 테스트 묶음

#### 정적·enum 계약

- 새 battle 코어가 Node·SceneTree·렌더·입력·내장 물리·비결정 RNG를 사용하지 않음
- Faction·Phase·CheckDirective·ContinuousAccelerationMode·SimEvent flag·SimStatus 숫자 골든
- public participant와 snapshot에 가변 배열·Dictionary·Variant·String payload가 없음

#### C-01~03 스케줄러

- CT 점프를 작은 1틱 참조 루프와 경계·고정 난수 벡터에서 비교
- int64 overflow, 0·범위 밖 속도의 전체 상태 불변 실패
- CT 초과분→속도→진영 교대→body ID 우선순위와 삽입 순서 교란
- 3대3 완전 동률의 확정 순서와 취소·복제 뒤 동일 순서

#### C-04 mutation

- participant·비participant spawn 혼합 순서에서 BODY_ADDED 상관키가 정확한 ID를 연결
- RESOLVE 밖 `commit_pending_spawns`가 world tick을 바꾸지 않음
- post-step BODY_ADDED 뒤 같은 sequence 묶음의 후속 이벤트가 participant를 조회함
- 중복 키·이벤트 누락·중복 상관·없는 body·제거 후 재추가의 장벽 전체 원복
- 새 has_turn participant CT 0, has_turn false CT 고정 0

#### C-05 예보

- count 1·10·32와 0·33 실패
- 권위 상태·world·RNG·pending 불변, 실제 행동 진행과 actor·절대 시점 일치
- 동률 group, 빠른 참여자 반복, mutation barrier 전후 갱신

#### C-06 phase

- 허용 전이와 잘못된 source phase의 전체 교차표
- AIM 취소 무변경, 유효 launch 단 한 번 소비, 강제 무발사와 actor 상실 분리
- 현재 행동자 잠금·RESOLVE 중 제거·CHECK 교체, BATTLE_END terminal
- 모든 실패의 phase·CT·world·pending 원복

#### C-07 RESOLVE

- 0틱 종료, 정상 959·960과 강제 1·240 경계
- 강제 감속 3/4 반올림, zone 가속 억제, 충돌·파괴·이벤트 보존
- 1,200틱 뒤 다음 호출의 `RESOLVE_DEADLOCK`과 최초 blocker 진단
- 원본·복제본의 정상→강제 전환과 최종 상태 일치

#### C-08 복제·스냅샷

- 모든 phase와 pending 상태의 깊은 복제 독립성
- 안정 phase capture→encode→decode→restore→encode 동일성
- 필드 민감도, malformed/truncated/oversized/trailing 입력 거부
- removed current actor 예외와 participant/world 교차 검증
- 내장 P0 bytes 동일성과 기존 P0 골든 무변경

#### 러너·통합

- `run_p1_ctb_battle_state.py`는 Python KAT 뒤 Godot import와 grouped test를 실행하고 최초 실패 case ID·phase·abstract time·body ID·status code/op/details를 출력한다.
- `ARTIFICER_SKIP_GODOT_TESTS=1`은 `verify --skip-godot`이 명시했을 때만 Godot 단계를 건너뛰며 Python·정적 검사는 계속 실행한다.
- `verify --full`이 새 runner를 자동 발견하고 기존 P0 narrow runner와 전체 파이프라인이 그대로 통과한다.
- Windows 실행은 공용 `godot_test_support`를 사용해 전용 로그·격리 profile·timeout tree cleanup 계약을 유지한다.

### 11. 구현 순서

C-09와 명세 전체는 승인되었다. 사용자 별도 구현 요청이 오면 아래 순서로 구현한다.

1. `BattleLimits`, enum·SimStatus append, runtime BODY_ADDED 상관키와 P0 호환 테스트
2. `BattleParticipant`, mutation request, 순수 `CtbScheduler`와 preview
3. `BattleState` 생성·조회·phase 전이와 장벽
4. SimWorld spawn commit·quiescence·SUPPRESS 정책과 C-07 RESOLVE
5. `SimSnapshot.decode`, `BattleSnapshot` capture·codec·restore
6. Python 독립 참조·fixture와 Godot 수용 러너
7. P1-1 narrow → 모든 P0 narrow → Godot 활성 `verify --full`

각 단계는 앞 단계의 테스트가 통과한 뒤 진행한다. 구현 중 새 미정 동작이 드러나면 C-01~09를 조용히 바꾸지 않고 영향·전환 비용과 함께 재승인 제안으로 올린다.

## 최종 대상 파일과 수용 기준

- 대상 파일의 정본은 C-09 4절의 새 전투 코어·P0 호환 확장·수용 테스트와 독립 참조 표다.
- 관찰 가능한 수용 기준의 정본은 C-09 10절의 정적·enum, C-01~08, 러너·통합 묶음이다.
- 구현 순서와 최종 검증 게이트는 C-09 11절을 따른다.

## 필요 에셋

없음. P1-1은 엔진 독립 전투 상태와 headless 테스트만 다룬다.

## 승인 진행

C-01부터 C-09까지의 개별 결정과 이 명세 전체는 2026-08-20 사용자 승인으로 확정되었다. 문서 상태는 `approved`이며 구현 가능 범위가 열렸지만, 이번 요청에 따라 구현은 시작하지 않고 별도 지시를 기다린다.
