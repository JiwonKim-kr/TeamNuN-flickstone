class_name BattleState
extends RefCounted

enum Phase {
	INVALID = 0,
	BATTLE_START = 1,
	TURN_START = 2,
	AIM = 3,
	RESOLVE = 4,
	TURN_END = 5,
	CHECK = 6,
	BATTLE_END = 7,
}

enum CheckDirective { INVALID = 0, CONTINUE = 1, END = 2 }

var _initialized: bool = false
var _phase: int = Phase.INVALID
var _current_actor_body_id: int = 0
var _abstract_time: int = 0
var _last_acted_faction: int = BattleParticipant.Faction.INVALID
var _participants: Array[BattleParticipant] = []
var _combatants: Array[BattleCombatant] = []
var _cooldowns: Array[DamagePairCooldown] = []
var _world: SimWorld = SimWorld.new()
var _pending: Array[BattleMutationRequest] = []
var _normal_resolve_ticks: int = 0
var _forced_resolve_ticks: int = 0
var _forced_settle_used: bool = false
var _battle_result: int = BattleResult.Value.ONGOING
var _next_trigger_sequence: int = 1
var _last_trigger_batch: Array[BattleTriggerRecord] = []
var _motion_credits: Array[BattleMotionCredit] = []
var _content_fingerprint: PackedByteArray = PackedByteArray()
var _ability_bindings: Array[AbilityBinding] = []
var _next_effect_sequence: int = 1
var _trigger_bus: BattleTriggerBus = BattleTriggerBus.new()
var _turn_index: int = 0
var _content_catalog: ContentCatalog = ContentCatalog.new()
var _piece_identities: Array[BattlePieceIdentity] = []
var _synergy_tally: SynergyTally = SynergyTally.new()
var _statuses: StatusCollection = StatusCollection.new()
var _modifier_resolver: ModifierResolver = ModifierResolver.new()
var _base_body_stats: Array[BattleBaseBodyStats] = []
var _expire_states: Array[ExpireState] = []
var _piece_origins: Array[BattlePieceOrigin] = []
var _runtime_spawn_count: int = 0
var _dynamic_spawn_transition_count: int = 0
var _dynamic_transform_body_ids: Array[int] = []
var _zone_spawns: Array[ZoneSpawnState] = []
var _zone_spawn_transition_count: int = 0
var _kill_tallies: Array[BattleKillTally] = []


static func _participant_less(left: BattleParticipant, right: BattleParticipant) -> bool:
	return left.body_id() < right.body_id()


static func _combatant_less(left: BattleCombatant, right: BattleCombatant) -> bool:
	return left.body_id() < right.body_id()


static func _cooldown_less(
		left: DamagePairCooldown, right: DamagePairCooldown
) -> bool:
	if left.low_body_id() != right.low_body_id():
		return left.low_body_id() < right.low_body_id()
	return left.high_body_id() < right.high_body_id()


static func _request_less(left: BattleMutationRequest, right: BattleMutationRequest) -> bool:
	if left.tick != right.tick: return left.tick < right.tick
	if left.cause_body_id != right.cause_body_id: return left.cause_body_id < right.cause_body_id
	if left.event_type_id != right.event_type_id: return left.event_type_id < right.event_type_id
	return left.ordinal < right.ordinal


static func _copy_participants(source: Array[BattleParticipant]) -> Array[BattleParticipant]:
	var result: Array[BattleParticipant] = []
	for item: BattleParticipant in source: result.append(item.copy())
	return result


static func _copy_combatants(
		source: Array[BattleCombatant]
) -> Array[BattleCombatant]:
	var result: Array[BattleCombatant] = []
	for item: BattleCombatant in source:
		result.append(item.copy())
	return result


static func _copy_cooldowns(
		source: Array[DamagePairCooldown]
) -> Array[DamagePairCooldown]:
	var result: Array[DamagePairCooldown] = []
	for item: DamagePairCooldown in source:
		result.append(item.copy())
	return result


static func _copy_pending(source: Array[BattleMutationRequest]) -> Array[BattleMutationRequest]:
	var result: Array[BattleMutationRequest] = []
	for item: BattleMutationRequest in source: result.append(item.copy())
	return result


static func _copy_trigger_records(source: Array[BattleTriggerRecord]) -> Array[BattleTriggerRecord]:
	var result: Array[BattleTriggerRecord] = []
	for item: BattleTriggerRecord in source: result.append(item.copy())
	return result


static func _copy_motion_credits(source: Array[BattleMotionCredit]) -> Array[BattleMotionCredit]:
	var result: Array[BattleMotionCredit] = []
	for item: BattleMotionCredit in source: result.append(item.copy())
	return result


static func _create_internal(
		world: SimWorld,
		participants: Array[BattleParticipant],
		combatants: Array[BattleCombatant],
		status: SimStatus
) -> BattleState:
	var state := BattleState.new()
	if not status.is_ok(): return state
	if world == null or world.has_pending_requests() or world.event_cursor() != world.event_count():
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_CREATE, 0, 0)
		return state
	var sorted: Array[BattleParticipant] = _copy_participants(participants)
	sorted.sort_custom(_participant_less)
	var has_actor: bool = false
	for index: int in range(sorted.size()):
		var item: BattleParticipant = sorted[index]
		if not item.is_initialized() or (index > 0 and sorted[index - 1].body_id() == item.body_id()):
			status.fail(SimStatus.Code.DUPLICATE_ID, SimStatus.Operation.BATTLE_CREATE, item.body_id(), 0)
			return state
		var body_status := SimStatus.new()
		world.body_by_id(item.body_id(), body_status)
		if not body_status.is_ok():
			status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_CREATE, item.body_id(), 0)
			return state
		has_actor = has_actor or item.has_turn()
	if not has_actor:
		status.fail(SimStatus.Code.NO_ELIGIBLE_ACTOR, SimStatus.Operation.BATTLE_CREATE, 0, 0)
		return state
	var sorted_combatants: Array[BattleCombatant] = _copy_combatants(combatants)
	sorted_combatants.sort_custom(_combatant_less)
	for index: int in range(sorted_combatants.size()):
		var combatant: BattleCombatant = sorted_combatants[index]
		if (
			not combatant.is_initialized()
			or combatant.current_hp() <= 0
			or (
				index > 0
				and sorted_combatants[index - 1].body_id() == combatant.body_id()
			)
		):
			status.fail(
				SimStatus.Code.INVALID_COMBATANT,
				SimStatus.Operation.BATTLE_CREATE,
				combatant.body_id(),
				combatant.critical_basis_points()
			)
			return state
		var combatant_body_status := SimStatus.new()
		var combatant_body: SimBody = world.body_by_id(
			combatant.body_id(), combatant_body_status
		)
		if not combatant_body_status.is_ok() or not combatant_body.destructible():
			status.fail(
				SimStatus.Code.INVALID_COMBATANT,
				SimStatus.Operation.BATTLE_CREATE,
				combatant.body_id(),
				0
			)
			return state
		for participant: BattleParticipant in sorted:
			if (
				participant.body_id() == combatant.body_id()
				and participant.faction() != combatant.faction()
			):
				status.fail(
					SimStatus.Code.INVALID_COMBATANT,
					SimStatus.Operation.BATTLE_CREATE,
					combatant.body_id(),
					combatant.faction()
				)
				return state
	state._world = world.copy(status)
	if not status.is_ok(): return BattleState.new()
	state._participants = sorted
	state._combatants = sorted_combatants
	state._phase = Phase.BATTLE_START
	state._initialized = true
	return state


static func create(
		world: SimWorld,
		participants: Array[BattleParticipant],
		status: SimStatus
) -> BattleState:
	var combatants: Array[BattleCombatant] = []
	return _create_internal(world, participants, combatants, status)


static func create_with_combatants(
		world: SimWorld,
		participants: Array[BattleParticipant],
		combatants: Array[BattleCombatant],
		status: SimStatus
) -> BattleState:
	return _create_internal(world, participants, combatants, status)


static func restore(
		world: SimWorld,
		participants: Array[BattleParticipant],
		phase: int,
		current_actor: int,
		abstract_time: int,
		last_faction: int,
		normal_ticks: int,
		forced_ticks: int,
		forced_used: bool,
		status: SimStatus
) -> BattleState:
	var combatants: Array[BattleCombatant] = []
	var cooldowns: Array[DamagePairCooldown] = []
	return restore_with_combatants(
		world,
		participants,
		combatants,
		cooldowns,
		phase,
		current_actor,
		abstract_time,
		last_faction,
		normal_ticks,
		forced_ticks,
		forced_used,
		status
	)


static func restore_with_combatants(
		world: SimWorld,
		participants: Array[BattleParticipant],
		combatants: Array[BattleCombatant],
		cooldowns: Array[DamagePairCooldown],
		phase: int,
		current_actor: int,
		abstract_time: int,
		last_faction: int,
		normal_ticks: int,
		forced_ticks: int,
		forced_used: bool,
		status: SimStatus
) -> BattleState:
	var state := BattleState.new()
	if not status.is_ok() or world == null or abstract_time < 0:
		return state
	state._world = world.copy(status)
	state._participants = _copy_participants(participants)
	state._combatants = _copy_combatants(combatants)
	state._cooldowns = _copy_cooldowns(cooldowns)
	state._phase = phase
	state._current_actor_body_id = current_actor
	state._abstract_time = abstract_time
	state._last_acted_faction = last_faction
	state._normal_resolve_ticks = normal_ticks
	state._forced_resolve_ticks = forced_ticks
	state._forced_settle_used = forced_used
	if phase == Phase.BATTLE_END:
		state._battle_result = BattleResultResolver.resolve(state._participants)
		if state._battle_result == BattleResult.Value.ONGOING:
			status.fail(SimStatus.Code.INVALID_BATTLE_RESULT, SimStatus.Operation.BATTLE_RESULT_RESOLVE, phase, 0)
	state._initialized = status.is_ok()
	if not state._validate(status): return BattleState.new()
	return state


static func restore_v3(world: SimWorld, participants: Array[BattleParticipant], combatants: Array[BattleCombatant], cooldowns: Array[DamagePairCooldown], phase: int, current_actor: int, abstract_time: int, last_faction: int, normal_ticks: int, forced_ticks: int, forced_used: bool, result_value: int, next_sequence: int, records: Array[BattleTriggerRecord], credits: Array[BattleMotionCredit], status: SimStatus) -> BattleState:
	var state: BattleState = restore_with_combatants(world, participants, combatants, cooldowns, phase, current_actor, abstract_time, last_faction, normal_ticks, forced_ticks, forced_used, status)
	if not status.is_ok(): return BattleState.new()
	if not BattleResult.is_known(result_value) or next_sequence <= 0 or next_sequence > UInt32Math.U32_MAX or (phase == Phase.BATTLE_END) != BattleResult.is_terminal(result_value):
		status.fail(SimStatus.Code.INVALID_BATTLE_RESULT, SimStatus.Operation.BATTLE_RESULT_RESOLVE, phase, result_value); return BattleState.new()
	var previous_sequence: int = 0
	for record: BattleTriggerRecord in records:
		if record == null or not record.is_initialized() or record.sequence() <= previous_sequence or record.sequence() >= next_sequence:
			status.fail(SimStatus.Code.INVALID_TRIGGER_RECORD, SimStatus.Operation.BATTLE_TRIGGER_READ, previous_sequence, next_sequence); return BattleState.new()
		previous_sequence = record.sequence()
	var previous_body: int = 0
	for credit: BattleMotionCredit in credits:
		if credit == null or not credit.is_initialized() or credit.body_id() <= previous_body:
			status.fail(SimStatus.Code.INVALID_MOTION_CREDIT, SimStatus.Operation.BATTLE_MOTION_CREDIT, previous_body, 0); return BattleState.new()
		previous_body = credit.body_id()
	state._battle_result = result_value; state._next_trigger_sequence = next_sequence
	state._last_trigger_batch = _copy_trigger_records(records); state._motion_credits = _copy_motion_credits(credits)
	return state


