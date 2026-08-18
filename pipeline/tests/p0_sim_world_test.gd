extends SceneTree
## Headless acceptance tests for docs/specs/p0_sim_world.md.

const SimStatusScript := preload("res://src/core/sim/sim_status.gd")
const FixMathScript := preload("res://src/core/sim/fix_math.gd")
const FixVec2Script := preload("res://src/core/sim/fix_vec2.gd")
const SimBodyScript := preload("res://src/core/sim/sim_body.gd")
const SimZoneScript := preload("res://src/core/sim/sim_zone.gd")
const SimEventScript := preload("res://src/core/sim/sim_event.gd")
const SimWorldScript := preload("res://src/core/sim/sim_world.gd")

var _failures: int = 0


func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % case_id)
		return
	_failures += 1
	var suffix: String = "" if detail.is_empty() else " — %s" % detail
	print("[FAIL] %s%s" % [case_id, suffix])


func _status_detail(status: SimStatus, body_id: int = 0) -> String:
	return "body=%d code=%d op=%d a=%d b=%d" % [
		body_id,
		status.code(),
		status.operation(),
		status.detail_a(),
		status.detail_b(),
	]


func _q(value: int) -> int:
	return value * FixMath.SCALE


func _body_raw(
		position_x_raw: int,
		position_y_raw: int,
		velocity_x_raw: int,
		velocity_y_raw: int,
		status: SimStatus,
		friction_multiplier_raw: int = FixMath.ONE_RAW
) -> SimBody:
	return SimBody.create_unassigned(
		FixVec2.from_raw(position_x_raw, position_y_raw),
		FixVec2.from_raw(velocity_x_raw, velocity_y_raw),
		_q(32),
		_q(64),
		status,
		friction_multiplier_raw,
		true
	)


func _body_units(
		position_x: int,
		position_y: int,
		velocity_x: int,
		velocity_y: int,
		status: SimStatus,
		friction_multiplier_raw: int = FixMath.ONE_RAW
) -> SimBody:
	return _body_raw(
		_q(position_x),
		_q(position_y),
		_q(velocity_x),
		_q(velocity_y),
		status,
		friction_multiplier_raw
	)


func _square(radius_units: int, status: SimStatus) -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	result.append(FixVec2.from_ints(-radius_units, -radius_units, status))
	result.append(FixVec2.from_ints(radius_units, -radius_units, status))
	result.append(FixVec2.from_ints(radius_units, radius_units, status))
	result.append(FixVec2.from_ints(-radius_units, radius_units, status))
	return result


func _worlds_match(left: SimWorld, right: SimWorld, status: SimStatus) -> bool:
	if (
		left.tick() != right.tick()
		or left.body_count() != right.body_count()
		or left.zone_count() != right.zone_count()
		or left.event_count() != right.event_count()
		or left.next_body_id() != right.next_body_id()
		or left.next_zone_id() != right.next_zone_id()
		or left.next_event_sequence() != right.next_event_sequence()
	):
		return false
	for index: int in range(left.body_count()):
		var a: SimBody = left.body_at(index, status)
		var b: SimBody = right.body_at(index, status)
		if (
			a.id() != b.id()
			or a.alive() != b.alive()
			or a.destructible() != b.destructible()
			or not a.position().is_equal(b.position())
			or not a.velocity().is_equal(b.velocity())
			or a.radius_raw() != b.radius_raw()
			or a.mass_raw() != b.mass_raw()
			or a.friction_multiplier_raw() != b.friction_multiplier_raw()
		):
			return false
	for index: int in range(left.event_count()):
		var event_a: SimEvent = left.event_at(index, status)
		var event_b: SimEvent = right.event_at(index, status)
		if (
			event_a.sequence() != event_b.sequence()
			or event_a.type_id() != event_b.type_id()
			or event_a.source_body_id() != event_b.source_body_id()
		):
			return false
	return status.is_ok()


