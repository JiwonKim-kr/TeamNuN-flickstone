class_name AiShotEvaluator
extends RefCounted
## Deterministic geometric estimate for one launch; never mutates BattleState.

const ENEMY_DAMAGE_WEIGHT := 100
const ENEMY_DESTROY_WEIGHT := 100000
const KILL_DESTROY_WEIGHT := 25000
const ALLY_DAMAGE_WEIGHT := -150
const ALLY_DESTROY_WEIGHT := -150000
const ACTOR_DANGER_WEIGHT := -300000

static func _ray_hits_kill_zone(world: SimWorld, origin: FixVec2, direction: FixVec2, step_raw: int, status: SimStatus) -> bool:
	for sample_index: int in range(1, 17):
		var point: FixVec2 = origin.add(direction.scaled(FixMath.multiply_int(step_raw, sample_index, status), status), status)
		for zone_index: int in range(world.zone_count()):
			var zone: SimZone = world.zone_at(zone_index, status)
			if zone.is_kill_zone() and zone.contains_point_strict(point, status): return true
	return false

static func evaluate(state: BattleState, command: LaunchCommand, status: SimStatus) -> AiShotEvaluation:
	if not status.is_ok() or state == null or not state.is_initialized() or state.phase() != BattleState.Phase.AIM or command == null or not command.is_initialized():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_SHOT_SUPPLY)
		return AiShotEvaluation.new()
	var actor_id: int = state.current_actor_body_id()
	var actor_participant: BattleParticipant = state.participant_by_body_id(actor_id, status)
	var actor_combatant: BattleCombatant = state.combatant_by_body_id(actor_id, status)
	var world: SimWorld = state.world_copy(status)
	var actor: SimBody = world.body_by_id(actor_id, status)
	var direction: FixVec2 = FixTrigLut.direction(command.angle(), status)
	var first_body: SimBody = null; var first_along: int = FixMath.INT64_MAX
	for index: int in range(world.body_count()):
		var body: SimBody = world.body_at(index, status)
		if body.id() == actor_id: continue
		var delta: FixVec2 = body.position().sub(actor.position(), status)
		var along: int = delta.dot_raw(direction, status)
		if along <= 0: continue
		var cross_a: int = FixMath.mul_raw(delta.x_raw(), direction.y_raw(), status)
		var cross_b: int = FixMath.mul_raw(delta.y_raw(), direction.x_raw(), status)
		var perpendicular: int = FixMath.abs_raw(FixMath.sub_raw(cross_a, cross_b, status), status)
		if perpendicular <= FixMath.add_raw(actor.radius_raw(), body.radius_raw(), status) and along < first_along:
			first_body = body; first_along = along
	var enemy_damage := 0; var enemy_destroyed := 0; var ally_damage := 0; var ally_destroyed := 0; var kill_destroyed := 0
	if first_body != null:
		var victim: BattleCombatant = state.combatant_by_body_id(first_body.id(), status)
		var estimated_damage: int = mini(victim.current_hp(), maxi(1, FixMath.round_div_int(actor_combatant.attack() * command.power_step(), LaunchLimits.POWER_STEPS, status)))
		if victim.faction() == actor_participant.faction():
			ally_damage = estimated_damage; ally_destroyed = 1 if estimated_damage >= victim.current_hp() else 0
		else:
			enemy_damage = estimated_damage; enemy_destroyed = 1 if estimated_damage >= victim.current_hp() else 0
			var beyond: FixVec2 = first_body.position().add(direction.scaled(first_body.radius_raw() * 2, status), status)
			for zone_index: int in range(world.zone_count()):
				var zone: SimZone = world.zone_at(zone_index, status)
				if zone.is_kill_zone() and zone.contains_point_strict(beyond, status): kill_destroyed = 1; break
	var actor_danger: bool = world.boundary_type() == SimWorld.BoundaryType.KILL or _ray_hits_kill_zone(world, actor.position(), direction, actor.radius_raw() * 2, status)
	var score: int = enemy_damage * ENEMY_DAMAGE_WEIGHT + enemy_destroyed * ENEMY_DESTROY_WEIGHT + kill_destroyed * KILL_DESTROY_WEIGHT + ally_damage * ALLY_DAMAGE_WEIGHT + ally_destroyed * ALLY_DESTROY_WEIGHT
	if actor_danger: score += ACTOR_DANGER_WEIGHT
	return AiShotEvaluation.create(score, enemy_damage, enemy_destroyed, ally_damage, ally_destroyed, kill_destroyed, not actor_danger, status)
