class_name EncounterDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _node_type_id: int = RunNodeType.Value.INVALID
var _map_ref: ContentIdRef
var _enemy_refs: Array[ContentIdRef] = []
var _reward_profile_numeric_id: int = 0
var _damage_zones: Array[EncounterDamageZoneDefinition] = []
var _initialized: bool = false

static func create(id_ref: ContentIdRef, node_type_id: int, map_ref: ContentIdRef, enemy_refs: Array[ContentIdRef], reward_profile_numeric_id: int, damage_zones: Array[EncounterDamageZoneDefinition], status: ContentStatus) -> EncounterDefinition:
	var result := EncounterDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or map_ref == null or not map_ref.is_initialized() or (node_type_id != RunNodeType.Value.NORMAL_BATTLE and node_type_id != RunNodeType.Value.ELITE_BATTLE and node_type_id != RunNodeType.Value.BOSS) or enemy_refs.size() < ContentLimits.ENCOUNTER_ENEMY_MIN_COUNT or enemy_refs.size() > ContentLimits.ENCOUNTER_ENEMY_MAX_COUNT or reward_profile_numeric_id <= 0 or reward_profile_numeric_id > ContentLimits.UINT32_MAX or damage_zones.size() > ContentLimits.ENCOUNTER_DAMAGE_ZONE_MAX_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENCOUNTER_VALIDATE, ContentIds.DocumentKind.ENCOUNTERS, 0)
		return result
	for ref: ContentIdRef in enemy_refs:
		if ref == null or not ref.is_initialized():
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENCOUNTER_VALIDATE, ContentIds.DocumentKind.ENCOUNTERS, id_ref.numeric_id(), ContentStatus.FieldId.ENEMY_REFS)
			return EncounterDefinition.new()
		result._enemy_refs.append(ref.copy())
	var previous_zone_id: int = 0
	for zone: EncounterDamageZoneDefinition in damage_zones:
		if zone == null or not zone.is_initialized() or zone.local_id() <= previous_zone_id:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENCOUNTER_VALIDATE, ContentIds.DocumentKind.ENCOUNTERS, id_ref.numeric_id(), ContentStatus.FieldId.DAMAGE_ZONES)
			return EncounterDefinition.new()
		result._damage_zones.append(zone.copy())
		previous_zone_id = zone.local_id()
	result._id_ref = id_ref.copy()
	result._node_type_id = node_type_id
	result._map_ref = map_ref.copy()
	result._reward_profile_numeric_id = reward_profile_numeric_id
	result._initialized = true
	return result

func copy() -> EncounterDefinition:
	if not _initialized: return EncounterDefinition.new()
	var status := ContentStatus.new()
	return create(_id_ref, _node_type_id, _map_ref, _enemy_refs, _reward_profile_numeric_id, _damage_zones, status)

func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return 0 if not _initialized else _id_ref.numeric_id()
func string_id() -> String: return "" if not _initialized else _id_ref.string_id()
func node_type_id() -> int: return _node_type_id
func map_ref() -> ContentIdRef: return ContentIdRef.new() if not _initialized else _map_ref.copy()
func enemy_ref_count() -> int: return _enemy_refs.size()
func enemy_ref_at(index: int, status: ContentStatus) -> ContentIdRef:
	if not status.is_ok(): return ContentIdRef.new()
	if index < 0 or index >= _enemy_refs.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENCOUNTERS, numeric_id(), ContentStatus.FieldId.ENEMY_REFS)
		return ContentIdRef.new()
	return _enemy_refs[index].copy()
func reward_profile_numeric_id() -> int: return _reward_profile_numeric_id
func damage_zone_count() -> int: return _damage_zones.size()
func damage_zone_at(index: int, status: ContentStatus) -> EncounterDamageZoneDefinition:
	if index < 0 or index >= _damage_zones.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENCOUNTERS, numeric_id(), ContentStatus.FieldId.DAMAGE_ZONES)
		return EncounterDamageZoneDefinition.new()
	return _damage_zones[index].copy()
