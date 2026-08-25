extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const EXPECTED_HEX: String = "464c49434b52554e00010089340a848cea8b0ec2b688243a16945bb6e071d6f28e9948e6cefe04e0d011f3110000001d00000001000100000000000000000003000300000000000a000500070000000100000005000700000001000000010000000100e90300000200020000000300000002000000020000000300ea0300000200040000000500000003000000020001000400eb0300000200040000000500000004000000030000000100ec03000001000600000005000000030001000200ed030000010006000000060000000400000005000000000001000700000007000000050000000600ef0300000000000000000000000006000000010000000100000001000000020000000100000001000000030000000100000001000000040000000200000001000000050000000200000001000000060000000200000001000000000000000000010000000000000000000000"
const EXPECTED_SHA256: String = "e2120285dd7abfe00d085413b4a4f4244591f7e98c03fa3e1626d58e8996dd64"

var failures: int = 0

func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)

func fixture_graph(status: SimStatus) -> RunNodeGraph:
	var nodes: Array[RunNode] = [
		RunNode.create(1, 1, 0, RunNodeType.Value.NORMAL_BATTLE, 1001, [2, 3], status),
		RunNode.create(2, 2, 0, RunNodeType.Value.SHOP, 1002, [4, 5], status),
		RunNode.create(3, 2, 1, RunNodeType.Value.EVENT, 1003, [4, 5], status),
		RunNode.create(4, 3, 0, RunNodeType.Value.NORMAL_BATTLE, 1004, [6], status),
		RunNode.create(5, 3, 1, RunNodeType.Value.ELITE_BATTLE, 1005, [6], status),
		RunNode.create(6, 4, 0, RunNodeType.Value.REST, 0, [7], status),
		RunNode.create(7, 5, 0, RunNodeType.Value.BOSS, 1007, [], status),
	]
	return RunNodeGraph.create(5, nodes, status)

func fixture_initial(order: Array[int], status: SimStatus) -> Array[RunPieceInit]:
	var result: Array[RunPieceInit] = []
	for key: int in order:
		result.append(RunPieceInit.create(key, 1 if key <= 3 else 2, 1, [], status))
	return result

func fixture_state(catalog: ContentCatalog, order: Array[int], status: SimStatus) -> RunState:
	return RunState.create(catalog, 1, fixture_graph(status), 17, 29, fixture_initial(order, status), status)

func write_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xFF; bytes[offset + 1] = (value >> 8) & 0xFF

func write_u32(bytes: PackedByteArray, offset: int, value: int) -> void:
	for shift: int in range(0, 32, 8): bytes[offset + (shift >> 3)] = (value >> shift) & 0xFF

func append_u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xFF); bytes.append((value >> 8) & 0xFF)

func append_u32(bytes: PackedByteArray, value: int) -> void:
	for shift: int in range(0, 32, 8): bytes.append((value >> shift) & 0xFF)

func append_i64(bytes: PackedByteArray, value: int) -> void:
	for shift: int in range(0, 64, 8): bytes.append((value >> shift) & 0xFF)

func rejected(bytes: PackedByteArray) -> bool:
	var status := SimStatus.new(); var snapshot: RunSnapshot = RunSnapshot.decode(bytes, status)
	return not status.is_ok() and not snapshot.is_initialized()

