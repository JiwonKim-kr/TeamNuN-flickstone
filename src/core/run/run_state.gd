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
var _next_battle_status_numeric_id: int = 0
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
	return restore_v2(catalog, content_fingerprint, seed_hi, seed_lo, phase_id, act_numeric_id, current_floor, current_node_id, life, max_life, gold, roster_capacity, deployment_capacity, next_piece_instance_id, next_transition_sequence, graph, visited_node_ids, completed_node_ids, roster, deployment_instance_ids, relic_numeric_ids, consumable_stacks, pending_choice, 0, status)

static func restore_v2(catalog: ContentCatalog, content_fingerprint: PackedByteArray, seed_hi: int, seed_lo: int, phase_id: int, act_numeric_id: int, current_floor: int, current_node_id: int, life: int, max_life: int, gold: int, roster_capacity: int, deployment_capacity: int, next_piece_instance_id: int, next_transition_sequence: int, graph: RunNodeGraph, visited_node_ids: Array[int], completed_node_ids: Array[int], roster: Array[RunPieceInstance], deployment_instance_ids: Array[int], relic_numeric_ids: Array[int], consumable_stacks: Array[RunConsumableStack], pending_choice: RunPendingChoice, next_battle_status_numeric_id: int, status: SimStatus) -> RunState:
	var result := RunState.new()
	if not status.is_ok(): return result
	if catalog == null or not catalog.is_initialized() or graph == null or not graph.is_initialized() or pending_choice == null or not pending_choice.is_initialized():
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_SNAPSHOT_RESTORE); return result
	result._content_fingerprint = content_fingerprint.duplicate(); result._seed_hi = seed_hi; result._seed_lo = seed_lo; result._phase_id = phase_id; result._act_numeric_id = act_numeric_id
	result._current_floor = current_floor; result._current_node_id = current_node_id; result._life = life; result._max_life = max_life; result._gold = gold
	result._roster_capacity = roster_capacity; result._deployment_capacity = deployment_capacity; result._next_piece_instance_id = next_piece_instance_id; result._next_transition_sequence = next_transition_sequence
	result._next_battle_status_numeric_id = next_battle_status_numeric_id
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
	if _next_piece_instance_id <= previous_instance or _next_piece_instance_id > 0xFFFFFFFF or _next_transition_sequence < 1 or _next_transition_sequence > 0xFFFFFFFF or _next_battle_status_numeric_id < 0 or _next_battle_status_numeric_id > 0xFFFFFFFF:
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
	if _deployment_instance_ids.size() > _deployment_capacity or _relic_numeric_ids.size() > RunLimits.MAX_RELICS or _consumable_stacks.size() > RunLimits.MAX_CONSUMABLE_STACKS:
		status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED, SimStatus.Operation.RUN_INVENTORY_VALIDATE, _relic_numeric_ids.size(), _consumable_stacks.size()); return false
	var previous_relic_id: int = 0
	for relic_id: int in _relic_numeric_ids:
		if relic_id <= previous_relic_id or relic_id > ContentLimits.UINT32_MAX:
			status.fail(SimStatus.Code.INVALID_RUN_INVENTORY, SimStatus.Operation.RUN_INVENTORY_VALIDATE, relic_id, previous_relic_id); return false
		previous_relic_id = relic_id
	var previous_consumable_id: int = 0
	for stack: RunConsumableStack in _consumable_stacks:
		if stack == null or not stack.is_initialized() or stack.consumable_numeric_id() <= previous_consumable_id:
			status.fail(SimStatus.Code.INVALID_RUN_INVENTORY, SimStatus.Operation.RUN_INVENTORY_VALIDATE, 0 if stack == null else stack.consumable_numeric_id(), previous_consumable_id); return false
		previous_consumable_id = stack.consumable_numeric_id()
	var current_node := RunNode.new()
	if _current_node_id != 0:
		current_node = _graph.node_by_id(_current_node_id, status)
		if not status.is_ok() or current_node.floor_index() != _current_floor: return false
		var visited_index: int = _visited_node_ids.bsearch(_current_node_id)
		if visited_index >= _visited_node_ids.size() or _visited_node_ids[visited_index] != _current_node_id:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _current_node_id, _current_floor); return false
	var is_battle_node: bool = _current_node_id != 0 and (current_node.node_type_id() == RunNodeType.Value.NORMAL_BATTLE or current_node.node_type_id() == RunNodeType.Value.ELITE_BATTLE or current_node.node_type_id() == RunNodeType.Value.BOSS)
	var is_rest_node: bool = _current_node_id != 0 and current_node.node_type_id() == RunNodeType.Value.REST
	var is_shop_node: bool = _current_node_id != 0 and current_node.node_type_id() == RunNodeType.Value.SHOP
	var is_event_node: bool = _current_node_id != 0 and current_node.node_type_id() == RunNodeType.Value.EVENT
	var completed_current: bool = false
	if _current_node_id != 0:
		var completed_index: int = _completed_node_ids.bsearch(_current_node_id)
		completed_current = completed_index < _completed_node_ids.size() and _completed_node_ids[completed_index] == _current_node_id
	if _phase_id == RunPhase.Value.MAP_CHOICE:
		if _current_floor != 0 or _current_node_id != 0 or not _deployment_instance_ids.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.NONE or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.FORMATION:
		if not is_battle_node or completed_current or _pending_choice.kind_id() != RunPendingKind.Value.NONE or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.BATTLE:
		if not is_battle_node or completed_current or _deployment_instance_ids.size() < ContentLimits.MAP_DEPLOY_MIN_COUNT or _pending_choice.kind_id() != RunPendingKind.Value.NONE or _next_battle_status_numeric_id != 0 or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _deployment_instance_ids.size()); return false
	elif _phase_id == RunPhase.Value.REWARD:
		var handoff: bool = _pending_choice.kind_id() == RunPendingKind.Value.NONE and _deployment_instance_ids.size() >= ContentLimits.MAP_DEPLOY_MIN_COUNT
		var prepared: bool = _pending_choice.kind_id() == RunPendingKind.Value.REWARD and _pending_choice.source_node_id() == _current_node_id and _deployment_instance_ids.is_empty()
		if not is_battle_node or (not handoff and not prepared) or _next_battle_status_numeric_id != 0 or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _life); return false
	elif _phase_id == RunPhase.Value.REST:
		if not is_rest_node or completed_current or not _deployment_instance_ids.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.REST or _pending_choice.source_node_id() != _current_node_id or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.SHOP:
		if not is_shop_node or completed_current or not _deployment_instance_ids.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.SHOP or _pending_choice.source_node_id() != _current_node_id or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.EVENT:
		if not is_event_node or completed_current or not _deployment_instance_ids.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.EVENT or _pending_choice.source_node_id() != _current_node_id or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_EVENT, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.ACT_COMPLETE:
		if not is_battle_node or current_node.node_type_id() != RunNodeType.Value.BOSS or not completed_current or not _deployment_instance_ids.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.NONE or _next_battle_status_numeric_id != 0 or _life == 0:
			status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_STATE_VALIDATE, _phase_id, _current_node_id); return false
	elif _phase_id == RunPhase.Value.RUN_FAILED:
		if not is_battle_node or completed_current or not _deployment_instance_ids.is_empty() or _pending_choice.kind_id() != RunPendingKind.Value.NONE or _next_battle_status_numeric_id != 0 or _life != 0:
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
	result._next_battle_status_numeric_id = _next_battle_status_numeric_id
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
	if not _validate_inventory(catalog, status): return false
	if _next_battle_status_numeric_id != 0:
		var boon_status := ContentStatus.new()
		var boon: StatusDefinition = catalog.status_by_numeric_id(_next_battle_status_numeric_id, boon_status)
		if not boon_status.is_ok() or boon.duration_kind_id() != StatusDefinition.DurationKind.BATTLE or boon.modifier_count() < 1:
			status.fail(SimStatus.Code.INVALID_RUN_BOON, SimStatus.Operation.RUN_STATE_VALIDATE, _next_battle_status_numeric_id, 0); return false
	if _current_node_id == 0: return _phase_id == RunPhase.Value.MAP_CHOICE
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	if not status.is_ok(): return false
	if node.node_type_id() == RunNodeType.Value.REST:
		if node.content_numeric_id() != 0 or _phase_id != RunPhase.Value.REST:
			status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), node.content_numeric_id()); return false
		return _validate_rest_pending(catalog, status)
	if node.node_type_id() == RunNodeType.Value.SHOP:
		if _phase_id != RunPhase.Value.SHOP: status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), _phase_id); return false
		return _validate_shop_pending(catalog, status)
	if node.node_type_id() == RunNodeType.Value.EVENT:
		if _phase_id != RunPhase.Value.EVENT: status.fail(SimStatus.Code.INVALID_RUN_EVENT, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), _phase_id); return false
		return _validate_event_pending(catalog, status)
	var content_status := ContentStatus.new()
	var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(node.content_numeric_id(), content_status)
	if not content_status.is_ok() or encounter.node_type_id() != node.node_type_id():
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), node.content_numeric_id()); return false
	var map_definition: MapDefinition = catalog.map_by_numeric_id(encounter.map_ref().numeric_id(), content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), encounter.map_ref().numeric_id()); return false
	var reward_profile: RewardProfileDefinition = catalog.reward_profile_by_numeric_id(encounter.reward_profile_numeric_id(), content_status)
	if not content_status.is_ok() or not reward_profile.is_initialized(): status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_STATE_VALIDATE, node.node_id(), encounter.reward_profile_numeric_id()); return false
	if _phase_id == RunPhase.Value.REWARD and _pending_choice.kind_id() == RunPendingKind.Value.REWARD and not _validate_reward_pending(reward_profile, status): return false
	if _phase_id == RunPhase.Value.FORMATION or _phase_id == RunPhase.Value.BATTLE or (_phase_id == RunPhase.Value.REWARD and _pending_choice.kind_id() == RunPendingKind.Value.NONE):
		var expected: int = mini(_deployment_capacity, mini(_roster.size(), map_definition.deploy_count()))
		if expected < ContentLimits.MAP_DEPLOY_MIN_COUNT or ((_phase_id == RunPhase.Value.BATTLE or _phase_id == RunPhase.Value.REWARD) and _deployment_instance_ids.size() != expected) or (_phase_id == RunPhase.Value.FORMATION and not _deployment_instance_ids.is_empty() and _deployment_instance_ids.size() != expected):
			status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.RUN_STATE_VALIDATE, _deployment_instance_ids.size(), expected); return false
	return true

