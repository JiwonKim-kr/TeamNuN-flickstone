class_name ActDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _is_development: bool = false
var _floors: Array[ActFloorDefinition] = []
var _initialized: bool = false

static func create(id_ref: ContentIdRef, is_development: bool, floors: Array[ActFloorDefinition], status: ContentStatus) -> ActDefinition:
	var result := ActDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or floors.size() < ContentLimits.ACT_FLOOR_MIN_COUNT or floors.size() > ContentLimits.ACT_FLOOR_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, 0, ContentStatus.FieldId.FLOORS)
		return result
	var coverage: Dictionary = {}
	for index: int in range(floors.size()):
		var floor: ActFloorDefinition = floors[index]
		if floor == null or not floor.is_initialized() or floor.floor_index() != index + 1:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, id_ref.numeric_id(), ContentStatus.FieldId.FLOOR_INDEX)
			return ActDefinition.new()
		if (index == 0 or index == floors.size() - 1) and floor.slot_count() != 1:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, id_ref.numeric_id(), ContentStatus.FieldId.SLOTS)
			return ActDefinition.new()
		for slot_index: int in range(floor.slot_count()):
			var slot: ActNodeSlotDefinition = floor.slot_at(slot_index, status)
			for option_index: int in range(slot.option_count()):
				var option: ActNodeOptionDefinition = slot.option_at(option_index, status)
				var node_type: int = option.node_type_id()
				if (index == 0 and node_type != RunNodeType.Value.NORMAL_BATTLE) or (index == floors.size() - 1 and node_type != RunNodeType.Value.BOSS) or (index > 0 and index < floors.size() - 1 and node_type == RunNodeType.Value.BOSS):
					status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, id_ref.numeric_id(), ContentStatus.FieldId.NODE_TYPE_ID)
					return ActDefinition.new()
				coverage[node_type] = true
		if not status.is_ok(): return ActDefinition.new()
		result._floors.append(floor.copy())
	if is_development:
		for node_type: int in range(RunNodeType.Value.NORMAL_BATTLE, RunNodeType.Value.BOSS + 1):
			if not coverage.has(node_type):
				status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ACT_VALIDATE, ContentIds.DocumentKind.ACTS, id_ref.numeric_id(), ContentStatus.FieldId.NODE_TYPE_ID)
				return ActDefinition.new()
	result._id_ref = id_ref.copy()
	result._is_development = is_development
	result._initialized = true
	return result

func copy() -> ActDefinition:
	if not _initialized: return ActDefinition.new()
	var status := ContentStatus.new()
	return create(_id_ref, _is_development, _floors, status)

func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return 0 if not _initialized else _id_ref.numeric_id()
func string_id() -> String: return "" if not _initialized else _id_ref.string_id()
func is_development() -> bool: return _is_development
func floor_count() -> int: return _floors.size()
func floor_at(index: int, status: ContentStatus) -> ActFloorDefinition:
	if not status.is_ok(): return ActFloorDefinition.new()
	if index < 0 or index >= _floors.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ACTS, numeric_id(), ContentStatus.FieldId.FLOORS)
		return ActFloorDefinition.new()
	return _floors[index].copy()
