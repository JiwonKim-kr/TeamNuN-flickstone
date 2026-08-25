extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const SAVE_MANAGER_SCRIPT: Script = preload("res://src/core/autoload/save_manager.gd")
const RUN_MANAGER_SCRIPT: Script = preload("res://src/core/autoload/run_manager.gd")
const CONTENT_DRIVER: Script = preload("res://src/ui/battle/p2_content_battle_driver.gd")
const BATTLE_TURN_LIMIT: int = 128
const BATTLE_STEP_LIMIT: int = 1000000

var failures: int = 0
var test_root: String = "user://p4_6_test_%d" % OS.get_process_id()
var save_manager: Node
var run_manager: Node

const TARGET_NAME: String = "continue_run.bin"
const TEMP_NAME: String = "continue_run.tmp"
const BACKUP_NAME: String = "continue_run.bak"

func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)

func initial_pieces(status: SimStatus) -> Array[RunPieceInit]:
	var result: Array[RunPieceInit] = []
	for key: int in range(1, 7): result.append(RunPieceInit.create(key, 1 if key <= 3 else 2, 1, [], status))
	return result

func terminal_candidate(catalog: ContentCatalog, status: SimStatus) -> RunState:
	var base: RunState = RunState.create(catalog, 1, 17, 29, initial_pieces(status), status)
	var graph: RunNodeGraph = base.graph_copy(status)
	var roster: Array[RunPieceInstance] = []
	for index: int in range(base.roster_count()): roster.append(base.roster_at(index, status))
	return RunState.restore_v2(catalog, base.content_fingerprint_bytes(), base.seed_hi(), base.seed_lo(), RunPhase.Value.ACT_COMPLETE, base.act_numeric_id(), 5, 7, 3, 3, 40, base.roster_capacity(), base.deployment_capacity(), base.next_piece_instance_id(), 5, graph, [1, 2, 4, 6, 7], [1, 2, 4, 6, 7], roster, [], [], [], RunPendingChoice.none(status), 0, status)

func synthetic_victory(request: RunBattleRequest, status: SimStatus) -> RunBattleOutcome:
	var facts: Array[RunBattlePlayerFact] = []
	for index: int in range(request.player_count()):
		var entry: RunBattlePlayerEntry = request.player_at(index, status)
		facts.append(RunBattlePlayerFact.create(index, entry.expected_body_id(), entry.run_instance_id(), true, 0, status))
	return RunBattleOutcome.create(request.content_fingerprint_bytes(), request.request_sequence(), request.act_numeric_id(), request.node_id(), request.node_type_id(), BattleResult.Value.PLAYER_VICTORY, facts, status)

func enemy_grade(request: RunBattleRequest, catalog: ContentCatalog, body_id: int, status: SimStatus) -> int:
	for index: int in range(request.enemy_count()):
		var entry: RunBattleEnemyEntry = request.enemy_at(index, status)
		if entry.expected_body_id() != body_id: continue
		var content_status := ContentStatus.new()
		var enemy: EnemyDefinition = catalog.enemy_by_numeric_id(entry.enemy_numeric_id(), content_status)
		if not content_status.is_ok() or not AiGrade.is_known(enemy.ai_grade_id()):
			status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD, body_id, entry.enemy_numeric_id())
			return AiGrade.Value.COMMON
		return enemy.ai_grade_id()
	status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD, body_id, 0)
	return AiGrade.Value.COMMON

