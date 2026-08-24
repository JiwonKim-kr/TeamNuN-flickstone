# P2-5 · 맵 / 적 / 환경 명세

| 항목 | 값 |
|---|---|
| status | **approved** |
| drafted | 2026-08-24 |
| approved | 2026-08-24 · 사용자 P2-M01~21 전체 승인 |
| phase | P2-5 · 맵·적·환경 |
| 선행 단계 | P2-1 카탈로그, P2-2 효과 실행, P2-3 상태·시너지·modifier, P2-4 동적 기물 승인·구현·검증 완료 |
| 후속 단계 | P2-6 콘텐츠 회색상자·완료 검증 |
| 구현 권한 | **있음.** 2026-08-24 P2-M01~21 전체 승인 범위 |
| 구현 상태 | **승인 범위 구현·검증 완료** |

## 목적

전투가 벌어지는 **판**을 코드가 아니라 데이터에서 만든다. 맵 경계·슬롯·지형 존과 플레이어 기물을 재사용한 적 정의를 엄격하게 읽어, 검증된 `BattleState`를 결정론적으로 조립하는 단일 경로를 만든다. 정적 장애물은 필드만 예약하고 P2-5에서는 활성화하지 않는다.

P2-4까지는 전투 상태를 테스트 fixture가 코드로 세웠다. P2-5는 그 자리를 콘텐츠가 대신하게 해 P2-6 회색상자가 **코드 수정 없이** 맵과 적 구성을 바꿀 수 있게 한다.

P2-5는 실제 맵 목록이나 적 스탯 스케일을 만들지 않는다. 구조 규칙만 구현하고 수치는 fixture로만 검증한다.

## 정본 참조

- `docs/design/game_design.md` 4.3 이동·마찰, 4.4 충돌 해결, 5장 소멸 영역(D-06/07/08/39)
- 7.7.1 기물 플래그 축, 7.7.2 중립 기물, 7.7.3 중립 기물 재사용 후보
- 7.10 적 기물 재사용, 8장 맵·환경 요소, 15.2 맵 스키마
- 14.1 결정론, 16장 검증 계획
- 22장 미결 U-01, U-02, U-03, U-10, U-22, U-34
- `docs/specs/p2_index.md` 적·맵·환경 경계, 공통 데이터 계약
- `docs/specs/p0_sim_world.md` 존 합성 순서(D-36), 폴리곤 제약(D-40)
- `docs/specs/p0_collision_boundaries.md` 경계·소멸 판정
- `docs/specs/p2_dynamic_piece_mechanics.md` P2-D04 발사체=기물, P2-D21 `spawn_faction_mode_id`, P2-D24 수명 barrier

참조 lore: 없음. 세계관은 현재 범위 밖이며 `lore/canon/`은 초기화하지 않았다.

## 포함 범위

- `maps.json` / `enemies.json` schema v1과 typed 불변 정의
- 경계 폴리곤·`boundary_type`·지형 존의 P0 규칙 재사용 검증
- 슬롯 좌표 검증과 `deploy_count` 계약
- 플레이어 기물을 참조하는 적 정의와 override whitelist
- 카탈로그 + 맵 + 배치 목록에서 `BattleState`를 조립하는 단일 경로
- 효과 원자 `SPAWN_ZONE`과 런타임 존 수명
- ability schema v5, catalog v5, fingerprint v5, `BattleSnapshot` v7
- 공학 한도, 결정론, 독립 Python 기준값, P0·P1·P2-1~4 회귀, `verify --full`

## 비범위

- **production 맵 목록과 수치** (U-01) — 15~20종 선정은 P2-6/U-01 승인 대상
- **빙판·모래밭·독장판·용암의 정식 채택과 효과 수치** (U-02)
- **주기 피해 존, 존 우선순위·override** — P0가 지원하지 않는다(D-36)
- **정적 장애물 활성화, 파괴 가능한 장애물, 반사 특성** (U-03) — `obstacles`는 예약 필드지만 P2-5에서는 빈 배열만 허용
- **판 크기와 슬롯 개수의 확정값** (U-34)
- **적 스탯 스케일 수치와 `ai_grade`·`ai_profile`** (U-10) — P3 소유
- **엘리트·보스 설계**, 소멸 영역 엘리트 비율 (U-05, U-06, U-22)
- `encounters.json` — 적 구성 + 맵 조합은 P4 소유
- `SPAWN_OBSTACLE` — U-03 미결. `SPAWN_PIECE`는 정적 장애물 대체가 아니라 움직이는 중립 위험물만 표현한다
- 노드·보상·해금·도감·위장, VFX, UI, 실제 아트, 효과음

## 용어

| 용어 | 의미 |
|---|---|
| 맵 정의 | 경계·슬롯·존과 비어 있는 장애물 예약 필드를 담은 불변 원형 |
| 슬롯 | 전투 시작 시 기물이 놓이는 좌표 |
| 배치(deployment) | 어느 슬롯에 어느 piece/enemy를 어느 level로 놓을지의 목록 |
| 존 | 기물이 그 위에 있을 때 마찰·가속·소멸을 적용하는 폴리곤 |
| 장애물 | U-03 승인 뒤 활성화할 정적 충돌체. P2-5의 `obstacles` 배열은 항상 비어 있다 |
| 적 정의 | 플레이어 기물 원형을 참조하고 허용된 필드만 덮어쓴 원형 |
| 설치 존 | 능력이 런타임에 만든 존 |

## 승인 결정안