func _profile_has_piece(profile: RewardProfileDefinition, piece_numeric_id: int, status: SimStatus) -> bool:
	var content_status := ContentStatus.new()
	for index: int in range(profile.recruit_pool_count()):
		if profile.recruit_pool_ref_at(index, content_status).numeric_id() == piece_numeric_id: return true
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_STATE_VALIDATE, profile.numeric_id(), piece_numeric_id)
	return false

func _validate_reward_pending(profile: RewardProfileDefinition, status: SimStatus) -> bool:
	if _pending_choice.source_node_id() != _current_node_id or _pending_choice.generation_ordinal() != _next_transition_sequence - 1:
		status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_STATE_VALIDATE, _pending_choice.source_node_id(), _pending_choice.generation_ordinal()); return false
	if _current_node_is_completed():
		if _roster.size() >= _roster_capacity or _pending_choice.entry_count() != profile.recruit_choice_count():
			status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_STATE_VALIDATE, _pending_choice.entry_count(), profile.recruit_choice_count()); return false
		var seen: Array[int] = []
		for index: int in range(_pending_choice.entry_count()):
			var entry: RunChoiceEntry = _pending_choice.entry_at(index, status)
			if entry.kind_id() != RunChoiceKind.Value.RECRUIT_PIECE or entry.secondary_numeric_id() != 0 or entry.amount() != 1 or entry.cost() != 0 or not entry.enabled() or seen.has(entry.primary_numeric_id()) or not _profile_has_piece(profile, entry.primary_numeric_id(), status):
				if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_STATE_VALIDATE, index, entry.primary_numeric_id())
				return false
			seen.append(entry.primary_numeric_id())
		return true
	if _pending_choice.entry_count() != 1:
		status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_STATE_VALIDATE, _pending_choice.entry_count(), 1); return false
	var revenge: RunChoiceEntry = _pending_choice.entry_at(0, status)
	var expected_id: int = profile.revenge_status_ref().numeric_id()
	if revenge.kind_id() != RunChoiceKind.Value.TAKE_REVENGE or revenge.primary_numeric_id() != expected_id or revenge.secondary_numeric_id() != 0 or revenge.amount() != 1 or revenge.cost() != 0 or not revenge.enabled():
		status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_STATE_VALIDATE, revenge.primary_numeric_id(), expected_id); return false
	return true

