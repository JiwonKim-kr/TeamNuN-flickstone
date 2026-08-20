class_name BattleSnapshot
extends RefCounted

const MAGIC: PackedByteArray = [70, 76, 73, 67, 75, 66, 84, 76, 0]
const SCHEMA_VERSION: int = 1
const MAX_PARTICIPANTS: int = 65535
const MAX_SIM_BYTES: int = 64 * 1024 * 1024

class Writer:
	var data := PackedByteArray()
	func u8(value: int) -> void: data.append(value & 0xFF)
	func u16(value: int) -> void:
		for shift: int in range(0, 16, 8): u8(value >> shift)
	func u32(value: int) -> void:
		for shift: int in range(0, 32, 8): u8(value >> shift)
	func i64(value: int) -> void:
		for shift: int in range(0, 64, 8): u8(value >> shift)

class Reader:
	var data: PackedByteArray
	var offset: int = 0
	var valid: bool = true
	func _init(source: PackedByteArray) -> void: data = source
	func remaining() -> int: return data.size() - offset
	func u8() -> int:
		if remaining() < 1: valid = false; return 0
		var value: int = data[offset]; offset += 1; return value
	func u16() -> int:
		var value: int = 0
		for shift: int in range(0, 16, 8): value |= u8() << shift
		return value
	func u32() -> int:
		var value: int = 0
		for shift: int in range(0, 32, 8): value |= u8() << shift
		return value
	func i64() -> int:
		var value: int = 0
		for shift: int in range(0, 64, 8): value |= u8() << shift
		return value

var _initialized: bool = false
var _phase: int = 0
var _current_actor: int = 0
var _abstract_time: int = 0
var _last_faction: int = 0
var _normal_ticks: int = 0
var _forced_ticks: int = 0
var _forced_used: bool = false
var _participants: Array[BattleParticipant] = []
var _sim_bytes := PackedByteArray()


static func capture(state: BattleState, status: SimStatus) -> BattleSnapshot:
	var snapshot := BattleSnapshot.new()
	if not status.is_ok() or state == null or not state.is_initialized() or state.has_pending_mutations():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_SNAPSHOT_CAPTURE, 0, 0)
		return snapshot
	var world: SimWorld = state.world_copy(status)
	if not status.is_ok() or world.has_pending_requests() or world.event_cursor() != world.event_count():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.BATTLE_SNAPSHOT_CAPTURE, world.event_cursor(), world.event_count())
		return snapshot
	snapshot._sim_bytes = SimSnapshot.capture(world, status).encode(status)
	if not status.is_ok(): return BattleSnapshot.new()
	snapshot._phase = state.phase(); snapshot._current_actor = state.current_actor_body_id()
	snapshot._abstract_time = state.abstract_time(); snapshot._last_faction = state.last_acted_faction()
	snapshot._normal_ticks = state.normal_resolve_ticks(); snapshot._forced_ticks = state.forced_resolve_ticks(); snapshot._forced_used = state.forced_settle_used()
	for index: int in range(state.participant_count()): snapshot._participants.append(state.participant_at(index, status))
	if not status.is_ok(): return BattleSnapshot.new()
	snapshot._initialized = true
	return snapshot


func is_initialized() -> bool: return _initialized


func encode(status: SimStatus) -> PackedByteArray:
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_ENCODE, 0, 0)
		return PackedByteArray()
	var writer := Writer.new()
	writer.data.append_array(MAGIC); writer.u16(SCHEMA_VERSION); writer.u16(_phase); writer.u32(_current_actor)
	writer.i64(_abstract_time); writer.u16(_last_faction); writer.u32(_normal_ticks); writer.u32(_forced_ticks); writer.u8(1 if _forced_used else 0)
	writer.u32(_participants.size())
	for item: BattleParticipant in _participants:
		writer.u32(item.body_id()); writer.u16(item.faction()); writer.u8(1 if item.has_turn() else 0)
		writer.u8(1 if item.controllable() else 0); writer.u8(1 if item.counts_for_victory() else 0)
		writer.u16(item.speed_stat()); writer.i64(item.ct())
	writer.u32(_sim_bytes.size()); writer.data.append_array(_sim_bytes)
	return writer.data


static func decode(bytes: PackedByteArray, status: SimStatus) -> BattleSnapshot:
	var result := BattleSnapshot.new()
	if not status.is_ok(): return result
	var reader := Reader.new(bytes)
	for expected: int in MAGIC:
		if reader.u8() != expected:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, reader.offset, 0); return result
	var version: int = reader.u16()
	if version != SCHEMA_VERSION:
		status.fail(SimStatus.Code.UNSUPPORTED_SCHEMA, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, version, SCHEMA_VERSION); return result
	result._phase = reader.u16(); result._current_actor = reader.u32(); result._abstract_time = reader.i64(); result._last_faction = reader.u16()
	result._normal_ticks = reader.u32(); result._forced_ticks = reader.u32(); var forced: int = reader.u8()
	if forced > 1:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, forced, 0); return BattleSnapshot.new()
	result._forced_used = forced == 1
	var count: int = reader.u32()
	if count > MAX_PARTICIPANTS or count > reader.remaining() / 19:
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, count, reader.remaining()); return BattleSnapshot.new()
	var previous_id: int = 0
	for index: int in range(count):
		var body_id: int = reader.u32(); var faction: int = reader.u16(); var has_turn: int = reader.u8(); var controllable: int = reader.u8(); var victory: int = reader.u8()
		var speed: int = reader.u16(); var ct: int = reader.i64()
		if has_turn > 1 or controllable > 1 or victory > 1 or body_id <= previous_id:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, body_id, previous_id); return BattleSnapshot.new()
		result._participants.append(BattleParticipant.restore(body_id, faction, has_turn == 1, controllable == 1, victory == 1, speed, ct, status))
		if not status.is_ok(): return BattleSnapshot.new()
		previous_id = body_id
	var sim_length: int = reader.u32()
	if sim_length <= 0 or sim_length > MAX_SIM_BYTES or sim_length != reader.remaining():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, sim_length, reader.remaining()); return BattleSnapshot.new()
	result._sim_bytes = bytes.slice(reader.offset, reader.offset + sim_length); reader.offset += sim_length
	var sim_status := SimStatus.new()
	var sim_snapshot: SimSnapshot = SimSnapshot.decode(result._sim_bytes, sim_status)
	if not sim_status.is_ok() or not reader.valid or reader.offset != bytes.size():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, sim_status.code(), reader.offset); return BattleSnapshot.new()
	var validation_status := SimStatus.new()
	BattleState.restore(
		sim_snapshot.restore_world(validation_status), result._participants, result._phase,
		result._current_actor, result._abstract_time, result._last_faction,
		result._normal_ticks, result._forced_ticks, result._forced_used, validation_status
	)
	if not validation_status.is_ok():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation())
		return BattleSnapshot.new()
	result._initialized = true
	return result


func restore_state(status: SimStatus) -> BattleState:
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_RESTORE, 0, 0)
		return BattleState.new()
	var world: SimWorld = SimSnapshot.decode(_sim_bytes, status).restore_world(status)
	if not status.is_ok(): return BattleState.new()
	return BattleState.restore(world, _participants, _phase, _current_actor, _abstract_time, _last_faction, _normal_ticks, _forced_ticks, _forced_used, status)
