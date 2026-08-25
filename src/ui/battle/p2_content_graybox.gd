class_name P2ContentGraybox
extends Node2D
## Data-driven P2-6 playable graybox. Core state remains authoritative.

signal run_battle_finished(outcome: RunBattleOutcome)

const PLAYER_TEXTURE := preload("res://assets/art/sprites/p1_graybox/PLACEHOLDER_player_piece.png")
const ENEMY_TEXTURE := preload("res://assets/art/sprites/p1_graybox/PLACEHOLDER_enemy_piece.png")
const DAMAGE_ZONE_TEXTURE := preload("res://assets/art/zones/turn_start_damage.png")
const PIECE_VISUALS_PATH := "res://src/ui/battle/piece_visuals.json"
const BOARD_VISUALS_PATH := "res://src/ui/battle/board_visuals.json"
const ABILITY_PRESENTATIONS_PATH := "res://src/ui/battle/ability_presentations.json"
const CONTENT_DRIVER: Script = preload("res://src/ui/battle/p2_content_battle_driver.gd")
const PREDICTION_QUEUE: Script = preload("res://src/ui/battle/trajectory_prediction_queue.gd")
const ENEMY_ACTION_DELAY: Script = preload("res://src/ui/battle/enemy_action_delay.gd")
const PIECE_SCALE := Vector2(4.0 / 3.0, 4.0 / 3.0)
const RESOLVE_STEPS_PER_FRAME := 12
const RESOLVE_FRAME_BUDGET_USEC := 12000
const SEED_HI := 0x12345678
const SEED_LO := 0x2468ACE0
const PREVIEW_COUNT := 6

@onready var _battlefield: Node2D = $Battlefield
@onready var _map_visuals: Node2D = $Battlefield/MapVisuals
@onready var _pieces: Node2D = $Battlefield/Pieces
@onready var _aim_line: Line2D = $Battlefield/AimLayer/AimLine
@onready var _trajectory_line: Line2D = $Battlefield/AimLayer/TrajectoryLine
@onready var _aim_marker: Sprite2D = $Battlefield/AimLayer/AimMarker
@onready var _status_label: Label = $Hud/Margin/Rows/Status
@onready var _details_label: Label = $Hud/Margin/Rows/Details
@onready var _help_label: Label = $Hud/Margin/Rows/Help
@onready var _input: AimInputAdapter = $AimInputAdapter

var _catalog: ContentCatalog = ContentCatalog.new()
var _map_definition: MapDefinition = MapDefinition.new()
var _encounter_definition: EncounterDefinition = EncounterDefinition.new()
var _piece_definitions: Array[PieceDefinition] = []
var _enemy_definitions: Array[EnemyDefinition] = []
var _selected_piece_indices: Array[int] = []
var _state: BattleState
var _piece_nodes: Dictionary = {}
var _trajectory := TrajectoryLineAdapter.new()
var _turns: int = 0
var _error: SimStatus = SimStatus.new()
var _content_error: ContentStatus = ContentStatus.new()
var _prediction_thread: Thread = null
var _prediction_queue: TrajectoryPredictionQueue = PREDICTION_QUEUE.new()
var _prediction_source_state: BattleState = null
var _prediction_cache: Dictionary = {}
var _aim_power_step: int = 0
var _enemy_action_delay: EnemyActionDelay = ENEMY_ACTION_DELAY.new()
var _ai_review_grade_id: int = AiGrade.Value.COMMON
var _run_mode: bool = false
var _run_request := RunBattleRequest.new()
var _run_outcome_emitted: bool = false
var _damage_notice: String = ""
var _piece_visuals: Dictionary = {}
var _board_visuals: Dictionary = {}
var _ability_presentations: Dictionary = {}
var _aim_command: LaunchCommand = LaunchCommand.new()
var _aim_first_target_body_id: int = 0


func _ready() -> void:
	_input.configure(_provide_state, _screen_to_world)
	_input.prediction_requested.connect(_on_prediction_requested)
	_input.launch_requested.connect(_on_launch_requested)
	_input.aim_cancelled.connect(_clear_aim)
	_help_label.text = "기물 중심에서 멀리 당길수록 강하게 발사 · 1/2/3: 기물 순환 · AI등급 F1/F2/F3 또는 7/8/9 · R: 재시작 · Esc: 취소"
	_load_content()
	if _content_error.is_ok():
		_build_map_view()
		_restart()
	else:
		_sync_view()


func _load_content() -> void:
	_catalog = DataDB.catalog_copy(_content_error)
	if not _content_error.is_ok():
		return
	if _catalog.map_count() < 1 or _catalog.piece_count() < 1 or _catalog.enemy_count() < 1:
		_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP)
		return
	_map_definition = _catalog.map_at(0, _content_error)
	_encounter_definition = _catalog.encounter_at(0, _content_error)
	if not _content_error.is_ok():
		return
	for index: int in range(_catalog.piece_count()):
		_piece_definitions.append(_catalog.piece_at(index, _content_error))
	_load_piece_visuals()
	_load_board_visuals()
	_load_ability_presentations()
	if not _content_error.is_ok():
		return
	for index: int in range(_encounter_definition.enemy_ref_count()):
		_enemy_definitions.append(_catalog.enemy_by_numeric_id(_encounter_definition.enemy_ref_at(index, _content_error).numeric_id(), _content_error))
	if not _content_error.is_ok():
		return
	for slot_index: int in range(_map_definition.deploy_count()):
		_selected_piece_indices.append(slot_index % _piece_definitions.size())