func production_outcome(request: RunBattleRequest, catalog: ContentCatalog, status: SimStatus) -> RunBattleOutcome:
	var battle: BattleState = RunBattleBridge.build_state(request, catalog, status)
	if status.is_ok(): CONTENT_DRIVER.resolve_last_transition(battle, status)
	var turns: int = 0
	var steps: int = 0
	while status.is_ok() and battle.phase() != BattleState.Phase.BATTLE_END:
		steps += 1
		if steps > BATTLE_STEP_LIMIT:
			status.fail(SimStatus.Code.BATTLE_TURN_LIMIT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, steps, BATTLE_STEP_LIMIT)
			break
		match battle.phase():
			BattleState.Phase.BATTLE_START: battle.complete_battle_start(status); CONTENT_DRIVER.resolve_last_transition(battle, status)
			BattleState.Phase.TURN_START: battle.complete_turn_start(status); CONTENT_DRIVER.resolve_last_transition(battle, status)
			BattleState.Phase.AIM:
				if turns >= BATTLE_TURN_LIMIT:
					status.fail(SimStatus.Code.BATTLE_TURN_LIMIT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, turns, BATTLE_TURN_LIMIT)
					break
				var actor: BattleParticipant = battle.participant_by_body_id(battle.current_actor_body_id(), status)
				var command: LaunchCommand
				if status.is_ok() and actor.faction() == BattleParticipant.Faction.PLAYER:
					command = P1DeterministicShotSupplier.command_for(battle, status)
				elif status.is_ok():
					command = AiShotSelector.command_for(battle, enemy_grade(request, catalog, actor.body_id(), status), status)
				if status.is_ok(): LaunchVelocitySolver.commit(battle, command, status); CONTENT_DRIVER.resolve_last_transition(battle, status)
				turns += 1
			BattleState.Phase.RESOLVE: battle.advance_resolve(status); CONTENT_DRIVER.resolve_last_transition(battle, status)
			BattleState.Phase.TURN_END: battle.complete_turn_end(status); CONTENT_DRIVER.resolve_last_transition(battle, status)
			BattleState.Phase.CHECK: battle.resolve_check(status); CONTENT_DRIVER.resolve_last_transition(battle, status)
			_: status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, battle.phase(), 0)
	return RunBattleBridge.outcome_from(request, battle, status) if status.is_ok() else RunBattleOutcome.new()

func test_completion_and_save(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: RunState = terminal_candidate(catalog, status)
	var before: PackedByteArray = RunSnapshot.capture(state, status).encode(status)
	var completed: bool = state.complete_development_run(catalog, status)
	var bytes: PackedByteArray = RunSnapshot.capture(state, status).encode(status)
	var restored: RunState = RunSnapshot.decode(bytes, status).restore_state(catalog, status)
	check("P4-6-RUN-COMPLETE-V2-ROUNDTRIP", completed and status.is_ok() and state.phase_id() == RunPhase.Value.RUN_COMPLETE and restored.phase_id() == RunPhase.Value.RUN_COMPLETE and bytes == RunSnapshot.capture(restored, status).encode(status))
	var invalid_status := SimStatus.new(); var invalid: RunState = RunState.create(catalog, 1, 17, 29, initial_pieces(invalid_status), invalid_status); var invalid_before: PackedByteArray = RunSnapshot.capture(invalid, invalid_status).encode(invalid_status)
	var invalid_call_status := SimStatus.new(); var invalid_result: bool = invalid.complete_development_run(catalog, invalid_call_status); var invalid_after_status := SimStatus.new(); var invalid_after: PackedByteArray = RunSnapshot.capture(invalid, invalid_after_status).encode(invalid_after_status)
	check("P4-6-COMPLETE-WRONG-PHASE-ROLLBACK", not invalid_result and invalid_call_status.code() == SimStatus.Code.INVALID_RUN_COMPLETION and invalid_before == invalid_after and before != bytes)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root))
	save_manager.call("set_storage_root_for_tests", test_root)
	var save_status := RunSaveStatus.new(); var saved: bool = bool(save_manager.call("save_continue", state, catalog, save_status))
	var load_status := RunSaveStatus.new(); var loaded: RunState = save_manager.call("load_continue", catalog, load_status) as RunState
	check("P4-6-SINGLE-SLOT-SAVE-LOAD", saved and save_status.is_ok() and load_status.is_ok() and loaded.phase_id() == RunPhase.Value.RUN_COMPLETE and RunSnapshot.capture(loaded, status).encode(status) == bytes)
	var directory: DirAccess = DirAccess.open(test_root); directory.rename(TARGET_NAME, BACKUP_NAME)
	var recovery_status := RunSaveStatus.new(); var recovered: RunState = save_manager.call("load_continue", catalog, recovery_status) as RunState
	check("P4-6-VALID-BACKUP-RECOVERY", recovery_status.is_ok() and recovered.is_initialized() and FileAccess.file_exists(test_root.path_join(TARGET_NAME)) and not FileAccess.file_exists(test_root.path_join(BACKUP_NAME)))
	var file: FileAccess = FileAccess.open(test_root.path_join(TARGET_NAME), FileAccess.WRITE); file.store_buffer(PackedByteArray([1, 2, 3])); file.close()
	var corrupt_status := RunSaveStatus.new(); var probe: int = int(save_manager.call("probe_continue", catalog, corrupt_status))
	check("P4-6-CORRUPT-SAVE-DIAGNOSTIC", probe == 2 and corrupt_status.code() == RunSaveStatus.Code.SNAPSHOT_REJECTED and FileAccess.file_exists(test_root.path_join(TARGET_NAME)))
	var replace_status := RunSaveStatus.new(); var replaced: bool = bool(save_manager.call("save_continue", state, catalog, replace_status))
	check("P4-6-CORRUPT-TARGET-REPLACED-BY-VALID", replaced and replace_status.is_ok() and int(save_manager.call("probe_continue", catalog, RunSaveStatus.new())) == 1)

