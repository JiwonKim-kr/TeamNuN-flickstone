class_name ZoneSpawnPayloadDefinition
extends RefCounted

var _flags: int = 0
var _friction_multiplier_raw: int = 0
var _acceleration: FixVec2 = FixVec2.zero()
var _turn_start_damage: int = 0
var _offset: FixVec2 = FixVec2.zero()
var _vertices: Array[FixVec2] = []
var _duration_turns: int = 0
var _initialized: bool = false


static func create(flags: int, friction_multiplier_raw: int, acceleration: FixVec2, turn_start_damage: int, offset: FixVec2, vertices: Array[FixVec2], duration_turns: int, status: ContentStatus) -> ZoneSpawnPayloadDefinition:
	var result := ZoneSpawnPayloadDefinition.new()
	if not status.is_ok(): return result
	if (
		flags < 0 or (flags & ~SimZone.KNOWN_FLAGS) != 0 or friction_multiplier_raw < 0
		or acceleration == null or offset == null or not SimLimits.is_position_valid(acceleration) or not SimLimits.is_position_valid(offset)
		or turn_start_damage < 0
		or vertices.size() < ContentLimits.ZONE_VERTEX_MIN_COUNT or vertices.size() > ContentLimits.ZONE_VERTEX_MAX_COUNT
		or duration_turns < 0 or duration_turns > ContentLimits.ZONE_DURATION_MAX_TURNS
		or ((flags & SimZone.FLAG_KILL) != 0 and (friction_multiplier_raw != FixMath.ONE_RAW or not acceleration.is_zero()))
		or (turn_start_damage > 0 and (flags != 0 or friction_multiplier_raw != FixMath.ONE_RAW or not acceleration.is_zero()))
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.ZONE_PAYLOAD); return result
	var sim_status := SimStatus.new()
	SimPolygon.create(vertices, false, sim_status)
	if not sim_status.is_ok(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.VERTICES); return result
	result._flags = flags; result._friction_multiplier_raw = friction_multiplier_raw; result._acceleration = acceleration.copy(); result._turn_start_damage = turn_start_damage; result._offset = offset.copy()
	for vertex: FixVec2 in vertices: result._vertices.append(vertex.copy())
	result._duration_turns = duration_turns; result._initialized = true
	return result


func copy() -> ZoneSpawnPayloadDefinition:
	if not _initialized: return ZoneSpawnPayloadDefinition.new()
	var status := ContentStatus.new()
	return create(_flags, _friction_multiplier_raw, _acceleration, _turn_start_damage, _offset, _vertices, _duration_turns, status)


func is_initialized() -> bool: return _initialized
func flags() -> int: return _flags
func friction_multiplier_raw() -> int: return _friction_multiplier_raw
func acceleration() -> FixVec2: return _acceleration.copy()
func turn_start_damage() -> int: return _turn_start_damage
func offset() -> FixVec2: return _offset.copy()
func duration_turns() -> int: return _duration_turns
func vertex_count() -> int: return _vertices.size()
func vertex_at(index: int, status: ContentStatus) -> FixVec2:
	if index < 0 or index >= _vertices.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.VERTICES); return FixVec2.zero()
	return _vertices[index].copy()
