# P2-1 · 콘텐츠 카탈로그 상세 명세

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-23 |
| approved | 2026-08-23 · 사용자 전체 명세 승인 (`승인한다. 구현 단계로 진입`) |
| implemented | 2026-08-23 · P2-C01~12 구현 완료 |
| verified | 2026-08-23 · Godot 4.6.3 narrow 및 `verify --full` 통과 |
| parent | `docs/specs/p2_index.md` · approved |
| phase | P2-1 · 콘텐츠 기반 / 카탈로그 |
| 선행 단계 | P0·P1 승인·구현·검증 완료, P2-A01~11 승인 완료 |
| 후속 단계 | P2-2 `p2_effect_resolution.md` |
| 구현 권한 | **있음 — P2-C01~12 승인 범위** |

## 목적

저작용 JSON 바이트를 엄격하게 해석해 안정 ID, 타입, 범위, 참조를 검증하고, 전투 계층에는 정렬된 불변 `ContentCatalog`만 전달한다. 성공한 카탈로그는 입력 파일·레코드 순서와 무관한 정규 바이트와 SHA-256 호환 지문을 가진다. 파일 하나라도 잘못되면 새 카탈로그를 전혀 공개하지 않고 기존 카탈로그를 유지한다.

P2-1은 **실행기보다 먼저 데이터 경계를 고정하는 단계**다. 기물 스탯과 능력 정체성은 읽을 수 있지만 능력 효과를 실행하거나 P1 전투를 카탈로그에서 생성하지 않는다. 정식 기물 수치도 만들지 않는다. 이 분리로 P2-2가 잘못된 Dictionary, 부동소수점, 배열 순서, 임시 ID에 의존하지 않게 한다.

## 설계 정본과 선행 계약

- `docs/design/game_design.md` 7.2 트리거, 7.7 기물 플래그, 7.9 레벨, 14장 결정론·레이어, 15장 데이터 스키마, 16장 검증, 17장 P2 완료 판정
- `docs/specs/p2_index.md` P2-A01~07, 공통 데이터 계약, 정의/인스턴스 분리
- `docs/specs/p1_ctb_battle_state.md`의 `BattleParticipant` 소유 상태와 mutation barrier
- `docs/specs/p1_damage_resolution.md`의 `DamageLimits`, 정수 스탯·basis points
- `docs/specs/p1_trigger_bus_battle_result.md`의 append-only `BattleTriggerId` 0~13과 first-error-wins 원자성
- `docs/specs/p1_batch_sim_graybox.md`의 제품 데이터와 분리된 P1 회귀 fixture
- `src/core/sim/sim_limits.gd`, `src/core/battle/battle_limits.gd`, `src/core/battle/damage_limits.gd`의 승인된 안전 범위

## 현재 구현에서 확인된 제약과 충돌

### 1. Godot `JSON`은 P2-A05·06을 단독으로 보장하지 않는다

Godot 4.6의 공식 `JSON` 문서는 trailing comma를 무시하고, 문자열 안의 raw newline/tab을 허용하며, 숫자를 `String.to_float()`로 해석하는 비엄격 동작을 명시한다. 따라서 Godot `JSON.parse()`만으로는 다음 승인 계약을 안전하게 구현할 수 없다.

- JSON number 정수 literal만 허용
- int64와 uint32를 문자열 왕복 없이 정확히 보존
- trailing comma와 비표준 문자열 거부
- duplicate object key를 최초 파싱 단계에서 검출

