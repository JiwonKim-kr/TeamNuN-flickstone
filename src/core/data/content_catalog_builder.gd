class_name ContentCatalogBuilder
extends RefCounted
## Exact-schema P2-1 builder. Parse trees never escape this boundary.

const CATALOG_KEYS: PackedStringArray = ["schema_version", "documents"]
const DOCUMENT_KEYS: PackedStringArray = ["kind_id", "file_name", "schema_version"]
const REGISTRY_KEYS: PackedStringArray = ["schema_version", "namespaces"]
const NAMESPACE_KEYS: PackedStringArray = ["namespace_id", "entries"]
const ENTRY_KEYS: PackedStringArray = ["numeric_id", "id", "state_id"]
const RECORD_DOCUMENT_KEYS: PackedStringArray = ["schema_version", "records"]
const ABILITY_KEYS: PackedStringArray = ["numeric_id", "id", "trigger_id", "conditions", "effects"]
const CONDITION_KEYS: PackedStringArray = ["kind_id", "relation_id", "value_a", "value_b"]
const EFFECT_KEYS: PackedStringArray = ["kind_id", "selector", "value_a", "value_b", "operation_id"]
const SPAWN_KEYS: PackedStringArray = ["piece_ref", "offset_x_raw", "offset_y_raw", "speed_raw", "direction_mode_id"]
const TRANSFORM_KEYS: PackedStringArray = ["piece_ref"]
const ATTACH_KEYS: PackedStringArray = ["owner_role_id", "anchor_mode_id", "anchor_offset_x_raw", "anchor_offset_y_raw", "attach_distance_raw", "inertia_basis_points", "duration_turns"]
const ZONE_PAYLOAD_KEYS: PackedStringArray = ["flags", "friction_multiplier_raw", "acceleration_x_raw", "acceleration_y_raw", "offset_x_raw", "offset_y_raw", "vertices", "duration_turns"]
const SELECTOR_KEYS: PackedStringArray = ["kind_id", "relation_id", "limit"]
const PIECE_KEYS: PackedStringArray = ["numeric_id", "id", "flags", "spawnable", "spawn_faction_mode_id", "expire_kind_id", "expire_value", "attach_anchor_mode_id", "attach_anchor_offset_x_raw", "attach_anchor_offset_y_raw", "tag_refs", "levels"]
const FLAG_KEYS: PackedStringArray = ["has_turn", "destructible", "transformable", "counts_for_victory", "is_token"]
const LEVEL_KEYS: PackedStringArray = ["level", "max_hp", "attack", "speed_stat", "mass_raw", "radius_raw", "friction_multiplier_raw", "critical_basis_points", "ability_refs"]
const REF_KEYS: PackedStringArray = ["numeric_id", "id"]
const STATUS_KEYS: PackedStringArray = ["numeric_id", "id", "stack_policy_id", "max_stacks", "duration_kind_id", "default_duration", "max_duration", "refresh_policy_id", "merge_sources", "modifiers"]
const SYNERGY_KEYS: PackedStringArray = ["numeric_id", "id", "tag_ref", "tag_kind_id", "scope_id", "count_cap", "tiers"]
const MODIFIER_KEYS: PackedStringArray = ["kind_id", "operation_id", "value_mode_id", "value"]
const TIER_KEYS: PackedStringArray = ["min_count", "modifiers"]
const POINT_KEYS: PackedStringArray = ["x_raw", "y_raw"]
const MAP_KEYS: PackedStringArray = ["numeric_id", "id", "boundary_type_id", "boundary_vertices", "deploy_count", "player_slots", "enemy_slots", "zones", "obstacles"]
const MAP_ZONE_KEYS: PackedStringArray = ["local_id", "flags", "friction_multiplier_raw", "acceleration_x_raw", "acceleration_y_raw", "vertices"]
const ENEMY_KEYS: PackedStringArray = ["numeric_id", "id", "base_piece_ref", "ai_grade_id", "override"]
const ENEMY_OVERRIDE_KEYS: PackedStringArray = ["max_hp", "attack", "speed_stat", "mass_raw", "radius_raw", "friction_multiplier_raw", "critical_basis_points", "ability_refs"]
const ACT_KEYS: PackedStringArray = ["numeric_id", "id", "is_development", "floors"]
const ACT_FLOOR_KEYS: PackedStringArray = ["floor_index", "slots"]
const ACT_SLOT_KEYS: PackedStringArray = ["slot_index", "options"]
const ACT_OPTION_KEYS: PackedStringArray = ["node_type_id", "weight", "content_refs"]
const ENCOUNTER_KEYS: PackedStringArray = ["numeric_id", "id", "node_type_id", "map_ref", "enemy_refs", "reward_profile_numeric_id"]
const REWARD_PROFILE_KEYS: PackedStringArray = ["numeric_id", "id", "victory_gold", "recruit_choice_count", "recruit_pool_refs", "revenge_status_ref"]
const RELIC_KEYS: PackedStringArray = ["numeric_id", "id", "effect"]
const CONSUMABLE_KEYS: PackedStringArray = ["numeric_id", "id", "max_stack", "use_phase_id", "effect"]
const RUN_EFFECT_KEYS: PackedStringArray = ["kind_id", "primary_numeric_id", "amount"]
const SHOP_KEYS: PackedStringArray = ["numeric_id", "id", "offers"]
const SHOP_OFFER_KEYS: PackedStringArray = ["offer_id", "item_kind_id", "item_ref", "count", "cost"]
const EVENT_KEYS: PackedStringArray = ["numeric_id", "id", "options"]
const EVENT_OPTION_KEYS: PackedStringArray = ["option_id", "effects"]


static func _registry_less(left: ContentRegistryEntry, right: ContentRegistryEntry) -> bool:
	if left.namespace_id() != right.namespace_id():
		return left.namespace_id() < right.namespace_id()
	return left.numeric_id() < right.numeric_id()


static func _piece_less(left: PieceDefinition, right: PieceDefinition) -> bool:
	return left.numeric_id() < right.numeric_id()


static func _ability_less(left: AbilityDefinition, right: AbilityDefinition) -> bool:
	return left.numeric_id() < right.numeric_id()


