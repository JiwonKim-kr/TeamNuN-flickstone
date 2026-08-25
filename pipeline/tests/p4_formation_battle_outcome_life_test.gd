extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const EXPECTED_SEED_HI: int = 3874717381
const EXPECTED_SEED_LO: int = 1837807032

var failures: int = 0

func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)

func write_u32(bytes: PackedByteArray, offset: int, value: int) -> void:
	for shift: int in range(0, 32, 8): bytes[offset + (shift >> 3)] = (value >> shift) & 0xFF

func initial_pieces(status: SimStatus) -> Array[RunPieceInit]:
	var result: Array[RunPieceInit] = []
	for key: int in range(1, 7): result.append(RunPieceInit.create(key, 1 if key <= 3 else 2, 1, [], status))
	return result

func new_state(catalog: ContentCatalog, status: SimStatus) -> RunState:
	return RunState.create(catalog, 1, 17, 29, initial_pieces(status), status)

func formation_for_node(catalog: ContentCatalog, node_id: int, life: int, visited: Array[int], completed: Array[int], status: SimStatus) -> RunState:
	var base: RunState = new_state(catalog, status); var graph: RunNodeGraph = base.graph_copy(status); var node: RunNode = graph.node_by_id(node_id, status)
	var roster: Array[RunPieceInstance] = []
	for index: int in range(base.roster_count()): roster.append(base.roster_at(index, status))
	return RunState.restore_v1(catalog, base.content_fingerprint_bytes(), base.seed_hi(), base.seed_lo(), RunPhase.Value.FORMATION, base.act_numeric_id(), node.floor_index(), node_id, life, base.max_life(), base.gold(), base.roster_capacity(), base.deployment_capacity(), base.next_piece_instance_id(), 1, graph, visited, completed, roster, [1, 4, 2], [], [], RunPendingChoice.none(status), status)

func synthetic_outcome(request: RunBattleRequest, result_value: int, survived: Array[bool], kills: Array[int], status: SimStatus) -> RunBattleOutcome:
	var facts: Array[RunBattlePlayerFact] = []
	for index: int in range(request.player_count()):
		var entry: RunBattlePlayerEntry = request.player_at(index, status)
		facts.append(RunBattlePlayerFact.create(index, entry.expected_body_id(), entry.run_instance_id(), survived[index], kills[index], status))
	return RunBattleOutcome.create(request.content_fingerprint_bytes(), request.request_sequence(), request.act_numeric_id(), request.node_id(), request.node_type_id(), result_value, facts, status)

func test_selection_request(catalog: ContentCatalog) -> RunBattleRequest:
	var status := SimStatus.new(); var state: RunState = new_state(catalog, status)
	var wrong_status := SimStatus.new(); var wrong: bool = state.choose_battle_node(catalog, 2, wrong_status)
	var chosen: bool = state.choose_battle_node(catalog, 1, status)
	var duplicate_status := SimStatus.new(); var duplicate: bool = state.set_deployment(catalog, [1, 1, 2], duplicate_status)
	var deployed: bool = state.set_deployment(catalog, [1, 4, 2], status)
	var formation_bytes: PackedByteArray = RunSnapshot.capture(state, status).encode(status)
	var request: RunBattleRequest = state.begin_battle(catalog, status)
	check("P4-3-NODE-REACHABILITY-ATOMIC", not wrong and wrong_status.code() == SimStatus.Code.INVALID_RUN_NODE and chosen and state.phase_id() == RunPhase.Value.BATTLE)
	check("P4-3-DEPLOYMENT-ORDER-AND-DUPLICATE", not duplicate and duplicate_status.code() == SimStatus.Code.INVALID_DEPLOYMENT and deployed and request.player_at(0, status).run_instance_id() == 1 and request.player_at(1, status).run_instance_id() == 4)
	check("P4-3-BATTLE-SEED-REQUEST-SEQUENCE", status.is_ok() and request.battle_seed_hi() == EXPECTED_SEED_HI and request.battle_seed_lo() == EXPECTED_SEED_LO and request.request_sequence() == 1 and state.next_transition_sequence() == 2)
	var capture_status := SimStatus.new(); RunSnapshot.capture(state, capture_status)
	var restored_status := SimStatus.new(); var restored: RunState = RunSnapshot.decode(formation_bytes, restored_status).restore_state(catalog, restored_status); var repeated: RunBattleRequest = restored.begin_battle(catalog, restored_status)
	check("P4-3-FORMATION-SAVE-BATTLE-SAVE-GATE", not capture_status.is_ok() and restored_status.is_ok() and repeated.battle_seed_hi() == request.battle_seed_hi() and repeated.request_sequence() == request.request_sequence())
	return request

