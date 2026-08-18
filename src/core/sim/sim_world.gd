class_name SimWorld
extends RefCounted
## Engine-independent deterministic fixed-step world.
##
## Authoritative arrays are kept in numeric ID order. Initial objects are
## assigned in stable spawn-key order; runtime requests are collected and
## assigned at the next step in `(tick, cause body, event type, ordinal)` order.
## A failed step rolls every authoritative collection and counter back.

const TICKS_PER_SECOND: int = 120
const DT_NUM: int = 1
const DT_DEN: int = 120
const DEFAULT_BASE_FRICTION_RAW: int = 163840 # Q(5/2)
const DEFAULT_STOP_SPEED_RAW: int = FixMath.HALF_RAW # Q(1/2)


class BodySpawnRequest:
	var tick: int
	var cause_body_id: int
	var event_type_id: int
	var ordinal: int
	var body_template: SimBody

	func _init(
			p_tick: int,
			p_cause_body_id: int,
			p_event_type_id: int,
			p_ordinal: int,
			p_body_template: SimBody
	) -> void:
		tick = p_tick
		cause_body_id = p_cause_body_id
		event_type_id = p_event_type_id
		ordinal = p_ordinal
		body_template = p_body_template.copy()

	func copy() -> BodySpawnRequest:
		return BodySpawnRequest.new(
			tick, cause_body_id, event_type_id, ordinal, body_template
		)


class ZoneSpawnRequest:
	var tick: int
	var cause_body_id: int
	var event_type_id: int
	var ordinal: int
	var zone_template: SimZone

	func _init(
			p_tick: int,
			p_cause_body_id: int,
			p_event_type_id: int,
			p_ordinal: int,
			p_zone_template: SimZone
	) -> void:
		tick = p_tick
		cause_body_id = p_cause_body_id
		event_type_id = p_event_type_id
		ordinal = p_ordinal
		zone_template = p_zone_template.copy()

	func copy() -> ZoneSpawnRequest:
		return ZoneSpawnRequest.new(
			tick, cause_body_id, event_type_id, ordinal, zone_template
		)


class ZoneEffects:
	var friction_raw: int
	var acceleration: FixVec2

	func _init(p_friction_raw: int, p_acceleration: FixVec2) -> void:
		friction_raw = p_friction_raw
		acceleration = p_acceleration.copy()


var _initialized: bool = false
var _tick: int = 0
var _base_friction_raw: int = DEFAULT_BASE_FRICTION_RAW
var _stop_speed_raw: int = DEFAULT_STOP_SPEED_RAW
var _rng: SimRng = SimRng.new()

var _bodies: Array[SimBody] = []
var _zones: Array[SimZone] = []
var _next_body_id: int = 1
var _next_zone_id: int = 1

var _events: Array[SimEvent] = []
var _event_cursor: int = 0
var _next_event_sequence: int = 1

var _pending_body_spawns: Array[BodySpawnRequest] = []
var _pending_zone_spawns: Array[ZoneSpawnRequest] = []
var _initial_bodies_committed: bool = false
var _initial_zones_committed: bool = false


static func create(
		seed_hi: int,
		seed_lo: int,
		status: SimStatus,
		base_friction_raw: int = DEFAULT_BASE_FRICTION_RAW,
		stop_speed_raw: int = DEFAULT_STOP_SPEED_RAW
) -> SimWorld:
	var world: SimWorld = SimWorld.new()
	if not status.is_ok():
		return world
	if base_friction_raw < 0 or stop_speed_raw < 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.WORLD_CREATE,
			base_friction_raw,
			stop_speed_raw
		)
		return world
	var stop_vector: FixVec2 = FixVec2.from_raw(stop_speed_raw, 0)
	if not SimLimits.is_speed_valid(stop_vector, status):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_RANGE,
				SimStatus.Operation.WORLD_CREATE,
				stop_speed_raw,
				0
			)
		return world
	var dt_denominator_raw: int = FixMath.multiply_int(
		FixMath.SCALE, DT_DEN, status
	)
	var friction_tick_raw: int = FixMath.multiply_int(
		base_friction_raw, DT_NUM, status
	)
	if not status.is_ok():
		return world
	if friction_tick_raw >= dt_denominator_raw:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.WORLD_CREATE,
			base_friction_raw,
			dt_denominator_raw
		)
		return world
	var rng: SimRng = SimRng.from_seed_words(seed_hi, seed_lo, status)
	if not status.is_ok():
		return world
	world._base_friction_raw = base_friction_raw
	world._stop_speed_raw = stop_speed_raw
	world._rng = rng
	world._initialized = true
	return world


