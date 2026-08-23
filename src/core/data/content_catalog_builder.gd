class_name ContentCatalogBuilder
extends RefCounted
## Exact-schema P2-1 builder. Parse trees never escape this boundary.

const CATALOG_KEYS: PackedStringArray = ["schema_version", "documents"]
const DOCUMENT_KEYS: PackedStringArray = ["kind_id", "file_name", "schema_version"]
const REGISTRY_KEYS: PackedStringArray = ["schema_version", "namespaces"]
const NAMESPACE_KEYS: PackedStringArray = ["namespace_id", "entries"]
const ENTRY_KEYS: PackedStringArray = ["numeric_id", "id", "state_id"]
const RECORD_DOCUMENT_KEYS: PackedStringArray = ["schema_version", "records"]
const ABILITY_KEYS: PackedStringArray = ["numeric_id", "id", "trigger_id"]
const PIECE_KEYS: PackedStringArray = ["numeric_id", "id", "flags", "levels"]
const FLAG_KEYS: PackedStringArray = ["has_turn", "destructible", "transformable", "counts_for_victory", "is_token"]
const LEVEL_KEYS: PackedStringArray = ["level", "max_hp", "attack", "speed_stat", "mass_raw", "radius_raw", "friction_multiplier_raw", "critical_basis_points", "ability_refs"]
const REF_KEYS: PackedStringArray = ["numeric_id", "id"]


static func _registry_less(left: ContentRegistryEntry, right: ContentRegistryEntry) -> bool:
	if left.namespace_id() != right.namespace_id():
		return left.namespace_id() < right.namespace_id()
	return left.numeric_id() < right.numeric_id()


static func _piece_less(left: PieceDefinition, right: PieceDefinition) -> bool:
	return left.numeric_id() < right.numeric_id()


static func _ability_less(left: AbilityDefinition, right: AbilityDefinition) -> bool:
	return left.numeric_id() < right.numeric_id()


static func _ref_less(left: ContentIdRef, right: ContentIdRef) -> bool:
	return left.numeric_id() < right.numeric_id()


static func _numeric_key(namespace_id: int, numeric_id: int) -> String:
	return "%d:%d" % [namespace_id, numeric_id]


static func _string_key(namespace_id: int, string_id: String) -> String:
	return "%d:%s" % [namespace_id, string_id]


static func _require_exact_keys(
		value: Dictionary,
		required: PackedStringArray,
		status: ContentStatus,
		document_kind_id: int,
		record_numeric_id: int = 0,
		field_id: int = ContentStatus.FieldId.NONE
) -> bool:
	for key: String in required:
		if not value.has(key):
			status.fail(ContentStatus.Code.MISSING_KEY, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
			return false
	var keys: Array = value.keys()
	keys.sort()
	for key_value: Variant in keys:
		if typeof(key_value) != TYPE_STRING or not required.has(String(key_value)):
			status.fail(ContentStatus.Code.UNKNOWN_KEY, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
			return false
	return true


static func _int_field(value: Dictionary, key: String, status: ContentStatus, document_kind_id: int, record_numeric_id: int, field_id: int) -> int:
	var raw: Variant = value[key]
	if typeof(raw) != TYPE_INT:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
		return 0
	return int(raw)


static func _string_field(value: Dictionary, key: String, status: ContentStatus, document_kind_id: int, record_numeric_id: int, field_id: int) -> String:
	var raw: Variant = value[key]
	if typeof(raw) != TYPE_STRING:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
		return ""
	return String(raw)


static func _bool_field(value: Dictionary, key: String, status: ContentStatus, document_kind_id: int, record_numeric_id: int, field_id: int) -> bool:
	var raw: Variant = value[key]
	if typeof(raw) != TYPE_BOOL:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
		return false
	return bool(raw)


static func _array_field(value: Dictionary, key: String, status: ContentStatus, document_kind_id: int, record_numeric_id: int, field_id: int) -> Array:
	var raw: Variant = value[key]
	if typeof(raw) != TYPE_ARRAY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
		return []
	return raw as Array


static func _dictionary_field(value: Dictionary, key: String, status: ContentStatus, document_kind_id: int, record_numeric_id: int, field_id: int) -> Dictionary:
	var raw: Variant = value[key]
	if typeof(raw) != TYPE_DICTIONARY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
		return {}
	return raw as Dictionary


static func _root_for_kind(source_documents: Array[ContentSourceFile], kind_id: int, status: ContentStatus) -> Dictionary:
	var found: ContentSourceFile
	for source: ContentSourceFile in source_documents:
		if source == null or not source.is_initialized():
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD, kind_id)
			return {}
		if source.kind_id() == kind_id:
			if found != null:
				status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, kind_id)
				return {}
			found = source
	if found == null:
		status.fail(ContentStatus.Code.MISSING_KEY, ContentStatus.Operation.CATALOG_BUILD, kind_id)
		return {}
	return found.root_copy()


