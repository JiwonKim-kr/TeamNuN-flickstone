class_name FixMath
extends RefCounted
## Release-safe deterministic Q47.16 scalar arithmetic.
##
## Every operation that can fail receives a caller-owned `SimStatus`. The first
## error is latched and later operations become no-ops returning neutral values.
## Authoritative state must be committed only after the status remains OK.

const FRACTION_BITS: int = 16
const SCALE: int = 1 << FRACTION_BITS
const HALF_RAW: int = SCALE >> 1
const ZERO_RAW: int = 0
const ONE_RAW: int = SCALE

const INT64_MAX: int = 9223372036854775807
const INT64_MIN: int = -9223372036854775807 - 1


static func compare_raw(a_raw: int, b_raw: int) -> int:
	if a_raw < b_raw:
		return -1
	if a_raw > b_raw:
		return 1
	return 0


static func sign_raw(value_raw: int) -> int:
	return compare_raw(value_raw, 0)


static func can_add_int(a: int, b: int) -> bool:
	if b > 0:
		return a <= INT64_MAX - b
	if b < 0:
		return a >= INT64_MIN - b
	return true


static func can_sub_int(a: int, b: int) -> bool:
	if b > 0:
		return a >= INT64_MIN + b
	if b < 0:
		return a <= INT64_MAX + b
	return true


static func can_mul_int(a: int, b: int) -> bool:
	if a == 0 or b == 0:
		return true
	# Use signed bounds directly. Taking abs(INT64_MIN) is impossible, and a
	# MAX-only absolute-value test incorrectly rejects valid products that are
	# exactly INT64_MIN.
	if a > 0:
		if b > 0:
			@warning_ignore("integer_division")
			return a <= INT64_MAX / b
		@warning_ignore("integer_division")
		return b >= INT64_MIN / a
	if b > 0:
		@warning_ignore("integer_division")
		return a >= INT64_MIN / b
	@warning_ignore("integer_division")
	return a >= INT64_MAX / b


static func _fail(
		status: SimStatus,
		code: int,
		operation: int,
		detail_a: int,
		detail_b: int
) -> int:
	status.fail(code, operation, detail_a, detail_b)
	return 0


static func add_raw(a_raw: int, b_raw: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if not can_add_int(a_raw, b_raw):
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.FIX_ADD, a_raw, b_raw)
	return a_raw + b_raw


static func sub_raw(a_raw: int, b_raw: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if not can_sub_int(a_raw, b_raw):
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.FIX_SUB, a_raw, b_raw)
	return a_raw - b_raw


static func negate_raw(value_raw: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if value_raw == INT64_MIN:
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.FIX_NEGATE, value_raw, 0)
	return -value_raw


static func abs_raw(value_raw: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if value_raw == INT64_MIN:
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.FIX_ABS, value_raw, 0)
	return -value_raw if value_raw < 0 else value_raw


static func multiply_int(a: int, b: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if not can_mul_int(a, b):
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.FIX_INT_MUL, a, b)
	return a * b


static func _multiply_int_for(a: int, b: int, status: SimStatus, operation: int) -> int:
	if not status.is_ok():
		return 0
	if not can_mul_int(a, b):
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, operation, a, b)
	return a * b


static func _trunc_div_int_for(
		numerator: int,
		denominator: int,
		status: SimStatus,
		operation: int
) -> int:
	if not status.is_ok():
		return 0
	if denominator == 0:
		return _fail(status, SimStatus.Code.DIVISION_BY_ZERO, operation, numerator, denominator)
	if numerator == INT64_MIN and denominator == -1:
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, operation, numerator, denominator)
	@warning_ignore("integer_division")
	var result: int = numerator / denominator
	return result


static func trunc_div_int(numerator: int, denominator: int, status: SimStatus) -> int:
	return _trunc_div_int_for(
		numerator, denominator, status, SimStatus.Operation.FIX_TRUNC_DIV
	)


static func _round_div_int_for(
		numerator: int,
		denominator: int,
		status: SimStatus,
		operation: int
) -> int:
	if not status.is_ok():
		return 0
	if denominator == 0:
		return _fail(status, SimStatus.Code.DIVISION_BY_ZERO, operation, numerator, denominator)
	if numerator == INT64_MIN and denominator == -1:
		return _fail(status, SimStatus.Code.INT64_OVERFLOW, operation, numerator, denominator)

	# abs(INT64_MIN) is not representable. Handle that denominator directly.
	if denominator == INT64_MIN:
		if numerator == INT64_MIN:
			return 1
		var abs_numerator: int = -numerator if numerator < 0 else numerator
		if abs_numerator >= (1 << 62):
			return 1 if numerator < 0 else -1
		return 0

	@warning_ignore("integer_division")
	var quotient: int = numerator / denominator
	var remainder: int = numerator % denominator
	if remainder == 0:
		return quotient

	var abs_remainder: int = -remainder if remainder < 0 else remainder
	var abs_denominator: int = -denominator if denominator < 0 else denominator
	@warning_ignore("integer_division")
	var half_floor: int = abs_denominator / 2
	var should_round_away: bool = abs_remainder > half_floor
	if abs_remainder == half_floor and abs_denominator % 2 == 0:
		should_round_away = true
	if should_round_away:
		var adjustment: int = -1 if (numerator < 0) != (denominator < 0) else 1
		if not can_add_int(quotient, adjustment):
			return _fail(status, SimStatus.Code.INT64_OVERFLOW, operation, numerator, denominator)
		quotient += adjustment
	return quotient


