extends SceneTree
## Headless P0-4 canonical snapshot and determinism acceptance adapter.

const SCENARIOS_PATH := "res://pipeline/tests/fixtures/p0_scenarios.json"
const PERMUTATION_SEED_HI: int = 0x5EED5EED
const PERMUTATION_SEED_LO: int = 0x00000004

var _failures: int = 0


func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % case_id)
		return
	_failures += 1
	print("[FAIL] %s%s" % [case_id, "" if detail.is_empty() else " — " + detail])


func _status_detail(status: SimStatus) -> String:
	return "code=%d op=%d a=%d b=%d" % [
		status.code(), status.operation(), status.detail_a(), status.detail_b()
	]


func _as_int(value: Variant) -> int:
	return int(value)


func _vec(raw: Variant) -> FixVec2:
	var pair: Array = raw as Array
	return FixVec2.from_raw(_as_int(pair[0]), _as_int(pair[1]))


func _vertices(raw: Variant) -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	for pair: Variant in raw as Array:
		result.append(_vec(pair))
	return result


func _seed_word(seed: String, start: int) -> int:
	return seed.substr(start, 8).hex_to_int()


func _permutation(count: int, variant: int, purpose: int, status: SimStatus) -> Array[int]:
	var order: Array[int] = []
	for index: int in range(count):
		order.append(index)
	if variant == 1:
		order.reverse()
		return order
	if variant < 2:
		return order
	var root: SimRng = SimRng.from_seed_words(
		PERMUTATION_SEED_HI, PERMUTATION_SEED_LO, status
	)
	var rng: SimRng = root.derive_substream(
		purpose, variant - 2, 0, status
	)
	for cursor: int in range(count - 1, 0, -1):
		var selected: int = rng.next_below(cursor + 1, status)
		var held: int = order[cursor]
		order[cursor] = order[selected]
		order[selected] = held
	return order


func _build_world(scenario: Dictionary, variant: int, status: SimStatus) -> SimWorld:
	var seed: String = scenario["seed"]
	var config: Dictionary = scenario["world"]
	var world: SimWorld = SimWorld.create(
		_seed_word(seed, 0),
		_seed_word(seed, 8),
		status,
		_as_int(config["base_friction_raw"]),
		_as_int(config["stop_speed_raw"]),
		_as_int(config["restitution_raw"])
	)
	world.configure_boundary(
		_vertices(config["boundary_vertices"]),
		_as_int(config["boundary_type"]),
		status
	)

	var raw_zones: Array = config["zones"]
	var zone_order: Array[int] = _permutation(raw_zones.size(), variant, 2, status)
	var zone_keys: Array[int] = []
	var zone_templates: Array[SimZone] = []
	for source_index: int in zone_order:
		var item: Dictionary = raw_zones[source_index]
		zone_keys.append(_as_int(item["spawn_key"]))
		zone_templates.append(SimZone.create_unassigned(
			_vertices(item["vertices"]),
			_as_int(item["friction_raw"]),
			_vec(item["acceleration"]),
			status,
			_as_int(item["flags"])
		))
	world.add_initial_zones(zone_keys, zone_templates, status)

	var raw_bodies: Array = config["bodies"]
	var body_order: Array[int] = _permutation(raw_bodies.size(), variant, 1, status)
	var body_keys: Array[int] = []
	var body_templates: Array[SimBody] = []
	for source_index: int in body_order:
		var item: Dictionary = raw_bodies[source_index]
		body_keys.append(_as_int(item["spawn_key"]))
		body_templates.append(SimBody.create_unassigned(
			_vec(item["position"]),
			_vec(item["velocity"]),
			_as_int(item["radius_raw"]),
			_as_int(item["mass_raw"]),
			status,
			_as_int(item["friction_raw"]),
			bool(item["destructible"])
		))
	world.add_initial_bodies(body_keys, body_templates, status)
	return world


