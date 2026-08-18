extends SceneTree
## Headless acceptance tests for docs/specs/p0_collision_boundaries.md.

const SimPolygonScript := preload("res://src/core/sim/sim_polygon.gd")
const SimCollisionScript := preload("res://src/core/sim/sim_collision.gd")
const SimWorldScript := preload("res://src/core/sim/sim_world.gd")

var _failures: int = 0


func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % case_id)
		return
	_failures += 1
	var suffix: String = "" if detail.is_empty() else " — %s" % detail
	print("[FAIL] %s%s" % [case_id, suffix])


func _detail(status: SimStatus, body_a: int = 0, body_b: int = 0) -> String:
	return "seed=0 step=0 pair=(%d,%d) code=%d op=%d a=%d b=%d" % [
		body_a,
		body_b,
		status.code(),
		status.operation(),
		status.detail_a(),
		status.detail_b(),
	]


func _q(value: int) -> int:
	return value * FixMath.SCALE


func _v(x: int, y: int, status: SimStatus) -> FixVec2:
	return FixVec2.from_ints(x, y, status)


func _square(radius: int, status: SimStatus) -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	result.append(_v(-radius, -radius, status))
	result.append(_v(radius, -radius, status))
	result.append(_v(radius, radius, status))
	result.append(_v(-radius, radius, status))
	return result


func _body(
		position_x: int,
		position_y: int,
		velocity_x: int,
		velocity_y: int,
		radius: int,
		mass: int,
		status: SimStatus,
		destructible: bool = true
) -> SimBody:
	return SimBody.create_unassigned(
		_v(position_x, position_y, status),
		_v(velocity_x, velocity_y, status),
		_q(radius),
		_q(mass),
		status,
		FixMath.ONE_RAW,
		destructible
	)


func _restored_body(
		id: int,
		position_x: int,
		velocity_x: int,
		status: SimStatus
) -> SimBody:
	return SimBody.restore(
		id,
		true,
		true,
		_v(position_x, 0, status),
		_v(velocity_x, 0, status),
		_q(8),
		_q(64),
		FixMath.ONE_RAW,
		status
	)


func _test_contract_and_polygon_validation() -> void:
	var status := SimStatus.new()
	var square: SimPolygon = SimPolygon.create(
		_square(100, status), true, status
	)
	var inside_class: int = square.classify_point(_v(0, 0, status), status)
	var boundary_class: int = square.classify_point(
		_v(100, 0, status), status
	)
	var outside_class: int = square.classify_point(
		_v(101, 0, status), status
	)
	_check(
		"CB-CONTRACT-001",
		SimCollision.DEFAULT_RESTITUTION_RAW == 55706
		and SimCollision.MAX_SUBSTEPS == 16
		and SimEvent.TypeId.BODY_COLLIDED == 4
		and SimEvent.TypeId.BODY_HIT_WALL == 5
		and SimEvent.TypeId.BODY_DESTROYED == 6
		and SimEvent.CauseId.KILL_BOUNDARY == 1
		and SimEvent.CauseId.KILL_ZONE == 2
		and SimStatus.Code.INVALID_POLYGON == 13
		and SimStatus.Code.SIM_LIMIT_EXCEEDED == 14
		and SimStatus.Code.UNRESOLVED_CONTACT == 15
		and status.is_ok()
	)
	_check(
		"CB-POLYGON-VALID-001",
		square.is_clockwise()
		and square.is_convex()
		and inside_class == SimPolygon.PointClass.INSIDE
		and boundary_class == SimPolygon.PointClass.BOUNDARY
		and outside_class == SimPolygon.PointClass.OUTSIDE,
		_detail(status)
	)

	var concave_status := SimStatus.new()
	var concave_vertices: Array[FixVec2] = [
		_v(-10, -10, concave_status),
		_v(10, -10, concave_status),
		_v(10, 10, concave_status),
		_v(0, 2, concave_status),
		_v(-10, 10, concave_status),
	]
	var concave: SimPolygon = SimPolygon.create(
		concave_vertices, false, concave_status
	)
	_check(
		"CB-POLYGON-CONCAVE-001",
		concave_status.is_ok()
		and not concave.is_convex()
		and concave.classify_point(
			_v(0, 0, concave_status), concave_status
		) == SimPolygon.PointClass.INSIDE,
		_detail(concave_status)
	)

	var reverse_status := SimStatus.new()
	var reverse_vertices: Array[FixVec2] = [
		_v(-100, -100, reverse_status),
		_v(-100, 100, reverse_status),
		_v(100, 100, reverse_status),
		_v(100, -100, reverse_status),
	]
	SimPolygon.create(reverse_vertices, true, reverse_status)
	var crossing_status := SimStatus.new()
	var crossing_vertices: Array[FixVec2] = [
		_v(-10, -10, crossing_status),
		_v(10, 10, crossing_status),
		_v(-10, 10, crossing_status),
		_v(10, -10, crossing_status),
	]
	SimPolygon.create(crossing_vertices, false, crossing_status)
	var collinear_status := SimStatus.new()
	var collinear_vertices: Array[FixVec2] = [
		_v(-10, -10, collinear_status),
		_v(0, -10, collinear_status),
		_v(10, -10, collinear_status),
		_v(10, 10, collinear_status),
		_v(-10, 10, collinear_status),
	]
	SimPolygon.create(collinear_vertices, false, collinear_status)
	var duplicate_status := SimStatus.new()
	var duplicate_vertices: Array[FixVec2] = [
		_v(-10, -10, duplicate_status),
		_v(10, -10, duplicate_status),
		_v(10, 10, duplicate_status),
		_v(-10, -10, duplicate_status),
	]
	SimPolygon.create(duplicate_vertices, false, duplicate_status)
	_check(
		"CB-POLYGON-REJECT-001",
		reverse_status.code() == SimStatus.Code.INVALID_POLYGON
		and crossing_status.code() == SimStatus.Code.INVALID_POLYGON
		and collinear_status.code() == SimStatus.Code.INVALID_POLYGON
		and duplicate_status.code() == SimStatus.Code.INVALID_POLYGON
	)