func _validate(status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized or _phase < Phase.BATTLE_START or _phase > Phase.BATTLE_END:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, _phase, 0)
		return false
	if (_phase == Phase.BATTLE_START or _phase == Phase.BATTLE_END) and _current_actor_body_id != 0:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, _phase, _current_actor_body_id)
		return false
	if _phase >= Phase.TURN_START and _phase <= Phase.CHECK and _current_actor_body_id == 0:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, _phase, 0)
		return false
	if _last_acted_faction < BattleParticipant.Faction.INVALID or _last_acted_faction > BattleParticipant.Faction.NEUTRAL:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, _last_acted_faction, 0)
		return false
	if _normal_resolve_ticks < 0 or _normal_resolve_ticks > BattleLimits.NORMAL_RESOLVE_MAX_TICKS or _forced_resolve_ticks < 0 or _forced_resolve_ticks > BattleLimits.FORCED_RESOLVE_MAX_TICKS:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, _normal_resolve_ticks, _forced_resolve_ticks)
		return false
	if (_forced_resolve_ticks > 0 and not _forced_settle_used) or (_forced_settle_used and _normal_resolve_ticks != BattleLimits.NORMAL_RESOLVE_MAX_TICKS):
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, _normal_resolve_ticks, _forced_resolve_ticks)
		return false
	if _forced_settle_used and _forced_resolve_ticks == 0 and _phase != Phase.RESOLVE:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, _phase, 0)
		return false
	for index: int in range(_participants.size()):
		var item: BattleParticipant = _participants[index]
		if not item.is_initialized() or (index > 0 and _participants[index - 1].body_id() >= item.body_id()):
			status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_STATE_READ, item.body_id(), index)
			return false
		var lookup := SimStatus.new()
		_world.body_by_id(item.body_id(), lookup)
		if not lookup.is_ok():
			status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_STATE_READ, item.body_id(), 0)
			return false
	for index: int in range(_combatants.size()):
		var combatant: BattleCombatant = _combatants[index]
		if (
			not combatant.is_initialized()
			or combatant.current_hp() <= 0
			or (
				index > 0
				and _combatants[index - 1].body_id() >= combatant.body_id()
			)
		):
			status.fail(
				SimStatus.Code.INVALID_COMBATANT,
				SimStatus.Operation.BATTLE_STATE_READ,
				combatant.body_id(),
				combatant.current_hp()
			)
			return false
		var body_status := SimStatus.new()
		var combatant_body: SimBody = _world.body_by_id(
			combatant.body_id(), body_status
		)
		if not body_status.is_ok() or not combatant_body.destructible():
			status.fail(
				SimStatus.Code.INVALID_COMBATANT,
				SimStatus.Operation.BATTLE_STATE_READ,
				combatant.body_id(),
				0
			)
			return false
		var participant_index: int = _find_participant(combatant.body_id())
		if (
			participant_index >= 0
			and _participants[participant_index].faction() != combatant.faction()
		):
			status.fail(
				SimStatus.Code.INVALID_COMBATANT,
				SimStatus.Operation.BATTLE_STATE_READ,
				combatant.body_id(),
				combatant.faction()
			)
			return false
	for index: int in range(_cooldowns.size()):
		var cooldown: DamagePairCooldown = _cooldowns[index]
		if (
			not cooldown.is_initialized()
			or _find_combatant(cooldown.low_body_id()) < 0
			or _find_combatant(cooldown.high_body_id()) < 0
			or (
				index > 0
				and not _cooldown_less(_cooldowns[index - 1], cooldown)
			)
		):
			status.fail(
				SimStatus.Code.INVALID_BATTLE_STATE,
				SimStatus.Operation.BATTLE_COOLDOWN_UPDATE,
				cooldown.low_body_id(),
				cooldown.high_body_id()
			)
			return false
	if _phase == Phase.TURN_START or _phase == Phase.AIM:
		if _find_participant(_current_actor_body_id) < 0:
			status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_STATE_READ, _current_actor_body_id, 0)
			return false
	return true


func _require_phase(expected: int, operation: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not _initialized:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, operation, 0, 0)
		return false
	if _phase != expected:
		status.fail(SimStatus.Code.INVALID_PHASE, operation, _phase, expected)
		return false
	return true


func _find_participant(body_id: int) -> int:
	for index: int in range(_participants.size()):
		if _participants[index].body_id() == body_id: return index
	return -1


func _find_combatant(body_id: int) -> int:
	for index: int in range(_combatants.size()):
		if _combatants[index].body_id() == body_id:
			return index
		if _combatants[index].body_id() > body_id:
			break
	return -1


func _find_identity(body_id: int) -> int:
	for index: int in range(_piece_identities.size()):
		if _piece_identities[index].body_id() == body_id: return index
		if _piece_identities[index].body_id() > body_id: break
	return -1


func _find_base_body_stats(body_id: int) -> int:
	for index: int in range(_base_body_stats.size()):
		if _base_body_stats[index].body_id() == body_id: return index
		if _base_body_stats[index].body_id() > body_id: break
	return -1


func _find_expire_state(body_id: int) -> int:
	for index: int in range(_expire_states.size()):
		if _expire_states[index].body_id() == body_id: return index
		if _expire_states[index].body_id() > body_id: break
	return -1


func _remove_ability_bindings(body_id: int) -> void:
	var survivors: Array[AbilityBinding] = []
	for binding: AbilityBinding in _ability_bindings:
		if binding.owner_body_id() != body_id: survivors.append(binding)
	_ability_bindings = survivors


func _find_cooldown(low_body_id: int, high_body_id: int) -> int:
	for index: int in range(_cooldowns.size()):
		var item: DamagePairCooldown = _cooldowns[index]
		if item.low_body_id() == low_body_id and item.high_body_id() == high_body_id:
			return index
		if (
			item.low_body_id() > low_body_id
			or (
				item.low_body_id() == low_body_id
				and item.high_body_id() > high_body_id
			)
		):
			break
	return -1


func _find_motion_credit(body_id: int) -> int:
	for index: int in range(_motion_credits.size()):
		if _motion_credits[index].body_id() == body_id: return index
		if _motion_credits[index].body_id() > body_id: break
	return -1


func _participant_faction(body_id: int) -> int:
	var index: int = _find_participant(body_id)
	return BattleParticipant.Faction.INVALID if index < 0 else _participants[index].faction()


func _set_motion_credit(body_id: int, root_body_id: int, root_faction: int, source_sequence: int, tick: int, status: SimStatus) -> void:
	var item: BattleMotionCredit = BattleMotionCredit.create(body_id, root_body_id, root_faction, source_sequence, tick, status)
	if not status.is_ok(): return
	var index: int = _find_motion_credit(body_id)
	if index >= 0: _motion_credits[index] = item
	else:
		_motion_credits.append(item)
		_motion_credits.sort_custom(func(a: BattleMotionCredit, b: BattleMotionCredit) -> bool: return a.body_id() < b.body_id())


func _begin_trigger_transition() -> void:
	_trigger_bus = BattleTriggerBus.new()


func _emit_trigger(trigger_id: int, source_sequence: int, subject: int, other: int, instigator: int, cause_id: int, position: FixVec2, vector: FixVec2, value_a: int, value_b: int, status: SimStatus) -> void:
	if not status.is_ok(): return
	if _next_trigger_sequence > UInt32Math.U32_MAX:
		status.fail(SimStatus.Code.COUNTER_EXHAUSTED, SimStatus.Operation.TRIGGER_ENQUEUE, _next_trigger_sequence, 0); return
	var record: BattleTriggerRecord = BattleTriggerRecord.create(_next_trigger_sequence, 0, trigger_id, _phase, _world.tick(), source_sequence, subject, other, instigator, cause_id, position, vector, value_a, value_b, 0, status)
	if status.is_ok() and _trigger_bus.enqueue(record, status): _next_trigger_sequence += 1


func _finish_trigger_transition(status: SimStatus) -> bool:
	if not status.is_ok(): return false
	_last_trigger_batch = _trigger_bus.drain(status)
	return status.is_ok() and _trigger_bus.is_empty()


func _transfer_motion_credit(attacker_id: int, victim_id: int, source_sequence: int, tick: int, status: SimStatus) -> void:
	var root_id: int = attacker_id
	var root_faction: int = _participant_faction(attacker_id)
	var index: int = _find_motion_credit(attacker_id)
	if index >= 0:
		root_id = _motion_credits[index].root_body_id()
		root_faction = _motion_credits[index].root_faction()
	if root_faction != BattleParticipant.Faction.INVALID:
		_set_motion_credit(victim_id, root_id, root_faction, source_sequence, tick, status)


func _remove_body_state(body_id: int, status: SimStatus = null) -> void:
	var mutation_status: SimStatus = status if status != null else SimStatus.new()
	_statuses.remove_target(body_id)
	var participant_index: int = _find_participant(body_id)
	if participant_index >= 0:
		_participants.remove_at(participant_index)
	var combatant_index: int = _find_combatant(body_id)
	if combatant_index >= 0:
		_combatants.remove_at(combatant_index)
	var survivors: Array[DamagePairCooldown] = []
	for item: DamagePairCooldown in _cooldowns:
		if item.low_body_id() != body_id and item.high_body_id() != body_id:
			survivors.append(item)
	_cooldowns = survivors
	var credit_index: int = _find_motion_credit(body_id)
	if credit_index >= 0: _motion_credits.remove_at(credit_index)
	var identity_index: int = _find_identity(body_id)
	if identity_index >= 0: _piece_identities.remove_at(identity_index)
	var base_index: int = _find_base_body_stats(body_id)
	if base_index >= 0: _base_body_stats.remove_at(base_index)
	var expire_index: int = _find_expire_state(body_id)
	if expire_index >= 0: _expire_states.remove_at(expire_index)
	_remove_ability_bindings(body_id)
	if _content_catalog.is_initialized():
		_modifier_resolver = ModifierResolver.build(_content_catalog, _piece_identities, _synergy_tally, mutation_status)


func _effective_participants(status: SimStatus) -> Array[BattleParticipant]:
	var result: Array[BattleParticipant] = []
	for participant: BattleParticipant in _participants:
		if not _modifier_resolver.is_initialized(): result.append(participant.copy()); continue
		var aggregate: ModifierAggregate = _modifier_resolver.aggregate(participant.body_id(), ModifierKind.Value.SPEED_STAT, _statuses, status)
		var speed: int = EffectiveStats.resolve(participant.speed_stat(), aggregate, ModifierKind.Value.SPEED_STAT, status)
		result.append(participant.with_effective_speed_stat(speed, status))
		if not status.is_ok(): return []
	return result


static func _copy_zone_spawns(source: Array[ZoneSpawnState]) -> Array[ZoneSpawnState]:
	var result: Array[ZoneSpawnState] = []
	for item: ZoneSpawnState in source: result.append(item.copy())
	return result


static func _copy_expire_states(source: Array[ExpireState]) -> Array[ExpireState]:
	var result: Array[ExpireState] = []
	for item: ExpireState in source: result.append(item.copy())
	return result


static func _copy_piece_origins(source: Array[BattlePieceOrigin]) -> Array[BattlePieceOrigin]:
	var result: Array[BattlePieceOrigin] = []
	for item: BattlePieceOrigin in source: result.append(item.copy())
	return result


static func _copy_kill_tallies(source: Array[BattleKillTally]) -> Array[BattleKillTally]:
	var result: Array[BattleKillTally] = []
	for item: BattleKillTally in source: result.append(item.copy())
	return result


func _has_piece_origin(body_id: int) -> bool:
	for origin: BattlePieceOrigin in _piece_origins:
		if origin.body_id() == body_id: return true
		if origin.body_id() > body_id: break
	return false


func _increment_kill_tally(body_id: int, status: SimStatus) -> void:
	if not status.is_ok() or not _has_piece_origin(body_id): return
	for index: int in range(_kill_tallies.size()):
		var item: BattleKillTally = _kill_tallies[index]
		if item.body_id() == body_id:
			if item.kill_count() >= 0xFFFFFFFF:
				status.fail(SimStatus.Code.COUNTER_EXHAUSTED, SimStatus.Operation.BATTLE_KILL_TALLY_UPDATE, body_id, item.kill_count()); return
			_kill_tallies[index] = BattleKillTally.create(body_id, item.kill_count() + 1, status); return
		if item.body_id() > body_id:
			_kill_tallies.insert(index, BattleKillTally.create(body_id, 1, status)); return
	_kill_tallies.append(BattleKillTally.create(body_id, 1, status))


func _select_actor(status: SimStatus) -> bool:
	var effective: Array[BattleParticipant] = _effective_participants(status)
	var selection: CtbScheduler.Selection = CtbScheduler.select_next(effective, _abstract_time, _last_acted_faction, status)
	if not status.is_ok(): return false
	for index: int in range(_participants.size()): _participants[index] = _participants[index].with_ct(selection.participants[index].ct(), status)
	_abstract_time = selection.abstract_time
	_current_actor_body_id = selection.participants[selection.actor_index].body_id()
	_phase = Phase.TURN_START
	return true


func _same_non_neutral_faction(
		left: BattleCombatant, right: BattleCombatant
) -> bool:
	return (
		left.faction() != BattleParticipant.Faction.NEUTRAL
		and left.faction() == right.faction()
	)


func _resolve_damage_direction(
		attacker: BattleCombatant,
		victim: BattleCombatant,
		attacker_mass_raw: int,
		victim_mass_raw: int,
		impact_speed_raw: int,
		collision_sequence: int,
		status: SimStatus
) -> DamageResult:
	var attack: int = attacker.attack(); var critical_bp: int = attacker.critical_basis_points(); var outgoing_bp: int = 0; var incoming_bp: int = 0; var fixed_increase: int = 0; var fixed_reduction: int = 0
	if _modifier_resolver.is_initialized():
		attack = EffectiveStats.resolve(attacker.attack(), _modifier_resolver.aggregate(attacker.body_id(), ModifierKind.Value.ATTACK, _statuses, status), ModifierKind.Value.ATTACK, status)
		critical_bp = EffectiveStats.resolve(attacker.critical_basis_points(), _modifier_resolver.aggregate(attacker.body_id(), ModifierKind.Value.CRITICAL_BASIS_POINTS, _statuses, status), ModifierKind.Value.CRITICAL_BASIS_POINTS, status)
		outgoing_bp = EffectiveStats.resolve(0, _modifier_resolver.aggregate(attacker.body_id(), ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, _statuses, status), ModifierKind.Value.DAMAGE_OUTGOING_RATIO_BONUS, status)
		incoming_bp = EffectiveStats.resolve(0, _modifier_resolver.aggregate(victim.body_id(), ModifierKind.Value.DAMAGE_INCOMING_RATIO_REDUCTION, _statuses, status), ModifierKind.Value.DAMAGE_INCOMING_RATIO_REDUCTION, status)
		fixed_increase = EffectiveStats.resolve(0, _modifier_resolver.aggregate(attacker.body_id(), ModifierKind.Value.DAMAGE_FIXED_INCREASE, _statuses, status), ModifierKind.Value.DAMAGE_FIXED_INCREASE, status)
		fixed_reduction = EffectiveStats.resolve(0, _modifier_resolver.aggregate(victim.body_id(), ModifierKind.Value.DAMAGE_FIXED_REDUCTION, _statuses, status), ModifierKind.Value.DAMAGE_FIXED_REDUCTION, status)
		if not status.is_ok(): return DamageResult.new()
	var critical_applied: bool = BattleRandom.for_collision_critical(_world, attacker.body_id(), collision_sequence, status).chance(critical_bp, 10000, status)
	if not status.is_ok(): return DamageResult.new()
	var context: DamageContext = DamageContext.create(
		attacker.body_id(),
		victim.body_id(),
		attack,
		victim.current_hp(),
		attacker_mass_raw,
		victim_mass_raw,
		impact_speed_raw,
		_same_non_neutral_faction(attacker, victim),
		critical_applied,
		FixMath.from_ratio(outgoing_bp, 10000, status),
		FixMath.from_ratio(incoming_bp, 10000, status),
		fixed_increase,
		fixed_reduction,
		status
	)
	return DamageCalculator.resolve(context, status)