static func _map_less(left: MapDefinition, right: MapDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _enemy_less(left: EnemyDefinition, right: EnemyDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _act_less(left: ActDefinition, right: ActDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _encounter_less(left: EncounterDefinition, right: EncounterDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _reward_profile_less(left: RewardProfileDefinition, right: RewardProfileDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _relic_less(left: RelicDefinition, right: RelicDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _consumable_less(left: ConsumableDefinition, right: ConsumableDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _shop_less(left: ShopDefinition, right: ShopDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _event_less(left: EventDefinition, right: EventDefinition) -> bool: return left.numeric_id() < right.numeric_id()
static func _map_zone_less(left: MapZoneDefinition, right: MapZoneDefinition) -> bool: return left.local_id() < right.local_id()
static func _act_content_ref_less(left: ActContentRef, right: ActContentRef) -> bool: return left.numeric_id() < right.numeric_id()
static func _act_option_less(left: ActNodeOptionDefinition, right: ActNodeOptionDefinition) -> bool: return left.node_type_id() < right.node_type_id()
static func _act_slot_less(left: ActNodeSlotDefinition, right: ActNodeSlotDefinition) -> bool: return left.slot_index() < right.slot_index()
static func _act_floor_less(left: ActFloorDefinition, right: ActFloorDefinition) -> bool: return left.floor_index() < right.floor_index()


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


static func _parse_point(raw: Variant, document_kind_id: int, record_numeric_id: int, field_id: int, status: ContentStatus) -> FixVec2:
	if typeof(raw) != TYPE_DICTIONARY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
		return FixVec2.zero()
	var value: Dictionary = raw as Dictionary
	if not _require_exact_keys(value, POINT_KEYS, status, document_kind_id, record_numeric_id, field_id): return FixVec2.zero()
	var point: FixVec2 = FixVec2.from_raw(
		_int_field(value, "x_raw", status, document_kind_id, record_numeric_id, field_id),
		_int_field(value, "y_raw", status, document_kind_id, record_numeric_id, field_id))
	if status.is_ok() and not SimLimits.is_position_valid(point):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
	return point


static func _parse_vertices(raw_values: Array, document_kind_id: int, record_numeric_id: int, field_id: int, status: ContentStatus) -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	if raw_values.size() < SimPolygon.MIN_VERTEX_COUNT or raw_values.size() > SimPolygon.MAX_VERTEX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, document_kind_id, record_numeric_id, field_id)
		return result
	for raw: Variant in raw_values:
		result.append(_parse_point(raw, document_kind_id, record_numeric_id, field_id, status))
		if not status.is_ok(): return []
	return result


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
	if documents.size() != ContentIds.DocumentKind.EVENTS or documents.size() > ContentLimits.DOCUMENT_MAX_COUNT or source_documents.size() != ContentIds.DocumentKind.EVENTS:
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
	for kind_id: int in range(ContentIds.DocumentKind.ID_REGISTRY, ContentIds.DocumentKind.EVENTS + 1):
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
	if namespaces.size() != ContentIds.Namespace.EVENT:
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
		if namespace_id == ContentIds.Namespace.PROJECTILE and not raw_entries.is_empty():
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
	for namespace_id: int in range(ContentIds.Namespace.PIECE, ContentIds.Namespace.EVENT + 1):
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


static func _parse_payload_piece_ref(raw_ref: Variant, registry_by_numeric: Dictionary, registry_by_string: Dictionary, ability_numeric_id: int, status: ContentStatus) -> ContentIdRef:
	const KIND: int = ContentIds.DocumentKind.ABILITIES
	if typeof(raw_ref) != TYPE_DICTIONARY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, ability_numeric_id, ContentStatus.FieldId.PIECE_REF)
		return ContentIdRef.new()
	var value: Dictionary = raw_ref as Dictionary
	if not _require_exact_keys(value, REF_KEYS, status, KIND, ability_numeric_id, ContentStatus.FieldId.PIECE_REF): return ContentIdRef.new()
	var numeric_id: int = _int_field(value, "numeric_id", status, KIND, ability_numeric_id, ContentStatus.FieldId.PIECE_REF)
	var string_id: String = _string_field(value, "id", status, KIND, ability_numeric_id, ContentStatus.FieldId.PIECE_REF)
	var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.PIECE, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.PIECE_REF)
	if not status.is_ok(): return ContentIdRef.new()
	return ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)


static func _parse_abilities(
		root: Dictionary,
		registry_by_numeric: Dictionary,
		registry_by_string: Dictionary,
		status_by_numeric: Dictionary,
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
		var raw_conditions: Array = _array_field(record, "conditions", status, KIND, numeric_id, ContentStatus.FieldId.CONDITIONS)
		var raw_effects: Array = _array_field(record, "effects", status, KIND, numeric_id, ContentStatus.FieldId.EFFECTS)
		if not status.is_ok(): return false
		if raw_conditions.size() > ContentLimits.ABILITY_CONDITIONS_MAX_COUNT or raw_effects.size() > ContentLimits.ABILITY_EFFECTS_MAX_COUNT:
			status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id); return false
		var conditions: Array[AbilityConditionDefinition] = []
		for raw_condition: Variant in raw_conditions:
			if typeof(raw_condition) != TYPE_DICTIONARY:
				status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.CONDITIONS); return false
			var condition_value: Dictionary = raw_condition as Dictionary
			if not _require_exact_keys(condition_value, CONDITION_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.CONDITIONS): return false
			var condition: AbilityConditionDefinition = AbilityConditionDefinition.create(
				_int_field(condition_value, "kind_id", status, KIND, numeric_id, ContentStatus.FieldId.CONDITION_KIND_ID),
				_int_field(condition_value, "relation_id", status, KIND, numeric_id, ContentStatus.FieldId.RELATION_ID),
				_int_field(condition_value, "value_a", status, KIND, numeric_id, ContentStatus.FieldId.VALUE_A),
				_int_field(condition_value, "value_b", status, KIND, numeric_id, ContentStatus.FieldId.VALUE_B), status)
			if not status.is_ok(): return false
			conditions.append(condition)
		var effects: Array[AbilityEffectDefinition] = []
		for raw_effect: Variant in raw_effects:
			if typeof(raw_effect) != TYPE_DICTIONARY:
				status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.EFFECTS); return false
			var effect_value: Dictionary = raw_effect as Dictionary
			if not effect_value.has("kind_id"):
				status.fail(ContentStatus.Code.MISSING_KEY, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.EFFECT_KIND_ID); return false
			var kind_id: int = _int_field(effect_value, "kind_id", status, KIND, numeric_id, ContentStatus.FieldId.EFFECT_KIND_ID)
			var expected_keys: PackedStringArray = EFFECT_KEYS.duplicate()
			if kind_id == AbilityEffectDefinition.Kind.SPAWN_PIECE or kind_id == AbilityEffectDefinition.Kind.SPAWN_PROJECTILE: expected_keys.append("spawn")
			elif kind_id == AbilityEffectDefinition.Kind.TRANSFORM_PIECE: expected_keys.append("transform")
			elif kind_id == AbilityEffectDefinition.Kind.ATTACH: expected_keys.append("attach")
			elif kind_id == AbilityEffectDefinition.Kind.SPAWN_ZONE: expected_keys.append("zone")
			if not _require_exact_keys(effect_value, expected_keys, status, KIND, numeric_id, ContentStatus.FieldId.EFFECTS): return false
			var selector_value: Dictionary = _dictionary_field(effect_value, "selector", status, KIND, numeric_id, ContentStatus.FieldId.SELECTOR)
			if not status.is_ok() or not _require_exact_keys(selector_value, SELECTOR_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.SELECTOR): return false
			var selector: AbilitySelectorDefinition = AbilitySelectorDefinition.create(
				_int_field(selector_value, "kind_id", status, KIND, numeric_id, ContentStatus.FieldId.SELECTOR_KIND_ID),
				_int_field(selector_value, "relation_id", status, KIND, numeric_id, ContentStatus.FieldId.RELATION_ID),
				_int_field(selector_value, "limit", status, KIND, numeric_id, ContentStatus.FieldId.LIMIT), status)
			var spawn_payload: SpawnPayloadDefinition = null
			var transform_payload: TransformPayloadDefinition = null
			var attach_payload: AttachPayloadDefinition = null
			var zone_payload: ZoneSpawnPayloadDefinition = null
			if kind_id == AbilityEffectDefinition.Kind.SPAWN_PIECE or kind_id == AbilityEffectDefinition.Kind.SPAWN_PROJECTILE:
				var payload_value: Dictionary = _dictionary_field(effect_value, "spawn", status, KIND, numeric_id, ContentStatus.FieldId.SPAWN_PAYLOAD)
				if not status.is_ok() or not _require_exact_keys(payload_value, SPAWN_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.SPAWN_PAYLOAD): return false
				var piece_ref: ContentIdRef = _parse_payload_piece_ref(payload_value["piece_ref"], registry_by_numeric, registry_by_string, numeric_id, status)
				spawn_payload = SpawnPayloadDefinition.create(piece_ref,
					_int_field(payload_value, "offset_x_raw", status, KIND, numeric_id, ContentStatus.FieldId.OFFSET_X_RAW),
					_int_field(payload_value, "offset_y_raw", status, KIND, numeric_id, ContentStatus.FieldId.OFFSET_Y_RAW),
					_int_field(payload_value, "speed_raw", status, KIND, numeric_id, ContentStatus.FieldId.SPEED_RAW),
					_int_field(payload_value, "direction_mode_id", status, KIND, numeric_id, ContentStatus.FieldId.DIRECTION_MODE_ID), status)
			elif kind_id == AbilityEffectDefinition.Kind.TRANSFORM_PIECE:
				var payload_value: Dictionary = _dictionary_field(effect_value, "transform", status, KIND, numeric_id, ContentStatus.FieldId.TRANSFORM_PAYLOAD)
				if not status.is_ok() or not _require_exact_keys(payload_value, TRANSFORM_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.TRANSFORM_PAYLOAD): return false
				transform_payload = TransformPayloadDefinition.create(_parse_payload_piece_ref(payload_value["piece_ref"], registry_by_numeric, registry_by_string, numeric_id, status), status)
			elif kind_id == AbilityEffectDefinition.Kind.ATTACH:
				var payload_value: Dictionary = _dictionary_field(effect_value, "attach", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_PAYLOAD)
				if not status.is_ok() or not _require_exact_keys(payload_value, ATTACH_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_PAYLOAD): return false
				attach_payload = AttachPayloadDefinition.create(
					_int_field(payload_value, "owner_role_id", status, KIND, numeric_id, ContentStatus.FieldId.OWNER_ROLE_ID),
					_int_field(payload_value, "anchor_mode_id", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_ANCHOR_MODE_ID),
					FixVec2.from_raw(_int_field(payload_value, "anchor_offset_x_raw", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_ANCHOR_OFFSET_X_RAW), _int_field(payload_value, "anchor_offset_y_raw", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_ANCHOR_OFFSET_Y_RAW)),
					_int_field(payload_value, "attach_distance_raw", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_DISTANCE_RAW),
					_int_field(payload_value, "inertia_basis_points", status, KIND, numeric_id, ContentStatus.FieldId.INERTIA_BASIS_POINTS),
					_int_field(payload_value, "duration_turns", status, KIND, numeric_id, ContentStatus.FieldId.DURATION_TURNS), status)
				if attach_payload.is_initialized() and attach_payload.anchor_mode_id() == AttachPayloadDefinition.AnchorMode.CONTACT_POINT and trigger_id != BattleTriggerId.Value.ON_HIT_DEAL and trigger_id != BattleTriggerId.Value.ON_HIT_TAKE and trigger_id != BattleTriggerId.Value.ON_ALLY_COLLIDE:
					status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ATTACH_PAYLOAD); return false
			elif kind_id == AbilityEffectDefinition.Kind.SPAWN_ZONE:
				var payload_value: Dictionary = _dictionary_field(effect_value, "zone", status, KIND, numeric_id, ContentStatus.FieldId.ZONE_PAYLOAD)
				if not status.is_ok() or not _require_exact_keys(payload_value, ZONE_PAYLOAD_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.ZONE_PAYLOAD): return false
				var raw_vertices: Array = _array_field(payload_value, "vertices", status, KIND, numeric_id, ContentStatus.FieldId.VERTICES)
				var vertices: Array[FixVec2] = _parse_vertices(raw_vertices, KIND, numeric_id, ContentStatus.FieldId.VERTICES, status)
				zone_payload = ZoneSpawnPayloadDefinition.create(
					_int_field(payload_value, "flags", status, KIND, numeric_id, ContentStatus.FieldId.FLAGS),
					_int_field(payload_value, "friction_multiplier_raw", status, KIND, numeric_id, ContentStatus.FieldId.FRICTION_MULTIPLIER_RAW),
					FixVec2.from_raw(_int_field(payload_value, "acceleration_x_raw", status, KIND, numeric_id, ContentStatus.FieldId.ACCELERATION_X_RAW), _int_field(payload_value, "acceleration_y_raw", status, KIND, numeric_id, ContentStatus.FieldId.ACCELERATION_Y_RAW)),
					FixVec2.from_raw(_int_field(payload_value, "offset_x_raw", status, KIND, numeric_id, ContentStatus.FieldId.OFFSET_X_RAW), _int_field(payload_value, "offset_y_raw", status, KIND, numeric_id, ContentStatus.FieldId.OFFSET_Y_RAW)),
					vertices, _int_field(payload_value, "duration_turns", status, KIND, numeric_id, ContentStatus.FieldId.DURATION_TURNS), status)
			var effect: AbilityEffectDefinition = AbilityEffectDefinition.create(
				kind_id, selector,
				_int_field(effect_value, "value_a", status, KIND, numeric_id, ContentStatus.FieldId.VALUE_A),
				_int_field(effect_value, "value_b", status, KIND, numeric_id, ContentStatus.FieldId.VALUE_B),
				_int_field(effect_value, "operation_id", status, KIND, numeric_id, ContentStatus.FieldId.OPERATION_ID), status, spawn_payload, transform_payload, attach_payload, zone_payload)
			if not status.is_ok(): return false
			if (effect.kind_id() == AbilityEffectDefinition.Kind.APPLY_STATUS or effect.kind_id() == AbilityEffectDefinition.Kind.REMOVE_STATUS) and not status_by_numeric.has(effect.value_a()):
				status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.VALUE_A); return false
			if effect.kind_id() == AbilityEffectDefinition.Kind.APPLY_STATUS and effect.value_b() > (status_by_numeric[effect.value_a()] as StatusDefinition).max_stacks():
				status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.VALUE_B); return false
			effects.append(effect)
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
		var ability: AbilityDefinition = AbilityDefinition.create(id_ref, trigger_id, conditions, effects, status)
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
		var spawnable: bool = _bool_field(record, "spawnable", status, KIND, numeric_id, ContentStatus.FieldId.SPAWNABLE)
		var spawn_faction_mode_id: int = _int_field(record, "spawn_faction_mode_id", status, KIND, numeric_id, ContentStatus.FieldId.SPAWN_FACTION_MODE_ID)
		var expire_kind_id: int = _int_field(record, "expire_kind_id", status, KIND, numeric_id, ContentStatus.FieldId.EXPIRE_KIND_ID)
		var expire_value: int = _int_field(record, "expire_value", status, KIND, numeric_id, ContentStatus.FieldId.EXPIRE_VALUE)
		var attach_anchor_mode_id: int = _int_field(record, "attach_anchor_mode_id", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_ANCHOR_MODE_ID)
		var attach_anchor_offset: FixVec2 = FixVec2.from_raw(
			_int_field(record, "attach_anchor_offset_x_raw", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_ANCHOR_OFFSET_X_RAW),
			_int_field(record, "attach_anchor_offset_y_raw", status, KIND, numeric_id, ContentStatus.FieldId.ATTACH_ANCHOR_OFFSET_Y_RAW))
		if not status.is_ok(): return false
		var raw_tags: Array = _array_field(record, "tag_refs", status, KIND, numeric_id, ContentStatus.FieldId.TAG_REFS)
		if not status.is_ok(): return false
		if raw_tags.size() > ContentLimits.PIECE_TAG_REFS_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.TAG_REFS); return false
		var tag_refs: Array[ContentIdRef] = []; var seen_tags: Dictionary = {}
		for raw_tag: Variant in raw_tags:
			if typeof(raw_tag) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.TAG_REFS); return false
			var tag_value: Dictionary = raw_tag as Dictionary
			if not _require_exact_keys(tag_value, REF_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.TAG_REFS): return false
			var tag_numeric_id: int = _int_field(tag_value, "numeric_id", status, KIND, numeric_id, ContentStatus.FieldId.TAG_REFS)
			var tag_string_id: String = _string_field(tag_value, "id", status, KIND, numeric_id, ContentStatus.FieldId.TAG_REFS)
			var tag_entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.TAG, tag_numeric_id, tag_string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.TAG_REFS)
			if not status.is_ok() or seen_tags.has(tag_numeric_id):
				if status.is_ok(): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.TAG_REFS)
				return false
			seen_tags[tag_numeric_id] = true; tag_refs.append(ContentIdRef.create(tag_entry.numeric_id(), tag_entry.string_id(), status))
		tag_refs.sort_custom(_ref_less)

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
		var piece: PieceDefinition = PieceDefinition.create(id_ref, has_turn, destructible, transformable, counts_for_victory, is_token, spawnable, spawn_faction_mode_id, expire_kind_id, expire_value, attach_anchor_mode_id, attach_anchor_offset, tag_refs, levels, status)
		if not status.is_ok(): return false
		pieces_out.append(piece)
		piece_by_numeric[numeric_id] = piece
		string_ids[string_id] = true
	pieces_out.sort_custom(_piece_less)
	return true


