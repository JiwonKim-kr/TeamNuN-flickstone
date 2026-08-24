class_name SimSnapshot
extends RefCounted
## Immutable canonical P0 simulation snapshot.
##
## Capture is allowed only at a stable world boundary. Encoding is a fixed,
## little-endian schema and never delegates to Variant/Object serialization.

const MAGIC: PackedByteArray = [70, 76, 73, 67, 75, 83, 73, 77, 0] # FLICKSIM\0
const LEGACY_SCHEMA_VERSION: int = 1
const SCHEMA_VERSION: int = 2


class ByteWriter:
	var data: PackedByteArray = PackedByteArray()

	func u8(value: int) -> void:
		data.append(value & 0xFF)

	func u16(value: int) -> void:
		for shift: int in range(0, 16, 8):
			u8(value >> shift)

	func u32(value: int) -> void:
		for shift: int in range(0, 32, 8):
			u8(value >> shift)

	func i64(value: int) -> void:
		for shift: int in range(0, 64, 8):
			u8(value >> shift)

	func vec2(value: FixVec2) -> void:
		i64(value.x_raw())
		i64(value.y_raw())


class ByteReader:
	var data: PackedByteArray
	var offset: int = 0
	var valid: bool = true

	func _init(source: PackedByteArray) -> void:
		data = source

	func remaining() -> int:
		return data.size() - offset

	func require(count: int) -> bool:
		if count < 0 or remaining() < count:
			valid = false
			return false
		return true

	func u8() -> int:
		if not require(1): return 0
		var value: int = data[offset]
		offset += 1
		return value

	func u16() -> int:
		var value: int = 0
		for shift: int in range(0, 16, 8): value |= u8() << shift
		return value

	func u32() -> int:
		var value: int = 0
		for shift: int in range(0, 32, 8): value |= u8() << shift
		return value

	func i64() -> int:
		var value: int = 0
		for shift: int in range(0, 64, 8): value |= u8() << shift
		return value

	func vec2() -> FixVec2:
		return FixVec2.from_raw(i64(), i64())


var _schema_version: int = SCHEMA_VERSION
var _tick: int = 0
var _root_seed_hi: int = 0
var _root_seed_lo: int = 0
var _base_friction_raw: int = 0
var _stop_speed_raw: int = 0
var _restitution_raw: int = 0
var _next_body_id: int = 1
var _next_zone_id: int = 1
var _next_link_id: int = 1

var _rng_purpose_id: int = 0
var _rng_owner_id: int = 0
var _rng_ordinal: int = 0
var _rng_state: Array[int] = [0, 0, 0, 0]
var _rng_draw_hi: int = 0
var _rng_draw_lo: int = 0

var _boundary_type: int = SimWorld.BoundaryType.NONE
var _boundary_vertices: Array[FixVec2] = []
var _zones: Array[SimZone] = []
var _bodies: Array[SimBody] = []
var _links: Array[SimLink] = []
var _event_cursor: int = 0
var _next_event_sequence: int = 1
var _events: Array[SimEvent] = []
var _initialized: bool = false


