class_name ContentStatus
extends RefCounted
## Release-safe, first-error-wins diagnostics for authored content loading.

enum Code {
	OK = 0,
	IO_ERROR = 1,
	FILE_TOO_LARGE = 2,
	INVALID_UTF8 = 3,
	JSON_SYNTAX = 4,
	JSON_LIMIT = 5,
	DUPLICATE_KEY = 6,
	NON_INTEGER_NUMBER = 7,
	INTEGER_OVERFLOW = 8,
	UNSUPPORTED_SCHEMA = 9,
	UNKNOWN_KEY = 10,
	MISSING_KEY = 11,
	INVALID_TYPE = 12,
	INVALID_ID = 13,
	DUPLICATE_ID = 14,
	MISSING_REFERENCE = 15,
	INVALID_DOMAIN = 16,
	CATALOG_LIMIT = 17,
	FINGERPRINT_ERROR = 18,
	CATALOG_UNAVAILABLE = 19,
}

enum Operation {
	NONE = 0,
	FILE_ENUMERATE = 1,
	FILE_READ = 2,
	JSON_PARSE = 3,
	DOCUMENT_VALIDATE = 4,
	ID_REGISTER = 5,
	REFERENCE_RESOLVE = 6,
	CATALOG_BUILD = 7,
	CANONICAL_ENCODE = 8,
	SHA256 = 9,
	LOOKUP = 10,
	DATA_DB_LOAD = 11,
	MAP_VALIDATE = 12,
	ENEMY_RESOLVE = 13,
	ACT_VALIDATE = 14,
	ENCOUNTER_VALIDATE = 15,
}

enum FieldId {
	NONE = 0,
	SCHEMA_VERSION = 1,
	DOCUMENTS = 2,
	KIND_ID = 3,
	FILE_NAME = 4,
	NAMESPACES = 5,
	NAMESPACE_ID = 6,
	ENTRIES = 7,
	NUMERIC_ID = 8,
	ID = 9,
	STATE_ID = 10,
	RECORDS = 11,
	TRIGGER_ID = 12,
	FLAGS = 13,
	HAS_TURN = 14,
	DESTRUCTIBLE = 15,
	TRANSFORMABLE = 16,
	COUNTS_FOR_VICTORY = 17,
	IS_TOKEN = 18,
	LEVELS = 19,
	LEVEL = 20,
	MAX_HP = 21,
	ATTACK = 22,
	SPEED_STAT = 23,
	MASS_RAW = 24,
	RADIUS_RAW = 25,
	FRICTION_MULTIPLIER_RAW = 26,
	CRITICAL_BASIS_POINTS = 27,
	ABILITY_REFS = 28,
	CONDITIONS = 29,
	CONDITION_KIND_ID = 30,
	RELATION_ID = 31,
	EFFECTS = 32,
	EFFECT_KIND_ID = 33,
	SELECTOR = 34,
	SELECTOR_KIND_ID = 35,
	LIMIT = 36,
	VALUE_A = 37,
	VALUE_B = 38,
	OPERATION_ID = 39,
	TAG_REFS = 40,
	STACK_POLICY_ID = 41,
	MAX_STACKS = 42,
	DURATION_KIND_ID = 43,
	DEFAULT_DURATION = 44,
	MAX_DURATION = 45,
	REFRESH_POLICY_ID = 46,
	MERGE_SOURCES = 47,
	MODIFIERS = 48,
	MODIFIER_KIND_ID = 49,
	VALUE_MODE_ID = 50,
	TAG_REF = 51,
	TAG_KIND_ID = 52,
	SCOPE_ID = 53,
	COUNT_CAP = 54,
	TIERS = 55,
	MIN_COUNT = 56,
	SPAWNABLE = 57,
	SPAWN_FACTION_MODE_ID = 58,
	EXPIRE_KIND_ID = 59,
	EXPIRE_VALUE = 60,
	ATTACH_ANCHOR_MODE_ID = 61,
	ATTACH_ANCHOR_OFFSET_X_RAW = 62,
	ATTACH_ANCHOR_OFFSET_Y_RAW = 63,
	SPAWN_PAYLOAD = 64,
	TRANSFORM_PAYLOAD = 65,
	ATTACH_PAYLOAD = 66,
	PIECE_REF = 67,
	OFFSET_X_RAW = 68,
	OFFSET_Y_RAW = 69,
	SPEED_RAW = 70,
	DIRECTION_MODE_ID = 71,
	OWNER_ROLE_ID = 72,
	ATTACH_DISTANCE_RAW = 73,
	INERTIA_BASIS_POINTS = 74,
	DURATION_TURNS = 75,
	ZONE_PAYLOAD = 76,
	BOUNDARY_TYPE_ID = 77,
	BOUNDARY_VERTICES = 78,
	DEPLOY_COUNT = 79,
	PLAYER_SLOTS = 80,
	ENEMY_SLOTS = 81,
	ZONES = 82,
	LOCAL_ID = 83,
	ACCELERATION_X_RAW = 84,
	ACCELERATION_Y_RAW = 85,
	VERTICES = 86,
	OBSTACLES = 87,
	BASE_PIECE_REF = 88,
	OVERRIDE = 89,
	AI_GRADE_ID = 90,
	IS_DEVELOPMENT = 91,
	FLOORS = 92,
	FLOOR_INDEX = 93,
	SLOTS = 94,
	SLOT_INDEX = 95,
	OPTIONS = 96,
	NODE_TYPE_ID = 97,
	WEIGHT = 98,
	CONTENT_REFS = 99,
	MAP_REF = 100,
	ENEMY_REFS = 101,
	REWARD_PROFILE_NUMERIC_ID = 102,
}

var _code: int = Code.OK
var _operation: int = Operation.NONE
var _document_kind_id: int = 0
var _record_numeric_id: int = 0
var _field_id: int = FieldId.NONE
var _line: int = 0
var _column: int = 0
var _byte_offset: int = 0


func is_ok() -> bool: return _code == Code.OK
func code() -> int: return _code
func operation() -> int: return _operation
func document_kind_id() -> int: return _document_kind_id
func record_numeric_id() -> int: return _record_numeric_id
func field_id() -> int: return _field_id
func line() -> int: return _line
func column() -> int: return _column
func byte_offset() -> int: return _byte_offset


func set_context(
		document_kind_id: int,
		record_numeric_id: int = 0,
		field_id: int = FieldId.NONE
) -> void:
	if not is_ok():
		return
	_document_kind_id = document_kind_id
	_record_numeric_id = record_numeric_id
	_field_id = field_id


func fail(
		p_code: int,
		p_operation: int,
		document_kind_id: int = -1,
		record_numeric_id: int = -1,
		field_id: int = -1,
		line: int = 0,
		column: int = 0,
		byte_offset: int = 0
) -> void:
	if not is_ok():
		return
	_code = p_code
	_operation = p_operation
	if document_kind_id >= 0: _document_kind_id = document_kind_id
	if record_numeric_id >= 0: _record_numeric_id = record_numeric_id
	if field_id >= 0: _field_id = field_id
	_line = line
	_column = column
	_byte_offset = byte_offset


func copy() -> ContentStatus:
	var result := ContentStatus.new()
	result._code = _code
	result._operation = _operation
	result._document_kind_id = _document_kind_id
	result._record_numeric_id = _record_numeric_id
	result._field_id = _field_id
	result._line = _line
	result._column = _column
	result._byte_offset = _byte_offset
	return result