func _process(_delta: float) -> void:
	if not visible:
		return
	_poll_prediction()
	if not _content_error.is_ok() or not _error.is_ok() or _state == null:
		_sync_view()
		return
	if _state.phase() == BattleState.Phase.RESOLVE:
		var frame_started: int = Time.get_ticks_usec()
		for _step: int in range(RESOLVE_STEPS_PER_FRAME):
			if _state.phase() != BattleState.Phase.RESOLVE:
				break
			_state.advance_resolve(_error)
			_resolve_content_transition()
			if not _error.is_ok():
				break
			if Time.get_ticks_usec() - frame_started >= RESOLVE_FRAME_BUDGET_USEC:
				break
	_advance_noninteractive_phases()
	_emit_run_outcome_if_ready()
	_sync_view()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_input.cancel_aim()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if not _run_mode: _restart()
				return
			KEY_1, KEY_2, KEY_3:
				if not _run_mode: _cycle_player_slot(int(event.keycode - KEY_1))
				return
			KEY_F1, KEY_7:
				if not _run_mode: select_ai_review_grade(AiGrade.Value.COMMON)
				return
			KEY_F2, KEY_8:
				if not _run_mode: select_ai_review_grade(AiGrade.Value.ELITE)
				return
			KEY_F3, KEY_9:
				if not _run_mode: select_ai_review_grade(AiGrade.Value.BOSS)
				return
	if not event is InputEventMouse or not _content_error.is_ok() or not _error.is_ok():
		return
	var mouse_event: InputEventMouse = event
	if mouse_event is InputEventMouseButton and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed and _pointer_hits_actor(mouse_event.position):
			_input.begin_aim(mouse_event.position)
		elif not mouse_event.pressed:
			_input.release_aim(mouse_event.position)
	elif mouse_event is InputEventMouseMotion:
		_input.update_aim(mouse_event.position)


func _provide_state() -> BattleState:
	return _state


func _screen_to_world(pointer_screen: Vector2) -> Vector2:
	return _battlefield.to_local(pointer_screen)


func _pointer_hits_actor(pointer_screen: Vector2) -> bool:
	if _state == null or _state.phase() != BattleState.Phase.AIM:
		return false
	var status := SimStatus.new()
	var world: SimWorld = _state.world_copy(status)
	var actor: SimBody = world.body_by_id(_state.current_actor_body_id(), status)
	if not status.is_ok():
		return false
	var center := _fix_to_vector(actor.position())
	return _screen_to_world(pointer_screen).distance_to(center) <= float(actor.radius_raw()) / float(FixMath.SCALE)


func _build_deployment(status: SimStatus) -> Array[BattleDeploymentEntry]:
	var result: Array[BattleDeploymentEntry] = []
	var content_status := ContentStatus.new()
	for slot_index: int in range(_map_definition.deploy_count()):
		var piece: PieceDefinition = _piece_definitions[_selected_piece_indices[slot_index]]
		result.append(BattleDeploymentEntry.create_player(slot_index, piece.id_ref(), 1, status))
	for slot_index: int in range(_map_definition.deploy_count()):
		var enemy: EnemyDefinition = _enemy_definitions[slot_index % _enemy_definitions.size()]
		var enemy_ref := ContentIdRef.create(enemy.numeric_id(), enemy.string_id(), content_status)
		result.append(BattleDeploymentEntry.create_enemy(slot_index, enemy_ref, status))
	if not content_status.is_ok() and status.is_ok():
		status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.BATTLE_SETUP_BUILD)
	return result


func _advance_noninteractive_phases() -> void:
	while _error.is_ok() and _state.phase() != BattleState.Phase.AIM and _state.phase() != BattleState.Phase.RESOLVE and _state.phase() != BattleState.Phase.BATTLE_END:
		match _state.phase():
			BattleState.Phase.BATTLE_START: _state.complete_battle_start(_error); _resolve_content_transition()
			BattleState.Phase.TURN_START:
				_damage_notice = ""
				var actor_id: int = _state.current_actor_body_id()
				var before_status := SimStatus.new()
				var before_hp: int = _state.combatant_by_body_id(actor_id, before_status).current_hp()
				_state.complete_turn_start(_error)
				if _error.is_ok() and before_status.is_ok():
					var after_status := SimStatus.new()
					var after_hp: int = 0
					var after: BattleCombatant = _state.combatant_by_body_id(actor_id, after_status)
					if after_status.is_ok(): after_hp = after.current_hp()
					if before_hp > after_hp: _damage_notice = " · 데미지 존 -%d" % (before_hp - after_hp)
				_resolve_content_transition()
			BattleState.Phase.TURN_END: _state.complete_turn_end(_error); _resolve_content_transition()
			BattleState.Phase.CHECK: _state.resolve_check(_error); _resolve_content_transition()
			_: _error.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, _state.phase(), 0)
	if _error.is_ok() and _state.phase() == BattleState.Phase.AIM:
		var participant: BattleParticipant = _state.participant_by_body_id(_state.current_actor_body_id(), _error)
		if _error.is_ok() and participant.faction() == BattleParticipant.Faction.ENEMY:
			if not _enemy_action_delay.is_ready(_state.current_actor_body_id(), Time.get_ticks_msec()):
				return
			_enemy_action_delay.consume()
			var grade_id: int = _run_enemy_grade(_state.current_actor_body_id(), _error) if _run_mode else _ai_review_grade_id
			var command: LaunchCommand = AiShotSelector.command_for(_state, grade_id, _error)
			if _error.is_ok():
				LaunchVelocitySolver.commit(_state, command, _error)
				_resolve_content_transition()
				_turns += 1
		else:
			_enemy_action_delay.reset()
	elif _state.phase() == BattleState.Phase.BATTLE_END:
		_enemy_action_delay.reset()


