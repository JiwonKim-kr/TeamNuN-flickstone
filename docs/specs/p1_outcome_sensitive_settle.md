# P1 · 저속 RESOLVE 즉시 정산

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 승인 | 2026-08-24 · 사용자 재승인: `vmax`가 20 이하이면 즉시 다음 턴 |
| 선행 계약 | P0 결정론 물리, P1 C-07 RESOLVE 안전 경계 |

## 목적

체감 영향이 거의 없는 저속 미끄러짐 때문에 턴이 길어지는 문제를 제거한다. 모든 이동 기물의 최대 속도가 20 이하가 되는 순간 현재 위치를 최종 위치로 확정하고 다음 턴으로 넘어간다.

## 승인 결정

| ID | 결정 | 상태 |
|---|---|---|
| OS-01 | RESOLVE 중 살아 있는 이동 본체가 하나 이상이고 모든 속도가 `20` 이하이면 즉시 정산한다 | ✅ 재승인 |
| OS-02 | 임계값은 `vmax <= 20`으로 경계를 포함한다 | ✅ 재승인 |
| OS-03 | 임계 도달 시 각 본체의 현재 위치를 보존하고 남은 속도를 0으로 만든다 | ✅ 재승인 |
| OS-04 | 잔여 경로의 충돌·벽·KILL·가속 존 가능성을 검사하지 않는다. 턴 템포를 우선한다 | ✅ 재승인 |
| OS-05 | 정산은 UI 배속이 아니라 `BattleState`의 권위 결과이므로 replay·snapshot·batch에도 동일하게 적용한다 | ✅ 재승인 |
| OS-06 | 임계 초과 구간의 물리 tick·충돌·피해·이벤트·RNG 규칙은 변경하지 않는다 | ✅ 승인 |
| OS-07 | 임계에 도달하지 않는 비정상 상태를 위한 기존 960틱 정상 + 240틱 강제 정산과 deadlock 경계는 유지한다 | ✅ 승인 |
| OS-08 | 이전의 `FAST ×20`, 180틱 최소 대기, 잔여 경로 위험 검사는 폐기한다 | ✅ 재승인 |

## 정산 순서

1. 현재 tick에 미소비 이벤트나 pending mutation이 없는 안정 경계인지 확인한다.
2. body ID 오름차순으로 살아 있는 본체의 속도를 검사한다.
3. 이동 본체가 하나 이상이고 모두 20 이하이면 transaction copy에서 이동 속도를 0으로 만든다.
4. 현재 위치와 그 이전까지 발생한 이벤트를 보존한 채 `TURN_END`로 전환한다.

## 수용 기준

1. 정확히 속도 20인 마지막 이동 본체는 다음 `advance_resolve`에서 현재 위치에 정지하고 `TURN_END`가 된다.
2. 속도 `20 + 1 raw`인 본체는 즉시 정산 대상이 아니다.
3. 여러 본체 중 하나라도 20을 초과하면 정상 물리를 계속한다.
4. 임계 도달 이전에 발생한 충돌·피해·파괴 이벤트는 그대로 처리한다.
5. 동일 상태 반복·복제·snapshot 복원 결과가 같다.
6. P0~P3 narrow와 Godot 활성 `verify --full`이 통과한다.

## 대상 파일

- `src/core/battle/resolve_pacing_policy.gd`
- `src/core/battle/battle_limits.gd`
- `src/core/battle/battle_state.gd`
- `src/ui/battle/p1_graybox_battle.gd`
- `src/ui/battle/p2_content_graybox.gd`
- `pipeline/tests/p1_ctb_battle_state_test.gd`
- `docs/design/game_design.md`
- `HANDOFF.md`

신규 에셋과 manifest 변경은 없다.
