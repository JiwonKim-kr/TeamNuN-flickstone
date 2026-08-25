class_name RunBattlePlayerEntry
extends RefCounted

var _slot_index: int = 0
var _expected_body_id: int = 0
var _run_instance_id: int = 0
var _piece_numeric_id: int = 0
var _level: int = 0
var _initialized: bool = false

static func create(slot_index: int, expected_body_id: int, run_instance_id: int, piece_numeric_id: int, level: int, status: SimStatus) -> RunBattlePlayerEntry:
	var result := RunBattlePlayerEntry.new()
	if not status.is_ok(): return result
	if slot_index < 0 or slot_index > 0xFFFF or expected_body_id <= 0 or expected_body_id > 0xFFFFFFFF or run_instance_id <= 0 or run_instance_id > 0xFFFFFFFF or piece_numeric_id <= 0 or piece_numeric_id > 0xFFFFFFFF or level < 1 or level > 3:
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_REQUEST_CREATE, run_instance_id, slot_index); return result
	result._slot_index = slot_index; result._expected_body_id = expected_body_id; result._run_instance_id = run_instance_id
	result._piece_numeric_id = piece_numeric_id; result._level = level; result._initialized = true
	return result

func copy() -> RunBattlePlayerEntry:
	var status := SimStatus.new()
	return create(_slot_index, _expected_body_id, _run_instance_id, _piece_numeric_id, _level, status) if _initialized else RunBattlePlayerEntry.new()
func is_initialized() -> bool: return _initialized
func slot_index() -> int: return _slot_index
func expected_body_id() -> int: return _expected_body_id
func run_instance_id() -> int: return _run_instance_id
func piece_numeric_id() -> int: return _piece_numeric_id
func level() -> int: return _level
