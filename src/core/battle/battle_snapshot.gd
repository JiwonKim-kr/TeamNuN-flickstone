class_name BattleSnapshot
extends RefCounted

const MAGIC: PackedByteArray = [70, 76, 73, 67, 75, 66, 84, 76, 0]
const LEGACY_SCHEMA_VERSION: int = 1
const COMBAT_SCHEMA_VERSION: int = 2
const TRIGGER_SCHEMA_VERSION: int = 3
const EFFECT_SCHEMA_VERSION: int = 4
const STATUS_SCHEMA_VERSION: int = 5
const DYNAMIC_SCHEMA_VERSION: int = 6
const ZONE_SCHEMA_VERSION: int = 7
const KILL_TALLY_SCHEMA_VERSION: int = 8
const DAMAGE_ZONE_SCHEMA_VERSION: int = 9
const SCHEMA_VERSION: int = 10
const MAX_PARTICIPANTS: int = 65535
const MAX_COMBATANTS: int = 65535
const MAX_COOLDOWNS: int = 65535
const MAX_SIM_BYTES: int = 64 * 1024 * 1024
const MAX_TRIGGER_RECORDS: int = BattleLimits.TRIGGER_MAX_RECORDS
const MAX_MOTION_CREDITS: int = 65535
const MAX_ABILITY_BINDINGS: int = 65535

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
var _combatants: Array[BattleCombatant] = []
var _cooldowns: Array[DamagePairCooldown] = []
var _battle_result: int = BattleResult.Value.ONGOING
var _next_trigger_sequence: int = 1
var _trigger_records: Array[BattleTriggerRecord] = []
var _motion_credits: Array[BattleMotionCredit] = []
var _sim_bytes := PackedByteArray()
var _content_fingerprint: PackedByteArray = PackedByteArray()
var _ability_bindings: Array[AbilityBinding] = []
var _next_effect_sequence: int = 1
var _turn_index: int = 0
var _next_status_sequence: int = 1
var _statuses: Array[StatusInstance] = []
var _tally: SynergyTally = SynergyTally.new()
var _identities: Array[BattlePieceIdentity] = []
var _base_body_stats: Array[BattleBaseBodyStats] = []
var _expire_states: Array[ExpireState] = []
var _piece_origins: Array[BattlePieceOrigin] = []
var _runtime_spawn_count: int = 0
var _zone_spawns: Array[ZoneSpawnState] = []
var _kill_tallies: Array[BattleKillTally] = []
var _damage_zones: Array[DamageZoneState] = []
var _launch_contact_mask: int = 0


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
	for index: int in range(state.combatant_count()): snapshot._combatants.append(state.combatant_at(index, status))
	for index: int in range(state.cooldown_count()): snapshot._cooldowns.append(state.cooldown_at(index, status))
	snapshot._battle_result = state.battle_result(); snapshot._next_trigger_sequence = state.next_trigger_sequence()
	for index: int in range(state.trigger_record_count()): snapshot._trigger_records.append(state.trigger_record_at(index, status))
	for index: int in range(state.motion_credit_count()): snapshot._motion_credits.append(state.motion_credit_at(index, status))
	snapshot._content_fingerprint = state.content_fingerprint_bytes()
	if snapshot._content_fingerprint.is_empty(): snapshot._content_fingerprint.resize(32)
	for index: int in range(state.ability_binding_count()): snapshot._ability_bindings.append(state.ability_binding_at(index, status))
	snapshot._next_effect_sequence = state.next_effect_sequence()
	snapshot._turn_index = state.turn_index(); snapshot._next_status_sequence = state.next_status_sequence()
	for index: int in range(state.status_count()): snapshot._statuses.append(state.status_at(index, status))
	snapshot._tally = state.synergy_tally_copy()
	for index: int in range(state.piece_identity_count()): snapshot._identities.append(state.piece_identity_at(index, status))
	for index: int in range(state.base_body_stats_count()): snapshot._base_body_stats.append(state.base_body_stats_at(index, status))
	for index: int in range(state.expire_state_count()): snapshot._expire_states.append(state.expire_state_at(index, status))
	for index: int in range(state.piece_origin_count()): snapshot._piece_origins.append(state.piece_origin_at(index, status))
	snapshot._runtime_spawn_count = state.runtime_spawn_count()
	for index: int in range(state.zone_spawn_count()): snapshot._zone_spawns.append(state.zone_spawn_at(index, status))
	for index: int in range(state.kill_tally_count()): snapshot._kill_tallies.append(state.kill_tally_at(index, status))
	for index: int in range(state.damage_zone_count()): snapshot._damage_zones.append(state.damage_zone_at(index, status))
	snapshot._launch_contact_mask = state.launch_contact_mask()
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
	writer.u32(_combatants.size())
	for item: BattleCombatant in _combatants:
		writer.u32(item.body_id()); writer.u16(item.faction()); writer.i64(item.current_hp())
		writer.i64(item.max_hp()); writer.i64(item.attack()); writer.u16(item.critical_basis_points()); writer.i64(item.clean_hit_damage_multiplier_raw())
	writer.u32(_cooldowns.size())
	for item: DamagePairCooldown in _cooldowns:
		writer.u32(item.low_body_id()); writer.u32(item.high_body_id()); writer.i64(item.next_allowed_tick())
	writer.u16(_battle_result); writer.u32(_next_trigger_sequence); writer.u32(_trigger_records.size())
	for item: BattleTriggerRecord in _trigger_records:
		writer.u32(item.sequence()); writer.u16(item.wave()); writer.u16(item.trigger_id()); writer.u16(item.phase()); writer.i64(item.tick())
		writer.u32(item.source_sim_sequence()); writer.u32(item.subject_body_id()); writer.u32(item.other_body_id()); writer.u32(item.instigator_body_id()); writer.u16(item.cause_id())
		var position: FixVec2 = item.position(); var vector: FixVec2 = item.vector()
		writer.i64(position.x_raw()); writer.i64(position.y_raw()); writer.i64(vector.x_raw()); writer.i64(vector.y_raw())
		writer.i64(item.value_a()); writer.i64(item.value_b()); writer.u32(item.flags())
	writer.u32(_motion_credits.size())
	for item: BattleMotionCredit in _motion_credits:
		writer.u32(item.body_id()); writer.u32(item.root_body_id()); writer.u16(item.root_faction()); writer.u32(item.source_sim_sequence()); writer.i64(item.tick())
	writer.data.append_array(_content_fingerprint)
	writer.u32(_ability_bindings.size())
	for binding: AbilityBinding in _ability_bindings:
		writer.u32(binding.owner_body_id()); writer.u32(binding.ability_numeric_id())
	writer.u32(_next_effect_sequence)
	writer.u32(_turn_index); writer.u32(_next_status_sequence); writer.u32(_statuses.size())
	for item: StatusInstance in _statuses:
		writer.u32(item.status_numeric_id()); writer.u32(item.target_body_id()); writer.u32(item.source_body_id()); writer.u16(item.stacks()); writer.u32(item.remaining()); writer.u32(item.applied_turn_index()); writer.u32(item.application_sequence())
	writer.u32(_tally.count())
	for index: int in range(_tally.count()): writer.u32(_tally.tag_numeric_id_at(index)); writer.u16(_tally.faction_id_at(index)); writer.u16(_tally.value_at(index))
	writer.u32(_identities.size())
	for item: BattlePieceIdentity in _identities: writer.u32(item.body_id()); writer.u32(item.piece_numeric_id()); writer.u16(item.level()); writer.u16(item.faction()); writer.u8(1 if item.is_token() else 0)
	writer.u32(_base_body_stats.size())
	for item: BattleBaseBodyStats in _base_body_stats: writer.u32(item.body_id()); writer.i64(item.mass_raw()); writer.i64(item.radius_raw()); writer.i64(item.friction_multiplier_raw())
	writer.u32(_runtime_spawn_count); writer.u32(_expire_states.size())
	for item: ExpireState in _expire_states: writer.u32(item.body_id()); writer.u16(item.kind_id()); writer.u32(item.remaining()); writer.u32(item.applied_turn_index()); writer.u8(1 if item.has_linked() else 0)
	writer.u32(_piece_origins.size())
	for item: BattlePieceOrigin in _piece_origins: writer.u32(item.body_id()); writer.u32(item.original_piece_numeric_id())
	writer.u32(_zone_spawns.size())
	for item: ZoneSpawnState in _zone_spawns: writer.u32(item.zone_id()); writer.u32(item.remaining_turns()); writer.u32(item.applied_turn_index())
	writer.u32(_kill_tallies.size())
	for item: BattleKillTally in _kill_tallies: writer.u32(item.body_id()); writer.u32(item.kill_count())
	writer.u32(_damage_zones.size())
	for item: DamageZoneState in _damage_zones: writer.u32(item.zone_id()); writer.i64(item.turn_start_damage())
	writer.u32(_launch_contact_mask)
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
	if version != LEGACY_SCHEMA_VERSION and version != COMBAT_SCHEMA_VERSION and version != TRIGGER_SCHEMA_VERSION and version != EFFECT_SCHEMA_VERSION and version != STATUS_SCHEMA_VERSION and version != DYNAMIC_SCHEMA_VERSION and version != ZONE_SCHEMA_VERSION and version != KILL_TALLY_SCHEMA_VERSION and version != DAMAGE_ZONE_SCHEMA_VERSION and version != SCHEMA_VERSION:
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
	if version >= COMBAT_SCHEMA_VERSION:
		var combatant_count: int = reader.u32()
		var combatant_size: int = 40 if version >= SCHEMA_VERSION else 32
		if combatant_count > MAX_COMBATANTS or combatant_count > reader.remaining() / combatant_size:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, combatant_count, reader.remaining()); return BattleSnapshot.new()
		previous_id = 0
		for index: int in range(combatant_count):
			var body_id: int = reader.u32(); var faction: int = reader.u16(); var current_hp: int = reader.i64()
			var max_hp: int = reader.i64(); var attack: int = reader.i64(); var critical_basis_points: int = reader.u16()
			var clean_hit_multiplier_raw: int = reader.i64() if version >= SCHEMA_VERSION else FixMath.ONE_RAW
			if body_id <= previous_id:
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, body_id, previous_id); return BattleSnapshot.new()
			result._combatants.append(BattleCombatant.restore_with_clean_hit_multiplier(body_id, faction, current_hp, max_hp, attack, critical_basis_points, clean_hit_multiplier_raw, status))
			if not status.is_ok(): return BattleSnapshot.new()
			previous_id = body_id
		var cooldown_count: int = reader.u32()
		if cooldown_count > MAX_COOLDOWNS or cooldown_count > reader.remaining() / 16:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, cooldown_count, reader.remaining()); return BattleSnapshot.new()
		var previous_low: int = 0
		var previous_high: int = 0
		for index: int in range(cooldown_count):
			var low_body_id: int = reader.u32(); var high_body_id: int = reader.u32(); var next_allowed_tick: int = reader.i64()
			if index > 0 and (low_body_id < previous_low or (low_body_id == previous_low and high_body_id <= previous_high)):
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, low_body_id, high_body_id); return BattleSnapshot.new()
			result._cooldowns.append(DamagePairCooldown.create(low_body_id, high_body_id, next_allowed_tick, status))
			if not status.is_ok(): return BattleSnapshot.new()
			previous_low = low_body_id; previous_high = high_body_id
	if version >= TRIGGER_SCHEMA_VERSION:
		result._battle_result = reader.u16(); result._next_trigger_sequence = reader.u32()
		var trigger_count: int = reader.u32()
		if trigger_count > MAX_TRIGGER_RECORDS or trigger_count > reader.remaining() / 88:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, trigger_count, reader.remaining()); return BattleSnapshot.new()
		var previous_trigger_sequence: int = 0
		for index: int in range(trigger_count):
			var sequence: int = reader.u32(); var wave: int = reader.u16(); var trigger_id: int = reader.u16(); var record_phase: int = reader.u16(); var tick: int = reader.i64()
			var source_sequence: int = reader.u32(); var subject: int = reader.u32(); var other: int = reader.u32(); var instigator: int = reader.u32(); var cause: int = reader.u16()
			var position := FixVec2.from_raw(reader.i64(), reader.i64()); var vector := FixVec2.from_raw(reader.i64(), reader.i64())
			var value_a: int = reader.i64(); var value_b: int = reader.i64(); var flags: int = reader.u32()
			if sequence <= previous_trigger_sequence:
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, sequence, previous_trigger_sequence); return BattleSnapshot.new()
			result._trigger_records.append(BattleTriggerRecord.create(sequence, wave, trigger_id, record_phase, tick, source_sequence, subject, other, instigator, cause, position, vector, value_a, value_b, flags, status))
			if not status.is_ok(): return BattleSnapshot.new()
			previous_trigger_sequence = sequence
		var credit_count: int = reader.u32()
		if credit_count > MAX_MOTION_CREDITS or credit_count > reader.remaining() / 22:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, credit_count, reader.remaining()); return BattleSnapshot.new()
		var previous_credit_body: int = 0
		for index: int in range(credit_count):
			var body_id: int = reader.u32(); var root_body_id: int = reader.u32(); var root_faction: int = reader.u16(); var source_sequence: int = reader.u32(); var tick: int = reader.i64()
			if body_id <= previous_credit_body:
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, body_id, previous_credit_body); return BattleSnapshot.new()
			result._motion_credits.append(BattleMotionCredit.create(body_id, root_body_id, root_faction, source_sequence, tick, status))
			if not status.is_ok(): return BattleSnapshot.new()
			previous_credit_body = body_id
	if version >= EFFECT_SCHEMA_VERSION:
		if reader.remaining() < 40:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, reader.remaining(), 40); return BattleSnapshot.new()
		result._content_fingerprint = bytes.slice(reader.offset, reader.offset + 32); reader.offset += 32
		var binding_count: int = reader.u32()
		if binding_count > MAX_ABILITY_BINDINGS or binding_count > reader.remaining() / 8:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, binding_count, reader.remaining()); return BattleSnapshot.new()
		var previous_owner: int = 0; var previous_ability: int = 0
		for index: int in range(binding_count):
			var owner_id: int = reader.u32(); var ability_id: int = reader.u32()
			if owner_id < previous_owner or (owner_id == previous_owner and ability_id <= previous_ability):
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, owner_id, ability_id); return BattleSnapshot.new()
			result._ability_bindings.append(AbilityBinding.create(owner_id, ability_id, status))
			if not status.is_ok(): return BattleSnapshot.new()
			previous_owner = owner_id; previous_ability = ability_id
		result._next_effect_sequence = reader.u32()
		if result._next_effect_sequence < 1:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, result._next_effect_sequence, 1); return BattleSnapshot.new()
	else:
		# Legacy snapshots predate content binding. Restore them with the canonical
		# empty fingerprint so recapturing them as v4 is deterministic.
		result._content_fingerprint.resize(32)
	if version >= STATUS_SCHEMA_VERSION:
		result._turn_index = reader.u32(); result._next_status_sequence = reader.u32(); var status_count: int = reader.u32()
		if status_count > 4096 or status_count > reader.remaining() / 26: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, status_count, reader.remaining()); return BattleSnapshot.new()
		for index: int in range(status_count): result._statuses.append(StatusInstance.create(reader.u32(), reader.u32(), reader.u32(), reader.u16(), reader.u32(), reader.u32(), reader.u32(), status))
		var tally_count: int = reader.u32(); var tally_entries: Array[SynergyTally.Entry] = []
		if tally_count > ContentLimits.RECORD_MAX_COUNT or tally_count > reader.remaining() / 8: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE); return BattleSnapshot.new()
		for index: int in range(tally_count): tally_entries.append(SynergyTally.Entry.new(reader.u32(), reader.u16(), reader.u16()))
		result._tally = SynergyTally.create(tally_entries, status)
		var identity_count: int = reader.u32()
		if identity_count > MAX_PARTICIPANTS or identity_count > reader.remaining() / 13: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE); return BattleSnapshot.new()
		for index: int in range(identity_count):
			var body_id: int = reader.u32(); var piece_id: int = reader.u32(); var level: int = reader.u16(); var faction: int = reader.u16(); var token: int = reader.u8()
			if token > 1: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE); return BattleSnapshot.new()
			result._identities.append(BattlePieceIdentity.create(body_id, piece_id, level, faction, token == 1, status))
		var base_count: int = reader.u32()
		if base_count > MAX_PARTICIPANTS or base_count > reader.remaining() / 28: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE); return BattleSnapshot.new()
		for index: int in range(base_count): result._base_body_stats.append(BattleBaseBodyStats.create(reader.u32(), reader.i64(), reader.i64(), reader.i64(), status))
		if not status.is_ok(): return BattleSnapshot.new()
	if version >= DYNAMIC_SCHEMA_VERSION:
		result._runtime_spawn_count = reader.u32(); var expire_count: int = reader.u32()
		if result._runtime_spawn_count > BattleLimits.RUNTIME_SPAWN_MAX_BODIES or expire_count > BattleLimits.RUNTIME_SPAWN_MAX_BODIES or expire_count > reader.remaining() / 15:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, expire_count, reader.remaining()); return BattleSnapshot.new()
		for index: int in range(expire_count):
			var body_id: int = reader.u32(); var kind_id: int = reader.u16(); var remaining: int = reader.u32(); var applied_turn: int = reader.u32(); var has_linked: int = reader.u8()
			if has_linked > 1: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, body_id, has_linked); return BattleSnapshot.new()
			result._expire_states.append(ExpireState.create(body_id, kind_id, remaining, applied_turn, has_linked == 1, status))
		var origin_count: int = reader.u32()
		if origin_count > MAX_PARTICIPANTS or origin_count > reader.remaining() / 8: status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, origin_count, reader.remaining()); return BattleSnapshot.new()
		for index: int in range(origin_count): result._piece_origins.append(BattlePieceOrigin.create(reader.u32(), reader.u32(), status))
		if not status.is_ok(): return BattleSnapshot.new()
	if version >= ZONE_SCHEMA_VERSION:
		var zone_count: int = reader.u32()
		if zone_count > BattleLimits.ZONE_SPAWN_MAX_PER_BATTLE or zone_count > reader.remaining() / 12:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, zone_count, reader.remaining()); return BattleSnapshot.new()
		var previous_zone_id: int = 0
		for index: int in range(zone_count):
			var zone_id: int = reader.u32(); var remaining_turns: int = reader.u32(); var applied_turn_index: int = reader.u32()
			if zone_id <= previous_zone_id or remaining_turns > ContentLimits.ZONE_DURATION_MAX_TURNS or applied_turn_index > result._turn_index:
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, zone_id, previous_zone_id); return BattleSnapshot.new()
			result._zone_spawns.append(ZoneSpawnState.create(zone_id, remaining_turns, applied_turn_index, status)); previous_zone_id = zone_id
			if not status.is_ok(): return BattleSnapshot.new()
	if version >= KILL_TALLY_SCHEMA_VERSION:
		var kill_tally_count: int = reader.u32()
		if kill_tally_count > result._piece_origins.size() or kill_tally_count > reader.remaining() / 8:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, kill_tally_count, result._piece_origins.size()); return BattleSnapshot.new()
		var previous_killer_id: int = 0
		for index: int in range(kill_tally_count):
			var killer_body_id: int = reader.u32(); var kill_count: int = reader.u32()
			if killer_body_id <= previous_killer_id:
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, killer_body_id, previous_killer_id); return BattleSnapshot.new()
			result._kill_tallies.append(BattleKillTally.create(killer_body_id, kill_count, status)); previous_killer_id = killer_body_id
			if not status.is_ok(): return BattleSnapshot.new()
	if version >= DAMAGE_ZONE_SCHEMA_VERSION:
		var damage_zone_count: int = reader.u32()
		if damage_zone_count > BattleLimits.ZONE_TOTAL_MAX or damage_zone_count > reader.remaining() / 12:
			status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, damage_zone_count, reader.remaining()); return BattleSnapshot.new()
		var previous_damage_zone_id: int = 0
		for index: int in range(damage_zone_count):
			var zone_id: int = reader.u32(); var damage: int = reader.i64()
			if zone_id <= previous_damage_zone_id or damage <= 0:
				status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, zone_id, previous_damage_zone_id); return BattleSnapshot.new()
			result._damage_zones.append(DamageZoneState.create(zone_id, damage, status)); previous_damage_zone_id = zone_id
			if not status.is_ok(): return BattleSnapshot.new()
	if version >= SCHEMA_VERSION:
		result._launch_contact_mask = reader.u32()
	var sim_length: int = reader.u32()
	if sim_length <= 0 or sim_length > MAX_SIM_BYTES or sim_length != reader.remaining():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, sim_length, reader.remaining()); return BattleSnapshot.new()
	result._sim_bytes = bytes.slice(reader.offset, reader.offset + sim_length); reader.offset += sim_length
	var sim_status := SimStatus.new()
	var sim_snapshot: SimSnapshot = SimSnapshot.decode(result._sim_bytes, sim_status)
	if not sim_status.is_ok() or not reader.valid or reader.offset != bytes.size():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, sim_status.code(), reader.offset); return BattleSnapshot.new()
	var validation_status := SimStatus.new()
	var restored: BattleState
	if version >= TRIGGER_SCHEMA_VERSION:
		restored = BattleState.restore_v3(
			sim_snapshot.restore_world(validation_status), result._participants, result._combatants, result._cooldowns, result._phase, result._current_actor,
			result._abstract_time, result._last_faction, result._normal_ticks, result._forced_ticks, result._forced_used,
			result._battle_result, result._next_trigger_sequence, result._trigger_records, result._motion_credits, validation_status)
	else:
		restored = BattleState.restore_with_combatants(
		sim_snapshot.restore_world(validation_status), result._participants,
		result._combatants, result._cooldowns, result._phase, result._current_actor,
		result._abstract_time, result._last_faction, result._normal_ticks,
		result._forced_ticks, result._forced_used, validation_status
		)
		if validation_status.is_ok(): result._battle_result = restored.battle_result()
	if not validation_status.is_ok():
		status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation())
		return BattleSnapshot.new()
	if version >= EFFECT_SCHEMA_VERSION:
		restored._effect_restore_content(result._content_fingerprint, result._ability_bindings, result._next_effect_sequence, validation_status)
		if not validation_status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation()); return BattleSnapshot.new()
	if version >= STATUS_SCHEMA_VERSION:
		restored._status_restore_snapshot(result._turn_index, result._identities, result._tally, result._statuses, result._next_status_sequence, result._base_body_stats, validation_status)
		if not validation_status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation()); return BattleSnapshot.new()
	if version >= DYNAMIC_SCHEMA_VERSION:
		restored._dynamic_restore_snapshot(result._expire_states, result._piece_origins, result._runtime_spawn_count, validation_status)
		if not validation_status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation()); return BattleSnapshot.new()
	if version >= ZONE_SCHEMA_VERSION:
		restored._zone_restore_snapshot(result._zone_spawns, validation_status)
		if not validation_status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation()); return BattleSnapshot.new()
	if version >= KILL_TALLY_SCHEMA_VERSION:
		restored._kill_tally_restore_snapshot(result._kill_tallies, validation_status)
		if not validation_status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation()); return BattleSnapshot.new()
	if version >= DAMAGE_ZONE_SCHEMA_VERSION:
		restored._damage_zone_restore_snapshot(result._damage_zones, validation_status)
		if not validation_status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation()); return BattleSnapshot.new()
	if version >= SCHEMA_VERSION:
		restored._clean_hit_restore_snapshot(result._launch_contact_mask, validation_status)
		if not validation_status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_DECODE, validation_status.code(), validation_status.operation()); return BattleSnapshot.new()
	result._initialized = true
	return result


