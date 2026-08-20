class_name CtbScheduler
extends RefCounted

class Selection:
	var participants: Array[BattleParticipant] = []
	var actor_index: int = -1
	var abstract_time: int = 0


static func _copy_participants(source: Array[BattleParticipant]) -> Array[BattleParticipant]:
	var result: Array[BattleParticipant] = []
	for item: BattleParticipant in source:
		result.append(item.copy())
	return result


static func _preferred(left: BattleParticipant, right: BattleParticipant, last_faction: int) -> bool:
	var left_over: int = left.ct() - BattleLimits.CT_THRESHOLD
	var right_over: int = right.ct() - BattleLimits.CT_THRESHOLD
	if left_over != right_over: return left_over > right_over
	if left.speed_stat() != right.speed_stat(): return left.speed_stat() > right.speed_stat()
	var opposite: int = BattleParticipant.Faction.INVALID
	if last_faction == BattleParticipant.Faction.PLAYER: opposite = BattleParticipant.Faction.ENEMY
	elif last_faction == BattleParticipant.Faction.ENEMY: opposite = BattleParticipant.Faction.PLAYER
	if left.faction() != right.faction() and opposite != BattleParticipant.Faction.INVALID:
		if left.faction() == opposite: return true
		if right.faction() == opposite: return false
	return left.body_id() < right.body_id()


static func select_next(
		participants: Array[BattleParticipant], abstract_time: int, last_faction: int, status: SimStatus
) -> Selection:
	var result := Selection.new()
	if not status.is_ok(): return result
	result.participants = _copy_participants(participants)
	result.abstract_time = abstract_time
	var delta: int = FixMath.INT64_MAX
	var eligible: int = 0
	for item: BattleParticipant in result.participants:
		if not item.has_turn(): continue
		eligible += 1
		if item.ct() >= BattleLimits.CT_THRESHOLD:
			delta = 0
			break
		var ticks: int = FixMath.ceil_div_int(BattleLimits.CT_THRESHOLD - item.ct(), item.speed_stat(), status)
		if not status.is_ok(): return Selection.new()
		delta = mini(delta, ticks)
	if eligible == 0:
		status.fail(SimStatus.Code.NO_ELIGIBLE_ACTOR, SimStatus.Operation.CTB_SELECT, 0, 0)
		return Selection.new()
	if delta > 0:
		if not FixMath.can_add_int(abstract_time, delta):
			status.fail(SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.CTB_SELECT, abstract_time, delta)
			return Selection.new()
		var advanced: Array[BattleParticipant] = []
		for item: BattleParticipant in result.participants:
			if item.has_turn():
				var gain: int = FixMath.multiply_int(item.speed_stat(), delta, status)
				var next_ct: int = FixMath.add_raw(item.ct(), gain, status)
				advanced.append(item.with_ct(next_ct, status))
			else: advanced.append(item.copy())
			if not status.is_ok(): return Selection.new()
		result.participants = advanced
		result.abstract_time += delta
	for index: int in range(result.participants.size()):
		var candidate: BattleParticipant = result.participants[index]
		if not candidate.has_turn() or candidate.ct() < BattleLimits.CT_THRESHOLD: continue
		if result.actor_index < 0 or _preferred(candidate, result.participants[result.actor_index], last_faction):
			result.actor_index = index
	if result.actor_index < 0:
		status.fail(SimStatus.Code.NO_ELIGIBLE_ACTOR, SimStatus.Operation.CTB_SELECT, 0, 0)
	return result


static func preview(
		participants: Array[BattleParticipant], abstract_time: int, last_faction: int, count: int, status: SimStatus
) -> Array[CtbPreviewEntry]:
	var entries: Array[CtbPreviewEntry] = []
	if count < 1 or count > BattleLimits.PREVIEW_MAX_COUNT:
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.CTB_PREVIEW, count, BattleLimits.PREVIEW_MAX_COUNT)
		return entries
	var local: Array[BattleParticipant] = _copy_participants(participants)
	var local_time: int = abstract_time
	var local_last: int = last_faction
	for order: int in range(count):
		var selection: Selection = select_next(local, local_time, local_last, status)
		if not status.is_ok(): return []
		var actor: BattleParticipant = selection.participants[selection.actor_index]
		var group: int = 0 if entries.is_empty() else entries[-1].simultaneous_group() + (0 if entries[-1].ready_at_abstract_time() == selection.abstract_time else 1)
		entries.append(CtbPreviewEntry.create(order, actor, selection.abstract_time, group))
		selection.participants[selection.actor_index] = actor.with_ct(actor.ct() - BattleLimits.CT_THRESHOLD, status)
		local = selection.participants
		local_time = selection.abstract_time
		local_last = actor.faction()
	for index: int in range(entries.size()):
		var same_before: bool = index > 0 and entries[index - 1].simultaneous_group() == entries[index].simultaneous_group()
		var same_after: bool = index + 1 < entries.size() and entries[index + 1].simultaneous_group() == entries[index].simultaneous_group()
		if same_before or same_after: entries[index].mark_simultaneous()
	return entries
