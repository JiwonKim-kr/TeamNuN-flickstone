extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const CONTENT_DRIVER: Script = preload("res://src/ui/battle/p2_content_battle_driver.gd")
const RUNTIME_ROOT := "res://src/core/data"
var failures := 0

func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)

func deployment(catalog: ContentCatalog, status: SimStatus) -> Array[BattleDeploymentEntry]:
	var result: Array[BattleDeploymentEntry] = []; var cs := ContentStatus.new()
	for index: int in range(3):
		var piece: PieceDefinition = catalog.piece_at(index, cs)
		result.append(BattleDeploymentEntry.create_player(index, piece.id_ref(), 1, status))
	for index: int in range(3):
		var enemy: EnemyDefinition = catalog.enemy_at(index, cs)
		result.append(BattleDeploymentEntry.create_enemy(index, ContentIdRef.create(enemy.numeric_id(), enemy.string_id(), cs), status))
	return result

func aim_state(catalog: ContentCatalog, status: SimStatus) -> BattleState:
	var state := BattleSetupBuilder.build(catalog, 1, deployment(catalog, status), 17, 29, status)
	CONTENT_DRIVER.resolve_last_transition(state, status)
	if state.phase() == BattleState.Phase.BATTLE_START:
		state.complete_battle_start(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	state.complete_turn_start(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	return state

func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var cs := ContentStatus.new(); var loaded: bool = db.call("reload_catalog", RUNTIME_ROOT, cs)
	var catalog: ContentCatalog = db.call("catalog_copy", cs)
	check("P3-RUNTIME-LOAD", loaded and cs.is_ok())
	var grades_ok := loaded and cs.is_ok() and catalog.enemy_count() == 5
	if grades_ok:
		var expected_grades: Array[int] = [AiGrade.Value.COMMON, AiGrade.Value.COMMON, AiGrade.Value.COMMON, AiGrade.Value.ELITE, AiGrade.Value.BOSS]
		for enemy_index: int in range(catalog.enemy_count()):
			grades_ok = grades_ok and catalog.enemy_at(enemy_index, cs).ai_grade_id() == expected_grades[enemy_index]
	check("P3-RUNTIME-ENEMY-GRADES", grades_ok and cs.is_ok())
	if loaded and cs.is_ok():
		var status := SimStatus.new(); var state := aim_state(catalog, status)
		var before: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
		var candidates: Array[AiShotSelector.Candidate] = AiShotSelector.raw_candidates(state, status)
		var started := Time.get_ticks_msec()
		var common: LaunchCommand = AiShotSelector.command_for(state, AiGrade.Value.COMMON, status)
		var elapsed: int = Time.get_ticks_msec() - started
		if not status.is_ok(): print("P3_AI_ERROR:%d/%d/%d/%d phase=%d" % [status.code(), status.operation(), status.detail_a(), status.detail_b(), state.phase()])
		var after: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
		check("P3-CANDIDATE-BUDGET", status.is_ok() and candidates.size() > 0 and candidates.size() <= 100)
		check("P3-COMMAND-VALID", status.is_ok() and common.is_initialized() and LaunchLimits.valid_launch_power_step(common.power_step()))
		check("P3-SOURCE-STATE-IMMUTABLE", status.is_ok() and before == after)
		check("P3-SELECTION-WITHIN-500MS", elapsed <= 500)
		var repeat_ok := true
		for _repeat: int in range(5):
			var repeat_status := SimStatus.new()
			var repeated: LaunchCommand = AiShotSelector.command_for(state, AiGrade.Value.COMMON, repeat_status)
			if not repeat_status.is_ok() or not repeated.is_equal(common): repeat_ok = false; break
		check("P3-COMMAND-DETERMINISM-5", repeat_ok)
		var elite_status := SimStatus.new(); var elite: LaunchCommand = AiShotSelector.command_for(state, AiGrade.Value.ELITE, elite_status)
		var boss_status := SimStatus.new(); var boss: LaunchCommand = AiShotSelector.command_for(state, AiGrade.Value.BOSS, boss_status)
		check("P3-THREE-GRADES-VALID", elite_status.is_ok() and boss_status.is_ok() and elite.is_initialized() and boss.is_initialized())
		print("P3_AI_BENCHMARK_MS:%d" % elapsed)
	print("P3_AI_SHOT_SELECTION_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