func _require_initialized(status: SimStatus, operation: int) -> bool:
	if not status.is_ok():
		return false
	if _initialized:
		return true
	status.fail(SimStatus.Code.INVALID_SIM_STATE, operation, 0, 0)
	return false


static func _advance_u32_counter(value: int) -> int:
	if value == UInt32Math.U32_MAX:
		return 0
	return value + 1


static func _copy_body_array(source: Array[SimBody]) -> Array[SimBody]:
	var result: Array[SimBody] = []
	for body: SimBody in source:
		result.append(body.copy())
	return result


static func _copy_zone_array(source: Array[SimZone]) -> Array[SimZone]:
	var result: Array[SimZone] = []
	for zone: SimZone in source:
		result.append(zone.copy())
	return result


static func _copy_event_array(source: Array[SimEvent]) -> Array[SimEvent]:
	var result: Array[SimEvent] = []
	for event: SimEvent in source:
		result.append(event.copy())
	return result


static func _copy_body_requests(
		source: Array[BodySpawnRequest]
) -> Array[BodySpawnRequest]:
	var result: Array[BodySpawnRequest] = []
	for request: BodySpawnRequest in source:
		result.append(request.copy())
	return result


static func _copy_zone_requests(
		source: Array[ZoneSpawnRequest]
) -> Array[ZoneSpawnRequest]:
	var result: Array[ZoneSpawnRequest] = []
	for request: ZoneSpawnRequest in source:
		result.append(request.copy())
	return result


static func _sorted_key_indices(keys: Array[int]) -> Array[int]:
	var order: Array[int] = []
	for index: int in range(keys.size()):
		order.append(index)
	for index: int in range(1, order.size()):
		var value: int = order[index]
		var cursor: int = index - 1
		while cursor >= 0 and keys[order[cursor]] > keys[value]:
			order[cursor + 1] = order[cursor]
			cursor -= 1
		order[cursor + 1] = value
	return order


static func _body_request_less(
		left: BodySpawnRequest, right: BodySpawnRequest
) -> bool:
	if left.tick != right.tick:
		return left.tick < right.tick
	if left.cause_body_id != right.cause_body_id:
		return left.cause_body_id < right.cause_body_id
	if left.event_type_id != right.event_type_id:
		return left.event_type_id < right.event_type_id
	return left.ordinal < right.ordinal


static func _zone_request_less(
		left: ZoneSpawnRequest, right: ZoneSpawnRequest
) -> bool:
	if left.tick != right.tick:
		return left.tick < right.tick
	if left.cause_body_id != right.cause_body_id:
		return left.cause_body_id < right.cause_body_id
	if left.event_type_id != right.event_type_id:
		return left.event_type_id < right.event_type_id
	return left.ordinal < right.ordinal


static func _sort_body_requests(
		source: Array[BodySpawnRequest]
) -> Array[BodySpawnRequest]:
	var result: Array[BodySpawnRequest] = _copy_body_requests(source)
	for index: int in range(1, result.size()):
		var value: BodySpawnRequest = result[index]
		var cursor: int = index - 1
		while cursor >= 0 and _body_request_less(value, result[cursor]):
			result[cursor + 1] = result[cursor]
			cursor -= 1
		result[cursor + 1] = value
	return result


