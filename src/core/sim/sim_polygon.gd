class_name SimPolygon
extends RefCounted
## Immutable deterministic simple polygon used by terrain and boundaries.
##
## All predicates operate on Q47.16 integer coordinates. A screen-clockwise
## polygon has positive local turns because screen Y grows downward.

const MIN_VERTEX_COUNT: int = 3
const MAX_VERTEX_COUNT: int = 64

enum PointClass {
	OUTSIDE = 0,
	BOUNDARY = 1,
	INSIDE = 2,
}

var _initialized: bool = false
var _vertices: Array[FixVec2] = []
var _clockwise: bool = false
var _convex: bool = false


static func _cross_vectors(
		left: FixVec2, right: FixVec2, status: SimStatus
) -> int:
	var a: int = FixMath.multiply_int(
		left.x_raw(), right.y_raw(), status
	)
	var b: int = FixMath.multiply_int(
		left.y_raw(), right.x_raw(), status
	)
	return FixMath.sub_raw(a, b, status)


static func _cross_points(
		a: FixVec2, b: FixVec2, c: FixVec2, status: SimStatus
) -> int:
	var edge: FixVec2 = b.sub(a, status)
	var offset: FixVec2 = c.sub(a, status)
	return _cross_vectors(edge, offset, status)


static func _between(value: int, endpoint_a: int, endpoint_b: int) -> bool:
	if endpoint_a <= endpoint_b:
		return value >= endpoint_a and value <= endpoint_b
	return value >= endpoint_b and value <= endpoint_a


static func _on_segment(a: FixVec2, b: FixVec2, point: FixVec2) -> bool:
	return (
		_between(point.x_raw(), a.x_raw(), b.x_raw())
		and _between(point.y_raw(), a.y_raw(), b.y_raw())
	)


static func _segments_intersect(
		a: FixVec2,
		b: FixVec2,
		c: FixVec2,
		d: FixVec2,
		status: SimStatus
) -> bool:
	var ab_c: int = _cross_points(a, b, c, status)
	var ab_d: int = _cross_points(a, b, d, status)
	var cd_a: int = _cross_points(c, d, a, status)
	var cd_b: int = _cross_points(c, d, b, status)
	if not status.is_ok():
		return false
	if ab_c == 0 and _on_segment(a, b, c):
		return true
	if ab_d == 0 and _on_segment(a, b, d):
		return true
	if cd_a == 0 and _on_segment(c, d, a):
		return true
	if cd_b == 0 and _on_segment(c, d, b):
		return true
	return (ab_c < 0) != (ab_d < 0) and (cd_a < 0) != (cd_b < 0)


static func _copy_vertices(source: Array[FixVec2]) -> Array[FixVec2]:
	var result: Array[FixVec2] = []
	for vertex: FixVec2 in source:
		result.append(vertex.copy())
	return result


