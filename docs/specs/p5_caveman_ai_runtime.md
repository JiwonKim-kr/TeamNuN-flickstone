# P5 · 원시인·AI 정식 콘텐츠와 런타임 아트

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 작성 | 2026-08-25 |
| 단계 | P5 제출 수직 슬라이스 · 정식 기물 2종 확장 |
| 구현 권한 | 있음. P5-CA01~18과 본문 전체 사용자 승인 · 2026-08-26 |
| 선행 조건 | P0~P4, P5-DZ, P5-BR, 선택 보드·바둑돌·병뚜껑 런타임 리스킨 완료 |

## 목표

사람 검수를 통과한 원시인·AI 이미지를 테스트 별칭 없이 정식 기물로 등록한다. 원시인은 물리 플레이 숙련을 보상하는 공격 기물, AI는 기본 궤적선을 대체하지 않고 수치 정보를 더하는 지원 기물로 구분한다. 두 기물 모두 기존 데이터 주도 catalog와 범용 visual/presentation mapping을 사용하며 컨트롤러에 콘텐츠 문자열 분기를 만들지 않는다.

## 범위

- 정식 PIECE `caveman`, `ai_core`와 L1~L3 임시 제출 수치
- 원시인의 clean-launch 충돌 피해 2배
- AI의 조준 각도·힘·첫 충돌 대상 추가 표시
- 제출 slice 한정 태그 배정과 기존 `destruction`·`steel` 시너지 참여
- 독립 전투 슬롯 순환, 세 reward pool, 64×64 런타임 아트
- snapshot·fingerprint·결정론·UI 회귀

## 비범위

- 5기 출전, 맵 슬롯·적 수·시작 로스터 변경
- 원시인·AI 적 버전과 encounter 변경
- `outlaw`, `support` 신규 시너지 효과
- 체스·원소 콘텐츠
- 최종 P6 밸런스
- Web 재배포, 장시간 통합 검증 부채 해소

## 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P5-CA01 | PIECE append-only ID 5=`caveman`, 6=`ai_core` | 테스트 별칭 없는 정식 콘텐츠 | ✅ 승인 · 2026-08-26 |
| P5-CA02 | ABILITY append-only ID 2=`caveman_unmindful`, 3=`ai_calculation` | 능력 식별·UI·향후 설명 데이터의 안정 ID | ✅ 승인 · 2026-08-26 |
| P5-CA03 | TAG append-only ID 4=`outlaw`, 5=`support`를 예약한다 | 기획 태그 보존. 이번 slice에서는 신규 synergy record 없음 | ✅ 승인 · 2026-08-26 |
| P5-CA04 | 원시인 태그는 `destruction`+`outlaw`, AI는 `steel`+`support` | 7.1.3 초안을 제출 slice에서만 승인해 기존 두 시너지를 즉시 체험 | ✅ 승인 · 2026-08-26 |
| P5-CA05 | 원시인 L1은 HP 105, 공격 18, 속도 95, 무게 72, 반지름 32, 마찰·탄성 1.0, 치명 0bp | 기본 공격은 낮추고 clean hit의 2배 보상을 핵심으로 둠 | ✅ 승인 · 2026-08-26 |
| P5-CA06 | 원시인 L2/L3 HP·공격은 131/23, 158/27이며 나머지는 L1과 같다 | 기존 1.25/1.5 성장 기준의 잠정 반올림 | ✅ 승인 · 2026-08-26 |
| P5-CA07 | AI L1은 HP 85, 공격 18, 속도 115, 무게 56, 반지름 32, 마찰·탄성 1.0, 치명 0bp | 빠르고 가벼운 정보 지원 기물로 구분 | ✅ 승인 · 2026-08-26 |
| P5-CA08 | AI L2/L3 HP·공격은 106/23, 128/27이며 나머지는 L1과 같다 | 기존 성장 기준 사용 | ✅ 승인 · 2026-08-26 |
| P5-CA09 | 원시인이 발사된 뒤 벽 또는 같은 진영 기물과 한 번도 접촉하지 않은 동안 적에게 주는 충돌 피해는 최종 크리티컬 전 단계에서 정확히 2배다 | 원문 ‘무심’을 재현하고 아군 충돌 리스크 유지 | ✅ 승인 · 2026-08-26 |
| P5-CA10 | 적과의 접촉은 clean 상태를 해제하지 않는다. 한 발사에서 여러 적을 맞혀도 벽·아군 접촉 전이면 각각 2배다 | 원문에 없는 ‘첫 적 1회’ 제한을 발명하지 않음 | ✅ 승인 · 2026-08-26 |
| P5-CA11 | 벽 접촉과 아군 접촉은 피해 발생 여부와 관계없이 즉시 clean을 해제하며 해당 충돌부터 이후 발사 종료까지 복구되지 않는다 | 저속·무피해 접촉도 조건 실패로 명확화 | ✅ 승인 · 2026-08-26 |
| P5-CA12 | clean 상태는 현재 발사 actor에만 존재하고 launch commit에서 시작, TURN_END/interrupt에서 종료한다. snapshot·copy·prediction은 이를 보존한다 | 복원·예측 결정론과 동일 판정 | ✅ 승인 · 2026-08-26 |
| P5-CA13 | clean-hit 배율은 모든 piece level에 기본 1.0인 typed 필드로 추가하고 원시인만 2.0으로 둔다 | 콘텐츠 ID 분기 없이 재사용 가능한 데이터 계약 | ✅ 승인 · 2026-08-26 |
| P5-CA14 | 모든 기물은 현재 기본 궤적선을 유지한다. AI는 AIM 중 양자화된 각도(도), 힘(%), 첫 충돌 대상 이름을 HUD에 추가 표시한다 | 접근성을 제거하지 않으면서 `계산`의 차별점을 직관화 | ✅ 승인 · 2026-08-26 |
| P5-CA15 | AI 추가 정보는 `ability_presentations.json`의 mode ID로 선택하며 코드에서 `ai_core`/ability 문자열을 비교하지 않는다 | 데이터 주도 UI 경계 유지 | ✅ 승인 · 2026-08-26 |
| P5-CA16 | 시작 로스터·적·map은 유지하고 세 reward pool에 두 기물을 추가한다. 독립 전투 1/2/3 슬롯 순환으로 즉시 선택할 수 있다 | P4 계약·전투 난도 이관을 최소화 | ✅ 승인 · 2026-08-26 |
| P5-CA17 | 승인 64px 샘플을 `assets/art/sprites/p5/caveman.png`, `ai_core.png`로 승격하고 기존 진영 링·행동자 화살표를 재사용한다 | 이미 끝난 사람 아트 검수 반영 | ✅ 승인 · 2026-08-26 |
| P5-CA18 | 이번 단계 검증은 영향 narrow, import/smoke/manifest, 실제 전투 렌더까지 수행하고 알려진 P2/P4 장시간 타임아웃은 별도 부채로 유지한다 | 구현 진행과 장시간 검증을 분리하라는 최신 지시 반영 | ✅ 승인 · 2026-08-26 |
| P5-CA19 | 궤적 계산 debounce를 50ms에서 16ms로 줄이고 새 계산 중에는 마지막 완성 궤적을 유지한다. AI 계산 모드는 6px 청록색 anti-aliased 선으로 강조한다 | 특정 방향에서만 늦게 나타나거나 계산 중 선이 사라져 끊겨 보이는 플레이 검수 문제 해소 | ✅ 승인 · 2026-08-26 |
| P5-CA20 | 연속 입력은 첫 pending 시각의 16ms 창을 유지하며 최신 command로 합친다. 같은 조준 session에서 완성된 결과는 더 최신 입력이 pending이어도 현재 표시 결과보다 새 generation이면 표시하고, 정확한 cache hit보다 오래된 결과는 덮어쓰지 못한다 | 커서를 계속 움직이면 trailing debounce와 generation 폐기로 경로가 갱신되지 않던 2차 플레이 검수 문제 해소 | ✅ 승인 · 2026-08-26 |

