class_name BattlePieceOrigin
extends RefCounted

var _body_id: int = 0
var _original_piece_numeric_id: int = 0
var _initialized: bool = false

static func create(body_id: int, original_piece_numeric_id: int, status: SimStatus) -> BattlePieceOrigin:
	var result := BattlePieceOrigin.new()
	if not status.is_ok(): return result
	if body_id == 0 or original_piece_numeric_id == 0 or not UInt32Math.is_u32(body_id) or not UInt32Math.is_u32(original_piece_numeric_id):
		status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, body_id, original_piece_numeric_id); return result
	result._body_id = body_id; result._original_piece_numeric_id = original_piece_numeric_id; result._initialized = true; return result
func copy() -> BattlePieceOrigin:
	if not _initialized: return BattlePieceOrigin.new()
	var status := SimStatus.new(); return create(_body_id, _original_piece_numeric_id, status)
func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func original_piece_numeric_id() -> int: return _original_piece_numeric_id
