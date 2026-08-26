# P5 · 탱탱볼 정식 콘텐츠와 런타임 아트

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 작성 | 2026-08-25 |
| 단계 | P5 제출 수직 슬라이스 · 첫 정식 기물 아트 적용 |
| 구현 권한 | P5-BR01~14 전체 사용자 승인 · 2026-08-25 |
| 선행 조건 | P0~P4 구현, P5-ART01~11, `bouncy_ball_refined_00_64.png` 사람 방향 승인 |

## 목표

마법 구슬로 오인되던 기존 후보 대신 고무 장난감으로 읽히는 새 탱탱볼 이미지를 정식 런타임 에셋으로 승격한다. 플레이스홀더에 임시 별칭을 붙이지 않고 append-only 콘텐츠 ID `bouncy_ball`을 추가하며, 기물별 코드 분기 없이 데이터가 런타임 이미지를 선택하게 한다. 탱탱볼의 핵심 차별점인 탄성 배율도 결정론 물리에 함께 연결한다. 최초 2배 값은 P5-BR15 플레이 검수에서 4배로 재승인됐다.

## 범위

- 정식 player piece `bouncy_ball` L1~L3 등록
- 기물별 탄성 배율과 벽/기물 충돌 적용
- SimSnapshot 하위 호환 복원과 state hash 반영
- 정식 64×64 RGBA 탱탱볼 sprite 승격 및 manifest 등록
- UI 전용 strict piece visual 데이터와 범용 로더
- 진영 링과 현재 행동자 표식 분리
- 독립 전투 기물 순환 및 개발 런 영입 보상 풀 노출
- 관련 schema, canonical fingerprint, golden, 회귀 테스트 갱신

## 비범위

- 기존 `graybox_striker` 삭제·이름 변경·탱탱볼 별칭화
- 개발 시작 로스터, 적 조합, encounter, 맵 구조 변경
- `trickery` 시너지 효과와 tier 수치 구현
- 나머지 6종 대표 아트의 런타임 연결
- 최종 P6 밸런스 확정
- Web 재배포와 제출 페이지 갱신

## 사람 승인 결정안

| ID | 권장안 | 이유 | 상태 |
|---|---|---|---|
| P5-BR01 | PIECE append-only ID 4를 `bouncy_ball`로 등록한다 | graybox 별칭 없이 정식 콘텐츠로 유지 | ✅ 승인 · 2026-08-25 |
| P5-BR02 | L1은 HP 100, 공격 20, 속도 100, 무게 64, 반지름 32, 마찰 1.0, 치명 0bp를 사용한다 | 제출 검증에서는 바둑돌과 같은 기준선으로 두고 탄성만 비교 | ✅ 승인 · 2026-08-25 |
| P5-BR03 | L2/L3은 HP·공격만 125/25, 150/30으로 증가하고 나머지는 L1과 같다 | 기존 바둑돌 성장 기준을 재사용해 merge 경로를 완결 | ✅ 승인 · 2026-08-25 |
| P5-BR04 | 모든 기물 level에 `elasticity_multiplier_raw`를 추가하며 기본 1.0, 탱탱볼은 전 레벨 2.0이다 | 탄성을 기물 고유의 결정론 물리 스탯으로 표현 | ✅ 승인 · 2026-08-25 |
| P5-BR05 | 기본 반발 19/20에서 탄성 2배는 손실량을 절반으로 하여 유효 반발 39/40을 만든다 | 기획의 “반사 시 속도 감소량 절반”을 기존 수식으로 정확히 표현 | ✅ 승인 · 2026-08-25 |
| P5-BR06 | 벽 충돌은 해당 기물 배율, 기물끼리 충돌은 두 배율 중 큰 값을 사용하며 중첩하지 않는다 | 한쪽이 탱탱볼이면 특성이 보이되 탱탱볼끼리 4배가 되는 폭주 방지 | ✅ 승인 · 2026-08-25 |
| P5-BR07 | SimBody와 SimSnapshot에 탄성을 저장하고 구버전 snapshot 복원 시 1.0을 주입한다 | 저장·예측·복제·재현의 결정론 유지 | ✅ 승인 · 2026-08-25 |
| P5-BR08 | TAG append-only ID 3 `trickery`를 탱탱볼에 부여하되 synergy record는 만들지 않는다 | 기획 역할은 보존하고 미정 시너지 효과는 발명하지 않음 | ✅ 승인 · 2026-08-25 |
| P5-BR09 | 시작 로스터는 유지하고 세 개발 reward pool에 탱탱볼을 추가한다 | 기존 P4 시작 흐름·세이브 계약을 보존하면서 실제 런에서 획득 가능 | ✅ 승인 · 2026-08-25 |
| P5-BR10 | 독립 전투는 현재 1/2/3 슬롯 순환 방식을 유지한다. 3번을 한 번 순환하면 `bouncy_ball`이 된다 | 전용 콘텐츠 분기나 새 디버그 UI 없이 즉시 플레이 검수 | ✅ 승인 · 2026-08-25 |
| P5-BR11 | 승인 샘플을 `assets/art/sprites/p5/bouncy_ball.png` 64×64 RGBA로 승격하고 1배 nearest로 표시한다 | P5-ART05와 새 탱탱볼 검수 결과 반영 | ✅ 승인 · 2026-08-25 |
| P5-BR12 | `src/ui/battle/piece_visuals.json`이 numeric/string ID 쌍, texture 경로, pixel size, scale을 strict하게 매핑하고 UI는 이를 범용 로드한다 | P2-G10의 콘텐츠 ID별 컨트롤러 분기 금지 | ✅ 승인 · 2026-08-25 |
| P5-BR13 | visual record가 없는 기존 기물은 현재 진영 placeholder로 fallback하며, 등록됐지만 파일/규격이 틀리면 조용히 fallback하지 않고 로드 오류로 정지한다 | 점진적 reskin과 엄격한 데이터 오류 검출을 함께 만족 | ✅ 승인 · 2026-08-25 |
| P5-BR14 | 본체에는 진영색을 굽지 않고 청록 원+돌기/주황 원+쐐기 링을 코드 오버레이로 표시하며 현재 행동자는 별도 노란 화살표로 표시한다 | P5-ART06을 충족하고 현재 노란 sprite tint로 재질이 사라지는 문제 방지 | ✅ 승인 · 2026-08-25 |
| P5-BR15 | 제출 플레이 검수에서 탄성 배율을 전 레벨 2.0에서 허용 상한 4.0으로 올린다. 유효 반발은 39/40에서 79/80이 된다 | 2배는 기본 19/20 대비 손실 차이가 2.5%p뿐이라 고유 특성이 체감되지 않음 | ✅ 승인 · 2026-08-26 |