func _resolve_content_transition() -> void:
	if _error.is_ok() and _state != null:
		CONTENT_DRIVER.resolve_last_transition(_state, _error)


func _on_prediction_requested(command: LaunchCommand) -> void:
	var status := SimStatus.new()
	var actor_position := _fix_to_vector(_input.actor_center())
	var fixed_direction: FixVec2 = FixTrigLut.direction(command.angle(), status)
	if not status.is_ok():
		return
	var direction := Vector2(float(fixed_direction.x_raw()), float(fixed_direction.y_raw())).normalized()
	_aim_power_step = command.power_step()
	_aim_command = command.copy()
	_aim_first_target_body_id = 0
	var guide_length: float = (
		float(LaunchLimits.MAX_DRAG_DISTANCE_RAW)
		* float(_aim_power_step)
		/ float(FixMath.SCALE * LaunchLimits.POWER_STEPS)
	)
	var guide_end: Vector2 = actor_position + direction * guide_length
	_aim_line.points = PackedVector2Array([actor_position, guide_end])
	_aim_marker.position = guide_end
	_aim_marker.rotation = direction.angle()
	_aim_marker.visible = _aim_power_step > 0

	_prediction_queue.submit(command, Time.get_ticks_usec())
	if not LaunchLimits.valid_launch_power_step(command.power_step()):
		_trajectory.clear()
		_trajectory_line.clear_points()
		return
	var cache_key: int = _prediction_cache_key(command)
	if _prediction_cache.has(cache_key):
		_prediction_queue.take_pending()
		_show_prediction(_prediction_cache[cache_key] as TrajectoryPrediction)
	else:
		_trajectory.clear()
		_trajectory_line.clear_points()


func _start_pending_prediction() -> void:
	if not _prediction_queue.has_pending() or _state == null:
		return
	var status := SimStatus.new()
	if _prediction_source_state == null:
		_prediction_source_state = _state.copy(status)
	if not status.is_ok() or _prediction_source_state == null:
		_prediction_queue.take_pending()
		return
	var command: LaunchCommand = _prediction_queue.take_pending()
	var session: int = _prediction_queue.session()
	var generation: int = _prediction_queue.generation()
	_prediction_thread = Thread.new()
	var start_error: int = _prediction_thread.start(
		_predict_trajectory.bind(
			_prediction_source_state,
			command,
			session,
			generation,
			_prediction_cache_key(command)
		),
		Thread.PRIORITY_LOW
	)
	if start_error != OK:
		_prediction_thread = null


func _predict_trajectory(
		source_state: BattleState,
		command: LaunchCommand,
		session: int,
		generation: int,
		cache_key: int
) -> Dictionary:
	var status := SimStatus.new()
	var prediction: TrajectoryPrediction = TrajectoryPredictor.predict(source_state, command, status)
	return {
		"session": session,
		"generation": generation,
		"cache_key": cache_key,
		"prediction": prediction,
		"code": status.code(),
		"operation": status.operation(),
	}


func _poll_prediction() -> void:
	if _prediction_thread != null and not _prediction_thread.is_alive():
		var result: Variant = _prediction_thread.wait_to_finish()
		_prediction_thread = null
		if (
			result is Dictionary
			and int(result.get("session", -1)) == _prediction_queue.session()
			and int(result.get("code", SimStatus.Code.INVALID_SIM_STATE)) == SimStatus.Code.OK
		):
			var prediction: TrajectoryPrediction = result.get("prediction") as TrajectoryPrediction
			_prediction_cache[int(result.get("cache_key", -1))] = prediction
			if (
				int(result.get("generation", -1)) == _prediction_queue.generation()
				and _input.is_dragging()
			):
				_show_prediction(prediction)
	if _prediction_queue.can_start(
		Time.get_ticks_usec(), _prediction_thread != null, _input.is_dragging()
	):
		_start_pending_prediction()


func _prediction_cache_key(command: LaunchCommand) -> int:
	return (command.angle() << 9) | command.power_step()


func _show_prediction(prediction: TrajectoryPrediction) -> void:
	var status := SimStatus.new()
	_trajectory.update_from_prediction(prediction, status)
	if status.is_ok():
		_trajectory_line.points = _trajectory.positions()
		_aim_first_target_body_id = 0
		for index: int in range(prediction.point_count()):
			var point: TrajectoryPoint = prediction.point_at(index, status)
			if point.marker() == TrajectoryPoint.Marker.COLLISION:
				_aim_first_target_body_id = point.target_body_id()
				break


func _on_launch_requested(command: LaunchCommand) -> void:
	_clear_aim()
	LaunchVelocitySolver.commit(_state, command, _error)
	if _error.is_ok():
		_resolve_content_transition()
		_turns += 1


func _clear_aim() -> void:
	_prediction_queue.reset()
	_prediction_source_state = null
	_prediction_cache.clear()
	_aim_power_step = 0
	_aim_command = LaunchCommand.new()
	_aim_first_target_body_id = 0
	_trajectory.clear()
	_trajectory_line.clear_points()
	_aim_line.clear_points()
	_aim_marker.visible = false