| ID | 결정안 | 이유 | 상태 |
|---|---|---|---|
| P2-M01 | `maps.json` v1은 경계 폴리곤·`boundary_type`·슬롯·`deploy_count`·존과 예약 `obstacles` 배열만 갖는다. 검증은 **P0 폴리곤 규칙을 그대로 재사용**한다 | 정본 15.2의 필드 집합. 새 기하 검증을 두 벌 만들지 않는다 | ✅ 승인 · 2026-08-24 |
| P2-M02 | 정본 15.2의 `size` 필드를 **두지 않는다.** 경계 폴리곤이 판 크기의 정본이다 | 두 정본이 어긋날 여지를 없애고 U-34를 선점하지 않는다 | ✅ 승인 · 2026-08-24 |
| P2-M03 | 존은 P0가 지원하는 **마찰 배율·가속도·`KILL` 플래그 조합**만 갖는다. 주기 피해·우선순위·override는 없다 | D-36이 확정한 합성 규칙 밖으로 나가지 않는다. U-02 수치를 발명하지 않음 | ✅ 승인 · 2026-08-24 |
| P2-M04 | P2-5에서 `obstacles`는 **빈 배열만 허용**한다. non-empty는 로드 실패다. 정적 장애물은 U-03 승인 뒤 maps schema 상승과 P0 충돌 회귀를 거쳐 활성화한다 | 현재 `SimBody`는 동적이고 combatant 없는 충돌은 피해를 만들지 않아 정적 장애물 의미를 충족하지 못함 | ✅ 승인 · 2026-08-24 |
| P2-M05 | 슬롯은 경계 **엄격한 내부**이며 벽과 충분히 떨어져야 하고, `KILL` 존의 엄격한 내부 또는 다른 슬롯과 겹치면 로드 실패다. 물리 여유는 모든 piece level과 resolved enemy override를 포함한 **카탈로그 최대 반지름**을 쓴다 | 배치와 독립적으로 어떤 승인 기물도 안전하게 놓이게 함. `KILL`은 D-39대로 중심점만 검사 | ✅ 승인 · 2026-08-24 |
| P2-M06 | `deploy_count`는 D-03의 **3~5**이며 player·enemy 슬롯 수가 각각 그 이상이어야 한다 | 정본 D-03을 loader가 강제한다. 슬롯을 여유 있게 두고 배치가 고르게 한다 | ✅ 승인 · 2026-08-24 |
| P2-M07 | `enemies.json` v1은 `base_piece_ref`와 **override whitelist**만 갖는다. unknown override는 실패다 | P2 인덱스 공통 계약. 적 전용 기물을 새로 설계하지 않는다는 정본 7.10 방침 유지 | ✅ 승인 · 2026-08-24 |
| P2-M08 | override 허용 범위는 **level 1 스탯 7종과 `ability_refs`**뿐이다. 플래그·태그·`expire`·spawn·attach 필드는 override 불가 | 정본 7.10의 조정 축(스탯·능력)과 정확히 일치. 적이 다른 기물 종류가 되는 것을 막는다 | ✅ 승인 · 2026-08-24 |
| P2-M09 | `ai_grade`·`ai_profile`을 `enemies.json`에 **두지 않는다** | U-10과 P3 소유. P2가 임의 등급 축을 만들면 P3가 재작업한다 | ✅ 승인 · 2026-08-24 |
| P2-M10 | `pieces.json`에 `enemy_eligible` 축을 추가하지 않는다. `enemies.json`의 record 존재는 적 원형 정의만 뜻하고, 일반 적 풀 편입은 P2-6, 이벤트 사용은 후속 encounter 계층이 승인한다 | 전설의 일반 풀 제외와 이벤트 적 등장 예외를 동시에 보존하고 불필요한 pieces schema 상승을 피함 | ✅ 승인 · 2026-08-24 |
| P2-M11 | `SPAWN_ZONE`(16)만 활성화하고 **`SPAWN_OBSTACLE`은 계속 거부**한다. 움직이는 중립 위험물만 `SPAWN_PIECE`로 저작한다 | U-03 전에 정적 장애물 전용 의미를 선점하지 않는다 | ✅ 승인 · 2026-08-24 |
| P2-M12 | 설치 존은 `duration_turns`를 가지며 0이면 영구다. 감소는 **전역 `TURN_END` barrier**이고 설치한 턴은 줄지 않는다 | P2-D24의 수명 barrier 패턴을 그대로 재사용해 축을 늘리지 않는다 | ✅ 승인 · 2026-08-24 |
| P2-M13 | `BattleSetupBuilder`가 **카탈로그 + map numeric ID + 배치 목록 + 시드**에서 `BattleState`를 조립하는 단일 경로다. 전투 계층은 파일을 읽지 않는다 | map 객체의 출처 혼합을 막고 P2-6과 batch·repro가 같은 입력으로 같은 전투를 재현하게 한다 | ✅ 승인 · 2026-08-24 |
| P2-M14 | 초기 body ID의 최종 기준은 **장애물 local ID → player 슬롯 인덱스 → enemy 슬롯 인덱스** 오름차순이다. P2-5에서는 장애물이 0개이므로 player→enemy만 관찰된다 | U-03 뒤 장애물을 활성화해도 ID 의미를 바꾸지 않으며, 장애물 ID가 배치 인원 변화에 흔들리지 않음 | ✅ 승인 · 2026-08-24 |
| P2-M15 | `BattleSnapshot`을 **v7**로 올려 설치 존 수명을 저장하고 legacy v1~6 decode를 유지한다. `SimSnapshot`은 v2를 유지한다. P0 SimSnapshot 골든은 불변이고 P1/P2 BattleSnapshot 골든은 승인 참조로 이관한다 | v6에는 확장 영역이 없어 수명 상태를 같은 버전에 추가할 수 없음 | ✅ 승인 · 2026-08-24 |
| P2-M16 | schema 상승: maps v1, enemies v1, abilities v5, catalog v5, fingerprint format v5, BattleSnapshot v7. pieces v3·SimSnapshot v2를 유지하며 **`projectiles.json`은 만들지 않는다** | 불필요한 pieces/SimSnapshot 상승을 피하고 P2-D04의 발사체 통합을 유지 | ✅ 승인 · 2026-08-24 |
| P2-M17 | 아래 공학 한도를 채택한다 | 악성·실수 데이터로 인한 정지와 메모리 폭증을 차단한다 | ✅ 승인 · 2026-08-24 |
| P2-M18 | runtime `maps.json`·`enemies.json` records는 **계속 0개**로 둔다. 모든 맵·적은 fixture에만 존재한다 | U-01·02·03·10·34를 추측 확정하지 않는다 | ✅ 승인 · 2026-08-24 |
| P2-M19 | 맵 존은 0이 아닌 고유 `local_id:uint32`를 가지며 local ID 오름차순으로 canonical encode·초기 `zone_id` 배정을 한다. 슬롯과 폴리곤 정점만 저작 순서를 보존한다 | 배열 교란과 zone 합성 순서를 동시에 결정론적으로 고정 | ✅ 승인 · 2026-08-24 |
| P2-M20 | MAP/ENEMY registry 활성화와 아래 canonical v5 exact 바이트 계약을 채택한다 | Godot·독립 Python fingerprint를 바이트 단위로 일치시킴 | ✅ 승인 · 2026-08-24 |
| P2-M21 | PLAYER 배치는 `piece_ref`+level 1~3만, ENEMY 배치는 `enemy_ref`+level 1만 허용하며 진영별 항목 수가 각각 `deploy_count`와 같아야 한다 | side/ref 모호성과 한 진영만 적게 배치되는 부분 상태를 제거 | ✅ 승인 · 2026-08-24 |

