extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const CONTENT_DRIVER: Script = preload("res://src/ui/battle/p2_content_battle_driver.gd")
const PREDICTION_QUEUE: Script = preload("res://src/ui/battle/trajectory_prediction_queue.gd")
const ENEMY_ACTION_DELAY: Script = preload("res://src/ui/battle/enemy_action_delay.gd")
const RUNTIME_ROOT := "res://src/core/data"
const EXPECTED_FINGERPRINT := "8067a487ceb0ef2d721a3a985d8c5b7c0d8185cd4f52ce30c9d8cb59fd68edca"
const DEFAULT_PRESET: Array[int] = [0, 1, 2]
const OFF_PRESET: Array[int] = [0, 0, 2]
const STACKED_PRESET: Array[int] = [1, 1, 2]

var failures: int = 0


func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)


func deployment(catalog: ContentCatalog, preset: Array[int], reversed: bool, status: SimStatus) -> Array[BattleDeploymentEntry]:
	var result: Array[BattleDeploymentEntry] = []
	var content_status := ContentStatus.new()
	for slot_index: int in range(3):
		var piece: PieceDefinition = catalog.piece_at(preset[slot_index], content_status)
		result.append(BattleDeploymentEntry.create_player(slot_index, piece.id_ref(), 1, status))
	for slot_index: int in range(3):
		var enemy: EnemyDefinition = catalog.enemy_at(slot_index, content_status)
		var enemy_ref := ContentIdRef.create(enemy.numeric_id(), enemy.string_id(), content_status)
		result.append(BattleDeploymentEntry.create_enemy(slot_index, enemy_ref, status))
	if reversed: result.reverse()
	if not content_status.is_ok() and status.is_ok(): status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.BATTLE_SETUP_BUILD)
	return result


func build_state(catalog: ContentCatalog, preset: Array[int], seed_hi: int, seed_lo: int, reversed: bool, status: SimStatus) -> BattleState:
	var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(catalog, preset, reversed, status), seed_hi, seed_lo, status, 1)
	if status.is_ok(): CONTENT_DRIVER.resolve_last_transition(state, status)
	return state


func tally_value(state: BattleState, tag_id: int, faction: int) -> int:
	var tally: SynergyTally = state.synergy_tally_copy()
	for index: int in range(tally.count()):
		if tally.tag_numeric_id_at(index) == tag_id and tally.faction_id_at(index) == faction:
			return tally.value_at(index)
	return 0


func has_status(state: BattleState, body_id: int, status_id: int, status: SimStatus) -> bool:
	for index: int in range(state.status_count()):
		var item: StatusInstance = state.status_at(index, status)
		if item.target_body_id() == body_id and item.status_numeric_id() == status_id:
			return true
	return false


func effective_speed(state: BattleState, body_id: int, status: SimStatus) -> int:
	for participant: BattleParticipant in state._effective_participants(status):
		if participant.body_id() == body_id:
			return participant.speed_stat()
	return -1


