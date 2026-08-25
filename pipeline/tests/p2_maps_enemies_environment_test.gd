extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const FIXTURE: String = "res://pipeline/tests/fixtures/p2_maps_enemies"
const EXPECTED_FINGERPRINT: String = "4af6db444e62d5494c2dfc72fe7d92eec34f1273760ad69c5b74a67d94efd874"

var failures: int = 0


func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)


func deployment(order_reversed: bool, status: SimStatus) -> Array[BattleDeploymentEntry]:
	var content_status := ContentStatus.new()
	var piece_ref: ContentIdRef = ContentIdRef.create(1, "stone", content_status)
	var enemy_ref: ContentIdRef = ContentIdRef.create(1, "enemy_stone", content_status)
	var result: Array[BattleDeploymentEntry] = [
		BattleDeploymentEntry.create_player(2, piece_ref, 1, status),
		BattleDeploymentEntry.create_enemy(1, enemy_ref, status),
		BattleDeploymentEntry.create_player(0, piece_ref, 1, status),
		BattleDeploymentEntry.create_enemy(2, enemy_ref, status),
		BattleDeploymentEntry.create_player(1, piece_ref, 1, status),
		BattleDeploymentEntry.create_enemy(0, enemy_ref, status),
	]
	if order_reversed: result.reverse()
	if not content_status.is_ok() and status.is_ok(): status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.BATTLE_SETUP_BUILD)
	return result


func trigger(trigger_id: int, phase: int, status: SimStatus) -> BattleTriggerRecord:
	var subject: int = 0 if trigger_id == BattleTriggerId.Value.ON_BATTLE_START else 1
	return BattleTriggerRecord.create(1, 0, trigger_id, phase, 0, 0, subject, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, status)


func resolve(state: BattleState, record: BattleTriggerRecord, status: SimStatus) -> EffectResolutionReport:
	return EffectResolver.resolve_transition(state, state.ability_registry(status), [record], state.content_fingerprint_bytes(), status)


func set_turn_index(state: BattleState, value: int, status: SimStatus) -> void:
	var identities: Array[BattlePieceIdentity] = []; var bases: Array[BattleBaseBodyStats] = []; var instances: Array[StatusInstance] = []
	for index: int in range(state.piece_identity_count()): identities.append(state.piece_identity_at(index, status))
	for index: int in range(state.base_body_stats_count()): bases.append(state.base_body_stats_at(index, status))
	for index: int in range(state.status_count()): instances.append(state.status_at(index, status))
	state._status_restore_snapshot(value, identities, state.synergy_tally_copy(), instances, state.next_status_sequence(), bases, status)


func write_u32(bytes: PackedByteArray, offset: int, value: int) -> void:
	for shift: int in range(0, 32, 8): bytes[offset + (shift >> 3)] = (value >> shift) & 0xFF


func snapshot_rejected(bytes: PackedByteArray) -> bool:
	var status := SimStatus.new()
	BattleSnapshot.decode(bytes, status)
	return not status.is_ok()


func test_catalog(catalog: ContentCatalog) -> void:
	var status := ContentStatus.new()
	var map_definition: MapDefinition = catalog.map_by_numeric_id(1, status)
	var enemy: EnemyDefinition = catalog.enemy_by_numeric_id(1, status)
	var level: PieceLevelDefinition = enemy.resolved_level(catalog, status)
	check("P2-5-CATALOG-V7-MAP-ENEMY", status.is_ok() and catalog.catalog_schema_version() == 7 and catalog.map_count() == 1 and catalog.enemy_count() == 1 and catalog.fingerprint_hex() == EXPECTED_FINGERPRINT)
	check("P2-5-MAP-ZONE-LOCAL-ID-SORT", status.is_ok() and map_definition.zone_count() == 2 and map_definition.zone_at(0, status).local_id() == 2 and map_definition.zone_at(1, status).local_id() == 10)
	check("P2-5-ENEMY-OVERRIDE-RESOLVE", status.is_ok() and level.max_hp() == 120 and level.attack() == 24 and level.radius_raw() == 40 * FixMath.SCALE and level.ability_ref_count() == 0)


