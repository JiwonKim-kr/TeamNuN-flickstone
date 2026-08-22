extends SceneTree

const SimStatusScript := preload("res://src/core/sim/sim_status.gd")
const FixVec2Script := preload("res://src/core/sim/fix_vec2.gd")
const SimEventScript := preload("res://src/core/sim/sim_event.gd")
const BattleTriggerIdScript := preload("res://src/core/battle/battle_trigger_id.gd")
const BattleTriggerRecordScript := preload("res://src/core/battle/battle_trigger_record.gd")

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
	_check(
		"P1-4-T01-GLOBAL-RELATION-001",
		global_status.is_ok() and global.is_initialized()
	)

	var passive_status := SimStatus.new()
	var passive: BattleTriggerRecord = _invalid_record(
		1, 0, BattleTriggerId.Value.PASSIVE, 1, 0,
		0, 0, SimEvent.CauseId.NONE, 0, passive_status
	)
	_check(
		"P1-4-T01-PASSIVE-RECORD-REJECTED-001",
		_is_record_error(passive_status, passive)
	)

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
		var status := SimStatus.new()
		var record: BattleTriggerRecord = _invalid_record(
			values[0], values[1], values[2], values[3], values[4],
			values[5], values[6], values[7], values[8], status
		)
		all_rejected = all_rejected and _is_record_error(status, record)
	_check("P1-4-T01-INVALID-FIELDS-ATOMIC-001", all_rejected)

	var latched := SimStatus.new()
	latched.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.FIX_FROM_INT, 7, 8)
	var neutral: BattleTriggerRecord = _valid_record(latched)
	_check(
		"P1-4-T01-FIRST-ERROR-WINS-001",
		not neutral.is_initialized()
		and latched.code() == SimStatus.Code.INVALID_ARGUMENT
		and latched.operation() == SimStatus.Operation.FIX_FROM_INT
		and latched.detail_a() == 7
		and latched.detail_b() == 8
	)


func _init() -> void:
	print("== P1-4 T-01 Trigger vocabulary / immutable record ==")
	_test_trigger_ids()
	_test_valid_record_and_copy()
	_test_record_boundaries()
	if _failures == 0:
		print("P1_TRIGGER_BUS_BATTLE_RESULT_RESULT: PASS")
		quit(0)
	else:
		print("P1_TRIGGER_BUS_BATTLE_RESULT_RESULT: FAIL (%d)" % _failures)
		quit(1)
