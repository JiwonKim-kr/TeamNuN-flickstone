class_name BattleResult
extends RefCounted

enum Value {
	ONGOING = 0,
	PLAYER_VICTORY = 1,
	PLAYER_DEFEAT = 2,
	DRAW = 3,
}

var _value: int = Value.ONGOING
var _origins: Array[BattlePieceOrigin] = []
var _initialized: bool = false

static func create(value: int, origins: Array[BattlePieceOrigin], status: SimStatus) -> BattleResult:
	var result := BattleResult.new()
	if not status.is_ok() or not is_known(value):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_RESULT, SimStatus.Operation.BATTLE_REPORT_CREATE, value, 0)
		return result
	var previous: int = 0
	for origin: BattlePieceOrigin in origins:
		if origin == null or not origin.is_initialized() or origin.body_id() <= previous:
			status.fail(SimStatus.Code.INVALID_BATTLE_RESULT, SimStatus.Operation.BATTLE_REPORT_CREATE, 0 if origin == null else origin.body_id(), previous); return BattleResult.new()
		result._origins.append(origin.copy()); previous = origin.body_id()
	result._value = value; result._initialized = true; return result

func is_initialized() -> bool: return _initialized
func value() -> int: return _value
func origin_count() -> int: return _origins.size()
func origin_at(index: int, status: SimStatus) -> BattlePieceOrigin:
	if index < 0 or index >= _origins.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_REPORT_CREATE, index, _origins.size()); return BattlePieceOrigin.new()
	return _origins[index].copy()

static func is_known(value: int) -> bool:
	return value >= Value.ONGOING and value <= Value.DRAW

static func is_terminal(value: int) -> bool:
	return value >= Value.PLAYER_VICTORY and value <= Value.DRAW
