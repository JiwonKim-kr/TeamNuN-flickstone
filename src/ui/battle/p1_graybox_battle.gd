class_name P1GrayboxBattle
extends Node2D
## Playable P1-5 graybox adapter. Core state remains authoritative.

const PLAYER_TEXTURE := preload("res://assets/art/sprites/p1_graybox/PLACEHOLDER_player_piece.png")
const ENEMY_TEXTURE := preload("res://assets/art/sprites/p1_graybox/PLACEHOLDER_enemy_piece.png")
const AIM_TEXTURE := preload("res://assets/art/ui/p1_graybox/PLACEHOLDER_aim_marker.png")
const PIECE_SCALE := Vector2(4.0 / 3.0, 4.0 / 3.0)
const RESOLVE_STEPS_PER_FRAME := 12

@onready var _pieces: Node2D = $Battlefield/Pieces
@onready var _aim_line: Line2D = $Battlefield/AimLayer/AimLine
@onready var _trajectory_line: Line2D = $Battlefield/AimLayer/TrajectoryLine
@onready var _aim_marker: Sprite2D = $Battlefield/AimLayer/AimMarker
@onready var _status_label: Label = $Hud/Status
@onready var _help_label: Label = $Hud/Help
@onready var _input: AimInputAdapter = $AimInputAdapter

var _state: BattleState
var _piece_nodes: Dictionary = {}
var _trajectory := TrajectoryLineAdapter.new()
var _turns: int = 0
var _error: SimStatus = SimStatus.new()


func _ready() -> void:
	_state = P1GrayboxFixture.create(0x12345678, 0x2468ACE0, false, _error)
	_input.configure(_provide_state, _screen_to_world)
	_input.prediction_requested.connect(_on_prediction_requested)
	_input.launch_requested.connect(_on_launch_requested)
	_input.aim_cancelled.connect(_clear_aim)
	_help_label.text = "아군 턴: 현재 P 기물을 드래그해 발사 · Esc: 조준 취소 · R: 재시작"
	_advance_noninteractive_phases()
	_sync_view()


func _process(_delta: float) -> void:
	if not _error.is_ok() or _state == null:
		_sync_view()
		return
	if _state.phase() == BattleState.Phase.RESOLVE:
		for _step: int in range(RESOLVE_STEPS_PER_FRAME):
			if _state.phase() != BattleState.Phase.RESOLVE:
				break
			_state.advance_resolve(_error)
			if not _error.is_ok():
				break
		_advance_noninteractive_phases()
	_sync_view()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_input.cancel_aim()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()
		return
	if not event is InputEventMouse:
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
	return $Battlefield.to_local(pointer_screen)


func _pointer_hits_actor(pointer_screen: Vector2) -> bool:
	if _state == null or _state.phase() != BattleState.Phase.AIM:
		return false
	var status := SimStatus.new()
	var world: SimWorld = _state.world_copy(status)
	var actor: SimBody = world.body_by_id(_state.current_actor_body_id(), status)
	if not status.is_ok():
		return false
	var center := Vector2(float(actor.position().x_raw()), float(actor.position().y_raw())) / float(FixMath.SCALE)
	return _screen_to_world(pointer_screen).distance_to(center) <= float(P1GrayboxFixture.RADIUS)


func _advance_noninteractive_phases() -> void:
	while _error.is_ok() and _state.phase() != BattleState.Phase.AIM and _state.phase() != BattleState.Phase.RESOLVE and _state.phase() != BattleState.Phase.BATTLE_END:
		match _state.phase():
			BattleState.Phase.BATTLE_START: _state.complete_battle_start(_error)
			BattleState.Phase.TURN_START: _state.complete_turn_start(_error)
			BattleState.Phase.TURN_END: _state.complete_turn_end(_error)
			BattleState.Phase.CHECK: _state.resolve_check(_error)
			_: _error.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, _state.phase(), 0)
	if _error.is_ok() and _state.phase() == BattleState.Phase.AIM:
		var participant: BattleParticipant = _state.participant_by_body_id(_state.current_actor_body_id(), _error)
		if _error.is_ok() and participant.faction() == BattleParticipant.Faction.ENEMY:
			var command: LaunchCommand = P1DeterministicShotSupplier.command_for(_state, _error)
			if _error.is_ok():
				LaunchVelocitySolver.commit(_state, command, _error)
				_turns += 1