근거: [Godot 4.6 JSON class reference](https://docs.godotengine.org/en/4.6/classes/class_json.html)

P2-C01은 `p2_index.md`의 “I/O 어댑터만 Godot `FileAccess`·`JSON` 사용” 문구 중 **권위 파서로 `JSON`을 사용한다는 부분을 수정**한다. `FileAccess`는 I/O에 사용하되, 권위 JSON 해석은 프로젝트 소유 strict parser가 담당한다. 영향 범위는 신규 `src/core/data/`와 P2-1 테스트뿐이고 P0·P1 저장 포맷 migration은 없다.

### 2. P1에는 런타임 데이터 디렉터리와 `DataDB`가 없다

현재 `src/core/data/`, `src/core/autoload/`와 `[autoload]` 설정이 없다. P1 회귀 fixture는 `src/core/battle/p1_graybox_fixture.gd`에 고정되어 있고 제품 밸런스 데이터가 아니다. P2-1은 이 fixture를 JSON으로 옮기거나 기존 golden을 갱신하지 않는다.

### 3. 설계 정본의 예시 schema에는 아직 미정인 축이 섞여 있다

15.1 예시는 faction, rarity, tag, level, presentation text, embedded ability를 한 객체에 보여 준다. 그러나 다음은 이미 다른 소유권이거나 아직 미정이다.

- faction·controllable은 같은 기물을 적으로 재사용할 때 배치 인스턴스가 정한다.
- rarity 축 U-27, 태그 배정 U-11b, 레벨별 수치 U-36은 미정이다.
- P2-A04는 embedded ability 대신 독립 `abilities.json`을 승인했다.
- expire·projectile·transform은 P2-4, sprite·표시 문자열은 P2-6/UI·아트 경계다.

P2-1 v1은 승인되지 않은 필드를 “나중을 위한 빈 필드”로 선점하지 않는다. 후속 명세가 필드를 승인할 때 document schema version을 올린다.

## 범위

### 포함

- UTF-8 바이트 기반 strict JSON subset parser
- catalog manifest와 고정 document set
- append-only 콘텐츠 namespace와 ID registry/tombstone
- P2-1용 `PieceDefinition`, `PieceLevelDefinition`, `AbilityDefinition`
- P0·P1 안전 범위와 P1 trigger ID 교차 검증
- 문자열/숫자 ID 쌍과 piece→ability 참조 검증
- 정렬된 불변 `ContentCatalog`과 release-safe 조회 API
- 타입화된 정규 바이트와 SHA-256 콘텐츠 호환 지문
- `DataDB`의 최초 로드·원자적 reload·기존 카탈로그 보존
- 독립 Python 기준 구현, Godot narrow, 자동 발견 runner
- 레코드가 0개인 유효 runtime catalog

### 범위 밖

- 조건, 대상 selector, effect schema와 실행
- trigger record→ability binding, RNG 소비, rollback
- 상태이상, 태그, 시너지, modifier, rarity
- faction·controllable·현재 level 같은 전투/런 인스턴스 상태
- projectile, attachment, transform, copy, spawn, expire
- enemy override, map, slot, zone, obstacle, encounter
- `balance.json`으로 기존 P0·P1 상수를 이동하는 migration
- `BattleState`·`BattleSnapshot`에 piece ID나 콘텐츠 지문을 연결하는 변경
- 정식 41종 기물, 최초 콘텐츠 패키지, 밸런스 수치
- display name, 능력 설명, localization, sprite/manifest 참조
- 실제 아트·VFX·SE와 회색상자 씬 변경

범위 밖 필드를 v1 JSON에 넣으면 조용히 보존하거나 무시하지 않고 `UNKNOWN_KEY`로 실패한다.

## 용어

| 용어 | 의미 |
|---|---|
| source document | `catalog.json`이 열거한 UTF-8 JSON 파일 |
| catalog schema version | 필요한 document 종류와 각 version 조합을 고정하는 집합 version |
| document schema version | 한 파일의 key·type·range 구조 version |
| content namespace | piece, ability처럼 numeric ID 중복을 독립적으로 허용하는 종류 |
| ID registry | active·retired ID 쌍을 보존하는 append-only 정본 |
| retired ID | 정의는 제거되었지만 재사용할 수 없도록 tombstone으로 남은 ID |
| definition | 검증 뒤 생성된 타입 고정·불변 콘텐츠 원형 |
| deployment state | faction, controllable, current level처럼 전투/런이 선택하는 인스턴스 상태 |
| compatibility bytes | 전투 의미가 있는 타입 필드만 고정 순서로 인코딩한 바이트 |
| content fingerprint | compatibility bytes의 SHA-256 32바이트 digest |
| presentation field | 표시 문자열·sprite처럼 전투 판정에 영향을 주지 않는 필드 |

## 결정 목록 — 승인 완료

| ID | 결정 | 권장안 | 영향 | 상태 |
|---|---|---|---|---|
| P2-C01 | 권위 JSON parser | `FileAccess`로 bytes를 읽고 프로젝트 소유 strict parser 사용. Godot `JSON.parse()`는 권위 경로에서 사용 금지 | P2-A05·06을 실제로 보장. P2 인덱스의 Godot JSON 사용 문구 수정 필요 | ✅ 승인 |
| P2-C02 | catalog v1 파일 집합 | `catalog.json`, `id_registry.json`, `pieces.json`, `abilities.json`만 필수. 추가 `.json`은 실패 | 부분 로드와 누락 방지. 후속 document 추가 때 catalog version 상승 | ✅ 승인 |
| P2-C03 | ID 정본 | namespace별 `(numeric_id, id, state_id)` registry. uint32 0 금지, active/retired, 쌍 영구 불변 | 삭제 뒤 ID 재사용과 자동 번호화를 차단 | ✅ 승인 |
| P2-C04 | piece/ability v1 schema | piece는 공통 flags와 level별 전체 stats·ability refs, ability는 ID와 P1 trigger ID까지만 | P2-2 전 효과 필드 선점 방지. 후속 ability schema v2 필요 | ✅ 승인 |
| P2-C05 | 원형과 배치 소유권 | piece 원형에서 faction·controllable·current level 제외. 배치/적 factory가 인스턴스에 부여 | 같은 player piece를 enemy로 재사용할 때 정의 복제 방지 | ✅ 승인 |
| P2-C06 | 미정·presentation 필드 | rarity·tag·expire·text·sprite·balance와 다른 P2 document는 v1에서 제외 | U-27/U-11b/U-36 등을 추측하지 않음. 승인 시 schema 상승 | ✅ 승인 |
| P2-C07 | 지문 포함 범위 | ID registry와 모든 battle-authoritative typed field 포함, source 공백/순서/파일명과 presentation 제외 | localization·아트 변경은 replay를 깨지 않고 전투 의미 변경은 반드시 감지 | ✅ 승인 |
| P2-C08 | 공학 안전 한도 | 파일 4 MiB, 전체 16 MiB, depth 32, 값 노드 262,144, 배열/namespace record 4,096 등 아래 한도 | 악성·실수 데이터로 인한 정지/메모리 폭증 차단 | ✅ 승인 |
| P2-C09 | `DataDB` 수명 | autoload가 빈 기본 catalog를 1회 로드. reload는 임시 build 성공 뒤 한 번에 swap, 실패 시 기존 유지 | 전역 접근은 단일 창구, hot file watching은 없음 | ✅ 승인 |
| P2-C10 | 오류 모델 | 별도 append-only `ContentStatus`, first-error-wins, 문서/record/field/byte 위치를 숫자로 보고 | OS·저작 오류와 결정론 `SimStatus`를 분리 | ✅ 승인 |
| P2-C11 | version 호환 | 현재 version만 exact 지원, 누락 기본값·자동 migration·구 version fallback 없음 | replay/data 불일치를 조기에 실패. migration은 별도 승인 작업 | ✅ 승인 |
| P2-C12 | P2-1 활성화 경계 | runtime records는 0개로 시작하고 테스트 fixture만 non-empty. P1 전투·snapshot은 연결하지 않음 | 정식 수치 발명과 P1 golden 변경 없이 인프라만 검증 | ✅ 승인 |

## P2-C01 · strict JSON subset

### 허용 문법

RFC 8259 JSON 중 다음 값만 허용한다.

- object, array, string, `true`, `false`, `null`
- 10진 정수 token: `0`, 음이 아닌 정수, `-`가 붙은 음의 정수
- token 사이의 ASCII space, tab, CR, LF
- JSON 표준 escape `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, `\uXXXX`
- 유효한 UTF-8과 올바르게 짝지어진 UTF-16 surrogate escape

정수 token은 부호 포함 int64 `[-9,223,372,036,854,775,808, 9,223,372,036,854,775,807]` 안에서 정확히 누적한다. parser 내부에서 float를 거치지 않는다.

### 거부 문법

- decimal point, exponent, `NaN`, `Infinity`, `+1`
- 선행 0이 붙은 `01`, `-01`
- comment, trailing comma, 누락 comma/colon
- 같은 object 안의 duplicate key
- raw control character, raw newline/tab이 들어간 string
- UTF-8 BOM, invalid UTF-8, 고립 surrogate, 범위 밖 code point
- int64 overflow
- root 뒤의 추가 token

`-0`은 유효 JSON 정수로 받아 typed value `0`으로 정규화한다. source 표기 차이는 지문에 영향을 주지 않는다.

### parser 출력 경계

```text
StrictJsonParser.parse_utf8(bytes, status) -> Variant
```

- 반환 `Dictionary`·`Array`는 `src/core/data/` builder 내부에서만 사용한다.
- parser는 schema 기본값, key 별칭, 문자열→숫자 coercion을 하지 않는다.
- parse 실패는 line·column·byte offset을 `ContentStatus`에 latch하고 중립값을 반환한다.
- `src/core/sim/`과 `src/core/battle/`은 parser와 `Dictionary`를 import하지 않는다.

## P2-C02 · catalog와 document 집합

### 디렉터리

권위 runtime root는 `res://src/core/data/`다. v1에서 JSON 파일은 정확히 다음 네 개다.

| 파일 | 역할 | schema version |
|---|---|---:|
| `catalog.json` | catalog version과 document 목록 | 1 |
| `id_registry.json` | namespace별 active/retired ID 정본 | 1 |
| `pieces.json` | piece 원형 | 1 |
| `abilities.json` | ability 정체성과 trigger | 1 |

같은 root에 있는 `.gd`, `.gd.uid`, 문서는 무시한다. 그러나 위 목록에 없는 `*.json`은 누락된 등록으로 보고 실패한다. backup·임시 JSON도 runtime root에 두지 않는다.

### `catalog.json` v1

```json
{
  "schema_version": 1,
  "documents": [
    {"kind_id": 1, "file_name": "id_registry.json", "schema_version": 1},
    {"kind_id": 2, "file_name": "pieces.json", "schema_version": 1},
    {"kind_id": 3, "file_name": "abilities.json", "schema_version": 1}
  ]
}
```

- `DocumentKindId`: `INVALID=0`, `ID_REGISTRY=1`, `PIECES=2`, `ABILITIES=3`.
- v1은 세 entry가 정확히 한 번씩 있어야 한다. 배열 순서는 의미가 없다.
- `file_name`은 위 고정 basename과 일치해야 한다. `/`, `\\`, `..`, URI scheme을 허용하지 않는다.
- 후속 명세가 document를 추가하면 `DocumentKindId`를 append하고 catalog schema version을 올린다.
- 모든 파일을 bytes로 읽고 build가 성공한 뒤에만 catalog를 공개한다.

## P2-C03 · namespace와 ID registry

### namespace ID

P2 인덱스에서 승인된 콘텐츠 종류를 다음 append-only 값으로 예약한다.

| ID | 이름 |
|---:|---|
| 0 | `INVALID` |
| 1 | `PIECE` |
| 2 | `ABILITY` |
| 3 | `STATUS` |
| 4 | `SYNERGY` |
| 5 | `PROJECTILE` |
| 6 | `ENEMY` |
| 7 | `MAP` |
| 8 | `TAG` |

v1 registry에는 1~8 namespace가 각각 정확히 한 번 존재한다. PIECE와 ABILITY만 active entry를 가질 수 있고 나머지는 빈 배열이어야 한다. 후속 schema 승인 뒤 해당 namespace가 활성화된다.

### `id_registry.json` v1

```json
{
  "schema_version": 1,
  "namespaces": [
    {
      "namespace_id": 1,
      "entries": []
    },
    {"namespace_id": 2, "entries": []},
    {"namespace_id": 3, "entries": []},
    {"namespace_id": 4, "entries": []},
    {"namespace_id": 5, "entries": []},
    {"namespace_id": 6, "entries": []},
    {"namespace_id": 7, "entries": []},
    {"namespace_id": 8, "entries": []}
  ]
}
```

`state_id`는 `ACTIVE=1`, `RETIRED=2`다.

위 예시는 records 0개인 runtime 기본 registry다. non-empty 테스트 fixture에서는 PIECE에 `(1, "fixture_puck", ACTIVE)`, ABILITY에 `(1, "fixture_collision", ACTIVE)`를 함께 등록한다.

- `numeric_id`: 1~4,294,967,295. namespace 안에서 유일하다.
- `id`: ASCII lower snake case, 정규식 `^[a-z][a-z0-9_]{0,63}$`. namespace 안에서 유일하다.
- `(namespace_id, numeric_id, id)` 쌍은 배정 후 의미·문자열을 바꾸지 않는다.
- active entry는 해당 document record와 정확히 1:1이어야 한다.
- 정의를 제거할 때 registry entry를 지우지 않고 `RETIRED`로 바꾼다.
- retired numeric/string ID는 record나 reference에 나타날 수 없고 다른 정의에 재사용할 수 없다.
- 배열 순서는 의미가 없으며 `(namespace_id, numeric_id)`로 정규화한다.
- 자동 번호 부여 API는 제공하지 않는다. ID 배정은 review 가능한 JSON 변경이다.

현재 파일만으로 과거 Git revision의 변조를 수학적으로 증명할 수는 없다. tombstone 보존과 fingerprint golden이 일반 실수·재사용을 막고, registry history review가 의도적 변경을 통제한다.

## P2-C04~06 · v1 definition schema

### 공통 `ContentIdRef`

```json
{"numeric_id": 1, "id": "fixture_collision"}
```

reference는 숫자와 문자열을 함께 적는다. builder는 두 값이 같은 active registry entry와 같은 definition을 가리키는지 검증한다. 한쪽만 맞거나 retired/missing이면 전체 load가 실패한다.

### `abilities.json` v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "fixture_collision",
      "trigger_id": 5
    }
  ]
}
```

| 필드 | 타입·범위 | 의미 |
|---|---|---|
| `numeric_id` | uint32, 0 금지 | ABILITY namespace 안정 ID |
| `id` | content string ID | registry와 일치하는 저작 ID |
| `trigger_id` | P1 `BattleTriggerId` 1~13 | ability가 결합될 trigger 정체성 |

P1의 `PASSIVE=1`, `ON_BATTLE_START=2` … `ON_BATTLE_END=13`만 허용한다. `effects`, `conditions`, `selectors`, cooldown, 사용 횟수, 설명 text는 v1에 존재하지 않는다. 따라서 v1 `AbilityDefinition`은 실행 가능한 능력이 아니라 **향후 실행기와 piece 참조가 공유할 안정된 identity/trigger 정의**다.

P2-2가 효과 구조를 승인하면 `abilities.json` document schema를 v2로 올린다. v1 레코드를 암묵적으로 “효과 0개”로 실행하지 않는다.

### `pieces.json` v1

아래 non-empty 예시는 테스트 fixture이며 runtime 기본 데이터가 아니다.

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "fixture_puck",
      "flags": {
        "has_turn": true,
        "destructible": true,
        "transformable": true,
        "counts_for_victory": true,
        "is_token": false
      },
      "levels": [
        {
          "level": 1,
          "max_hp": 100,
          "attack": 20,
          "speed_stat": 100,
          "mass_raw": 4194304,
          "radius_raw": 2097152,
          "friction_multiplier_raw": 65536,
          "critical_basis_points": 0,
          "ability_refs": [
            {"numeric_id": 1, "id": "fixture_collision"}
          ]
        }
      ]
    }
  ]
}
```

