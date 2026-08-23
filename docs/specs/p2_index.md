# P2 콘텐츠 기반 명세 인덱스

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-23 |
| approved | 2026-08-23 · 사용자 초안 승인 (`상세 명세로 넘어가자`) |
| phase | P2 · 콘텐츠 기반 |
| 선행 단계 | P0·P1 승인·구현·검증 및 전투 감각 승인 완료 |
| 병렬 단계 | P3 · AI. 단, P2-1·2의 공개 데이터/평가 경계 승인 뒤 본격 결합 권장 |
| 구현 권한 | **하위 명세별 별도 승인 필요.** 이 인덱스 승인만으로 `src/core/` 구현을 시작하지 않음 |

P2는 P1의 결정론적 전투 골격에 콘텐츠 정의, 능력 실행, 상태이상, 시너지, 적·맵·환경 데이터를 연결하는 단계다. 완료 시 **이미 승인·구현된 효과 원자와 조건을 조합하는 새 기물은 런타임 JSON과 필요한 manifest 에셋만 추가해 만들 수 있고, 게임 코드는 수정하지 않는다.**

이 계약은 “앞으로 상상할 수 있는 모든 새 메커니즘을 코드 수정 없이 지원한다”는 뜻이 아니다. 기존 원자로 표현할 수 없는 새 메커니즘은 새 효과 원자 또는 키워드이며, 별도 명세·승인·구현·회귀가 필요하다.

## 설계 정본 참조

- `docs/design/game_design.md` 7.1 태그·시너지, 7.2 트리거, 7.3 효과 원자, 7.4 상태이상
- 7.6 키워드, 7.7 기물 플래그, 7.9 레벨, 7.10 적 재사용
- 8장 맵·환경 요소
- 14장 결정론·레이어·리플레이
- 15장 데이터 스키마
- 16장 검증 계획
- 17장 P2 완료 판정
- 22장 미결 사항 U-01~03, U-10~12, U-20~21, U-24~31, U-36~40과 S-6~12

선행 승인 계약:

- `docs/specs/p1_ctb_battle_state.md`: CTB, phase, mutation barrier, `BattleSnapshot`
- `docs/specs/p1_launch_aim_prediction.md`: 양자화 발사와 조준 제약 확장 경계
- `docs/specs/p1_damage_resolution.md`: 피해 modifier 입력과 연산 순서
- `docs/specs/p1_trigger_bus_battle_result.md`: 트리거 어휘, wave, 처리 한도, RNG 서브스트림
- `docs/specs/p1_batch_sim_graybox.md`: 결정론 fixture, batch, golden, repro 계약

### 정본 정합 메모

- 설계 정본 22.2의 U-23은 아직 미결 표에 남아 있으나, P1-4 T-07에서 전투 효과 RNG 소비 순서가 승인·구현·검증되었다. P2는 T-07을 선행 승인 계약으로 사용한다. 설계 정본의 U-23 표기 정리는 별도 문서 정합 변경으로 처리한다.
- 설계 정본에는 전체 기물 수가 40과 41로 혼재하는 과거 문구가 일부 있다. 현재 상위 표와 7.5 목록의 기준은 41종이지만, P2 최초 콘텐츠 패키지의 수량은 아래 승인 결정 P2-A10에서 별도로 확정해야 한다.

## 목표

1. 런타임 JSON을 엄격하게 읽고 교차 참조를 검증한 뒤, 전투 계층에는 타입이 고정된 불변 정의만 전달한다.
2. P1 트리거 레코드를 콘텐츠 능력과 결합해 조건 판정, 대상 선택, 효과 실행을 결정론적으로 수행한다.
3. 상태이상·패시브·태그 시너지가 같은 modifier 집계 경계를 사용하고 P1 피해·CTB·물리 계약을 침범하지 않게 한다.
4. 기물과 적 버전, 맵 경계·슬롯·존·승인된 환경 요소를 데이터로 생성한다.
5. 능력 실행 중 실패가 발생하면 해당 공개 전이 전체를 롤백하며, 복제·스냅샷·리플레이가 같은 결과를 낸다.
6. 승인된 원자만으로 구성한 새 시험 기물을 JSON에 추가해 코드 변경 없이 회색상자 전투와 batch에서 동작시킨다.

## 범위

### 포함