func _test_substeps() -> void:
	var status := SimStatus.new()
	var count: int = SimCollision.required_substeps(
		_q(4096), _q(8), status
	)
	var limit_status := SimStatus.new()
	var rejected: int = SimCollision.required_substeps(
		_q(8192), _q(8), limit_status
	)
	var enhanced_raw: int = SimCollision.enhanced_restitution_raw(
		SimCollision.DEFAULT_RESTITUTION_RAW,
		_q(2),
		status
	)
	_check(
		"CB-SUBSTEP-001",
		count == 9
		and enhanced_raw == 60621
		and status.is_ok()
		and rejected == 0
		and limit_status.code() == SimStatus.Code.SIM_LIMIT_EXCEEDED
		and limit_status.operation() == SimStatus.Operation.COLLISION_SUBSTEPS,
		_detail(limit_status)
	)


func _test_circle_response() -> void:
	var status := SimStatus.new()
	var body_a: SimBody = _restored_body(1, -7, 100, status)
	var body_b: SimBody = _restored_body(2, 7, 0, status)
	var result: SimCollision.CircleResult = SimCollision.resolve_circle_pair(
		body_a,
		body_b,
		SimCollision.DEFAULT_RESTITUTION_RAW,
		status
	)
	var separation: int = result.body_b.position().x_raw() - (
		result.body_a.position().x_raw()
	)
	_check(
		"CB-CIRCLE-IMPULSE-001",
		result.had_overlap
		and result.impulse_applied
		and result.approach_speed_raw == _q(100)
		and result.body_a.velocity().x_raw() == 491500
		and result.body_b.velocity().x_raw() == 6062100
		and separation >= _q(16)
		and status.is_ok(),
		_detail(status, 1, 2)
	)

	var separating_status := SimStatus.new()
	var separating_a: SimBody = _restored_body(
		1, -7, -100, separating_status
	)
	var separating_b: SimBody = _restored_body(
		2, 7, 100, separating_status
	)
	var separating: SimCollision.CircleResult = (
		SimCollision.resolve_circle_pair(
			separating_a,
			separating_b,
			SimCollision.DEFAULT_RESTITUTION_RAW,
			separating_status
		)
	)
	_check(
		"CB-CIRCLE-SEPARATING-001",
		separating.had_overlap
		and not separating.impulse_applied
		and separating.body_a.velocity().x_raw() == -_q(100)
		and separating.body_b.velocity().x_raw() == _q(100)
		and separating_status.is_ok(),
		_detail(separating_status, 1, 2)
	)

	var weighted_status := SimStatus.new()
	var weighted_a: SimBody = SimBody.restore(
		1,
		true,
		true,
		_v(-7, 0, weighted_status),
		FixVec2.zero(),
		_q(8),
		_q(32),
		FixMath.ONE_RAW,
		weighted_status
	)
	var weighted_b: SimBody = SimBody.restore(
		2,
		true,
		true,
		_v(7, 0, weighted_status),
		FixVec2.zero(),
		_q(8),
		_q(96),
		FixMath.ONE_RAW,
		weighted_status
	)
	var weighted: SimCollision.CircleResult = (
		SimCollision.resolve_circle_pair(
			weighted_a,
			weighted_b,
			SimCollision.DEFAULT_RESTITUTION_RAW,
			weighted_status
		)
	)
	_check(
		"CB-CIRCLE-INVERSE-MASS-001",
		weighted.body_a.position().x_raw() == -_q(8) - FixMath.HALF_RAW
		and weighted.body_b.position().x_raw() == _q(7) + FixMath.HALF_RAW
		and weighted_status.is_ok(),
		_detail(weighted_status, 1, 2)
	)


