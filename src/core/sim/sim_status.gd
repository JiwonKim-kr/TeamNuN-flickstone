class_name SimStatus
extends RefCounted
## Release-safe, first-error-wins status for deterministic simulation work.
##
## Checked operations return neutral values after latching an error. A caller
## must compute into a temporary step buffer and commit authoritative state only
## when `is_ok()` remains true. Keeping diagnostics numeric makes this status
## safe to copy into deterministic failure reports without dynamic payloads.

# Deterministic diagnostic IDs may be persisted in failure reports. Never
# reorder or reuse a value; new IDs are appended with an explicit number.
enum Code {
	OK = 0,
	INVALID_ARGUMENT = 1,
	INVALID_RANGE = 2,
	INT64_OVERFLOW = 3,
	DIVISION_BY_ZERO = 4,
	NEGATIVE_SQRT = 5,
	ZERO_LENGTH = 6,
	INVALID_RNG_STATE = 7,
	RNG_COUNTER_OVERFLOW = 8,
}

enum Operation {
	NONE = 0,
	FIX_FROM_INT = 1,
	FIX_FROM_RATIO = 2,
	FIX_ADD = 3,
	FIX_SUB = 4,
	FIX_NEGATE = 5,
	FIX_ABS = 6,
	FIX_INT_MUL = 7,
	FIX_MUL = 8,
	FIX_DIV = 9,
	FIX_ROUND_DIV = 10,
	FIX_TRUNC_DIV = 11,
	FIX_FLOOR_DIV = 12,
	FIX_CEIL_DIV = 13,
	FIX_CLAMP = 14,
	FIX_SQRT = 15,
	VEC_DOT = 16,
	VEC_LENGTH = 17,
	VEC_NORMALIZE = 18,
	VEC_LENGTH_COMPARE = 19,
	LUT_SAMPLE = 20,
	U32_ADD = 21,
	U32_MULTIPLY = 22,
	U32_ROTATE = 23,
	RNG_COPY = 24,
	RNG_DERIVE = 25,
	RNG_RESTORE = 26,
	RNG_STATE_READ = 27,
	RNG_DRAW = 28,
	RNG_RANGE = 29,
	RNG_CHANCE = 30,
}

var _code: int = Code.OK
var _operation: int = Operation.NONE
var _detail_a: int = 0
var _detail_b: int = 0


func is_ok() -> bool:
	return _code == Code.OK


func code() -> int:
	return _code


func operation() -> int:
	return _operation


func detail_a() -> int:
	return _detail_a


func detail_b() -> int:
	return _detail_b


func fail(
		p_code: int,
		p_operation: int,
		p_detail_a: int = 0,
		p_detail_b: int = 0
) -> void:
	if not is_ok():
		return
	_code = p_code
	_operation = p_operation
	_detail_a = p_detail_a
	_detail_b = p_detail_b


func copy() -> SimStatus:
	var result: SimStatus = SimStatus.new()
	result._code = _code
	result._operation = _operation
	result._detail_a = _detail_a
	result._detail_b = _detail_b
	return result