static func _validate_catalog_document(catalog: Dictionary, source_documents: Array[ContentSourceFile], status: ContentStatus) -> bool:
	if not _require_exact_keys(catalog, CATALOG_KEYS, status, ContentIds.DocumentKind.INVALID): return false
	var schema_version: int = _int_field(catalog, "schema_version", status, 0, 0, ContentStatus.FieldId.SCHEMA_VERSION)
	if not status.is_ok(): return false
	if schema_version != ContentIds.CATALOG_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, 0, 0, ContentStatus.FieldId.SCHEMA_VERSION)
		return false
	var documents: Array = _array_field(catalog, "documents", status, 0, 0, ContentStatus.FieldId.DOCUMENTS)
	if not status.is_ok(): return false
	if documents.size() != 3 or documents.size() > ContentLimits.DOCUMENT_MAX_COUNT or source_documents.size() != 3:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, 0, 0, ContentStatus.FieldId.DOCUMENTS)
		return false
	var seen: Dictionary = {}
	for raw_document: Variant in documents:
		if typeof(raw_document) != TYPE_DICTIONARY:
			status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, 0, 0, ContentStatus.FieldId.DOCUMENTS)
			return false
		var document: Dictionary = raw_document as Dictionary
		if not _require_exact_keys(document, DOCUMENT_KEYS, status, 0, 0, ContentStatus.FieldId.DOCUMENTS): return false
		var kind_id: int = _int_field(document, "kind_id", status, 0, 0, ContentStatus.FieldId.KIND_ID)
		var file_name: String = _string_field(document, "file_name", status, 0, 0, ContentStatus.FieldId.FILE_NAME)
		var document_schema: int = _int_field(document, "schema_version", status, 0, 0, ContentStatus.FieldId.SCHEMA_VERSION)
		if not status.is_ok(): return false
		if (
			not ContentIds.is_known_document_kind(kind_id)
			or seen.has(kind_id)
			or file_name != ContentIds.file_for_document_kind(kind_id)
			or document_schema != ContentIds.schema_for_document_kind(kind_id)
		):
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, kind_id)
			return false
		seen[kind_id] = true
	for kind_id: int in range(ContentIds.DocumentKind.ID_REGISTRY, ContentIds.DocumentKind.ABILITIES + 1):
		if not seen.has(kind_id):
			status.fail(ContentStatus.Code.MISSING_KEY, ContentStatus.Operation.DOCUMENT_VALIDATE, kind_id)
			return false
		var source_seen: bool = false
		for source: ContentSourceFile in source_documents:
			if source.kind_id() == kind_id:
				if source_seen:
					status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, kind_id)
					return false
				source_seen = true
		if not source_seen:
			status.fail(ContentStatus.Code.MISSING_KEY, ContentStatus.Operation.CATALOG_BUILD, kind_id)
			return false
	return true


