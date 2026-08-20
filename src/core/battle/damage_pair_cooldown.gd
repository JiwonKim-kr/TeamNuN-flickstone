class_name DamagePairCooldown
extends RefCounted

var _low_body_id: int = 0
var _high_body_id: int = 0
var _next_allowed_tick: int = 0
var _initialized: bool = false


static func create(
		low_body_id: int,
		high_body_id: int,
		next_allowed_tick: int,
		status: SimStatus
) -> DamagePairCooldown:
	var result := DamagePairCooldown.new()
	if not status.is_ok():
		return result
	if (
		low_body_id == 0
		or low_body_id >= high_body_id
		or not UInt32Math.is_u32(low_body_id)
		or not UInt32Math.is_u32(high_body_id)
		or next_allowed_tick < 0
	):
		status.fail(
			SimStatus.Code.INVALID_DAMAGE_CONTEXT,
			SimStatus.Operation.BATTLE_COOLDOWN_UPDATE,
			low_body_id,
			high_body_id
		)
		return result
	result._low_body_id = low_body_id
	result._high_body_id = high_body_id
	result._next_allowed_tick = next_allowed_tick
	result._initialized = true
	return result


func copy() -> DamagePairCooldown:
	if not _initialized:
		return DamagePairCooldown.new()
	var status := SimStatus.new()
	return create(_low_body_id, _high_body_id, _next_allowed_tick, status)


func is_initialized() -> bool: return _initialized
func low_body_id() -> int: return _low_body_id
func high_body_id() -> int: return _high_body_id
func next_allowed_tick() -> int: return _next_allowed_tick
func is_ready(tick: int) -> bool: return tick >= _next_allowed_tick