#### 원형 필드

| 필드 | 타입·범위 | 검증 |
|---|---|---|
| `numeric_id`, `id` | PIECE registry active pair | namespace 내 유일 |
| `flags.has_turn` | bool | CTB 참여 가능 원형 |
| `flags.destructible` | bool | `SimBody.destructible` 기본값 |
| `flags.transformable` | bool | P2-4가 소비할 capability |
| `flags.counts_for_victory` | bool | `BattleParticipant` 기본 capability |
| `flags.is_token` | bool | P2-3/4가 소비할 토큰 분류 |
| `levels` | 1~3개 | level 1부터 연속, 중복 없음 |

#### level 필드

| 필드 | 타입·범위 | 선행 validator |
|---|---|---|
| `level` | 1~3 | 배열 index가 아니라 명시 값, 1부터 연속 |
| `max_hp` | 1~1,000,000 | `DamageLimits.valid_stat` |
| `attack` | 1~1,000,000 | `DamageLimits.valid_stat` |
| `speed_stat` | 50~200 | `BattleLimits.valid_base_speed` |
| `mass_raw` | 65,536~16,777,216 | `SimLimits.is_mass_valid` |
| `radius_raw` | 524,288~8,388,608 | `SimLimits.is_radius_valid` |
| `friction_multiplier_raw` | 0~int64 max | `SimBody`의 현재 non-negative 계약. 후속 balance spec이 더 좁힐 수 있음 |
| `critical_basis_points` | 0~10,000 | `DamageLimits.valid_critical_basis_points` |
| `ability_refs` | 0~32개 | ABILITY active 정의 참조, numeric ID 중복 금지 |

