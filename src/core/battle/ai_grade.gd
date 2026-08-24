class_name AiGrade
extends RefCounted

enum Value { INVALID = 0, COMMON = 1, ELITE = 2, BOSS = 3 }

static func is_known(value: int) -> bool:
	return value >= Value.COMMON and value <= Value.BOSS

static func angle_error_limit(value: int) -> int:
	match value:
		Value.COMMON: return 4096
		Value.ELITE: return 2048
		Value.BOSS: return 1024
		_: return 0

static func power_error_limit(value: int) -> int:
	match value:
		Value.COMMON: return 64
		Value.ELITE: return 32
		Value.BOSS: return 16
		_: return 0
