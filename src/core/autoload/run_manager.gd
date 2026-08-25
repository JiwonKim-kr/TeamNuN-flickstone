extends Node

signal state_changed(state: RunState)
signal battle_requested(request: RunBattleRequest)
signal persistence_failed(status: RunSaveStatus)

const DEVELOPMENT_ACT_NUMERIC_ID: int = 1

var _catalog := ContentCatalog.new()
var _active := RunState.new()
var _in_flight_request := RunBattleRequest.new()
var _pending_outcome := RunBattleOutcome.new()
var _last_save_status := RunSaveStatus.new()

func _ready() -> void:
	var data_db: Node = get_node_or_null("/root/DataDB")
	var content_status := ContentStatus.new()
	if data_db != null: _catalog = data_db.call("catalog_copy", content_status) as ContentCatalog
	else: content_status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
	if not content_status.is_ok():
		push_error("RunManager catalog unavailable code=%d op=%d" % [content_status.code(), content_status.operation()])

func has_active_run() -> bool:
	return _active.is_initialized()

func state_copy(status: SimStatus) -> RunState:
	if not status.is_ok(): return RunState.new()
	if not has_active_run():
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_COPY)
		return RunState.new()
	return _active.copy(status)

func catalog_copy() -> ContentCatalog:
	return _catalog.copy() if _catalog.is_initialized() else ContentCatalog.new()

func last_save_status_copy() -> RunSaveStatus:
	return _last_save_status.copy()

func continue_probe(status: RunSaveStatus) -> int:
	var adapter: Node = get_node_or_null("/root/SaveManager")
	if adapter == null:
		status.fail(RunSaveStatus.Code.IO_ERROR, RunSaveStatus.Operation.PROBE)
		return 2
	return int(adapter.call("probe_continue", _catalog, status))

func _initial_pieces(status: SimStatus) -> Array[RunPieceInit]:
	var result: Array[RunPieceInit] = []
	for key: int in range(1, 7):
		result.append(RunPieceInit.create(key, 1 if key <= 3 else 2, 1, [], status))
	return result

func _save_candidate(candidate: RunState, save_status: RunSaveStatus) -> bool:
	var adapter: Node = get_node_or_null("/root/SaveManager")
	if adapter == null:
		save_status.fail(RunSaveStatus.Code.IO_ERROR, RunSaveStatus.Operation.WRITE_TEMP)
	elif bool(adapter.call("save_continue", candidate, _catalog, save_status)):
		_last_save_status = RunSaveStatus.new()
		return true
	_last_save_status = save_status.copy()
	persistence_failed.emit(_last_save_status.copy())
	return false

func _commit(candidate: RunState) -> void:
	_active = candidate
	state_changed.emit(_active.copy(SimStatus.new()))

func start_new_development_run(seed_hi: int, seed_lo: int, sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not sim_status.is_ok() or not save_status.is_ok(): return false
	var candidate: RunState = RunState.create(_catalog, DEVELOPMENT_ACT_NUMERIC_ID, seed_hi, seed_lo, _initial_pieces(sim_status), sim_status)
	if not sim_status.is_ok() or not candidate.is_initialized() or not _save_candidate(candidate, save_status): return false
	_in_flight_request = RunBattleRequest.new()
	_pending_outcome = RunBattleOutcome.new()
	_commit(candidate)
	return true

func continue_run(sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not sim_status.is_ok() or not save_status.is_ok(): return false
	var adapter: Node = get_node_or_null("/root/SaveManager")
	if adapter == null:
		save_status.fail(RunSaveStatus.Code.IO_ERROR, RunSaveStatus.Operation.READ)
		return false
	var candidate: RunState = adapter.call("load_continue", _catalog, save_status) as RunState
	if not save_status.is_ok() or not candidate.is_initialized(): return false
	if not candidate.validate(_catalog, sim_status): return false
	_in_flight_request = RunBattleRequest.new()
	_pending_outcome = RunBattleOutcome.new()
	_last_save_status = RunSaveStatus.new()
	_commit(candidate)
	return true

func _node_type(node_id: int, status: SimStatus) -> int:
	var graph: RunNodeGraph = _active.graph_copy(status)
	var node: RunNode = graph.node_by_id(node_id, status)
	return node.node_type_id() if status.is_ok() else RunNodeType.Value.INVALID

func enter_node(node_id: int, sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not has_active_run() or _active.phase_id() != RunPhase.Value.MAP_CHOICE:
		sim_status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_NODE_CHOOSE, 0 if not has_active_run() else _active.phase_id(), node_id)
		return false
	# P4-R16: persist the recovery point before entering an unsaved node screen.
	if not _save_candidate(_active, save_status): return false
	var node_type_id: int = _node_type(node_id, sim_status)
	var candidate: RunState = _active.copy(sim_status)
	if not sim_status.is_ok(): return false
	var ok: bool = false
	match node_type_id:
		RunNodeType.Value.NORMAL_BATTLE, RunNodeType.Value.ELITE_BATTLE, RunNodeType.Value.BOSS:
			ok = candidate.choose_battle_node(_catalog, node_id, sim_status)
		RunNodeType.Value.SHOP:
			ok = candidate.choose_shop_node(_catalog, node_id, sim_status)
		RunNodeType.Value.EVENT:
			ok = candidate.choose_event_node(_catalog, node_id, sim_status)
		RunNodeType.Value.REST:
			ok = candidate.choose_rest_node(_catalog, node_id, sim_status)
		_:
			sim_status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, node_id, node_type_id)
	if not ok: return false
	# REST can complete immediately when neither action is available.
	if candidate.phase_id() == RunPhase.Value.MAP_CHOICE and not _save_candidate(candidate, save_status): return false
	_commit(candidate)
	return true

func set_deployment(instance_ids: Array[int], sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not has_active_run():
		sim_status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_DEPLOYMENT_SET)
		return false
	var candidate: RunState = _active.copy(sim_status)
	if not sim_status.is_ok() or not candidate.set_deployment(_catalog, instance_ids, sim_status): return false
	if not _save_candidate(candidate, save_status): return false
	_commit(candidate)
	return true

func begin_battle(sim_status: SimStatus, save_status: RunSaveStatus) -> RunBattleRequest:
	if not has_active_run():
		sim_status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_BATTLE_BEGIN)
		return RunBattleRequest.new()
	if not _save_candidate(_active, save_status): return RunBattleRequest.new()
	var candidate: RunState = _active.copy(sim_status)
	var request: RunBattleRequest = candidate.begin_battle(_catalog, sim_status)
	if not sim_status.is_ok() or not request.is_initialized(): return RunBattleRequest.new()
	_active = candidate
	_in_flight_request = request.copy()
	_pending_outcome = RunBattleOutcome.new()
	state_changed.emit(_active.copy(SimStatus.new()))
	battle_requested.emit(request.copy())
	return request