func _exit_tree() -> void:
	_prediction_queue.reset()
	_prediction_source_state = null
	_prediction_cache.clear()
	if _prediction_thread != null:
		_prediction_thread.wait_to_finish()
		_prediction_thread = null


func _fix_to_vector(value: FixVec2) -> Vector2:
	return Vector2(float(value.x_raw()), float(value.y_raw())) / float(FixMath.SCALE)


func _build_map_view() -> void:
	for child: Node in _map_visuals.get_children():
		child.queue_free()
	var content_status := ContentStatus.new()
	var boundary_points := PackedVector2Array()
	for vertex: FixVec2 in _map_definition.boundary_vertices_copy():
		boundary_points.append(_fix_to_vector(vertex))
	var has_board_visual: bool = _add_board_visual(boundary_points)
	if not has_board_visual:
		var floor := Polygon2D.new()
		floor.name = "Floor"
		floor.polygon = boundary_points
		floor.color = Color(0.105, 0.125, 0.15, 1.0)
		_map_visuals.add_child(floor)
	for zone_index: int in range(_map_definition.zone_count()):
		var zone: MapZoneDefinition = _map_definition.zone_at(zone_index, content_status)
		var points := PackedVector2Array()
		var center := Vector2.ZERO
		for vertex: FixVec2 in zone.vertices_copy():
			var point := _fix_to_vector(vertex)
			points.append(point)
			center += point
		center /= float(points.size())
		var fill := Polygon2D.new()
		fill.name = "Zone%d" % zone.local_id()
		fill.polygon = points
		fill.color = _zone_color(zone, 0.34)
		_map_visuals.add_child(fill)
		var outline := Line2D.new()
		outline.width = 4.0
		outline.default_color = _zone_color(zone, 0.95)
		outline.points = points
		outline.add_point(points[0])
		_map_visuals.add_child(outline)
		var label := Label.new()
		label.text = "KILL" if zone.is_kill_zone() else "ZONE"
		label.position = center - Vector2(42.0, 14.0)
		label.size = Vector2(84.0, 28.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", _zone_color(zone, 1.0))
		_map_visuals.add_child(label)
	for zone_index: int in range(_encounter_definition.damage_zone_count()):
		var damage_zone: EncounterDamageZoneDefinition = _encounter_definition.damage_zone_at(zone_index, content_status)
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		var center := Vector2.ZERO
		for vertex: FixVec2 in damage_zone.vertices_copy():
			var point := _fix_to_vector(vertex)
			points.append(point); uv.append(point); center += point
		center /= float(points.size())
		var fill := Polygon2D.new()
		fill.name = "DamageZone%d" % damage_zone.local_id()
		fill.polygon = points; fill.uv = uv; fill.texture = DAMAGE_ZONE_TEXTURE
		fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		fill.color = Color(1.0, 1.0, 1.0, 0.38)
		_map_visuals.add_child(fill)
		var outline := Line2D.new()
		outline.width = 2.0; outline.default_color = Color(1.0, 0.416, 0.125, 0.9); outline.points = points; outline.add_point(points[0])
		_map_visuals.add_child(outline)
		var label := Label.new()
		label.text = "턴 시작 -%d" % damage_zone.turn_start_damage()
		label.position = center - Vector2(70.0, 14.0); label.size = Vector2(140.0, 28.0); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18); label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
		_map_visuals.add_child(label)
	var walls := Line2D.new()
	walls.name = "Walls"
	walls.width = 4.0
	walls.default_color = Color(0.58, 0.66, 0.78, 1.0)
	walls.points = boundary_points
	walls.add_point(boundary_points[0])
	_map_visuals.add_child(walls)
	if not content_status.is_ok():
		_content_error = content_status


func _add_board_visual(boundary_points: PackedVector2Array) -> bool:
	var visual: Dictionary = _board_visuals.get(_map_definition.numeric_id(), {}) as Dictionary
	if visual.is_empty() or boundary_points.is_empty():
		return false
	var boundary_min: Vector2 = boundary_points[0]
	var boundary_max: Vector2 = boundary_points[0]
	for point: Vector2 in boundary_points:
		boundary_min = Vector2(minf(boundary_min.x, point.x), minf(boundary_min.y, point.y))
		boundary_max = Vector2(maxf(boundary_max.x, point.x), maxf(boundary_max.y, point.y))
	var arena_width: float = float(int(visual["arena_right_px"]) - int(visual["arena_left_px"]))
	var arena_height: float = float(int(visual["arena_bottom_px"]) - int(visual["arena_top_px"]))
	var board_scale := Vector2((boundary_max.x - boundary_min.x) / arena_width, (boundary_max.y - boundary_min.y) / arena_height)
	var board := Sprite2D.new()
	board.name = "Board"
	board.centered = false
	board.texture = visual["texture"] as Texture2D
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.scale = board_scale
	board.position = boundary_min - Vector2(float(int(visual["arena_left_px"])), float(int(visual["arena_top_px"]))) * board_scale
	_map_visuals.add_child(board)
	return true


func _zone_color(zone: MapZoneDefinition, alpha: float) -> Color:
	if zone.is_kill_zone():
		return Color(0.95, 0.18, 0.22, alpha)
	if not zone.acceleration().is_zero():
		return Color(0.1, 0.78, 0.9, alpha)
	return Color(0.35, 0.58, 0.95, alpha)