static func capture(world: SimWorld, status: SimStatus) -> SimSnapshot:
	var snapshot: SimSnapshot = SimSnapshot.new()
	if not status.is_ok():
		return snapshot
	if world == null or world.has_pending_requests():
		status.fail(
			SimStatus.Code.INVALID_SIM_STATE,
			SimStatus.Operation.SNAPSHOT_CAPTURE,
			0 if world == null else world.tick(),
			0
		)
		return snapshot

	var rng: SimRng = world.root_rng_copy(status)
	if not status.is_ok():
		return snapshot
	snapshot._tick = world.tick()
	snapshot._root_seed_hi = world.root_seed_hi()
	snapshot._root_seed_lo = world.root_seed_lo()
	snapshot._base_friction_raw = world.base_friction_raw()
	snapshot._stop_speed_raw = world.stop_speed_raw()
	snapshot._restitution_raw = world.restitution_raw()
	snapshot._next_body_id = world.next_body_id()
	snapshot._next_zone_id = world.next_zone_id()
	snapshot._next_link_id = world.next_link_id()
	snapshot._rng_purpose_id = rng.purpose_id()
	snapshot._rng_owner_id = rng.owner_id()
	snapshot._rng_ordinal = rng.ordinal()
	for index: int in range(4):
		snapshot._rng_state[index] = rng.state_word(index, status)
	snapshot._rng_draw_hi = rng.draw_count_hi()
	snapshot._rng_draw_lo = rng.draw_count_lo()
	if not status.is_ok():
		return SimSnapshot.new()

	snapshot._boundary_type = world.boundary_type()
	if snapshot._boundary_type != SimWorld.BoundaryType.NONE:
		var polygon: SimPolygon = world.boundary_polygon(status)
		for index: int in range(polygon.vertex_count()):
			snapshot._boundary_vertices.append(polygon.vertex(index, status))
	for index: int in range(world.zone_count()):
		snapshot._zones.append(world.zone_at(index, status))
	for index: int in range(world.body_count()):
		snapshot._bodies.append(world.body_at(index, status))
	for index: int in range(world.link_count()): snapshot._links.append(world.link_at(index, status))
	snapshot._event_cursor = world.event_cursor()
	snapshot._next_event_sequence = world.next_event_sequence()
	for index: int in range(world.event_count()):
		snapshot._events.append(world.event_at(index, status))
	if not status.is_ok() or not snapshot._validate(status):
		return SimSnapshot.new()
	snapshot._initialized = true
	return snapshot


