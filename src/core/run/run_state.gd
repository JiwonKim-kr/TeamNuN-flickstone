class_name RunState
extends RefCounted

var _content_fingerprint: PackedByteArray = PackedByteArray()
var _seed_hi: int = 0
var _seed_lo: int = 0
var _phase_id: int = RunPhase.Value.INVALID
var _act_numeric_id: int = 0
var _current_floor: int = 0
var _current_node_id: int = 0
var _life: int = 0
var _max_life: int = 0
var _gold: int = 0
var _roster_capacity: int = 0
var _deployment_capacity: int = 0
var _next_piece_instance_id: int = 0
var _next_transition_sequence: int = 0
var _graph: RunNodeGraph = RunNodeGraph.new()
var _visited_node_ids: Array[int] = []
var _completed_node_ids: Array[int] = []
var _roster: Array[RunPieceInstance] = []
var _deployment_instance_ids: Array[int] = []
var _relic_numeric_ids: Array[int] = []
var _consumable_stacks: Array[RunConsumableStack] = []
var _pending_choice: RunPendingChoice = RunPendingChoice.new()
var _initialized: bool = false

static func create(catalog: ContentCatalog, act_numeric_id: int, seed_hi: int, seed_lo: int, initial_pieces: Array[RunPieceInit], status: SimStatus) -> RunState:
	var result := RunState.new()
	if not status.is_ok(): return result
	if catalog == null or not catalog.is_initialized() or act_numeric_id <= 0 or act_numeric_id > 0xFFFFFFFF or seed_hi < 0 or seed_hi > 0xFFFFFFFF or seed_lo < 0 or seed_lo > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_CREATE, act_numeric_id, 0); return result
	var graph: RunNodeGraph = RunMapGenerator.generate(catalog, act_numeric_id, seed_hi, seed_lo, status)
	if not status.is_ok(): return RunState.new()
	if initial_pieces.is_empty() or initial_pieces.size() > RunLimits.GAMEPLAY_ROSTER_CAP:
		status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED, SimStatus.Operation.RUN_STATE_CREATE, initial_pieces.size(), RunLimits.GAMEPLAY_ROSTER_CAP); return result
	var sorted: Array[RunPieceInit] = []
	for item: RunPieceInit in initial_pieces:
		if item == null or not item.is_initialized():
			status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_CREATE); return RunState.new()
		sorted.append(item.copy())
	sorted.sort_custom(func(a: RunPieceInit, b: RunPieceInit) -> bool: return a.initial_key() < b.initial_key())
	var previous_key: int = 0
	for index: int in range(sorted.size()):
		var item: RunPieceInit = sorted[index]
		if item.initial_key() <= previous_key:
			status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_CREATE, item.initial_key(), previous_key); return RunState.new()
		if not _catalog_allows_piece(catalog, item.piece_numeric_id(), item.level()):
			status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_CREATE, item.piece_numeric_id(), item.level()); return RunState.new()
		var counters: Array[RunCounter] = []
		for counter_index: int in range(item.counter_count()): counters.append(item.counter_at(counter_index, status))
		result._roster.append(RunPieceInstance.restore(index + 1, item.piece_numeric_id(), item.level(), counters, status))
		if not status.is_ok(): return RunState.new()
		previous_key = item.initial_key()
	result._content_fingerprint = catalog.fingerprint_bytes()
	result._seed_hi = seed_hi; result._seed_lo = seed_lo; result._phase_id = RunPhase.Value.MAP_CHOICE; result._act_numeric_id = act_numeric_id
	result._life = RunLimits.GAMEPLAY_START_LIFE; result._max_life = RunLimits.GAMEPLAY_START_LIFE; result._roster_capacity = RunLimits.GAMEPLAY_ROSTER_CAP
	result._deployment_capacity = RunLimits.GAMEPLAY_DEPLOYMENT_CAP; result._next_piece_instance_id = result._roster.size() + 1; result._next_transition_sequence = 1
	result._graph = graph.copy(status); result._pending_choice = RunPendingChoice.none(status)
	if not status.is_ok() or not result._validate_structure(status): return RunState.new()
	result._initialized = true
	return result

