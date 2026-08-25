extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const EXPECTED_FINGERPRINT: String = "ed6dd1319f158a539ffe4bc89bce965ea1061586b1e462a7e211bb8f0f561e3e"
const EXPECTED_GRAPH: String = "1:1:0:1:1>2,3|2:2:0:3:1>4|3:2:1:4:1>5|4:3:0:1:1>6|5:3:1:2:3>6|6:4:0:5:0>7|7:5:0:6:4>"

var failures: int = 0

func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)

func graph_signature(graph: RunNodeGraph, status: SimStatus) -> String:
	var parts: PackedStringArray = []
	for index: int in range(graph.node_count()):
		var node: RunNode = graph.node_at(index, status)
		var edges: PackedStringArray = []
		for edge_index: int in range(node.next_node_count()): edges.append(str(node.next_node_id_at(edge_index, status)))
		parts.append("%d:%d:%d:%d:%d>%s" % [node.node_id(), node.floor_index(), node.slot_index(), node.node_type_id(), node.content_numeric_id(), ",".join(edges)])
	return "|".join(parts)

func tampered_graph(source: RunNodeGraph, status: SimStatus) -> RunNodeGraph:
	var nodes: Array[RunNode] = []
	for index: int in range(source.node_count()):
		var node: RunNode = source.node_at(index, status)
		var edges: Array[int] = []
		for edge_index: int in range(node.next_node_count()): edges.append(node.next_node_id_at(edge_index, status))
		var content_id: int = 2 if index == 0 else node.content_numeric_id()
		nodes.append(RunNode.create(node.node_id(), node.floor_index(), node.slot_index(), node.node_type_id(), content_id, edges, status))
	return RunNodeGraph.create(source.floor_count(), nodes, status)

func test_catalog(catalog: ContentCatalog) -> void:
	var status := ContentStatus.new()
	var act: ActDefinition = catalog.act_by_numeric_id(1, status)
	var elite: EncounterDefinition = catalog.encounter_by_string_id("development_elite_pair", status)
	var boss: EncounterDefinition = catalog.encounter_by_numeric_id(4, status)
	check("P4-2-CATALOG-V7-COUNTS", status.is_ok() and catalog.catalog_schema_version() == 7 and catalog.registry_entry_count() == 20 and catalog.act_count() == 1 and catalog.encounter_count() == 4 and catalog.enemy_count() == 5 and catalog.relic_count() == 0 and catalog.consumable_count() == 0)
	check("P4-2-ACT-ENCOUNTER-TYPED", status.is_ok() and act.is_initialized() and act.is_development() and act.floor_count() == 5 and elite.node_type_id() == RunNodeType.Value.ELITE_BATTLE and elite.enemy_ref_count() == 3 and boss.node_type_id() == RunNodeType.Value.BOSS and boss.reward_profile_numeric_id() == 3)
	var copy: ActDefinition = act.copy()
	check("P4-2-CATALOG-DEEP-COPY", copy.is_initialized() and copy.numeric_id() == act.numeric_id() and copy.floor_count() == act.floor_count())

func test_graph(catalog: ContentCatalog) -> void:
	var status := SimStatus.new()
	var graph: RunNodeGraph = RunMapGenerator.generate(catalog, 1, 17, 29, status)
	var signature: String = graph_signature(graph, status)
	check("P4-2-GRAPH-EXACT-KAT", status.is_ok() and graph.floor_count() == 5 and graph.node_count() == 7 and signature == EXPECTED_GRAPH)
	var deterministic: bool = true
	for index: int in range(1000):
		var repeat_status := SimStatus.new()
		if graph_signature(RunMapGenerator.generate(catalog, 1, 17, 29, repeat_status), repeat_status) != EXPECTED_GRAPH or not repeat_status.is_ok(): deterministic = false; break
	check("P4-2-GRAPH-DETERMINISM-1000", deterministic)
	var exact_status := SimStatus.new(); var exact: bool = RunMapGenerator.validate_exact(catalog, 1, 17, 29, graph, exact_status)
	var tamper_build_status := SimStatus.new(); var tampered: RunNodeGraph = tampered_graph(graph, tamper_build_status)
	var tamper_status := SimStatus.new(); var tamper_exact: bool = RunMapGenerator.validate_exact(catalog, 1, 17, 29, tampered, tamper_status)
	var seed_status := SimStatus.new(); var seed_exact: bool = RunMapGenerator.validate_exact(catalog, 1, 18, 29, graph, seed_status)
	check("P4-2-GRAPH-EXACT-VALIDATION", exact and exact_status.is_ok() and tamper_build_status.is_ok() and not tamper_exact and tamper_status.code() == SimStatus.Code.INVALID_RUN_GRAPH and not seed_exact and seed_status.code() == SimStatus.Code.INVALID_RUN_GRAPH)

func test_weighted_selection() -> void:
	var content_status := ContentStatus.new()
	var normal_refs: Array[ActContentRef] = [ActContentRef.create(1, "normal_profile", content_status)]
	var elite_refs: Array[ActContentRef] = [ActContentRef.create(3, "elite_profile", content_status)]
	var options: Array[ActNodeOptionDefinition] = [
		ActNodeOptionDefinition.create(RunNodeType.Value.NORMAL_BATTLE, 1, normal_refs, content_status),
		ActNodeOptionDefinition.create(RunNodeType.Value.ELITE_BATTLE, 3, elite_refs, content_status),
	]
	var slot: ActNodeSlotDefinition = ActNodeSlotDefinition.create(0, options, content_status)
	var first_status := SimStatus.new(); var first: ActNodeOptionDefinition = RunMapGenerator._select_option(slot, 17, 29, 1, 42, first_status)
	var second_status := SimStatus.new(); var second: ActNodeOptionDefinition = RunMapGenerator._select_option(slot, 17, 29, 1, 4, second_status)
	var max_options: Array[ActNodeOptionDefinition] = [
		ActNodeOptionDefinition.create(RunNodeType.Value.NORMAL_BATTLE, 1, normal_refs, content_status),
		ActNodeOptionDefinition.create(RunNodeType.Value.ELITE_BATTLE, ContentLimits.UINT32_MAX, elite_refs, content_status),
	]
	var max_slot: ActNodeSlotDefinition = ActNodeSlotDefinition.create(0, max_options, content_status)
	check("P4-2-WEIGHTED-UINT32-SPACE", content_status.is_ok() and first_status.is_ok() and second_status.is_ok() and first.node_type_id() == RunNodeType.Value.NORMAL_BATTLE and second.node_type_id() == RunNodeType.Value.ELITE_BATTLE and max_slot.total_weight() == ContentLimits.UINT32_SPACE)

func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new()
	var loaded: bool = bool(db.call("reload_catalog", "res://src/core/data", content_status))
	var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P4-2-RUNTIME-CATALOG-LOAD", loaded and content_status.is_ok() and catalog.fingerprint_hex() == EXPECTED_FINGERPRINT)
	if loaded and content_status.is_ok(): test_catalog(catalog); test_graph(catalog); test_weighted_selection()
	print("P4_ACT_ENCOUNTER_MAP_GENERATION_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
