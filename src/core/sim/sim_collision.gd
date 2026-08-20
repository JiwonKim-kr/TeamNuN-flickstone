class_name SimCollision
extends RefCounted
## Deterministic circle/circle and circle/convex-wall response.

const DEFAULT_RESTITUTION_RAW: int = 55706 # Q(17/20)
const MAX_SUBSTEPS: int = 16
const MAX_CONTACT_PASSES: int = 64


class CircleResult:
	var body_a: SimBody
	var body_b: SimBody
	var had_overlap: bool
	var impulse_applied: bool
	var normal: FixVec2
	var contact_position: FixVec2
	var approach_speed_raw: int
	var speed_order: int

	func _init(a: SimBody, b: SimBody) -> void:
		body_a = a.copy()
		body_b = b.copy()
		had_overlap = false
		impulse_applied = false
		normal = FixVec2.zero()
		contact_position = FixVec2.zero()
		approach_speed_raw = 0
		speed_order = SimEvent.COLLISION_SPEED_TIE


class WallHit:
	var edge_index: int
	var position: FixVec2
	var normal: FixVec2
	var approach_speed_raw: int

	func _init(
			p_edge_index: int,
			p_position: FixVec2,
			p_normal: FixVec2,
			p_approach_speed_raw: int
	) -> void:
		edge_index = p_edge_index
		position = p_position.copy()
		normal = p_normal.copy()
		approach_speed_raw = p_approach_speed_raw


class WallResult:
	var body: SimBody
	var hits: Array[WallHit]

	func _init(p_body: SimBody) -> void:
		body = p_body.copy()
		hits = []


class WallContact:
	var edge_index: int
	var penetration_raw: int
	var position: FixVec2
	var normal: FixVec2

	func _init(
			p_edge_index: int,
			p_penetration_raw: int,
			p_position: FixVec2,
			p_normal: FixVec2
	) -> void:
		edge_index = p_edge_index
		penetration_raw = p_penetration_raw
		position = p_position.copy()
		normal = p_normal.copy()


static func is_restitution_valid(restitution_raw: int) -> bool:
	return restitution_raw >= 0 and restitution_raw < FixMath.ONE_RAW


static func enhanced_restitution_raw(
		base_restitution_raw: int,
		elasticity_multiplier_raw: int,
		status: SimStatus
) -> int:
	if not status.is_ok():
		return 0
	if (
		not is_restitution_valid(base_restitution_raw)
		or elasticity_multiplier_raw < FixMath.ONE_RAW
	):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.COLLISION_CIRCLE,
			base_restitution_raw,
			elasticity_multiplier_raw
		)
		return 0
	var loss_raw: int = FixMath.sub_raw(
		FixMath.ONE_RAW, base_restitution_raw, status
	)
	var reduced_loss_raw: int = FixMath.div_raw(
		loss_raw, elasticity_multiplier_raw, status
	)
	return FixMath.sub_raw(
		FixMath.ONE_RAW, reduced_loss_raw, status
	)


static func required_substeps(
		max_speed_raw: int, min_radius_raw: int, status: SimStatus
) -> int:
	if not status.is_ok():
		return 0
	if max_speed_raw < 0 or min_radius_raw <= 0:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.COLLISION_SUBSTEPS,
			max_speed_raw,
			min_radius_raw
		)
		return 0
	var numerator: int = FixMath.multiply_int(max_speed_raw, 2, status)
	var denominator: int = FixMath.multiply_int(
		120, min_radius_raw, status
	)
	var count: int = FixMath.ceil_div_int(numerator, denominator, status)
	if not status.is_ok():
		return 0
	if count < 1:
		count = 1
	if count > MAX_SUBSTEPS:
		status.fail(
			SimStatus.Code.SIM_LIMIT_EXCEEDED,
			SimStatus.Operation.COLLISION_SUBSTEPS,
			count,
			MAX_SUBSTEPS
		)
		return 0
	return count


