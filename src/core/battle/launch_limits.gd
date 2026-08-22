class_name LaunchLimits
extends RefCounted

const COMMAND_SCHEMA_VERSION: int = 1
const COMMAND_BYTE_COUNT: int = 6
const ANGLE_STEP: int = 256
const ANGLE_DIRECTION_COUNT: int = 256
const POWER_STEPS: int = 256
const MIN_POWER_STEP: int = 32
const MAX_DRAG_DISTANCE_RAW: int = 192 * FixMath.SCALE
const BASE_MAX_LAUNCH_SPEED_RAW: int = 1536 * FixMath.SCALE
const ABSOLUTE_LAUNCH_SPEED_RAW: int = 2048 * FixMath.SCALE
const REFERENCE_MASS_RAW: int = 64 * FixMath.SCALE
const PREDICTION_MAX_TICKS: int = 240
const PREDICTION_SAMPLE_TICKS: int = 4
const PREDICTION_MAX_POINTS: int = 64
const PREDICTION_MAX_WALL_HITS: int = 2


static func valid_angle(angle: int) -> bool:
	return angle >= 0 and angle <= 0xFFFF


static func valid_quantized_angle(angle: int) -> bool:
	return valid_angle(angle) and angle % ANGLE_STEP == 0


static func valid_power_step(power_step: int) -> bool:
	return power_step >= 0 and power_step <= POWER_STEPS


static func valid_launch_power_step(power_step: int) -> bool:
	return power_step >= MIN_POWER_STEP and power_step <= POWER_STEPS
