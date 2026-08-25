# P5 피해 지역 생성 기록 — 2026-08-25

## 공통 참조

- 선택 보드: `../p5_map_board_a/p5_map_board_a_refined_02.png`
- 불 원소 토큰: `../p5_no_training_samples/fire_elemental_test_00.png`
- 기존 플레이스홀더: `../../zones/PLACEHOLDER_turn_start_damage.png`
- 생성 도구: Codex 내장 imagegen
- 커스텀 모델 학습: 사용하지 않음

## A — thermal fracture (제외)

보드와 분리된 정투영 위험 지역 overlay 타일을 생성하도록 지시했다. 어두운 숯빛 균열, 주황 열광, 불규칙하지만 가장자리가 반복되는 64px용 패턴, 문자·아이콘·기물·보드 프레임 금지, 완전 투명 배경을 요구했다.

첫 출력과 투명 배경 조건을 강화한 정제 출력 모두 체크무늬를 이미지에 구운 RGB로 반환했다. alpha probe 실패로 제외했다.

## B — warning lattice (권장)

다음 조건으로 별도 후보를 생성했다.

- 정투영 2D 게임용 overlay texture
- 얇고 끊어진 주황·적색의 대각 경고선과 작은 ember node
- 반복 가능한 사각 타일, 중앙 피사체 없음
- 바닥을 충분히 드러내는 희소한 패턴
- 문자, 숫자, 방사능·해골 아이콘, 기물, 보드, HUD 금지
- 실제 RGBA 투명 배경, 가짜 체크무늬 금지

출력은 1,254×1,254 RGBA 및 실제 alpha를 통과했다. 64×64 nearest 축소본을 만들고, 첫 런타임 존 크기 192×96에 반복한 뒤 alpha 0.38과 2px 주황 경계를 적용해 보드 검수본을 만들었다.

## 후처리 원칙

- 생성 원본은 비교·감사 용도로 보존한다.
- 런타임 후보는 64×64 RGBA를 유지한다.
- 최종 scene 적용 시 이미지 사각형이 아니라 데이터의 zone polygon으로 clip한다.
- 겹친 존의 시각 표현은 명세의 중첩 피해 규칙을 훼손하지 않도록 별도 검수한다.
