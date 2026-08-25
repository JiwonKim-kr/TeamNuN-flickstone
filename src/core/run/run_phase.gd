class_name RunPhase
extends RefCounted

enum Value {
	INVALID = 0,
	MAP_CHOICE = 1,
	FORMATION = 2,
	BATTLE = 3,
	REWARD = 4,
	SHOP = 5,
	EVENT = 6,
	REST = 7,
	ACT_COMPLETE = 8,
	RUN_COMPLETE = 9,
	RUN_FAILED = 10,
}

static func is_valid(value: int) -> bool:
	return value >= Value.MAP_CHOICE and value <= Value.RUN_FAILED
