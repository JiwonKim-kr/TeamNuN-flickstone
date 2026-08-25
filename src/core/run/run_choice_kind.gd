class_name RunChoiceKind
extends RefCounted

enum Value {
	INVALID = 0,
	RECRUIT_PIECE = 1,
	TAKE_RELIC = 2,
	TAKE_CONSUMABLE = 3,
	GAIN_GOLD = 4,
	RECOVER_LIFE = 5,
	MERGE_PIECES = 6,
	EVENT_OPTION = 7,
	TAKE_REVENGE = 8,
	LEAVE_SHOP = 9,
}

static func is_valid(value: int) -> bool:
	return value >= Value.RECRUIT_PIECE and value <= Value.LEAVE_SHOP