## 원시인 clean-launch 계약

`BattleState`는 현재 발사 actor와 함께 append-only 접촉 mask를 보존한다.

```text
launch commit      -> contact_mask = 0
actor wall contact -> contact_mask |= WALL
actor ally contact -> contact_mask |= ALLY
enemy collision    -> mask 불변
turn end/interrupt -> mask 폐기
```

충돌 피해 계산 시 다음 조건을 모두 만족하면 공격자의 typed `clean_hit_damage_multiplier_raw`을 적용한다.

1. 공격자가 현재 발사 actor다.
2. 접촉 mask가 0이다.
3. 공격자 level의 배율이 1.0보다 크다.
4. 피해자가 다른 비중립 진영이다.

배율은 P1 피해 공식의 기본·modifier·아군 보정 뒤, 크리티컬 직전에 한 번 적용한다. checked Q47.16 계산과 기존 round 규칙을 사용한다. actor가 아닌 연쇄 충돌 기물에는 적용하지 않는다.

## AI 계산 표시 계약

- 기본 궤적선은 전 기물 공통으로 유지한다.
- AI actor의 ability presentation mode가 활성일 때만 HUD에 `각도 N° · 힘 N% · 첫 충돌 <기물명|없음>`을 표시한다.
- 각도는 `LaunchCommand.angle_units`를 0~359 정수 도로 표시하고, 힘은 `power_step / 256`을 0~100 정수 퍼센트로 표시한다.
- 첫 충돌은 기존 `TrajectoryPoint.Marker.COLLISION`의 첫 `target_body_id`를 읽는다. 추가 시뮬레이션이나 RNG를 실행하지 않는다.
- 표시 데이터는 파생 UI이며 snapshot·state hash·전투 판정에 들어가지 않는다.
- P5-CA19 이후 AI 계산 선은 같은 권위 prediction 값을 사용하되 6px 청록색으로 표시한다. 입력 직후의 현재 방향은 공용 aim guide가 즉시 표시하며 새 prediction 완료 전에는 직전 완성 경로를 유지한다.
- P5-CA20 이후 연속 커서 이동은 계산 시작을 계속 뒤로 미루지 않는다. UI는 같은 조준 session의 가장 최근 완성 경로를 순차적으로 갱신하고, 현재 command의 정확한 cache hit는 더 오래된 worker 결과로부터 보호한다.