func test_setup(catalog: ContentCatalog) -> BattleState:
	var status := SimStatus.new()
	var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(false, status), 17, 29, status)
	var world: SimWorld = state.world_copy(status)
	var enemy_combatant: BattleCombatant = state.combatant_by_body_id(4, status)
	check("P2-5-SETUP-BODY-ZONE-ID-ORDER", status.is_ok() and world.body_count() == 6 and world.zone_count() == 2 and world.zone_at(0, status).id() == 1 and world.zone_at(1, status).id() == 2 and world.body_at(0, status).position().is_equal(FixVec2.from_raw(16777216, 12582912)))
	check("P2-5-SETUP-ENEMY-OVERRIDE-BINDING", status.is_ok() and enemy_combatant.max_hp() == 120 and world.body_by_id(4, status).radius_raw() == 40 * FixMath.SCALE and state.ability_binding_count() == 6)
	var order_status := SimStatus.new(); var reordered: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(true, order_status), 17, 29, order_status)
	var bytes_a: PackedByteArray = BattleSnapshot.capture(state, status).encode(status); var bytes_b: PackedByteArray = BattleSnapshot.capture(reordered, order_status).encode(order_status)
	check("P2-5-DEPLOYMENT-AUTHORING-ORDER-INDEPENDENT", status.is_ok() and order_status.is_ok() and bytes_a == bytes_b)
	var duplicate_status := SimStatus.new(); var duplicate: Array[BattleDeploymentEntry] = deployment(false, duplicate_status); duplicate[1] = duplicate[5].copy()
	BattleSetupBuilder.build(catalog, 1, duplicate, 17, 29, duplicate_status)
	check("P2-5-DEPLOYMENT-DUPLICATE-ATOMIC-FAIL", duplicate_status.code() == SimStatus.Code.INVALID_DEPLOYMENT)
	return state


func test_setup_rejections(catalog: ContentCatalog) -> void:
	var count_status := SimStatus.new(); var short_deployment: Array[BattleDeploymentEntry] = deployment(false, count_status); short_deployment.pop_back()
	var short_state: BattleState = BattleSetupBuilder.build(catalog, 1, short_deployment, 1, 2, count_status)
	var level_status := SimStatus.new(); var bad_level: Array[BattleDeploymentEntry] = deployment(false, level_status); var content_status := ContentStatus.new()
	bad_level[0] = BattleDeploymentEntry.create_player(2, ContentIdRef.create(1, "stone", content_status), 2, level_status)
	var level_state: BattleState = BattleSetupBuilder.build(catalog, 1, bad_level, 1, 2, level_status)
	var ref_status := SimStatus.new(); var bad_ref: Array[BattleDeploymentEntry] = deployment(false, ref_status); var ref_content_status := ContentStatus.new()
	bad_ref[0] = BattleDeploymentEntry.create_player(2, ContentIdRef.create(1, "wrong_stone", ref_content_status), 1, ref_status)
	var ref_state: BattleState = BattleSetupBuilder.build(catalog, 1, bad_ref, 1, 2, ref_status)
	check("P2-5-DEPLOYMENT-COUNT-LEVEL-REF-REJECT", count_status.code() == SimStatus.Code.INVALID_DEPLOYMENT and not short_state.is_initialized() and level_status.code() == SimStatus.Code.INVALID_DEPLOYMENT and not level_state.is_initialized() and ref_status.code() == SimStatus.Code.INVALID_DEPLOYMENT and not ref_state.is_initialized())


func test_zone_lifecycle(catalog: ContentCatalog, state: BattleState) -> void:
	var status := SimStatus.new()
	var report: EffectResolutionReport = resolve(state, trigger(BattleTriggerId.Value.ON_BATTLE_START, BattleState.Phase.BATTLE_START, status), status)
	var world: SimWorld = state.world_copy(status); var first_dynamic: SimZone = world.zone_at(2, status)
	check("P2-5-SPAWN-ZONE-LOCAL-COMPOSITION", status.is_ok() and report.application_count() == 3 and state.zone_spawn_count() == 3 and world.zone_count() == 5 and first_dynamic.vertex(0, status).is_equal(FixVec2.from_raw(15728640, 11534336)))
	if not status.is_ok(): return
	var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var decoded: BattleSnapshot = BattleSnapshot.decode(bytes, status); var restored: BattleState = decoded.restore_state_with_catalog(catalog, status)
	var bytes_again: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	var encoded_version: int = bytes[9] | (bytes[10] << 8)
	check("P2-5-SNAPSHOT-V7-ZONE-ROUNDTRIP", status.is_ok() and encoded_version == 7 and bytes == bytes_again and restored.zone_spawn_count() == 3)
	set_turn_index(restored, 1, status); resolve(restored, trigger(BattleTriggerId.Value.ON_TURN_END, BattleState.Phase.TURN_END, status), status)
	var same_turn_remaining: int = restored.zone_spawn_at(0, status).remaining_turns()
	set_turn_index(restored, 2, status); resolve(restored, trigger(BattleTriggerId.Value.ON_TURN_END, BattleState.Phase.TURN_END, status), status)
	var next_turn_remaining: int = restored.zone_spawn_at(0, status).remaining_turns()
	set_turn_index(restored, 3, status); resolve(restored, trigger(BattleTriggerId.Value.ON_TURN_END, BattleState.Phase.TURN_END, status), status)
	check("P2-5-ZONE-LIFETIME-SAME-NEXT-EXPIRE", status.is_ok() and same_turn_remaining == 2 and next_turn_remaining == 1 and restored.zone_spawn_count() == 0 and restored.world_copy(status).zone_count() == 2)