static func _parse_modifier(raw: Variant, kind: int, record_id: int, status: ContentStatus) -> StatusModifierDefinition:
	if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, kind, record_id, ContentStatus.FieldId.MODIFIERS); return StatusModifierDefinition.new()
	var value: Dictionary = raw as Dictionary
	if not _require_exact_keys(value, MODIFIER_KEYS, status, kind, record_id, ContentStatus.FieldId.MODIFIERS): return StatusModifierDefinition.new()
	return StatusModifierDefinition.create(
		_int_field(value, "kind_id", status, kind, record_id, ContentStatus.FieldId.MODIFIER_KIND_ID),
		_int_field(value, "operation_id", status, kind, record_id, ContentStatus.FieldId.OPERATION_ID),
		_int_field(value, "value_mode_id", status, kind, record_id, ContentStatus.FieldId.VALUE_MODE_ID),
		_int_field(value, "value", status, kind, record_id, ContentStatus.FieldId.VALUE_A), status)


static func _parse_statuses(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, output: Array[StatusDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.STATUSES
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.STATUSES_SCHEMA_VERSION: status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS); var string_ids: Dictionary = {}
	if records.size() > ContentLimits.RECORD_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, STATUS_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID); var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.STATUS, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		if not status.is_ok() or by_numeric.has(numeric_id) or string_ids.has(string_id):
			if status.is_ok(): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, KIND, numeric_id)
			return false
		var raw_modifiers: Array = _array_field(record, "modifiers", status, KIND, numeric_id, ContentStatus.FieldId.MODIFIERS)
		if raw_modifiers.size() > ContentLimits.STATUS_MODIFIERS_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id); return false
		var modifiers: Array[StatusModifierDefinition] = []
		for raw_modifier: Variant in raw_modifiers:
			modifiers.append(_parse_modifier(raw_modifier, KIND, numeric_id, status))
			if not status.is_ok(): return false
		var id_ref: ContentIdRef = ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)
		var definition: StatusDefinition = StatusDefinition.create(id_ref,
			_int_field(record, "stack_policy_id", status, KIND, numeric_id, ContentStatus.FieldId.STACK_POLICY_ID), _int_field(record, "max_stacks", status, KIND, numeric_id, ContentStatus.FieldId.MAX_STACKS),
			_int_field(record, "duration_kind_id", status, KIND, numeric_id, ContentStatus.FieldId.DURATION_KIND_ID), _int_field(record, "default_duration", status, KIND, numeric_id, ContentStatus.FieldId.DEFAULT_DURATION),
			_int_field(record, "max_duration", status, KIND, numeric_id, ContentStatus.FieldId.MAX_DURATION), _int_field(record, "refresh_policy_id", status, KIND, numeric_id, ContentStatus.FieldId.REFRESH_POLICY_ID),
			_bool_field(record, "merge_sources", status, KIND, numeric_id, ContentStatus.FieldId.MERGE_SOURCES), modifiers, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true
	output.sort_custom(func(a: StatusDefinition, b: StatusDefinition) -> bool: return a.numeric_id() < b.numeric_id()); return true


static func _parse_synergies(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, output: Array[SynergyDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.SYNERGIES
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.SYNERGIES_SCHEMA_VERSION: status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS); var string_ids: Dictionary = {}; var tag_ids: Dictionary = {}
	if records.size() > ContentLimits.RECORD_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, SYNERGY_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID); var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.SYNERGY, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var tag_value: Dictionary = _dictionary_field(record, "tag_ref", status, KIND, numeric_id, ContentStatus.FieldId.TAG_REF)
		if not _require_exact_keys(tag_value, REF_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.TAG_REF): return false
		var tag_numeric_id: int = _int_field(tag_value, "numeric_id", status, KIND, numeric_id, ContentStatus.FieldId.TAG_REF); var tag_string_id: String = _string_field(tag_value, "id", status, KIND, numeric_id, ContentStatus.FieldId.TAG_REF)
		var tag_entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.TAG, tag_numeric_id, tag_string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.TAG_REF)
		if not status.is_ok() or by_numeric.has(numeric_id) or string_ids.has(string_id) or tag_ids.has(tag_numeric_id):
			if status.is_ok(): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, KIND, numeric_id)
			return false
		var raw_tiers: Array = _array_field(record, "tiers", status, KIND, numeric_id, ContentStatus.FieldId.TIERS)
		if raw_tiers.size() > ContentLimits.SYNERGY_TIERS_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id); return false
		var tiers: Array[SynergyTierDefinition] = []
		for raw_tier: Variant in raw_tiers:
			if typeof(raw_tier) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id); return false
			var tier_value: Dictionary = raw_tier as Dictionary
			if not _require_exact_keys(tier_value, TIER_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.TIERS): return false
			var raw_modifiers: Array = _array_field(tier_value, "modifiers", status, KIND, numeric_id, ContentStatus.FieldId.MODIFIERS); var modifiers: Array[StatusModifierDefinition] = []
			if raw_modifiers.size() > ContentLimits.SYNERGY_TIER_MODIFIERS_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id); return false
			for raw_modifier: Variant in raw_modifiers: modifiers.append(_parse_modifier(raw_modifier, KIND, numeric_id, status))
			tiers.append(SynergyTierDefinition.create(_int_field(tier_value, "min_count", status, KIND, numeric_id, ContentStatus.FieldId.MIN_COUNT), modifiers, status))
			if not status.is_ok(): return false
		var id_ref: ContentIdRef = ContentIdRef.create(entry.numeric_id(), entry.string_id(), status); var tag_ref: ContentIdRef = ContentIdRef.create(tag_entry.numeric_id(), tag_entry.string_id(), status)
		var definition: SynergyDefinition = SynergyDefinition.create(id_ref, tag_ref, _int_field(record, "tag_kind_id", status, KIND, numeric_id, ContentStatus.FieldId.TAG_KIND_ID), _int_field(record, "scope_id", status, KIND, numeric_id, ContentStatus.FieldId.SCOPE_ID), _int_field(record, "count_cap", status, KIND, numeric_id, ContentStatus.FieldId.COUNT_CAP), tiers, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true; tag_ids[tag_numeric_id] = true
	output.sort_custom(func(a: SynergyDefinition, b: SynergyDefinition) -> bool: return a.numeric_id() < b.numeric_id()); return true


static func _parse_ref_for_namespace(raw: Variant, namespace_id: int, document_kind_id: int, record_numeric_id: int, field_id: int, registry_by_numeric: Dictionary, registry_by_string: Dictionary, target_by_numeric: Dictionary, status: ContentStatus) -> ContentIdRef:
	if typeof(raw) != TYPE_DICTIONARY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.REFERENCE_RESOLVE, document_kind_id, record_numeric_id, field_id); return ContentIdRef.new()
	var value: Dictionary = raw as Dictionary
	if not _require_exact_keys(value, REF_KEYS, status, document_kind_id, record_numeric_id, field_id): return ContentIdRef.new()
	var numeric_id: int = _int_field(value, "numeric_id", status, document_kind_id, record_numeric_id, field_id)
	var string_id: String = _string_field(value, "id", status, document_kind_id, record_numeric_id, field_id)
	var entry: ContentRegistryEntry = _active_registry_pair(namespace_id, numeric_id, string_id, registry_by_numeric, registry_by_string, status, document_kind_id, field_id)
	if not status.is_ok(): return ContentIdRef.new()
	if not target_by_numeric.has(numeric_id):
		status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE, document_kind_id, record_numeric_id, field_id); return ContentIdRef.new()
	return ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)