- 콘텐츠 파일 버전, ID, 타입, 범위, 중복, 참조, 순환 참조 검증
- 기물·능력·상태이상·시너지·적 override·맵·존 정의의 타입화
- P1 트리거 레코드와 능력 등록의 결합
- 조건, 대상 선택, 효과 원자 실행과 연쇄 wave
- 전투 스코프 상태이상, 능력 사용 횟수·쿨다운·카운터
- passive modifier 재평가와 피해·CTB·물리 입력으로의 명시적 전달
- 토큰·발사체·중립 기물·변신·부착 등 승인된 동적 기물 규칙
- P0가 이미 지원하는 벽, 소멸 경계·존, 마찰·가속 존을 이용한 맵 데이터
- 플레이어 기물 정의를 참조하는 적 버전과 명시적 override
- P2 결정 상태의 `BattleSnapshot` 확장, 콘텐츠 지문, 결정론 회귀
- manifest 등록 플레이스홀더를 이용한 P2 회색상자 수동 검수

### 비범위

- P3의 후보 샷 생성, 평가 가중치, AI 등급별 오차, 사고 시간 예산
- P4의 노드맵, 보상, 상점, 유물, 소모품, 덱 관리, 저장, 해금
- D-12/U-11 전투 종료 후 체력·파괴 상태를 `RunState`에 반영하는 규칙
- `GAIN_CURRENCY`의 런 재화 반영과 런 스코프 카운터의 영속화
- 유물·소모품·이벤트·보스·런 전체 encounter 콘텐츠
- U-02·03 승인 전 주기 피해 존, 새 장애물 충돌형, 파괴 가능한 장애물
- 실제 아트·애니메이션·VFX·SE와 최종 수치 밸런싱
- 승인되지 않은 기물 능력을 임시 동작이나 하드코딩으로 대체하는 것

비범위 기능을 데이터에 선언했을 때 조용히 무시하지 않는다. 현재 런타임이 지원하지 않는 원자·트리거·필드는 로드 실패다.

## 용어

| 용어 | 의미 |
|---|---|
| 콘텐츠 정의 | JSON에서 읽어 검증한 기물·능력·상태·시너지·맵의 불변 원형 |
| 콘텐츠 인스턴스 | 전투에 배치되어 `body_id`를 얻은 기물의 런타임 상태 |
| 콘텐츠 카탈로그 | 모든 정의와 ID 교차 참조를 원자적으로 검증한 읽기 전용 집합 |
| 문자열 ID | 저작·진단·manifest 참조에 쓰는 snake_case 식별자 |
| 숫자 ID | 정렬·스냅샷·트리거 invocation에 쓰는 append-only 정수 식별자 |
| 능력 binding | 한 기물 정의가 참조하는 능력과 소유 body의 결합 |
| 효과 원자 | 하나의 결정론적 상태 변경을 표현하는 코드가 아는 최소 연산 |
| 조건 | 능력 invocation의 실행 여부를 판정하는 순수 데이터 규칙 |
| 대상 selector | 현재 트리거 사실과 전투 상태에서 대상 ID 목록을 만드는 순수 규칙 |
| modifier | 기본 정의를 바꾸지 않고 특정 계산 입력에 합성되는 파생 보정값 |
| 콘텐츠 지문 | 정규화한 승인 콘텐츠 집합의 SHA-256 |

## 구현 순서와 하위 명세 경계

| 순서 | 하위 명세 | 상태 | 완료 조건 |
|---|---|---|---|
| 1 | `p2_content_catalog.md` | approved · implemented · verified · 2026-08-23 | JSON I/O와 타입 검증, 안정 ID, 원자적 카탈로그, 콘텐츠 지문 |
| 2 | [`p2_effect_resolution.md`](p2_effect_resolution.md) | **approved · implemented · verified** · 2026-08-23 | 트리거→능력→효과의 고정 순서, 조건·대상·기초 효과 원자, rollback |
| 3 | [`p2_status_synergy_modifiers.md`](p2_status_synergy_modifiers.md) | **approved** · 2026-08-24 | 상태 수명, passive 재평가, 태그 계수, P1 계산 입력 modifier 결합 |
| 4 | `p2_dynamic_piece_mechanics.md` | 미작성 | spawn·projectile·attachment·transform·copy 등 승인된 고급 키워드 |
| 5 | `p2_maps_enemies_environment.md` | 미작성 | 맵·슬롯·존·적 override를 데이터에서 전투 fixture로 구성 |
| 6 | `p2_content_graybox.md` | 미작성 | 승인된 최초 콘텐츠 패키지, data-only 신규 기물 증명, batch·수동 검수 |

```text
P2-1 콘텐츠 카탈로그
  ↓
P2-2 효과 실행
  ↓
P2-3 상태·시너지·modifier
  ├──────────────┐
  ↓              ↓
P2-4 동적 기물   P2-5 맵·적·환경
  └──────┬───────┘
         ↓
P2-6 콘텐츠 회색상자·완료 검증
```

하위 명세는 독립 승인 대상이다. 이 인덱스 승인은 구현 권한이 아니며, 선행 하위 명세가 승인·구현·검증되기 전 후속 핵심 구현을 시작하지 않는다.

## 공통 데이터 계약

