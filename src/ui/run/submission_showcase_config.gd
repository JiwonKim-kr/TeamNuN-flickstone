class_name SubmissionShowcaseConfig
extends RefCounted
## Strict, UI-only configuration for the submission battle entry point.

const EXPECTED_KEYS := ["encounter_ref", "map_ref", "piece_refs", "seed", "version"]
const REF_KEYS := ["id", "numeric_id"]
const EXPECTED_VERSION := 1
const EXPECTED_PIECE_COUNT := 3

var _map_numeric_id: int = 0
var _encounter_numeric_id: int = 0
var _piece_numeric_ids: Array[int] = []
var _seed_hi: int = 0
var _seed_lo: int = 0


static func load_file(path: String, catalog: ContentCatalog, status: ContentStatus) -> SubmissionShowcaseConfig:
	if not status.is_ok() or catalog == null or not catalog.is_initialized():
		if status.is_ok(): status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return SubmissionShowcaseConfig.new()
	if not FileAccess.file_exists(path):
		status.fail(ContentStatus.Code.IO_ERROR, ContentStatus.Operation.FILE_READ)
		return SubmissionShowcaseConfig.new()
	var parsed: Variant = StrictJsonParser.parse_utf8(FileAccess.get_file_as_bytes(path), status)
	if not status.is_ok() or not parsed is Dictionary:
		if status.is_ok(): status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return SubmissionShowcaseConfig.new()
	return _from_dictionary(parsed as Dictionary, catalog, status)


static func _from_dictionary(root: Dictionary, catalog: ContentCatalog, status: ContentStatus) -> SubmissionShowcaseConfig:
	var result := SubmissionShowcaseConfig.new()
	if not _has_exact_keys(root, EXPECTED_KEYS):
		status.fail(_key_error(root, EXPECTED_KEYS), ContentStatus.Operation.DOCUMENT_VALIDATE)
		return result
	if not root["version"] is int or int(root["version"]) != EXPECTED_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return result
	if not root["seed"] is String or not _valid_seed(root["seed"] as String):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return result
	if not root["map_ref"] is Dictionary or not root["encounter_ref"] is Dictionary or not root["piece_refs"] is Array:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return result
	var map_ref: Dictionary = root["map_ref"]
	var encounter_ref: Dictionary = root["encounter_ref"]
	if not _valid_ref_shape(map_ref, status) or not _valid_ref_shape(encounter_ref, status): return result
	var map_definition: MapDefinition = catalog.map_by_numeric_id(int(map_ref["numeric_id"]), status)
	if not status.is_ok() or map_definition.string_id() != String(map_ref["id"]):
		if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE)
		return result
	var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(int(encounter_ref["numeric_id"]), status)
	if not status.is_ok() or encounter.string_id() != String(encounter_ref["id"]) or encounter.map_ref().numeric_id() != map_definition.numeric_id():
		if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE)
		return result
	var piece_refs: Array = root["piece_refs"]
	if piece_refs.size() != EXPECTED_PIECE_COUNT or map_definition.deploy_count() != EXPECTED_PIECE_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return result
	var seen: Dictionary = {}
	for value: Variant in piece_refs:
		if not value is Dictionary or not _valid_ref_shape(value as Dictionary, status): return result
		var piece_ref: Dictionary = value
		var numeric_id: int = int(piece_ref["numeric_id"])
		if seen.has(numeric_id):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.DOCUMENT_VALIDATE)
			return result
		var piece: PieceDefinition = catalog.piece_by_numeric_id(numeric_id, status)
		if not status.is_ok() or piece.string_id() != String(piece_ref["id"]):
			if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE)
			return result
		seen[numeric_id] = true
		result._piece_numeric_ids.append(numeric_id)
	result._map_numeric_id = map_definition.numeric_id()
	result._encounter_numeric_id = encounter.numeric_id()
	var seed: String = root["seed"]
	result._seed_hi = seed.substr(0, 8).hex_to_int()
	result._seed_lo = seed.substr(8, 8).hex_to_int()
	return result


static func _valid_ref_shape(value: Dictionary, status: ContentStatus) -> bool:
	if not _has_exact_keys(value, REF_KEYS):
		status.fail(_key_error(value, REF_KEYS), ContentStatus.Operation.DOCUMENT_VALIDATE)
		return false
	if not value["numeric_id"] is int or int(value["numeric_id"]) <= 0 or not value["id"] is String or String(value["id"]).is_empty():
		status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.DOCUMENT_VALIDATE)
		return false
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: Variant in expected:
		if not value.has(key): return false
	return true


static func _key_error(value: Dictionary, expected: Array) -> int:
	for key: Variant in expected:
		if not value.has(key): return ContentStatus.Code.MISSING_KEY
	return ContentStatus.Code.UNKNOWN_KEY


static func _valid_seed(value: String) -> bool:
	if value.length() != 16: return false
	for index: int in range(value.length()):
		if "0123456789abcdefABCDEF".find(value[index]) < 0: return false
	return true


func is_initialized() -> bool:
	return _map_numeric_id > 0 and _encounter_numeric_id > 0 and _piece_numeric_ids.size() == EXPECTED_PIECE_COUNT

func map_numeric_id() -> int: return _map_numeric_id
func encounter_numeric_id() -> int: return _encounter_numeric_id
func piece_numeric_ids() -> Array[int]: return _piece_numeric_ids.duplicate()
func seed_hi() -> int: return _seed_hi
func seed_lo() -> int: return _seed_lo
