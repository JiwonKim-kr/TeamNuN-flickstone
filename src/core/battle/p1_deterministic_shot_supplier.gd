class_name P1DeterministicShotSupplier
extends RefCounted

const POWER_STEP := 192

static func command_for(state: BattleState, status: SimStatus) -> LaunchCommand:
	if not status.is_ok() or state == null or state.phase() != BattleState.Phase.AIM:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_SHOT_SUPPLY, 0, 0)
		return LaunchCommand.new()
	var actor_id := state.current_actor_body_id()
	var actor_participant := state.participant_by_body_id(actor_id, status)
	var world := state.world_copy(status)
	var actor := world.body_by_id(actor_id, status)
	var target: SimBody = null
	var best_distance := FixMath.INT64_MAX
	for index: int in range(state.participant_count()):
		var candidate := state.participant_at(index, status)
		if candidate.faction() == actor_participant.faction(): continue
		var body := world.body_by_id(candidate.body_id(), status)
		var distance := body.position().sub(actor.position(), status).length_squared_raw(status)
		if target == null or distance < best_distance or (distance == best_distance and body.id() < target.id()): target = body; best_distance = distance
	if target == null:
		status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_SHOT_SUPPLY, actor_id, 0); return LaunchCommand.new()
	var direction := target.position().sub(actor.position(), status).normalized(status)
	var drag_raw := FixMath.mul_ratio_raw(LaunchLimits.MAX_DRAG_DISTANCE_RAW, POWER_STEP, LaunchLimits.POWER_STEPS, status)
	var pointer := actor.position().sub(direction.scaled(drag_raw, status), status)
	var command := AimQuantizer.quantize(actor.position(), pointer, status)
	if status.is_ok() and command.power_step() != POWER_STEP: status.fail(SimStatus.Code.INVALID_LAUNCH_COMMAND, SimStatus.Operation.BATTLE_SHOT_SUPPLY, command.power_step(), POWER_STEP)
	return command
