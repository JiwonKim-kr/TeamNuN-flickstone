class_name DamageResult
extends RefCounted

var _attacker_body_id: int = 0
var _victim_body_id: int = 0
var _weight_ratio_raw: int = 0
var _resolved_damage: int = 0
var _applied_damage: int = 0
var _lethal: bool = false
var _initialized: bool = false


static func create(
		attacker_body_id: int,
		victim_body_id: int,
		weight_ratio_raw: int,
		resolved_damage: int,
		applied_damage: int,
		lethal: bool
) -> DamageResult:
	var result := DamageResult.new()
	result._attacker_body_id = attacker_body_id
	result._victim_body_id = victim_body_id
	result._weight_ratio_raw = weight_ratio_raw
	result._resolved_damage = resolved_damage
	result._applied_damage = applied_damage
	result._lethal = lethal
	result._initialized = true
	return result


func is_initialized() -> bool: return _initialized
func attacker_body_id() -> int: return _attacker_body_id
func victim_body_id() -> int: return _victim_body_id
func weight_ratio_raw() -> int: return _weight_ratio_raw
func resolved_damage() -> int: return _resolved_damage
func applied_damage() -> int: return _applied_damage
func is_lethal() -> bool: return _lethal
func has_damage() -> bool: return _applied_damage > 0
