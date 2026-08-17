extends SceneTree
## Headless acceptance tests for docs/specs/p0_fix_math_rng.md.

const SimStatusScript := preload("res://src/core/sim/sim_status.gd")
const FixMathScript := preload("res://src/core/sim/fix_math.gd")
const SimLimitsScript := preload("res://src/core/sim/sim_limits.gd")
const UInt32MathScript := preload("res://src/core/sim/uint32_math.gd")
const FixVec2Script := preload("res://src/core/sim/fix_vec2.gd")
const FixTrigLutScript := preload("res://src/core/sim/fix_trig_lut.gd")
const SimRngScript := preload("res://src/core/sim/sim_rng.gd")

const RNG_FIXTURE_PATH: String = "res://pipeline/tests/fixtures/p0_rng_vectors.json"

var _failures: int = 0


func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % case_id)
		return
	_failures += 1
	var suffix: String = "" if detail.is_empty() else " — %s" % detail
	print("[FAIL] %s%s" % [case_id, suffix])


func _hex_nibble(codepoint: int) -> int:
	if codepoint >= 48 and codepoint <= 57:
		return codepoint - 48
	if codepoint >= 97 and codepoint <= 102:
		return codepoint - 97 + 10
	if codepoint >= 65 and codepoint <= 70:
		return codepoint - 65 + 10
	return -1


func _parse_hex(text: String) -> int:
	var value: int = 0
	for index: int in range(text.length()):
		var nibble: int = _hex_nibble(text.unicode_at(index))
		if nibble < 0:
			return -1
		value = (value << 4) | nibble
	return value


func _rng_state_matches(rng: SimRng, expected: Array, status: SimStatus) -> bool:
	if expected.size() != 4:
		return false
	for index: int in range(4):
		if rng.state_word(index, status) != _parse_hex(str(expected[index])):
			return false
	return status.is_ok()


func _rng_count_matches(rng: SimRng, expected_hex: String) -> bool:
	if expected_hex.length() != 16:
		return false
	return (
		rng.draw_count_hi() == _parse_hex(expected_hex.substr(0, 8))
		and rng.draw_count_lo() == _parse_hex(expected_hex.substr(8, 8))
	)


func _rng_snapshot(rng: SimRng, status: SimStatus) -> Array[int]:
	var snapshot: Array[int] = []
	for index: int in range(4):
		snapshot.append(rng.state_word(index, status))
	snapshot.append(rng.draw_count_hi())
	snapshot.append(rng.draw_count_lo())
	return snapshot


func _rng_matches_snapshot(rng: SimRng, snapshot: Array[int], status: SimStatus) -> bool:
	if snapshot.size() != 6:
		return false
	for index: int in range(4):
		if rng.state_word(index, status) != snapshot[index]:
			return false
	return (
		status.is_ok()
		and rng.draw_count_hi() == snapshot[4]
		and rng.draw_count_lo() == snapshot[5]
	)


func _run_rng_outputs(rng: SimRng, case_data: Dictionary, status: SimStatus) -> String:
	var outputs: Array = case_data.get("outputs", [])
	for index: int in range(outputs.size()):
		var actual: int = rng.next_u32(status)
		var expected: int = _parse_hex(str(outputs[index]))
		if not status.is_ok():
			return "status failed at output %d code=%d op=%d" % [
				index, status.code(), status.operation()
			]
		if actual != expected:
			return "output[%d] expected=%08x actual=%08x" % [index, expected, actual]
	if not _rng_state_matches(rng, case_data.get("final_state", []), status):
		return "final state mismatch"
	if not _rng_count_matches(rng, str(case_data.get("draw_count", ""))):
		return "draw count mismatch"
	return ""


