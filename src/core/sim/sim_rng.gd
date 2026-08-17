class_name SimRng
extends RefCounted
## Deterministic xoshiro128** 1.1 stream with versioned keyed derivation.
##
## FSR1 derivation hashes a fixed six-word little-endian key with
## MurmurHash3_x86_128. Substreams depend only on the root seed and explicit
## keys, never on mutable parent state or draw count. A bare `SimRng.new()` is
## invalid until a factory or `restore_state()` succeeds; state-only restores
## may draw but cannot derive keyed substreams.

const PURPOSE_ID_MIN: int = 1
const PURPOSE_ID_MAX: int = 0xFFFF
const DERIVATION_DOMAIN: int = 0x31525346 # little-endian bytes "FSR1"
const DERIVATION_KEY_BYTES: int = 24

const MURMUR_C1: int = 0x239B961B
const MURMUR_C2: int = 0xAB0E9789
const MURMUR_C3: int = 0x38B34AE5
const MURMUR_C4: int = 0xA1E38B93

var _root_seed_hi: int = 0
var _root_seed_lo: int = 0
var _purpose_id: int = 0
var _owner_id: int = 0
var _ordinal: int = 0

var _initialized: bool = false
var _has_derivation_key: bool = false
var _s0: int = 0
var _s1: int = 0
var _s2: int = 0
var _s3: int = 0
var _draw_count_hi: int = 0
var _draw_count_lo: int = 0


static func _is_valid_key(
		seed_hi: int,
		seed_lo: int,
		purpose_id: int,
		owner_id: int,
		ordinal: int
) -> bool:
	return (
		UInt32Math.is_u32(seed_hi)
		and UInt32Math.is_u32(seed_lo)
		and purpose_id >= PURPOSE_ID_MIN
		and purpose_id <= PURPOSE_ID_MAX
		and UInt32Math.is_u32(owner_id)
		and UInt32Math.is_u32(ordinal)
	)


func _require_initialized(status: SimStatus, operation: int) -> bool:
	if not status.is_ok():
		return false
	if _initialized:
		return true
	status.fail(SimStatus.Code.INVALID_RNG_STATE, operation, 0, 0)
	return false