func _test_world_pair_order() -> void:
	var status_a := SimStatus.new()
	var status_b := SimStatus.new()
	var world_a: SimWorld = SimWorld.create(0, 31, status_a, 0, 0)
	var world_b: SimWorld = SimWorld.create(0, 31, status_b, 0, 0)
	var keys_a: Array[int] = [20, 10]
	var bodies_a: Array[SimBody] = [
		_body(8, 0, 0, 0, 8, 64, status_a),
		_body(-8, 0, 120, 0, 8, 64, status_a),
	]
	var keys_b: Array[int] = [10, 20]
	var bodies_b: Array[SimBody] = [
		_body(-8, 0, 120, 0, 8, 64, status_b),
		_body(8, 0, 0, 0, 8, 64, status_b),
	]
	world_a.add_initial_bodies(keys_a, bodies_a, status_a)
	world_b.add_initial_bodies(keys_b, bodies_b, status_b)
	world_a.step(status_a)
	world_b.step(status_b)
	var a1: SimBody = world_a.body_by_id(1, status_a)
	var a2: SimBody = world_a.body_by_id(2, status_a)
	var b1: SimBody = world_b.body_by_id(1, status_b)
	var b2: SimBody = world_b.body_by_id(2, status_b)
	var collision: SimEvent = world_a.event_at(2, status_a)
	_check(
		"CB-PAIR-ORDER-001",
		a1.position().is_equal(b1.position())
		and a1.velocity().is_equal(b1.velocity())
		and a2.position().is_equal(b2.position())
		and a2.velocity().is_equal(b2.velocity())
		and collision.type_id() == SimEvent.TypeId.BODY_COLLIDED
		and collision.source_body_id() == 1
		and collision.target_body_id() == 2
		and status_a.is_ok()
		and status_b.is_ok(),
		_detail(status_a, 1, 2)
	)