각 level은 상속·delta 없이 모든 스탯과 그 level에서 활성인 전체 ability ref 목록을 적는다. 배열 저작 순서는 의미가 없고 numeric ability ID로 정규화한다. 이 방식은 level 2/3의 누락 필드를 추측하지 않고, 도플갱어처럼 level 1만 허용할 미래 콘텐츠도 `levels` 길이 1로 표현한다.

### definition에서 제외되는 상태

| 제외 필드 | 소유/후속 경계 |
|---|---|
| `current_level` | P4 deck/run instance와 P2 battle content instance |
| `faction` | P2-5 deployment/enemy factory가 `BattleParticipant`·`BattleCombatant`에 부여 |
| `controllable` | 플레이어/AI 배치 정책. 같은 piece 원형에 고정하지 않음 |
| `rarity` | U-27 승인 뒤 document schema 상승 |
| `tags` | P2-3 U-11b·시너지 schema 승인 뒤 추가 |
| `expire` | P2-4 동적 기물 수명 계약 |
| `name`, `text`, `text_revealed`, `reveal_key` | P2-6/UI·해금·localization 경계 |
| `sprite` | P2-6 manifest placeholder/asset 연결 |
| embedded `abilities` | P2-A04에 따라 금지. `ability_refs`만 사용 |