func _validate_rest_pending(catalog: ContentCatalog, status: SimStatus) -> bool:
	if _pending_choice.source_node_id() != _current_node_id or _pending_choice.generation_ordinal() != _next_transition_sequence or _pending_choice.entry_count() != 2:
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_STATE_VALIDATE, _pending_choice.source_node_id(), _pending_choice.entry_count()); return false
	var recover: RunChoiceEntry = _pending_choice.entry_at(0, status); var merge: RunChoiceEntry = _pending_choice.entry_at(1, status)
	if not status.is_ok(): return false
	if recover.kind_id() != RunChoiceKind.Value.RECOVER_LIFE or recover.primary_numeric_id() != 0 or recover.secondary_numeric_id() != 0 or recover.amount() != 1 or recover.cost() != 0 or recover.enabled() != (_life < _max_life):
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_STATE_VALIDATE, recover.kind_id(), 1); return false
	if merge.kind_id() != RunChoiceKind.Value.MERGE_PIECES or merge.primary_numeric_id() != 0 or merge.secondary_numeric_id() != 0 or merge.amount() != 1 or merge.cost() != 0 or merge.enabled() != _has_merge_pair(catalog):
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_STATE_VALIDATE, merge.kind_id(), 2); return false
	return recover.enabled() or merge.enabled()

func _validate_inventory(catalog: ContentCatalog, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	for relic_id: int in _relic_numeric_ids:
		var content_status := ContentStatus.new()
		var definition: RelicDefinition = catalog.relic_by_numeric_id(relic_id, content_status)
		if not content_status.is_ok() or not definition.is_initialized():
			status.fail(SimStatus.Code.INVALID_RUN_INVENTORY, SimStatus.Operation.RUN_INVENTORY_VALIDATE, relic_id, 0); return false
	for stack: RunConsumableStack in _consumable_stacks:
		var content_status := ContentStatus.new()
		var definition: ConsumableDefinition = catalog.consumable_by_numeric_id(stack.consumable_numeric_id(), content_status)
		if not content_status.is_ok() or not definition.is_initialized() or stack.count() > definition.max_stack():
			status.fail(SimStatus.Code.INVALID_RUN_INVENTORY, SimStatus.Operation.RUN_INVENTORY_VALIDATE, stack.consumable_numeric_id(), stack.count()); return false
	return true

func _can_add_relic(relic_numeric_id: int) -> bool:
	if _relic_numeric_ids.size() >= RunLimits.MAX_RELICS: return false
	var index: int = _relic_numeric_ids.bsearch(relic_numeric_id)
	return index >= _relic_numeric_ids.size() or _relic_numeric_ids[index] != relic_numeric_id

func _consumable_index(consumable_numeric_id: int) -> int:
	var low: int = 0; var high: int = _consumable_stacks.size() - 1
	while low <= high:
		var middle: int = (low + high) >> 1; var value: int = _consumable_stacks[middle].consumable_numeric_id()
		if value == consumable_numeric_id: return middle
		if value < consumable_numeric_id: low = middle + 1
		else: high = middle - 1
	return -low - 1

func _can_add_consumable(catalog: ContentCatalog, consumable_numeric_id: int, count: int) -> bool:
	if count < 1: return false
	var content_status := ContentStatus.new(); var definition: ConsumableDefinition = catalog.consumable_by_numeric_id(consumable_numeric_id, content_status)
	if not content_status.is_ok() or not definition.is_initialized(): return false
	var index: int = _consumable_index(consumable_numeric_id)
	if index >= 0: return count <= definition.max_stack() - _consumable_stacks[index].count()
	return _consumable_stacks.size() < RunLimits.MAX_CONSUMABLE_STACKS and count <= definition.max_stack()

func _can_apply_effect(catalog: ContentCatalog, effect: RunEffectDefinition) -> bool:
	if effect == null or not effect.is_initialized(): return false
	if effect.kind_id() == RunEffectKind.Value.GAIN_GOLD:
		return effect.amount() <= ContentLimits.UINT32_MAX - _gold
	if effect.kind_id() == RunEffectKind.Value.RECOVER_LIFE:
		return effect.amount() == 1 and _life < _max_life
	if effect.kind_id() == RunEffectKind.Value.GAIN_CONSUMABLE:
		return _can_add_consumable(catalog, effect.primary_numeric_id(), effect.amount())
	return false

func _shop_offer_enabled(catalog: ContentCatalog, offer: ShopOfferDefinition) -> bool:
	if offer.cost() > _gold: return false
	if offer.item_kind_id() == RunShopItemKind.Value.RELIC: return offer.count() == 1 and _can_add_relic(offer.item_ref().numeric_id())
	if offer.item_kind_id() == RunShopItemKind.Value.CONSUMABLE: return _can_add_consumable(catalog, offer.item_ref().numeric_id(), offer.count())
	return false

func _validate_shop_pending(catalog: ContentCatalog, status: SimStatus) -> bool:
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	var content_status := ContentStatus.new(); var profile: ShopDefinition = catalog.shop_by_numeric_id(node.content_numeric_id(), content_status)
	if not status.is_ok() or not content_status.is_ok() or not profile.is_initialized() or _pending_choice.generation_ordinal() != _next_transition_sequence or _pending_choice.entry_count() != profile.offer_count() + 1:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_STATE_VALIDATE, _current_node_id, node.content_numeric_id())
		return false
	for index: int in range(profile.offer_count()):
		var offer: ShopOfferDefinition = profile.offer_at(index, content_status); var entry: RunChoiceEntry = _pending_choice.entry_at(index, status)
		var expected_kind: int = RunChoiceKind.Value.TAKE_RELIC if offer.item_kind_id() == RunShopItemKind.Value.RELIC else RunChoiceKind.Value.TAKE_CONSUMABLE
		if not content_status.is_ok() or not status.is_ok() or entry.choice_id() != offer.offer_id() or entry.kind_id() != expected_kind or entry.primary_numeric_id() != offer.item_ref().numeric_id() or entry.secondary_numeric_id() != 0 or entry.amount() != offer.count() or entry.cost() != offer.cost() or entry.enabled() != _shop_offer_enabled(catalog, offer):
			if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_STATE_VALIDATE, index + 1, offer.offer_id())
			return false
	var leave: RunChoiceEntry = _pending_choice.entry_at(profile.offer_count(), status)
	if not status.is_ok() or leave.choice_id() != profile.offer_count() + 1 or leave.kind_id() != RunChoiceKind.Value.LEAVE_SHOP or leave.primary_numeric_id() != 0 or leave.secondary_numeric_id() != 0 or leave.amount() != 0 or leave.cost() != 0 or not leave.enabled():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_STATE_VALIDATE, leave.choice_id(), leave.kind_id())
		return false
	return true