static func _parse_enemies(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, piece_by_numeric: Dictionary, ability_by_numeric: Dictionary, output: Array[EnemyDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.ENEMIES
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.ENEMIES_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.RECORD_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
	var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, ENEMY_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.ENEMY, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var base_ref: ContentIdRef = _parse_ref_for_namespace(record["base_piece_ref"], ContentIds.Namespace.PIECE, KIND, numeric_id, ContentStatus.FieldId.BASE_PIECE_REF, registry_by_numeric, registry_by_string, piece_by_numeric, status)
		var ai_grade_id: int = _int_field(record, "ai_grade_id", status, KIND, numeric_id, ContentStatus.FieldId.AI_GRADE_ID)
		if not AiGrade.is_known(ai_grade_id): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.AI_GRADE_ID); return false
		var override_value: Dictionary = _dictionary_field(record, "override", status, KIND, numeric_id, ContentStatus.FieldId.OVERRIDE)
		if not status.is_ok(): return false
		for key: Variant in override_value.keys():
			if typeof(key) != TYPE_STRING or not ENEMY_OVERRIDE_KEYS.has(String(key)):
				status.fail(ContentStatus.Code.UNKNOWN_KEY, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.OVERRIDE); return false
		var mask: int = 0
		var max_hp: int = 0; var attack: int = 0; var speed_stat: int = 0; var mass_raw: int = 0; var radius_raw: int = 0; var friction_raw: int = 0; var critical: int = 0
		if override_value.has("max_hp"): mask |= EnemyOverrideDefinition.MAX_HP_BIT; max_hp = _int_field(override_value, "max_hp", status, KIND, numeric_id, ContentStatus.FieldId.MAX_HP)
		if override_value.has("attack"): mask |= EnemyOverrideDefinition.ATTACK_BIT; attack = _int_field(override_value, "attack", status, KIND, numeric_id, ContentStatus.FieldId.ATTACK)
		if override_value.has("speed_stat"): mask |= EnemyOverrideDefinition.SPEED_STAT_BIT; speed_stat = _int_field(override_value, "speed_stat", status, KIND, numeric_id, ContentStatus.FieldId.SPEED_STAT)
		if override_value.has("mass_raw"): mask |= EnemyOverrideDefinition.MASS_RAW_BIT; mass_raw = _int_field(override_value, "mass_raw", status, KIND, numeric_id, ContentStatus.FieldId.MASS_RAW)
		if override_value.has("radius_raw"): mask |= EnemyOverrideDefinition.RADIUS_RAW_BIT; radius_raw = _int_field(override_value, "radius_raw", status, KIND, numeric_id, ContentStatus.FieldId.RADIUS_RAW)
		if override_value.has("friction_multiplier_raw"): mask |= EnemyOverrideDefinition.FRICTION_RAW_BIT; friction_raw = _int_field(override_value, "friction_multiplier_raw", status, KIND, numeric_id, ContentStatus.FieldId.FRICTION_MULTIPLIER_RAW)
		if override_value.has("critical_basis_points"): mask |= EnemyOverrideDefinition.CRITICAL_BIT; critical = _int_field(override_value, "critical_basis_points", status, KIND, numeric_id, ContentStatus.FieldId.CRITICAL_BASIS_POINTS)
		var refs: Array[ContentIdRef] = []
		if override_value.has("ability_refs"):
			mask |= EnemyOverrideDefinition.ABILITY_REFS_BIT
			var raw_refs: Array = _array_field(override_value, "ability_refs", status, KIND, numeric_id, ContentStatus.FieldId.ABILITY_REFS)
			if raw_refs.size() > ContentLimits.ABILITY_REFS_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ABILITY_REFS); return false
			var seen_refs: Dictionary = {}
			for raw_ref: Variant in raw_refs:
				var ref: ContentIdRef = _parse_ref_for_namespace(raw_ref, ContentIds.Namespace.ABILITY, KIND, numeric_id, ContentStatus.FieldId.ABILITY_REFS, registry_by_numeric, registry_by_string, ability_by_numeric, status)
				if not status.is_ok(): return false
				if seen_refs.has(ref.numeric_id()): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.ABILITY_REFS); return false
				seen_refs[ref.numeric_id()] = true; refs.append(ref)
			refs.sort_custom(_ref_less)
		var override_definition: EnemyOverrideDefinition = EnemyOverrideDefinition.create(mask, max_hp, attack, speed_stat, mass_raw, radius_raw, friction_raw, critical, refs, status)
		if not status.is_ok() or by_numeric.has(numeric_id) or string_ids.has(string_id):
			if status.is_ok(): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, KIND, numeric_id)
			return false
		var id_ref: ContentIdRef = ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)
		var definition: EnemyDefinition = EnemyDefinition.create(id_ref, base_ref, ai_grade_id, override_definition, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true
	output.sort_custom(_enemy_less)
	return true


static func _parse_slots(raw_slots: Array, kind: int, numeric_id: int, field_id: int, status: ContentStatus) -> Array[MapSlotDefinition]:
	var result: Array[MapSlotDefinition] = []
	if raw_slots.size() < ContentLimits.MAP_SLOT_MIN_COUNT or raw_slots.size() > ContentLimits.MAP_SLOT_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.MAP_VALIDATE, kind, numeric_id, field_id); return result
	for raw: Variant in raw_slots:
		result.append(MapSlotDefinition.create(_parse_point(raw, kind, numeric_id, field_id, status), status))
		if not status.is_ok(): return []
	return result


