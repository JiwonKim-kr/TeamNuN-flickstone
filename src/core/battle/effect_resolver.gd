class_name EffectResolver
extends RefCounted

static func _record_less(left: BattleTriggerRecord, right: BattleTriggerRecord) -> bool:
	return left.wave() < right.wave() or (left.wave() == right.wave() and left.sequence() < right.sequence())

static func _append_damage_records(records: Array[BattleTriggerRecord], next_sequence: Array[int], owner_id: int, target_id: int, source: BattleTriggerRecord, applied_damage: int, status: SimStatus) -> void:
	if applied_damage <= 0 or not status.is_ok(): return
	var wave: int = source.wave() + 1
	if wave >= BattleLimits.TRIGGER_MAX_WAVES or records.size() + 2 > BattleLimits.TRIGGER_MAX_RECORDS or next_sequence[0] > UInt32Math.U32_MAX - 1:
		status.fail(SimStatus.Code.EFFECT_LIMIT_EXCEEDED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, wave, records.size() + 2); return
	var position: FixVec2 = source.position(); var vector: FixVec2 = source.vector()
	var deal: BattleTriggerRecord = BattleTriggerRecord.create(next_sequence[0], wave, BattleTriggerId.Value.ON_HIT_DEAL, source.phase(), source.tick(), 0, owner_id, target_id, 0, SimEvent.CauseId.NONE, position, vector, applied_damage, applied_damage, 0, status)
	if not status.is_ok(): return
	next_sequence[0] += 1
	var take: BattleTriggerRecord = BattleTriggerRecord.create(next_sequence[0], wave, BattleTriggerId.Value.ON_HIT_TAKE, source.phase(), source.tick(), 0, target_id, owner_id, 0, SimEvent.CauseId.NONE, position, vector.negated(status), applied_damage, applied_damage, 0, status)
	if not status.is_ok(): return
	next_sequence[0] += 1; records.append(deal); records.append(take)

static func _apply(state: BattleState, owner_id: int, target_id: int, record: BattleTriggerRecord, effect: AbilityEffectDefinition, application_ordinal: int, status_change: Array[int], status: SimStatus) -> bool:
	var combatant: BattleCombatant
	var body: SimBody
	var world: SimWorld
	match effect.kind_id():
		AbilityEffectDefinition.Kind.DAMAGE:
			combatant = state.combatant_by_body_id(target_id, status)
			if not status.is_ok(): return false
			var hp: int = 0 if effect.value_a() >= combatant.current_hp() else combatant.current_hp() - effect.value_a()
			return state._effect_set_hp(target_id, hp, owner_id, status)
		AbilityEffectDefinition.Kind.HEAL:
			combatant = state.combatant_by_body_id(target_id, status)
			if not status.is_ok() or combatant.current_hp() == 0: status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.EFFECT_APPLY, target_id, effect.kind_id()); return false
			if not FixMath.can_add_int(combatant.current_hp(), effect.value_a()): status.fail(SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.EFFECT_APPLY, combatant.current_hp(), effect.value_a()); return false
			return state._effect_set_hp(target_id, mini(combatant.max_hp(), combatant.current_hp() + effect.value_a()), owner_id, status)
		AbilityEffectDefinition.Kind.MODIFY_CT:
			var participant: BattleParticipant = state.participant_by_body_id(target_id, status)
			if not status.is_ok() or not FixMath.can_add_int(participant.ct(), effect.value_a()): status.fail(SimStatus.Code.EFFECT_APPLICATION_FAILED, SimStatus.Operation.EFFECT_APPLY, target_id, effect.kind_id()); return false
			return state._effect_set_ct(target_id, participant.ct() + effect.value_a(), status)
		AbilityEffectDefinition.Kind.MODIFY_VELOCITY:
			world = state.world_copy(status); body = world.body_by_id(target_id, status)
			if not status.is_ok(): return false
			return state._effect_set_velocity(target_id, body.velocity().add(FixVec2.from_raw(effect.value_a(), effect.value_b()), status), status)
		AbilityEffectDefinition.Kind.KNOCKBACK, AbilityEffectDefinition.Kind.PULL:
			world = state.world_copy(status); var owner: SimBody = world.body_by_id(owner_id, status); body = world.body_by_id(target_id, status)
			if not status.is_ok(): return false
			var direction: FixVec2 = body.position().sub(owner.position(), status)
			if direction.is_zero(): direction = record.vector()
			if effect.kind_id() == AbilityEffectDefinition.Kind.PULL: direction = direction.negated(status)
			var delta: FixVec2 = direction.normalized(status).scaled(effect.value_a(), status)
			return state._effect_set_velocity(target_id, body.velocity().add(delta, status), status)
		AbilityEffectDefinition.Kind.APPLY_STATUS:
			status_change[0] = state._effect_apply_status_change(target_id, owner_id, effect.value_a(), effect.value_b(), status)
			return status.is_ok() and status_change[0] > 0
		AbilityEffectDefinition.Kind.REMOVE_STATUS:
			if state._effect_remove_status(target_id, effect.value_a(), effect.value_b(), status) > 0: status_change[0] = 3
			return status.is_ok()
		AbilityEffectDefinition.Kind.MODIFY_STAT:
			return state._effect_modify_stat(target_id, effect.value_a(), effect.value_b(), status)
		AbilityEffectDefinition.Kind.SPAWN_PIECE, AbilityEffectDefinition.Kind.SPAWN_PROJECTILE:
			return state._effect_dynamic_spawn(owner_id, target_id, record, effect, application_ordinal, status)
		AbilityEffectDefinition.Kind.TRANSFORM_PIECE:
			return state._effect_transform(target_id, effect, status)
		AbilityEffectDefinition.Kind.ATTACH:
			return state._effect_attach(owner_id, target_id, record, effect, status)
		AbilityEffectDefinition.Kind.SPAWN_ZONE:
			return state._effect_spawn_zone(owner_id, target_id, effect, application_ordinal, status)
	status.fail(SimStatus.Code.INVALID_EFFECT_DEFINITION, SimStatus.Operation.EFFECT_APPLY, target_id, effect.kind_id()); return false