func test_value_contracts(catalog: ContentCatalog) -> void:
	check("P4-1-ENUM-STATUS-APPEND", SimStatus.Code.INVALID_RUN_STATE == 61 and SimStatus.Code.RUN_LIMIT_EXCEEDED == 67 and SimStatus.Operation.RUN_PIECE_INIT_CREATE == 134 and SimStatus.Operation.RUN_SNAPSHOT_RESTORE == 147 and RunPhase.Value.RUN_FAILED == 10 and RunNodeType.Value.BOSS == 6)
	var counter_status := SimStatus.new(); var counters: Array[RunCounter] = [RunCounter.create(RunCounterKind.Value.BATTLES_SURVIVED, 3, counter_status), RunCounter.create(RunCounterKind.Value.KILLS, 7, counter_status)]
	var instance: RunPieceInstance = RunPieceInstance.restore(9, 1, 1, counters, counter_status)
	var zero_status := SimStatus.new(); RunCounter.create(RunCounterKind.Value.KILLS, 0, zero_status)
	check("P4-1-COUNTER-CANONICAL", counter_status.is_ok() and instance.counter_value(RunCounterKind.Value.BATTLES_SURVIVED) == 3 and instance.counter_value(99) == 0 and zero_status.code() == SimStatus.Code.INVALID_RUN_COUNTER)
	var none_status := SimStatus.new(); var none: RunPendingChoice = RunPendingChoice.none(none_status)
	var bad_none_status := SimStatus.new(); RunPendingChoice.create(RunPendingKind.Value.NONE, 1, 0, [], bad_none_status)
	var future_status := SimStatus.new(); var entries: Array[RunChoiceEntry] = [RunChoiceEntry.create(1, RunChoiceKind.Value.GAIN_GOLD, 0, 0, 10, 0, true, future_status)]
	var future: RunPendingChoice = RunPendingChoice.create(RunPendingKind.Value.REWARD, 7, 1, entries, future_status)
	check("P4-1-PENDING-TYPED-SLOTS", none_status.is_ok() and none.kind_id() == RunPendingKind.Value.NONE and bad_none_status.code() == SimStatus.Code.INVALID_RUN_CHOICE and future_status.is_ok() and future.entry_count() == 1)
	var invalid_status := SimStatus.new(); RunState.create(catalog, 1, fixture_graph(invalid_status), 0, 0, fixture_initial([1, 1, 3, 4, 5, 6], invalid_status), invalid_status)
	check("P4-1-DUPLICATE-INITIAL-KEY-REJECT", invalid_status.code() == SimStatus.Code.INVALID_RUN_PIECE_INSTANCE)
	var missing_status := SimStatus.new(); var missing: Array[RunPieceInit] = fixture_initial([1, 2, 3, 4, 5, 6], missing_status); missing[0] = RunPieceInit.create(1, 999, 1, [], missing_status); var missing_state: RunState = RunState.create(catalog, 1, fixture_graph(missing_status), 0, 0, missing, missing_status)
	var level_status := SimStatus.new(); var bad_level: Array[RunPieceInit] = fixture_initial([1, 2, 3, 4, 5, 6], level_status); bad_level[0] = RunPieceInit.create(1, 1, 2, [], level_status); var level_state: RunState = RunState.create(catalog, 1, fixture_graph(level_status), 0, 0, bad_level, level_status)
	var count_status := SimStatus.new(); var too_many: Array[RunPieceInit] = []
	for key: int in range(1, 12): too_many.append(RunPieceInit.create(key, 1, 1, [], count_status))
	var count_state: RunState = RunState.create(catalog, 1, fixture_graph(count_status), 0, 0, too_many, count_status)
	check("P4-1-PIECE-CATALOG-LEVEL-ROSTER-LIMIT", missing_status.code() == SimStatus.Code.INVALID_RUN_PIECE_INSTANCE and not missing_state.is_initialized() and level_status.code() == SimStatus.Code.INVALID_RUN_PIECE_INSTANCE and not level_state.is_initialized() and count_status.code() == SimStatus.Code.RUN_LIMIT_EXCEEDED and not count_state.is_initialized())

func test_graph_rejections() -> void:
	var status := SimStatus.new(); var graph: RunNodeGraph = fixture_graph(status)
	var gap_status := SimStatus.new(); var gap_nodes: Array[RunNode] = [RunNode.create(1, 1, 0, RunNodeType.Value.NORMAL_BATTLE, 1, [2], gap_status), RunNode.create(2, 2, 1, RunNodeType.Value.BOSS, 2, [], gap_status)]
	var gap: RunNodeGraph = RunNodeGraph.create(2, gap_nodes, gap_status)
	var edge_status := SimStatus.new(); var edge_nodes: Array[RunNode] = [RunNode.create(1, 1, 0, RunNodeType.Value.NORMAL_BATTLE, 1, [3], edge_status), RunNode.create(2, 2, 0, RunNodeType.Value.NORMAL_BATTLE, 2, [3], edge_status), RunNode.create(3, 3, 0, RunNodeType.Value.BOSS, 3, [], edge_status)]
	var bad_edge: RunNodeGraph = RunNodeGraph.create(3, edge_nodes, edge_status)
	var content_status := SimStatus.new(); var bad_rest: RunNode = RunNode.create(1, 1, 0, RunNodeType.Value.REST, 99, [], content_status)
	check("P4-1-GRAPH-FIXTURE-AND-REJECTIONS", status.is_ok() and graph.node_count() == 7 and gap_status.code() == SimStatus.Code.INVALID_RUN_GRAPH and not gap.is_initialized() and edge_status.code() == SimStatus.Code.INVALID_RUN_GRAPH and not bad_edge.is_initialized() and content_status.code() == SimStatus.Code.INVALID_RUN_NODE and not bad_rest.is_initialized())