static func decode(bytes: PackedByteArray, status: SimStatus) -> SimSnapshot:
	var snapshot := SimSnapshot.new()
	if not status.is_ok(): return snapshot
	var reader := ByteReader.new(bytes)
	if not reader.require(MAGIC.size() + 2):
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, bytes.size(), 0)
		return snapshot
	for expected: int in MAGIC:
		if reader.u8() != expected:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, reader.offset - 1, 0)
			return snapshot
	var decoded_version: int = reader.u16()
	if decoded_version != LEGACY_SCHEMA_VERSION and decoded_version != SCHEMA_VERSION:
		status.fail(SimStatus.Code.UNSUPPORTED_SCHEMA, SimStatus.Operation.SNAPSHOT_DECODE, decoded_version, SCHEMA_VERSION)
		return snapshot
	snapshot._schema_version = SCHEMA_VERSION
	snapshot._tick = reader.i64()
	snapshot._root_seed_lo = reader.u32(); snapshot._root_seed_hi = reader.u32()
	snapshot._base_friction_raw = reader.i64(); snapshot._stop_speed_raw = reader.i64(); snapshot._restitution_raw = reader.i64()
	snapshot._next_body_id = reader.u32(); snapshot._next_zone_id = reader.u32()
	var rng_count: int = reader.u32()
	if rng_count != 1:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, rng_count, 1); return SimSnapshot.new()
	snapshot._rng_purpose_id = reader.u16(); snapshot._rng_owner_id = reader.u32(); snapshot._rng_ordinal = reader.u32()
	for index: int in range(4): snapshot._rng_state[index] = reader.u32()
	snapshot._rng_draw_lo = reader.u32(); snapshot._rng_draw_hi = reader.u32()
	var has_boundary: int = reader.u8()
	if has_boundary > 1:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, has_boundary, 0); return SimSnapshot.new()
	if has_boundary == 1:
		snapshot._boundary_type = reader.u16()
		var vertex_count: int = reader.u32()
		if vertex_count < SimPolygon.MIN_VERTEX_COUNT or vertex_count > SimPolygon.MAX_VERTEX_COUNT or not reader.require(vertex_count * 16):
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, vertex_count, 0); return SimSnapshot.new()
		for index: int in range(vertex_count): snapshot._boundary_vertices.append(reader.vec2())
	var zone_count: int = reader.u32()
	if zone_count > reader.remaining() / 32:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, zone_count, reader.remaining()); return SimSnapshot.new()
	for index: int in range(zone_count):
		var zone_id: int = reader.u32(); var flags: int = reader.u32(); var friction: int = reader.i64(); var acceleration: FixVec2 = reader.vec2()
		var zone_vertices_count: int = reader.u32()
		if zone_vertices_count < SimPolygon.MIN_VERTEX_COUNT or zone_vertices_count > SimPolygon.MAX_VERTEX_COUNT or not reader.require(zone_vertices_count * 16):
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, zone_vertices_count, index); return SimSnapshot.new()
		var vertices: Array[FixVec2] = []
		for vertex_index: int in range(zone_vertices_count): vertices.append(reader.vec2())
		snapshot._zones.append(SimZone.restore(zone_id, flags, friction, acceleration, vertices, status))
		if not status.is_ok(): return SimSnapshot.new()
	var body_count: int = reader.u32()
	if body_count > reader.remaining() / 58:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, body_count, reader.remaining()); return SimSnapshot.new()
	for index: int in range(body_count):
		var body_id: int = reader.u32(); var alive: int = reader.u8(); var destructible: int = reader.u8()
		if alive > 1 or destructible > 1:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, alive, destructible); return SimSnapshot.new()
		var position: FixVec2 = reader.vec2(); var velocity: FixVec2 = reader.vec2()
		snapshot._bodies.append(SimBody.restore(body_id, alive == 1, destructible == 1, position, velocity, reader.i64(), reader.i64(), reader.i64(), status))
		if not status.is_ok(): return SimSnapshot.new()
	if decoded_version >= SCHEMA_VERSION:
		snapshot._next_link_id = reader.u32()
		var link_count: int = reader.u32()
		if link_count > SimLimits.LINK_MAX_COUNT or link_count > reader.remaining() / 48:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, link_count, reader.remaining()); return SimSnapshot.new()
		for index: int in range(link_count):
			var link: SimLink = SimLink.restore(reader.u32(), reader.u32(), reader.u32(), reader.u16(), reader.vec2(), reader.i64(), reader.u16(), reader.u32(), reader.u32(), status)
			snapshot._links.append(link)
			if not status.is_ok(): return SimSnapshot.new()
	snapshot._event_cursor = reader.u32(); snapshot._next_event_sequence = reader.u32()
	var event_count: int = reader.u32()
	if event_count > reader.remaining() / 80:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, event_count, reader.remaining()); return SimSnapshot.new()
	for index: int in range(event_count):
		var event_tick: int = reader.i64(); var substep: int = reader.u16(); var sequence: int = reader.u32(); var type_id: int = reader.u16()
		var source: int = reader.u32(); var target: int = reader.u32(); var zone_id: int = reader.u32(); var cause: int = reader.u16()
		var position: FixVec2 = reader.vec2(); var vector: FixVec2 = reader.vec2(); var value_a: int = reader.i64(); var value_b: int = reader.i64(); var flags: int = reader.u32()
		snapshot._events.append(SimEvent.create(event_tick, substep, sequence, type_id, source, target, zone_id, cause, position, vector, value_a, value_b, flags, status))
		if not status.is_ok(): return SimSnapshot.new()
	if not reader.valid or reader.offset != bytes.size():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_DECODE, reader.offset, bytes.size()); return SimSnapshot.new()
	snapshot._initialized = true
	if not snapshot._validate(status): return SimSnapshot.new()
	return snapshot


