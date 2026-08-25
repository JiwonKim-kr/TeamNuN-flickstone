class_name ActContentRef
extends RefCounted

var _numeric_id: int = 0
var _string_id: String = ""
var _initialized: bool = false

static func create(numeric_id: int, string_id: String, status: ContentStatus) -> ActContentRef:
	var result := ActContentRef.new()
	if not status.is_ok(): return result
	if numeric_id <= 0 or numeric_id > ContentLimits.UINT32_MAX or not ContentIds.valid_string_id(string_id):
		status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, numeric_id, ContentStatus.FieldId.CONTENT_REFS)
		return result
	result._numeric_id = numeric_id
	result._string_id = string_id
	result._initialized = true
	return result

func copy() -> ActContentRef:
	if not _initialized: return ActContentRef.new()
	var status := ContentStatus.new()
	return create(_numeric_id, _string_id, status)

func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _numeric_id
func string_id() -> String: return _string_id
