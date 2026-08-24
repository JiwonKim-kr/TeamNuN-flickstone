# P2-6 · 최초 콘텐츠 패키지 / 회색상자 완료 검증 명세

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 초안 작성 | 2026-08-24 |
| 승인 | 2026-08-24 · 사용자 P2-G01~16 전체 승인 |
| 선행 단계 | P2-1~5 승인·구현·검증 완료 |
| 구현 권한 | **있음. P2-G01~16 승인 범위** |
| 구현 상태 | **구현·자동 검증 완료 · 사람 플레이 검수 대기** |

## 목적

P2-1~5에서 구현한 콘텐츠 카탈로그, 효과, 상태, 시너지, 동적 기물, 맵·적 조립 경계를 실제 런타임 JSON과 플레이 가능한 회색상자로 한 번에 연결한다.

완료 시 다음을 증명한다.

1. 승인된 기존 원자만 조합한 새 시험 기물이 `src/core/` 변경 없이 런타임 카탈로그와 전투에 들어간다.
2. 첫 기물·능력·상태·시너지·적·맵 패키지가 strict JSON, 안정 ID, 지문, snapshot과 batch 경계를 통과한다.
3. 사람이 능력 발동 시점, 상태 수명, 시너지 변화, 적의 player piece 재사용, 맵 위험 표시를 한 씬에서 확인할 수 있다.
4. P2를 닫기 위해 41종 전체나 최종 밸런스를 임의 확정하지 않는다.

## 정본 참조

- `docs/design/game_design.md`
  - 4.4·4.5: P1 승인 물리·피해 기준
  - 7.1~7.1.3: 바둑돌, 역할/테마 태그, 시너지, 승인 대기 태그 배정
  - 7.4~7.5: 상태와 기물 원문
  - 7.10: player piece를 재사용하는 적 정의
  - 13.1~13.2: 전투 정보와 위험 표시
  - 22장: U-01·02·03·10·11b·34·36~40 미정
- `docs/specs/p2_index.md`: P2-A01~11과 P2-6 수용 기준 15~19
- `docs/specs/p2_content_catalog.md`: strict JSON, append-only ID, 원자 로드, 지문
- `docs/specs/p2_effect_resolution.md`: 조건·selector·효과 실행과 rollback
- `docs/specs/p2_status_synergy_modifiers.md`: 상태 수명, 시너지 계수, modifier
- `docs/specs/p2_dynamic_piece_mechanics.md`: 생성·변신·부착과 snapshot v6
- `docs/specs/p2_maps_enemies_environment.md`: maps/enemies, `BattleSetupBuilder`, snapshot v7
- `pipeline/commands/play.md`: `play spec → 승인 → play build → play test`

## 구현 가능성 점검 결과

설계 정본의 41종 중 현재 원자만으로 원문을 손실 없이 표현할 수 있는 일반 기물은 첫 패키지 기준으로 다음 두 종이다.

| 기물 | 판단 | 근거 |
|---|---|---|
| 바둑돌 | 포함 가능 | 능력 없는 기준점 |
| 병뚜껑 | 포함 가능 | 순수 스탯형 |

풀·얼음·불꽃·슬러지·슬링 샷 등을 지금 production record로 넣으면 각각 미정 시너지, 주기 피해, 상태 전환 조건, 이동 궤적 존, 충돌 횟수 카운터 또는 범위 selector를 새로 확정해야 한다. P2-6은 이 범위를 넓히지 않는다.

대신 P2 인덱스가 요구한 data-only 증명을 위해 **41종 정식 로스터와 분리된 회색상자 검증 전용 기물 1종**을 둔다. 이 레코드는 런타임 `DataDB`의 같은 경로를 사용하되 P4의 영입·해금·encounter 풀에는 들어가지 않는다.

## 포함 범위

- runtime JSON 최초 non-empty 패키지
  - 정식 로스터 level 1 기물 2종
  - 회색상자 검증 전용 level 1 기물 1종
  - 능력 1종, 상태 1종, 시너지 2종, 태그 2종
  - player piece를 참조하는 적 3종
  - KILL 존이 있는 세로형 3대3 시험 맵 1종