func _test_wall_and_corner_response() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 32, status, 0, 0)
	world.configure_boundary(
		_square(100, status), SimWorld.BoundaryType.WALL, status
	)
	var keys: Array[int] = [1]
	var bodies: Array[SimBody] = [
		_body(91, 0, 240, 0, 8, 64, status)
	]
	world.add_initial_bodies(keys, bodies, status)
	world.step(status)
	var body: SimBody = world.body_by_id(1, status)
	var hit: SimEvent = world.event_at(1, status)
	_check(
		"CB-WALL-REFLECT-001",
		body.position().x_raw() == _q(92)
		and body.velocity().x_raw() == -13369440
		and world.last_substep_count() == 1
		and hit.type_id() == SimEvent.TypeId.BODY_HIT_WALL
		and hit.value_a() == 1
		and hit.vector().x_raw() == -FixMath.ONE_RAW
		and hit.value_b() == _q(240)
		and status.is_ok(),
		_detail(status, 1)
	)

	var corner_status := SimStatus.new()
	var corner_world: SimWorld = SimWorld.create(
		0, 33, corner_status, 0, 0
	)
	corner_world.configure_boundary(
		_square(100, corner_status),
		SimWorld.BoundaryType.WALL,
		corner_status
	)
	var corner_keys: Array[int] = [1]
	var corner_bodies: Array[SimBody] = [
		_body(91, 91, 120, 120, 8, 64, corner_status)
	]
	corner_world.add_initial_bodies(
		corner_keys, corner_bodies, corner_status
	)
	corner_world.step(corner_status)
	var corner: SimBody = corner_world.body_by_id(1, corner_status)
	var first_hit: SimEvent = corner_world.event_at(1, corner_status)
	var second_hit: SimEvent = corner_world.event_at(2, corner_status)
	_check(
		"CB-WALL-CORNER-001",
		corner.position().x_raw() == _q(92)
		and corner.position().y_raw() == _q(92)
		and corner.velocity().x_raw() < 0
		and corner.velocity().y_raw() < 0
		and first_hit.value_a() == 1
		and second_hit.value_a() == 2
		and corner_status.is_ok(),
		_detail(corner_status, 1)
	)

	var vertex_status := SimStatus.new()
	var vertex_polygon: SimPolygon = SimPolygon.create(
		_square(100, vertex_status), true, vertex_status
	)
	var vertex_body: SimBody = SimBody.restore(
		1,
		true,
		true,
		_v(100, 100, vertex_status),
		FixVec2.from_raw(1, 1),
		_q(8),
		_q(64),
		FixMath.ONE_RAW,
		vertex_status
	)
	var vertex_result: SimCollision.WallResult = SimCollision.resolve_wall(
		vertex_body,
		vertex_polygon,
		SimCollision.DEFAULT_RESTITUTION_RAW,
		vertex_status
	)
	_check(
		"CB-WALL-SHARED-VERTEX-001",
		vertex_result.hits.size() == 1
		and vertex_result.hits[0].edge_index == 1
		and vertex_result.body.position().x_raw() == _q(92)
		and vertex_result.body.position().y_raw() == _q(92)
		and vertex_status.is_ok(),
		_detail(vertex_status, 1)
	)