func _validate_event_pending(catalog: ContentCatalog, status: SimStatus) -> bool:
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	var content_status := ContentStatus.new(); var profile: EventDefinition = catalog.event_by_numeric_id(node.content_numeric_id(), content_status)
	if not status.is_ok() or not content_status.is_ok() or not profile.is_initialized() or _pending_choice.generation_ordinal() != _next_transition_sequence or _pending_choice.entry_count() != profile.option_count():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_EVENT, SimStatus.Operation.RUN_STATE_VALIDATE, _current_node_id, node.content_numeric_id())
		return false
	for index: int in range(profile.option_count()):
		var option: EventOptionDefinition = profile.option_at(index, content_status); var entry: RunChoiceEntry = _pending_choice.entry_at(index, status)
		var kind_id: int = 0; var primary_id: int = 0; var amount: int = 0; var enabled: bool = true
		if option.has_effect():
			var effect: RunEffectDefinition = option.effect(); kind_id = effect.kind_id(); primary_id = effect.primary_numeric_id(); amount = effect.amount(); enabled = _can_apply_effect(catalog, effect)
		if not content_status.is_ok() or not status.is_ok() or entry.choice_id() != option.option_id() or entry.kind_id() != RunChoiceKind.Value.EVENT_OPTION or entry.primary_numeric_id() != kind_id or entry.secondary_numeric_id() != primary_id or entry.amount() != amount or entry.cost() != 0 or entry.enabled() != enabled:
			if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_EVENT, SimStatus.Operation.RUN_STATE_VALIDATE, index + 1, option.option_id())
			return false
	return true

func _assign_from(other: RunState) -> void:
	_content_fingerprint = other._content_fingerprint; _seed_hi = other._seed_hi; _seed_lo = other._seed_lo; _phase_id = other._phase_id; _act_numeric_id = other._act_numeric_id
	_current_floor = other._current_floor; _current_node_id = other._current_node_id; _life = other._life; _max_life = other._max_life; _gold = other._gold
	_roster_capacity = other._roster_capacity; _deployment_capacity = other._deployment_capacity; _next_piece_instance_id = other._next_piece_instance_id; _next_transition_sequence = other._next_transition_sequence
	_next_battle_status_numeric_id = other._next_battle_status_numeric_id
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
	var request: RunBattleRequest = RunBattleRequest.create(_content_fingerprint, _next_transition_sequence, _act_numeric_id, _current_node_id, node.node_type_id(), encounter.numeric_id(), map_definition.numeric_id(), battle_seed_hi, battle_seed_lo, _next_battle_status_numeric_id, players, enemies, status)
	if not status.is_ok(): return RunBattleRequest.new()
	var candidate: RunState = copy(status)
	candidate._phase_id = RunPhase.Value.BATTLE; candidate._next_transition_sequence += 1; candidate._next_battle_status_numeric_id = 0
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
	candidate._pending_choice = RunPendingChoice.none(status)
	if victory:
		candidate._append_sorted_id(candidate._completed_node_ids, candidate._current_node_id); candidate._phase_id = RunPhase.Value.REWARD
	elif candidate._life == 0:
		candidate._deployment_instance_ids.clear(); candidate._phase_id = RunPhase.Value.RUN_FAILED
	else: candidate._phase_id = RunPhase.Value.REWARD
	if not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func _current_node_is_completed() -> bool:
	var index: int = _completed_node_ids.bsearch(_current_node_id)
	return index < _completed_node_ids.size() and _completed_node_ids[index] == _current_node_id

func _finish_to_map_choice(complete_current: bool, status: SimStatus) -> void:
	if complete_current: _append_sorted_id(_completed_node_ids, _current_node_id)
	_phase_id = RunPhase.Value.MAP_CHOICE; _current_floor = 0; _current_node_id = 0
	_deployment_instance_ids.clear(); _pending_choice = RunPendingChoice.none(status)

func _finish_victory_reward(node: RunNode, status: SimStatus) -> void:
	_deployment_instance_ids.clear(); _pending_choice = RunPendingChoice.none(status)
	if node.node_type_id() == RunNodeType.Value.BOSS:
		_phase_id = RunPhase.Value.ACT_COMPLETE
	else:
		_phase_id = RunPhase.Value.MAP_CHOICE; _current_floor = 0; _current_node_id = 0

