extends SceneTree

const DATA_DB_SCRIPT: Script = preload("res://src/core/autoload/data_db.gd")
var _failures: int = 0

func _check(label: String, condition: bool) -> void:
	if condition: print("[PASS] %s" % label)
	else: _failures += 1; print("[FAIL] %s" % label)

func _init() -> void:
	var db: Node = DATA_DB_SCRIPT.new(); root.add_child(db)
	var content_status := ContentStatus.new()
	var loaded: bool = bool(db.call("reload_catalog", "res://pipeline/tests/fixtures/p2_effect_resolution", content_status))
	var catalog: ContentCatalog = db.call("catalog_copy", content_status) as ContentCatalog
	_check("P2-2-E02-SCHEMA-V2-001", loaded and content_status.is_ok() and catalog.ability_count() == 6)
	var status := SimStatus.new()
	var state: BattleState = P1GrayboxFixture.create(1, 2, false, status)
	var bindings: Array[AbilityBinding] = []
	for ability_id: int in range(1, 7): bindings.append(AbilityBinding.create(1, ability_id, status))
	var registry: AbilityRegistry = AbilityRegistry.bind(catalog, bindings, status)
	var record: BattleTriggerRecord = BattleTriggerRecord.create(1, 0, BattleTriggerId.Value.ON_HIT_DEAL, BattleState.Phase.RESOLVE, 0, 0, 1, 4, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.from_ints(1, 0, status), 0, 0, 0, status)
	var before: BattleCombatant = state.combatant_by_body_id(4, status)
	var report: EffectResolutionReport = EffectResolver.resolve_transition(state, registry, [record], catalog.fingerprint_bytes(), status)
	var after: BattleCombatant = state.combatant_by_body_id(4, status)
	var after_participant: BattleParticipant = state.participant_by_body_id(4, status)
	var after_body: SimBody = state.world_copy(status).body_by_id(4, status)
	_check("P2-2-E03-E04-BIND-CONDITION-SELECT-001", registry.is_initialized() and registry.binding_count() == 6)
	_check("P2-2-E05-SIX-EFFECTS-ATOMIC-001", status.is_ok() and report.is_initialized() and report.invocation_count() == 6 and report.application_count() == 6 and before.current_hp() == 100 and after.current_hp() == 95 and after_participant.ct() == 100 and after_body.velocity().x_raw() == 100 and after_body.velocity().y_raw() == 0)
	var snapshot_bytes: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var restored: BattleState = BattleSnapshot.decode(snapshot_bytes, status).restore_state(status)
	var reencoded: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	_check("P2-2-E11-SNAPSHOT-V4-001", status.is_ok() and snapshot_bytes == reencoded and restored.content_fingerprint_bytes() == catalog.fingerprint_bytes() and restored.ability_binding_count() == 6 and restored.next_effect_sequence() == 7)
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
	if _failures == 0: print("P2_EFFECT_RESOLUTION_RESULT: PASS"); quit(0)
	else: print("P2_EFFECT_RESOLUTION_RESULT: FAIL (%d)" % _failures); quit(1)
