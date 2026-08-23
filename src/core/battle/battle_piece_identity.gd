class_name BattlePieceIdentity
extends RefCounted

var _body_id: int = 0
var _piece_numeric_id: int = 0
var _level: int = 0
var _faction: int = 0
var _is_token: bool = false
var _initialized: bool = false

static func create(body_id: int, piece_numeric_id: int, level: int, faction: int, is_token: bool, status: SimStatus) -> BattlePieceIdentity:
	var result := BattlePieceIdentity.new()
	if not status.is_ok(): return result
	if body_id <= 0 or piece_numeric_id <= 0 or level < 1 or level > ContentLimits.PIECE_LEVEL_MAX_COUNT or faction < BattleParticipant.Faction.PLAYER or faction > BattleParticipant.Faction.NEUTRAL:
		status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, body_id, piece_numeric_id); return result
	result._body_id = body_id; result._piece_numeric_id = piece_numeric_id; result._level = level; result._faction = faction; result._is_token = is_token; result._initialized = true; return result
func copy() -> BattlePieceIdentity:
	var status := SimStatus.new(); return create(_body_id, _piece_numeric_id, _level, _faction, _is_token, status) if _initialized else BattlePieceIdentity.new()
func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func piece_numeric_id() -> int: return _piece_numeric_id
func level() -> int: return _level
func faction() -> int: return _faction
func is_token() -> bool: return _is_token
