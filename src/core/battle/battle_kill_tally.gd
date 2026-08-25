class_name BattleKillTally
extends RefCounted

var _body_id: int = 0
var _kill_count: int = 0
var _initialized: bool = false

static func create(body_id: int, kill_count: int, status: SimStatus) -> BattleKillTally:
	var result := BattleKillTally.new()
	if not status.is_ok(): return result
	if body_id <= 0 or body_id > 0xFFFFFFFF or kill_count <= 0 or kill_count > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_BATTLE_KILL_TALLY, SimStatus.Operation.BATTLE_KILL_TALLY_UPDATE, body_id, kill_count); return result
	result._body_id = body_id; result._kill_count = kill_count; result._initialized = true
	return result

func copy() -> BattleKillTally:
	var status := SimStatus.new()
	return create(_body_id, _kill_count, status) if _initialized else BattleKillTally.new()
func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func kill_count() -> int: return _kill_count
