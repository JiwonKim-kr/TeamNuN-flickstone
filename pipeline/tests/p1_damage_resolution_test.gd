extends SceneTree

const SimStatusScript := preload("res://src/core/sim/sim_status.gd")
const FixMathScript := preload("res://src/core/sim/fix_math.gd")
const FixVec2Script := preload("res://src/core/sim/fix_vec2.gd")
const SimBodyScript := preload("res://src/core/sim/sim_body.gd")
const SimEventScript := preload("res://src/core/sim/sim_event.gd")
const SimWorldScript := preload("res://src/core/sim/sim_world.gd")
const SimSnapshotScript := preload("res://src/core/sim/sim_snapshot.gd")
const SimZoneScript := preload("res://src/core/sim/sim_zone.gd")
const BattleLimitsScript := preload("res://src/core/battle/battle_limits.gd")
const BattleParticipantScript := preload("res://src/core/battle/battle_participant.gd")
const BattleCombatantScript := preload("res://src/core/battle/battle_combatant.gd")
const DamageLimitsScript := preload("res://src/core/battle/damage_limits.gd")
const DamageContextScript := preload("res://src/core/battle/damage_context.gd")
const DamageResultScript := preload("res://src/core/battle/damage_result.gd")
const DamageCalculatorScript := preload("res://src/core/battle/damage_calculator.gd")
const DamagePairCooldownScript := preload("res://src/core/battle/damage_pair_cooldown.gd")
const BattleStateScript := preload("res://src/core/battle/battle_state.gd")
const BattleSnapshotScript := preload("res://src/core/battle/battle_snapshot.gd")

var _failures: int = 0


class LegacyWriter:
	var data := PackedByteArray()
	func u8(value: int) -> void: data.append(value & 0xFF)
	func u16(value: int) -> void:
		for shift: int in range(0, 16, 8): u8(value >> shift)
	func u32(value: int) -> void:
		for shift: int in range(0, 32, 8): u8(value >> shift)
	func i64(value: int) -> void:
		for shift: int in range(0, 64, 8): u8(value >> shift)


