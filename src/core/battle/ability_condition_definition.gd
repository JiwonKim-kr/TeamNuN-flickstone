class_name AbilityConditionDefinition
extends RefCounted

enum Kind { INVALID = 0, ALWAYS = 1, RELATION_EXISTS = 2, RELATION_ALIVE = 3, RELATION_IS_ALLY = 4, RELATION_IS_ENEMY = 5, HP_AT_MOST_BASIS_POINTS = 6, HP_AT_LEAST_BASIS_POINTS = 7 }
enum Relation { INVALID = 0, OWNER = 1, SUBJECT = 2, OTHER = 3, INSTIGATOR = 4 }

var _kind_id: int = Kind.INVALID
var _relation_id: int = Relation.INVALID
var _value_a: int = 0
var _value_b: int = 0
var _initialized: bool = false

static func create(kind_id: int, relation_id: int, value_a: int, value_b: int, status: ContentStatus) -> AbilityConditionDefinition:
	var result := AbilityConditionDefinition.new()
	if not status.is_ok(): return result
	if kind_id < Kind.ALWAYS or kind_id > Kind.HP_AT_LEAST_BASIS_POINTS:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.CONDITION_KIND_ID); return result
	if kind_id == Kind.ALWAYS:
		if relation_id != Relation.INVALID or value_a != 0 or value_b != 0:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.CONDITIONS); return result
	elif relation_id < Relation.OWNER or relation_id > Relation.INSTIGATOR:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.RELATION_ID); return result
	if (kind_id == Kind.HP_AT_MOST_BASIS_POINTS or kind_id == Kind.HP_AT_LEAST_BASIS_POINTS) and (value_a < 0 or value_a > 10000 or value_b != 0):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.CONDITIONS); return result
	result._kind_id = kind_id; result._relation_id = relation_id; result._value_a = value_a; result._value_b = value_b; result._initialized = true
	return result

func copy() -> AbilityConditionDefinition:
	var status := ContentStatus.new(); return create(_kind_id, _relation_id, _value_a, _value_b, status) if _initialized else AbilityConditionDefinition.new()
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func relation_id() -> int: return _relation_id
func value_a() -> int: return _value_a
func value_b() -> int: return _value_b
