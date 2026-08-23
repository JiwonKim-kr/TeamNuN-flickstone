class_name EffectiveStats
extends RefCounted

static func _minimum(kind_id: int) -> int:
	match kind_id:
		ModifierKind.Value.ATTACK: return 1
		ModifierKind.Value.SPEED_STAT: return 1
		ModifierKind.Value.CRITICAL_BASIS_POINTS: return 0
		ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, ModifierKind.Value.DAMAGE_INCOMING_RATIO_REDUCTION, ModifierKind.Value.DAMAGE_FIXED_INCREASE, ModifierKind.Value.DAMAGE_FIXED_REDUCTION: return 0
		ModifierKind.Value.MASS_RAW: return SimLimits.MASS_MIN_RAW
		ModifierKind.Value.RADIUS_RAW: return SimLimits.RADIUS_MIN_RAW
		ModifierKind.Value.FRICTION_MULTIPLIER_RAW: return 0
	return 0

static func _maximum(kind_id: int) -> int:
	match kind_id:
		ModifierKind.Value.ATTACK, ModifierKind.Value.DAMAGE_FIXED_INCREASE, ModifierKind.Value.DAMAGE_FIXED_REDUCTION: return DamageLimits.STAT_MAX
		ModifierKind.Value.SPEED_STAT: return 2000
		ModifierKind.Value.CRITICAL_BASIS_POINTS, ModifierKind.Value.DAMAGE_INCOMING_RATIO_REDUCTION: return 10000
		ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS: return 100000
		ModifierKind.Value.MASS_RAW: return SimLimits.MASS_MAX_RAW
		ModifierKind.Value.RADIUS_RAW: return SimLimits.RADIUS_MAX_RAW
		ModifierKind.Value.FRICTION_MULTIPLIER_RAW: return 9223372036854775807
	return 0

static func resolve(base_value: int, aggregate: ModifierAggregate, kind_id: int, status: SimStatus) -> int:
	if not status.is_ok(): return 0
	if aggregate == null or not aggregate.is_initialized() or aggregate.kind_id() != kind_id:
		status.fail(SimStatus.Code.INVALID_MODIFIER_DEFINITION, SimStatus.Operation.EFFECTIVE_STAT_RESOLVE, kind_id, 0); return 0
	var value: int = FixMath.add_raw(base_value, aggregate.sum_add(), status)
	var ratio: int = FixMath.add_raw(10000, aggregate.sum_ratio(), status)
	var numerator: int = FixMath.multiply_int(value, ratio, status)
	value = FixMath.round_div_int(numerator, 10000, status)
	if not status.is_ok(): return 0
	var low: int = _minimum(kind_id); var high: int = _maximum(kind_id)
	if ModifierKind.is_physical(kind_id):
		if value < low or value > high: status.fail(SimStatus.Code.MODIFIER_RANGE_VIOLATION, SimStatus.Operation.EFFECTIVE_STAT_RESOLVE, kind_id, value); return 0
		return value
	return clampi(value, low, high)
