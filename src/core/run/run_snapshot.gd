class_name RunSnapshot
extends RefCounted

const MAGIC: PackedByteArray = [70, 76, 73, 67, 75, 82, 85, 78, 0] # FLICKRUN\0
const SCHEMA_VERSION: int = 1

class Writer:
	var data: PackedByteArray = PackedByteArray()
	func u8(value: int) -> void: data.append(value & 0xFF)
	func u16(value: int) -> void:
		for shift: int in range(0, 16, 8): u8(value >> shift)
	func u32(value: int) -> void:
		for shift: int in range(0, 32, 8): u8(value >> shift)
	func i64(value: int) -> void:
		for shift: int in range(0, 64, 8): u8(value >> shift)

class Reader:
	var data: PackedByteArray
	var offset: int = 0
	var valid: bool = true
	func _init(source: PackedByteArray) -> void: data = source
	func remaining() -> int: return data.size() - offset
	func require(count: int) -> bool:
		if count < 0 or remaining() < count: valid = false; return false
		return true
	func u8() -> int:
		if not require(1): return 0
		var value: int = data[offset]; offset += 1; return value
	func u16() -> int:
		var value: int = 0
		for shift: int in range(0, 16, 8): value |= u8() << shift
		return value
	func u32() -> int:
		var value: int = 0
		for shift: int in range(0, 32, 8): value |= u8() << shift
		return value
	func i64() -> int:
		var value: int = 0
		for shift: int in range(0, 64, 8): value |= u8() << shift
		return value
	func bytes(count: int) -> PackedByteArray:
		if not require(count): return PackedByteArray()
		var value: PackedByteArray = data.slice(offset, offset + count); offset += count; return value

class Decoded:
	var fingerprint: PackedByteArray = PackedByteArray()
	var seed_hi: int = 0
	var seed_lo: int = 0
	var phase_id: int = 0
	var act_numeric_id: int = 0
	var current_floor: int = 0
	var current_node_id: int = 0
	var life: int = 0
	var max_life: int = 0
	var gold: int = 0
	var roster_capacity: int = 0
	var deployment_capacity: int = 0
	var next_piece_instance_id: int = 0
	var next_transition_sequence: int = 0
	var graph: RunNodeGraph = RunNodeGraph.new()
	var visited_node_ids: Array[int] = []
	var completed_node_ids: Array[int] = []
	var roster: Array[RunPieceInstance] = []
	var deployment_instance_ids: Array[int] = []
	var relic_numeric_ids: Array[int] = []
	var consumable_stacks: Array[RunConsumableStack] = []
	var pending_choice: RunPendingChoice = RunPendingChoice.new()
	var initialized: bool = false

var _bytes: PackedByteArray = PackedByteArray()
var _initialized: bool = false

static func capture(state: RunState, status: SimStatus) -> RunSnapshot:
	var result := RunSnapshot.new()
	if not status.is_ok(): return result
	if state == null or not state.is_initialized() or state.phase_id() != RunPhase.Value.MAP_CHOICE:
		status.fail(SimStatus.Code.INVALID_RUN_STATE, SimStatus.Operation.RUN_SNAPSHOT_CAPTURE, 0 if state == null else state.phase_id(), 0); return result
	var state_copy: RunState = state.copy(status)
	if not status.is_ok(): return RunSnapshot.new()
	result._bytes = _encode_state(state_copy, status)
	if not status.is_ok() or result._bytes.is_empty(): return RunSnapshot.new()
	result._initialized = true
	return result

static func decode(bytes: PackedByteArray, status: SimStatus) -> RunSnapshot:
	var result := RunSnapshot.new()
	if not status.is_ok(): return result
	var decoded: Decoded = _parse(bytes, status)
	if not status.is_ok() or not decoded.initialized: return RunSnapshot.new()
	result._bytes = bytes.duplicate(); result._initialized = true
	return result

func restore_state(catalog: ContentCatalog, status: SimStatus) -> RunState:
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.RUN_SNAPSHOT_RESTORE)
		return RunState.new()
	var decoded: Decoded = _parse(_bytes, status)
	if not status.is_ok(): return RunState.new()
	return RunState.restore_v1(catalog, decoded.fingerprint, decoded.seed_hi, decoded.seed_lo, decoded.phase_id, decoded.act_numeric_id, decoded.current_floor, decoded.current_node_id, decoded.life, decoded.max_life, decoded.gold, decoded.roster_capacity, decoded.deployment_capacity, decoded.next_piece_instance_id, decoded.next_transition_sequence, decoded.graph, decoded.visited_node_ids, decoded.completed_node_ids, decoded.roster, decoded.deployment_instance_ids, decoded.relic_numeric_ids, decoded.consumable_stacks, decoded.pending_choice, status)

func is_initialized() -> bool: return _initialized