func _identity_for_body(body_id: int, status: SimStatus) -> BattlePieceIdentity:
	for index: int in range(_state.piece_identity_count()):
		var identity: BattlePieceIdentity = _state.piece_identity_at(index, status)
		if identity.body_id() == body_id:
			return identity
	return BattlePieceIdentity.new()


func _status_text_for_body(body_id: int, status: SimStatus) -> String:
	var items: PackedStringArray = PackedStringArray()
	for index: int in range(_state.status_count()):
		var instance: StatusInstance = _state.status_at(index, status)
		if instance.target_body_id() != body_id:
			continue
		var content_status := ContentStatus.new()
		var definition: StatusDefinition = _catalog.status_by_numeric_id(instance.status_numeric_id(), content_status)
		if not content_status.is_ok():
			return "status_error"
		items.append("%s×%d/%d" % [definition.string_id(), instance.stacks(), instance.remaining()])
	return ",".join(items)


func _load_piece_visuals() -> void:
	var file := FileAccess.open(PIECE_VISUALS_PATH, FileAccess.READ)
	if file == null:
		_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_content_error.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return
	var root: Dictionary = parsed as Dictionary
	if root.size() != 2 or not root.has("schema_version") or not root.has("records") or root["schema_version"] != 1 or typeof(root["records"]) != TYPE_ARRAY:
		_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return
	for value: Variant in root["records"] as Array:
		if typeof(value) != TYPE_DICTIONARY:
			_content_error.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		var record: Dictionary = value as Dictionary
		var keys: PackedStringArray = PackedStringArray(["numeric_id", "id", "texture", "pixel_width", "pixel_height", "scale_raw"])
		if record.size() != keys.size():
			_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		for key: String in keys:
			if not record.has(key):
				_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
				return
		var numeric_id: int = int(record["numeric_id"])
		var piece: PieceDefinition = _catalog.piece_by_numeric_id(numeric_id, _content_error)
		if not _content_error.is_ok() or piece.string_id() != String(record["id"]) or _piece_visuals.has(numeric_id):
			if _content_error.is_ok(): _content_error.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.REFERENCE_RESOLVE)
			return
		var path: String = String(record["texture"])
		if not path.begins_with("res://assets/art/") or not path.ends_with(".png"):
			_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or texture.get_width() != int(record["pixel_width"]) or texture.get_height() != int(record["pixel_height"]) or int(record["scale_raw"]) <= 0:
			_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		_piece_visuals[numeric_id] = {"texture": texture, "scale": float(int(record["scale_raw"])) / float(FixMath.SCALE)}


func _load_board_visuals() -> void:
	var file := FileAccess.open(BOARD_VISUALS_PATH, FileAccess.READ)
	if file == null:
		_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_content_error.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return
	var root: Dictionary = parsed as Dictionary
	if root.size() != 2 or not root.has("schema_version") or not root.has("records") or root["schema_version"] != 1 or typeof(root["records"]) != TYPE_ARRAY:
		_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return
	var keys: PackedStringArray = PackedStringArray(["numeric_id", "id", "texture", "pixel_width", "pixel_height", "arena_left_px", "arena_top_px", "arena_right_px", "arena_bottom_px"])
	for value: Variant in root["records"] as Array:
		if typeof(value) != TYPE_DICTIONARY:
			_content_error.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		var record: Dictionary = value as Dictionary
		if record.size() != keys.size():
			_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		for key: String in keys:
			if not record.has(key):
				_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
				return
		var numeric_id: int = int(record["numeric_id"])
		var map: MapDefinition = _catalog.map_by_numeric_id(numeric_id, _content_error)
		if not _content_error.is_ok() or map.string_id() != String(record["id"]) or _board_visuals.has(numeric_id):
			if _content_error.is_ok(): _content_error.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.REFERENCE_RESOLVE)
			return
		var path: String = String(record["texture"])
		var pixel_width: int = int(record["pixel_width"])
		var pixel_height: int = int(record["pixel_height"])
		var left: int = int(record["arena_left_px"])
		var top: int = int(record["arena_top_px"])
		var right: int = int(record["arena_right_px"])
		var bottom: int = int(record["arena_bottom_px"])
		if not path.begins_with("res://assets/art/") or not path.ends_with(".png") or left < 0 or top < 0 or right <= left or bottom <= top or right > pixel_width or bottom > pixel_height:
			_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or texture.get_width() != pixel_width or texture.get_height() != pixel_height:
			_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		_board_visuals[numeric_id] = {
			"texture": texture,
			"arena_left_px": left,
			"arena_top_px": top,
			"arena_right_px": right,
			"arena_bottom_px": bottom,
		}


func _load_ability_presentations() -> void:
	var file := FileAccess.open(ABILITY_PRESENTATIONS_PATH, FileAccess.READ)
	if file == null:
		_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_content_error.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return
	var root: Dictionary = parsed as Dictionary
	if root.size() != 2 or root.get("schema_version", 0) != 1 or typeof(root.get("records", null)) != TYPE_ARRAY:
		_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return
	for value: Variant in root["records"] as Array:
		if typeof(value) != TYPE_DICTIONARY:
			_content_error.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		var record: Dictionary = value as Dictionary
		if record.size() != 3 or not record.has("ability_numeric_id") or not record.has("id") or not record.has("aim_detail_mode_id"):
			_content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return
		var ability_id: int = int(record["ability_numeric_id"])
		var ability: AbilityDefinition = _catalog.ability_by_numeric_id(ability_id, _content_error)
		var mode_id: int = int(record["aim_detail_mode_id"])
		if not _content_error.is_ok() or ability.string_id() != String(record["id"]) or mode_id != 1 or _ability_presentations.has(ability_id):
			if _content_error.is_ok(): _content_error.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REFERENCE_RESOLVE)
			return
		_ability_presentations[ability_id] = mode_id


