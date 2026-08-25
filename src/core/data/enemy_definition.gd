class_name EnemyDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _base_piece_ref: ContentIdRef
var _ai_grade_id: int = AiGrade.Value.INVALID
var _override: EnemyOverrideDefinition
var _initialized: bool = false


static func create(id_ref: ContentIdRef, base_piece_ref: ContentIdRef, ai_grade_id: int, override_definition: EnemyOverrideDefinition, status: ContentStatus) -> EnemyDefinition:
	var result := EnemyDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or base_piece_ref == null or not base_piece_ref.is_initialized() or not AiGrade.is_known(ai_grade_id) or override_definition == null or not override_definition.is_initialized():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENEMY_RESOLVE, ContentIds.DocumentKind.ENEMIES)
		return result
	result._id_ref = id_ref.copy(); result._base_piece_ref = base_piece_ref.copy(); result._ai_grade_id = ai_grade_id; result._override = override_definition.copy(); result._initialized = true
	return result


func copy() -> EnemyDefinition:
	if not _initialized: return EnemyDefinition.new()
	var status := ContentStatus.new()
	return create(_id_ref, _base_piece_ref, _ai_grade_id, _override, status)


func resolved_level(catalog: ContentCatalog, status: ContentStatus) -> PieceLevelDefinition:
	if not status.is_ok(): return PieceLevelDefinition.new()
	if not _initialized or catalog == null or not catalog.is_initialized():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENEMY_RESOLVE, ContentIds.DocumentKind.ENEMIES, numeric_id()); return PieceLevelDefinition.new()
	var piece: PieceDefinition = catalog.piece_by_numeric_id(_base_piece_ref.numeric_id(), status)
	if not status.is_ok() or piece.string_id() != _base_piece_ref.string_id():
		if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.ENEMY_RESOLVE, ContentIds.DocumentKind.ENEMIES, numeric_id(), ContentStatus.FieldId.BASE_PIECE_REF)
		return PieceLevelDefinition.new()
	var base: PieceLevelDefinition = piece.level_definition(1, status)
	if not status.is_ok(): return PieceLevelDefinition.new()
	var refs: Array[ContentIdRef] = []
	if _override.has_value(EnemyOverrideDefinition.ABILITY_REFS_BIT):
		for index: int in range(_override.ability_ref_count()): refs.append(_override.ability_ref_at(index, status))
	else:
		for index: int in range(base.ability_ref_count()): refs.append(base.ability_ref_at(index, status))
	return PieceLevelDefinition.create(
		1,
		_override.max_hp() if _override.has_value(EnemyOverrideDefinition.MAX_HP_BIT) else base.max_hp(),
		_override.attack() if _override.has_value(EnemyOverrideDefinition.ATTACK_BIT) else base.attack(),
		_override.speed_stat() if _override.has_value(EnemyOverrideDefinition.SPEED_STAT_BIT) else base.speed_stat(),
		_override.mass_raw() if _override.has_value(EnemyOverrideDefinition.MASS_RAW_BIT) else base.mass_raw(),
		_override.radius_raw() if _override.has_value(EnemyOverrideDefinition.RADIUS_RAW_BIT) else base.radius_raw(),
		_override.friction_multiplier_raw() if _override.has_value(EnemyOverrideDefinition.FRICTION_RAW_BIT) else base.friction_multiplier_raw(),
		base.elasticity_multiplier_raw(),
		base.clean_hit_damage_multiplier_raw(),
		_override.critical_basis_points() if _override.has_value(EnemyOverrideDefinition.CRITICAL_BIT) else base.critical_basis_points(), refs, status)


func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return 0 if not _initialized else _id_ref.numeric_id()
func string_id() -> String: return "" if not _initialized else _id_ref.string_id()
func base_piece_ref() -> ContentIdRef: return ContentIdRef.new() if not _initialized else _base_piece_ref.copy()
func ai_grade_id() -> int: return _ai_grade_id
func override_definition() -> EnemyOverrideDefinition: return EnemyOverrideDefinition.new() if not _initialized else _override.copy()
