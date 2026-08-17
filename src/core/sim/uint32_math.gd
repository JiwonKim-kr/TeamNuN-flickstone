class_name UInt32Math
extends RefCounted
## Unsigned 32-bit operations implemented without signed int64 overflow.

const U16_MAX: int = 0xFFFF
const U32_MAX: int = 0xFFFFFFFF
const U32_SPACE: int = 0x100000000


static func is_u16(value: int) -> bool:
	return value >= 0 and value <= U16_MAX


static func is_u32(value: int) -> bool:
	return value >= 0 and value <= U32_MAX


static func add(a: int, b: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if not is_u32(a) or not is_u32(b):
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.U32_ADD, a, b)
		return 0
	return (a + b) & U32_MAX


static func multiply(a: int, b: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if not is_u32(a) or not is_u32(b):
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.U32_MULTIPLY, a, b)
		return 0
	var a_low: int = a & U16_MAX
	var a_high: int = (a >> 16) & U16_MAX
	var b_low: int = b & U16_MAX
	var b_high: int = (b >> 16) & U16_MAX
	var low_product: int = a_low * b_low
	var cross_low: int = (a_low * b_high + a_high * b_low) & U16_MAX
	return (low_product + (cross_low << 16)) & U32_MAX


static func rotate_left(value: int, shift: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if not is_u32(value) or shift < 0 or shift > 31:
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.U32_ROTATE, value, shift)
		return 0
	if shift == 0:
		return value
	return ((value << shift) | (value >> (32 - shift))) & U32_MAX


static func fmix32(value: int, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if not is_u32(value):
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.U32_MULTIPLY, value, 0)
		return 0
	var mixed: int = value
	mixed ^= mixed >> 16
	mixed = multiply(mixed, 0x85EBCA6B, status)
	mixed ^= mixed >> 13
	mixed = multiply(mixed, 0xC2B2AE35, status)
	mixed ^= mixed >> 16
	return mixed & U32_MAX