func _validate(status: SimStatus) -> bool:
	if not status.is_ok():
		return false
	if _schema_version != SCHEMA_VERSION:
		status.fail(
			SimStatus.Code.UNSUPPORTED_SCHEMA,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_schema_version,
			SCHEMA_VERSION
		)
		return false
	if (
		_tick < 0
		or not UInt32Math.is_u32(_root_seed_hi)
		or not UInt32Math.is_u32(_root_seed_lo)
		or not UInt32Math.is_u32(_next_body_id)
		or not UInt32Math.is_u32(_next_zone_id)
		or not UInt32Math.is_u32(_next_link_id)
		or _rng_purpose_id != 0
		or _rng_owner_id != 0
		or _rng_ordinal != 0
		or not UInt32Math.is_u32(_rng_draw_hi)
		or not UInt32Math.is_u32(_rng_draw_lo)
		or not UInt32Math.is_u32(_event_cursor)
		or _event_cursor > _events.size()
		or not UInt32Math.is_u32(_next_event_sequence)
	):
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_tick,
			_event_cursor
		)
		return false
	if _rng_state.size() != 4:
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_rng_state.size(),
			4
		)
		return false
	for word: int in _rng_state:
		if not UInt32Math.is_u32(word):
			status.fail(
				SimStatus.Code.INVALID_SNAPSHOT,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				word,
				0
			)
			return false
	if _rng_state[0] == 0 and _rng_state[1] == 0 and _rng_state[2] == 0 and _rng_state[3] == 0:
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			0,
			0
		)
		return false
	if (
		_boundary_type != SimWorld.BoundaryType.NONE
		and _boundary_type != SimWorld.BoundaryType.WALL
		and _boundary_type != SimWorld.BoundaryType.KILL
	):
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_boundary_type,
			0
		)
		return false
	if (
		(_boundary_type == SimWorld.BoundaryType.NONE and not _boundary_vertices.is_empty())
		or (_boundary_type != SimWorld.BoundaryType.NONE and _boundary_vertices.is_empty())
	):
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_boundary_type,
			_boundary_vertices.size()
		)
		return false
	for vertex: FixVec2 in _boundary_vertices:
		if vertex == null or not SimLimits.is_position_valid(vertex):
			status.fail(
				SimStatus.Code.INVALID_SNAPSHOT,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				0,
				0
			)
			return false
	for zone: SimZone in _zones:
		if (
			zone == null
			or zone.id() == 0
			or not UInt32Math.is_u32(zone.id())
			or not UInt32Math.is_u32(zone.flags())
			or (zone.flags() & ~SimZone.KNOWN_FLAGS) != 0
			or zone.friction_multiplier_raw() < 0
		):
			status.fail(
				SimStatus.Code.INVALID_SNAPSHOT,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				0 if zone == null else zone.id(),
				0
			)
			return false
	for index: int in range(1, _zones.size()):
		if _zones[index - 1].id() >= _zones[index].id():
			status.fail(
				SimStatus.Code.DUPLICATE_ID,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				_zones[index - 1].id(),
				_zones[index].id()
			)
			return false
	if (
		not _zones.is_empty()
		and _next_zone_id != 0
		and _next_zone_id <= _zones[-1].id()
	):
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_next_zone_id,
			_zones[-1].id()
		)
		return false
	for body: SimBody in _bodies:
		var body_speed_status := SimStatus.new()
		if (
			body == null
			or body.id() == 0
			or not UInt32Math.is_u32(body.id())
			or not SimLimits.is_position_valid(body.position())
			or not SimLimits.is_speed_valid(body.velocity(), body_speed_status)
			or not SimLimits.is_radius_valid(body.radius_raw())
			or not SimLimits.is_mass_valid(body.mass_raw())
			or body.friction_multiplier_raw() < 0
		):
			status.fail(
				SimStatus.Code.INVALID_SNAPSHOT,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				0 if body == null else body.id(),
				0
			)
			return false
	for index: int in range(1, _bodies.size()):
		if _bodies[index - 1].id() >= _bodies[index].id():
			status.fail(
				SimStatus.Code.DUPLICATE_ID,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				_bodies[index - 1].id(),
				_bodies[index].id()
			)
			return false
	if (
		not _bodies.is_empty()
		and _next_body_id != 0
		and _next_body_id <= _bodies[-1].id()
	):
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_next_body_id,
			_bodies[-1].id()
		)
		return false
	var previous_link_id: int = 0
	for link: SimLink in _links:
		if link == null or not link.is_initialized() or link.link_id() <= previous_link_id:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_ENCODE, 0 if link == null else link.link_id(), previous_link_id); return false
		var has_anchor: bool = false; var has_attached: bool = false
		for body: SimBody in _bodies:
			if body.id() == link.anchor_body_id(): has_anchor = true
			if body.id() == link.attached_body_id(): has_attached = true
		if not has_anchor or not has_attached:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_ENCODE, link.anchor_body_id(), link.attached_body_id()); return false
		previous_link_id = link.link_id()
	if not _links.is_empty() and _next_link_id != 0 and _next_link_id <= _links[-1].link_id():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.SNAPSHOT_ENCODE, _next_link_id, _links[-1].link_id()); return false
	for event: SimEvent in _events:
		if (
			event == null
			or event.tick() < 0
			or not UInt32Math.is_u16(event.substep())
			or event.sequence() == 0
			or not UInt32Math.is_u32(event.sequence())
			or event.type_id() < SimEvent.TypeId.BODY_ADDED
			or event.type_id() > SimEvent.TypeId.BODY_DESTROYED
			or not UInt32Math.is_u32(event.source_body_id())
			or not UInt32Math.is_u32(event.target_body_id())
			or not UInt32Math.is_u32(event.zone_id())
			or event.cause_id() < SimEvent.CauseId.NONE
			or event.cause_id() > SimEvent.CauseId.DAMAGE
			or not UInt32Math.is_u32(event.flags())
		):
			status.fail(
				SimStatus.Code.INVALID_SNAPSHOT,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				0 if event == null else event.sequence(),
				0
			)
			return false
	for index: int in range(1, _events.size()):
		if _events[index - 1].sequence() >= _events[index].sequence():
			status.fail(
				SimStatus.Code.DUPLICATE_ID,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				_events[index - 1].sequence(),
				_events[index].sequence()
			)
			return false
	var expected_next_sequence: int = 1
	if not _events.is_empty():
		expected_next_sequence = (
			0
			if _events[-1].sequence() == UInt32Math.U32_MAX
			else _events[-1].sequence() + 1
		)
	if _next_event_sequence != expected_next_sequence:
		status.fail(
			SimStatus.Code.INVALID_SNAPSHOT,
			SimStatus.Operation.SNAPSHOT_ENCODE,
			_next_event_sequence,
			expected_next_sequence
		)
		return false
	return true