- `BattleSetupBuilder`를 쓰는 데이터 구동 P2 회색상자
- 기존 P1 아군·적군·조준 placeholder 3종 재사용
- 고정 seed enemy shot supplier와 사용자 drag launch
- 기물 ID·HP·상태, 진영별 활성 시너지, KILL 존 표시
- content load, positive/negative/boundary, 결정론, snapshot, batch, scene, manifest 검증
- P2 인덱스와 handoff의 상태 갱신

## 비범위

- 41종 전체, 초기 해금 24종, 15~20개 production 맵 목록
- level 2·3 수치와 합성 밸런스
- rarity, 이름 현지화, 영입 가중치, encounter/AI profile
- 풀·얼음·불꽃 등 원문 능력의 축약·대체 구현
- S-6~12, U-02·03·10·11b 전체, U-36~40 전체 해소
- 새 trigger, condition, selector, effect kind, modifier kind 또는 snapshot schema
- 정적 장애물, 주기 피해 존, P3 AI
- 실제 아트·VFX·애니메이션·SE, 최종 전투 밸런스

지원되지 않는 기능은 데이터에서 생략하거나 조용히 무시하지 않는다. 해당 기물 자체를 첫 패키지에서 제외한다.

## 용어

| 용어 | 의미 |
|---|---|
| 정식 로스터 레코드 | 설계 정본 41종에 속하며 후속 콘텐츠 작업에서 유지할 기물 |
| 검증 전용 레코드 | P2 데이터 구동 증명용이며 영입·해금·일반 encounter에서 제외할 기물 |
| 패키지 기준값 | P2 회색상자와 회귀의 승인 기준. P6 최종 밸런스는 아님 |
| 선택 슬롯 | P2 회색상자에서 player 배치 기물 numeric ID를 순환시키는 UI 상태. 전투 밖 로컬 표시 상태이며 snapshot 대상이 아님 |
| 요소 검증 | 능력·상태·시너지·맵 요소별 positive/negative/boundary 검사 |

## 승인 결정안

아래 안은 2026-08-24 사용자 지시로 전체 승인되었다.

