extends Node

const RUN_SCENE := "res://scenes/run_graybox.tscn"
const CONFIG_PATH := "res://src/ui/run/submission_showcase.json"

var failures: int = 0


func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else:
		failures += 1
		print("[FAIL] %s" % label)


func write_fixture(name: String, text: String) -> String:
	var path := "user://%s_%d.json" % [name, OS.get_process_id()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func invalid_fixture(catalog: ContentCatalog, name: String, text: String, expected_code: int) -> void:
	var path: String = write_fixture(name, text)
	var status := ContentStatus.new()
	var config: SubmissionShowcaseConfig = SubmissionShowcaseConfig.load_file(path, catalog, status)
	check("P5-FP-INVALID-%s" % name.to_upper(), not status.is_ok() and status.code() == expected_code and not config.is_initialized())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _ready() -> void:
	var content_status := ContentStatus.new()
	var catalog: ContentCatalog = DataDB.catalog_copy(content_status)
	var config_status := ContentStatus.new()
	var config: SubmissionShowcaseConfig = SubmissionShowcaseConfig.load_file(CONFIG_PATH, catalog, config_status)
	check("P5-FP-CONFIG-STRICT-LOAD", content_status.is_ok() and config_status.is_ok() and config.is_initialized())
	check("P5-FP-CONFIG-FIXED-CONTENT", config.map_numeric_id() == 1 and config.encounter_numeric_id() == 1 and config.piece_numeric_ids() == [4, 5, 6] and config.seed_hi() == 0 and config.seed_lo() == 1)
	invalid_fixture(catalog, "unknown_key", '{"version":1,"map_ref":{"numeric_id":1,"id":"graybox_pit_arena"},"encounter_ref":{"numeric_id":1,"id":"development_normal_mixed"},"piece_refs":[{"numeric_id":4,"id":"bouncy_ball"},{"numeric_id":5,"id":"caveman"},{"numeric_id":6,"id":"ai_core"}],"seed":"0000000000000001","extra":1}', ContentStatus.Code.UNKNOWN_KEY)
	invalid_fixture(catalog, "id_mismatch", '{"version":1,"map_ref":{"numeric_id":1,"id":"wrong"},"encounter_ref":{"numeric_id":1,"id":"development_normal_mixed"},"piece_refs":[{"numeric_id":4,"id":"bouncy_ball"},{"numeric_id":5,"id":"caveman"},{"numeric_id":6,"id":"ai_core"}],"seed":"0000000000000001"}', ContentStatus.Code.MISSING_REFERENCE)
	invalid_fixture(catalog, "duplicate_piece", '{"version":1,"map_ref":{"numeric_id":1,"id":"graybox_pit_arena"},"encounter_ref":{"numeric_id":1,"id":"development_normal_mixed"},"piece_refs":[{"numeric_id":4,"id":"bouncy_ball"},{"numeric_id":4,"id":"bouncy_ball"},{"numeric_id":6,"id":"ai_core"}],"seed":"0000000000000001"}', ContentStatus.Code.DUPLICATE_ID)
	invalid_fixture(catalog, "duplicate_key", '{"version":1,"version":1,"map_ref":{"numeric_id":1,"id":"graybox_pit_arena"},"encounter_ref":{"numeric_id":1,"id":"development_normal_mixed"},"piece_refs":[{"numeric_id":4,"id":"bouncy_ball"},{"numeric_id":5,"id":"caveman"},{"numeric_id":6,"id":"ai_core"}],"seed":"0000000000000001"}', ContentStatus.Code.DUPLICATE_KEY)

	var packed: PackedScene = load(RUN_SCENE) as PackedScene
	var scene: RunGraybox = packed.instantiate() as RunGraybox if packed != null else null
	check("P5-FP-RUN-SCENE-LOAD", scene != null)
	if scene != null:
		get_tree().root.add_child.call_deferred(scene)
		await get_tree().process_frame
		await get_tree().process_frame
		var body: VBoxContainer = scene.get_node("Content/Body") as VBoxContainer
		var primary_cta: Button = null
		for child: Node in body.get_children():
			if child is Button:
				primary_cta = child as Button
				break
		check("P5-FP-PRIMARY-CTA-FIRST", primary_cta != null and primary_cta.text == "5분 전투 체험" and not primary_cta.disabled)
		scene.call("_open_showcase_intro")
		check("P5-FP-INTRO-GUIDE", scene.get_node("ShowcaseIntro").visible and String((scene.get_node("ShowcaseIntro/Margin/Rows/Guide") as Label).text).contains("반대 방향"))
		scene.call("_start_showcase_battle")
		await get_tree().process_frame
		var battle: P2ContentGraybox = scene.get_node("Battle") as P2ContentGraybox
		var state: BattleState = battle.get("_state") as BattleState
		var ids: Array[int] = []
		var sim_status := SimStatus.new()
		for index: int in range(3): ids.append(state.piece_identity_at(index, sim_status).piece_numeric_id())
		check("P5-FP-CURATED-FORMATION", sim_status.is_ok() and ids == [4, 5, 6])
		check("P5-FP-SHOWCASE-NO-ACTIVE-RUN", not RunManager.has_active_run())
		check("P5-FP-HELP-ENTRY", scene.get_node("ShowcaseHelpButton").visible)
		var seen_before: int = (scene.get("_showcase_seen_piece_hints") as Dictionary).size()
		scene.call("_on_showcase_player_turn_started", 4)
		var first_hint: String = (scene.get_node("ShowcaseHint/Margin/Label") as Label).text
		var seen_after_first: int = (scene.get("_showcase_seen_piece_hints") as Dictionary).size()
		scene.call("_on_showcase_player_turn_started", 4)
		check("P5-FP-PIECE-HINT-ONCE", scene.get_node("ShowcaseHint").visible and first_hint.contains("탱탱볼") and seen_after_first == seen_before + 1 and (scene.get("_showcase_seen_piece_hints") as Dictionary).size() == seen_after_first)
		scene.call("_on_showcase_zone_damage")
		check("P5-FP-ZONE-HINT", String((scene.get_node("ShowcaseHint/Margin/Label") as Label).text).contains("겹친 구역"))
		scene.call("_on_showcase_battle_finished", BattleResult.Value.PLAYER_VICTORY)
		check("P5-FP-END-CTA", scene.get_node("ShowcaseEnd").visible and String((scene.get_node("ShowcaseEnd/Margin/Rows/Result") as Label).text).contains("승리"))
		scene.call("_leave_showcase")
		check("P5-FP-LEAVE-RESTORES-START", not bool(scene.get("_showcase_active")) and not battle.visible and scene.get_node("Content").visible)
		scene.free()

	print("P5_FIRST_PLAY_FIVE_MINUTE_FLOW_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(0 if failures == 0 else 1)
