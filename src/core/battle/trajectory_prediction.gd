class_name TrajectoryPrediction
extends RefCounted
## Immutable-by-convention derived trajectory value.

var _initialized: bool = false
var _actor_body_id: int = 0
var _ticks_simulated: int = 0
var _truncated: bool = false
var _points: Array[TrajectoryPoint] = []


static func create(actor_body_id: int, ticks_simulated: int, truncated: bool, points: Array[TrajectoryPoint], status: SimStatus) -> TrajectoryPrediction:
	var result := TrajectoryPrediction.new()
	if not status.is_ok():
		return result
	if not UInt32Math.is_u32(actor_body_id) or actor_body_id == 0 or ticks_simulated < 0 or ticks_simulated > LaunchLimits.PREDICTION_MAX_TICKS or points.is_empty() or points.size() > LaunchLimits.PREDICTION_MAX_POINTS:
		status.fail(SimStatus.Code.PREDICTION_LIMIT_EXCEEDED, SimStatus.Operation.TRAJECTORY_PREDICT, ticks_simulated, points.size())
		return result
	result._initialized = true
	result._actor_body_id = actor_body_id
	result._ticks_simulated = ticks_simulated
	result._truncated = truncated
	for point: TrajectoryPoint in points:
		if point == null or not point.is_initialized():
			status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.TRAJECTORY_PREDICT, result._points.size(), 0)
			return TrajectoryPrediction.new()
		result._points.append(point.copy())
	return result


func copy() -> TrajectoryPrediction:
	var result := TrajectoryPrediction.new()
	result._initialized = _initialized
	result._actor_body_id = _actor_body_id
	result._ticks_simulated = _ticks_simulated
	result._truncated = _truncated
	for point: TrajectoryPoint in _points: result._points.append(point.copy())
	return result


func is_initialized() -> bool: return _initialized
func actor_body_id() -> int: return _actor_body_id
func ticks_simulated() -> int: return _ticks_simulated
func is_truncated() -> bool: return _truncated
func point_count() -> int: return _points.size()
func point_at(index: int, status: SimStatus) -> TrajectoryPoint:
	if index < 0 or index >= _points.size():
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.TRAJECTORY_PREDICT, index, _points.size())
		return TrajectoryPoint.new()
	return _points[index].copy()
