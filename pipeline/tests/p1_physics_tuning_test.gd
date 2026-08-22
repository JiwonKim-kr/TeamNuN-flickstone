extends SceneTree
## PT-01~04: launch reach, impact energy, and deterministic settling.

var _failures: int = 0


func _init() -> void:
	_check(
		"P1-TUNING-CONSTANTS-001",
		SimWorld.DEFAULT_BASE_FRICTION_RAW == 98304
		and SimCollision.DEFAULT_RESTITUTION_RAW == 62259
		and LaunchLimits.BASE_MAX_LAUNCH_SPEED_RAW == 1536 * FixMath.SCALE
		and LaunchLimits.ABSOLUTE_LAUNCH_SPEED_RAW == 2048 * FixMath.SCALE
		and DamageLimits.DAMAGE_REFERENCE_SPEED_RAW == 1024 * FixMath.SCALE
	)
	var power_75: Dictionary = _probe(192)
	_check(
		"P1-TUNING-REACH-75-001",
		int(power_75.get("status", -1)) == SimStatus.Code.OK
		and int(power_75.get("launch", 0)) == 1152 * FixMath.SCALE
		and int(power_75.get("collision_tick", 9999)) <= 120
		and int(power_75.get("approach", 0)) >= 256 * FixMath.SCALE
		and int(power_75.get("target_after", 0)) * 100
			>= int(power_75.get("approach", 0)) * 97,
		str(power_75)
	)
	var power_full: Dictionary = _probe(256)
	_check(
		"P1-TUNING-REACH-FULL-001",
		int(power_full.get("status", -1)) == SimStatus.Code.OK
		and int(power_full.get("launch", 0)) == 1536 * FixMath.SCALE
		and int(power_full.get("collision_tick", 9999)) <= 72
		and int(power_full.get("approach", 0)) >= 640 * FixMath.SCALE
		and int(power_full.get("stopped_tick", 9999)) <= 720
		and int(power_full.get("max_substeps", 99)) <= SimCollision.MAX_SUBSTEPS,
		str(power_full)
	)
	if _failures == 0:
		print("P1_PHYSICS_TUNING_RESULT: PASS")
		quit(0)
	else:
		print("P1_PHYSICS_TUNING_RESULT: FAIL (%d)" % _failures)
		quit(1)


func _probe(power_step: int) -> Dictionary:
	var status := SimStatus.new()
	var command: LaunchCommand = LaunchCommand.create(49152, power_step, status)
	var actor_template: SimBody = SimBody.create_unassigned(
		FixVec2.from_ints(480, 832, status),
		FixVec2.zero(),
		32 * FixMath.SCALE,
		64 * FixMath.SCALE,
		status
	)
	var launch_velocity: FixVec2 = LaunchVelocitySolver.solve(
		command, actor_template, status
	)
	var world: SimWorld = SimWorld.create(0x1234, 0x5678, status)
	var boundary: Array[FixVec2] = [
		FixVec2.from_ints(0, 0, status),
		FixVec2.from_ints(640, 0, status),
		FixVec2.from_ints(640, 1024, status),
		FixVec2.from_ints(0, 1024, status),
	]
	world.configure_boundary(boundary, SimWorld.BoundaryType.WALL, status)
	var bodies: Array[SimBody] = [
		SimBody.create_unassigned(
			FixVec2.from_ints(480, 832, status), launch_velocity,
			32 * FixMath.SCALE, 64 * FixMath.SCALE, status
		),
		SimBody.create_unassigned(
			FixVec2.from_ints(480, 192, status), FixVec2.zero(),
			32 * FixMath.SCALE, 64 * FixMath.SCALE, status
		),
	]
	world.add_initial_bodies([10, 60], bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count():
		world.consume_next_event(status)
	var collision_tick: int = -1
	var approach_raw: int = 0
	var target_after_raw: int = 0
	var stopped_tick: int = -1
	var max_substeps: int = 1
	for tick: int in range(960):
		world.step(status)
		max_substeps = maxi(max_substeps, world.last_substep_count())
		while status.is_ok() and world.event_cursor() < world.event_count():
			var event: SimEvent = world.consume_next_event(status)
			if (
				event.type_id() == SimEvent.TypeId.BODY_COLLIDED
				and collision_tick < 0
			):
				collision_tick = tick + 1
				approach_raw = event.value_a()
				target_after_raw = world.body_by_id(
					2, status
				).velocity().length_raw(status)
		if not status.is_ok():
			break
		if world.is_quiescent(
			SimWorld.ContinuousAccelerationMode.APPLY, status
		):
			stopped_tick = tick + 1
			break
	return {
		"status": status.code(),
		"launch": launch_velocity.length_raw(SimStatus.new()),
		"collision_tick": collision_tick,
		"approach": approach_raw,
		"target_after": target_after_raw,
		"stopped_tick": stopped_tick,
		"max_substeps": max_substeps,
	}


func _check(id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % id)
	else:
		_failures += 1
		print("[FAIL] %s %s" % [id, detail])
