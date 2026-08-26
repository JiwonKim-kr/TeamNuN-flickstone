extends Node

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const ROUTER_SCRIPT: Script = preload("res://src/ui/battle/combat_audio_cue_router.gd")
const CONTENT_DRIVER: Script = preload("res://src/ui/battle/p2_content_battle_driver.gd")
const RUNTIME_ROOT := "res://src/core/data"

var failures: int = 0


func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)


func build_state(catalog: ContentCatalog, piece_numeric_id: int, status: SimStatus) -> BattleState:
	var deployment: Array[BattleDeploymentEntry] = []
	var content_status := ContentStatus.new()
	var piece: PieceDefinition = catalog.piece_by_numeric_id(piece_numeric_id, content_status)
	for slot: int in range(3): deployment.append(BattleDeploymentEntry.create_player(slot, piece.id_ref(), 1, status))
	for slot: int in range(3):
		var enemy: EnemyDefinition = catalog.enemy_at(slot, content_status)
		var enemy_ref := ContentIdRef.create(enemy.numeric_id(), enemy.string_id(), content_status)
		deployment.append(BattleDeploymentEntry.create_enemy(slot, enemy_ref, status))
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.BATTLE_SETUP_BUILD)
	var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment, 701, 907, status, 1)
	if status.is_ok(): CONTENT_DRIVER.resolve_last_transition(state, status)
	if status.is_ok(): state.complete_turn_start(status); CONTENT_DRIVER.resolve_last_transition(state, status)
	return state


func record(trigger_id: int, sim_sequence: int, subject: int, other: int, damage: int, status: SimStatus) -> BattleTriggerRecord:
	return BattleTriggerRecord.create(sim_sequence, 0, trigger_id, BattleState.Phase.RESOLVE, 1, sim_sequence, subject, other, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), damage, damage, 0, status)


func test_bouncy(catalog: ContentCatalog) -> void:
	var status := SimStatus.new()
	var state: BattleState = build_state(catalog, 4, status)
	var router: RefCounted = ROUTER_SCRIPT.new()
	router.reset_battle(); router.reset_launch()
	var pair: Array[BattleTriggerRecord] = [
		record(BattleTriggerId.Value.ON_HIT_DEAL, 10, 1, 4, 12, status),
		record(BattleTriggerId.Value.ON_HIT_TAKE, 10, 4, 1, 12, status),
	]
	var first: Array[int] = router.route(state, catalog, pair, 1000, status)
	var suppressed_records: Array[BattleTriggerRecord] = [record(BattleTriggerId.Value.ON_WALL_BOUNCE, 11, 1, 0, 0, status)]
	var allowed_records: Array[BattleTriggerRecord] = [record(BattleTriggerId.Value.ON_WALL_BOUNCE, 12, 1, 0, 0, status)]
	var suppressed: Array[int] = router.route(state, catalog, suppressed_records, 1079, status)
	var allowed: Array[int] = router.route(state, catalog, allowed_records, 1080, status)
	check("P5-CS-IMPACT-ONCE-PER-COLLISION", status.is_ok() and first.count(ROUTER_SCRIPT.Cue.IMPACT) == 1)
	check("P5-CS-BOUNCE-DEDUP-AND-80MS", first.count(ROUTER_SCRIPT.Cue.BOUNCY_REBOUND) == 1 and suppressed.is_empty() and allowed == [ROUTER_SCRIPT.Cue.BOUNCY_REBOUND])


func test_clean_hit(catalog: ContentCatalog) -> void:
	var status := SimStatus.new()
	var state: BattleState = build_state(catalog, 5, status)
	# Cue routing is presentation-only; pin a known caveman body as the acting body
	# so this fixture does not depend on CTB ordering of the encounter enemies.
	state.set("_current_actor_body_id", 1)
	var actor_id: int = 1
	var router: RefCounted = ROUTER_SCRIPT.new()
	router.reset_battle(); router.reset_launch()
	var clean_records: Array[BattleTriggerRecord] = [
		record(BattleTriggerId.Value.ON_HIT_DEAL, 20, actor_id, 4, 20, status),
		record(BattleTriggerId.Value.ON_HIT_DEAL, 20, actor_id, 4, 20, status),
	]
	var clean: Array[int] = router.route(state, catalog, clean_records, 2000, status)
	router.reset_launch()
	var blocked_records: Array[BattleTriggerRecord] = [
		record(BattleTriggerId.Value.ON_ALLY_COLLIDE, 21, actor_id, 2 if actor_id != 2 else 3, 0, status),
		record(BattleTriggerId.Value.ON_HIT_DEAL, 22, actor_id, 4, 20, status),
	]
	var blocked: Array[int] = router.route(state, catalog, blocked_records, 2100, status)
	check("P5-CS-CAVEMAN-CLEAN-HIT", status.is_ok() and clean.count(ROUTER_SCRIPT.Cue.CLEAN_HIT) == 1)
	check("P5-CS-CLEAN-HIT-BLOCKED-AFTER-ALLY", not blocked.has(ROUTER_SCRIPT.Cue.CLEAN_HIT) and blocked.has(ROUTER_SCRIPT.Cue.IMPACT))


func _ready() -> void:
	var db: Node = DATA_DB_SCRIPT.new()
	var content_status := ContentStatus.new()
	var loaded: bool = bool(db.call("reload_catalog", RUNTIME_ROOT, content_status))
	var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P5-CS-RUNTIME-LOAD", loaded and content_status.is_ok())
	if loaded and content_status.is_ok():
		test_bouncy(catalog)
		test_clean_hit(catalog)
	print("P5_COMBAT_AUDIO_CUE_ROUTER_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(0 if failures == 0 else 1)