func test_bridge_and_v9(catalog: ContentCatalog, request: RunBattleRequest) -> void:
	var status := SimStatus.new(); var battle: BattleState = RunBattleBridge.build_state(request, catalog, status)
	var initial_bytes: PackedByteArray = BattleSnapshot.capture(battle, status).encode(status); var initial_sim: PackedByteArray = SimSnapshot.capture(battle.world_copy(status), status).encode(status)
	var initial_sim_length_offset: int = initial_bytes.size() - initial_sim.size() - 4; var initial_damage_count_offset: int = initial_sim_length_offset - 4 - battle.damage_zone_count() * 12; var initial_kill_count_offset: int = initial_damage_count_offset - 4 - battle.kill_tally_count() * 8
	var legacy_v7: PackedByteArray = initial_bytes.slice(0, initial_kill_count_offset); legacy_v7.append_array(initial_bytes.slice(initial_sim_length_offset, initial_bytes.size())); legacy_v7[9] = 7; legacy_v7[10] = 0
	var legacy_status := SimStatus.new(); var legacy_state: BattleState = BattleSnapshot.decode(legacy_v7, legacy_status).restore_state_with_catalog(catalog, legacy_status); var legacy_recap: PackedByteArray = BattleSnapshot.capture(legacy_state, legacy_status).encode(legacy_status)
	var report: P1BattleReport = P1BattleDriver.run(battle, status)
	var outcome: RunBattleOutcome = RunBattleBridge.outcome_from(request, battle, status)
	var bytes: PackedByteArray = BattleSnapshot.capture(battle, status).encode(status)
	var restored: BattleState = BattleSnapshot.decode(bytes, status).restore_state_with_catalog(catalog, status)
	var tally_equal: bool = restored.kill_tally_count() == battle.kill_tally_count()
	for index: int in range(battle.kill_tally_count()):
		var left: BattleKillTally = battle.kill_tally_at(index, status); var right: BattleKillTally = restored.kill_tally_at(index, status)
		tally_equal = tally_equal and left.body_id() == right.body_id() and left.kill_count() == right.kill_count()
	check("P4-3-BRIDGE-TERMINAL-OUTCOME", status.is_ok() and report.result == outcome.battle_result() and outcome.player_fact_count() == request.player_count())
	check("P4-3-BATTLE-SNAPSHOT-V9-KILL-TALLY", status.is_ok() and bytes[9] == BattleSnapshot.SCHEMA_VERSION and bytes[10] == 0 and battle.kill_tally_count() > 0 and tally_equal and restored.damage_zone_count() == battle.damage_zone_count())
	check("P4-3-LEGACY-V7-RECAPTURE-V9", legacy_status.is_ok() and legacy_state.kill_tally_count() == 0 and legacy_state.damage_zone_count() == 0 and legacy_recap[9] == 9 and legacy_recap[10] == 0)
	var malformed: PackedByteArray = initial_bytes.duplicate(); write_u32(malformed, initial_kill_count_offset, battle.piece_origin_count() + 1)
	var malformed_status := SimStatus.new(); BattleSnapshot.decode(malformed, malformed_status)
	check("P4-3-KILL-TALLY-MALFORMED-REJECT", not malformed_status.is_ok())