func _queue_pending_destroy(
		body_id: int,
		cause_body_id: int,
		body_ids: Array[int],
		cause_ids: Array[int]
) -> void:
	for index: int in range(body_ids.size()):
		if body_ids[index] == body_id:
			return
		if body_ids[index] > body_id:
			body_ids.insert(index, body_id)
			cause_ids.insert(index, cause_body_id)
			return
	body_ids.append(body_id)
	cause_ids.append(cause_body_id)


func _apply_damage_result(
		result: DamageResult,
		pending_body_ids: Array[int],
		pending_cause_ids: Array[int],
		status: SimStatus
) -> void:
	if not status.is_ok() or result == null or not result.is_initialized():
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_DAMAGE_CONTEXT,
				SimStatus.Operation.BATTLE_DAMAGE_EVENT,
				0,
				0
			)
		return
	if not result.has_damage():
		return
	var victim_index: int = _find_combatant(result.victim_body_id())
	if victim_index < 0:
		status.fail(
			SimStatus.Code.NOT_FOUND,
			SimStatus.Operation.BATTLE_DAMAGE_EVENT,
			result.victim_body_id(),
			0
		)
		return
	var victim: BattleCombatant = _combatants[victim_index]
	var next_hp: int = victim.current_hp() - result.applied_damage()
	_combatants[victim_index] = victim.with_current_hp(next_hp, status)
	if status.is_ok() and next_hp == 0:
		_queue_pending_destroy(
			result.victim_body_id(),
			result.attacker_body_id(),
			pending_body_ids,
			pending_cause_ids
		)


func _update_cooldown(
		low_body_id: int,
		high_body_id: int,
		event_tick: int,
		status: SimStatus
) -> void:
	if not FixMath.can_add_int(
		event_tick, DamageLimits.RECOLLISION_COOLDOWN_TICKS
	):
		status.fail(
			SimStatus.Code.COUNTER_EXHAUSTED,
			SimStatus.Operation.BATTLE_COOLDOWN_UPDATE,
			event_tick,
			DamageLimits.RECOLLISION_COOLDOWN_TICKS
		)
		return
	var item: DamagePairCooldown = DamagePairCooldown.create(
		low_body_id,
		high_body_id,
		event_tick + DamageLimits.RECOLLISION_COOLDOWN_TICKS,
		status
	)
	if not status.is_ok():
		return
	var index: int = _find_cooldown(low_body_id, high_body_id)
	if index >= 0:
		_cooldowns[index] = item
	else:
		_cooldowns.append(item)
		_cooldowns.sort_custom(_cooldown_less)


func _emit_damage_pair(result: DamageResult, event: SimEvent, normal: FixVec2, status: SimStatus) -> void:
	if not status.is_ok() or not result.has_damage(): return
	_emit_trigger(BattleTriggerId.Value.ON_HIT_DEAL, event.sequence(), result.attacker_body_id(), result.victim_body_id(), 0, SimEvent.CauseId.NONE, event.position(), normal, result.applied_damage(), result.resolved_damage(), status)
	_emit_trigger(BattleTriggerId.Value.ON_HIT_TAKE, event.sequence(), result.victim_body_id(), result.attacker_body_id(), 0, SimEvent.CauseId.NONE, event.position(), normal.negated(status), result.applied_damage(), result.resolved_damage(), status)


func _process_collision_event(
		event: SimEvent,
		pending_body_ids: Array[int],
		pending_cause_ids: Array[int],
		status: SimStatus
) -> void:
	var source_id: int = event.source_body_id()
	var target_id: int = event.target_body_id()
	if source_id == 0 or source_id >= target_id:
		status.fail(
			SimStatus.Code.INVALID_COLLISION_FACT,
			SimStatus.Operation.BATTLE_DAMAGE_EVENT,
			source_id,
			target_id
		)
		return
	var source_index: int = _find_combatant(source_id)
	var target_index: int = _find_combatant(target_id)
	if source_index < 0 or target_index < 0:
		return
	var source: BattleCombatant = _combatants[source_index]
	var target: BattleCombatant = _combatants[target_index]
	if source.current_hp() == 0 or target.current_hp() == 0:
		return
	var source_mass_raw: int = event.collision_source_mass_raw(status)
	var target_mass_raw: int = event.collision_target_mass_raw(status)
	var speed_order: int = event.collision_speed_order(status)
	if not status.is_ok():
		return
	if _same_non_neutral_faction(source, target):
		_emit_trigger(BattleTriggerId.Value.ON_ALLY_COLLIDE, event.sequence(), source_id, target_id, 0, SimEvent.CauseId.NONE, event.position(), event.vector(), event.value_a(), 0, status)
		_emit_trigger(BattleTriggerId.Value.ON_ALLY_COLLIDE, event.sequence(), target_id, source_id, 0, SimEvent.CauseId.NONE, event.position(), event.vector().negated(status), event.value_a(), 0, status)
	# Motion lineage follows contact even when the impact is below the damage threshold.
	if speed_order == SimEvent.COLLISION_SOURCE_FASTER:
		_transfer_motion_credit(source_id, target_id, event.sequence(), event.tick(), status)
	elif speed_order == SimEvent.COLLISION_TARGET_FASTER:
		_transfer_motion_credit(target_id, source_id, event.sequence(), event.tick(), status)
	else:
		var source_credit: BattleMotionCredit = BattleMotionCredit.new()
		var target_credit: BattleMotionCredit = BattleMotionCredit.new()
		var source_credit_index: int = _find_motion_credit(source_id)
		var target_credit_index: int = _find_motion_credit(target_id)
		if source_credit_index >= 0: source_credit = _motion_credits[source_credit_index].copy()
		if target_credit_index >= 0: target_credit = _motion_credits[target_credit_index].copy()
		var source_root: int = target_id if not target_credit.is_initialized() else target_credit.root_body_id()
		var source_faction: int = target.faction() if not target_credit.is_initialized() else target_credit.root_faction()
		var target_root: int = source_id if not source_credit.is_initialized() else source_credit.root_body_id()
		var target_faction: int = source.faction() if not source_credit.is_initialized() else source_credit.root_faction()
		_set_motion_credit(source_id, source_root, source_faction, event.sequence(), event.tick(), status)
		_set_motion_credit(target_id, target_root, target_faction, event.sequence(), event.tick(), status)
	if event.value_a() < DamageLimits.DAMAGE_THRESHOLD_SPEED_RAW:
		return
	var cooldown_index: int = _find_cooldown(source_id, target_id)
	if (
		cooldown_index >= 0
		and not _cooldowns[cooldown_index].is_ready(event.tick())
	):
		return

	var dealt_damage: bool = false
	if speed_order == SimEvent.COLLISION_SOURCE_FASTER:
		var source_result: DamageResult = _resolve_damage_direction(
			source,
			target,
			source_mass_raw,
			target_mass_raw,
			event.value_a(),
			event.sequence(),
			status
		)
		dealt_damage = status.is_ok() and source_result.has_damage()
		_emit_damage_pair(source_result, event, event.vector(), status)
		_apply_damage_result(
			source_result, pending_body_ids, pending_cause_ids, status
		)
	elif speed_order == SimEvent.COLLISION_TARGET_FASTER:
		var target_result: DamageResult = _resolve_damage_direction(
			target,
			source,
			target_mass_raw,
			source_mass_raw,
			event.value_a(),
			event.sequence(),
			status
		)
		dealt_damage = status.is_ok() and target_result.has_damage()
		_emit_damage_pair(target_result, event, event.vector().negated(status), status)
		_apply_damage_result(
			target_result, pending_body_ids, pending_cause_ids, status
		)
	else:
		var source_to_target: DamageResult = _resolve_damage_direction(
			source,
			target,
			source_mass_raw,
			target_mass_raw,
			event.value_a(),
			event.sequence(),
			status
		)
		var target_to_source: DamageResult = _resolve_damage_direction(
			target,
			source,
			target_mass_raw,
			source_mass_raw,
			event.value_a(),
			event.sequence(),
			status
		)
		dealt_damage = (
			status.is_ok()
			and (source_to_target.has_damage() or target_to_source.has_damage())
		)
		_emit_damage_pair(source_to_target, event, event.vector(), status)
		_emit_damage_pair(target_to_source, event, event.vector().negated(status), status)
		_apply_damage_result(
			source_to_target, pending_body_ids, pending_cause_ids, status
		)
		_apply_damage_result(
			target_to_source, pending_body_ids, pending_cause_ids, status
		)
	if status.is_ok() and dealt_damage:
		_update_cooldown(source_id, target_id, event.tick(), status)


func _process_destroy_event(event: SimEvent, status: SimStatus) -> void:
	var victim_id: int = event.source_body_id()
	var victim_faction: int = _participant_faction(victim_id)
	var direct_attacker: int = event.target_body_id()
	_emit_trigger(BattleTriggerId.Value.ON_DEATH_SELF, event.sequence(), victim_id, 0, 0, event.cause_id(), event.position(), event.vector(), 0, 0, status)
	var killer_id: int = 0
	var killer_faction: int = BattleParticipant.Faction.INVALID
	var credit_index: int = _find_motion_credit(victim_id)
	if credit_index >= 0:
		killer_id = _motion_credits[credit_index].root_body_id()
		killer_faction = _motion_credits[credit_index].root_faction()
	elif direct_attacker > 0:
		killer_id = direct_attacker
		killer_faction = _participant_faction(direct_attacker)
	if killer_id > 0 and ((killer_faction == BattleParticipant.Faction.PLAYER and victim_faction == BattleParticipant.Faction.ENEMY) or (killer_faction == BattleParticipant.Faction.ENEMY and victim_faction == BattleParticipant.Faction.PLAYER)):
		_emit_trigger(BattleTriggerId.Value.ON_KILL, event.sequence(), killer_id, victim_id, direct_attacker, event.cause_id(), event.position(), event.vector(), 0, 0, status)
		_increment_kill_tally(killer_id, status)
	_remove_body_state(victim_id, status)


func _consume_world_events(status: SimStatus) -> void:
	var event_boundary: int = _world.event_count()
	var pending_body_ids: Array[int] = []
	var pending_cause_ids: Array[int] = []
	while status.is_ok() and _world.event_cursor() < event_boundary:
		var event: SimEvent = _world.consume_next_event(status)
		if not status.is_ok():
			return
		if event.type_id() == SimEvent.TypeId.BODY_COLLIDED:
			_expire_collision_body(event.source_body_id(), event.sequence(), status)
			_expire_collision_body(event.target_body_id(), event.sequence(), status)
			_process_collision_event(
				event, pending_body_ids, pending_cause_ids, status
			)
		elif event.type_id() == SimEvent.TypeId.BODY_HIT_WALL:
			_expire_collision_body(event.source_body_id(), event.sequence(), status)
			_emit_trigger(BattleTriggerId.Value.ON_WALL_BOUNCE, event.sequence(), event.source_body_id(), 0, 0, SimEvent.CauseId.NONE, event.position(), event.vector(), event.value_a(), event.value_b(), status)
		elif event.type_id() == SimEvent.TypeId.BODY_DESTROYED:
			_process_destroy_event(event, status)
		elif event.type_id() == SimEvent.TypeId.BODY_REMOVED:
			_remove_body_state(event.source_body_id(), status)
	if not status.is_ok():
		return
	for index: int in range(pending_body_ids.size()):
		var body_id: int = pending_body_ids[index]
		var combatant_index: int = _find_combatant(body_id)
		if combatant_index < 0:
			continue
		if _combatants[combatant_index].current_hp() != 0:
			status.fail(
				SimStatus.Code.INVALID_BATTLE_STATE,
				SimStatus.Operation.BATTLE_DAMAGE_EVENT,
				body_id,
				_combatants[combatant_index].current_hp()
			)
			return
		_world.destroy_body(body_id, pending_cause_ids[index], status)
		if not status.is_ok():
			return
	while status.is_ok() and _world.event_cursor() < _world.event_count():
		var event: SimEvent = _world.consume_next_event(status)
		if not status.is_ok():
			return
		if (
			event.type_id() != SimEvent.TypeId.BODY_DESTROYED
			or event.cause_id() != SimEvent.CauseId.DAMAGE
		):
			status.fail(
				SimStatus.Code.INVALID_BATTLE_STATE,
				SimStatus.Operation.BATTLE_DAMAGE_EVENT,
				event.type_id(),
				event.cause_id()
			)
			return
		_process_destroy_event(event, status)