static func _validate_body_result(body: SimBody, status: SimStatus) -> bool:
	if not SimLimits.is_position_valid(body.position()):
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.COLLISION_CIRCLE,
			body.id(),
			body.position().x_raw()
		)
		return false
	if not SimLimits.is_speed_valid(body.velocity(), status):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_RANGE,
				SimStatus.Operation.COLLISION_CIRCLE,
				body.id(),
				0
			)
		return false
	return true


static func resolve_circle_pair(
		body_a: SimBody,
		body_b: SimBody,
		restitution_raw: int,
		status: SimStatus
) -> CircleResult:
	var result: CircleResult = CircleResult.new(body_a, body_b)
	if not status.is_ok():
		return result
	if (
		body_a == null
		or body_b == null
		or body_a.id() == 0
		or body_b.id() == 0
		or body_a.id() >= body_b.id()
		or not is_restitution_valid(restitution_raw)
	):
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.COLLISION_CIRCLE,
			0 if body_a == null else body_a.id(),
			0 if body_b == null else body_b.id()
		)
		return result

	var offset: FixVec2 = body_b.position().sub(body_a.position(), status)
	var distance_raw: int = offset.length_raw(status)
	var combined_radius_raw: int = FixMath.add_raw(
		body_a.radius_raw(), body_b.radius_raw(), status
	)
	if not status.is_ok() or distance_raw > combined_radius_raw:
		return result

	var normal: FixVec2
	if distance_raw > 0:
		normal = offset.divided(distance_raw, status)
	else:
		var relative_for_normal: FixVec2 = body_a.velocity().sub(
			body_b.velocity(), status
		)
		if relative_for_normal.is_zero():
			normal = FixVec2.from_raw(FixMath.ONE_RAW, 0)
		else:
			normal = relative_for_normal.normalized(status)
	if not status.is_ok():
		return result
	result.normal = normal.copy()

	var velocity_a: FixVec2 = body_a.velocity()
	var velocity_b: FixVec2 = body_b.velocity()
	var speed_a_squared_wide: int = _wide_dot(
		velocity_a, velocity_a, status
	)
	var speed_b_squared_wide: int = _wide_dot(
		velocity_b, velocity_b, status
	)
	if not status.is_ok():
		return result
	result.speed_order = FixMath.compare_raw(
		speed_a_squared_wide, speed_b_squared_wide
	)
	var relative_velocity: FixVec2 = velocity_a.sub(velocity_b, status)
	var approach_raw: int = relative_velocity.dot_raw(normal, status)
	result.approach_speed_raw = approach_raw
	if approach_raw > 0:
		var mass_sum_raw: int = FixMath.add_raw(
			body_a.mass_raw(), body_b.mass_raw(), status
		)
		var response_raw: int = FixMath.mul_raw(
			FixMath.add_raw(FixMath.ONE_RAW, restitution_raw, status),
			approach_raw,
			status
		)
		var delta_a_raw: int = FixMath.mul_ratio_raw(
			response_raw, body_b.mass_raw(), mass_sum_raw, status
		)
		var delta_b_raw: int = FixMath.mul_ratio_raw(
			response_raw, body_a.mass_raw(), mass_sum_raw, status
		)
		velocity_a = velocity_a.sub(normal.scaled(delta_a_raw, status), status)
		velocity_b = velocity_b.add(normal.scaled(delta_b_raw, status), status)
		result.impulse_applied = status.is_ok()

	var position_a: FixVec2 = body_a.position()
	var position_b: FixVec2 = body_b.position()
	if distance_raw < combined_radius_raw and status.is_ok():
		result.had_overlap = true
		var penetration_raw: int = FixMath.sub_raw(
			combined_radius_raw, distance_raw, status
		)
		var mass_sum_raw: int = FixMath.add_raw(
			body_a.mass_raw(), body_b.mass_raw(), status
		)
		var share_a_raw: int = FixMath.mul_ratio_raw(
			penetration_raw, body_b.mass_raw(), mass_sum_raw, status
		)
		var share_b_raw: int = FixMath.sub_raw(
			penetration_raw, share_a_raw, status
		)
		position_a = position_a.sub(
			normal.scaled(share_a_raw, status), status
		)
		position_b = position_b.add(
			normal.scaled(share_b_raw, status), status
		)

	if not status.is_ok():
		return result
	result.body_a = body_a.with_motion(position_a, velocity_a, status)
	result.body_b = body_b.with_motion(position_b, velocity_b, status)
	if not status.is_ok():
		return result
	if not _validate_body_result(result.body_a, status):
		return result
	if not _validate_body_result(result.body_b, status):
		return result
	result.contact_position = result.body_a.position().add(
		normal.scaled(body_a.radius_raw(), status), status
	)
	return result


