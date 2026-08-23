class_name AbilityConditionEvaluator
extends RefCounted

static func _relation(owner_body_id: int, record: BattleTriggerRecord, relation_id: int) -> int:
	match relation_id:
		AbilityConditionDefinition.Relation.OWNER: return owner_body_id
		AbilityConditionDefinition.Relation.SUBJECT: return record.subject_body_id()
		AbilityConditionDefinition.Relation.OTHER: return record.other_body_id()
		AbilityConditionDefinition.Relation.INSTIGATOR: return record.instigator_body_id()
	return 0

static func matches(state: BattleState, owner_body_id: int, record: BattleTriggerRecord, condition: AbilityConditionDefinition, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if state == null or not state.is_initialized() or record == null or not record.is_initialized() or condition == null or not condition.is_initialized():
		status.fail(SimStatus.Code.INVALID_EFFECT_DEFINITION, SimStatus.Operation.ABILITY_CONDITION_EVALUATE, owner_body_id, 0); return false
	if condition.kind_id() == AbilityConditionDefinition.Kind.ALWAYS: return true
	var body_id: int = _relation(owner_body_id, record, condition.relation_id())
	if condition.kind_id() == AbilityConditionDefinition.Kind.RELATION_EXISTS:
		if body_id == 0: return false
		var exists_status := SimStatus.new()
		state.participant_by_body_id(body_id, exists_status); state.combatant_by_body_id(body_id, exists_status); state.world_copy(exists_status).body_by_id(body_id, exists_status)
		return exists_status.is_ok()
	if body_id == 0: status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.ABILITY_CONDITION_EVALUATE, owner_body_id, condition.relation_id()); return false
	var lookup := SimStatus.new(); var participant: BattleParticipant = state.participant_by_body_id(body_id, lookup)
	if condition.kind_id() == AbilityConditionDefinition.Kind.RELATION_ALIVE: return lookup.is_ok()
	if not lookup.is_ok(): status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.ABILITY_CONDITION_EVALUATE, body_id, condition.kind_id()); return false
	var owner_status := SimStatus.new(); var owner: BattleParticipant = state.participant_by_body_id(owner_body_id, owner_status)
	if not owner_status.is_ok(): status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.ABILITY_CONDITION_EVALUATE, owner_body_id, condition.kind_id()); return false
	if condition.kind_id() == AbilityConditionDefinition.Kind.RELATION_IS_ALLY: return owner.faction() != BattleParticipant.Faction.NEUTRAL and participant.faction() == owner.faction()
	if condition.kind_id() == AbilityConditionDefinition.Kind.RELATION_IS_ENEMY: return owner.faction() != BattleParticipant.Faction.NEUTRAL and participant.faction() != BattleParticipant.Faction.NEUTRAL and participant.faction() != owner.faction()
	var combat_status := SimStatus.new(); var combatant: BattleCombatant = state.combatant_by_body_id(body_id, combat_status)
	if not combat_status.is_ok() or not FixMath.can_mul_int(combatant.current_hp(), 10000) or not FixMath.can_mul_int(combatant.max_hp(), condition.value_a()):
		status.fail(SimStatus.Code.EFFECT_APPLICATION_FAILED, SimStatus.Operation.ABILITY_CONDITION_EVALUATE, body_id, condition.kind_id()); return false
	var left: int = combatant.current_hp() * 10000; var right: int = combatant.max_hp() * condition.value_a()
	return left <= right if condition.kind_id() == AbilityConditionDefinition.Kind.HP_AT_MOST_BASIS_POINTS else left >= right