func test_outcome_life_counters(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var normal: RunState = formation_for_node(catalog, 1, 3, [1], [], status); var normal_request: RunBattleRequest = normal.begin_battle(catalog, status)
	var draw: RunBattleOutcome = synthetic_outcome(normal_request, BattleResult.Value.DRAW, [true, false, true], [2, 0, 1], status)
	var applied: bool = normal.apply_battle_outcome(catalog, draw, status); var snapshot: PackedByteArray = RunSnapshot.capture(normal, status).encode(status); var restored: RunState = RunSnapshot.decode(snapshot, status).restore_state(catalog, status)
	check("P4-3-DRAW-LIFE-REWARD-INCOMPLETE", applied and status.is_ok() and restored.life() == 2 and restored.phase_id() == RunPhase.Value.REWARD and restored.completed_node_count() == 0)
	check("P4-3-RUN-COUNTERS-AND-D12", restored.counter_value(1, RunCounterKind.Value.BATTLES_SURVIVED, status) == 1 and restored.counter_value(1, RunCounterKind.Value.KILLS, status) == 2 and restored.counter_value(4, RunCounterKind.Value.BATTLES_SURVIVED, status) == 0 and restored.roster_count() == 6)
	var duplicate_status := SimStatus.new(); var duplicate: bool = normal.apply_battle_outcome(catalog, draw, duplicate_status)
	check("P4-3-OUTCOME-EXACTLY-ONCE", not duplicate and duplicate_status.code() == SimStatus.Code.INVALID_PHASE)

	var elite_status := SimStatus.new(); var elite: RunState = formation_for_node(catalog, 5, 3, [1, 5], [1], elite_status); var elite_request: RunBattleRequest = elite.begin_battle(catalog, elite_status)
	var elite_loss: RunBattleOutcome = synthetic_outcome(elite_request, BattleResult.Value.PLAYER_DEFEAT, [false, false, true], [0, 0, 0], elite_status); elite.apply_battle_outcome(catalog, elite_loss, elite_status)
	check("P4-3-ELITE-LIFE-MINUS-TWO", elite_status.is_ok() and elite.life() == 1 and elite.phase_id() == RunPhase.Value.REWARD and elite.completed_node_count() == 1)

	var boss_status := SimStatus.new(); var boss: RunState = formation_for_node(catalog, 7, 1, [1, 5, 7], [1, 5], boss_status); var boss_request: RunBattleRequest = boss.begin_battle(catalog, boss_status)
	var boss_loss: RunBattleOutcome = synthetic_outcome(boss_request, BattleResult.Value.PLAYER_DEFEAT, [false, false, false], [0, 0, 0], boss_status); boss.apply_battle_outcome(catalog, boss_loss, boss_status)
	var failed_bytes: PackedByteArray = RunSnapshot.capture(boss, boss_status).encode(boss_status)
	check("P4-3-BOSS-RUN-FAILED-SNAPSHOT", boss_status.is_ok() and boss.life() == 0 and boss.phase_id() == RunPhase.Value.RUN_FAILED and not failed_bytes.is_empty())

func test_request_determinism(catalog: ContentCatalog) -> void:
	var deterministic: bool = true
	for index: int in range(1000):
		var status := SimStatus.new(); var state: RunState = new_state(catalog, status)
		state.choose_battle_node(catalog, 1, status); state.set_deployment(catalog, [1, 4, 2], status); var request: RunBattleRequest = state.begin_battle(catalog, status)
		if not status.is_ok() or request.battle_seed_hi() != EXPECTED_SEED_HI or request.battle_seed_lo() != EXPECTED_SEED_LO or request.player_at(1, status).run_instance_id() != 4: deterministic = false; break
	check("P4-3-REQUEST-DETERMINISM-1000", deterministic)

func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new(); var loaded: bool = bool(db.call("reload_catalog", "res://src/core/data", content_status)); var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P4-3-RUNTIME-CATALOG-LOAD", loaded and content_status.is_ok())
	if loaded and content_status.is_ok():
		var request: RunBattleRequest = test_selection_request(catalog)
		if request.is_initialized(): test_bridge_and_v9(catalog, request)
		test_outcome_life_counters(catalog); test_request_determinism(catalog)
	print("P4_FORMATION_BATTLE_OUTCOME_LIFE_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
