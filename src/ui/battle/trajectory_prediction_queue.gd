class_name TrajectoryPredictionQueue
extends RefCounted
## Keeps only the latest aim command and starts prediction after pointer input settles.

const DEFAULT_DEBOUNCE_USEC := 50_000

var _debounce_usec: int = DEFAULT_DEBOUNCE_USEC
var _session: int = 0
var _generation: int = 0
var _ready_at_usec: int = 0
var _pending_command: LaunchCommand = null


func _init(debounce_usec: int = DEFAULT_DEBOUNCE_USEC) -> void:
	_debounce_usec = maxi(0, debounce_usec)


func submit(command: LaunchCommand, now_usec: int) -> int:
	_generation += 1
	_pending_command = null
	_ready_at_usec = 0
	if (
		command == null
		or not command.is_initialized()
		or not LaunchLimits.valid_launch_power_step(command.power_step())
	):
		return _generation
	_pending_command = command.copy()
	_ready_at_usec = maxi(0, now_usec) + _debounce_usec
	return _generation


func can_start(now_usec: int, worker_busy: bool, dragging: bool) -> bool:
	return (
		_pending_command != null
		and not worker_busy
		and dragging
		and now_usec >= _ready_at_usec
	)


func take_pending() -> LaunchCommand:
	if _pending_command == null:
		return null
	var result: LaunchCommand = _pending_command.copy()
	_pending_command = null
	_ready_at_usec = 0
	return result


func reset() -> void:
	_session += 1
	_generation += 1
	_pending_command = null
	_ready_at_usec = 0


func has_pending() -> bool:
	return _pending_command != null


func session() -> int:
	return _session


func generation() -> int:
	return _generation
