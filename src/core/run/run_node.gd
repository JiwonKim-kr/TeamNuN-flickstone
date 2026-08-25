class_name RunNode
extends RefCounted

var _node_id: int = 0
var _floor_index: int = 0
var _slot_index: int = 0
var _node_type_id: int = RunNodeType.Value.INVALID
var _content_numeric_id: int = 0
var _next_node_ids: Array[int] = []
var _initialized: bool = false

static func create(node_id: int, floor_index: int, slot_index: int, node_type_id: int, content_numeric_id: int, next_node_ids: Array[int], status: SimStatus) -> RunNode:
	var result := RunNode.new()
	if not status.is_ok(): return result
	if node_id <= 0 or node_id > 0xFFFFFFFF or floor_index <= 0 or floor_index > RunLimits.MAX_FLOORS or slot_index < 0 or slot_index >= RunLimits.MAX_NODES_PER_FLOOR or not RunNodeType.is_valid(node_type_id) or content_numeric_id < 0 or content_numeric_id > 0xFFFFFFFF or next_node_ids.size() > RunLimits.MAX_EDGES_PER_NODE:
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CREATE, node_id, floor_index); return result
	if (node_type_id == RunNodeType.Value.REST and content_numeric_id != 0) or (node_type_id != RunNodeType.Value.REST and content_numeric_id == 0):
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CREATE, node_type_id, content_numeric_id); return result
	var previous_id: int = 0
	for next_id: int in next_node_ids:
		if next_id <= previous_id or next_id > 0xFFFFFFFF:
			status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CREATE, next_id, previous_id); return RunNode.new()
		result._next_node_ids.append(next_id); previous_id = next_id
	result._node_id = node_id; result._floor_index = floor_index; result._slot_index = slot_index
	result._node_type_id = node_type_id; result._content_numeric_id = content_numeric_id; result._initialized = true
	return result

func copy() -> RunNode:
	var result := RunNode.new()
	result._node_id = _node_id; result._floor_index = _floor_index; result._slot_index = _slot_index
	result._node_type_id = _node_type_id; result._content_numeric_id = _content_numeric_id; result._next_node_ids = _next_node_ids.duplicate(); result._initialized = _initialized
	return result
func is_initialized() -> bool: return _initialized
func node_id() -> int: return _node_id
func floor_index() -> int: return _floor_index
func slot_index() -> int: return _slot_index
func node_type_id() -> int: return _node_type_id
func content_numeric_id() -> int: return _content_numeric_id
func next_node_count() -> int: return _next_node_ids.size()
func next_node_id_at(index: int, status: SimStatus) -> int:
	if not status.is_ok(): return 0
	if index < 0 or index >= _next_node_ids.size():
		status.fail(SimStatus.Code.INVALID_RUN_NODE, SimStatus.Operation.RUN_NODE_CREATE, index, _next_node_ids.size()); return 0
	return _next_node_ids[index]