func encode(status: SimStatus) -> PackedByteArray:
	if not status.is_ok():
		return PackedByteArray()
	if not _initialized or not _validate(status):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_SNAPSHOT,
				SimStatus.Operation.SNAPSHOT_ENCODE,
				0,
				0
			)
		return PackedByteArray()
	var writer: ByteWriter = ByteWriter.new()
	writer.data.append_array(MAGIC)
	writer.u16(_schema_version)
	writer.i64(_tick)
	writer.u32(_root_seed_lo)
	writer.u32(_root_seed_hi)
	writer.i64(_base_friction_raw)
	writer.i64(_stop_speed_raw)
	writer.i64(_restitution_raw)
	writer.u32(_next_body_id)
	writer.u32(_next_zone_id)

	writer.u32(1) # The P0 world owns exactly one root/default stream.
	writer.u16(_rng_purpose_id)
	writer.u32(_rng_owner_id)
	writer.u32(_rng_ordinal)
	for word: int in _rng_state:
		writer.u32(word)
	writer.u32(_rng_draw_lo)
	writer.u32(_rng_draw_hi)

	writer.u8(0 if _boundary_type == SimWorld.BoundaryType.NONE else 1)
	if _boundary_type != SimWorld.BoundaryType.NONE:
		writer.u16(_boundary_type)
		writer.u32(_boundary_vertices.size())
		for vertex: FixVec2 in _boundary_vertices:
			writer.vec2(vertex)

	writer.u32(_zones.size())
	for zone: SimZone in _zones:
		writer.u32(zone.id())
		writer.u32(zone.flags())
		writer.i64(zone.friction_multiplier_raw())
		writer.vec2(zone.acceleration())
		writer.u32(zone.vertex_count())
		for index: int in range(zone.vertex_count()):
			writer.vec2(zone.vertex(index, status))

	writer.u32(_bodies.size())
	for body: SimBody in _bodies:
		writer.u32(body.id())
		writer.u8(1 if body.alive() else 0)
		writer.u8(1 if body.destructible() else 0)
		writer.vec2(body.position())
		writer.vec2(body.velocity())
		writer.i64(body.radius_raw())
		writer.i64(body.mass_raw())
		writer.i64(body.friction_multiplier_raw())

	writer.u32(_next_link_id)
	writer.u32(_links.size())
	for link: SimLink in _links:
		writer.u32(link.link_id()); writer.u32(link.anchor_body_id()); writer.u32(link.attached_body_id()); writer.u16(link.anchor_mode_id()); writer.vec2(link.anchor_offset())
		writer.i64(link.attach_distance_raw()); writer.u16(link.inertia_basis_points()); writer.u32(link.remaining_turns()); writer.u32(link.applied_turn_index())

	writer.u32(_event_cursor)
	writer.u32(_next_event_sequence)
	writer.u32(_events.size())
	for event: SimEvent in _events:
		writer.i64(event.tick())
		writer.u16(event.substep())
		writer.u32(event.sequence())
		writer.u16(event.type_id())
		writer.u32(event.source_body_id())
		writer.u32(event.target_body_id())
		writer.u32(event.zone_id())
		writer.u16(event.cause_id())
		writer.vec2(event.position())
		writer.vec2(event.vector())
		writer.i64(event.value_a())
		writer.i64(event.value_b())
		writer.u32(event.flags())
	if not status.is_ok():
		return PackedByteArray()
	return writer.data