아래 내용은 P2-A01~11과 함께 승인된 P2 공통 계약이다. 하위 명세는 이 경계를 구체화하되, 새 근거로 변경이 필요하면 충돌·영향·회귀 범위를 밝히고 다시 승인받는다.

### 1. JSON I/O와 타입 경계

```text
src/core/autoload/data_db.gd
  JSON/FileAccess 사용, 파일별 파싱
        ↓ Dictionary/Array는 이 경계 안에서만 허용
src/core/data/content_catalog_builder.gd
  필드·범위·교차 참조·전체 원자성 검증
        ↓ 타입이 고정된 불변 정의
src/core/battle/
  파일 경로·JSON·Dictionary를 알지 못함
```

- I/O 어댑터만 Godot `FileAccess`·`JSON`을 사용한다.
- `src/core/sim/`과 `src/core/battle/`은 파일을 직접 읽지 않는다.
- 파싱 결과의 Dictionary·Array를 권위 전투 상태나 스냅샷에 저장하지 않는다.
- 모든 파일이 성공한 뒤에만 새 카탈로그를 한 번에 교체한다. 한 파일이라도 실패하면 기존 카탈로그를 유지한다.
- 명시된 optional 필드 외에는 기본값을 추측하지 않는다. unknown key도 실패로 처리한다.

### 2. 파일과 참조 방향

| 파일 | P2 역할 |
|---|---|
| `balance.json` | P1에서 승인된 공통 기준값과 P2 콘텐츠 계수. 코드 안전 상한과 밸런스값을 구분 |
| `pieces.json` | 플레이어·중립·토큰 기물 원형, 스탯·플래그·태그·능력 참조 |
| `abilities.json` | 재사용 가능한 능력 정의, 트리거·조건·대상·효과 배열 |
| `statuses.json` | 상태이상 정의, 중첩·지속·해제·modifier·트리거 참조 |
| `synergies.json` | 태그별 계수 규칙과 효과 정의 |
| `projectiles.json` | 발사체·부착물처럼 특수 플래그를 가진 기물 원형 |
| `enemies.json` | 플레이어 기물 기준 ID와 허용된 적 override |
| `maps.json` | 경계, 슬롯, 존, 장애물 참조 |

`abilities.json` 분리를 권장한다. 설계 정본 15.1의 embedded ability 예시는 단순하지만, 복사·변신·적 재사용에서 능력 정체성을 안정적으로 참조하려면 독립 정의가 유리하다. embedded 구조를 유지할지는 P2-A04 승인 항목이다.

P4 소유 파일인 `relics.json`, `consumables.json`, `encounters.json`, `acts.json`, `events.json`, `unlocks.json`, `disguises.json`은 P2에서 생성하거나 빈 schema로 선점하지 않는다.

### 3. 안정 ID와 schema

- 각 파일은 최상위 `schema_version` 정수를 가진다.
- 기물·능력·상태·시너지·맵은 문자열 ID와 명시적 숫자 ID를 함께 가진다.
- 숫자 ID는 namespace별 uint32, 0은 무효, 한번 배정한 값은 의미를 바꾸거나 재사용하지 않는다.
- JSON 배열 순서와 파일 로드 순서는 의미가 없다. 검증 후 숫자 ID 오름차순으로 정규화한다.
- 문자열 ID는 진단·저작·manifest 연결에 사용하고, 권위 정렬과 스냅샷에는 숫자 ID를 사용한다.
- 참조 대상은 문자열 ID와 숫자 ID가 같은 정의를 가리키는지 교차 검증한다.
- enum 숫자는 기존 P0·P1과 동일하게 append-only다.

새 콘텐츠를 문자열 정렬 순번으로 자동 번호화하는 안은 기존 콘텐츠에 앞서는 ID 하나를 추가할 때 모든 숫자 ID가 바뀌므로 권장하지 않는다.

### 4. 수치 표현

- JSON number는 정수만 허용한다. 부동소수점 literal과 문자열 수식은 금지한다.
- 물리량·비율은 이름으로 단위를 드러낸다: `*_raw`, `*_basis_points`, `*_ticks`, `*_turns`.
- Q47.16 값은 raw int64로 저장하고 P0 `FixMath` 범위 검증을 통과해야 한다.
- 확률은 0~10,000 basis points 또는 명시적 정수 분수만 사용한다. P1 T-07의 0%·100% 무소비 계약을 유지한다.
- 코드 안전 한도를 벗어난 값은 clamp하지 않고 데이터 로드 실패다.
- U-36~40의 미정 밸런스값은 하위 콘텐츠 명세 승인 전 임의로 채우지 않는다.

### 5. 콘텐츠 지문