func choose_reachable_type(state: RunState, type_id: int, status: SimStatus) -> int:
	var graph: RunNodeGraph = state.graph_copy(status)
	var candidates: Array[int] = []
	if state.completed_node_count() == 0:
		for index: int in range(graph.node_count()):
			var node: RunNode = graph.node_at(index, status)
			if node.floor_index() == 1 and node.node_type_id() == type_id: candidates.append(node.node_id())
	else:
		var source: RunNode = graph.node_by_id(state.completed_node_id_at(state.completed_node_count() - 1, status), status)
		for index: int in range(source.next_node_count()):
			var node: RunNode = graph.node_by_id(source.next_node_id_at(index, status), status)
			if node.node_type_id() == type_id: candidates.append(node.node_id())
	candidates.sort()
	return 0 if candidates.is_empty() else candidates[0]

func manager_battle(node_type_id: int, status: SimStatus) -> bool:
	var state: RunState = run_manager.call("state_copy", status) as RunState; var node_id: int = choose_reachable_type(state, node_type_id, status); var save_status := RunSaveStatus.new()
	if node_id == 0 or not bool(run_manager.call("enter_node", node_id, status, save_status)): return false
	state = run_manager.call("state_copy", status) as RunState; var deployment: Array[int] = []
	for index: int in range(3): deployment.append(state.roster_at(index, status).instance_id())
	if not bool(run_manager.call("set_deployment", deployment, status, RunSaveStatus.new())): return false
	var request: RunBattleRequest = run_manager.call("begin_battle", status, RunSaveStatus.new()) as RunBattleRequest
	if not request.is_initialized(): return false
	return bool(run_manager.call("accept_battle_outcome", synthetic_victory(request, status), status, RunSaveStatus.new()))

func manager_choose_first(status: SimStatus) -> bool:
	return bool(run_manager.call("choose_pending", 1, 0, 0, status, RunSaveStatus.new()))

func test_manager_route() -> void:
	var status := SimStatus.new(); var started: bool = bool(run_manager.call("start_new_development_run", 0, 1, status, RunSaveStatus.new()))
	var normal_one: bool = started and manager_battle(RunNodeType.Value.NORMAL_BATTLE, status) and manager_choose_first(status)
	var state: RunState = run_manager.call("state_copy", status) as RunState; var shop_id: int = choose_reachable_type(state, RunNodeType.Value.SHOP, status)
	var shop: bool = bool(run_manager.call("enter_node", shop_id, status, RunSaveStatus.new())) and manager_choose_first(status)
	var normal_two: bool = manager_battle(RunNodeType.Value.NORMAL_BATTLE, status) and manager_choose_first(status)
	state = run_manager.call("state_copy", status) as RunState; var rest_id: int = choose_reachable_type(state, RunNodeType.Value.REST, status)
	var rest_entered: bool = bool(run_manager.call("enter_node", rest_id, status, RunSaveStatus.new()))
	state = run_manager.call("state_copy", status) as RunState; var pair: Array[int] = []
	for left_index: int in range(state.roster_count()):
		var left: RunPieceInstance = state.roster_at(left_index, status)
		for right_index: int in range(left_index + 1, state.roster_count()):
			var right: RunPieceInstance = state.roster_at(right_index, status)
			if left.piece_numeric_id() == right.piece_numeric_id() and left.level() == right.level() and left.level() < 3: pair = [left.instance_id(), right.instance_id()]; break
		if not pair.is_empty(): break
	var rest: bool = rest_entered and pair.size() == 2 and bool(run_manager.call("choose_pending", 2, pair[0], pair[1], status, RunSaveStatus.new()))
	var boss: bool = manager_battle(RunNodeType.Value.BOSS, status) and manager_choose_first(status)
	var completed: bool = bool(run_manager.call("complete_run", status, RunSaveStatus.new()))
	state = run_manager.call("state_copy", status) as RunState
	if not (normal_one and shop and normal_two and rest and boss and completed and status.is_ok()):
		print("[INFO] route normal1=%s shop=%s normal2=%s rest=%s boss=%s complete=%s code=%d op=%d phase=%d" % [normal_one, shop, normal_two, rest, boss, completed, status.code(), status.operation(), 0 if state == null else state.phase_id()])
	check("P4-6-MANAGER-ROUTE-TRANSACTION", normal_one and shop and normal_two and rest and boss and completed and status.is_ok() and state.phase_id() == RunPhase.Value.RUN_COMPLETE and state.relic_count() == 1)

