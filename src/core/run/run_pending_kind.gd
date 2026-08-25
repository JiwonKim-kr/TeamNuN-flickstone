class_name RunPendingKind
extends RefCounted

enum Value {
	INVALID = 0,
	NONE = 1,
	REWARD = 2,
	SHOP = 3,
	EVENT = 4,
	REST = 5,
}

static func is_valid(value: int) -> bool:
	return value >= Value.NONE and value <= Value.REST