## 데이터 계약

### maps.json schema v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "test_arena",
      "boundary_type_id": 1,
      "boundary_vertices": [
        {"x_raw": -33554432, "y_raw": -20971520},
        {"x_raw": 33554432, "y_raw": -20971520},
        {"x_raw": 33554432, "y_raw": 20971520},
        {"x_raw": -33554432, "y_raw": 20971520}
      ],
      "deploy_count": 3,
      "player_slots": [
        {"x_raw": -20971520, "y_raw": -10485760},
        {"x_raw": -20971520, "y_raw": 0},
        {"x_raw": -20971520, "y_raw": 10485760}
      ],
      "enemy_slots": [
        {"x_raw": 20971520, "y_raw": -10485760},
        {"x_raw": 20971520, "y_raw": 0},
        {"x_raw": 20971520, "y_raw": 10485760}
      ],
      "zones": [
        {
          "local_id": 1,
          "flags": 0,
          "friction_multiplier_raw": 91750,
          "acceleration_x_raw": 0,
          "acceleration_y_raw": 0,
          "vertices": [
            {"x_raw": -6291456, "y_raw": -6291456},
            {"x_raw": 6291456, "y_raw": -6291456},
            {"x_raw": 6291456, "y_raw": 6291456},
            {"x_raw": -6291456, "y_raw": 6291456}
          ]
        }
      ],
      "obstacles": []
    }
  ]
}
```

- `boundary_type_id`는 `WALL`(1) 또는 `KILL`(2)이다. `NONE`은 저작할 수 없다.
- 경계는 **시계 방향 단순 볼록 폴리곤 3~64정점**이어야 한다(D-40). 자동 보정하지 않고 실패한다.
- 존 폴리곤은 자기 교차 없는 단순 오목까지 허용한다. 정점은 위치 안전 범위 안이어야 한다.
- 존 `local_id`는 0이 아닌 `uint32`이며 같은 맵 안에서 고유해야 한다. canonical encode와 초기 `zone_id` 배정은 `local_id` 오름차순이다.
- 존 `flags`는 `0` 또는 `FLAG_KILL`(1)이다. `KILL` 존은 `friction_multiplier_raw = 65,536(FixMath.ONE_RAW)`이고 가속도 `(0, 0)`이어야 한다. 그 외 값은 환경 효과를 함께 저작한 것으로 보고 실패한다.
- `obstacles`는 exact key set에 반드시 존재해야 하고 P2-5에서는 빈 배열만 허용한다. 원소가 하나라도 있으면 전체 load 실패다.
- record와 존 배열의 저작 순서는 의미가 없다. record는 `numeric_id`, 존은 `local_id`로 정규화한다. 슬롯과 각 폴리곤 정점의 순서만 보존한다.

### enemies.json schema v1

```json
{
  "schema_version": 1,
  "records": [
    {
      "numeric_id": 1,
      "id": "enemy_stone",
      "base_piece_ref": {"numeric_id": 1, "id": "stone"},
      "override": {
        "max_hp": 120,
        "attack": 24
      }
    }
  ]
}
```

override whitelist:

| 필드 | 허용 | 비고 |
|---|---|---|
| `max_hp`, `attack`, `speed_stat` | ✔ | level 1 값을 대체 |
| `mass_raw`, `radius_raw` | ✔ | 기존 `SimLimits` 안전 범위 재검증 |
| `friction_multiplier_raw` | ✔ | 기존 piece level과 같은 non-negative int64 |
| `critical_basis_points` | ✔ | 0~10,000 |
| `ability_refs` | ✔ | active ABILITY ref 0~32개, numeric ID 중복 금지·오름차순 정규화. 빈 배열은 능력 제거 |
| 그 외 전부 | ✘ | 플래그·태그·`expire`·`spawnable`·`attach_*`·level 2~3 |

- `override`는 부분 집합이며 명시한 키만 대체한다. 빈 객체는 원형 그대로를 뜻한다.
- 적 정의는 level 개념을 갖지 않는다. 언제나 base piece의 level 1을 기준으로 한다.
- 적 record의 존재는 적 원형 정의만 뜻한다. 일반 적 풀 편입은 P2-6, 이벤트 사용 여부는 후속 encounter 계층이 정하며 `pieces.json`에는 별도 eligibility 필드를 추가하지 않는다.

### enum ID

| enum | 값 |
|---|---|
| EffectKind 추가 | 16 `SPAWN_ZONE` |
| BoundaryTypeId | 1 `WALL`, 2 `KILL` |
| ZoneFlags | 0 없음, 1 `KILL` |
| DocumentKind 추가 | 6 `MAPS`, 7 `ENEMIES` |
| Registry Namespace 활성 | 6 `ENEMY`, 7 `MAP` |
| DeploymentSideId | 1 `PLAYER`, 2 `ENEMY` |

`SPAWN_OBSTACLE`·`TELEPORT`·`SET_FLAG`·`COPY_ABILITY`는 계속 loader 거부다.

### abilities.json v5 — SPAWN_ZONE payload

```json
{
  "kind_id": 16,
  "selector": {"kind_id": 1, "relation_id": 0, "limit": 1},
  "value_a": 0,
  "value_b": 0,
  "operation_id": 0,
  "zone": {
    "flags": 0,
    "friction_multiplier_raw": 91750,
    "acceleration_x_raw": 0,
    "acceleration_y_raw": 0,
    "offset_x_raw": 0,
    "offset_y_raw": 0,
    "vertices": [
      {"x_raw": -1048576, "y_raw": -1048576},
      {"x_raw": 1048576, "y_raw": -1048576},
      {"x_raw": 0, "y_raw": 1048576}
    ],
    "duration_turns": 2
  }
}
```

- 정점은 **대상 기준 로컬 좌표**이며 `offset` 뒤 대상 위치에 더한다. 절대 좌표를 저작하지 않는다.
- 각 결과 정점은 `target.position + offset + local_vertex`다. 회전·속도 방향 변환은 없다.
- 결과 폴리곤이 위치 안전 범위를 벗어나면 실패한다.
- flags·마찰·가속·정점 규칙은 map zone과 같고 `local_id`만 없다. 다른 존·body·경계와의 overlap은 허용하며 기존 `zone_id` 합성·소멸 판정으로 처리한다.
- `zone` payload는 `SPAWN_ZONE`에서만 허용되고 다른 kind에서는 금지다.

### canonical fingerprint binary format v5

모든 정수는 little-endian이다. `str`은 `u16 byte_length + UTF-8 bytes`, bool은 `u8 0|1`, `vec2`는 `i64 x_raw + i64 y_raw`다. v4의 기존 typed record 바이트는 바꾸지 않고 ability payload 확장과 MAPS·ENEMIES document만 append한다.

```text
8 bytes  ASCII "FLICKCAT"
u16      fingerprint_format_version = 5
u16      catalog_schema_version = 5
u16      id_registry_schema_version = 1

