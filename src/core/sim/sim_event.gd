class_name SimEvent
extends RefCounted
## Immutable fixed-layout simulation event.
##
## Type/cause numbers are replay data. Existing values are append-only and
## must never be reordered or reused.

const FLAG_RUNTIME_SPAWN_KEY_PRESENT: int = 1

enum TypeId {
	NONE = 0,
	BODY_ADDED = 1,
	BODY_REMOVED = 2,
	BODY_STOPPED = 3,
	BODY_COLLIDED = 4,
	BODY_HIT_WALL = 5,
	BODY_DESTROYED = 6,
}

enum CauseId {
	NONE = 0,
	KILL_BOUNDARY = 1,
	KILL_ZONE = 2,
}

var _tick: int = 0
var _substep: int = 0
var _sequence: int = 0
var _type_id: int = TypeId.NONE
var _source_body_id: int = 0
var _target_body_id: int = 0
var _zone_id: int = 0
var _cause_id: int = CauseId.NONE
var _position: FixVec2 = FixVec2.zero()
var _vector: FixVec2 = FixVec2.zero()
var _value_a: int = 0
var _value_b: int = 0
var _flags: int = 0


static func _is_known_type(type_id: int) -> bool:
	return (
		type_id == TypeId.BODY_ADDED
		or type_id == TypeId.BODY_REMOVED
		or type_id == TypeId.BODY_STOPPED
		or type_id == TypeId.BODY_COLLIDED
		or type_id == TypeId.BODY_HIT_WALL
		or type_id == TypeId.BODY_DESTROYED
	)


static func _is_known_cause(cause_id: int) -> bool:
	return (
		cause_id == CauseId.NONE
		or cause_id == CauseId.KILL_BOUNDARY
		or cause_id == CauseId.KILL_ZONE
	)


static func create(
		tick: int,
		substep: int,
		sequence: int,
		type_id: int,
		source_body_id: int,
		target_body_id: int,
		zone_id: int,
		cause_id: int,
		position: FixVec2,
		vector: FixVec2,
		value_a: int,
		value_b: int,
		flags: int,
		status: SimStatus
) -> SimEvent:
	var event: SimEvent = SimEvent.new()
	if not status.is_ok():
		return event
	if tick < 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.EVENT_CREATE,
			tick,
			0
		)
		return event
	if substep < 0 or substep > 0xFFFF:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.EVENT_CREATE,
			substep,
			0
		)
		return event
	if sequence <= 0 or not UInt32Math.is_u32(sequence):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.EVENT_CREATE,
			sequence,
			0
		)
		return event
	if not _is_known_type(type_id) or not _is_known_cause(cause_id):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.EVENT_CREATE,
			type_id,
			cause_id
		)
		return event
	if not (
		UInt32Math.is_u32(source_body_id)
		and UInt32Math.is_u32(target_body_id)
		and UInt32Math.is_u32(zone_id)
		and UInt32Math.is_u32(flags)
	):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.EVENT_CREATE,
			source_body_id,
			target_body_id
		)
		return event
	if position == null or vector == null:
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.EVENT_CREATE,
			0,
			0
		)
		return event

	event._tick = tick
	event._substep = substep
	event._sequence = sequence
	event._type_id = type_id
	event._source_body_id = source_body_id
	event._target_body_id = target_body_id
	event._zone_id = zone_id
	event._cause_id = cause_id
	event._position = position.copy()
	event._vector = vector.copy()
	event._value_a = value_a
	event._value_b = value_b
	event._flags = flags
	return event


func copy() -> SimEvent:
	var event: SimEvent = SimEvent.new()
	event._tick = _tick
	event._substep = _substep
	event._sequence = _sequence
	event._type_id = _type_id
	event._source_body_id = _source_body_id
	event._target_body_id = _target_body_id
	event._zone_id = _zone_id
	event._cause_id = _cause_id
	event._position = _position.copy()
	event._vector = _vector.copy()
	event._value_a = _value_a
	event._value_b = _value_b
	event._flags = _flags
	return event


func tick() -> int:
	return _tick


func substep() -> int:
	return _substep


func sequence() -> int:
	return _sequence


func type_id() -> int:
	return _type_id


func source_body_id() -> int:
	return _source_body_id


func target_body_id() -> int:
	return _target_body_id


func zone_id() -> int:
	return _zone_id


func cause_id() -> int:
	return _cause_id


func position() -> FixVec2:
	return _position.copy()


func vector() -> FixVec2:
	return _vector.copy()


func value_a() -> int:
	return _value_a


func value_b() -> int:
	return _value_b


func flags() -> int:
	return _flags