static func resolve_transition(state: BattleState, registry: AbilityRegistry, records: Array[BattleTriggerRecord], content_fingerprint: PackedByteArray, status: SimStatus) -> EffectResolutionReport:
	if not status.is_ok(): return EffectResolutionReport.new()
	if state == null or not state.is_initialized() or registry == null or not registry.is_initialized() or content_fingerprint.size() != 32:
		status.fail(SimStatus.Code.INVALID_EFFECT_DEFINITION, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION); return EffectResolutionReport.new()
	if registry.fingerprint_bytes() != content_fingerprint:
		status.fail(SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION); return EffectResolutionReport.new()
	var state_has_content: bool = state.content_fingerprint_bytes().size() == 32
	if state_has_content and not state.ability_registry_matches(registry, status):
		status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION); return EffectResolutionReport.new()
	if records.size() > BattleLimits.TRIGGER_MAX_RECORDS:
		status.fail(SimStatus.Code.EFFECT_LIMIT_EXCEEDED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, records.size(), BattleLimits.TRIGGER_MAX_RECORDS); return EffectResolutionReport.new()
	var local: BattleState = state.copy(status); local._dynamic_begin_transition(); var invocations: int = 0; var applications: Array[EffectApplication] = []; var status_applications: int = 0; var status_updates: int = 0; var status_removals: int = 0; var status_changes: int = 0
	var queue: Array[BattleTriggerRecord] = []; var generated: Array[BattleTriggerRecord] = []
	for input_record: BattleTriggerRecord in records:
		if input_record == null or not input_record.is_initialized(): status.fail(SimStatus.Code.INVALID_TRIGGER_RECORD, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION); return EffectResolutionReport.new()
		queue.append(input_record.copy())
	queue.sort_custom(_record_less)
	var next_trigger_value: int = local.next_trigger_sequence()
	for input_record: BattleTriggerRecord in queue:
		if input_record.sequence() >= next_trigger_value:
			if input_record.sequence() == UInt32Math.U32_MAX: status.fail(SimStatus.Code.COUNTER_EXHAUSTED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, input_record.sequence(), 0); return EffectResolutionReport.new()
			next_trigger_value = input_record.sequence() + 1
	var next_trigger_sequence: Array[int] = [next_trigger_value]; var queue_index: int = 0
	while queue_index < queue.size():
		var record: BattleTriggerRecord = queue[queue_index]; queue_index += 1
		if record == null or not record.is_initialized(): status.fail(SimStatus.Code.INVALID_TRIGGER_RECORD, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION); break
		for binding_index: int in range(registry.binding_count()):
			var binding: AbilityBinding = registry.binding_at(binding_index, status)
			var abilities: Array[AbilityDefinition] = registry.abilities_for_trigger(binding.owner_body_id(), record.trigger_id(), status)
			for ability: AbilityDefinition in abilities:
				if ability.numeric_id() != binding.ability_numeric_id(): continue
				invocations += 1
				if invocations > BattleLimits.EFFECT_MAX_INVOCATIONS: status.fail(SimStatus.Code.EFFECT_LIMIT_EXCEEDED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, invocations, BattleLimits.EFFECT_MAX_INVOCATIONS); break
				var matched: bool = true
				var content_status := ContentStatus.new()
				for condition_index: int in range(ability.condition_count()):
					if not AbilityConditionEvaluator.matches(local, binding.owner_body_id(), record, ability.condition_at(condition_index, content_status), status): matched = false; break
				if not status.is_ok(): break
				if not matched: continue
				for effect_index: int in range(ability.effect_count()):
					var effect: AbilityEffectDefinition = ability.effect_at(effect_index, content_status)
					var targets: Array[int] = AbilityTargetSelector.select(local, binding.owner_body_id(), record, effect.selector(), status)
					for target_id: int in targets:
						if applications.size() >= BattleLimits.EFFECT_MAX_APPLICATIONS: status.fail(SimStatus.Code.EFFECT_LIMIT_EXCEEDED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, applications.size() + 1, BattleLimits.EFFECT_MAX_APPLICATIONS); break
						var hp_before: int = -1
						if effect.kind_id() == AbilityEffectDefinition.Kind.DAMAGE:
							hp_before = local.combatant_by_body_id(target_id, status).current_hp()
						var status_change: Array[int] = [0]
						if not status.is_ok() or not _apply(local, binding.owner_body_id(), target_id, record, effect, applications.size(), status_change, status): break
						if status_change[0] == 1: status_applications += 1; status_changes += 1
						elif status_change[0] == 2: status_updates += 1; status_changes += 1
						elif status_change[0] == 3: status_removals += 1; status_changes += 1
						if status_changes > BattleLimits.STATUS_MAX_CHANGES_PER_TRANSITION: status.fail(SimStatus.Code.STATUS_LIMIT_EXCEEDED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, status_changes, BattleLimits.STATUS_MAX_CHANGES_PER_TRANSITION); break
						applications.append(EffectApplication.create(binding.owner_body_id(), ability.numeric_id(), effect_index, target_id, effect.kind_id()))
						if hp_before >= 0:
							var hp_after: int = 0
							var lookup_status := SimStatus.new(); var remaining: BattleCombatant = local.combatant_by_body_id(target_id, lookup_status)
							if lookup_status.is_ok(): hp_after = remaining.current_hp()
							var new_records: Array[BattleTriggerRecord] = []
							_append_damage_records(new_records, next_trigger_sequence, binding.owner_body_id(), target_id, record, hp_before - hp_after, status)
							for generated_record: BattleTriggerRecord in new_records: generated.append(generated_record.copy()); queue.append(generated_record)
							queue.sort_custom(_record_less)
					if not status.is_ok(): break
			if not status.is_ok(): break
		if not status.is_ok(): break
	if not status.is_ok(): return EffectResolutionReport.new()
	var expired_bodies: Dictionary = {}
	for record: BattleTriggerRecord in queue:
		if record.trigger_id() == BattleTriggerId.Value.ON_TURN_END and record.phase() == BattleState.Phase.TURN_END and record.subject_body_id() > 0 and not expired_bodies.has(record.subject_body_id()):
			var expiration_changes: Array[int] = local._status_expire_turn_end(record.subject_body_id(), status)
			status_updates += expiration_changes[0]; status_removals += expiration_changes[1]
			status_changes += expiration_changes[0] + expiration_changes[1]; expired_bodies[record.subject_body_id()] = true
			if status_changes > BattleLimits.STATUS_MAX_CHANGES_PER_TRANSITION: status.fail(SimStatus.Code.STATUS_LIMIT_EXCEEDED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, status_changes, BattleLimits.STATUS_MAX_CHANGES_PER_TRANSITION); break
	if not status.is_ok(): return EffectResolutionReport.new()
	var has_turn_end: bool = false
	for record: BattleTriggerRecord in queue:
		if record.trigger_id() == BattleTriggerId.Value.ON_TURN_END and record.phase() == BattleState.Phase.TURN_END: has_turn_end = true; break
	if not local._dynamic_finish_transition(has_turn_end, status): return EffectResolutionReport.new()
	var binding_copies: Array[AbilityBinding] = []
	if state_has_content:
		for binding_index: int in range(local.ability_binding_count()): binding_copies.append(local.ability_binding_at(binding_index, status))
	else:
		for binding_index: int in range(registry.binding_count()): binding_copies.append(registry.binding_at(binding_index, status))
	if applications.size() > UInt32Math.U32_MAX - local.next_effect_sequence():
		status.fail(SimStatus.Code.COUNTER_EXHAUSTED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, local.next_effect_sequence(), applications.size()); return EffectResolutionReport.new()
	local._effect_restore_content(content_fingerprint, binding_copies, local.next_effect_sequence() + applications.size(), status)
	generated.sort_custom(_record_less)
	local._effect_restore_triggers(generated, next_trigger_sequence[0], status)
	state._effect_commit_from(local, status)
	return EffectResolutionReport.create(invocations, applications, generated, status_applications, status_updates, status_removals) if status.is_ok() else EffectResolutionReport.new()