| ID | 결정안 | 이유 | 상태 |
|---|---|---|---|
| P2-G01 | 최초 패키지는 정식 `baduk_stone`, `bottle_cap`과 검증 전용 `graybox_striker` 3종으로 제한한다 | 실제 기물 원문을 훼손하지 않으면서 P2-A10과 data-only 증명을 함께 충족 | ✅ 승인 |
| P2-G02 | `graybox_*` 레코드는 runtime catalog에는 존재하지만 41종 로스터 밖이며 P4 영입·해금·encounter가 catalog 전체 열거로 풀을 만들지 못하게 한다 | 별도 test catalog를 쓰면 실제 `DataDB` 연결 수동 검수가 되지 않음. append-only ID 오염은 명시적 training content로 통제 | ✅ 승인 |
| P2-G03 | 모든 namespace의 최초 numeric ID를 아래 표대로 1부터 append-only 배정한다 | 현재 runtime registry가 비어 있어 가장 단순하며 이후 ID 이동을 금지 | ✅ 승인 |
| P2-G04 | 세 기물은 level 1만 등록하고 아래 P1 기준 파생값을 패키지 기준값으로 사용한다. level 2·3은 P6/합성 명세 전까지 없는 레벨로 실패한다 | U-36 전체를 선점하지 않고 플레이 가능한 최소 단위를 만든다 | ✅ 승인 |
| P2-G05 | `bottle_cap`에 `destruction`·`steel`, `graybox_striker`에 `destruction`, `baduk_stone`에 무태그를 부여한다 | 바둑돌 예외와 병뚜껑의 7.1.3 초안을 패키지 범위에서만 채택. U-11b 전체는 미결 유지 | ✅ 승인 |
| P2-G06 | `destruction`과 `steel` 시너지만 production runtime에 활성화하고 정본 7.1.2의 선형 수치를 그대로 저작한다 | 두 효과는 현재 modifier 경계로 정확히 표현 가능. S-6~12를 건드리지 않음 | ✅ 승인 |
| P2-G07 | `graybox_striker`는 전투 시작 시 자기에게 1 대상 턴 동안 speed +25를 주는 `graybox_opening_haste`/`graybox_haste`만 가진다 | 기존 `ON_BATTLE_START`·`APPLY_STATUS`·`TARGET_TURNS`·modifier만으로 발동과 만료를 명확히 관찰 가능 | ✅ 승인 |
| P2-G08 | 적은 세 player piece를 각각 참조하는 3종이며 `enemy_baduk_stone`만 `max_hp=110`으로 override한다 | 무override 상속과 whitelist override를 같은 패키지에서 증명 | ✅ 승인 |
| P2-G09 | 맵은 640×1024 WALL 경계, 위·아래 3슬롯, 중앙 KILL 존 1개인 `graybox_pit_arena` 하나다 | 승인된 P0/P2-5 요소만 사용하고 U-02 환경 수치를 발명하지 않음. production 맵 U-01/U-34는 미결 유지 | ✅ 승인 |
| P2-G10 | 회색상자는 map/piece/enemy numeric ID 순서를 읽어 배치를 만들고 기물 string ID에 따른 동작 분기를 두지 않는다 | 이후 승인 원자로 만든 기물이 JSON 추가만으로 같은 씬 경로에 진입하게 함 | ✅ 승인 |
| P2-G11 | 숫자키 1~3은 각 player 슬롯을 다음 piece ID로 순환하고 즉시 같은 seed로 재시작한다. `R`은 현재 선택 재시작, `Esc`는 조준 취소다 | 별도 덱 UI 없이 시너지 off/2/3과 중복 배치를 빠르게 검수 | ✅ 승인 |
| P2-G12 | enemy 턴은 P1 deterministic shot supplier를 재사용하며 P3 AI로 부르거나 평가하지 않는다 | P2 수동 검수의 진행만 보장하고 P3 소유권을 침범하지 않음 | ✅ 승인 |
| P2-G13 | 새 이미지 없이 P1 placeholder 3종을 재사용하고 manifest `requested_by`만 P2 씬 노드까지 확장한다. 기물·상태·존 구분은 generic Label/Polygon2D/Line2D로 그린다 | 회색상자 목적에 충분하며 별도 art 승인 비용을 만들지 않음 | ✅ 승인 |
| P2-G14 | `scenes/main.tscn`의 기본 실행 대상을 P2 회색상자로 바꾸고 P1 씬은 직접 실행 가능한 상태로 유지한다 | 사용자 플레이 테스트 진입점을 최신 단계로 이동 | ✅ 승인 |
| P2-G15 | 1,000회 결정론 검사는 전체 전투 1,000회가 아니라 고정 3 public transition의 결과 tuple·snapshot hash 반복으로 제한한다. 별도로 16개 seed terminal batch와 중간 snapshot 복원을 수행한다 | P2 수용 의미를 유지하면서 MVP 시간에 맞게 반복 비용을 제한 | ✅ 승인 |
| P2-G16 | 구현 diff는 `src/core/` 0개를 강제한다. 새 core 기능이 필요하면 P2-6을 중단하고 별도 재승인을 요청한다 | P2 단계 완료의 핵심 data-only 계약 | ✅ 승인 |

## 안정 ID 배정

`state_id=1(ACTIVE)`로 등록한다. 한번 승인·배포한 numeric/string pair는 이후 내용이 퇴역해도 재사용하지 않는다.

| namespace | numeric ID | string ID | 분류 |
|---|---:|---|---|
| PIECE | 1 | `baduk_stone` | 정식 로스터 |
| PIECE | 2 | `bottle_cap` | 정식 로스터 |
| PIECE | 3 | `graybox_striker` | 검증 전용 |
| ABILITY | 1 | `graybox_opening_haste` | 검증 전용 |
| STATUS | 1 | `graybox_haste` | 검증 전용 |
| SYNERGY | 1 | `destruction` | 정식 규칙 |
| SYNERGY | 2 | `steel` | 정식 규칙 |
| ENEMY | 1 | `enemy_baduk_stone` | 첫 적 패키지 |
| ENEMY | 2 | `enemy_bottle_cap` | 첫 적 패키지 |
| ENEMY | 3 | `enemy_graybox_striker` | 검증 전용 |
| MAP | 1 | `graybox_pit_arena` | 검증 전용 |
| TAG | 1 | `destruction` | 역할군 |
| TAG | 2 | `steel` | 테마 |

PROJECTILE namespace는 계속 비어 있다.

