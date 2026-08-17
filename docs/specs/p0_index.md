# P0 명세 인덱스

P0의 구현 순서와 승인 상태를 관리한다. 각 명세는 독립 승인 대상이며, 선행 명세가 구현·검증되기 전에는 후속 구현을 시작하지 않는다.

| 순서 | 명세 | 상태 | 완료 조건 |
|---|---|---|---|
| 1 | [`p0_fix_math_rng.md`](p0_fix_math_rng.md) | draft | 고정소수점·벡터·PRNG 골든 벡터 통과 |
| 2 | [`p0_sim_world.md`](p0_sim_world.md) | draft | 순수 데이터 월드의 고정 스텝 통과 |
| 3 | [`p0_collision_boundaries.md`](p0_collision_boundaries.md) | draft | 원 충돌·벽·소멸·관통 검사 통과 |
| 4 | [`p0_determinism_hash_regression.md`](p0_determinism_hash_regression.md) | draft | 반복·삽입 순서·플랫폼 교차 해시 일치 |

```text
P0-1 FixMath·SimRng
  ↓
P0-2 SimWorld
  ↓
P0-3 충돌·벽·소멸 영역
  ↓
P0-4 상태 해시 회귀
```

## 공통 승인 체크

- 설계 정본의 관련 확정 항목과 모순이 없는가
- `⬜ 미정`을 임의로 확정하지 않았는가
- 수용 기준이 headless 환경에서 관찰 가능한가
- `src/core/sim/`이 Godot API와 분리되는가
- 게임 전용 회귀 러너가 `verify --full`에 자동 편입되는가
- P0·P1 플레이스홀더 정책을 위반하는 에셋 요구가 없는가
