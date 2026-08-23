class_name AbilityTargetSelector
extends RefCounted

static func _single(record: BattleTriggerRecord, owner_body_id: int, kind_id: int) -> int:
	match kind_id:
		AbilitySelectorDefinition.Kind.OWNER: return owner_body_id
		AbilitySelectorDefinition.Kind.SUBJECT: return record.subject_body_id()
		AbilitySelectorDefinition.Kind.OTHER: return record.other_body_id()
		AbilitySelectorDefinition.Kind.INSTIGATOR: return record.instigator_body_id()
	return 0

static func select(state: BattleState, owner_body_id: int, record: BattleTriggerRecord, selector: AbilitySelectorDefinition, status: SimStatus) -> Array[int]:
	var result: Array[int] = []
	if not status.is_ok(): return result
	if state == null or not state.is_initialized() or record == null or not record.is_initialized() or selector == null or not selector.is_initialized():
		status.fail(SimStatus.Code.INVALID_EFFECT_DEFINITION, SimStatus.Operation.ABILITY_TARGET_SELECT, owner_body_id, 0); return result
	if selector.kind_id() <= AbilitySelectorDefinition.Kind.INSTIGATOR:
		var single: int = _single(record, owner_body_id, selector.kind_id())
		if single == 0: return result
		var lookup := SimStatus.new(); state.combatant_by_body_id(single, lookup)
		if not lookup.is_ok(): status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.ABILITY_TARGET_SELECT, single, selector.kind_id()); return []
		return [single]
	var owner_status := SimStatus.new(); var owner: BattleParticipant = state.participant_by_body_id(owner_body_id, owner_status)
	var world: SimWorld = state.world_copy(owner_status); var owner_body: SimBody = world.body_by_id(owner_body_id, owner_status)
	if not owner_status.is_ok(): status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.ABILITY_TARGET_SELECT, owner_body_id, selector.kind_id()); return result
	var nearest_id: int = 0; var nearest_distance: int = 0
	for index: int in range(state.participant_count()):
		var candidate: BattleParticipant = state.participant_at(index, status)
		if candidate.faction() == BattleParticipant.Faction.NEUTRAL: continue
		var ally: bool = candidate.faction() == owner.faction()
		var wants_ally: bool = selector.kind_id() == AbilitySelectorDefinition.Kind.ALL_ALLIES or selector.kind_id() == AbilitySelectorDefinition.Kind.NEAREST_ALLY
		if ally != wants_ally or (selector.kind_id() == AbilitySelectorDefinition.Kind.NEAREST_ALLY and candidate.body_id() == owner_body_id): continue
		var body: SimBody = world.body_by_id(candidate.body_id(), status)
		state.combatant_by_body_id(candidate.body_id(), status)
		if not status.is_ok(): return []
		if selector.kind_id() == AbilitySelectorDefinition.Kind.ALL_ALLIES or selector.kind_id() == AbilitySelectorDefinition.Kind.ALL_ENEMIES:
			result.append(candidate.body_id())
		else:
			var delta: FixVec2 = body.position().sub(owner_body.position(), status); var distance: int = delta.length_squared_raw(status)
			if nearest_id == 0 or distance < nearest_distance or (distance == nearest_distance and candidate.body_id() < nearest_id): nearest_id = candidate.body_id(); nearest_distance = distance
	if nearest_id != 0: result.append(nearest_id)
	result.sort()
	var limit: int = selector.limit()
	if limit > 0 and result.size() > limit: result.resize(limit)
	if result.size() > ContentLimits.SELECTOR_MAX_RESULTS: status.fail(SimStatus.Code.EFFECT_LIMIT_EXCEEDED, SimStatus.Operation.ABILITY_TARGET_SELECT, result.size(), ContentLimits.SELECTOR_MAX_RESULTS); return []
	return result
