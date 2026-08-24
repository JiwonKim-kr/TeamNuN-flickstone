class_name AiShotSelector
extends RefCounted

const POWERS: Array[int] = [64, 128, 192, 256]
const MAX_CANDIDATES := 100

class Candidate:
	var command: LaunchCommand
	var evaluation: AiShotEvaluation
	func _init(value_command: LaunchCommand, value_evaluation: AiShotEvaluation) -> void:
		command = value_command; evaluation = value_evaluation

static func _less(a: Candidate, b: Candidate) -> bool:
	if a.evaluation.score() != b.evaluation.score(): return a.evaluation.score() > b.evaluation.score()
	if a.evaluation.actor_survived() != b.evaluation.actor_survived(): return a.evaluation.actor_survived()
	if a.evaluation.ally_destroyed() != b.evaluation.ally_destroyed(): return a.evaluation.ally_destroyed() < b.evaluation.ally_destroyed()
	if a.command.angle() != b.command.angle(): return a.command.angle() < b.command.angle()
	return a.command.power_step() < b.command.power_step()

static func _command_toward(actor_position: FixVec2, target_position: FixVec2, power: int, status: SimStatus) -> LaunchCommand:
	var direction: FixVec2 = target_position.sub(actor_position, status).normalized(status)
	var drag_raw: int = FixMath.mul_ratio_raw(LaunchLimits.MAX_DRAG_DISTANCE_RAW, power, LaunchLimits.POWER_STEPS, status)
	return AimQuantizer.quantize(actor_position, actor_position.sub(direction.scaled(drag_raw, status), status), status)

static func _mirror_across_edge(target: FixVec2, a: FixVec2, b: FixVec2, status: SimStatus) -> FixVec2:
	var edge: FixVec2 = b.sub(a, status); var relative: FixVec2 = target.sub(a, status)
	var t_raw: int = FixMath.div_raw(relative.dot_raw(edge, status), edge.length_squared_raw(status), status)
	var projection: FixVec2 = a.add(edge.scaled(t_raw, status), status)
	return projection.add(projection.sub(target, status), status)

static func _add(state: BattleState, actor_position: FixVec2, target_position: FixVec2, power: int, seen: Dictionary, result: Array[Candidate], status: SimStatus) -> void:
	if result.size() >= MAX_CANDIDATES or not status.is_ok(): return
	var command: LaunchCommand = _command_toward(actor_position, target_position, power, status)
	var key := "%d:%d" % [command.angle(), command.power_step()]
	if seen.has(key): return
	seen[key] = true
	result.append(Candidate.new(command, AiShotEvaluator.evaluate(state, command, status)))

static func raw_candidates(state: BattleState, status: SimStatus) -> Array[Candidate]:
	var result: Array[Candidate] = []; var seen: Dictionary = {}
	if not status.is_ok() or state == null or state.phase() != BattleState.Phase.AIM:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_SHOT_SUPPLY)
		return result
	var world: SimWorld = state.world_copy(status); var actor_id: int = state.current_actor_body_id()
	var actor_participant: BattleParticipant = state.participant_by_body_id(actor_id, status)
	var actor_position: FixVec2 = world.body_by_id(actor_id, status).position()
	var targets: Array[SimBody] = []
	for index: int in range(state.participant_count()):
		var participant: BattleParticipant = state.participant_at(index, status)
		if participant.faction() != actor_participant.faction(): targets.append(world.body_by_id(participant.body_id(), status))
	targets.sort_custom(func(a: SimBody, b: SimBody) -> bool: return a.id() < b.id())
	for target: SimBody in targets:
		for power: int in POWERS: _add(state, actor_position, target.position(), power, seen, result, status)
	var boundary: SimPolygon = world.boundary_polygon(status)
	for target: SimBody in targets:
		for edge_index: int in range(boundary.vertex_count()):
			var mirrored: FixVec2 = _mirror_across_edge(target.position(), boundary.vertex(edge_index, status), boundary.vertex((edge_index + 1) % boundary.vertex_count(), status), status)
			for power: int in POWERS: _add(state, actor_position, mirrored, power, seen, result, status)
	result.sort_custom(_less)
	return result

static func _signed_error(random: BattleRandom, limit: int, quantum: int, status: SimStatus) -> int:
	var steps: int = limit / quantum
	return (random.next_index(steps * 2 + 1, status) - steps) * quantum

static func command_for(state: BattleState, grade_id: int, status: SimStatus) -> LaunchCommand:
	if not status.is_ok() or state == null or state.phase() != BattleState.Phase.AIM or not AiGrade.is_known(grade_id):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_SHOT_SUPPLY, grade_id, 0)
		return LaunchCommand.new()
	var candidates: Array[Candidate] = raw_candidates(state, status)
	if not status.is_ok() or candidates.is_empty(): return LaunchCommand.new()
	var best: Candidate = candidates[0]; var safe_best: Candidate = null
	for candidate: Candidate in candidates:
		if candidate.evaluation.is_safe(): safe_best = candidate; break
	var random: BattleRandom = BattleRandom.for_ai_shot(state.world_copy(status), state.current_actor_body_id(), state.turn_index(), status)
	var angle_delta: int = _signed_error(random, AiGrade.angle_error_limit(grade_id), 256, status)
	var power_delta: int = _signed_error(random, AiGrade.power_error_limit(grade_id), 8, status)
	for attempt: int in range(4):
		var perturbed := LaunchCommand.create((best.command.angle() + angle_delta) & 0xFFFF, clampi(best.command.power_step() + power_delta, LaunchLimits.MIN_POWER_STEP, LaunchLimits.POWER_STEPS), status)
		var evaluation := AiShotEvaluator.evaluate(state, perturbed, status)
		if evaluation.is_safe() or safe_best == null: return perturbed
		angle_delta = FixMath.trunc_div_int(angle_delta, 2, status); power_delta = FixMath.trunc_div_int(power_delta, 2, status)
	return safe_best.command.copy() if safe_best != null else best.command.copy()