func _reward_profile(catalog: ContentCatalog, status: SimStatus) -> RewardProfileDefinition:
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	if not status.is_ok():
		return RewardProfileDefinition.new()
	var content_status := ContentStatus.new()
	var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(node.content_numeric_id(), content_status)
	var profile: RewardProfileDefinition = catalog.reward_profile_by_numeric_id(encounter.reward_profile_numeric_id(), content_status)
	if not status.is_ok() or not content_status.is_ok() or not profile.is_initialized():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_REWARD_PREPARE, _current_node_id, 0)
		return RewardProfileDefinition.new()
	return profile

func prepare_reward(catalog: ContentCatalog, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.REWARD or _pending_choice.kind_id() != RunPendingKind.Value.NONE or _deployment_instance_ids.size() < ContentLimits.MAP_DEPLOY_MIN_COUNT or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_REWARD_PREPARE, _phase_id, _pending_choice.kind_id())
		return false
	var profile: RewardProfileDefinition = _reward_profile(catalog, status)
	if not status.is_ok(): return false
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	var victory: bool = _current_node_is_completed()
	var generated := RunPendingChoice.new()
	if victory and _roster.size() < _roster_capacity:
		generated = RunRewardGenerator.generate_victory(self, catalog, profile, status)
		if not status.is_ok(): return false
	var candidate: RunState = copy(status)
	if not status.is_ok(): return false
	if victory:
		var victory_gold: int = profile.victory_gold()
		for relic_id: int in candidate._relic_numeric_ids:
			var content_status := ContentStatus.new(); var relic: RelicDefinition = catalog.relic_by_numeric_id(relic_id, content_status); var effect: RunEffectDefinition = relic.effect()
			if not content_status.is_ok() or not relic.is_initialized() or effect.kind_id() != RunEffectKind.Value.VICTORY_GOLD_BONUS or effect.amount() > ContentLimits.UINT32_MAX - victory_gold:
				status.fail(SimStatus.Code.INVALID_RUN_EFFECT, SimStatus.Operation.RUN_REWARD_PREPARE, relic_id, victory_gold); return false
			victory_gold += effect.amount()
		if candidate._gold > ContentLimits.UINT32_MAX - victory_gold:
			status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_REWARD_PREPARE, candidate._gold, victory_gold); return false
		candidate._gold += victory_gold; candidate._deployment_instance_ids.clear()
		if candidate._roster.size() < candidate._roster_capacity:
			candidate._pending_choice = generated
		else:
			candidate._finish_victory_reward(node, status)
	else:
		var revenge_ref: ContentIdRef = profile.revenge_status_ref()
		var entries: Array[RunChoiceEntry] = [RunChoiceEntry.create(1, RunChoiceKind.Value.TAKE_REVENGE, revenge_ref.numeric_id(), 0, 1, 0, true, status)]
		candidate._deployment_instance_ids.clear()
		candidate._pending_choice = RunPendingChoice.create(RunPendingKind.Value.REWARD, candidate._current_node_id, candidate._next_transition_sequence - 1, entries, status)
	if not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func choose_reward(catalog: ContentCatalog, choice_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.REWARD or _pending_choice.kind_id() != RunPendingKind.Value.REWARD or _pending_choice.source_node_id() != _current_node_id or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_REWARD_CHOOSE, _phase_id, choice_id)
		return false
	if choice_id <= 0 or choice_id > _pending_choice.entry_count():
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_REWARD_CHOOSE, choice_id, _pending_choice.entry_count()); return false
	var entry: RunChoiceEntry = _pending_choice.entry_at(choice_id - 1, status)
	if not status.is_ok() or not entry.enabled() or entry.choice_id() != choice_id: return false
	var profile: RewardProfileDefinition = _reward_profile(catalog, status)
	var node: RunNode = _graph.node_by_id(_current_node_id, status)
	if not status.is_ok(): return false
	var candidate: RunState = copy(status)
	if entry.kind_id() == RunChoiceKind.Value.RECRUIT_PIECE:
		if not _current_node_is_completed() or entry.secondary_numeric_id() != 0 or entry.amount() != 1 or entry.cost() != 0 or candidate._roster.size() >= candidate._roster_capacity or candidate._next_piece_instance_id >= ContentLimits.UINT32_MAX:
			status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_REWARD_CHOOSE, entry.primary_numeric_id(), candidate._roster.size()); return false
		var allowed: bool = false
		var content_status := ContentStatus.new()
		for index: int in range(profile.recruit_pool_count()):
			if profile.recruit_pool_ref_at(index, content_status).numeric_id() == entry.primary_numeric_id(): allowed = true; break
		var piece: PieceDefinition = catalog.piece_by_numeric_id(entry.primary_numeric_id(), content_status)
		if not content_status.is_ok() or not allowed or piece.is_token() or piece.level_count() < 1:
			status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_REWARD_CHOOSE, entry.primary_numeric_id(), profile.numeric_id()); return false
		var counters: Array[RunCounter] = []
		candidate._roster.append(RunPieceInstance.restore(candidate._next_piece_instance_id, entry.primary_numeric_id(), 1, counters, status))
		candidate._next_piece_instance_id += 1
		candidate._finish_victory_reward(node, status)
	elif entry.kind_id() == RunChoiceKind.Value.TAKE_REVENGE:
		var expected_status_id: int = profile.revenge_status_ref().numeric_id()
		if _current_node_is_completed() or entry.primary_numeric_id() != expected_status_id or entry.secondary_numeric_id() != 0 or entry.amount() != 1 or entry.cost() != 0 or candidate._next_battle_status_numeric_id != 0:
			status.fail(SimStatus.Code.INVALID_RUN_BOON, SimStatus.Operation.RUN_REWARD_CHOOSE, entry.primary_numeric_id(), expected_status_id); return false
		candidate._next_battle_status_numeric_id = expected_status_id; candidate._pending_choice = RunPendingChoice.none(status); candidate._deployment_instance_ids.clear()
		if node.node_type_id() == RunNodeType.Value.BOSS:
			candidate._phase_id = RunPhase.Value.FORMATION
		else:
			candidate._finish_to_map_choice(true, status)
	else:
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_REWARD_CHOOSE, choice_id, entry.kind_id()); return false
	if not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func _next_node_matches(node_id: int, expected_type: int, status: SimStatus) -> RunNode:
	var node: RunNode = _graph.node_by_id(node_id, status)
	if not status.is_ok() or _is_visited(node_id):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, node_id, 0)
		return RunNode.new()
	var expected_floor: int = 1
	if not _completed_node_ids.is_empty():
		var source_id: int = _completed_node_ids[-1]; var source: RunNode = _graph.node_by_id(source_id, status); expected_floor = source.floor_index() + 1
		var reachable: bool = false
		for index: int in range(source.next_node_count()):
			if source.next_node_id_at(index, status) == node_id: reachable = true; break
		if not reachable: status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, node_id, source_id); return RunNode.new()
	if node.floor_index() != expected_floor or node.node_type_id() != expected_type or node.content_numeric_id() <= 0:
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CHOOSE, node_id, expected_floor); return RunNode.new()
	return node

