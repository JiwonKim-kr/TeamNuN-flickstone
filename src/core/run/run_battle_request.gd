class_name RunBattleRequest
extends RefCounted

var _content_fingerprint: PackedByteArray = PackedByteArray()
var _request_sequence: int = 0
var _act_numeric_id: int = 0
var _node_id: int = 0
var _node_type_id: int = RunNodeType.Value.INVALID
var _encounter_numeric_id: int = 0
var _map_numeric_id: int = 0
var _battle_seed_hi: int = 0
var _battle_seed_lo: int = 0
var _players: Array[RunBattlePlayerEntry] = []
var _enemies: Array[RunBattleEnemyEntry] = []
var _initialized: bool = false

static func create(fingerprint: PackedByteArray, request_sequence: int, act_numeric_id: int, node_id: int, node_type_id: int, encounter_numeric_id: int, map_numeric_id: int, seed_hi: int, seed_lo: int, players: Array[RunBattlePlayerEntry], enemies: Array[RunBattleEnemyEntry], status: SimStatus) -> RunBattleRequest:
	var result := RunBattleRequest.new()
	if not status.is_ok(): return result
	if fingerprint.size() != 32 or request_sequence <= 0 or request_sequence > 0xFFFFFFFF or act_numeric_id <= 0 or act_numeric_id > 0xFFFFFFFF or node_id <= 0 or node_id > 0xFFFFFFFF or (node_type_id != RunNodeType.Value.NORMAL_BATTLE and node_type_id != RunNodeType.Value.ELITE_BATTLE and node_type_id != RunNodeType.Value.BOSS) or encounter_numeric_id <= 0 or encounter_numeric_id > 0xFFFFFFFF or map_numeric_id <= 0 or map_numeric_id > 0xFFFFFFFF or not UInt32Math.is_u32(seed_hi) or not UInt32Math.is_u32(seed_lo) or players.size() < 3 or players.size() > ContentLimits.MAP_DEPLOY_MAX_COUNT or enemies.size() < ContentLimits.MAP_DEPLOY_MIN_COUNT or enemies.size() > ContentLimits.MAP_DEPLOY_MAX_COUNT:
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_REQUEST_CREATE, request_sequence, node_id); return result
	var instance_ids: Array[int] = []
	for index: int in range(players.size()):
		var entry: RunBattlePlayerEntry = players[index]
		if entry == null or not entry.is_initialized() or entry.slot_index() != index or entry.expected_body_id() != index + 1 or instance_ids.has(entry.run_instance_id()):
			status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_REQUEST_CREATE, index, 0 if entry == null else entry.run_instance_id()); return RunBattleRequest.new()
		instance_ids.append(entry.run_instance_id()); result._players.append(entry.copy())
	for index: int in range(enemies.size()):
		var entry: RunBattleEnemyEntry = enemies[index]
		if entry == null or not entry.is_initialized() or entry.slot_index() != index or entry.expected_body_id() != players.size() + index + 1:
			status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_REQUEST_CREATE, index, 0 if entry == null else entry.expected_body_id()); return RunBattleRequest.new()
		result._enemies.append(entry.copy())
	result._content_fingerprint = fingerprint.duplicate(); result._request_sequence = request_sequence; result._act_numeric_id = act_numeric_id
	result._node_id = node_id; result._node_type_id = node_type_id; result._encounter_numeric_id = encounter_numeric_id; result._map_numeric_id = map_numeric_id
	result._battle_seed_hi = seed_hi; result._battle_seed_lo = seed_lo; result._initialized = true
	return result

func copy() -> RunBattleRequest:
	var status := SimStatus.new()
	return create(_content_fingerprint, _request_sequence, _act_numeric_id, _node_id, _node_type_id, _encounter_numeric_id, _map_numeric_id, _battle_seed_hi, _battle_seed_lo, _players, _enemies, status) if _initialized else RunBattleRequest.new()
func is_initialized() -> bool: return _initialized
func content_fingerprint_bytes() -> PackedByteArray: return _content_fingerprint.duplicate()
func request_sequence() -> int: return _request_sequence
func act_numeric_id() -> int: return _act_numeric_id
func node_id() -> int: return _node_id
func node_type_id() -> int: return _node_type_id
func encounter_numeric_id() -> int: return _encounter_numeric_id
func map_numeric_id() -> int: return _map_numeric_id
func battle_seed_hi() -> int: return _battle_seed_hi
func battle_seed_lo() -> int: return _battle_seed_lo
func player_count() -> int: return _players.size()
func player_at(index: int, status: SimStatus) -> RunBattlePlayerEntry:
	if not status.is_ok(): return RunBattlePlayerEntry.new()
	if index < 0 or index >= _players.size(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_REQUEST_CREATE, index, _players.size()); return RunBattlePlayerEntry.new()
	return _players[index].copy()
func enemy_count() -> int: return _enemies.size()
func enemy_at(index: int, status: SimStatus) -> RunBattleEnemyEntry:
	if not status.is_ok(): return RunBattleEnemyEntry.new()
	if index < 0 or index >= _enemies.size(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_REQUEST_CREATE, index, _enemies.size()); return RunBattleEnemyEntry.new()
	return _enemies[index].copy()