func restore_world(status: SimStatus) -> SimWorld:
	if not status.is_ok() or not _initialized or not _validate(status):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_SNAPSHOT,
				SimStatus.Operation.SNAPSHOT_RESTORE,
				0,
				0
			)
		return SimWorld.new()
	var world: SimWorld = SimWorld.create(
		_root_seed_hi,
		_root_seed_lo,
		status,
		_base_friction_raw,
		_stop_speed_raw,
		_restitution_raw
	)
	if _boundary_type != SimWorld.BoundaryType.NONE:
		world.configure_boundary(_boundary_vertices, _boundary_type, status)
	for zone: SimZone in _zones:
		world.insert_zone_for_restore(zone, status)
	for body: SimBody in _bodies:
		world.insert_body_for_restore(body, status)
	for link: SimLink in _links: world.insert_link_for_restore(link, status)
	world.restore_authoritative_state(
		_tick,
		_next_body_id,
		_next_zone_id,
		_next_link_id,
		_events,
		_event_cursor,
		_next_event_sequence,
		_rng_state[0],
		_rng_state[1],
		_rng_state[2],
		_rng_state[3],
		_rng_draw_hi,
		_rng_draw_lo,
		status
	)
	return world


## Deep mutable copy exposed only to the P0 schema-sensitivity adapter.
func copy_for_test() -> SimSnapshot:
	var result: SimSnapshot = SimSnapshot.new()
	result._schema_version = _schema_version
	result._tick = _tick
	result._root_seed_hi = _root_seed_hi
	result._root_seed_lo = _root_seed_lo
	result._base_friction_raw = _base_friction_raw
	result._stop_speed_raw = _stop_speed_raw
	result._restitution_raw = _restitution_raw
	result._next_body_id = _next_body_id
	result._next_zone_id = _next_zone_id
	result._next_link_id = _next_link_id
	result._rng_purpose_id = _rng_purpose_id
	result._rng_owner_id = _rng_owner_id
	result._rng_ordinal = _rng_ordinal
	result._rng_state = _rng_state.duplicate()
	result._rng_draw_hi = _rng_draw_hi
	result._rng_draw_lo = _rng_draw_lo
	result._boundary_type = _boundary_type
	for vertex: FixVec2 in _boundary_vertices:
		result._boundary_vertices.append(vertex.copy())
	for zone: SimZone in _zones:
		result._zones.append(zone.copy())
	for body: SimBody in _bodies:
		result._bodies.append(body.copy())
	for link: SimLink in _links: result._links.append(link.copy())
	result._event_cursor = _event_cursor
	result._next_event_sequence = _next_event_sequence
	for event: SimEvent in _events:
		result._events.append(event.copy())
	result._initialized = _initialized
	return result


## Test-only malformed-version probe; gameplay code must never call this.
func set_schema_version_for_test(version: int) -> void:
	_schema_version = version