- 성공한 카탈로그는 타입 정의를 고정 순서로 정규 인코딩하고 SHA-256 지문을 계산한다.
- `BattleSnapshot`과 P2 fixture·repro는 사용한 콘텐츠 지문을 보존한다.
- 다른 지문의 카탈로그로 snapshot을 복원하면 추측 migration 없이 `CONTENT_FINGERPRINT_MISMATCH`로 실패한다.
- 지문은 회귀·호환 검사용이며 RNG 시드, 콘텐츠 숫자 ID, 게임 판정에는 사용하지 않는다.

## 공통 런타임 상태 모델

### 정의와 인스턴스 분리

콘텐츠 정의는 전투 중 바뀌지 않는다. 전투에서 변하는 값은 `body_id`를 키로 한 별도 콘텐츠 인스턴스 상태가 소유한다.

| 상태 | 소유 | 예 |
|---|---|---|
| 원형 정의 | `ContentCatalog` | 기본 스탯, 태그, 능력 목록, 플래그 |
| 물리 상태 | `SimWorld` | 위치, 속도, 질량, 반지름, 마찰, 존 |
| CTB 상태 | `BattleParticipant` | faction, CT, speed, turn/controllable 플래그 |
| 피해 상태 | `BattleCombatant` | 현재·최대 HP, 공격력, 크리티컬 |
| P2 콘텐츠 상태 | 별도 typed state | piece numeric ID, level, 상태 목록, 능력 횟수·쿨다운, 카운터, 변신 원형, 링크 |

- 기본 정의를 mutation하지 않는다. 유효 스탯은 정의 + 레벨 + passive + 상태 + 시너지에서 순수 파생한다.
- 하나의 값이 여러 기존 객체에 중복 저장되어 서로 어긋나지 않도록, 각 하위 명세가 정본 소유자와 projection barrier를 명시한다.
- P2의 전투 스코프 상태는 `BattleSnapshot` 새 schema에 정규화해 포함한다.
- 런 스코프 카운터와 전투 종료 후 체력 처리는 P4 `RunState` 소유다. P2에서는 데이터 필드 존재를 선점하거나 임시 저장하지 않는다.

### modifier 재평가 barrier

P1 T-01을 이어 다음 시점에만 passive·태그·상태에서 유효 modifier를 다시 계산한다.

- 전투 시작 콘텐츠 인스턴스 생성 완료 뒤
- spawn/remove commit 뒤
- 상태 적용·해제·중첩 변경 뒤
- 변신 commit 뒤
- 레벨·태그가 바뀌는 승인된 mutation 뒤

물리 서브스텝 중 Dictionary를 다시 훑거나 매 프레임 재평가하지 않는다. `ON_MOVING` 효과는 트리거 실행이며 passive 재평가와 구분한다.

## 능력 실행 파이프라인

P1-4에서 예약한 순서를 그대로 확장한다.

```text
BattleTriggerRecord.sequence
  → owner body_id 오름차순
  → ability numeric ID 오름차순
  → condition index 오름차순
  → target body/zone ID 오름차순
  → effect index 오름차순
  → 새 사실은 다음 trigger wave
```

- 능력 배열의 저작 순서는 `effect index`로 보존하되, 능력끼리의 순서는 숫자 ID가 정본이다.
- 조건과 대상 selector는 등록된 enum + 정수 인자만 사용한다. 임의 GDScript 경로, 스크립트 문자열, 자유 수식 DSL은 허용하지 않는다.
- selector가 여러 대상을 반환하면 body ID 또는 zone ID 오름차순으로 정렬한다. 거리·최대 HP 같은 선택 기준과 동률 해소는 P2-2에서 각각 명시한다.
- 한 effect가 만든 충돌·피해·파괴·상태 변화는 현재 handler에 재진입하지 않고 다음 P1 trigger wave로 들어간다.
- P1의 wave 32, transition당 record 4,096 한도를 유지한다. 효과·대상 수의 추가 안전 한도는 P2-2에서 최악 fixture와 함께 승인한다.

### 트리거 범위

P2-2 첫 구현은 P1에서 승인된 아래 어휘만 사용한다.

`PASSIVE`, `ON_BATTLE_START`, `ON_TURN_START`, `ON_LAUNCH`, `ON_HIT_DEAL`, `ON_HIT_TAKE`, `ON_ALLY_COLLIDE`, `ON_WALL_BOUNCE`, `ON_MOVING`, `ON_DEATH_SELF`, `ON_KILL`, `ON_TURN_END`, `ON_BATTLE_END`

설계 정본의 후보인 `ON_ZONE_ENTER`, `ON_STOP`, `ON_ALLY_DEATH`가 최초 콘텐츠 패키지에 필요하면 append-only ID, 발생 시점, payload, 우선순위를 P2-2 하위 명세에서 별도 승인한다.

