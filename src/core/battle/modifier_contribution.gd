class_name ModifierContribution
extends RefCounted

var _kind_id: int = 0
var _operation_id: int = 0
var _value: int = 0
var _initialized: bool = false

static func create(kind_id: int, operation_id: int, value: int, status: SimStatus) -> ModifierContribution:
	var result := ModifierContribution.new()
	if not status.is_ok(): return result
	if not ModifierKind.supports_operation(kind_id, operation_id): status.fail(SimStatus.Code.INVALID_MODIFIER_DEFINITION, SimStatus.Operation.MODIFIER_AGGREGATE, kind_id, operation_id); return result
	result._kind_id = kind_id; result._operation_id = operation_id; result._value = value; result._initialized = true; return result
func copy() -> ModifierContribution:
	var status := SimStatus.new(); return create(_kind_id, _operation_id, _value, status) if _initialized else ModifierContribution.new()
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func operation_id() -> int: return _operation_id
func value() -> int: return _value
