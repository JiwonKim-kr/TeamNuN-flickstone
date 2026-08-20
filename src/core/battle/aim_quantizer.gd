class_name AimQuantizer
extends RefCounted
## Pure integer drag-to-command quantization. No inverse trigonometry is used.


static func _power_step_for_drag(drag: FixVec2, status: SimStatus) -> int:
	var length_raw: int = drag.length_raw(status)
	if not status.is_ok():
		return 0
	if length_raw >= LaunchLimits.MAX_DRAG_DISTANCE_RAW:
		return LaunchLimits.POWER_STEPS
	var scaled: int = FixMath.multiply_int(length_raw, LaunchLimits.POWER_STEPS, status)
	return FixMath.round_div_int(scaled, LaunchLimits.MAX_DRAG_DISTANCE_RAW, status)


static func _angle_for_drag(drag: FixVec2, status: SimStatus) -> int:
	if drag.is_zero():
		return 0
	var best_angle: int = 0
	var best_dot: int = FixMath.INT64_MIN
	for index: int in range(LaunchLimits.ANGLE_DIRECTION_COUNT):
		var angle: int = index * LaunchLimits.ANGLE_STEP
		var direction: FixVec2 = FixTrigLut.direction(angle, status)
		var dot: int = drag.dot_raw(direction, status)
		if not status.is_ok():
			return 0
		if dot > best_dot or (dot == best_dot and not (best_angle == 0 and angle == 65280)):
			best_dot = dot
			best_angle = angle
	return best_angle


static func quantize(actor_center: FixVec2, pointer_world: FixVec2, status: SimStatus) -> LaunchCommand:
	if not status.is_ok():
		return LaunchCommand.new()
	if actor_center == null or pointer_world == null:
		status.fail(SimStatus.Code.INVALID_AIM_INPUT, SimStatus.Operation.AIM_QUANTIZE, 0, 0)
		return LaunchCommand.new()
	if not SimLimits.is_position_valid(actor_center) or not SimLimits.is_position_valid(pointer_world):
		status.fail(
			SimStatus.Code.INVALID_AIM_INPUT,
			SimStatus.Operation.AIM_QUANTIZE,
			pointer_world.x_raw(),
			pointer_world.y_raw()
		)
		return LaunchCommand.new()
	var drag: FixVec2 = actor_center.sub(pointer_world, status)
	var power_step: int = _power_step_for_drag(drag, status)
	var angle: int = _angle_for_drag(drag, status)
	if not status.is_ok():
		return LaunchCommand.new()
	var create_status := SimStatus.new()
	var result: LaunchCommand = LaunchCommand.create(angle, power_step, create_status)
	if not create_status.is_ok():
		status.fail(create_status.code(), SimStatus.Operation.AIM_QUANTIZE, angle, power_step)
	return result


static func preview_power_step(actor_center: FixVec2, pointer_world: FixVec2, status: SimStatus) -> int:
	if not status.is_ok():
		return 0
	if actor_center == null or pointer_world == null:
		status.fail(SimStatus.Code.INVALID_AIM_INPUT, SimStatus.Operation.AIM_QUANTIZE, 0, 0)
		return 0
	if not SimLimits.is_position_valid(actor_center) or not SimLimits.is_position_valid(pointer_world):
		status.fail(
			SimStatus.Code.INVALID_AIM_INPUT,
			SimStatus.Operation.AIM_QUANTIZE,
			pointer_world.x_raw(),
			pointer_world.y_raw()
		)
		return 0
	var drag: FixVec2 = actor_center.sub(pointer_world, status)
	return _power_step_for_drag(drag, status)