func choose_shop_node(catalog: ContentCatalog, node_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.MAP_CHOICE or catalog == null or not catalog.is_initialized() or _content_fingerprint != catalog.fingerprint_bytes() or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_SHOP_CHOOSE, _phase_id, node_id)
		return false
	var node: RunNode = _next_node_matches(node_id, RunNodeType.Value.SHOP, status)
	var content_status := ContentStatus.new(); var profile: ShopDefinition = catalog.shop_by_numeric_id(node.content_numeric_id(), content_status)
	if not status.is_ok() or not content_status.is_ok() or not profile.is_initialized():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_SHOP_CHOOSE, node_id, node.content_numeric_id())
		return false
	var candidate: RunState = copy(status)
	candidate._phase_id = RunPhase.Value.SHOP; candidate._current_floor = node.floor_index(); candidate._current_node_id = node_id; candidate._deployment_instance_ids.clear(); candidate._append_sorted_id(candidate._visited_node_ids, node_id)
	var entries: Array[RunChoiceEntry] = []
	for index: int in range(profile.offer_count()):
		var offer: ShopOfferDefinition = profile.offer_at(index, content_status)
		var kind_id: int = RunChoiceKind.Value.TAKE_RELIC if offer.item_kind_id() == RunShopItemKind.Value.RELIC else RunChoiceKind.Value.TAKE_CONSUMABLE
		entries.append(RunChoiceEntry.create(offer.offer_id(), kind_id, offer.item_ref().numeric_id(), 0, offer.count(), offer.cost(), candidate._shop_offer_enabled(catalog, offer), status))
	entries.append(RunChoiceEntry.create(profile.offer_count() + 1, RunChoiceKind.Value.LEAVE_SHOP, 0, 0, 0, 0, true, status))
	candidate._pending_choice = RunPendingChoice.create(RunPendingKind.Value.SHOP, node_id, candidate._next_transition_sequence, entries, status)
	if not content_status.is_ok() or not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func _add_relic(relic_numeric_id: int, status: SimStatus) -> bool:
	if not _can_add_relic(relic_numeric_id): status.fail(SimStatus.Code.INVALID_RUN_INVENTORY, SimStatus.Operation.RUN_EFFECT_APPLY, relic_numeric_id, _relic_numeric_ids.size()); return false
	_relic_numeric_ids.insert(_relic_numeric_ids.bsearch(relic_numeric_id), relic_numeric_id)
	return true

func _add_consumable(catalog: ContentCatalog, consumable_numeric_id: int, count: int, status: SimStatus) -> bool:
	if not _can_add_consumable(catalog, consumable_numeric_id, count): status.fail(SimStatus.Code.INVALID_RUN_INVENTORY, SimStatus.Operation.RUN_EFFECT_APPLY, consumable_numeric_id, count); return false
	var index: int = _consumable_index(consumable_numeric_id)
	if index >= 0:
		_consumable_stacks[index] = RunConsumableStack.create(consumable_numeric_id, _consumable_stacks[index].count() + count, status)
	else:
		_consumable_stacks.insert(-index - 1, RunConsumableStack.create(consumable_numeric_id, count, status))
	return status.is_ok()

func _apply_effect(catalog: ContentCatalog, effect: RunEffectDefinition, status: SimStatus) -> bool:
	if effect == null or not effect.is_initialized() or not _can_apply_effect(catalog, effect):
		status.fail(SimStatus.Code.INVALID_RUN_EFFECT, SimStatus.Operation.RUN_EFFECT_APPLY, 0 if effect == null else effect.kind_id(), 0 if effect == null else effect.primary_numeric_id()); return false
	if effect.kind_id() == RunEffectKind.Value.GAIN_GOLD: _gold += effect.amount()
	elif effect.kind_id() == RunEffectKind.Value.RECOVER_LIFE: _life += effect.amount()
	elif effect.kind_id() == RunEffectKind.Value.GAIN_CONSUMABLE: return _add_consumable(catalog, effect.primary_numeric_id(), effect.amount(), status)
	else: status.fail(SimStatus.Code.INVALID_RUN_EFFECT, SimStatus.Operation.RUN_EFFECT_APPLY, effect.kind_id(), effect.primary_numeric_id()); return false
	return true