func test_snapshot(catalog: ContentCatalog) -> PackedByteArray:
	var status := SimStatus.new(); var state: RunState = fixture_state(catalog, [6, 2, 5, 1, 4, 3], status)
	var snapshot: RunSnapshot = RunSnapshot.capture(state, status); var bytes: PackedByteArray = snapshot.encode(status)
	check("P4-1-STATE-DEFAULTS-AND-ID-ORDER", status.is_ok() and state.life() == 3 and state.gold() == 0 and state.phase_id() == RunPhase.Value.MAP_CHOICE and state.roster_capacity() == 10 and state.deployment_capacity() == 5 and state.next_piece_instance_id() == 7 and state.roster_at(0, status).piece_numeric_id() == 1 and state.roster_at(5, status).piece_numeric_id() == 2)
	check("P4-1-BINARY-KAT", status.is_ok() and bytes.hex_encode() == EXPECTED_HEX and snapshot.state_hash_hex(status) == EXPECTED_SHA256)
	var decoded: RunSnapshot = RunSnapshot.decode(bytes, status); var restored: RunState = decoded.restore_state(catalog, status); var roundtrip: PackedByteArray = RunSnapshot.capture(restored, status).encode(status)
	check("P4-1-CODEC-RESTORE-EXACT", status.is_ok() and decoded.encode(status) == bytes and roundtrip == bytes)
	var copy_status := SimStatus.new(); var copied: RunState = state.copy(copy_status); copied._visited_node_ids.append(1)
	var original_again: PackedByteArray = RunSnapshot.capture(state, copy_status).encode(copy_status)
	check("P4-1-DEEP-COPY-ORIGINAL-IMMUTABLE", copy_status.is_ok() and original_again == bytes and copied.visited_node_count() == 1 and state.visited_node_count() == 0)
	return bytes

func test_snapshot_rejections(catalog: ContentCatalog, bytes: PackedByteArray) -> void:
	var bad_magic: PackedByteArray = bytes.duplicate(); bad_magic[0] = 0
	var bad_version: PackedByteArray = bytes.duplicate(); write_u16(bad_version, 9, 2)
	var count_bomb: PackedByteArray = bytes.duplicate(); write_u32(count_bomb, 85, RunLimits.MAX_NODES + 1)
	var trailing: PackedByteArray = bytes.duplicate(); trailing.append(0)
	var bad_phase: PackedByteArray = bytes.duplicate(); write_u16(bad_phase, 51, 99)
	var zero_act: PackedByteArray = bytes.duplicate(); write_u32(zero_act, 53, 0)
	var bad_life: PackedByteArray = bytes.duplicate(); write_u16(bad_life, 63, 4)
	var zero_capacity: PackedByteArray = bytes.duplicate(); write_u16(zero_capacity, 71, 0)
	var zero_next_id: PackedByteArray = bytes.duplicate(); write_u32(zero_next_id, 75, 0)
	var bad_node_type: PackedByteArray = bytes.duplicate(); write_u16(bad_node_type, 97, 99)
	var duplicate_roster_id: PackedByteArray = bytes.duplicate(); write_u32(duplicate_roster_id, 261, 1)
	var all_cuts_rejected: bool = true
	for length: int in range(bytes.size()):
		if not rejected(bytes.slice(0, length)): all_cuts_rejected = false; break
	check("P4-1-SNAPSHOT-CORRUPTION-COUNT-BOMB-TRUNCATION", rejected(bad_magic) and rejected(bad_version) and rejected(count_bomb) and rejected(trailing) and rejected(bad_phase) and rejected(zero_act) and rejected(bad_life) and rejected(zero_capacity) and rejected(zero_next_id) and rejected(bad_node_type) and rejected(duplicate_roster_id) and all_cuts_rejected)
	var mismatch: PackedByteArray = bytes.duplicate(); mismatch[11] ^= 0xFF
	var mismatch_status := SimStatus.new(); var decoded: RunSnapshot = RunSnapshot.decode(mismatch, mismatch_status); var restored: RunState = decoded.restore_state(catalog, mismatch_status)
	check("P4-1-FINGERPRINT-MISMATCH", mismatch_status.code() == SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH and not restored.is_initialized() and decoded.encode(SimStatus.new()) == mismatch)
	var missing_piece: PackedByteArray = bytes.duplicate(); write_u32(missing_piece, 253, 999)
	var missing_status := SimStatus.new(); var missing_snapshot: RunSnapshot = RunSnapshot.decode(missing_piece, missing_status); var missing_state: RunState = missing_snapshot.restore_state(catalog, missing_status)
	var bad_level: PackedByteArray = bytes.duplicate(); write_u16(bad_level, 257, 2)
	var level_status := SimStatus.new(); var level_snapshot: RunSnapshot = RunSnapshot.decode(bad_level, level_status); var level_state: RunState = level_snapshot.restore_state(catalog, level_status)
	check("P4-1-RESTORE-CATALOG-PIECE-LEVEL", missing_status.code() == SimStatus.Code.INVALID_RUN_PIECE_INSTANCE and not missing_state.is_initialized() and level_status.code() == SimStatus.Code.INVALID_RUN_PIECE_INSTANCE and not level_state.is_initialized())
	var future: PackedByteArray = bytes.slice(0, 327)
	append_u16(future, RunPendingKind.Value.REWARD); append_u32(future, 7); append_u32(future, 1); append_u16(future, 1)
	append_u16(future, 1); append_u16(future, RunChoiceKind.Value.GAIN_GOLD); append_u32(future, 0); append_u32(future, 0); append_i64(future, 10); append_u32(future, 0); future.append(1)
	var future_status := SimStatus.new(); var future_snapshot: RunSnapshot = RunSnapshot.decode(future, future_status); var future_state: RunState = future_snapshot.restore_state(catalog, future_status)
	var bad_bool: PackedByteArray = future.duplicate(); bad_bool[bad_bool.size() - 1] = 2
	check("P4-1-FUTURE-PENDING-CODEC-RESTORE-GATE", future_snapshot.is_initialized() and future_snapshot.encode(SimStatus.new()) == future and future_status.code() == SimStatus.Code.INVALID_RUN_STATE and not future_state.is_initialized() and rejected(bad_bool))