static func _parse_registry(
		root: Dictionary,
		entries_out: Array[ContentRegistryEntry],
		by_numeric: Dictionary,
		by_string: Dictionary,
		status: ContentStatus
) -> bool:
	const KIND: int = ContentIds.DocumentKind.ID_REGISTRY
	if not _require_exact_keys(root, REGISTRY_KEYS, status, KIND): return false
	var schema_version: int = _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION)
	if not status.is_ok(): return false
	if schema_version != ContentIds.REGISTRY_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION)
		return false
	var namespaces: Array = _array_field(root, "namespaces", status, KIND, 0, ContentStatus.FieldId.NAMESPACES)
	if not status.is_ok(): return false
	if namespaces.size() != ContentIds.Namespace.TAG:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.NAMESPACES)
		return false
	var seen_namespaces: Dictionary = {}
	for raw_namespace: Variant in namespaces:
		if typeof(raw_namespace) != TYPE_DICTIONARY:
			status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.NAMESPACES)
			return false
		var namespace_value: Dictionary = raw_namespace as Dictionary
		if not _require_exact_keys(namespace_value, NAMESPACE_KEYS, status, KIND, 0, ContentStatus.FieldId.NAMESPACES): return false
		var namespace_id: int = _int_field(namespace_value, "namespace_id", status, KIND, 0, ContentStatus.FieldId.NAMESPACE_ID)
		var raw_entries: Array = _array_field(namespace_value, "entries", status, KIND, 0, ContentStatus.FieldId.ENTRIES)
		if not status.is_ok(): return false
		if not ContentIds.is_known_namespace(namespace_id) or seen_namespaces.has(namespace_id):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.ID_REGISTER, KIND, 0, ContentStatus.FieldId.NAMESPACE_ID)
			return false
		seen_namespaces[namespace_id] = true
		if raw_entries.size() > ContentLimits.REGISTRY_MAX_ENTRIES_PER_NAMESPACE:
			status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ID_REGISTER, KIND, 0, ContentStatus.FieldId.ENTRIES)
			return false
		if namespace_id > ContentIds.Namespace.ABILITY and not raw_entries.is_empty():
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ID_REGISTER, KIND, 0, ContentStatus.FieldId.ENTRIES)
			return false
		for raw_entry: Variant in raw_entries:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.ID_REGISTER, KIND, 0, ContentStatus.FieldId.ENTRIES)
				return false
			var value: Dictionary = raw_entry as Dictionary
			if not _require_exact_keys(value, ENTRY_KEYS, status, KIND, 0, ContentStatus.FieldId.ENTRIES): return false
			var numeric_id: int = _int_field(value, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
			var string_id: String = _string_field(value, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
			var state_id: int = _int_field(value, "state_id", status, KIND, numeric_id, ContentStatus.FieldId.STATE_ID)
			if not status.is_ok(): return false
			var numeric_key: String = _numeric_key(namespace_id, numeric_id)
			var string_key: String = _string_key(namespace_id, string_id)
			if by_numeric.has(numeric_key) or by_string.has(string_key):
				status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.ID_REGISTER, KIND, numeric_id)
				return false
			var entry: ContentRegistryEntry = ContentRegistryEntry.create(namespace_id, numeric_id, string_id, state_id, status)
			if not status.is_ok(): return false
			entries_out.append(entry)
			by_numeric[numeric_key] = entry
			by_string[string_key] = entry
	for namespace_id: int in range(ContentIds.Namespace.PIECE, ContentIds.Namespace.TAG + 1):
		if not seen_namespaces.has(namespace_id):
			status.fail(ContentStatus.Code.MISSING_KEY, ContentStatus.Operation.ID_REGISTER, KIND, 0, ContentStatus.FieldId.NAMESPACE_ID)
			return false
	entries_out.sort_custom(_registry_less)
	return true


static func _active_registry_pair(
		namespace_id: int,
		numeric_id: int,
		string_id: String,
		by_numeric: Dictionary,
		by_string: Dictionary,
		status: ContentStatus,
		document_kind_id: int,
		field_id: int
) -> ContentRegistryEntry:
	if numeric_id <= 0 or numeric_id > ContentLimits.UINT32_MAX or not ContentIds.valid_string_id(string_id):
		status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.REFERENCE_RESOLVE, document_kind_id, numeric_id, field_id)
		return ContentRegistryEntry.new()
	var numeric_key: String = _numeric_key(namespace_id, numeric_id)
	var string_key: String = _string_key(namespace_id, string_id)
	if not by_numeric.has(numeric_key) or not by_string.has(string_key):
		status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE, document_kind_id, numeric_id, field_id)
		return ContentRegistryEntry.new()
	var numeric_entry: ContentRegistryEntry = by_numeric[numeric_key]
	var string_entry: ContentRegistryEntry = by_string[string_key]
	if numeric_entry != string_entry or numeric_entry.state_id() != ContentIds.EntryState.ACTIVE:
		status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.REFERENCE_RESOLVE, document_kind_id, numeric_id, field_id)
		return ContentRegistryEntry.new()
	return numeric_entry