static func _wide_dot(
		left: FixVec2, right: FixVec2, status: SimStatus
) -> int:
	var x: int = FixMath.multiply_int(
		left.x_raw(), right.x_raw(), status
	)
	var y: int = FixMath.multiply_int(
		left.y_raw(), right.y_raw(), status
	)
	return FixMath.add_raw(x, y, status)


static func _edge_inward_normal(
		polygon: SimPolygon, edge_index: int, status: SimStatus
) -> FixVec2:
	var start: FixVec2 = polygon.vertex(edge_index, status)
	var finish: FixVec2 = polygon.vertex(
		(edge_index + 1) % polygon.vertex_count(), status
	)
	var edge: FixVec2 = finish.sub(start, status)
	return FixVec2.from_raw(
		FixMath.negate_raw(edge.y_raw(), status),
		edge.x_raw()
	).normalized(status)


static func _vertex_normal(
		polygon: SimPolygon,
		vertex_index: int,
		center: FixVec2,
		status: SimStatus
) -> FixVec2:
	var vertex: FixVec2 = polygon.vertex(vertex_index, status)
	var offset: FixVec2 = center.sub(vertex, status)
	if not offset.is_zero():
		return offset.normalized(status)
	var previous_edge: int = (
		vertex_index - 1 + polygon.vertex_count()
	) % polygon.vertex_count()
	var previous_normal: FixVec2 = _edge_inward_normal(
		polygon, previous_edge, status
	)
	var next_normal: FixVec2 = _edge_inward_normal(
		polygon, vertex_index, status
	)
	return previous_normal.add(next_normal, status).normalized(status)


static func _contact_for_edge(
		body: SimBody,
		polygon: SimPolygon,
		edge_index: int,
		status: SimStatus
) -> WallContact:
	var start: FixVec2 = polygon.vertex(edge_index, status)
	var finish: FixVec2 = polygon.vertex(
		(edge_index + 1) % polygon.vertex_count(), status
	)
	var edge: FixVec2 = finish.sub(start, status)
	var from_start: FixVec2 = body.position().sub(start, status)
	var edge_length_squared: int = _wide_dot(edge, edge, status)
	var projection: int = _wide_dot(from_start, edge, status)
	if not status.is_ok():
		return null

	var closest: FixVec2
	var normal: FixVec2
	if projection <= 0:
		var previous_edge: int = (
			edge_index - 1 + polygon.vertex_count()
		) % polygon.vertex_count()
		var owner: int = mini(edge_index, previous_edge)
		if owner != edge_index:
			return null
		closest = start
		normal = _vertex_normal(
			polygon, edge_index, body.position(), status
		)
	elif projection >= edge_length_squared:
		var vertex_index: int = (edge_index + 1) % polygon.vertex_count()
		var next_edge: int = vertex_index
		var owner: int = mini(edge_index, next_edge)
		if owner != edge_index:
			return null
		closest = finish
		normal = _vertex_normal(
			polygon, vertex_index, body.position(), status
		)
	else:
		var t_raw: int = SimPolygon.unit_ratio_raw(
			projection, edge_length_squared, status
		)
		closest = start.add(edge.scaled(t_raw, status), status)
		normal = _edge_inward_normal(polygon, edge_index, status)
	if not status.is_ok():
		return null

	var distance_raw: int = body.position().sub(
		closest, status
	).length_raw(status)
	var penetration_raw: int = FixMath.sub_raw(
		body.radius_raw(), distance_raw, status
	)
	if not status.is_ok() or penetration_raw < 0:
		return null
	var normal_speed_raw: int = body.velocity().dot_raw(normal, status)
	if penetration_raw == 0 and normal_speed_raw >= 0:
		return null
	return WallContact.new(
		edge_index, penetration_raw, closest, normal
	)


