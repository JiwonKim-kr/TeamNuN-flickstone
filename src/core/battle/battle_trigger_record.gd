class_name BattleTriggerRecord
extends RefCounted
## Immutable fixed-layout battle trigger fact.
##
## Records normalize P0 simulation facts and P1 phase boundaries for later
## ability matching. They do not represent an ability subscription or effect
## invocation. Removed body IDs remain valid correlation keys.

const PHASE_MIN: int = 1
const PHASE_MAX: int = 7

var _initialized: bool = false
var _sequence: int = 0
var _wave: int = 0
var _trigger_id: int = BattleTriggerId.Value.INVALID
var _phase: int = 0
var _tick: int = 0
var _source_sim_sequence: int = 0
var _subject_body_id: int = 0
var _other_body_id: int = 0
var _instigator_body_id: int = 0
var _cause_id: int = SimEvent.CauseId.NONE
var _position: FixVec2 = FixVec2.zero()
var _vector: FixVec2 = FixVec2.zero()
var _value_a: int = 0
var _value_b: int = 0
var _flags: int = 0


static func _fail(
		status: SimStatus, detail_a: int, detail_b: int
) -> BattleTriggerRecord:
	status.fail(
		SimStatus.Code.INVALID_TRIGGER_RECORD,
		SimStatus.Operation.TRIGGER_RECORD_CREATE,
		detail_a,
		detail_b
	)
	return BattleTriggerRecord.new()


static func _known_cause(cause_id: int) -> bool:
	return (
		cause_id == SimEvent.CauseId.NONE
		or cause_id == SimEvent.CauseId.KILL_BOUNDARY
		or cause_id == SimEvent.CauseId.KILL_ZONE
		or cause_id == SimEvent.CauseId.DAMAGE
		or cause_id == SimEvent.CauseId.TURN_START_DAMAGE_ZONE
	)


static func _valid_relations(
		trigger_id: int,
		subject_body_id: int,
		other_body_id: int,
		instigator_body_id: int
) -> bool:
	if (
		trigger_id == BattleTriggerId.Value.ON_BATTLE_START
		or trigger_id == BattleTriggerId.Value.ON_BATTLE_END
	):
		return (
			subject_body_id == 0
			and other_body_id == 0
			and instigator_body_id == 0
		)
	if subject_body_id == 0:
		return false
	if (
		trigger_id == BattleTriggerId.Value.ON_HIT_DEAL
		or trigger_id == BattleTriggerId.Value.ON_HIT_TAKE
		or trigger_id == BattleTriggerId.Value.ON_ALLY_COLLIDE
		or trigger_id == BattleTriggerId.Value.ON_KILL
	):
		return other_body_id > 0 and other_body_id != subject_body_id
	return other_body_id == 0


static func create(
		sequence: int,
		wave: int,
		trigger_id: int,
		phase: int,
		tick: int,
		source_sim_sequence: int,
		subject_body_id: int,
		other_body_id: int,
		instigator_body_id: int,
		cause_id: int,
		position: FixVec2,
		vector: FixVec2,
		value_a: int,
		value_b: int,
		flags: int,
		status: SimStatus
) -> BattleTriggerRecord:
	var record := BattleTriggerRecord.new()
	if not status.is_ok():
		return record
	if sequence <= 0 or not UInt32Math.is_u32(sequence):
		return _fail(status, sequence, trigger_id)
	if wave < 0 or wave > 0xFFFF:
		return _fail(status, wave, trigger_id)
	# PASSIVE is a stable registration mode, never an event in this queue.
	if not BattleTriggerId.is_record_trigger(trigger_id):
		return _fail(status, trigger_id, BattleTriggerId.Value.PASSIVE)
	if phase < PHASE_MIN or phase > PHASE_MAX or tick < 0:
		return _fail(status, phase, tick)
	if (
		not UInt32Math.is_u32(source_sim_sequence)
		or not UInt32Math.is_u32(subject_body_id)
		or not UInt32Math.is_u32(other_body_id)
		or not UInt32Math.is_u32(instigator_body_id)
		or not UInt32Math.is_u32(flags)
	):
		return _fail(status, subject_body_id, other_body_id)
	if not _known_cause(cause_id):
		return _fail(status, trigger_id, cause_id)
	if position == null or vector == null:
		return _fail(status, trigger_id, 0)
	if not _valid_relations(
		trigger_id, subject_body_id, other_body_id, instigator_body_id
	):
		return _fail(status, subject_body_id, other_body_id)

	record._sequence = sequence
	record._wave = wave
	record._trigger_id = trigger_id
	record._phase = phase
	record._tick = tick
	record._source_sim_sequence = source_sim_sequence
	record._subject_body_id = subject_body_id
	record._other_body_id = other_body_id
	record._instigator_body_id = instigator_body_id
	record._cause_id = cause_id
	record._position = position.copy()
	record._vector = vector.copy()
	record._value_a = value_a
	record._value_b = value_b
	record._flags = flags
	record._initialized = true
	return record


func copy() -> BattleTriggerRecord:
	var record := BattleTriggerRecord.new()
	record._initialized = _initialized
	record._sequence = _sequence
	record._wave = _wave
	record._trigger_id = _trigger_id
	record._phase = _phase
	record._tick = _tick
	record._source_sim_sequence = _source_sim_sequence
	record._subject_body_id = _subject_body_id
	record._other_body_id = _other_body_id
	record._instigator_body_id = _instigator_body_id
	record._cause_id = _cause_id
	record._position = _position.copy()
	record._vector = _vector.copy()
	record._value_a = _value_a
	record._value_b = _value_b
	record._flags = _flags
	return record


func is_initialized() -> bool: return _initialized
func sequence() -> int: return _sequence
func wave() -> int: return _wave
func trigger_id() -> int: return _trigger_id
func phase() -> int: return _phase
func tick() -> int: return _tick
func source_sim_sequence() -> int: return _source_sim_sequence
func subject_body_id() -> int: return _subject_body_id
func other_body_id() -> int: return _other_body_id
func instigator_body_id() -> int: return _instigator_body_id
func cause_id() -> int: return _cause_id
func position() -> FixVec2: return _position.copy()
func vector() -> FixVec2: return _vector.copy()
func value_a() -> int: return _value_a
func value_b() -> int: return _value_b
func flags() -> int: return _flags
