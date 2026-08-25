class_name ActFloorDefinition
extends RefCounted

var _floor_index: int = 0
var _slots: Array[ActNodeSlotDefinition] = []
var _initialized: bool = false

static func create(floor_index: int, slots: Array[ActNodeSlotDefinition], status: ContentStatus) -> ActFloorDefinition:
	var result := ActFloorDefinition.new()
	if not status.is_ok(): return result
	if floor_index <= 0 or floor_index > ContentLimits.ACT_FLOOR_MAX_COUNT or slots.is_empty() or slots.size() > ContentLimits.ACT_SLOT_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.FLOOR_INDEX)
		return result
	for index: int in range(slots.size()):
		var slot: ActNodeSlotDefinition = slots[index]
		if slot == null or not slot.is_initialized() or slot.slot_index() != index:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.SLOT_INDEX)
			return ActFloorDefinition.new()
		result._slots.append(slot.copy())
	result._floor_index = floor_index
	result._initialized = true
	return result

func copy() -> ActFloorDefinition:
	if not _initialized: return ActFloorDefinition.new()
	var status := ContentStatus.new()
	return create(_floor_index, _slots, status)

func is_initialized() -> bool: return _initialized
func floor_index() -> int: return _floor_index
func slot_count() -> int: return _slots.size()
func slot_at(index: int, status: ContentStatus) -> ActNodeSlotDefinition:
	if not status.is_ok(): return ActNodeSlotDefinition.new()
	if index < 0 or index >= _slots.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.SLOTS)
		return ActNodeSlotDefinition.new()
	return _slots[index].copy()