func accept_battle_outcome(outcome: RunBattleOutcome, sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if outcome == null or not outcome.is_initialized() or not _in_flight_request.is_initialized() or outcome.request_sequence() != _in_flight_request.request_sequence():
		sim_status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_APPLY, 0 if outcome == null else outcome.request_sequence(), 0 if not _in_flight_request.is_initialized() else _in_flight_request.request_sequence())
		return false
	_pending_outcome = outcome.copy()
	return retry_battle_outcome_commit(sim_status, save_status)

func retry_battle_outcome_commit(sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not _pending_outcome.is_initialized() or not has_active_run() or _active.phase_id() != RunPhase.Value.BATTLE:
		sim_status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_APPLY)
		return false
	var candidate: RunState = _active.copy(sim_status)
	if not sim_status.is_ok() or not candidate.apply_battle_outcome(_catalog, _pending_outcome, sim_status): return false
	if candidate.phase_id() == RunPhase.Value.REWARD and candidate.pending_choice_copy().kind_id() == RunPendingKind.Value.NONE:
		if not candidate.prepare_reward(_catalog, sim_status): return false
	if not _save_candidate(candidate, save_status): return false
	_in_flight_request = RunBattleRequest.new()
	_pending_outcome = RunBattleOutcome.new()
	_commit(candidate)
	return true

func choose_pending(choice_id: int, first_instance_id: int, second_instance_id: int, sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not has_active_run():
		sim_status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE)
		return false
	var candidate: RunState = _active.copy(sim_status)
	if not sim_status.is_ok(): return false
	var ok: bool = false
	match candidate.phase_id():
		RunPhase.Value.REWARD: ok = candidate.choose_reward(_catalog, choice_id, sim_status)
		RunPhase.Value.SHOP: ok = candidate.resolve_shop(_catalog, choice_id, sim_status)
		RunPhase.Value.EVENT: ok = candidate.resolve_event(_catalog, choice_id, sim_status)
		RunPhase.Value.REST: ok = candidate.resolve_rest(_catalog, choice_id, first_instance_id, second_instance_id, sim_status)
		_: sim_status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_STATE_VALIDATE, candidate.phase_id(), choice_id)
	if not ok or not _save_candidate(candidate, save_status): return false
	_commit(candidate)
	return true

func use_consumable(consumable_numeric_id: int, sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not has_active_run():
		sim_status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_CONSUMABLE_USE)
		return false
	var candidate: RunState = _active.copy(sim_status)
	if not sim_status.is_ok() or not candidate.use_consumable(_catalog, consumable_numeric_id, sim_status): return false
	if not _save_candidate(candidate, save_status): return false
	_commit(candidate)
	return true

func complete_run(sim_status: SimStatus, save_status: RunSaveStatus) -> bool:
	if not has_active_run():
		sim_status.fail(SimStatus.Code.INVALID_RUN_COMPLETION, SimStatus.Operation.RUN_COMPLETE)
		return false
	var candidate: RunState = _active.copy(sim_status)
	if not sim_status.is_ok() or not candidate.complete_development_run(_catalog, sim_status): return false
	if not _save_candidate(candidate, save_status): return false
	_commit(candidate)
	return true
