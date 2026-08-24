class_name AimInputAdapter
extends Node
## Godot pointer bridge. It observes battle state and emits immutable commands.

signal prediction_requested(command: LaunchCommand)
signal launch_requested(command: LaunchCommand)
signal aim_cancelled

var _state_provider: Callable
var _screen_to_world: Callable
var _dragging: bool = false
var _actor_center: FixVec2 = FixVec2.zero()
var _last_command: LaunchCommand = null
var _last_status: SimStatus = SimStatus.new()


func configure(state_provider: Callable, screen_to_world: Callable) -> void:
	_state_provider = state_provider
	_screen_to_world = screen_to_world
	clear()


func _state() -> BattleState:
	if not _state_provider.is_valid():
		return null
	var value: Variant = _state_provider.call()
	return value as BattleState


func _can_aim(state: BattleState) -> bool:
	if state == null or not state.is_initialized() or state.phase() != BattleState.Phase.AIM:
		return false
	var status := SimStatus.new()
	var participant: BattleParticipant = state.participant_by_body_id(state.current_actor_body_id(), status)
	return status.is_ok() and participant.faction() == BattleParticipant.Faction.PLAYER and participant.controllable()


func _world_pointer(pointer_screen: Vector2, status: SimStatus) -> FixVec2:
	if not is_finite(pointer_screen.x) or not is_finite(pointer_screen.y) or not _screen_to_world.is_valid():
		status.fail(SimStatus.Code.INVALID_AIM_INPUT, SimStatus.Operation.AIM_QUANTIZE, 0, 0)
		return FixVec2.zero()
	var value: Variant = _screen_to_world.call(pointer_screen)
	if not value is Vector2:
		status.fail(SimStatus.Code.INVALID_AIM_INPUT, SimStatus.Operation.AIM_QUANTIZE, 0, 0)
		return FixVec2.zero()
	var pointer: Vector2 = value
	if not is_finite(pointer.x) or not is_finite(pointer.y):
		status.fail(SimStatus.Code.INVALID_AIM_INPUT, SimStatus.Operation.AIM_QUANTIZE, 0, 0)
		return FixVec2.zero()
	var x_scaled: float = pointer.x * float(FixMath.SCALE)
	var y_scaled: float = pointer.y * float(FixMath.SCALE)
	var x_raw: int = floori(x_scaled + 0.5) if x_scaled >= 0.0 else ceili(x_scaled - 0.5)
	var y_raw: int = floori(y_scaled + 0.5) if y_scaled >= 0.0 else ceili(y_scaled - 0.5)
	var fixed := FixVec2.from_raw(x_raw, y_raw)
	if not SimLimits.is_position_valid(fixed):
		status.fail(SimStatus.Code.INVALID_AIM_INPUT, SimStatus.Operation.AIM_QUANTIZE, x_raw, y_raw)
		return FixVec2.zero()
	return fixed


func begin_aim(pointer_screen: Vector2) -> void:
	clear()
	var state: BattleState = _state()
	if not _can_aim(state):
		return
	var status := SimStatus.new()
	var world: SimWorld = state.world_copy(status)
	var actor: SimBody = world.body_by_id(state.current_actor_body_id(), status)
	var pointer: FixVec2 = _world_pointer(pointer_screen, status)
	if not status.is_ok():
		_last_status = status
		return
	_actor_center = actor.position()
	_dragging = true
	_update_command(pointer)


func update_aim(pointer_screen: Vector2) -> void:
	if not _dragging:
		return
	var state: BattleState = _state()
	if not _can_aim(state):
		clear()
		return
	var status := SimStatus.new()
	var pointer: FixVec2 = _world_pointer(pointer_screen, status)
	if not status.is_ok():
		_last_status = status
		return
	_update_command(pointer)


func _update_command(pointer_world: FixVec2) -> void:
	var status := SimStatus.new()
	var command: LaunchCommand = AimQuantizer.quantize(_actor_center, pointer_world, status)
	_last_status = status
	if not status.is_ok():
		return
	if _last_command == null or not _last_command.is_equal(command):
		_last_command = command.copy()
		prediction_requested.emit(_last_command.copy())


func release_aim(pointer_screen: Vector2) -> void:
	if not _dragging:
		return
	update_aim(pointer_screen)
	if not _dragging:
		return
	var command: LaunchCommand = null if _last_command == null else _last_command.copy()
	clear()
	if command != null and LaunchLimits.valid_launch_power_step(command.power_step()):
		launch_requested.emit(command)


func cancel_aim() -> void:
	if not _dragging:
		return
	clear()
	aim_cancelled.emit()


func clear() -> void:
	_dragging = false
	_actor_center = FixVec2.zero()
	_last_command = null


func is_dragging() -> bool: return _dragging
func actor_center() -> FixVec2: return _actor_center.copy()
func last_status() -> SimStatus: return _last_status.copy()
