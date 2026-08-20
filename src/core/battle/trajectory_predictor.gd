class_name TrajectoryPredictor
extends RefCounted
## Executes an authoritative launch only on a deep BattleState copy.


static func _append_point(points: Array[TrajectoryPoint], point: TrajectoryPoint, is_event: bool, status: SimStatus) -> void:
	if not status.is_ok() or point == null or not point.is_initialized():
		return
	if not points.is_empty():
		var last: TrajectoryPoint = points[points.size() - 1]
		if last.tick() == point.tick() and last.position().is_equal(point.position()):
			if is_event and last.marker() == TrajectoryPoint.Marker.NONE:
				points[points.size() - 1] = point.copy()
			return
	if points.size() >= LaunchLimits.PREDICTION_MAX_POINTS:
		if not is_event:
			return
		var removable: int = -1
		for index: int in range(points.size() - 1, 0, -1):
			if points[index].marker() == TrajectoryPoint.Marker.NONE:
				removable = index
				break
		if removable < 0:
			status.fail(SimStatus.Code.PREDICTION_LIMIT_EXCEEDED, SimStatus.Operation.TRAJECTORY_PREDICT, points.size(), point.marker())
			return
		points.remove_at(removable)
	points.append(point.copy())


static func _body_position(world: SimWorld, body_id: int, status: SimStatus) -> FixVec2:
	var lookup := SimStatus.new()
	var body: SimBody = world.body_by_id(body_id, lookup)
	if not lookup.is_ok():
		status.fail(lookup.code(), SimStatus.Operation.TRAJECTORY_PREDICT, body_id, 0)
		return FixVec2.zero()
	return body.position()


static func _event_involves_actor(event: SimEvent, actor_body_id: int) -> bool:
	return event.source_body_id() == actor_body_id or event.target_body_id() == actor_body_id


static func predict(state: BattleState, command: LaunchCommand, status: SimStatus) -> TrajectoryPrediction:
	var neutral := TrajectoryPrediction.new()
	if not status.is_ok():
		return neutral
	if state == null or not state.is_initialized() or state.phase() != BattleState.Phase.AIM or state.has_pending_mutations():
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.TRAJECTORY_PREDICT, 0 if state == null else state.phase(), 0)
		return neutral
	var before_status := SimStatus.new()
	var before_bytes: PackedByteArray = BattleSnapshot.capture(state, before_status).encode(before_status)
	if not before_status.is_ok():
		status.fail(before_status.code(), SimStatus.Operation.TRAJECTORY_PREDICT, before_status.detail_a(), before_status.detail_b())
		return neutral
	var local: BattleState = state.copy(status)
	var actor_body_id: int = local.current_actor_body_id()
	var local_world: SimWorld = local.world_copy(status)
	var points: Array[TrajectoryPoint] = []
	_append_point(points, TrajectoryPoint.create(0, 0, _body_position(local_world, actor_body_id, status), TrajectoryPoint.Marker.NONE, 0, status), false, status)
	if not status.is_ok() or not LaunchVelocitySolver.commit(local, command, status):
		return neutral
	var scanned_event_count: int = local_world.event_count()
	var wall_hits: int = 0
	var ticks: int = 0
	var terminal: bool = false
	while status.is_ok() and not terminal and ticks < LaunchLimits.PREDICTION_MAX_TICKS:
		if local.phase() != BattleState.Phase.RESOLVE:
			break
		if not local.advance_resolve(status):
			return neutral
		ticks += 1
		local_world = local.world_copy(status)
		var destroyed_event: SimEvent = null
		var collision_event: SimEvent = null
		var second_wall_event: SimEvent = null
		var stopped_event: SimEvent = null
		for event_index: int in range(scanned_event_count, local_world.event_count()):
			var event: SimEvent = local_world.event_at(event_index, status)
			if not _event_involves_actor(event, actor_body_id):
				continue
			match event.type_id():
				SimEvent.TypeId.BODY_DESTROYED:
					if destroyed_event == null: destroyed_event = event
				SimEvent.TypeId.BODY_COLLIDED:
					if collision_event == null: collision_event = event
				SimEvent.TypeId.BODY_HIT_WALL:
					wall_hits += 1
					_append_point(points, TrajectoryPoint.create(ticks, event.sequence(), event.position(), TrajectoryPoint.Marker.WALL, 0, status), true, status)
					if wall_hits == LaunchLimits.PREDICTION_MAX_WALL_HITS and second_wall_event == null: second_wall_event = event
				SimEvent.TypeId.BODY_STOPPED:
					if stopped_event == null: stopped_event = event
		scanned_event_count = local_world.event_count()
		var selected: SimEvent = null
		var marker: int = TrajectoryPoint.Marker.NONE
		var target_body_id: int = 0
		if destroyed_event != null:
			selected = destroyed_event; marker = TrajectoryPoint.Marker.DESTROYED
		elif collision_event != null:
			selected = collision_event; marker = TrajectoryPoint.Marker.COLLISION
			target_body_id = collision_event.target_body_id() if collision_event.source_body_id() == actor_body_id else collision_event.source_body_id()
		elif second_wall_event != null:
			selected = second_wall_event; marker = TrajectoryPoint.Marker.WALL
		elif stopped_event != null:
			selected = stopped_event; marker = TrajectoryPoint.Marker.STOPPED
		if selected != null:
			_append_point(points, TrajectoryPoint.create(ticks, selected.sequence(), selected.position(), marker, target_body_id, status), true, status)
			terminal = true
		elif local.phase() == BattleState.Phase.TURN_END:
			var end_position: FixVec2 = _body_position(local_world, actor_body_id, status)
			_append_point(points, TrajectoryPoint.create(ticks, 0, end_position, TrajectoryPoint.Marker.STOPPED, 0, status), true, status)
			terminal = true
		elif ticks % LaunchLimits.PREDICTION_SAMPLE_TICKS == 0:
			var sample_status := SimStatus.new()
			var sample_body: SimBody = local_world.body_by_id(actor_body_id, sample_status)
			if sample_status.is_ok():
				_append_point(points, TrajectoryPoint.create(ticks, 0, sample_body.position(), TrajectoryPoint.Marker.NONE, 0, status), false, status)
	var truncated: bool = not terminal and ticks >= LaunchLimits.PREDICTION_MAX_TICKS
	if truncated:
		var final_position: FixVec2 = _body_position(local_world, actor_body_id, status)
		_append_point(points, TrajectoryPoint.create(ticks, 0, final_position, TrajectoryPoint.Marker.TRUNCATED, 0, status), true, status)
	var after_status := SimStatus.new()
	var after_bytes: PackedByteArray = BattleSnapshot.capture(state, after_status).encode(after_status)
	if not after_status.is_ok() or before_bytes != after_bytes:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.TRAJECTORY_PREDICT, before_bytes.size(), after_bytes.size())
		return neutral
	return TrajectoryPrediction.create(actor_body_id, ticks, truncated, points, status)
