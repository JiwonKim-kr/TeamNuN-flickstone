# P5 · 핵심 플레이 쇼케이스 수직 슬라이스 명세 초안

| 항목 | 내용 |
|---|---|
| status | `draft` |
| 작성 | 2026-08-26 |
| 대상 브랜치 | `codex/core-play-showcase` |
| 단계 | P5 폴리시 · 외부 공개용 핵심 플레이 수직 슬라이스 |
| 상위 목표 | 별도 설명 없이 8~12분 안에 Flickstone의 전투와 런 성장을 이해하고 개발 Act를 완주할 수 있다 |
| 선행 구현 | P0~P4, P5-DZ, P5-BR, P5-CA, P5 공격 템포 조정 |
| 구현 권한 | 없음. P5-CS01~10과 본문 전체 승인 후 구현 가능 |

## 목적

현재 구현된 5층 개발 Act를 버리지 않고, 첫 플레이어가 다음 핵심 재미를 한 런에서 순서대로 경험하게 한다.

1. 드래그 거리로 힘을 정하고 궤적을 읽는 조준
2. 벽 반사와 기물 간 연쇄 충돌
3. 탱탱볼의 높은 탄성, 원시인의 clean-launch 2배 피해, AI의 계산 궤적
4. 파괴·강철 시너지와 전투별 편성 변경
5. 턴 시작 위험 구역의 위치 전술
6. 영입·상점/이벤트·휴식 합성·엘리트·보스로 이어지는 런 성장

이 명세는 새로운 전투 규칙을 만드는 작업이 아니다. 이미 승인·구현된 판정을 외부인이 이해할 수 있도록 시작 편성, 표시 정보, 짧은 상황별 안내와 파생 전투 피드백을 연결한다.

## 목표 플레이 흐름

```text
새 런
  → 탱탱볼·원시인·병뚜껑 기본 편성
  → 일반 전투: 드래그·반사·clean hit·위험 구역
  → 영입 보상
  → 상점 또는 이벤트
  → 일반 또는 엘리트 전투: AI 교체·시너지 변화
  → 휴식: 중복 병뚜껑 합성
  → 보스
  → 런 완료
```

개발 Act의 5개 층, 7개 결정론 노드 graph, encounter와 reward RNG는 유지한다. 한 경로에서 상점과 이벤트를 모두 방문하게 만들지 않으며, 선택하지 않은 분기는 다음 런의 변주로 남긴다.

## 범위

- 개발용 새 런 시작 로스터와 기본 편성 순서 변경
- core catalog와 분리된 UI 전용 한글 콘텐츠 표시 문서
- 런 시작·노드·편성·보상·상점·이벤트·휴식·terminal 정보 구조 정리
- 첫 조준, 위험 구역, 기물 개성, 편성 교체, 합성을 설명하는 비차단 상황별 안내
- 기존 전투 event/result에서 파생한 피해·clean hit·위험 구역·파괴 피드백
- 640×1,024 native/Web 공용 레이아웃 유지
- 변경 범위의 정적 검토와 회귀 테스트 코드 보강
- 사용자 지시 뒤 최소 실행 검증과 8~12분 사람 완주 검수

## 비범위

- 새 기물, 체스·원소 정식 콘텐츠, 신규 ability/status/synergy
- 새로운 map, encounter, node type 또는 3막 콘텐츠
- 피해·물리·CTB·AI 평가식과 현재 P5 수치 변경
- 기존 save 자동 마이그레이션 또는 여러 save slot
- 전체 튜토리얼 캠페인, 설정 메뉴, 패드·모바일 조작
- SE/BGM과 신규 bitmap asset
- P6 최종 밸런싱·해금
- P2 terminal, P4 four-run, `verify --full` 등 장시간 검증 부채 해소
- 현재 runtime 콘텐츠에서 도달하지 않는 transform 및 neutral combatant 계약 보정

## 선행 승인과 충돌

이 명세는 다음 승인 결정을 개발 Act에 한해 재승인한다.

- `p4_run_ui_save_completion.md` P4-F14: 시작 로스터 `baduk_stone` 3기 + `bottle_cap` 3기
- `p5_caveman_ai_runtime.md` P5-CA16: 시작 로스터 유지

