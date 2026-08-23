class_name AbilityDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _trigger_id: int = BattleTriggerId.Value.INVALID
var _initialized: bool = false


static func create(id_ref: ContentIdRef, trigger_id: int, status: ContentStatus) -> AbilityDefinition:
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
	result._id_ref = id_ref.copy()
	result._trigger_id = trigger_id
	result._initialized = true
	return result


func copy() -> AbilityDefinition:
	if not _initialized: return AbilityDefinition.new()
	var status := ContentStatus.new()
	return create(_id_ref, _trigger_id, status)


func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return 0 if not _initialized else _id_ref.numeric_id()
func string_id() -> String: return "" if not _initialized else _id_ref.string_id()
func trigger_id() -> int: return _trigger_id
func id_ref() -> ContentIdRef: return ContentIdRef.new() if not _initialized else _id_ref.copy()
