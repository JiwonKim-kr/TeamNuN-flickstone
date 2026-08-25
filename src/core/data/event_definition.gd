class_name EventDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _options: Array[EventOptionDefinition] = []
var _initialized: bool = false

static func create(id_ref: ContentIdRef, options: Array[EventOptionDefinition], status: ContentStatus) -> EventDefinition:
	var result := EventDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or options.is_empty() or options.size() > ContentLimits.EVENT_OPTION_MAX_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.EVENT_VALIDATE, ContentIds.DocumentKind.EVENTS, 0, ContentStatus.FieldId.OPTIONS); return result
	var has_empty: bool = false
	for index: int in range(options.size()):
		var option: EventOptionDefinition = options[index]
		if option == null or not option.is_initialized() or option.option_id() != index + 1:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.EVENT_VALIDATE, ContentIds.DocumentKind.EVENTS, id_ref.numeric_id(), ContentStatus.FieldId.OPTION_ID); return EventDefinition.new()
		if not option.has_effect(): has_empty = true
		result._options.append(option.copy())
	if not has_empty: status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.EVENT_VALIDATE, ContentIds.DocumentKind.EVENTS, id_ref.numeric_id(), ContentStatus.FieldId.EFFECTS); return EventDefinition.new()
	result._id_ref = id_ref.copy(); result._initialized = true
	return result

func copy() -> EventDefinition:
	var result := EventDefinition.new()
	if _initialized:
		result._id_ref = _id_ref.copy()
		for option: EventOptionDefinition in _options: result._options.append(option.copy())
		result._initialized = true
	return result
func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _id_ref.numeric_id() if _initialized else 0
func string_id() -> String: return _id_ref.string_id() if _initialized else ""
func id_ref() -> ContentIdRef: return _id_ref.copy() if _initialized else ContentIdRef.new()
func option_count() -> int: return _options.size()
func option_at(index: int, status: ContentStatus) -> EventOptionDefinition:
	if index < 0 or index >= _options.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.EVENTS, numeric_id(), ContentStatus.FieldId.OPTIONS); return EventOptionDefinition.new()
	return _options[index].copy()
