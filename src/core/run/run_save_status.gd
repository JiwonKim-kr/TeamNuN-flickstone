class_name RunSaveStatus
extends RefCounted

enum Code {
	OK = 0,
	NOT_FOUND = 1,
	IO_ERROR = 2,
	SNAPSHOT_REJECTED = 3,
	REPLACE_FAILED = 4,
}

enum Operation {
	NONE = 0,
	PROBE = 1,
	READ = 2,
	WRITE_TEMP = 3,
	VERIFY_TEMP = 4,
	ROTATE_OLD = 5,
	COMMIT_TEMP = 6,
	RECOVER_BACKUP = 7,
	CLEANUP = 8,
}

var _code: int = Code.OK
var _operation: int = Operation.NONE
var _detail_a: int = 0
var _detail_b: int = 0
var _sim_code: int = SimStatus.Code.OK
var _sim_operation: int = SimStatus.Operation.NONE
var _sim_detail_a: int = 0
var _sim_detail_b: int = 0

func is_ok() -> bool: return _code == Code.OK
func code() -> int: return _code
func operation() -> int: return _operation
func detail_a() -> int: return _detail_a
func detail_b() -> int: return _detail_b
func sim_code() -> int: return _sim_code
func sim_operation() -> int: return _sim_operation
func sim_detail_a() -> int: return _sim_detail_a
func sim_detail_b() -> int: return _sim_detail_b

func fail(code: int, operation: int, detail_a: int = 0, detail_b: int = 0) -> void:
	if not is_ok(): return
	_code = code
	_operation = operation
	_detail_a = detail_a
	_detail_b = detail_b

func fail_snapshot(operation: int, sim_status: SimStatus) -> void:
	if not is_ok(): return
	_code = Code.SNAPSHOT_REJECTED
	_operation = operation
	if sim_status != null:
		_sim_code = sim_status.code()
		_sim_operation = sim_status.operation()
		_sim_detail_a = sim_status.detail_a()
		_sim_detail_b = sim_status.detail_b()

func copy() -> RunSaveStatus:
	var result := RunSaveStatus.new()
	result._code = _code
	result._operation = _operation
	result._detail_a = _detail_a
	result._detail_b = _detail_b
	result._sim_code = _sim_code
	result._sim_operation = _sim_operation
	result._sim_detail_a = _sim_detail_a
	result._sim_detail_b = _sim_detail_b
	return result
