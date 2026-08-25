class_name PieceLevelDefinition
extends RefCounted

var _level: int = 0
var _max_hp: int = 0
var _attack: int = 0
var _speed_stat: int = 0
var _mass_raw: int = 0
var _radius_raw: int = 0
var _friction_multiplier_raw: int = 0
var _elasticity_multiplier_raw: int = FixMath.ONE_RAW
var _clean_hit_damage_multiplier_raw: int = FixMath.ONE_RAW
var _critical_basis_points: int = 0
var _ability_refs: Array[ContentIdRef] = []
var _initialized: bool = false


static func create(
		level: int,
		max_hp: int,
		attack: int,
		speed_stat: int,
		mass_raw: int,
		radius_raw: int,
		friction_multiplier_raw: int,
		elasticity_multiplier_raw: int,
		clean_hit_damage_multiplier_raw: int,
		critical_basis_points: int,
		ability_refs: Array[ContentIdRef],
		status: ContentStatus
) -> PieceLevelDefinition:
	var result := PieceLevelDefinition.new()
	if not status.is_ok():
		return result
	if (
		level < 1
		or level > ContentLimits.PIECE_LEVEL_MAX_COUNT
		or not DamageLimits.valid_stat(max_hp)
		or not DamageLimits.valid_stat(attack)
		or not BattleLimits.valid_base_speed(speed_stat)
		or not SimLimits.is_mass_valid(mass_raw)
		or not SimLimits.is_radius_valid(radius_raw)
		or friction_multiplier_raw < 0
		or elasticity_multiplier_raw < FixMath.ONE_RAW
		or elasticity_multiplier_raw > 4 * FixMath.ONE_RAW
		or clean_hit_damage_multiplier_raw < FixMath.ONE_RAW
		or clean_hit_damage_multiplier_raw > 4 * FixMath.ONE_RAW
		or not DamageLimits.valid_critical_basis_points(critical_basis_points)
		or ability_refs.size() > ContentLimits.ABILITY_REFS_MAX_COUNT
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD)
		return result
	var previous_id: int = 0
	for item: ContentIdRef in ability_refs:
		if item == null or not item.is_initialized() or item.numeric_id() <= previous_id:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD)
			return PieceLevelDefinition.new()
		previous_id = item.numeric_id()
		result._ability_refs.append(item.copy())
	result._level = level
	result._max_hp = max_hp
	result._attack = attack
	result._speed_stat = speed_stat
	result._mass_raw = mass_raw
	result._radius_raw = radius_raw
	result._friction_multiplier_raw = friction_multiplier_raw
	result._elasticity_multiplier_raw = elasticity_multiplier_raw
	result._clean_hit_damage_multiplier_raw = clean_hit_damage_multiplier_raw
	result._critical_basis_points = critical_basis_points
	result._initialized = true
	return result


func copy() -> PieceLevelDefinition:
	if not _initialized: return PieceLevelDefinition.new()
	var status := ContentStatus.new()
	return create(
		_level, _max_hp, _attack, _speed_stat, _mass_raw, _radius_raw,
		_friction_multiplier_raw, _elasticity_multiplier_raw, _clean_hit_damage_multiplier_raw, _critical_basis_points, _ability_refs, status
	)


func is_initialized() -> bool: return _initialized
func level() -> int: return _level
func max_hp() -> int: return _max_hp
func attack() -> int: return _attack
func speed_stat() -> int: return _speed_stat
func mass_raw() -> int: return _mass_raw
func radius_raw() -> int: return _radius_raw
func friction_multiplier_raw() -> int: return _friction_multiplier_raw
func elasticity_multiplier_raw() -> int: return _elasticity_multiplier_raw
func clean_hit_damage_multiplier_raw() -> int: return _clean_hit_damage_multiplier_raw
func critical_basis_points() -> int: return _critical_basis_points
func ability_ref_count() -> int: return _ability_refs.size()


func ability_ref_at(index: int, status: ContentStatus) -> ContentIdRef:
	if not status.is_ok(): return ContentIdRef.new()
	if index < 0 or index >= _ability_refs.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.PIECES, 0, ContentStatus.FieldId.ABILITY_REFS)
		return ContentIdRef.new()
	return _ability_refs[index].copy()