func _actor_aim_detail_mode(status: SimStatus) -> int:
	if _state == null or _state.current_actor_body_id() == 0: return 0
	var identity: BattlePieceIdentity = _identity_for_body(_state.current_actor_body_id(), status)
	if not identity.is_initialized(): return 0
	var content_status := ContentStatus.new()
	var piece: PieceDefinition = _catalog.piece_by_numeric_id(identity.piece_numeric_id(), content_status)
	var level: PieceLevelDefinition = piece.level_definition(identity.level(), content_status)
	if not content_status.is_ok(): return 0
	for index: int in range(level.ability_ref_count()):
		var ability_ref: ContentIdRef = level.ability_ref_at(index, content_status)
		if _ability_presentations.has(ability_ref.numeric_id()): return int(_ability_presentations[ability_ref.numeric_id()])
	return 0


func _aim_detail_text(status: SimStatus) -> String:
	if not _input.is_dragging() or not _aim_command.is_initialized() or _actor_aim_detail_mode(status) != 1: return ""
	var angle_degrees: int = (_aim_command.angle() * 360 + 32768) / 65536
	var power_percent: int = (_aim_command.power_step() * 100 + LaunchLimits.POWER_STEPS / 2) / LaunchLimits.POWER_STEPS
	var target_name: String = "없음"
	if _aim_first_target_body_id > 0:
		var identity: BattlePieceIdentity = _identity_for_body(_aim_first_target_body_id, status)
		if identity.is_initialized():
			var content_status := ContentStatus.new()
			var piece: PieceDefinition = _catalog.piece_by_numeric_id(identity.piece_numeric_id(), content_status)
			target_name = piece.string_id() if content_status.is_ok() else "#%d" % _aim_first_target_body_id
	return " · 계산 각도 %d° / 파워 %d%% / 첫 충돌 %s" % [angle_degrees, power_percent, target_name]


func _configure_piece_sprite(holder: Node2D, faction: int, piece: PieceDefinition) -> void:
	var sprite: Sprite2D = holder.get_node("Sprite") as Sprite2D
	var visual: Dictionary = _piece_visuals.get(piece.numeric_id(), {}) as Dictionary
	if visual.is_empty():
		sprite.texture = PLAYER_TEXTURE if faction == BattleParticipant.Faction.PLAYER else ENEMY_TEXTURE
		sprite.scale = PIECE_SCALE
	else:
		sprite.texture = visual["texture"] as Texture2D
		var scale_value: float = float(visual["scale"])
		sprite.scale = Vector2(scale_value, scale_value)
	holder.set_meta("piece_numeric_id", piece.numeric_id())