func _register_dynamic_spawn(body_id: int, request: DynamicSpawnRequest, status: SimStatus) -> bool:
	if request == null or body_id == 0 or _runtime_spawn_count >= BattleLimits.RUNTIME_SPAWN_MAX_BODIES:
		status.fail(SimStatus.Code.SPAWN_LIMIT_EXCEEDED, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, _runtime_spawn_count + 1, BattleLimits.RUNTIME_SPAWN_MAX_BODIES); return false
	var identity: BattlePieceIdentity = BattlePieceIdentity.create(body_id, request.piece_numeric_id, 1, request.faction, true, status)
	var body: SimBody = _world.body_by_id(body_id, status)
	var base_stats: BattleBaseBodyStats = BattleBaseBodyStats.create(body_id, body.mass_raw(), body.radius_raw(), body.friction_multiplier_raw(), status)
	var expire: ExpireState = ExpireState.create(body_id, request.expire_kind_id, request.expire_value, request.applied_turn_index, false, status)
	if not status.is_ok(): return false
	_piece_identities.append(identity); _piece_identities.sort_custom(func(a: BattlePieceIdentity, b: BattlePieceIdentity) -> bool: return a.body_id() < b.body_id())
	_base_body_stats.append(base_stats); _base_body_stats.sort_custom(func(a: BattleBaseBodyStats, b: BattleBaseBodyStats) -> bool: return a.body_id() < b.body_id())
	_expire_states.append(expire); _expire_states.sort_custom(func(a: ExpireState, b: ExpireState) -> bool: return a.body_id() < b.body_id())
	for ability_id: int in request.ability_numeric_ids: _ability_bindings.append(AbilityBinding.create(body_id, ability_id, status))
	_ability_bindings.sort_custom(func(a: AbilityBinding, b: AbilityBinding) -> bool: return a.owner_body_id() < b.owner_body_id() or (a.owner_body_id() == b.owner_body_id() and a.ability_numeric_id() < b.ability_numeric_id()))
	_runtime_spawn_count += 1
	_modifier_resolver = ModifierResolver.build(_content_catalog, _piece_identities, _synergy_tally, status)
	if not status.is_ok() or not _materialize_physical_stats(status): return false
	if not _world.correct_body_overlap_once(body_id, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, body_id, request.piece_numeric_id)
		return false
	return true


func _apply_barrier(status: SimStatus) -> bool:
	if _pending.is_empty():
		_consume_world_events(status)
		return status.is_ok()
	var backup_status := SimStatus.new()
	var backup: BattleState = copy(backup_status)
	if not backup_status.is_ok():
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_MUTATION_BARRIER, 0, 0)
		return false
	_pending.sort_custom(_request_less)
	for request: BattleMutationRequest in _pending:
		if request.kind == BattleMutationRequest.Kind.SPAWN:
			_world.queue_body_spawn(request.body_template, request.cause_body_id, request.event_type_id, request.ordinal, status)
			_world.commit_pending_spawns(status)
			if not status.is_ok(): break
			var event: SimEvent = _world.consume_next_event(status)
			if not status.is_ok(): break
			if event.type_id() != SimEvent.TypeId.BODY_ADDED or (event.flags() & SimEvent.FLAG_RUNTIME_SPAWN_KEY_PRESENT) == 0 or event.tick() != request.tick or event.target_body_id() != request.cause_body_id or event.value_a() != request.event_type_id or event.value_b() != request.ordinal:
				status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_MUTATION_BARRIER, request.cause_body_id, request.ordinal)
				break
			if request.participant_template != null:
				_participants.append(request.participant_template.assigned_copy(event.source_body_id(), status))
				_participants.sort_custom(_participant_less)
			if status.is_ok() and request.combatant_template != null:
				_combatants.append(
					request.combatant_template.assigned_copy(
						event.source_body_id(), status
					)
				)
				_combatants.sort_custom(_combatant_less)
			if status.is_ok() and request.dynamic_spawn != null:
				_register_dynamic_spawn(event.source_body_id(), request.dynamic_spawn, status)
		elif request.kind == BattleMutationRequest.Kind.ZONE_SPAWN:
			var planned_zone_id: int = _world.next_zone_id()
			_world.queue_zone_spawn(request.zone_template, request.cause_body_id, request.event_type_id, request.ordinal, status)
			_world.commit_pending_spawns(status)
			if not status.is_ok(): break
			var found_zone: bool = false
			for zone_index: int in range(_world.zone_count()):
				if _world.zone_at(zone_index, status).id() == planned_zone_id: found_zone = true; break
			if not status.is_ok() or not found_zone:
				if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_ZONE_SPAWN, planned_zone_id, _world.zone_count())
				break
			_zone_spawns.append(ZoneSpawnState.create(planned_zone_id, request.zone_duration_turns, request.zone_applied_turn_index, status))
			_zone_spawns.sort_custom(func(a: ZoneSpawnState, b: ZoneSpawnState) -> bool: return a.zone_id() < b.zone_id())
		else:
			_world.remove_body(request.body_id, status)
			if status.is_ok():
				_remove_body_state(request.body_id, status)
				_consume_world_events(status)
		if not status.is_ok(): break
	if status.is_ok():
		_pending.clear()
		_consume_world_events(status)
		if status.is_ok(): _settle_link_release_expire(status)
		return status.is_ok()
	_assign_from(backup)
	return false


func queue_body_spawn(body_template: SimBody, participant_template: BattleParticipant, cause_body_id: int, event_type_id: int, ordinal: int, status: SimStatus) -> bool:
	if not status.is_ok() or body_template == null or body_template.id() != 0 or (participant_template != null and participant_template.body_id() != 0):
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_QUEUE_MUTATION, cause_body_id, ordinal)
		return false
	return _queue_request(BattleMutationRequest.Kind.SPAWN, 0, body_template, participant_template, null, cause_body_id, event_type_id, ordinal, status)


func queue_combatant_body_spawn(
		body_template: SimBody,
		participant_template: BattleParticipant,
		combatant_template: BattleCombatant,
		cause_body_id: int,
		event_type_id: int,
		ordinal: int,
		status: SimStatus
) -> bool:
	if (
		not status.is_ok()
		or body_template == null
		or body_template.id() != 0
		or not body_template.destructible()
		or combatant_template == null
		or not combatant_template.is_initialized()
		or combatant_template.body_id() != 0
		or combatant_template.current_hp() <= 0
		or combatant_template.critical_basis_points() != 0
		or (
			participant_template != null
			and (
				participant_template.body_id() != 0
				or participant_template.faction() != combatant_template.faction()
			)
		)
	):
		if status.is_ok():
			status.fail(
				SimStatus.Code.INVALID_COMBATANT,
				SimStatus.Operation.BATTLE_QUEUE_MUTATION,
				cause_body_id,
				ordinal
			)
		return false
	return _queue_request(
		BattleMutationRequest.Kind.SPAWN,
		0,
		body_template,
		participant_template,
		combatant_template,
		cause_body_id,
		event_type_id,
		ordinal,
		status
	)


func queue_dynamic_spawn(request: DynamicSpawnRequest, status: SimStatus) -> bool:
	if request == null or request.body_template == null or request.participant_template == null or request.piece_numeric_id == 0 or _dynamic_spawn_transition_count >= BattleLimits.DYNAMIC_SPAWN_MAX_PER_TRANSITION or _runtime_spawn_count + _dynamic_spawn_transition_count >= BattleLimits.RUNTIME_SPAWN_MAX_BODIES:
		status.fail(SimStatus.Code.SPAWN_LIMIT_EXCEEDED, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, _dynamic_spawn_transition_count + 1, BattleLimits.DYNAMIC_SPAWN_MAX_PER_TRANSITION); return false
	var queued: bool = _queue_request(BattleMutationRequest.Kind.SPAWN, 0, request.body_template, request.participant_template, request.combatant_template, request.cause_body_id, request.event_type_id, request.ordinal, status)
	if queued:
		_pending[-1].dynamic_spawn = request.copy(); _dynamic_spawn_transition_count += 1
	return queued


func queue_zone_spawn(zone_template: SimZone, duration_turns: int, cause_body_id: int, event_type_id: int, ordinal: int, status: SimStatus) -> bool:
	if (
		not status.is_ok() or zone_template == null or zone_template.id() != 0
		or duration_turns < 0 or duration_turns > ContentLimits.ZONE_DURATION_MAX_TURNS
		or _zone_spawn_transition_count >= BattleLimits.ZONE_SPAWN_MAX_PER_TRANSITION
		or _zone_spawns.size() + _zone_spawn_transition_count >= BattleLimits.ZONE_SPAWN_MAX_PER_BATTLE
		or _world.zone_count() + _zone_spawn_transition_count >= BattleLimits.ZONE_TOTAL_MAX
	):
		status.fail(SimStatus.Code.ZONE_LIMIT_EXCEEDED, SimStatus.Operation.BATTLE_ZONE_SPAWN, _zone_spawns.size() + _zone_spawn_transition_count + 1, _world.zone_count() + _zone_spawn_transition_count + 1)
		return false
	var queued: bool = _queue_request(BattleMutationRequest.Kind.ZONE_SPAWN, 0, null, null, null, cause_body_id, event_type_id, ordinal, status)
	if queued:
		_pending[-1].zone_template = zone_template.copy(); _pending[-1].zone_duration_turns = duration_turns; _pending[-1].zone_applied_turn_index = _turn_index
		_zone_spawn_transition_count += 1
	return queued


func queue_participant_removal(body_id: int, cause_body_id: int, event_type_id: int, ordinal: int, status: SimStatus) -> bool:
	if _find_participant(body_id) < 0:
		status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_QUEUE_MUTATION, body_id, 0)
		return false
	return _queue_request(BattleMutationRequest.Kind.REMOVE, body_id, null, null, null, cause_body_id, event_type_id, ordinal, status)


func _queue_request(
		kind: int,
		body_id: int,
		body_template: SimBody,
		participant_template: BattleParticipant,
		combatant_template: BattleCombatant,
		cause_body_id: int,
		event_type_id: int,
		ordinal: int,
		status: SimStatus
) -> bool:
	if not status.is_ok() or not UInt32Math.is_u32(cause_body_id) or event_type_id < 0 or event_type_id > 0xFFFF or not UInt32Math.is_u32(ordinal): return false
	for prior: BattleMutationRequest in _pending:
		if prior.tick == _world.tick() and prior.cause_body_id == cause_body_id and prior.event_type_id == event_type_id and prior.ordinal == ordinal:
			status.fail(SimStatus.Code.DUPLICATE_ID, SimStatus.Operation.BATTLE_QUEUE_MUTATION, cause_body_id, ordinal)
			return false
	var request := BattleMutationRequest.new()
	request.kind = kind; request.tick = _world.tick(); request.body_id = body_id
	request.body_template = null if body_template == null else body_template.copy()
	request.participant_template = null if participant_template == null else participant_template.copy()
	request.combatant_template = null if combatant_template == null else combatant_template.copy()
	request.cause_body_id = cause_body_id; request.event_type_id = event_type_id; request.ordinal = ordinal
	_pending.append(request)
	return true


func complete_battle_start(status: SimStatus) -> bool:
	if not _require_phase(Phase.BATTLE_START, SimStatus.Operation.BATTLE_START_COMPLETE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	_begin_trigger_transition()
	if _apply_barrier(status): _emit_trigger(BattleTriggerId.Value.ON_BATTLE_START, 0, 0, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, status)
	if status.is_ok() and _select_actor(status) and _finish_trigger_transition(status): return true
	_assign_from(backup)
	return false


func complete_turn_start(status: SimStatus) -> bool:
	if not _require_phase(Phase.TURN_START, SimStatus.Operation.BATTLE_TURN_START_COMPLETE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	_begin_trigger_transition()
	if not _apply_barrier(status): _assign_from(backup); return false
	if _find_participant(_current_actor_body_id) < 0:
		status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_TURN_START_COMPLETE, _current_actor_body_id, 0)
		_assign_from(backup)
		return false
	_emit_trigger(BattleTriggerId.Value.ON_TURN_START, 0, _current_actor_body_id, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, status)
	if not _finish_trigger_transition(status): _assign_from(backup); return false
	_phase = Phase.AIM
	return true


func cancel_aim(status: SimStatus) -> bool:
	return _require_phase(Phase.AIM, SimStatus.Operation.BATTLE_AIM_CANCEL, status)


func _consume_actor(status: SimStatus) -> bool:
	var index: int = _find_participant(_current_actor_body_id)
	if index < 0:
		status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_ACTION_COMMIT, _current_actor_body_id, 0)
		return false
	var actor: BattleParticipant = _participants[index]
	if actor.ct() < BattleLimits.CT_THRESHOLD:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_ACTION_COMMIT, actor.body_id(), actor.ct())
		return false
	_participants[index] = actor.with_ct(actor.ct() - BattleLimits.CT_THRESHOLD, status)
	_last_acted_faction = actor.faction()
	return status.is_ok()


func commit_launch_velocity(launch_velocity: FixVec2, status: SimStatus) -> bool:
	if not _require_phase(Phase.AIM, SimStatus.Operation.BATTLE_ACTION_COMMIT, status): return false
	if launch_velocity == null or launch_velocity.is_zero() or not SimLimits.is_launch_speed_valid(launch_velocity, status): return false
	if not _world.is_quiescent(SimWorld.ContinuousAccelerationMode.APPLY, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_ACTION_COMMIT, _current_actor_body_id, 0)
		return false
	var backup: BattleState = copy(SimStatus.new())
	_begin_trigger_transition()
	if not _materialize_physical_stats(status): _assign_from(backup); return false
	var next_world: SimWorld = _world._transaction_copy(status)
	next_world.set_body_velocity(_current_actor_body_id, launch_velocity, status)
	if not status.is_ok() or not _consume_actor(status): _assign_from(backup); return false
	_world = next_world
	_motion_credits.clear()
	var actor_faction: int = _participant_faction(_current_actor_body_id)
	_set_motion_credit(_current_actor_body_id, _current_actor_body_id, actor_faction, 0, _world.tick(), status)
	_emit_trigger(BattleTriggerId.Value.ON_LAUNCH, 0, _current_actor_body_id, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), launch_velocity, 0, 0, status)
	_normal_resolve_ticks = 0; _forced_resolve_ticks = 0; _forced_settle_used = false
	_phase = Phase.RESOLVE
	if not _finish_trigger_transition(status): _assign_from(backup); return false
	return true