func _check(case_id: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("[PASS] %s" % case_id)
		return
	_failures += 1
	print("[FAIL] %s %s" % [case_id, detail])


func _v(x: int, y: int, status: SimStatus) -> FixVec2:
	return FixVec2.from_ints(x, y, status)


func _body(
		x: int,
		velocity_x: int,
		mass_units: int,
		status: SimStatus,
		destructible: bool = true
) -> SimBody:
	return SimBody.create_unassigned(
		_v(x, 0, status),
		_v(velocity_x, 0, status),
		8 * FixMath.SCALE,
		mass_units * FixMath.SCALE,
		status,
		FixMath.ONE_RAW,
		destructible
	)


func _world(
		velocity_a: int,
		velocity_b: int,
		status: SimStatus,
		destructible_b: bool = true,
		reverse_input: bool = false
) -> SimWorld:
	var world: SimWorld = SimWorld.create(0x1234, 0x5678, status, 0, 0)
	var keys: Array[int] = [1, 2]
	var bodies: Array[SimBody] = [
		_body(0, velocity_a, 64, status),
		_body(16, velocity_b, 64, status, destructible_b),
	]
	if reverse_input:
		keys.reverse()
		bodies.reverse()
	world.add_initial_bodies(keys, bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count():
		world.consume_next_event(status)
	return world


func _participant(
		body_id: int, faction: int, ct: int, status: SimStatus
) -> BattleParticipant:
	return BattleParticipant.restore(
		body_id, faction, true, faction == BattleParticipant.Faction.PLAYER,
		true, 100, ct, status
	)


func _combatant(
		body_id: int, faction: int, hp: int, attack: int, status: SimStatus
) -> BattleCombatant:
	return BattleCombatant.create(body_id, faction, hp, attack, 0, status)


func _battle(
		velocity_a: int,
		velocity_b: int,
		hp_a: int,
		hp_b: int,
		attack_a: int,
		attack_b: int,
		status: SimStatus,
		reverse_input: bool = false
) -> BattleState:
	var world: SimWorld = _world(
		velocity_a, velocity_b, status, true, reverse_input
	)
	var participants: Array[BattleParticipant] = [
		_participant(1, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, status),
		_participant(2, BattleParticipant.Faction.ENEMY, 0, status),
	]
	var combatants: Array[BattleCombatant] = [
		_combatant(1, BattleParticipant.Faction.PLAYER, hp_a, attack_a, status),
		_combatant(2, BattleParticipant.Faction.ENEMY, hp_b, attack_b, status),
	]
	return BattleState.restore_with_combatants(
		world, participants, combatants, [], BattleState.Phase.RESOLVE, 1,
		0, BattleParticipant.Faction.INVALID, 0, 0, false, status
	)


func _context(
		attack: int,
		victim_hp: int,
		attacker_mass_units: int,
		victim_mass_units: int,
		impact_speed_units: int,
		friendly: bool,
		critical: bool,
		outgoing_bonus_raw: int,
		incoming_reduction_raw: int,
		fixed_increase: int,
		fixed_reduction: int,
		status: SimStatus
) -> DamageContext:
	return DamageContext.create(
		1, 2, attack, victim_hp, attacker_mass_units * FixMath.SCALE,
		victim_mass_units * FixMath.SCALE, impact_speed_units * FixMath.SCALE,
		friendly, critical, outgoing_bonus_raw, incoming_reduction_raw,
		fixed_increase, fixed_reduction, status
	)


func _world_bytes(state: BattleState, status: SimStatus) -> PackedByteArray:
	return SimSnapshot.capture(state.world_copy(status), status).encode(status)


func _append_collision_event(
		state: BattleState,
		approach_speed_raw: int,
		flags: int,
		valid_payload: bool,
		status: SimStatus
) -> void:
	var world: SimWorld = state._world
	var sequence: int = world.next_event_sequence()
	var packed_masses: int = 0
	if valid_payload:
		packed_masses = SimEvent.pack_collision_masses(
			64 * FixMath.SCALE, 64 * FixMath.SCALE, status
		)
	var event: SimEvent = SimEvent.create(
		world.tick(), 0, sequence, SimEvent.TypeId.BODY_COLLIDED,
		1, 2, 0, SimEvent.CauseId.NONE, FixVec2.zero(),
		FixVec2.from_raw(FixMath.ONE_RAW, 0), approach_speed_raw,
		packed_masses, flags, status
	)
	if status.is_ok():
		world._events.append(event)
		world._next_event_sequence = sequence + 1


func _first_collision(world: SimWorld, status: SimStatus) -> SimEvent:
	while status.is_ok() and world.event_cursor() < world.event_count():
		var event: SimEvent = world.consume_next_event(status)
		if event.type_id() == SimEvent.TypeId.BODY_COLLIDED:
			return event
	return null


func _test_formula() -> void:
	var status := SimStatus.new()
	var cases: Array[Array] = [
		[100, 999, 64, 64, 63, false, false, 0, 0, 0, 0, 0, 0, 0],
		[100, 999, 64, 64, 64, false, false, 0, 0, 0, 0, FixMath.SCALE, 6, 6],
		[100, 999, 64, 64, 1024, false, false, 0, 0, 0, 0, FixMath.SCALE, 100, 100],
		[100, 999, 64, 256, 1024, false, false, 0, 0, 0, 0, FixMath.SCALE / 2, 50, 50],
		[100, 999, 256, 64, 1024, false, false, 0, 0, 0, 0, 2 * FixMath.SCALE, 200, 200],
		[100, 999, 256, 16, 1024, false, false, 0, 0, 0, 0, 2 * FixMath.SCALE, 200, 200],
		[100, 999, 16, 256, 1024, false, false, 0, 0, 0, 0, FixMath.SCALE / 2, 50, 50],
		[100, 999, 64, 64, 1024, true, true, FixMath.SCALE / 4, 13107, 7, 3, FixMath.SCALE, 104, 104],
	]
	var all_match: bool = true
	for item: Array in cases:
		var result: DamageResult = DamageCalculator.resolve(
			_context(
				item[0], item[1], item[2], item[3], item[4], item[5], item[6],
				item[7], item[8], item[9], item[10], status
			),
			status
		)
		all_match = (
			all_match and status.is_ok()
			and result.weight_ratio_raw() == item[11]
			and result.resolved_damage() == item[12]
			and result.applied_damage() == item[13]
		)
	_check("P1-DAMAGE-FORMULA-KAT-001", all_match, "status=%d" % status.code())
	var edge_status := SimStatus.new()
	var edge_context: DamageContext = DamageContext.create(
		1, 2, 100, 999, 64 * FixMath.SCALE, 64 * FixMath.SCALE,
		DamageLimits.DAMAGE_THRESHOLD_SPEED_RAW - 1, false, false,
		0, 0, 0, 0, edge_status
	)
	var edge_result: DamageResult = DamageCalculator.resolve(
		edge_context, edge_status
	)
	_check(
		"P1-DAMAGE-THRESHOLD-RAW-001",
		edge_status.is_ok() and not edge_result.has_damage()
	)
	var repeated: bool = true
	for index: int in range(1000):
		var local_status := SimStatus.new()
		var result: DamageResult = DamageCalculator.resolve(
			_context(137, 91, 48, 96, 777, false, false, 0, 0, 0, 0, local_status),
			local_status
		)
		repeated = repeated and local_status.is_ok() and result.resolved_damage() == 74
	_check("P1-DAMAGE-REPEAT-1000-001", repeated)


func _test_collision_payload() -> void:
	var status := SimStatus.new()
	var world: SimWorld = _world(128, 0, status)
	world.step(status)
	var collision: SimEvent = _first_collision(world, status)
	_check(
		"P1-COLLISION-FACT-001",
		status.is_ok() and collision != null
		and collision.value_a() == 128 * FixMath.SCALE
		and collision.collision_source_mass_raw(status) == 64 * FixMath.SCALE
		and collision.collision_target_mass_raw(status) == 64 * FixMath.SCALE
		and collision.collision_speed_order(status) == SimEvent.COLLISION_SOURCE_FASTER
	)
	var target_status := SimStatus.new()
	var target_world: SimWorld = _world(0, -128, target_status)
	target_world.step(target_status)
	var target_collision: SimEvent = _first_collision(
		target_world, target_status
	)
	var tie_status := SimStatus.new()
	var tie_world: SimWorld = _world(64, -64, tie_status)
	tie_world.step(tie_status)
	var tie_collision: SimEvent = _first_collision(tie_world, tie_status)
	_check(
		"P1-COLLISION-SPEED-ORDER-001",
		target_status.is_ok() and tie_status.is_ok()
		and target_collision != null and tie_collision != null
		and target_collision.collision_speed_order(target_status)
			== SimEvent.COLLISION_TARGET_FASTER
		and tie_collision.collision_speed_order(tie_status)
			== SimEvent.COLLISION_SPEED_TIE
	)
	var malformed_status := SimStatus.new()
	var malformed: SimEvent = SimEvent.create(
		0, 0, 1, SimEvent.TypeId.BODY_COLLIDED, 1, 2, 0,
		SimEvent.CauseId.NONE, FixVec2.zero(), FixVec2.zero(),
		128 * FixMath.SCALE, 0, 0, malformed_status
	)
	malformed.collision_source_mass_raw(malformed_status)
	_check(
		"P1-COLLISION-FACT-REJECT-001",
		malformed_status.code() == SimStatus.Code.INVALID_COLLISION_FACT
	)


func _test_destroy_api() -> void:
	var status := SimStatus.new()
	var world: SimWorld = _world(0, 0, status, false)
	var before: PackedByteArray = SimSnapshot.capture(world, status).encode(status)
	var rejected_status := SimStatus.new()
	world.destroy_body(2, 1, rejected_status)
	var after: PackedByteArray = SimSnapshot.capture(world, status).encode(status)
	_check(
		"P1-DAMAGE-DESTROY-ATOMIC-001",
		not rejected_status.is_ok() and before == after and world.body_count() == 2
	)
	world.destroy_body(1, 2, status)
	var event: SimEvent = world.consume_next_event(status)
	_check(
		"P1-DAMAGE-DESTROY-001",
		status.is_ok() and world.body_count() == 1
		and event.type_id() == SimEvent.TypeId.BODY_DESTROYED
		and event.cause_id() == SimEvent.CauseId.DAMAGE
		and event.source_body_id() == 1 and event.target_body_id() == 2
	)


func _test_battle_damage_and_cooldown() -> void:
	var status := SimStatus.new()
	var state: BattleState = _battle(128, 0, 100, 100, 100, 100, status)
	state.advance_resolve(status)
	var target: BattleCombatant = state.combatant_by_body_id(2, status)
	var cooldown: DamagePairCooldown = state.cooldown_at(0, status)
	_check(
		"P1-BATTLE-DAMAGE-001",
		status.is_ok() and target.current_hp() == 87 and state.cooldown_count() == 1
		and cooldown.low_body_id() == 1 and cooldown.high_body_id() == 2
		and cooldown.next_allowed_tick() == 12
	)
	var below_status := SimStatus.new()
	var below: BattleState = _battle(32, 0, 100, 100, 100, 100, below_status)
	below.advance_resolve(below_status)
	_check(
		"P1-BATTLE-THRESHOLD-001",
		below_status.is_ok() and below.cooldown_count() == 0
		and below.combatant_by_body_id(2, below_status).current_hp() == 100
	)
	var tick_11_status := SimStatus.new()
	var tick_11: BattleState = _battle(
		0, 0, 100, 100, 100, 100, tick_11_status
	)
	for index: int in range(11):
		tick_11._world.step(tick_11_status)
	var tick_11_cooldowns: Array[DamagePairCooldown] = [
		DamagePairCooldown.create(1, 2, 12, tick_11_status)
	]
	tick_11._cooldowns = tick_11_cooldowns
	_append_collision_event(
		tick_11, 128 * FixMath.SCALE,
		SimEvent.FLAG_COLLISION_SOURCE_FASTER, true, tick_11_status
	)
	tick_11.advance_resolve(tick_11_status)
	var tick_12_status := SimStatus.new()
	var tick_12: BattleState = _battle(
		0, 0, 100, 100, 100, 100, tick_12_status
	)
	for index: int in range(12):
		tick_12._world.step(tick_12_status)
	var tick_12_cooldowns: Array[DamagePairCooldown] = [
		DamagePairCooldown.create(1, 2, 12, tick_12_status)
	]
	tick_12._cooldowns = tick_12_cooldowns
	_append_collision_event(
		tick_12, 128 * FixMath.SCALE,
		SimEvent.FLAG_COLLISION_SOURCE_FASTER, true, tick_12_status
	)
	tick_12.advance_resolve(tick_12_status)
	_check(
		"P1-BATTLE-COOLDOWN-11-12-001",
		tick_11_status.is_ok() and tick_12_status.is_ok()
		and tick_11.combatant_by_body_id(2, tick_11_status).current_hp() == 100
		and tick_12.combatant_by_body_id(2, tick_12_status).current_hp() == 87
	)


func _test_faction_and_critical_boundaries() -> void:
	var neutral_status := SimStatus.new()
	var neutral_world: SimWorld = SimWorld.create(
		0x44, 0x55, neutral_status, 0, 0
	)
	var neutral_keys: Array[int] = [1, 2, 3]
	var neutral_bodies: Array[SimBody] = [
		_body(0, 128, 64, neutral_status),
		_body(16, 0, 64, neutral_status),
		_body(100, 0, 64, neutral_status),
	]
	neutral_world.add_initial_bodies(
		neutral_keys, neutral_bodies, neutral_status
	)
	while (
		neutral_status.is_ok()
		and neutral_world.event_cursor() < neutral_world.event_count()
	):
		neutral_world.consume_next_event(neutral_status)
	var neutral_participants: Array[BattleParticipant] = [
		_participant(3, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, neutral_status),
	]
	var neutral_combatants: Array[BattleCombatant] = [
		_combatant(1, BattleParticipant.Faction.NEUTRAL, 100, 100, neutral_status),
		_combatant(2, BattleParticipant.Faction.NEUTRAL, 100, 100, neutral_status),
	]
	var neutral: BattleState = BattleState.restore_with_combatants(
		neutral_world, neutral_participants, neutral_combatants, [],
		BattleState.Phase.RESOLVE, 3, 0, BattleParticipant.Faction.INVALID,
		0, 0, false, neutral_status
	)
	neutral.advance_resolve(neutral_status)
	var friendly_status := SimStatus.new()
	var friendly_world: SimWorld = _world(128, 0, friendly_status)
	var friendly_participants: Array[BattleParticipant] = [
		_participant(1, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, friendly_status),
		_participant(2, BattleParticipant.Faction.PLAYER, 0, friendly_status),
	]
	var friendly_combatants: Array[BattleCombatant] = [
		_combatant(1, BattleParticipant.Faction.PLAYER, 100, 100, friendly_status),
		_combatant(2, BattleParticipant.Faction.PLAYER, 100, 100, friendly_status),
	]
	var friendly: BattleState = BattleState.restore_with_combatants(
		friendly_world, friendly_participants, friendly_combatants, [],
		BattleState.Phase.RESOLVE, 1, 0, BattleParticipant.Faction.INVALID,
		0, 0, false, friendly_status
	)
	friendly.advance_resolve(friendly_status)
	_check(
		"P1-BATTLE-NEUTRAL-FRIENDLY-001",
		neutral_status.is_ok() and friendly_status.is_ok()
		and neutral.combatant_by_body_id(2, neutral_status).current_hp() == 87
		and friendly.combatant_by_body_id(2, friendly_status).current_hp() == 94,
		"neutral_status=%d friendly_status=%d neutral_hp=%d friendly_hp=%d" % [
			neutral_status.code(), friendly_status.code(),
			neutral.combatant_by_body_id(2, SimStatus.new()).current_hp(),
			friendly.combatant_by_body_id(2, SimStatus.new()).current_hp(),
		]
	)
	var critical_status := SimStatus.new()
	var critical_world: SimWorld = _world(0, 0, critical_status)
	var before: PackedByteArray = SimSnapshot.capture(
		critical_world, critical_status
	).encode(critical_status)
	var critical_participants: Array[BattleParticipant] = [
		_participant(1, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, critical_status),
		_participant(2, BattleParticipant.Faction.ENEMY, 0, critical_status),
	]
	var critical_combatants: Array[BattleCombatant] = [
		BattleCombatant.create(1, BattleParticipant.Faction.PLAYER, 100, 100, 1, critical_status),
		_combatant(2, BattleParticipant.Faction.ENEMY, 100, 100, critical_status),
	]
	var rejected_status := SimStatus.new()
	BattleState.create_with_combatants(
		critical_world, critical_participants, critical_combatants, rejected_status
	)
	var after: PackedByteArray = SimSnapshot.capture(
		critical_world, critical_status
	).encode(critical_status)
	_check(
		"P1-BATTLE-CRITICAL-REJECT-001",
		critical_status.is_ok()
		and rejected_status.code() == SimStatus.Code.INVALID_COMBATANT
		and before == after
	)


func _test_lethal_and_tie() -> void:
	var status := SimStatus.new()
	var lethal: BattleState = _battle(128, 0, 100, 10, 100, 100, status)
	lethal.advance_resolve(status)
	var lethal_world: SimWorld = lethal.world_copy(status)
	_check(
		"P1-BATTLE-LETHAL-001",
		status.is_ok() and lethal_world.body_count() == 1
		and lethal.combatant_count() == 1 and lethal.participant_count() == 1
		and lethal.cooldown_count() == 0
	)
	var tie_status := SimStatus.new()
	var tie: BattleState = _battle(64, -64, 10, 10, 100, 100, tie_status)
	tie.advance_resolve(tie_status)
	_check(
		"P1-BATTLE-TIE-SIMULTANEOUS-001",
		tie_status.is_ok() and tie.world_copy(tie_status).body_count() == 0
		and tie.combatant_count() == 0 and tie.participant_count() == 0
	)


func _test_chain_and_kill_cause() -> void:
	var chain_status := SimStatus.new()
	var chain_world: SimWorld = SimWorld.create(
		0xCA, 0xFE, chain_status, 0, 0
	)
	var chain_keys: Array[int] = [1, 2, 3]
	var chain_bodies: Array[SimBody] = [
		_body(0, 256, 64, chain_status),
		_body(16, 0, 64, chain_status),
		_body(32, 0, 64, chain_status),
	]
	chain_world.add_initial_bodies(chain_keys, chain_bodies, chain_status)
	while chain_status.is_ok() and chain_world.event_cursor() < chain_world.event_count():
		chain_world.consume_next_event(chain_status)
	var chain_participants: Array[BattleParticipant] = [
		_participant(1, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, chain_status),
		_participant(2, BattleParticipant.Faction.ENEMY, 0, chain_status),
		_participant(3, BattleParticipant.Faction.ENEMY, 0, chain_status),
	]
	var chain_combatants: Array[BattleCombatant] = [
		_combatant(1, BattleParticipant.Faction.PLAYER, 100, 100, chain_status),
		_combatant(2, BattleParticipant.Faction.ENEMY, 10, 100, chain_status),
		_combatant(3, BattleParticipant.Faction.ENEMY, 100, 100, chain_status),
	]
	var chain: BattleState = BattleState.restore_with_combatants(
		chain_world, chain_participants, chain_combatants, [],
		BattleState.Phase.RESOLVE, 1, 0, BattleParticipant.Faction.INVALID,
		0, 0, false, chain_status
	)
	chain.advance_resolve(chain_status)
	_check(
		"P1-BATTLE-CHAIN-HP0-001",
		chain_status.is_ok() and chain.combatant_count() == 2
		and chain.combatant_by_body_id(3, chain_status).current_hp() == 100,
		"status=%d combatants=%d" % [chain_status.code(), chain.combatant_count()]
	)

	var kill_status := SimStatus.new()
	var kill_world: SimWorld = SimWorld.create(0xBA, 0xBE, kill_status, 0, 0)
	var zone_left_raw: int = 16 * FixMath.SCALE + FixMath.SCALE / 4
	var zone_right_raw: int = 16 * FixMath.SCALE + 3 * FixMath.SCALE / 4
	var zone_bottom_raw: int = -20 * FixMath.SCALE
	var zone_top_raw: int = 20 * FixMath.SCALE
	var zone_vertices: Array[FixVec2] = [
		FixVec2.from_raw(zone_left_raw, zone_bottom_raw),
		FixVec2.from_raw(zone_right_raw, zone_bottom_raw),
		FixVec2.from_raw(zone_right_raw, zone_top_raw),
		FixVec2.from_raw(zone_left_raw, zone_top_raw),
	]
	var zone_keys: Array[int] = [1]
	var zones: Array[SimZone] = [
		SimZone.create_unassigned(
			zone_vertices, FixMath.ONE_RAW, FixVec2.zero(), kill_status,
			SimZone.FLAG_KILL
		)
	]
	kill_world.add_initial_zones(zone_keys, zones, kill_status)
	var kill_keys: Array[int] = [1, 2]
	var kill_bodies: Array[SimBody] = [
		_body(0, 128, 64, kill_status), _body(16, 0, 64, kill_status)
	]
	kill_world.add_initial_bodies(kill_keys, kill_bodies, kill_status)
	while kill_status.is_ok() and kill_world.event_cursor() < kill_world.event_count():
		kill_world.consume_next_event(kill_status)
	var kill_participants: Array[BattleParticipant] = [
		_participant(1, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, kill_status),
		_participant(2, BattleParticipant.Faction.ENEMY, 0, kill_status),
	]
	var kill_combatants: Array[BattleCombatant] = [
		_combatant(1, BattleParticipant.Faction.PLAYER, 100, 100, kill_status),
		_combatant(2, BattleParticipant.Faction.ENEMY, 10, 100, kill_status),
	]
	var kill_state: BattleState = BattleState.restore_with_combatants(
		kill_world, kill_participants, kill_combatants, [],
		BattleState.Phase.RESOLVE, 1, 0, BattleParticipant.Faction.INVALID,
		0, 0, false, kill_status
	)
	kill_state.advance_resolve(kill_status)
	var settled_world: SimWorld = kill_state.world_copy(kill_status)
	var kill_destroy_count: int = 0
	var damage_destroy_count: int = 0
	for index: int in range(settled_world.event_count()):
		var event: SimEvent = settled_world.event_at(index, kill_status)
		if event.type_id() == SimEvent.TypeId.BODY_DESTROYED:
			if event.cause_id() == SimEvent.CauseId.KILL_ZONE:
				kill_destroy_count += 1
			elif event.cause_id() == SimEvent.CauseId.DAMAGE:
				damage_destroy_count += 1
	_check(
		"P1-BATTLE-KILL-CAUSE-PRESERVE-001",
		kill_status.is_ok() and settled_world.body_count() == 1
		and kill_destroy_count == 1 and damage_destroy_count == 0,
		"status=%d bodies=%d kill=%d damage=%d events=%d" % [
			kill_status.code(), settled_world.body_count(), kill_destroy_count,
			damage_destroy_count, settled_world.event_count(),
		]
	)


func _test_atomic_rollback() -> void:
	var malformed_status := SimStatus.new()
	var malformed: BattleState = _battle(
		0, 0, 100, 100, 100, 100, malformed_status
	)
	_append_collision_event(
		malformed, 128 * FixMath.SCALE,
		SimEvent.FLAG_COLLISION_SOURCE_FASTER, false, malformed_status
	)
	var malformed_before: PackedByteArray = _world_bytes(
		malformed, malformed_status
	)
	var malformed_phase: int = malformed.phase()
	var malformed_hp: int = malformed.combatant_by_body_id(
		2, malformed_status
	).current_hp()
	var failure_status := SimStatus.new()
	malformed.advance_resolve(failure_status)
	var compare_status := SimStatus.new()
	var malformed_after: PackedByteArray = _world_bytes(
		malformed, compare_status
	)
	_check(
		"P1-BATTLE-MALFORMED-ROLLBACK-001",
		malformed_status.is_ok() and compare_status.is_ok()
		and failure_status.code() == SimStatus.Code.INVALID_COLLISION_FACT
		and malformed_before == malformed_after
		and malformed.phase() == malformed_phase
		and malformed.combatant_by_body_id(2, compare_status).current_hp()
			== malformed_hp
		and malformed.cooldown_count() == 0
	)

	var destroy_status := SimStatus.new()
	var destroy_failure: BattleState = _battle(
		0, 0, 100, 10, 100, 100, destroy_status
	)
	destroy_failure._world._bodies[1]._destructible = false
	_append_collision_event(
		destroy_failure, 128 * FixMath.SCALE,
		SimEvent.FLAG_COLLISION_SOURCE_FASTER, true, destroy_status
	)
	var destroy_before: PackedByteArray = _world_bytes(
		destroy_failure, destroy_status
	)
	var destroy_failure_status := SimStatus.new()
	destroy_failure.advance_resolve(destroy_failure_status)
	var destroy_compare_status := SimStatus.new()
	var destroy_after: PackedByteArray = _world_bytes(
		destroy_failure, destroy_compare_status
	)
	_check(
		"P1-BATTLE-DESTROY-ROLLBACK-001",
		destroy_status.is_ok() and destroy_compare_status.is_ok()
		and not destroy_failure_status.is_ok()
		and destroy_before == destroy_after
		and destroy_failure.combatant_by_body_id(
			2, destroy_compare_status
		).current_hp() == 10
		and destroy_failure.cooldown_count() == 0
	)

	var overflow_status := SimStatus.new()
	var overflow_context: DamageContext = _context(
		100, 100, 64, 64, 1024, false, false,
		FixMath.INT64_MAX, 0, 0, 0, overflow_status
	)
	DamageCalculator.resolve(overflow_context, overflow_status)
	_check(
		"P1-DAMAGE-OVERFLOW-REJECT-001",
		overflow_status.code() == SimStatus.Code.INT64_OVERFLOW
	)


func _legacy_v1_bytes(state: BattleState, status: SimStatus) -> PackedByteArray:
	var writer := LegacyWriter.new()
	writer.data.append_array(BattleSnapshot.MAGIC)
	writer.u16(BattleSnapshot.LEGACY_SCHEMA_VERSION)
	writer.u16(state.phase()); writer.u32(state.current_actor_body_id())
	writer.i64(state.abstract_time()); writer.u16(state.last_acted_faction())
	writer.u32(state.normal_resolve_ticks()); writer.u32(state.forced_resolve_ticks())
	writer.u8(1 if state.forced_settle_used() else 0)
	writer.u32(state.participant_count())
	for index: int in range(state.participant_count()):
		var item: BattleParticipant = state.participant_at(index, status)
		writer.u32(item.body_id()); writer.u16(item.faction())
		writer.u8(1 if item.has_turn() else 0); writer.u8(1 if item.controllable() else 0)
		writer.u8(1 if item.counts_for_victory() else 0); writer.u16(item.speed_stat())
		writer.i64(item.ct())
	var sim_bytes: PackedByteArray = SimSnapshot.capture(
		state.world_copy(status), status
	).encode(status)
	writer.u32(sim_bytes.size()); writer.data.append_array(sim_bytes)
	return writer.data


func _test_snapshot_compatibility() -> void:
	var status := SimStatus.new()
	var state: BattleState = _battle(128, 0, 100, 100, 100, 100, status)
	state.advance_resolve(status)
	var encoded: PackedByteArray = BattleSnapshot.capture(state, status).encode(status)
	var restored: BattleState = BattleSnapshot.decode(encoded, status).restore_state(status)
	var reencoded: PackedByteArray = BattleSnapshot.capture(restored, status).encode(status)
	_check(
		"P1-SNAPSHOT-V3-ROUNDTRIP-001",
		status.is_ok() and encoded[9] == 3 and encoded[10] == 0
		and encoded == reencoded and restored.combatant_count() == 2
		and restored.cooldown_count() == 1
	)
	var copy_status := SimStatus.new()
	var copied: BattleState = state.copy(copy_status)
	var original_hp: int = state.combatant_by_body_id(2, copy_status).current_hp()
	state._combatants[1] = state._combatants[1].with_current_hp(
		original_hp - 1, copy_status
	)
	state._cooldowns[0] = DamagePairCooldown.create(1, 2, 99, copy_status)
	_check(
		"P1-BATTLE-DEEP-COPY-001",
		copy_status.is_ok()
		and copied.combatant_by_body_id(2, copy_status).current_hp() == original_hp
		and copied.cooldown_at(0, copy_status).next_allowed_tick() == 12
	)
	var continuation_status := SimStatus.new()
	for index: int in range(24):
		if restored.phase() == BattleState.Phase.RESOLVE:
			restored.advance_resolve(continuation_status)
		if copied.phase() == BattleState.Phase.RESOLVE:
			copied.advance_resolve(continuation_status)
		if (
			restored.phase() != BattleState.Phase.RESOLVE
			and copied.phase() != BattleState.Phase.RESOLVE
		):
			break
	var restored_continuation: PackedByteArray = BattleSnapshot.capture(
		restored, continuation_status
	).encode(continuation_status)
	var copied_continuation: PackedByteArray = BattleSnapshot.capture(
		copied, continuation_status
	).encode(continuation_status)
	_check(
		"P1-SNAPSHOT-CONTINUATION-001",
		continuation_status.is_ok()
		and restored_continuation == copied_continuation
	)
	var legacy_status := SimStatus.new()
	var legacy_world: SimWorld = _world(0, 0, legacy_status)
	var legacy_participants: Array[BattleParticipant] = [
		_participant(1, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, legacy_status),
		_participant(2, BattleParticipant.Faction.ENEMY, 0, legacy_status),
	]
	var legacy_state: BattleState = BattleState.create(
		legacy_world, legacy_participants, legacy_status
	)
	legacy_state.complete_battle_start(legacy_status)
	var legacy_bytes: PackedByteArray = _legacy_v1_bytes(legacy_state, legacy_status)
	var legacy_restored: BattleState = BattleSnapshot.decode(
		legacy_bytes, legacy_status
	).restore_state(legacy_status)
	_check(
		"P1-SNAPSHOT-V1-COMPAT-001",
		legacy_status.is_ok() and legacy_restored.is_initialized()
		and legacy_restored.combatant_count() == 0
		and legacy_restored.cooldown_count() == 0
	)


func _test_spawn_and_order_determinism() -> void:
	var status := SimStatus.new()
	var world: SimWorld = SimWorld.create(1, 2, status)
	var keys: Array[int] = [1]
	var bodies: Array[SimBody] = [_body(0, 0, 64, status)]
	world.add_initial_bodies(keys, bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count():
		world.consume_next_event(status)
	var participants: Array[BattleParticipant] = [
		_participant(1, BattleParticipant.Faction.PLAYER, BattleLimits.CT_THRESHOLD, status)
	]
	var combatants: Array[BattleCombatant] = [
		_combatant(1, BattleParticipant.Faction.PLAYER, 100, 100, status)
	]
	var state: BattleState = BattleState.create_with_combatants(
		world, participants, combatants, status
	)
	state.queue_combatant_body_spawn(
		_body(64, 0, 64, status),
		BattleParticipant.create_unassigned(
			BattleParticipant.Faction.ENEMY, true, false, true, 100, status
		),
		BattleCombatant.create_unassigned(
			BattleParticipant.Faction.ENEMY, 50, 25, 0, status
		),
		1, 7, 0, status
	)
	state.complete_battle_start(status)
	_check(
		"P1-COMBATANT-SPAWN-001",
		status.is_ok() and state.combatant_count() == 2
		and state.combatant_by_body_id(2, status).current_hp() == 50
	)
	var left_status := SimStatus.new()
	var right_status := SimStatus.new()
	var left: BattleState = _battle(128, 0, 100, 100, 100, 100, left_status, false)
	var right: BattleState = _battle(128, 0, 100, 100, 100, 100, right_status, true)
	left.advance_resolve(left_status); right.advance_resolve(right_status)
	var left_bytes: PackedByteArray = BattleSnapshot.capture(left, left_status).encode(left_status)
	var right_bytes: PackedByteArray = BattleSnapshot.capture(right, right_status).encode(right_status)
	_check(
		"P1-DAMAGE-INSERTION-ORDER-001",
		left_status.is_ok() and right_status.is_ok() and left_bytes == right_bytes
	)


func _initialize() -> void:
	print("== P1-3 Damage Resolution / Destruction ==")
	_check(
		"P1-DAMAGE-ENUM-001",
		SimStatus.Code.INVALID_COLLISION_FACT == 27
		and SimStatus.Operation.BATTLE_DAMAGE_EVENT == 94
		and SimEvent.CauseId.DAMAGE == 3
		and BattleSnapshot.SCHEMA_VERSION == 3
	)
	_test_formula()
	_test_collision_payload()
	_test_destroy_api()
	_test_battle_damage_and_cooldown()
	_test_faction_and_critical_boundaries()
	_test_lethal_and_tie()
	_test_chain_and_kill_cause()
	_test_atomic_rollback()
	_test_snapshot_compatibility()
	_test_spawn_and_order_determinism()
	if _failures == 0:
		print("P1_DAMAGE_RESOLUTION_RESULT: PASS")
		quit(0)
	else:
		print("P1_DAMAGE_RESOLUTION_RESULT: FAIL (%d)" % _failures)
		quit(1)
