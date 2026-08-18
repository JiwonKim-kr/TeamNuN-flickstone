class_name FixVec2
extends RefCounted
## Immutable-by-convention Q47.16 vector value object.
##
## Components are private by repository convention and exposed only as raw
## getters. Every arithmetic method returns a new vector and shares the caller's
## release-safe `SimStatus`. Component-wise failures retain their scalar
## `FixMath` operation ID; only vector-owned wide operations use `VEC_*` IDs.

var _x_raw: int
var _y_raw: int


func _init(p_x_raw: int = 0, p_y_raw: int = 0) -> void:
	_x_raw = p_x_raw
	_y_raw = p_y_raw


static func from_raw(p_x_raw: int, p_y_raw: int) -> FixVec2:
	return FixVec2.new(p_x_raw, p_y_raw)


static func from_ints(p_x: int, p_y: int, status: SimStatus) -> FixVec2:
	var x_value_raw: int = FixMath.from_int(p_x, status)
	var y_value_raw: int = FixMath.from_int(p_y, status)
	return FixVec2.new(x_value_raw, y_value_raw)


static func zero() -> FixVec2:
	return FixVec2.new(0, 0)


func x_raw() -> int:
	return _x_raw


func y_raw() -> int:
	return _y_raw


func copy() -> FixVec2:
	return FixVec2.new(_x_raw, _y_raw)


func is_zero() -> bool:
	return _x_raw == 0 and _y_raw == 0


func is_equal(other: FixVec2) -> bool:
	return _x_raw == other._x_raw and _y_raw == other._y_raw


func add(other: FixVec2, status: SimStatus) -> FixVec2:
	var result_x_raw: int = FixMath.add_raw(_x_raw, other._x_raw, status)
	var result_y_raw: int = FixMath.add_raw(_y_raw, other._y_raw, status)
	return FixVec2.new(result_x_raw, result_y_raw)


func sub(other: FixVec2, status: SimStatus) -> FixVec2:
	var result_x_raw: int = FixMath.sub_raw(_x_raw, other._x_raw, status)
	var result_y_raw: int = FixMath.sub_raw(_y_raw, other._y_raw, status)
	return FixVec2.new(result_x_raw, result_y_raw)


func negated(status: SimStatus) -> FixVec2:
	var result_x_raw: int = FixMath.negate_raw(_x_raw, status)
	var result_y_raw: int = FixMath.negate_raw(_y_raw, status)
	return FixVec2.new(result_x_raw, result_y_raw)


func scaled(scalar_raw: int, status: SimStatus) -> FixVec2:
	var result_x_raw: int = FixMath.mul_raw(_x_raw, scalar_raw, status)
	var result_y_raw: int = FixMath.mul_raw(_y_raw, scalar_raw, status)
	return FixVec2.new(result_x_raw, result_y_raw)


func divided(scalar_raw: int, status: SimStatus) -> FixVec2:
	var result_x_raw: int = FixMath.div_raw(_x_raw, scalar_raw, status)
	var result_y_raw: int = FixMath.div_raw(_y_raw, scalar_raw, status)
	return FixVec2.new(result_x_raw, result_y_raw)


func _wide_dot(other: FixVec2, status: SimStatus, operation: int) -> int:
	if not status.is_ok():
		return 0
	if not FixMath.can_mul_int(_x_raw, other._x_raw):
		status.fail(SimStatus.Code.INT64_OVERFLOW, operation, _x_raw, other._x_raw)
		return 0
	var wide_x: int = _x_raw * other._x_raw
	if not FixMath.can_mul_int(_y_raw, other._y_raw):
		status.fail(SimStatus.Code.INT64_OVERFLOW, operation, _y_raw, other._y_raw)
		return 0
	var wide_y: int = _y_raw * other._y_raw
	if not FixMath.can_add_int(wide_x, wide_y):
		status.fail(SimStatus.Code.INT64_OVERFLOW, operation, wide_x, wide_y)
		return 0
	return wide_x + wide_y


func dot_raw(other: FixVec2, status: SimStatus) -> int:
	var wide: int = _wide_dot(other, status, SimStatus.Operation.VEC_DOT)
	return FixMath.round_div_int(wide, FixMath.SCALE, status)


func length_squared_raw(status: SimStatus) -> int:
	var wide: int = _wide_dot(self, status, SimStatus.Operation.VEC_LENGTH)
	return FixMath.round_div_int(wide, FixMath.SCALE, status)


func length_raw(status: SimStatus) -> int:
	var wide: int = _wide_dot(self, status, SimStatus.Operation.VEC_LENGTH)
	return FixMath.isqrt_nearest(wide, status)


func normalized(status: SimStatus) -> FixVec2:
	var magnitude_raw: int = length_raw(status)
	if not status.is_ok():
		return FixVec2.zero()
	if magnitude_raw == 0:
		status.fail(
			SimStatus.Code.ZERO_LENGTH,
			SimStatus.Operation.VEC_NORMALIZE,
			_x_raw,
			_y_raw
		)
		return FixVec2.zero()
	return divided(magnitude_raw, status)


func is_length_at_most_raw(limit_raw: int, status: SimStatus) -> bool:
	if not status.is_ok():
		return false
	if limit_raw < 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.VEC_LENGTH_COMPARE,
			limit_raw,
			0
		)
		return false
	if not FixMath.can_mul_int(limit_raw, limit_raw):
		status.fail(
			SimStatus.Code.INT64_OVERFLOW,
			SimStatus.Operation.VEC_LENGTH_COMPARE,
			limit_raw,
			limit_raw
		)
		return false
	var limit_squared_wide: int = limit_raw * limit_raw
	var wide: int = _wide_dot(self, status, SimStatus.Operation.VEC_LENGTH_COMPARE)
	if not status.is_ok():
		return false
	return wide <= limit_squared_wide


func is_length_below_raw(limit_raw: int, status: SimStatus) -> bool:
	if not status.is_ok():
		return false
	if limit_raw < 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.VEC_LENGTH_COMPARE,
			limit_raw,
			0
		)
		return false
	if not FixMath.can_mul_int(limit_raw, limit_raw):
		status.fail(
			SimStatus.Code.INT64_OVERFLOW,
			SimStatus.Operation.VEC_LENGTH_COMPARE,
			limit_raw,
			limit_raw
		)
		return false
	var limit_squared_wide: int = limit_raw * limit_raw
	var wide: int = _wide_dot(self, status, SimStatus.Operation.VEC_LENGTH_COMPARE)
	if not status.is_ok():
		return false
	return wide < limit_squared_wide
