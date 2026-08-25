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
	if result._phase_id == RunPhase.Value.BATTLE:
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_SNAPSHOT_RESTORE, result._phase_id, 0); return RunState.new()
	if not result._validate_catalog_phase(catalog, status): return RunState.new()
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
	if _content_fingerprint.size() != 32 or _seed_hi < 0 or _seed_hi > 0xFFFFFFFF or _seed_lo < 0 or _seed_lo > 0xFFFFFFFF or not RunPhase.is_valid(_phase_id) or _act_numeric_id <= 0 or _act_numeric_id > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _act_numeric_id); return false
	if _current_floor < 0 or _current_floor > RunLimits.MAX_FLOORS or _current_node_id < 0 or _current_node_id > 0xFFFFFFFF or _life < 0 or _life > _max_life or _max_life < 1 or _max_life > RunLimits.MAX_LIFE or _gold < 0 or _gold > 0xFFFFFFFF:
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
	if _next_piece_instance_id <= previous_instance or _next_piece_instance_id > 0xFFFFFFFF or _next_transition_sequence < 1 or _next_transition_sequence > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _next_piece_instance_id, _next_transition_sequence); return false
	var deployment_seen: Array[int] = []
	for instance_id: int in _deployment_instance_ids:
		if instance_id <= 0 or deployment_seen.has(instance_id): status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, instance_id, 0); return false
		var found: bool = false
		for piece: RunPieceInstance in _roster:
			if piece.instance_id() == instance_id: found = true; break
			if piece.instance_id() > instance_id: break
		if not found: status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_STATE_VALIDATE, instance_id, 0); return false
		deployment_seen.append(instance_id)
	if _deployment_instance_ids.size() > _deployment_capacity or not _relic_numeric_ids.is_empty() or not _consumable_stacks.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.NONE:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _pending_choice.kind_id(), 1); return false
	var current_node := RunNode.new()
	if _current_node_id != 0:
		current_node = _graph.node_by_id(_current_node_id, status)
		if not status.is_ok() or current_node.floor_index() != _current_floor: return false
		var visited_index: int = _visited_node_ids.bsearch(_current_node_id)
		if visited_index >= _visited_node_ids.size() or _visited_node_ids[visited_index] != _current_node_id:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _current_node_id, _current_floor); return false
	var is_battle_node: bool = _current_node_id != 0 and (current_node.node_type_id() == RunNodeType.Value.NORMAL_BATTLE or current_node.node_type_id() == RunNodeType.Value.ELITE_BATTLE or current_node.node_type_id() == RunNodeType.Value.BOSS)
	var completed_current: bool = false
	if _current_node_id != 0:
		var completed_index: int = _completed_node_ids.bsearch(_current_node_id)
		completed_current = completed_index < _completed_node_ids.size() and _completed_node_ids[completed_index] == _current_node_id
	if _phase_id == RunPhase.Value.MAP_CHOICE:
		if _current_floor != 0 or _current_node_id != 0 or not _deployment_instance_ids.is_empty() or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.FORMATION:
		if not is_battle_node or completed_current or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.BATTLE:
		if not is_battle_node or completed_current or _deployment_instance_ids.size() < ContentLimits.MAP_DEPLOY_MIN_COUNT or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _deployment_instance_ids.size()); return false
	elif _phase_id == RunPhase.Value.REWARD:
		if not is_battle_node or not _deployment_instance_ids.is_empty() or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _life); return false
	elif _phase_id == RunPhase.Value.RUN_FAILED:
		if not is_battle_node or completed_current or not _deployment_instance_ids.is_empty() or _life != 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _life); return false
	else:
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, 0); return false
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
	return _validate_catalog_phase(catalog, status)

func _validate_catalog_phase(catalog: ContentCatalog, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if _current_node_id == 0: return _phase_id == RunPhase.Value.MAP_CHOICE
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	if not status.is_ok(): return false
	var content_status := ContentStatus.new()
	var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(node.content_numeric_id(), content_status)
	if not content_status.is_ok() or encounter.node_type_id() != node.node_type_id():
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), node.content_numeric_id()); return false
	var map_definition: MapDefinition = catalog.map_by_numeric_id(encounter.map_ref().numeric_id(), content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), encounter.map_ref().numeric_id()); return false
	if _phase_id == RunPhase.Value.FORMATION or _phase_id == RunPhase.Value.BATTLE:
		var expected: int = mini(_deployment_capacity, mini(_roster.size(), map_definition.deploy_count()))
		if expected < ContentLimits.MAP_DEPLOY_MIN_COUNT or (_phase_id == RunPhase.Value.BATTLE and _deployment_instance_ids.size() != expected) or (_phase_id == RunPhase.Value.FORMATION and not _deployment_instance_ids.is_empty() and _deployment_instance_ids.size() != expected):
			status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.RUN_STATE_VALIDATE, _deployment_instance_ids.size(), expected); return false
	return true