func _apply_inputs(world: SimWorld, inputs: Array, tick: int, status: SimStatus) -> void:
	for raw_input: Variant in inputs:
		var item: Dictionary = raw_input
		if _as_int(item["tick"]) != tick:
			continue
		var power_raw: int = _as_int(item["power_raw"])
		var speed_raw: int = FixMath.multiply_int(power_raw, 2048, status)
		var direction: FixVec2 = FixTrigLut.direction(_as_int(item["angle"]), status)
		world.set_body_velocity(
			_as_int(item["body_id"]), direction.scaled(speed_raw, status), status
		)


func _snapshot_record(world: SimWorld, status: SimStatus) -> Array[String]:
	var snapshot: SimSnapshot = SimSnapshot.capture(world, status)
	var bytes: PackedByteArray = snapshot.encode(status)
	var pure_hex: String = SimStateHash.hex_digest(bytes, status)
	var godot_hex: String = _godot_sha256(bytes)
	if pure_hex != godot_hex:
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.HASH_SHA256,
			world.tick(),
			0
		)
	return [pure_hex, bytes.hex_encode()]


func _godot_sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if not bytes.is_empty() and context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _run_scenario(
		scenario: Dictionary,
		variant: int,
		emit_snapshots: bool = false
) -> Dictionary:
	var status := SimStatus.new()
	var world: SimWorld = _build_world(scenario, variant, status)
	var hashes: Array[String] = []
	var snapshots: Array[String] = []
	var first_substep_count: int = 0
	var ticks: int = _as_int(scenario["ticks"])
	var inputs: Array = scenario["inputs"]
	for tick: int in range(ticks + 1):
		var record: Array[String] = _snapshot_record(world, status)
		hashes.append(record[0])
		if emit_snapshots:
			snapshots.append(record[1])
		if tick == ticks or not status.is_ok():
			break
		_apply_inputs(world, inputs, tick, status)
		world.step(status)
		if tick == 0:
			first_substep_count = world.last_substep_count()
	return {
		"ok": status.is_ok(),
		"detail": _status_detail(status),
		"hashes": hashes,
		"snapshots": snapshots,
		"world": world,
		"first_substep_count": first_substep_count,
	}


func _matches_snapshot_sequence(
		scenario: Dictionary,
		variant: int,
		expected_snapshots: Array
) -> bool:
	var status := SimStatus.new()
	var world: SimWorld = _build_world(scenario, variant, status)
	var ticks: int = _as_int(scenario["ticks"])
	var inputs: Array = scenario["inputs"]
	if expected_snapshots.size() != ticks + 1:
		return false
	for tick: int in range(ticks + 1):
		var bytes: PackedByteArray = SimSnapshot.capture(world, status).encode(status)
		if not status.is_ok() or bytes.hex_encode() != String(expected_snapshots[tick]):
			return false
		if tick < ticks:
			_apply_inputs(world, inputs, tick, status)
			world.step(status)
	return status.is_ok()