### 효과 원자 분류

| 분류 | 후보 원자 | 승인 경계 |
|---|---|---|
| 기초 전투 | `DAMAGE`, `HEAL`, `KNOCKBACK`, `PULL`, `MODIFY_STAT`, `MODIFY_CT`, `MODIFY_VELOCITY`, `TELEPORT`, `SET_FLAG` | P2-2에서 입력·대상·반올림·실패 원자성 승인 |
| 상태 | `APPLY_STATUS`, `REMOVE_STATUS` | P2-3 상태 수명·중첩 계약 승인 뒤 활성화 |
| 월드 생성 | `SPAWN_ZONE`, `SPAWN_OBSTACLE` | P2-4/5에서 지원 가능한 P0 zone·body 형태만 승인 |
| 동적 기물 | `SPAWN_PROJECTILE`, `SPAWN_PIECE`, `TRANSFORM_PIECE`, `ATTACH` | P2-4의 ID·수명·snapshot·충돌 계약 승인 필요 |
| 행동·입력 | `EXTRA_LAUNCH`, `CONSTRAIN_AIM`, `MID_FLIGHT_INPUT` | CTB·LaunchCommand·리플레이·P3 탐색 영향 별도 승인 필요 |
| 복사·무적 | `COPY_ABILITY`, `SET_INVULNERABLE` | U-12·U-20 선결 승인 필요 |
| 런 상태 | `GAIN_CURRENCY` | P4 `RunState` 소유. P2 런타임에서는 지원하지 않음 |

원자 이름이 설계 정본에 있다는 사실만으로 실행 의미가 승인된 것은 아니다. 하위 명세가 입력 단위, 대상, 순서, 오류, snapshot 범위를 확정한 원자만 JSON에서 허용한다.

## 상태이상·시너지 경계

### 상태 인스턴스 최소 필드 후보

- status numeric ID
- 대상 body ID
- 최초 source body ID
- stack 수
- 남은 대상 턴 수 또는 물리 tick 수 중 승인된 한 종류
- 적용 trigger sequence
- 상태별 runtime counter

정렬 키는 `(target_body_id, status_numeric_id, source_body_id, application_sequence)`를 권장한다. 중첩 시 source를 합칠지 분리할지, 지속시간 갱신 방식, 대상 턴과 전역 턴 중 어느 경계를 쓰는지는 P2-3 승인 항목이다.

### 시너지 계수

- 전투 시작 배치의 비토큰 기물만 계수에 포함한다.
- 중복 기물도 각각 센다.
- 역할군 태그는 기물당 1, 테마 태그는 level만큼 기여한다.
- 토큰은 활성 효과를 받지만 계수에 포함되지 않는다.
- 자기 진영 한정이 기본이며 `체스`만 설계 정본의 승인된 양 진영 적용을 따른다.
- U-11b의 태그 배정과 S-6~12의 개별 효과가 승인되기 전에는 해당 시너지를 production 콘텐츠로 활성화하지 않는다.

### P1 계산 연결

- 피해 보정은 P1 `DamageContext`의 `outgoing_ratio_bonus_raw`, `incoming_ratio_reduction_raw`, `fixed_increase`, `fixed_reduction`에만 전달하고 P1 연산 순서를 바꾸지 않는다.
- CTB 속도 modifier는 유효 speed와 CT 환산 규칙을 P2-3에서 승인한 뒤 적용한다.
- 질량·반지름·마찰·반발 보정은 P0 안전 범위를 재검증하며 조용히 clamp하지 않는다.
- 크리티컬은 P1의 2배·적용 순서를 유지한다. `무법자` 시너지의 추가 50%는 S-9 승인 전 적용하지 않는다.

## 적·맵·환경 경계

### 적 재사용

- 적 정의는 `base_piece_id`로 플레이어 기물 원형을 참조한다.
- override 허용 필드는 하위 명세에서 whitelist로 고정한다. unknown override는 실패다.
- 능력을 그대로 재사용하는 것이 기본이며, 약화·비활성화는 명시적 ability override로만 허용한다.
- `ai_grade`와 `ai_profile`의 의미·값은 P3/U-10 소유다. P2가 임의 등급을 만들지 않는다.
- 설계 정본에서 적 풀 제외가 확정된 5종은 일반 적 데이터로 로드하지 않는다.

### 맵과 환경

