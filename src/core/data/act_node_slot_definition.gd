class_name ActNodeSlotDefinition
extends RefCounted

var _slot_index: int = 0
var _options: Array[ActNodeOptionDefinition] = []
var _total_weight: int = 0
var _initialized: bool = false

static func create(slot_index: int, options: Array[ActNodeOptionDefinition], status: ContentStatus) -> ActNodeSlotDefinition:
	var result := ActNodeSlotDefinition.new()
	if not status.is_ok(): return result
	if slot_index < 0 or slot_index >= ContentLimits.ACT_SLOT_MAX_COUNT or options.is_empty() or options.size() > ContentLimits.ACT_OPTION_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.SLOT_INDEX)
		return result
	var previous_type: int = 0
	for option: ActNodeOptionDefinition in options:
		if option == null or not option.is_initialized() or option.node_type_id() <= previous_type:
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.NODE_TYPE_ID)
			return ActNodeSlotDefinition.new()
		result._total_weight += option.weight()
		if result._total_weight > ContentLimits.UINT32_SPACE:
			status.fail(ContentStatus.Code.INTEGER_OVERFLOW, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.WEIGHT)
			return ActNodeSlotDefinition.new()
		result._options.append(option.copy())
		previous_type = option.node_type_id()
	result._slot_index = slot_index
	result._initialized = true
	return result

func copy() -> ActNodeSlotDefinition:
	if not _initialized: return ActNodeSlotDefinition.new()
	var status := ContentStatus.new()
	return create(_slot_index, _options, status)

func is_initialized() -> bool: return _initialized
func slot_index() -> int: return _slot_index
func option_count() -> int: return _options.size()
func total_weight() -> int: return _total_weight
func option_at(index: int, status: ContentStatus) -> ActNodeOptionDefinition:
	if not status.is_ok(): return ActNodeOptionDefinition.new()
	if index < 0 or index >= _options.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.OPTIONS)
		return ActNodeOptionDefinition.new()
	return _options[index].copy()