static func _sort_zone_requests(
		source: Array[ZoneSpawnRequest]
) -> Array[ZoneSpawnRequest]:
	var result: Array[ZoneSpawnRequest] = _copy_zone_requests(source)
	for index: int in range(1, result.size()):
		var value: ZoneSpawnRequest = result[index]
		var cursor: int = index - 1
		while cursor >= 0 and _zone_request_less(value, result[cursor]):
			result[cursor + 1] = result[cursor]
			cursor -= 1
		result[cursor + 1] = value
	return result


func _find_body_index(body_id: int) -> int:
	for index: int in range(_bodies.size()):
		if _bodies[index].id() == body_id:
			return index
		if _bodies[index].id() > body_id:
			break
	return -1


func _find_zone_index(zone_id: int) -> int:
	for index: int in range(_zones.size()):
		if _zones[index].id() == zone_id:
			return index
		if _zones[index].id() > zone_id:
			break
	return -1


func _append_body_event(
		type_id: int,
		body: SimBody,
		vector: FixVec2,
		status: SimStatus
) -> void:
	if not status.is_ok():
		return
	if _next_event_sequence == 0:
		status.fail(
			SimStatus.Code.COUNTER_EXHAUSTED,
			SimStatus.Operation.WORLD_EVENT_APPEND,
			0,
			type_id
		)
		return
	var sequence: int = _next_event_sequence
	var event: SimEvent = SimEvent.create(
		_tick,
		0,
		sequence,
		type_id,
		body.id(),
		0,
		0,
		SimEvent.CauseId.NONE,
		body.position(),
		vector,
		0,
		0,
		0,
		status
	)
	if not status.is_ok():
		return
	_events.append(event)
	_next_event_sequence = _advance_u32_counter(sequence)


func add_initial_bodies(
		spawn_keys: Array[int],
		body_templates: Array[SimBody],
		status: SimStatus
) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_ADD_BODY):
		return
	if (
		_initial_bodies_committed
		or _tick != 0
		or not _bodies.is_empty()
		or spawn_keys.size() != body_templates.size()
	):
		status.fail(
			SimStatus.Code.INVALID_SIM_STATE,
			SimStatus.Operation.WORLD_ADD_BODY,
			spawn_keys.size(),
			body_templates.size()
		)
		return
	for index: int in range(spawn_keys.size()):
		if (
			not UInt32Math.is_u32(spawn_keys[index])
			or body_templates[index] == null
			or body_templates[index].id() != 0
		):
			status.fail(
				SimStatus.Code.INVALID_ARGUMENT,
				SimStatus.Operation.WORLD_ADD_BODY,
				spawn_keys[index],
				index
			)
			return

	var order: Array[int] = _sorted_key_indices(spawn_keys)
	for index: int in range(1, order.size()):
		if spawn_keys[order[index - 1]] == spawn_keys[order[index]]:
			status.fail(
				SimStatus.Code.DUPLICATE_ID,
				SimStatus.Operation.WORLD_ADD_BODY,
				spawn_keys[order[index]],
				0
			)
			return

	var bodies_before: Array[SimBody] = _copy_body_array(_bodies)
	var events_before: Array[SimEvent] = _copy_event_array(_events)
	var next_id_before: int = _next_body_id
	var next_sequence_before: int = _next_event_sequence
	for source_index: int in order:
		if _next_body_id == 0:
			status.fail(
				SimStatus.Code.COUNTER_EXHAUSTED,
				SimStatus.Operation.WORLD_ADD_BODY,
				0,
				spawn_keys[source_index]
			)
			break
		var assigned: SimBody = body_templates[source_index].assigned_copy(
			_next_body_id, status
		)
		if not status.is_ok():
			break
		_next_body_id = _advance_u32_counter(_next_body_id)
		_bodies.append(assigned)
		_append_body_event(
			SimEvent.TypeId.BODY_ADDED, assigned, assigned.velocity(), status
		)
		if not status.is_ok():
			break
	if not status.is_ok():
		_bodies = bodies_before
		_events = events_before
		_next_body_id = next_id_before
		_next_event_sequence = next_sequence_before
		return
	_initial_bodies_committed = true


