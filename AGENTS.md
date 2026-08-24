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
- P1-5 deterministic fixture, battle driver, batch CSV/golden/repro runner, and playable manifest-placeholder graybox scene are implemented and verified. The PT-01~04 physics baseline uses friction 3/2, restitution 19/20, and base launch speed 1,536. Godot 4.6.3 import/smoke/manifest, 16/256/1,000-case batches, current `verify --full`, and human combat-feel review pass.
- P2-1 strict JSON, append-only content IDs, typed immutable catalog, atomic `DataDB`, and canonical SHA-256 content fingerprint are approved, implemented, and verified. Runtime piece/ability records remain empty until later P2 specs approve actual content.
- P2-2 typed conditions/selectors, ability bindings, six base effects, next-wave hit records, atomic rollback, all approved engineering limits, BattleSnapshot v4, and 1,000-repeat determinism are approved, implemented, and verified. Runtime ability records remain empty.
- P2-3 status lifetime, synergy tally, modifier aggregation, three reserved effects, deterministic critical evaluation, physical materialization boundary, and BattleSnapshot v5 are approved, implemented, and verified. Catalog v3 and the P2-3 fixture pass independent canonical fingerprint checks, 1,000-repeat determinism, P0/P1/P2 regressions, and Godot 4.6.3 `verify --full`. Runtime status/synergy records remain empty until later content approval.
- P2-4 runtime spawn/projectile/transform/attach, deterministic links and expiry, atomic rollback, and result origin reporting are approved, implemented, and verified. Catalog v4, pieces v3, abilities v4, BattleSnapshot v6, and SimSnapshot v2 pass independent schema/fingerprint checks, 1,000-repeat determinism, P0/P1/P2 regressions, and Godot 4.6.3 `verify --full`. Runtime piece/ability records remain empty until later content approval.
- P2-5 maps/enemies v1, catalog/abilities/fingerprint v5, map geometry and catalog-radius deployment validation, enemy overrides, deterministic battle setup, runtime `SPAWN_ZONE` lifetime/rollback, and BattleSnapshot v7 are approved, implemented, and verified. Independent Python KAT, 18 Godot grouped checks, 1,000-repeat P2-5 determinism, P0/P1/P2 regressions, and Godot 4.6.3 `verify --full` pass. Runtime map/enemy records remain empty and static obstacles remain disabled until later approval.
- P2-6 runtime content and the playable data-driven graybox are approved, implemented, and automated-verified. Runtime now contains two roster pieces, one graybox-only piece, one ability/status, two synergies, three enemies, and one KILL-zone map at fingerprint `f721ffce47ff27324a92dd8c9564e75463113fd5adb10ee7ebb388889511cf0e`. The 1,000-repeat short transition check, 16x2 terminal/snapshot golden, and Godot 4.6.3 `verify --full` pass; human graybox review remains pending before closing P2.
- P0 order was: FixMath/SimRng → SimWorld → collision/wall/kill zones → state-hash regression.
- P0 and P1 use manifest-registered placeholders only.
- Combat feel was approved on 2026-08-23. Art lock/generation/reskin and SE generation/attachment remain separate, explicitly requested follow-up work.

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
