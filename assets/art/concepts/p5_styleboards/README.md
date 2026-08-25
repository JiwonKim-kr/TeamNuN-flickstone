# P5 style-board generation memo

| 항목 | 값 |
|---|---|
| 생성 승인 | 2026-08-25 · Scenario 최신 API 이관 및 A/B/C 스타일 보드 생성 |
| 모델 | Scenario FLUX.2 Dev · `model_bfl-flux-2-dev` |
| 규격 | 640×1,024 PNG · 후보별 1장 |
| 시드 | `250825` · 세 후보 공통 |
| 용도 | `art concept` 사람 비교용. 런타임 사용 금지 |

- `prompt_a_tactile_otherworld.txt`: 손에 잡히는 이세계 보드 토큰
- `prompt_b_neon_arcade.txt`: 네온 아케이드 칩
- `prompt_c_classic_toybox.txt`: 고전 장난감 상자
- 출력 이름은 각각 `p5_styleboard_a_00.png`, `p5_styleboard_b_00.png`, `p5_styleboard_c_00.png`이다.
- 생성물은 manifest와 게임 씬에 등록하지 않는다. 사람 선택 뒤에도 별도 `art lock` 승인 전에는 양산하지 않는다.

## 2026-08-25 자동 검사와 시각 사전 점검

| 후보 | probe | 방향 판독 | 발견한 생성 오차 |
|---|---|---|---|
| A · tactile | 640×1,024 · PNG RGB | 도자기·금속·석재·회로·고무·불 재질과 어두운 전장이 가장 일관됨 | 체스 말이 하나 더 생겨 총 8개 토큰, HUD와 `KILL` 텍스트 생성 |
| B · neon | 640×1,024 · PNG RGB | 네온 대비와 썸네일 임팩트가 가장 강함 | 세로 레인으로 구도가 바뀌고 토큰 수가 늘어남, 의미 없는 HUD/중앙 텍스트 생성 |
| C · toybox | 640×1,024 · PNG RGB | 따뜻한 목재 보드와 수집형 장난감 감성이 가장 명확함 | 원시인 토큰 중복으로 총 9개 토큰, HUD·`KILL`·`AI` 텍스트 생성 |

세 이미지는 **스타일 방향 비교용으로는 사용 가능**하지만, 정확한 7종 구성과 무문자 조건을 충족하지 않아 런타임 에셋이나 최종 `art lock` 입력으로 자동 확정하지 않는다. 사람 방향 선택 후 선택안의 대표 클로즈업을 별도 생성한다.