func add_initial_zones(
		spawn_keys: Array[int],
		zone_templates: Array[SimZone],
		status: SimStatus
) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_ADD_ZONE):
		return
	if (
		_initial_zones_committed
		or _tick != 0
		or not _zones.is_empty()
		or spawn_keys.size() != zone_templates.size()
	):
		status.fail(
			SimStatus.Code.INVALID_SIM_STATE,
			SimStatus.Operation.WORLD_ADD_ZONE,
			spawn_keys.size(),
			zone_templates.size()
		)
		return
	for index: int in range(spawn_keys.size()):
		if (
			not UInt32Math.is_u32(spawn_keys[index])
			or zone_templates[index] == null
			or zone_templates[index].id() != 0
		):
			status.fail(
				SimStatus.Code.INVALID_ARGUMENT,
				SimStatus.Operation.WORLD_ADD_ZONE,
				spawn_keys[index],
				index
			)
			return
	var order: Array[int] = _sorted_key_indices(spawn_keys)
	for index: int in range(1, order.size()):
		if spawn_keys[order[index - 1]] == spawn_keys[order[index]]:
			status.fail(
				SimStatus.Code.DUPLICATE_ID,
				SimStatus.Operation.WORLD_ADD_ZONE,
				spawn_keys[order[index]],
				0
			)
			return

	var zones_before: Array[SimZone] = _copy_zone_array(_zones)
	var next_id_before: int = _next_zone_id
	for source_index: int in order:
		if _next_zone_id == 0:
			status.fail(
				SimStatus.Code.COUNTER_EXHAUSTED,
				SimStatus.Operation.WORLD_ADD_ZONE,
				0,
				spawn_keys[source_index]
			)
			break
		var assigned: SimZone = zone_templates[source_index].assigned_copy(
			_next_zone_id, status
		)
		if not status.is_ok():
			break
		_next_zone_id = _advance_u32_counter(_next_zone_id)
		_zones.append(assigned)
	if not status.is_ok():
		_zones = zones_before
		_next_zone_id = next_id_before
		return
	_initial_zones_committed = true


func insert_body_for_restore(body: SimBody, status: SimStatus) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_ADD_BODY):
		return
	if body == null or body.id() == 0 or _find_body_index(body.id()) >= 0:
		status.fail(
			SimStatus.Code.DUPLICATE_ID if body != null else SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.WORLD_ADD_BODY,
			0 if body == null else body.id(),
			0
		)
		return
	var insert_at: int = 0
	while insert_at < _bodies.size() and _bodies[insert_at].id() < body.id():
		insert_at += 1
	_bodies.insert(insert_at, body.copy())
	if _next_body_id != 0 and body.id() >= _next_body_id:
		_next_body_id = _advance_u32_counter(body.id())


func insert_zone_for_restore(zone: SimZone, status: SimStatus) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_ADD_ZONE):
		return
	if zone == null or zone.id() == 0 or _find_zone_index(zone.id()) >= 0:
		status.fail(
			SimStatus.Code.DUPLICATE_ID if zone != null else SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.WORLD_ADD_ZONE,
			0 if zone == null else zone.id(),
			0
		)
		return
	var insert_at: int = 0
	while insert_at < _zones.size() and _zones[insert_at].id() < zone.id():
		insert_at += 1
	_zones.insert(insert_at, zone.copy())
	if _next_zone_id != 0 and zone.id() >= _next_zone_id:
		_next_zone_id = _advance_u32_counter(zone.id())