func encode(status: SimStatus) -> PackedByteArray:
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.RUN_SNAPSHOT_ENCODE)
		return PackedByteArray()
	return _bytes.duplicate()

func state_hash_hex(status: SimStatus) -> String:
	return SimStateHash.hex_digest(encode(status), status)

static func _encode_state(state: RunState, status: SimStatus) -> PackedByteArray:
	var writer := Writer.new()
	writer.data.append_array(MAGIC); writer.u16(SCHEMA_VERSION); writer.data.append_array(state.content_fingerprint_bytes())
	writer.u32(state.seed_hi()); writer.u32(state.seed_lo()); writer.u16(state.phase_id()); writer.u32(state.act_numeric_id()); writer.u16(state.current_floor()); writer.u32(state.current_node_id())
	writer.u16(state.life()); writer.u16(state.max_life()); writer.u32(state.gold()); writer.u16(state.roster_capacity()); writer.u16(state.deployment_capacity())
	writer.u32(state.next_piece_instance_id()); writer.u32(state.next_transition_sequence())
	var graph: RunNodeGraph = state.graph_copy(status)
	writer.u16(graph.floor_count()); writer.u32(graph.node_count())
	for index: int in range(graph.node_count()):
		var node: RunNode = graph.node_at(index, status)
		writer.u32(node.node_id()); writer.u16(node.floor_index()); writer.u16(node.slot_index()); writer.u16(node.node_type_id()); writer.u32(node.content_numeric_id()); writer.u16(node.next_node_count())
		for edge_index: int in range(node.next_node_count()): writer.u32(node.next_node_id_at(edge_index, status))
	writer.u32(state.visited_node_count())
	for index: int in range(state.visited_node_count()): writer.u32(state.visited_node_id_at(index, status))
	writer.u32(state.completed_node_count())
	for index: int in range(state.completed_node_count()): writer.u32(state.completed_node_id_at(index, status))
	writer.u32(state.roster_count())
	for index: int in range(state.roster_count()):
		var piece: RunPieceInstance = state.roster_at(index, status)
		writer.u32(piece.instance_id()); writer.u32(piece.piece_numeric_id()); writer.u16(piece.level()); writer.u16(piece.counter_count())
		for counter_index: int in range(piece.counter_count()):
			var counter: RunCounter = piece.counter_at(counter_index, status); writer.u16(counter.kind_id()); writer.i64(counter.value())
	writer.u16(state.deployment_count())
	for index: int in range(state.deployment_count()): writer.u32(state.deployment_instance_id_at(index, status))
	writer.u16(state.relic_count())
	for index: int in range(state.relic_count()): writer.u32(state.relic_numeric_id_at(index, status))
	writer.u16(state.consumable_stack_count())
	for index: int in range(state.consumable_stack_count()):
		var stack: RunConsumableStack = state.consumable_stack_at(index, status); writer.u32(stack.consumable_numeric_id()); writer.u16(stack.count())
	var pending: RunPendingChoice = state.pending_choice_copy()
	writer.u16(pending.kind_id()); writer.u32(pending.source_node_id()); writer.u32(pending.generation_ordinal()); writer.u16(pending.entry_count())
	for index: int in range(pending.entry_count()):
		var entry: RunChoiceEntry = pending.entry_at(index, status)
		writer.u16(entry.choice_id()); writer.u16(entry.kind_id()); writer.u32(entry.primary_numeric_id()); writer.u32(entry.secondary_numeric_id()); writer.i64(entry.amount()); writer.u32(entry.cost()); writer.u8(1 if entry.enabled() else 0)
	if not status.is_ok() or writer.data.size() > RunLimits.SNAPSHOT_MAX_BYTES:
		if status.is_ok(): status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED, SimStatus.Operation.RUN_SNAPSHOT_ENCODE, writer.data.size(), RunLimits.SNAPSHOT_MAX_BYTES)
		return PackedByteArray()
	return writer.data

static func _fail_decode(status: SimStatus, detail_a: int = 0, detail_b: int = 0) -> Decoded:
	if status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.RUN_SNAPSHOT_DECODE, detail_a, detail_b)
	return Decoded.new()

static func _strictly_sorted_ids(values: Array[int], max_value: int = 0) -> bool:
	var previous: int = 0
	for value: int in values:
		if value <= previous or (max_value > 0 and value > max_value): return false
		previous = value
	return true

static func _contains_sorted(values: Array[int], target: int) -> bool:
	var index: int = values.bsearch(target)
	return index < values.size() and values[index] == target

static func _roster_contains(roster: Array[RunPieceInstance], instance_id: int) -> bool:
	for piece: RunPieceInstance in roster:
		if piece.instance_id() == instance_id: return true
		if piece.instance_id() > instance_id: return false
	return false

