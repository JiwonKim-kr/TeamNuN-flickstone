class_name RunChoiceEntry
extends RefCounted

var _choice_id: int = 0
var _kind_id: int = RunChoiceKind.Value.INVALID
var _primary_numeric_id: int = 0
var _secondary_numeric_id: int = 0
var _amount: int = 0
var _cost: int = 0
var _enabled: bool = false
var _initialized: bool = false

static func create(choice_id: int, kind_id: int, primary_numeric_id: int, secondary_numeric_id: int, amount: int, cost: int, enabled: bool, status: SimStatus) -> RunChoiceEntry:
	var result := RunChoiceEntry.new()
	if not status.is_ok(): return result
	if choice_id <= 0 or choice_id > 0xFFFF or not RunChoiceKind.is_valid(kind_id) or primary_numeric_id < 0 or primary_numeric_id > 0xFFFFFFFF or secondary_numeric_id < 0 or secondary_numeric_id > 0xFFFFFFFF or cost < 0 or cost > 0xFFFFFFFF:
		status.fail(SimStatus.Code.INVALID_RUN_CHOICE, SimStatus.Operation.RUN_CHOICE_CREATE, choice_id, kind_id); return result
	result._choice_id = choice_id; result._kind_id = kind_id; result._primary_numeric_id = primary_numeric_id
	result._secondary_numeric_id = secondary_numeric_id; result._amount = amount; result._cost = cost; result._enabled = enabled; result._initialized = true
	return result

func copy() -> RunChoiceEntry:
	var result := RunChoiceEntry.new()
	result._choice_id = _choice_id; result._kind_id = _kind_id; result._primary_numeric_id = _primary_numeric_id; result._secondary_numeric_id = _secondary_numeric_id
	result._amount = _amount; result._cost = _cost; result._enabled = _enabled; result._initialized = _initialized
	return result
func is_initialized() -> bool: return _initialized
func choice_id() -> int: return _choice_id
func kind_id() -> int: return _kind_id
func primary_numeric_id() -> int: return _primary_numeric_id
func secondary_numeric_id() -> int: return _secondary_numeric_id
func amount() -> int: return _amount
func cost() -> int: return _cost
func enabled() -> bool: return _enabled