## 기물 데이터 계약

세 기물 공통 플래그와 동적 필드는 다음과 같다.

- `has_turn=true`, `destructible=true`, `transformable=true`, `counts_for_victory=true`, `is_token=false`
- `spawnable=false`, `spawn_faction_mode_id=1`
- `expire_kind_id=1`, `expire_value=0`
- `attach_anchor_mode_id=1`, anchor offset `(0,0)`
- level record는 level 1 하나만 둔다.

### level 1 기준값

| piece | HP | 공격 | speed | 무게 | 반지름 | 마찰 배율 | 치명타 | 능력 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `baduk_stone` | 100 | 20 | 100 | 64 | 32 | 1.0 | 0 bp | 없음 |
| `bottle_cap` | 90 | 24 | 100 | 56 | 32 | 1.0 | 0 bp | 없음 |
| `graybox_striker` | 100 | 20 | 100 | 64 | 32 | 1.0 | 0 bp | `graybox_opening_haste` |

Q47.16 raw는 무게 64=`4194304`, 무게 56=`3670016`, 반지름 32=`2097152`, 마찰 1.0=`65536`이다.

`bottle_cap`의 HP −10, 공격 +4, 무게 −8은 「조금 높은 공격력, 가벼움, 약간 낮은 체력」을 검수할 수 있는 첫 기준값일 뿐 최종 밸런스가 아니다. P6 변경 시 ID는 유지하고 content fingerprint와 golden을 승인 참조로 이관한다.

## 능력·상태 계약

### `graybox_opening_haste`

- `trigger_id=2(ON_BATTLE_START)`
- condition 없음
- effect 1개
  - `kind_id=10(APPLY_STATUS)`
  - selector `OWNER(1)`, `relation_id=0`, `limit=0`
  - `value_a=1(graybox_haste)`, `value_b=1`, `operation_id=0`
- RNG draw와 새 trigger record가 없다.

### `graybox_haste`

- `SINGLE`, `max_stacks=1`
- `TARGET_TURNS`, `default_duration=1`, `max_duration=1`, `KEEP`
- `merge_sources=true`
- modifier: `SPEED_STAT`, `ADD`, `FLAT`, `value=25`
- `BattleSetupBuilder.build()`가 완료되면 striker의 유효 speed는 125다.
- striker 자신의 첫 `TURN_END` 완료 barrier에서 만료되고 유효 speed는 base 100으로 돌아간다.
- 이 상태는 정식 41종의 능력·상태 이름이나 수치를 확정하지 않는다.

## 태그·시너지 계약

### 태그 배정

| piece | 역할 태그 | 테마 태그 |
|---|---|---|
| `baduk_stone` | 없음 | 없음 |
| `bottle_cap` | `destruction` | `steel` |
| `graybox_striker` | `destruction` | 없음 |

이는 P2 패키지 세 record에만 적용한다. 7.1.3 전체 표와 역할 분포 U-11b는 승인된 것으로 간주하지 않는다.

### 시너지 정의

| synergy | kind/scope/cap | min 2부터 누적 modifier |
|---|---|---|
| `destruction` | ROLE / OWN_FACTION / 5 | `DAMAGE_OUTGOING_RATIO_BONUS`, ADD, SCALED, `+1000 bp × n` |
| `steel` | THEME / OWN_FACTION / 8 | `DAMAGE_FIXED_REDUCTION`, ADD, SCALED, `+2 × n`; `MASS_RAW`, ADD, SCALED, `+327680 × n` |

각 정의는 `min_count=2` tier 하나를 갖는다. SCALED가 동결된 유효 계수 `n`을 곱하므로 정본의 선형 누적과 일치한다.

기본 player 배치 `[baduk_stone, bottle_cap, graybox_striker]`는 `destruction=2`, `steel=1`이다. 두 번째 슬롯을 두 번 순환하면 `[baduk_stone, baduk_stone, graybox_striker]`가 되어 활성 시너지가 사라진다. 첫 번째 슬롯을 한 번 순환하면 `[bottle_cap, bottle_cap, graybox_striker]`가 되어 `destruction=3`, `steel=2`가 된다.

## 적 데이터 계약