## 데이터 계약

### pieces v4

모든 level record에 다음 값을 필수 추가한다.

```json
{
  "elasticity_multiplier_raw": 65536
}
```

- 허용 범위: `1.0 <= value <= 4.0`
- 기존 정식·graybox 기물: `65536` (1.0)
- `bouncy_ball`: `262144` (4.0, P5-BR15 재승인)
- canonical field order는 `friction_multiplier_raw` 다음, `critical_basis_points` 앞이다.

탱탱볼은 `numeric_id=4`, `id=bouncy_ball`, 일반 로스터 기물 flags, 비spawnable, `trickery` tag, 빈 `ability_refs`를 사용한다. 탄성은 이번 범위에서 별도 trigger/effect record가 아니라 물리 스탯이다.

### piece visuals v1

UI 문서는 core catalog fingerprint에 포함하지 않는다. 각 record는 다음 exact key만 허용한다.

```json
{
  "numeric_id": 4,
  "id": "bouncy_ball",
  "texture": "res://assets/art/sprites/p5/bouncy_ball.png",
  "pixel_width": 64,
  "pixel_height": 64,
  "scale_raw": 65536
}
```

- numeric/string ID 쌍은 현재 catalog와 정확히 일치해야 한다.
- texture는 `res://assets/art/` 아래 PNG만 허용한다.
- 중복 ID, 알 수 없는 ID, 누락 파일, 크기·PNG·alpha 불일치는 초기화 실패다.
- visual record가 없는 piece만 기존 faction placeholder와 4/3 scale을 사용한다.
- renderer는 `piece.string_id()` 비교나 match branch를 두지 않는다.

## 물리 규칙

기본 반발계수 `e`와 선택된 탄성 배율 `m`에 대해 기존 고정소수점 helper를 사용한다.

```text
effective_e = 1 - (1 - e) / m
```

- wall: `m = body.elasticity_multiplier`
- circle pair: `m = max(body_a.elasticity_multiplier, body_b.elasticity_multiplier)`
- 위치 보정, 질량 impulse, 접촉 pass, 이벤트 순서는 기존 P0 계약을 유지한다.
- 4배 탄성도 저속 `vmax <= 20` 즉시 settle 규칙의 예외가 아니다.
- prediction clone, runtime spawn, transform, snapshot restore는 탄성 값을 잃지 않는다.

## 런타임 노출

- 독립 `p2_content_graybox`의 piece catalog 순서는 append-only ID 순서다.
- 기본 배치 `[baduk_stone, bottle_cap, graybox_striker]`는 유지한다.
- 숫자 3을 한 번 누르면 세 번째 슬롯이 `bouncy_ball`로 순환한다.
- 개발 시작 로스터 6기는 변경하지 않는다.
- normal/elite/boss 영입 후보 pool은 `[baduk_stone, bottle_cap, bouncy_ball]`이 된다.
- 기존 seed의 reward 결과가 바뀌는 것은 승인된 content fingerprint 변경으로 취급하고 새 golden을 기록한다.

## 아트·manifest 계약

