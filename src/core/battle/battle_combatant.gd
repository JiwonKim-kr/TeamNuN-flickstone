class_name BattleCombatant
extends RefCounted

var _body_id: int = 0
var _faction: int = BattleParticipant.Faction.INVALID
var _current_hp: int = 0
var _max_hp: int = 0
var _attack: int = 0
var _critical_basis_points: int = 0
var _initialized: bool = false


static func _build(
		body_id: int,
		faction: int,
		current_hp: int,
		max_hp: int,
		attack: int,
		critical_basis_points: int
) -> BattleCombatant:
	var result := BattleCombatant.new()
	result._body_id = body_id
	result._faction = faction
	result._current_hp = current_hp
	result._max_hp = max_hp
	result._attack = attack
	result._critical_basis_points = critical_basis_points
	result._initialized = true
	return result


static func _create_checked(
		body_id: int,
		allow_unassigned: bool,
		faction: int,
		current_hp: int,
		max_hp: int,
		attack: int,
		critical_basis_points: int,
		status: SimStatus
) -> BattleCombatant:
	if not status.is_ok():
		return BattleCombatant.new()
	if (
		not UInt32Math.is_u32(body_id)
		or (body_id == 0 and not allow_unassigned)
		or (
			faction != BattleParticipant.Faction.PLAYER
			and faction != BattleParticipant.Faction.ENEMY
			and faction != BattleParticipant.Faction.NEUTRAL
		)
		or not DamageLimits.valid_stat(max_hp)
		or not DamageLimits.valid_stat(attack)
		or current_hp < 0
		or current_hp > max_hp
		or not DamageLimits.valid_critical_basis_points(critical_basis_points)
	):
		status.fail(
			SimStatus.Code.INVALID_COMBATANT,
			SimStatus.Operation.COMBATANT_CREATE,
			body_id,
			current_hp
		)
		return BattleCombatant.new()
	return _build(
		body_id,
		faction,
		current_hp,
		max_hp,
		attack,
		critical_basis_points
	)


static func create(
		body_id: int,
		faction: int,
		max_hp: int,
		attack: int,
		critical_basis_points: int,
		status: SimStatus
) -> BattleCombatant:
	return _create_checked(
		body_id,
		false,
		faction,
		max_hp,
		max_hp,
		attack,
		critical_basis_points,
		status
	)


static func create_unassigned(
		faction: int,
		max_hp: int,
		attack: int,
		critical_basis_points: int,
		status: SimStatus
) -> BattleCombatant:
	return _create_checked(
		0,
		true,
		faction,
		max_hp,
		max_hp,
		attack,
		critical_basis_points,
		status
	)


static func restore(
		body_id: int,
		faction: int,
		current_hp: int,
		max_hp: int,
		attack: int,
		critical_basis_points: int,
		status: SimStatus
) -> BattleCombatant:
	return _create_checked(
		body_id,
		false,
		faction,
		current_hp,
		max_hp,
		attack,
		critical_basis_points,
		status
	)


func assigned_copy(body_id: int, status: SimStatus) -> BattleCombatant:
	if not _initialized or _body_id != 0:
		status.fail(
			SimStatus.Code.INVALID_COMBATANT,
			SimStatus.Operation.COMBATANT_CREATE,
			_body_id,
			body_id
		)
		return BattleCombatant.new()
	return _create_checked(
		body_id,
		false,
		_faction,
		_current_hp,
		_max_hp,
		_attack,
		_critical_basis_points,
		status
	)


func with_current_hp(value: int, status: SimStatus) -> BattleCombatant:
	return _create_checked(
		_body_id,
		false,
		_faction,
		value,
		_max_hp,
		_attack,
		_critical_basis_points,
		status
	)

func with_base_stats(attack: int, critical_basis_points: int, status: SimStatus) -> BattleCombatant:
	return _create_checked(_body_id, false, _faction, _current_hp, _max_hp, attack, critical_basis_points, status)


func copy() -> BattleCombatant:
	if not _initialized:
		return BattleCombatant.new()
	return _build(
		_body_id,
		_faction,
		_current_hp,
		_max_hp,
		_attack,
		_critical_basis_points
	)


func is_initialized() -> bool: return _initialized
func body_id() -> int: return _body_id
func faction() -> int: return _faction
func current_hp() -> int: return _current_hp
func max_hp() -> int: return _max_hp
func attack() -> int: return _attack
func critical_basis_points() -> int: return _critical_basis_points
