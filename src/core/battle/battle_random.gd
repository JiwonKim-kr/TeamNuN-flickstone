class_name BattleRandom
extends RefCounted

const PURPOSE_TRIGGER_EFFECT: int = 1
const PURPOSE_COLLISION_CRITICAL: int = 2
const PURPOSE_AI_SHOT_ERROR: int = 3

var _rng: SimRng = SimRng.new()

static func for_record(world: SimWorld, record: BattleTriggerRecord, status: SimStatus) -> BattleRandom:
	var result := BattleRandom.new()
	if not status.is_ok() or world == null or record == null or not record.is_initialized():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_RANDOM, 0, 0)
		return result
	result._rng = world.root_rng_copy(status).derive_substream(PURPOSE_TRIGGER_EFFECT, record.subject_body_id(), record.sequence(), status)
	return result

static func for_collision_critical(world: SimWorld, attacker_body_id: int, event_sequence: int, status: SimStatus) -> BattleRandom:
	var result := BattleRandom.new()
	if not status.is_ok() or world == null or attacker_body_id <= 0 or not UInt32Math.is_u32(event_sequence):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_RANDOM, attacker_body_id, event_sequence)
		return result
	result._rng = world.root_rng_copy(status).derive_substream(PURPOSE_COLLISION_CRITICAL, attacker_body_id, event_sequence, status)
	return result

static func for_ai_shot(world: SimWorld, actor_body_id: int, turn_index: int, status: SimStatus) -> BattleRandom:
	var result := BattleRandom.new()
	if not status.is_ok() or world == null or actor_body_id <= 0 or turn_index < 0:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_RANDOM, actor_body_id, turn_index)
		return result
	result._rng = world.root_rng_copy(status).derive_substream(PURPOSE_AI_SHOT_ERROR, actor_body_id, turn_index, status)
	return result

func next_index(count: int, status: SimStatus) -> int:
	if count <= 0:
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_RANDOM, count, 0); return 0
	if count == 1: return 0
	return _rng.next_below(count, status)

func chance(numerator: int, denominator: int, status: SimStatus) -> bool:
	if denominator <= 0 or numerator < 0 or numerator > denominator:
		status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_RANDOM, numerator, denominator); return false
	if numerator == 0: return false
	if numerator == denominator: return true
	return _rng.chance(numerator, denominator, status)

func draw_count_hi() -> int: return _rng.draw_count_hi()
func draw_count_lo() -> int: return _rng.draw_count_lo()
