class_name StatusInstance
extends RefCounted

var _status_numeric_id: int = 0
var _target_body_id: int = 0
var _source_body_id: int = 0
var _stacks: int = 0
var _remaining: int = 0
var _applied_turn_index: int = 0
var _application_sequence: int = 0
var _initialized: bool = false

static func create(status_numeric_id: int, target_body_id: int, source_body_id: int, stacks: int, remaining: int, applied_turn_index: int, application_sequence: int, status: SimStatus) -> StatusInstance:
	var result := StatusInstance.new()
	if not status.is_ok(): return result
	if status_numeric_id <= 0 or target_body_id <= 0 or source_body_id <= 0 or stacks < 1 or stacks > ContentLimits.STATUS_MAX_STACKS or remaining < 0 or applied_turn_index < 0 or application_sequence <= 0:
		status.fail(SimStatus.Code.INVALID_STATUS_INSTANCE, SimStatus.Operation.STATUS_APPLY, target_body_id, status_numeric_id); return result
	result._status_numeric_id = status_numeric_id; result._target_body_id = target_body_id; result._source_body_id = source_body_id; result._stacks = stacks; result._remaining = remaining; result._applied_turn_index = applied_turn_index; result._application_sequence = application_sequence; result._initialized = true; return result

func copy() -> StatusInstance:
	var status := SimStatus.new(); return create(_status_numeric_id, _target_body_id, _source_body_id, _stacks, _remaining, _applied_turn_index, _application_sequence, status) if _initialized else StatusInstance.new()
func with_values(stacks: int, remaining: int, applied_turn_index: int, status: SimStatus) -> StatusInstance: return create(_status_numeric_id, _target_body_id, _source_body_id, stacks, remaining, applied_turn_index, _application_sequence, status)
func is_initialized() -> bool: return _initialized
func status_numeric_id() -> int: return _status_numeric_id
func target_body_id() -> int: return _target_body_id
func source_body_id() -> int: return _source_body_id
func stacks() -> int: return _stacks
func remaining() -> int: return _remaining
func applied_turn_index() -> int: return _applied_turn_index
func application_sequence() -> int: return _application_sequence