static func restore_v1(catalog: ContentCatalog, content_fingerprint: PackedByteArray, seed_hi: int, seed_lo: int, phase_id: int, act_numeric_id: int, current_floor: int, current_node_id: int, life: int, max_life: int, gold: int, roster_capacity: int, deployment_capacity: int, next_piece_instance_id: int, next_transition_sequence: int, graph: RunNodeGraph, visited_node_ids: Array[int], completed_node_ids: Array[int], roster: Array[RunPieceInstance], deployment_instance_ids: Array[int], relic_numeric_ids: Array[int], consumable_stacks: Array[RunConsumableStack], pending_choice: RunPendingChoice, status: SimStatus) -> RunState:
	var result := RunState.new()
	if not status.is_ok(): return result
	if catalog == null or not catalog.is_initialized() or graph == null or not graph.is_initialized() or pending_choice == null or not pending_choice.is_initialized():
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_SNAPSHOT_RESTORE); return result
	result._content_fingerprint = content_fingerprint.duplicate(); result._seed_hi = seed_hi; result._seed_lo = seed_lo; result._phase_id = phase_id; result._act_numeric_id = act_numeric_id
	result._current_floor = current_floor; result._current_node_id = current_node_id; result._life = life; result._max_life = max_life; result._gold = gold
	result._roster_capacity = roster_capacity; result._deployment_capacity = deployment_capacity; result._next_piece_instance_id = next_piece_instance_id; result._next_transition_sequence = next_transition_sequence
	result._graph = graph.copy(status); result._visited_node_ids = visited_node_ids.duplicate(); result._completed_node_ids = completed_node_ids.duplicate()
	for item: RunPieceInstance in roster: result._roster.append(item.copy())
	result._deployment_instance_ids = deployment_instance_ids.duplicate(); result._relic_numeric_ids = relic_numeric_ids.duplicate()
	for stack: RunConsumableStack in consumable_stacks: result._consumable_stacks.append(stack.copy())
	result._pending_choice = pending_choice.copy()
	if not status.is_ok() or not result._validate_structure(status): return RunState.new()
	if result._content_fingerprint != catalog.fingerprint_bytes():
		status.fail(SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH, SimStatus.Operation.RUN_SNAPSHOT_RESTORE); return RunState.new()
	if not RunMapGenerator.validate_exact(catalog, result._act_numeric_id, result._seed_hi, result._seed_lo, result._graph, status): return RunState.new()
	for piece: RunPieceInstance in result._roster:
		if not _catalog_allows_piece(catalog, piece.piece_numeric_id(), piece.level()):
			status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_SNAPSHOT_RESTORE, piece.piece_numeric_id(), piece.level()); return RunState.new()
	result._initialized = true
	return result

static func _catalog_allows_piece(catalog: ContentCatalog, piece_numeric_id: int, level: int) -> bool:
	var content_status := ContentStatus.new()
	var piece: PieceDefinition = catalog.piece_by_numeric_id(piece_numeric_id, content_status)
	return content_status.is_ok() and piece.is_initialized() and not piece.is_token() and level >= 1 and level <= piece.level_count()

func _validate_sorted_node_ids(values: Array[int], status: SimStatus) -> bool:
	var previous: int = 0
	for value: int in values:
		if value <= previous or value > _graph.node_count():
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, value, previous); return false
		previous = value
	return true

func _validate_structure(status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if _content_fingerprint.size() != 32 or _seed_hi < 0 or _seed_hi > 0xFFFFFFFF or _seed_lo < 0 or _seed_lo > 0xFFFFFFFF or _phase_id != RunPhase.Value.MAP_CHOICE or _act_numeric_id <= 0 or _act_numeric_id > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _act_numeric_id); return false
	if _current_floor != 0 or _current_node_id != 0 or _life <= 0 or _life > _max_life or _max_life < 1 or _max_life > RunLimits.MAX_LIFE or _gold < 0 or _gold > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _life, _max_life); return false
	if _roster_capacity < 1 or _roster_capacity > RunLimits.MAX_ROSTER or _deployment_capacity < 1 or _deployment_capacity > RunLimits.MAX_DEPLOYMENT or _deployment_capacity > _roster_capacity or _roster.is_empty() or _roster.size() > _roster_capacity:
		status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED, SimStatus.Operation.RUN_STATE_VALIDATE, _roster.size(), _roster_capacity); return false
	if _graph == null or not _graph.is_initialized() or _pending_choice == null or not _pending_choice.is_initialized():
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE); return false
	if not _validate_sorted_node_ids(_visited_node_ids, status) or not _validate_sorted_node_ids(_completed_node_ids, status): return false
	for completed_id: int in _completed_node_ids:
		if _visited_node_ids.bsearch(completed_id) >= _visited_node_ids.size() or _visited_node_ids[_visited_node_ids.bsearch(completed_id)] != completed_id:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, completed_id, 0); return false
	var previous_instance: int = 0
	for piece: RunPieceInstance in _roster:
		if piece == null or not piece.is_initialized() or piece.instance_id() <= previous_instance:
			status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_VALIDATE, 0 if piece == null else piece.instance_id(), previous_instance); return false
		previous_instance = piece.instance_id()
	if _next_piece_instance_id <= previous_instance or _next_piece_instance_id > 0xFFFFFFFF or _next_transition_sequence != 1:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _next_piece_instance_id, _next_transition_sequence); return false
	if not _visited_node_ids.is_empty() or not _completed_node_ids.is_empty() or not _deployment_instance_ids.is_empty() or not _relic_numeric_ids.is_empty() or not _consumable_stacks.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.NONE:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _pending_choice.kind_id(), 1); return false
	return true

