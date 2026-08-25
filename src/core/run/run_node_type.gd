class_name RunNodeType
extends RefCounted

enum Value {
	INVALID = 0,
	NORMAL_BATTLE = 1,
	ELITE_BATTLE = 2,
	SHOP = 3,
	EVENT = 4,
	REST = 5,
	BOSS = 6,
}

static func is_valid(value: int) -> bool:
	return value >= Value.NORMAL_BATTLE and value <= Value.BOSS
