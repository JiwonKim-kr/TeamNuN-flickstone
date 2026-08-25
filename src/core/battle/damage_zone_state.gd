class_name DamageZoneState
extends RefCounted

var _zone_id: int = 0
var _turn_start_damage: int = 0
var _initialized: bool = false

static func create(zone_id: int, turn_start_damage: int, status: SimStatus) -> DamageZoneState:
	var result := DamageZoneState.new()
	if not status.is_ok(): return result
	if zone_id <= 0 or not UInt32Math.is_u32(zone_id) or turn_start_damage <= 0:
		status.fail(SimStatus.Code.INVALID_DAMAGE_ZONE_STATE, SimStatus.Operation.BATTLE_DAMAGE_ZONE_UPDATE, zone_id, turn_start_damage)
		return result
	result._zone_id = zone_id
	result._turn_start_damage = turn_start_damage
	result._initialized = true
	return result

func copy() -> DamageZoneState:
	if not _initialized: return DamageZoneState.new()
	var status := SimStatus.new()
	return create(_zone_id, _turn_start_damage, status)

func is_initialized() -> bool: return _initialized
func zone_id() -> int: return _zone_id
func turn_start_damage() -> int: return _turn_start_damage
