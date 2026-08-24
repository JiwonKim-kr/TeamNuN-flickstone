class_name ZoneSpawnState
extends RefCounted

var _zone_id: int = 0
var _remaining_turns: int = 0
var _applied_turn_index: int = 0
var _initialized: bool = false


static func create(zone_id: int, remaining_turns: int, applied_turn_index: int, status: SimStatus) -> ZoneSpawnState:
	var result := ZoneSpawnState.new()
	if not status.is_ok(): return result
	if zone_id <= 0 or not UInt32Math.is_u32(zone_id) or remaining_turns < 0 or remaining_turns > ContentLimits.ZONE_DURATION_MAX_TURNS or applied_turn_index < 0:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_ZONE_SPAWN, zone_id, remaining_turns); return result
	result._zone_id = zone_id; result._remaining_turns = remaining_turns; result._applied_turn_index = applied_turn_index; result._initialized = true
	return result


func copy() -> ZoneSpawnState:
	if not _initialized: return ZoneSpawnState.new()
	var status := SimStatus.new()
	return create(_zone_id, _remaining_turns, _applied_turn_index, status)


func with_remaining(value: int, status: SimStatus) -> ZoneSpawnState:
	return create(_zone_id, value, _applied_turn_index, status)


func is_initialized() -> bool: return _initialized
func zone_id() -> int: return _zone_id
func remaining_turns() -> int: return _remaining_turns
func applied_turn_index() -> int: return _applied_turn_index