static func create(
		vertices: Array[FixVec2],
		require_clockwise_convex: bool,
		status: SimStatus
) -> SimPolygon:
	var polygon: SimPolygon = SimPolygon.new()
	if not status.is_ok():
		return polygon
	if (
		vertices.size() < MIN_VERTEX_COUNT
		or vertices.size() > MAX_VERTEX_COUNT
	):
		status.fail(
			SimStatus.Code.INVALID_POLYGON,
			SimStatus.Operation.POLYGON_CREATE,
			vertices.size(),
			0
		)
		return polygon

	for index: int in range(vertices.size()):
		var vertex: FixVec2 = vertices[index]
		if vertex == null or not SimLimits.is_position_valid(vertex):
			status.fail(
				SimStatus.Code.INVALID_POLYGON,
				SimStatus.Operation.POLYGON_CREATE,
				index,
				0
			)
			return polygon
		for prior: int in range(index):
			if vertex.is_equal(vertices[prior]):
				status.fail(
					SimStatus.Code.INVALID_POLYGON,
					SimStatus.Operation.POLYGON_CREATE,
					prior,
					index
				)
				return polygon

	var count: int = vertices.size()
	var turns: Array[int] = []
	for index: int in range(count):
		var previous: FixVec2 = vertices[(index - 1 + count) % count]
		var current: FixVec2 = vertices[index]
		var next: FixVec2 = vertices[(index + 1) % count]
		var turn: int = _cross_points(previous, current, next, status)
		if not status.is_ok():
			return polygon
		if turn == 0:
			status.fail(
				SimStatus.Code.INVALID_POLYGON,
				SimStatus.Operation.POLYGON_CREATE,
				index,
				0
			)
			return polygon
		turns.append(turn)

	for first_edge: int in range(count):
		var a: FixVec2 = vertices[first_edge]
		var b: FixVec2 = vertices[(first_edge + 1) % count]
		for second_edge: int in range(first_edge + 1, count):
			if (
				second_edge == first_edge
				or second_edge == (first_edge + 1) % count
				or (second_edge + 1) % count == first_edge
			):
				continue
			var c: FixVec2 = vertices[second_edge]
			var d: FixVec2 = vertices[(second_edge + 1) % count]
			if _segments_intersect(a, b, c, d, status):
				status.fail(
					SimStatus.Code.INVALID_POLYGON,
					SimStatus.Operation.POLYGON_CREATE,
					first_edge,
					second_edge
				)
				return polygon
			if not status.is_ok():
				return polygon

	# At the lexicographically leftmost vertex the local turn has the global
	# orientation of a simple polygon. This avoids an overflowing 64-term
	# shoelace sum at the approved coordinate extremes.
	var extreme: int = 0
	for index: int in range(1, count):
		if (
			vertices[index].x_raw() < vertices[extreme].x_raw()
			or (
				vertices[index].x_raw() == vertices[extreme].x_raw()
				and vertices[index].y_raw() < vertices[extreme].y_raw()
			)
		):
			extreme = index
	var clockwise: bool = turns[extreme] > 0
	var convex: bool = true
	for turn: int in turns:
		if (turn > 0) != clockwise:
			convex = false
			break
	if require_clockwise_convex and (not clockwise or not convex):
		status.fail(
			SimStatus.Code.INVALID_POLYGON,
			SimStatus.Operation.POLYGON_CREATE,
			1 if clockwise else 0,
			1 if convex else 0
		)
		return polygon

	polygon._vertices = _copy_vertices(vertices)
	polygon._clockwise = clockwise
	polygon._convex = convex
	polygon._initialized = true
	return polygon


static func _unit_ratio_raw(
		numerator: int, denominator: int, status: SimStatus
) -> int:
	if not status.is_ok():
		return 0
	if denominator <= 0 or numerator < 0 or numerator > denominator:
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.POLYGON_SEGMENT_QUERY,
			numerator,
			denominator
		)
		return 0
	if numerator == 0:
		return 0
	if numerator == denominator:
		return FixMath.ONE_RAW
	var remainder: int = numerator
	var result: int = 0
	for unused: int in range(FixMath.FRACTION_BITS):
		result = FixMath.multiply_int(result, 2, status)
		remainder = FixMath.multiply_int(remainder, 2, status)
		if not status.is_ok():
			return 0
		if remainder >= denominator:
			remainder -= denominator
			result += 1
	var twice_remainder: int = FixMath.multiply_int(remainder, 2, status)
	if status.is_ok() and twice_remainder >= denominator:
		result += 1
	return result


static func unit_ratio_raw(
		numerator: int, denominator: int, status: SimStatus
) -> int:
	return _unit_ratio_raw(numerator, denominator, status)


func classify_point(point: FixVec2, status: SimStatus) -> int:
	if not status.is_ok():
		return PointClass.OUTSIDE
	if not _initialized or point == null:
		status.fail(
			SimStatus.Code.INVALID_SIM_STATE,
			SimStatus.Operation.POLYGON_POINT_QUERY,
			0,
			0
		)
		return PointClass.OUTSIDE
	var winding: int = 0
	for index: int in range(_vertices.size()):
		var a: FixVec2 = _vertices[index]
		var b: FixVec2 = _vertices[(index + 1) % _vertices.size()]
		var cross: int = _cross_points(a, b, point, status)
		if not status.is_ok():
			return PointClass.OUTSIDE
		if cross == 0 and _on_segment(a, b, point):
			return PointClass.BOUNDARY
		if a.y_raw() <= point.y_raw():
			if b.y_raw() > point.y_raw() and cross > 0:
				winding += 1
		elif b.y_raw() <= point.y_raw() and cross < 0:
			winding -= 1
	return PointClass.INSIDE if winding != 0 else PointClass.OUTSIDE


