class_name RunCounterKind
extends RefCounted

enum Value {
	INVALID = 0,
	BATTLES_SURVIVED = 1,
	KILLS = 2,
}

static func is_valid(value: int) -> bool:
	return value == Value.BATTLES_SURVIVED or value == Value.KILLS
