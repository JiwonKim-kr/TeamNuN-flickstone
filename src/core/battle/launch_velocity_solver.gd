class_name LaunchVelocitySolver
extends RefCounted
## Converts a validated command and body mass into an authoritative velocity.


static func solve(command: LaunchCommand, actor_body: SimBody, status: SimStatus) -> FixVec2:
	if not status.is_ok():
		return FixVec2.zero()
	if command == null or not command.is_initialized() or actor_body == null:
		status.fail(SimStatus.Code.INVALID_LAUNCH_COMMAND, SimStatus.Operation.LAUNCH_VELOCITY_SOLVE, 0, 0)
		return FixVec2.zero()
	if not LaunchLimits.valid_quantized_angle(command.angle()) or not LaunchLimits.valid_launch_power_step(command.power_step()):
		status.fail(
			SimStatus.Code.INVALID_LAUNCH_COMMAND,
			SimStatus.Operation.LAUNCH_VELOCITY_SOLVE,
			command.angle(),
			command.power_step()
		)
		return FixVec2.zero()
	if not SimLimits.is_mass_valid(actor_body.mass_raw()):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.LAUNCH_VELOCITY_SOLVE,
			actor_body.mass_raw(),
			0
		)
		return FixVec2.zero()
	var power_raw: int = FixMath.from_ratio(command.power_step(), LaunchLimits.POWER_STEPS, status)
	var base_speed_raw: int = FixMath.mul_raw(LaunchLimits.BASE_MAX_LAUNCH_SPEED_RAW, power_raw, status)
	var mass_ratio_raw: int = FixMath.div_raw(LaunchLimits.REFERENCE_MASS_RAW, actor_body.mass_raw(), status)
	var weight_factor_raw: int = FixMath.sqrt_raw(mass_ratio_raw, status)
	var speed_raw: int = FixMath.mul_raw(base_speed_raw, weight_factor_raw, status)
	if speed_raw > LaunchLimits.ABSOLUTE_LAUNCH_SPEED_RAW:
		speed_raw = LaunchLimits.ABSOLUTE_LAUNCH_SPEED_RAW
	var result: FixVec2 = FixTrigLut.direction(command.angle(), status).scaled(speed_raw, status)
	if not status.is_ok() or result.is_zero() or not SimLimits.is_launch_speed_valid(result, status):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_LAUNCH_COMMAND,
				SimStatus.Operation.LAUNCH_VELOCITY_SOLVE,
				command.angle(),
				command.power_step()
			)
		return FixVec2.zero()
	return result


static func commit(state: BattleState, command: LaunchCommand, status: SimStatus) -> bool:
	if not status.is_ok():
		return false
	if state == null or not state.is_initialized():
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.LAUNCH_COMMIT, 0, 0)
		return false
	if state.phase() != BattleState.Phase.AIM:
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.LAUNCH_COMMIT, state.phase(), BattleState.Phase.AIM)
		return false
	var world: SimWorld = state.world_copy(status)
	var actor: SimBody = world.body_by_id(state.current_actor_body_id(), status)
	var velocity: FixVec2 = solve(command, actor, status)
	if not status.is_ok():
		return false
	return state.commit_launch_velocity(velocity, status)
