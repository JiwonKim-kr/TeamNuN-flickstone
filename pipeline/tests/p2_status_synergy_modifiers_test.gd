extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
const FIXTURE: String = "res://pipeline/tests/fixtures/p2_status_synergy"
var failures: int = 0

func check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: failures += 1; print("[FAIL] %s" % label)

func record(sequence: int, trigger_id: int, phase: int, status: SimStatus, other_body_id: int = 0) -> BattleTriggerRecord:
	return BattleTriggerRecord.create(sequence, 0, trigger_id, phase, 0, 0, 1, other_body_id, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, status)

func identities(status: SimStatus) -> Array[BattlePieceIdentity]:
	return [
		BattlePieceIdentity.create(1, 1, 1, BattleParticipant.Faction.PLAYER, false, status),
		BattlePieceIdentity.create(2, 1, 1, BattleParticipant.Faction.PLAYER, false, status),
		BattlePieceIdentity.create(4, 1, 1, BattleParticipant.Faction.ENEMY, false, status),
		BattlePieceIdentity.create(5, 1, 1, BattleParticipant.Faction.ENEMY, false, status),
	]

func status_definition(numeric_id: int, stack_policy: int, refresh_policy: int, merge_sources: bool, duration_kind: int = StatusDefinition.DurationKind.TARGET_TURNS, default_duration: int = 2, max_duration: int = 8, max_stacks: int = 3) -> StatusDefinition:
	var cs := ContentStatus.new(); var modifiers: Array[StatusModifierDefinition] = []
	return StatusDefinition.create(ContentIdRef.create(numeric_id, "test_%d" % numeric_id, cs), stack_policy, max_stacks, duration_kind, default_duration, max_duration, refresh_policy, merge_sources, modifiers, cs)

func refreshed_remaining(definition: StatusDefinition) -> int:
	var local_status := SimStatus.new(); var local := StatusCollection.new()
	# Create the pre-refresh remaining=1 snapshot while preserving the original key.
	var items: Array[StatusInstance] = [StatusInstance.create(definition.numeric_id(), 1, 2, 1, 1, 0, 1, local_status)]
	local.restore(items, 2, local_status); local.apply(definition, 1, 3, 1, 1, local_status)
	return local.item_at(0, local_status).remaining() if local_status.is_ok() else -1

