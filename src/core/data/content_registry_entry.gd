class_name ContentRegistryEntry
extends RefCounted

var _namespace_id: int = ContentIds.Namespace.INVALID
var _numeric_id: int = 0
var _string_id: String = ""
var _state_id: int = ContentIds.EntryState.INVALID
var _initialized: bool = false


static func create(
		namespace_id: int,
		numeric_id: int,
		string_id: String,
		state_id: int,
		status: ContentStatus
) -> ContentRegistryEntry:
	var result := ContentRegistryEntry.new()
	if not status.is_ok():
		return result
	if (
		not ContentIds.is_known_namespace(namespace_id)
		or numeric_id <= 0
		or numeric_id > ContentLimits.UINT32_MAX
		or not ContentIds.valid_string_id(string_id)
		or (state_id != ContentIds.EntryState.ACTIVE and state_id != ContentIds.EntryState.RETIRED)
	):
		status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.ID_REGISTER, ContentIds.DocumentKind.ID_REGISTRY, numeric_id)
		return result
	result._namespace_id = namespace_id
	result._numeric_id = numeric_id
	result._string_id = string_id
	result._state_id = state_id
	result._initialized = true
	return result


func copy() -> ContentRegistryEntry:
	if not _initialized: return ContentRegistryEntry.new()
	var status := ContentStatus.new()
	return create(_namespace_id, _numeric_id, _string_id, _state_id, status)


func is_initialized() -> bool: return _initialized
func namespace_id() -> int: return _namespace_id
func numeric_id() -> int: return _numeric_id
func string_id() -> String: return _string_id
func state_id() -> int: return _state_id