u16      namespace_count = 8
for namespace_id 1..8 ascending:
  u16    namespace_id
  u32    entry_count
  for numeric_id ascending:
    u32  numeric_id
    str  id
    u8   state_id

u16      document_count = 6
for document_kind_id ascending:
  # 2 PIECES(v3), 3 ABILITIES(v5), 4 STATUSES(v1), 5 SYNERGIES(v1),
  # 6 MAPS(v1), 7 ENEMIES(v1)
  u16    document_kind_id
  u16    document_schema_version
  u32    record_count
  typed records sorted by numeric_id
```

MAPS typed record:

```text
u32 numeric_id; str id; u16 boundary_type_id
u32 boundary_vertex_count; vec2 boundary_vertices[저작 순서]
u16 deploy_count
u32 player_slot_count; vec2 player_slots[인덱스 순서]
u32 enemy_slot_count;  vec2 enemy_slots[인덱스 순서]
u32 zone_count
for local_id ascending:
  u32 local_id; u32 flags; i64 friction_multiplier_raw
  vec2 acceleration
  u32 vertex_count; vec2 vertices[저작 순서]
u32 obstacle_count = 0
```

ENEMIES typed record는 `numeric_id → id → base_piece_ref → override_presence_mask → 존재하는 override 값` 순서다. `base_piece_ref`와 ability ref는 각각 `u32 numeric_id + str id`로 쓴다. mask는 `u16`이며 bit 0~7을 차례대로 `max_hp`, `attack`, `speed_stat`, `mass_raw`, `radius_raw`, `friction_multiplier_raw`, `critical_basis_points`, `ability_refs`에 배정한다. bit 0~6은 set된 필드의 `i64` 값만 필드 순서대로 하나씩 쓰고, bit 7은 `u16 count` 뒤 numeric ID 오름차순 ability ref를 쓴다. unset 필드는 바이트를 쓰지 않으며 빈 `ability_refs` override는 bit 7이 set되고 count가 0이다.

ABILITY v5는 v4 effect 공통 바이트 뒤 payload tag `4`를 `SPAWN_ZONE`에 배정하고 아래를 쓴다. 다른 기존 payload tag `0~3`은 바꾸지 않는다.

```text
u32 flags; i64 friction_multiplier_raw; vec2 acceleration; vec2 offset
u32 vertex_count; vec2 vertices[저작 순서]
u32 duration_turns
```

MAP·ENEMY의 모든 active record는 같은 namespace의 **active registry numeric/string pair와 정확히 일치**해야 한다. retired pair의 record 출현, active pair의 record 누락, numeric/string 교차 참조는 기존 registry 원자적 검증과 동일하게 전체 load 실패다. JSON object key 순서, record·존·reference 배열 순서는 지문에 영향을 주지 않고, 슬롯 및 폴리곤 정점 순서는 의미가 있으므로 지문에 그대로 반영한다.

### 공학 한도

| 항목 | 한도 |
|---|---:|
| 맵 정의 수 | 4,096 |
| 적 정의 수 | 4,096 |
| 경계 정점 | 3 ~ 64 (P0 재사용) |
| 맵당 존 | 32 |
| 존당 정점 | 3 ~ 64 |
| 맵당 장애물 | 0 (예약 필드, 빈 배열만 허용) |
| 진영별 슬롯 | 3 ~ 16 |
| `deploy_count` | 3 ~ 5 |
| 전투당 설치 존 | 32 |
| transition당 `SPAWN_ZONE` | 16 |
| 설치 존 지속 턴 | 0 ~ 1,024 |
| 전투당 총 존(맵 + 설치) | 64 |

한도 초과는 전체 load 또는 transition 실패다. truncate·일부 skip·자동 분할하지 않는다.

## 맵 검증

typed catalog 후보를 모두 만든 뒤 맵 `numeric_id` 오름차순으로 검증한다. 첫 실패에서 멈추고 카탈로그 전체를 거부한다.

```text
1) 경계 폴리곤 — 시계 방향 단순 볼록 3~64정점, 위치 안전 범위
2) 존           — local_id 고유성, 단순 3~64정점, 위치 안전 범위,
                  KILL과 마찰·가속 배타
3) obstacles    — 배열이 정확히 비어 있음
4) 안전 반지름  — catalog_max_radius_raw 계산
5) 슬롯         — 경계 엄격한 내부, KILL 존 엄격한 내부 밖,
                  벽 clearance, 전체 슬롯 상호 비겹침