func test_catalog(catalog: ContentCatalog) -> void:
	var status := ContentStatus.new()
	var baduk: PieceDefinition = catalog.piece_at(0, status)
	var bottle: PieceDefinition = catalog.piece_at(1, status)
	var striker: PieceDefinition = catalog.piece_at(2, status)
	var bottle_level: PieceLevelDefinition = bottle.level_definition(1, status)
	var striker_level: PieceLevelDefinition = striker.level_definition(1, status)
	var map_definition: MapDefinition = catalog.map_at(0, status)
	var encounter: EncounterDefinition = catalog.encounter_at(0, status)
	var bouncy: PieceDefinition = catalog.piece_by_numeric_id(4, status)
	var bouncy_level: PieceLevelDefinition = bouncy.level_definition(1, status)
	var caveman: PieceDefinition = catalog.piece_by_numeric_id(5, status)
	var ai_core: PieceDefinition = catalog.piece_by_numeric_id(6, status)
	var caveman_level: PieceLevelDefinition = caveman.level_definition(1, status)
	check("P2-6-RUNTIME-PACKAGE-COUNTS-IDS", status.is_ok() and catalog.fingerprint_hex() == EXPECTED_FINGERPRINT and catalog.piece_count() == 6 and catalog.ability_count() == 3 and catalog.status_count() == 2 and catalog.synergy_count() == 2 and catalog.map_count() == 1 and catalog.enemy_count() == 5 and catalog.act_count() == 1 and catalog.encounter_count() == 4 and catalog.relic_count() == 1 and catalog.consumable_count() == 1 and catalog.shop_count() == 1 and catalog.event_count() == 1 and baduk.string_id() == "baduk_stone" and bottle.string_id() == "bottle_cap" and striker.string_id() == "graybox_striker" and bouncy.string_id() == "bouncy_ball" and bouncy_level.elasticity_multiplier_raw() == 2 * FixMath.ONE_RAW and caveman.string_id() == "caveman" and caveman_level.clean_hit_damage_multiplier_raw() == 2 * FixMath.ONE_RAW and ai_core.string_id() == "ai_core")
	check("P2-6-PIECE-LEVEL1-VALUES", status.is_ok() and baduk.level_count() == 3 and bottle.level_count() == 3 and striker.level_count() == 1 and bottle_level.max_hp() == 90 and bottle_level.attack() == 24 and bottle_level.mass_raw() == 56 * FixMath.SCALE and striker_level.ability_ref_count() == 1)
	var reward_bouncy_ok: bool = true
	for reward_index: int in range(catalog.reward_profile_count()):
		var reward: RewardProfileDefinition = catalog.reward_profile_at(reward_index, status)
		reward_bouncy_ok = reward_bouncy_ok and reward.recruit_pool_count() == 5 and reward.recruit_pool_ref_at(2, status).numeric_id() == 4 and reward.recruit_pool_ref_at(3, status).numeric_id() == 5 and reward.recruit_pool_ref_at(4, status).numeric_id() == 6
	check("P5-CA-REWARD-POOLS", status.is_ok() and reward_bouncy_ok)
	check("P2-6-MAP-NEUTRAL-ENCOUNTER-DAMAGE-ZONE", status.is_ok() and map_definition.deploy_count() == 3 and map_definition.zone_count() == 0 and encounter.damage_zone_count() == 1 and encounter.damage_zone_at(0, status).turn_start_damage() == 15 and map_definition.player_slot_at(0, status).position().is_equal(FixVec2.from_ints(160, 832, SimStatus.new())))


func test_setup_status_enemy(catalog: ContentCatalog) -> void:
	var status := SimStatus.new()
	var state: BattleState = build_state(catalog, DEFAULT_PRESET, 17, 29, false, status)
	var world: SimWorld = state.world_copy(status)
	var enemy_baduk: BattleCombatant = state.combatant_by_body_id(4, status)
	check("P2-6-SETUP-BODY-DAMAGE-ZONE-ORDER", status.is_ok() and world.body_count() == 6 and world.zone_count() == 1 and not world.zone_at(0, status).is_kill_zone() and state.damage_zone_count() == 1 and world.body_by_id(1, status).position().is_equal(FixVec2.from_ints(160, 832, status)) and world.body_by_id(4, status).position().is_equal(FixVec2.from_ints(160, 192, status)))
	check("P2-6-OPENING-HASTE-BOTH-FACTIONS", status.is_ok() and state.status_count() == 2 and has_status(state, 3, 1, status) and has_status(state, 6, 1, status) and effective_speed(state, 3, status) == 125 and effective_speed(state, 6, status) == 125)
	CONTENT_DRIVER.resolve_last_transition(state, status)
	check("P2-6-OPENING-HASTE-NO-DUPLICATE", status.is_ok() and state.status_count() == 2 and state.status_at(0, status).remaining() == 1 and state.status_at(1, status).remaining() == 1)
	var empty_statuses := StatusCollection.new()
	check("P2-6-STATUS-MISSING-REMOVE-NOOP", empty_statuses.remove(3, 1, 0, status) == 0 and status.is_ok() and empty_statuses.count() == 0)
	check("P2-6-ENEMY-BASE-REUSE-OVERRIDE", status.is_ok() and enemy_baduk.max_hp() == 110 and state.piece_identity_at(3, status).piece_numeric_id() == 1 and state.piece_identity_at(5, status).piece_numeric_id() == 3 and state.ability_binding_count() == 2)
	var reversed_status := SimStatus.new()
	var reversed_state: BattleState = build_state(catalog, DEFAULT_PRESET, 17, 29, true, reversed_status)
	var bytes_a: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var bytes_b: PackedByteArray = BattleSnapshot.capture(reversed_state, reversed_status).encode(reversed_status)
	check("P2-6-DEPLOYMENT-ORDER-INDEPENDENT", status.is_ok() and reversed_status.is_ok() and bytes_a == bytes_b)