| enemy | base piece | override |
|---|---|---|
| `enemy_baduk_stone` | `baduk_stone` | `max_hp=110` |
| `enemy_bottle_cap` | `bottle_cap` | 없음 (`{}`) |
| `enemy_graybox_striker` | `graybox_striker` | 없음 (`{}`) |

- enemy는 base piece의 태그·플래그·능력을 그대로 재사용한다.
- `enemy_graybox_striker`도 battle start haste를 받고 자기 첫 턴 종료에 잃는다.
- 기본 enemy 배치는 numeric ID 1, 2, 3 오름차순이다.
- `ai_grade`나 `ai_profile`은 추가하지 않는다.

## 맵 데이터 계약

`graybox_pit_arena`는 P1 세로 플레이테스트 배치를 데이터로 옮긴 시험 맵이다. production 맵 목록 U-01이나 표준 판 크기 U-34의 일반 결론이 아니다.

- `boundary_type_id=1(WALL)`
- 경계: `(0,0) → (640,0) → (640,1024) → (0,1024)`
- `deploy_count=3`
- player 슬롯: `(160,832)`, `(320,832)`, `(480,832)`
- enemy 슬롯: `(160,192)`, `(320,192)`, `(480,192)`
- 중앙 KILL 존 `local_id=1`
  - 사각형 `(224,464) → (416,464) → (416,560) → (224,560)`
  - `flags=1`, 마찰 `65536`, 가속 `(0,0)`
- `obstacles=[]`

| 값 | raw |
|---|---:|
| 경계 640×1024 | `41943040 × 67108864` |
| 슬롯 x 160/320/480 | `10485760 / 20971520 / 31457280` |
| 슬롯 y 832/192 | `54525952 / 12582912` |
| KILL x 224/416 | `14680064 / 27262976` |
| KILL y 464/560 | `30408704 / 36700160` |

맵 존은 반투명 적색 fill, 적색 border, 중앙 `KILL` text로 표시한다. 판정은 JSON polygon과 P0 `SimZone`이 정본이며 렌더 도형은 같은 좌표를 복사한 표시일 뿐이다.

## 회색상자 씬 계약

### 초기화

1. autoload `DataDB`의 catalog copy를 얻는다. 실패하면 오류를 HUD에 표시하고 멈춘다.
2. 첫 map numeric ID와 map의 `deploy_count`를 읽는다.
3. player와 enemy 정의를 numeric ID 오름차순으로 각 3개 선택한다.
4. 고정 seed `0x12345678 / 0x2468ACE0`과 `BattleSetupBuilder.build()`로 상태를 만든다.
5. 별도 fixture state나 P1 하드코딩 body 생성으로 fallback하지 않는다.

### 표시

- P1 P/E placeholder로 진영을 표시하고 현재 actor는 노란 tint를 적용한다.
- 각 body에 catalog의 `piece.string_id`, current/max HP, level을 text로 표시한다.
- 상태가 있으면 status string ID와 남은 값/stack을 body 옆에 표시한다.
- HUD에 player/enemy별 활성 tag string ID와 동결 계수를 표시한다.
- HUD에 `BattleState.preview()`의 다음 6개 body ID를 표시해 opening haste의 CTB 영향을 확인할 수 있게 한다.
- KILL/마찰/가속 존은 kind별 generic 색상 규칙으로 표시한다.
- 문자열 ID별 texture, 색, 능력 연출 분기는 두지 않는다.

### 입력과 진행

- player AIM: 현재 actor drag/release와 비동기 trajectory prediction을 P1 adapter로 재사용한다.
- enemy AIM: P1 deterministic shot supplier가 즉시 command를 만든다.
- `1`, `2`, `3`: 해당 player 선택 슬롯의 piece를 numeric ID 순으로 다음 레코드로 순환하고 같은 seed로 재시작한다.
- `R`: 현재 선택과 같은 seed로 재시작한다.
- `Esc`: 조준을 취소한다.
- 전투 종료 뒤 자동 재시작하지 않는다.

## 결정론·snapshot·batch 계약

P2-G15의 1,000회 검증 단위는 다음처럼 제한한다.

