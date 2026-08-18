class_name SimZone
extends RefCounted
## Immutable-by-convention polygon zone with multiplicative friction and
## additive acceleration.
##
## P0-2 uses strict point containment for terrain sampling. Full polygon
## topology validation and kill-zone segment crossing are owned by P0-3's
## SimPolygon implementation.

const MIN_VERTEX_COUNT: int = 3
const MAX_VERTEX_COUNT: int = 64

var _id: int = 0
var _flags: int = 0
var _friction_multiplier_raw: int = FixMath.ONE_RAW
var _acceleration: FixVec2 = FixVec2.zero()
var _vertices: Array[FixVec2] = []


static func _validate(
		id: int,
		allow_unassigned: bool,
		flags: int,
		friction_multiplier_raw: int,
		acceleration: FixVec2,
		vertices: Array[FixVec2],
		status: SimStatus
) -> bool:
	if not status.is_ok():
		return false
	if acceleration == null:
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.ZONE_CREATE,
			0,
			0
		)
		return false
	if (
		not UInt32Math.is_u32(id)
		or (id == 0 and not allow_unassigned)
	):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.ZONE_CREATE,
			id,
			0
		)
		return false
	if not UInt32Math.is_u32(flags):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.ZONE_CREATE,
			flags,
			0
		)
		return false
	if friction_multiplier_raw < 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.ZONE_CREATE,
			friction_multiplier_raw,
			0
		)
		return false
	if (
		vertices.size() < MIN_VERTEX_COUNT
		or vertices.size() > MAX_VERTEX_COUNT
	):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.ZONE_CREATE,
			vertices.size(),
			0
		)
		return false
	for vertex: FixVec2 in vertices:
		if vertex == null:
			status.fail(
				SimStatus.Code.INVALID_ARGUMENT,
				SimStatus.Operation.ZONE_CREATE,
				0,
				0
			)
			return false
		if not SimLimits.is_position_valid(vertex):
			status.fail(
				SimStatus.Code.INVALID_RANGE,
				SimStatus.Operation.ZONE_CREATE,
				vertex.x_raw(),
				vertex.y_raw()
			)
			return false
	return true


static func _copy_vertices(vertices: Array[FixVec2]) -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	for vertex: FixVec2 in vertices:
		result.append(vertex.copy())
	return result


static func _build(
		id: int,
		flags: int,
		friction_multiplier_raw: int,
		acceleration: FixVec2,
		vertices: Array[FixVec2]
) -> SimZone:
	var zone: SimZone = SimZone.new()
	zone._id = id
	zone._flags = flags
	zone._friction_multiplier_raw = friction_multiplier_raw
	zone._acceleration = acceleration.copy()
	zone._vertices = _copy_vertices(vertices)
	return zone


static func create_unassigned(
		vertices: Array[FixVec2],
		friction_multiplier_raw: int,
		acceleration: FixVec2,
		status: SimStatus,
		flags: int = 0
) -> SimZone:
	if not _validate(
		0,
		true,
		flags,
		friction_multiplier_raw,
		acceleration,
		vertices,
		status
	):
		return SimZone.new()
	return _build(
		0,
		flags,
		friction_multiplier_raw,
		acceleration,
		vertices
	)


static func restore(
		id: int,
		flags: int,
		friction_multiplier_raw: int,
		acceleration: FixVec2,
		vertices: Array[FixVec2],
		status: SimStatus
) -> SimZone:
	if not _validate(
		id,
		false,
		flags,
		friction_multiplier_raw,
		acceleration,
		vertices,
		status
	):
		return SimZone.new()
	return _build(
		id,
		flags,
		friction_multiplier_raw,
		acceleration,
		vertices
	)


func assigned_copy(id: int, status: SimStatus) -> SimZone:
	if _id != 0:
		status.fail(
			SimStatus.Code.INVALID_SIM_STATE,
			SimStatus.Operation.ZONE_CREATE,
			_id,
			id
		)
		return SimZone.new()
	if not _validate(
		id,
		false,
		_flags,
		_friction_multiplier_raw,
		_acceleration,
		_vertices,
		status
	):
		return SimZone.new()
	return _build(
		id,
		_flags,
		_friction_multiplier_raw,
		_acceleration,
		_vertices
	)


static func _cross(a: FixVec2, b: FixVec2, point: FixVec2, status: SimStatus) -> int:
	var edge_x: int = FixMath.sub_raw(b.x_raw(), a.x_raw(), status)
	var edge_y: int = FixMath.sub_raw(b.y_raw(), a.y_raw(), status)
	var point_x: int = FixMath.sub_raw(point.x_raw(), a.x_raw(), status)
	var point_y: int = FixMath.sub_raw(point.y_raw(), a.y_raw(), status)
	var left: int = FixMath.multiply_int(edge_x, point_y, status)
	var right: int = FixMath.multiply_int(edge_y, point_x, status)
	return FixMath.sub_raw(left, right, status)


static func _between(value: int, endpoint_a: int, endpoint_b: int) -> bool:
	if endpoint_a <= endpoint_b:
		return value >= endpoint_a and value <= endpoint_b
	return value >= endpoint_b and value <= endpoint_a


static func _on_segment(
		a: FixVec2, b: FixVec2, point: FixVec2, cross: int
) -> bool:
	return (
		cross == 0
		and _between(point.x_raw(), a.x_raw(), b.x_raw())
		and _between(point.y_raw(), a.y_raw(), b.y_raw())
	)


func contains_point_strict(point: FixVec2, status: SimStatus) -> bool:
	if not status.is_ok():
		return false
	var winding: int = 0
	for index: int in range(_vertices.size()):
		var a: FixVec2 = _vertices[index]
		var b: FixVec2 = _vertices[(index + 1) % _vertices.size()]
		var cross: int = _cross(a, b, point, status)
		if not status.is_ok():
			return false
		if _on_segment(a, b, point, cross):
			return false
		if a.y_raw() <= point.y_raw():
			if b.y_raw() > point.y_raw() and cross > 0:
				winding += 1
		elif b.y_raw() <= point.y_raw() and cross < 0:
			winding -= 1
	return winding != 0


func copy() -> SimZone:
	return _build(
		_id,
		_flags,
		_friction_multiplier_raw,
		_acceleration,
		_vertices
	)


func id() -> int:
	return _id


func flags() -> int:
	return _flags


func friction_multiplier_raw() -> int:
	return _friction_multiplier_raw


func acceleration() -> FixVec2:
	return _acceleration.copy()


func vertex_count() -> int:
	return _vertices.size()


func vertex(index: int, status: SimStatus) -> FixVec2:
	if not status.is_ok():
		return FixVec2.zero()
	if index < 0 or index >= _vertices.size():
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.ZONE_CREATE,
			index,
			_vertices.size()
		)
		return FixVec2.zero()
	return _vertices[index].copy()