변경은 개발용 새 런의 initial piece 목록에만 적용한다. catalog, 기존 save, 전투 snapshot, reward pool과 정식 시작 덱 미정 상태는 바꾸지 않는다.

## 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P5-CS01 | 구현은 `codex/core-play-showcase`에서 진행하고 사람 승인된 결과만 `main`에 병합한다 | 제출 수직 슬라이스의 빠른 반복과 main 안정성 분리 | ⬜ 승인 대기 |
| P5-CS02 | 개발 새 런의 initial key 1~6을 `bouncy_ball`, `caveman`, `bottle_cap`, `ai_core`, `bottle_cap`, `baduk_stone` L1으로 둔다 | 첫 전투에서 물리 개성과 파괴 시너지를 보이고, AI 교체와 병뚜껑 합성을 한 런에서 보장 | ⬜ 승인 대기 |
| P5-CS03 | 기존 편성 UI의 첫 3기 기본 선택을 유지해 첫 전투는 탱탱볼·원시인·병뚜껑이 되며, 이후 AI 교체는 안내하되 자동 강제하지 않는다 | 조작을 늘리지 않고 선택과 시너지 변화를 직접 경험 | ⬜ 승인 대기 |
| P5-CS04 | 5층 Act·7노드 graph·3회 전투 경로와 현재 전투 수치를 유지한다 | 신규 런 코어 작업 없이 구현된 전체 흐름을 재사용 | ⬜ 승인 대기 |
| P5-CS05 | 이름·한 줄 설명은 UI 전용 strict presentation JSON과 읽기 전용 loader로 제공하고 core fingerprint·snapshot에 포함하지 않는다 | schema/golden 이관 없이 내부 ID 노출 제거 | ⬜ 승인 대기 |
| P5-CS06 | 안내는 입력을 막는 모달이 아니라 현재 phase에 붙는 짧은 문장으로 반복 표시한다. 별도 튜토리얼 저장 상태를 만들지 않는다 | 첫 플레이 이해도와 구현 속도 양립 | ⬜ 승인 대기 |
| P5-CS07 | 피해 숫자, `무심 ×2`, `위험 구역 −15`, `파괴`는 기존 권위 event/result의 UI 파생 표현이며 RNG·snapshot·판정에 관여하지 않는다 | 핵심 충돌 결과를 즉시 읽게 하면서 결정론 코어 보존 | ⬜ 승인 대기 |
| P5-CS08 | 첫 구현에서는 새 SE/BGM을 만들지 않고, 플레이 흐름 승인 뒤 최소 SE를 별도 작업으로 결정한다 | 오디오 backend와 검수 대기로 핵심 플레이 구현이 막히지 않게 함 | ⬜ 승인 대기 |
| P5-CS09 | 현재 쇼케이스에서 도달하지 않는 transform clean-hit 배율, neutral 피해 조건, visual alpha 엄격성은 별도 보정 부채로 유지한다 | 데모 핵심 경로에 직접 영향 없는 작업을 critical path에서 제외 | ⬜ 승인 대기 |
| P5-CS10 | 테스트 코드는 구현하되 실행 `play test`와 Godot 검증은 사용자의 별도 지시가 있을 때만 수행한다 | 최신 작업 지시 준수 | ⬜ 승인 대기 |

## 시작 로스터·편성 계약

| initial key | piece | level | 첫 기본 편성 |
|---:|---|---:|---|
| 1 | `bouncy_ball` | 1 | 포함 |
| 2 | `caveman` | 1 | 포함 |
| 3 | `bottle_cap` | 1 | 포함 |
| 4 | `ai_core` | 1 | 미포함 |
| 5 | `bottle_cap` | 1 | 미포함 |
| 6 | `baduk_stone` | 1 | 미포함 |

- 첫 편성의 `caveman`+`bottle_cap`은 `destruction` 2기 시너지를 활성화한다.
- 다음 편성에서 `ai_core`를 넣으면 계산 표시를 경험할 수 있다.
- `bottle_cap`+`ai_core`는 `steel` 2기 시너지를 활성화한다.
- 중복 병뚜껑 두 기는 floor 4 REST의 기존 합성 선택을 보장한다.
- 기존 save의 roster는 변경하지 않는다. 새 목록은 명세 승인 뒤 생성한 개발 새 런부터 적용한다.