func _test_contract_and_empty_world() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0x01234567, 0x89ABCDEF, status)
	var stepped: bool = world.step(status)
	_check(
		"SW-CONTRACT-001",
		SimWorld.TICKS_PER_SECOND == 120
		and SimWorld.DT_NUM == 1
		and SimWorld.DT_DEN == 120
		and SimWorld.DEFAULT_BASE_FRICTION_RAW == 163840
		and SimWorld.DEFAULT_STOP_SPEED_RAW == 32768
		and SimEvent.TypeId.NONE == 0
		and SimEvent.TypeId.BODY_ADDED == 1
		and SimEvent.TypeId.BODY_REMOVED == 2
		and SimEvent.TypeId.BODY_STOPPED == 3
		and SimEvent.CauseId.NONE == 0
		and SimStatus.Code.INVALID_SIM_STATE == 12
		and SimStatus.Operation.WORLD_RNG_DRAW == 46
		and status.is_ok()
	)
	_check(
		"SW-EMPTY-001",
		stepped
		and world.tick() == 1
		and world.body_count() == 0
		and world.zone_count() == 0
		and world.event_count() == 0,
		_status_detail(status)
	)


func _test_stable_initial_ids() -> void:
	var status_a := SimStatus.new()
	var status_b := SimStatus.new()
	var world_a: SimWorld = SimWorld.create(0, 11, status_a)
	var world_b: SimWorld = SimWorld.create(0, 11, status_b)
	var keys_a: Array[int] = [30, 10, 20]
	var bodies_a: Array[SimBody] = [
		_body_units(30, 0, 0, 0, status_a),
		_body_units(10, 0, 0, 0, status_a),
		_body_units(20, 0, 0, 0, status_a),
	]
	var keys_b: Array[int] = [20, 30, 10]
	var bodies_b: Array[SimBody] = [
		_body_units(20, 0, 0, 0, status_b),
		_body_units(30, 0, 0, 0, status_b),
		_body_units(10, 0, 0, 0, status_b),
	]
	world_a.add_initial_bodies(keys_a, bodies_a, status_a)
	world_b.add_initial_bodies(keys_b, bodies_b, status_b)
	for unused: int in range(5):
		world_a.step(status_a)
		world_b.step(status_b)
	var inspect_status := SimStatus.new()
	var first: SimBody = world_a.body_at(0, inspect_status)
	var second: SimBody = world_a.body_at(1, inspect_status)
	var third: SimBody = world_a.body_at(2, inspect_status)
	_check(
		"SW-ID-ORDER-001",
		status_a.is_ok()
		and status_b.is_ok()
		and first.id() == 1 and first.position().x_raw() == _q(10)
		and second.id() == 2 and second.position().x_raw() == _q(20)
		and third.id() == 3 and third.position().x_raw() == _q(30)
		and _worlds_match(world_a, world_b, inspect_status),
		_status_detail(status_a)
	)


func _test_exact_default_friction() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 12, status)
	var keys: Array[int] = [1]
	var bodies: Array[SimBody] = [_body_units(0, 0, 48, 0, status)]
	world.add_initial_bodies(keys, bodies, status)
	var stepped: bool = world.step(status)
	var body: SimBody = world.body_at(0, status)
	_check(
		"SW-FRICTION-47-48-001",
		stepped
		and body.velocity().x_raw() == _q(47)
		and body.velocity().y_raw() == 0
		and body.position().x_raw() == 25668
		and body.position().y_raw() == 0
		and world.tick() == 1
		and world.event_count() == 1
		and status.is_ok(),
		_status_detail(status, body.id())
	)


