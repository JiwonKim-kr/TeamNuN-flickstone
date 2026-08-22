class_name BattleMotionCredit
extends RefCounted

var _initialized: bool = false
var _body_id: int = 0
var _root_body_id: int = 0
var _root_faction: int = BattleParticipant.Faction.INVALID
var _source_sim_sequence: int = 0
var _tick: int = 0

static func create(body_id: int, root_body_id: int, root_faction: int, source_sim_sequence: int, tick: int, status: SimStatus) -> BattleMotionCredit:
	var result := BattleMotionCredit.new()
	if not status.is_ok(): return result
	if body_id <= 0 or root_body_id <= 0 or not UInt32Math.is_u32(body_id) or not UInt32Math.is_u32(root_body_id) or not UInt32Math.is_u32(source_sim_sequence) or tick < 0 or (root_faction != BattleParticipant.Faction.PLAYER and root_faction != BattleParticipant.Faction.ENEMY and root_faction != BattleParticipant.Faction.NEUTRAL):
		status.fail(SimStatus.Code.INVALID_MOTION_CREDIT, SimStatus.Operation.BATTLE_MOTION_CREDIT, body_id, root_body_id)
		return result
	result._initialized = true; result._body_id = body_id; result._root_body_id = root_body_id
	result._root_faction = root_faction; result._source_sim_sequence = source_sim_sequence; result._tick = tick
	return result

func copy() -> BattleMotionCredit:
	var result := BattleMotionCredit.new()
	result._initialized = _initialized; result._body_id = _body_id; result._root_body_id = _root_body_id
	result._root_faction = _root_faction; result._source_sim_sequence = _source_sim_sequence; result._tick = _tick
	return result

func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func root_body_id() -> int: return _root_body_id
func root_faction() -> int: return _root_faction
func source_sim_sequence() -> int: return _source_sim_sequence
func tick() -> int: return _tick
