class_name DamageLimits
extends RefCounted

const STAT_MAX: int = 1000000
const CRITICAL_BASIS_POINTS_DENOMINATOR: int = 10000

const DAMAGE_REFERENCE_SPEED_RAW: int = 1024 * FixMath.SCALE
const DAMAGE_THRESHOLD_SPEED_RAW: int = 64 * FixMath.SCALE
const MAX_APPROACH_SPEED_RAW: int = 8192 * FixMath.SCALE

const WEIGHT_RATIO_MIN_RAW: int = FixMath.SCALE / 2
const WEIGHT_RATIO_MAX_RAW: int = FixMath.SCALE * 2

const FRIENDLY_DAMAGE_NUMERATOR: int = 1
const FRIENDLY_DAMAGE_DENOMINATOR: int = 2
const CRITICAL_DAMAGE_NUMERATOR: int = 2
const CRITICAL_DAMAGE_DENOMINATOR: int = 1

const RECOLLISION_COOLDOWN_TICKS: int = 12


static func valid_stat(value: int) -> bool:
	return value >= 1 and value <= STAT_MAX


static func valid_critical_basis_points(value: int) -> bool:
	return value >= 0 and value <= CRITICAL_BASIS_POINTS_DENOMINATOR
