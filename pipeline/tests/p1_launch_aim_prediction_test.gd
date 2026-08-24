extends SceneTree

const SimStatusScript := preload("res://src/core/sim/sim_status.gd")
const FixMathScript := preload("res://src/core/sim/fix_math.gd")
const FixVec2Script := preload("res://src/core/sim/fix_vec2.gd")
const FixTrigLutScript := preload("res://src/core/sim/fix_trig_lut.gd")
const SimBodyScript := preload("res://src/core/sim/sim_body.gd")
const SimWorldScript := preload("res://src/core/sim/sim_world.gd")
const BattleLimitsScript := preload("res://src/core/battle/battle_limits.gd")
const BattleParticipantScript := preload("res://src/core/battle/battle_participant.gd")
const BattleStateScript := preload("res://src/core/battle/battle_state.gd")
const BattleSnapshotScript := preload("res://src/core/battle/battle_snapshot.gd")
const LaunchLimitsScript := preload("res://src/core/battle/launch_limits.gd")
const LaunchCommandScript := preload("res://src/core/battle/launch_command.gd")
const AimQuantizerScript := preload("res://src/core/battle/aim_quantizer.gd")
const LaunchVelocitySolverScript := preload("res://src/core/battle/launch_velocity_solver.gd")
const TrajectoryPointScript := preload("res://src/core/battle/trajectory_point.gd")
const TrajectoryPredictionScript := preload("res://src/core/battle/trajectory_prediction.gd")
const TrajectoryPredictorScript := preload("res://src/core/battle/trajectory_predictor.gd")
const AimInputAdapterScript := preload("res://src/ui/battle/aim_input_adapter.gd")
const TrajectoryLineAdapterScript := preload("res://src/ui/battle/trajectory_line_adapter.gd")

var _failures: int = 0
var _ui_state: BattleState = null
var _prediction_requests: int = 0
var _launch_requests: int = 0
var _cancel_requests: int = 0
var _prediction_powers: Array[int] = []
var _launch_power: int = -1


func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % case_id)
		return
	_failures += 1
	print("[FAIL] %s %s" % [case_id, detail])


func _v(x: int, y: int, status: SimStatus) -> FixVec2:
	return FixVec2.from_ints(x, y, status)


func _body(x: int, y: int, mass_units: int, status: SimStatus) -> SimBody:
	return SimBody.create_unassigned(_v(x, y, status), FixVec2.zero(), 8 * FixMath.SCALE, mass_units * FixMath.SCALE, status)


