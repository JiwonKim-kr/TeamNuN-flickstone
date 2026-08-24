class_name AiShotEvaluation
extends RefCounted

var _initialized := false
var _score := 0
var _enemy_damage := 0
var _enemy_destroyed := 0
var _ally_damage := 0
var _ally_destroyed := 0
var _kill_destroyed := 0
var _actor_survived := false

static func create(score: int, enemy_damage: int, enemy_destroyed: int, ally_damage: int, ally_destroyed: int, kill_destroyed: int, actor_survived: bool, status: SimStatus) -> AiShotEvaluation:
	var result := AiShotEvaluation.new()
	if not status.is_ok() or enemy_damage < 0 or enemy_destroyed < 0 or ally_damage < 0 or ally_destroyed < 0 or kill_destroyed < 0:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_SHOT_SUPPLY, enemy_damage, ally_damage)
		return result
	result._score = score; result._enemy_damage = enemy_damage; result._enemy_destroyed = enemy_destroyed
	result._ally_damage = ally_damage; result._ally_destroyed = ally_destroyed; result._kill_destroyed = kill_destroyed
	result._actor_survived = actor_survived; result._initialized = true
	return result

func is_initialized() -> bool: return _initialized
func score() -> int: return _score
func enemy_damage() -> int: return _enemy_damage
func enemy_destroyed() -> int: return _enemy_destroyed
func ally_damage() -> int: return _ally_damage
func ally_destroyed() -> int: return _ally_destroyed
func kill_destroyed() -> int: return _kill_destroyed
func actor_survived() -> bool: return _actor_survived
func is_safe() -> bool: return _initialized and _actor_survived and _ally_destroyed == 0