func _test_overlapping_zones() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 13, status)
	var zone_low_key: SimZone = SimZone.create_unassigned(
		_square(100, status),
		FixMath.from_ratio(1, 2, status),
		FixVec2.from_ints(0, 240, status),
		status
	)
	var zone_high_key: SimZone = SimZone.create_unassigned(
		_square(100, status),
		FixMath.from_int(2, status),
		FixVec2.from_ints(120, 0, status),
		status
	)
	var zone_keys: Array[int] = [20, 10]
	var zones: Array[SimZone] = [zone_high_key, zone_low_key]
	world.add_initial_zones(zone_keys, zones, status)
	var body_keys: Array[int] = [1, 2]
	var bodies: Array[SimBody] = [
		_body_units(0, 0, 48, 0, status),
		_body_units(200, 0, 0, 0, status),
	]
	world.add_initial_bodies(body_keys, bodies, status)
	world.step(status)
	var inside: SimBody = world.body_by_id(1, status)
	var outside: SimBody = world.body_by_id(2, status)
	var first_zone: SimZone = world.zone_at(0, status)
	var second_zone: SimZone = world.zone_at(1, status)
	_check(
		"SW-ZONE-OVERLAP-001",
		first_zone.id() == 1
		and first_zone.acceleration().y_raw() == _q(240)
		and second_zone.id() == 2
		and second_zone.acceleration().x_raw() == _q(120)
		and inside.velocity().x_raw() == _q(48)
		and inside.velocity().y_raw() == _q(2)
		and inside.position().x_raw() == 26214
		and inside.position().y_raw() == 1092
		and outside.velocity().is_zero()
		and outside.position().x_raw() == _q(200)
		and status.is_ok(),
		_status_detail(status, inside.id())
	)


func _test_stop_threshold_and_acceleration_guard() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 14, status, 0)
	var keys: Array[int] = [1, 2]
	var bodies: Array[SimBody] = [
		_body_raw(0, 0, FixMath.HALF_RAW - 1, 0, status),
		_body_raw(_q(10), 0, FixMath.HALF_RAW, 0, status),
	]
	world.add_initial_bodies(keys, bodies, status)
	world.step(status)
	var below: SimBody = world.body_by_id(1, status)
	var exact: SimBody = world.body_by_id(2, status)
	var stopped_event: SimEvent = world.event_at(2, status)
	_check(
		"SW-STOP-STRICT-001",
		below.velocity().is_zero()
		and exact.velocity().x_raw() == FixMath.HALF_RAW
		and world.event_count() == 3
		and stopped_event.sequence() == 3
		and stopped_event.type_id() == SimEvent.TypeId.BODY_STOPPED
		and stopped_event.source_body_id() == 1
		and stopped_event.vector().x_raw() == FixMath.HALF_RAW - 1
		and status.is_ok(),
		_status_detail(status, 1)
	)

	var guard_status := SimStatus.new()
	var guard_world: SimWorld = SimWorld.create(0, 15, guard_status, 0)
	var guard_zone: SimZone = SimZone.create_unassigned(
		_square(10, guard_status),
		FixMath.ONE_RAW,
		FixVec2.from_raw(1, 0),
		guard_status
	)
	var guard_zone_keys: Array[int] = [1]
	var guard_zones: Array[SimZone] = [guard_zone]
	guard_world.add_initial_zones(guard_zone_keys, guard_zones, guard_status)
	var guard_body_keys: Array[int] = [1]
	var guard_bodies: Array[SimBody] = [
		_body_raw(0, 0, 1, 0, guard_status)
	]
	guard_world.add_initial_bodies(
		guard_body_keys, guard_bodies, guard_status
	)
	guard_world.step(guard_status)
	var guarded: SimBody = guard_world.body_by_id(1, guard_status)
	_check(
		"SW-STOP-ACCEL-GUARD-001",
		guarded.velocity().x_raw() == 1
		and guard_world.event_count() == 1
		and guard_status.is_ok(),
		_status_detail(guard_status, 1)
	)