1. runtime catalog를 로드하고 기본 배치 state를 만든다.
2. deterministic supplier가 만든 command로 정확히 3개 public transition을 수행한다.
3. 각 반복의 `(phase, current_actor_body_id, battle_result, trigger_record_count, fingerprint, BattleSnapshot bytes SHA-256)` tuple을 기준 1회와 비교한다.
4. 500번째 반복은 첫 transition 뒤 snapshot encode/decode/restore를 거쳐 같은 tuple이 되는지 확인한다.
5. 별도 reordered fixture는 namespace별 record 배열을 뒤집어도 같은 fingerprint와 tuple을 내야 한다.

전체 terminal 전투는 1,000회 반복하지 않는다. 대신 고정 16개 seed를 기본 배치와 stacked 배치 각각에 실행해 result, turn, sim tick, terminal snapshot hash를 CSV/golden으로 고정한다. snapshot restore case는 각 배치 최소 1개 seed를 포함한다.

## 오류 계약

- 새 오류 코드나 operation은 추가하지 않는다.
- strict JSON·참조·범위·map geometry 실패는 기존 `ContentStatus`를 그대로 보고하고 catalog를 교체하지 않는다.
- battle setup, effect, snapshot 실패는 기존 `SimStatus` first-error-wins와 transition rollback을 유지한다.
- 회색상자는 `code/operation`을 HUD에 표시하고 입력·자동 진행을 멈춘다.
- 없는 레벨, map, piece, enemy를 기본값으로 대체하지 않는다.
- KILL 존 표시 생성 실패가 물리 존 부재로 이어지는 것처럼 보이게 하지 않는다. 표시 초기화 실패도 scene smoke 실패다.

## 요소별 fixture

| 요소 | positive | negative | boundary |
|---|---|---|---|
| catalog/ID | runtime package 로드·exact ID | 중복/누락/retired ref 거부 | record 순서 역전 시 같은 fingerprint |
| 능력 | battle start에 owner 상태 1개 | 다른 body에는 부여되지 않음 | battle start 재호출 불가/중복 상태 없음 |
| 상태 | 유효 speed 125 | 없는 상태 제거는 성공한 무효과 | 첫 대상 TURN_END 직전 유지, barrier 뒤 만료 |
| destruction | count 2에서 +20% | count 1에서 비활성 | count 5 cap에서 +50% |
| steel | count 2에서 피해 −4·무게 +10 | count 1에서 비활성 | count 8 cap과 물리 strict 상한 |
| enemy | base 능력·태그 상속, HP override | unknown override key 거부 | override radius가 catalog max radius가 됨 |
| map/KILL | 3대3 build·zone kill | slot이 KILL 내부면 거부 | 벽 거리 `max_radius+1 raw` 성공, `max_radius raw` 실패 |
| deployment | first 3 records로 body ID 1~6 | 인원/side/ref/slot 오류 거부 | 중복 기물 3개와 마지막 유효 slot |
| snapshot | v7 restore 동일 | fingerprint mismatch 거부 | 0/최대 상태·tally 경계 기존 회귀 재사용 |

경계용 count 5/8, radius override, slot은 test fixture에만 만든다. runtime 패키지 수치를 바꾸지 않는다.

## 수용 기준

1. runtime 8개 JSON이 최초 non-empty 패키지와 정확한 schema `catalog v5 / registry v1 / pieces v3 / abilities v5 / statuses v1 / synergies v1 / maps v1 / enemies v1`을 로드한다.
2. append-only ID 표와 canonical fingerprint가 Godot와 독립 reference에서 일치한다.
3. 기본·off·stacked 배치가 예상 시너지 계수와 modifier를 낸다.
4. `graybox_opening_haste`가 battle start에 정확히 1회 발동하고 자기 첫 turn end에 만료된다.
5. 세 enemy가 base piece 정의를 재사용하며 허용 override만 적용한다.
6. map JSON만으로 WALL, 3+3 슬롯, KILL 존이 구성되고 표시와 판정 좌표가 일치한다.
7. runtime package record 순서와 fixture 파일 로드 순서를 바꿔도 fingerprint·전투 tuple·hash가 같다.
8. 1,000회 제한 반복과 16-seed terminal batch가 통과한다.
9. snapshot 중간 복원 전후 terminal result·turn·tick·hash가 같다.
10. `src/core/` diff가 0개이며 scene/controller/test가 string ID별 전투 동작을 하드코딩하지 않는다.
11. P0·P1 관련 narrow, P2-1~6 narrow가 통과한다.
12. 구현 반복 중에는 `P0_ALLOW_QUICK=1`, `P0_REPEAT_COUNT=20`, `P0_PERMUTATION_COUNT=3`, `FLICKSTONE_P2_CONTENT_PROFILE=quick` + Godot 활성 `verify.py --full`을 사용한다. P2 단계 종료 기록에는 P2-6 자체 1,000회와 `--profile milestone` 16×2 결과를 남긴다. P0 exhaustive 1,000-case는 milestone/CI gate로 유지한다.
13. main scene smoke와 manifest 정합성이 통과한다.
14. 사람이 아래 검수 시나리오를 승인한다.