func queue_body_spawn(
		body_template: SimBody,
		cause_body_id: int,
		event_type_id: int,
		ordinal: int,
		status: SimStatus
) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_QUEUE_SPAWN):
		return
	if (
		body_template == null
		or body_template.id() != 0
		or not UInt32Math.is_u32(cause_body_id)
		or event_type_id < 0
		or event_type_id > 0xFFFF
		or not UInt32Math.is_u32(ordinal)
	):
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.WORLD_QUEUE_SPAWN,
			cause_body_id,
			ordinal
		)
		return
	for request: BodySpawnRequest in _pending_body_spawns:
		if (
			request.tick == _tick
			and request.cause_body_id == cause_body_id
			and request.event_type_id == event_type_id
			and request.ordinal == ordinal
		):
			status.fail(
				SimStatus.Code.DUPLICATE_ID,
				SimStatus.Operation.WORLD_QUEUE_SPAWN,
				cause_body_id,
				ordinal
			)
			return
	_pending_body_spawns.append(BodySpawnRequest.new(
		_tick, cause_body_id, event_type_id, ordinal, body_template
	))


func queue_zone_spawn(
		zone_template: SimZone,
		cause_body_id: int,
		event_type_id: int,
		ordinal: int,
		status: SimStatus
) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_QUEUE_SPAWN):
		return
	if (
		zone_template == null
		or zone_template.id() != 0
		or not UInt32Math.is_u32(cause_body_id)
		or event_type_id < 0
		or event_type_id > 0xFFFF
		or not UInt32Math.is_u32(ordinal)
	):
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.WORLD_QUEUE_SPAWN,
			cause_body_id,
			ordinal
		)
		return
	for request: ZoneSpawnRequest in _pending_zone_spawns:
		if (
			request.tick == _tick
			and request.cause_body_id == cause_body_id
			and request.event_type_id == event_type_id
			and request.ordinal == ordinal
		):
			status.fail(
				SimStatus.Code.DUPLICATE_ID,
				SimStatus.Operation.WORLD_QUEUE_SPAWN,
				cause_body_id,
				ordinal
			)
			return
	_pending_zone_spawns.append(ZoneSpawnRequest.new(
		_tick, cause_body_id, event_type_id, ordinal, zone_template
	))


func _flush_pending_spawns(status: SimStatus) -> void:
	var body_requests: Array[BodySpawnRequest] = _sort_body_requests(
		_pending_body_spawns
	)
	for request: BodySpawnRequest in body_requests:
		if _next_body_id == 0:
			status.fail(
				SimStatus.Code.COUNTER_EXHAUSTED,
				SimStatus.Operation.WORLD_ADD_BODY,
				request.cause_body_id,
				request.ordinal
			)
			return
		var assigned: SimBody = request.body_template.assigned_copy(
			_next_body_id, status
		)
		if not status.is_ok():
			return
		_next_body_id = _advance_u32_counter(_next_body_id)
		_bodies.append(assigned)
		_append_body_event(
			SimEvent.TypeId.BODY_ADDED, assigned, assigned.velocity(), status
		)
		if not status.is_ok():
			return
	_pending_body_spawns.clear()

	var zone_requests: Array[ZoneSpawnRequest] = _sort_zone_requests(
		_pending_zone_spawns
	)
	for request: ZoneSpawnRequest in zone_requests:
		if _next_zone_id == 0:
			status.fail(
				SimStatus.Code.COUNTER_EXHAUSTED,
				SimStatus.Operation.WORLD_ADD_ZONE,
				request.cause_body_id,
				request.ordinal
			)
			return
		var assigned: SimZone = request.zone_template.assigned_copy(
			_next_zone_id, status
		)
		if not status.is_ok():
			return
		_next_zone_id = _advance_u32_counter(_next_zone_id)
		_zones.append(assigned)
	_pending_zone_spawns.clear()


func remove_body(body_id: int, status: SimStatus) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_REMOVE_BODY):
		return
	var index: int = _find_body_index(body_id)
	if index < 0:
		status.fail(
			SimStatus.Code.NOT_FOUND,
			SimStatus.Operation.WORLD_REMOVE_BODY,
			body_id,
			0
		)
		return
	var body: SimBody = _bodies[index]
	_append_body_event(
		SimEvent.TypeId.BODY_REMOVED, body, body.velocity(), status
	)
	if not status.is_ok():
		return
	_bodies.remove_at(index)