func _test_rejections_and_atomic_step() -> void:
	var bad_radius_status := SimStatus.new()
	SimBody.create_unassigned(
		FixVec2.zero(),
		FixVec2.zero(),
		SimLimits.RADIUS_MIN_RAW - 1,
		_q(64),
		bad_radius_status
	)
	_check(
		"SW-BODY-RANGE-001",
		bad_radius_status.code() == SimStatus.Code.INVALID_RANGE
		and bad_radius_status.operation() == SimStatus.Operation.BODY_CREATE
	)

	var duplicate_status := SimStatus.new()
	var duplicate_world: SimWorld = SimWorld.create(0, 16, duplicate_status)
	var duplicate_keys: Array[int] = [7, 7]
	var duplicate_bodies: Array[SimBody] = [
		_body_units(0, 0, 0, 0, duplicate_status),
		_body_units(10, 0, 0, 0, duplicate_status),
	]
	duplicate_world.add_initial_bodies(
		duplicate_keys, duplicate_bodies, duplicate_status
	)
	_check(
		"SW-DUPLICATE-SPAWN-KEY-001",
		duplicate_status.code() == SimStatus.Code.DUPLICATE_ID
		and duplicate_world.body_count() == 0
		and duplicate_world.event_count() == 0
		and duplicate_world.next_body_id() == 1
	)

	var restore_status := SimStatus.new()
	var restore_world: SimWorld = SimWorld.create(0, 17, restore_status)
	var restored: SimBody = SimBody.restore(
		7,
		true,
		true,
		FixVec2.zero(),
		FixVec2.zero(),
		_q(32),
		_q(64),
		FixMath.ONE_RAW,
		restore_status
	)
	restore_world.insert_body_for_restore(restored, restore_status)
	var duplicate_id_status := SimStatus.new()
	restore_world.insert_body_for_restore(restored, duplicate_id_status)
	var missing_status := SimStatus.new()
	restore_world.remove_body(99, missing_status)
	_check(
		"SW-ID-REJECT-001",
		duplicate_id_status.code() == SimStatus.Code.DUPLICATE_ID
		and missing_status.code() == SimStatus.Code.NOT_FOUND
		and restore_world.body_count() == 1
		and restore_world.next_body_id() == 8
	)

	var atomic_status := SimStatus.new()
	var atomic_world: SimWorld = SimWorld.create(0, 18, atomic_status, 0)
	var fast_body: SimBody = _body_units(0, 0, 4096, 0, atomic_status)
	var atomic_body_keys: Array[int] = [1]
	var atomic_bodies: Array[SimBody] = [fast_body]
	atomic_world.add_initial_bodies(
		atomic_body_keys, atomic_bodies, atomic_status
	)
	var accelerator: SimZone = SimZone.create_unassigned(
		_square(100, atomic_status),
		FixMath.ONE_RAW,
		FixVec2.from_ints(120, 0, atomic_status),
		atomic_status
	)
	var atomic_zone_keys: Array[int] = [1]
	var atomic_zones: Array[SimZone] = [accelerator]
	atomic_world.add_initial_zones(
		atomic_zone_keys, atomic_zones, atomic_status
	)
	var event_count_before: int = atomic_world.event_count()
	var failed_step_status := SimStatus.new()
	var stepped: bool = atomic_world.step(failed_step_status)
	var unchanged: SimBody = atomic_world.body_by_id(1, SimStatus.new())
	_check(
		"SW-STEP-ATOMIC-001",
		not stepped
		and failed_step_status.code() == SimStatus.Code.INVALID_RANGE
		and failed_step_status.operation() == SimStatus.Operation.WORLD_STEP
		and failed_step_status.detail_a() == 1
		and atomic_world.tick() == 0
		and atomic_world.event_count() == event_count_before
		and unchanged.position().is_zero()
		and unchanged.velocity().x_raw() == _q(4096),
		_status_detail(failed_step_status, 1)
	)


func _test_runtime_request_sorting() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 19, status, 0)
	world.queue_body_spawn(
		_body_units(300, 0, 0, 0, status), 2, 5, 1, status
	)
	world.queue_body_spawn(
		_body_units(100, 0, 0, 0, status), 1, 9, 2, status
	)
	world.queue_body_spawn(
		_body_units(200, 0, 0, 0, status), 1, 9, 1, status
	)
	var pending_before: bool = world.has_pending_requests()
	world.step(status)
	var first: SimBody = world.body_at(0, status)
	var second: SimBody = world.body_at(1, status)
	var third: SimBody = world.body_at(2, status)
	_check(
		"SW-RUNTIME-SPAWN-ORDER-001",
		pending_before
		and not world.has_pending_requests()
		and first.id() == 1 and first.position().x_raw() == _q(200)
		and second.id() == 2 and second.position().x_raw() == _q(100)
		and third.id() == 3 and third.position().x_raw() == _q(300)
		and world.event_count() == 3
		and world.next_body_id() == 4
		and status.is_ok(),
		_status_detail(status)
	)


