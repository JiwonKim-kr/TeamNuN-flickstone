class_name BattleLimits
extends RefCounted

const CT_THRESHOLD: int = 10000
const BASE_SPEED_MIN: int = 50
const BASE_SPEED_MAX: int = 200
const BASE_SPEED_DEFAULT: int = 100
const PREVIEW_DEFAULT_COUNT: int = 10
const PREVIEW_MAX_COUNT: int = 32
const NORMAL_RESOLVE_MAX_TICKS: int = 960
const FORCED_RESOLVE_MAX_TICKS: int = 240
const FORCED_DAMPING_NUMERATOR: int = 3
const FORCED_DAMPING_DENOMINATOR: int = 4


static func valid_base_speed(value: int) -> bool:
	return value >= BASE_SPEED_MIN and value <= BASE_SPEED_MAX
