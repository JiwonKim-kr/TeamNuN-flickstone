class_name RunEffectDefinition
extends RefCounted

var _kind_id: int = RunEffectKind.Value.INVALID
var _primary_numeric_id: int = 0
var _amount: int = 0
var _initialized: bool = false

static func create(kind_id: int, primary_numeric_id: int, amount: int, status: ContentStatus) -> RunEffectDefinition:
	var result := RunEffectDefinition.new()
	if not status.is_ok(): return result
	var valid: bool = RunEffectKind.is_valid(kind_id)
	if kind_id == RunEffectKind.Value.GAIN_GOLD or kind_id == RunEffectKind.Value.VICTORY_GOLD_BONUS:
		valid = valid and primary_numeric_id == 0 and amount >= 1 and amount <= ContentLimits.RUN_EFFECT_GOLD_MAX
	elif kind_id == RunEffectKind.Value.RECOVER_LIFE:
		valid = valid and primary_numeric_id == 0 and amount == 1
	elif kind_id == RunEffectKind.Value.GAIN_CONSUMABLE:
		valid = valid and primary_numeric_id >= 1 and primary_numeric_id <= ContentLimits.UINT32_MAX and amount >= 1 and amount <= ContentLimits.RUN_ITEM_STACK_MAX
	if not valid:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.RUN_EFFECT_VALIDATE, 0, 0, ContentStatus.FieldId.EFFECT)
		return result
	result._kind_id = kind_id
	result._primary_numeric_id = primary_numeric_id
	result._amount = amount
	result._initialized = true
	return result

func copy() -> RunEffectDefinition:
	var result := RunEffectDefinition.new()
	result._kind_id = _kind_id; result._primary_numeric_id = _primary_numeric_id; result._amount = _amount; result._initialized = _initialized
	return result

func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func primary_numeric_id() -> int: return _primary_numeric_id
func amount() -> int: return _amount