## 데이터·마이그레이션

- pieces v4 → v5: `clean_hit_damage_multiplier_raw`
- abilities v6 → v7: 두 정식 ability record
- catalog/canonical fingerprint v11 → v12
- BattleCombatant에 clean-hit 배율을 materialize하고 BattleSnapshot은 다음 버전으로 이관
- 현재 launch contact mask를 snapshot/copy/restore/state validation에 포함
- reward profile과 P2/P4 fixture fingerprint·RunSnapshot KAT 이관
- visual catalog에 PIECE 5/6, 별도 ability presentation catalog에 ABILITY 3 추가
- 기존 snapshot은 clean-hit 배율 1.0, contact mask 0으로 복원한다.

## 대상 파일

주요 수정:

```text
src/core/data/{pieces,abilities,id_registry,reward_profiles,catalog}.json
src/core/data/*definition.gd
src/core/battle/{battle_state,battle_combatant,battle_snapshot,damage_calculator}.gd
src/ui/battle/{p2_content_graybox,piece_visuals,ability_presentations}.*
pipeline/schemas/*
pipeline/tests/*
pipeline/manifest.json (manifest.py만 사용)
```

런타임 아트:

```text
assets/art/sprites/p5/caveman.png
assets/art/sprites/p5/ai_core.png
```

## 오류·결정론 계약

- clean-hit 배율은 1.0~4.0만 허용하고 범위 밖은 catalog 전체 실패다.
- 접촉 mask의 알 수 없는 bit, actor 0인데 nonzero mask, AIM/BATTLE_END의 잔존 mask는 snapshot/validation 실패다.
- wall/ally event는 기존 안정 event sequence 순서로 mask를 갱신한다.
- prediction은 deep copy에서 같은 mask·피해를 계산하고 원본 bytes를 바꾸지 않는다.
- visual/presentation JSON은 exact key, stable numeric/string ID, `res://assets/art/` PNG 경로를 검증한다.

## 수용 기준

1. 기존 기물은 배율 1.0으로 기존 피해 결과를 유지한다.
2. 원시인 direct enemy hit은 동일 조건 일반 기물의 정확히 2배 피해다.
3. 벽 또는 아군 접촉 뒤 적중은 1배이며, 저속 무피해 접촉도 clean을 해제한다.
4. 적 연쇄 적중만 이어지면 각 적에게 2배가 적용된다.
5. actor가 밀어낸 다른 기물의 연쇄 피해에는 원시인 배율이 전달되지 않는다.
6. snapshot round-trip, legacy restore, prediction copy가 contact mask와 배율 계약을 지킨다.
7. 원시인·AI가 세 reward pool의 결정론적 후보이며 시작 로스터는 불변이다.
8. 독립 전투 슬롯 순환으로 두 기물을 선택할 수 있다.
9. AI actor에서만 각도·힘·첫 충돌 정보가 표시되고 기본 궤적선은 모든 기물에 남는다.
10. 컨트롤러에 `caveman`, `ai_core`, ability 문자열 분기가 없다.
11. 두 64×64 RGBA sprite, 진영 링, 행동자 화살표와 manifest가 검증된다.
12. catalog Python/Godot KAT, 영향 P1/P2/P4 narrow, Godot import/smoke와 실제 전투 렌더가 통과한다.

## 구현 순서

1. 승인 결정 반영과 append-only ID/schema/fingerprint 이관
2. typed clean-hit stat·contact mask·피해 경계·snapshot 구현
3. 원시인·AI 데이터와 reward/standalone 연결
4. 두 sprite 승격과 visual/presentation catalog 연결
5. narrow·import/smoke·실제 전투 렌더
6. AGENTS·HANDOFF·설계 문서 최신화

## 승인 기록

2026-08-26 사용자가 P5-CA01~18과 본문 전체를 승인했다. P5-CA04는 기획서의 승인 대기 태그 배정을 제출 slice에서 부분 확정하고, P5-CA05~08은 P6 전 임시 수치이며, P5-CA14는 기본 궤적선과 AI 능력의 차이를 확정한다.

## 구현·검증 기록

2026-08-26 P5-CA01~18 구현을 완료했다. 후속 회귀 보강에서 P1 피해 narrow를 31개 그룹으로 확장해 direct/연속 적 적중 2배, 비행동자 1배, 저속 아군 접촉·벽 접촉 뒤 1배, contact mask와 typed 배율의 BattleSnapshot/copy 보존을 Godot 4.6.3으로 확인했다. 기본 import·smoke·manifest 게이트와 orchestration/art/se/placeholder 파이프라인 회귀도 통과한다. P2-6/P4 장시간 종단 러너와 원시인·AI 실제 플레이 감각 판정은 P5-CA18에 따라 별도 후속 항목으로 유지한다.