P2-1은 faction별 조합 규칙을 검증하지 않는다. 예를 들어 neutral이면 `has_turn=false`라는 7.7 계약은 P2-5 factory가 faction을 부여하는 시점에 원자적으로 검증한다.

## P2-C07 · 정규 바이트와 콘텐츠 지문

### 포함 범위

호환 지문은 다음 battle-authoritative 정보만 포함한다.

- fingerprint format version과 catalog/document schema version
- namespace ID, active/retired 상태, numeric/string ID 쌍
- piece numeric/string ID, flags, 모든 level stats, ability refs
- ability numeric/string ID와 trigger ID

source whitespace, object key 순서, document/record/reference 배열 순서, JSON filename은 포함하지 않는다. 향후 display text·localization key·sprite/manifest ID가 추가되어도 호환 지문에서는 제외한다. 해당 파일 자체의 무결성은 repository/manifest 검증이 담당한다.

### binary format v1

모든 정수는 little-endian이다. 문자열은 `u16 byte_length + UTF-8 bytes`, bool은 `u8 0|1`이다.

```text
8 bytes  ASCII "FLICKCAT"
u16      fingerprint_format_version = 1
u16      catalog_schema_version = 1
u16      id_registry_schema_version = 1

u16      namespace_count
for namespace_id ascending:
  u16    namespace_id
  u32    entry_count
  for numeric_id ascending:
    u32  numeric_id
    str  id
    u8   state_id

u16      document_count = 2       # typed content documents; registry는 위에서 인코딩
for document_kind_id ascending:
  u16    document_kind_id
  u16    document_schema_version
  u32    record_count
  typed records sorted by numeric_id
```

piece typed record는 `numeric_id → id → flags bitset → level count → level 오름차순 전체 필드 → ability ref numeric ID 오름차순`이다. ability typed record는 `numeric_id → id → trigger_id`다. flags bit는 `has_turn=0`, `destructible=1`, `transformable=2`, `counts_for_victory=3`, `is_token=4`로 고정한다. stats 정수는 signed i64, ID는 u32다.

`ContentCanonicalEncoder`가 만든 bytes를 기존 프로젝트 소유 `SimStateHash.sha256()`에 전달한다. SHA-256 구현을 복제하거나 engine hash 결과를 정본으로 삼지 않는다. hash 호출에는 새 `SimStatus`를 사용하고 예상 밖 실패를 `ContentStatus.FINGERPRINT_ERROR`로 변환한다. 기존 `sim_state_hash.gd`는 수정하지 않는다.

P2-1은 fingerprint 32 bytes와 소문자 64자리 hex 조회만 제공한다. `BattleSnapshot` 저장·restore mismatch 검사는 P2-2 이후 snapshot schema 변경 명세에서 연결한다.

## P2-C08 · 공학 안전 한도

| 항목 | v1 한도 | 실패 |
|---|---:|---|
| 파일 하나 | 4 MiB | `FILE_TOO_LARGE` |
| 네 JSON 총합 | 16 MiB | `CATALOG_LIMIT` |
| document 수 | 16 | `CATALOG_LIMIT` |
| JSON nesting depth | 32 | `JSON_LIMIT` |
| 전체 parsed value node | 262,144 | `JSON_LIMIT` |
| object member | 128 | `JSON_LIMIT` |
| 일반 array 원소 | 4,096 | `JSON_LIMIT` |
| UTF-8 string | 4,096 bytes | `JSON_LIMIT` |
| file basename | 64 ASCII bytes | `INVALID_DOMAIN` |
| namespace당 registry entry | 4,096 | `CATALOG_LIMIT` |
| piece/ability active record | namespace별 4,096 | `CATALOG_LIMIT` |
| piece level | 1~3 | `INVALID_DOMAIN` |
| level당 ability ref | 0~32 | `CATALOG_LIMIT` |

한도 초과를 truncate, clamp, 일부 skip하지 않는다. 모두 전체 catalog load 실패다. numeric ID 공간 uint32와 현재 record 수 한도는 별개다. retired tombstone도 registry entry 수에 포함한다. 4,096개를 실제로 소진할 조짐이 생기면 namespace 분할이나 한도 상승을 별도 승인한다.

## P2-C09 · 상태 모델과 공개 API

### 타입과 불변성

```text
ContentIdRef
PieceLevelDefinition
PieceDefinition
AbilityDefinition
ContentCatalog
```

- 모두 `RefCounted`이며 `Node`, `FileAccess`, scene API를 사용하지 않는다.
- 생성은 validator/builder의 checked factory만 허용한다.
- 내부 배열은 numeric ID 오름차순으로 저장하고 getter는 scalar 또는 copy를 반환한다.
- definition과 catalog는 setter를 제공하지 않는다.
- 조회 구현은 정렬 배열의 binary search를 사용한다. 내부 Dictionary iteration 결과에 의존하지 않는다.
- 오류 조회는 `ContentStatus`를 latch하고 uninitialized 중립 객체를 반환한다. `null`과 정상 빈 값을 혼동하지 않는다.

### core data API

```text
StrictJsonParser.parse_utf8(bytes, status) -> Variant

ContentCatalogBuilder.build(
    catalog_document,
    source_documents: Array[ContentSourceFile],
    status
) -> ContentCatalog

ContentCatalog.is_initialized() -> bool
ContentCatalog.catalog_schema_version() -> int
ContentCatalog.piece_count() -> int
ContentCatalog.piece_at(index, status) -> PieceDefinition
ContentCatalog.piece_by_numeric_id(id, status) -> PieceDefinition
ContentCatalog.piece_by_string_id(id, status) -> PieceDefinition
ContentCatalog.ability_count() -> int
ContentCatalog.ability_at(index, status) -> AbilityDefinition
ContentCatalog.ability_by_numeric_id(id, status) -> AbilityDefinition
ContentCatalog.ability_by_string_id(id, status) -> AbilityDefinition
ContentCatalog.fingerprint_bytes() -> PackedByteArray
ContentCatalog.fingerprint_hex() -> String
```

