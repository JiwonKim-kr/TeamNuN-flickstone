# P5 턴 시작 피해 지역 컨셉 샘플

- 단계: `art concept`
- 목적: 선택 보드 위에 동적으로 배치할 수 있는 위험 지역 overlay 검수
- 기준 명세: `docs/specs/p5_turn_start_damage_zones.md`
- 런타임 연결: **경고 격자 후보 선택·연결 완료** · 2026-08-25 사용자 승인
- 매니페스트: `art:zones/turn_start_damage` → `assets/art/zones/turn_start_damage.png`

## 선택 후보: 경고 격자

`damage_zone_warning_lattice_00.png`는 선택 보드와 불 원소 기물을 참조해 만든 전류·열 경고 격자다. 생성 원본은 1,254×1,254 RGBA이며 실제 alpha를 포함한다.

| 파일 | 규격 | 용도·판정 |
|---|---:|---|
| `damage_zone_warning_lattice_00.png` | 1,254×1,254 RGBA | 생성 원본, 실제 투명 배경 통과 |
| `damage_zone_warning_lattice_00_64.png` | 64×64 RGBA | 명세 규격의 반복 타일 후보 |
| `damage_zone_warning_lattice_00_board_preview.png` | 640×1,024 RGBA | 첫 존 사각형 `(224,464)~(416,560)`에 38% 불투명도로 합성한 검수본 |

보드 합성은 64×64 타일을 3×2회 반복하고, 실제 존 경계에 2px 주황 외곽선을 더했다. 보드 이미지 자체에는 위험 지역을 굽지 않는다. 런타임에서는 같은 충돌 polygon을 마스크로 사용해야 한다.

2026-08-25 사용자 검수에서 이 후보를 실제 위험 존 표시로 선택했다. 런타임은 38% alpha와 2px 주황 경계를 사용한다. 아래 열 균열 후보와 생성 원본은 향후 다른 존이나 비교 작업에 쓸 수 있도록 그대로 보존한다.

## 제외 후보: 열 균열

- `damage_zone_thermal_fracture_00.png`
- `damage_zone_thermal_fracture_refined_00.png`
- `damage_zone_thermal_fracture_00_64.png`

두 차례 모두 이미지 생성기가 투명 배경 대신 체크무늬를 RGB 픽셀로 구워 출력했다. 원본 probe가 `rgb24`, alpha 없음으로 확인되어 런타임 후보에서 제외한다. 기록과 비교 검수를 위해 원본을 보존한다.

## 후속 사람 플레이 검수 항목

1. 1배 크기에서 위험 지역임을 즉시 알아볼 수 있는가
2. 격자가 철망이나 이동 불가 장애물로 오인되지 않는가
3. 기물이 올라갔을 때 실루엣과 진영 표시를 가리지 않는가
4. 불·전기·독 등 특정 속성에 지나치게 고정되지 않는가
5. 여러 존이 겹칠 때 중첩 피해를 시각적으로 구분할 여지가 있는가

생성 지시와 후처리 기록은 `prompt_damage_zone_batch_2026-08-25.md`에 보존한다.
