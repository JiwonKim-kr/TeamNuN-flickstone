class_name EnemyOverrideDefinition
extends RefCounted

const MAX_HP_BIT: int = 1 << 0
const ATTACK_BIT: int = 1 << 1
const SPEED_STAT_BIT: int = 1 << 2
const MASS_RAW_BIT: int = 1 << 3
const RADIUS_RAW_BIT: int = 1 << 4
const FRICTION_RAW_BIT: int = 1 << 5
const CRITICAL_BIT: int = 1 << 6
const ABILITY_REFS_BIT: int = 1 << 7
const KNOWN_MASK: int = (1 << 8) - 1

var _presence_mask: int = 0
var _max_hp: int = 0
var _attack: int = 0
var _speed_stat: int = 0
var _mass_raw: int = 0
var _radius_raw: int = 0
var _friction_multiplier_raw: int = 0
var _critical_basis_points: int = 0
var _ability_refs: Array[ContentIdRef] = []
var _initialized: bool = false


static func create(presence_mask: int, max_hp: int, attack: int, speed_stat: int, mass_raw: int, radius_raw: int, friction_multiplier_raw: int, critical_basis_points: int, ability_refs: Array[ContentIdRef], status: ContentStatus) -> EnemyOverrideDefinition:
	var result := EnemyOverrideDefinition.new()
	if not status.is_ok(): return result
	if presence_mask < 0 or (presence_mask & ~KNOWN_MASK) != 0:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENEMY_RESOLVE, ContentIds.DocumentKind.ENEMIES, 0, ContentStatus.FieldId.OVERRIDE); return result
	if (
		((presence_mask & MAX_HP_BIT) != 0 and not DamageLimits.valid_stat(max_hp))
		or ((presence_mask & ATTACK_BIT) != 0 and not DamageLimits.valid_stat(attack))
		or ((presence_mask & SPEED_STAT_BIT) != 0 and not BattleLimits.valid_base_speed(speed_stat))
		or ((presence_mask & MASS_RAW_BIT) != 0 and not SimLimits.is_mass_valid(mass_raw))
		or ((presence_mask & RADIUS_RAW_BIT) != 0 and not SimLimits.is_radius_valid(radius_raw))
		or ((presence_mask & FRICTION_RAW_BIT) != 0 and friction_multiplier_raw < 0)
		or ((presence_mask & CRITICAL_BIT) != 0 and not DamageLimits.valid_critical_basis_points(critical_basis_points))
		or ability_refs.size() > ContentLimits.ABILITY_REFS_MAX_COUNT
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENEMY_RESOLVE, ContentIds.DocumentKind.ENEMIES, 0, ContentStatus.FieldId.OVERRIDE); return result
	var previous_id: int = 0
	for ability_ref: ContentIdRef in ability_refs:
		if ability_ref == null or not ability_ref.is_initialized() or ability_ref.numeric_id() <= previous_id:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENEMY_RESOLVE, ContentIds.DocumentKind.ENEMIES, 0, ContentStatus.FieldId.ABILITY_REFS); return EnemyOverrideDefinition.new()
		result._ability_refs.append(ability_ref.copy()); previous_id = ability_ref.numeric_id()
	result._presence_mask = presence_mask
	result._max_hp = max_hp; result._attack = attack; result._speed_stat = speed_stat
	result._mass_raw = mass_raw; result._radius_raw = radius_raw; result._friction_multiplier_raw = friction_multiplier_raw
	result._critical_basis_points = critical_basis_points; result._initialized = true
	return result


func copy() -> EnemyOverrideDefinition:
	if not _initialized: return EnemyOverrideDefinition.new()
	var status := ContentStatus.new()
	return create(_presence_mask, _max_hp, _attack, _speed_stat, _mass_raw, _radius_raw, _friction_multiplier_raw, _critical_basis_points, _ability_refs, status)


func is_initialized() -> bool: return _initialized
func presence_mask() -> int: return _presence_mask
func has_value(bit: int) -> bool: return (_presence_mask & bit) != 0
func max_hp() -> int: return _max_hp
func attack() -> int: return _attack
func speed_stat() -> int: return _speed_stat
func mass_raw() -> int: return _mass_raw
func radius_raw() -> int: return _radius_raw
func friction_multiplier_raw() -> int: return _friction_multiplier_raw
func critical_basis_points() -> int: return _critical_basis_points
func ability_ref_count() -> int: return _ability_refs.size()
func ability_ref_at(index: int, status: ContentStatus) -> ContentIdRef:
	if index < 0 or index >= _ability_refs.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENEMIES, 0, ContentStatus.FieldId.ABILITY_REFS); return ContentIdRef.new()
	return _ability_refs[index].copy()