- source: `assets/art/concepts/p5_no_training_samples/bouncy_ball_refined_00_64.png`
- runtime: `assets/art/sprites/p5/bouncy_ball.png`
- runtime 파일은 source와 byte-identical 복사본이어도 되며 concept 원본은 보존한다.
- manifest ID: `art:sprites/p5_bouncy_ball`
- status: `approved`
- requested_by: `src/ui/battle/piece_visuals.json::bouncy_ball`
- manifest 변경은 `pipeline/scripts/manifest.py`만 사용한다.

## 마이그레이션 영향

- pieces schema v3 → v4
- catalog schema와 canonical fingerprint 다음 버전
- SimSnapshot 다음 버전; 이전 버전은 탄성 1.0으로 복원
- state hash에 body 탄성 포함
- 기존 BattleSnapshot version은 내부 SimSnapshot framing이 버전을 자체 보유하면 유지하고, 그렇지 않으면 다음 버전으로 올린다
- reward golden과 P2 content count/fingerprint 기대값 갱신
- 기존 세이브는 catalog fingerprint 불일치 정책을 그대로 따른다. 제출 개발 세이브의 자동 콘텐츠 이관은 범위 밖이다.

## 검증 기준

1. strict JSON/schema/KAT와 독립 canonical fingerprint 계산이 통과한다.
2. 기존 기물의 1.0 탄성 결과가 변경 전 golden과 동일하다.
3. 기본 19/20에서 탱탱볼 벽 충돌과 일반-탱탱볼 충돌이 79/80을 사용한다.
4. 탱탱볼-탱탱볼도 79/80이며 배율이 중첩되지 않는다.
5. snapshot round-trip, 구버전 restore 기본값, state hash 민감도가 통과한다.
6. prediction/runtime/transform/spawn 경로가 탄성을 보존한다.
7. 1,000-repeat 동일 seed 결과와 기존 P0~P4 대표 회귀가 통과한다.
8. 세 reward profile에서 탱탱볼이 유효 후보이고 정렬·선택이 결정론적이다.
9. 컨트롤러 소스에 `bouncy_ball` 등 콘텐츠 string ID 분기가 없다.
10. 64×64 RGBA/alpha/manifest 검증과 Godot import·headless smoke가 통과한다.
11. 실제 독립 전투에서 3번 순환 후 새 sprite, 진영 링, 행동자 화살표, 더 높은 반사가 눈으로 구분된다.
12. 영향 narrow tests 뒤 Godot 포함 `verify --demo`를 실행한다.

## 구현 순서

1. pieces v4·ID registry·typed definition·catalog/fingerprint 마이그레이션
2. SimBody·충돌·snapshot/hash·materialization 탄성 연결
3. 탱탱볼 L1~L3와 reward pool 등록
4. sprite 승격, manifest 등록, strict visual loader와 오버레이 적용
5. narrow 결정론/콘텐츠/런/UI/아트 검증
6. `verify --demo`와 실제 플레이 검수

## 승인 이후 문서 갱신

- 승인 시 이 문서의 status와 P5-BR01~14를 `approved`로 변경한다.
- 구현·검증 뒤 `AGENTS.md`, `docs/design/game_design.md` 현재 단계, 아트 생성 기록과 작업 진행 체크 문서를 최신화한다.

## 구현·검증 기록

2026-08-25 구현을 완료했다. 2026-08-26 사람 플레이 검수에서 탄성 체감이 부족하다는 피드백에 따라 P5-BR15로 4.0 상한을 재승인했다.

- PIECE ID 4 `bouncy_ball`, TAG ID 3 `trickery`, L1~L3와 세 reward pool을 등록했다.
- pieces v4, catalog/fingerprint v11, SimSnapshot v3으로 이관했다. 현재 runtime fingerprint는 `8067a487ceb0ef2d721a3a985d8c5b7c0d8185cd4f52ce30c9d8cb59fd68edca`다.
- 일반 body는 기존 반발 경로를 그대로 사용하고, P5-BR15 이후 4배 탄성 body에는 79/80 유효 반발을 계산한다. circle pair는 최대 배율만 적용한다.
- `bouncy_ball.png` 64×64 RGBA를 manifest에 approved로 등록하고 strict `piece_visuals.json`, 진영 링, 현재 행동자 화살표를 연결했다.
- Godot 4.6.3 import/smoke/manifest, P0 충돌 23그룹(legacy v2 탄성 기본값 포함), P2 콘텐츠 21그룹, P4 snapshot 17그룹, P4 map 8그룹, P4 formation, P5-DZ 및 독립 Python KAT가 통과했다.
- P0 1,000회·30순열 exhaustive 실행으로 SimSnapshot v3 golden을 승인 문서 경로와 함께 갱신했고, 후속 demo quick P0 13그룹도 통과했다.
- 통합 `verify --demo`의 5개 기본 게이트는 통과했다. 기존 P2 terminal 병렬 배치는 Windows에서 300초, P4 4-run UI 배치는 600초 제한에 걸렸으며 기능 narrow 실패는 없었다. 두 장기 러너 완료와 실제 화면 사람 검수는 후속 확인 사항이다.
