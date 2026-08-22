# Flickstone repository instructions

These instructions apply to the entire repository.

## Sources of truth

1. Read `docs/design/game_design.md` for game rules and the roadmap.
2. Read the relevant `docs/specs/*.md` before implementation.
3. Only implement core code from a spec whose `status` is `approved`.
4. Never invent values or behavior marked `⬜ 미정`; surface them as approval decisions.
5. Treat approved decisions as baselines, not untouchable conclusions. If new evidence suggests a better direction, surface the conflict, impact, migration cost, and regression scope, then request human re-approval before changing it. Never revise an approved decision silently.

## Current phase

- P0 deterministic simulation core is complete.
- P1-1 CTB/BattleState, P1-2 launch/aim/prediction, and P1-3 damage resolution are approved, implemented, and verified.
- P1-4 trigger bus/battle result T-01~10 is approved, implemented, and verified with Godot 4.6.3 narrow tests and `verify --full`.
- P1-5 deterministic fixture, battle driver, batch CSV/golden/repro runner, and playable manifest-placeholder graybox scene are implemented. Godot 4.6.3 import/smoke/manifest and the 16-case narrow batch pass; the 256/1,000-case runs, current full verification, and human combat-feel review remain.
- P0 order was: FixMath/SimRng → SimWorld → collision/wall/kill zones → state-hash regression.
- P0 and P1 use manifest-registered placeholders only.
- Do not run art lock/generation/reskin or SE generation/attachment until combat feel is approved.

## Architecture

- Put engine-independent simulation in `src/core/sim/`.
- Simulation classes must not inherit `Node` or call Godot APIs.
- Use fixed-point arithmetic, a project-owned PRNG, fixed simulation steps, stable IDs, and explicitly sorted iteration.
- Put runtime JSON under `src/core/data/`.
- Use `pipeline/scripts/manifest.py` for every manifest write.

## Verification

- Add game-specific runners as `pipeline/tests/run_*.py` so `verify --full` discovers them.
- On Windows, set `PYTHONUTF8=1` when invoking pipeline scripts.
- Before handing off implementation, run the narrow tests first and then `pipeline/scripts/verify.py --full` with Godot enabled when available.