func resolve_shop(catalog: ContentCatalog, choice_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.SHOP or _pending_choice.kind_id() != RunPendingKind.Value.SHOP or _pending_choice.source_node_id() != _current_node_id or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_SHOP_RESOLVE, _phase_id, choice_id)
		return false
	if choice_id <= 0 or choice_id > _pending_choice.entry_count(): status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_SHOP_RESOLVE, choice_id, _pending_choice.entry_count()); return false
	var entry: RunChoiceEntry = _pending_choice.entry_at(choice_id - 1, status)
	if not status.is_ok() or not entry.enabled():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_SHOP_RESOLVE, choice_id, 0)
		return false
	var candidate: RunState = copy(status)
	if entry.kind_id() == RunChoiceKind.Value.TAKE_RELIC:
		if entry.cost() > candidate._gold or not candidate._add_relic(entry.primary_numeric_id(), status): return false
		candidate._gold -= entry.cost()
	elif entry.kind_id() == RunChoiceKind.Value.TAKE_CONSUMABLE:
		if entry.cost() > candidate._gold or not candidate._add_consumable(catalog, entry.primary_numeric_id(), entry.amount(), status): return false
		candidate._gold -= entry.cost()
	elif entry.kind_id() != RunChoiceKind.Value.LEAVE_SHOP:
		status.fail(SimStatus.Code.INVALID_RUN_SHOP, SimStatus.Operation.RUN_SHOP_RESOLVE, choice_id, entry.kind_id()); return false
	candidate._finish_to_map_choice(true, status)
	if not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func choose_event_node(catalog: ContentCatalog, node_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.MAP_CHOICE or catalog == null or not catalog.is_initialized() or _content_fingerprint != catalog.fingerprint_bytes() or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_EVENT_CHOOSE, _phase_id, node_id)
		return false
	var node: RunNode = _next_node_matches(node_id, RunNodeType.Value.EVENT, status)
	var content_status := ContentStatus.new(); var profile: EventDefinition = catalog.event_by_numeric_id(node.content_numeric_id(), content_status)
	if not status.is_ok() or not content_status.is_ok() or not profile.is_initialized():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_EVENT, SimStatus.Operation.RUN_EVENT_CHOOSE, node_id, node.content_numeric_id())
		return false
	var candidate: RunState = copy(status)
	candidate._phase_id = RunPhase.Value.EVENT; candidate._current_floor = node.floor_index(); candidate._current_node_id = node_id; candidate._deployment_instance_ids.clear(); candidate._append_sorted_id(candidate._visited_node_ids, node_id)
	var entries: Array[RunChoiceEntry] = []
	for index: int in range(profile.option_count()):
		var option: EventOptionDefinition = profile.option_at(index, content_status); var kind_id: int = 0; var primary_id: int = 0; var amount: int = 0; var enabled: bool = true
		if option.has_effect():
			var effect: RunEffectDefinition = option.effect(); kind_id = effect.kind_id(); primary_id = effect.primary_numeric_id(); amount = effect.amount(); enabled = candidate._can_apply_effect(catalog, effect)
		entries.append(RunChoiceEntry.create(option.option_id(), RunChoiceKind.Value.EVENT_OPTION, kind_id, primary_id, amount, 0, enabled, status))
	candidate._pending_choice = RunPendingChoice.create(RunPendingKind.Value.EVENT, node_id, candidate._next_transition_sequence, entries, status)
	if not content_status.is_ok() or not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func resolve_event(catalog: ContentCatalog, choice_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.EVENT or _pending_choice.kind_id() != RunPendingKind.Value.EVENT or _pending_choice.source_node_id() != _current_node_id or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_EVENT, SimStatus.Operation.RUN_EVENT_RESOLVE, _phase_id, choice_id)
		return false
	if choice_id <= 0 or choice_id > _pending_choice.entry_count(): status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_EVENT_RESOLVE, choice_id, _pending_choice.entry_count()); return false
	var entry: RunChoiceEntry = _pending_choice.entry_at(choice_id - 1, status)
	if not status.is_ok() or not entry.enabled() or entry.kind_id() != RunChoiceKind.Value.EVENT_OPTION:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_EVENT, SimStatus.Operation.RUN_EVENT_RESOLVE, choice_id, entry.kind_id())
		return false
	var node: RunNode = _graph.node_by_id(_current_node_id, status); var content_status := ContentStatus.new(); var profile: EventDefinition = catalog.event_by_numeric_id(node.content_numeric_id(), content_status)
	var option: EventOptionDefinition = profile.option_at(choice_id - 1, content_status)
	var candidate: RunState = copy(status)
	if option.has_effect() and not candidate._apply_effect(catalog, option.effect(), status): return false
	candidate._finish_to_map_choice(true, status)
	if not content_status.is_ok() or not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func use_consumable(catalog: ContentCatalog, consumable_numeric_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.MAP_CHOICE or _current_node_id != 0 or _pending_choice.kind_id() != RunPendingKind.Value.NONE or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_CONSUMABLE_USE, _phase_id, consumable_numeric_id)
		return false
	var index: int = _consumable_index(consumable_numeric_id)
	var content_status := ContentStatus.new(); var definition: ConsumableDefinition = catalog.consumable_by_numeric_id(consumable_numeric_id, content_status)
	if index < 0 or not content_status.is_ok() or not definition.is_initialized() or definition.use_phase_id() != RunPhase.Value.MAP_CHOICE:
		status.fail(SimStatus.Code.INVALID_RUN_INVENTORY, SimStatus.Operation.RUN_CONSUMABLE_USE, consumable_numeric_id, 0 if index < 0 else _consumable_stacks[index].count()); return false
	var candidate: RunState = copy(status)
	if not candidate._apply_effect(catalog, definition.effect(), status): return false
	var remaining: int = candidate._consumable_stacks[index].count() - 1
	if remaining == 0: candidate._consumable_stacks.remove_at(index)
	else: candidate._consumable_stacks[index] = RunConsumableStack.create(consumable_numeric_id, remaining, status)
	if not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func _has_merge_pair(catalog: ContentCatalog) -> bool:
	if _roster.size() - 1 < ContentLimits.MAP_DEPLOY_MIN_COUNT: return false
	for left_index: int in range(_roster.size()):
		var left: RunPieceInstance = _roster[left_index]
		if left.level() >= 3: continue
		var content_status := ContentStatus.new(); var piece: PieceDefinition = catalog.piece_by_numeric_id(left.piece_numeric_id(), content_status)
		if not content_status.is_ok() or piece.level_count() <= left.level(): continue
		for right_index: int in range(left_index + 1, _roster.size()):
			var right: RunPieceInstance = _roster[right_index]
			if right.piece_numeric_id() == left.piece_numeric_id() and right.level() == left.level(): return true
	return false