func _test_id_exhaustion_and_non_reuse() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 20, status, 0)
	var restored: SimBody = SimBody.restore(
		UInt32Math.U32_MAX,
		true,
		true,
		FixVec2.zero(),
		FixVec2.zero(),
		_q(32),
		_q(64),
		FixMath.ONE_RAW,
		status
	)
	world.insert_body_for_restore(restored, status)
	world.remove_body(UInt32Math.U32_MAX, status)
	var removal: SimEvent = world.event_at(0, status)
	world.queue_body_spawn(
		_body_units(0, 0, 0, 0, status), 0, 0, 0, status
	)
	var exhausted_status := SimStatus.new()
	var stepped: bool = world.step(exhausted_status)
	_check(
		"SW-ID-EXHAUSTION-001",
		not stepped
		and exhausted_status.code() == SimStatus.Code.COUNTER_EXHAUSTED
		and exhausted_status.operation() == SimStatus.Operation.WORLD_ADD_BODY
		and world.tick() == 0
		and world.body_count() == 0
		and world.next_body_id() == 0
		and world.event_count() == 1
		and removal.type_id() == SimEvent.TypeId.BODY_REMOVED
		and removal.source_body_id() == UInt32Math.U32_MAX
		and world.has_pending_requests()
		and status.is_ok(),
		_status_detail(exhausted_status)
	)


func _test_deep_clone_and_event_cursor() -> void:
	var status := SimStatus.new()
	var original: SimWorld = SimWorld.create(0x12345678, 0x9ABCDEF0, status, 0)
	var body_keys: Array[int] = [1, 2]
	var bodies: Array[SimBody] = [
		_body_units(0, 0, 0, 0, status),
		_body_units(10, 0, 0, 0, status),
	]
	original.add_initial_bodies(body_keys, bodies, status)
	var zone: SimZone = SimZone.create_unassigned(
		_square(50, status), FixMath.ONE_RAW, FixVec2.zero(), status
	)
	var zone_keys: Array[int] = [1]
	var zones: Array[SimZone] = [zone]
	original.add_initial_zones(zone_keys, zones, status)
	original.consume_next_event(status)
	original.queue_body_spawn(
		_body_units(20, 0, 0, 0, status), 2, 7, 0, status
	)
	var clone: SimWorld = original.copy(status)
	var clone_event: SimEvent = clone.consume_next_event(status)
	var clone_draw: int = clone.next_random_u32(status)
	clone.step(status)
	clone.remove_body(1, status)
	clone.remove_zone(1, status)
	_check(
		"SW-CLONE-DEEP-001",
		clone_event.sequence() == 2
		and clone_draw >= 0
		and clone.tick() == 1
		and clone.body_count() == 2
		and clone.zone_count() == 0
		and clone.event_cursor() == 2
		and clone.rng_draw_count_lo() == 1
		and original.tick() == 0
		and original.body_count() == 2
		and original.zone_count() == 1
		and original.event_count() == 2
		and original.event_cursor() == 1
		and original.next_event_sequence() == 3
		and original.rng_draw_count_lo() == 0
		and original.has_pending_requests()
		and status.is_ok(),
		_status_detail(status)
	)


func _initialize() -> void:
	print("== P0-2 SimBody / SimZone / SimEvent / SimWorld ==")
	_test_contract_and_empty_world()
	_test_stable_initial_ids()
	_test_exact_default_friction()
	_test_overlapping_zones()
	_test_stop_threshold_and_acceleration_guard()
	_test_rejections_and_atomic_step()
	_test_runtime_request_sorting()
	_test_id_exhaustion_and_non_reuse()
	_test_deep_clone_and_event_cursor()

	if _failures == 0:
		print("P0_SIM_WORLD_RESULT: PASS")
		quit(0)
	else:
		print("P0_SIM_WORLD_RESULT: FAIL (%d grouped checks)" % _failures)
		quit(1)
