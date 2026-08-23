class_name BattleBaseBodyStats
extends RefCounted

var _body_id: int = 0
var _mass_raw: int = 0
var _radius_raw: int = 0
var _friction_raw: int = 0
var _initialized: bool = false

static func create(body_id: int, mass_raw: int, radius_raw: int, friction_raw: int, status: SimStatus) -> BattleBaseBodyStats:
	var result := BattleBaseBodyStats.new()
	if not status.is_ok(): return result
	if body_id <= 0 or not SimLimits.is_mass_valid(mass_raw) or not SimLimits.is_radius_valid(radius_raw) or friction_raw < 0:
		status.fail(SimStatus.Code.MODIFIER_RANGE_VIOLATION, SimStatus.Operation.BATTLE_PHYSICAL_STATS_APPLY, body_id, 0); return result
	result._body_id = body_id; result._mass_raw = mass_raw; result._radius_raw = radius_raw; result._friction_raw = friction_raw; result._initialized = true; return result
func copy() -> BattleBaseBodyStats:
	var status := SimStatus.new(); return create(_body_id, _mass_raw, _radius_raw, _friction_raw, status) if _initialized else BattleBaseBodyStats.new()
func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func mass_raw() -> int: return _mass_raw
func radius_raw() -> int: return _radius_raw
func friction_multiplier_raw() -> int: return _friction_raw