func _load_rng_fixture() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(RNG_FIXTURE_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return parsed as Dictionary


func _test_fix_math() -> void:
	_check(
		"FM-CONSTANTS-001",
		FixMath.SCALE == 65536
		and FixMath.FRACTION_BITS == 16
		and SimLimits.POSITION_COMPONENT_LIMIT_RAW == 8192 * 65536
		and SimLimits.SPEED_MAGNITUDE_LIMIT_RAW == 4096 * 65536
		and SimLimits.RADIUS_MIN_RAW == 8 * 65536
		and SimLimits.RADIUS_MAX_RAW == 128 * 65536
		and SimLimits.IMPULSE_ABS_LIMIT_RAW == 2097152 * 65536
		and SimStatus.Code.RNG_COUNTER_OVERFLOW == 8
		and SimStatus.Operation.RNG_CHANCE == 30
	)

	var status := SimStatus.new()
	var rounding_ok: bool = (
		FixMath.round_div_int(3, 2, status) == 2
		and FixMath.round_div_int(-3, 2, status) == -2
		and FixMath.round_div_int(1, 2, status) == 1
		and FixMath.round_div_int(-1, 2, status) == -1
		and FixMath.round_div_int(1, 3, status) == 0
		and FixMath.round_div_int(2, 3, status) == 1
		and FixMath.round_div_int(1 << 62, FixMath.INT64_MIN, status) == -1
		and FixMath.round_div_int(-(1 << 62), FixMath.INT64_MIN, status) == 1
		and status.is_ok()
	)
	_check("FM-ROUND-001", rounding_ok)

	status = SimStatus.new()
	var directed_ok: bool = (
		FixMath.trunc_div_int(-3, 2, status) == -1
		and FixMath.floor_div_int(-3, 2, status) == -2
		and FixMath.ceil_div_int(-3, 2, status) == -1
		and FixMath.floor_div_int(3, -2, status) == -2
		and FixMath.ceil_div_int(3, -2, status) == -1
		and status.is_ok()
	)
	_check("FM-DIRECTED-001", directed_ok)

	status = SimStatus.new()
	var one_and_half_raw: int = FixMath.from_ratio(3, 2, status)
	var two_raw: int = FixMath.from_int(2, status)
	var fixed_ok: bool = (
		one_and_half_raw == 98304
		and FixMath.mul_raw(one_and_half_raw, two_raw, status) == 3 * FixMath.SCALE
		and FixMath.div_raw(3 * FixMath.SCALE, two_raw, status) == one_and_half_raw
		and FixMath.to_int_round(one_and_half_raw, status) == 2
		and FixMath.to_int_floor(-one_and_half_raw, status) == -2
		and FixMath.to_int_ceil(-one_and_half_raw, status) == -1
		and status.is_ok()
	)
	_check("FM-FIXED-001", fixed_ok)

	status = SimStatus.new()
	var divide_result: int = FixMath.div_raw(FixMath.ONE_RAW, 0, status)
	var first_code: int = status.code()
	var first_operation: int = status.operation()
	var ignored_result: int = FixMath.add_raw(FixMath.INT64_MAX, 1, status)
	_check(
		"FM-STATUS-001",
		divide_result == 0
		and ignored_result == 0
		and first_code == SimStatus.Code.DIVISION_BY_ZERO
		and first_operation == SimStatus.Operation.FIX_DIV
		and status.code() == first_code
		and status.operation() == first_operation
	)

	status = SimStatus.new()
	FixMath.add_raw(FixMath.INT64_MAX, 1, status)
	_check(
		"FM-OVERFLOW-001",
		status.code() == SimStatus.Code.INT64_OVERFLOW
		and status.operation() == SimStatus.Operation.FIX_ADD
		and not FixMath.can_mul_int(SimLimits.IMPULSE_ABS_LIMIT_RAW, SimLimits.IMPULSE_ABS_LIMIT_RAW)
	)

	var exact_min_status := SimStatus.new()
	var exact_min_left: int = FixMath.multiply_int(-(1 << 62), 2, exact_min_status)
	var exact_min_right: int = FixMath.multiply_int(2, -(1 << 62), exact_min_status)
	var minimum_raw: int = FixMath.from_int(-140737488355328, exact_min_status)
	var maximum_integer_raw: int = FixMath.from_int(140737488355327, exact_min_status)
	_check(
		"FM-REPRESENTATION-EDGE-001",
		exact_min_left == FixMath.INT64_MIN
		and exact_min_right == FixMath.INT64_MIN
		and minimum_raw == FixMath.INT64_MIN
		and maximum_integer_raw == FixMath.INT64_MAX - (FixMath.SCALE - 1)
		and FixMath.can_mul_int(FixMath.INT64_MIN, 1)
		and FixMath.can_mul_int(1, FixMath.INT64_MIN)
		and not FixMath.can_mul_int(FixMath.INT64_MIN, -1)
		and not FixMath.can_mul_int(-1, FixMath.INT64_MIN)
		and exact_min_status.is_ok()
	)

	var below_min_status := SimStatus.new()
	var below_min_result: int = FixMath.multiply_int(
		-(1 << 62) - 1, 2, below_min_status
	)
	var above_max_status := SimStatus.new()
	var above_max_result: int = FixMath.from_int(140737488355328, above_max_status)
	_check(
		"FM-REPRESENTATION-OVERFLOW-001",
		below_min_result == 0
		and below_min_status.code() == SimStatus.Code.INT64_OVERFLOW
		and below_min_status.operation() == SimStatus.Operation.FIX_INT_MUL
		and above_max_result == 0
		and above_max_status.code() == SimStatus.Code.INT64_OVERFLOW
		and above_max_status.operation() == SimStatus.Operation.FIX_FROM_INT
	)

	status = SimStatus.new()
	var sqrt_ok: bool = (
		FixMath.isqrt_floor(0, status) == 0
		and FixMath.isqrt_floor(1, status) == 1
		and FixMath.isqrt_floor(2, status) == 1
		and FixMath.isqrt_nearest(3, status) == 2
		and FixMath.isqrt_floor(FixMath.INT64_MAX, status) == 3037000499
		and FixMath.sqrt_raw(4 * FixMath.SCALE, status) == 2 * FixMath.SCALE
		and status.is_ok()
	)
	_check("FM-SQRT-001", sqrt_ok)

	status = SimStatus.new()
	FixMath.sqrt_raw(-1, status)
	_check(
		"FM-SQRT-ERROR-001",
		status.code() == SimStatus.Code.NEGATIVE_SQRT
		and status.operation() == SimStatus.Operation.FIX_SQRT
	)


func _test_fix_vec2() -> void:
	var status := SimStatus.new()
	var vector := FixVec2.from_ints(3, 4, status)
	var length_ok: bool = (
		vector.length_raw(status) == 5 * FixMath.SCALE
		and vector.length_squared_raw(status) == 25 * FixMath.SCALE
		and status.is_ok()
	)
	_check("FV-LENGTH-001", length_ok)

	status = SimStatus.new()
	var normalized: FixVec2 = vector.normalized(status)
	var normalize_ok: bool = (
		normalized.x_raw() == 39322
		and normalized.y_raw() == 52429
		and normalized.length_raw(status) == FixMath.ONE_RAW
		and status.is_ok()
	)
	_check("FV-NORMALIZE-001", normalize_ok)

	status = SimStatus.new()
	var tiny_a := FixVec2.from_raw(1, 1)
	var tiny_b := FixVec2.from_raw(FixMath.HALF_RAW, FixMath.HALF_RAW)
	_check(
		"FV-WIDE-ROUND-001",
		tiny_a.dot_raw(tiny_b, status) == 1
		and tiny_a.length_raw(status) == 1
		and status.is_ok()
	)

	status = SimStatus.new()
	FixVec2.zero().normalized(status)
	_check(
		"FV-ZERO-001",
		status.code() == SimStatus.Code.ZERO_LENGTH
		and status.operation() == SimStatus.Operation.VEC_NORMALIZE
	)

	status = SimStatus.new()
	var below := FixVec2.from_raw(
		FixMath.from_ratio(3, 10, status), FixMath.from_ratio(3, 10, status)
	)
	var threshold_raw: int = FixMath.from_ratio(1, 2, status)
	var exact := FixVec2.from_raw(threshold_raw, 0)
	var above := FixVec2.from_raw(threshold_raw, 1)
	_check(
		"FV-THRESHOLD-001",
		below.is_length_at_most_raw(threshold_raw, status)
		and exact.is_length_at_most_raw(threshold_raw, status)
		and not above.is_length_at_most_raw(threshold_raw, status)
		and status.is_ok()
	)

	status = SimStatus.new()
	var overflow_add: FixVec2 = FixVec2.from_raw(FixMath.INT64_MAX, 0).add(
		FixVec2.from_raw(1, 0), status
	)
	_check(
		"FV-SCALAR-DIAGNOSTIC-ADD-001",
		overflow_add.is_zero()
		and status.code() == SimStatus.Code.INT64_OVERFLOW
		and status.operation() == SimStatus.Operation.FIX_ADD
	)

	status = SimStatus.new()
	var overflow_scale: FixVec2 = FixVec2.from_raw(FixMath.INT64_MAX, 0).scaled(
		2 * FixMath.SCALE, status
	)
	_check(
		"FV-SCALAR-DIAGNOSTIC-SCALE-001",
		overflow_scale.is_zero()
		and status.code() == SimStatus.Code.INT64_OVERFLOW
		and status.operation() == SimStatus.Operation.FIX_MUL
	)


func _test_trig_lut() -> void:
	var status := SimStatus.new()
	var axes_ok: bool = (
		FixTrigLut.sin_raw(0, status) == 0
		and FixTrigLut.cos_raw(0, status) == FixMath.ONE_RAW
		and FixTrigLut.sin_raw(16384, status) == FixMath.ONE_RAW
		and FixTrigLut.cos_raw(16384, status) == 0
		and FixTrigLut.sin_raw(32768, status) == 0
		and FixTrigLut.cos_raw(32768, status) == -FixMath.ONE_RAW
		and FixTrigLut.sin_raw(49152, status) == -FixMath.ONE_RAW
		and FixTrigLut.sin_raw(65536, status) == 0
		and FixTrigLut.sin_raw(-16384, status) == -FixMath.ONE_RAW
		and status.is_ok()
	)
	_check("LUT-AXES-001", axes_ok)

	status = SimStatus.new()
	var interpolation_ok: bool = (
		FixTrigLut.sin_raw(1, status) == 6
		and FixTrigLut.sin_raw(2, status) == 13
		and FixTrigLut.sin_raw(3, status) == 19
		and FixTrigLut.sin_raw(8192, status) == 46341
		and FixTrigLut.cos_raw(8192, status) == 46341
		and status.is_ok()
	)
	_check("LUT-INTERPOLATE-001", interpolation_ok)

	status = SimStatus.new()
	var direction: FixVec2 = FixTrigLut.direction(0, status)
	_check(
		"LUT-DIRECTION-001",
		direction.x_raw() == FixMath.ONE_RAW
		and direction.y_raw() == 0
		and FixTrigLut.wrap_angle(-1) == 65535
		and status.is_ok()
	)

	status = SimStatus.new()
	var sample_angle: int = 1235
	var sample_sin: int = FixTrigLut.sin_raw(sample_angle, status)
	var symmetry_ok: bool = (
		FixTrigLut.sin_raw(FixTrigLut.QUARTER_TURN - sample_angle, status)
			== FixTrigLut.sin_raw(FixTrigLut.QUARTER_TURN + sample_angle, status)
		and FixTrigLut.sin_raw(FixTrigLut.HALF_TURN - sample_angle, status) == sample_sin
		and FixTrigLut.sin_raw(FixTrigLut.HALF_TURN + sample_angle, status) == -sample_sin
		and FixTrigLut.sin_raw(FixTrigLut.FULL_TURN - sample_angle, status) == -sample_sin
		and FixTrigLut.sin_raw(FixTrigLut.QUARTER_TURN - 1, status)
			== FixTrigLut.sin_raw(FixTrigLut.QUARTER_TURN + 1, status)
		and FixTrigLut.sin_raw(FixTrigLut.HALF_TURN - 1, status)
			== -FixTrigLut.sin_raw(FixTrigLut.HALF_TURN + 1, status)
		and FixTrigLut.sin_raw(FixTrigLut.FULL_TURN - 1, status)
			== FixTrigLut.sin_raw(-1, status)
		and status.is_ok()
	)
	_check("LUT-SYMMETRY-SEAMS-001", symmetry_ok)

	status = SimStatus.new()
	var extreme_ok: bool = (
		FixTrigLut.cos_raw(FixMath.INT64_MAX, status)
			== FixTrigLut.cos_raw(FixMath.INT64_MAX & FixTrigLut.ANGLE_MASK, status)
		and FixTrigLut.cos_raw(FixMath.INT64_MIN, status)
			== FixTrigLut.cos_raw(FixMath.INT64_MIN & FixTrigLut.ANGLE_MASK, status)
		and status.is_ok()
	)
	_check("LUT-EXTREME-WRAP-001", extreme_ok)


func _test_uint32_math() -> void:
	var status := SimStatus.new()
	var operations_ok: bool = (
		UInt32Math.multiply(0xFFFFFFFF, 0xFFFFFFFF, status) == 1
		and UInt32Math.rotate_left(1, 1, status) == 2
		and UInt32Math.rotate_left(1, 31, status) == 0x80000000
		and UInt32Math.rotate_left(0xFFFFFFFF, 17, status) == 0xFFFFFFFF
		and status.is_ok()
	)
	_check("U32-OPS-001", operations_ok)

	status = SimStatus.new()
	UInt32Math.multiply(-1, 1, status)
	_check(
		"U32-RANGE-001",
		status.code() == SimStatus.Code.INVALID_RANGE
		and status.operation() == SimStatus.Operation.U32_MULTIPLY
	)


func _test_rng() -> void:
	var fixture: Dictionary = _load_rng_fixture()
	_check("RNG-FIXTURE-001", not fixture.is_empty(), RNG_FIXTURE_PATH)
	if fixture.is_empty():
		return

	var direct: Dictionary = fixture.get("direct_state", {})
	var direct_initial: Array = direct.get("initial_state", [])
	var status := SimStatus.new()
	var direct_rng := SimRng.new()
	direct_rng.restore_state(
		_parse_hex(str(direct_initial[0])),
		_parse_hex(str(direct_initial[1])),
		_parse_hex(str(direct_initial[2])),
		_parse_hex(str(direct_initial[3])),
		0,
		0,
		status
	)
	var direct_error: String = _run_rng_outputs(direct_rng, direct, status)
	_check("RNG-GOLDEN-DIRECT-1000", direct_error.is_empty(), direct_error)

	var derived: Dictionary = fixture.get("derived_stream", {})
	var root_seed: String = str(derived.get("root_seed", ""))
	var purpose_id: int = _parse_hex(str(derived.get("purpose_id", "")))
	var owner_id: int = _parse_hex(str(derived.get("owner_id", "")))
	var ordinal: int = _parse_hex(str(derived.get("ordinal", "")))
	status = SimStatus.new()
	var derived_rng: SimRng = SimRng.derive(
		_parse_hex(root_seed.substr(0, 8)),
		_parse_hex(root_seed.substr(8, 8)),
		purpose_id,
		owner_id,
		ordinal,
		status
	)
	var derived_initial_ok: bool = _rng_state_matches(
		derived_rng, derived.get("initial_state", []), status
	)
	var derived_error: String = _run_rng_outputs(derived_rng, derived, status)
	_check(
		"RNG-GOLDEN-DERIVED-1000",
		derived_initial_ok and derived_error.is_empty(),
		derived_error
	)

	status = SimStatus.new()
	var parent: SimRng = SimRng.from_seed_words(
		_parse_hex(root_seed.substr(0, 8)), _parse_hex(root_seed.substr(8, 8)), status
	)
	var parent_before: Array[int] = []
	for index: int in range(4):
		parent_before.append(parent.state_word(index, status))
	var child: SimRng = parent.derive_substream(purpose_id, owner_id, ordinal, status)
	var parent_unchanged: bool = parent.draw_count_hi() == 0 and parent.draw_count_lo() == 0
	for index: int in range(4):
		parent_unchanged = parent_unchanged and parent.state_word(index, status) == parent_before[index]
	_check(
		"RNG-SUBSTREAM-NONCONSUMING-001",
		parent_unchanged
		and _rng_state_matches(child, derived.get("initial_state", []), status)
		and status.is_ok()
	)

	var parent_snapshot_status := SimStatus.new()
	var parent_snapshot: Array[int] = _rng_snapshot(parent, parent_snapshot_status)
	var reserved_status := SimStatus.new()
	var rejected_child: SimRng = parent.derive_substream(
		0, owner_id, ordinal, reserved_status
	)
	var rejected_child_status := SimStatus.new()
	var rejected_child_draw: int = rejected_child.next_u32(rejected_child_status)
	var reserved_inspect_status := SimStatus.new()
	_check(
		"RNG-PURPOSE-ZERO-RESERVED-001",
		parent_snapshot_status.is_ok()
		and reserved_status.code() == SimStatus.Code.INVALID_RANGE
		and reserved_status.operation() == SimStatus.Operation.RNG_DERIVE
		and rejected_child_draw == 0
		and rejected_child_status.code() == SimStatus.Code.INVALID_RNG_STATE
		and rejected_child_status.operation() == SimStatus.Operation.RNG_DRAW
		and _rng_matches_snapshot(parent, parent_snapshot, reserved_inspect_status)
	)

	var keyless_setup_status := SimStatus.new()
	var keyless_rng := SimRng.new()
	keyless_rng.restore_state(1, 2, 3, 4, 0, 0, keyless_setup_status)
	var keyless_snapshot: Array[int] = _rng_snapshot(keyless_rng, keyless_setup_status)
	var keyless_derive_status := SimStatus.new()
	keyless_rng.derive_substream(purpose_id, owner_id, ordinal, keyless_derive_status)
	var keyless_inspect_status := SimStatus.new()
	_check(
		"RNG-KEYLESS-SUBSTREAM-REJECTED-001",
		keyless_setup_status.is_ok()
		and keyless_derive_status.code() == SimStatus.Code.INVALID_RNG_STATE
		and keyless_derive_status.operation() == SimStatus.Operation.RNG_DERIVE
		and _rng_matches_snapshot(keyless_rng, keyless_snapshot, keyless_inspect_status)
	)

	var rejection: Dictionary = fixture.get("rejection_case", {})
	var rejection_state: Array = rejection.get("pre_state", [])
	var rejection_count: String = str(rejection.get("pre_draw_count", ""))
	status = SimStatus.new()
	var rejection_rng := SimRng.new()
	rejection_rng.restore_state(
		_parse_hex(str(rejection_state[0])),
		_parse_hex(str(rejection_state[1])),
		_parse_hex(str(rejection_state[2])),
		_parse_hex(str(rejection_state[3])),
		_parse_hex(rejection_count.substr(0, 8)),
		_parse_hex(rejection_count.substr(8, 8)),
		status
	)
	var accepted: int = rejection_rng.next_below(
		_parse_hex(str(rejection.get("bound", ""))), status
	)
	_check(
		"RNG-REJECTION-001",
		accepted == _parse_hex(str(rejection.get("accepted", "")))
		and _rng_state_matches(rejection_rng, rejection.get("post_state", []), status)
		and _rng_count_matches(rejection_rng, str(rejection.get("post_draw_count", "")))
		and status.is_ok()
	)

	var rollback_setup_status := SimStatus.new()
	var rollback_rng := SimRng.new()
	rollback_rng.restore_state(
		_parse_hex(str(rejection_state[0])),
		_parse_hex(str(rejection_state[1])),
		_parse_hex(str(rejection_state[2])),
		_parse_hex(str(rejection_state[3])),
		UInt32Math.U32_MAX,
		UInt32Math.U32_MAX - 1,
		rollback_setup_status
	)
	var rollback_snapshot: Array[int] = _rng_snapshot(rollback_rng, rollback_setup_status)
	var rollback_status := SimStatus.new()
	var rollback_value: int = rollback_rng.next_below(
		_parse_hex(str(rejection.get("bound", ""))), rollback_status
	)
	var rollback_inspect_status := SimStatus.new()
	_check(
		"RNG-REJECTION-ATOMIC-001",
		rollback_setup_status.is_ok()
		and rollback_value == 0
		and rollback_status.code() == SimStatus.Code.RNG_COUNTER_OVERFLOW
		and rollback_status.operation() == SimStatus.Operation.RNG_DRAW
		and _rng_matches_snapshot(rollback_rng, rollback_snapshot, rollback_inspect_status)
	)

	var boundary_setup_status := SimStatus.new()
	var boundary_rng := SimRng.new()
	boundary_rng.restore_state(1, 2, 3, 4, 0, 0, boundary_setup_status)
	var boundary_snapshot: Array[int] = _rng_snapshot(boundary_rng, boundary_setup_status)
	var copy_status := SimStatus.new()
	var bound_one_rng: SimRng = boundary_rng.copy(copy_status)
	var unit_range_rng: SimRng = boundary_rng.copy(copy_status)
	var zero_chance_rng: SimRng = boundary_rng.copy(copy_status)
	var full_chance_rng: SimRng = boundary_rng.copy(copy_status)
	var bound_one_status := SimStatus.new()
	var unit_range_status := SimStatus.new()
	var zero_chance_status := SimStatus.new()
	var full_chance_status := SimStatus.new()
	var bound_one_value: int = bound_one_rng.next_below(1, bound_one_status)
	var unit_range_value: int = unit_range_rng.next_range(5, 6, unit_range_status)
	var zero_chance_value: bool = zero_chance_rng.chance(0, 7, zero_chance_status)
	var full_chance_value: bool = full_chance_rng.chance(7, 7, full_chance_status)
	var boundary_inspect_status := SimStatus.new()
	var boundary_unchanged: bool = _rng_matches_snapshot(
		bound_one_rng, boundary_snapshot, boundary_inspect_status
	)
	boundary_inspect_status = SimStatus.new()
	boundary_unchanged = boundary_unchanged and _rng_matches_snapshot(
		unit_range_rng, boundary_snapshot, boundary_inspect_status
	)
	boundary_inspect_status = SimStatus.new()
	boundary_unchanged = boundary_unchanged and _rng_matches_snapshot(
		zero_chance_rng, boundary_snapshot, boundary_inspect_status
	)
	boundary_inspect_status = SimStatus.new()
	boundary_unchanged = boundary_unchanged and _rng_matches_snapshot(
		full_chance_rng, boundary_snapshot, boundary_inspect_status
	)
	_check(
		"RNG-DEGENERATE-PENDING-U23-001",
		boundary_setup_status.is_ok()
		and copy_status.is_ok()
		and bound_one_value == 0
		and unit_range_value == 0
		and not zero_chance_value
		and not full_chance_value
		and bound_one_status.code() == SimStatus.Code.INVALID_RANGE
		and bound_one_status.operation() == SimStatus.Operation.RNG_RANGE
		and unit_range_status.code() == SimStatus.Code.INVALID_RANGE
		and unit_range_status.operation() == SimStatus.Operation.RNG_RANGE
		and zero_chance_status.code() == SimStatus.Code.INVALID_RANGE
		and zero_chance_status.operation() == SimStatus.Operation.RNG_CHANCE
		and full_chance_status.code() == SimStatus.Code.INVALID_RANGE
		and full_chance_status.operation() == SimStatus.Operation.RNG_CHANCE
		and boundary_unchanged
	)

	status = SimStatus.new()
	var invalid_rng := SimRng.new()
	invalid_rng.restore_state(0, 0, 0, 0, 0, 0, status)
	var invalid_draw_status := SimStatus.new()
	var invalid_draw: int = invalid_rng.next_u32(invalid_draw_status)
	_check(
		"RNG-ALL-ZERO-001",
		status.code() == SimStatus.Code.INVALID_RNG_STATE
		and status.operation() == SimStatus.Operation.RNG_RESTORE
		and invalid_draw == 0
		and invalid_draw_status.code() == SimStatus.Code.INVALID_RNG_STATE
		and invalid_draw_status.operation() == SimStatus.Operation.RNG_DRAW
	)

	status = SimStatus.new()
	var exhausted_rng := SimRng.new()
	exhausted_rng.restore_state(
		1, 2, 3, 4, UInt32Math.U32_MAX, UInt32Math.U32_MAX, status
	)
	var exhausted_value: int = exhausted_rng.next_u32(status)
	var unchanged_status := SimStatus.new()
	_check(
		"RNG-COUNT-OVERFLOW-001",
		exhausted_value == 0
		and status.code() == SimStatus.Code.RNG_COUNTER_OVERFLOW
		and exhausted_rng.state_word(0, unchanged_status) == 1
		and exhausted_rng.state_word(1, unchanged_status) == 2
		and exhausted_rng.draw_count_hi() == UInt32Math.U32_MAX
		and exhausted_rng.draw_count_lo() == UInt32Math.U32_MAX
	)


func _test_safety_boundaries() -> void:
	var position_raw: int = SimLimits.POSITION_COMPONENT_LIMIT_RAW
	var speed_raw: int = SimLimits.SPEED_MAGNITUDE_LIMIT_RAW
	var unit_raw: int = FixMath.ONE_RAW
	var position_square: int = position_raw * position_raw
	var speed_square: int = speed_raw * speed_raw
	var mass_speed_wide: int = SimLimits.MASS_MAX_RAW * speed_raw
	var impulse_unit_wide: int = SimLimits.IMPULSE_ABS_LIMIT_RAW * unit_raw
	_check(
		"SAFE-INTERMEDIATE-001",
		FixMath.can_mul_int(position_raw, position_raw)
		and FixMath.can_add_int(position_square, position_square)
		and SimLimits.MAX_POSITION_DOT_WIDE == 2 * position_square
		and FixMath.can_mul_int(speed_raw, speed_raw)
		and SimLimits.MAX_SPEED_LENGTH_SQUARED_WIDE == speed_square
		and FixMath.can_mul_int(SimLimits.MASS_MAX_RAW, speed_raw)
		and SimLimits.MAX_MASS_SPEED_PRODUCT_WIDE == mass_speed_wide
		and FixMath.can_mul_int(SimLimits.IMPULSE_ABS_LIMIT_RAW, unit_raw)
		and SimLimits.MAX_IMPULSE_UNIT_PRODUCT_WIDE == impulse_unit_wide
		and not FixMath.can_mul_int(
			SimLimits.IMPULSE_ABS_LIMIT_RAW, SimLimits.IMPULSE_ABS_LIMIT_RAW
		)
	)

	var status := SimStatus.new()
	var maximum_momentum_raw: int = FixMath.mul_raw(
		SimLimits.MASS_MAX_RAW, speed_raw, status
	)
	_check(
		"SAFE-MASS-SPEED-001",
		maximum_momentum_raw == 256 * 4096 * FixMath.SCALE
		and SimLimits.is_mass_valid(SimLimits.MASS_MIN_RAW)
		and SimLimits.is_mass_valid(SimLimits.MASS_MAX_RAW)
		and not SimLimits.is_mass_valid(SimLimits.MASS_MIN_RAW - 1)
		and not SimLimits.is_mass_valid(SimLimits.MASS_MAX_RAW + 1)
		and status.is_ok()
	)

	status = SimStatus.new()
	var position_edge := FixVec2.from_raw(position_raw, -position_raw)
	var position_outside := FixVec2.from_raw(position_raw + 1, 0)
	var speed_edge := FixVec2.from_raw(speed_raw, 0)
	var speed_outside := FixVec2.from_raw(speed_raw, 1)
	var launch_edge := FixVec2.from_raw(SimLimits.LAUNCH_SPEED_LIMIT_RAW, 0)
	var launch_outside := FixVec2.from_raw(SimLimits.LAUNCH_SPEED_LIMIT_RAW, 1)
	_check(
		"SAFE-LIMIT-PREDICATES-001",
		SimLimits.is_position_valid(position_edge)
		and not SimLimits.is_position_valid(position_outside)
		and SimLimits.is_speed_valid(speed_edge, status)
		and not SimLimits.is_speed_valid(speed_outside, status)
		and SimLimits.is_launch_speed_valid(launch_edge, status)
		and not SimLimits.is_launch_speed_valid(launch_outside, status)
		and SimLimits.is_radius_valid(SimLimits.RADIUS_MIN_RAW)
		and SimLimits.is_radius_valid(SimLimits.RADIUS_MAX_RAW)
		and not SimLimits.is_radius_valid(SimLimits.RADIUS_MIN_RAW - 1)
		and not SimLimits.is_radius_valid(SimLimits.RADIUS_MAX_RAW + 1)
		and SimLimits.is_impulse_valid(-SimLimits.IMPULSE_ABS_LIMIT_RAW)
		and SimLimits.is_impulse_valid(SimLimits.IMPULSE_ABS_LIMIT_RAW)
		and not SimLimits.is_impulse_valid(SimLimits.IMPULSE_ABS_LIMIT_RAW + 1)
		and status.is_ok()
	)


func _initialize() -> void:
	print("== P0-1 FixMath / FixVec2 / FixTrigLut / SimRng ==")
	_test_fix_math()
	_test_fix_vec2()
	_test_trig_lut()
	_test_uint32_math()
	_test_rng()
	_test_safety_boundaries()

	if _failures == 0:
		print("P0_MATH_RNG_RESULT: PASS")
		quit(0)
	else:
		print("P0_MATH_RNG_RESULT: FAIL (%d grouped checks)" % _failures)
		quit(1)