func commit_forced_no_launch(status: SimStatus) -> bool:
	if _phase != Phase.TURN_START and _phase != Phase.AIM:
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_ACTION_COMMIT, _phase, (1 << Phase.TURN_START) | (1 << Phase.AIM))
		return false
	var backup: BattleState = copy(SimStatus.new())
	_begin_trigger_transition()
	if not _apply_barrier(status) or not _consume_actor(status): _assign_from(backup); return false
	_motion_credits.clear()
	_normal_resolve_ticks = 0; _forced_resolve_ticks = 0; _forced_settle_used = false
	_phase = Phase.TURN_END if _world.is_quiescent(SimWorld.ContinuousAccelerationMode.APPLY, status) else Phase.RESOLVE
	if not _finish_trigger_transition(status): _assign_from(backup); return false
	return status.is_ok()


func interrupt_missing_current_actor(status: SimStatus) -> bool:
	if _phase != Phase.TURN_START and _phase != Phase.AIM:
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_ACTOR_INTERRUPT, _phase, 0)
		return false
	var backup: BattleState = copy(SimStatus.new())
	_begin_trigger_transition()
	if not _apply_barrier(status):
		_assign_from(backup)
		return false
	var lookup := SimStatus.new()
	_world.body_by_id(_current_actor_body_id, lookup)
	if _find_participant(_current_actor_body_id) >= 0 and lookup.is_ok():
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_ACTOR_INTERRUPT, _current_actor_body_id, 0)
		_assign_from(backup)
		return false
	_phase = Phase.TURN_END if _world.is_quiescent(SimWorld.ContinuousAccelerationMode.APPLY, status) else Phase.RESOLVE
	if not _finish_trigger_transition(status): _assign_from(backup); return false
	return status.is_ok()


func advance_resolve(status: SimStatus) -> bool:
	if not _require_phase(Phase.RESOLVE, SimStatus.Operation.BATTLE_RESOLVE_ADVANCE, status): return false
	var backup: BattleState = _rollback_snapshot()
	_begin_trigger_transition()
	var mode: int = SimWorld.ContinuousAccelerationMode.SUPPRESS if _forced_settle_used else SimWorld.ContinuousAccelerationMode.APPLY
	if (not _forced_settle_used or _forced_resolve_ticks > 0) and _world.is_quiescent(mode, status) and _pending.is_empty() and _world.event_cursor() == _world.event_count():
		_phase = Phase.TURN_END
		return _finish_trigger_transition(status)
	if _pending.is_empty() and _world.event_cursor() == _world.event_count() and ResolvePacingPolicy.should_settle(_world, status):
		var settled_world: SimWorld = _world._transaction_copy(status)
		for index: int in range(settled_world.body_count()):
			var settled_body: SimBody = settled_world.body_at(index, status)
			if not settled_body.velocity().is_zero(): settled_world.set_body_velocity(settled_body.id(), FixVec2.zero(), status)
		if not status.is_ok(): _assign_from(backup); return false
		_world = settled_world
		_phase = Phase.TURN_END
		return _finish_trigger_transition(status)
	if _forced_settle_used and _forced_resolve_ticks >= BattleLimits.FORCED_RESOLVE_MAX_TICKS:
		var blocker: int = 0
		for index: int in range(_world.body_count()):
			var body: SimBody = _world.body_at(index, status)
			if not body.velocity().is_zero(): blocker = body.id(); break
		status.fail(SimStatus.Code.RESOLVE_DEADLOCK, SimStatus.Operation.BATTLE_RESOLVE_ADVANCE, blocker, _normal_resolve_ticks + _forced_resolve_ticks)
		return false
	for index: int in range(_world.body_count()):
		var moving_body: SimBody = _world.body_at(index, status)
		if not moving_body.velocity().is_zero():
			_emit_trigger(BattleTriggerId.Value.ON_MOVING, 0, moving_body.id(), 0, 0, SimEvent.CauseId.NONE, moving_body.position(), moving_body.velocity(), 0, 0, status)
	var next_world: SimWorld = _world._transaction_copy(status)
	if _forced_settle_used:
		for index: int in range(next_world.body_count()):
			var body: SimBody = next_world.body_at(index, status)
			if not body.velocity().is_zero():
				var damped := FixVec2.from_raw(
					FixMath.mul_ratio_raw(body.velocity().x_raw(), BattleLimits.FORCED_DAMPING_NUMERATOR, BattleLimits.FORCED_DAMPING_DENOMINATOR, status),
					FixMath.mul_ratio_raw(body.velocity().y_raw(), BattleLimits.FORCED_DAMPING_NUMERATOR, BattleLimits.FORCED_DAMPING_DENOMINATOR, status))
				next_world.set_body_velocity(body.id(), damped, status)
	if not status.is_ok() or not next_world.step_with_acceleration_mode(mode, status): _assign_from(backup); return false
	_world = next_world
	_consume_world_events(status)
	if not _apply_barrier(status): _assign_from(backup); return false
	if _forced_settle_used: _forced_resolve_ticks += 1
	else:
		_normal_resolve_ticks += 1
		if _normal_resolve_ticks >= BattleLimits.NORMAL_RESOLVE_MAX_TICKS: _forced_settle_used = true
	if _forced_settle_used and _forced_resolve_ticks == 0:
		if not _finish_trigger_transition(status): _assign_from(backup); return false
		return status.is_ok()
	mode = SimWorld.ContinuousAccelerationMode.SUPPRESS if _forced_settle_used else SimWorld.ContinuousAccelerationMode.APPLY
	if _world.is_quiescent(mode, status) and _pending.is_empty() and _world.event_cursor() == _world.event_count(): _phase = Phase.TURN_END
	if not _finish_trigger_transition(status): _assign_from(backup); return false
	return status.is_ok()


func complete_turn_end(status: SimStatus) -> bool:
	if not _require_phase(Phase.TURN_END, SimStatus.Operation.BATTLE_TURN_END_COMPLETE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	_begin_trigger_transition()
	if not _apply_barrier(status): _assign_from(backup); return false
	_emit_trigger(BattleTriggerId.Value.ON_TURN_END, 0, _current_actor_body_id, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), 0, 0, status)
	if not _finish_trigger_transition(status): _assign_from(backup); return false
	_turn_index += 1
	_phase = Phase.CHECK
	return true


func apply_check_directive(directive: int, status: SimStatus) -> bool:
	if not _require_phase(Phase.CHECK, SimStatus.Operation.BATTLE_CHECK_APPLY, status): return false
	if directive != CheckDirective.CONTINUE and directive != CheckDirective.END:
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_CHECK_APPLY, directive, 0)
		return false
	var computed: int = BattleResultResolver.resolve(_participants)
	if (directive == CheckDirective.CONTINUE) != (computed == BattleResult.Value.ONGOING):
		status.fail(SimStatus.Code.INVALID_BATTLE_RESULT, SimStatus.Operation.BATTLE_RESULT_RESOLVE, directive, computed)
		return false
	return resolve_check(status)


func resolve_check(status: SimStatus) -> bool:
	if not _require_phase(Phase.CHECK, SimStatus.Operation.BATTLE_RESULT_RESOLVE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	_begin_trigger_transition()
	if not _pending.is_empty() or _world.event_cursor() != _world.event_count():
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_RESULT_RESOLVE, _pending.size(), _world.event_count() - _world.event_cursor())
		_assign_from(backup); return false
	var computed: int = BattleResultResolver.resolve(_participants)
	_current_actor_body_id = 0
	if computed == BattleResult.Value.ONGOING:
		if not _select_actor(status) or not _finish_trigger_transition(status): _assign_from(backup); return false
		return true
	_battle_result = computed
	_phase = Phase.BATTLE_END
	_statuses.clear()
	_motion_credits.clear()
	_emit_trigger(BattleTriggerId.Value.ON_BATTLE_END, 0, 0, 0, 0, SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(), computed, 0, status)
	if not _finish_trigger_transition(status): _assign_from(backup); return false
	return true


func preview(count: int, status: SimStatus) -> Array[CtbPreviewEntry]:
	if not _initialized:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.CTB_PREVIEW, 0, 0); return []
	if count < 1 or count > BattleLimits.PREVIEW_MAX_COUNT:
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.CTB_PREVIEW, count, BattleLimits.PREVIEW_MAX_COUNT)
		return []
	if _phase == Phase.BATTLE_END: return []
	var local: Array[BattleParticipant] = _effective_participants(status)
	var local_last: int = _last_acted_faction
	if _phase == Phase.TURN_START or _phase == Phase.AIM:
		var index: int = _find_participant(_current_actor_body_id)
		if index < 0: return []
		local[index] = local[index].with_ct(local[index].ct() - BattleLimits.CT_THRESHOLD, status)
		local_last = local[index].faction()
	return CtbScheduler.preview(local, _abstract_time, local_last, count, status)


func copy(status: SimStatus) -> BattleState:
	var result := BattleState.new()
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_COPY, 0, 0)
		return result
	result._initialized = true; result._phase = _phase; result._current_actor_body_id = _current_actor_body_id
	result._abstract_time = _abstract_time; result._last_acted_faction = _last_acted_faction
	result._participants = _copy_participants(_participants)
	result._combatants = _copy_combatants(_combatants)
	result._cooldowns = _copy_cooldowns(_cooldowns)
	result._world = _world.copy(status)
	result._pending = _copy_pending(_pending); result._normal_resolve_ticks = _normal_resolve_ticks
	result._forced_resolve_ticks = _forced_resolve_ticks; result._forced_settle_used = _forced_settle_used
	result._battle_result = _battle_result; result._next_trigger_sequence = _next_trigger_sequence
	result._last_trigger_batch = _copy_trigger_records(_last_trigger_batch)
	result._motion_credits = _copy_motion_credits(_motion_credits)
	result._content_fingerprint = _content_fingerprint.duplicate()
	for binding: AbilityBinding in _ability_bindings: result._ability_bindings.append(binding.copy())
	result._next_effect_sequence = _next_effect_sequence
	result._turn_index = _turn_index; result._content_catalog = _content_catalog.copy() if _content_catalog.is_initialized() else ContentCatalog.new()
	for identity: BattlePieceIdentity in _piece_identities: result._piece_identities.append(identity.copy())
	result._synergy_tally = _synergy_tally.copy(); result._statuses = _statuses.copy(); result._modifier_resolver = _modifier_resolver.copy()
	for base_stats: BattleBaseBodyStats in _base_body_stats: result._base_body_stats.append(base_stats.copy())
	result._expire_states = _copy_expire_states(_expire_states); result._piece_origins = _copy_piece_origins(_piece_origins); result._runtime_spawn_count = _runtime_spawn_count
	result._dynamic_spawn_transition_count = _dynamic_spawn_transition_count; result._dynamic_transform_body_ids = _dynamic_transform_body_ids.duplicate()
	result._zone_spawns = _copy_zone_spawns(_zone_spawns); result._zone_spawn_transition_count = _zone_spawn_transition_count
	result._kill_tallies = _copy_kill_tallies(_kill_tallies)
	return result


func _rollback_snapshot() -> BattleState:
	# Resolve replaces value objects and the world reference before applying any
	# mutation barrier. A shallow structural snapshot is therefore sufficient
	# for atomic rollback and avoids cloning the full append-only event history
	# every 120 Hz tick. Public copy() remains deeply isolated.
	var result := BattleState.new()
	result._initialized = _initialized; result._phase = _phase; result._current_actor_body_id = _current_actor_body_id
	result._abstract_time = _abstract_time; result._last_acted_faction = _last_acted_faction
	result._participants = _participants.duplicate(); result._combatants = _combatants.duplicate()
	result._cooldowns = _cooldowns.duplicate(); result._world = _world
	result._pending = _pending.duplicate(); result._normal_resolve_ticks = _normal_resolve_ticks
	result._forced_resolve_ticks = _forced_resolve_ticks; result._forced_settle_used = _forced_settle_used
	result._battle_result = _battle_result; result._next_trigger_sequence = _next_trigger_sequence
	result._last_trigger_batch = _last_trigger_batch.duplicate(); result._motion_credits = _motion_credits.duplicate()
	result._content_fingerprint = _content_fingerprint.duplicate(); result._ability_bindings = _ability_bindings.duplicate(); result._next_effect_sequence = _next_effect_sequence
	result._turn_index = _turn_index; result._content_catalog = _content_catalog; result._piece_identities = _piece_identities.duplicate(); result._synergy_tally = _synergy_tally; result._statuses = _statuses.copy(); result._modifier_resolver = _modifier_resolver; result._base_body_stats = _base_body_stats.duplicate()
	result._expire_states = _expire_states.duplicate(); result._piece_origins = _piece_origins.duplicate(); result._runtime_spawn_count = _runtime_spawn_count; result._dynamic_spawn_transition_count = _dynamic_spawn_transition_count; result._dynamic_transform_body_ids = _dynamic_transform_body_ids.duplicate()
	result._zone_spawns = _zone_spawns.duplicate(); result._zone_spawn_transition_count = _zone_spawn_transition_count
	result._kill_tallies = _kill_tallies.duplicate()
	return result


