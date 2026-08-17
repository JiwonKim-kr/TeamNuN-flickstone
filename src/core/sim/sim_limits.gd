class_name SimLimits
extends RefCounted
## Approved P0 physical safety limits, separate from numeric representation.

const POSITION_COMPONENT_LIMIT_RAW: int = 8192 * FixMath.SCALE
const SPEED_MAGNITUDE_LIMIT_RAW: int = 4096 * FixMath.SCALE
const LAUNCH_SPEED_LIMIT_RAW: int = 2048 * FixMath.SCALE
const RADIUS_MIN_RAW: int = 8 * FixMath.SCALE
const RADIUS_MAX_RAW: int = 128 * FixMath.SCALE
const MASS_MIN_RAW: int = FixMath.SCALE
const MASS_MAX_RAW: int = 256 * FixMath.SCALE
const IMPULSE_ABS_LIMIT_RAW: int = 2097152 * FixMath.SCALE

# Worst supported wide intermediates (Q94.32). These equations are the
# executable safety rationale for P0-1 acceptance criterion 8:
#   position dot: 2 * (8192*S)^2 = 2^59
#   speed length:     (4096*S)^2 = 2^56
#   mass * speed: (256*S)*(4096*S) = 2^52
#   impulse * unit: (2097152*S)*S = 2^53
# All remain below INT64_MAX. Squaring two impulses is intentionally unsafe.
const MAX_POSITION_DOT_WIDE: int = (
	2 * POSITION_COMPONENT_LIMIT_RAW * POSITION_COMPONENT_LIMIT_RAW
)
const MAX_SPEED_LENGTH_SQUARED_WIDE: int = (
	SPEED_MAGNITUDE_LIMIT_RAW * SPEED_MAGNITUDE_LIMIT_RAW
)
const MAX_MASS_SPEED_PRODUCT_WIDE: int = MASS_MAX_RAW * SPEED_MAGNITUDE_LIMIT_RAW
const MAX_IMPULSE_UNIT_PRODUCT_WIDE: int = IMPULSE_ABS_LIMIT_RAW * FixMath.ONE_RAW


static func is_position_component_valid(value_raw: int) -> bool:
	return value_raw >= -POSITION_COMPONENT_LIMIT_RAW and value_raw <= POSITION_COMPONENT_LIMIT_RAW


static func is_position_valid(position: FixVec2) -> bool:
	return (
		is_position_component_valid(position.x_raw())
		and is_position_component_valid(position.y_raw())
	)


static func is_speed_valid(velocity: FixVec2, status: SimStatus) -> bool:
	return velocity.is_length_at_most_raw(SPEED_MAGNITUDE_LIMIT_RAW, status)


static func is_launch_speed_valid(velocity: FixVec2, status: SimStatus) -> bool:
	return velocity.is_length_at_most_raw(LAUNCH_SPEED_LIMIT_RAW, status)


static func is_radius_valid(value_raw: int) -> bool:
	return value_raw >= RADIUS_MIN_RAW and value_raw <= RADIUS_MAX_RAW


static func is_mass_valid(value_raw: int) -> bool:
	return value_raw >= MASS_MIN_RAW and value_raw <= MASS_MAX_RAW


static func is_impulse_valid(value_raw: int) -> bool:
	return value_raw >= -IMPULSE_ABS_LIMIT_RAW and value_raw <= IMPULSE_ABS_LIMIT_RAW
