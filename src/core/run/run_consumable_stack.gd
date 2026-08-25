class_name RunConsumableStack
extends RefCounted

var _consumable_numeric_id: int = 0
var _count: int = 0
var _initialized: bool = false

static func create(consumable_numeric_id: int, count: int, status: SimStatus) -> RunConsumableStack:
	var result := RunConsumableStack.new()
	if not status.is_ok(): return result
	if consumable_numeric_id <= 0 or consumable_numeric_id > 0xFFFFFFFF or count <= 0 or count > 0xFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_CHOICE_CREATE, consumable_numeric_id, count); return result
	result._consumable_numeric_id = consumable_numeric_id; result._count = count; result._initialized = true
	return result

func copy() -> RunConsumableStack:
	var result := RunConsumableStack.new()
	result._consumable_numeric_id = _consumable_numeric_id; result._count = _count; result._initialized = _initialized
	return result
func is_initialized() -> bool: return _initialized
func consumable_numeric_id() -> int: return _consumable_numeric_id
func count() -> int: return _count
