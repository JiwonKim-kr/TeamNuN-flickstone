extends SceneTree

const SimStatusScript := preload("res://src/core/sim/sim_status.gd")
const FixMathScript := preload("res://src/core/sim/fix_math.gd")
const FixVec2Script := preload("res://src/core/sim/fix_vec2.gd")
const SimBodyScript := preload("res://src/core/sim/sim_body.gd")
const SimEventScript := preload("res://src/core/sim/sim_event.gd")
const SimWorldScript := preload("res://src/core/sim/sim_world.gd")
const SimSnapshotScript := preload("res://src/core/sim/sim_snapshot.gd")
const BattleLimitsScript := preload("res://src/core/battle/battle_limits.gd")
const BattleParticipantScript := preload("res://src/core/battle/battle_participant.gd")
const CtbPreviewEntryScript := preload("res://src/core/battle/ctb_preview_entry.gd")
const CtbSchedulerScript := preload("res://src/core/battle/ctb_scheduler.gd")
const BattleMutationRequestScript := preload("res://src/core/battle/battle_mutation_request.gd")
const BattleStateScript := preload("res://src/core/battle/battle_state.gd")
const BattleSnapshotScript := preload("res://src/core/battle/battle_snapshot.gd")

var _failures: int = 0

func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition: print("[PASS] %s" % case_id); return
	_failures += 1
	print("[FAIL] %s %s" % [case_id, detail])

func _body(x: int, status: SimStatus) -> SimBody:
	return SimBody.create_unassigned(FixVec2.from_ints(x, 0, status), FixVec2.zero(), 8 * FixMath.SCALE, 64 * FixMath.SCALE, status)

