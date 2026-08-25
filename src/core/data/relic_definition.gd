class_name RelicDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _effect: RunEffectDefinition
var _initialized: bool = false

static func create(id_ref: ContentIdRef, effect: RunEffectDefinition, status: ContentStatus) -> RelicDefinition:
	var result := RelicDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or effect == null or not effect.is_initialized() or effect.kind_id() != RunEffectKind.Value.VICTORY_GOLD_BONUS:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.RELIC_VALIDATE, ContentIds.DocumentKind.RELICS, 0, ContentStatus.FieldId.EFFECT)
		return result
	result._id_ref = id_ref.copy(); result._effect = effect.copy(); result._initialized = true
	return result

func copy() -> RelicDefinition:
	var result := RelicDefinition.new()
	if _initialized: result._id_ref = _id_ref.copy(); result._effect = _effect.copy(); result._initialized = true
	return result
func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _id_ref.numeric_id() if _initialized else 0
func string_id() -> String: return _id_ref.string_id() if _initialized else ""
func id_ref() -> ContentIdRef: return _id_ref.copy() if _initialized else ContentIdRef.new()
func effect() -> RunEffectDefinition: return _effect.copy() if _initialized else RunEffectDefinition.new()
