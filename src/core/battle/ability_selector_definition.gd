class_name AbilitySelectorDefinition
extends RefCounted

enum Kind { INVALID = 0, OWNER = 1, SUBJECT = 2, OTHER = 3, INSTIGATOR = 4, ALL_ALLIES = 5, ALL_ENEMIES = 6, NEAREST_ALLY = 7, NEAREST_ENEMY = 8 }

var _kind_id: int = Kind.INVALID
var _relation_id: int = 0
var _limit: int = 0
var _initialized: bool = false

static func create(kind_id: int, relation_id: int, limit: int, status: ContentStatus) -> AbilitySelectorDefinition:
	var result := AbilitySelectorDefinition.new()
	if not status.is_ok(): return result
	if kind_id < Kind.OWNER or kind_id > Kind.NEAREST_ENEMY or relation_id != 0 or limit < 0 or limit > ContentLimits.SELECTOR_MAX_RESULTS:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.SELECTOR); return result
	result._kind_id = kind_id; result._relation_id = relation_id; result._limit = limit; result._initialized = true
	return result

func copy() -> AbilitySelectorDefinition:
	var status := ContentStatus.new(); return create(_kind_id, _relation_id, _limit, status) if _initialized else AbilitySelectorDefinition.new()
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func relation_id() -> int: return _relation_id
func limit() -> int: return _limit
