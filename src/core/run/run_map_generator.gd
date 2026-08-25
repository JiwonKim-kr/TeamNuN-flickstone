class_name RunMapGenerator
extends RefCounted

static func _fail_content(status: SimStatus, act_numeric_id: int, detail: int = 0) -> RunNodeGraph:
	if status.is_ok(): status.fail(SimStatus.Code.RUN_MAP_GENERATION_FAILED, SimStatus.Operation.RUN_MAP_GENERATE, act_numeric_id, detail)
	return RunNodeGraph.new()

static func _select_option(slot: ActNodeSlotDefinition, seed_hi: int, seed_lo: int, act_numeric_id: int, node_id: int, status: SimStatus) -> ActNodeOptionDefinition:
	if slot.option_count() == 1:
		var content_status := ContentStatus.new()
		var only: ActNodeOptionDefinition = slot.option_at(0, content_status)
		if not content_status.is_ok(): status.fail(SimStatus.Code.RUN_MAP_GENERATION_FAILED, SimStatus.Operation.RUN_MAP_SELECT, node_id, RunRandomPurpose.RUN_MAP_NODE_TYPE)
		return only
	var rng: SimRng = SimRng.derive(seed_hi, seed_lo, RunRandomPurpose.RUN_MAP_NODE_TYPE, act_numeric_id, node_id, status)
	if not status.is_ok(): return ActNodeOptionDefinition.new()
	var ticket: int = rng.next_below(slot.total_weight(), status)
	if not status.is_ok(): return ActNodeOptionDefinition.new()
	var cumulative: int = 0
	var content_status := ContentStatus.new()
	for index: int in range(slot.option_count()):
		var option: ActNodeOptionDefinition = slot.option_at(index, content_status)
		if not content_status.is_ok():
			status.fail(SimStatus.Code.RUN_MAP_GENERATION_FAILED, SimStatus.Operation.RUN_MAP_SELECT, node_id, RunRandomPurpose.RUN_MAP_NODE_TYPE)
			return ActNodeOptionDefinition.new()
		cumulative += option.weight()
		if ticket < cumulative: return option
	status.fail(SimStatus.Code.RUN_MAP_GENERATION_FAILED, SimStatus.Operation.RUN_MAP_SELECT, node_id, ticket)
	return ActNodeOptionDefinition.new()

static func _select_content(option: ActNodeOptionDefinition, seed_hi: int, seed_lo: int, act_numeric_id: int, node_id: int, status: SimStatus) -> int:
	if option.node_type_id() == RunNodeType.Value.REST: return 0
	var index: int = 0
	if option.content_ref_count() > 1:
		var rng: SimRng = SimRng.derive(seed_hi, seed_lo, RunRandomPurpose.RUN_MAP_NODE_CONTENT, act_numeric_id, node_id, status)
		if not status.is_ok(): return 0
		index = rng.next_below(option.content_ref_count(), status)
		if not status.is_ok(): return 0
	var content_status := ContentStatus.new()
	var ref: ActContentRef = option.content_ref_at(index, content_status)
	if not content_status.is_ok():
		status.fail(SimStatus.Code.RUN_MAP_GENERATION_FAILED, SimStatus.Operation.RUN_MAP_SELECT, node_id, RunRandomPurpose.RUN_MAP_NODE_CONTENT)
		return 0
	return ref.numeric_id()

static func _edges_for_slot(source_slot: int, source_width: int, target_width: int, target_start_id: int, status: SimStatus) -> Array[int]:
	var first_target: int = FixMath.floor_div_int(source_slot * target_width, source_width, status)
	if not status.is_ok(): return []
	var target_slots: Array[int] = [first_target]
	for target_slot: int in range(target_width):
		var has_incoming: bool = false
		for other_source: int in range(source_width):
			if FixMath.floor_div_int(other_source * target_width, source_width, status) == target_slot:
				has_incoming = true
				break
		if not status.is_ok(): return []
		if not has_incoming and FixMath.floor_div_int(target_slot * source_width, target_width, status) == source_slot:
			target_slots.append(target_slot)
		if not status.is_ok(): return []
	target_slots.sort()
	var result: Array[int] = []
	var previous: int = -1
	for target_slot: int in target_slots:
		if target_slot == previous: continue
		result.append(target_start_id + target_slot)
		previous = target_slot
	return result

