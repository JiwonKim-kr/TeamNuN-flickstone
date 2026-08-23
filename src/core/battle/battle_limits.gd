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
const TRIGGER_MAX_WAVES: int = 32
const TRIGGER_MAX_RECORDS: int = 4096
const EFFECT_MAX_INVOCATIONS: int = 2048
const EFFECT_MAX_APPLICATIONS: int = 8192
const EFFECT_CT_MAX: int = CT_THRESHOLD * 2


static func valid_base_speed(value: int) -> bool:
	return value >= BASE_SPEED_MIN and value <= BASE_SPEED_MAX