func remove_zone(zone_id: int, status: SimStatus) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_REMOVE_ZONE):
		return
	var index: int = _find_zone_index(zone_id)
	if index < 0:
		status.fail(
			SimStatus.Code.NOT_FOUND,
			SimStatus.Operation.WORLD_REMOVE_ZONE,
			zone_id,
			0
		)
		return
	_zones.remove_at(index)


func set_body_velocity(
		body_id: int, velocity: FixVec2, status: SimStatus
) -> void:
	if not _require_initialized(status, SimStatus.Operation.WORLD_BODY_UPDATE):
		return
	var index: int = _find_body_index(body_id)
	if index < 0:
		status.fail(
			SimStatus.Code.NOT_FOUND,
			SimStatus.Operation.WORLD_BODY_UPDATE,
			body_id,
			0
		)
		return
	var updated: SimBody = _bodies[index].with_velocity(velocity, status)
	if status.is_ok():
		_bodies[index] = updated


func _compose_zone_effects(
		body: SimBody, status: SimStatus
) -> ZoneEffects:
	var effective_friction_raw: int = FixMath.mul_raw(
		_base_friction_raw, body.friction_multiplier_raw(), status
	)
	var acceleration: FixVec2 = FixVec2.zero()
	var position: FixVec2 = body.position()
	for zone: SimZone in _zones:
		if not zone.contains_point_strict(position, status):
			if not status.is_ok():
				return ZoneEffects.new(0, FixVec2.zero())
			continue
		effective_friction_raw = FixMath.mul_raw(
			effective_friction_raw,
			zone.friction_multiplier_raw(),
			status
		)
		acceleration = acceleration.add(zone.acceleration(), status)
		if not status.is_ok():
			return ZoneEffects.new(0, FixVec2.zero())
	return ZoneEffects.new(effective_friction_raw, acceleration)


func _step_body(
		body: SimBody,
		stopped_vectors: Array[FixVec2],
		status: SimStatus
) -> SimBody:
	if not body.alive():
		stopped_vectors.append(FixVec2.zero())
		return body.copy()
	var effects: ZoneEffects = _compose_zone_effects(body, status)
	if not status.is_ok():
		stopped_vectors.append(FixVec2.zero())
		return SimBody.new()
	var effective_friction_raw: int = effects.friction_raw
	var acceleration: FixVec2 = effects.acceleration

	var damping_denominator: int = FixMath.multiply_int(
		FixMath.SCALE, DT_DEN, status
	)
	var friction_numerator: int = FixMath.multiply_int(
		effective_friction_raw, DT_NUM, status
	)
	if not status.is_ok():
		stopped_vectors.append(FixVec2.zero())
		return SimBody.new()
	if friction_numerator < 0 or friction_numerator >= damping_denominator:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.WORLD_STEP,
			body.id(),
			effective_friction_raw
		)
		stopped_vectors.append(FixVec2.zero())
		return SimBody.new()
	var damping_numerator: int = FixMath.sub_raw(
		damping_denominator, friction_numerator, status
	)
	var old_velocity: FixVec2 = body.velocity()
	var damped_velocity: FixVec2 = FixVec2.from_raw(
		FixMath.mul_ratio_raw(
			old_velocity.x_raw(), damping_numerator, damping_denominator, status
		),
		FixMath.mul_ratio_raw(
			old_velocity.y_raw(), damping_numerator, damping_denominator, status
		)
	)
	var acceleration_delta: FixVec2 = FixVec2.from_raw(
		FixMath.mul_ratio_raw(
			acceleration.x_raw(), DT_NUM, DT_DEN, status
		),
		FixMath.mul_ratio_raw(
			acceleration.y_raw(), DT_NUM, DT_DEN, status
		)
	)
	var next_velocity: FixVec2 = damped_velocity.add(
		acceleration_delta, status
	)
	if not SimLimits.is_speed_valid(next_velocity, status):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_RANGE,
				SimStatus.Operation.WORLD_STEP,
				body.id(),
				next_velocity.length_raw(SimStatus.new())
			)
		stopped_vectors.append(FixVec2.zero())
		return SimBody.new()

	var position_delta: FixVec2 = FixVec2.from_raw(
		FixMath.mul_ratio_raw(
			next_velocity.x_raw(), DT_NUM, DT_DEN, status
		),
		FixMath.mul_ratio_raw(
			next_velocity.y_raw(), DT_NUM, DT_DEN, status
		)
	)
	var next_position: FixVec2 = body.position().add(position_delta, status)
	if not status.is_ok():
		stopped_vectors.append(FixVec2.zero())
		return SimBody.new()
	if not SimLimits.is_position_valid(next_position):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.WORLD_STEP,
			body.id(),
			next_position.x_raw()
		)
		stopped_vectors.append(FixVec2.zero())
		return SimBody.new()

	var stopped_vector: FixVec2 = FixVec2.zero()
	if (
		acceleration.is_zero()
		and not next_velocity.is_zero()
		and next_velocity.is_length_below_raw(_stop_speed_raw, status)
	):
		stopped_vector = next_velocity.copy()
		next_velocity = FixVec2.zero()
	stopped_vectors.append(stopped_vector)
	return body.with_motion(next_position, next_velocity, status)