`ContentCatalogBuilder`는 parse tree를 최종 객체에 보존하지 않는다. build 성공 뒤 source `Dictionary`와 bytes를 버려도 catalog 결과가 변하지 않아야 한다.

### `DataDB` autoload

```text
DataDB.is_ready() -> bool
DataDB.reload_catalog(root_path: String, status: ContentStatus) -> bool
DataDB.catalog_schema_version(status) -> int
DataDB.piece_by_numeric_id(id, status) -> PieceDefinition
DataDB.ability_by_numeric_id(id, status) -> AbilityDefinition
DataDB.fingerprint_bytes(status) -> PackedByteArray
DataDB.fingerprint_hex(status) -> String
```

- `project.godot`에 `DataDB="*res://src/core/autoload/data_db.gd"`를 등록한다.
- `_ready()`에서 `res://src/core/data/`를 정확히 한 번 로드한다.
- runtime 기본 JSON의 records는 비어 있으므로 초기 catalog는 유효하고 ready가 된다.
- 자동 file watch와 매 frame reload는 없다.
- reload는 모든 파일을 임시 bytes→parse tree→typed catalog→fingerprint 순서로 완성한 뒤 `_catalog` 참조 하나만 교체한다.
- 실패 시 기존 `_catalog` 객체와 fingerprint는 byte-for-byte 유지한다. 최초 로드 실패면 unready 상태다.
- UI·battle은 `DataDB` 반환 사본을 읽을 수 있지만 catalog나 definition을 수정할 수 없다.

테스트는 별도 fixture root를 전달할 수 있다. production caller가 임의 user path를 저작 데이터로 사용하거나 network path를 읽는 기능은 제공하지 않는다.

## P2-C10 · 오류 계약

### `ContentStatus.Code`

append-only 숫자는 다음과 같이 시작한다.

| 값 | 이름 |
|---:|---|
| 0 | `OK` |
| 1 | `IO_ERROR` |
| 2 | `FILE_TOO_LARGE` |
| 3 | `INVALID_UTF8` |
| 4 | `JSON_SYNTAX` |
| 5 | `JSON_LIMIT` |
| 6 | `DUPLICATE_KEY` |
| 7 | `NON_INTEGER_NUMBER` |
| 8 | `INTEGER_OVERFLOW` |
| 9 | `UNSUPPORTED_SCHEMA` |
| 10 | `UNKNOWN_KEY` |
| 11 | `MISSING_KEY` |
| 12 | `INVALID_TYPE` |
| 13 | `INVALID_ID` |
| 14 | `DUPLICATE_ID` |
| 15 | `MISSING_REFERENCE` |
| 16 | `INVALID_DOMAIN` |
| 17 | `CATALOG_LIMIT` |
| 18 | `FINGERPRINT_ERROR` |
| 19 | `CATALOG_UNAVAILABLE` |

### `ContentStatus.Operation`

| 값 | 이름 |
|---:|---|
| 0 | `NONE` |
| 1 | `FILE_ENUMERATE` |
| 2 | `FILE_READ` |
| 3 | `JSON_PARSE` |
| 4 | `DOCUMENT_VALIDATE` |
| 5 | `ID_REGISTER` |
| 6 | `REFERENCE_RESOLVE` |
| 7 | `CATALOG_BUILD` |
| 8 | `CANONICAL_ENCODE` |
| 9 | `SHA256` |
| 10 | `LOOKUP` |
| 11 | `DATA_DB_LOAD` |

### 진단 필드

`ContentStatus`는 `code`, `operation`, `document_kind_id`, `record_numeric_id`, `field_id`, `line`, `column`, `byte_offset`을 정수로 보존한다. first-error-wins이며 `copy()`를 제공한다.

`field_id`도 append-only다.

| 값 | 필드 |
|---:|---|
| 0 | `NONE` |
| 1 | `SCHEMA_VERSION` |
| 2 | `DOCUMENTS` |
| 3 | `KIND_ID` |
| 4 | `FILE_NAME` |
| 5 | `NAMESPACES` |
| 6 | `NAMESPACE_ID` |
| 7 | `ENTRIES` |
| 8 | `NUMERIC_ID` |
| 9 | `ID` |
| 10 | `STATE_ID` |
| 11 | `RECORDS` |
| 12 | `TRIGGER_ID` |
| 13 | `FLAGS` |
| 14 | `HAS_TURN` |
| 15 | `DESTRUCTIBLE` |
| 16 | `TRANSFORMABLE` |
| 17 | `COUNTS_FOR_VICTORY` |
| 18 | `IS_TOKEN` |
| 19 | `LEVELS` |
| 20 | `LEVEL` |
| 21 | `MAX_HP` |
| 22 | `ATTACK` |
| 23 | `SPEED_STAT` |
| 24 | `MASS_RAW` |
| 25 | `RADIUS_RAW` |
| 26 | `FRICTION_MULTIPLIER_RAW` |
| 27 | `CRITICAL_BASIS_POINTS` |
| 28 | `ABILITY_REFS` |

- parse 오류는 가능한 line/column/byte offset을 채우고 아직 알 수 없는 record·field는 0이다.
- document 검증 뒤 오류는 document kind, 알고 있는 numeric ID, field ID를 채운다.
- OS 오류 문자열과 절대 경로는 결정론 객체에 저장하지 않고 `DataDB` adapter 로그에서만 표시한다.
- release에서도 오류를 관찰할 수 있어야 하며 `assert`, clamp, default 추측, 부분 성공으로 숨기지 않는다.

