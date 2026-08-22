class_name BattleResult
extends RefCounted

enum Value {
	ONGOING = 0,
	PLAYER_VICTORY = 1,
	PLAYER_DEFEAT = 2,
	DRAW = 3,
}

static func is_known(value: int) -> bool:
	return value >= Value.ONGOING and value <= Value.DRAW

static func is_terminal(value: int) -> bool:
	return value >= Value.PLAYER_VICTORY and value <= Value.DRAW
