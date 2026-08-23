class_name ModifierKind
extends RefCounted

enum Value {
	INVALID = 0,
	ATTACK = 1,
	SPEED_STAT = 2,
	CRITICAL_BASIS_POINTS = 3,
	DAMAGE_OUTGOING_RATIO_BONUS = 4,
	DAMAGE_INCOMING_RATIO_REDUCTION = 5,
	DAMAGE_FIXED_INCREASE = 6,
	DAMAGE_FIXED_REDUCTION = 7,
	MASS_RAW = 8,
	RADIUS_RAW = 9,
	FRICTION_MULTIPLIER_RAW = 10,
}

enum Operation { INVALID = 0, ADD = 1, RATIO_BASIS_POINTS = 2 }
enum ValueMode { INVALID = 0, FLAT = 1, SCALED = 2 }

static func is_known(value: int) -> bool: return value >= Value.ATTACK and value <= Value.FRICTION_MULTIPLIER_RAW
static func is_damage_modifier(value: int) -> bool: return value >= Value.DAMAGE_OUTGOING_RATIO_BONUS and value <= Value.DAMAGE_FIXED_REDUCTION
static func is_physical(value: int) -> bool: return value >= Value.MASS_RAW and value <= Value.FRICTION_MULTIPLIER_RAW
static func supports_operation(kind_id: int, operation_id: int) -> bool:
	if not is_known(kind_id): return false
	if is_damage_modifier(kind_id): return operation_id == Operation.ADD
	return operation_id == Operation.ADD or operation_id == Operation.RATIO_BASIS_POINTS