## P2-C11 · schema 진화 규칙

1. loader는 현재 승인된 catalog/document version의 exact key set만 지원한다.
2. required field 추가·삭제·type 변경·의미 변경은 해당 document schema version을 올린다.
3. required document 추가·삭제 또는 기대 document version 변경은 catalog schema version을 올린다.
4. 같은 schema에서 active record 추가·retire·밸런스값 변경은 version을 올리지 않지만 fingerprint는 바뀐다.
5. unknown newer version과 지원 종료된 older version은 모두 `UNSUPPORTED_SCHEMA`다.
6. runtime loader는 자동 migration, 누락 기본값, key alias를 제공하지 않는다.
7. migration이 필요하면 입력/출력 version, ID 보존, golden 변화, rollback을 별도 spec과 도구로 승인한다.
8. schema version과 fingerprint format version은 별개다. 정규 binary 규칙이 바뀔 때만 fingerprint format version을 올린다.

## 원자적 로드 순서

`DataDB.reload_catalog()`은 다음 순서를 고정한다.

1. root의 `.json` basename을 수집하고 bytewise ASCII 오름차순으로 정렬한다.
2. `catalog.json` 크기·UTF-8·strict JSON·exact schema를 검증한다.
3. manifest가 요구한 document set과 실제 `.json` 집합이 정확히 같은지 검증한다.
4. document를 kind ID 오름차순으로 읽고 각 bytes 한도와 전체 한도를 검증한다.
5. 각 document를 strict parse하고 exact key/type/schema를 검증한다.
6. registry namespace와 ID 쌍을 임시 typed registry에 등록한다.
7. ability record를 numeric ID 오름차순으로 검증·생성한다.
8. piece와 level을 검증하고 ability ref를 해소한다.
9. active registry entry와 active definition이 1:1인지, retired ID가 참조되지 않는지 검사한다.
10. immutable sorted catalog를 만든다.
11. compatibility bytes와 SHA-256을 계산한다.
12. 성공한 새 catalog 참조를 단일 assignment로 공개한다.

어느 단계든 실패하면 이후 단계와 swap을 수행하지 않는다. 기존 catalog의 getter 결과와 fingerprint가 바뀌지 않아야 한다.

## 대상 파일

### 신규

```text
docs/specs/p2_content_catalog.md

src/core/autoload/data_db.gd
src/core/data/catalog.json
src/core/data/id_registry.json
src/core/data/pieces.json
src/core/data/abilities.json
src/core/data/content_status.gd
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_source_file.gd
src/core/data/strict_json_parser.gd
src/core/data/content_id_ref.gd
src/core/data/piece_level_definition.gd
src/core/data/piece_definition.gd
src/core/data/ability_definition.gd
src/core/data/content_catalog.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd

pipeline/scripts/content_catalog.py
pipeline/schemas/p2-catalog-v1.schema.json
pipeline/schemas/p2-id-registry-v1.schema.json
pipeline/schemas/p2-pieces-v1.schema.json
pipeline/schemas/p2-abilities-v1.schema.json
pipeline/tests/p2_content_catalog_test.gd
pipeline/tests/p2_content_catalog_reference.py
pipeline/tests/run_p2_content_catalog.py
pipeline/tests/fixtures/p2_content_catalog/**
```

### 수정

```text
project.godot                     # DataDB autoload 등록
docs/specs/p2_index.md            # P2-1 상태/승인 기록
AGENTS.md                         # 구현·검증 완료 뒤 current phase만 갱신
HANDOFF.md                        # 구현·검증 완료 뒤 인계 상태만 갱신
```

P2-1은 `src/core/sim/`, `src/core/battle/`, P1 fixture/golden, scene, asset, `pipeline/manifest.json`을 수정하지 않는다. JSON Schema는 저작 도구 보조이며 duplicate key·canonical fingerprint의 정본은 strict parser와 독립 Python validator다.

## 필요 에셋

없음.

- runtime catalog는 records 0개로 시작한다.
- non-empty positive fixture는 `pipeline/tests/fixtures/p2_content_catalog/`에만 둔다.
- P1 플레이스홀더와 manifest entry를 piece definition에 연결하지 않는다.
- art lock/gen/reskin과 SE gen/attach를 실행하지 않는다.

## 테스트와 수용 기준

### 독립 Python 기준

`p2_content_catalog_reference.py`는 GDScript 구현을 호출하거나 그 출력 bytes를 재사용하지 않고 다음을 독립 계산한다.

- duplicate key를 보존하는 pair hook과 float token 거부
- exact schema·registry·reference 검증
- numeric ID 정렬과 compatibility bytes v1
- `hashlib.sha256` digest

고정 known-answer fixture는 canonical bytes hex와 fingerprint hex를 체크인한다. 갱신은 schema/fingerprint format 변경 승인 참조가 있을 때만 허용한다.

### parser fixture

각 항목은 최소 positive/negative/boundary case를 가진다.

1. 빈 object/array, escape, 유효 UTF-8, int64 min/max
2. decimal, exponent, int64 overflow, leading zero
3. duplicate key, trailing comma, comment, root 뒤 token
4. raw newline/tab, invalid escape, invalid UTF-8, 고립 surrogate, BOM
5. depth, node, object member, array, string, file/total byte 한도

Godot `JSON.parse()`가 허용하는 trailing comma와 raw newline fixture도 strict parser에서는 반드시 실패해야 한다.

### schema·ID fixture

6. missing/unknown key와 잘못된 primitive/container type
7. catalog/document version mismatch, document 누락·중복·추가 JSON
8. namespace 누락·중복, uint32 0/max/overflow, 문자열 ID 형식
9. active record 불일치, retired record/reference, numeric/string ref 불일치
10. duplicate piece/ability ID, duplicate level, level gap, duplicate ability ref
11. HP/attack/speed/mass/radius/friction/critical의 최소·최대·범위 밖
12. 알려지지 않은 P1 trigger ID 0/14와 알려진 1/13 경계

