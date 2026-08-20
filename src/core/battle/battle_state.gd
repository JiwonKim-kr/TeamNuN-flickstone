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
var _world: SimWorld = SimWorld.new()
var _pending: Array[BattleMutationRequest] = []
var _normal_resolve_ticks: int = 0
var _forced_resolve_ticks: int = 0
var _forced_settle_used: bool = false


static func _participant_less(left: BattleParticipant, right: BattleParticipant) -> bool:
	return left.body_id() < right.body_id()


static func _request_less(left: BattleMutationRequest, right: BattleMutationRequest) -> bool:
	if left.tick != right.tick: return left.tick < right.tick
	if left.cause_body_id != right.cause_body_id: return left.cause_body_id < right.cause_body_id
	if left.event_type_id != right.event_type_id: return left.event_type_id < right.event_type_id
	return left.ordinal < right.ordinal


static func _copy_participants(source: Array[BattleParticipant]) -> Array[BattleParticipant]:
	var result: Array[BattleParticipant] = []
	for item: BattleParticipant in source: result.append(item.copy())
	return result


static func _copy_pending(source: Array[BattleMutationRequest]) -> Array[BattleMutationRequest]:
	var result: Array[BattleMutationRequest] = []
	for item: BattleMutationRequest in source: result.append(item.copy())
	return result


static func create(world: SimWorld, participants: Array[BattleParticipant], status: SimStatus) -> BattleState:
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
	state._world = world.copy(status)
	if not status.is_ok(): return BattleState.new()
	state._participants = sorted
	state._phase = Phase.BATTLE_START
	state._initialized = true
	return state


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
	var state := BattleState.new()
	if not status.is_ok() or world == null or abstract_time < 0:
		return state
	state._world = world.copy(status)
	state._participants = _copy_participants(participants)
	state._phase = phase
	state._current_actor_body_id = current_actor
	state._abstract_time = abstract_time
	state._last_acted_faction = last_faction
	state._normal_resolve_ticks = normal_ticks
	state._forced_resolve_ticks = forced_ticks
	state._forced_settle_used = forced_used
	state._initialized = status.is_ok()
	if not state._validate(status): return BattleState.new()
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


func _select_actor(status: SimStatus) -> bool:
	var selection: CtbScheduler.Selection = CtbScheduler.select_next(_participants, _abstract_time, _last_acted_faction, status)
	if not status.is_ok(): return false
	_participants = selection.participants
	_abstract_time = selection.abstract_time
	_current_actor_body_id = _participants[selection.actor_index].body_id()
	_phase = Phase.TURN_START
	return true


func _consume_world_events(status: SimStatus) -> void:
	while status.is_ok() and _world.event_cursor() < _world.event_count():
		var event: SimEvent = _world.consume_next_event(status)
		if not status.is_ok(): return
		if event.type_id() == SimEvent.TypeId.BODY_REMOVED or event.type_id() == SimEvent.TypeId.BODY_DESTROYED:
			var index: int = _find_participant(event.source_body_id())
			if index >= 0: _participants.remove_at(index)


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
		else:
			_world.remove_body(request.body_id, status)
			if status.is_ok():
				var index: int = _find_participant(request.body_id)
				if index >= 0: _participants.remove_at(index)
				_consume_world_events(status)
		if not status.is_ok(): break
	if status.is_ok():
		_pending.clear()
		_consume_world_events(status)
		return status.is_ok()
	_assign_from(backup)
	return false


func queue_body_spawn(body_template: SimBody, participant_template: BattleParticipant, cause_body_id: int, event_type_id: int, ordinal: int, status: SimStatus) -> bool:
	if not status.is_ok() or body_template == null or body_template.id() != 0 or (participant_template != null and participant_template.body_id() != 0):
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_QUEUE_MUTATION, cause_body_id, ordinal)
		return false
	return _queue_request(BattleMutationRequest.Kind.SPAWN, 0, body_template, participant_template, cause_body_id, event_type_id, ordinal, status)