func _point_at_t_raw(
		start: FixVec2, delta: FixVec2, t_raw: int, status: SimStatus
) -> FixVec2:
	return start.add(delta.scaled(t_raw, status), status)


func first_strict_entry_t_raw(
		start: FixVec2, finish: FixVec2, status: SimStatus
) -> int:
	if classify_point(start, status) == PointClass.INSIDE:
		return 0
	if not status.is_ok():
		return -1
	var delta: FixVec2 = finish.sub(start, status)
	if delta.is_zero():
		return -1
	var candidates: Array[int] = [0, FixMath.ONE_RAW]
	for edge_index: int in range(_vertices.size()):
		var edge_start: FixVec2 = _vertices[edge_index]
		var edge_finish: FixVec2 = _vertices[
			(edge_index + 1) % _vertices.size()
		]
		var edge_delta: FixVec2 = edge_finish.sub(edge_start, status)
		var denominator: int = _cross_vectors(delta, edge_delta, status)
		var offset: FixVec2 = edge_start.sub(start, status)
		var numerator_t: int = _cross_vectors(offset, edge_delta, status)
		var numerator_u: int = _cross_vectors(offset, delta, status)
		if not status.is_ok():
			return -1
		if denominator == 0:
			continue
		if denominator < 0:
			denominator = -denominator
			numerator_t = -numerator_t
			numerator_u = -numerator_u
		if (
			numerator_t < 0
			or numerator_t > denominator
			or numerator_u < 0
			or numerator_u > denominator
		):
			continue
		candidates.append(_unit_ratio_raw(
			numerator_t, denominator, status
		))
		if not status.is_ok():
			return -1
	candidates.sort()
	var unique: Array[int] = []
	for candidate: int in candidates:
		if unique.is_empty() or unique[-1] != candidate:
			unique.append(candidate)
	for index: int in range(unique.size() - 1):
		var low: int = unique[index]
		var high: int = unique[index + 1]
		if high <= low:
			continue
		@warning_ignore("integer_division")
		var middle: int = low + (high - low) / 2
		if middle == low and high > low:
			middle = high
		var sample: FixVec2 = _point_at_t_raw(
			start, delta, middle, status
		)
		if classify_point(sample, status) == PointClass.INSIDE:
			return low
		if not status.is_ok():
			return -1
	if classify_point(finish, status) == PointClass.INSIDE:
		return FixMath.ONE_RAW
	return -1


func first_strict_exit_t_raw(
		start: FixVec2, finish: FixVec2, status: SimStatus
) -> int:
	var start_class: int = classify_point(start, status)
	if not status.is_ok():
		return -1
	if start_class == PointClass.OUTSIDE:
		return 0
	var finish_class: int = classify_point(finish, status)
	if not status.is_ok() or finish_class != PointClass.OUTSIDE:
		return -1
	if start_class == PointClass.BOUNDARY:
		return 0
	var reverse_entry_raw: int = first_strict_entry_t_raw(
		finish, start, status
	)
	if reverse_entry_raw < 0 or not status.is_ok():
		return -1
	return FixMath.sub_raw(
		FixMath.ONE_RAW, reverse_entry_raw, status
	)


func copy() -> SimPolygon:
	var result: SimPolygon = SimPolygon.new()
	result._initialized = _initialized
	result._vertices = _copy_vertices(_vertices)
	result._clockwise = _clockwise
	result._convex = _convex
	return result


func vertex_count() -> int:
	return _vertices.size()


func vertex(index: int, status: SimStatus) -> FixVec2:
	if not status.is_ok():
		return FixVec2.zero()
	if index < 0 or index >= _vertices.size():
		status.fail(
			SimStatus.Code.INVALID_RANGE,
			SimStatus.Operation.POLYGON_POINT_QUERY,
			index,
			_vertices.size()
		)
		return FixVec2.zero()
	return _vertices[index].copy()


func is_clockwise() -> bool:
	return _clockwise


func is_convex() -> bool:
	return _convex