## UI presentation 문서

신규 UI 전용 문서 후보는 `src/ui/presentation/content_presentations.json`이다. core content fingerprint에 포함하지 않는다.

최상위 exact key:

```json
{
  "schema_version": 1,
  "pieces": [],
  "synergies": [],
  "relics": [],
  "consumables": []
}
```

각 record는 현재 catalog의 numeric/string ID 쌍과 정확히 일치해야 한다.

```json
{
  "numeric_id": 4,
  "id": "bouncy_ball",
  "display_name": "탱탱볼",
  "summary": "벽과 기물에 강하게 반사되어 연쇄 충돌을 만든다."
}
```

필수 표시 대상은 정식 기물 5종과 개발 `graybox_striker`, 활성 시너지 2종, 개발 유물 1종, 소모품 1종이다. 중복·알 수 없는 ID·잘못된 타입·누락 필드는 초기화 오류다. 아직 presentation record가 없는 미래 콘텐츠는 primary UI에서 조용히 내부 ID로 대체하지 않고 `미등록 콘텐츠 #<numeric_id>`로 표시한다.

`ContentPresentationCatalog`는 UI 전용 `RefCounted` 읽기 모델로 두고 `RunState`, `BattleState`, `ContentCatalog`를 수정하지 않는다. 런과 전투 UI는 numeric ID로 조회하며 콘텐츠 문자열 분기를 만들지 않는다.

## 상황별 안내 계약

| 위치 | 표시 문장 |
|---|---|
| 시작 | `새 런을 시작해 5층 보스를 격파하세요.` |
| 첫 MAP_CHOICE | `노드를 선택하면 자동 저장됩니다. 전투 전에 출전 기물 3기를 고릅니다.` |
| FORMATION | `탱탱볼은 반사, 원시인은 벽·아군 접촉 전 2배, AI는 계산 궤적을 제공합니다.` |
| 첫 AIM | `기물 중심에서 멀리 당길수록 강하게 발사합니다.` |
| 위험 구역 전투 | `주황 위험 구역 위 기물은 자기 턴 시작에 15 피해를 받습니다.` |
| 첫 전투 뒤 | `편성을 바꿔 다른 능력과 시너지를 시험하세요.` |
| AI가 roster에 있고 미편성 | `AI를 출전시키면 각도·힘·첫 충돌 대상을 볼 수 있습니다.` |
| REST | `같은 레벨의 같은 기물 2개를 합쳐 다음 레벨로 성장시킵니다.` |
| BOSS | `보스를 격파하면 이번 개발 Act를 완주합니다.` |

안내는 현재 state에서 파생한다. 표시 여부가 save, snapshot, RNG, 전투 결과에 들어가지 않는다.

## 전투 피드백 계약

- 충돌 피해가 확정되면 피해자 위치에 `-N`을 짧게 표시한다.
- clean-hit 배율이 실제 적용된 피해에는 `무심 ×2`를 함께 표시한다.
- turn-start damage zone 피해에는 주황색 `위험 구역 -15`를 표시한다.
- 기물이 제거된 위치에는 `파괴`를 표시한다.
- 같은 transition의 여러 결과는 stable result sequence 순서로 생성하고, 겹치면 화면 y축으로 일정 간격만큼 쌓는다.
- 피드백 수명과 애니메이션 시간은 UI delta만 사용하며 simulation tick, RNG, state hash에 포함하지 않는다.
- feedback node가 없어도 전투 판정과 run outcome은 동일해야 한다.

## 런 화면 정보 구조

- header: `Flickstone · 개발 Act`, 현재 층/5, life, gold
- node button: 층, 유형, 한 줄 결과 설명. node ID는 primary label에서 숨기고 오류/디버그 정보에만 남긴다.
- roster: 한글 기물명, 레벨, 한 줄 능력, 현재 출전 여부
- formation: 선택 기물과 활성 시너지 이름·효과를 즉시 표시
- reward/shop/event/rest: 선택 결과를 누르기 전에 한글로 설명
- terminal: 완료 층, 남은 life, 최종 roster와 획득 유물·소모품 요약
- seed와 fingerprint는 시작 화면의 재현 정보와 오류 진단에만 남기고 일반 진행 header에서는 숨긴다.

