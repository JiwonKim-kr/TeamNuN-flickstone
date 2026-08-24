extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const FIXTURE_ROOT: String = "res://pipeline/tests/fixtures/p2_dynamic_piece"
const EXPECTED_FINGERPRINT: String = "68af8d2f3d1c0abd46a372a2fb5da632c0650da95d31bd5b7ed7e1b427dd8742"

var failures: int = 0


func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)


func make_state(catalog: ContentCatalog, ability_ids: Array[int], status: SimStatus) -> BattleState:
	var world := SimWorld.create(17, 29, status)
	var boundary: Array[FixVec2] = [FixVec2.from_ints(0, 0, status), FixVec2.from_ints(1024, 0, status), FixVec2.from_ints(1024, 768, status), FixVec2.from_ints(0, 768, status)]
	world.configure_boundary(boundary, SimWorld.BoundaryType.WALL, status)
	var bodies: Array[SimBody] = [
		SimBody.create_unassigned(FixVec2.from_ints(256, 256, status), FixVec2.zero(), 32 * FixMath.SCALE, 64 * FixMath.SCALE, status, FixMath.ONE_RAW, true),
		SimBody.create_unassigned(FixVec2.from_ints(640, 256, status), FixVec2.zero(), 32 * FixMath.SCALE, 64 * FixMath.SCALE, status, FixMath.ONE_RAW, true),
	]
	world.add_initial_bodies([1, 2], bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	var participants: Array[BattleParticipant] = [
		BattleParticipant.create(1, BattleParticipant.Faction.PLAYER, true, true, true, 100, status),
		BattleParticipant.create(2, BattleParticipant.Faction.ENEMY, true, false, true, 80, status),
	]
	var combatants: Array[BattleCombatant] = [
		BattleCombatant.create(1, BattleParticipant.Faction.PLAYER, 100, 20, 0, status),
		BattleCombatant.create(2, BattleParticipant.Faction.ENEMY, 80, 10, 0, status),
	]
	var state: BattleState = BattleState.create_with_combatants(world, participants, combatants, status)
	var identities: Array[BattlePieceIdentity] = [
		BattlePieceIdentity.create(1, 1, 1, BattleParticipant.Faction.PLAYER, false, status),
		BattlePieceIdentity.create(2, 2, 1, BattleParticipant.Faction.ENEMY, false, status),
	]
	var bindings: Array[AbilityBinding] = []
	for ability_id: int in ability_ids: bindings.append(AbilityBinding.create(1, ability_id, status))
	state.attach_content(catalog, identities, bindings, status)
	return state


func record(trigger_id: int, subject: int, other: int, status: SimStatus) -> BattleTriggerRecord:
	var phase: int = BattleState.Phase.RESOLVE
	if trigger_id == BattleTriggerId.Value.ON_BATTLE_START: phase = BattleState.Phase.BATTLE_START; subject = 0; other = 0
	elif trigger_id == BattleTriggerId.Value.ON_TURN_START: phase = BattleState.Phase.TURN_START; other = 0
	elif trigger_id == BattleTriggerId.Value.ON_LAUNCH: other = 0
	return BattleTriggerRecord.create(1, 0, trigger_id, phase, 0, 0, subject, other, 0, SimEvent.CauseId.NONE, FixVec2.from_ints(448, 256, status), FixVec2.from_ints(1, 0, status), 0, 0, 0, status)


func resolve(state: BattleState, input: BattleTriggerRecord, status: SimStatus) -> EffectResolutionReport:
	var registry: AbilityRegistry = state.ability_registry(status)
	return EffectResolver.resolve_transition(state, registry, [input], state.content_fingerprint_bytes(), status)


func identity_for(state: BattleState, body_id: int, status: SimStatus) -> BattlePieceIdentity:
	for index: int in range(state.piece_identity_count()):
		var identity: BattlePieceIdentity = state.piece_identity_at(index, status)
		if identity.body_id() == body_id: return identity
	return BattlePieceIdentity.new()


func set_turn_index(state: BattleState, value: int, status: SimStatus) -> void:
	var identities: Array[BattlePieceIdentity] = []
	for index: int in range(state.piece_identity_count()): identities.append(state.piece_identity_at(index, status))
	var bases: Array[BattleBaseBodyStats] = []
	for index: int in range(state.base_body_stats_count()): bases.append(state.base_body_stats_at(index, status))
	var statuses: Array[StatusInstance] = []
	for index: int in range(state.status_count()): statuses.append(state.status_at(index, status))
	state._status_restore_snapshot(value, identities, state.synergy_tally_copy(), statuses, state.next_status_sequence(), bases, status)


func effect_payload(catalog: ContentCatalog, ability_id: int, status: SimStatus) -> AbilityEffectDefinition:
	var content_status := ContentStatus.new()
	var effect: AbilityEffectDefinition = catalog.ability_by_numeric_id(ability_id, content_status).effect_at(0, content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_EFFECT_DEFINITION, SimStatus.Operation.EFFECT_APPLY, ability_id, 0)
	return effect


func test_spawn_and_binding(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(catalog, [1], status)
	var before_rng: int = state.world_copy(status).rng_draw_count_lo()
	var report: EffectResolutionReport = resolve(state, record(BattleTriggerId.Value.ON_BATTLE_START, 1, 2, status), status)
	var world: SimWorld = state.world_copy(status); var token: BattlePieceIdentity = identity_for(state, 3, status)
	var token_participant: BattleParticipant = state.participant_by_body_id(3, status)
	check("P2-4-SPAWN-PIECE-TOKEN-LEVEL-FACTION", status.is_ok() and report.invocation_count() == 1 and report.application_count() == 1 and world.body_count() == 3 and token.is_initialized() and token.piece_numeric_id() == 3 and token.level() == 1 and token.is_token() and token_participant.faction() == BattleParticipant.Faction.PLAYER and world.body_by_id(3, status).velocity().is_zero())
	check("P2-4-SPAWN-BINDING-NEXT-TRANSITION", status.is_ok() and state.ability_binding_count() == 2 and state.ability_binding_at(1, status).owner_body_id() == 3 and state.ability_binding_at(1, status).ability_numeric_id() == 6)
	var next_report: EffectResolutionReport = resolve(state, record(BattleTriggerId.Value.ON_TURN_START, 3, 2, status), status)
	check("P2-4-SPAWNED-ABILITY-PUBLIC-NEXT-TRANSITION", status.is_ok() and next_report.invocation_count() == 1 and state.world_copy(status).body_by_id(3, status).velocity().x_raw() == FixMath.ONE_RAW)
	check("P2-4-DYNAMIC-RNG-TRIGGER-ZERO", status.is_ok() and state.world_copy(status).rng_draw_count_lo() == before_rng and report.generated_record_count() == 0 and next_report.generated_record_count() == 0)


func test_projectile_and_expiry(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(catalog, [2], status)
	resolve(state, record(BattleTriggerId.Value.ON_TURN_START, 1, 0, status), status)
	var projectile: SimBody = state.world_copy(status).body_by_id(3, status)
	check("P2-4-SPAWN-PROJECTILE-DIRECTION-SPEED", status.is_ok() and projectile.velocity().x_raw() == 20 * FixMath.SCALE and projectile.velocity().y_raw() == 0 and identity_for(state, 3, status).piece_numeric_id() == 4)
	state._expire_collision_body(3, 1, status); state._dynamic_finish_transition(false, status)
	var missing := SimStatus.new(); state.world_copy(missing).body_by_id(3, missing)
	check("P2-4-AFTER-COLLISION-REMOVAL-ONLY", status.is_ok() and not missing.is_ok() and state.world_copy(status).body_count() == 2 and state.trigger_record_count() == 0)


func test_turn_expiry(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(catalog, [1], status)
	resolve(state, record(BattleTriggerId.Value.ON_BATTLE_START, 1, 2, status), status)
	set_turn_index(state, 1, status); state._dynamic_finish_transition(true, status)
	check("P2-4-SAME-TURN-NO-EXPIRE", status.is_ok() and state.expire_state_count() == 1 and state.expire_state_at(0, status).remaining() == 2)
	set_turn_index(state, 2, status); state._dynamic_finish_transition(true, status)
	check("P2-4-NEXT-TURN-DECAY", status.is_ok() and state.expire_state_at(0, status).remaining() == 1)
	set_turn_index(state, 3, status); state._dynamic_finish_transition(true, status)
	var missing := SimStatus.new(); state.world_copy(missing).body_by_id(3, missing)
	check("P2-4-AFTER-TURNS-EXACT-REMOVE", status.is_ok() and not missing.is_ok() and state.expire_state_count() == 0)


func test_transform_and_binding(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(catalog, [4], status)
	state._effect_set_hp(2, 40, 1, status); state._effect_set_ct(2, 5000, status)
	var report: EffectResolutionReport = resolve(state, record(BattleTriggerId.Value.ON_TURN_START, 1, 2, status), status)
	var transformed: BattleCombatant = state.combatant_by_body_id(2, status); var participant: BattleParticipant = state.participant_by_body_id(2, status); var identity: BattlePieceIdentity = identity_for(state, 2, status)
	check("P2-4-TRANSFORM-HP-CT-IDENTITY", status.is_ok() and report.application_count() == 1 and transformed.current_hp() == 100 and transformed.max_hp() == 200 and transformed.attack() == 40 and participant.speed_stat() == 150 and participant.ct() == 550 and identity.piece_numeric_id() == 6 and identity.body_id() == 2 and identity.faction() == BattleParticipant.Faction.ENEMY and not identity.is_token())
	check("P2-4-TRANSFORM-BINDING-REPLACED", status.is_ok() and state.ability_binding_count() == 2 and state.ability_binding_at(1, status).owner_body_id() == 2 and state.ability_binding_at(1, status).ability_numeric_id() == 7)
	var next_report: EffectResolutionReport = resolve(state, record(BattleTriggerId.Value.ON_LAUNCH, 2, 1, status), status)
	check("P2-4-TRANSFORMED-ABILITY-NEXT-TRANSITION", status.is_ok() and next_report.invocation_count() == 1 and state.combatant_by_body_id(2, status).attack() == 41)
	var result_report: BattleResult = state.battle_result_report(status)
	check("P2-4-RESULT-ORIGINAL-PIECES", status.is_ok() and state.battle_result() == BattleResult.Value.ONGOING and result_report.origin_count() == 2 and result_report.origin_at(1, status).body_id() == 2 and result_report.origin_at(1, status).original_piece_numeric_id() == 2)


func test_links_snapshot_and_release(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(catalog, [5], status)
	var report: EffectResolutionReport = resolve(state, record(BattleTriggerId.Value.ON_HIT_DEAL, 1, 2, status), status)
	var world: SimWorld = state.world_copy(status); var link: SimLink = world.link_at(0, status)
	check("P2-4-ATTACH-SURFACE-LINK", status.is_ok() and report.application_count() == 1 and world.link_count() == 1 and world.next_link_id() == 2 and link.anchor_body_id() == 1 and link.attached_body_id() == 2 and link.anchor_mode_id() == AttachPayloadDefinition.AnchorMode.SURFACE_FOLLOW)
	var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var restored: BattleState = BattleSnapshot.decode(bytes, status).restore_state_with_catalog(catalog, status)
	var bytes_again: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	check("P2-4-SNAPSHOT-V6-SIM-LINK-SINGLE-SOURCE", status.is_ok() and bytes == bytes_again and restored.world_copy(status).link_count() == 1 and restored.world_copy(status).next_link_id() == 2)
	state.queue_participant_removal(1, 1, SimStatus.Operation.BATTLE_EXPIRE, 1, status); state._dynamic_finish_transition(false, status)
	var target_status := SimStatus.new(); state.world_copy(target_status).body_by_id(2, target_status)
	check("P2-4-ANCHOR-REMOVAL-LEAVES-ATTACHED", status.is_ok() and target_status.is_ok() and state.world_copy(status).link_count() == 0 and state.world_copy(status).body_count() == 1)


func test_on_link_release(catalog: ContentCatalog) -> void:
	var status := SimStatus.new(); var state: BattleState = make_state(catalog, [3], status)
	resolve(state, record(BattleTriggerId.Value.ON_BATTLE_START, 1, 2, status), status)
	check("P2-4-ON-LINK-RELEASE-NOT-ARMED", status.is_ok() and state.expire_state_at(0, status).kind_id() == PieceDefinition.ExpireKind.ON_LINK_RELEASE and not state.expire_state_at(0, status).has_linked())
	var payload: AttachPayloadDefinition = effect_payload(catalog, 5, status).attach_payload()
	state.attach(1, 3, payload, record(BattleTriggerId.Value.ON_HIT_DEAL, 1, 3, status), status)
	check("P2-4-ON-LINK-RELEASE-ARMED", status.is_ok() and state.expire_state_at(0, status).has_linked() and state.world_copy(status).link_count() == 1)
	state.queue_participant_removal(1, 1, SimStatus.Operation.BATTLE_EXPIRE, 1, status); state._dynamic_finish_transition(false, status)
	var token_status := SimStatus.new(); state.world_copy(token_status).body_by_id(3, token_status)
	check("P2-4-ON-LAST-LINK-RELEASE-EXPIRE", status.is_ok() and not token_status.is_ok() and state.world_copy(status).body_count() == 1 and state.world_copy(status).link_count() == 0)


func test_transition_rollbacks(catalog: ContentCatalog) -> void:
	var spawn_status := SimStatus.new(); var spawn_state: BattleState = make_state(catalog, [10], spawn_status)
	var spawn_before: PackedByteArray = BattleSnapshot.capture(spawn_state, spawn_status).encode(spawn_status)
	var zero_record: BattleTriggerRecord = BattleTriggerRecord.create(1, 0, BattleTriggerId.Value.ON_TURN_START, BattleState.Phase.TURN_START, 0, 0, 1, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, spawn_status)
	var spawn_report: EffectResolutionReport = resolve(spawn_state, zero_record, spawn_status)
	var inspect := SimStatus.new(); var spawn_after: PackedByteArray = BattleSnapshot.capture(spawn_state, inspect).encode(inspect)
	check("P2-4-ZERO-DIRECTION-SPAWN-ROLLBACK", not spawn_report.is_initialized() and spawn_status.code() == SimStatus.Code.INVALID_SPAWN_REQUEST and inspect.is_ok() and spawn_before == spawn_after)

	var transform_status := SimStatus.new(); var transform_state: BattleState = make_state(catalog, [11], transform_status)
	var transform_before: PackedByteArray = BattleSnapshot.capture(transform_state, transform_status).encode(transform_status)
	var transform_report: EffectResolutionReport = resolve(transform_state, record(BattleTriggerId.Value.ON_TURN_START, 1, 0, transform_status), transform_status)
	inspect = SimStatus.new(); var transform_after: PackedByteArray = BattleSnapshot.capture(transform_state, inspect).encode(inspect)
	check("P2-4-SECOND-TRANSFORM-ATOMIC-ROLLBACK", not transform_report.is_initialized() and transform_status.code() == SimStatus.Code.TRANSFORM_LIMIT_EXCEEDED and inspect.is_ok() and transform_before == transform_after)

	var attach_status := SimStatus.new(); var attach_state: BattleState = make_state(catalog, [12], attach_status)
	var attach_before: PackedByteArray = BattleSnapshot.capture(attach_state, attach_status).encode(attach_status)
	var attach_report: EffectResolutionReport = resolve(attach_state, record(BattleTriggerId.Value.ON_HIT_DEAL, 1, 2, attach_status), attach_status)
	inspect = SimStatus.new(); var attach_after: PackedByteArray = BattleSnapshot.capture(attach_state, inspect).encode(inspect)
	check("P2-4-DUPLICATE-ATTACH-ATOMIC-ROLLBACK", not attach_report.is_initialized() and attach_status.code() == SimStatus.Code.DUPLICATE_ATTACH_LINK and inspect.is_ok() and attach_before == attach_after)


func test_link_solver_overlap_and_velocity() -> void:
	var status := SimStatus.new(); var world := SimWorld.create(3, 5, status)
	var bodies: Array[SimBody] = [
		SimBody.create_unassigned(FixVec2.from_ints(100, 100, status), FixVec2.zero(), 16 * FixMath.SCALE, 64 * FixMath.SCALE, status),
		SimBody.create_unassigned(FixVec2.from_ints(100, 100, status), FixVec2.zero(), 16 * FixMath.SCALE, 16 * FixMath.SCALE, status),
	]
	world.add_initial_bodies([1, 2], bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	var link: SimLink = SimLink.create_unassigned(1, 2, AttachPayloadDefinition.AnchorMode.SURFACE_FOLLOW, FixVec2.zero(), 0, 10000, 2, 0, status)
	world.add_link(link, status); world.step(status)
	var anchor: SimBody = world.body_by_id(1, status); var attached: SimBody = world.body_by_id(2, status)
	var anchor_move: int = absi(anchor.position().x_raw() - 100 * FixMath.SCALE); var attached_move: int = absi(attached.position().x_raw() - 100 * FixMath.SCALE)
	var distance: int = attached.position().sub(anchor.position(), status).length_raw(status)
	var collision_event: bool = false
	while status.is_ok() and world.event_cursor() < world.event_count():
		if world.consume_next_event(status).type_id() == SimEvent.TypeId.BODY_COLLIDED: collision_event = true
	check("P2-4-LINK-OVERLAP-INVERSE-MASS-NO-COLLISION", status.is_ok() and distance >= 32 * FixMath.SCALE - 1 and attached_move >= anchor_move * 3 and not collision_event)
	check("P2-4-LINK-VELOCITY-DERIVED-AFTER-CONSTRAINT", status.is_ok() and anchor.velocity().x_raw() == (anchor.position().x_raw() - 100 * FixMath.SCALE) * SimWorld.DT_DEN and attached.velocity().x_raw() == (attached.position().x_raw() - 100 * FixMath.SCALE) * SimWorld.DT_DEN)


func test_link_limits() -> void:
	var status := SimStatus.new(); var world := SimWorld.create(7, 11, status)
	var keys: Array[int] = []; var bodies: Array[SimBody] = []
	for index: int in range(16):
		keys.append(index + 1)
		bodies.append(SimBody.create_unassigned(FixVec2.from_ints(index * 24, 0, status), FixVec2.zero(), 8 * FixMath.SCALE, FixMath.ONE_RAW, status))
	world.add_initial_bodies(keys, bodies, status)
	var boundary_ok: bool = true
	for left: int in range(1, 9):
		for right: int in range(9, 17):
			var link: SimLink = SimLink.create_unassigned(left, right, SimLink.AnchorMode.SURFACE_FOLLOW, FixVec2.zero(), 0, 10000, 1, 0, status)
			if world.add_link(link, status) == 0: boundary_ok = false
	check("P2-4-LINK-LIMIT-64-BOUNDARY", boundary_ok and status.is_ok() and world.link_count() == SimLimits.LINK_MAX_COUNT)
	var over_status := SimStatus.new(); var extra: SimLink = SimLink.create_unassigned(1, 16, SimLink.AnchorMode.FIXED_POINT, FixVec2.from_ints(1, 0, over_status), 0, 10000, 1, 0, over_status)
	world.add_link(extra, over_status)
	check("P2-4-LINK-LIMIT-65-FAIL", over_status.code() == SimStatus.Code.ATTACH_LIMIT_EXCEEDED and world.link_count() == SimLimits.LINK_MAX_COUNT)

	var body_status := SimStatus.new(); var body_world := SimWorld.create(13, 17, body_status)
	keys.clear(); bodies.clear()
	for index: int in range(10): keys.append(index + 1); bodies.append(SimBody.create_unassigned(FixVec2.from_ints(index * 24, 0, body_status), FixVec2.zero(), 8 * FixMath.SCALE, FixMath.ONE_RAW, body_status))
	body_world.add_initial_bodies(keys, bodies, body_status)
	for other: int in range(2, 10): body_world.add_link(SimLink.create_unassigned(1, other, SimLink.AnchorMode.SURFACE_FOLLOW, FixVec2.zero(), 0, 10000, 1, 0, body_status), body_status)
	var body_over := SimStatus.new(); body_world.add_link(SimLink.create_unassigned(1, 10, SimLink.AnchorMode.SURFACE_FOLLOW, FixVec2.zero(), 0, 10000, 1, 0, body_over), body_over)
	check("P2-4-LINK-PER-BODY-8-BOUNDARY", body_status.is_ok() and body_world.link_count_for_body(1) == SimLimits.LINK_MAX_PER_BODY and body_over.code() == SimStatus.Code.ATTACH_LIMIT_EXCEEDED)


func test_determinism_1000(catalog: ContentCatalog) -> void:
	var expected := PackedByteArray(); var all_equal: bool = true
	for index: int in range(1000):
		var status := SimStatus.new(); var state: BattleState = make_state(catalog, [1], status)
		var report: EffectResolutionReport = resolve(state, record(BattleTriggerId.Value.ON_BATTLE_START, 1, 2, status), status)
		var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
		if index == 0: expected = bytes
		elif bytes != expected: all_equal = false
		if not status.is_ok() or not report.is_initialized(): all_equal = false; break
	var restore_status := SimStatus.new(); var restored: BattleState = BattleSnapshot.decode(expected, restore_status).restore_state_with_catalog(catalog, restore_status)
	check("P2-4-DETERMINISM-1000-RESTORE", all_equal and restore_status.is_ok() and BattleSnapshot.capture(restored, restore_status).encode(restore_status) == expected)


func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new(); var loaded: bool = bool(db.call("reload_catalog", FIXTURE_ROOT, content_status)); var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P2-4-SCHEMA-CATALOG-V4", loaded and content_status.is_ok() and catalog.piece_count() == 6 and catalog.ability_count() == 12 and catalog.fingerprint_hex() == EXPECTED_FINGERPRINT)
	test_spawn_and_binding(catalog)
	test_projectile_and_expiry(catalog)
	test_turn_expiry(catalog)
	test_transform_and_binding(catalog)
	test_links_snapshot_and_release(catalog)
	test_on_link_release(catalog)
	test_transition_rollbacks(catalog)
	test_link_solver_overlap_and_velocity()
	test_link_limits()
	test_determinism_1000(catalog)
	if failures == 0: print("P2_DYNAMIC_PIECE_MECHANICS_RESULT: PASS"); quit(0)
	else: print("P2_DYNAMIC_PIECE_MECHANICS_RESULT: FAIL (%d)" % failures); quit(1)