func test_synergy_modifiers(catalog: ContentCatalog) -> void:
	var default_status := SimStatus.new(); var default_state: BattleState = build_state(catalog, DEFAULT_PRESET, 31, 47, false, default_status)
	var off_status := SimStatus.new(); var off_state: BattleState = build_state(catalog, OFF_PRESET, 31, 47, false, off_status)
	var stacked_status := SimStatus.new(); var stacked_state: BattleState = build_state(catalog, STACKED_PRESET, 31, 47, false, stacked_status)
	check("P2-6-SYNERGY-OFF-TWO-THREE", default_status.is_ok() and off_status.is_ok() and stacked_status.is_ok() and tally_value(default_state, 1, BattleParticipant.Faction.PLAYER) == 2 and tally_value(off_state, 1, BattleParticipant.Faction.PLAYER) == 0 and tally_value(stacked_state, 1, BattleParticipant.Faction.PLAYER) == 3 and tally_value(stacked_state, 2, BattleParticipant.Faction.PLAYER) == 2)
	var default_damage: DamageResult = default_state._resolve_damage_direction(default_state.combatant_by_body_id(3, default_status), default_state.combatant_by_body_id(4, default_status), 64 * FixMath.SCALE, 64 * FixMath.SCALE, 1024 * FixMath.SCALE, 100, default_status)
	var off_damage: DamageResult = off_state._resolve_damage_direction(off_state.combatant_by_body_id(3, off_status), off_state.combatant_by_body_id(4, off_status), 64 * FixMath.SCALE, 64 * FixMath.SCALE, 1024 * FixMath.SCALE, 100, off_status)
	check("P2-6-DESTRUCTION-DAMAGE-MODIFIER", default_status.is_ok() and off_status.is_ok() and default_damage.resolved_damage() > off_damage.resolved_damage())
	stacked_state.complete_turn_start(stacked_status)
	CONTENT_DRIVER.resolve_last_transition(stacked_state, stacked_status)
	var command: LaunchCommand = P1DeterministicShotSupplier.command_for(stacked_state, stacked_status)
	LaunchVelocitySolver.commit(stacked_state, command, stacked_status)
	CONTENT_DRIVER.resolve_last_transition(stacked_state, stacked_status)
	var stacked_world: SimWorld = stacked_state.world_copy(stacked_status)
	check("P2-6-STEEL-MASS-MATERIALIZE", stacked_status.is_ok() and stacked_world.body_by_id(1, stacked_status).mass_raw() == 66 * FixMath.SCALE and stacked_world.body_by_id(2, stacked_status).mass_raw() == 66 * FixMath.SCALE)
	var identities: Array[BattlePieceIdentity] = []
	for index: int in range(default_state.piece_identity_count()):
		identities.append(default_state.piece_identity_at(index, default_status))
	var cap_entries: Array[SynergyTally.Entry] = [
		SynergyTally.Entry.new(1, BattleParticipant.Faction.PLAYER, ContentLimits.SYNERGY_COUNT_MAX),
		SynergyTally.Entry.new(2, BattleParticipant.Faction.PLAYER, ContentLimits.SYNERGY_COUNT_MAX),
	]
	var cap_tally: SynergyTally = SynergyTally.create(cap_entries, default_status)
	var cap_resolver: ModifierResolver = ModifierResolver.build(catalog, identities, cap_tally, default_status)
	var no_statuses := StatusCollection.new()
	var capped_outgoing: int = EffectiveStats.resolve(0, cap_resolver.aggregate(2, ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, no_statuses, default_status), ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, default_status)
	var capped_reduction: int = EffectiveStats.resolve(0, cap_resolver.aggregate(2, ModifierKind.Value.DAMAGE_FIXED_REDUCTION, no_statuses, default_status), ModifierKind.Value.DAMAGE_FIXED_REDUCTION, default_status)
	var mass_aggregate: ModifierAggregate = cap_resolver.aggregate(2, ModifierKind.Value.MASS_RAW, no_statuses, default_status)
	var capped_mass: int = EffectiveStats.resolve(56 * FixMath.SCALE, mass_aggregate, ModifierKind.Value.MASS_RAW, default_status)
	var edge_status := SimStatus.new()
	var edge_mass: int = EffectiveStats.resolve(SimLimits.MASS_MAX_RAW - 40 * FixMath.SCALE, mass_aggregate, ModifierKind.Value.MASS_RAW, edge_status)
	var overflow_status := SimStatus.new()
	EffectiveStats.resolve(SimLimits.MASS_MAX_RAW - 40 * FixMath.SCALE + 1, mass_aggregate, ModifierKind.Value.MASS_RAW, overflow_status)
	check("P2-6-SYNERGY-COUNT-CAPS-STRICT-MASS", default_status.is_ok() and capped_outgoing == 5000 and capped_reduction == 16 and capped_mass == 96 * FixMath.SCALE and edge_status.is_ok() and edge_mass == SimLimits.MASS_MAX_RAW and overflow_status.code() == SimStatus.Code.MODIFIER_RANGE_VIOLATION)