## 사람 검수 시나리오

1. 기본 실행 직후 player/enemy striker에 `graybox_haste`가 표시되고 유효 speed 변화가 턴 순서에 반영되는지 본다.
2. striker의 첫 행동을 완료한 뒤 해당 상태가 사라지는지 본다.
3. 기본 배치에서 `destruction=2`, 숫자키로 `[baduk,baduk,striker]`를 만들었을 때 비활성, `[bottle,bottle,striker]`에서 `destruction=3`·`steel=2`가 표시되는지 본다.
4. player와 enemy의 같은 base piece ID가 진영 placeholder만 다르게 사용되고 enemy 바둑돌 HP만 110인지 본다.
5. 중앙 적색 KILL 존의 표시와 진입 제거가 일치하는지 본다.
6. drag, trajectory, launch, enemy 자동 진행, `Esc`, `R`, 숫자키 재배치를 확인한다.
7. 체감 승률·최종 밸런스가 아니라 발동 시점·표시·데이터 재사용만 판정한다.

## 대상 파일

### 신규

```text
docs/specs/p2_content_graybox.md
scenes/p2_content_graybox.tscn
src/ui/battle/p2_content_battle_driver.gd
src/ui/battle/p2_content_graybox.gd
pipeline/tests/p2_content_graybox_test.gd
pipeline/tests/run_p2_content_graybox.py
pipeline/tests/p2_content_graybox_reference.py
pipeline/tests/fixtures/p2_content_graybox/
pipeline/tests/fixtures/p2_content_graybox_goldens.json
```

### 수정

```text
docs/specs/p2_index.md
HANDOFF.md
src/core/data/id_registry.json
src/core/data/pieces.json
src/core/data/abilities.json
src/core/data/statuses.json
src/core/data/synergies.json
src/core/data/maps.json
src/core/data/enemies.json
scenes/main.tscn
pipeline/manifest.json     # manifest.py만 사용
```

### 변경 금지

```text
src/core/**/*.gd           # 승인된 runtime JSON은 위 수정 목록에 포함
assets/art/**              # 기존 placeholder 파일 재사용
project.godot
```

테스트 구현 중 fixture 수를 줄일 수 있으면 디렉터리/파일 수는 축소할 수 있지만, 요소별 positive/negative/boundary 의미와 독립 fingerprint 비교는 줄이지 않는다.

## 필요 에셋

신규 파일 없음.

| manifest ID | 재사용 파일 | P2 requested_by 추가 |
|---|---|---|
| `art:sprites/p1_graybox_player_piece` | `assets/art/sprites/p1_graybox/PLACEHOLDER_player_piece.png` | `scenes/p2_content_graybox.tscn::Battlefield/Pieces` |
| `art:sprites/p1_graybox_enemy_piece` | `assets/art/sprites/p1_graybox/PLACEHOLDER_enemy_piece.png` | `scenes/p2_content_graybox.tscn::Battlefield/Pieces` |
| `art:ui/p1_graybox_aim_marker` | `assets/art/ui/p1_graybox/PLACEHOLDER_aim_marker.png` | `scenes/p2_content_graybox.tscn::Battlefield/AimLayer` |

manifest 변경은 `pipeline/scripts/manifest.py`의 지원 동작만 사용한다. 직접 JSON 편집은 금지한다.

## 구현 순서 — 전체 승인 뒤 적용

