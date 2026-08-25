class_name RunNodeGraph
extends RefCounted

var _floor_count: int = 0
var _nodes: Array[RunNode] = []
var _initialized: bool = false

static func create(floor_count: int, nodes: Array[RunNode], status: SimStatus) -> RunNodeGraph:
	var result := RunNodeGraph.new()
	if not status.is_ok(): return result
	if floor_count < 1 or floor_count > RunLimits.MAX_FLOORS or nodes.is_empty() or nodes.size() > RunLimits.MAX_NODES:
		status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED, SimStatus.Operation.RUN_GRAPH_CREATE, floor_count, nodes.size()); return result
	var floor_widths: Array[int] = []
	floor_widths.resize(floor_count + 1); floor_widths.fill(0)
	for index: int in range(nodes.size()):
		var node: RunNode = nodes[index]
		if node == null or not node.is_initialized() or node.node_id() != index + 1 or node.floor_index() < 1 or node.floor_index() > floor_count:
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, index + 1, 0 if node == null else node.node_id()); return RunNodeGraph.new()
		var floor: int = node.floor_index()
		if node.slot_index() != floor_widths[floor]:
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, floor, node.slot_index()); return RunNodeGraph.new()
		floor_widths[floor] += 1
		if floor_widths[floor] > RunLimits.MAX_NODES_PER_FLOOR:
			status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED, SimStatus.Operation.RUN_GRAPH_CREATE, floor, floor_widths[floor]); return RunNodeGraph.new()
		result._nodes.append(node.copy())
	for floor: int in range(1, floor_count + 1):
		if floor_widths[floor] < 1:
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, floor, 0); return RunNodeGraph.new()
	var final_nodes: Array[RunNode] = []
	for node: RunNode in result._nodes:
		if node.floor_index() == floor_count: final_nodes.append(node)
		if (node.floor_index() == floor_count) != (node.node_type_id() == RunNodeType.Value.BOSS):
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, node.node_id(), node.node_type_id()); return RunNodeGraph.new()
		if node.floor_index() < floor_count and (node.next_node_count() < 1 or node.next_node_count() > RunLimits.MAX_EDGES_PER_NODE):
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, node.node_id(), node.next_node_count()); return RunNodeGraph.new()
		if node.floor_index() == floor_count and node.next_node_count() != 0:
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, node.node_id(), node.next_node_count()); return RunNodeGraph.new()
		for edge_index: int in range(node.next_node_count()):
			var target_id: int = node.next_node_id_at(edge_index, status)
			if target_id < 1 or target_id > result._nodes.size() or result._nodes[target_id - 1].floor_index() != node.floor_index() + 1:
				status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, node.node_id(), target_id); return RunNodeGraph.new()
	if final_nodes.size() != 1 or final_nodes[0].node_type_id() != RunNodeType.Value.BOSS:
		status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, final_nodes.size(), 0 if final_nodes.is_empty() else final_nodes[0].node_type_id()); return RunNodeGraph.new()
	var reachable: Array[bool] = []
	reachable.resize(result._nodes.size()); reachable.fill(false)
	for node: RunNode in result._nodes:
		if node.floor_index() == 1: reachable[node.node_id() - 1] = true
		if not reachable[node.node_id() - 1]: continue
		for edge_index: int in range(node.next_node_count()): reachable[node.next_node_id_at(edge_index, status) - 1] = true
	for index: int in range(reachable.size()):
		if not reachable[index]:
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, index + 1, 1); return RunNodeGraph.new()
	var reaches_boss: Array[bool] = []
	reaches_boss.resize(result._nodes.size()); reaches_boss.fill(false)
	reaches_boss[final_nodes[0].node_id() - 1] = true
	for index: int in range(result._nodes.size() - 1, -1, -1):
		var node: RunNode = result._nodes[index]
		for edge_index: int in range(node.next_node_count()):
			if reaches_boss[node.next_node_id_at(edge_index, status) - 1]: reaches_boss[index] = true
	for index: int in range(reaches_boss.size()):
		if not reaches_boss[index]:
			status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE, index + 1, 2); return RunNodeGraph.new()
	result._floor_count = floor_count; result._initialized = true
	return result

func copy(status: SimStatus) -> RunNodeGraph:
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_GRAPH, SimStatus.Operation.RUN_GRAPH_CREATE)
		return RunNodeGraph.new()
	return create(_floor_count, _nodes, status)
func is_initialized() -> bool: return _initialized
func floor_count() -> int: return _floor_count
func node_count() -> int: return _nodes.size()
func node_at(index: int, status: SimStatus) -> RunNode:
	if not status.is_ok(): return RunNode.new()
	if index < 0 or index >= _nodes.size():
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_GRAPH_CREATE, index, _nodes.size()); return RunNode.new()
	return _nodes[index].copy()
func node_by_id(node_id: int, status: SimStatus) -> RunNode:
	if not status.is_ok(): return RunNode.new()
	if node_id < 1 or node_id > _nodes.size():
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_GRAPH_CREATE, node_id, _nodes.size()); return RunNode.new()
	return _nodes[node_id - 1].copy()