static func round_div_int(numerator: int, denominator: int, status: SimStatus) -> int:
	return _round_div_int_for(
		numerator, denominator, status, SimStatus.Operation.FIX_ROUND_DIV
	)


static func floor_div_int(numerator: int, denominator: int, status: SimStatus) -> int:
	var value: int = _trunc_div_int_for(
		numerator, denominator, status, SimStatus.Operation.FIX_FLOOR_DIV
	)
	if not status.is_ok():
		return 0
	var remainder: int = numerator % denominator
	if remainder != 0 and (numerator < 0) != (denominator < 0):
		if not can_sub_int(value, 1):
			return _fail(
				status, SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.FIX_FLOOR_DIV,
				numerator, denominator
			)
		value -= 1
	return value


static func ceil_div_int(numerator: int, denominator: int, status: SimStatus) -> int:
	var value: int = _trunc_div_int_for(
		numerator, denominator, status, SimStatus.Operation.FIX_CEIL_DIV
	)
	if not status.is_ok():
		return 0
	var remainder: int = numerator % denominator
	if remainder != 0 and (numerator < 0) == (denominator < 0):
		if not can_add_int(value, 1):
			return _fail(
				status, SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.FIX_CEIL_DIV,
				numerator, denominator
			)
		value += 1
	return value


static func from_int(value: int, status: SimStatus) -> int:
	return _multiply_int_for(value, SCALE, status, SimStatus.Operation.FIX_FROM_INT)


static func from_ratio(numerator: int, denominator: int, status: SimStatus) -> int:
	var scaled: int = _multiply_int_for(
		numerator, SCALE, status, SimStatus.Operation.FIX_FROM_RATIO
	)
	return _round_div_int_for(
		scaled, denominator, status, SimStatus.Operation.FIX_FROM_RATIO
	)


static func to_int_round(value_raw: int, status: SimStatus) -> int:
	return _round_div_int_for(
		value_raw, SCALE, status, SimStatus.Operation.FIX_ROUND_DIV
	)


static func to_int_trunc(value_raw: int, status: SimStatus) -> int:
	return _trunc_div_int_for(
		value_raw, SCALE, status, SimStatus.Operation.FIX_TRUNC_DIV
	)


static func to_int_floor(value_raw: int, status: SimStatus) -> int:
	return floor_div_int(value_raw, SCALE, status)


static func to_int_ceil(value_raw: int, status: SimStatus) -> int:
	return ceil_div_int(value_raw, SCALE, status)


static func mul_raw(a_raw: int, b_raw: int, status: SimStatus) -> int:
	var wide: int = _multiply_int_for(
		a_raw, b_raw, status, SimStatus.Operation.FIX_MUL
	)
	return _round_div_int_for(wide, SCALE, status, SimStatus.Operation.FIX_MUL)


static func div_raw(a_raw: int, b_raw: int, status: SimStatus) -> int:
	var scaled: int = _multiply_int_for(
		a_raw, SCALE, status, SimStatus.Operation.FIX_DIV
	)
	return _round_div_int_for(scaled, b_raw, status, SimStatus.Operation.FIX_DIV)


static func mul_ratio_raw(
		value_raw: int,
		numerator: int,
		denominator: int,
		status: SimStatus
) -> int:
	var scaled: int = _multiply_int_for(
		value_raw, numerator, status, SimStatus.Operation.FIX_MUL
	)
	return _round_div_int_for(scaled, denominator, status, SimStatus.Operation.FIX_MUL)


static func clamp_explicit_raw(
		value_raw: int,
		minimum_raw: int,
		maximum_raw: int,
		status: SimStatus
) -> int:
	if not status.is_ok():
		return 0
	if minimum_raw > maximum_raw:
		return _fail(
			status, SimStatus.Code.INVALID_RANGE, SimStatus.Operation.FIX_CLAMP,
			minimum_raw, maximum_raw
		)
	if value_raw < minimum_raw:
		return minimum_raw
	if value_raw > maximum_raw:
		return maximum_raw
	return value_raw


static func _bit_length(value: int) -> int:
	var bits: int = 0
	var remaining: int = value
	while remaining > 0:
		remaining >>= 1
		bits += 1
	return bits


static func isqrt_floor(value: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if value < 0:
		return _fail(status, SimStatus.Code.NEGATIVE_SQRT, SimStatus.Operation.FIX_SQRT, value, 0)
	if value < 2:
		return value

	var guess_shift: int = (_bit_length(value) + 1) >> 1
	var root: int = 1 << guess_shift
	while true:
		@warning_ignore("integer_division")
		var quotient: int = value / root
		@warning_ignore("integer_division")
		var next_root: int = (root + quotient) / 2
		if next_root >= root:
			return root
		root = next_root
	return root


static func isqrt_nearest(value: int, status: SimStatus) -> int:
	var lower: int = isqrt_floor(value, status)
	if not status.is_ok():
		return 0
	var lower_squared: int = lower * lower
	var remainder: int = value - lower_squared
	var root_gap: int = 2 * lower + 1
	if 2 * remainder >= root_gap:
		return lower + 1
	return lower


static func sqrt_raw(value_raw: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if value_raw < 0:
		return _fail(
			status, SimStatus.Code.NEGATIVE_SQRT, SimStatus.Operation.FIX_SQRT,
			value_raw, 0
		)
	var scaled: int = _multiply_int_for(
		value_raw, SCALE, status, SimStatus.Operation.FIX_SQRT
	)
	return isqrt_nearest(scaled, status)