6) deploy_count — 3~5이고 양 진영 슬롯 수가 각각 deploy_count 이상
```

- `catalog_max_radius_raw`는 **모든 piece의 모든 저작 level `radius_raw`와 모든 enemy의 resolved level 1 `radius_raw`의 최댓값**이다. 맵 record가 하나라도 있는데 후보 집합이 비어 있으면 load 실패다. 맵이 0개면 계산을 요구하지 않는다.
- catalog 후보 조립 순서는 `registry/document exact 검증 → piece·ability·status·synergy typed 정의 → enemy 참조·override resolve → 최대 반지름 계산 → map 검증 → canonical bytes/fingerprint`다. 모든 단계는 임시 후보에서 수행하고 성공할 때만 `DataDB`를 교체한다.
- player·enemy 슬롯을 한 배열로 합쳐 모든 쌍을 검사한다. 두 중심의 거리는 `2 * catalog_max_radius_raw`를 **초과**해야 한다. 같으면 접촉이므로 실패다.
- 슬롯 중심에서 경계의 모든 선분까지의 최소 거리는 `catalog_max_radius_raw`를 **초과**해야 한다. 중심이 경계선 위거나 바깥이면 거리와 무관하게 실패다.
- `KILL` 존은 D-39를 그대로 따른다. 슬롯 **중심**이 `contains_point_strict`일 때만 실패하고 존 경계선 위는 안전하다. 카탈로그 최대 반지름을 `KILL` 존 검사에 팽창 적용하지 않는다.
- 경계·존의 유효성 및 point classification은 P0 `SimPolygon`을 그대로 쓴다. P0에 없는 point-to-segment clearance만 `MapGeometryValidator` 한 곳에서 `SimCollision`의 wall contact와 같은 `wide projection → 선분에 clamp → Q16 nearest ratio → FixVec2.length_raw` 순서로 계산한다. float, Godot 물리 API, epsilon을 쓰지 않으며 raw 거리 동률은 실패다.

## 전투 조립

`BattleSetupBuilder.build(catalog, map_numeric_id, deployment, seed_hi, seed_lo, status)`

```text
1) SimWorld 생성, 시드 주입
2) configure_boundary(경계 정점, boundary_type)
3) add_initial_zones(local_id spawn key, 맵 존)   — local_id 오름차순으로 zone_id 배정
4) deployment 검증·정규화
5) player 슬롯 → enemy 슬롯 순서로 body template 생성
6) 모든 template을 add_initial_bodies 한 번으로 추가
7) BODY_ADDED event를 body ID 순서대로 정확히 소진·검증
8) participant·combatant·BattleState·BattlePieceIdentity 등록 (is_token = false)
9) resolved level의 ability_refs로 binding 생성
10) BattleState.attach_content로 카탈로그·identity·binding 연결
11) BATTLE_START 완료 barrier에서 시너지 계수 동결
```

- 배치 항목은 `(side_id:u16, slot_index:u16, piece_ref?, enemy_ref?, level:u16)`이다. `slot_index`는 0부터 시작한다. `PLAYER`는 active `piece_ref`만 필수이고 `enemy_ref`는 금지하며 level 1~3을 허용한다. `ENEMY`는 active `enemy_ref`만 필수이고 `piece_ref`는 금지하며 level은 정확히 1이어야 한다.
- PLAYER level은 참조 piece에 실제 존재해야 한다. PLAYER piece와 ENEMY base piece는 초기 배치이므로 definition의 `is_token`이 false여야 하며 true면 실패한다.
- 진영별 항목 수는 각각 `deploy_count`와 정확히 같아야 한다. 같은 `(side_id, slot_index)`를 두 항목이 쓰거나 슬롯 인덱스가 해당 진영 배열 범위를 벗어나면 실패다.
- enemy 항목은 base piece level 1에 override를 적용한 resolved level로 body·participant·combatant·binding을 만든다. identity의 `piece_numeric_id`는 base piece ID, level은 1이며 enemy ID를 별도 전투 상태로 저장하지 않는다.
- body는 슬롯 위치·0 속도와 resolved `radius/mass/friction`, definition의 `destructible`로 만든다. participant는 side를 faction으로 쓰고 definition의 `has_turn/counts_for_victory`, `PLAYER && has_turn`일 때만 controllable을 쓴다. destructible일 때만 resolved `max_hp/attack/critical`로 current HP=max HP인 combatant를 만든다.
- 배치 배열의 저작 순서는 의미가 없다. 정렬은 `(side_id, slot_index)`다.
- 초기 body template은 fresh world의 `add_initial_bodies`에 **한 번만** 전달한다. P2-5 spawn key는 player 슬롯 오름차순 뒤 enemy 슬롯 오름차순에 연속 `1..2*deploy_count`를 부여한다. U-03이 장애물을 승인하면 obstacle local ID 오름차순 template을 앞에 삽입한 뒤 전체에 연속 key를 다시 부여한다. 이것이 P2-M14의 장애물 → player → enemy 최종 순서다.
- `add_initial_bodies`가 낸 `BODY_ADDED` event는 개수·type·body ID를 검증하며 모두 소비한다. 미소비 event가 남은 world는 `BattleState.create_with_combatants`에 넘기지 않는다.
- 조립은 원자적이다. 한 단계라도 실패하면 `BattleState`를 만들지 않는다.
- P1 `p1_graybox_fixture.gd`는 그대로 둔다. 기존 P1 골든이 이 경로로 바뀌지 않는다.

## 설치 존

- `SPAWN_ZONE`은 대상 위치 + 오프셋에 폴리곤을 놓고 `BattleState`의 mutation request를 거쳐 기존 `SimWorld.queue_zone_spawn`으로 barrier에 넣는다. `event_type_id`는 effect kind 16, `ordinal`은 transition 내 application ordinal이다.
- request는 기존 `(tick, cause_body_id, event_type_id, ordinal)` 오름차순으로 처리한다. 각 request를 commit하기 직전 `SimWorld.next_zone_id()`를 예정 ID로 캡처하고 성공 뒤 같은 ID의 zone 존재를 확인해 `ZoneSpawnState`를 등록한다. 별도 ID 축이나 zone event를 만들지 않는다.
- transition당 요청 수, 전투당 설치 존 수, 맵+설치 총 존 수를 queue 전에 검사한다. pending 요청도 수에 포함하며 하나라도 넘으면 transition 전체를 실패시킨다.
- `duration_turns`가 0이 아니면 기존 P2-D24와 같은 전역 `TURN_END` 완료 처리에서 1 감소하고, 0에 도달하면 `SimWorld.remove_zone`으로 제거한다. `complete_turn_end` 뒤의 `completed_turn_index = max(0, turn_index - 1)`을 쓰며 `applied_turn_index < completed_turn_index`인 상태만 감소한다.
- 따라서 설치한 전역 턴과 바로 이어지는 `TURN_END`에서는 감소하지 않는다.
- `duration_turns = 0`도 영구 설치 존임을 식별할 수 있도록 `ZoneSpawnState(remaining_turns=0)`를 보관한다. timed 존은 감소 결과가 0이 되는 barrier에서 즉시 world와 상태 목록 양쪽에서 제거한다.
- 설치 존도 D-36의 `zone_id` 오름차순 합성에 그대로 참여한다. 우선순위는 없다.
- `KILL` 설치 존은 다음 정산에서 안에 있는 body를 파괴한다. 파괴는 D-23의 일반 파괴이며 `ON_DEATH_SELF`를 정상 발생시킨다.
- 전투 종료 시 설치 존을 명시적으로 제거하지 않는다. 전투 상태와 함께 폐기된다.
- zone request, world, `ZoneSpawnState`, 수명 감소, RNG, report는 P2-E10 transition backup에 모두 포함한다. queue·commit·등록·제거 중 하나라도 실패하면 호출 전 bytes로 복원한다. 성공 반환 시 pending mutation과 pending world spawn은 모두 0개다.

## 상태 모델과 공개 API

신규 immutable/typed 객체:

```text
MapSlotDefinition
MapZoneDefinition
MapDefinition
MapGeometryValidator
EnemyOverrideDefinition
EnemyDefinition
ZoneSpawnPayloadDefinition
BattleDeploymentEntry
ZoneSpawnState
```

공개 경계:

```text
ContentCatalog.map_by_numeric_id(id, status) -> MapDefinition
ContentCatalog.enemy_by_numeric_id(id, status) -> EnemyDefinition
EnemyDefinition.resolved_level(catalog, status) -> PieceLevelDefinition

