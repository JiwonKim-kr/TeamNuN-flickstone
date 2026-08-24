class_name MapDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _boundary_type_id: int = SimWorld.BoundaryType.NONE
var _boundary_vertices: Array[FixVec2] = []
var _deploy_count: int = 0
var _player_slots: Array[MapSlotDefinition] = []
var _enemy_slots: Array[MapSlotDefinition] = []
var _zones: Array[MapZoneDefinition] = []
var _initialized: bool = false


static func create(id_ref: ContentIdRef, boundary_type_id: int, boundary_vertices: Array[FixVec2], deploy_count: int, player_slots: Array[MapSlotDefinition], enemy_slots: Array[MapSlotDefinition], zones: Array[MapZoneDefinition], status: ContentStatus) -> MapDefinition:
	var result := MapDefinition.new()
	if not status.is_ok(): return result
	if (
		id_ref == null or not id_ref.is_initialized()
		or (boundary_type_id != SimWorld.BoundaryType.WALL and boundary_type_id != SimWorld.BoundaryType.KILL)
		or deploy_count < ContentLimits.MAP_DEPLOY_MIN_COUNT or deploy_count > ContentLimits.MAP_DEPLOY_MAX_COUNT
		or player_slots.size() < ContentLimits.MAP_SLOT_MIN_COUNT or player_slots.size() > ContentLimits.MAP_SLOT_MAX_COUNT
		or enemy_slots.size() < ContentLimits.MAP_SLOT_MIN_COUNT or enemy_slots.size() > ContentLimits.MAP_SLOT_MAX_COUNT
		or player_slots.size() < deploy_count or enemy_slots.size() < deploy_count
		or zones.size() > ContentLimits.MAP_ZONE_MAX_COUNT
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, ContentIds.DocumentKind.MAPS, 0)
		return result
	var sim_status := SimStatus.new()
	SimPolygon.create(boundary_vertices, true, sim_status)
	if not sim_status.is_ok():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, ContentIds.DocumentKind.MAPS, id_ref.numeric_id(), ContentStatus.FieldId.BOUNDARY_VERTICES)
		return result
	var previous_local_id: int = 0
	for zone: MapZoneDefinition in zones:
		if zone == null or not zone.is_initialized() or zone.local_id() <= previous_local_id:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE, ContentIds.DocumentKind.MAPS, id_ref.numeric_id(), ContentStatus.FieldId.LOCAL_ID)
			return MapDefinition.new()
		previous_local_id = zone.local_id()
		result._zones.append(zone.copy())
	for slot: MapSlotDefinition in player_slots:
		if slot == null or not slot.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE); return MapDefinition.new()
		result._player_slots.append(slot.copy())
	for slot: MapSlotDefinition in enemy_slots:
		if slot == null or not slot.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.MAP_VALIDATE); return MapDefinition.new()
		result._enemy_slots.append(slot.copy())
	result._id_ref = id_ref.copy()
	result._boundary_type_id = boundary_type_id
	for vertex: FixVec2 in boundary_vertices: result._boundary_vertices.append(vertex.copy())
	result._deploy_count = deploy_count
	result._initialized = true
	return result


func copy() -> MapDefinition:
	if not _initialized: return MapDefinition.new()
	var status := ContentStatus.new()
	return create(_id_ref, _boundary_type_id, _boundary_vertices, _deploy_count, _player_slots, _enemy_slots, _zones, status)


func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return 0 if not _initialized else _id_ref.numeric_id()
func string_id() -> String: return "" if not _initialized else _id_ref.string_id()
func boundary_type_id() -> int: return _boundary_type_id
func boundary_vertices_copy() -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	for vertex: FixVec2 in _boundary_vertices: result.append(vertex.copy())
	return result
func deploy_count() -> int: return _deploy_count
func player_slot_count() -> int: return _player_slots.size()
func enemy_slot_count() -> int: return _enemy_slots.size()
func zone_count() -> int: return _zones.size()
func player_slot_at(index: int, status: ContentStatus) -> MapSlotDefinition:
	if index < 0 or index >= _player_slots.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.MAPS, numeric_id(), ContentStatus.FieldId.PLAYER_SLOTS); return MapSlotDefinition.new()
	return _player_slots[index].copy()
func enemy_slot_at(index: int, status: ContentStatus) -> MapSlotDefinition:
	if index < 0 or index >= _enemy_slots.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.MAPS, numeric_id(), ContentStatus.FieldId.ENEMY_SLOTS); return MapSlotDefinition.new()
	return _enemy_slots[index].copy()
func zone_at(index: int, status: ContentStatus) -> MapZoneDefinition:
	if index < 0 or index >= _zones.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.MAPS, numeric_id(), ContentStatus.FieldId.ZONES); return MapZoneDefinition.new()
	return _zones[index].copy()
