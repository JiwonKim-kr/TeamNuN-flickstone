class_name BattleDeploymentEntry
extends RefCounted

enum Side { INVALID = 0, PLAYER = 1, ENEMY = 2 }

var _side_id: int = Side.INVALID
var _slot_index: int = 0
var _piece_ref: ContentIdRef
var _enemy_ref: ContentIdRef
var _level: int = 0
var _initialized: bool = false


static func create_player(slot_index: int, piece_ref: ContentIdRef, level: int, status: SimStatus) -> BattleDeploymentEntry:
	return _create(Side.PLAYER, slot_index, piece_ref, null, level, status)


static func create_enemy(slot_index: int, enemy_ref: ContentIdRef, status: SimStatus) -> BattleDeploymentEntry:
	return _create(Side.ENEMY, slot_index, null, enemy_ref, 1, status)


static func _create(side_id: int, slot_index: int, piece_ref: ContentIdRef, enemy_ref: ContentIdRef, level: int, status: SimStatus) -> BattleDeploymentEntry:
	var result := BattleDeploymentEntry.new()
	if not status.is_ok(): return result
	if (
		slot_index < 0 or slot_index > 0xFFFF
		or (side_id == Side.PLAYER and (piece_ref == null or not piece_ref.is_initialized() or enemy_ref != null or level < 1 or level > ContentLimits.PIECE_LEVEL_MAX_COUNT))
		or (side_id == Side.ENEMY and (enemy_ref == null or not enemy_ref.is_initialized() or piece_ref != null or level != 1))
		or (side_id != Side.PLAYER and side_id != Side.ENEMY)
	):
		status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.BATTLE_SETUP_BUILD, side_id, slot_index)
		return result
	result._side_id = side_id; result._slot_index = slot_index; result._level = level
	result._piece_ref = null if piece_ref == null else piece_ref.copy(); result._enemy_ref = null if enemy_ref == null else enemy_ref.copy(); result._initialized = true
	return result


func copy() -> BattleDeploymentEntry:
	if not _initialized: return BattleDeploymentEntry.new()
	var status := SimStatus.new()
	return _create(_side_id, _slot_index, _piece_ref, _enemy_ref, _level, status)


func is_initialized() -> bool: return _initialized
func side_id() -> int: return _side_id
func slot_index() -> int: return _slot_index
func level() -> int: return _level
func piece_ref() -> ContentIdRef: return ContentIdRef.new() if _piece_ref == null else _piece_ref.copy()
func enemy_ref() -> ContentIdRef: return ContentIdRef.new() if _enemy_ref == null else _enemy_ref.copy()
