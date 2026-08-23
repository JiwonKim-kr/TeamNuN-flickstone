extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
var _failures: int = 0

func _check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: _failures += 1; print("[FAIL] %s" % label)

func _hit_records(count: int, status: SimStatus) -> Array[BattleTriggerRecord]:
	var result: Array[BattleTriggerRecord] = []
	for sequence: int in range(1, count + 1):
		result.append(BattleTriggerRecord.create(sequence, 0, BattleTriggerId.Value.ON_HIT_DEAL, BattleState.Phase.RESOLVE, 0, 0, 1, 4, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.from_ints(1, 0, status), 0, 0, 0, status))
	return result

func _selector_limit_state(enemy_count: int, status: SimStatus) -> BattleState:
	var world := SimWorld.create(7, 9, status)
	var boundary: Array[FixVec2] = [FixVec2.from_ints(0, 0, status), FixVec2.from_ints(1024, 0, status), FixVec2.from_ints(1024, 1024, status), FixVec2.from_ints(0, 1024, status)]
	world.configure_boundary(boundary, SimWorld.BoundaryType.WALL, status)
	var keys: Array[int] = []; var bodies: Array[SimBody] = []
	for index: int in range(enemy_count + 1):
		keys.append(index + 1)
		bodies.append(SimBody.create_unassigned(FixVec2.from_ints(16 + (index % 32) * 30, 16 + (index / 32) * 30, status), FixVec2.zero(), 8 * FixMath.SCALE, 64 * FixMath.SCALE, status))
	world.add_initial_bodies(keys, bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	var participants: Array[BattleParticipant] = []; var combatants: Array[BattleCombatant] = []
	for index: int in range(enemy_count + 1):
		var faction: int = BattleParticipant.Faction.PLAYER if index == 0 else BattleParticipant.Faction.ENEMY
		participants.append(BattleParticipant.create(index + 1, faction, true, index == 0, true, 100, status))
		combatants.append(BattleCombatant.create(index + 1, faction, 100, 20, 0, status))
	return BattleState.create_with_combatants(world, participants, combatants, status)

func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new()
	var loaded: bool = bool(db.call("reload_catalog", "res://pipeline/tests/fixtures/p2_effect_resolution", content_status))
	var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	_check("P2-2-E02-SCHEMA-V2-001", loaded and content_status.is_ok() and catalog.ability_count() == 8)
	var status := SimStatus.new()
	var state: BattleState = P1GrayboxFixture.create(1, 2, false, status)
	var bindings: Array[AbilityBinding] = []
	for ability_id: int in range(1, 7): bindings.append(AbilityBinding.create(1, ability_id, status))
	var registry: AbilityRegistry = AbilityRegistry.bind(catalog, bindings, status)
	var record: BattleTriggerRecord = BattleTriggerRecord.create(1, 0, BattleTriggerId.Value.ON_HIT_DEAL, BattleState.Phase.RESOLVE, 0, 0, 1, 4, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.from_ints(1, 0, status), 0, 0, 0, status)
	var relation_record: BattleTriggerRecord = BattleTriggerRecord.create(2, 0, BattleTriggerId.Value.ON_HIT_DEAL, BattleState.Phase.RESOLVE, 0, 0, 1, 4, 2, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.from_ints(1, 0, status), 0, 0, 0, status)
	var definition_status := ContentStatus.new()
	var condition_results: Array[bool] = []
	condition_results.append(AbilityConditionEvaluator.matches(state, 1, relation_record, AbilityConditionDefinition.create(AbilityConditionDefinition.Kind.ALWAYS, 0, 0, 0, definition_status), status))
	condition_results.append(AbilityConditionEvaluator.matches(state, 1, relation_record, AbilityConditionDefinition.create(AbilityConditionDefinition.Kind.RELATION_EXISTS, AbilityConditionDefinition.Relation.OTHER, 0, 0, definition_status), status))
	condition_results.append(AbilityConditionEvaluator.matches(state, 1, relation_record, AbilityConditionDefinition.create(AbilityConditionDefinition.Kind.RELATION_ALIVE, AbilityConditionDefinition.Relation.OTHER, 0, 0, definition_status), status))
	condition_results.append(AbilityConditionEvaluator.matches(state, 1, relation_record, AbilityConditionDefinition.create(AbilityConditionDefinition.Kind.RELATION_IS_ALLY, AbilityConditionDefinition.Relation.INSTIGATOR, 0, 0, definition_status), status))
	condition_results.append(AbilityConditionEvaluator.matches(state, 1, relation_record, AbilityConditionDefinition.create(AbilityConditionDefinition.Kind.RELATION_IS_ENEMY, AbilityConditionDefinition.Relation.OTHER, 0, 0, definition_status), status))
	condition_results.append(AbilityConditionEvaluator.matches(state, 1, relation_record, AbilityConditionDefinition.create(AbilityConditionDefinition.Kind.HP_AT_MOST_BASIS_POINTS, AbilityConditionDefinition.Relation.OTHER, 10000, 0, definition_status), status))
	condition_results.append(AbilityConditionEvaluator.matches(state, 1, relation_record, AbilityConditionDefinition.create(AbilityConditionDefinition.Kind.HP_AT_LEAST_BASIS_POINTS, AbilityConditionDefinition.Relation.OTHER, 10000, 0, definition_status), status))
	var selector_results: Array[Array] = []
	for selector_kind: int in range(AbilitySelectorDefinition.Kind.OWNER, AbilitySelectorDefinition.Kind.NEAREST_ENEMY + 1):
		selector_results.append(AbilityTargetSelector.select(state, 1, relation_record, AbilitySelectorDefinition.create(selector_kind, 0, 0, definition_status), status))
	_check("P2-2-E03-CONDITION-VOCABULARY-001", status.is_ok() and definition_status.is_ok() and condition_results == [true, true, true, true, true, true, true])
	_check("P2-2-E04-SELECTOR-VOCABULARY-001", status.is_ok() and selector_results[0] == [1] and selector_results[1] == [1] and selector_results[2] == [4] and selector_results[3] == [2] and selector_results[4] == [1, 2, 3] and selector_results[5] == [4, 5, 6] and selector_results[6].size() == 1 and selector_results[6][0] != 1 and selector_results[7].size() == 1 and selector_results[7][0] >= 4)
	var selector_limit_status := SimStatus.new(); var selector_limit_definition_status := ContentStatus.new()
	var selector_limit_state: BattleState = _selector_limit_state(ContentLimits.SELECTOR_MAX_RESULTS, selector_limit_status)
	var selector_limit_record: BattleTriggerRecord = BattleTriggerRecord.create(1, 0, BattleTriggerId.Value.ON_HIT_DEAL, BattleState.Phase.RESOLVE, 0, 0, 1, 2, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, selector_limit_status)
	var all_enemies: AbilitySelectorDefinition = AbilitySelectorDefinition.create(AbilitySelectorDefinition.Kind.ALL_ENEMIES, 0, 0, selector_limit_definition_status)
	var selector_limit_result: Array[int] = AbilityTargetSelector.select(selector_limit_state, 1, selector_limit_record, all_enemies, selector_limit_status)
	_check("P2-2-E09-SELECTOR-LIMIT-256-001", selector_limit_status.is_ok() and selector_limit_definition_status.is_ok() and selector_limit_result.size() == ContentLimits.SELECTOR_MAX_RESULTS and selector_limit_result[0] == 2 and selector_limit_result[-1] == 257)
	var selector_over_status := SimStatus.new()
	var selector_over_state: BattleState = _selector_limit_state(ContentLimits.SELECTOR_MAX_RESULTS + 1, selector_over_status)
	var selector_over_record: BattleTriggerRecord = BattleTriggerRecord.create(1, 0, BattleTriggerId.Value.ON_HIT_DEAL, BattleState.Phase.RESOLVE, 0, 0, 1, 2, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, selector_over_status)
	var selector_over_result: Array[int] = AbilityTargetSelector.select(selector_over_state, 1, selector_over_record, all_enemies, selector_over_status)
	_check("P2-2-E09-SELECTOR-LIMIT-257-FAIL-001", selector_over_result.is_empty() and selector_over_status.code() == SimStatus.Code.EFFECT_LIMIT_EXCEEDED)
	var before: BattleCombatant = state.combatant_by_body_id(4, status)
	var report: EffectResolutionReport = EffectResolver.resolve_transition(state, registry, [record], catalog.fingerprint_bytes(), status)
	var after: BattleCombatant = state.combatant_by_body_id(4, status)
	var after_participant: BattleParticipant = state.participant_by_body_id(4, status)
	var after_body: SimBody = state.world_copy(status).body_by_id(4, status)
	_check("P2-2-E03-E04-BIND-CONDITION-SELECT-001", registry.is_initialized() and registry.binding_count() == 6)
	_check("P2-2-E05-NONDAMAGE-EFFECTS-ATOMIC-001", status.is_ok() and report.is_initialized() and report.invocation_count() == 5 and report.application_count() == 5 and before.current_hp() == 100 and after.current_hp() == 100 and after_participant.ct() == 100 and after_body.velocity().x_raw() == 100 and after_body.velocity().y_raw() == 0)
	var snapshot_bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var restored: BattleState = BattleSnapshot.decode(snapshot_bytes, status).restore_state(status)
	var reencoded: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	_check("P2-2-E11-SNAPSHOT-V4-001", status.is_ok() and snapshot_bytes == reencoded and restored.content_fingerprint_bytes() == catalog.fingerprint_bytes() and restored.ability_binding_count() == 6 and restored.next_effect_sequence() == 6)
	var damage_status := SimStatus.new()
	var damage_state: BattleState = P1GrayboxFixture.create(1, 2, false, damage_status)
	var damage_registry: AbilityRegistry = AbilityRegistry.bind(catalog, [AbilityBinding.create(1, 1, damage_status)], damage_status)
	var turn_record: BattleTriggerRecord = BattleTriggerRecord.create(1, 0, BattleTriggerId.Value.ON_TURN_START, BattleState.Phase.TURN_START, 0, 0, 1, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, damage_status)
	var damage_report: EffectResolutionReport = EffectResolver.resolve_transition(damage_state, damage_registry, [turn_record], catalog.fingerprint_bytes(), damage_status)
	var deal_record: BattleTriggerRecord = damage_report.generated_record_at(0, damage_status)
	var take_record: BattleTriggerRecord = damage_report.generated_record_at(1, damage_status)
	_check("P2-2-E05-E08-DAMAGE-NEXT-WAVE-001", damage_status.is_ok() and damage_report.invocation_count() == 1 and damage_report.application_count() == 1 and damage_report.generated_record_count() == 2 and damage_state.combatant_by_body_id(4, damage_status).current_hp() == 90 and deal_record.sequence() == 2 and deal_record.wave() == 1 and deal_record.trigger_id() == BattleTriggerId.Value.ON_HIT_DEAL and deal_record.value_a() == 10 and take_record.sequence() == 3 and take_record.wave() == 1 and take_record.trigger_id() == BattleTriggerId.Value.ON_HIT_TAKE and damage_state.next_trigger_sequence() == 4)
	var duplicate_status := SimStatus.new()
	var duplicate: AbilityRegistry = AbilityRegistry.bind(catalog, [AbilityBinding.create(1, 1, duplicate_status), AbilityBinding.create(1, 1, duplicate_status)], duplicate_status)
	_check("P2-2-E10-DUPLICATE-BIND-FAIL-001", not duplicate.is_initialized() and duplicate_status.code() == SimStatus.Code.INVALID_ABILITY_BINDING)
	var rollback_status := SimStatus.new()
	var rollback_state: BattleState = P1GrayboxFixture.create(1, 2, false, rollback_status)
	var rollback_before: PackedByteArray = BattleSnapshot.capture(rollback_state, rollback_status).encode(rollback_status)
	var invalid_records: Array[BattleTriggerRecord] = [record, null]
	var rollback_report: EffectResolutionReport = EffectResolver.resolve_transition(rollback_state, registry, invalid_records, catalog.fingerprint_bytes(), rollback_status)
	var inspect_status := SimStatus.new()
	var rollback_after: PackedByteArray = BattleSnapshot.capture(rollback_state, inspect_status).encode(inspect_status)
	_check("P2-2-E10-ATOMIC-ROLLBACK-001", not rollback_report.is_initialized() and rollback_status.code() == SimStatus.Code.INVALID_TRIGGER_RECORD and inspect_status.is_ok() and rollback_before == rollback_after)
	var mismatch_status := SimStatus.new()
	var mismatch_state: BattleState = P1GrayboxFixture.create(1, 2, false, mismatch_status)
	var mismatch_before: PackedByteArray = BattleSnapshot.capture(mismatch_state, mismatch_status).encode(mismatch_status)
	var wrong_fingerprint: PackedByteArray = catalog.fingerprint_bytes(); wrong_fingerprint[0] ^= 1
	var mismatch_report: EffectResolutionReport = EffectResolver.resolve_transition(mismatch_state, registry, [record], wrong_fingerprint, mismatch_status)
	inspect_status = SimStatus.new()
	var mismatch_after: PackedByteArray = BattleSnapshot.capture(mismatch_state, inspect_status).encode(inspect_status)
	_check("P2-2-E10-FINGERPRINT-MISMATCH-001", not mismatch_report.is_initialized() and mismatch_status.code() == SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH and inspect_status.is_ok() and mismatch_before == mismatch_after)
	var limit_status := SimStatus.new()
	var limit_state: BattleState = P1GrayboxFixture.create(1, 2, false, limit_status)
	var limit_registry: AbilityRegistry = AbilityRegistry.bind(catalog, [AbilityBinding.create(1, 7, limit_status)], limit_status)
	var limit_report: EffectResolutionReport = EffectResolver.resolve_transition(limit_state, limit_registry, _hit_records(BattleLimits.EFFECT_MAX_INVOCATIONS, limit_status), catalog.fingerprint_bytes(), limit_status)
	_check("P2-2-E09-INVOCATION-APPLICATION-LIMIT-001", limit_status.is_ok() and limit_report.invocation_count() == BattleLimits.EFFECT_MAX_INVOCATIONS and limit_report.application_count() == BattleLimits.EFFECT_MAX_APPLICATIONS)
	var over_status := SimStatus.new()
	var over_state: BattleState = P1GrayboxFixture.create(1, 2, false, over_status)
	var over_before: PackedByteArray = BattleSnapshot.capture(over_state, over_status).encode(over_status)
	var invocation_over_registry: AbilityRegistry = AbilityRegistry.bind(catalog, [AbilityBinding.create(1, 6, over_status)], over_status)
	var over_report: EffectResolutionReport = EffectResolver.resolve_transition(over_state, invocation_over_registry, _hit_records(BattleLimits.EFFECT_MAX_INVOCATIONS + 1, over_status), catalog.fingerprint_bytes(), over_status)
	inspect_status = SimStatus.new()
	var over_after: PackedByteArray = BattleSnapshot.capture(over_state, inspect_status).encode(inspect_status)
	_check("P2-2-E09-INVOCATION-LIMIT-2049-ROLLBACK-001", not over_report.is_initialized() and over_status.code() == SimStatus.Code.EFFECT_LIMIT_EXCEEDED and inspect_status.is_ok() and over_before == over_after)
	var application_over_status := SimStatus.new()
	var application_over_state: BattleState = P1GrayboxFixture.create(1, 2, false, application_over_status)
	var application_over_before: PackedByteArray = BattleSnapshot.capture(application_over_state, application_over_status).encode(application_over_status)
	var application_over_registry: AbilityRegistry = AbilityRegistry.bind(catalog, [AbilityBinding.create(1, 8, application_over_status)], application_over_status)
	var application_over_report: EffectResolutionReport = EffectResolver.resolve_transition(application_over_state, application_over_registry, _hit_records(1639, application_over_status), catalog.fingerprint_bytes(), application_over_status)
	inspect_status = SimStatus.new()
	var application_over_after: PackedByteArray = BattleSnapshot.capture(application_over_state, inspect_status).encode(inspect_status)
	_check("P2-2-E09-APPLICATION-LIMIT-8193-ROLLBACK-001", not application_over_report.is_initialized() and application_over_status.code() == SimStatus.Code.EFFECT_LIMIT_EXCEEDED and inspect_status.is_ok() and application_over_before == application_over_after)
	var wave_status := SimStatus.new()
	var wave_state: BattleState = P1GrayboxFixture.create(1, 2, false, wave_status)
	var wave_before: PackedByteArray = BattleSnapshot.capture(wave_state, wave_status).encode(wave_status)
	var wave_record: BattleTriggerRecord = BattleTriggerRecord.create(1, BattleLimits.TRIGGER_MAX_WAVES - 1, BattleTriggerId.Value.ON_TURN_START, BattleState.Phase.TURN_START, 0, 0, 1, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, wave_status)
	var wave_report: EffectResolutionReport = EffectResolver.resolve_transition(wave_state, damage_registry, [wave_record], catalog.fingerprint_bytes(), wave_status)
	inspect_status = SimStatus.new()
	var wave_after: PackedByteArray = BattleSnapshot.capture(wave_state, inspect_status).encode(inspect_status)
	_check("P2-2-E08-WAVE-32-ROLLBACK-001", not wave_report.is_initialized() and wave_status.code() == SimStatus.Code.EFFECT_LIMIT_EXCEEDED and inspect_status.is_ok() and wave_before == wave_after)
	var record_limit_status := SimStatus.new()
	var record_limit_state: BattleState = P1GrayboxFixture.create(1, 2, false, record_limit_status)
	var record_limit_registry: AbilityRegistry = AbilityRegistry.bind(catalog, [], record_limit_status)
	var record_limit_report: EffectResolutionReport = EffectResolver.resolve_transition(record_limit_state, record_limit_registry, _hit_records(BattleLimits.TRIGGER_MAX_RECORDS, record_limit_status), catalog.fingerprint_bytes(), record_limit_status)
	_check("P2-2-E08-RECORD-LIMIT-4096-001", record_limit_status.is_ok() and record_limit_report.is_initialized() and record_limit_report.invocation_count() == 0)
	var record_over_status := SimStatus.new()
	var record_over_state: BattleState = P1GrayboxFixture.create(1, 2, false, record_over_status)
	var record_over_before: PackedByteArray = BattleSnapshot.capture(record_over_state, record_over_status).encode(record_over_status)
	var record_over_report: EffectResolutionReport = EffectResolver.resolve_transition(record_over_state, record_limit_registry, _hit_records(BattleLimits.TRIGGER_MAX_RECORDS + 1, record_over_status), catalog.fingerprint_bytes(), record_over_status)
	inspect_status = SimStatus.new()
	var record_over_after: PackedByteArray = BattleSnapshot.capture(record_over_state, inspect_status).encode(inspect_status)
	_check("P2-2-E08-RECORD-LIMIT-4097-ROLLBACK-001", not record_over_report.is_initialized() and record_over_status.code() == SimStatus.Code.EFFECT_LIMIT_EXCEEDED and inspect_status.is_ok() and record_over_before == record_over_after)
	var repeat_expected: PackedByteArray = PackedByteArray(); var repeat_ok: bool = true
	for repeat_index: int in range(1000):
		var repeat_status := SimStatus.new()
		var repeat_state: BattleState = P1GrayboxFixture.create(1, 2, false, repeat_status)
		var repeat_report: EffectResolutionReport = EffectResolver.resolve_transition(repeat_state, damage_registry, [turn_record], catalog.fingerprint_bytes(), repeat_status)
		var repeat_bytes: PackedByteArray = BattleSnapshot.capture(repeat_state, repeat_status).encode(repeat_status)
		if repeat_index == 0: repeat_expected = repeat_bytes
		elif repeat_bytes != repeat_expected: repeat_ok = false
		if not repeat_status.is_ok() or not repeat_report.is_initialized(): repeat_ok = false; break
	var repeat_restore_status := SimStatus.new()
	var repeat_restored: BattleState = BattleSnapshot.decode(repeat_expected, repeat_restore_status).restore_state(repeat_restore_status)
	var repeat_reencoded: PackedByteArray = BattleSnapshot.capture(repeat_restored, repeat_restore_status).encode(repeat_restore_status)
	_check("P2-2-E11-REPEAT-1000-SNAPSHOT-001", repeat_ok and repeat_restore_status.is_ok() and repeat_expected == repeat_reencoded)
	if _failures == 0: print("P2_EFFECT_RESOLUTION_RESULT: PASS"); quit(0)
	else: print("P2_EFFECT_RESOLUTION_RESULT: FAIL (%d)" % _failures); quit(1)
