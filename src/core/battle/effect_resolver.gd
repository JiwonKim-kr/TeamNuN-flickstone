class_name EffectResolver
extends RefCounted

static func _apply(state: BattleState, owner_id: int, target_id: int, record: BattleTriggerRecord, effect: AbilityEffectDefinition, status: SimStatus) -> bool:
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
	status.fail(SimStatus.Code.INVALID_EFFECT_DEFINITION, SimStatus.Operation.EFFECT_APPLY, target_id, effect.kind_id()); return false

static func resolve_transition(state: BattleState, registry: AbilityRegistry, records: Array[BattleTriggerRecord], content_fingerprint: PackedByteArray, status: SimStatus) -> EffectResolutionReport:
	if not status.is_ok(): return EffectResolutionReport.new()
	if state == null or not state.is_initialized() or registry == null or not registry.is_initialized() or content_fingerprint.size() != 32:
		status.fail(SimStatus.Code.INVALID_EFFECT_DEFINITION, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION); return EffectResolutionReport.new()
	if registry.fingerprint_bytes() != content_fingerprint:
		status.fail(SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION); return EffectResolutionReport.new()
	var local: BattleState = state.copy(status); var invocations: int = 0; var applications: Array[EffectApplication] = []
	for record: BattleTriggerRecord in records:
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
						if not _apply(local, binding.owner_body_id(), target_id, record, effect, status): break
						applications.append(EffectApplication.create(binding.owner_body_id(), ability.numeric_id(), effect_index, target_id, effect.kind_id()))
					if not status.is_ok(): break
			if not status.is_ok(): break
		if not status.is_ok(): break
	if not status.is_ok(): return EffectResolutionReport.new()
	var binding_copies: Array[AbilityBinding] = []
	for binding_index: int in range(registry.binding_count()): binding_copies.append(registry.binding_at(binding_index, status))
	local._effect_restore_content(content_fingerprint, binding_copies, applications.size() + 1, status)
	state._effect_commit_from(local, status)
	return EffectResolutionReport.create(invocations, applications) if status.is_ok() else EffectResolutionReport.new()
