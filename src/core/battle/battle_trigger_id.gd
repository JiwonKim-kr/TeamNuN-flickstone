class_name BattleTriggerId
extends RefCounted
## Append-only P1 battle trigger vocabulary.
##
## PASSIVE is a registration mode evaluated at approved mutation barriers. It
## is intentionally not an event record. Candidate trigger names are not
## reserved until their design is approved.

enum Value {
	INVALID = 0,
	PASSIVE = 1,
	ON_BATTLE_START = 2,
	ON_TURN_START = 3,
	ON_LAUNCH = 4,
	ON_HIT_DEAL = 5,
	ON_HIT_TAKE = 6,
	ON_ALLY_COLLIDE = 7,
	ON_WALL_BOUNCE = 8,
	ON_MOVING = 9,
	ON_DEATH_SELF = 10,
	ON_KILL = 11,
	ON_TURN_END = 12,
	ON_BATTLE_END = 13,
}


static func is_known(value: int) -> bool:
	return value >= Value.PASSIVE and value <= Value.ON_BATTLE_END


static func is_record_trigger(value: int) -> bool:
	return value >= Value.ON_BATTLE_START and value <= Value.ON_BATTLE_END
