extends SceneTree

const SimStatusScript := preload("res://src/core/sim/sim_status.gd")
const FixVec2Script := preload("res://src/core/sim/fix_vec2.gd")
const FixMathScript := preload("res://src/core/sim/fix_math.gd")
const SimBodyScript := preload("res://src/core/sim/sim_body.gd")
const SimEventScript := preload("res://src/core/sim/sim_event.gd")
const SimWorldScript := preload("res://src/core/sim/sim_world.gd")
const BattleTriggerIdScript := preload("res://src/core/battle/battle_trigger_id.gd")
const BattleTriggerRecordScript := preload("res://src/core/battle/battle_trigger_record.gd")
const BattleTriggerBusScript := preload("res://src/core/battle/battle_trigger_bus.gd")
const BattleRandomScript := preload("res://src/core/battle/battle_random.gd")
const BattleResultScript := preload("res://src/core/battle/battle_result.gd")
const BattleParticipantScript := preload("res://src/core/battle/battle_participant.gd")
const BattleStateScript := preload("res://src/core/battle/battle_state.gd")
const BattleSnapshotScript := preload("res://src/core/battle/battle_snapshot.gd")

var _failures: int = 0


func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % case_id)
		return
	_failures += 1
	print("[FAIL] %s %s" % [case_id, detail])


func _valid_record(status: SimStatus) -> BattleTriggerRecord:
	return BattleTriggerRecord.create(
		42,
		3,
		BattleTriggerId.Value.ON_HIT_DEAL,
		4,
		17,
		23,
		11,
		22,
		33,
		SimEvent.CauseId.NONE,
		FixVec2.from_raw(101, -202),
		FixVec2.from_raw(303, -404),
		505,
		606,
		7,
		status
	)


func _invalid_record(
		sequence: int,
		wave: int,
		trigger_id: int,
		phase: int,
		tick: int,
		subject: int,
		other: int,
		cause_id: int,
		flags: int,
		status: SimStatus
) -> BattleTriggerRecord:
	return BattleTriggerRecord.create(
		sequence, wave, trigger_id, phase, tick, 0,
		subject, other, 0, cause_id,
		FixVec2.zero(), FixVec2.zero(), 0, 0, flags, status
	)


func _is_record_error(status: SimStatus, record: BattleTriggerRecord) -> bool:
	return (
		not record.is_initialized()
		and status.code() == SimStatus.Code.INVALID_TRIGGER_RECORD
		and status.operation() == SimStatus.Operation.TRIGGER_RECORD_CREATE
	)


func _test_trigger_ids() -> void:
	var values: Array[int] = [
		BattleTriggerId.Value.PASSIVE,
		BattleTriggerId.Value.ON_BATTLE_START,
		BattleTriggerId.Value.ON_TURN_START,
		BattleTriggerId.Value.ON_LAUNCH,
		BattleTriggerId.Value.ON_HIT_DEAL,
		BattleTriggerId.Value.ON_HIT_TAKE,
		BattleTriggerId.Value.ON_ALLY_COLLIDE,
		BattleTriggerId.Value.ON_WALL_BOUNCE,
		BattleTriggerId.Value.ON_MOVING,
		BattleTriggerId.Value.ON_DEATH_SELF,
		BattleTriggerId.Value.ON_KILL,
		BattleTriggerId.Value.ON_TURN_END,
		BattleTriggerId.Value.ON_BATTLE_END,
	]
	var exact: bool = true
	for index: int in range(values.size()):
		exact = exact and values[index] == index + 1
	_check("P1-4-T01-TRIGGER-ID-APPEND-ONLY-001", exact)
	_check(
		"P1-4-T01-PASSIVE-REGISTRATION-ONLY-001",
		BattleTriggerId.is_known(BattleTriggerId.Value.PASSIVE)
		and not BattleTriggerId.is_record_trigger(BattleTriggerId.Value.PASSIVE)
		and BattleTriggerId.is_record_trigger(BattleTriggerId.Value.ON_BATTLE_START)
		and BattleTriggerId.is_record_trigger(BattleTriggerId.Value.ON_BATTLE_END)
		and not BattleTriggerId.is_known(BattleTriggerId.Value.INVALID)
		and not BattleTriggerId.is_known(14)
	)