BattleDeploymentEntry.create_player(slot_index, piece_ref, level, status)
BattleDeploymentEntry.create_enemy(slot_index, enemy_ref, status)

BattleSetupBuilder.build(
    catalog, map_numeric_id, deployment, seed_hi, seed_lo, status
) -> BattleState

BattleState.zone_spawn_count() -> int
BattleState.zone_spawn_at(index, status) -> ZoneSpawnState
```

- 맵·적 정의는 불변이며 `BattleState`가 참조를 보관하지 않는다. 조립 시점에 값만 꺼낸다.
- `EnemyDefinition.resolved_level`은 base piece의 level 1에 override를 적용한 새 값 객체를 만든다. 원형을 변형하지 않는다.
- `zone_spawn_at`은 `zone_id` 오름차순 불변 사본을 반환한다. map 초기 존은 이 목록에 들어가지 않는다.

## snapshot과 호환성

- `BattleSnapshot.SCHEMA_VERSION`을 **7**로 올리고 legacy v1~6 decode를 유지한다. `SimSnapshot`은 v2 그대로다.
- 현재 v6 동적 기물 섹션의 gate는 `DYNAMIC_SCHEMA_VERSION = 6`으로 이름을 분리하고, 설치 존 섹션만 새 `SCHEMA_VERSION = 7` gate를 쓴다. v6 decode가 동적 기물 상태를 누락해서는 안 된다.
- v7은 v6의 `piece_origins` 배열 뒤, `sim_length` 앞에 아래 섹션을 append한다. `ZoneSpawnState`는 `zone_id` 오름차순이다.

```text
u32 zone_spawn_count
repeat zone_spawn_count:
  u32 zone_id
  u32 remaining_turns
  u32 applied_turn_index