func choose_rest_node(catalog: ContentCatalog, node_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.MAP_CHOICE or catalog == null or not catalog.is_initialized() or _content_fingerprint != catalog.fingerprint_bytes():
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_REST_CHOOSE, _phase_id, node_id); return false
	if not validate(catalog, status): return false
	var node: RunNode = _graph.node_by_id(node_id, status)
	if not status.is_ok() or _is_visited(node_id):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_REST_CHOOSE, node_id, 0)
		return false
	var expected_floor: int = 1
	if not _completed_node_ids.is_empty():
		var source_id: int = _completed_node_ids[-1]; var source: RunNode = _graph.node_by_id(source_id, status); expected_floor = source.floor_index() + 1
		var reachable: bool = false
		for index: int in range(source.next_node_count()):
			if source.next_node_id_at(index, status) == node_id: reachable = true; break
		if not reachable: status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_REST_CHOOSE, node_id, source_id); return false
	if node.floor_index() != expected_floor or node.node_type_id() != RunNodeType.Value.REST or node.content_numeric_id() != 0:
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_REST_CHOOSE, node_id, expected_floor); return false
	var candidate: RunState = copy(status)
	if not status.is_ok(): return false
	candidate._phase_id = RunPhase.Value.REST; candidate._current_floor = node.floor_index(); candidate._current_node_id = node_id; candidate._deployment_instance_ids.clear(); candidate._append_sorted_id(candidate._visited_node_ids, node_id)
	var recover_enabled: bool = candidate._life < candidate._max_life
	var merge_enabled: bool = candidate._has_merge_pair(catalog)
	if not recover_enabled and not merge_enabled:
		candidate._finish_to_map_choice(true, status)
	else:
		var entries: Array[RunChoiceEntry] = [
			RunChoiceEntry.create(1, RunChoiceKind.Value.RECOVER_LIFE, 0, 0, 1, 0, recover_enabled, status),
			RunChoiceEntry.create(2, RunChoiceKind.Value.MERGE_PIECES, 0, 0, 1, 0, merge_enabled, status),
		]
		candidate._pending_choice = RunPendingChoice.create(RunPendingKind.Value.REST, node_id, candidate._next_transition_sequence, entries, status)
	if not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
	_assign_from(candidate); return true

func _merge_pair(catalog: ContentCatalog, first_instance_id: int, second_instance_id: int, status: SimStatus) -> bool:
	if first_instance_id <= 0 or second_instance_id <= 0 or first_instance_id == second_instance_id or _roster.size() - 1 < ContentLimits.MAP_DEPLOY_MIN_COUNT:
		status.fail(SimStatus.Code.INVALID_RUN_MERGE, SimStatus.Operation.RUN_PIECE_MERGE, first_instance_id, second_instance_id); return false
	var low_id: int = mini(first_instance_id, second_instance_id); var high_id: int = maxi(first_instance_id, second_instance_id)
	var low_index: int = -1; var high_index: int = -1
	for index: int in range(_roster.size()):
		if _roster[index].instance_id() == low_id: low_index = index
		elif _roster[index].instance_id() == high_id: high_index = index
	if low_index < 0 or high_index < 0:
		status.fail(SimStatus.Code.INVALID_RUN_MERGE, SimStatus.Operation.RUN_PIECE_MERGE, low_id, high_id); return false
	var low: RunPieceInstance = _roster[low_index]; var high: RunPieceInstance = _roster[high_index]
	if low.piece_numeric_id() != high.piece_numeric_id() or low.level() != high.level() or low.level() < 1 or low.level() >= 3:
		status.fail(SimStatus.Code.INVALID_RUN_MERGE, SimStatus.Operation.RUN_PIECE_MERGE, low.piece_numeric_id(), high.piece_numeric_id()); return false
	var content_status := ContentStatus.new(); var piece: PieceDefinition = catalog.piece_by_numeric_id(low.piece_numeric_id(), content_status)
	if not content_status.is_ok() or piece.level_count() <= low.level():
		status.fail(SimStatus.Code.INVALID_RUN_MERGE, SimStatus.Operation.RUN_PIECE_MERGE, low.piece_numeric_id(), low.level() + 1); return false
	var counters: Array[RunCounter] = []
	for kind_id: int in range(RunCounterKind.Value.BATTLES_SURVIVED, RunCounterKind.Value.KILLS + 1):
		var value: int = maxi(low.counter_value(kind_id), high.counter_value(kind_id))
		if value > 0: counters.append(RunCounter.create(kind_id, value, status))
	_roster[low_index] = RunPieceInstance.restore(low_id, low.piece_numeric_id(), low.level() + 1, counters, status)
	_roster.remove_at(high_index)
	return status.is_ok()

func resolve_rest(catalog: ContentCatalog, choice_id: int, first_instance_id: int, second_instance_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase_id != RunPhase.Value.REST or _pending_choice.kind_id() != RunPendingKind.Value.REST or _pending_choice.source_node_id() != _current_node_id or not validate(catalog, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.RUN_REST_RESOLVE, _phase_id, choice_id)
		return false
	if choice_id <= 0 or choice_id > _pending_choice.entry_count(): status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_REST_RESOLVE, choice_id, _pending_choice.entry_count()); return false
	var entry: RunChoiceEntry = _pending_choice.entry_at(choice_id - 1, status)
	if not status.is_ok() or not entry.enabled() or entry.choice_id() != choice_id or entry.primary_numeric_id() != 0 or entry.secondary_numeric_id() != 0 or entry.amount() != 1 or entry.cost() != 0:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_REST_RESOLVE, choice_id, entry.kind_id())
		return false
	var candidate: RunState = copy(status)
	if entry.kind_id() == RunChoiceKind.Value.RECOVER_LIFE:
		if first_instance_id != 0 or second_instance_id != 0 or candidate._life >= candidate._max_life:
			status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_REST_RESOLVE, first_instance_id, second_instance_id); return false
		candidate._life += 1
	elif entry.kind_id() == RunChoiceKind.Value.MERGE_PIECES:
		if not candidate._merge_pair(catalog, first_instance_id, second_instance_id, status): return false
	else:
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_REST_RESOLVE, choice_id, entry.kind_id()); return false
	candidate._finish_to_map_choice(true, status)
	if not status.is_ok() or not candidate._validate_structure(status) or not candidate._validate_catalog_phase(catalog, status): return false
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
func next_battle_status_numeric_id() -> int: return _next_battle_status_numeric_id
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
