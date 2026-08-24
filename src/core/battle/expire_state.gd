class_name ExpireState
extends RefCounted

var _body_id: int = 0
var _kind_id: int = PieceDefinition.ExpireKind.INVALID
var _remaining: int = 0
var _applied_turn_index: int = 0
var _has_linked: bool = false
var _initialized: bool = false

static func create(body_id: int, kind_id: int, remaining: int, applied_turn_index: int, has_linked: bool, status: SimStatus) -> ExpireState:
	var result := ExpireState.new()
	if not status.is_ok(): return result
	if body_id == 0 or not UInt32Math.is_u32(body_id) or kind_id < PieceDefinition.ExpireKind.NONE or kind_id > PieceDefinition.ExpireKind.ON_LINK_RELEASE or applied_turn_index < 0 or not UInt32Math.is_u32(applied_turn_index) or (kind_id == PieceDefinition.ExpireKind.NONE and remaining != 0) or (kind_id == PieceDefinition.ExpireKind.AFTER_TURNS and (remaining < 1 or remaining > 1024)) or (kind_id == PieceDefinition.ExpireKind.AFTER_COLLISIONS and (remaining < 1 or remaining > 255)) or (kind_id == PieceDefinition.ExpireKind.ON_LINK_RELEASE and remaining != 0):
		status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_EXPIRE, body_id, kind_id); return result
	result._body_id = body_id; result._kind_id = kind_id; result._remaining = remaining; result._applied_turn_index = applied_turn_index; result._has_linked = has_linked; result._initialized = true
	return result

func copy() -> ExpireState:
	if not _initialized: return ExpireState.new()
	var status := SimStatus.new(); return create(_body_id, _kind_id, _remaining, _applied_turn_index, _has_linked, status)
func with_remaining(value: int, status: SimStatus) -> ExpireState: return create(_body_id, _kind_id, value, _applied_turn_index, _has_linked, status)
func with_has_linked(status: SimStatus) -> ExpireState: return create(_body_id, _kind_id, _remaining, _applied_turn_index, true, status)
func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func kind_id() -> int: return _kind_id
func remaining() -> int: return _remaining
func applied_turn_index() -> int: return _applied_turn_index
func has_linked() -> bool: return _has_linked
