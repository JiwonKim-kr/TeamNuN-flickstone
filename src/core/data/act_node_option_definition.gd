class_name ActNodeOptionDefinition
extends RefCounted

var _node_type_id: int = RunNodeType.Value.INVALID
var _weight: int = 0
var _content_refs: Array[ActContentRef] = []
var _initialized: bool = false

static func create(node_type_id: int, weight: int, content_refs: Array[ActContentRef], status: ContentStatus) -> ActNodeOptionDefinition:
	var result := ActNodeOptionDefinition.new()
	if not status.is_ok(): return result
	var rest: bool = node_type_id == RunNodeType.Value.REST
	if not RunNodeType.is_valid(node_type_id) or weight <= 0 or weight > ContentLimits.UINT32_MAX or content_refs.size() > ContentLimits.ACT_CONTENT_REFS_MAX_COUNT or (rest and not content_refs.is_empty()) or (not rest and content_refs.is_empty()):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.OPTIONS)
		return result
	var previous_numeric: int = 0
	var string_ids: Dictionary = {}
	for ref: ActContentRef in content_refs:
		if ref == null or not ref.is_initialized() or ref.numeric_id() <= previous_numeric or string_ids.has(ref.string_id()):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.CONTENT_REFS)
			return ActNodeOptionDefinition.new()
		result._content_refs.append(ref.copy())
		previous_numeric = ref.numeric_id()
		string_ids[ref.string_id()] = true
	result._node_type_id = node_type_id
	result._weight = weight
	result._initialized = true
	return result

func copy() -> ActNodeOptionDefinition:
	if not _initialized: return ActNodeOptionDefinition.new()
	var status := ContentStatus.new()
	return create(_node_type_id, _weight, _content_refs, status)

func is_initialized() -> bool: return _initialized
func node_type_id() -> int: return _node_type_id
func weight() -> int: return _weight
func content_ref_count() -> int: return _content_refs.size()
func content_ref_at(index: int, status: ContentStatus) -> ActContentRef:
	if not status.is_ok(): return ActContentRef.new()
	if index < 0 or index >= _content_refs.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.CONTENT_REFS)
		return ActContentRef.new()
	return _content_refs[index].copy()
