class_name AbilityEffectDefinition
extends RefCounted

enum Kind { INVALID = 0, DAMAGE = 1, HEAL = 2, KNOCKBACK = 3, PULL = 4, MODIFY_CT = 5, MODIFY_VELOCITY = 6, MODIFY_STAT = 7, TELEPORT = 8, SET_FLAG = 9, APPLY_STATUS = 10, REMOVE_STATUS = 11 }

var _kind_id: int = Kind.INVALID
var _selector: AbilitySelectorDefinition
var _value_a: int = 0
var _value_b: int = 0
var _operation_id: int = 0
var _initialized: bool = false

static func create(kind_id: int, selector: AbilitySelectorDefinition, value_a: int, value_b: int, operation_id: int, status: ContentStatus) -> AbilityEffectDefinition:
	var result := AbilityEffectDefinition.new()
	if not status.is_ok(): return result
	if kind_id < Kind.DAMAGE or kind_id > Kind.REMOVE_STATUS or kind_id == Kind.TELEPORT or kind_id == Kind.SET_FLAG or selector == null or not selector.is_initialized():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECT_KIND_ID); return result
	if kind_id == Kind.MODIFY_STAT:
		if value_a < ModifierKind.Value.ATTACK or value_a > ModifierKind.Value.CRITICAL_BASIS_POINTS or value_b == 0 or operation_id != ModifierKind.Operation.ADD:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	elif operation_id != 0:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.OPERATION_ID); return result
	if kind_id == Kind.APPLY_STATUS and (value_a <= 0 or value_b <= 0): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	if kind_id == Kind.REMOVE_STATUS and (value_a <= 0 or value_b < 0): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	if (kind_id == Kind.DAMAGE or kind_id == Kind.HEAL or kind_id == Kind.KNOCKBACK or kind_id == Kind.PULL) and (value_a <= 0 or value_b != 0):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	if kind_id == Kind.MODIFY_VELOCITY and value_a == 0 and value_b == 0:
		pass
	result._kind_id = kind_id; result._selector = selector.copy(); result._value_a = value_a; result._value_b = value_b; result._operation_id = operation_id; result._initialized = true
	return result

func copy() -> AbilityEffectDefinition:
	var status := ContentStatus.new(); return create(_kind_id, _selector, _value_a, _value_b, _operation_id, status) if _initialized else AbilityEffectDefinition.new()
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func selector() -> AbilitySelectorDefinition: return _selector.copy()
func value_a() -> int: return _value_a
func value_b() -> int: return _value_b
func operation_id() -> int: return _operation_id