func _assign_from(other: BattleState) -> void:
	_initialized = other._initialized; _phase = other._phase; _current_actor_body_id = other._current_actor_body_id
	_abstract_time = other._abstract_time; _last_acted_faction = other._last_acted_faction
	_participants = other._participants; _combatants = other._combatants
	_cooldowns = other._cooldowns; _world = other._world; _pending = other._pending
	_normal_resolve_ticks = other._normal_resolve_ticks; _forced_resolve_ticks = other._forced_resolve_ticks
	_forced_settle_used = other._forced_settle_used
	_battle_result = other._battle_result; _next_trigger_sequence = other._next_trigger_sequence
	_last_trigger_batch = other._last_trigger_batch; _motion_credits = other._motion_credits
	_trigger_bus = BattleTriggerBus.new()
	_content_fingerprint = other._content_fingerprint.duplicate()
	_ability_bindings.clear()
	for binding: AbilityBinding in other._ability_bindings: _ability_bindings.append(binding.copy())
	_next_effect_sequence = other._next_effect_sequence
	_turn_index = other._turn_index; _content_catalog = other._content_catalog; _piece_identities = other._piece_identities; _synergy_tally = other._synergy_tally; _statuses = other._statuses; _modifier_resolver = other._modifier_resolver; _base_body_stats = other._base_body_stats
	_expire_states = other._expire_states; _piece_origins = other._piece_origins; _runtime_spawn_count = other._runtime_spawn_count; _dynamic_spawn_transition_count = other._dynamic_spawn_transition_count; _dynamic_transform_body_ids = other._dynamic_transform_body_ids
	_zone_spawns = other._zone_spawns; _zone_spawn_transition_count = other._zone_spawn_transition_count
	_kill_tallies = other._kill_tallies


func attach_content(catalog: ContentCatalog, identities: Array[BattlePieceIdentity], bindings: Array[AbilityBinding], status: SimStatus) -> bool:
	if not status.is_ok() or not _require_phase(Phase.BATTLE_START, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, status): return false
	if catalog == null or not catalog.is_initialized() or _content_catalog.is_initialized(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ); return false
	var sorted: Array[BattlePieceIdentity] = []; var previous_body: int = 0
	for identity: BattlePieceIdentity in identities:
		if identity == null or not identity.is_initialized(): status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ); return false
		sorted.append(identity.copy())
	sorted.sort_custom(func(a: BattlePieceIdentity, b: BattlePieceIdentity) -> bool: return a.body_id() < b.body_id())
	var bases: Array[BattleBaseBodyStats] = []
	for identity: BattlePieceIdentity in sorted:
		if identity.body_id() <= previous_body: status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, identity.body_id(), previous_body); return false
		var world_status := SimStatus.new(); var body: SimBody = _world.body_by_id(identity.body_id(), world_status)
		var content_status := ContentStatus.new(); var piece: PieceDefinition = catalog.piece_by_numeric_id(identity.piece_numeric_id(), content_status)
		if not world_status.is_ok() or not content_status.is_ok() or piece.is_token() != identity.is_token(): status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, identity.body_id(), identity.piece_numeric_id()); return false
		bases.append(BattleBaseBodyStats.create(identity.body_id(), body.mass_raw(), body.radius_raw(), body.friction_multiplier_raw(), status)); previous_body = identity.body_id()
	var tally: SynergyTally = SynergyTallyBuilder.build(catalog, sorted, status)
	var resolver: ModifierResolver = ModifierResolver.build(catalog, sorted, tally, status)
	var registry: AbilityRegistry = AbilityRegistry.bind(catalog, bindings, status)
	if not status.is_ok() or not registry.is_initialized(): return false
	_content_catalog = catalog.copy(); _piece_identities = sorted; _base_body_stats = bases; _synergy_tally = tally; _modifier_resolver = resolver
	_piece_origins.clear()
	for identity: BattlePieceIdentity in sorted:
		if not identity.is_token(): _piece_origins.append(BattlePieceOrigin.create(identity.body_id(), identity.piece_numeric_id(), status))
	_content_fingerprint = catalog.fingerprint_bytes(); _ability_bindings.clear()
	for index: int in range(registry.binding_count()): _ability_bindings.append(registry.binding_at(index, status))
	return status.is_ok()


func apply_run_opening_status(player_body_ids: Array[int], status_numeric_id: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if status_numeric_id == 0: return true
	# BattleSetupBuilder resolves BATTLE_START before returning the playable
	# state, so run-opening boons attach at the resulting TURN_START boundary.
	if not _initialized or not _require_phase(Phase.TURN_START, SimStatus.Operation.RUN_BOON_APPLY, status) or not _content_catalog.is_initialized() or player_body_ids.is_empty():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_BOON, SimStatus.Operation.RUN_BOON_APPLY, status_numeric_id, player_body_ids.size())
		return false
	var content_status := ContentStatus.new(); var definition: StatusDefinition = _content_catalog.status_by_numeric_id(status_numeric_id, content_status)
	if not content_status.is_ok() or definition.duration_kind_id() != StatusDefinition.DurationKind.BATTLE or definition.modifier_count() < 1:
		status.fail(SimStatus.Code.INVALID_RUN_BOON, SimStatus.Operation.RUN_BOON_APPLY, status_numeric_id, 0); return false
	var candidate: BattleState = copy(status)
	if not status.is_ok(): return false
	var previous_body_id: int = 0
	for body_id: int in player_body_ids:
		var participant_index: int = candidate._find_participant(body_id)
		if body_id <= previous_body_id or participant_index < 0 or candidate._participants[participant_index].faction() != BattleParticipant.Faction.PLAYER:
			status.fail(SimStatus.Code.INVALID_RUN_BOON, SimStatus.Operation.RUN_BOON_APPLY, body_id, previous_body_id); return false
		if candidate._effect_apply_status_change(body_id, body_id, status_numeric_id, 1, status) <= 0: return false
		previous_body_id = body_id
	if not candidate._materialize_physical_stats(status): return false
	_assign_from(candidate)
	return true


func _dynamic_begin_transition() -> void:
	_dynamic_spawn_transition_count = 0; _dynamic_transform_body_ids.clear(); _zone_spawn_transition_count = 0


func _level_one_ability_ids(piece: PieceDefinition, status: SimStatus) -> Array[int]:
	var result: Array[int] = []; var content_status := ContentStatus.new(); var level: PieceLevelDefinition = piece.level_definition(1, content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, piece.numeric_id(), 1); return result
	for index: int in range(level.ability_ref_count()):
		var ref: ContentIdRef = level.ability_ref_at(index, content_status); result.append(ref.numeric_id())
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, piece.numeric_id(), 1)
	return result


func _effect_dynamic_spawn(owner_body_id: int, target_body_id: int, record: BattleTriggerRecord, effect: AbilityEffectDefinition, ordinal: int, status: SimStatus) -> bool:
	if not _content_catalog.is_initialized(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, owner_body_id, 0); return false
	var payload: SpawnPayloadDefinition = effect.spawn_payload(); var content_status := ContentStatus.new()
	var piece: PieceDefinition = _content_catalog.piece_by_numeric_id(payload.piece_ref().numeric_id(), content_status)
	if not content_status.is_ok() or not piece.spawnable(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, owner_body_id, payload.piece_ref().numeric_id()); return false
	var owner: SimBody = _world.body_by_id(owner_body_id, status); var position: FixVec2 = owner.position().add(payload.offset(), status)
	if not status.is_ok() or not _world.position_inside_boundary(position, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, owner_body_id, piece.numeric_id())
		return false
	var velocity: FixVec2 = FixVec2.zero()
	if effect.kind_id() == AbilityEffectDefinition.Kind.SPAWN_PROJECTILE:
		var direction: FixVec2
		if payload.direction_mode_id() == SpawnPayloadDefinition.DirectionMode.OWNER_VELOCITY: direction = owner.velocity()
		elif payload.direction_mode_id() == SpawnPayloadDefinition.DirectionMode.OWNER_TO_TARGET:
			direction = _world.body_by_id(target_body_id, status).position().sub(owner.position(), status)
		else: direction = record.vector()
		if not status.is_ok() or direction.is_zero():
			if status.is_ok(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, owner_body_id, payload.direction_mode_id())
			return false
		velocity = direction.normalized(status).scaled(payload.speed_raw(), status)
	var level: PieceLevelDefinition = piece.level_definition(1, content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, piece.numeric_id(), 1); return false
	var faction: int = BattleParticipant.Faction.NEUTRAL if piece.spawn_faction_mode_id() == PieceDefinition.SpawnFactionMode.NEUTRAL else _participant_faction(owner_body_id)
	if faction == BattleParticipant.Faction.INVALID: status.fail(SimStatus.Code.INVALID_SPAWN_REQUEST, SimStatus.Operation.BATTLE_DYNAMIC_SPAWN, owner_body_id, faction); return false
	var body_template: SimBody = SimBody.create_unassigned(position, velocity, level.radius_raw(), level.mass_raw(), status, level.friction_multiplier_raw(), piece.destructible())
	var participant_template: BattleParticipant = BattleParticipant.create_unassigned(faction, piece.has_turn(), faction == BattleParticipant.Faction.PLAYER and piece.has_turn(), piece.counts_for_victory(), level.speed_stat(), status)
	var combatant_template: BattleCombatant = null
	if piece.destructible(): combatant_template = BattleCombatant.create_unassigned(faction, level.max_hp(), level.attack(), level.critical_basis_points(), status)
	if not status.is_ok(): return false
	var request := DynamicSpawnRequest.new(); request.body_template = body_template; request.participant_template = participant_template; request.combatant_template = combatant_template
	request.piece_numeric_id = piece.numeric_id(); request.faction = faction; request.ability_numeric_ids = _level_one_ability_ids(piece, status); request.expire_kind_id = piece.expire_kind_id(); request.expire_value = piece.expire_value(); request.applied_turn_index = _turn_index
	request.cause_body_id = owner_body_id; request.event_type_id = effect.kind_id(); request.ordinal = ordinal
	return status.is_ok() and queue_dynamic_spawn(request, status)


func _effect_spawn_zone(owner_body_id: int, target_body_id: int, effect: AbilityEffectDefinition, ordinal: int, status: SimStatus) -> bool:
	var payload: ZoneSpawnPayloadDefinition = effect.zone_payload()
	var target: SimBody = _world.body_by_id(target_body_id, status)
	if not status.is_ok(): return false
	var origin: FixVec2 = target.position().add(payload.offset(), status)
	var vertices: Array[FixVec2] = []; var content_status := ContentStatus.new()
	for index: int in range(payload.vertex_count()):
		var vertex: FixVec2 = origin.add(payload.vertex_at(index, content_status), status)
		if not content_status.is_ok() or not status.is_ok() or not SimLimits.is_position_valid(vertex):
			if status.is_ok(): status.fail(SimStatus.Code.INVALID_MAP_DEFINITION, SimStatus.Operation.BATTLE_ZONE_SPAWN, target_body_id, index)
			return false
		vertices.append(vertex)
	var zone: SimZone = SimZone.create_unassigned(vertices, payload.friction_multiplier_raw(), payload.acceleration(), status, payload.flags())
	return status.is_ok() and queue_zone_spawn(zone, payload.duration_turns(), owner_body_id, effect.kind_id(), ordinal, status)


func _replace_bindings_for_piece(body_id: int, piece: PieceDefinition, status: SimStatus) -> void:
	_remove_ability_bindings(body_id)
	for ability_id: int in _level_one_ability_ids(piece, status): _ability_bindings.append(AbilityBinding.create(body_id, ability_id, status))
	_ability_bindings.sort_custom(func(a: AbilityBinding, b: AbilityBinding) -> bool: return a.owner_body_id() < b.owner_body_id() or (a.owner_body_id() == b.owner_body_id() and a.ability_numeric_id() < b.ability_numeric_id()))


func transform_body(body_id: int, piece: PieceDefinition, status: SimStatus) -> bool:
	if piece == null or not piece.is_initialized() or _dynamic_transform_body_ids.size() >= BattleLimits.TRANSFORM_MAX_PER_TRANSITION or _dynamic_transform_body_ids.has(body_id):
		status.fail(SimStatus.Code.TRANSFORM_LIMIT_EXCEEDED, SimStatus.Operation.BATTLE_TRANSFORM, body_id, _dynamic_transform_body_ids.size()); return false
	var identity_index: int = _find_identity(body_id)
	if identity_index < 0: status.fail(SimStatus.Code.INVALID_TRANSFORM_TARGET, SimStatus.Operation.BATTLE_TRANSFORM, body_id, piece.numeric_id()); return false
	var content_status := ContentStatus.new(); var current_piece: PieceDefinition = _content_catalog.piece_by_numeric_id(_piece_identities[identity_index].piece_numeric_id(), content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_TRANSFORM_TARGET, SimStatus.Operation.BATTLE_TRANSFORM, body_id, piece.numeric_id()); return false
	if not current_piece.transformable() or current_piece.numeric_id() == piece.numeric_id(): return true
	var level: PieceLevelDefinition = piece.level_definition(1, content_status)
	var combatant_index: int = _find_combatant(body_id); var participant_index: int = _find_participant(body_id); var base_index: int = _find_base_body_stats(body_id)
	if not content_status.is_ok() or combatant_index < 0 or participant_index < 0 or base_index < 0: status.fail(SimStatus.Code.INVALID_TRANSFORM_TARGET, SimStatus.Operation.BATTLE_TRANSFORM, body_id, piece.numeric_id()); return false
	var combatant: BattleCombatant = _combatants[combatant_index]
	var numerator: int = FixMath.multiply_int(level.max_hp(), combatant.current_hp(), status)
	var next_hp: int = maxi(1, FixMath.floor_div_int(numerator, combatant.max_hp(), status))
	_combatants[combatant_index] = combatant.with_transformed_stats(next_hp, level.max_hp(), level.attack(), level.critical_basis_points(), status)
	var participant: BattleParticipant = _participants[participant_index]; var next_ct: int = participant.ct()
	if participant.faction() != BattleParticipant.Faction.NEUTRAL and participant.ct() < BattleLimits.CT_THRESHOLD:
		var remaining: int = BattleLimits.CT_THRESHOLD - participant.ct()
		var old_time: int = FixMath.ceil_div_int(remaining, participant.speed_stat(), status); var new_time: int = FixMath.ceil_div_int(remaining, level.speed_stat(), status)
		var target_time: int = mini(old_time, new_time) if participant.faction() == BattleParticipant.Faction.PLAYER else maxi(old_time, new_time)
		next_ct = clampi(BattleLimits.CT_THRESHOLD - target_time * level.speed_stat(), 0, BattleLimits.CT_THRESHOLD)
	_participants[participant_index] = participant.with_speed_stat(level.speed_stat(), status).with_ct(next_ct, status)
	_piece_identities[identity_index] = _piece_identities[identity_index].with_piece_numeric_id(piece.numeric_id(), status)
	_base_body_stats[base_index] = BattleBaseBodyStats.create(body_id, level.mass_raw(), level.radius_raw(), level.friction_multiplier_raw(), status)
	_replace_bindings_for_piece(body_id, piece, status); _dynamic_transform_body_ids.append(body_id); _dynamic_transform_body_ids.sort()
	_modifier_resolver = ModifierResolver.build(_content_catalog, _piece_identities, _synergy_tally, status)
	if not status.is_ok() or not _materialize_physical_stats(status): return false
	if not _world.correct_body_overlap_once(body_id, status):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_TRANSFORM_REQUEST, SimStatus.Operation.BATTLE_TRANSFORM, body_id, piece.numeric_id())
		return false
	return true