## 결정론·오류 계약

- 시작 roster 변경 외 simulation 입력과 결정론 순서는 바뀌지 않는다.
- presentation과 안내·feedback은 UI 파생 데이터이며 snapshot과 fingerprint에 들어가지 않는다.
- presentation 로드 실패는 primary run UI를 시작하지 않고 오류 code와 document section을 표시한다.
- 기존 continue save는 현재 catalog fingerprint가 일치하면 그대로 복원한다.
- 새 런 roster 변경에 따라 자동 runner의 초기 snapshot/golden이 바뀌는 경우 해당 기대값만 승인 근거와 함께 이관한다.
- feedback event가 누락되거나 중복돼도 core 상태를 수정하거나 전투 진행을 멈추지 않는다. UI 자체의 순서·중복은 테스트 가능한 관찰 상태로 노출한다.

## 대상 파일

신규 후보:

```text
docs/specs/p5_core_play_showcase.md
src/ui/presentation/content_presentations.json
src/ui/presentation/content_presentation_catalog.gd
src/ui/presentation/combat_feedback_layer.gd
pipeline/tests/p5_core_play_showcase_test.gd
pipeline/tests/p5_core_play_showcase_test.tscn
pipeline/tests/run_p5_core_play_showcase.py
```

수정 후보:

```text
src/core/autoload/run_manager.gd
src/ui/run/run_graybox.gd
src/ui/battle/p2_content_graybox.gd
scenes/run_graybox.tscn
scenes/p2_content_graybox.tscn
pipeline/scripts/verify.py
pipeline/tests/p4_run_ui_save_completion_test.gd
AGENTS.md
HANDOFF.md
docs/design/game_design.md
```

새 bitmap/audio asset과 manifest entry는 없다.

## 수용 기준

1. 개발 새 런의 roster 순서와 첫 기본 편성이 P5-CS02~03 표와 정확히 일치한다.
2. 기존 continue save는 roster를 재작성하지 않고 복원한다.
3. 첫 편성에서 탱탱볼·원시인·병뚜껑과 파괴 시너지가 한글로 설명된다.
4. AI 교체 시 계산 표시와 강철 시너지 가능성을 편성 화면에서 이해할 수 있다.
5. 첫 AIM과 위험 구역에서 조작·피해 규칙 안내가 전투 입력을 막지 않는다.
6. 실제 피해, clean hit, turn-start zone, 파괴 결과에 대응하는 UI feedback이 권위 결과와 같은 순서로 표시된다.
7. run progression primary UI에 콘텐츠 string ID, fingerprint, node ID가 노출되지 않는다.
8. 상점/이벤트/휴식 선택 결과와 합성 조건을 선택 전에 이해할 수 있다.
9. 5층 graph와 encounter/reward 수치, combat snapshot/hash는 시작 roster 외에 바뀌지 않는다.
10. presentation 누락·중복·타입 오류가 명시적 초기화 실패가 되고 core state를 변경하지 않는다.
11. 신규 테스트가 시작 roster, presentation strictness, contextual hint와 feedback의 core 비간섭을 검사한다.
12. 사용자가 별도 지시한 뒤 640×1,024 native 또는 Web에서 8~12분 완주와 핵심 재미 노출을 사람 검수한다.

## 승인 후 구현 순서

1. 명세 status와 P5-CS01~10을 승인 상태로 전환한다.
2. presentation 문서·loader와 시작 roster를 구현한다.
3. 런 UI 한글 표시·진행 정보·상황별 안내를 연결한다.
4. 전투 HUD 한글 이름·위험 구역 안내·파생 feedback을 연결한다.
5. 신규 narrow test와 기존 P4/P5 기대값을 코드로 보강한다.
6. 정적 검토 결과를 보고하고 실행 검증 승인 지점에서 멈춘다.
7. 사용자 지시가 있으면 영향 narrow와 최소 `play test`만 실행한다.
8. 사람 8~12분 완주 승인 뒤 문서·AGENTS·HANDOFF 상태를 갱신한다.

## 승인 요청

P5-CS01~10과 본문 전체를 승인하면 `codex/core-play-showcase`에서 구현을 시작한다.