func _test_kill_boundary_and_zone() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 34, status, 0, 0)
	world.configure_boundary(
		_square(100, status), SimWorld.BoundaryType.KILL, status
	)
	var keys: Array[int] = [1]
	var bodies: Array[SimBody] = [
		_body(99, 0, 240, 0, 8, 64, status, false)
	]
	world.add_initial_bodies(keys, bodies, status)
	world.step(status)
	var destroyed: SimEvent = world.event_at(1, status)
	_check(
		"CB-KILL-BOUNDARY-001",
		world.body_count() == 0
		and destroyed.type_id() == SimEvent.TypeId.BODY_DESTROYED
		and destroyed.cause_id() == SimEvent.CauseId.KILL_BOUNDARY
		and destroyed.zone_id() == 0
		and destroyed.source_body_id() == 1
		and status.is_ok(),
		_detail(status, 1)
	)

	var safe_status := SimStatus.new()
	var safe_world: SimWorld = SimWorld.create(
		0, 340, safe_status, 0, 0
	)
	safe_world.configure_boundary(
		_square(100, safe_status),
		SimWorld.BoundaryType.KILL,
		safe_status
	)
	var safe_keys: Array[int] = [1]
	var safe_bodies: Array[SimBody] = [
		_body(100, 0, 0, 0, 8, 64, safe_status, false)
	]
	safe_world.add_initial_bodies(safe_keys, safe_bodies, safe_status)
	safe_world.step(safe_status)
	_check(
		"CB-KILL-BOUNDARY-LINE-SAFE-001",
		safe_world.body_count() == 1
		and safe_world.event_count() == 1
		and safe_status.is_ok(),
		_detail(safe_status, 1)
	)

	var edge_exit_status := SimStatus.new()
	var edge_exit_world: SimWorld = SimWorld.create(
		0, 341, edge_exit_status, 0, 0
	)
	edge_exit_world.configure_boundary(
		_square(100, edge_exit_status),
		SimWorld.BoundaryType.KILL,
		edge_exit_status
	)
	var edge_exit_keys: Array[int] = [1]
	var edge_exit_bodies: Array[SimBody] = [
		_body(100, 0, 120, 0, 8, 64, edge_exit_status, false)
	]
	edge_exit_world.add_initial_bodies(
		edge_exit_keys, edge_exit_bodies, edge_exit_status
	)
	edge_exit_world.step(edge_exit_status)
	var edge_exit_event: SimEvent = edge_exit_world.event_at(
		1, edge_exit_status
	)
	_check(
		"CB-KILL-BOUNDARY-EDGE-EXIT-001",
		edge_exit_world.body_count() == 0
		and edge_exit_event.cause_id() == SimEvent.CauseId.KILL_BOUNDARY
		and edge_exit_event.position().x_raw() == _q(100)
		and edge_exit_status.is_ok(),
		_detail(edge_exit_status, 1)
	)

	var zone_status := SimStatus.new()
	var zone_world: SimWorld = SimWorld.create(
		0, 35, zone_status, 0, 0
	)
	var thin_vertices: Array[FixVec2] = [
		_v(0, -50, zone_status),
		_v(1, -50, zone_status),
		_v(1, 50, zone_status),
		_v(0, 50, zone_status),
	]
	var kill_zone: SimZone = SimZone.create_unassigned(
		thin_vertices,
		FixMath.ONE_RAW,
		FixVec2.zero(),
		zone_status,
		SimZone.FLAG_KILL
	)
	var later_vertices: Array[FixVec2] = [
		_v(5, -50, zone_status),
		_v(6, -50, zone_status),
		_v(6, 50, zone_status),
		_v(5, 50, zone_status),
	]
	var later_zone: SimZone = SimZone.create_unassigned(
		later_vertices,
		FixMath.ONE_RAW,
		FixVec2.zero(),
		zone_status,
		SimZone.FLAG_KILL
	)
	var zone_keys: Array[int] = [20, 10]
	var zones: Array[SimZone] = [kill_zone, later_zone]
	zone_world.add_initial_zones(zone_keys, zones, zone_status)
	var tunnel_keys: Array[int] = [1]
	var tunnel_bodies: Array[SimBody] = [
		_body(-10, 0, 2400, 0, 128, 64, zone_status, false)
	]
	zone_world.add_initial_bodies(
		tunnel_keys, tunnel_bodies, zone_status
	)
	zone_world.step(zone_status)
	var zone_destroyed: SimEvent = zone_world.event_at(1, zone_status)
	_check(
		"CB-KILL-ZONE-TUNNEL-001",
		zone_world.body_count() == 0
		and zone_destroyed.type_id() == SimEvent.TypeId.BODY_DESTROYED
		and zone_destroyed.cause_id() == SimEvent.CauseId.KILL_ZONE
		and zone_destroyed.zone_id() == 2
		and zone_destroyed.position().x_raw() == 0
		and zone_status.is_ok(),
		_detail(zone_status, 1)
	)

	var initial_status := SimStatus.new()
	var initial_world: SimWorld = SimWorld.create(
		0, 36, initial_status, 0, 0
	)
	var initial_zone: SimZone = SimZone.create_unassigned(
		_square(20, initial_status),
		FixMath.ONE_RAW,
		FixVec2.zero(),
		initial_status,
		SimZone.FLAG_KILL
	)
	var initial_zone_keys: Array[int] = [1]
	var initial_zones: Array[SimZone] = [initial_zone]
	initial_world.add_initial_zones(
		initial_zone_keys, initial_zones, initial_status
	)
	var invalid_status := SimStatus.new()
	var invalid_keys: Array[int] = [1]
	var invalid_bodies: Array[SimBody] = [
		_body(0, 0, 0, 0, 8, 64, invalid_status)
	]
	initial_world.add_initial_bodies(
		invalid_keys, invalid_bodies, invalid_status
	)
	_check(
		"CB-KILL-INITIAL-REJECT-001",
		invalid_status.code() == SimStatus.Code.INVALID_SIM_STATE
		and initial_world.body_count() == 0
	)


func _test_management_remove_is_distinct() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 37, status, 0, 0)
	var keys: Array[int] = [1]
	var bodies: Array[SimBody] = [
		_body(0, 0, 0, 0, 8, 64, status, false)
	]
	world.add_initial_bodies(keys, bodies, status)
	world.remove_body(1, status)
	var removed: SimEvent = world.event_at(1, status)
	_check(
		"CB-MANAGED-REMOVE-001",
		removed.type_id() == SimEvent.TypeId.BODY_REMOVED
		and removed.cause_id() == SimEvent.CauseId.NONE
		and world.body_count() == 0
		and status.is_ok(),
		_detail(status, 1)
	)