func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new(); var loaded: bool = bool(db.call("reload_catalog", FIXTURE, content_status)); var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	check("P2-3-SCHEMA-CATALOG-V7", loaded and content_status.is_ok() and catalog.status_count() == 3 and catalog.synergy_count() == 1 and catalog.fingerprint_hex() == "109bd2868c82c88b2f84dc63408c9dcfa967e8ae1293abf7b6985ff20ccad7ca")
	var status := SimStatus.new(); var ids: Array[BattlePieceIdentity] = identities(status); var tally: SynergyTally = SynergyTallyBuilder.build(catalog, ids, status)
	check("P2-3-SYNERGY-TALLY", status.is_ok() and tally.count() == 2 and tally.value_at(0) == 2 and tally.value_at(1) == 2)
	var reversed_ids: Array[BattlePieceIdentity] = ids.duplicate(); reversed_ids.reverse(); var reversed_tally: SynergyTally = SynergyTallyBuilder.build(catalog, reversed_ids, status)
	check("P2-3-IDENTITY-ORDER-INDEPENDENT", status.is_ok() and reversed_tally.count() == tally.count() and reversed_tally.tag_numeric_id_at(0) == tally.tag_numeric_id_at(0) and reversed_tally.faction_id_at(0) == tally.faction_id_at(0) and reversed_tally.value_at(0) == tally.value_at(0))
	var collection := StatusCollection.new(); var cs := ContentStatus.new(); var chill: StatusDefinition = catalog.status_by_numeric_id(1, cs)
	collection.apply(chill, 1, 2, 1, 0, status); collection.apply(chill, 1, 3, 1, 1, status)
	var merged: StatusInstance = collection.item_at(0, status)
	check("P2-3-STATUS-MERGE-STACK-REFRESH", status.is_ok() and collection.count() == 1 and merged.source_body_id() == 2 and merged.stacks() == 2 and merged.remaining() == 2 and merged.applied_turn_index() == 1)
	var resolver: ModifierResolver = ModifierResolver.build(catalog, ids, tally, status)
	var speed: int = EffectiveStats.resolve(100, resolver.aggregate(1, ModifierKind.Value.SPEED_STAT, collection, status), ModifierKind.Value.SPEED_STAT, status)
	var outgoing: int = EffectiveStats.resolve(0, resolver.aggregate(1, ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, collection, status), ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, status)
	check("P2-3-MODIFIER-ORDER-SCALE", status.is_ok() and speed == 90 and outgoing == 4000)
	var token_ids: Array[BattlePieceIdentity] = [BattlePieceIdentity.create(1, 1, 1, BattleParticipant.Faction.PLAYER, false, status), BattlePieceIdentity.create(2, 1, 1, BattleParticipant.Faction.PLAYER, false, status), BattlePieceIdentity.create(3, 1, 1, BattleParticipant.Faction.PLAYER, true, status)]
	var token_tally: SynergyTally = SynergyTallyBuilder.build(catalog, token_ids, status); var token_resolver: ModifierResolver = ModifierResolver.build(catalog, token_ids, token_tally, status)
	var token_outgoing: int = EffectiveStats.resolve(0, token_resolver.aggregate(3, ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, StatusCollection.new(), status), ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, status)
	check("P2-3-TOKEN-RECEIVES-NOT-COUNTS", status.is_ok() and token_tally.count() == 1 and token_tally.value_at(0) == 2 and token_outgoing == 2000)
	var cap_entries: Array[SynergyTally.Entry] = [SynergyTally.Entry.new(1, BattleParticipant.Faction.PLAYER, 64), SynergyTally.Entry.new(1, BattleParticipant.Faction.ENEMY, 64)]
	var cap_tally: SynergyTally = SynergyTally.create(cap_entries, status); var cap_resolver: ModifierResolver = ModifierResolver.build(catalog, ids, cap_tally, status)
	var capped_outgoing: int = EffectiveStats.resolve(0, cap_resolver.aggregate(1, ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, StatusCollection.new(), status), ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, status)
	check("P2-3-BOTH-FACTIONS-TIERS-COUNT-CAP", status.is_ok() and capped_outgoing == 11000)
	var saturate_status := SimStatus.new(); var saturated_attack: int = EffectiveStats.resolve(999999, ModifierAggregate.create(ModifierKind.Value.ATTACK, 100, 0, saturate_status), ModifierKind.Value.ATTACK, saturate_status)
	var strict_status := SimStatus.new(); EffectiveStats.resolve(SimLimits.MASS_MIN_RAW, ModifierAggregate.create(ModifierKind.Value.MASS_RAW, -1, 0, strict_status), ModifierKind.Value.MASS_RAW, strict_status)
	check("P2-3-SATURATE-STRICT-RANGE", saturate_status.is_ok() and saturated_attack == DamageLimits.STAT_MAX and strict_status.code() == SimStatus.Code.MODIFIER_RANGE_VIOLATION)
	collection.expire_target_turn(1, 1, catalog, status); check("P2-3-TURN-SAME-NO-DECAY", collection.item_at(0, status).remaining() == 2)
	collection.expire_target_turn(1, 2, catalog, status); check("P2-3-TURN-NEXT-DECAY", collection.item_at(0, status).remaining() == 1)
	collection.expire_target_turn(1, 3, catalog, status); check("P2-3-TURN-EXPIRE", collection.count() == 0)

	var single: StatusDefinition = status_definition(10, StatusDefinition.StackPolicy.SINGLE, StatusDefinition.RefreshPolicy.KEEP, true)
	var stacked: StatusDefinition = status_definition(11, StatusDefinition.StackPolicy.STACKED, StatusDefinition.RefreshPolicy.KEEP, true)
	var independent: StatusDefinition = status_definition(12, StatusDefinition.StackPolicy.INDEPENDENT, StatusDefinition.RefreshPolicy.KEEP, false)
	var policy_collection := StatusCollection.new(); policy_collection.apply(single, 1, 9, 3, 0, status); policy_collection.apply(single, 1, 8, 3, 1, status)
	check("P2-3-STATUS-SINGLE", status.is_ok() and policy_collection.count() == 1 and policy_collection.item_at(0, status).stacks() == 1)
	policy_collection = StatusCollection.new(); policy_collection.apply(stacked, 1, 9, 3, 0, status); policy_collection.apply(stacked, 1, 8, 3, 1, status)
	check("P2-3-STATUS-STACKED-SATURATE", status.is_ok() and policy_collection.count() == 1 and policy_collection.item_at(0, status).stacks() == 3)
	policy_collection = StatusCollection.new(); policy_collection.apply(independent, 1, 9, 1, 0, status); policy_collection.apply(independent, 1, 2, 1, 0, status)
	check("P2-3-STATUS-INDEPENDENT-SORTED", status.is_ok() and policy_collection.count() == 2 and policy_collection.item_at(0, status).source_body_id() == 2)
	policy_collection.remove(1, independent.numeric_id(), 1, status)
	check("P2-3-REMOVE-SORTED-FIRST", status.is_ok() and policy_collection.count() == 1 and policy_collection.item_at(0, status).source_body_id() == 9)
	check("P2-3-REFRESH-POLICIES", refreshed_remaining(status_definition(20, 2, 1, true)) == 2 and refreshed_remaining(status_definition(21, 2, 2, true)) == 2 and refreshed_remaining(status_definition(22, 2, 3, true)) == 3 and refreshed_remaining(status_definition(23, 2, 4, true)) == 1)

	var body_limit := StatusCollection.new(); var body_limit_status := SimStatus.new()
	for index: int in range(StatusCollection.BODY_MAX): body_limit.apply(independent, 1, 2, 1, 0, body_limit_status)
	var body_boundary_ok: bool = body_limit_status.is_ok() and body_limit.count() == StatusCollection.BODY_MAX
	body_limit.apply(independent, 1, 2, 1, 0, body_limit_status)
	check("P2-3-STATUS-BODY-LIMIT", body_boundary_ok and body_limit_status.code() == SimStatus.Code.STATUS_LIMIT_EXCEEDED)
	var full_items: Array[StatusInstance] = []; var full_status := SimStatus.new(); var sequence: int = 1
	for body_id: int in range(1, 65):
		for ordinal: int in range(64):
			full_items.append(StatusInstance.create(independent.numeric_id(), body_id, 1, 1, 1, 0, sequence, full_status)); sequence += 1
	var full_collection := StatusCollection.new(); full_collection.restore(full_items, sequence, full_status); var full_boundary_ok: bool = full_status.is_ok() and full_collection.count() == StatusCollection.BATTLE_MAX
	full_collection.apply(independent, 65, 1, 1, 0, full_status)
	check("P2-3-STATUS-BATTLE-LIMIT", full_boundary_ok and full_status.code() == SimStatus.Code.STATUS_LIMIT_EXCEEDED)

	var state: BattleState = P1GrayboxFixture.create(7, 9, false, status); var bindings: Array[AbilityBinding] = [AbilityBinding.create(1, 1, status), AbilityBinding.create(1, 2, status), AbilityBinding.create(1, 3, status)]
	check("P2-3-ATTACH-CONTENT", state.attach_content(catalog, ids, bindings, status) and status.is_ok())
	var before_materialize: SimBody = state.world_copy(status).body_by_id(1, status); state._materialize_physical_stats(status); var after_materialize: SimBody = state.world_copy(status).body_by_id(1, status)
	check("P2-3-PHYSICAL-MATERIALIZE", status.is_ok() and before_materialize.mass_raw() == 64 * FixMath.SCALE and after_materialize.mass_raw() == 68 * FixMath.SCALE)
	var registry: AbilityRegistry = AbilityRegistry.bind(catalog, bindings, status)
	var apply_report: EffectResolutionReport = EffectResolver.resolve_transition(state, registry, [record(1, BattleTriggerId.Value.ON_TURN_START, BattleState.Phase.TURN_START, status)], catalog.fingerprint_bytes(), status)
	check("P2-3-APPLY-STATUS-EFFECT", status.is_ok() and apply_report.status_application_count() == 1 and state.status_count() == 1)
	var stat_report: EffectResolutionReport = EffectResolver.resolve_transition(state, registry, [record(2, BattleTriggerId.Value.ON_LAUNCH, BattleState.Phase.RESOLVE, status)], catalog.fingerprint_bytes(), status)
	check("P2-3-MODIFY-STAT-EFFECT", status.is_ok() and stat_report.application_count() == 1 and state.combatant_by_body_id(1, status).attack() == 25)
	var remove_report: EffectResolutionReport = EffectResolver.resolve_transition(state, registry, [record(3, BattleTriggerId.Value.ON_TURN_END, BattleState.Phase.TURN_END, status)], catalog.fingerprint_bytes(), status)
	check("P2-3-REMOVE-STATUS-EFFECT", status.is_ok() and remove_report.status_removal_count() == 1 and state.status_count() == 0)
	var sequence_before_noop: int = state.next_status_sequence(); var rng_before_noop: int = state.world_copy(status).rng_draw_count_lo()
	var noop_report: EffectResolutionReport = EffectResolver.resolve_transition(state, registry, [record(4, BattleTriggerId.Value.ON_TURN_END, BattleState.Phase.TURN_END, status)], catalog.fingerprint_bytes(), status)
	check("P2-3-REMOVE-NOOP", status.is_ok() and noop_report.status_removal_count() == 0 and state.next_status_sequence() == sequence_before_noop and state.world_copy(status).rng_draw_count_lo() == rng_before_noop)
	var limit_records: Array[BattleTriggerRecord] = []
	for index: int in range(BattleLimits.STATUS_MAX_CHANGES_PER_TRANSITION): limit_records.append(record(index + 1, BattleTriggerId.Value.ON_TURN_START, BattleState.Phase.TURN_START, status))
	var limit_state: BattleState = P1GrayboxFixture.create(7, 9, false, status); limit_state.attach_content(catalog, ids, bindings, status)
	var limit_report: EffectResolutionReport = EffectResolver.resolve_transition(limit_state, registry, limit_records, catalog.fingerprint_bytes(), status)
	check("P2-3-TRANSITION-STATUS-LIMIT-BOUNDARY", status.is_ok() and limit_report.status_application_count() == 1 and limit_report.status_update_count() == BattleLimits.STATUS_MAX_CHANGES_PER_TRANSITION - 1)
	var overflow_state: BattleState = P1GrayboxFixture.create(7, 9, false, status); overflow_state.attach_content(catalog, ids, bindings, status)
	var overflow_before: PackedByteArray = BattleSnapshot.capture(overflow_state, status).encode(status); limit_records.append(record(BattleLimits.STATUS_MAX_CHANGES_PER_TRANSITION + 1, BattleTriggerId.Value.ON_TURN_START, BattleState.Phase.TURN_START, status))
	var overflow_status := SimStatus.new(); EffectResolver.resolve_transition(overflow_state, registry, limit_records, catalog.fingerprint_bytes(), overflow_status)
	var overflow_after: PackedByteArray = BattleSnapshot.capture(overflow_state, status).encode(status)
	check("P2-3-TRANSITION-STATUS-LIMIT-ROLLBACK", overflow_status.code() == SimStatus.Code.STATUS_LIMIT_EXCEEDED and overflow_before == overflow_after)
	var decay_state: BattleState = P1GrayboxFixture.create(7, 9, false, status); decay_state.attach_content(catalog, ids, [], status); decay_state._effect_apply_status(1, 2, 1, 1, status)
	var decay_instances: Array[StatusInstance] = [decay_state.status_at(0, status)]; var decay_bases: Array[BattleBaseBodyStats] = []
	for base_index: int in range(decay_state.base_body_stats_count()): decay_bases.append(decay_state.base_body_stats_at(base_index, status))
	decay_state._status_restore_snapshot(2, ids, decay_state.synergy_tally_copy(), decay_instances, decay_state.next_status_sequence(), decay_bases, status)
	var empty_registry: AbilityRegistry = AbilityRegistry.bind(catalog, [], status)
	var decay_report: EffectResolutionReport = EffectResolver.resolve_transition(decay_state, empty_registry, [record(1, BattleTriggerId.Value.ON_TURN_END, BattleState.Phase.TURN_END, status)], catalog.fingerprint_bytes(), status)
	check("P2-3-TURN-DECAY-REPORTS-UPDATE", status.is_ok() and decay_report.status_update_count() == 1 and decay_report.status_removal_count() == 0 and decay_state.status_at(0, status).remaining() == 1)
	var hit_status := SimStatus.new()
	decay_state._status_restore_snapshot(2, ids, decay_state.synergy_tally_copy(), decay_instances, decay_state.next_status_sequence(), decay_bases, hit_status)
	var hit_report: EffectResolutionReport = EffectResolver.resolve_transition(decay_state, empty_registry, [record(2, BattleTriggerId.Value.ON_HIT_TAKE, BattleState.Phase.TURN_END, hit_status, 2)], catalog.fingerprint_bytes(), hit_status)
	check("P2-3-NON-TURN-END-DOES-NOT-DECAY", hit_status.is_ok() and hit_report.status_update_count() == 0 and decay_state.status_at(0, hit_status).remaining() == 2)
	var barrier_status := SimStatus.new(); var barrier_state: BattleState = P1GrayboxFixture.create(7, 9, false, barrier_status); barrier_state.attach_content(catalog, ids, [], barrier_status); barrier_state.complete_battle_start(barrier_status)
	var lifetime_target: int = barrier_state.current_actor_body_id(); barrier_state._effect_apply_status(lifetime_target, 2, 1, lifetime_target, barrier_status); barrier_state.complete_turn_start(barrier_status); barrier_state.commit_forced_no_launch(barrier_status); barrier_state.complete_turn_end(barrier_status)
	var first_turn_records: Array[BattleTriggerRecord] = []
	for trigger_index: int in range(barrier_state.trigger_record_count()): first_turn_records.append(barrier_state.trigger_record_at(trigger_index, barrier_status))
	EffectResolver.resolve_transition(barrier_state, empty_registry, first_turn_records, catalog.fingerprint_bytes(), barrier_status)
	var same_turn_remaining: int = barrier_state.status_at(0, barrier_status).remaining(); barrier_state.resolve_check(barrier_status)
	while barrier_status.is_ok() and barrier_state.current_actor_body_id() != lifetime_target:
		barrier_state.complete_turn_start(barrier_status); barrier_state.commit_forced_no_launch(barrier_status); barrier_state.complete_turn_end(barrier_status)
		var skipped_turn_records: Array[BattleTriggerRecord] = []
		for trigger_index: int in range(barrier_state.trigger_record_count()): skipped_turn_records.append(barrier_state.trigger_record_at(trigger_index, barrier_status))
		EffectResolver.resolve_transition(barrier_state, empty_registry, skipped_turn_records, catalog.fingerprint_bytes(), barrier_status); barrier_state.resolve_check(barrier_status)
	barrier_state.complete_turn_start(barrier_status); barrier_state.commit_forced_no_launch(barrier_status); barrier_state.complete_turn_end(barrier_status)
	var second_turn_records: Array[BattleTriggerRecord] = []
	for trigger_index: int in range(barrier_state.trigger_record_count()): second_turn_records.append(barrier_state.trigger_record_at(trigger_index, barrier_status))
	EffectResolver.resolve_transition(barrier_state, empty_registry, second_turn_records, catalog.fingerprint_bytes(), barrier_status)
	check("P2-3-TURN-END-BARRIER-LIFETIME", barrier_status.is_ok() and same_turn_remaining == 2 and barrier_state.status_at(0, barrier_status).remaining() == 1)
	state._effect_apply_status(1, 2, 3, 1, status); var charges_before: int = state.status_at(0, status).remaining(); state._status_expire_turn_end(1, status); var charges_after_turn: int = state.status_at(0, status).remaining(); state._effect_remove_status(1, 3, 1, status)
	check("P2-3-CHARGES-REMOVE-ONLY", status.is_ok() and charges_before == 3 and charges_after_turn == 3 and state.status_at(0, status).remaining() == 2)
	var lifetime_state: BattleState = P1GrayboxFixture.create(7, 9, false, status); lifetime_state.attach_content(catalog, ids, [], status); lifetime_state._effect_apply_status(1, 2, 2, 1, status); lifetime_state._effect_apply_status(2, 1, 2, 1, status); lifetime_state._remove_body_state(2)
	check("P2-3-SOURCE-SURVIVES-TARGET-REMOVES", status.is_ok() and lifetime_state.status_count() == 1 and lifetime_state.status_at(0, status).target_body_id() == 1 and lifetime_state.status_at(0, status).source_body_id() == 2)

	var ctb_state: BattleState = P1GrayboxFixture.create(7, 9, false, status); ctb_state.attach_content(catalog, ids, [], status); ctb_state._effect_apply_status(3, 1, 1, 2, status); ctb_state.complete_battle_start(status)
	check("P2-3-CTB-EFFECTIVE-SPEED", status.is_ok() and ctb_state.current_actor_body_id() == 6 and ctb_state.participant_by_body_id(3, status).speed_stat() == 125)
	var damage_state: BattleState = P1GrayboxFixture.create(7, 9, false, status); damage_state.attach_content(catalog, ids, [], status)
	var attacker: BattleCombatant = damage_state.combatant_by_body_id(1, status); var victim: BattleCombatant = damage_state.combatant_by_body_id(4, status)
	var normal_damage: DamageResult = damage_state._resolve_damage_direction(attacker, victim, 66 * FixMath.SCALE, 66 * FixMath.SCALE, 1024 * FixMath.SCALE, 100, status)
	damage_state._effect_modify_stat(1, ModifierKind.Value.CRITICAL_BASIS_POINTS, 10000, status); attacker = damage_state.combatant_by_body_id(1, status)
	var critical_damage: DamageResult = damage_state._resolve_damage_direction(attacker, victim, 66 * FixMath.SCALE, 66 * FixMath.SCALE, 1024 * FixMath.SCALE, 101, status)
	check("P2-3-DAMAGE-MODIFIERS-CRITICAL", status.is_ok() and normal_damage.resolved_damage() > 0 and critical_damage.resolved_damage() == normal_damage.resolved_damage() * 2 and damage_state.world_copy(status).rng_draw_count_lo() == 0)
	var invalid_state: BattleState = P1GrayboxFixture.create(7, 9, false, status); invalid_state.attach_content(catalog, ids, [], status); var invalid_before: PackedByteArray = BattleSnapshot.capture(invalid_state, status).encode(status)
	var invalid_status := SimStatus.new(); invalid_state._effect_modify_stat(1, ModifierKind.Value.ATTACK, DamageLimits.STAT_MAX, invalid_status)
	var capture_status := SimStatus.new(); var invalid_after: PackedByteArray = BattleSnapshot.capture(invalid_state, capture_status).encode(capture_status)
	check("P2-3-MODIFY-STAT-RANGE-ATOMIC", invalid_status.code() == SimStatus.Code.MODIFIER_RANGE_VIOLATION and capture_status.is_ok() and invalid_before == invalid_after)
	var bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status); var restored: BattleState = BattleSnapshot.decode(bytes, status).restore_state_with_catalog(catalog, status); var bytes_again: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	check("P2-3-SNAPSHOT-V5-ROUNDTRIP", status.is_ok() and bytes == bytes_again and restored.turn_index() == state.turn_index())
	var empty_db: Node = DATA_DB_SCRIPT.new(); root.add_child(empty_db); var empty_cs := ContentStatus.new(); empty_db.call("reload_catalog", "res://src/core/data", empty_cs); var empty_catalog: ContentCatalog = empty_db.call("catalog_copy", empty_cs) as ContentCatalog
	var mismatch_status := SimStatus.new(); BattleSnapshot.decode(bytes, mismatch_status).restore_state_with_catalog(empty_catalog, mismatch_status)
	check("P2-3-SNAPSHOT-FINGERPRINT-MISMATCH", empty_cs.is_ok() and mismatch_status.code() == SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH and BattleSnapshot.capture(state, status).encode(status) == bytes)
	var expected: PackedByteArray = PackedByteArray(); var repeat_ok: bool = true
	for index: int in range(1000):
		var local_status := SimStatus.new(); var local_state: BattleState = P1GrayboxFixture.create(7, 9, false, local_status); local_state.attach_content(catalog, ids, bindings, local_status)
		EffectResolver.resolve_transition(local_state, registry, [record(1, BattleTriggerId.Value.ON_TURN_START, BattleState.Phase.TURN_START, local_status)], catalog.fingerprint_bytes(), local_status)
		var local_bytes: PackedByteArray = BattleSnapshot.capture(local_state, local_status).encode(local_status)
		if index == 0: expected = local_bytes
		elif expected != local_bytes: repeat_ok = false
		if not local_status.is_ok(): repeat_ok = false; break
	check("P2-3-DETERMINISM-1000", repeat_ok)
	if failures == 0: print("P2_STATUS_SYNERGY_MODIFIERS_RESULT: PASS"); quit(0)
	else: print("P2_STATUS_SYNERGY_MODIFIERS_RESULT: FAIL (%d)" % failures); quit(1)