func _assign_from(other: RunState) -> void:
	_content_fingerprint = other._content_fingerprint; _seed_hi = other._seed_hi; _seed_lo = other._seed_lo; _phase_id = other._phase_id; _act_numeric_id = other._act_numeric_id
	_current_floor = other._current_floor; _current_node_id = other._current_node_id; _life = other._life; _max_life = other._max_life; _gold = other._gold
	_roster_capacity = other._roster_capacity; _deployment_capacity = other._deployment_capacity; _next_piece_instance_id = other._next_piece_instance_id; _next_transition_sequence = other._next_transition_sequence
	_graph = other._graph; _visited_node_ids = other._visited_node_ids; _completed_node_ids = other._completed_node_ids; _roster = other._roster
	_deployment_instance_ids = other._deployment_instance_ids; _relic_numeric_ids = other._relic_numeric_ids; _consumable_stacks = other._consumable_stacks; _pending_choice = other._pending_choice; _initialized = other._initialized

func _is_visited(node_id: int) -> bool:
	var index: int = _visited_node_ids.bsearch(node_id)
	return index < _visited_node_ids.size() and _visited_node_ids[index] == node_id

func _append_sorted_id(values: Array[int], value: int) -> void:
	var index: int = values.bsearch(value)
	if index >= values.size() or values[index] != value: values.insert(index, value)

func choose_battle_node(catalog: ContentCatalog, node_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.MAP_CHOICE or catalog == null or not catalog.is_initialized() or _content_fingerprint != catalog.fingerprint_bytes():
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_NODE_CHOOSE, _phase_id, node_id); return false
	var node: RunNode = _graph.node_by_id(node_id, status)
	if not status.is_ok() or _is_visited(node_id):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, node_id, 0)
		return false
	var expected_floor: int = 1; var source_node_id: int = 0
	if not _completed_node_ids.is_empty():
		source_node_id = _completed_node_ids[_completed_node_ids.size() - 1]
		var source: RunNode = _graph.node_by_id(source_node_id, status)
		expected_floor = source.floor_index() + 1
		var reachable: bool = false
		for index: int in range(source.next_node_count()):
			if source.next_node_id_at(index, status) == node_id: reachable = true; break
		if not reachable:
			status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, node_id, source_node_id); return false
	if node.floor_index() != expected_floor or (node.node_type_id() != RunNodeType.Value.NORMAL_BATTLE and node.node_type_id() != RunNodeType.Value.ELITE_BATTLE and node.node_type_id() != RunNodeType.Value.BOSS):
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, node_id, expected_floor); return false
	var candidate: RunState = copy(status)
	if not status.is_ok(): return false
	candidate._phase_id = RunPhase.Value.FORMATION; candidate._current_floor = node.floor_index(); candidate._current_node_id = node_id; candidate._deployment_instance_ids.clear(); candidate._append_sorted_id(candidate._visited_node_ids, node_id)
	if not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func set_deployment(catalog: ContentCatalog, instance_ids: Array[int], status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.FORMATION or catalog == null or not catalog.is_initialized(): status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_DEPLOYMENT_SET, _phase_id, instance_ids.size()); return false
	var node: RunNode = _graph.node_by_id(_current_node_id, status); var content_status := ContentStatus.new()
	var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(node.content_numeric_id(), content_status)
	var map_definition: MapDefinition = catalog.map_by_numeric_id(encounter.map_ref().numeric_id(), content_status)
	var expected: int = mini(_deployment_capacity, mini(_roster.size(), map_definition.deploy_count()))
	if not content_status.is_ok() or expected < ContentLimits.MAP_DEPLOY_MIN_COUNT or instance_ids.size() != expected:
		status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.RUN_DEPLOYMENT_SET, instance_ids.size(), expected); return false
	var seen: Array[int] = []
	for index: int in range(instance_ids.size()):
		var instance_id: int = instance_ids[index]
		if seen.has(instance_id): status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.RUN_DEPLOYMENT_SET, instance_id, index); return false
		var lookup := SimStatus.new(); roster_by_instance_id(instance_id, lookup)
		if not lookup.is_ok(): status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.RUN_DEPLOYMENT_SET, instance_id, index); return false
		seen.append(instance_id)
	var candidate: RunState = copy(status)
	if not status.is_ok(): return false
	candidate._deployment_instance_ids = instance_ids.duplicate()
	if not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func begin_battle(catalog: ContentCatalog, status: SimStatus) -> RunBattleRequest:
	if not status.is_ok(): return RunBattleRequest.new()
	if not _initialized or _phase_id != RunPhase.Value.FORMATION or _next_transition_sequence >= 0xFFFFFFFF or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_BATTLE_BEGIN, _phase_id, _next_transition_sequence)
		return RunBattleRequest.new()
	var node: RunNode = _graph.node_by_id(_current_node_id, status); var content_status := ContentStatus.new()
	var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(node.content_numeric_id(), content_status)
	var map_definition: MapDefinition = catalog.map_by_numeric_id(encounter.map_ref().numeric_id(), content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BEGIN, node.content_numeric_id(), 0); return RunBattleRequest.new()
	var rng: SimRng = SimRng.derive(_seed_hi, _seed_lo, RunRandomPurpose.RUN_BATTLE_SEED, _act_numeric_id, _current_node_id, status)
	var battle_seed_hi: int = rng.next_u32(status); var battle_seed_lo: int = rng.next_u32(status)
	var players: Array[RunBattlePlayerEntry] = []
	for index: int in range(_deployment_instance_ids.size()):
		var piece: RunPieceInstance = roster_by_instance_id(_deployment_instance_ids[index], status)
		players.append(RunBattlePlayerEntry.create(index, index + 1, piece.instance_id(), piece.piece_numeric_id(), piece.level(), status))
	var enemies: Array[RunBattleEnemyEntry] = []
	for index: int in range(encounter.enemy_ref_count()):
		var enemy_ref: ContentIdRef = encounter.enemy_ref_at(index, content_status)
		enemies.append(RunBattleEnemyEntry.create(index, players.size() + index + 1, enemy_ref.numeric_id(), status))
	if not status.is_ok() or not content_status.is_ok(): return RunBattleRequest.new()
	var request: RunBattleRequest = RunBattleRequest.create(_content_fingerprint, _next_transition_sequence, _act_numeric_id, _current_node_id, node.node_type_id(), encounter.numeric_id(), map_definition.numeric_id(), battle_seed_hi, battle_seed_lo, players, enemies, status)
	if not status.is_ok(): return RunBattleRequest.new()
	var candidate: RunState = copy(status)
	candidate._phase_id = RunPhase.Value.BATTLE; candidate._next_transition_sequence += 1
	if not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return RunBattleRequest.new()
	_assign_from(candidate); return request