func deployment_ids(state: RunState, status: SimStatus) -> Array[int]:
	var result: Array[int] = []
	for index: int in range(mini(3, state.roster_count())): result.append(state.roster_at(index, status).instance_id())
	return result

func merge_pair(state: RunState, status: SimStatus) -> Array[int]:
	for left_index: int in range(state.roster_count()):
		var left: RunPieceInstance = state.roster_at(left_index, status)
		for right_index: int in range(left_index + 1, state.roster_count()):
			var right: RunPieceInstance = state.roster_at(right_index, status)
			if left.piece_numeric_id() == right.piece_numeric_id() and left.level() == right.level() and left.level() < 3:
				return [left.instance_id(), right.instance_id()]
	return []

func automatic_choice(state: RunState, status: SimStatus) -> Array[int]:
	var pending: RunPendingChoice = state.pending_choice_copy()
	var selected := RunChoiceEntry.new()
	var selected_rank: int = 100
	for index: int in range(pending.entry_count()):
		var entry: RunChoiceEntry = pending.entry_at(index, status)
		if not entry.enabled(): continue
		var rank: int = entry.choice_id()
		if state.phase_id() == RunPhase.Value.SHOP:
			if entry.kind_id() == RunChoiceKind.Value.TAKE_RELIC: rank = entry.choice_id()
			elif entry.kind_id() == RunChoiceKind.Value.TAKE_CONSUMABLE: rank = 20 + entry.choice_id()
			else: rank = 40 + entry.choice_id()
		elif state.phase_id() == RunPhase.Value.EVENT:
			if entry.primary_numeric_id() == RunEffectKind.Value.GAIN_CONSUMABLE: rank = entry.choice_id()
			elif entry.primary_numeric_id() == RunEffectKind.Value.GAIN_GOLD: rank = 20 + entry.choice_id()
			else: rank = 40 + entry.choice_id()
		elif state.phase_id() == RunPhase.Value.REST:
			if entry.kind_id() == RunChoiceKind.Value.RECOVER_LIFE: rank = entry.choice_id()
			else: rank = 20 + entry.choice_id()
		if rank < selected_rank: selected = entry; selected_rank = rank
	if not selected.is_initialized(): return []
	var result: Array[int] = [selected.choice_id(), 0, 0]
	if selected.kind_id() == RunChoiceKind.Value.MERGE_PIECES:
		var pair: Array[int] = merge_pair(state, status)
		if pair.size() == 2: result = [selected.choice_id(), pair[0], pair[1]]
	return result

