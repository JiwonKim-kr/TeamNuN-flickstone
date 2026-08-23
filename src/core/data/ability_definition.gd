class_name AbilityDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _trigger_id: int = BattleTriggerId.Value.INVALID
var _conditions: Array[AbilityConditionDefinition] = []
var _effects: Array[AbilityEffectDefinition] = []
var _initialized: bool = false


static func create(id_ref: ContentIdRef, trigger_id: int, conditions: Array[AbilityConditionDefinition], effects: Array[AbilityEffectDefinition], status: ContentStatus) -> AbilityDefinition:
	var result := AbilityDefinition.new()
	if not status.is_ok():
		return result
	if id_ref == null or not id_ref.is_initialized():
		status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.CATALOG_BUILD)
		return result
	if not BattleTriggerId.is_known(trigger_id):
		status.fail(
			ContentStatus.Code.INVALID_DOMAIN,
			ContentStatus.Operation.DOCUMENT_VALIDATE,
			ContentIds.DocumentKind.ABILITIES,
			id_ref.numeric_id(),
			ContentStatus.FieldId.TRIGGER_ID
		)
		return result
	if conditions.size() > ContentLimits.ABILITY_CONDITIONS_MAX_COUNT or effects.size() > ContentLimits.ABILITY_EFFECTS_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.ABILITIES, id_ref.numeric_id()); return result
	for condition: AbilityConditionDefinition in conditions:
		if condition == null or not condition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.ABILITIES, id_ref.numeric_id()); return result
		result._conditions.append(condition.copy())
	for effect: AbilityEffectDefinition in effects:
		if effect == null or not effect.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.ABILITIES, id_ref.numeric_id()); return result
		result._effects.append(effect.copy())
	result._id_ref = id_ref.copy()
	result._trigger_id = trigger_id
	result._initialized = true
	return result


func copy() -> AbilityDefinition:
	if not _initialized: return AbilityDefinition.new()
	var status := ContentStatus.new()
	return create(_id_ref, _trigger_id, _conditions, _effects, status)


func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return 0 if not _initialized else _id_ref.numeric_id()
func string_id() -> String: return "" if not _initialized else _id_ref.string_id()
func trigger_id() -> int: return _trigger_id
func id_ref() -> ContentIdRef: return ContentIdRef.new() if not _initialized else _id_ref.copy()
func condition_count() -> int: return _conditions.size()
func condition_at(index: int, status: ContentStatus) -> AbilityConditionDefinition:
	if index < 0 or index >= _conditions.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ABILITIES, numeric_id(), ContentStatus.FieldId.CONDITIONS); return AbilityConditionDefinition.new()
	return _conditions[index].copy()
func effect_count() -> int: return _effects.size()
func effect_at(index: int, status: ContentStatus) -> AbilityEffectDefinition:
	if index < 0 or index >= _effects.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ABILITIES, numeric_id(), ContentStatus.FieldId.EFFECTS); return AbilityEffectDefinition.new()
	return _effects[index].copy()