func queue_participant_removal(body_id: int, cause_body_id: int, event_type_id: int, ordinal: int, status: SimStatus) -> bool:
	if _find_participant(body_id) < 0:
		status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_QUEUE_MUTATION, body_id, 0)
		return false
	return _queue_request(BattleMutationRequest.Kind.REMOVE, body_id, null, null, cause_body_id, event_type_id, ordinal, status)


func _queue_request(kind: int, body_id: int, body_template: SimBody, participant_template: BattleParticipant, cause_body_id: int, event_type_id: int, ordinal: int, status: SimStatus) -> bool:
	if not status.is_ok() or not UInt32Math.is_u32(cause_body_id) or event_type_id < 0 or event_type_id > 0xFFFF or not UInt32Math.is_u32(ordinal): return false
	for prior: BattleMutationRequest in _pending:
		if prior.tick == _world.tick() and prior.cause_body_id == cause_body_id and prior.event_type_id == event_type_id and prior.ordinal == ordinal:
			status.fail(SimStatus.Code.DUPLICATE_ID, SimStatus.Operation.BATTLE_QUEUE_MUTATION, cause_body_id, ordinal)
			return false
	var request := BattleMutationRequest.new()
	request.kind = kind; request.tick = _world.tick(); request.body_id = body_id
	request.body_template = null if body_template == null else body_template.copy()
	request.participant_template = null if participant_template == null else participant_template.copy()
	request.cause_body_id = cause_body_id; request.event_type_id = event_type_id; request.ordinal = ordinal
	_pending.append(request)
	return true


func complete_battle_start(status: SimStatus) -> bool:
	if not _require_phase(Phase.BATTLE_START, SimStatus.Operation.BATTLE_START_COMPLETE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	if _apply_barrier(status) and _select_actor(status): return true
	_assign_from(backup)
	return false


func complete_turn_start(status: SimStatus) -> bool:
	if not _require_phase(Phase.TURN_START, SimStatus.Operation.BATTLE_TURN_START_COMPLETE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	if not _apply_barrier(status): _assign_from(backup); return false
	if _find_participant(_current_actor_body_id) < 0:
		status.fail(SimStatus.Code.NOT_FOUND, SimStatus.Operation.BATTLE_TURN_START_COMPLETE, _current_actor_body_id, 0)
		_assign_from(backup)
		return false
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
	var next_world: SimWorld = _world.copy(status)
	next_world.set_body_velocity(_current_actor_body_id, launch_velocity, status)
	if not status.is_ok() or not _consume_actor(status): return false
	_world = next_world
	_normal_resolve_ticks = 0; _forced_resolve_ticks = 0; _forced_settle_used = false
	_phase = Phase.RESOLVE
	return true


func commit_forced_no_launch(status: SimStatus) -> bool:
	if _phase != Phase.TURN_START and _phase != Phase.AIM:
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_ACTION_COMMIT, _phase, (1 << Phase.TURN_START) | (1 << Phase.AIM))
		return false
	var backup: BattleState = copy(SimStatus.new())
	if not _apply_barrier(status) or not _consume_actor(status): _assign_from(backup); return false
	_normal_resolve_ticks = 0; _forced_resolve_ticks = 0; _forced_settle_used = false
	_phase = Phase.TURN_END if _world.is_quiescent(SimWorld.ContinuousAccelerationMode.APPLY, status) else Phase.RESOLVE
	return status.is_ok()


func interrupt_missing_current_actor(status: SimStatus) -> bool:
	if _phase != Phase.TURN_START and _phase != Phase.AIM:
		status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_ACTOR_INTERRUPT, _phase, 0)
		return false
	var backup: BattleState = copy(SimStatus.new())
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
	return status.is_ok()


