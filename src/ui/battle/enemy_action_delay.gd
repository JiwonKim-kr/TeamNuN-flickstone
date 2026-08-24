class_name EnemyActionDelay
extends RefCounted
## Presentation-only delay before a deterministic enemy command is committed.

const DEFAULT_DELAY_MSEC := 600

var _delay_msec: int = DEFAULT_DELAY_MSEC
var _actor_body_id: int = 0
var _ready_at_msec: int = 0


func _init(delay_msec: int = DEFAULT_DELAY_MSEC) -> void:
	_delay_msec = maxi(0, delay_msec)


func is_ready(actor_body_id: int, now_msec: int) -> bool:
	if actor_body_id <= 0:
		reset()
		return false
	if _actor_body_id != actor_body_id:
		_actor_body_id = actor_body_id
		_ready_at_msec = maxi(0, now_msec) + _delay_msec
		return false
	return now_msec >= _ready_at_msec


func remaining_msec(actor_body_id: int, now_msec: int) -> int:
	if actor_body_id != _actor_body_id:
		return 0
	return maxi(0, _ready_at_msec - now_msec)


func consume() -> void:
	reset()


func reset() -> void:
	_actor_body_id = 0
	_ready_at_msec = 0


func scheduled_actor_body_id() -> int:
	return _actor_body_id