func _world(count: int, status: SimStatus) -> SimWorld:
	var world: SimWorld = SimWorld.create(1, 2, status)
	var keys: Array[int] = []
	var bodies: Array[SimBody] = []
	for index: int in range(count): keys.append(index + 1); bodies.append(_body(index * 32, status))
	world.add_initial_bodies(keys, bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	return world

func _frictionless_world(status: SimStatus) -> SimWorld:
	var world: SimWorld = SimWorld.create(3, 4, status, 0)
	var keys: Array[int] = [1]
	var bodies: Array[SimBody] = [_body(0, status)]
	world.add_initial_bodies(keys, bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	return world

func _participants(count: int, status: SimStatus) -> Array[BattleParticipant]:
	var result: Array[BattleParticipant] = []
	for index: int in range(count):
		var faction: int = BattleParticipant.Faction.PLAYER if index % 2 == 0 else BattleParticipant.Faction.ENEMY
		result.append(BattleParticipant.create(index + 1, faction, true, faction == BattleParticipant.Faction.PLAYER, true, 100, status))
	return result

func _test_enums_and_scheduler() -> void:
	_check("P1-ENUM-001", BattleState.Phase.BATTLE_END == 7 and SimStatus.Operation.BATTLE_SNAPSHOT_RESTORE == 82)
	var status := SimStatus.new()
	var tied: Array[BattleParticipant] = []
	for body_id: int in range(1, 7):
		var faction: int = BattleParticipant.Faction.PLAYER if body_id <= 3 else BattleParticipant.Faction.ENEMY
		tied.append(BattleParticipant.restore(body_id, faction, true, faction == BattleParticipant.Faction.PLAYER, true, 100, 10000, status))
	var order: Array[int] = []
	var last: int = BattleParticipant.Faction.INVALID
	for index: int in range(6):
		var selection: CtbScheduler.Selection = CtbScheduler.select_next(tied, 0, last, status)
		var actor: BattleParticipant = selection.participants[selection.actor_index]
		order.append(actor.body_id()); last = actor.faction()
		selection.participants[selection.actor_index] = actor.with_ct(actor.ct() - BattleLimits.CT_THRESHOLD, status)
		tied = selection.participants
	_check("P1-CTB-TIE-001", order == [1, 4, 2, 5, 3, 6], str(order))

func _test_state_preview_and_snapshot() -> void:
	var status := SimStatus.new()
	var state: BattleState = BattleState.create(_world(2, status), _participants(2, status), status)
	_check("P1-STATE-CREATE-001", status.is_ok() and state.phase() == BattleState.Phase.BATTLE_START)
	state.complete_battle_start(status)
	_check("P1-STATE-ACTOR-001", status.is_ok() and state.current_actor_body_id() == 1 and state.abstract_time() == 100)
	var before: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var preview: Array[CtbPreviewEntry] = state.preview(10, status)
	var after: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	_check("P1-PREVIEW-PURE-001", status.is_ok() and preview.size() == 10 and before == after)
	var restored: BattleState = BattleSnapshot.decode(before, status).restore_state(status)
	var roundtrip: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	_check("P1-SNAPSHOT-ROUNDTRIP-001", status.is_ok() and before == roundtrip)
	state.complete_turn_start(status)
	var actor_before: int = state.current_actor_body_id()
	state.cancel_aim(status)
	_check("P1-AIM-CANCEL-001", status.is_ok() and state.phase() == BattleState.Phase.AIM and state.current_actor_body_id() == actor_before)
	state.commit_forced_no_launch(status)
	_check("P1-NOLAUNCH-001", status.is_ok() and state.phase() == BattleState.Phase.TURN_END)
	state.complete_turn_end(status); state.apply_check_directive(BattleState.CheckDirective.CONTINUE, status)
	_check("P1-CHECK-CONTINUE-001", status.is_ok() and state.phase() == BattleState.Phase.TURN_START and state.current_actor_body_id() == 2)

func _test_sim_snapshot_decode() -> void:
	var status := SimStatus.new()
	var encoded: PackedByteArray = SimSnapshot.capture(_world(1, status), status).encode(status)
	var decoded: SimSnapshot = SimSnapshot.decode(encoded, status)
	_check("P1-SIM-DECODE-001", status.is_ok() and decoded.encode(status) == encoded)
	var trailing: PackedByteArray = encoded.duplicate(); trailing.append(0)
	var bad := SimStatus.new(); SimSnapshot.decode(trailing, bad)
	_check("P1-SIM-DECODE-TRAILING-001", not bad.is_ok())

func _test_launch_resolve_and_mutation() -> void:
	var status := SimStatus.new()
	var initial: Array[BattleParticipant] = _participants(2, status)
	initial[0] = BattleParticipant.restore(1, BattleParticipant.Faction.PLAYER, true, true, true, 100, BattleLimits.CT_THRESHOLD, status)
	var state: BattleState = BattleState.create(_world(2, status), initial, status)
	var spawned_participant: BattleParticipant = BattleParticipant.create_unassigned(
		BattleParticipant.Faction.PLAYER, true, true, true, 125, status
	)
	state.queue_body_spawn(_body(96, status), spawned_participant, 2, 7, 2, status)
	state.queue_body_spawn(_body(64, status), null, 1, 7, 1, status)
	state.complete_battle_start(status)
	var added: BattleParticipant = state.participant_by_body_id(4, status)
	var mutated_world: SimWorld = state.world_copy(status)
	var runtime_event: SimEvent = mutated_world.event_at(mutated_world.event_count() - 1, status)
	_check(
		"P1-MUTATION-CORRELATION-001",
		status.is_ok()
		and mutated_world.body_count() == 4
		and state.participant_count() == 3
		and added.ct() == 0
		and runtime_event.source_body_id() == 4
		and runtime_event.target_body_id() == 2
		and runtime_event.value_a() == 7
		and runtime_event.value_b() == 2
		and (runtime_event.flags() & SimEvent.FLAG_RUNTIME_SPAWN_KEY_PRESENT) != 0,
		"status=%d bodies=%d participants=%d id=%d target=%d a=%d b=%d flags=%d" % [status.code(), mutated_world.body_count(), state.participant_count(), runtime_event.source_body_id(), runtime_event.target_body_id(), runtime_event.value_a(), runtime_event.value_b(), runtime_event.flags()]
	)
	state.complete_turn_start(status)
	state.commit_launch_velocity(FixVec2.from_ints(1, 0, status), status)
	var calls: int = 0
	while status.is_ok() and state.phase() == BattleState.Phase.RESOLVE and calls < 1000:
		state.advance_resolve(status)
		calls += 1
	_check("P1-RESOLVE-NORMAL-001", status.is_ok() and state.phase() == BattleState.Phase.TURN_END and calls > 0 and calls < 960, str(calls))

func _test_rejections_are_stable() -> void:
	var status := SimStatus.new()
	var state: BattleState = BattleState.create(_world(2, status), _participants(2, status), status)
	var before: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var failure := SimStatus.new()
	state.commit_launch_velocity(FixVec2.from_ints(1, 0, failure), failure)
	var after: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	_check("P1-PHASE-ROLLBACK-001", not failure.is_ok() and before == after)
	var pending_status := SimStatus.new()
	state.queue_body_spawn(_body(96, pending_status), null, 1, 8, 1, pending_status)
	var rejected: BattleSnapshot = BattleSnapshot.capture(state, pending_status)
	_check("P1-SNAPSHOT-PENDING-001", not pending_status.is_ok() and not rejected.is_initialized())

func _test_forced_settle_boundary() -> void:
	var status := SimStatus.new()
	var participants: Array[BattleParticipant] = [
		BattleParticipant.create(1, BattleParticipant.Faction.PLAYER, true, true, true, 100, status)
	]
	var state: BattleState = BattleState.create(_frictionless_world(status), participants, status)
	state.complete_battle_start(status); state.complete_turn_start(status)
	state.commit_launch_velocity(FixVec2.from_ints(1, 0, status), status)
	var calls: int = 0
	while status.is_ok() and state.phase() == BattleState.Phase.RESOLVE and calls < 1201:
		state.advance_resolve(status); calls += 1
	_check(
		"P1-FORCED-SETTLE-001",
		status.is_ok() and state.phase() == BattleState.Phase.TURN_END
		and state.normal_resolve_ticks() == BattleLimits.NORMAL_RESOLVE_MAX_TICKS
		and state.forced_resolve_ticks() > 0 and state.forced_settle_used(),
		"calls=%d normal=%d forced=%d" % [calls, state.normal_resolve_ticks(), state.forced_resolve_ticks()]
	)

func _initialize() -> void:
	print("== P1-1 CTB / BattleState ==")
	_test_enums_and_scheduler(); _test_state_preview_and_snapshot(); _test_sim_snapshot_decode()
	_test_launch_resolve_and_mutation(); _test_rejections_are_stable()
	_test_forced_settle_boundary()
	if _failures == 0: print("P1_CTB_BATTLE_STATE_RESULT: PASS"); quit(0)
	else: print("P1_CTB_BATTLE_STATE_RESULT: FAIL (%d)" % _failures); quit(1)