func _ensure_piece_view(body_id: int, faction: int, piece: PieceDefinition) -> Node2D:
	var holder: Node2D = _piece_nodes.get(body_id) as Node2D
	if holder != null:
		if int(holder.get_meta("piece_numeric_id", 0)) != piece.numeric_id():
			_configure_piece_sprite(holder, faction, piece)
		return holder
	holder = Node2D.new()
	holder.name = "Body%d" % body_id
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	holder.add_child(sprite)
	var ring := Line2D.new()
	ring.name = "FactionRing"
	ring.width = 3.0
	ring.default_color = Color(0.20, 0.92, 0.84) if faction == BattleParticipant.Faction.PLAYER else Color(1.0, 0.43, 0.20)
	for point_index: int in range(33):
		var angle: float = TAU * float(point_index) / 32.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * 35.0)
	holder.add_child(ring)
	var faction_mark := Polygon2D.new()
	faction_mark.name = "FactionMark"
	faction_mark.color = ring.default_color
	faction_mark.polygon = PackedVector2Array([Vector2(-5, -39), Vector2(5, -39), Vector2(0, -31)]) if faction == BattleParticipant.Faction.PLAYER else PackedVector2Array([Vector2(-6, -39), Vector2(6, -39), Vector2(0, -29)])
	holder.add_child(faction_mark)
	var actor_mark := Polygon2D.new()
	actor_mark.name = "ActorMark"
	actor_mark.color = Color(1.0, 0.92, 0.25)
	actor_mark.polygon = PackedVector2Array([Vector2(-8, -49), Vector2(8, -49), Vector2(0, -38)])
	actor_mark.visible = false
	holder.add_child(actor_mark)
	var label := Label.new()
	label.name = "Info"
	label.position = Vector2(-105.0, 42.0)
	label.size = Vector2(210.0, 70.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	holder.add_child(label)
	_pieces.add_child(holder)
	_piece_nodes[body_id] = holder
	_configure_piece_sprite(holder, faction, piece)
	return holder


func _selection_text() -> String:
	if _run_mode and _run_request.is_initialized():
		var run_ids: PackedStringArray = PackedStringArray()
		var status := SimStatus.new()
		for index: int in range(_run_request.player_count()):
			var entry: RunBattlePlayerEntry = _run_request.player_at(index, status)
			var content_status := ContentStatus.new()
			var piece: PieceDefinition = _catalog.piece_by_numeric_id(entry.piece_numeric_id(), content_status)
			run_ids.append("#%d %s L%d" % [entry.run_instance_id(), piece.string_id(), entry.level()])
		return " / ".join(run_ids)
	var ids: PackedStringArray = PackedStringArray()
	for selected_index: int in _selected_piece_indices:
		ids.append(_piece_definitions[selected_index].string_id())
	return " / ".join(ids)


func _synergy_text() -> String:
	if _state == null:
		return ""
	var tally: SynergyTally = _state.synergy_tally_copy()
	var player: PackedStringArray = PackedStringArray()
	var enemy: PackedStringArray = PackedStringArray()
	for index: int in range(tally.count()):
		var content_status := ContentStatus.new()
		var definition: SynergyDefinition = _catalog.synergy_by_tag_numeric_id(tally.tag_numeric_id_at(index), content_status)
		var text_value := "%s=%d" % [definition.tag_ref().string_id(), tally.value_at(index)] if content_status.is_ok() else "tag_error"
		if tally.faction_id_at(index) == BattleParticipant.Faction.PLAYER:
			player.append(text_value)
		else:
			enemy.append(text_value)
	return "P[%s] E[%s]" % [", ".join(player) if not player.is_empty() else "없음", ", ".join(enemy) if not enemy.is_empty() else "없음"]


func _preview_text(status: SimStatus) -> String:
	if _state == null or _state.phase() == BattleState.Phase.BATTLE_END:
		return ""
	var entries: Array[CtbPreviewEntry] = _state.preview(PREVIEW_COUNT, status)
	var ids: PackedStringArray = PackedStringArray()
	for entry: CtbPreviewEntry in entries:
		ids.append("#%d" % entry.body_id())
	return "▶".join(ids)


func ai_review_grade_id() -> int:
	return _ai_review_grade_id


func ai_review_grade_name() -> String:
	return String(AiGrade.Value.keys()[_ai_review_grade_id])


func select_ai_review_grade(grade_id: int) -> bool:
	if _run_mode or not AiGrade.is_known(grade_id):
		return false
	_ai_review_grade_id = grade_id
	_restart()
	return true


func _sync_view() -> void:
	if not _content_error.is_ok():
		_status_label.text = "P2-6 콘텐츠 로드 오류 · code %d / op %d / doc %d / record %d" % [_content_error.code(), _content_error.operation(), _content_error.document_kind_id(), _content_error.record_numeric_id()]
		_details_label.text = "fallback 없이 정지"
		return
	if _state == null:
		_status_label.text = "P2-6 전투 초기화 중"
		return
	var status := SimStatus.new()
	var world: SimWorld = _state.world_copy(status)
	var alive: Dictionary = {}
	var max_speed_raw: int = 0
	for index: int in range(world.body_count()):
		var body: SimBody = world.body_at(index, status)
		max_speed_raw = maxi(max_speed_raw, body.velocity().length_raw(status))
		var participant: BattleParticipant = _state.participant_by_body_id(body.id(), status)
		var identity: BattlePieceIdentity = _identity_for_body(body.id(), status)
		var content_status := ContentStatus.new()
		var piece: PieceDefinition = _catalog.piece_by_numeric_id(identity.piece_numeric_id(), content_status)
		var combatant: BattleCombatant = _state.combatant_by_body_id(body.id(), status)
		alive[body.id()] = true
		var holder := _ensure_piece_view(body.id(), participant.faction(), piece)
		holder.position = _fix_to_vector(body.position())
		var sprite: Sprite2D = holder.get_node("Sprite") as Sprite2D
		sprite.modulate = Color.WHITE
		(holder.get_node("ActorMark") as Polygon2D).visible = body.id() == _state.current_actor_body_id()
		var info: Label = holder.get_node("Info") as Label
		var status_text := _status_text_for_body(body.id(), status)
		info.text = "%s L%d\nHP %d/%d%s" % [piece.string_id(), identity.level(), combatant.current_hp(), combatant.max_hp(), "\n" + status_text if not status_text.is_empty() else ""]
		if not content_status.is_ok():
			info.text = "content_error"
	for body_id: Variant in _piece_nodes.keys():
		if not alive.has(body_id):
			(_piece_nodes[body_id] as Node2D).queue_free()
			_piece_nodes.erase(body_id)
	var phase_name: String = BattleState.Phase.keys()[_state.phase()]
	if _run_mode:
		_status_label.text = "런 전투 · node #%d · 턴 %d · %s · actor #%d · 생존 %d/%d · fp %s" % [_run_request.node_id(), _turns, phase_name, _state.current_actor_body_id(), world.body_count(), _run_request.player_count() + _run_request.enemy_count(), _catalog.fingerprint_hex().left(8)]
	else:
		_status_label.text = "P3 AI 검수 %s · 턴 %d · %s · actor #%d · 생존 %d/6 · fp %s" % [ai_review_grade_name(), _turns, phase_name, _state.current_actor_body_id(), world.body_count(), _catalog.fingerprint_hex().left(8)]
	if _input.is_dragging():
		_status_label.text += " · POWER %d/%d" % [_aim_power_step, LaunchLimits.POWER_STEPS]
	if _state.phase() == BattleState.Phase.RESOLVE:
		_status_label.text += " · RESOLVE %d/%d" % [_state.normal_resolve_ticks(), BattleLimits.NORMAL_RESOLVE_MAX_TICKS]
		if _state.forced_settle_used():
			_status_label.text += " · FORCED %d/%d" % [_state.forced_resolve_ticks(), BattleLimits.FORCED_RESOLVE_MAX_TICKS]
		var speed_tenths: int = (max_speed_raw * 10) / FixMath.SCALE
		_status_label.text += " · vmax %d.%d" % [speed_tenths / 10, speed_tenths % 10]
	elif _state.phase() == BattleState.Phase.AIM:
		var delay_remaining: int = _enemy_action_delay.remaining_msec(_state.current_actor_body_id(), Time.get_ticks_msec())
		if delay_remaining > 0:
			_status_label.text += " · 적 발사 대기 %dms" % delay_remaining
	if not _error.is_ok():
		_status_label.text += " · ERROR %d/%d" % [_error.code(), _error.operation()]
	elif _state.phase() == BattleState.Phase.BATTLE_END:
		_status_label.text += " · 결과 %s" % BattleResult.Value.keys()[_state.battle_result()]
	var preview := _preview_text(status)
	_details_label.text = "편성 %s\n시너지 %s%s%s%s" % [_selection_text(), _synergy_text(), " · CTB " + preview if not preview.is_empty() else "", _damage_notice, _aim_detail_text(status)]
	if not status.is_ok() and _error.is_ok():
		_error = status


func _clear_piece_nodes() -> void:
	for holder: Node2D in _piece_nodes.values():
		holder.queue_free()
	_piece_nodes.clear()


func _cycle_player_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _selected_piece_indices.size() or _piece_definitions.is_empty():
		return
	_selected_piece_indices[slot_index] = (_selected_piece_indices[slot_index] + 1) % _piece_definitions.size()
	_restart()


func _restart() -> void:
	if _run_mode or not _content_error.is_ok() or _selected_piece_indices.is_empty():
		return
	_clear_piece_nodes()
	_clear_aim()
	_enemy_action_delay.reset()
	_turns = 0
	_damage_notice = ""
	_error = SimStatus.new()
	var deployment: Array[BattleDeploymentEntry] = _build_deployment(_error)
	if _error.is_ok():
		_state = BattleSetupBuilder.build(_catalog, _map_definition.numeric_id(), deployment, SEED_HI, SEED_LO, _error, _encounter_definition.numeric_id())
	if _error.is_ok():
		_resolve_content_transition()
		_advance_noninteractive_phases()
	_sync_view()

func start_run_battle(request: RunBattleRequest, catalog: ContentCatalog, status: SimStatus) -> bool:
	if not status.is_ok() or request == null or not request.is_initialized() or catalog == null or not catalog.is_initialized() or request.content_fingerprint_bytes() != catalog.fingerprint_bytes():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD)
		return false
	_clear_piece_nodes()
	_clear_aim()
	_enemy_action_delay.reset()
	_run_mode = true
	_run_request = request.copy()
	_run_outcome_emitted = false
	_turns = 0
	_error = status
	_content_error = ContentStatus.new()
	_catalog = catalog.copy()
	_map_definition = _catalog.map_by_numeric_id(request.map_numeric_id(), _content_error)
	_piece_definitions.clear()
	_enemy_definitions.clear()
	_selected_piece_indices.clear()
	for index: int in range(_catalog.piece_count()): _piece_definitions.append(_catalog.piece_at(index, _content_error))
	if not _content_error.is_ok():
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD, request.map_numeric_id(), _content_error.code())
		return false
	_state = RunBattleBridge.build_state(request, _catalog, status)
	if not status.is_ok() or _state == null or not _state.is_initialized(): return false
	_help_label.text = "기물 중심에서 멀리 당길수록 강하게 발사 · Esc: 조준 취소"
	_build_map_view()
	_resolve_content_transition()
	_advance_noninteractive_phases()
	_sync_view()
	return status.is_ok()

