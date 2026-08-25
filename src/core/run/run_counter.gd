class_name RunCounter
extends RefCounted

var _kind_id: int = RunCounterKind.Value.INVALID
var _value: int = 0
var _initialized: bool = false

static func create(kind_id: int, value: int, status: SimStatus) -> RunCounter:
	var result := RunCounter.new()
	if not status.is_ok(): return result
	if not RunCounterKind.is_valid(kind_id) or value <= 0:
		status.fail(SimStatus.Code.INVALID_RUN_COUNTER, SimStatus.Operation.RUN_COUNTER_CREATE, kind_id, value)
		return result
	result._kind_id = kind_id
	result._value = value
	result._initialized = true
	return result

func copy() -> RunCounter:
	var result := RunCounter.new()
	result._kind_id = _kind_id; result._value = _value; result._initialized = _initialized
	return result

func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func value() -> int: return _value