static func _parse_abilities(
		root: Dictionary,
		registry_by_numeric: Dictionary,
		registry_by_string: Dictionary,
		abilities_out: Array[AbilityDefinition],
		ability_by_numeric: Dictionary,
		status: ContentStatus
) -> bool:
	const KIND: int = ContentIds.DocumentKind.ABILITIES
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	var schema_version: int = _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION)
	if not status.is_ok(): return false
	if schema_version != ContentIds.ABILITIES_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION)
		return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if not status.is_ok(): return false
	if records.size() > ContentLimits.RECORD_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS)
		return false
	var string_ids: Dictionary = {}
	for raw_record: Variant in records:
		if typeof(raw_record) != TYPE_DICTIONARY:
			status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS)
			return false
		var record: Dictionary = raw_record as Dictionary
		if not _require_exact_keys(record, ABILITY_KEYS, status, KIND, 0, ContentStatus.FieldId.RECORDS): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		var trigger_id: int = _int_field(record, "trigger_id", status, KIND, numeric_id, ContentStatus.FieldId.TRIGGER_ID)
		if not status.is_ok(): return false
		var registry_entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.ABILITY, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		if not status.is_ok(): return false
		if ability_by_numeric.has(numeric_id) or string_ids.has(string_id):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, KIND, numeric_id)
			return false
		var id_status := ContentStatus.new()
		var id_ref: ContentIdRef = ContentIdRef.create(registry_entry.numeric_id(), registry_entry.string_id(), id_status)
		if not id_status.is_ok():
			status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.CATALOG_BUILD, KIND, numeric_id)
			return false
		var ability: AbilityDefinition = AbilityDefinition.create(id_ref, trigger_id, status)
		if not status.is_ok(): return false
		abilities_out.append(ability)
		ability_by_numeric[numeric_id] = ability
		string_ids[string_id] = true
	abilities_out.sort_custom(_ability_less)
	return true


static func _parse_ability_ref(
		raw_ref: Variant,
		piece_numeric_id: int,
		registry_by_numeric: Dictionary,
		registry_by_string: Dictionary,
		ability_by_numeric: Dictionary,
		status: ContentStatus
) -> ContentIdRef:
	const KIND: int = ContentIds.DocumentKind.PIECES
	if typeof(raw_ref) != TYPE_DICTIONARY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, piece_numeric_id, ContentStatus.FieldId.ABILITY_REFS)
		return ContentIdRef.new()
	var value: Dictionary = raw_ref as Dictionary
	if not _require_exact_keys(value, REF_KEYS, status, KIND, piece_numeric_id, ContentStatus.FieldId.ABILITY_REFS): return ContentIdRef.new()
	var numeric_id: int = _int_field(value, "numeric_id", status, KIND, piece_numeric_id, ContentStatus.FieldId.ABILITY_REFS)
	var string_id: String = _string_field(value, "id", status, KIND, piece_numeric_id, ContentStatus.FieldId.ABILITY_REFS)
	if not status.is_ok(): return ContentIdRef.new()
	var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.ABILITY, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ABILITY_REFS)
	if not status.is_ok(): return ContentIdRef.new()
	if not ability_by_numeric.has(numeric_id):
		status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, piece_numeric_id, ContentStatus.FieldId.ABILITY_REFS)
		return ContentIdRef.new()
	var ability: AbilityDefinition = ability_by_numeric[numeric_id]
	if ability.string_id() != string_id:
		status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, piece_numeric_id, ContentStatus.FieldId.ABILITY_REFS)
		return ContentIdRef.new()
	return ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)


static func _valid_level_domain(
		level: int,
		max_hp: int,
		attack: int,
		speed_stat: int,
		mass_raw: int,
		radius_raw: int,
		friction_multiplier_raw: int,
		critical_basis_points: int,
		status: ContentStatus,
		piece_numeric_id: int
) -> bool:
	var field_id: int = ContentStatus.FieldId.NONE
	if level < 1 or level > ContentLimits.PIECE_LEVEL_MAX_COUNT: field_id = ContentStatus.FieldId.LEVEL
	elif not DamageLimits.valid_stat(max_hp): field_id = ContentStatus.FieldId.MAX_HP
	elif not DamageLimits.valid_stat(attack): field_id = ContentStatus.FieldId.ATTACK
	elif not BattleLimits.valid_base_speed(speed_stat): field_id = ContentStatus.FieldId.SPEED_STAT
	elif not SimLimits.is_mass_valid(mass_raw): field_id = ContentStatus.FieldId.MASS_RAW
	elif not SimLimits.is_radius_valid(radius_raw): field_id = ContentStatus.FieldId.RADIUS_RAW
	elif friction_multiplier_raw < 0: field_id = ContentStatus.FieldId.FRICTION_MULTIPLIER_RAW
	elif not DamageLimits.valid_critical_basis_points(critical_basis_points): field_id = ContentStatus.FieldId.CRITICAL_BASIS_POINTS
	if field_id != ContentStatus.FieldId.NONE:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.PIECES, piece_numeric_id, field_id)
		return false
	return true


