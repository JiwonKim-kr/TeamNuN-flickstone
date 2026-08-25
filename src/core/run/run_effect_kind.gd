class_name RunEffectKind
extends RefCounted

enum Value {
	INVALID = 0,
	GAIN_GOLD = 1,
	RECOVER_LIFE = 2,
	GAIN_CONSUMABLE = 3,
	VICTORY_GOLD_BONUS = 4,
}

static func is_valid(value: int) -> bool:
	return value >= Value.GAIN_GOLD and value <= Value.VICTORY_GOLD_BONUS