func leave_run_mode() -> void:
	_run_mode = false
	_run_request = RunBattleRequest.new()
	_run_outcome_emitted = false
	_help_label.text = "기물 중심에서 멀리 당길수록 강하게 발사 · 1/2/3: 기물 순환 · AI등급 F1/F2/F3 또는 7/8/9 · R: 재시작 · Esc: 취소"

func _run_enemy_grade(body_id: int, status: SimStatus) -> int:
	for index: int in range(_run_request.enemy_count()):
		var entry: RunBattleEnemyEntry = _run_request.enemy_at(index, status)
		if entry.expected_body_id() != body_id: continue
		var content_status := ContentStatus.new()
		var enemy: EnemyDefinition = _catalog.enemy_by_numeric_id(entry.enemy_numeric_id(), content_status)
		if not content_status.is_ok() or not AiGrade.is_known(enemy.ai_grade_id()):
			status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD, body_id, entry.enemy_numeric_id())
			return AiGrade.Value.COMMON
		return enemy.ai_grade_id()
	status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD, body_id, 0)
	return AiGrade.Value.COMMON

func _emit_run_outcome_if_ready() -> void:
	if not _run_mode or _run_outcome_emitted or _state == null or not _error.is_ok() or _state.phase() != BattleState.Phase.BATTLE_END: return
	var outcome: RunBattleOutcome = RunBattleBridge.outcome_from(_run_request, _state, _error)
	if not _error.is_ok() or not outcome.is_initialized(): return
	_run_outcome_emitted = true
	run_battle_finished.emit(outcome)