func step(status: SimStatus) -> bool:
	if not _require_initialized(status, SimStatus.Operation.WORLD_STEP):
		return false
	if _tick == FixMath.INT64_MAX:
		status.fail(
			SimStatus.Code.COUNTER_EXHAUSTED,
			SimStatus.Operation.WORLD_STEP,
			_tick,
			0
		)
		return false

	var tick_before: int = _tick
	var bodies_before: Array[SimBody] = _copy_body_array(_bodies)
	var zones_before: Array[SimZone] = _copy_zone_array(_zones)
	var events_before: Array[SimEvent] = _copy_event_array(_events)
	var body_requests_before: Array[BodySpawnRequest] = _copy_body_requests(
		_pending_body_spawns
	)
	var zone_requests_before: Array[ZoneSpawnRequest] = _copy_zone_requests(
		_pending_zone_spawns
	)
	var next_body_before: int = _next_body_id
	var next_zone_before: int = _next_zone_id
	var next_sequence_before: int = _next_event_sequence

	_flush_pending_spawns(status)
	var next_bodies: Array[SimBody] = []
	var stopped_vectors: Array[FixVec2] = []
	if status.is_ok():
		for body: SimBody in _bodies:
			next_bodies.append(_step_body(body, stopped_vectors, status))
			if not status.is_ok():
				break
	if status.is_ok():
		_bodies = next_bodies
		for index: int in range(_bodies.size()):
			if not stopped_vectors[index].is_zero():
				_append_body_event(
					SimEvent.TypeId.BODY_STOPPED,
					_bodies[index],
					stopped_vectors[index],
					status
				)
				if not status.is_ok():
					break
	if status.is_ok():
		_tick += 1
		return true

	_tick = tick_before
	_bodies = bodies_before
	_zones = zones_before
	_events = events_before
	_pending_body_spawns = body_requests_before
	_pending_zone_spawns = zone_requests_before
	_next_body_id = next_body_before
	_next_zone_id = next_zone_before
	_next_event_sequence = next_sequence_before
	return false


func consume_next_event(status: SimStatus) -> SimEvent:
	if not _require_initialized(status, SimStatus.Operation.WORLD_EVENT_CONSUME):
		return SimEvent.new()
	if _event_cursor >= _events.size():
		status.fail(
			SimStatus.Code.NOT_FOUND,
			SimStatus.Operation.WORLD_EVENT_CONSUME,
			_event_cursor,
			_events.size()
		)
		return SimEvent.new()
	var result: SimEvent = _events[_event_cursor].copy()
	_event_cursor += 1
	return result


