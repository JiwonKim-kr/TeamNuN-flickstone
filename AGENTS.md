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
- P2-6 runtime content and the playable data-driven graybox are approved, implemented, automated-verified, and human-reviewed. Runtime contains two roster pieces, one graybox-only piece, one ability/status, two synergies, one KILL-zone map, and five enemies after the P4 development ELITE/BOSS append. Its P2 baseline fingerprint was `f721ffce47ff27324a92dd8c9564e75463113fd5adb10ee7ebb388889511cf0e`; P3 migrated it to catalog v6, P4-2 to v7, P4-4 to v8, and P4-5 now owns catalog/fingerprint v9. The v9 exact cross-KAT is intentionally pending the P4-6 accumulated verification run.
- P3 deterministic hybrid shot selection is approved, implemented, automated-verified, and human-reviewed. It uses direct and one-wall-bank candidates, integer geometric scoring, COMMON/ELITE/BOSS error substreams, and an error safety guard. Catalog/fingerprint v6 and enemies v2 add mandatory `ai_grade_id`; independent Python, Godot P3 narrow, migrated P2-6 16x2 terminal golden, and Godot 4.6.3 quick `verify --full` pass. Local headless selection measured 302–336ms initially and 132ms in the final review-mode narrow run, under the 500ms ceiling. The same-seed review controls confirmed acceptable overall behavior and a clear difficulty increase for ELITE/BOSS; P3 is complete.
- P4-1 RunState/RunSnapshot and P4-2 Act/Encounter map generation are approved, implemented, and demo-verified. Catalog/fingerprint v7 introduces empty relic/consumable future documents, one five-floor development Act, four encounters, and deterministic seven-node map generation. `RunState.create` generates the graph from catalog/act/seed; restore validates it by exact regeneration. The migrated RunSnapshot v1 KAT is 331 bytes with SHA-256 `73ea51d49acb0fc2b1f2b1d696241dcf724937653e42d1249d63d66f9ff34797`.
- P4-3 formation, immutable battle request/outcome, battle seed, cumulative initial-body kill tally, D-12 restoration, run counters, life loss, and post-battle phase contracts are approved, implemented, and demo-verified. BattleSnapshot v8 restores legacy v1~7 with empty tallies, and P2-M21 now permits 3..map-capacity players while enemies remain full-capacity. Independent Python seed KAT/1,000 repeats, 15 Godot grouped checks, representative P1~P4 regressions, and Godot 4.6.3 `verify --demo` pass.
- P4-4 reward recruitment, gold, REST recovery/merge, revenge boon, catalog/fingerprint v8, and RunSnapshot v2 are approved, implemented, and covered by the accumulated P4-6 demo validation. Runtime adds three reward profiles, a battle-scoped +25% player outgoing-damage revenge status, and L2/L3 stats for both roster pieces.
- P4-5 relic/consumable/shop/event framework and catalog/fingerprint v9 are approved, implemented, and covered by the accumulated P4-6 demo validation. Runtime adds one development relic, consumable, shop, and event; RunState supports atomic fixed SHOP/EVENT choices, MAP_CHOICE life-flask use, sorted bounded inventory, and persistent victory-gold relic bonuses. The current canonical fingerprint is `f556a6e8c162e62ad2df3a90ab006f52aeefecbadc204f1f204307aaf124965f`.
- P4-6 run completion, single-slot save/continue, RunManager transaction, production battle run mode, and the 640×1,024 run graybox are approved and implemented. Targeted save/completion checks, production core/P3-AI quick four runs, P0~P4 representative regressions, import/smoke/manifest, and native render pass. Human two-route/save-restart/Web review remains before P4 closure; 16-seed all-route and `verify --full` remain formal-release debt.
- The parallel P5 art-direction draft and three 640×1,024 A/B/C style boards are present for human direction selection. They are concept-only, are not manifest-registered, and do not authorize art lock, generation, or reskin.
- Authoritative low-speed RESOLVE cutoff is approved and implemented. When every moving body is at `vmax <= 20`, remaining velocity is cleared at the current position and the battle advances to TURN_END. This intentionally prioritizes turn tempo over later low-speed collision, wall, acceleration-zone, or KILL outcomes.
- P4 submission Web preview is approved, implemented, deployed, and browser-smoke-verified. The single-thread Godot 4.6.3 Web build is published at `https://jiwonkim-kr.github.io/TeamNuN-flickstone/`; direct entry, reload, Korean HUD rendering, drag launch, and turn progression pass without browser errors.
- P4 run-loop phase direction P4-R01~17 is approved. The completed submission Web preview is classified as the P4-W delivery track, while roadmap P4 means the run loop. D-12 now restores and fully heals every roster piece after battle while preserving only level and run-scope counters. The development slice is one five-floor act, and ordinary automated verification is limited to four runs.
- During the demo period, local/CI `verify --demo` runs the five base gates and ten representative regression runners, including P4-3 and P4-6, with the approved quick P0 profile (20 repeats, 3 permutations), and CI skips docs-only changes. Exhaustive 1,000-repeat Ubuntu verification and Windows cross-platform determinism remain mandatory via the manual `release` workflow profile before a formal release.
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
- Before handing off demo-period implementation, run the affected narrow tests first and then the approved quick `pipeline/scripts/verify.py --demo` profile with Godot enabled when available. Keep `--full` and exhaustive repeats mandatory for the formal release profile.
