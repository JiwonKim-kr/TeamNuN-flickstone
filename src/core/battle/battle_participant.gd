class_name BattleParticipant
extends RefCounted

enum Faction {
	INVALID = 0,
	PLAYER = 1,
	ENEMY = 2,
	NEUTRAL = 3,
}

var _body_id: int = 0
var _faction: int = Faction.INVALID
var _has_turn: bool = false
var _controllable: bool = false
var _counts_for_victory: bool = false
var _speed_stat: int = 0
var _ct: int = 0
var _initialized: bool = false


static func _valid_flags(
		faction: int, has_turn: bool, controllable: bool, counts_for_victory: bool
) -> bool:
	if faction == Faction.NEUTRAL:
		return not has_turn and not controllable and not counts_for_victory
	if faction != Faction.PLAYER and faction != Faction.ENEMY:
		return false
	if controllable and (faction != Faction.PLAYER or not has_turn):
		return false
	return true


static func _build(
		body_id: int,
		faction: int,
		has_turn: bool,
		controllable: bool,
		counts_for_victory: bool,
		speed_stat: int,
		ct: int
) -> BattleParticipant:
	var result := BattleParticipant.new()
	result._body_id = body_id
	result._faction = faction
	result._has_turn = has_turn
	result._controllable = controllable
	result._counts_for_victory = counts_for_victory
	result._speed_stat = speed_stat
	result._ct = ct
	result._initialized = true
	return result


static func _create_checked(
		body_id: int,
		allow_unassigned: bool,
		faction: int,
		has_turn: bool,
		controllable: bool,
		counts_for_victory: bool,
		speed_stat: int,
		ct: int,
		status: SimStatus
) -> BattleParticipant:
	if not status.is_ok():
		return BattleParticipant.new()
	if (
		not UInt32Math.is_u32(body_id)
		or (body_id == 0 and not allow_unassigned)
		or not _valid_flags(faction, has_turn, controllable, counts_for_victory)
		or not BattleLimits.valid_base_speed(speed_stat)
		or ct < 0
		or (not has_turn and ct != 0)
	):
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.PARTICIPANT_CREATE, body_id, speed_stat)
		return BattleParticipant.new()
	return _build(body_id, faction, has_turn, controllable, counts_for_victory, speed_stat, ct)


static func create(
		body_id: int,
		faction: int,
		has_turn: bool,
		controllable: bool,
		counts_for_victory: bool,
		speed_stat: int,
		status: SimStatus
) -> BattleParticipant:
	return _create_checked(body_id, false, faction, has_turn, controllable, counts_for_victory, speed_stat, 0, status)


static func create_unassigned(
		faction: int,
		has_turn: bool,
		controllable: bool,
		counts_for_victory: bool,
		speed_stat: int,
		status: SimStatus
) -> BattleParticipant:
	return _create_checked(0, true, faction, has_turn, controllable, counts_for_victory, speed_stat, 0, status)


static func restore(
		body_id: int,
		faction: int,
		has_turn: bool,
		controllable: bool,
		counts_for_victory: bool,
		speed_stat: int,
		ct: int,
		status: SimStatus
) -> BattleParticipant:
	return _create_checked(body_id, false, faction, has_turn, controllable, counts_for_victory, speed_stat, ct, status)


func assigned_copy(body_id: int, status: SimStatus) -> BattleParticipant:
	if _body_id != 0:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.PARTICIPANT_CREATE, _body_id, body_id)
		return BattleParticipant.new()
	return _create_checked(body_id, false, _faction, _has_turn, _controllable, _counts_for_victory, _speed_stat, 0, status)


func copy() -> BattleParticipant:
	if not _initialized:
		return BattleParticipant.new()
	return _build(_body_id, _faction, _has_turn, _controllable, _counts_for_victory, _speed_stat, _ct)


func with_ct(value: int, status: SimStatus) -> BattleParticipant:
	return _create_checked(_body_id, false, _faction, _has_turn, _controllable, _counts_for_victory, _speed_stat, value, status)


func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func faction() -> int: return _faction
func has_turn() -> bool: return _has_turn
func controllable() -> bool: return _controllable
func counts_for_victory() -> bool: return _counts_for_victory
func speed_stat() -> int: return _speed_stat
func ct() -> int: return _ct