static func _parse_maps(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, catalog_max_radius_raw: int, output: Array[MapDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.MAPS
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.MAPS_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.RECORD_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
	if not records.is_empty() and not SimLimits.is_radius_valid(catalog_max_radius_raw): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, KIND); return false
	var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, MAP_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.MAP, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var boundary_vertices: Array[FixVec2] = _parse_vertices(_array_field(record, "boundary_vertices", status, KIND, numeric_id, ContentStatus.FieldId.BOUNDARY_VERTICES), KIND, numeric_id, ContentStatus.FieldId.BOUNDARY_VERTICES, status)
		var player_slots: Array[MapSlotDefinition] = _parse_slots(_array_field(record, "player_slots", status, KIND, numeric_id, ContentStatus.FieldId.PLAYER_SLOTS), KIND, numeric_id, ContentStatus.FieldId.PLAYER_SLOTS, status)
		var enemy_slots: Array[MapSlotDefinition] = _parse_slots(_array_field(record, "enemy_slots", status, KIND, numeric_id, ContentStatus.FieldId.ENEMY_SLOTS), KIND, numeric_id, ContentStatus.FieldId.ENEMY_SLOTS, status)
		var raw_zones: Array = _array_field(record, "zones", status, KIND, numeric_id, ContentStatus.FieldId.ZONES)
		var obstacles: Array = _array_field(record, "obstacles", status, KIND, numeric_id, ContentStatus.FieldId.OBSTACLES)
		if not status.is_ok(): return false
		if raw_zones.size() > ContentLimits.MAP_ZONE_MAX_COUNT or not obstacles.is_empty(): status.fail(ContentStatus.Code.CATALOG_LIMIT if raw_zones.size() > ContentLimits.MAP_ZONE_MAX_COUNT else ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ZONES if raw_zones.size() > ContentLimits.MAP_ZONE_MAX_COUNT else ContentStatus.FieldId.OBSTACLES); return false
		var zones: Array[MapZoneDefinition] = []; var local_ids: Dictionary = {}
		for raw_zone: Variant in raw_zones:
			if typeof(raw_zone) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ZONES); return false
			var value: Dictionary = raw_zone as Dictionary
			if not _require_exact_keys(value, MAP_ZONE_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.ZONES): return false
			var local_id: int = _int_field(value, "local_id", status, KIND, numeric_id, ContentStatus.FieldId.LOCAL_ID)
			if local_ids.has(local_id): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.MAP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.LOCAL_ID); return false
			local_ids[local_id] = true
			var vertices: Array[FixVec2] = _parse_vertices(_array_field(value, "vertices", status, KIND, numeric_id, ContentStatus.FieldId.VERTICES), KIND, numeric_id, ContentStatus.FieldId.VERTICES, status)
			zones.append(MapZoneDefinition.create(local_id, _int_field(value, "flags", status, KIND, numeric_id, ContentStatus.FieldId.FLAGS), _int_field(value, "friction_multiplier_raw", status, KIND, numeric_id, ContentStatus.FieldId.FRICTION_MULTIPLIER_RAW), FixVec2.from_raw(_int_field(value, "acceleration_x_raw", status, KIND, numeric_id, ContentStatus.FieldId.ACCELERATION_X_RAW), _int_field(value, "acceleration_y_raw", status, KIND, numeric_id, ContentStatus.FieldId.ACCELERATION_Y_RAW)), vertices, status))
			if not status.is_ok(): return false
		zones.sort_custom(_map_zone_less)
		if by_numeric.has(numeric_id) or string_ids.has(string_id): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CATALOG_BUILD, KIND, numeric_id); return false
		var id_ref: ContentIdRef = ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)
		var definition: MapDefinition = MapDefinition.create(id_ref, _int_field(record, "boundary_type_id", status, KIND, numeric_id, ContentStatus.FieldId.BOUNDARY_TYPE_ID), boundary_vertices, _int_field(record, "deploy_count", status, KIND, numeric_id, ContentStatus.FieldId.DEPLOY_COUNT), player_slots, enemy_slots, zones, status)
		if not status.is_ok(): return false
		var sim_status := SimStatus.new()
		if not MapGeometryValidator.validate(definition, catalog_max_radius_raw, sim_status):
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.PLAYER_SLOTS); return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true
	output.sort_custom(_map_less)
	return true


static func _parse_empty_run_document(root: Dictionary, kind: int, expected_schema: int, status: ContentStatus) -> bool:
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, kind): return false
	if _int_field(root, "schema_version", status, kind, 0, ContentStatus.FieldId.SCHEMA_VERSION) != expected_schema:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, kind, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, kind, 0, ContentStatus.FieldId.RECORDS)
	if not status.is_ok(): return false
	if not records.is_empty():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, kind, 0, ContentStatus.FieldId.RECORDS); return false
	return true


static func _parse_run_effect(raw: Variant, document_kind_id: int, record_numeric_id: int, allowed_kinds: Array, consumable_by_numeric: Dictionary, status: ContentStatus) -> RunEffectDefinition:
	if typeof(raw) != TYPE_DICTIONARY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.RUN_EFFECT_VALIDATE, document_kind_id, record_numeric_id, ContentStatus.FieldId.EFFECT)
		return RunEffectDefinition.new()
	var value: Dictionary = raw as Dictionary
	if not _require_exact_keys(value, RUN_EFFECT_KEYS, status, document_kind_id, record_numeric_id, ContentStatus.FieldId.EFFECT): return RunEffectDefinition.new()
	var kind_id: int = _int_field(value, "kind_id", status, document_kind_id, record_numeric_id, ContentStatus.FieldId.EFFECT_KIND_ID)
	var primary_numeric_id: int = _int_field(value, "primary_numeric_id", status, document_kind_id, record_numeric_id, ContentStatus.FieldId.PRIMARY_NUMERIC_ID)
	var amount: int = _int_field(value, "amount", status, document_kind_id, record_numeric_id, ContentStatus.FieldId.AMOUNT)
	if not status.is_ok(): return RunEffectDefinition.new()
	if not allowed_kinds.has(kind_id):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.RUN_EFFECT_VALIDATE, document_kind_id, record_numeric_id, ContentStatus.FieldId.EFFECT_KIND_ID)
		return RunEffectDefinition.new()
	if kind_id == RunEffectKind.Value.GAIN_CONSUMABLE:
		if not consumable_by_numeric.has(primary_numeric_id) or amount > (consumable_by_numeric[primary_numeric_id] as ConsumableDefinition).max_stack():
			status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.RUN_EFFECT_VALIDATE, document_kind_id, record_numeric_id, ContentStatus.FieldId.PRIMARY_NUMERIC_ID)
			return RunEffectDefinition.new()
	return RunEffectDefinition.create(kind_id, primary_numeric_id, amount, status)


