# P5 무학습 참조 기반 테스트 샘플

- 단계: Flickstone 제출용 프로젝트 예외 (`art lock`·커스텀 학습 미사용)
- 목적: 승인 참조 이미지와 범용 이미지 모델만으로 런타임 규격의 스타일 일관성을 확보할 수 있는지 검수
- 런타임 연결: 금지. 사람 샘플 승인 뒤 별도 P5 구현에서 진행
- 매니페스트: 변경하지 않음, `style_guide`는 `null` 유지

## 승인 참조

- 보드: `../p5_map_board_a/p5_map_board_a_refined_02.png`
- 주 피사체: `../p5_token_refs_a/baduk_stone_refined_00.png`
- 보조 토큰 스타일: `../p5_token_refs_a/bottle_cap_00.png`, `../p5_token_refs_a/ai_core_00.png`

## 2026-08-25 바둑돌 테스트

내장 이미지 생성 도구에 위 네 파일을 참조로 제공해, 커스텀 학습 없이 투명 배경의 바둑돌 후보를 만들었다. 생성 도구가 모델 식별자와 시드를 노출하지 않아 재현 메타데이터에는 `built-in imagegen`, 참조 경로와 전체 프롬프트만 기록한다.

| 파일 | 규격 | 용도·판정 |
|---|---:|---|
| `baduk_stone_test_00.png` | 1,254×1,254 RGBA | 생성 원본. 투명 배경·무문자·무문양·무진영색·무균열 통과 |
| `baduk_stone_test_00_64.png` | 64×64 RGBA | 전체 캔버스 단순 축소. 투명 여백 때문에 본체가 작아 제외 후보 |
| `baduk_stone_test_01_64.png` | 64×64 RGBA | 전체 알파 경계 기준 정규화. 그림자 범위가 커서 본체가 여전히 작아 제외 후보 |
| `baduk_stone_test_02_64.png` | 64×64 RGBA | 950×950 중심 크롭 → 60×60 nearest → 2px 투명 패딩. **검수 권장안** |
| `baduk_stone_test_00_board_preview.png` | 640×1,024 RGBA | 단순 축소안의 보드 1배 합성 비교 |
| `baduk_stone_test_01_board_preview.png` | 640×1,024 RGBA | 알파 경계 정규화안의 보드 1배 합성 비교 |
| `baduk_stone_test_02_board_preview.png` | 640×1,024 RGBA | 검수 권장안의 보드 1배 합성 비교 |

기계 검사는 생성 원본과 세 64×64 후보 모두 RGBA·alpha를 확인했다. `test_02_64`는 검은 본체가 중립 보드 위에서 읽히고, 향후 청록/주황 진영 링이 차지할 외곽 여백도 남긴다.

사람 검수 항목:

1. 바둑돌이 병뚜껑이나 검은 구슬이 아니라 실제 바둑돌로 읽히는가
2. 64×64·1배에서 하이라이트와 원형 실루엣이 충분한가
3. 보드 위 검은 본체의 대비가 지나치게 낮지 않은가
4. 같은 방식으로 병뚜껑·원시인·AI·탱탱볼·체스 나이트·불 원소를 확장해도 되는가

전체 생성 프롬프트는 `prompt_baduk_stone_test_00.txt`에 보존한다.

## 2026-08-25 대표 기물 6종 확장

사용자가 선택 보드 형태를 승인하고 다른 기물 생성을 요청했다. 바둑돌 생성 원본과 선택 보드를 공통 스타일 참조로 두고, 각 기물의 기존 A 방향 컨셉을 주 피사체 참조로 사용해 여섯 번의 독립 호출로 생성했다.

| 기물 | 생성 원본 | 64×64 검수본 | 64px 판독 |
|---|---|---|---|
| 병뚜껑 | `bottle_cap_test_00.png` | `bottle_cap_test_00_64.png` | 톱니 외곽·금속·방사 문양 양호 |
| 원시인 | `caveman_test_00.png` | `caveman_test_00_64.png` | 석재 얼굴 부조 양호. 유인원 인상이 강한지는 사람 검수 필요 |
| AI | `ai_core_test_00.png` | `ai_core_test_00_64.png` | 단안·회로·소형 청록 코어 판독 양호 |
| 탱탱볼 | `bouncy_ball_test_00.png` | `bouncy_ball_test_00_64.png` | 자홍 소용돌이와 고무 광택 판독 양호. 마법 구슬 오인 여부 검수 필요 |
| 체스 나이트 | `chess_knight_test_00.png` | `chess_knight_test_00_64.png` | 아이보리 말 부조 판독 양호 |
| 불 원소 | `fire_elemental_test_00.png` | `fire_elemental_test_00_64.png` | 원 안에 봉인된 불꽃과 암석 림 판독 양호 |

- 모든 생성 원본과 64×64 검수본은 RGBA·alpha probe를 통과했다.
- 검수본은 기물별 중심 크롭 → 60×60 nearest → 2px 투명 패딩으로 정규화했다.
- `all_tokens_test_00_strip.png`는 일곱 기물의 64×64 가로 비교다.
- `all_tokens_test_00_board_preview.png`는 선택 보드에 1배 크기로 올린 합성 검수본이며 보드 원본에는 기물이 포함되지 않는다.
- 생성 프롬프트 집합은 `prompt_token_batch_2026-08-25.md`에 보존한다.
- 사람 승인 전에는 `assets/art/sprites/`, scene, manifest를 변경하지 않는다.

## 2026-08-25 사람 검수와 탱탱볼 정제

- 바둑돌·병뚜껑·원시인·AI·체스 나이트·불 원소 6종은 사용자 검수를 통과했다.
- 기존 `bouncy_ball_test_00`은 자홍 소용돌이와 금속 림 때문에 마법 구슬로 오인될 가능성이 있어 런타임 후보에서 제외하되 비교용으로 보존한다.
- 대체 후보 `bouncy_ball_refined_00.png`는 실제 장난감 고무공의 성형선·사출점·잔기스와 청록/노랑 인쇄 띠를 강조하고, 외부 림·오라·마법 문양을 제거했다.
- `bouncy_ball_refined_00_64.png`는 1,254px 원본을 중심 1,000px 크롭 → 60×60 nearest → 2px 투명 패딩으로 정규화했으며 RGBA·alpha probe를 통과했다.
- `all_tokens_refined_bouncy_ball_board_preview.png`는 기존 여섯 승인 후보와 새 탱탱볼을 선택 보드에 1배로 합성한 사람 검수본이다.

새 탱탱볼은 아직 사람 최종 승인 전이므로 runtime sprite나 manifest에 연결하지 않는다.