func copy(status: SimStatus) -> SimWorld:
	var result: SimWorld = SimWorld.new()
	if not _require_initialized(status, SimStatus.Operation.WORLD_COPY):
		return result
	var rng_copy: SimRng = _rng.copy(status)
	if not status.is_ok():
		return result
	result._initialized = true
	result._tick = _tick
	result._base_friction_raw = _base_friction_raw
	result._stop_speed_raw = _stop_speed_raw
	result._rng = rng_copy
	result._bodies = _copy_body_array(_bodies)
	result._zones = _copy_zone_array(_zones)
	result._next_body_id = _next_body_id
	result._next_zone_id = _next_zone_id
	result._events = _copy_event_array(_events)
	result._event_cursor = _event_cursor
	result._next_event_sequence = _next_event_sequence
	result._pending_body_spawns = _copy_body_requests(_pending_body_spawns)
	result._pending_zone_spawns = _copy_zone_requests(_pending_zone_spawns)
	result._initial_bodies_committed = _initial_bodies_committed
	result._initial_zones_committed = _initial_zones_committed
	return result


func next_random_u32(status: SimStatus) -> int:
	if not _require_initialized(status, SimStatus.Operation.WORLD_RNG_DRAW):
		return 0
	return _rng.next_u32(status)


func tick() -> int:
	return _tick


func base_friction_raw() -> int:
	return _base_friction_raw


func stop_speed_raw() -> int:
	return _stop_speed_raw


func root_seed_hi() -> int:
	return _rng.root_seed_hi()


func root_seed_lo() -> int:
	return _rng.root_seed_lo()


func rng_draw_count_hi() -> int:
	return _rng.draw_count_hi()


func rng_draw_count_lo() -> int:
	return _rng.draw_count_lo()


func body_count() -> int:
	return _bodies.size()


func body_at(index: int, status: SimStatus) -> SimBody:
	if not _require_initialized(status, SimStatus.Operation.WORLD_BODY_UPDATE):
		return SimBody.new()
	if index < 0 or index >= _bodies.size():
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.WORLD_BODY_UPDATE,
			index,
			_bodies.size()
		)
		return SimBody.new()
	return _bodies[index].copy()


func body_by_id(body_id: int, status: SimStatus) -> SimBody:
	if not _require_initialized(status, SimStatus.Operation.WORLD_BODY_UPDATE):
		return SimBody.new()
	var index: int = _find_body_index(body_id)
	if index < 0:
		status.fail(
			SimStatus.Code.NOT_FOUND,
			SimStatus.Operation.WORLD_BODY_UPDATE,
			body_id,
			0
		)
		return SimBody.new()
	return _bodies[index].copy()


func zone_count() -> int:
	return _zones.size()


func zone_at(index: int, status: SimStatus) -> SimZone:
	if not _require_initialized(status, SimStatus.Operation.WORLD_ADD_ZONE):
		return SimZone.new()
	if index < 0 or index >= _zones.size():
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.WORLD_ADD_ZONE,
			index,
			_zones.size()
		)
		return SimZone.new()
	return _zones[index].copy()


func event_count() -> int:
	return _events.size()


func event_cursor() -> int:
	return _event_cursor


func next_event_sequence() -> int:
	return _next_event_sequence


func event_at(index: int, status: SimStatus) -> SimEvent:
	if not _require_initialized(status, SimStatus.Operation.WORLD_EVENT_CONSUME):
		return SimEvent.new()
	if index < 0 or index >= _events.size():
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.WORLD_EVENT_CONSUME,
			index,
			_events.size()
		)
		return SimEvent.new()
	return _events[index].copy()


func next_body_id() -> int:
	return _next_body_id


func next_zone_id() -> int:
	return _next_zone_id


func has_pending_requests() -> bool:
	return (
		not _pending_body_spawns.is_empty()
		or not _pending_zone_spawns.is_empty()
	)