func _effect_transform(body_id: int, effect: AbilityEffectDefinition, status: SimStatus) -> bool:
	var content_status := ContentStatus.new(); var piece: PieceDefinition = _content_catalog.piece_by_numeric_id(effect.transform_payload().piece_ref().numeric_id(), content_status)
	if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_TRANSFORM_TARGET, SimStatus.Operation.BATTLE_TRANSFORM, body_id, effect.transform_payload().piece_ref().numeric_id()); return false
	return transform_body(body_id, piece, status)


func attach(anchor_id: int, attached_id: int, payload: AttachPayloadDefinition, record: BattleTriggerRecord, status: SimStatus) -> bool:
	var offset: FixVec2 = payload.anchor_offset()
	if payload.anchor_mode_id() == AttachPayloadDefinition.AnchorMode.CONTACT_POINT:
		offset = record.position().sub(_world.body_by_id(anchor_id, status).position(), status)
	var link: SimLink = SimLink.create_unassigned(anchor_id, attached_id, payload.anchor_mode_id(), offset, payload.attach_distance_raw(), payload.inertia_basis_points(), payload.duration_turns(), _turn_index, status)
	if not status.is_ok() or _world.add_link(link, status) == 0: return false
	for body_id: int in [anchor_id, attached_id]:
		var expire_index: int = _find_expire_state(body_id)
		if expire_index >= 0 and _expire_states[expire_index].kind_id() == PieceDefinition.ExpireKind.ON_LINK_RELEASE and not _expire_states[expire_index].has_linked(): _expire_states[expire_index] = _expire_states[expire_index].with_has_linked(status)
	return status.is_ok()


func _effect_attach(owner_id: int, target_id: int, record: BattleTriggerRecord, effect: AbilityEffectDefinition, status: SimStatus) -> bool:
	var payload: AttachPayloadDefinition = effect.attach_payload()
	var anchor_id: int = owner_id if payload.owner_role_id() == AttachPayloadDefinition.LinkRole.ANCHOR else target_id
	var attached_id: int = target_id if payload.owner_role_id() == AttachPayloadDefinition.LinkRole.ANCHOR else owner_id
	return attach(anchor_id, attached_id, payload, record, status)


func _expire_collision_body(body_id: int, event_sequence: int, status: SimStatus) -> void:
	var index: int = _find_expire_state(body_id)
	if index < 0 or _expire_states[index].kind_id() != PieceDefinition.ExpireKind.AFTER_COLLISIONS: return
	if _expire_states[index].remaining() > 1:
		_expire_states[index] = _expire_states[index].with_remaining(_expire_states[index].remaining() - 1, status); return
	for pending: BattleMutationRequest in _pending:
		if pending.kind == BattleMutationRequest.Kind.REMOVE and pending.body_id == body_id: return
	queue_participant_removal(body_id, body_id, SimStatus.Operation.BATTLE_EXPIRE, event_sequence, status)


func _settle_link_release_expire(status: SimStatus) -> void:
	while status.is_ok():
		var removals: Array[int] = []
		for expire: ExpireState in _expire_states:
			if expire.kind_id() == PieceDefinition.ExpireKind.ON_LINK_RELEASE and expire.has_linked() and _world.link_count_for_body(expire.body_id()) == 0: removals.append(expire.body_id())
		if removals.is_empty(): return
		for body_id: int in removals:
			var lookup := SimStatus.new(); _world.body_by_id(body_id, lookup)
			if not lookup.is_ok(): continue
			_world.remove_body(body_id, status)
			if not status.is_ok(): return
		_consume_world_events(status)


func _expire_dynamic_turn_end(status: SimStatus) -> void:
	var completed_turn: int = maxi(0, _turn_index - 1)
	var removals: Array[int] = []
	for index: int in range(_expire_states.size()):
		var expire: ExpireState = _expire_states[index]
		if expire.kind_id() != PieceDefinition.ExpireKind.AFTER_TURNS or expire.applied_turn_index() >= completed_turn: continue
		if expire.remaining() <= 1: removals.append(expire.body_id())
		else: _expire_states[index] = expire.with_remaining(expire.remaining() - 1, status)
	var released: Array[int] = _world.expire_link_turns(completed_turn, status)
	for body_id: int in removals:
		if _find_participant(body_id) >= 0: queue_participant_removal(body_id, body_id, SimStatus.Operation.BATTLE_EXPIRE, completed_turn, status)
	if not released.is_empty(): _settle_link_release_expire(status)


func _expire_zone_turn_end(status: SimStatus) -> void:
	var completed_turn: int = maxi(0, _turn_index - 1)
	var survivors: Array[ZoneSpawnState] = []
	for zone_state: ZoneSpawnState in _zone_spawns:
		if zone_state.remaining_turns() == 0 or zone_state.applied_turn_index() >= completed_turn:
			survivors.append(zone_state.copy())
		elif zone_state.remaining_turns() <= 1:
			_world.remove_zone(zone_state.zone_id(), status)
			if not status.is_ok(): return
		else:
			survivors.append(zone_state.with_remaining(zone_state.remaining_turns() - 1, status))
			if not status.is_ok(): return
	_zone_spawns = survivors


func _dynamic_finish_transition(has_turn_end: bool, status: SimStatus) -> bool:
	if not _apply_barrier(status): return false
	if has_turn_end: _expire_dynamic_turn_end(status); _expire_zone_turn_end(status)
	if status.is_ok() and not _pending.is_empty() and not _apply_barrier(status): return false
	if status.is_ok(): _settle_link_release_expire(status)
	_dynamic_spawn_transition_count = 0; _dynamic_transform_body_ids.clear(); _zone_spawn_transition_count = 0
	return status.is_ok() and _pending.is_empty() and not _world.has_pending_requests()

func _materialize_physical_stats(status: SimStatus) -> bool:
	if not _modifier_resolver.is_initialized(): return true
	var next_world: SimWorld = _world._transaction_copy(status)
	for base_stats: BattleBaseBodyStats in _base_body_stats:
		var mass: int = EffectiveStats.resolve(base_stats.mass_raw(), _modifier_resolver.aggregate(base_stats.body_id(), ModifierKind.Value.MASS_RAW, _statuses, status), ModifierKind.Value.MASS_RAW, status)
		var radius: int = EffectiveStats.resolve(base_stats.radius_raw(), _modifier_resolver.aggregate(base_stats.body_id(), ModifierKind.Value.RADIUS_RAW, _statuses, status), ModifierKind.Value.RADIUS_RAW, status)
		var friction: int = EffectiveStats.resolve(base_stats.friction_multiplier_raw(), _modifier_resolver.aggregate(base_stats.body_id(), ModifierKind.Value.FRICTION_MULTIPLIER_RAW, _statuses, status), ModifierKind.Value.FRICTION_MULTIPLIER_RAW, status)
		next_world.set_body_physical_stats(base_stats.body_id(), radius, mass, friction, status)
		if not status.is_ok(): return false
	_world = next_world; return true

func _effect_apply_status(target_body_id: int, source_body_id: int, status_id: int, stacks: int, status: SimStatus) -> bool:
	return _effect_apply_status_change(target_body_id, source_body_id, status_id, stacks, status) > 0

func _effect_apply_status_change(target_body_id: int, source_body_id: int, status_id: int, stacks: int, status: SimStatus) -> int:
	if not _content_catalog.is_initialized() or _find_combatant(target_body_id) < 0: status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.STATUS_APPLY, target_body_id, status_id); return 0
	var cs := ContentStatus.new(); var definition: StatusDefinition = _content_catalog.status_by_numeric_id(status_id, cs)
	if not cs.is_ok(): status.fail(SimStatus.Code.INVALID_STATUS_DEFINITION, SimStatus.Operation.STATUS_APPLY, target_body_id, status_id); return 0
	var updated: bool = _statuses.would_update(definition, target_body_id, source_body_id)
	if not _statuses.apply(definition, target_body_id, source_body_id, stacks, _turn_index, status): return 0
	return 2 if updated else 1

func _effect_remove_status(target_body_id: int, status_id: int, stacks: int, status: SimStatus) -> int:
	if not _content_catalog.is_initialized(): status.fail(SimStatus.Code.INVALID_STATUS_DEFINITION, SimStatus.Operation.STATUS_REMOVE, target_body_id, status_id); return 0
	var cs := ContentStatus.new(); var definition: StatusDefinition = _content_catalog.status_by_numeric_id(status_id, cs)
	if not cs.is_ok(): status.fail(SimStatus.Code.INVALID_STATUS_DEFINITION, SimStatus.Operation.STATUS_REMOVE, target_body_id, status_id); return 0
	return _statuses.remove(target_body_id, status_id, stacks, status, definition)

func _effect_modify_stat(target_body_id: int, kind_id: int, delta: int, status: SimStatus) -> bool:
	if kind_id == ModifierKind.Value.SPEED_STAT:
		var index: int = _find_participant(target_body_id)
		if index < 0 or not FixMath.can_add_int(_participants[index].speed_stat(), delta): status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.EFFECT_APPLY, target_body_id, kind_id); return false
		var value: int = _participants[index].speed_stat() + delta
		if not BattleLimits.valid_base_speed(value): status.fail(SimStatus.Code.MODIFIER_RANGE_VIOLATION, SimStatus.Operation.EFFECT_APPLY, kind_id, value); return false
		_participants[index] = _participants[index].with_speed_stat(value, status); return status.is_ok()
	var combatant_index: int = _find_combatant(target_body_id)
	if combatant_index < 0: status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.EFFECT_APPLY, target_body_id, kind_id); return false
	var combatant: BattleCombatant = _combatants[combatant_index]; var attack: int = combatant.attack(); var critical: int = combatant.critical_basis_points()
	if kind_id == ModifierKind.Value.ATTACK:
		if not FixMath.can_add_int(attack, delta): status.fail(SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.EFFECT_APPLY); return false
		attack += delta
	elif kind_id == ModifierKind.Value.CRITICAL_BASIS_POINTS:
		if not FixMath.can_add_int(critical, delta): status.fail(SimStatus.Code.INT64_OVERFLOW, SimStatus.Operation.EFFECT_APPLY); return false
		critical += delta
	else: status.fail(SimStatus.Code.INVALID_MODIFIER_DEFINITION, SimStatus.Operation.EFFECT_APPLY, target_body_id, kind_id); return false
	if not DamageLimits.valid_stat(attack) or not DamageLimits.valid_critical_basis_points(critical): status.fail(SimStatus.Code.MODIFIER_RANGE_VIOLATION, SimStatus.Operation.EFFECT_APPLY, kind_id, attack if kind_id == ModifierKind.Value.ATTACK else critical); return false
	_combatants[combatant_index] = combatant.with_base_stats(attack, critical, status); return status.is_ok()

func _status_expire_turn_end(body_id: int, status: SimStatus) -> Array[int]:
	if not _content_catalog.is_initialized(): return [0, 0]
	# TURN_END records are resolved after complete_turn_end advances the global
	# index, so compare against the turn that just completed.
	return _statuses.expire_target_turn(body_id, maxi(0, _turn_index - 1), _content_catalog, status)

func is_initialized() -> bool: return _initialized
func phase() -> int: return _phase
func current_actor_body_id() -> int: return _current_actor_body_id
func abstract_time() -> int: return _abstract_time
func last_acted_faction() -> int: return _last_acted_faction
func participant_count() -> int: return _participants.size()
func participant_at(index: int, status: SimStatus) -> BattleParticipant:
	if index < 0 or index >= _participants.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_STATE_READ, index, _participants.size()); return BattleParticipant.new()
	return _participants[index].copy()
func participant_by_body_id(body_id: int, status: SimStatus) -> BattleParticipant:
	var index: int = _find_participant(body_id)
	if index < 0: status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_STATE_READ, body_id, 0); return BattleParticipant.new()
	return _participants[index].copy()
func combatant_count() -> int: return _combatants.size()
func combatant_at(index: int, status: SimStatus) -> BattleCombatant:
	if index < 0 or index >= _combatants.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_STATE_READ, index, _combatants.size()); return BattleCombatant.new()
	return _combatants[index].copy()
func combatant_by_body_id(body_id: int, status: SimStatus) -> BattleCombatant:
	var index: int = _find_combatant(body_id)
	if index < 0: status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_STATE_READ, body_id, 0); return BattleCombatant.new()
	return _combatants[index].copy()
func cooldown_count() -> int: return _cooldowns.size()
func cooldown_at(index: int, status: SimStatus) -> DamagePairCooldown:
	if index < 0 or index >= _cooldowns.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_STATE_READ, index, _cooldowns.size()); return DamagePairCooldown.new()
	return _cooldowns[index].copy()