static func _murmur_x86_128_six_words(
		words: Array[int], hash_seed: int, status: SimStatus
) -> Array[int]:
	if not status.is_ok():
		return [0, 0, 0, 0]
	if words.size() != 6 or not UInt32Math.is_u32(hash_seed):
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.RNG_DERIVE,
			words.size(),
			hash_seed
		)
		return [0, 0, 0, 0]
	for word: int in words:
		if not UInt32Math.is_u32(word):
			status.fail(
				SimStatus.Code.INVALID_RANGE,
				SimStatus.Operation.RNG_DERIVE,
				word,
				0
			)
			return [0, 0, 0, 0]

	var h1: int = hash_seed
	var h2: int = hash_seed
	var h3: int = hash_seed
	var h4: int = hash_seed

	var k1: int = UInt32Math.multiply(words[0], MURMUR_C1, status)
	k1 = UInt32Math.multiply(UInt32Math.rotate_left(k1, 15, status), MURMUR_C2, status)
	h1 = (h1 ^ k1) & UInt32Math.U32_MAX
	h1 = UInt32Math.rotate_left(h1, 19, status)
	h1 = UInt32Math.add(h1, h2, status)
	h1 = UInt32Math.add(UInt32Math.multiply(h1, 5, status), 0x561CCD1B, status)

	var k2: int = UInt32Math.multiply(words[1], MURMUR_C2, status)
	k2 = UInt32Math.multiply(UInt32Math.rotate_left(k2, 16, status), MURMUR_C3, status)
	h2 = (h2 ^ k2) & UInt32Math.U32_MAX
	h2 = UInt32Math.rotate_left(h2, 17, status)
	h2 = UInt32Math.add(h2, h3, status)
	h2 = UInt32Math.add(UInt32Math.multiply(h2, 5, status), 0x0BCAA747, status)

	var k3: int = UInt32Math.multiply(words[2], MURMUR_C3, status)
	k3 = UInt32Math.multiply(UInt32Math.rotate_left(k3, 17, status), MURMUR_C4, status)
	h3 = (h3 ^ k3) & UInt32Math.U32_MAX
	h3 = UInt32Math.rotate_left(h3, 15, status)
	h3 = UInt32Math.add(h3, h4, status)
	h3 = UInt32Math.add(UInt32Math.multiply(h3, 5, status), 0x96CD1C35, status)

	var k4: int = UInt32Math.multiply(words[3], MURMUR_C4, status)
	k4 = UInt32Math.multiply(UInt32Math.rotate_left(k4, 18, status), MURMUR_C1, status)
	h4 = (h4 ^ k4) & UInt32Math.U32_MAX
	h4 = UInt32Math.rotate_left(h4, 13, status)
	h4 = UInt32Math.add(h4, h1, status)
	h4 = UInt32Math.add(UInt32Math.multiply(h4, 5, status), 0x32AC3B17, status)

	# The 24-byte key leaves exactly two complete little-endian tail words.
	k2 = UInt32Math.multiply(words[5], MURMUR_C2, status)
	k2 = UInt32Math.multiply(UInt32Math.rotate_left(k2, 16, status), MURMUR_C3, status)
	h2 = (h2 ^ k2) & UInt32Math.U32_MAX
	k1 = UInt32Math.multiply(words[4], MURMUR_C1, status)
	k1 = UInt32Math.multiply(UInt32Math.rotate_left(k1, 15, status), MURMUR_C2, status)
	h1 = (h1 ^ k1) & UInt32Math.U32_MAX

	h1 = (h1 ^ DERIVATION_KEY_BYTES) & UInt32Math.U32_MAX
	h2 = (h2 ^ DERIVATION_KEY_BYTES) & UInt32Math.U32_MAX
	h3 = (h3 ^ DERIVATION_KEY_BYTES) & UInt32Math.U32_MAX
	h4 = (h4 ^ DERIVATION_KEY_BYTES) & UInt32Math.U32_MAX

	h1 = UInt32Math.add(UInt32Math.add(UInt32Math.add(h1, h2, status), h3, status), h4, status)
	h2 = UInt32Math.add(h2, h1, status)
	h3 = UInt32Math.add(h3, h1, status)
	h4 = UInt32Math.add(h4, h1, status)

	h1 = UInt32Math.fmix32(h1, status)
	h2 = UInt32Math.fmix32(h2, status)
	h3 = UInt32Math.fmix32(h3, status)
	h4 = UInt32Math.fmix32(h4, status)

	h1 = UInt32Math.add(UInt32Math.add(UInt32Math.add(h1, h2, status), h3, status), h4, status)
	h2 = UInt32Math.add(h2, h1, status)
	h3 = UInt32Math.add(h3, h1, status)
	h4 = UInt32Math.add(h4, h1, status)
	return [h1, h2, h3, h4]


static func _derive_state(
		seed_hi: int,
		seed_lo: int,
		purpose_id: int,
		owner_id: int,
		ordinal: int,
		status: SimStatus
) -> Array[int]:
	var key: Array[int] = [
		DERIVATION_DOMAIN,
		seed_lo,
		seed_hi,
		purpose_id,
		owner_id,
		ordinal,
	]
	var hash_seed: int = 0
	while status.is_ok():
		var state: Array[int] = _murmur_x86_128_six_words(key, hash_seed, status)
		if not status.is_ok():
			return [1, 0, 0, 0]
		if state[0] != 0 or state[1] != 0 or state[2] != 0 or state[3] != 0:
			return state
		if hash_seed == UInt32Math.U32_MAX:
			status.fail(
				SimStatus.Code.INVALID_RNG_STATE,
				SimStatus.Operation.RNG_DERIVE,
				seed_hi,
				seed_lo
			)
			return [1, 0, 0, 0]
		hash_seed += 1
	return [1, 0, 0, 0]


static func _build_from_key(
		seed_hi: int,
		seed_lo: int,
		purpose_id: int,
		owner_id: int,
		ordinal: int,
		status: SimStatus
) -> SimRng:
	var rng: SimRng = SimRng.new()
	if not status.is_ok():
		return rng
	var state: Array[int] = _derive_state(
		seed_hi, seed_lo, purpose_id, owner_id, ordinal, status
	)
	if not status.is_ok():
		return rng
	rng._root_seed_hi = seed_hi
	rng._root_seed_lo = seed_lo
	rng._purpose_id = purpose_id
	rng._owner_id = owner_id
	rng._ordinal = ordinal
	rng._assign_state(state[0], state[1], state[2], state[3], 0, 0)
	rng._initialized = true
	rng._has_derivation_key = true
	return rng


