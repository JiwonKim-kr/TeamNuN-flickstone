class_name EncounterDamageZoneDefinition
extends RefCounted

var _local_id: int = 0
var _turn_start_damage: int = 0
var _duration_turns: int = 0
var _vertices: Array[FixVec2] = []
var _initialized: bool = false

static func create(local_id: int, turn_start_damage: int, duration_turns: int, vertices: Array[FixVec2], status: ContentStatus) -> EncounterDamageZoneDefinition:
	var result := EncounterDamageZoneDefinition.new()
	if not status.is_ok(): return result
	if local_id <= 0 or local_id > ContentLimits.UINT32_MAX or turn_start_damage <= 0 or duration_turns < 0 or duration_turns > ContentLimits.ZONE_DURATION_MAX_TURNS or vertices.size() < ContentLimits.ZONE_VERTEX_MIN_COUNT or vertices.size() > ContentLimits.ZONE_VERTEX_MAX_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENCOUNTER_VALIDATE, ContentIds.DocumentKind.ENCOUNTERS, 0, ContentStatus.FieldId.DAMAGE_ZONES)
		return result
	var sim_status := SimStatus.new()
	SimPolygon.create(vertices, false, sim_status)
	if not sim_status.is_ok():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.ENCOUNTER_VALIDATE, ContentIds.DocumentKind.ENCOUNTERS, 0, ContentStatus.FieldId.VERTICES)
		return result
	result._local_id = local_id
	result._turn_start_damage = turn_start_damage
	result._duration_turns = duration_turns
	for vertex: FixVec2 in vertices: result._vertices.append(vertex.copy())
	result._initialized = true
	return result

func copy() -> EncounterDamageZoneDefinition:
	if not _initialized: return EncounterDamageZoneDefinition.new()
	var status := ContentStatus.new()
	return create(_local_id, _turn_start_damage, _duration_turns, _vertices, status)

func is_initialized() -> bool: return _initialized
func local_id() -> int: return _local_id
func turn_start_damage() -> int: return _turn_start_damage
func duration_turns() -> int: return _duration_turns
func vertex_count() -> int: return _vertices.size()
func vertices_copy() -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	for vertex: FixVec2 in _vertices: result.append(vertex.copy())
	return result
func vertex_at(index: int, status: ContentStatus) -> FixVec2:
	if index < 0 or index >= _vertices.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENCOUNTERS, 0, ContentStatus.FieldId.VERTICES)
		return FixVec2.zero()
	return _vertices[index].copy()

func sim_template(status: SimStatus) -> SimZone:
	return SimZone.create_unassigned(_vertices, FixMath.ONE_RAW, FixVec2.zero(), status)
