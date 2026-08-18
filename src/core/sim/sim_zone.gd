class_name SimZone
extends RefCounted
## Immutable polygon terrain zone.

const MIN_VERTEX_COUNT: int = SimPolygon.MIN_VERTEX_COUNT
const MAX_VERTEX_COUNT: int = SimPolygon.MAX_VERTEX_COUNT
const FLAG_KILL: int = 1
const KNOWN_FLAGS: int = FLAG_KILL

var _id: int = 0
var _flags: int = 0
var _friction_multiplier_raw: int = FixMath.ONE_RAW
var _acceleration: FixVec2 = FixVec2.zero()
var _polygon: SimPolygon = SimPolygon.new()


static func _validate_fields(
		id: int,
		allow_unassigned: bool,
		flags: int,
		friction_multiplier_raw: int,
		acceleration: FixVec2,
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
	if not UInt32Math.is_u32(flags) or (flags & ~KNOWN_FLAGS) != 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.ZONE_CREATE,
			flags,
			KNOWN_FLAGS
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
	return true


static func _build(
		id: int,
		flags: int,
		friction_multiplier_raw: int,
		acceleration: FixVec2,
		polygon: SimPolygon
) -> SimZone:
	var zone: SimZone = SimZone.new()
	zone._id = id
	zone._flags = flags
	zone._friction_multiplier_raw = friction_multiplier_raw
	zone._acceleration = acceleration.copy()
	zone._polygon = polygon.copy()
	return zone


static func create_unassigned(
		vertices: Array[FixVec2],
		friction_multiplier_raw: int,
		acceleration: FixVec2,
		status: SimStatus,
		flags: int = 0
) -> SimZone:
	if not _validate_fields(
		0,
		true,
		flags,
		friction_multiplier_raw,
		acceleration,
		status
	):
		return SimZone.new()
	var polygon: SimPolygon = SimPolygon.create(vertices, false, status)
	if not status.is_ok():
		return SimZone.new()
	return _build(
		0,
		flags,
		friction_multiplier_raw,
		acceleration,
		polygon
	)


static func restore(
		id: int,
		flags: int,
		friction_multiplier_raw: int,
		acceleration: FixVec2,
		vertices: Array[FixVec2],
		status: SimStatus
) -> SimZone:
	if not _validate_fields(
		id,
		false,
		flags,
		friction_multiplier_raw,
		acceleration,
		status
	):
		return SimZone.new()
	var polygon: SimPolygon = SimPolygon.create(vertices, false, status)
	if not status.is_ok():
		return SimZone.new()
	return _build(
		id,
		flags,
		friction_multiplier_raw,
		acceleration,
		polygon
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
	if not _validate_fields(
		id,
		false,
		_flags,
		_friction_multiplier_raw,
		_acceleration,
		status
	):
		return SimZone.new()
	return _build(
		id,
		_flags,
		_friction_multiplier_raw,
		_acceleration,
		_polygon
	)


func contains_point_strict(point: FixVec2, status: SimStatus) -> bool:
	return (
		_polygon.classify_point(point, status)
		== SimPolygon.PointClass.INSIDE
	)


func first_strict_entry_t_raw(
		start: FixVec2, finish: FixVec2, status: SimStatus
) -> int:
	return _polygon.first_strict_entry_t_raw(start, finish, status)


func copy() -> SimZone:
	return _build(
		_id,
		_flags,
		_friction_multiplier_raw,
		_acceleration,
		_polygon
	)


func id() -> int:
	return _id


func flags() -> int:
	return _flags


func is_kill_zone() -> bool:
	return (_flags & FLAG_KILL) != 0


func friction_multiplier_raw() -> int:
	return _friction_multiplier_raw


func acceleration() -> FixVec2:
	return _acceleration.copy()


func polygon() -> SimPolygon:
	return _polygon.copy()


func vertex_count() -> int:
	return _polygon.vertex_count()


func vertex(index: int, status: SimStatus) -> FixVec2:
	return _polygon.vertex(index, status)
