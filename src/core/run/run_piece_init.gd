class_name RunPieceInit
extends RefCounted

var _initial_key: int = 0
var _piece_numeric_id: int = 0
var _level: int = 0
var _counters: Array[RunCounter] = []
var _initialized: bool = false

static func create(initial_key: int, piece_numeric_id: int, level: int, counters: Array[RunCounter], status: SimStatus) -> RunPieceInit:
	var result := RunPieceInit.new()
	if not status.is_ok(): return result
	if initial_key <= 0 or initial_key > 0xFFFFFFFF or piece_numeric_id <= 0 or piece_numeric_id > 0xFFFFFFFF or level < 1 or level > 3 or counters.size() > RunLimits.MAX_COUNTERS_PER_PIECE:
		status.fail(SimStatus.Code.INVALID_RUN_PIECE_INSTANCE, SimStatus.Operation.RUN_PIECE_INIT_CREATE, initial_key, piece_numeric_id)
		return result
	var previous_kind: int = 0
	for counter: RunCounter in counters:
		if counter == null or not counter.is_initialized() or counter.kind_id() <= previous_kind:
			status.fail(SimStatus.Code.INVALID_RUN_COUNTER, SimStatus.Operation.RUN_PIECE_INIT_CREATE, previous_kind, 0 if counter == null else counter.kind_id())
			return RunPieceInit.new()
		result._counters.append(counter.copy()); previous_kind = counter.kind_id()
	result._initial_key = initial_key; result._piece_numeric_id = piece_numeric_id; result._level = level; result._initialized = true
	return result

func copy() -> RunPieceInit:
	var result := RunPieceInit.new()
	result._initial_key = _initial_key; result._piece_numeric_id = _piece_numeric_id; result._level = _level
	for counter: RunCounter in _counters: result._counters.append(counter.copy())
	result._initialized = _initialized
	return result

func is_initialized() -> bool: return _initialized
func initial_key() -> int: return _initial_key
func piece_numeric_id() -> int: return _piece_numeric_id
func level() -> int: return _level
func counter_count() -> int: return _counters.size()
func counter_at(index: int, status: SimStatus) -> RunCounter:
	if not status.is_ok(): return RunCounter.new()
	if index < 0 or index >= _counters.size():
		status.fail(SimStatus.Code.INVALID_RUN_COUNTER, SimStatus.Operation.RUN_PIECE_INIT_CREATE, index, _counters.size()); return RunCounter.new()
	return _counters[index].copy()