func advance_resolve(status: SimStatus) -> bool:
	if not _require_phase(Phase.RESOLVE, SimStatus.Operation.BATTLE_RESOLVE_ADVANCE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	var mode: int = SimWorld.ContinuousAccelerationMode.SUPPRESS if _forced_settle_used else SimWorld.ContinuousAccelerationMode.APPLY
	if (not _forced_settle_used or _forced_resolve_ticks > 0) and _world.is_quiescent(mode, status) and _pending.is_empty() and _world.event_cursor() == _world.event_count():
		_phase = Phase.TURN_END
		return true
	if _forced_settle_used and _forced_resolve_ticks >= BattleLimits.FORCED_RESOLVE_MAX_TICKS:
		var blocker: int = 0
		for index: int in range(_world.body_count()):
			var body: SimBody = _world.body_at(index, status)
			if not body.velocity().is_zero(): blocker = body.id(); break
		status.fail(SimStatus.Code.RESOLVE_DEADLOCK, SimStatus.Operation.BATTLE_RESOLVE_ADVANCE, blocker, _normal_resolve_ticks + _forced_resolve_ticks)
		return false
	var next_world: SimWorld = _world.copy(status)
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
		return status.is_ok()
	mode = SimWorld.ContinuousAccelerationMode.SUPPRESS if _forced_settle_used else SimWorld.ContinuousAccelerationMode.APPLY
	if _world.is_quiescent(mode, status) and _pending.is_empty() and _world.event_cursor() == _world.event_count(): _phase = Phase.TURN_END
	return status.is_ok()


func complete_turn_end(status: SimStatus) -> bool:
	if not _require_phase(Phase.TURN_END, SimStatus.Operation.BATTLE_TURN_END_COMPLETE, status): return false
	var backup: BattleState = copy(SimStatus.new())
	if not _apply_barrier(status): _assign_from(backup); return false
	_phase = Phase.CHECK
	return true


func apply_check_directive(directive: int, status: SimStatus) -> bool:
	if not _require_phase(Phase.CHECK, SimStatus.Operation.BATTLE_CHECK_APPLY, status): return false
	if directive != CheckDirective.CONTINUE and directive != CheckDirective.END:
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_CHECK_APPLY, directive, 0)
		return false
	var backup: BattleState = copy(SimStatus.new())
	if not _apply_barrier(status): _assign_from(backup); return false
	if directive == CheckDirective.END:
		_current_actor_body_id = 0; _phase = Phase.BATTLE_END
		return true
	_current_actor_body_id = 0
	if _select_actor(status): return true
	_assign_from(backup)
	return false


func preview(count: int, status: SimStatus) -> Array[CtbPreviewEntry]:
	if not _initialized:
		status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.CTB_PREVIEW, 0, 0); return []
	if count < 1 or count > BattleLimits.PREVIEW_MAX_COUNT:
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.CTB_PREVIEW, count, BattleLimits.PREVIEW_MAX_COUNT)
		return []
	if _phase == Phase.BATTLE_END: return []
	var local: Array[BattleParticipant] = _copy_participants(_participants)
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
	result._participants = _copy_participants(_participants); result._world = _world.copy(status)
	result._pending = _copy_pending(_pending); result._normal_resolve_ticks = _normal_resolve_ticks
	result._forced_resolve_ticks = _forced_resolve_ticks; result._forced_settle_used = _forced_settle_used
	return result


func _assign_from(other: BattleState) -> void:
	_initialized = other._initialized; _phase = other._phase; _current_actor_body_id = other._current_actor_body_id
	_abstract_time = other._abstract_time; _last_acted_faction = other._last_acted_faction
	_participants = other._participants; _world = other._world; _pending = other._pending
	_normal_resolve_ticks = other._normal_resolve_ticks; _forced_resolve_ticks = other._forced_resolve_ticks
	_forced_settle_used = other._forced_settle_used


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
func normal_resolve_ticks() -> int: return _normal_resolve_ticks
func forced_resolve_ticks() -> int: return _forced_resolve_ticks
func forced_settle_used() -> bool: return _forced_settle_used
func world_copy(status: SimStatus) -> SimWorld: return _world.copy(status)
func has_pending_mutations() -> bool: return not _pending.is_empty()