func test_permanent_zone(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(false, status), 31, 47, status)
	var vertices: Array[FixVec2] = [FixVec2.from_raw(15000000, 11000000), FixVec2.from_raw(18000000, 11000000), FixVec2.from_raw(16500000, 14000000)]
	state._dynamic_begin_transition(); state.queue_zone_spawn(SimZone.create_unassigned(vertices, FixMath.ONE_RAW, FixVec2.zero(), status), 0, 1, AbilityEffectDefinition.Kind.SPAWN_ZONE, 0, status); state._dynamic_finish_transition(false, status)
	var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status); var restored: BattleState = BattleSnapshot.decode(bytes, status).restore_state_with_catalog(catalog, status)
	check("P2-5-PERMANENT-ZONE-SNAPSHOT", status.is_ok() and restored.zone_spawn_count() == 1 and restored.zone_spawn_at(0, status).remaining_turns() == 0 and restored.world_copy(status).zone_count() == 3)


func test_legacy_v6(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(false, status), 53, 71, status)
	var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var sim_bytes: PackedByteArray = SimSnapshot.capture(state.world_copy(status), status).encode(status)
	var sim_length_offset: int = bytes.size() - sim_bytes.size() - 4; var zone_count_offset: int = sim_length_offset - 4
	var legacy: PackedByteArray = bytes.slice(0, zone_count_offset); legacy.append_array(bytes.slice(sim_length_offset, bytes.size())); legacy[9] = 6; legacy[10] = 0
	var decoded: BattleSnapshot = BattleSnapshot.decode(legacy, status); var restored: BattleState = decoded.restore_state_with_catalog(catalog, status)
	var recaptured: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	check("P2-5-LEGACY-V6-DECODE-RECAPTURE-V7", status.is_ok() and restored.zone_spawn_count() == 0 and restored.world_copy(status).zone_count() == 2 and (recaptured[9] | (recaptured[10] << 8)) == 7)


func test_zone_limit_rollback(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(false, status), 79, 83, status)
	var before: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var report: EffectResolutionReport = resolve(state, trigger(BattleTriggerId.Value.ON_LAUNCH, BattleState.Phase.AIM, status), status)
	var after_status := SimStatus.new(); var after: PackedByteArray = BattleSnapshot.capture(state, after_status).encode(after_status)
	check("P2-5-ZONE-LIMIT-TRANSITION-ROLLBACK", status.code() == SimStatus.Code.ZONE_LIMIT_EXCEEDED and report.application_count() == 0 and after_status.is_ok() and before == after and state.zone_spawn_count() == 0 and state.world_copy(after_status).zone_count() == 2)


func test_snapshot_rejections(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(false, status), 89, 97, status)
	resolve(state, trigger(BattleTriggerId.Value.ON_BATTLE_START, BattleState.Phase.BATTLE_START, status), status)
	var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status); var sim_bytes: PackedByteArray = SimSnapshot.capture(state.world_copy(status), status).encode(status)
	var sim_length_offset: int = bytes.size() - sim_bytes.size() - 4; var count: int = state.zone_spawn_count(); var zone_count_offset: int = sim_length_offset - 4 - count * 12; var first_record: int = zone_count_offset + 4
	var bad_count: PackedByteArray = bytes.duplicate(); write_u32(bad_count, zone_count_offset, BattleLimits.ZONE_SPAWN_MAX_PER_BATTLE + 1)
	var duplicate_id: PackedByteArray = bytes.duplicate(); write_u32(duplicate_id, first_record + 12, state.zone_spawn_at(0, status).zone_id())
	var missing_id: PackedByteArray = bytes.duplicate(); write_u32(missing_id, first_record + 24, 999)
	var bad_remaining: PackedByteArray = bytes.duplicate(); write_u32(bad_remaining, first_record + 4, ContentLimits.ZONE_DURATION_MAX_TURNS + 1)
	var future_turn: PackedByteArray = bytes.duplicate(); write_u32(future_turn, first_record + 8, state.turn_index() + 1)
	var trailing: PackedByteArray = bytes.duplicate(); trailing.append(0)
	check("P2-5-SNAPSHOT-V7-MALFORMED-REJECT", status.is_ok() and snapshot_rejected(bad_count) and snapshot_rejected(duplicate_id) and snapshot_rejected(missing_id) and snapshot_rejected(bad_remaining) and snapshot_rejected(future_turn) and snapshot_rejected(trailing))