1. runtime registry와 7개 record JSON에 승인 패키지를 추가하고 독립 fingerprint KAT를 만든다.
2. 요소별 positive/negative/boundary narrow를 추가한다.
3. generic P2 graybox controller/scene을 만들고 main scene을 전환한다.
4. `manifest.py`로 기존 placeholder의 P2 `requested_by`를 등록한다.
5. 1,000회 제한 결정론, 16-seed terminal, reorder, snapshot restore를 검증한다.
6. 관련 narrow 뒤 quick-profile Godot 활성 `verify.py --full`과 scene/manifest smoke를 실행한다.
7. 사람이 검수한 뒤 문서·P2 index·handoff에 승인/구현/검증 기록을 남긴다.

## 승인 기록

2026-08-24 사용자가 P2-G01~16 전체를 한 묶음으로 승인했다. 특히 다음 세 영향도 승인 범위에 포함한다.

1. append-only runtime ID를 쓰는 `graybox_*` 검증 전용 레코드를 남긴다.
2. U-11b 전체가 아니라 `bottle_cap` 한 종의 태그만 부분 채택한다.
3. P2-6 1,000회는 3 public transition 반복으로 제한하고 terminal은 16 seed로 분리한다.

이 승인으로 runtime JSON, scene, manifest, test code 구현 권한이 열렸다. 구현 중 `src/core/` 변경 필요가 발견되면 P2-G16에 따라 중단하고 다시 승인받는다.

## 구현·자동 검증 기록

2026-08-24 승인 범위의 구현과 자동 검증을 완료했다. 사람 플레이 검수 시나리오 1~7은 아직 별도 승인 대기다.

- runtime 8개 JSON에 정식 `baduk_stone`, `bottle_cap`, 검증 전용 `graybox_striker`, 능력·상태 각 1종, 시너지 2종, 적 3종, 맵 1종을 등록했다. canonical fingerprint는 `f721ffce47ff27324a92dd8c9564e75463113fd5adb10ee7ebb388889511cf0e`다.
- `BattleSetupBuilder`와 기존 P2 resolver를 합성하는 generic UI 전투 어댑터 및 세로형 P2 회색상자를 추가했다. 콘텐츠 문자열 ID별 분기와 `src/core/**/*.gd` 변경은 0개다.
- 기존 P1 placeholder 3종의 P2 소비 지점은 `manifest.py add-requested-by`로만 등록했다. 이 명령은 성공·중복 멱등·없는 ID 파일 불변을 파이프라인 테스트로 고정했다.
- 독립 Python positive/negative/boundary·canonical reorder 검사, Godot 16개 기능 그룹, 1,000회 3-public-transition 결정론이 통과했다.
- `quick`은 두 프리셋의 seed 0과 snapshot 복원을 검사한다. `milestone`은 기본·stacked 각 16시드와 복원 대조, 체크인 골든 32행을 검사하며 전부 통과했다.
- 기본 16시드는 모두 적 승리·5턴·1,644틱, stacked 16시드는 모두 적 승리·16턴·7,794틱으로 종료했다. seed별 terminal hash와 중간 snapshot 복원 결과가 일치했다.
- Godot 4.6.3 `play_test.py`의 import·main scene smoke·manifest 3단계와 quick-profile `verify.py --full`이 통과했다. 통합 결과는 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 자동 발견 러너 23종 PASS다.

## 2026-08-24 플레이테스트 보정 승인

사용자가 조작감 확인 뒤 다음 P2 회색상자 표시·진행 보정을 승인했다.

1. 적 AIM 진입 뒤 실제 발사까지 최소 600ms를 기다린다. 연속 적 턴도 발사마다 다시 기다리며, 이 시간은 UI 연출 상태일 뿐 BattleState·snapshot·batch 결과에 포함하지 않는다.
2. HUD에 RESOLVE 정상/강제 정산 tick과 현재 최대 본체 속도를 표시해 드문 진행 지연을 관찰할 수 있게 한다.
3. 다양한 양자화 각도·파워와 벽 모서리 경로가 기존 960+240 tick 예산 안에서 TURN_END에 도달하는 회귀를 추가한다. `RESOLVE_DEADLOCK`을 자동 턴 넘김으로 숨기지 않는다.
4. 상단을 가리던 HUD/조작 매뉴얼을 세로 맵 왼쪽 공간으로 옮기고, 좁아진 폭에서는 문장을 자동 줄바꿈한다.