static func generate(catalog: ContentCatalog, act_numeric_id: int, seed_hi: int, seed_lo: int, status: SimStatus) -> RunNodeGraph:
	if not status.is_ok(): return RunNodeGraph.new()
	if catalog == null or not catalog.is_initialized() or act_numeric_id <= 0 or act_numeric_id > ContentLimits.UINT32_MAX or seed_hi < 0 or seed_hi > ContentLimits.UINT32_MAX or seed_lo < 0 or seed_lo > ContentLimits.UINT32_MAX:
		status.fail(SimStatus.Code.INVALID_RUN_ACT, SimStatus.Operation.RUN_MAP_GENERATE, act_numeric_id, 0)
		return RunNodeGraph.new()
	var content_status := ContentStatus.new()
	var act: ActDefinition = catalog.act_by_numeric_id(act_numeric_id, content_status)
	if not content_status.is_ok() or not act.is_initialized():
		status.fail(SimStatus.Code.INVALID_RUN_ACT, SimStatus.Operation.RUN_MAP_GENERATE, act_numeric_id, 0)
		return RunNodeGraph.new()
	var widths: Array[int] = []
	var starts: Array[int] = []
	var next_node_id: int = 1
	for floor_index: int in range(act.floor_count()):
		var floor: ActFloorDefinition = act.floor_at(floor_index, content_status)
		if not content_status.is_ok(): return _fail_content(status, act_numeric_id, floor_index + 1)
		starts.append(next_node_id); widths.append(floor.slot_count()); next_node_id += floor.slot_count()
	if next_node_id - 1 > RunLimits.MAX_NODES:
		status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED, SimStatus.Operation.RUN_MAP_GENERATE, next_node_id - 1, RunLimits.MAX_NODES)
		return RunNodeGraph.new()
	var nodes: Array[RunNode] = []
	for floor_index: int in range(act.floor_count()):
		var floor: ActFloorDefinition = act.floor_at(floor_index, content_status)
		if not content_status.is_ok(): return _fail_content(status, act_numeric_id, floor_index + 1)
		for slot_index: int in range(floor.slot_count()):
			var slot: ActNodeSlotDefinition = floor.slot_at(slot_index, content_status)
			if not content_status.is_ok(): return _fail_content(status, act_numeric_id, floor_index + 1)
			var node_id: int = starts[floor_index] + slot_index
			var option: ActNodeOptionDefinition = _select_option(slot, seed_hi, seed_lo, act_numeric_id, node_id, status)
			if not status.is_ok(): return RunNodeGraph.new()
			var content_numeric_id: int = _select_content(option, seed_hi, seed_lo, act_numeric_id, node_id, status)
			if not status.is_ok(): return RunNodeGraph.new()
			var edges: Array[int] = []
			if floor_index + 1 < act.floor_count(): edges = _edges_for_slot(slot_index, widths[floor_index], widths[floor_index + 1], starts[floor_index + 1], status)
			if not status.is_ok(): return RunNodeGraph.new()
			nodes.append(RunNode.create(node_id, floor_index + 1, slot_index, option.node_type_id(), content_numeric_id, edges, status))
			if not status.is_ok(): return RunNodeGraph.new()
	return RunNodeGraph.create(act.floor_count(), nodes, status)

static func validate_exact(catalog: ContentCatalog, act_numeric_id: int, seed_hi: int, seed_lo: int, graph: RunNodeGraph, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if graph == null or not graph.is_initialized():
		status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CONTENT_VALIDATE, act_numeric_id, 0)
		return false
	var expected: RunNodeGraph = generate(catalog, act_numeric_id, seed_hi, seed_lo, status)
	if not status.is_ok(): return false
	if graph.floor_count() != expected.floor_count() or graph.node_count() != expected.node_count():
		status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CONTENT_VALIDATE, graph.node_count(), expected.node_count())
		return false
	for index: int in range(graph.node_count()):
		var actual_node: RunNode = graph.node_at(index, status)
		var expected_node: RunNode = expected.node_at(index, status)
		if not status.is_ok(): return false
		if actual_node.node_id() != expected_node.node_id() or actual_node.floor_index() != expected_node.floor_index() or actual_node.slot_index() != expected_node.slot_index() or actual_node.node_type_id() != expected_node.node_type_id() or actual_node.content_numeric_id() != expected_node.content_numeric_id() or actual_node.next_node_count() != expected_node.next_node_count():
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CONTENT_VALIDATE, index + 1, expected_node.content_numeric_id())
			return false
		for edge_index: int in range(actual_node.next_node_count()):
			if actual_node.next_node_id_at(edge_index, status) != expected_node.next_node_id_at(edge_index, status):
				status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CONTENT_VALIDATE, index + 1, edge_index)
				return false
	return status.is_ok()