func _world(positions: Array[FixVec2], masses: Array[int], status: SimStatus, friction_raw: int = SimWorld.DEFAULT_BASE_FRICTION_RAW, with_wall: bool = false) -> SimWorld:
	var world: SimWorld = SimWorld.create(0x12, 0x34, status, friction_raw)
	if with_wall:
		var boundary: Array[FixVec2] = [_v(-64, -64, status), _v(64, -64, status), _v(64, 64, status), _v(-64, 64, status)]
		world.configure_boundary(boundary, SimWorld.BoundaryType.WALL, status)
	var keys: Array[int] = []
	var bodies: Array[SimBody] = []
	for index: int in range(positions.size()):
		keys.append(index + 1)
		bodies.append(SimBody.create_unassigned(positions[index], FixVec2.zero(), 8 * FixMath.SCALE, masses[index] * FixMath.SCALE, status))
	world.add_initial_bodies(keys, bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	return world


func _aim_state(positions: Array[FixVec2], masses: Array[int], status: SimStatus, friction_raw: int = SimWorld.DEFAULT_BASE_FRICTION_RAW, with_wall: bool = false) -> BattleState:
	var world: SimWorld = _world(positions, masses, status, friction_raw, with_wall)
	var participants: Array[BattleParticipant] = []
	for index: int in range(positions.size()):
		var faction: int = BattleParticipant.Faction.PLAYER if index == 0 else BattleParticipant.Faction.ENEMY
		participants.append(BattleParticipant.restore(index + 1, faction, true, index == 0, true, 100, BattleLimits.CT_THRESHOLD if index == 0 else 0, status))
	var state: BattleState = BattleState.create(world, participants, status)
	state.complete_battle_start(status)
	state.complete_turn_start(status)
	return state


func _command(angle: int, power_step: int, status: SimStatus) -> LaunchCommand:
	return LaunchCommand.create(angle, power_step, status)


func _test_enums_and_codec() -> void:
	_check("P1-LAUNCH-ENUM-001", SimStatus.Code.PREDICTION_LIMIT_EXCEEDED == 24 and SimStatus.Operation.TRAJECTORY_PREDICT == 89)
	var status := SimStatus.new()
	var command: LaunchCommand = _command(8192, 32, status)
	var encoded: PackedByteArray = command.encode(status)
	var decoded: LaunchCommand = LaunchCommand.decode(encoded, status)
	_check("P1-LAUNCH-CODEC-001", status.is_ok() and encoded.hex_encode() == "010000202000" and decoded.is_equal(command), encoded.hex_encode())
	var short_status := SimStatus.new(); LaunchCommand.decode(encoded.slice(0, 5), short_status)
	var trailing := encoded.duplicate(); trailing.append(0)
	var trailing_status := SimStatus.new(); LaunchCommand.decode(trailing, trailing_status)
	var version := encoded.duplicate(); version[0] = 2
	var version_status := SimStatus.new(); LaunchCommand.decode(version, version_status)
	var angle_status := SimStatus.new(); LaunchCommand.create(1, 32, angle_status)
	_check("P1-LAUNCH-CODEC-REJECT-001", not short_status.is_ok() and not trailing_status.is_ok() and version_status.code() == SimStatus.Code.UNSUPPORTED_SCHEMA and not angle_status.is_ok())


func _test_quantization() -> void:
	var status := SimStatus.new()
	var center: FixVec2 = _v(0, 0, status)
	var commands: Array[LaunchCommand] = [
		AimQuantizer.quantize(center, _v(-192, 0, status), status),
		AimQuantizer.quantize(center, _v(0, -192, status), status),
		AimQuantizer.quantize(center, _v(192, 0, status), status),
		AimQuantizer.quantize(center, _v(0, 192, status), status),
	]
	var angles: Array[int] = []
	for command: LaunchCommand in commands: angles.append(command.angle())
	_check("P1-AIM-AXES-001", status.is_ok() and angles == [0, 16384, 32768, 49152], str(angles))
	var zero: LaunchCommand = AimQuantizer.quantize(center, center, status)
	var below: LaunchCommand = AimQuantizer.quantize(center, _v(-23, 0, status), status)
	var minimum: LaunchCommand = AimQuantizer.quantize(center, _v(-24, 0, status), status)
	var capped: LaunchCommand = AimQuantizer.quantize(center, _v(-384, 0, status), status)
	_check("P1-AIM-POWER-001", status.is_ok() and zero.power_step() == 0 and below.power_step() == 31 and minimum.power_step() == 32 and capped.power_step() == 256)
	var d0: FixVec2 = FixTrigLut.direction(0, status)
	var d1: FixVec2 = FixTrigLut.direction(256, status)
	var tie_drag: FixVec2 = FixVec2.from_raw(d1.y_raw(), d0.x_raw() - d1.x_raw())
	var tie: LaunchCommand = AimQuantizer.quantize(center, tie_drag.negated(status), status)
	var dw: FixVec2 = FixTrigLut.direction(65280, status)
	var wrap_drag: FixVec2 = FixVec2.from_raw(-dw.y_raw(), -(d0.x_raw() - dw.x_raw()))
	var wrap: LaunchCommand = AimQuantizer.quantize(center, wrap_drag.negated(status), status)
	_check("P1-AIM-TIE-001", status.is_ok() and tie.angle() == 256 and wrap.angle() == 0, "%d %d" % [tie.angle(), wrap.angle()])


func _test_velocity_and_commit() -> void:
	var status := SimStatus.new()
	var full: LaunchCommand = _command(0, 256, status)
	var speeds: Array[int] = []
	for mass: int in [1, 16, 64, 256]:
		speeds.append(LaunchVelocitySolver.solve(full, _body(0, 0, mass, status), status).x_raw())
	_check("P1-LAUNCH-SPEED-001", status.is_ok() and speeds == [2048 * FixMath.SCALE, 2048 * FixMath.SCALE, 1536 * FixMath.SCALE, 768 * FixMath.SCALE], str(speeds))
	var state: BattleState = _aim_state([_v(0, 0, status)], [64], status)
	var before: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var weak_status := SimStatus.new()
	LaunchVelocitySolver.commit(state, _command(0, 31, weak_status), weak_status)
	var after: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	_check("P1-LAUNCH-ATOMIC-001", not weak_status.is_ok() and before == after)
	LaunchVelocitySolver.commit(state, full, status)
	var launched: SimBody = state.world_copy(status).body_by_id(1, status)
	_check("P1-LAUNCH-COMMIT-001", status.is_ok() and state.phase() == BattleState.Phase.RESOLVE and launched.velocity().x_raw() == 1536 * FixMath.SCALE and launched.velocity().y_raw() == 0)


func _terminal_marker(prediction: TrajectoryPrediction, status: SimStatus) -> int:
	return prediction.point_at(prediction.point_count() - 1, status).marker()


func _test_prediction() -> void:
	var status := SimStatus.new()
	var full: LaunchCommand = _command(0, 256, status)
	var state: BattleState = _aim_state([_v(0, 0, status)], [64], status, 0)
	var before: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var first: TrajectoryPrediction = TrajectoryPredictor.predict(state, full, status)
	var second: TrajectoryPrediction = TrajectoryPredictor.predict(state, full, status)
	var after: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	_check("P1-PREDICT-PURE-001", status.is_ok() and before == after and first.is_initialized() and second.is_initialized() and first.point_count() == second.point_count())
	_check("P1-PREDICT-TRUNCATE-001", first.is_truncated() and first.ticks_simulated() == 240 and _terminal_marker(first, status) == TrajectoryPoint.Marker.TRUNCATED and first.point_count() <= 64)
	var collision_state: BattleState = _aim_state([_v(0, 0, status), _v(64, 0, status)], [64, 64], status)
	var collision: TrajectoryPrediction = TrajectoryPredictor.predict(collision_state, _command(0, 64, status), status)
	var collision_end: TrajectoryPoint = collision.point_at(collision.point_count() - 1, status)
	_check("P1-PREDICT-COLLISION-001", status.is_ok() and collision_end.marker() == TrajectoryPoint.Marker.COLLISION and collision_end.target_body_id() == 2 and collision.ticks_simulated() < 240)
	var wall_state: BattleState = _aim_state([_v(0, 0, status)], [64], status, 0, true)
	var wall: TrajectoryPrediction = TrajectoryPredictor.predict(wall_state, _command(0, 128, status), status)
	_check("P1-PREDICT-WALL-001", status.is_ok() and not wall.is_truncated() and _terminal_marker(wall, status) == TrajectoryPoint.Marker.WALL and wall.ticks_simulated() < 240)
	var line := TrajectoryLineAdapter.new()
	line.update_from_prediction(collision, status)
	_check("P1-PREDICT-UI-LINE-001", status.is_ok() and line.point_count() == collision.point_count() and line.marker_at(line.point_count() - 1) == TrajectoryPoint.Marker.COLLISION)


func _provide_ui_state() -> BattleState:
	return _ui_state


func _screen_to_world(pointer: Vector2) -> Vector2:
	return pointer


func _on_prediction_requested(command_value: LaunchCommand) -> void:
	_prediction_requests += 1
	_prediction_powers.append(command_value.power_step())


func _on_launch_requested(command_value: LaunchCommand) -> void:
	_launch_requests += 1
	_launch_power = command_value.power_step()


func _on_aim_cancelled() -> void: _cancel_requests += 1


func _test_ui_input_bridge() -> void:
	var status := SimStatus.new()
	_ui_state = _aim_state([_v(0, 0, status)], [64], status)
	var adapter := AimInputAdapter.new()
	adapter.configure(Callable(self, "_provide_ui_state"), Callable(self, "_screen_to_world"))
	adapter.prediction_requested.connect(_on_prediction_requested)
	adapter.launch_requested.connect(_on_launch_requested)
	adapter.aim_cancelled.connect(_on_aim_cancelled)
	adapter.begin_aim(Vector2.ZERO); adapter.update_aim(Vector2(-48, 0)); adapter.release_aim(Vector2(-96, 0))
	adapter.begin_aim(Vector2(-24, 0)); adapter.cancel_aim()
	_check("P1-AIM-UI-DRAG-POWER-001", _prediction_powers.slice(0, 3) == [0, 64, 128] and _launch_power == 128, str(_prediction_powers))
	_check("P1-AIM-UI-BRIDGE-001", status.is_ok() and _prediction_requests == 4 and _launch_requests == 1 and _cancel_requests == 1 and _ui_state.phase() == BattleState.Phase.AIM, "%d %d %d" % [_prediction_requests, _launch_requests, _cancel_requests])
	adapter.free()


func _initialize() -> void:
	print("== P1-2 Launch / Aim / Prediction ==")
	_test_enums_and_codec()
	_test_quantization()
	_test_velocity_and_commit()
	_test_prediction()
	_test_ui_input_bridge()
	if _failures == 0:
		print("P1_LAUNCH_AIM_PREDICTION_RESULT: PASS")
		quit(0)
	else:
		print("P1_LAUNCH_AIM_PREDICTION_RESULT: FAIL (%d)" % _failures)
		quit(1)