static func _parse_relics(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, output: Array[RelicDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.RELICS
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.RELICS_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.RELIC_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.RELIC_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.RELIC_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS); return false
	var previous_id: int = 0; var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.RELIC_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, RELIC_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		if numeric_id <= previous_id or by_numeric.has(numeric_id) or string_ids.has(string_id): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.RELIC_VALIDATE, KIND, numeric_id); return false
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.RELIC, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var effect: RunEffectDefinition = _parse_run_effect(record["effect"], KIND, numeric_id, [RunEffectKind.Value.VICTORY_GOLD_BONUS], {}, status)
		var definition: RelicDefinition = RelicDefinition.create(ContentIdRef.create(entry.numeric_id(), entry.string_id(), status), effect, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true; previous_id = numeric_id
	output.sort_custom(_relic_less)
	return true


static func _parse_consumables(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, output: Array[ConsumableDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.CONSUMABLES
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.CONSUMABLES_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.CONSUMABLE_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.CONSUMABLE_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.CONSUMABLE_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS); return false
	var previous_id: int = 0; var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.CONSUMABLE_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, CONSUMABLE_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		if numeric_id <= previous_id or by_numeric.has(numeric_id) or string_ids.has(string_id): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.CONSUMABLE_VALIDATE, KIND, numeric_id); return false
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.CONSUMABLE, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var effect: RunEffectDefinition = _parse_run_effect(record["effect"], KIND, numeric_id, [RunEffectKind.Value.RECOVER_LIFE], {}, status)
		var definition: ConsumableDefinition = ConsumableDefinition.create(ContentIdRef.create(entry.numeric_id(), entry.string_id(), status), _int_field(record, "max_stack", status, KIND, numeric_id, ContentStatus.FieldId.MAX_STACK_COUNT), _int_field(record, "use_phase_id", status, KIND, numeric_id, ContentStatus.FieldId.USE_PHASE_ID), effect, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true; previous_id = numeric_id
	output.sort_custom(_consumable_less)
	return true


static func _parse_shops(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, relic_by_numeric: Dictionary, consumable_by_numeric: Dictionary, output: Array[ShopDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.SHOPS
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.SHOPS_SCHEMA_VERSION: status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.SHOP_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.SHOP_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.SHOP_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS); return false
	var previous_id: int = 0; var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.SHOP_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, SHOP_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		if numeric_id <= previous_id or by_numeric.has(numeric_id) or string_ids.has(string_id): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.SHOP_VALIDATE, KIND, numeric_id); return false
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.SHOP, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var raw_offers: Array = _array_field(record, "offers", status, KIND, numeric_id, ContentStatus.FieldId.OFFERS)
		if raw_offers.is_empty() or raw_offers.size() > ContentLimits.SHOP_OFFER_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.SHOP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.OFFERS); return false
		var offers: Array[ShopOfferDefinition] = []
		for index: int in range(raw_offers.size()):
			if typeof(raw_offers[index]) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.SHOP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.OFFERS); return false
			var offer_value: Dictionary = raw_offers[index] as Dictionary
			if not _require_exact_keys(offer_value, SHOP_OFFER_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.OFFERS): return false
			var offer_id: int = _int_field(offer_value, "offer_id", status, KIND, numeric_id, ContentStatus.FieldId.OFFER_ID)
			var item_kind_id: int = _int_field(offer_value, "item_kind_id", status, KIND, numeric_id, ContentStatus.FieldId.ITEM_KIND_ID)
			var target_namespace: int = ContentIds.Namespace.RELIC if item_kind_id == RunShopItemKind.Value.RELIC else ContentIds.Namespace.CONSUMABLE
			var target_map: Dictionary = relic_by_numeric if item_kind_id == RunShopItemKind.Value.RELIC else consumable_by_numeric
			if not RunShopItemKind.is_valid(item_kind_id): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.SHOP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ITEM_KIND_ID); return false
			var item_ref: ContentIdRef = _parse_ref_for_namespace(offer_value["item_ref"], target_namespace, KIND, numeric_id, ContentStatus.FieldId.ITEM_REF, registry_by_numeric, registry_by_string, target_map, status)
			var count: int = _int_field(offer_value, "count", status, KIND, numeric_id, ContentStatus.FieldId.COUNT)
			if item_kind_id == RunShopItemKind.Value.RELIC and count != 1: status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.SHOP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.COUNT); return false
			if item_kind_id == RunShopItemKind.Value.CONSUMABLE and (count < 1 or count > (target_map[item_ref.numeric_id()] as ConsumableDefinition).max_stack()): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.SHOP_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.COUNT); return false
			offers.append(ShopOfferDefinition.create(offer_id, item_kind_id, item_ref, count, _int_field(offer_value, "cost", status, KIND, numeric_id, ContentStatus.FieldId.COST), status))
			if not status.is_ok(): return false
		var definition: ShopDefinition = ShopDefinition.create(ContentIdRef.create(entry.numeric_id(), entry.string_id(), status), offers, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true; previous_id = numeric_id
	output.sort_custom(_shop_less)
	return true


static func _parse_events(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, consumable_by_numeric: Dictionary, output: Array[EventDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.EVENTS
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.EVENTS_SCHEMA_VERSION: status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.EVENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.EVENT_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.EVENT_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS); return false
	var previous_id: int = 0; var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.EVENT_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, EVENT_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		if numeric_id <= previous_id or by_numeric.has(numeric_id) or string_ids.has(string_id): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.EVENT_VALIDATE, KIND, numeric_id); return false
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.EVENT, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var raw_options: Array = _array_field(record, "options", status, KIND, numeric_id, ContentStatus.FieldId.OPTIONS)
		if raw_options.is_empty() or raw_options.size() > ContentLimits.EVENT_OPTION_MAX_COUNT: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.EVENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.OPTIONS); return false
		var options: Array[EventOptionDefinition] = []
		for index: int in range(raw_options.size()):
			if typeof(raw_options[index]) != TYPE_DICTIONARY: status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.EVENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.OPTIONS); return false
			var option_value: Dictionary = raw_options[index] as Dictionary
			if not _require_exact_keys(option_value, EVENT_OPTION_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.OPTIONS): return false
			var raw_effects: Array = _array_field(option_value, "effects", status, KIND, numeric_id, ContentStatus.FieldId.EFFECTS)
			if raw_effects.size() > 1: status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.EVENT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.EFFECTS); return false
			var effect: RunEffectDefinition = null
			if raw_effects.size() == 1: effect = _parse_run_effect(raw_effects[0], KIND, numeric_id, [RunEffectKind.Value.GAIN_GOLD, RunEffectKind.Value.GAIN_CONSUMABLE], consumable_by_numeric, status)
			options.append(EventOptionDefinition.create(_int_field(option_value, "option_id", status, KIND, numeric_id, ContentStatus.FieldId.OPTION_ID), effect, status))
			if not status.is_ok(): return false
		var definition: EventDefinition = EventDefinition.create(ContentIdRef.create(entry.numeric_id(), entry.string_id(), status), options, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true; previous_id = numeric_id
	output.sort_custom(_event_less)
	return true


static func _parse_reward_profiles(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, piece_by_numeric: Dictionary, status_by_numeric: Dictionary, output: Array[RewardProfileDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.REWARD_PROFILES
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.REWARD_PROFILES_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.REWARD_PROFILE_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS); return false
	var string_ids: Dictionary = {}; var previous_id: int = 0
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY:
			status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, REWARD_PROFILE_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		if numeric_id <= previous_id:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.NUMERIC_ID); return false
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.REWARD_PROFILE, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var victory_gold: int = _int_field(record, "victory_gold", status, KIND, numeric_id, ContentStatus.FieldId.VICTORY_GOLD)
		var choice_count: int = _int_field(record, "recruit_choice_count", status, KIND, numeric_id, ContentStatus.FieldId.RECRUIT_CHOICE_COUNT)
		var raw_pool: Array = _array_field(record, "recruit_pool_refs", status, KIND, numeric_id, ContentStatus.FieldId.RECRUIT_POOL_REFS)
		if not status.is_ok(): return false
		if raw_pool.is_empty() or raw_pool.size() > ContentLimits.REWARD_RECRUIT_POOL_MAX:
			status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.RECRUIT_POOL_REFS); return false
		var pool_refs: Array[ContentIdRef] = []
		for raw_ref: Variant in raw_pool:
			var ref: ContentIdRef = _parse_ref_for_namespace(raw_ref, ContentIds.Namespace.PIECE, KIND, numeric_id, ContentStatus.FieldId.RECRUIT_POOL_REFS, registry_by_numeric, registry_by_string, piece_by_numeric, status)
			if not status.is_ok(): return false
			var piece: PieceDefinition = piece_by_numeric[ref.numeric_id()]
			if piece.is_token() or piece.level_count() < 1:
				status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.RECRUIT_POOL_REFS); return false
			pool_refs.append(ref)
		var revenge_ref: ContentIdRef = _parse_ref_for_namespace(record["revenge_status_ref"], ContentIds.Namespace.STATUS, KIND, numeric_id, ContentStatus.FieldId.REVENGE_STATUS_REF, registry_by_numeric, registry_by_string, status_by_numeric, status)
		if not status.is_ok(): return false
		var revenge_definition: StatusDefinition = status_by_numeric[revenge_ref.numeric_id()]
		if revenge_definition.duration_kind_id() != StatusDefinition.DurationKind.BATTLE or revenge_definition.modifier_count() < 1:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.REVENGE_STATUS_REF); return false
		if by_numeric.has(numeric_id) or string_ids.has(string_id):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, KIND, numeric_id); return false
		var id_ref: ContentIdRef = ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)
		var definition: RewardProfileDefinition = RewardProfileDefinition.create(id_ref, victory_gold, choice_count, pool_refs, revenge_ref, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true; previous_id = numeric_id
	output.sort_custom(_reward_profile_less)
	return true


static func _parse_encounters(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, map_by_numeric: Dictionary, enemy_by_numeric: Dictionary, reward_profile_by_numeric: Dictionary, output: Array[EncounterDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.ENCOUNTERS
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.ENCOUNTERS_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.RECORD_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ENCOUNTER_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS); return false
	var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY:
			status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.ENCOUNTER_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, ENCOUNTER_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.ENCOUNTER, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var node_type_id: int = _int_field(record, "node_type_id", status, KIND, numeric_id, ContentStatus.FieldId.NODE_TYPE_ID)
		var map_ref: ContentIdRef = _parse_ref_for_namespace(record["map_ref"], ContentIds.Namespace.MAP, KIND, numeric_id, ContentStatus.FieldId.MAP_REF, registry_by_numeric, registry_by_string, map_by_numeric, status)
		var raw_enemy_refs: Array = _array_field(record, "enemy_refs", status, KIND, numeric_id, ContentStatus.FieldId.ENEMY_REFS)
		if not status.is_ok(): return false
		if raw_enemy_refs.size() < ContentLimits.ENCOUNTER_ENEMY_MIN_COUNT or raw_enemy_refs.size() > ContentLimits.ENCOUNTER_ENEMY_MAX_COUNT:
			status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ENCOUNTER_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ENEMY_REFS); return false
		var enemy_refs: Array[ContentIdRef] = []
		for raw_ref: Variant in raw_enemy_refs:
			enemy_refs.append(_parse_ref_for_namespace(raw_ref, ContentIds.Namespace.ENEMY, KIND, numeric_id, ContentStatus.FieldId.ENEMY_REFS, registry_by_numeric, registry_by_string, enemy_by_numeric, status))
			if not status.is_ok(): return false
		if map_ref.is_initialized() and (map_by_numeric[map_ref.numeric_id()] as MapDefinition).deploy_count() != enemy_refs.size():
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENCOUNTER_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.ENEMY_REFS); return false
		if by_numeric.has(numeric_id) or string_ids.has(string_id):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.ENCOUNTER_VALIDATE, KIND, numeric_id); return false
		var reward_profile_numeric_id: int = _int_field(record, "reward_profile_numeric_id", status, KIND, numeric_id, ContentStatus.FieldId.REWARD_PROFILE_NUMERIC_ID)
		if not reward_profile_by_numeric.has(reward_profile_numeric_id):
			status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.ENCOUNTER_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.REWARD_PROFILE_NUMERIC_ID); return false
		var id_ref: ContentIdRef = ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)
		var definition: EncounterDefinition = EncounterDefinition.create(id_ref, node_type_id, map_ref, enemy_refs, reward_profile_numeric_id, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true
	output.sort_custom(_encounter_less)
	return true


static func _parse_acts(root: Dictionary, registry_by_numeric: Dictionary, registry_by_string: Dictionary, encounter_by_numeric: Dictionary, shop_by_numeric: Dictionary, event_by_numeric: Dictionary, output: Array[ActDefinition], by_numeric: Dictionary, status: ContentStatus) -> bool:
	const KIND: int = ContentIds.DocumentKind.ACTS
	if not _require_exact_keys(root, RECORD_DOCUMENT_KEYS, status, KIND): return false
	if _int_field(root, "schema_version", status, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION) != ContentIds.ACTS_SCHEMA_VERSION:
		status.fail(ContentStatus.Code.UNSUPPORTED_SCHEMA, ContentStatus.Operation.DOCUMENT_VALIDATE, KIND, 0, ContentStatus.FieldId.SCHEMA_VERSION); return false
	var records: Array = _array_field(root, "records", status, KIND, 0, ContentStatus.FieldId.RECORDS)
	if records.size() > ContentLimits.ACT_MAX_COUNT:
		status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, KIND, 0, ContentStatus.FieldId.RECORDS); return false
	var string_ids: Dictionary = {}
	for raw: Variant in records:
		if typeof(raw) != TYPE_DICTIONARY:
			status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.ACT_VALIDATE, KIND); return false
		var record: Dictionary = raw as Dictionary
		if not _require_exact_keys(record, ACT_KEYS, status, KIND): return false
		var numeric_id: int = _int_field(record, "numeric_id", status, KIND, 0, ContentStatus.FieldId.NUMERIC_ID)
		var string_id: String = _string_field(record, "id", status, KIND, numeric_id, ContentStatus.FieldId.ID)
		var entry: ContentRegistryEntry = _active_registry_pair(ContentIds.Namespace.ACT, numeric_id, string_id, registry_by_numeric, registry_by_string, status, KIND, ContentStatus.FieldId.ID)
		var is_development: bool = _bool_field(record, "is_development", status, KIND, numeric_id, ContentStatus.FieldId.IS_DEVELOPMENT)
		var raw_floors: Array = _array_field(record, "floors", status, KIND, numeric_id, ContentStatus.FieldId.FLOORS)
		if not status.is_ok(): return false
		if raw_floors.size() < ContentLimits.ACT_FLOOR_MIN_COUNT or raw_floors.size() > ContentLimits.ACT_FLOOR_MAX_COUNT:
			status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.FLOORS); return false
		var floors: Array[ActFloorDefinition] = []
		var local_numeric_to_string: Dictionary = {}
		var local_string_to_numeric: Dictionary = {}
		for raw_floor: Variant in raw_floors:
			if typeof(raw_floor) != TYPE_DICTIONARY:
				status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.FLOORS); return false
			var floor_value: Dictionary = raw_floor as Dictionary
			if not _require_exact_keys(floor_value, ACT_FLOOR_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.FLOORS): return false
			var floor_index: int = _int_field(floor_value, "floor_index", status, KIND, numeric_id, ContentStatus.FieldId.FLOOR_INDEX)
			var raw_slots: Array = _array_field(floor_value, "slots", status, KIND, numeric_id, ContentStatus.FieldId.SLOTS)
			if raw_slots.is_empty() or raw_slots.size() > ContentLimits.ACT_SLOT_MAX_COUNT:
				status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.SLOTS); return false
			var slots: Array[ActNodeSlotDefinition] = []
			for raw_slot: Variant in raw_slots:
				if typeof(raw_slot) != TYPE_DICTIONARY:
					status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.SLOTS); return false
				var slot_value: Dictionary = raw_slot as Dictionary
				if not _require_exact_keys(slot_value, ACT_SLOT_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.SLOTS): return false
				var slot_index: int = _int_field(slot_value, "slot_index", status, KIND, numeric_id, ContentStatus.FieldId.SLOT_INDEX)
				var raw_options: Array = _array_field(slot_value, "options", status, KIND, numeric_id, ContentStatus.FieldId.OPTIONS)
				if raw_options.is_empty() or raw_options.size() > ContentLimits.ACT_OPTION_MAX_COUNT:
					status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.OPTIONS); return false
				var options: Array[ActNodeOptionDefinition] = []
				for raw_option: Variant in raw_options:
					if typeof(raw_option) != TYPE_DICTIONARY:
						status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.OPTIONS); return false
					var option_value: Dictionary = raw_option as Dictionary
					if not _require_exact_keys(option_value, ACT_OPTION_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.OPTIONS): return false
					var node_type_id: int = _int_field(option_value, "node_type_id", status, KIND, numeric_id, ContentStatus.FieldId.NODE_TYPE_ID)
					var weight: int = _int_field(option_value, "weight", status, KIND, numeric_id, ContentStatus.FieldId.WEIGHT)
					var raw_content_refs: Array = _array_field(option_value, "content_refs", status, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS)
					if raw_content_refs.size() > ContentLimits.ACT_CONTENT_REFS_MAX_COUNT:
						status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS); return false
					var content_refs: Array[ActContentRef] = []
					for raw_ref: Variant in raw_content_refs:
						if typeof(raw_ref) != TYPE_DICTIONARY:
							status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS); return false
						var ref_value: Dictionary = raw_ref as Dictionary
						if not _require_exact_keys(ref_value, REF_KEYS, status, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS): return false
						var ref_numeric: int = _int_field(ref_value, "numeric_id", status, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS)
						var ref_string: String = _string_field(ref_value, "id", status, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS)
						var ref: ActContentRef = ActContentRef.create(ref_numeric, ref_string, status)
						if not status.is_ok(): return false
						if node_type_id == RunNodeType.Value.NORMAL_BATTLE or node_type_id == RunNodeType.Value.ELITE_BATTLE or node_type_id == RunNodeType.Value.BOSS:
							if not encounter_by_numeric.has(ref_numeric):
								status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS); return false
							var encounter: EncounterDefinition = encounter_by_numeric[ref_numeric]
							if encounter.string_id() != ref_string or encounter.node_type_id() != node_type_id:
								status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS); return false
						elif node_type_id == RunNodeType.Value.SHOP or node_type_id == RunNodeType.Value.EVENT:
							var target_by_numeric: Dictionary = shop_by_numeric if node_type_id == RunNodeType.Value.SHOP else event_by_numeric
							if not target_by_numeric.has(ref_numeric):
								status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS); return false
							var target_string_id: String = (target_by_numeric[ref_numeric] as ShopDefinition).string_id() if node_type_id == RunNodeType.Value.SHOP else (target_by_numeric[ref_numeric] as EventDefinition).string_id()
							if target_string_id != ref_string:
								status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id, ContentStatus.FieldId.CONTENT_REFS); return false
						content_refs.append(ref)
					content_refs.sort_custom(_act_content_ref_less)
					var option: ActNodeOptionDefinition = ActNodeOptionDefinition.create(node_type_id, weight, content_refs, status)
					if not status.is_ok(): return false
					options.append(option)
				options.sort_custom(_act_option_less)
				var slot: ActNodeSlotDefinition = ActNodeSlotDefinition.create(slot_index, options, status)
				if not status.is_ok(): return false
				slots.append(slot)
			slots.sort_custom(_act_slot_less)
			var floor: ActFloorDefinition = ActFloorDefinition.create(floor_index, slots, status)
			if not status.is_ok(): return false
			floors.append(floor)
		floors.sort_custom(_act_floor_less)
		if by_numeric.has(numeric_id) or string_ids.has(string_id):
			status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.ACT_VALIDATE, KIND, numeric_id); return false
		var id_ref: ContentIdRef = ContentIdRef.create(entry.numeric_id(), entry.string_id(), status)
		var definition: ActDefinition = ActDefinition.create(id_ref, is_development, floors, status)
		if not status.is_ok(): return false
		output.append(definition); by_numeric[numeric_id] = definition; string_ids[string_id] = true
	output.sort_custom(_act_less)
	return true