static func derive(
		seed_hi: int,
		seed_lo: int,
		purpose_id: int,
		owner_id: int,
		ordinal: int,
		status: SimStatus
) -> SimRng:
	if not status.is_ok():
		return SimRng.new()
	if not _is_valid_key(seed_hi, seed_lo, purpose_id, owner_id, ordinal):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.RNG_DERIVE,
			purpose_id,
			owner_id
		)
		return SimRng.new()
	return _build_from_key(
		seed_hi, seed_lo, purpose_id, owner_id, ordinal, status
	)


static func from_seed_words(seed_hi: int, seed_lo: int, status: SimStatus) -> SimRng:
	if not status.is_ok():
		return SimRng.new()
	if not UInt32Math.is_u32(seed_hi) or not UInt32Math.is_u32(seed_lo):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.RNG_DERIVE,
			seed_hi,
			seed_lo
		)
		return SimRng.new()
	# Purpose 0 is reserved for this root/default stream constructor.
	return _build_from_key(seed_hi, seed_lo, 0, 0, 0, status)


func derive_substream(
		purpose_id: int, owner_id: int, ordinal: int, status: SimStatus
) -> SimRng:
	if not _require_initialized(status, SimStatus.Operation.RNG_DERIVE):
		return SimRng.new()
	if not _has_derivation_key:
		status.fail(
			SimStatus.Code.INVALID_RNG_STATE,
			SimStatus.Operation.RNG_DERIVE,
			purpose_id,
			owner_id
		)
		return SimRng.new()
	return derive(
		_root_seed_hi, _root_seed_lo, purpose_id, owner_id, ordinal, status
	)


func _assign_state(
		p_s0: int,
		p_s1: int,
		p_s2: int,
		p_s3: int,
		p_count_hi: int,
		p_count_lo: int
) -> void:
	_s0 = p_s0
	_s1 = p_s1
	_s2 = p_s2
	_s3 = p_s3
	_draw_count_hi = p_count_hi
	_draw_count_lo = p_count_lo


func restore_state(
		p_s0: int,
		p_s1: int,
		p_s2: int,
		p_s3: int,
		p_count_hi: int,
		p_count_lo: int,
		status: SimStatus
) -> void:
	if not status.is_ok():
		return
	if not (
		UInt32Math.is_u32(p_s0)
		and UInt32Math.is_u32(p_s1)
		and UInt32Math.is_u32(p_s2)
		and UInt32Math.is_u32(p_s3)
		and UInt32Math.is_u32(p_count_hi)
		and UInt32Math.is_u32(p_count_lo)
	):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.RNG_RESTORE,
			p_s0,
			p_s1
		)
		return
	if p_s0 == 0 and p_s1 == 0 and p_s2 == 0 and p_s3 == 0:
		status.fail(
			SimStatus.Code.INVALID_RNG_STATE,
			SimStatus.Operation.RNG_RESTORE,
			0,
			0
		)
		return
	_assign_state(p_s0, p_s1, p_s2, p_s3, p_count_hi, p_count_lo)
	_initialized = true


func copy(status: SimStatus) -> SimRng:
	var result: SimRng = SimRng.new()
	if not _require_initialized(status, SimStatus.Operation.RNG_COPY):
		return result
	result._root_seed_hi = _root_seed_hi
	result._root_seed_lo = _root_seed_lo
	result._purpose_id = _purpose_id
	result._owner_id = _owner_id
	result._ordinal = _ordinal
	result._assign_state(_s0, _s1, _s2, _s3, _draw_count_hi, _draw_count_lo)
	result._initialized = _initialized
	result._has_derivation_key = _has_derivation_key
	return result


func root_seed_hi() -> int:
	return _root_seed_hi


func root_seed_lo() -> int:
	return _root_seed_lo


func purpose_id() -> int:
	return _purpose_id


func owner_id() -> int:
	return _owner_id


func ordinal() -> int:
	return _ordinal


func state_word(index: int, status: SimStatus) -> int:
	if not _require_initialized(status, SimStatus.Operation.RNG_STATE_READ):
		return 0
	match index:
		0:
			return _s0
		1:
			return _s1
		2:
			return _s2
		3:
			return _s3
		_:
			status.fail(
				SimStatus.Code.INVALID_RANGE,
				SimStatus.Operation.RNG_STATE_READ,
				index,
				0
			)
			return 0


func draw_count_hi() -> int:
	return _draw_count_hi


func draw_count_lo() -> int:
	return _draw_count_lo


func _can_increment_draw_count() -> bool:
	return not (
		_draw_count_hi == UInt32Math.U32_MAX
		and _draw_count_lo == UInt32Math.U32_MAX
	)