func copy(status: SimStatus) -> RunState:
	var result := RunState.new()
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_COPY)
		return result
	result._content_fingerprint = _content_fingerprint.duplicate(); result._seed_hi = _seed_hi; result._seed_lo = _seed_lo; result._phase_id = _phase_id; result._act_numeric_id = _act_numeric_id
	result._current_floor = _current_floor; result._current_node_id = _current_node_id; result._life = _life; result._max_life = _max_life; result._gold = _gold
	result._roster_capacity = _roster_capacity; result._deployment_capacity = _deployment_capacity; result._next_piece_instance_id = _next_piece_instance_id; result._next_transition_sequence = _next_transition_sequence
	result._graph = _graph.copy(status); result._visited_node_ids = _visited_node_ids.duplicate(); result._completed_node_ids = _completed_node_ids.duplicate()
	for piece: RunPieceInstance in _roster: result._roster.append(piece.copy())
	result._deployment_instance_ids = _deployment_instance_ids.duplicate(); result._relic_numeric_ids = _relic_numeric_ids.duplicate()
	for stack: RunConsumableStack in _consumable_stacks: result._consumable_stacks.append(stack.copy())
	result._pending_choice = _pending_choice.copy()
	if not status.is_ok() or not result._validate_structure(status): return RunState.new()
	result._initialized = true
	return result

func validate(catalog: ContentCatalog, status: SimStatus) -> bool:
	if not _initialized or not _validate_structure(status): return false
	if catalog == null or not catalog.is_initialized() or _content_fingerprint != catalog.fingerprint_bytes():
		if status.is_ok(): status.fail(SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH, SimStatus.Operation.RUN_STATE_VALIDATE)
		return false
	for piece: RunPieceInstance in _roster:
		if not _catalog_allows_piece(catalog, piece.piece_numeric_id(), piece.level()):
			status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_VALIDATE, piece.piece_numeric_id(), piece.level()); return false
	if not RunMapGenerator.validate_exact(catalog, _act_numeric_id, _seed_hi, _seed_lo, _graph, status): return false
	return true

func is_initialized() -> bool: return _initialized
func content_fingerprint_bytes() -> PackedByteArray: return _content_fingerprint.duplicate()
func seed_hi() -> int: return _seed_hi
func seed_lo() -> int: return _seed_lo
func phase_id() -> int: return _phase_id
func act_numeric_id() -> int: return _act_numeric_id
func current_floor() -> int: return _current_floor
func current_node_id() -> int: return _current_node_id
func life() -> int: return _life
func max_life() -> int: return _max_life
func gold() -> int: return _gold
func roster_capacity() -> int: return _roster_capacity
func deployment_capacity() -> int: return _deployment_capacity
func next_piece_instance_id() -> int: return _next_piece_instance_id
func next_transition_sequence() -> int: return _next_transition_sequence
func graph_copy(status: SimStatus) -> RunNodeGraph: return _graph.copy(status)
func visited_node_count() -> int: return _visited_node_ids.size()
func visited_node_id_at(index: int, status: SimStatus) -> int: return _id_at(_visited_node_ids, index, status)
func completed_node_count() -> int: return _completed_node_ids.size()
func completed_node_id_at(index: int, status: SimStatus) -> int: return _id_at(_completed_node_ids, index, status)
func roster_count() -> int: return _roster.size()
func roster_at(index: int, status: SimStatus) -> RunPieceInstance:
	if not status.is_ok(): return RunPieceInstance.new()
	if index < 0 or index >= _roster.size(): status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_VALIDATE, index, _roster.size()); return RunPieceInstance.new()
	return _roster[index].copy()
func roster_by_instance_id(instance_id: int, status: SimStatus) -> RunPieceInstance:
	if not status.is_ok(): return RunPieceInstance.new()
	for piece: RunPieceInstance in _roster:
		if piece.instance_id() == instance_id: return piece.copy()
		if piece.instance_id() > instance_id: break
	status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_VALIDATE, instance_id, 0); return RunPieceInstance.new()
func deployment_count() -> int: return _deployment_instance_ids.size()
func deployment_instance_id_at(index: int, status: SimStatus) -> int: return _id_at(_deployment_instance_ids, index, status)
func relic_count() -> int: return _relic_numeric_ids.size()
func relic_numeric_id_at(index: int, status: SimStatus) -> int: return _id_at(_relic_numeric_ids, index, status)
func consumable_stack_count() -> int: return _consumable_stacks.size()
func consumable_stack_at(index: int, status: SimStatus) -> RunConsumableStack:
	if not status.is_ok(): return RunConsumableStack.new()
	if index < 0 or index >= _consumable_stacks.size(): status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_STATE_VALIDATE, index, _consumable_stacks.size()); return RunConsumableStack.new()
	return _consumable_stacks[index].copy()
func pending_choice_copy() -> RunPendingChoice: return _pending_choice.copy()
func counter_value(instance_id: int, kind_id: int, status: SimStatus) -> int:
	if not RunCounterKind.is_valid(kind_id): status.fail(SimStatus.Code.INVALID_RUN_COUNTER, SimStatus.Operation.RUN_STATE_VALIDATE, kind_id, 0); return 0
	var piece: RunPieceInstance = roster_by_instance_id(instance_id, status)
	return 0 if not status.is_ok() else piece.counter_value(kind_id)
func _id_at(values: Array[int], index: int, status: SimStatus) -> int:
	if not status.is_ok(): return 0
	if index < 0 or index >= values.size(): status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, index, values.size()); return 0
	return values[index]
