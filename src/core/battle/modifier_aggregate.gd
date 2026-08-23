class_name ModifierAggregate
extends RefCounted

var _kind_id: int = 0
var _sum_add: int = 0
var _sum_ratio: int = 0
var _initialized: bool = false

static func create(kind_id: int, sum_add: int, sum_ratio: int, status: SimStatus) -> ModifierAggregate:
	var result := ModifierAggregate.new()
	if not status.is_ok(): return result
	if not ModifierKind.is_known(kind_id) or (ModifierKind.is_damage_modifier(kind_id) and sum_ratio != 0): status.fail(SimStatus.Code.INVALID_MODIFIER_DEFINITION, SimStatus.Operation.MODIFIER_AGGREGATE, kind_id, sum_ratio); return result
	result._kind_id = kind_id; result._sum_add = sum_add; result._sum_ratio = sum_ratio; result._initialized = true; return result
func copy() -> ModifierAggregate:
	var status := SimStatus.new(); return create(_kind_id, _sum_add, _sum_ratio, status) if _initialized else ModifierAggregate.new()
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func sum_add() -> int: return _sum_add
func sum_ratio() -> int: return _sum_ratio
