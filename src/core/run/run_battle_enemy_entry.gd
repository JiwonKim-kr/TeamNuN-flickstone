class_name RunBattleEnemyEntry
extends RefCounted

var _slot_index: int = 0
var _expected_body_id: int = 0
var _enemy_numeric_id: int = 0
var _initialized: bool = false

static func create(slot_index: int, expected_body_id: int, enemy_numeric_id: int, status: SimStatus) -> RunBattleEnemyEntry:
	var result := RunBattleEnemyEntry.new()
	if not status.is_ok(): return result
	if slot_index < 0 or slot_index > 0xFFFF or expected_body_id <= 0 or expected_body_id > 0xFFFFFFFF or enemy_numeric_id <= 0 or enemy_numeric_id > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_REQUEST_CREATE, enemy_numeric_id, slot_index); return result
	result._slot_index = slot_index; result._expected_body_id = expected_body_id; result._enemy_numeric_id = enemy_numeric_id; result._initialized = true
	return result

func copy() -> RunBattleEnemyEntry:
	var status := SimStatus.new()
	return create(_slot_index, _expected_body_id, _enemy_numeric_id, status) if _initialized else RunBattleEnemyEntry.new()
func is_initialized() -> bool: return _initialized
func slot_index() -> int: return _slot_index
func expected_body_id() -> int: return _expected_body_id
func enemy_numeric_id() -> int: return _enemy_numeric_id
