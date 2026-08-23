class_name StatusModifierDefinition
extends RefCounted

var _kind_id: int = 0
var _operation_id: int = 0
var _value_mode_id: int = 0
var _value: int = 0
var _initialized: bool = false

static func create(kind_id: int, operation_id: int, value_mode_id: int, value: int, status: ContentStatus) -> StatusModifierDefinition:
	var result := StatusModifierDefinition.new()
	if not status.is_ok(): return result
	if not ModifierKind.supports_operation(kind_id, operation_id) or value_mode_id < ModifierKind.ValueMode.FLAT or value_mode_id > ModifierKind.ValueMode.SCALED:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, 0, 0, ContentStatus.FieldId.MODIFIER_KIND_ID); return result
	result._kind_id = kind_id; result._operation_id = operation_id; result._value_mode_id = value_mode_id; result._value = value; result._initialized = true
	return result

func copy() -> StatusModifierDefinition:
	var status := ContentStatus.new(); return create(_kind_id, _operation_id, _value_mode_id, _value, status) if _initialized else StatusModifierDefinition.new()
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func operation_id() -> int: return _operation_id
func value_mode_id() -> int: return _value_mode_id
func value() -> int: return _value