func test_determinism(catalog: ContentCatalog, expected: PackedByteArray) -> void:
	var deterministic: bool = true
	for index: int in range(1000):
		var status := SimStatus.new(); var state: RunState = fixture_state(catalog, [1, 2, 3, 4, 5, 6], status); var copied: RunState = state.copy(status)
		var bytes: PackedByteArray = RunSnapshot.capture(copied, status).encode(status); var restored: RunState = RunSnapshot.decode(bytes, status).restore_state(catalog, status)
		if not status.is_ok() or bytes != expected or RunSnapshot.capture(restored, status).encode(status) != expected: deterministic = false; break
	check("P4-1-DETERMINISM-1000", deterministic)
	var permutations: Array[Array] = [
		[1,2,3,4,5,6],[1,2,4,3,5,6],[1,3,2,4,5,6],[1,3,4,2,5,6],[1,4,2,3,5,6],[1,4,3,2,5,6],
		[2,1,3,4,5,6],[2,1,4,3,5,6],[2,3,1,4,5,6],[2,3,4,1,5,6],[2,4,1,3,5,6],[2,4,3,1,5,6],
		[3,1,2,4,5,6],[3,1,4,2,5,6],[3,2,1,4,5,6],[3,2,4,1,5,6],[3,4,1,2,5,6],[3,4,2,1,5,6],
		[4,1,2,3,5,6],[4,1,3,2,5,6],[4,2,1,3,5,6],[4,2,3,1,5,6],[4,3,1,2,5,6],[4,3,2,1,5,6],
	]
	var same: bool = true
	for permutation: Array in permutations:
		var order: Array[int] = []
		for value: int in permutation: order.append(value)
		var status := SimStatus.new(); var actual: PackedByteArray = RunSnapshot.capture(fixture_state(catalog, order, status), status).encode(status)
		if not status.is_ok() or actual != expected: same = false; break
	check("P4-1-INITIAL-PERMUTATIONS-24", same)

func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new(); var loaded: bool = bool(db.call("reload_catalog", "res://src/core/data", content_status)); var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P4-1-RUNTIME-CATALOG-LOAD", loaded and content_status.is_ok() and catalog.fingerprint_hex() == "89340a848cea8b0ec2b688243a16945bb6e071d6f28e9948e6cefe04e0d011f3")
	if loaded and content_status.is_ok():
		test_value_contracts(catalog); test_graph_rejections(); var bytes: PackedByteArray = test_snapshot(catalog); test_snapshot_rejections(catalog, bytes); test_determinism(catalog, bytes)
	print("P4_RUN_STATE_SNAPSHOT_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
