class_name MapZoneDefinition
extends RefCounted

var _local_id: int = 0
var _flags: int = 0
var _friction_multiplier_raw: int = 0
var _acceleration: FixVec2 = FixVec2.zero()
var _vertices: Array[FixVec2] = []
var _initialized: bool = false


static func create(local_id: int, flags: int, friction_multiplier_raw: int, acceleration: FixVec2, vertices: Array[FixVec2], status: ContentStatus) -> MapZoneDefinition:
	var result := MapZoneDefinition.new()
	if not status.is_ok(): return result
	if (
		local_id <= 0 or local_id > ContentLimits.UINT32_MAX
		or acceleration == null or not SimLimits.is_position_valid(acceleration)
		or flags < 0 or (flags & ~SimZone.KNOWN_FLAGS) != 0
		or friction_multiplier_raw < 0
		or vertices.size() < ContentLimits.ZONE_VERTEX_MIN_COUNT
		or vertices.size() > ContentLimits.ZONE_VERTEX_MAX_COUNT
		or ((flags & SimZone.FLAG_KILL) != 0 and (friction_multiplier_raw != FixMath.ONE_RAW or not acceleration.is_zero()))
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, ContentIds.DocumentKind.MAPS, 0, ContentStatus.FieldId.ZONES)
		return result
	var sim_status := SimStatus.new()
	var polygon: SimPolygon = SimPolygon.create(vertices, false, sim_status)
	if not sim_status.is_ok():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, ContentIds.DocumentKind.MAPS, 0, ContentStatus.FieldId.VERTICES)
		return result
	result._local_id = local_id
	result._flags = flags
	result._friction_multiplier_raw = friction_multiplier_raw
	result._acceleration = acceleration.copy()
	for vertex: FixVec2 in vertices: result._vertices.append(vertex.copy())
	result._initialized = true
	return result


func copy() -> MapZoneDefinition:
	if not _initialized: return MapZoneDefinition.new()
	var status := ContentStatus.new()
	return create(_local_id, _flags, _friction_multiplier_raw, _acceleration, _vertices, status)


func sim_template(status: SimStatus) -> SimZone:
	return SimZone.create_unassigned(_vertices, _friction_multiplier_raw, _acceleration, status, _flags)


func is_initialized() -> bool: return _initialized
func local_id() -> int: return _local_id
func flags() -> int: return _flags
func is_kill_zone() -> bool: return (_flags & SimZone.FLAG_KILL) != 0
func friction_multiplier_raw() -> int: return _friction_multiplier_raw
func acceleration() -> FixVec2: return _acceleration.copy()
func vertex_count() -> int: return _vertices.size()
func vertex_at(index: int, status: ContentStatus) -> FixVec2:
	if index < 0 or index >= _vertices.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.MAPS, 0, ContentStatus.FieldId.VERTICES)
		return FixVec2.zero()
	return _vertices[index].copy()
func vertices_copy() -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	for vertex: FixVec2 in _vertices: result.append(vertex.copy())
	return result