static func _parse_pieces(
		root: Dictionary,
		registry_by_numeric: Dictionary,
		registry_by_string: Dictionary,
		ability_by_numeric: Dictionary,
		pieces_out: Array[PieceDefinition],
		piece_by_numeric: Dictionary,
		status: ContentStatus
) -> bool:
	const KIND: int = ContentIds.DocumentKind.PIECES
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	var schema_version: int = _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION)
	if not status.is_ok(): return false
	if schema_version != ContentIds.PIECES_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION)
		return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if not status.is_ok(): return false
	if records.size() > ContentLimits.RECORD_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS)
		return false
	var string_ids: Dictionary = {}
	for raw_record: Variant in records:
		if typeof(raw_record) != TYPE_DICTIONARY:
			status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS)
			return false
		var record: Dictionary = raw_record as Dictionary
		if not _require_exact_keys(record, PIECE_KEYS, status, KIND, 0, ContentStatus.FieldId.RECORDS): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		if not status.is_ok(): return false
		var registry_entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.PIECE, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		if not status.is_ok(): return false
		if piece_by_numeric.has(numeric_id) or string_ids.has(string_id):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, KIND, numeric_id)
			return false

		var flags: Dictionary = _dictionary_field(record, "flags", status, KIND, numeric_id, ContentStatus.FieldId.FLAGS)
		if not status.is_ok() or not _require_exact_keys(flags, FLAG_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.FLAGS): return false
		var has_turn: bool = _bool_field(flags, "has_turn", status, KIND, numeric_id, ContentStatus.FieldId.HAS_TURN)
		var destructible: bool = _bool_field(flags, "destructible", status, KIND, numeric_id, ContentStatus.FieldId.DESTRUCTIBLE)
		var transformable: bool = _bool_field(flags, "transformable", status, KIND, numeric_id, ContentStatus.FieldId.TRANSFORMABLE)
		var counts_for_victory: bool = _bool_field(flags, "counts_for_victory", status, KIND, numeric_id, ContentStatus.FieldId.COUNTS_FOR_VICTORY)
		var is_token: bool = _bool_field(flags, "is_token", status, KIND, numeric_id, ContentStatus.FieldId.IS_TOKEN)
		if not status.is_ok(): return false

		var raw_levels: Array = _array_field(record, "levels", status, KIND, numeric_id, ContentStatus.FieldId.LEVELS)
		if not status.is_ok(): return false
		if raw_levels.is_empty() or raw_levels.size() > ContentLimits.PIECE_LEVEL_MAX_COUNT:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.LEVELS)
			return false
		var levels: Array[PieceLevelDefinition] = []
		for level_index: int in range(raw_levels.size()):
			var raw_level: Variant = raw_levels[level_index]
			if typeof(raw_level) != TYPE_DICTIONARY:
				status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.LEVELS)
				return false
			var level_value: Dictionary = raw_level as Dictionary
			if not _require_exact_keys(level_value, LEVEL_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.LEVELS): return false
			var level: int = _int_field(level_value, "level", status, KIND, numeric_id, ContentStatus.FieldId.LEVEL)
			var max_hp: int = _int_field(level_value, "max_hp", status, KIND, numeric_id, ContentStatus.FieldId.MAX_HP)
			var attack: int = _int_field(level_value, "attack", status, KIND, numeric_id, ContentStatus.FieldId.ATTACK)
			var speed_stat: int = _int_field(level_value, "speed_stat", status, KIND, numeric_id, ContentStatus.FieldId.SPEED_STAT)
			var mass_raw: int = _int_field(level_value, "mass_raw", status, KIND, numeric_id, ContentStatus.FieldId.MASS_RAW)
			var radius_raw: int = _int_field(level_value, "radius_raw", status, KIND, numeric_id, ContentStatus.FieldId.RADIUS_RAW)
			var friction_raw: int = _int_field(level_value, "friction_multiplier_raw", status, KIND, numeric_id, ContentStatus.FieldId.FRICTION_MULTIPLIER_RAW)
			var critical: int = _int_field(level_value, "critical_basis_points", status, KIND, numeric_id, ContentStatus.FieldId.CRITICAL_BASIS_POINTS)
			var raw_refs: Array = _array_field(level_value, "ability_refs", status, KIND, numeric_id, ContentStatus.FieldId.ABILITY_REFS)
			if not status.is_ok(): return false
			if level != level_index + 1 or not _valid_level_domain(level, max_hp, attack, speed_stat, mass_raw, radius_raw, friction_raw, critical, status, numeric_id):
				if status.is_ok(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.LEVEL)
				return false
			if raw_refs.size() > ContentLimits.ABILITY_REFS_MAX_COUNT:
				status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ABILITY_REFS)
				return false
			var refs: Array[ContentIdRef] = []
			var seen_refs: Dictionary = {}
			for raw_ref: Variant in raw_refs:
				var ability_ref: ContentIdRef = _parse_ability_ref(raw_ref, numeric_id, registry_by_numeric, registry_by_string, ability_by_numeric, status)
				if not status.is_ok(): return false
				if seen_refs.has(ability_ref.numeric_id()):
					status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.ABILITY_REFS)
					return false
				seen_refs[ability_ref.numeric_id()] = true
				refs.append(ability_ref)
			refs.sort_custom(_ref_less)
			var level_definition: PieceLevelDefinition = PieceLevelDefinition.create(level, max_hp, attack, speed_stat, mass_raw, radius_raw, friction_raw, critical, refs, status)
			if not status.is_ok(): return false
			levels.append(level_definition)

		var id_ref: ContentIdRef = ContentIdRef.create(registry_entry.numeric_id(), registry_entry.string_id(), status)
		var piece: PieceDefinition = PieceDefinition.create(id_ref, has_turn, destructible, transformable, counts_for_victory, is_token, levels, status)
		if not status.is_ok(): return false
		pieces_out.append(piece)
		piece_by_numeric[numeric_id] = piece
		string_ids[string_id] = true
	pieces_out.sort_custom(_piece_less)
	return true