- P2-5의 첫 지원 범위는 P0가 이미 검증한 볼록 외곽 경계, `WALL|KILL`, 슬롯, 마찰·가속·KILL 존이다.
- 좌표·존 정점·슬롯은 정수 또는 Q47.16 raw로 저장하고 P0 polygon 검증을 재사용한다.
- 슬롯은 zone/경계 위험 내부, 벽 접촉, 상호 겹침이면 로드 실패다.
- `deploy_count`는 player/enemy 슬롯 수와 D-03의 3~5 범위를 함께 검증한다.
- U-01·02 승인 전 production 맵 목록이나 빙판·모래·독·용암 수치를 만들지 않는다.
- U-03 승인 전 새 정적 장애물 충돌형을 추가하지 않는다. 기존 중립 `SimBody`로 표현 가능한 시험 장애물은 P2-4 승인 범위에서만 사용한다.

## 결정론·RNG·원자성

1. P1 트리거 레코드별 비소비 서브스트림을 재사용한다.
2. 한 record 안에서 능력 숫자 ID→effect index 순으로 RNG를 소비한다.
3. 0%·100%·단일 후보는 RNG draw 0회다.
4. 대상 후보와 random choice 후보는 안정 ID로 정렬한 뒤 추첨한다.
5. AI 사본은 P3 전용 purpose ID를 사용하고 권위 전투 stream을 소비하지 않는다.
6. JSON 배열·Dictionary 순회 순서는 결과에 영향을 주지 않는다.
7. 공개 transition은 원본의 깊은 사본에서 조건·효과·연쇄·결과까지 준비한 뒤 성공 시 한 번에 commit한다.
8. 어느 effect라도 실패하면 HP, CT, 위치·속도, 상태, 카운터, RNG 관찰값, trigger sequence, last batch를 호출 전으로 되돌린다.
9. 성공 반환 시 pending mutation, 미소비 P0 event, 처리 중 trigger wave가 남아 있지 않아야 한다.

## 공개 API 초안

정확한 클래스명과 시그니처는 각 하위 명세에서 확정한다. 다음 책임 경계를 제안한다.

```text
ContentCatalogBuilder.build(parsed_files, status) -> ContentCatalog
ContentCatalog.piece_by_numeric_id(id, status) -> PieceDefinition
ContentCatalog.ability_by_numeric_id(id, status) -> AbilityDefinition
ContentCatalog.status_by_numeric_id(id, status) -> StatusDefinition
ContentCatalog.map_by_numeric_id(id, status) -> MapDefinition
ContentCatalog.fingerprint() -> PackedByteArray

BattleContentFactory.create_battle(catalog, map_id, deployments, seed, status) -> BattleState
AbilityRegistry.bind(catalog, battle_state, status) -> AbilityRegistry
EffectResolver.resolve_trigger_record(state, registry, record, status) -> bool
StatusSystem.apply/remove/advance_at_barrier(..., status) -> bool
SynergySystem.evaluate(state, catalog, faction, status) -> SynergySnapshot
ModifierResolver.for_damage/ctb/physics(..., status) -> typed modifier result
```

- mutable 원본 배열·Dictionary를 반환하지 않는다.
- 조회 실패와 초기화 실패는 `null`/빈 값과 `ContentStatus` 또는 append-only `SimStatus`를 함께 반환한다.
- UI는 정의·상태의 값 사본만 읽고 전투 상태를 직접 수정하지 않는다.

## 오류 계약

### 로드 시 실패

- 파일 누락, JSON parse 실패, schema version 불일치
- unknown/missing key, 잘못된 타입, 부동소수점 수치
- 숫자·문자열 ID 0/빈 값/중복/불일치
- 없는 기물·능력·상태·맵·에셋 참조
- 지원하지 않는 trigger/effect/condition/selector
- 스탯·확률·물리량·배열 길이의 안전 범위 초과
- 금지된 faction/flag 조합, token·neutral 규칙 위반
- 순환 참조가 금지된 transform/copy/spawn 그래프
- 맵 polygon·slot·zone 검증 실패

### 실행 시 실패

- 이미 제거된 필수 대상, 잘못된 phase, 불법 effect 대상
- 안전 범위를 넘는 modifier·속도·질량·HP·CT 결과
- trigger/effect/spawn/상태/링크 처리 한도 초과
- 콘텐츠 지문이 다른 snapshot 복원
- 지원되지 않는 run-scope 효과 호출

모든 오류는 release에서도 관찰 가능해야 한다. first-error-wins를 유지하고, 코드·operation·주요 안정 ID·effect index를 보고한다. `assert`, 조용한 무시, clamp, 부분 적용으로 실패를 숨기지 않는다.

## 대상 파일 초안

실제 생성·수정 목록은 각 하위 명세에서 좁혀 승인한다.