func restore_state(status: SimStatus) -> BattleState:
	if not status.is_ok() or not _initialized:
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_SNAPSHOT, SimStatus.Operation.BATTLE_SNAPSHOT_RESTORE, 0, 0)
		return BattleState.new()
	var world: SimWorld = SimSnapshot.decode(_sim_bytes, status).restore_world(status)
	if not status.is_ok(): return BattleState.new()
	var restored: BattleState = BattleState.restore_v3(world, _participants, _combatants, _cooldowns, _phase, _current_actor, _abstract_time, _last_faction, _normal_ticks, _forced_ticks, _forced_used, _battle_result, _next_trigger_sequence, _trigger_records, _motion_credits, status)
	if status.is_ok(): restored._effect_restore_content(_content_fingerprint, _ability_bindings, _next_effect_sequence, status)
	if status.is_ok(): restored._status_restore_snapshot(_turn_index, _identities, _tally, _statuses, _next_status_sequence, _base_body_stats, status)
	if status.is_ok(): restored._dynamic_restore_snapshot(_expire_states, _piece_origins, _runtime_spawn_count, status)
	if status.is_ok(): restored._zone_restore_snapshot(_zone_spawns, status)
	if status.is_ok(): restored._kill_tally_restore_snapshot(_kill_tallies, status)
	if status.is_ok(): restored._damage_zone_restore_snapshot(_damage_zones, status)
	if status.is_ok(): restored._clean_hit_restore_snapshot(_launch_contact_mask, status)
	return restored

func restore_state_with_catalog(catalog: ContentCatalog, status: SimStatus) -> BattleState:
	var restored: BattleState = restore_state(status)
	if status.is_ok(): restored._status_bind_restored_catalog(catalog, status)
	return restored