static func _validate_active_registry_coverage(
		entries: Array[ContentRegistryEntry],
		piece_by_numeric: Dictionary,
		ability_by_numeric: Dictionary,
		status_by_numeric: Dictionary,
		synergy_by_numeric: Dictionary,
		map_by_numeric: Dictionary,
		enemy_by_numeric: Dictionary,
		act_by_numeric: Dictionary,
		encounter_by_numeric: Dictionary,
		relic_by_numeric: Dictionary,
		consumable_by_numeric: Dictionary,
		reward_profile_by_numeric: Dictionary,
		shop_by_numeric: Dictionary,
		event_by_numeric: Dictionary,
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
		elif entry.namespace_id() == ContentIds.Namespace.STATUS:
			if not status_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.STATUSES, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.SYNERGY:
			if not synergy_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.SYNERGIES, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.MAP:
			if not map_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.MAPS, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.ENEMY:
			if not enemy_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.ENEMIES, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.ACT:
			if not act_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.ACTS, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.ENCOUNTER:
			if not encounter_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.ENCOUNTERS, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.REWARD_PROFILE:
			if not reward_profile_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.REWARD_PROFILES, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.RELIC:
			if not relic_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.RELICS, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.CONSUMABLE:
			if not consumable_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.CONSUMABLES, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.SHOP:
			if not shop_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.SHOPS, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.EVENT:
			if not event_by_numeric.has(entry.numeric_id()): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.EVENTS, entry.numeric_id()); return false
		elif entry.namespace_id() == ContentIds.Namespace.TAG:
			pass
		else:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ID_REGISTER, ContentIds.DocumentKind.ID_REGISTRY, entry.numeric_id())
			return false
	return true