func _test_valid_record_and_copy() -> void:
	var status := SimStatus.new()
	var record: BattleTriggerRecord = _valid_record(status)
	var copied: BattleTriggerRecord = record.copy()
	var position: FixVec2 = record.position()
	var vector: FixVec2 = record.vector()
	_check(
		"P1-4-T01-RECORD-FIXED-FIELDS-001",
		status.is_ok()
		and record.is_initialized()
		and record.sequence() == 42
		and record.wave() == 3
		and record.trigger_id() == BattleTriggerId.Value.ON_HIT_DEAL
		and record.phase() == 4
		and record.tick() == 17
		and record.source_sim_sequence() == 23
		and record.subject_body_id() == 11
		and record.other_body_id() == 22
		and record.instigator_body_id() == 33
		and record.cause_id() == SimEvent.CauseId.NONE
		and position.x_raw() == 101
		and position.y_raw() == -202
		and vector.x_raw() == 303
		and vector.y_raw() == -404
		and record.value_a() == 505
		and record.value_b() == 606
		and record.flags() == 7
	)
	_check(
		"P1-4-T01-RECORD-DEEP-COPY-001",
		copied != record
		and copied.is_initialized()
		and copied.position() != position
		and copied.position().is_equal(position)
		and copied.vector() != vector
		and copied.vector().is_equal(vector)
		and copied.sequence() == record.sequence()
	)


func _test_record_boundaries() -> void:
	var global_status := SimStatus.new()
	var global: BattleTriggerRecord = _invalid_record(
		1, 0, BattleTriggerId.Value.ON_BATTLE_START, 1, 0,
		0, 0, SimEvent.CauseId.NONE, 0, global_status
	)
	_check("P1-4-T01-GLOBAL-RELATION-001", global_status.is_ok() and global.is_initialized())
	var passive_status := SimStatus.new()
	var passive: BattleTriggerRecord = _invalid_record(1, 0, BattleTriggerId.Value.PASSIVE, 1, 0, 0, 0, SimEvent.CauseId.NONE, 0, passive_status)
	_check("P1-4-T01-PASSIVE-RECORD-REJECTED-001", _is_record_error(passive_status, passive))
	var cases: Array[Array] = [
		[0, 0, BattleTriggerId.Value.ON_TURN_START, 2, 0, 1, 0, 0, 0],
		[1, 0x10000, BattleTriggerId.Value.ON_TURN_START, 2, 0, 1, 0, 0, 0],
		[1, 0, BattleTriggerId.Value.ON_TURN_START, 0, 0, 1, 0, 0, 0],
		[1, 0, BattleTriggerId.Value.ON_TURN_START, 2, -1, 1, 0, 0, 0],
		[1, 0, BattleTriggerId.Value.ON_TURN_START, 2, 0, 0, 0, 0, 0],
		[1, 0, BattleTriggerId.Value.ON_HIT_DEAL, 4, 0, 1, 1, 0, 0],
		[1, 0, BattleTriggerId.Value.ON_BATTLE_END, 7, 0, 1, 0, 0, 0],
		[1, 0, BattleTriggerId.Value.ON_DEATH_SELF, 4, 0, 1, 2, 0, 0],
		[1, 0, BattleTriggerId.Value.ON_DEATH_SELF, 4, 0, 1, 0, 99, 0],
		[1, 0, BattleTriggerId.Value.ON_DEATH_SELF, 4, 0, 1, 0, 0, 0x100000000],
	]
	var all_rejected: bool = true
	for values: Array in cases:
		var case_status := SimStatus.new()
		var record: BattleTriggerRecord = _invalid_record(values[0], values[1], values[2], values[3], values[4], values[5], values[6], values[7], values[8], case_status)
		all_rejected = all_rejected and _is_record_error(case_status, record)
	_check("P1-4-T01-INVALID-FIELDS-ATOMIC-001", all_rejected)
	var latched := SimStatus.new()
	latched.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.FIX_FROM_INT, 7, 8)
	var neutral: BattleTriggerRecord = _valid_record(latched)
	_check("P1-4-T01-FIRST-ERROR-WINS-001", not neutral.is_initialized() and latched.code() == SimStatus.Code.INVALID_ARGUMENT and latched.operation() == SimStatus.Operation.FIX_FROM_INT and latched.detail_a() == 7 and latched.detail_b() == 8)


func _body(x: int, status: SimStatus) -> SimBody:
	return SimBody.create_unassigned(FixVec2.from_ints(x, 0, status), FixVec2.zero(), 8 * FixMath.SCALE, 64 * FixMath.SCALE, status)


