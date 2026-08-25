class_name MapGeometryValidator
extends RefCounted


static func validate(definition: MapDefinition, catalog_max_radius_raw: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if definition == null or not definition.is_initialized() or not SimLimits.is_radius_valid(catalog_max_radius_raw):
		status.fail(SimStatus.Code.INVALID_MAP_DEFINITION, SimStatus.Operation.MAP_GEOMETRY_VALIDATE)
		return false
	var boundary: SimPolygon = SimPolygon.create(definition.boundary_vertices_copy(), true, status)
	if not status.is_ok(): status.fail(SimStatus.Code.INVALID_MAP_DEFINITION, SimStatus.Operation.MAP_GEOMETRY_VALIDATE); return false
	var kill_polygons: Array[SimPolygon] = []
	for zone_index: int in range(definition.zone_count()):
		var content_status := ContentStatus.new()
		var zone: MapZoneDefinition = definition.zone_at(zone_index, content_status)
		if zone.is_kill_zone(): kill_polygons.append(SimPolygon.create(zone.vertices_copy(), false, status))
		if not status.is_ok(): return false
	var slots: Array[FixVec2] = []
	var read_status := ContentStatus.new()
	for index: int in range(definition.player_slot_count()): slots.append(definition.player_slot_at(index, read_status).position())
	for index: int in range(definition.enemy_slot_count()): slots.append(definition.enemy_slot_at(index, read_status).position())
	if not read_status.is_ok(): status.fail(SimStatus.Code.INVALID_MAP_SLOT, SimStatus.Operation.MAP_GEOMETRY_VALIDATE); return false
	for slot_index: int in range(slots.size()):
		var point: FixVec2 = slots[slot_index]
		if boundary.classify_point(point, status) != SimPolygon.PointClass.INSIDE:
			status.fail(SimStatus.Code.INVALID_MAP_SLOT, SimStatus.Operation.MAP_GEOMETRY_VALIDATE, slot_index, 0); return false
		for edge_index: int in range(boundary.vertex_count()):
			var distance: int = SimPolygon.distance_to_segment_raw(point, boundary.vertex(edge_index, status), boundary.vertex((edge_index + 1) % boundary.vertex_count(), status), status)
			if not status.is_ok() or distance <= catalog_max_radius_raw:
				if status.is_ok(): status.fail(SimStatus.Code.INVALID_MAP_SLOT, SimStatus.Operation.MAP_GEOMETRY_VALIDATE, slot_index, edge_index)
				return false
		for polygon: SimPolygon in kill_polygons:
			if polygon.classify_point(point, status) == SimPolygon.PointClass.INSIDE:
				status.fail(SimStatus.Code.INVALID_MAP_SLOT, SimStatus.Operation.MAP_GEOMETRY_VALIDATE, slot_index, 1); return false
		var diameter: int = FixMath.multiply_int(catalog_max_radius_raw, 2, status)
		for prior_index: int in range(slot_index):
			if slots[slot_index].sub(slots[prior_index], status).is_length_at_most_raw(diameter, status):
				status.fail(SimStatus.Code.INVALID_MAP_SLOT, SimStatus.Operation.MAP_GEOMETRY_VALIDATE, prior_index, slot_index); return false
	return status.is_ok()