func _increment_draw_count() -> void:
	_draw_count_lo = (_draw_count_lo + 1) & UInt32Math.U32_MAX
	if _draw_count_lo == 0:
		_draw_count_hi = (_draw_count_hi + 1) & UInt32Math.U32_MAX


func next_u32(status: SimStatus) -> int:
	if not _require_initialized(status, SimStatus.Operation.RNG_DRAW):
		return 0
	if not _can_increment_draw_count():
		status.fail(
			SimStatus.Code.RNG_COUNTER_OVERFLOW,
			SimStatus.Operation.RNG_DRAW,
			_draw_count_hi,
			_draw_count_lo
		)
		return 0

	# Compute the complete transition before mutating state.
	var result: int = UInt32Math.multiply(
		UInt32Math.rotate_left(UInt32Math.multiply(_s1, 5, status), 7, status),
		9,
		status
	)
	var shifted: int = (_s1 << 9) & UInt32Math.U32_MAX
	var next_s2: int = (_s2 ^ _s0) & UInt32Math.U32_MAX
	var next_s3: int = (_s3 ^ _s1) & UInt32Math.U32_MAX
	var next_s1: int = (_s1 ^ next_s2) & UInt32Math.U32_MAX
	var next_s0: int = (_s0 ^ next_s3) & UInt32Math.U32_MAX
	next_s2 = (next_s2 ^ shifted) & UInt32Math.U32_MAX
	next_s3 = UInt32Math.rotate_left(next_s3, 11, status)
	if not status.is_ok():
		return 0

	_s0 = next_s0
	_s1 = next_s1
	_s2 = next_s2
	_s3 = next_s3
	_increment_draw_count()
	return result


func next_below(bound_exclusive: int, status: SimStatus) -> int:
	if not _require_initialized(status, SimStatus.Operation.RNG_RANGE):
		return 0
	# U-23 has not yet decided whether a degenerate range consumes a draw.
	# Reject it before touching the stream so callers cannot depend on either
	# consumption policy prematurely.
	if bound_exclusive < 2 or bound_exclusive > UInt32Math.U32_SPACE:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.RNG_RANGE,
			bound_exclusive,
			0
		)
		return 0
	var limit: int = UInt32Math.U32_SPACE - (
		UInt32Math.U32_SPACE % bound_exclusive
	)
	var initial_s0: int = _s0
	var initial_s1: int = _s1
	var initial_s2: int = _s2
	var initial_s3: int = _s3
	var initial_count_hi: int = _draw_count_hi
	var initial_count_lo: int = _draw_count_lo
	while status.is_ok():
		var draw: int = next_u32(status)
		if not status.is_ok():
			# Rejection sampling is one logical operation. If a later primitive
			# draw fails (for example at counter overflow), none of its earlier
			# rejected draws may remain committed.
			_assign_state(
				initial_s0,
				initial_s1,
				initial_s2,
				initial_s3,
				initial_count_hi,
				initial_count_lo
			)
			return 0
		if draw < limit:
			return draw % bound_exclusive
	return 0


func next_range(minimum: int, maximum_exclusive: int, status: SimStatus) -> int:
	if not _require_initialized(status, SimStatus.Operation.RNG_RANGE):
		return 0
	if not FixMath.can_sub_int(maximum_exclusive, minimum):
		status.fail(
			SimStatus.Code.INT64_OVERFLOW,
			SimStatus.Operation.RNG_RANGE,
			minimum,
			maximum_exclusive
		)
		return 0
	var width: int = maximum_exclusive - minimum
	# Width 1 is the range form of U-23's unresolved degenerate case.
	if width < 2 or width > UInt32Math.U32_SPACE:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.RNG_RANGE,
			minimum,
			maximum_exclusive
		)
		return 0
	var offset: int = next_below(width, status)
	if not status.is_ok():
		return 0
	if not FixMath.can_add_int(minimum, offset):
		status.fail(
			SimStatus.Code.INT64_OVERFLOW,
			SimStatus.Operation.RNG_RANGE,
			minimum,
			offset
		)
		return 0
	return minimum + offset


func chance(numerator: int, denominator: int, status: SimStatus) -> bool:
	if not _require_initialized(status, SimStatus.Operation.RNG_CHANCE):
		return false
	# U-23 has not yet decided whether 0% and 100% consume a draw. Treat both
	# as invalid until that policy is approved, before touching stream state.
	if (
		denominator < 2
		or denominator > UInt32Math.U32_SPACE
		or numerator <= 0
		or numerator >= denominator
	):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.RNG_CHANCE,
			numerator,
			denominator
		)
		return false
	return next_below(denominator, status) < numerator
