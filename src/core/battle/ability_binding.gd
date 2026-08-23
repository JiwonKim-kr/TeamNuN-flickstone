class_name AbilityBinding
extends RefCounted

var _owner_body_id: int = 0
var _ability_numeric_id: int = 0
var _initialized: bool = false

static func create(owner_body_id: int, ability_numeric_id: int, status: SimStatus) -> AbilityBinding:
	var result := AbilityBinding.new()
	if not status.is_ok(): return result
	if not UInt32Math.is_u32(owner_body_id) or owner_body_id == 0 or not UInt32Math.is_u32(ability_numeric_id) or ability_numeric_id == 0:
		status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.ABILITY_BIND, owner_body_id, ability_numeric_id); return result
	result._owner_body_id = owner_body_id; result._ability_numeric_id = ability_numeric_id; result._initialized = true
	return result

func copy() -> AbilityBinding:
	var status := SimStatus.new(); return create(_owner_body_id, _ability_numeric_id, status) if _initialized else AbilityBinding.new()
func is_initialized() -> bool: return _initialized
func owner_body_id() -> int: return _owner_body_id
func ability_numeric_id() -> int: return _ability_numeric_id
