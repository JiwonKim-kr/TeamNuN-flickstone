class_name TrajectoryPoint
extends RefCounted

enum Marker {
	NONE = 0,
	WALL = 1,
	COLLISION = 2,
	DESTROYED = 3,
	STOPPED = 4,
	TRUNCATED = 5,
}

var _initialized: bool = false
var _tick: int = 0
var _event_sequence: int = 0
var _position: FixVec2 = FixVec2.zero()
var _marker: int = Marker.NONE
var _target_body_id: int = 0


static func create(tick: int, event_sequence: int, position: FixVec2, marker: int, target_body_id: int, status: SimStatus) -> TrajectoryPoint:
	var result := TrajectoryPoint.new()
	if not status.is_ok():
		return result
	if tick < 0 or not UInt32Math.is_u32(event_sequence) or position == null or marker < Marker.NONE or marker > Marker.TRUNCATED or not UInt32Math.is_u32(target_body_id):
		status.fail(SimStatus.Code.PREDICTION_LIMIT_EXCEEDED, SimStatus.Operation.TRAJECTORY_PREDICT, tick, marker)
		return result
	result._initialized = true
	result._tick = tick
	result._event_sequence = event_sequence
	result._position = position.copy()
	result._marker = marker
	result._target_body_id = target_body_id
	return result


func copy() -> TrajectoryPoint:
	var result := TrajectoryPoint.new()
	result._initialized = _initialized
	result._tick = _tick
	result._event_sequence = _event_sequence
	result._position = _position.copy()
	result._marker = _marker
	result._target_body_id = _target_body_id
	return result


func is_initialized() -> bool: return _initialized
func tick() -> int: return _tick
func event_sequence() -> int: return _event_sequence
func position() -> FixVec2: return _position.copy()
func marker() -> int: return _marker
func target_body_id() -> int: return _target_body_id
