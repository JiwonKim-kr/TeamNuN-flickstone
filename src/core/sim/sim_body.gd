class_name SimBody
extends RefCounted
## Immutable-by-convention physical body state for deterministic simulation.
##
## ID 0 denotes an unassigned setup/runtime-spawn template. Bodies stored in a
## SimWorld always have a non-zero uint32 ID. All value getters return copies so
## a world clone cannot be mutated through aliases.

var _id: int = 0
var _alive: bool = true
var _destructible: bool = true
var _position: FixVec2 = FixVec2.zero()
var _velocity: FixVec2 = FixVec2.zero()
var _radius_raw: int = 0
var _mass_raw: int = 0
var _friction_multiplier_raw: int = FixMath.ONE_RAW


static func _validate(
		id: int,
		allow_unassigned: bool,
		position: FixVec2,
		velocity: FixVec2,
		radius_raw: int,
		mass_raw: int,
		friction_multiplier_raw: int,
		status: SimStatus
) -> bool:
	if not status.is_ok():
		return false
	if position == null or velocity == null:
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.BODY_CREATE,
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
			SimStatus.Operation.BODY_CREATE,
			id,
			0
		)
		return false
	if not SimLimits.is_position_valid(position):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.BODY_CREATE,
			position.x_raw(),
			position.y_raw()
		)
		return false
	if not SimLimits.is_speed_valid(velocity, status):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_RANGE,
				SimStatus.Operation.BODY_CREATE,
				velocity.x_raw(),
				velocity.y_raw()
			)
		return false
	if not SimLimits.is_radius_valid(radius_raw):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.BODY_CREATE,
			radius_raw,
			0
		)
		return false
	if not SimLimits.is_mass_valid(mass_raw):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.BODY_CREATE,
			mass_raw,
			0
		)
		return false
	if friction_multiplier_raw < 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.BODY_CREATE,
			friction_multiplier_raw,
			0
		)
		return false
	return true


static func _build(
		id: int,
		alive: bool,
		destructible: bool,
		position: FixVec2,
		velocity: FixVec2,
		radius_raw: int,
		mass_raw: int,
		friction_multiplier_raw: int
) -> SimBody:
	var body: SimBody = SimBody.new()
	body._id = id
	body._alive = alive
	body._destructible = destructible
	body._position = position.copy()
	body._velocity = velocity.copy()
	body._radius_raw = radius_raw
	body._mass_raw = mass_raw
	body._friction_multiplier_raw = friction_multiplier_raw
	return body


static func create_unassigned(
		position: FixVec2,
		velocity: FixVec2,
		radius_raw: int,
		mass_raw: int,
		status: SimStatus,
		friction_multiplier_raw: int = FixMath.ONE_RAW,
		destructible: bool = true
) -> SimBody:
	if not _validate(
		0,
		true,
		position,
		velocity,
		radius_raw,
		mass_raw,
		friction_multiplier_raw,
		status
	):
		return SimBody.new()
	return _build(
		0,
		true,
		destructible,
		position,
		velocity,
		radius_raw,
		mass_raw,
		friction_multiplier_raw
	)


static func restore(
		id: int,
		alive: bool,
		destructible: bool,
		position: FixVec2,
		velocity: FixVec2,
		radius_raw: int,
		mass_raw: int,
		friction_multiplier_raw: int,
		status: SimStatus
) -> SimBody:
	if not _validate(
		id,
		false,
		position,
		velocity,
		radius_raw,
		mass_raw,
		friction_multiplier_raw,
		status
	):
		return SimBody.new()
	return _build(
		id,
		alive,
		destructible,
		position,
		velocity,
		radius_raw,
		mass_raw,
		friction_multiplier_raw
	)


func assigned_copy(id: int, status: SimStatus) -> SimBody:
	if _id != 0:
		status.fail(
			SimStatus.Code.INVALID_SIM_STATE,
			SimStatus.Operation.BODY_CREATE,
			_id,
			id
		)
		return SimBody.new()
	if not _validate(
		id,
		false,
		_position,
		_velocity,
		_radius_raw,
		_mass_raw,
		_friction_multiplier_raw,
		status
	):
		return SimBody.new()
	return _build(
		id,
		_alive,
		_destructible,
		_position,
		_velocity,
		_radius_raw,
		_mass_raw,
		_friction_multiplier_raw
	)


func with_motion(
		position: FixVec2, velocity: FixVec2, status: SimStatus
) -> SimBody:
	if not _validate(
		_id,
		_id == 0,
		position,
		velocity,
		_radius_raw,
		_mass_raw,
		_friction_multiplier_raw,
		status
	):
		return SimBody.new()
	return _build(
		_id,
		_alive,
		_destructible,
		position,
		velocity,
		_radius_raw,
		_mass_raw,
		_friction_multiplier_raw
	)


func with_velocity(velocity: FixVec2, status: SimStatus) -> SimBody:
	return with_motion(_position, velocity, status)


func copy() -> SimBody:
	return _build(
		_id,
		_alive,
		_destructible,
		_position,
		_velocity,
		_radius_raw,
		_mass_raw,
		_friction_multiplier_raw
	)


func id() -> int:
	return _id


func alive() -> bool:
	return _alive


func destructible() -> bool:
	return _destructible


func position() -> FixVec2:
	return _position.copy()


func velocity() -> FixVec2:
	return _velocity.copy()


func radius_raw() -> int:
	return _radius_raw


func mass_raw() -> int:
	return _mass_raw


func friction_multiplier_raw() -> int:
	return _friction_multiplier_raw
