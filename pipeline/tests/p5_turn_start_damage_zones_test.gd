extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
var failures: int = 0

func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)

func rectangle(left: int, top: int, right: int, bottom: int) -> Array[FixVec2]:
	return [FixVec2.from_raw(left, top), FixVec2.from_raw(right, top), FixVec2.from_raw(right, bottom), FixVec2.from_raw(left, bottom)]

func make_state(zone_count: int, hp: int, status: SimStatus) -> BattleState:
	var world: SimWorld = SimWorld.create(17, 29, status)
	var keys: Array[int] = []
	var zones: Array[SimZone] = []
	for index: int in range(zone_count):
		keys.append(index + 1)
		zones.append(SimZone.create_unassigned(rectangle(64 * FixMath.SCALE, 64 * FixMath.SCALE, 136 * FixMath.SCALE, 136 * FixMath.SCALE), FixMath.ONE_RAW, FixVec2.zero(), status))
	world.add_initial_zones(keys, zones, status)
	var bodies: Array[SimBody] = [
		SimBody.create_unassigned(FixVec2.from_raw(100 * FixMath.SCALE, 100 * FixMath.SCALE), FixVec2.zero(), 32 * FixMath.SCALE, FixMath.ONE_RAW, status, FixMath.ONE_RAW, true),
		SimBody.create_unassigned(FixVec2.from_raw(400 * FixMath.SCALE, 400 * FixMath.SCALE), FixVec2.zero(), 32 * FixMath.SCALE, FixMath.ONE_RAW, status, FixMath.ONE_RAW, true),
	]
	world.add_initial_bodies([1, 2], bodies, status)
	for expected: int in [1, 2]:
		var event: SimEvent = world.consume_next_event(status)
		if event.source_body_id() != expected: status.fail(SimStatus.Code.INVALID_SIM_STATE, SimStatus.Operation.BATTLE_DAMAGE_ZONE_UPDATE, event.source_body_id(), expected)
	var participants: Array[BattleParticipant] = [
		BattleParticipant.create(1, BattleParticipant.Faction.PLAYER, true, true, true, 100, status),
		BattleParticipant.create(2, BattleParticipant.Faction.ENEMY, true, false, true, 50, status),
	]
	var combatants: Array[BattleCombatant] = [
		BattleCombatant.create(1, BattleParticipant.Faction.PLAYER, hp, 20, 0, status),
		BattleCombatant.create(2, BattleParticipant.Faction.ENEMY, 100, 20, 0, status),
	]
	var state: BattleState = BattleState.create_with_combatants(world, participants, combatants, status)
	for zone_id: int in range(1, zone_count + 1): state.register_initial_damage_zone(zone_id, 15, 0, status)
	state.complete_battle_start(status)
	return state

func test_geometry() -> void:
	var status := SimStatus.new()
	var polygon: SimPolygon = SimPolygon.create(rectangle(0, 0, 100 * FixMath.SCALE, 100 * FixMath.SCALE), false, status)
	var radius: int = 32 * FixMath.SCALE
	check("P5-DZ-GEOMETRY-INSIDE", polygon.overlaps_circle(FixVec2.from_raw(50 * FixMath.SCALE, 50 * FixMath.SCALE), radius, status))
	check("P5-DZ-GEOMETRY-TANGENT", polygon.overlaps_circle(FixVec2.from_raw(132 * FixMath.SCALE, 50 * FixMath.SCALE), radius, status))
	check("P5-DZ-GEOMETRY-RADIUS-PLUS-ONE", not polygon.overlaps_circle(FixVec2.from_raw(132 * FixMath.SCALE + 1, 50 * FixMath.SCALE), radius, status))
	check("P5-DZ-GEOMETRY-STATUS", status.is_ok())

func test_damage_and_snapshot() -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(1, 100, status)
	state.complete_turn_start(status)
	var hp: int = state.combatant_by_body_id(1, status).current_hp()
	var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var restored: BattleState = BattleSnapshot.decode(bytes, status).restore_state(status)
	check("P5-DZ-TURN-START-EXACT-15-BEFORE-AIM", status.is_ok() and hp == 85 and state.phase() == BattleState.Phase.AIM)
	check("P5-DZ-SNAPSHOT-V9-ROUNDTRIP", status.is_ok() and (bytes[9] | (bytes[10] << 8)) == 9 and restored.damage_zone_count() == 1 and BattleSnapshot.capture(restored, status).encode(status) == bytes)

func test_overlap_lethal_environment() -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(3, 30, status)
	state.complete_turn_start(status)
	var death_seen: bool = false; var kill_seen: bool = false
	for index: int in range(state.trigger_record_count()):
		var record: BattleTriggerRecord = state.trigger_record_at(index, status)
		if record.trigger_id() == BattleTriggerId.Value.ON_DEATH_SELF and record.cause_id() == SimEvent.CauseId.TURN_START_DAMAGE_ZONE: death_seen = true
		if record.trigger_id() == BattleTriggerId.Value.ON_KILL: kill_seen = true
	var missing := SimStatus.new(); state.combatant_by_body_id(1, missing)
	check("P5-DZ-OVERLAP-LETHAL-STOPS-AFTER-SECOND", status.is_ok() and not missing.is_ok() and state.phase() == BattleState.Phase.TURN_END)
	check("P5-DZ-ENV-DEATH-NO-KILL-TALLY", death_seen and not kill_seen and state.kill_tally_count() == 0)

func test_runtime_encounter_setup() -> void:
	var node: Node = DATA_DB_SCRIPT.new(); root.add_child(node)
	var content_status := ContentStatus.new(); var loaded: bool = bool(node.call("reload_catalog", "res://src/core/data", content_status))
	var catalog: ContentCatalog = node.call("catalog_copy", content_status) as ContentCatalog
	var status := SimStatus.new(); var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(1, content_status)
	var deployment: Array[BattleDeploymentEntry] = []
	for index: int in range(3):
		var piece: PieceDefinition = catalog.piece_at(index, content_status)
		deployment.append(BattleDeploymentEntry.create_player(index, piece.id_ref(), 1, status))
		deployment.append(BattleDeploymentEntry.create_enemy(index, encounter.enemy_ref_at(index, content_status), status))
	var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment, 17, 29, status, 1)
	var world: SimWorld = state.world_copy(status)
	check("P5-DZ-RUNTIME-ENCOUNTER-OWNS-ZONE", loaded and content_status.is_ok() and status.is_ok() and catalog.map_by_numeric_id(1, content_status).zone_count() == 0 and encounter.damage_zone_count() == 1 and world.zone_count() == 1 and state.damage_zone_count() == 1)
	node.queue_free()

func _init() -> void:
	test_geometry(); test_damage_and_snapshot(); test_overlap_lethal_environment(); test_runtime_encounter_setup()
	if failures == 0:
		print("P5_TURN_START_DAMAGE_ZONES_RESULT: PASS")
		quit(0)
	else:
		print("P5_TURN_START_DAMAGE_ZONES_RESULT: FAIL (%d)" % failures)
		quit(1)