func _on_prediction_requested(command: LaunchCommand) -> void:
	var status := SimStatus.new()
	var prediction: TrajectoryPrediction = TrajectoryPredictor.predict(_state, command, status)
	_trajectory.update_from_prediction(prediction, status)
	if not status.is_ok():
		_error = status
		return
	_trajectory_line.points = _trajectory.positions()
	var world: SimWorld = _state.world_copy(status)
	var actor: SimBody = world.body_by_id(_state.current_actor_body_id(), status)
	var actor_position := Vector2(float(actor.position().x_raw()), float(actor.position().y_raw())) / float(FixMath.SCALE)
	var velocity: FixVec2 = LaunchVelocitySolver.solve(actor, command, status)
	var direction := Vector2(float(velocity.x_raw()), float(velocity.y_raw())).normalized()
	_aim_line.points = PackedVector2Array([actor_position, actor_position + direction * 120.0])
	_aim_marker.position = actor_position + direction * 132.0
	_aim_marker.rotation = direction.angle()
	_aim_marker.visible = status.is_ok()


func _on_launch_requested(command: LaunchCommand) -> void:
	_clear_aim()
	LaunchVelocitySolver.commit(_state, command, _error)
	if _error.is_ok():
		_turns += 1


func _clear_aim() -> void:
	_trajectory.clear()
	_trajectory_line.clear_points()
	_aim_line.clear_points()
	_aim_marker.visible = false


func _sync_view() -> void:
	if _state == null:
		return
	var status := SimStatus.new()
	var world: SimWorld = _state.world_copy(status)
	var alive: Dictionary = {}
	for index: int in range(world.body_count()):
		var body: SimBody = world.body_at(index, status)
		var participant: BattleParticipant = _state.participant_by_body_id(body.id(), status)
		alive[body.id()] = true
		var sprite: Sprite2D = _piece_nodes.get(body.id()) as Sprite2D
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.texture = PLAYER_TEXTURE if participant.faction() == BattleParticipant.Faction.PLAYER else ENEMY_TEXTURE
			sprite.scale = PIECE_SCALE
			_pieces.add_child(sprite)
			_piece_nodes[body.id()] = sprite
		sprite.position = Vector2(float(body.position().x_raw()), float(body.position().y_raw())) / float(FixMath.SCALE)
		sprite.modulate = Color.WHITE if body.id() != _state.current_actor_body_id() else Color(1.0, 0.92, 0.35)
	for body_id: Variant in _piece_nodes.keys():
		if not alive.has(body_id):
			(_piece_nodes[body_id] as Sprite2D).queue_free()
			_piece_nodes.erase(body_id)
	var phase_name: String = BattleState.Phase.keys()[_state.phase()]
	_status_label.text = "P1-5 회색상자 · 턴 %d · %s · 현재 actor #%d · 생존 %d/6" % [_turns, phase_name, _state.current_actor_body_id(), world.body_count()]
	if not _error.is_ok():
		_status_label.text += " · ERROR %d/%d" % [_error.code(), _error.operation()]
	elif _state.phase() == BattleState.Phase.BATTLE_END:
		_status_label.text += " · 결과 %s" % BattleResult.Value.keys()[_state.battle_result()]


func _restart() -> void:
	for sprite: Sprite2D in _piece_nodes.values():
		sprite.queue_free()
	_piece_nodes.clear()
	_clear_aim()
	_turns = 0
	_error = SimStatus.new()
	_state = P1GrayboxFixture.create(0x12345678, 0x2468ACE0, false, _error)
	_advance_noninteractive_phases()
	_sync_view()