func quick_run(catalog: ContentCatalog, seed_lo: int, route: Array[int], status: SimStatus) -> PackedByteArray:
	if not bool(run_manager.call("start_new_development_run", 0, seed_lo, status, RunSaveStatus.new())): return PackedByteArray()
	var command_count: int = 0
	while status.is_ok() and command_count < 64:
		command_count += 1
		var state: RunState = run_manager.call("state_copy", status) as RunState
		match state.phase_id():
			RunPhase.Value.MAP_CHOICE:
				if state.life() < state.max_life() and state.consumable_stack_count() > 0:
					var stack: RunConsumableStack = state.consumable_stack_at(0, status)
					if not bool(run_manager.call("use_consumable", stack.consumable_numeric_id(), status, RunSaveStatus.new())): break
					state = run_manager.call("state_copy", status) as RunState
				var route_index: int = state.completed_node_count()
				if route_index >= route.size(): status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, route_index, route.size()); break
				var node_id: int = choose_reachable_type(state, route[route_index], status)
				if node_id == 0 or not bool(run_manager.call("enter_node", node_id, status, RunSaveStatus.new())): break
			RunPhase.Value.FORMATION:
				var ids: Array[int] = deployment_ids(state, status)
				if ids.size() != 3 or not bool(run_manager.call("set_deployment", ids, status, RunSaveStatus.new())): break
				var request: RunBattleRequest = run_manager.call("begin_battle", status, RunSaveStatus.new()) as RunBattleRequest
				if not request.is_initialized(): break
				var outcome: RunBattleOutcome = production_outcome(request, catalog, status)
				if not outcome.is_initialized() or not bool(run_manager.call("accept_battle_outcome", outcome, status, RunSaveStatus.new())): break
			RunPhase.Value.REWARD, RunPhase.Value.SHOP, RunPhase.Value.EVENT, RunPhase.Value.REST:
				var choice: Array[int] = automatic_choice(state, status)
				if choice.size() != 3 or not bool(run_manager.call("choose_pending", choice[0], choice[1], choice[2], status, RunSaveStatus.new())): break
			RunPhase.Value.ACT_COMPLETE:
				if not bool(run_manager.call("complete_run", status, RunSaveStatus.new())): break
			RunPhase.Value.RUN_COMPLETE, RunPhase.Value.RUN_FAILED:
				return RunSnapshot.capture(state, status).encode(status)
			_: status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_STATE_VALIDATE, state.phase_id(), command_count)
	var failed_state: RunState = run_manager.call("state_copy", SimStatus.new()) as RunState
	print("[INFO] quick seed=%d phase=%d commands=%d code=%d op=%d detail=%d/%d" % [seed_lo, 0 if failed_state == null else failed_state.phase_id(), command_count, status.code(), status.operation(), status.detail_a(), status.detail_b()])
	return PackedByteArray()

func test_quick_run(catalog: ContentCatalog, seed_lo: int, route_id: int) -> void:
	var route_a: Array[int] = [RunNodeType.Value.NORMAL_BATTLE, RunNodeType.Value.SHOP, RunNodeType.Value.NORMAL_BATTLE, RunNodeType.Value.REST, RunNodeType.Value.BOSS]
	var route_b: Array[int] = [RunNodeType.Value.NORMAL_BATTLE, RunNodeType.Value.EVENT, RunNodeType.Value.ELITE_BATTLE, RunNodeType.Value.REST, RunNodeType.Value.BOSS]
	var route: Array[int] = route_a if route_id == 0 else route_b
	var status := SimStatus.new()
	var bytes: PackedByteArray = quick_run(catalog, seed_lo, route, status)
	check("P4-6-PRODUCTION-QUICK-RUN-%d-%d" % [seed_lo, route_id], status.is_ok() and not bytes.is_empty())

func quick_arguments() -> Array[int]:
	var seed_lo: int = 0
	var route_id: int = -1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--quick-seed="): seed_lo = int(argument.trim_prefix("--quick-seed="))
		elif argument.begins_with("--quick-route="): route_id = int(argument.trim_prefix("--quick-route="))
	return [seed_lo, route_id]

func cleanup() -> void:
	var directory: DirAccess = DirAccess.open(test_root)
	if directory != null:
		for name: String in [TARGET_NAME, TEMP_NAME, BACKUP_NAME]:
			if directory.file_exists(name): directory.remove(name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_root))

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); db.name = "DataDB"; root.add_child(db)
	save_manager = SAVE_MANAGER_SCRIPT.new(); save_manager.name = "SaveManager"; root.add_child(save_manager)
	run_manager = RUN_MANAGER_SCRIPT.new(); run_manager.name = "RunManager"; root.add_child(run_manager)
	await process_frame
	var content_status := ContentStatus.new(); var loaded: bool = bool(db.call("reload_catalog", "res://src/core/data", content_status)); var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P4-6-AUTOLOADS-AVAILABLE", save_manager != null and run_manager != null)
	check("P4-6-RUNTIME-CATALOG-V9-LOAD", loaded and content_status.is_ok())
	if loaded and content_status.is_ok():
		var quick: Array[int] = quick_arguments()
		if quick[0] > 0 and quick[1] >= 0:
			test_quick_run(catalog, quick[0], quick[1])
		else:
			test_completion_and_save(catalog)
			test_manager_route()
	cleanup()
	print("P4_RUN_UI_SAVE_COMPLETION_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