### 결정론·원자성 fixture

13. object key·document·namespace·record·ability ref 순서를 교란해도 canonical bytes와 fingerprint가 같다.
14. battle-authoritative 값, active/retired 상태, ID 쌍 중 하나를 바꾸면 fingerprint가 달라진다.
15. 공백과 source 순서만 바꾸면 fingerprint가 바뀌지 않는다.
16. 같은 fixture 1,000회 build의 canonical bytes와 digest가 동일하다.
17. GDScript digest가 독립 Python known-answer와 byte-for-byte 같다.
18. 반환 definition/array 사본을 수정해도 catalog 조회와 fingerprint가 변하지 않는다.
19. 유효 catalog A 로드 뒤 잘못된 B reload가 실패해도 A의 count·lookup·fingerprint가 유지된다.
20. 유효 B reload 성공 시에만 모든 lookup과 fingerprint가 한 번에 B로 바뀐다.

### 통합 수용

21. records 0개인 runtime 네 JSON이 `DataDB._ready()`에서 성공하고 initialized empty catalog 지문을 제공한다.
22. `src/core/sim/`·`src/core/battle/`이 `FileAccess`, `JSON`, raw Dictionary를 새로 참조하지 않는다.
23. P1 graybox fixture ID·golden·terminal hash가 변경되지 않는다.
24. game-specific runner가 `pipeline/tests/run_p2_content_catalog.py` 이름으로 `verify --full`에 자동 발견된다.
25. Godot 4.6.3 import/headless narrow 뒤 P0·P1 narrow와 `PYTHONUTF8=1 python pipeline/scripts/verify.py --full`이 통과한다.

P2-1 완료는 1~25 전체 통과, P2-C01~12 승인 반영, 문서/AGENTS/HANDOFF 상태 갱신까지다. P2-1 완료만으로 P2 전체 또는 data-only 신규 기물 완료를 선언하지 않는다.

## 구현 순서 — 전체 승인 뒤 적용

1. 독립 Python parser/schema/canonical reference와 known-answer fixture를 먼저 고정한다.
2. `ContentStatus`, ID/field enums, 공학 한도를 구현한다.
3. byte 기반 strict JSON parser와 negative corpus를 구현한다.
4. typed source/ID/definition 객체와 exact schema validator를 구현한다.
5. registry·cross-reference·immutable sorted catalog builder를 구현한다.
6. canonical encoder와 기존 `SimStateHash` SHA-256 연결을 구현한다.
7. records 0개 runtime JSON과 `DataDB` atomic load/reload를 구현하고 autoload를 등록한다.
8. Godot narrow에서 parser, schema, ID, fingerprint, immutability, rollback을 검증한다.
9. P0·P1 회귀와 Godot 활성 `verify --full`을 실행한다.
10. 구현·검증 결과를 본 문서, `p2_index.md`, `AGENTS.md`, `HANDOFF.md`에 기록한다.

## 승인 기록

P2-C01~12는 2026-08-23 사용자 구현 진입 지시로 한 묶음 승인되었다. 특히 다음 두 변경점이 명시적으로 승인 범위에 포함된다.

1. Godot `JSON.parse()`의 공식 비엄격 동작 때문에 권위 parser를 프로젝트 strict parser로 교체한다.
2. 설계 정본 15.1의 큰 예시를 한 번에 구현하지 않고, v1은 piece/ability identity·stats 경계만 확정하며 미정·presentation·effect 필드는 후속 version으로 미룬다.

승인 범위 밖 변경은 별도 재승인을 받는다.

## 구현·검증 기록

- 프로젝트 소유 byte 기반 strict JSON parser, exact schema validator, append-only namespace/ID registry, typed immutable piece/ability 정의와 정렬 catalog를 구현했다.
- `DataDB`는 정확한 네 JSON 집합을 임시 catalog로 완성한 뒤 한 번에 교체하며, 실패 시 직전 catalog와 fingerprint를 유지한다. `project.godot` autoload 등록도 완료했다.
- 호환 bytes v1은 기존 `SimStateHash.sha256()`을 재사용한다. KAT fingerprint는 runtime empty `e8626e30d47cab13a00d054228b2403dee1d3db27e5620c225f83f898fc37bee`, 순서 교란 A `bd0803434d4d632da9e1b3291bcfd57050a9d35c8e3ca610dd29d3dc8de3e0b2`, 권위값 변경 B `378f413f0c8889f0f3286a0787767a27e8bf038f5db85b045b2f20b3c8d7e010`으로 고정했다.
- 독립 stdlib Python 기준은 strict parser·schema/reference·canonical bytes/SHA-256 세 그룹을 통과했다. Godot 4.6.3 narrow는 parser, limits, first-error-wins, lookup, immutability, retired ID, atomic rollback, 순서 독립, 1,000회 반복을 포함한 23개 그룹을 통과했다.
- Godot 활성 `PYTHONUTF8=1 python pipeline/scripts/verify.py --full`은 게이트 #1~4 PASS, lore 미초기화 #5 정상 SKIP, 자동 발견 러너 18종 전부 PASS다.
- P2-C12대로 runtime piece/ability record는 0개이며 P1 fixture/golden, `src/core/sim/`, `src/core/battle/`, scene, asset, manifest는 변경하지 않았다.

P2-1은 완료되었다. 다음 구현 경계는 별도 명세·승인이 필요한 P2-2 효과 실행이며, P2 전체 완료나 data-only 신규 기물 완료를 의미하지 않는다.