static func _validate_dynamic_piece_references(abilities: Array[AbilityDefinition], piece_by_numeric: Dictionary, status: ContentStatus) -> bool:
	for ability: AbilityDefinition in abilities:
		for effect_index: int in range(ability.effect_count()):
			var effect: AbilityEffectDefinition = ability.effect_at(effect_index, status)
			if not status.is_ok(): return false
			var piece_ref: ContentIdRef = ContentIdRef.new()
			var requires_spawnable: bool = false
			if effect.kind_id() == AbilityEffectDefinition.Kind.SPAWN_PIECE or effect.kind_id() == AbilityEffectDefinition.Kind.SPAWN_PROJECTILE:
				piece_ref = effect.spawn_payload().piece_ref(); requires_spawnable = true
			elif effect.kind_id() == AbilityEffectDefinition.Kind.TRANSFORM_PIECE:
				piece_ref = effect.transform_payload().piece_ref()
			else:
				continue
			if not piece_by_numeric.has(piece_ref.numeric_id()):
				status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.REFERENCE_RESOLVE, ContentIds.DocumentKind.ABILITIES, ability.numeric_id(), ContentStatus.FieldId.PIECE_REF); return false
			if requires_spawnable and not (piece_by_numeric[piece_ref.numeric_id()] as PieceDefinition).spawnable():
				status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REFERENCE_RESOLVE, ContentIds.DocumentKind.ABILITIES, ability.numeric_id(), ContentStatus.FieldId.SPAWNABLE); return false
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
	var statuses_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.STATUSES, status)
	var synergies_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.SYNERGIES, status)
	var maps_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.MAPS, status)
	var enemies_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.ENEMIES, status)
	var acts_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.ACTS, status)
	var encounters_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.ENCOUNTERS, status)
	var relics_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.RELICS, status)
	var consumables_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.CONSUMABLES, status)
	var reward_profiles_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.REWARD_PROFILES, status)
	var shops_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.SHOPS, status)
	var events_root: Dictionary = _root_for_kind(source_documents, ContentIds.DocumentKind.EVENTS, status)
	if not status.is_ok(): return ContentCatalog.new()

	var registry_entries: Array[ContentRegistryEntry] = []
	var registry_by_numeric: Dictionary = {}
	var registry_by_string: Dictionary = {}
	if not _parse_registry(registry_root, registry_entries, registry_by_numeric, registry_by_string, status): return ContentCatalog.new()
	var statuses: Array[StatusDefinition] = []; var status_by_numeric: Dictionary = {}
	if not _parse_statuses(statuses_root, registry_by_numeric, registry_by_string, statuses, status_by_numeric, status): return ContentCatalog.new()
	var synergies: Array[SynergyDefinition] = []; var synergy_by_numeric: Dictionary = {}
	if not _parse_synergies(synergies_root, registry_by_numeric, registry_by_string, synergies, synergy_by_numeric, status): return ContentCatalog.new()

	var abilities: Array[AbilityDefinition] = []
	var ability_by_numeric: Dictionary = {}
	if not _parse_abilities(abilities_root, registry_by_numeric, registry_by_string, status_by_numeric, abilities, ability_by_numeric, status): return ContentCatalog.new()

	var pieces: Array[PieceDefinition] = []
	var piece_by_numeric: Dictionary = {}
	if not _parse_pieces(pieces_root, registry_by_numeric, registry_by_string, ability_by_numeric, pieces, piece_by_numeric, status): return ContentCatalog.new()
	if not _validate_dynamic_piece_references(abilities, piece_by_numeric, status): return ContentCatalog.new()
	var enemies: Array[EnemyDefinition] = []; var enemy_by_numeric: Dictionary = {}
	if not _parse_enemies(enemies_root, registry_by_numeric, registry_by_string, piece_by_numeric, ability_by_numeric, enemies, enemy_by_numeric, status): return ContentCatalog.new()
	var catalog_max_radius_raw: int = 0
	for piece: PieceDefinition in pieces:
		for level_index: int in range(piece.level_count()):
			var level_status := ContentStatus.new(); var level: PieceLevelDefinition = piece.level_at(level_index, level_status)
			if not level_status.is_ok(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
			catalog_max_radius_raw = maxi(catalog_max_radius_raw, level.radius_raw())
	for enemy: EnemyDefinition in enemies:
		var base_ref: ContentIdRef = enemy.base_piece_ref(); var base_piece: PieceDefinition = piece_by_numeric[base_ref.numeric_id()]
		var level_status := ContentStatus.new(); var base_level: PieceLevelDefinition = base_piece.level_definition(1, level_status)
		var override_definition: EnemyOverrideDefinition = enemy.override_definition()
		var radius_raw: int = override_definition.radius_raw() if override_definition.has_value(EnemyOverrideDefinition.RADIUS_RAW_BIT) else base_level.radius_raw()
		catalog_max_radius_raw = maxi(catalog_max_radius_raw, radius_raw)
	var maps: Array[MapDefinition] = []; var map_by_numeric: Dictionary = {}
	if not _parse_maps(maps_root, registry_by_numeric, registry_by_string, catalog_max_radius_raw, maps, map_by_numeric, status): return ContentCatalog.new()
	var reward_profiles: Array[RewardProfileDefinition] = []; var reward_profile_by_numeric: Dictionary = {}
	if not _parse_reward_profiles(reward_profiles_root, registry_by_numeric, registry_by_string, piece_by_numeric, status_by_numeric, reward_profiles, reward_profile_by_numeric, status): return ContentCatalog.new()
	var encounters: Array[EncounterDefinition] = []; var encounter_by_numeric: Dictionary = {}
	if not _parse_encounters(encounters_root, registry_by_numeric, registry_by_string, map_by_numeric, enemy_by_numeric, reward_profile_by_numeric, encounters, encounter_by_numeric, status): return ContentCatalog.new()
	var relics: Array[RelicDefinition] = []; var relic_by_numeric: Dictionary = {}
	if not _parse_relics(relics_root, registry_by_numeric, registry_by_string, relics, relic_by_numeric, status): return ContentCatalog.new()
	var consumables: Array[ConsumableDefinition] = []; var consumable_by_numeric: Dictionary = {}
	if not _parse_consumables(consumables_root, registry_by_numeric, registry_by_string, consumables, consumable_by_numeric, status): return ContentCatalog.new()
	var shops: Array[ShopDefinition] = []; var shop_by_numeric: Dictionary = {}
	if not _parse_shops(shops_root, registry_by_numeric, registry_by_string, relic_by_numeric, consumable_by_numeric, shops, shop_by_numeric, status): return ContentCatalog.new()
	var events: Array[EventDefinition] = []; var event_by_numeric: Dictionary = {}
	if not _parse_events(events_root, registry_by_numeric, registry_by_string, consumable_by_numeric, events, event_by_numeric, status): return ContentCatalog.new()
	var acts: Array[ActDefinition] = []; var act_by_numeric: Dictionary = {}
	if not _parse_acts(acts_root, registry_by_numeric, registry_by_string, encounter_by_numeric, shop_by_numeric, event_by_numeric, acts, act_by_numeric, status): return ContentCatalog.new()
	if not _validate_active_registry_coverage(registry_entries, piece_by_numeric, ability_by_numeric, status_by_numeric, synergy_by_numeric, map_by_numeric, enemy_by_numeric, act_by_numeric, encounter_by_numeric, relic_by_numeric, consumable_by_numeric, reward_profile_by_numeric, shop_by_numeric, event_by_numeric, status): return ContentCatalog.new()

	var compatibility_bytes: PackedByteArray = ContentCanonicalEncoder.encode(registry_entries, pieces, abilities, statuses, synergies, maps, enemies, acts, encounters, relics, consumables, reward_profiles, shops, events, status)
	if not status.is_ok(): return ContentCatalog.new()
	var sim_status := SimStatus.new()
	var fingerprint: PackedByteArray = SimStateHash.sha256(compatibility_bytes, sim_status)
	if not sim_status.is_ok() or fingerprint.size() != 32:
		status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.SHA256)
		return ContentCatalog.new()
	return ContentCatalog.create(ContentIds.CATALOG_SCHEMA_VERSION, registry_entries, pieces, abilities, statuses, synergies, maps, enemies, acts, encounters, relics, consumables, reward_profiles, shops, events, compatibility_bytes, fingerprint, status)
