class_name DamageContext
extends RefCounted

var _attacker_body_id: int = 0
var _victim_body_id: int = 0
var _attacker_attack: int = 0
var _victim_current_hp: int = 0
var _attacker_mass_raw: int = 0
var _victim_mass_raw: int = 0
var _impact_speed_raw: int = 0
var _same_non_neutral_faction: bool = false
var _critical_applied: bool = false
var _outgoing_ratio_bonus_raw: int = 0
var _incoming_ratio_reduction_raw: int = 0
var _fixed_increase: int = 0
var _fixed_reduction: int = 0
var _initialized: bool = false


static func create(
		attacker_body_id: int,
		victim_body_id: int,
		attacker_attack: int,
		victim_current_hp: int,
		attacker_mass_raw: int,
		victim_mass_raw: int,
		impact_speed_raw: int,
		same_non_neutral_faction: bool,
		critical_applied: bool,
		outgoing_ratio_bonus_raw: int,
		incoming_ratio_reduction_raw: int,
		fixed_increase: int,
		fixed_reduction: int,
		status: SimStatus
) -> DamageContext:
	var result := DamageContext.new()
	if not status.is_ok():
		return result
	if (
		attacker_body_id == 0
		or victim_body_id == 0
		or attacker_body_id == victim_body_id
		or not UInt32Math.is_u32(attacker_body_id)
		or not UInt32Math.is_u32(victim_body_id)
		or not DamageLimits.valid_stat(attacker_attack)
		or victim_current_hp <= 0
		or victim_current_hp > DamageLimits.STAT_MAX
		or not SimLimits.is_mass_valid(attacker_mass_raw)
		or not SimLimits.is_mass_valid(victim_mass_raw)
		or impact_speed_raw < 0
		or impact_speed_raw > DamageLimits.MAX_APPROACH_SPEED_RAW
		or outgoing_ratio_bonus_raw < 0
		or incoming_ratio_reduction_raw < 0
		or incoming_ratio_reduction_raw > FixMath.ONE_RAW
		or fixed_increase < 0
		or fixed_increase > DamageLimits.STAT_MAX
		or fixed_reduction < 0
		or fixed_reduction > DamageLimits.STAT_MAX
	):
		status.fail(
			SimStatus.Code.INVALID_DAMAGE_CONTEXT,
			SimStatus.Operation.DAMAGE_CONTEXT_CREATE,
			attacker_body_id,
			victim_body_id
		)
		return result
	result._attacker_body_id = attacker_body_id
	result._victim_body_id = victim_body_id
	result._attacker_attack = attacker_attack
	result._victim_current_hp = victim_current_hp
	result._attacker_mass_raw = attacker_mass_raw
	result._victim_mass_raw = victim_mass_raw
	result._impact_speed_raw = impact_speed_raw
	result._same_non_neutral_faction = same_non_neutral_faction
	result._critical_applied = critical_applied
	result._outgoing_ratio_bonus_raw = outgoing_ratio_bonus_raw
	result._incoming_ratio_reduction_raw = incoming_ratio_reduction_raw
	result._fixed_increase = fixed_increase
	result._fixed_reduction = fixed_reduction
	result._initialized = true
	return result


func is_initialized() -> bool: return _initialized
func attacker_body_id() -> int: return _attacker_body_id
func victim_body_id() -> int: return _victim_body_id
func attacker_attack() -> int: return _attacker_attack
func victim_current_hp() -> int: return _victim_current_hp
func attacker_mass_raw() -> int: return _attacker_mass_raw
func victim_mass_raw() -> int: return _victim_mass_raw
func impact_speed_raw() -> int: return _impact_speed_raw
func same_non_neutral_faction() -> bool: return _same_non_neutral_faction
func critical_applied() -> bool: return _critical_applied
func outgoing_ratio_bonus_raw() -> int: return _outgoing_ratio_bonus_raw
func incoming_ratio_reduction_raw() -> int: return _incoming_ratio_reduction_raw
func fixed_increase() -> int: return _fixed_increase
func fixed_reduction() -> int: return _fixed_reduction
