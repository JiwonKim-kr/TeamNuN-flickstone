class_name RunBattlePlayerFact
extends RefCounted

var _slot_index: int = 0
var _expected_body_id: int = 0
var _run_instance_id: int = 0
var _survived: bool = false
var _kills: int = 0
var _initialized: bool = false

static func create(slot_index: int, expected_body_id: int, run_instance_id: int, survived: bool, kills: int, status: SimStatus) -> RunBattlePlayerFact:
	var result := RunBattlePlayerFact.new()
	if not status.is_ok(): return result
	if slot_index < 0 or slot_index > 0xFFFF or expected_body_id <= 0 or expected_body_id > 0xFFFFFFFF or run_instance_id <= 0 or run_instance_id > 0xFFFFFFFF or kills < 0 or kills > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_CREATE, run_instance_id, kills); return result
	result._slot_index = slot_index; result._expected_body_id = expected_body_id; result._run_instance_id = run_instance_id
	result._survived = survived; result._kills = kills; result._initialized = true
	return result

func copy() -> RunBattlePlayerFact:
	var status := SimStatus.new()
	return create(_slot_index, _expected_body_id, _run_instance_id, _survived, _kills, status) if _initialized else RunBattlePlayerFact.new()
func is_initialized() -> bool: return _initialized
func slot_index() -> int: return _slot_index
func expected_body_id() -> int: return _expected_body_id
func run_instance_id() -> int: return _run_instance_id
func survived() -> bool: return _survived
func kills() -> int: return _kills
