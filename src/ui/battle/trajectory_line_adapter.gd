class_name TrajectoryLineAdapter
extends RefCounted
## Converts deterministic trajectory values into renderer-friendly copies.

var _positions: PackedVector2Array = PackedVector2Array()
var _marker_types: Array[int] = []
var _marker_targets: Array[int] = []


func update_from_prediction(prediction: TrajectoryPrediction, status: SimStatus) -> void:
	clear()
	if not status.is_ok():
		return
	if prediction == null or not prediction.is_initialized():
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.TRAJECTORY_PREDICT, 0, 0)
		return
	for index: int in range(prediction.point_count()):
		var point: TrajectoryPoint = prediction.point_at(index, status)
		var fixed: FixVec2 = point.position()
		_positions.append(Vector2(
			float(fixed.x_raw()) / float(FixMath.SCALE),
			float(fixed.y_raw()) / float(FixMath.SCALE)
		))
		_marker_types.append(point.marker())
		_marker_targets.append(point.target_body_id())


func clear() -> void:
	_positions = PackedVector2Array()
	_marker_types.clear()
	_marker_targets.clear()


func positions() -> PackedVector2Array: return _positions.duplicate()
func point_count() -> int: return _positions.size()
func marker_at(index: int) -> int: return _marker_types[index]
func marker_target_at(index: int) -> int: return _marker_targets[index]
