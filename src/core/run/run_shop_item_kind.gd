class_name RunShopItemKind
extends RefCounted

enum Value {
	INVALID = 0,
	RELIC = 1,
	CONSUMABLE = 2,
}

static func is_valid(value: int) -> bool:
	return value == Value.RELIC or value == Value.CONSUMABLE