func normal_resolve_ticks() -> int: return _normal_resolve_ticks
func forced_resolve_ticks() -> int: return _forced_resolve_ticks
func forced_settle_used() -> bool: return _forced_settle_used
func world_copy(status: SimStatus) -> SimWorld: return _world.copy(status)
func has_pending_mutations() -> bool: return not _pending.is_empty()
func battle_result() -> int: return _battle_result
func battle_result_report(status: SimStatus) -> BattleResult: return BattleResult.create(_battle_result, _piece_origins, status)
func next_trigger_sequence() -> int: return _next_trigger_sequence
func trigger_record_count() -> int: return _last_trigger_batch.size()
func trigger_record_at(index: int, status: SimStatus) -> BattleTriggerRecord:
	if index < 0 or index >= _last_trigger_batch.size():
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_TRIGGER_READ, index, _last_trigger_batch.size()); return BattleTriggerRecord.new()
	return _last_trigger_batch[index].copy()
func motion_credit_count() -> int: return _motion_credits.size()
func motion_credit_at(index: int, status: SimStatus) -> BattleMotionCredit:
	if index < 0 or index >= _motion_credits.size():
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_MOTION_CREDIT, index, _motion_credits.size()); return BattleMotionCredit.new()
	return _motion_credits[index].copy()

func content_fingerprint_bytes() -> PackedByteArray: return _content_fingerprint.duplicate()
func ability_binding_count() -> int: return _ability_bindings.size()
func ability_binding_at(index: int, status: SimStatus) -> AbilityBinding:
	if index < 0 or index >= _ability_bindings.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.ABILITY_BIND, index, _ability_bindings.size()); return AbilityBinding.new()
	return _ability_bindings[index].copy()
func ability_registry(status: SimStatus) -> AbilityRegistry:
	if not _content_catalog.is_initialized(): status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.ABILITY_BIND); return AbilityRegistry.new()
	return AbilityRegistry.bind(_content_catalog, _ability_bindings, status)
func ability_registry_matches(registry: AbilityRegistry, status: SimStatus) -> bool:
	if registry == null or not registry.is_initialized() or registry.binding_count() != _ability_bindings.size(): return false
	for index: int in range(_ability_bindings.size()):
		var other: AbilityBinding = registry.binding_at(index, status)
		if not status.is_ok() or other.owner_body_id() != _ability_bindings[index].owner_body_id() or other.ability_numeric_id() != _ability_bindings[index].ability_numeric_id(): return false
	return registry.fingerprint_bytes() == _content_fingerprint
func next_effect_sequence() -> int: return _next_effect_sequence
func turn_index() -> int: return _turn_index
func status_count() -> int: return _statuses.count()
func status_at(index: int, status: SimStatus) -> StatusInstance: return _statuses.item_at(index, status)
func next_status_sequence() -> int: return _statuses.next_sequence()
func piece_identity_count() -> int: return _piece_identities.size()
func piece_identity_at(index: int, status: SimStatus) -> BattlePieceIdentity:
	if index < 0 or index >= _piece_identities.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, index, _piece_identities.size()); return BattlePieceIdentity.new()
	return _piece_identities[index].copy()
func synergy_tally_copy() -> SynergyTally: return _synergy_tally.copy()
func base_body_stats_count() -> int: return _base_body_stats.size()
func base_body_stats_at(index: int, status: SimStatus) -> BattleBaseBodyStats:
	if index < 0 or index >= _base_body_stats.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_PHYSICAL_STATS_APPLY, index, _base_body_stats.size()); return BattleBaseBodyStats.new()
	return _base_body_stats[index].copy()
func expire_state_count() -> int: return _expire_states.size()
func expire_state_at(index: int, status: SimStatus) -> ExpireState:
	if index < 0 or index >= _expire_states.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_EXPIRE, index, _expire_states.size()); return ExpireState.new()
	return _expire_states[index].copy()
func piece_origin_count() -> int: return _piece_origins.size()
func piece_origin_at(index: int, status: SimStatus) -> BattlePieceOrigin:
	if index < 0 or index >= _piece_origins.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, index, _piece_origins.size()); return BattlePieceOrigin.new()
	return _piece_origins[index].copy()
func kill_tally_count() -> int: return _kill_tallies.size()
func kill_tally_at(index: int, status: SimStatus) -> BattleKillTally:
	if index < 0 or index >= _kill_tallies.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_KILL_TALLY_UPDATE, index, _kill_tallies.size()); return BattleKillTally.new()
	return _kill_tallies[index].copy()
func kill_count_for_body(body_id: int) -> int:
	for tally: BattleKillTally in _kill_tallies:
		if tally.body_id() == body_id: return tally.kill_count()
		if tally.body_id() > body_id: break
	return 0
func runtime_spawn_count() -> int: return _runtime_spawn_count
func zone_spawn_count() -> int: return _zone_spawns.size()
func zone_spawn_at(index: int, status: SimStatus) -> ZoneSpawnState:
	if index < 0 or index >= _zone_spawns.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_ZONE_SPAWN, index, _zone_spawns.size()); return ZoneSpawnState.new()
	return _zone_spawns[index].copy()
func link_collection_copy(status: SimStatus) -> AttachLinkCollection: return AttachLinkCollection.from_world(_world, status)

func _effect_restore_content(fingerprint: PackedByteArray, bindings: Array[AbilityBinding], next_sequence: int, status: SimStatus) -> bool:
	if fingerprint.size() != 32 or next_sequence < 1:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, fingerprint.size(), next_sequence); return false
	var previous_owner: int = 0; var previous_ability: int = 0
	var copied: Array[AbilityBinding] = []
	for binding: AbilityBinding in bindings:
		if binding == null or not binding.is_initialized() or binding.owner_body_id() < previous_owner or (binding.owner_body_id() == previous_owner and binding.ability_numeric_id() <= previous_ability):
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, 0 if binding == null else binding.owner_body_id(), 0 if binding == null else binding.ability_numeric_id()); return false
		copied.append(binding.copy()); previous_owner = binding.owner_body_id(); previous_ability = binding.ability_numeric_id()
	_content_fingerprint = fingerprint.duplicate(); _ability_bindings = copied; _next_effect_sequence = next_sequence
	return true

func _status_restore_snapshot(turn_index: int, identities: Array[BattlePieceIdentity], tally: SynergyTally, statuses: Array[StatusInstance], next_status_sequence: int, bases: Array[BattleBaseBodyStats], status: SimStatus) -> bool:
	if turn_index < 0 or tally == null: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, turn_index, 0); return false
	var collection := StatusCollection.new()
	if not collection.restore(statuses, next_status_sequence, status): return false
	_piece_identities.clear(); _base_body_stats.clear(); var previous: int = 0
	for identity: BattlePieceIdentity in identities:
		if identity == null or not identity.is_initialized() or identity.body_id() <= previous: status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE); return false
		_piece_identities.append(identity.copy()); previous = identity.body_id()
	previous = 0
	for base_stats: BattleBaseBodyStats in bases:
		if base_stats == null or not base_stats.is_initialized() or base_stats.body_id() <= previous: status.fail(SimStatus.Code.MODIFIER_RANGE_VIOLATION, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE); return false
		_base_body_stats.append(base_stats.copy()); previous = base_stats.body_id()
	_turn_index = turn_index; _synergy_tally = tally.copy(); _statuses = collection; return true

func _dynamic_restore_snapshot(expire_states: Array[ExpireState], origins: Array[BattlePieceOrigin], runtime_spawn_count: int, status: SimStatus) -> bool:
	if runtime_spawn_count < 0 or runtime_spawn_count > BattleLimits.RUNTIME_SPAWN_MAX_BODIES:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, runtime_spawn_count, BattleLimits.RUNTIME_SPAWN_MAX_BODIES); return false
	var previous: int = 0; _expire_states.clear()
	for expire: ExpireState in expire_states:
		if expire == null or not expire.is_initialized() or expire.body_id() <= previous:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, 0 if expire == null else expire.body_id(), previous); return false
		_expire_states.append(expire.copy()); previous = expire.body_id()
	previous = 0; _piece_origins.clear()
	for origin: BattlePieceOrigin in origins:
		if origin == null or not origin.is_initialized() or origin.body_id() <= previous:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, 0 if origin == null else origin.body_id(), previous); return false
		_piece_origins.append(origin.copy()); previous = origin.body_id()
	_runtime_spawn_count = runtime_spawn_count; return true


func _zone_restore_snapshot(zone_spawns: Array[ZoneSpawnState], status: SimStatus) -> bool:
	if zone_spawns.size() > BattleLimits.ZONE_SPAWN_MAX_PER_BATTLE or _world.zone_count() > BattleLimits.ZONE_TOTAL_MAX:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, zone_spawns.size(), _world.zone_count()); return false
	var existing: Dictionary = {}
	for index: int in range(_world.zone_count()): existing[_world.zone_at(index, status).id()] = true
	var previous: int = 0; _zone_spawns.clear()
	for zone_state: ZoneSpawnState in zone_spawns:
		if zone_state == null or not zone_state.is_initialized() or zone_state.zone_id() <= previous or zone_state.applied_turn_index() > _turn_index or not existing.has(zone_state.zone_id()):
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, 0 if zone_state == null else zone_state.zone_id(), previous); return false
		_zone_spawns.append(zone_state.copy()); previous = zone_state.zone_id()
	return status.is_ok()

func _kill_tally_restore_snapshot(tallies: Array[BattleKillTally], status: SimStatus) -> bool:
	if tallies.size() > _piece_origins.size():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_KILL_TALLY_UPDATE, tallies.size(), _piece_origins.size()); return false
	var previous: int = 0; _kill_tallies.clear()
	for tally: BattleKillTally in tallies:
		if tally == null or not tally.is_initialized() or tally.body_id() <= previous or not _has_piece_origin(tally.body_id()):
			status.fail(SimStatus.Code.INVALID_BATTLE_KILL_TALLY, SimStatus.Operation.BATTLE_KILL_TALLY_UPDATE, 0 if tally == null else tally.body_id(), previous); return false
		_kill_tallies.append(tally.copy()); previous = tally.body_id()
	return true

func _status_bind_restored_catalog(catalog: ContentCatalog, status: SimStatus) -> bool:
	if catalog == null or not catalog.is_initialized() or catalog.fingerprint_bytes() != _content_fingerprint:
		status.fail(SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE); return false
	_content_catalog = catalog.copy(); _modifier_resolver = ModifierResolver.build(_content_catalog, _piece_identities, _synergy_tally, status); return status.is_ok()

func _effect_restore_triggers(records: Array[BattleTriggerRecord], next_sequence: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if next_sequence < 1 or not UInt32Math.is_u32(next_sequence) or records.size() > BattleLimits.TRIGGER_MAX_RECORDS:
		status.fail(SimStatus.Code.INVALID_TRIGGER_RECORD, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, next_sequence, records.size()); return false
	var copied: Array[BattleTriggerRecord] = []; var previous_wave: int = -1; var previous_sequence: int = 0
	for record: BattleTriggerRecord in records:
		if record == null or not record.is_initialized() or record.wave() < previous_wave or (record.wave() == previous_wave and record.sequence() <= previous_sequence):
			status.fail(SimStatus.Code.INVALID_TRIGGER_RECORD, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION, previous_sequence, 0); return false
		copied.append(record.copy()); previous_wave = record.wave(); previous_sequence = record.sequence()
	_last_trigger_batch = copied; _next_trigger_sequence = next_sequence
	return true


## P2 effect transaction helpers. EffectResolver operates on a deep state copy
## and commits through _assign_from only after every application succeeds.
func _effect_set_hp(body_id: int, value: int, source_body_id: int, status: SimStatus) -> bool:
	var index: int = _find_combatant(body_id)
	if index < 0 or source_body_id == 0:
		status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.EFFECT_APPLY, body_id, source_body_id); return false
	var combatant: BattleCombatant = _combatants[index]
	if value < 0 or value > combatant.max_hp():
		status.fail(SimStatus.Code.EFFECT_APPLICATION_FAILED, SimStatus.Operation.EFFECT_APPLY, body_id, value); return false
	_combatants[index] = combatant.with_current_hp(value, status)
	if status.is_ok() and value == 0:
		_world.destroy_body(body_id, source_body_id, status)
		while status.is_ok() and _world.event_cursor() < _world.event_count():
			var event: SimEvent = _world.consume_next_event(status)
			if event.type_id() == SimEvent.TypeId.BODY_DESTROYED: _process_destroy_event(event, status)
	return status.is_ok()


func _effect_set_ct(body_id: int, value: int, status: SimStatus) -> bool:
	var index: int = _find_participant(body_id)
	if index < 0 or not _participants[index].has_turn() or value < 0 or value > BattleLimits.EFFECT_CT_MAX:
		status.fail(SimStatus.Code.INVALID_EFFECT_TARGET, SimStatus.Operation.EFFECT_APPLY, body_id, value); return false
	_participants[index] = _participants[index].with_ct(value, status)
	return status.is_ok()


func _effect_set_velocity(body_id: int, velocity: FixVec2, status: SimStatus) -> bool:
	if velocity == null or not SimLimits.is_launch_speed_valid(velocity, status):
		if status.is_ok(): status.fail(SimStatus.Code.EFFECT_APPLICATION_FAILED, SimStatus.Operation.EFFECT_APPLY, body_id, 0)
		return false
	_world.set_body_velocity(body_id, velocity, status)
	return status.is_ok()


func _effect_commit_from(resolved: BattleState, status: SimStatus) -> bool:
	if not status.is_ok() or resolved == null or not resolved.is_initialized():
		if status.is_ok(): status.fail(SimStatus.Code.EFFECT_APPLICATION_FAILED, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION)
		return false
	_assign_from(resolved)
	return true