func _test_collision_failure_is_atomic() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(0, 371, status, 0, 0)
	world.configure_boundary(
		_square(100, status), SimWorld.BoundaryType.WALL, status
	)
	world.queue_body_spawn(
		_body(200, 0, 0, 0, 8, 64, status),
		0,
		0,
		0,
		status
	)
	var failed_status := SimStatus.new()
	var stepped: bool = world.step(failed_status)
	_check(
		"CB-STEP-ATOMIC-001",
		not stepped
		and failed_status.code() == SimStatus.Code.UNRESOLVED_CONTACT
		and failed_status.operation() == SimStatus.Operation.COLLISION_WALL
		and world.tick() == 0
		and world.body_count() == 0
		and world.event_count() == 0
		and world.next_body_id() == 1
		and world.has_pending_requests(),
		_detail(failed_status)
	)


func _worlds_match(left: SimWorld, right: SimWorld) -> bool:
	if (
		left.tick() != right.tick()
		or left.body_count() != right.body_count()
		or left.event_count() != right.event_count()
	):
		return false
	var status := SimStatus.new()
	for index: int in range(left.body_count()):
		var a: SimBody = left.body_at(index, status)
		var b: SimBody = right.body_at(index, status)
		if (
			a.id() != b.id()
			or not a.position().is_equal(b.position())
			or not a.velocity().is_equal(b.velocity())
		):
			return false
	return status.is_ok()


func _has_overlap(world: SimWorld, status: SimStatus) -> bool:
	for low: int in range(world.body_count()):
		var a: SimBody = world.body_at(low, status)
		for high: int in range(low + 1, world.body_count()):
			var b: SimBody = world.body_at(high, status)
			var distance: int = b.position().sub(
				a.position(), status
			).length_raw(status)
			if distance < a.radius_raw() + b.radius_raw():
				return true
	return false


func _test_stress_determinism() -> void:
	var status_a := SimStatus.new()
	var status_b := SimStatus.new()
	var world_a: SimWorld = SimWorld.create(0, 38, status_a, 0, 0)
	var world_b: SimWorld = SimWorld.create(0, 38, status_b, 0, 0)
	world_a.configure_boundary(
		_square(1000, status_a), SimWorld.BoundaryType.WALL, status_a
	)
	world_b.configure_boundary(
		_square(1000, status_b), SimWorld.BoundaryType.WALL, status_b
	)
	var keys_a: Array[int] = [30, 10, 20]
	var bodies_a: Array[SimBody] = [
		_body(500, 0, -1024, 0, 8, 64, status_a),
		_body(-500, 0, 4096, 0, 8, 64, status_a),
		_body(0, 0, -2048, 0, 8, 64, status_a),
	]
	var keys_b: Array[int] = [20, 30, 10]
	var bodies_b: Array[SimBody] = [
		_body(0, 0, -2048, 0, 8, 64, status_b),
		_body(500, 0, -1024, 0, 8, 64, status_b),
		_body(-500, 0, 4096, 0, 8, 64, status_b),
	]
	world_a.add_initial_bodies(keys_a, bodies_a, status_a)
	world_b.add_initial_bodies(keys_b, bodies_b, status_b)
	for step_index: int in range(1000):
		world_a.step(status_a)
		world_b.step(status_b)
		if not status_a.is_ok() or not status_b.is_ok():
			break
	var overlap_status := SimStatus.new()
	_check(
		"CB-STRESS-DETERMINISM-001",
		status_a.is_ok()
		and status_b.is_ok()
		and world_a.tick() == 1000
		and _worlds_match(world_a, world_b)
		and not _has_overlap(world_a, overlap_status)
		and overlap_status.is_ok(),
		_detail(status_a)
	)


func _initialize() -> void:
	print("== P0-3 circle collision / wall / kill zones ==")
	_test_contract_and_polygon_validation()
	_test_substeps()
	_test_circle_response()
	_test_world_pair_order()
	_test_wall_and_corner_response()
	_test_kill_boundary_and_zone()
	_test_management_remove_is_distinct()
	_test_collision_failure_is_atomic()
	_test_stress_determinism()

	if _failures == 0:
		print("P0_COLLISION_BOUNDARIES_RESULT: PASS")
		quit(0)
	else:
		print(
			"P0_COLLISION_BOUNDARIES_RESULT: FAIL (%d grouped checks)"
			% _failures
		)
		quit(1)