func _test_sha_vectors() -> void:
	var vectors: Array[Array] = [
		["", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"],
		["abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"],
		["The quick brown fox jumps over the lazy dog", "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"],
	]
	var all_match: bool = true
	for vector: Array in vectors:
		var status := SimStatus.new()
		var bytes: PackedByteArray = String(vector[0]).to_utf8_buffer()
		var pure: String = SimStateHash.hex_digest(bytes, status)
		var engine: String = _godot_sha256(bytes)
		all_match = all_match and status.is_ok() and pure == vector[1] and engine == pure
	_check("DET-SHA256-VECTORS-001", all_match)


func _test_schema_failures(scenario: Dictionary) -> void:
	var status := SimStatus.new()
	var world: SimWorld = _build_world(scenario, 0, status)
	var original: SimSnapshot = SimSnapshot.capture(world, status)
	var wrong_version: SimSnapshot = original.copy_for_test()
	wrong_version.set_schema_version_for_test(3)
	var version_status := SimStatus.new()
	wrong_version.encode(version_status)
	_check(
		"DET-SCHEMA-VERSION-001",
		version_status.code() == SimStatus.Code.UNSUPPORTED_SCHEMA
	)
	var width_snapshot: SimSnapshot = original.copy_for_test()
	width_snapshot._next_body_id = 0x100000000
	var width_status := SimStatus.new()
	width_snapshot.encode(width_status)
	var enum_snapshot: SimSnapshot = original.copy_for_test()
	enum_snapshot._boundary_type = 99
	var enum_status := SimStatus.new()
	enum_snapshot.encode(enum_status)
	_check(
		"DET-SCHEMA-RANGE-001",
		width_status.code() == SimStatus.Code.INVALID_SNAPSHOT
		and enum_status.code() == SimStatus.Code.INVALID_SNAPSHOT
	)
	var canonical: PackedByteArray = original.encode(status)
	_check(
		"DET-CANONICAL-PREFIX-001",
		status.is_ok()
		and canonical.slice(0, 9) == SimSnapshot.MAGIC
		and canonical[9] == 2
		and canonical[10] == 0
	)
	var pending_status := SimStatus.new()
	var pending_world: SimWorld = _build_world(scenario, 0, pending_status)
	var pending_body: SimBody = SimBody.create_unassigned(
		FixVec2.from_raw(0, 6553600),
		FixVec2.zero(),
		2097152,
		4194304,
		pending_status
	)
	pending_world.queue_body_spawn(pending_body, 0, 1, 1, pending_status)
	var capture_status := SimStatus.new()
	SimSnapshot.capture(pending_world, capture_status)
	_check(
		"DET-STABLE-BOUNDARY-001",
		pending_status.is_ok()
		and capture_status.code() == SimStatus.Code.INVALID_SIM_STATE
	)


func _test_restore_and_sensitivity(scenario: Dictionary) -> void:
	var result: Dictionary = _run_scenario(scenario, 0, false)
	var world: SimWorld = result["world"]
	var status := SimStatus.new()
	var original: SimSnapshot = SimSnapshot.capture(world, status)
	var original_bytes: PackedByteArray = original.encode(status)
	var restored: SimWorld = original.restore_world(status)
	var restored_bytes: PackedByteArray = SimSnapshot.capture(restored, status).encode(status)
	var continuation_equal: bool = status.is_ok() and original_bytes == restored_bytes
	for index: int in range(120):
		world.step(status)
		restored.step(status)
		var left: PackedByteArray = SimSnapshot.capture(world, status).encode(status)
		var right: PackedByteArray = SimSnapshot.capture(restored, status).encode(status)
		continuation_equal = continuation_equal and left == right
		if not continuation_equal or not status.is_ok():
			break
	_check("DET-SNAPSHOT-RESTORE-001", continuation_equal, _status_detail(status))

	var mutations: Array[SimSnapshot] = []
	var changed: SimSnapshot = original.copy_for_test()
	changed._tick += 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._root_seed_hi ^= 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._root_seed_lo ^= 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._base_friction_raw += 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._stop_speed_raw += 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._restitution_raw += 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._next_body_id += 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._next_zone_id += 1
	mutations.append(changed)
	for word_index: int in range(4):
		changed = original.copy_for_test()
		changed._rng_state[word_index] ^= 1
		mutations.append(changed)
	changed = original.copy_for_test()
	changed._rng_draw_hi += 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._rng_draw_lo += 1
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._boundary_type = SimWorld.BoundaryType.KILL
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._boundary_vertices[0] = FixVec2.from_raw(
		changed._boundary_vertices[0].x_raw() + 1,
		changed._boundary_vertices[0].y_raw()
	)
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._boundary_type = SimWorld.BoundaryType.NONE
	changed._boundary_vertices.clear()
	mutations.append(changed)
	if not original._zones.is_empty():
		changed = original.copy_for_test()
		changed._zones[0]._id += 1
		changed._next_zone_id += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._zones[0]._flags ^= SimZone.FLAG_KILL
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._zones[0]._friction_multiplier_raw += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._zones[0]._acceleration = FixVec2.from_raw(1, 0)
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._zones[0]._polygon._vertices[0] = FixVec2.from_raw(
			changed._zones[0]._polygon._vertices[0].x_raw() + 1,
			changed._zones[0]._polygon._vertices[0].y_raw()
		)
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._zones.clear()
		mutations.append(changed)
	if not original._bodies.is_empty():
		changed = original.copy_for_test()
		changed._bodies[0]._id += 1
		changed._next_body_id += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies[0]._alive = not changed._bodies[0]._alive
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies[0]._destructible = not changed._bodies[0]._destructible
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies[0]._position = FixVec2.from_raw(
			changed._bodies[0]._position.x_raw() + 1,
			changed._bodies[0]._position.y_raw()
		)
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies[0]._velocity = FixVec2.from_raw(
			changed._bodies[0]._velocity.x_raw() + 1,
			changed._bodies[0]._velocity.y_raw()
		)
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies[0]._radius_raw += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies[0]._mass_raw += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies[0]._friction_multiplier_raw += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._bodies.clear()
		mutations.append(changed)
	changed = original.copy_for_test()
	changed._event_cursor = 0 if original._event_cursor != 0 else mini(1, original._events.size())
	mutations.append(changed)
	changed = original.copy_for_test()
	changed._next_event_sequence += 1
	changed._events[-1]._sequence += 1
	mutations.append(changed)
	if not original._events.is_empty():
		changed = original.copy_for_test()
		changed._events[0]._tick += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._substep += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._type_id = SimEvent.TypeId.BODY_REMOVED
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._source_body_id += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._target_body_id += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._zone_id += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._cause_id = SimEvent.CauseId.KILL_ZONE
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._position = FixVec2.from_raw(1, 0)
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._vector = FixVec2.from_raw(1, 0)
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._value_a += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._value_b += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events[0]._flags += 1
		mutations.append(changed)
		changed = original.copy_for_test()
		changed._events.clear()
		changed._event_cursor = 0
		changed._next_event_sequence = 1
		mutations.append(changed)
	var all_sensitive: bool = true
	var failed_mutation: int = -1
	var base_hash: String = SimStateHash.hex_digest(original_bytes, status)
	for mutation_index: int in range(mutations.size()):
		var mutation: SimSnapshot = mutations[mutation_index]
		var mutation_status := SimStatus.new()
		var mutation_bytes: PackedByteArray = mutation.encode(mutation_status)
		var mutation_hash: String = SimStateHash.hex_digest(mutation_bytes, mutation_status)
		all_sensitive = (
			all_sensitive
			and mutation_status.is_ok()
			and mutation_bytes != original_bytes
			and mutation_hash != base_hash
		)
		if not all_sensitive and failed_mutation < 0:
			failed_mutation = mutation_index
	# P0 owns only the root stream, so its key is fixed to zero. Verify those
	# exact encoded fields directly without constructing an invalid stream.
	for offset: int in [63, 65, 69]:
		var raw_mutation: PackedByteArray = original_bytes.duplicate()
		raw_mutation[offset] ^= 1
		all_sensitive = (
			all_sensitive
			and SimStateHash.hex_digest(raw_mutation, SimStatus.new()) != base_hash
		)
	_check(
		"DET-FIELD-SENSITIVITY-001",
		all_sensitive,
		"failed_mutation=%d count=%d" % [failed_mutation, mutations.size()]
	)


func _mutated_scenario(source: Dictionary, field: String) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	var input: Dictionary = result["inputs"][0]
	match field:
		"angle":
			input["angle"] = _as_int(input["angle"]) + 1
		"power":
			input["power_raw"] = _as_int(input["power_raw"]) + 1
		"tick":
			input["tick"] = 1
	return result


func _test_input_sensitivity(scenario: Dictionary, baseline_final: String) -> void:
	var all_different: bool = true
	for field: String in ["angle", "power", "tick"]:
		var result: Dictionary = _run_scenario(_mutated_scenario(scenario, field), 0)
		var hashes: Array = result["hashes"]
		all_different = (
			all_different
			and bool(result["ok"])
			and not hashes.is_empty()
			and String(hashes[-1]) != baseline_final
		)
	_check("DET-INPUT-SENSITIVITY-001", all_different)


func _load_scenarios() -> Array:
	var text: String = FileAccess.get_file_as_string(SCENARIOS_PATH)
	var root: Variant = JSON.parse_string(text)
	if not root is Dictionary:
		return []
	return (root as Dictionary).get("scenarios", []) as Array


func _initialize() -> void:
	print("== P0-4 canonical snapshot / state hash / determinism ==")
	var quick_allowed: bool = (
		OS.has_environment("P0_ALLOW_QUICK")
		and OS.get_environment("P0_ALLOW_QUICK") == "1"
	)
	_test_sha_vectors()
	var scenarios: Array = _load_scenarios()
	_check("DET-SCENARIO-LOAD-001", scenarios.size() == 6)
	if scenarios.size() != 6:
		print("P0_DETERMINISM_RESULT: FAIL")
		quit(1)
		return
	_test_schema_failures(scenarios[0])

	var baselines: Dictionary = {}
	var base_results: Dictionary = {}
	var base_ok: bool = true
	for raw_scenario: Variant in scenarios:
		var scenario: Dictionary = raw_scenario
		var scenario_id: String = scenario["scenario_id"]
		var result: Dictionary = _run_scenario(scenario, 0, true)
		base_results[scenario_id] = result
		baselines[scenario_id] = result["hashes"]
		base_ok = base_ok and bool(result["ok"])
		var hashes: Array = result["hashes"]
		var snapshots: Array = result["snapshots"]
		for tick: int in range(hashes.size()):
			print("P0_SNAPSHOT|%s|%d|%s|%s" % [
				scenario_id, tick, hashes[tick], snapshots[tick]
			])
	_check("DET-GOLDEN-SCENARIOS-001", base_ok)
	_check(
		"DET-SUBSTEP-TUNNEL-N9-001",
		int(base_results["substep_tunnel"]["first_substep_count"]) == 9
	)

	var permutation_count: int = 30
	if OS.has_environment("P0_PERMUTATION_COUNT"):
		permutation_count = int(OS.get_environment("P0_PERMUTATION_COUNT"))
	print("[INFO] DET-PROFILE permutations=%d" % permutation_count)
	var permutations_ok: bool = true
	for raw_scenario: Variant in scenarios:
		var scenario: Dictionary = raw_scenario
		var scenario_id: String = scenario["scenario_id"]
		for variant: int in range(1, permutation_count + 2):
			permutations_ok = (
				permutations_ok
				and _matches_snapshot_sequence(
					scenario, variant, base_results[scenario_id]["snapshots"]
				)
			)
			if not permutations_ok:
				break
	_check(
		"DET-INSERTION-PERMUTATIONS-001",
		permutations_ok and (permutation_count == 30 or quick_allowed)
	)

	var repeat_count: int = 1000
	if OS.has_environment("P0_REPEAT_COUNT"):
		repeat_count = int(OS.get_environment("P0_REPEAT_COUNT"))
	print("[INFO] DET-PROFILE repeats=%d" % repeat_count)
	var repeat_ok: bool = true
	var chain: Dictionary
	for raw_scenario: Variant in scenarios:
		if String((raw_scenario as Dictionary)["scenario_id"]) == "circle_chain":
			chain = raw_scenario
			break
	for repetition: int in range(repeat_count):
		repeat_ok = (
			repeat_ok
			and _matches_snapshot_sequence(
				chain, 0, base_results["circle_chain"]["snapshots"]
			)
		)
		if not repeat_ok:
			break
	_check(
		"DET-REPEAT-COUNT-001",
		repeat_ok and (repeat_count == 1000 or quick_allowed)
	)

	var head_hashes: Array = baselines["circle_head_on"]
	_test_input_sensitivity(scenarios[0], String(head_hashes[-1]))
	_test_restore_and_sensitivity(scenarios[4])
	if _failures == 0:
		print("P0_DETERMINISM_RESULT: PASS")
		quit(0)
	else:
		print("P0_DETERMINISM_RESULT: FAIL (%d)" % _failures)
		quit(1)