func _piece_with_battle_fact(piece: RunPieceInstance, fact: RunBattlePlayerFact, status: SimStatus) -> RunPieceInstance:
	var survived_value: int = mini(5, piece.counter_value(RunCounterKind.Value.BATTLES_SURVIVED) + 1) if fact.survived() else 0
	var previous_kills: int = piece.counter_value(RunCounterKind.Value.KILLS)
	if fact.kills() > 0 and previous_kills > 9223372036854775807 - fact.kills():
		status.fail(SimStatus.Code.COUNTER_EXHAUSTED, SimStatus.Operation.RUN_BATTLE_OUTCOME_APPLY, piece.instance_id(), fact.kills()); return RunPieceInstance.new()
	var kill_value: int = previous_kills + fact.kills()
	var counters: Array[RunCounter] = []
	if survived_value > 0: counters.append(RunCounter.create(RunCounterKind.Value.BATTLES_SURVIVED, survived_value, status))
	if kill_value > 0: counters.append(RunCounter.create(RunCounterKind.Value.KILLS, kill_value, status))
	return RunPieceInstance.restore(piece.instance_id(), piece.piece_numeric_id(), piece.level(), counters, status)

func apply_battle_outcome(catalog: ContentCatalog, outcome: RunBattleOutcome, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.BATTLE or outcome == null or not outcome.is_initialized() or catalog == null or not catalog.is_initialized():
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_BATTLE_OUTCOME_APPLY, _phase_id, 0 if outcome == null else outcome.request_sequence()); return false
	if outcome.request_sequence() != _next_transition_sequence - 1 or outcome.content_fingerprint_bytes() != _content_fingerprint or outcome.act_numeric_id() != _act_numeric_id or outcome.node_id() != _current_node_id:
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_APPLY, outcome.request_sequence(), _current_node_id); return false
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	if outcome.node_type_id() != node.node_type_id() or outcome.player_fact_count() != _deployment_instance_ids.size(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_APPLY, outcome.player_fact_count(), _deployment_instance_ids.size()); return false
	var candidate: RunState = copy(status)
	for index: int in range(outcome.player_fact_count()):
		var fact: RunBattlePlayerFact = outcome.player_fact_at(index, status)
		if fact.run_instance_id() != _deployment_instance_ids[index] or fact.slot_index() != index or fact.expected_body_id() != index + 1:
			status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_APPLY, fact.run_instance_id(), _deployment_instance_ids[index]); return false
		for roster_index: int in range(candidate._roster.size()):
			if candidate._roster[roster_index].instance_id() == fact.run_instance_id():
				candidate._roster[roster_index] = candidate._piece_with_battle_fact(candidate._roster[roster_index], fact, status); break
	if not status.is_ok(): return false
	var victory: bool = outcome.battle_result() == BattleResult.Value.PLAYER_VICTORY
	if not victory:
		var loss: int = 2 if node.node_type_id() == RunNodeType.Value.ELITE_BATTLE else 1
		candidate._life = maxi(0, candidate._life - loss)
	candidate._deployment_instance_ids.clear(); candidate._pending_choice = RunPendingChoice.none(status)
	if victory:
		candidate._append_sorted_id(candidate._completed_node_ids, candidate._current_node_id); candidate._phase_id = RunPhase.Value.REWARD
	elif candidate._life == 0: candidate._phase_id = RunPhase.Value.RUN_FAILED
	else: candidate._phase_id = RunPhase.Value.REWARD
	if not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

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