```text
docs/specs/p2_index.md
docs/specs/p2_content_catalog.md
docs/specs/p2_effect_resolution.md
docs/specs/p2_status_synergy_modifiers.md
docs/specs/p2_dynamic_piece_mechanics.md
docs/specs/p2_maps_enemies_environment.md
docs/specs/p2_content_graybox.md

src/core/autoload/data_db.gd
src/core/data/*.json
src/core/data/content_*.gd
src/core/battle/ability_*.gd
src/core/battle/effect_*.gd
src/core/battle/status_*.gd
src/core/battle/synergy_*.gd
src/core/battle/modifier_*.gd
src/core/battle/battle_state.gd
src/core/battle/battle_snapshot.gd
src/core/sim/sim_status.gd

scenes/p2_content_graybox.tscn
src/ui/battle/p2_content_graybox.gd
pipeline/tests/p2_*.gd
pipeline/tests/run_p2_*.py
pipeline/tests/fixtures/p2_*.json
```

`src/core/sim/` 변경은 P0 공개 API로 표현할 수 없는 승인된 동적 물리 규칙이 있을 때만 허용한다. 편의를 위해 P0 내부를 직접 수정하지 않는다.

## 필요 에셋

이 인덱스 초안 자체는 에셋을 생성하지 않는다.

- P2-1~5의 headless 수용은 무에셋으로 가능해야 한다.
- P2-6 회색상자는 가능한 범위에서 기존 P1 manifest 플레이스홀더 3종을 재사용한다.
- 새 기물·상태·존의 시각 구분이 필요하면 P2-6 명세가 정확한 manifest ID, 파일 경로, 글리프·색·규격, `requested_by` 씬 노드를 먼저 승인받는다.
- 새 이미지는 `pipeline/scripts/placeholder_gen.py`, manifest 쓰기는 `pipeline/scripts/manifest.py`만 사용한다.
- 실제 art reskin과 SE attachment는 별도 사용자 요청과 해당 트랙 승인 없이는 수행하지 않는다.

## 수용 기준

### P2-1 · 데이터

1. 모든 runtime JSON은 schema/version/unknown key/type/range/duplicate/reference 검증을 통과해야 로드된다.
2. 파일 하나가 실패하면 카탈로그 전체가 교체되지 않는다.
3. JSON record 순서와 파일 로드 순서를 뒤섞어도 같은 정규 바이트와 콘텐츠 지문을 낸다.
4. 기존 숫자 ID를 유지한 채 새 정의를 추가할 수 있고 기존 정의의 숫자 ID가 바뀌지 않는다.

### P2-2~4 · 전투 콘텐츠

5. 같은 trigger record에서 invocation이 owner body ID→ability ID→effect index→target ID 순으로 실행된다.
6. 효과가 새 trigger를 만들면 다음 wave에서만 처리되고 P1 처리 한도를 넘으면 전체 transition이 롤백된다.
7. 조건 불충족은 성공한 무효과이며 RNG를 소비하지 않는다. 잘못된 데이터·대상은 실패이며 상태가 불변이다.
8. 상태·능력 횟수·쿨다운·변신·링크 등 승인된 P2 결정 상태가 snapshot copy/encode/decode/restore 뒤 동일하다.
9. insertion order 교란과 중간 snapshot 복원 뒤에도 최종 BattleSnapshot 바이트가 같다.
10. P1 피해 modifier 입력을 통해 시너지·상태 보정이 적용되며 P1의 공식 순서와 기준값은 바뀌지 않는다.

### P2-5 · 적·맵·환경

11. 같은 player piece를 참조한 enemy override가 허용 필드만 바꾸고 능력 규칙은 재사용한다.
12. 승인된 map JSON만으로 경계·슬롯·존이 구성되며 잘못된 polygon·겹친 슬롯·위험 영역 슬롯은 로드 실패다.
13. 벽, 소멸 경계·존, 마찰·가속 존이 P0와 같은 판정·정렬을 사용한다.

### P2-6 · 단계 완료

14. 승인된 효과 원자만 조합한 새 시험 기물을 JSON과 필요한 manifest 에셋만 추가해 회색상자 전투에 투입한다. 이 검증에서 `src/core/` 변경은 0개다.
15. 최초 콘텐츠 패키지의 각 능력·상태·시너지·맵 요소가 최소 하나의 positive/negative/boundary fixture를 가진다.
16. 동일 seed·content fingerprint·입력의 1,000회 반복, record 순서 교란, snapshot 복원이 같은 결과와 상태 해시를 낸다.
17. P0·P1 narrow와 신규 P2 narrow가 통과하고 Godot 활성 `pipeline/scripts/verify.py --full`이 통과한다.
18. P2 회색상자에서 사람이 능력 발동 시점, 상태 표시, 시너지 변화, 적 재사용, 맵 위험 표시를 검수한다.

P2 완료는 수용 기준 1~18과 모든 하위 명세의 승인·구현·검증을 요구한다. 특정 승률이나 최종 콘텐츠 밸런스는 P6 범위다.

## 승인 결정 목록 — 승인 완료

아래 결정은 2026-08-23 사용자 초안 승인으로 확정되었다.

