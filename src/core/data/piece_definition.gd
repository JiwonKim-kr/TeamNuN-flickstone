class_name PieceDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _has_turn: bool = false
var _destructible: bool = false
var _transformable: bool = false
var _counts_for_victory: bool = false
var _is_token: bool = false
var _levels: Array[PieceLevelDefinition] = []
var _initialized: bool = false


static func create(
		id_ref: ContentIdRef,
		has_turn: bool,
		destructible: bool,
		transformable: bool,
		counts_for_victory: bool,
		is_token: bool,
		levels: Array[PieceLevelDefinition],
		status: ContentStatus
) -> PieceDefinition:
	var result := PieceDefinition.new()
	if not status.is_ok():
		return result
	if (
		id_ref == null
		or not id_ref.is_initialized()
		or levels.is_empty()
		or levels.size() > ContentLimits.PIECE_LEVEL_MAX_COUNT
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD)
		return result
	for index: int in range(levels.size()):
		var item: PieceLevelDefinition = levels[index]
		if item == null or not item.is_initialized() or item.level() != index + 1:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.PIECES, id_ref.numeric_id(), ContentStatus.FieldId.LEVELS)
			return PieceDefinition.new()
		result._levels.append(item.copy())
	result._id_ref = id_ref.copy()
	result._has_turn = has_turn
	result._destructible = destructible
	result._transformable = transformable
	result._counts_for_victory = counts_for_victory
	result._is_token = is_token
	result._initialized = true
	return result


func copy() -> PieceDefinition:
	if not _initialized: return PieceDefinition.new()
	var status := ContentStatus.new()
	return create(
		_id_ref, _has_turn, _destructible, _transformable,
		_counts_for_victory, _is_token, _levels, status
	)


func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return 0 if not _initialized else _id_ref.numeric_id()
func string_id() -> String: return "" if not _initialized else _id_ref.string_id()
func id_ref() -> ContentIdRef: return ContentIdRef.new() if not _initialized else _id_ref.copy()
func has_turn() -> bool: return _has_turn
func destructible() -> bool: return _destructible
func transformable() -> bool: return _transformable
func counts_for_victory() -> bool: return _counts_for_victory
func is_token() -> bool: return _is_token
func level_count() -> int: return _levels.size()


func level_at(index: int, status: ContentStatus) -> PieceLevelDefinition:
	if not status.is_ok(): return PieceLevelDefinition.new()
	if index < 0 or index >= _levels.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.PIECES, numeric_id(), ContentStatus.FieldId.LEVELS)
		return PieceLevelDefinition.new()
	return _levels[index].copy()


func level_definition(level_value: int, status: ContentStatus) -> PieceLevelDefinition:
	if level_value < 1 or level_value > _levels.size():
		if status.is_ok(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.PIECES, numeric_id(), ContentStatus.FieldId.LEVEL)
		return PieceLevelDefinition.new()
	return level_at(level_value - 1, status)