func complete_current_turn(state: BattleState, status: SimStatus) -> int:
	if state.phase() == BattleState.Phase.TURN_START: state.complete_turn_start(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	var actor: int = state.current_actor_body_id()
	if status.is_ok() and state.phase() == BattleState.Phase.AIM:
		LaunchVelocitySolver.commit(state, P1DeterministicShotSupplier.command_for(state, status), status)
		CONTENT_DRIVER.resolve_last_transition(state, status)
	while status.is_ok() and state.phase() == BattleState.Phase.RESOLVE: state.advance_resolve(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	if status.is_ok() and state.phase() == BattleState.Phase.TURN_END: state.complete_turn_end(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	if status.is_ok() and state.phase() == BattleState.Phase.CHECK: state.resolve_check(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	return actor


func test_status_expiry(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = build_state(catalog, DEFAULT_PRESET, 53, 71, false, status)
	var completed := 0
	while status.is_ok() and completed != 3 and state.phase() != BattleState.Phase.BATTLE_END:
		completed = complete_current_turn(state, status)
	check("P2-6-HASTE-TARGET-FIRST-TURN-EXPIRY", status.is_ok() and completed == 3 and not has_status(state, 3, 1, status))


func test_prediction_queue() -> void:
	var status := SimStatus.new()
	var queue: TrajectoryPredictionQueue = PREDICTION_QUEUE.new(50)
	var first: LaunchCommand = LaunchCommand.create(0, 64, status)
	var latest: LaunchCommand = LaunchCommand.create(256, 128, status)
	var weak: LaunchCommand = LaunchCommand.create(0, 31, status)
	var first_generation: int = queue.submit(first, 100)
	var early: bool = queue.can_start(149, false, true)
	var first_ready: bool = queue.can_start(150, false, true)
	var latest_generation: int = queue.submit(latest, 120)
	var latest_ready: bool = queue.can_start(170, false, true)
	var blocked_while_busy: bool = queue.can_start(170, true, true)
	var taken: LaunchCommand = queue.take_pending()
	var session_before_reset: int = queue.session()
	queue.submit(weak, 200)
	var weak_rejected: bool = not queue.has_pending()
	queue.reset()
	check("P2-6-PREDICTION-QUEUE-DEBOUNCE-LATEST", status.is_ok() and first_generation == 1 and not early and first_ready and latest_generation == 2 and latest_ready and not blocked_while_busy and taken.is_equal(latest))
	check("P2-6-PREDICTION-QUEUE-INVALIDATE", weak_rejected and queue.session() == session_before_reset + 1 and not queue.has_pending())


func test_enemy_action_delay() -> void:
	var delay: EnemyActionDelay = ENEMY_ACTION_DELAY.new(600)
	var scheduled: bool = not delay.is_ready(4, 100)
	var waits_before_boundary: bool = not delay.is_ready(4, 699)
	var ready_at_boundary: bool = delay.is_ready(4, 700)
	var remaining_is_exact: bool = delay.remaining_msec(4, 250) == 450
	delay.consume()
	var consecutive_turn_waits_again: bool = not delay.is_ready(4, 701) and delay.remaining_msec(4, 701) == 600
	delay.reset()
	check("P2-6-ENEMY-ACTION-DELAY-600MS", scheduled and waits_before_boundary and ready_at_boundary and remaining_is_exact and consecutive_turn_waits_again and delay.scheduled_actor_body_id() == 0)


func test_resolve_liveness_matrix(catalog: ContentCatalog) -> void:
	var all_settled: bool = true
	var case_count: int = 0
	var angles: Array[int] = [0, 8192, 16384, 24576, 32768, 40960, 49152, 57344]
	var powers: Array[int] = [32, 256, 128, 256, 32, 256, 128, 256]
	for case_index: int in range(angles.size()):
		var angle: int = angles[case_index]
		var power_step: int = powers[case_index]
		case_count += 1
		var status := SimStatus.new()
		var state: BattleState = build_state(catalog, DEFAULT_PRESET, 0x7000 + angle, 0x9000 + power_step, false, status)
		if status.is_ok() and state.phase() == BattleState.Phase.TURN_START:
			state.complete_turn_start(status)
			CONTENT_DRIVER.resolve_last_transition(state, status)
		if status.is_ok():
			var command: LaunchCommand = LaunchCommand.create(angle, power_step, status)
			LaunchVelocitySolver.commit(state, command, status)
			CONTENT_DRIVER.resolve_last_transition(state, status)
		var resolve_calls: int = 0
		while status.is_ok() and state.phase() == BattleState.Phase.RESOLVE and resolve_calls <= BattleLimits.NORMAL_RESOLVE_MAX_TICKS + BattleLimits.FORCED_RESOLVE_MAX_TICKS:
			state.advance_resolve(status)
			CONTENT_DRIVER.resolve_last_transition(state, status)
			resolve_calls += 1
		if not status.is_ok() or state.phase() != BattleState.Phase.TURN_END:
			all_settled = false
			break
	check("P2-6-RESOLVE-LIVENESS-ANGLE-POWER-MATRIX", all_settled and case_count == 8)


func short_transition_bytes(catalog: ContentCatalog, reversed: bool, restore_after_start: bool, status: SimStatus) -> PackedByteArray:
	var state: BattleState = build_state(catalog, DEFAULT_PRESET, 107, 109, reversed, status)
	state.complete_turn_start(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	if restore_after_start and status.is_ok():
		var checkpoint: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
		state = BattleSnapshot.decode(checkpoint, status).restore_state_with_catalog(catalog, status)
	if status.is_ok(): LaunchVelocitySolver.commit(state, P1DeterministicShotSupplier.command_for(state, status), status); CONTENT_DRIVER.resolve_last_transition(state, status)
	if status.is_ok(): state.advance_resolve(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	return BattleSnapshot.capture(state, status).encode(status)


func test_determinism_1000(catalog: ContentCatalog) -> void:
	var baseline_status := SimStatus.new(); var expected: PackedByteArray = short_transition_bytes(catalog, false, false, baseline_status)
	var deterministic: bool = baseline_status.is_ok()
	for index: int in range(1000):
		var status := SimStatus.new()
		var actual: PackedByteArray = short_transition_bytes(catalog, index % 2 == 1, index == 499, status)
		if not status.is_ok() or actual != expected:
			deterministic = false
			break
	check("P2-6-DETERMINISM-1000-THREE-TRANSITIONS", deterministic)


func report_row(preset_name: String, seed_index: int, report: P1BattleReport) -> Dictionary:
	return {
		"preset": preset_name,
		"seed_index": seed_index,
		"result": report.result,
		"turns": report.turn_count,
		"ticks": report.sim_tick_count,
		"player_alive": report.player_alive,
		"enemy_alive": report.enemy_alive,
		"player_damage": report.player_damage,
		"enemy_damage": report.enemy_damage,
		"damage_destroyed": report.damage_destroyed,
		"kill_boundary_destroyed": report.kill_boundary_destroyed,
		"kill_zone_destroyed": report.kill_zone_destroyed,
		"forced_settle_count": report.forced_settle_count,
		"terminal_hash": report.terminal_hash,
	}


func terminal_case(catalog: ContentCatalog, argument: String) -> Dictionary:
	var parts: PackedStringArray = argument.split(":")
	if parts.size() != 3:
		return {}
	var preset_name: String = parts[0]
	var seed_index: int = int(parts[1])
	var restore_after_turn: int = int(parts[2])
	var preset: Array[int] = DEFAULT_PRESET if preset_name == "default" else STACKED_PRESET
	var seed_hi: int = 0xA11CE + seed_index * 17
	var seed_lo: int = 0xBEE + seed_index * 31
	var status := SimStatus.new()
	var state: BattleState = build_state(catalog, preset, seed_hi, seed_lo, restore_after_turn > 0, status)
	var report: P1BattleReport = CONTENT_DRIVER.run_with_restore_after_turn(catalog, state, restore_after_turn, status)
	if not status.is_ok():
		print("[FAIL] P2-6-TERMINAL-CASE-%s-%d code=%d op=%d" % [preset_name, seed_index, status.code(), status.operation()])
		return {}
	return report_row(preset_name, seed_index, report)


func _init() -> void:
	var smoke_only: bool = OS.get_cmdline_user_args().has("--smoke-only")
	var terminal_argument := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--terminal-case="): terminal_argument = argument.trim_prefix("--terminal-case=")
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new(); var loaded: bool = bool(db.call("reload_catalog", RUNTIME_ROOT, content_status)); var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	if not terminal_argument.is_empty():
		var row: Dictionary = terminal_case(catalog, terminal_argument) if loaded and content_status.is_ok() else {}
		print("P2_CONTENT_GRAYBOX_CASE:%s" % JSON.stringify(row))
		print("P2_CONTENT_GRAYBOX_RESULT: %s" % ("PASS" if not row.is_empty() else "FAIL"))
		quit(0 if not row.is_empty() else 1)
		return
	check("P2-6-RUNTIME-LOAD", loaded and content_status.is_ok())
	if loaded and content_status.is_ok():
		test_catalog(catalog)
		test_setup_status_enemy(catalog)
		test_synergy_modifiers(catalog)
		test_status_expiry(catalog)
		test_prediction_queue()
		test_enemy_action_delay()
		test_resolve_liveness_matrix(catalog)
		if not smoke_only:
			test_determinism_1000(catalog)
	print("P2_CONTENT_GRAYBOX_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