func _two_side_state(status: SimStatus) -> BattleState:
	var world: SimWorld = SimWorld.create(0x01234567, 0x89ABCDEF, status)
	var bodies: Array[SimBody] = [_body(0, status), _body(64, status)]
	world.add_initial_bodies([1, 2], bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	var participants: Array[BattleParticipant] = [
		BattleParticipant.create(1, BattleParticipant.Faction.PLAYER, true, true, true, 100, status),
		BattleParticipant.create(2, BattleParticipant.Faction.ENEMY, true, false, true, 100, status),
	]
	return BattleState.create(world, participants, status)


func _test_bus_limits_and_random() -> void:
	var status := SimStatus.new()
	var bus := BattleTriggerBus.new()
	for index: int in range(4096):
		var record: BattleTriggerRecord = BattleTriggerRecord.create(index + 1, 0, BattleTriggerId.Value.ON_TURN_START, 2, 0, 0, 1, 0, 0, 0, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, status)
		bus.enqueue(record, status)
	_check("P1-4-T03-RECORD-LIMIT-4096-001", status.is_ok() and bus.drain(status).size() == 4096)
	var overflow_status := SimStatus.new()
	for index: int in range(4097):
		var record: BattleTriggerRecord = BattleTriggerRecord.create(index + 1, 0, BattleTriggerId.Value.ON_TURN_START, 2, 0, 0, 1, 0, 0, 0, FixVec2.zero(), FixVec2.zero(), 0, 0, 0, overflow_status)
		bus.enqueue(record, overflow_status)
	_check("P1-4-T03-RECORD-LIMIT-4097-001", overflow_status.code() == SimStatus.Code.TRIGGER_LIMIT_EXCEEDED)
	var state_status := SimStatus.new(); var state: BattleState = _two_side_state(state_status)
	var random_record: BattleTriggerRecord = _valid_record(state_status)
	var random: BattleRandom = BattleRandom.for_record(state.world_copy(state_status), random_record, state_status)
	var zero: bool = random.chance(0, 100, state_status); var full: bool = random.chance(100, 100, state_status); var only: int = random.next_index(1, state_status)
	_check("P1-4-T07-DEGENERATE-DRAW-ZERO-001", state_status.is_ok() and not zero and full and only == 0 and random.draw_count_hi() == 0 and random.draw_count_lo() == 0)


func _test_phase_result_and_snapshot() -> void:
	var status := SimStatus.new(); var state: BattleState = _two_side_state(status)
	state.complete_battle_start(status)
	_check("P1-4-T02-BATTLE-START-001", status.is_ok() and state.trigger_record_count() == 1 and state.trigger_record_at(0, status).trigger_id() == BattleTriggerId.Value.ON_BATTLE_START)
	state.queue_participant_removal(2, 1, 1, 1, status)
	state.complete_turn_start(status)
	_check("P1-4-T02-TURN-START-001", status.is_ok() and state.trigger_record_count() == 1 and state.trigger_record_at(0, status).trigger_id() == BattleTriggerId.Value.ON_TURN_START)
	state.commit_forced_no_launch(status); state.complete_turn_end(status); state.resolve_check(status)
	_check("P1-4-T05-RESULT-LATCH-001", status.is_ok() and state.phase() == BattleState.Phase.BATTLE_END and state.battle_result() == BattleResult.Value.PLAYER_VICTORY and state.trigger_record_count() == 1 and state.trigger_record_at(0, status).trigger_id() == BattleTriggerId.Value.ON_BATTLE_END)
	var encoded: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var restored: BattleState = BattleSnapshot.decode(encoded, status).restore_state(status)
	var reencoded: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	_check("P1-4-T08-SNAPSHOT-V3-001", status.is_ok() and encoded == reencoded and restored.battle_result() == BattleResult.Value.PLAYER_VICTORY and restored.next_trigger_sequence() == state.next_trigger_sequence())
	var mismatch := SimStatus.new(); state.apply_check_directive(BattleState.CheckDirective.CONTINUE, mismatch)
	_check("P1-4-T06-TERMINAL-IMMUTABLE-001", mismatch.code() == SimStatus.Code.INVALID_PHASE and state.battle_result() == BattleResult.Value.PLAYER_VICTORY)


func _init() -> void:
	print("== P1-4 T-01 Trigger vocabulary / immutable record ==")
	_test_trigger_ids()
	_test_valid_record_and_copy()
	_test_record_boundaries()
	_test_bus_limits_and_random()
	_test_phase_result_and_snapshot()
	if _failures == 0:
		print("P1_TRIGGER_BUS_BATTLE_RESULT_RESULT: PASS")
		quit(0)
	else:
		print("P1_TRIGGER_BUS_BATTLE_RESULT_RESULT: FAIL (%d)" % _failures)
		quit(1)
