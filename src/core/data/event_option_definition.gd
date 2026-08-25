class_name EventOptionDefinition
extends RefCounted

var _option_id: int = 0
var _effect: RunEffectDefinition
var _initialized: bool = false

static func create(option_id: int, effect: RunEffectDefinition, status: ContentStatus) -> EventOptionDefinition:
	var result := EventOptionDefinition.new()
	if not status.is_ok(): return result
	if option_id < 1 or option_id > ContentLimits.EVENT_OPTION_MAX_COUNT or (effect != null and (not effect.is_initialized() or (effect.kind_id() != RunEffectKind.Value.GAIN_GOLD and effect.kind_id() != RunEffectKind.Value.GAIN_CONSUMABLE))):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.EVENT_VALIDATE, ContentIds.DocumentKind.EVENTS, 0, ContentStatus.FieldId.OPTIONS); return result
	result._option_id = option_id; result._effect = effect.copy() if effect != null else null; result._initialized = true
	return result

func copy() -> EventOptionDefinition:
	var result := EventOptionDefinition.new()
	if _initialized: result._option_id = _option_id; result._effect = _effect.copy() if _effect != null else null; result._initialized = true
	return result
func is_initialized() -> bool: return _initialized
func option_id() -> int: return _option_id
func has_effect() -> bool: return _effect != null
func effect() -> RunEffectDefinition: return _effect.copy() if _effect != null else RunEffectDefinition.new()
