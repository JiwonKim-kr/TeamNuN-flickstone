class_name MapSlotDefinition
extends RefCounted

var _position: FixVec2 = FixVec2.zero()
var _initialized: bool = false


static func create(position: FixVec2, status: ContentStatus) -> MapSlotDefinition:
	var result := MapSlotDefinition.new()
	if not status.is_ok(): return result
	if position == null or not SimLimits.is_position_valid(position):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE)
		return result
	result._position = position.copy()
	result._initialized = true
	return result


func copy() -> MapSlotDefinition:
	if not _initialized: return MapSlotDefinition.new()
	var status := ContentStatus.new()
	return create(_position, status)


func is_initialized() -> bool: return _initialized
func position() -> FixVec2: return _position.copy()