static func _contact_less(left: WallContact, right: WallContact) -> bool:
	if left.penetration_raw != right.penetration_raw:
		return left.penetration_raw > right.penetration_raw
	return left.edge_index < right.edge_index


static func _collect_wall_contacts(
		body: SimBody, polygon: SimPolygon, status: SimStatus
) -> Array[WallContact]:
	var contacts: Array[WallContact] = []
	for edge_index: int in range(polygon.vertex_count()):
		var contact: WallContact = _contact_for_edge(
			body, polygon, edge_index, status
		)
		if not status.is_ok():
			return contacts
		if contact != null:
			contacts.append(contact)
	for index: int in range(1, contacts.size()):
		var value: WallContact = contacts[index]
		var cursor: int = index - 1
		while cursor >= 0 and _contact_less(value, contacts[cursor]):
			contacts[cursor + 1] = contacts[cursor]
			cursor -= 1
		contacts[cursor + 1] = value
	return contacts


static func _contains_int(values: Array[int], value: int) -> bool:
	for existing: int in values:
		if existing == value:
			return true
	return false


static func resolve_wall(
		body: SimBody,
		polygon: SimPolygon,
		restitution_raw: int,
		status: SimStatus
) -> WallResult:
	var result: WallResult = WallResult.new(body)
	if not status.is_ok():
		return result
	if (
		body == null
		or polygon == null
		or not polygon.is_clockwise()
		or not polygon.is_convex()
		or not is_restitution_valid(restitution_raw)
	):
		status.fail(
			SimStatus.Code.INVALID_ARGUMENT,
			SimStatus.Operation.COLLISION_WALL,
			0 if body == null else body.id(),
			restitution_raw
		)
		return result

	var current: SimBody = body.copy()
	var hit_edges: Array[int] = []
	for pass_index: int in range(MAX_CONTACT_PASSES):
		var contacts: Array[WallContact] = _collect_wall_contacts(
			current, polygon, status
		)
		if not status.is_ok():
			return result
		if contacts.is_empty():
			if (
				polygon.classify_point(
					current.position(), status
				) == SimPolygon.PointClass.OUTSIDE
			):
				status.fail(
					SimStatus.Code.UNRESOLVED_CONTACT,
					SimStatus.Operation.COLLISION_WALL,
					current.id(),
					pass_index
				)
				return result
			result.body = current
			return result

		var position: FixVec2 = current.position()
		var velocity: FixVec2 = current.velocity()
		for contact: WallContact in contacts:
			if contact.penetration_raw > 0:
				position = position.add(
					contact.normal.scaled(
						contact.penetration_raw, status
					),
					status
				)
			var normal_speed_raw: int = velocity.dot_raw(
				contact.normal, status
			)
			if normal_speed_raw < 0:
				var reflected_component_raw: int = FixMath.mul_raw(
					FixMath.add_raw(
						FixMath.ONE_RAW, restitution_raw, status
					),
					normal_speed_raw,
					status
				)
				velocity = velocity.sub(
					contact.normal.scaled(
						reflected_component_raw, status
					),
					status
				)
				if not _contains_int(hit_edges, contact.edge_index):
					hit_edges.append(contact.edge_index)
					result.hits.append(WallHit.new(
						contact.edge_index,
						contact.position,
						contact.normal,
						-normal_speed_raw
					))
			if not status.is_ok():
				return result
		current = current.with_motion(position, velocity, status)
		if not status.is_ok() or not _validate_body_result(current, status):
			return result

	status.fail(
		SimStatus.Code.UNRESOLVED_CONTACT,
		SimStatus.Operation.COLLISION_WALL,
		body.id(),
		MAX_CONTACT_PASSES
	)
	return result