static func _validate_active_registry_coverage(
		entries: Array[ContentRegistryEntry],
		piece_by_numeric: Dictionary,
		ability_by_numeric: Dictionary,
		status: ContentStatus
) -> bool:
	for entry: ContentRegistryEntry in entries:
		if entry.state_id() != ContentIds.EntryState.ACTIVE: continue
		if entry.namespace_id() == ContentIds.Namespace.PIECE:
			if not piece_by_numeric.has(entry.numeric_id()):
				status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.PIECES, entry.numeric_id())
				return false
		elif entry.namespace_id() == ContentIds.Namespace.ABILITY:
			if not ability_by_numeric.has(entry.numeric_id()):
				status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.ABILITIES, entry.numeric_id())
				return false
		else:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ID_REGISTER, ContentIds.DocumentKind.ID_REGISTRY, entry.numeric_id())
			return false
	return true


static func build(
		catalog_document: Dictionary,
		source_documents: Array[ContentSourceFile],
		status: ContentStatus
) -> ContentCatalog:
	if not status.is_ok(): return ContentCatalog.new()
	if not _validate_catalog_document(catalog_document, source_documents, status): return ContentCatalog.new()
	var registry_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.ID_REGISTRY, status)
	var pieces_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.PIECES, status)
	var abilities_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.ABILITIES, status)
	if not status.is_ok(): return ContentCatalog.new()

	var registry_entries: Array[ContentRegistryEntry] = []
	var registry_by_numeric: Dictionary = {}
	var registry_by_string: Dictionary = {}
	if not _parse_registry(registry_root, registry_entries, registry_by_numeric, registry_by_string, status): return ContentCatalog.new()

	var abilities: Array[AbilityDefinition] = []
	var ability_by_numeric: Dictionary = {}
	if not _parse_abilities(abilities_root, registry_by_numeric, registry_by_string, abilities, ability_by_numeric, status): return ContentCatalog.new()

	var pieces: Array[PieceDefinition] = []
	var piece_by_numeric: Dictionary = {}
	if not _parse_pieces(pieces_root, registry_by_numeric, registry_by_string, ability_by_numeric, pieces, piece_by_numeric, status): return ContentCatalog.new()
	if not _validate_active_registry_coverage(registry_entries, piece_by_numeric, ability_by_numeric, status): return ContentCatalog.new()

	var compatibility_bytes: PackedByteArray = ContentCanonicalEncoder.encode(registry_entries, pieces, abilities, status)
	if not status.is_ok(): return ContentCatalog.new()
	var sim_status := SimStatus.new()
	var fingerprint: PackedByteArray = SimStateHash.sha256(compatibility_bytes, sim_status)
	if not sim_status.is_ok() or fingerprint.size() != 32:
		status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.SHA256)
		return ContentCatalog.new()
	return ContentCatalog.create(ContentIds.CATALOG_SCHEMA_VERSION, registry_entries, pieces, abilities, compatibility_bytes, fingerprint, status)