u32 sim_length
bytes sim_snapshot_v2
```

- decode는 `zone_spawn_count <= 32`, zone ID의 0 아님·유일·엄격한 오름차순, `remaining_turns <= 1,024`, `applied_turn_index <= turn_index`, 각 ID가 복원된 `SimWorld` 존에 실제 존재함, world 총 존 `<= 64`를 검증한다. map 초기 존과 설치 존의 구분은 이 목록 자체가 정본이므로 capture는 초기 존을 넣지 않고 decode는 목록의 ID를 설치 존으로 복원한다.
- legacy v1~6에는 설치 존 기능이 없었으므로 빈 `ZoneSpawnState` 목록으로 decode하고, 다시 capture하면 v7 bytes를 낸다.
- 경계 타입·경계 정점·존 전체·`next_zone_id`는 이미 `SimSnapshot`이 인코딩한다. v7은 그중 어느 존이 설치 존이고 수명이 얼마 남았는지만 보존한다.
- 어떤 맵으로 시작했는지는 콘텐츠 지문 + 복원된 world 상태로 충분히 재현된다. 맵 ID를 따로 저장하지 않는다.
- P0 `SimSnapshot` bytes·골든은 불변이다. P1/P2의 `BattleSnapshot` v6 기준값은 동작·턴·tick 불변을 먼저 확인한 뒤 v7 bytes/hash로 명시적으로 이관한다. 설명되지 않은 결과 변화가 있으면 구현을 중단한다.

## 오류 계약

기존 숫자를 재사용하지 않고 아래 값을 append한다.

| enum | 값 | 이름 |
|---|---:|---|
| `ContentStatus.Operation` | 12 | `MAP_VALIDATE` |
|  | 13 | `ENEMY_RESOLVE` |
| `ContentStatus.FieldId` | 76 | `ZONE_PAYLOAD` |
|  | 77 | `BOUNDARY_TYPE_ID` |
|  | 78 | `BOUNDARY_VERTICES` |
|  | 79 | `DEPLOY_COUNT` |
|  | 80 | `PLAYER_SLOTS` |
|  | 81 | `ENEMY_SLOTS` |
|  | 82 | `ZONES` |
|  | 83 | `LOCAL_ID` |
|  | 84 | `ACCELERATION_X_RAW` |
|  | 85 | `ACCELERATION_Y_RAW` |
|  | 86 | `VERTICES` |
|  | 87 | `OBSTACLES` |
|  | 88 | `BASE_PIECE_REF` |
|  | 89 | `OVERRIDE` |
| `SimStatus.Code` | 57 | `INVALID_MAP_DEFINITION` |
|  | 58 | `INVALID_MAP_SLOT` |
|  | 59 | `INVALID_DEPLOYMENT` |
|  | 60 | `ZONE_LIMIT_EXCEEDED` |
| `SimStatus.Operation` | 130 | `MAP_GEOMETRY_VALIDATE` |
|  | 131 | `BATTLE_SETUP_BUILD` |
|  | 132 | `BATTLE_ZONE_SPAWN` |
|  | 133 | `BATTLE_ZONE_EXPIRE` |

콘텐츠 오류는 기존 `document_kind_id → record_numeric_id → field_id` 문맥을 쓴다. 배열 원소의 세부 위치가 필요하면 parse 단계의 line/column/byte offset을 보존한다. 전투 오류는 first-error-wins이며 `BATTLE_SETUP_BUILD`의 `detail_a/detail_b`는 `side_id/slot_index`, 존 spawn·expire는 `zone_id/현재 개수 또는 remaining_turns`로 고정한다.

## 대상 파일

신규:

```text
src/core/data/map_slot_definition.gd
src/core/data/map_zone_definition.gd
src/core/data/map_definition.gd
src/core/data/map_geometry_validator.gd
src/core/data/enemy_override_definition.gd
src/core/data/enemy_definition.gd
src/core/data/zone_spawn_payload_definition.gd
src/core/data/maps.json
src/core/data/enemies.json
src/core/battle/battle_deployment_entry.gd
src/core/battle/battle_setup_builder.gd
src/core/battle/zone_spawn_state.gd
pipeline/schemas/p2-maps-v1.schema.json
pipeline/schemas/p2-enemies-v1.schema.json
pipeline/schemas/p2-abilities-v5.schema.json
pipeline/schemas/p2-catalog-v5.schema.json
pipeline/tests/p2_maps_enemies_environment_test.gd
pipeline/tests/p2_maps_enemies_reference.py
pipeline/tests/run_p2_maps_enemies_environment.py
pipeline/tests/fixtures/p2_maps_enemies/**
```

수정:

```text
src/core/data/content_ids.gd
src/core/data/content_limits.gd
src/core/data/content_status.gd
src/core/data/content_catalog.gd
src/core/data/content_catalog_builder.gd
src/core/data/content_canonical_encoder.gd
src/core/data/catalog.json
src/core/data/abilities.json
src/core/battle/ability_effect_definition.gd
src/core/battle/battle_mutation_request.gd
src/core/battle/battle_state.gd
src/core/battle/battle_snapshot.gd
src/core/battle/battle_limits.gd
src/core/battle/effect_resolver.gd
src/core/sim/sim_status.gd
pipeline/tests/fixtures/p2_content_catalog/**
pipeline/tests/fixtures/p2_effect_resolution/**
pipeline/tests/fixtures/p2_status_synergy/**
pipeline/tests/fixtures/p2_dynamic_piece/**
docs/design/game_design.md
docs/specs/p2_index.md
AGENTS.md
HANDOFF.md
```

**`src/core/sim/`의 시뮬레이션 코드는 수정하지 않는다.** `configure_boundary`, `add_initial_zones`, `queue_zone_spawn`, `remove_zone`이 이미 P0에 있고 스냅샷도 이를 덮는다. `sim_status.gd`의 append-only enum 추가만 예외다. `game_design.md` 수정은 15.2의 중복 `size` 필드를 제거하고 예약 `obstacles` 경계를 맞추는 문서 정합 작업뿐이다. 씬·UI·에셋·매니페스트는 수정하지 않는다.

## 필요 에셋

없음. runtime records는 비어 있고 모든 맵·적 정의는 headless test fixture에만 존재한다. 매니페스트 등록 대상이 없다.

실제 맵 배경 placeholder는 P2-6 회색상자에서 필요할 때 별도 승인·등록한다. 정적 장애물 아트와 `MapRoot/Obstacles` 연결은 U-03 뒤로 미룬다. 본 명세에서는 후보 ID도 선점하지 않는다.

## 수용 기준

1. maps v1·enemies v1·abilities v5·catalog v5 schema가 exact key·타입·범위·배열 한도를 검증하고 pieces v3은 변하지 않는다.
2. runtime `maps.json`·`enemies.json`은 schema-valid 빈 records이며 production 수치를 추가하지 않는다.
3. MAP/ENEMY active·retired registry pair의 누락·불일치·교차 참조가 기존 namespace 규칙대로 전체 load 실패한다.
4. 반시계 방향·오목·자기 교차·2정점·65정점 경계가 각각 실패한다.
5. 중복·0 `local_id`, `KILL`과 마찰·가속 동시 사용, 존 자기 교차·2/65정점·위치 범위 이탈이 각각 실패한다.
6. `obstacles` 누락과 non-empty 배열이 실패하고 빈 배열만 통과한다.
7. 슬롯 중심이 경계 밖·선 위, `KILL` 존 엄격한 내부일 때 실패하고 `KILL` 존 경계선 위는 통과한다.
8. 슬롯-벽 거리가 최대 반지름과 같거나 작을 때, player/enemy 전체 슬롯 쌍 거리가 최대 지름과 같거나 작을 때 실패한다.
9. `catalog_max_radius_raw`가 모든 piece level과 resolved enemy radius override를 포함하며, 반지름 증가가 이전 맵을 실패시킨다.
10. 맵이 존재하지만 반지름 후보가 없으면 실패하고, 맵 records가 0개면 빈 piece catalog도 통과한다.
11. `deploy_count` 2·6과 진영별 슬롯 부족이 실패하고 3·5는 통과한다.
12. unknown override key와 whitelist 밖 필드가 실패한다.
13. override가 명시한 키만 대체하고 빈 override가 base piece level 1과 같은 resolved 값을 만든다.
14. override된 스탯·질량·반지름·마찰·크리티컬이 기존 안전 범위 밖이면 실패한다.
15. `ability_refs: []` override는 능력을 제거하고 key 미지정은 base 능력을 보존한다.
16. `ai_grade`·`ai_profile`·`enemy_eligible` 키는 unknown key로 실패한다. enemy record 자체는 일반 풀·이벤트 사용 여부를 결정하지 않는다.
17. canonical v5 Godot bytes가 독립 Python known-answer와 일치하고 SHA-256 fingerprint도 같다.
18. record·존·ability ref 배열 순서를 교란해도 fingerprint가 같고 슬롯·폴리곤 정점 순서를 바꾸면 fingerprint가 달라진다.
19. unset override와 명시된 동일 값 override, unset ability refs와 빈 override가 presence mask 때문에 서로 다른 canonical bytes를 낸다.
20. `BattleSetupBuilder`가 P2-5의 빈 장애물 조건에서 player 슬롯 → enemy 슬롯 순으로 body ID를 배정한다. 장애물 선두 배정의 실행 검증은 U-03 활성화 명세가 소유한다.
21. 배치 배열 저작 순서를 교란해도 같은 body ID·identity·binding·초기 snapshot bytes가 나온다.
22. 각 진영 배치 수 불일치, 슬롯 중복·범위 이탈, side와 ref 종류 불일치가 실패한다.
23. PLAYER level 0·4·참조 piece에 없는 level, ENEMY level 1 이외 값, 초기 배치가 `is_token = true`인 piece/base piece 참조가 실패한다.
24. enemy override가 body·participant·combatant·ability binding에 반영되고 identity는 non-token base piece ID/level 1을 보존한다.
25. 조립 실패 시 `BattleState`가 반환되지 않고 부분 world·registry가 남지 않는다.
26. 조립된 모든 초기 identity가 `is_token = false`이고 `BATTLE_START`에서 시너지 계수가 정상 동결된다.
27. `boundary_type = KILL` 경계 이탈은 D-23의 일반 파괴, `WALL` 경계는 피해 없는 반사로 처리된다.
28. `SPAWN_ZONE`이 대상 로컬 좌표 + offset으로 폴리곤을 만들고 2/65정점·위치 범위 이탈을 거부한다.
29. 여러 설치 요청이 `(tick,cause,effect kind,ordinal)` 순으로 ID를 받고 D-36의 `zone_id` 오름차순 합성에 참여한다.
30. 설치한 턴에는 수명이 감소하지 않고 다음 전역 `TURN_END`부터 감소하며 timed 존은 0 도달 즉시 제거된다.
31. `duration_turns = 0` 설치 존이 `ZoneSpawnState(remaining=0)`로 snapshot·restore 뒤에도 영구 유지된다.
32. `KILL` 설치 존이 다음 정산에서 일반 파괴와 `ON_DEATH_SELF`를 정상 발생시킨다.
33. queue·commit·등록·expire 중 실패하면 world·존 상태·RNG·report가 transition 전과 byte-for-byte 같다.
34. 맵 32존·진영별 16슬롯·설치 32존·전투 총 64존·transition 16요청·지속 1,024턴의 경계값과 초과값이 각각 성공·실패한다.
35. `SPAWN_OBSTACLE`은 loader에서 계속 거부된다. 기존 `SPAWN_PIECE` 중립 fixture는 회귀 통과하되 정적 장애물로 해석하지 않는다.
36. BattleSnapshot v7이 설치 존 상태를 exact 바이트로 저장하고 v1~6을 빈 설치 존 목록으로 decode·v7 recapture한다.
37. 손상된 v7 count·정렬·중복·존 참조·remaining·applied turn·trailing bytes가 각각 decode 실패한다.
38. P0 SimSnapshot bytes/hash는 불변이고 P1/P2 BattleSnapshot은 결과·턴·tick 불변 확인 뒤 v7 골든으로 이관된다.
39. 독립 Python reference가 맵 검증·canonical v5·body/zone ID·존 합성·설치 존 수명의 known-answer를 계산한다.
40. 같은 fixture 1,000회와 중간 v7 snapshot restore가 같은 final bytes/hash를 만든다.
41. `run_p2_maps_enemies_environment.py`가 `verify --full`에 자동 발견된다.
42. P2-4~1, P1-1~5, P0 narrow·결정론·충돌 경계 회귀와 Godot 4.6.3 활성 `PYTHONUTF8=1 python pipeline/scripts/verify.py --full`이 통과한다.

## 구현 순서 — 전체 승인 뒤 적용

1. maps·enemies schema와 독립 Python reference·negative fixture를 먼저 고정한다.
2. typed 맵·적 정의와 catalog canonical v5, fingerprint v5를 구현한다.
3. P0 `SimPolygon`과 checked clearance를 사용한 맵 검증 6단계를 구현한다.
4. 적 override whitelist와 `resolved_level`을 구현한다.
5. `BattleSetupBuilder`와 body ID 배정 순서를 구현한다.
6. `SPAWN_ZONE`과 설치 존 수명을 effect resolver·rollback에 편입한다.
7. BattleSnapshot v7 encode/decode/restore와 legacy v1~6 migration fixture를 구현한다.
8. P0 SimSnapshot 불변과 P1/P2 BattleSnapshot 동작 불변을 확인한 뒤 v7 골든을 이관한다.
9. 검증·조립·존·한도·rollback·1,000회 수용 테스트를 통과시킨다.
10. P2-4~1, P1, P0 회귀 뒤 Godot 활성 `verify --full`을 실행한다.
11. 구현·검증 결과를 P2 인덱스·AGENTS·HANDOFF에 기록한다.

## 승인된 결정 요약

정본 ⬜ 미정을 임의로 확정하지 않는다. 아래 수정 방향과 P2-M01~21 전체는 2026-08-24 승인되었다.

| 항목 | 반영안 |
|---|---|
| 정적 장애물 | P2-5 비범위. `obstacles`는 빈 배열만 허용하고 U-03에서 schema 상승 뒤 활성화 |
| `SPAWN_OBSTACLE` | 계속 loader 거부. `SPAWN_PIECE`를 정적 장애물 별칭으로 쓰지 않음 |
| 초기 body ID | 최종 계약은 장애물 local ID → player slot → enemy slot. P2-5 관찰 순서는 player → enemy |
| 슬롯 안전 반지름 | 모든 piece level + resolved enemy override를 포함한 카탈로그 최대 반지름 |
| 적 pool 축 | `enemy_eligible`를 추가하지 않고 일반 풀은 P2-6, 이벤트 사용은 encounter 계층에서 결정 |
| snapshot | BattleSnapshot v7, legacy v1~6 decode, SimSnapshot v2 유지 |

아래는 P2-5가 **확정하지 않고 미결로 유지**하는 정본 항목이다. 구현을 막지 않으며 fixture로 우회한다.

U-01 맵 목록 · U-02 환경 요소 채택·수치 · U-03 장애물 종류 · U-05 보스 · U-06 엘리트 · U-10 적 스탯 스케일·AI 등급 · U-22 소멸 영역 엘리트 비율 · U-34 판 크기·슬롯 개수

## 승인 기록

2026-08-24 사용자가 초기 body ID `장애물 → player → enemy`, 슬롯 안전 검사 `카탈로그 최대 반지름`을 선택했다. 이어 정적 장애물 연기, `SPAWN_OBSTACLE` 거부, BattleSnapshot v7, `enemy_eligible` 제거, local zone ID·canonical·배치 계약을 포함한 수정 권장안을 승인해 이 초안에 반영했다.

2026-08-24 사용자가 P2-M01~21 전체 명세를 승인했다. `status: approved`로 전환하고 이 문서 범위의 구현 권한을 열었다.

## 구현·검증 기록

- maps v1·enemies v1·abilities v5·catalog v5와 canonical fingerprint v5를 구현했다. runtime map/enemy records는 비어 있고 production 수치는 추가하지 않았다.
- P0 폴리곤 규칙과 카탈로그 최대 반지름을 재사용하는 맵·슬롯 검증, exact-key 적 override와 `BattleSetupBuilder`의 player → enemy body ID 배정을 구현했다. 정적 장애물은 계속 거부한다.
- `SPAWN_ZONE`, local 좌표 합성, 설치 턴 제외 수명, 영구 존, transition rollback을 구현하고 `BattleSnapshot` v7에 설치 존 상태를 저장했다. legacy v1~6은 빈 설치 존으로 복원한다.
- 독립 Python schema·기하·canonical KAT와 Godot 18개 grouped check가 통과했다. P2-5 setup·존 설치·snapshot 복원을 1,000회 반복했고, P1-5 terminal 결과·20턴·10,699틱은 유지한 채 승인 참조 P2-M15로 v7 hash `8e822066ae3c4b2fb9ad817cf543db4e8e0f7a7eb4e14018cb99f971b935c0ac`로 이관했다.
- P0/P1/P2 회귀와 Godot 4.6.3 활성 `verify --full` 자동 발견 러너 22종이 통과했다.
