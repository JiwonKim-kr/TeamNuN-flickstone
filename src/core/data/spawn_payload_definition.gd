class_name SpawnPayloadDefinition
extends RefCounted

enum DirectionMode { INVALID = 0, OWNER_VELOCITY = 1, OWNER_TO_TARGET = 2, RECORD_VECTOR = 3 }

var _piece_ref: ContentIdRef
var _offset_x_raw: int = 0
var _offset_y_raw: int = 0
var _speed_raw: int = 0
var _direction_mode_id: int = DirectionMode.INVALID
var _initialized: bool = false

static func create(piece_ref: ContentIdRef, offset_x_raw: int, offset_y_raw: int, speed_raw: int, direction_mode_id: int, status: ContentStatus) -> SpawnPayloadDefinition:
	var result := SpawnPayloadDefinition.new()
	if not status.is_ok(): return result
	var offset := FixVec2.from_raw(offset_x_raw, offset_y_raw)
	if piece_ref == null or not piece_ref.is_initialized() or not SimLimits.is_position_valid(offset) or speed_raw < 0 or speed_raw > SimLimits.LAUNCH_SPEED_LIMIT_RAW or direction_mode_id < DirectionMode.OWNER_VELOCITY or direction_mode_id > DirectionMode.RECORD_VECTOR:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.SPAWN_PAYLOAD)
		return result
	var distance_status := SimStatus.new()
	if not offset.is_length_at_most_raw(SimLimits.RADIUS_MAX_RAW * 8, distance_status):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.SPAWN_PAYLOAD)
		return result
	result._piece_ref = piece_ref.copy(); result._offset_x_raw = offset_x_raw; result._offset_y_raw = offset_y_raw
	result._speed_raw = speed_raw; result._direction_mode_id = direction_mode_id; result._initialized = true
	return result

func copy() -> SpawnPayloadDefinition:
	if not _initialized: return SpawnPayloadDefinition.new()
	var status := ContentStatus.new()
	return create(_piece_ref, _offset_x_raw, _offset_y_raw, _speed_raw, _direction_mode_id, status)

func is_initialized() -> bool: return _initialized
func piece_ref() -> ContentIdRef: return ContentIdRef.new() if not _initialized else _piece_ref.copy()
func offset() -> FixVec2: return FixVec2.from_raw(_offset_x_raw, _offset_y_raw)
func speed_raw() -> int: return _speed_raw
func direction_mode_id() -> int: return _direction_mode_id