static func _parse(bytes: PackedByteArray, status: SimStatus) -> Decoded:
	var result := Decoded.new()
	if not status.is_ok(): return result
	if bytes.size() > RunLimits.SNAPSHOT_MAX_BYTES or bytes.size() < MAGIC.size() + 2 + 32:
		status.fail(SimStatus.Code.RUN_LIMIT_EXCEEDED if bytes.size() > RunLimits.SNAPSHOT_MAX_BYTES else SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.RUN_SNAPSHOT_DECODE, bytes.size(), RunLimits.SNAPSHOT_MAX_BYTES); return result
	var reader := Reader.new(bytes)
	for expected: int in MAGIC:
		if reader.u8() != expected: return _fail_decode(status, reader.offset - 1, expected)
	var schema_version: int = reader.u16()
	if schema_version != SCHEMA_VERSION:
		status.fail(SimStatus.Code.UNSUPPORTED_SCHEMA, SimStatus.Operation.RUN_SNAPSHOT_DECODE, schema_version, SCHEMA_VERSION); return result
	result.fingerprint = reader.bytes(32); result.seed_hi = reader.u32(); result.seed_lo = reader.u32(); result.phase_id = reader.u16(); result.act_numeric_id = reader.u32()
	result.current_floor = reader.u16(); result.current_node_id = reader.u32(); result.life = reader.u16(); result.max_life = reader.u16(); result.gold = reader.u32()
	result.roster_capacity = reader.u16(); result.deployment_capacity = reader.u16(); result.next_piece_instance_id = reader.u32(); result.next_transition_sequence = reader.u32()
	if not reader.valid or not RunPhase.is_valid(result.phase_id) or result.act_numeric_id <= 0 or result.max_life < 1 or result.max_life > RunLimits.MAX_LIFE or result.life > result.max_life or result.roster_capacity < 1 or result.roster_capacity > RunLimits.MAX_ROSTER or result.deployment_capacity < 1 or result.deployment_capacity > RunLimits.MAX_DEPLOYMENT or result.deployment_capacity > result.roster_capacity or result.next_piece_instance_id <= 0 or result.next_transition_sequence <= 0:
		return _fail_decode(status, reader.offset, result.phase_id)
	var floor_count: int = reader.u16(); var node_count: int = reader.u32()
	if node_count < 1 or node_count > RunLimits.MAX_NODES or floor_count < 1 or floor_count > RunLimits.MAX_FLOORS or node_count > reader.remaining() / 16: return _fail_decode(status, node_count, reader.remaining())
	var nodes: Array[RunNode] = []
	for index: int in range(node_count):
		var node_id: int = reader.u32(); var floor_index: int = reader.u16(); var slot_index: int = reader.u16(); var node_type_id: int = reader.u16(); var content_numeric_id: int = reader.u32(); var edge_count: int = reader.u16()
		if edge_count > RunLimits.MAX_EDGES_PER_NODE or edge_count > reader.remaining() / 4: return _fail_decode(status, edge_count, reader.remaining())
		var edges: Array[int] = []
		for edge_index: int in range(edge_count): edges.append(reader.u32())
		var node_status := SimStatus.new(); var node: RunNode = RunNode.create(node_id, floor_index, slot_index, node_type_id, content_numeric_id, edges, node_status)
		if not node_status.is_ok(): return _fail_decode(status, reader.offset, node_status.code())
		nodes.append(node)
	var graph_status := SimStatus.new(); result.graph = RunNodeGraph.create(floor_count, nodes, graph_status)
	if not graph_status.is_ok(): return _fail_decode(status, reader.offset, graph_status.code())
	if result.current_floor > floor_count or result.current_node_id > node_count: return _fail_decode(status, result.current_floor, result.current_node_id)
	var visited_count: int = reader.u32()
	if visited_count > RunLimits.MAX_NODES or visited_count > reader.remaining() / 4: return _fail_decode(status, visited_count, reader.remaining())
	for index: int in range(visited_count): result.visited_node_ids.append(reader.u32())
	if not _strictly_sorted_ids(result.visited_node_ids, node_count): return _fail_decode(status, reader.offset, visited_count)
	var completed_count: int = reader.u32()
	if completed_count > RunLimits.MAX_NODES or completed_count > reader.remaining() / 4: return _fail_decode(status, completed_count, reader.remaining())
	for index: int in range(completed_count): result.completed_node_ids.append(reader.u32())
	if not _strictly_sorted_ids(result.completed_node_ids, node_count): return _fail_decode(status, reader.offset, completed_count)
	for completed_id: int in result.completed_node_ids:
		if not _contains_sorted(result.visited_node_ids, completed_id): return _fail_decode(status, reader.offset, completed_id)
	var roster_count: int = reader.u32()
	if roster_count < 1 or roster_count > RunLimits.MAX_ROSTER or roster_count > reader.remaining() / 12: return _fail_decode(status, roster_count, reader.remaining())
	for index: int in range(roster_count):
		var instance_id: int = reader.u32(); var piece_numeric_id: int = reader.u32(); var level: int = reader.u16(); var counter_count: int = reader.u16()
		if counter_count > RunLimits.MAX_COUNTERS_PER_PIECE or counter_count > reader.remaining() / 10: return _fail_decode(status, counter_count, reader.remaining())
		var counters: Array[RunCounter] = []
		for counter_index: int in range(counter_count):
			var counter_status := SimStatus.new(); var counter: RunCounter = RunCounter.create(reader.u16(), reader.i64(), counter_status)
			if not counter_status.is_ok(): return _fail_decode(status, reader.offset, counter_status.code())
			counters.append(counter)
		var piece_status := SimStatus.new(); var piece: RunPieceInstance = RunPieceInstance.restore(instance_id, piece_numeric_id, level, counters, piece_status)
		if not piece_status.is_ok(): return _fail_decode(status, reader.offset, piece_status.code())
		if not result.roster.is_empty() and instance_id <= result.roster[-1].instance_id(): return _fail_decode(status, reader.offset, instance_id)
		result.roster.append(piece)
	if roster_count > result.roster_capacity or result.next_piece_instance_id <= result.roster[-1].instance_id(): return _fail_decode(status, roster_count, result.next_piece_instance_id)
	var deployment_count: int = reader.u16()
	if deployment_count > RunLimits.MAX_DEPLOYMENT or deployment_count > reader.remaining() / 4: return _fail_decode(status, deployment_count, reader.remaining())
	if deployment_count > result.deployment_capacity: return _fail_decode(status, deployment_count, result.deployment_capacity)
	for index: int in range(deployment_count):
		var instance_id: int = reader.u32()
		if not _roster_contains(result.roster, instance_id) or result.deployment_instance_ids.has(instance_id): return _fail_decode(status, reader.offset, instance_id)
		result.deployment_instance_ids.append(instance_id)
	var relic_count: int = reader.u16()
	if relic_count > RunLimits.MAX_RELICS or relic_count > reader.remaining() / 4: return _fail_decode(status, relic_count, reader.remaining())
	for index: int in range(relic_count): result.relic_numeric_ids.append(reader.u32())
	if not _strictly_sorted_ids(result.relic_numeric_ids): return _fail_decode(status, reader.offset, relic_count)
	var consumable_count: int = reader.u16()
	if consumable_count > RunLimits.MAX_CONSUMABLE_STACKS or consumable_count > reader.remaining() / 6: return _fail_decode(status, consumable_count, reader.remaining())
	var previous_consumable_id: int = 0
	for index: int in range(consumable_count):
		var stack_status := SimStatus.new(); var stack: RunConsumableStack = RunConsumableStack.create(reader.u32(), reader.u16(), stack_status)
		if not stack_status.is_ok() or stack.consumable_numeric_id() <= previous_consumable_id: return _fail_decode(status, reader.offset, stack_status.code() if not stack_status.is_ok() else stack.consumable_numeric_id())
		result.consumable_stacks.append(stack); previous_consumable_id = stack.consumable_numeric_id()
	if reader.remaining() < 12: return _fail_decode(status, reader.remaining(), 12)
	var pending_kind: int = reader.u16(); var source_node_id: int = reader.u32(); var generation_ordinal: int = reader.u32(); var entry_count: int = reader.u16()
	if entry_count > RunLimits.MAX_PENDING_ENTRIES or entry_count > reader.remaining() / 25: return _fail_decode(status, entry_count, reader.remaining())
	var entries: Array[RunChoiceEntry] = []
	for index: int in range(entry_count):
		var choice_id: int = reader.u16(); var choice_kind: int = reader.u16(); var primary_id: int = reader.u32(); var secondary_id: int = reader.u32(); var amount: int = reader.i64(); var cost: int = reader.u32(); var enabled: int = reader.u8()
		if enabled > 1: return _fail_decode(status, enabled, index)
		var choice_status := SimStatus.new(); var entry: RunChoiceEntry = RunChoiceEntry.create(choice_id, choice_kind, primary_id, secondary_id, amount, cost, enabled == 1, choice_status)
		if not choice_status.is_ok(): return _fail_decode(status, reader.offset, choice_status.code())
		entries.append(entry)
	var pending_status := SimStatus.new(); result.pending_choice = RunPendingChoice.create(pending_kind, source_node_id, generation_ordinal, entries, pending_status)
	if not pending_status.is_ok() or (pending_kind != RunPendingKind.Value.NONE and source_node_id > node_count): return _fail_decode(status, reader.offset, pending_status.code() if not pending_status.is_ok() else source_node_id)
	if not reader.valid or reader.remaining() != 0: return _fail_decode(status, reader.remaining(), reader.offset)
	result.initialized = true
	return result
