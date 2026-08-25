class_name RunBattleOutcome
extends RefCounted

var _content_fingerprint: PackedByteArray = PackedByteArray()
var _request_sequence: int = 0
var _act_numeric_id: int = 0
var _node_id: int = 0
var _node_type_id: int = RunNodeType.Value.INVALID
var _battle_result: int = BattleResult.Value.ONGOING
var _player_facts: Array[RunBattlePlayerFact] = []
var _initialized: bool = false

static func create(fingerprint: PackedByteArray, request_sequence: int, act_numeric_id: int, node_id: int, node_type_id: int, battle_result: int, facts: Array[RunBattlePlayerFact], status: SimStatus) -> RunBattleOutcome:
	var result := RunBattleOutcome.new()
	if not status.is_ok(): return result
	if fingerprint.size() != 32 or request_sequence <= 0 or request_sequence > 0xFFFFFFFF or act_numeric_id <= 0 or act_numeric_id > 0xFFFFFFFF or node_id <= 0 or node_id > 0xFFFFFFFF or (node_type_id != RunNodeType.Value.NORMAL_BATTLE and node_type_id != RunNodeType.Value.ELITE_BATTLE and node_type_id != RunNodeType.Value.BOSS) or not BattleResult.is_terminal(battle_result) or facts.size() < 3 or facts.size() > ContentLimits.MAP_DEPLOY_MAX_COUNT:
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_CREATE, request_sequence, battle_result); return result
	var instance_ids: Array[int] = []
	for index: int in range(facts.size()):
		var fact: RunBattlePlayerFact = facts[index]
		if fact == null or not fact.is_initialized() or fact.slot_index() != index or fact.expected_body_id() != index + 1 or instance_ids.has(fact.run_instance_id()):
			status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_CREATE, index, 0 if fact == null else fact.run_instance_id()); return RunBattleOutcome.new()
		instance_ids.append(fact.run_instance_id()); result._player_facts.append(fact.copy())
	result._content_fingerprint = fingerprint.duplicate(); result._request_sequence = request_sequence; result._act_numeric_id = act_numeric_id
	result._node_id = node_id; result._node_type_id = node_type_id; result._battle_result = battle_result; result._initialized = true
	return result

func copy() -> RunBattleOutcome:
	var status := SimStatus.new()
	return create(_content_fingerprint, _request_sequence, _act_numeric_id, _node_id, _node_type_id, _battle_result, _player_facts, status) if _initialized else RunBattleOutcome.new()
func is_initialized() -> bool: return _initialized
func content_fingerprint_bytes() -> PackedByteArray: return _content_fingerprint.duplicate()
func request_sequence() -> int: return _request_sequence
func act_numeric_id() -> int: return _act_numeric_id
func node_id() -> int: return _node_id
func node_type_id() -> int: return _node_type_id
func battle_result() -> int: return _battle_result
func player_fact_count() -> int: return _player_facts.size()
func player_fact_at(index: int, status: SimStatus) -> RunBattlePlayerFact:
	if not status.is_ok(): return RunBattlePlayerFact.new()
	if index < 0 or index >= _player_facts.size(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_CREATE, index, _player_facts.size()); return RunBattlePlayerFact.new()
	return _player_facts[index].copy()