func test_dynamic_kill_zone(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(false, status), 101, 103, status)
	var position: FixVec2 = state.world_copy(status).body_by_id(1, status).position(); var extent: int = 4 * FixMath.SCALE
	var vertices: Array[FixVec2] = [position.add(FixVec2.from_raw(-extent, -extent), status), position.add(FixVec2.from_raw(extent, -extent), status), position.add(FixVec2.from_raw(0, extent), status)]
	state._dynamic_begin_transition(); state.queue_zone_spawn(SimZone.create_unassigned(vertices, FixMath.ONE_RAW, FixVec2.zero(), status, SimZone.FLAG_KILL), 0, 1, AbilityEffectDefinition.Kind.SPAWN_ZONE, 0, status); state._dynamic_finish_transition(false, status)
	if status.is_ok() and state.phase() == BattleState.Phase.TURN_START: state.complete_turn_start(status)
	if status.is_ok(): state.commit_launch_velocity(FixVec2.from_raw(64 * FixMath.SCALE, 0), status)
	if status.is_ok(): state.advance_resolve(status)
	var death_seen: bool = false
	for index: int in range(state.trigger_record_count()):
		var record: BattleTriggerRecord = state.trigger_record_at(index, status)
		if record.trigger_id() == BattleTriggerId.Value.ON_DEATH_SELF and record.subject_body_id() == 1 and record.cause_id() == SimEvent.CauseId.KILL_ZONE: death_seen = true
	var lookup := SimStatus.new(); state.participant_by_body_id(1, lookup)
	check("P2-5-DYNAMIC-KILL-ZONE-DEATH-TRIGGER", status.is_ok() and not lookup.is_ok() and death_seen)


func test_determinism_1000(catalog: ContentCatalog) -> void:
	var baseline_status := SimStatus.new(); var baseline_state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(false, baseline_status), 107, 109, baseline_status)
	resolve(baseline_state, trigger(BattleTriggerId.Value.ON_BATTLE_START, BattleState.Phase.BATTLE_START, baseline_status), baseline_status)
	var expected: PackedByteArray = BattleSnapshot.capture(baseline_state, baseline_status).encode(baseline_status); var deterministic: bool = baseline_status.is_ok()
	var restored: BattleState = BattleSnapshot.decode(expected, baseline_status).restore_state_with_catalog(catalog, baseline_status)
	deterministic = deterministic and BattleSnapshot.capture(restored, baseline_status).encode(baseline_status) == expected
	for index: int in range(1000):
		var status := SimStatus.new(); var state: BattleState = BattleSetupBuilder.build(catalog, 1, deployment(index % 2 == 1, status), 107, 109, status)
		resolve(state, trigger(BattleTriggerId.Value.ON_BATTLE_START, BattleState.Phase.BATTLE_START, status), status)
		var actual: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
		if not status.is_ok() or actual != expected: deterministic = false; break
	check("P2-5-DETERMINISM-1000-RESTORE", deterministic)


func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new(); var loaded: bool = bool(db.call("reload_catalog", FIXTURE, content_status)); var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P2-5-FIXTURE-LOAD", loaded and content_status.is_ok())
	if loaded and content_status.is_ok():
		test_catalog(catalog)
		var state: BattleState = test_setup(catalog)
		test_setup_rejections(catalog)
		test_zone_lifecycle(catalog, state)
		test_permanent_zone(catalog)
		test_legacy_v6(catalog)
		test_zone_limit_rollback(catalog)
		test_snapshot_rejections(catalog)
		test_dynamic_kill_zone(catalog)
		test_determinism_1000(catalog)
	print("P2_MAPS_ENEMIES_ENVIRONMENT_RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