| ID | 결정 | 승인안 | 영향 | 상태 |
|---|---|---|---|---|
| P2-A01 | “데이터만으로 신규 기물”의 의미 | 승인·구현된 원자 조합에 한정. 새 원자는 별도 spec/build | 무제한 스크립트 DSL과 하드코딩을 모두 피함 | ✅ 승인 |
| P2-A02 | 하위 명세 분할 | 카탈로그→효과→상태/시너지→동적 기물·맵/적→회색상자 6개 | 승인·회귀 범위를 작게 유지 | ✅ 승인 |
| P2-A03 | 콘텐츠 숫자 ID | JSON에 namespace별 append-only uint32를 명시 | 추가 시 기존 replay/snapshot 정렬 안정 | ✅ 승인 |
| P2-A04 | 능력 저장 구조 | `abilities.json` 독립 정의 + 기물은 ID 참조 | 복사·변신·적 재사용에서 능력 정체성 유지 | ✅ 승인 |
| P2-A05 | 수치 포맷 | 정수만 허용하고 raw/basis_points/ticks/turns로 단위 명시 | 결정론·범위 검증 단순화 | ✅ 승인 |
| P2-A06 | 로더 정책 | unknown key 거부, 전체 파일 원자 로드, 실패 시 기존 카탈로그 유지 | 데이터 오타와 부분 로드 차단 | ✅ 승인 |
| P2-A07 | 콘텐츠 호환 | 정규 SHA-256 지문을 snapshot·fixture에 포함, 불일치 복원 거부 | 데이터 변경 뒤 잘못된 replay 방지 | ✅ 승인 |
| P2-A08 | P2의 런 상태 경계 | 전투 스코프까지만 구현, D-12·재화·영속 카운터는 P4 | U-11 미정 때문에 P2 전체가 막히지 않음 | ✅ 승인 |
| P2-A09 | 첫 맵 기능 범위 | P0가 지원하는 벽/KILL/마찰/가속 존까지. 새 장애물·피해 존은 U-02·03 뒤 | P0 물리 회귀 범위 통제 | ✅ 승인 |
| P2-A10 | 최초 콘텐츠 패키지 | 수량·선정은 P2-6 전에 별도 승인. 미정 기물은 임시 동작 없이 제외 | 41종 전체를 추측 구현하지 않음 | ✅ 승인 |
| P2-A11 | P3 병렬 착수점 | P2-1 카탈로그와 P2-2 평가용 순수 effect 경계 승인 후 | AI가 임시 콘텐츠 구조에 결합되는 재작업 방지 | ✅ 승인 |

## 하위 명세에서 다룰 미정 결정

| 하위 명세 | 선결 또는 동시 승인 항목 |
|---|---|
| P2-1 | rarity 축 U-27, ID namespace·schema 상한, 콘텐츠 지문 포함 범위 |
| P2-2 | 신규 트리거 후보, condition/selector 어휘, 효과·대상 안전 한도, 각 기초 원자의 정확한 단위와 순서 |
| P2-3 | U-11b, S-6~12, U-20~21, U-36~37·40, 상태 중첩·지속·해제 규칙 |
| P2-4 | U-12, U-24~31, U-38~39, spawn 수명, projectile/attachment/transform/copy 계약 |
| P2-5 | U-01~03, 적 override와 U-10의 P2/P3 소유권 경계, 맵·슬롯 수 U-34 |
| P2-6 | P2-A10 최초 기물·적·맵 목록과 수치, 각 placeholder ID, 사람 검수 시나리오 |

## 승인 기록과 다음 경계

P2 전체 구조와 P2-A01~11은 2026-08-23 승인되었다. P2-1은 같은 날 별도 상세 승인 뒤 구현·검증을 완료했다. 하위 명세는 각각 `draft → approved` 절차를 거치며, 하위 명세 승인 전에는 해당 핵심 구현을 시작하지 않는다.

P2-2 `p2_effect_resolution.md`의 P2-E01~12 승인 범위에서 schema v2, typed 실행 정의, binding, 6개 원자, next-wave, 원자적 resolver, BattleSnapshot v4, wave/record/invocation/application/selector 전 한도와 1,000회 반복 검증을 완료했다. P2-3 `p2_status_synergy_modifiers.md`의 P2-S01~20도 2026-08-24 승인 범위에서 catalog v3, 상태 수명, 동결 시너지 tally, modifier 집계, 세 원자, CTB·피해·물리 연결, BattleSnapshot v5와 전 한도·rollback·1,000회 결정론을 구현하고 Godot 4.6.3 `verify --full` 러너 20종으로 검증했다. 개별 기물 수치와 복사·무적·상태 세부는 명시된 후속 명세 승인까지 미정으로 유지한다.
