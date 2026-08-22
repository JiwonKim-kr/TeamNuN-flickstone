class_name P1GrayboxFixture
extends RefCounted
## Approved P1-only deterministic 3v3 encounter; not product balance data.

const FIXTURE_ID := "p1_graybox_v1"
const WIDTH := 1024
const HEIGHT := 640
const RADIUS := 32
const MASS := 64
const HP := 100
const ATTACK := 20
const SPEEDS: Array[int] = [80, 100, 125]

static func create(seed_hi: int, seed_lo: int, reverse_insertion: bool, status: SimStatus) -> BattleState:
	var world := SimWorld.create(seed_hi, seed_lo, status)
	var boundary: Array[FixVec2] = [FixVec2.from_ints(0, 0, status), FixVec2.from_ints(WIDTH, 0, status), FixVec2.from_ints(WIDTH, HEIGHT, status), FixVec2.from_ints(0, HEIGHT, status)]
	world.configure_boundary(boundary, SimWorld.BoundaryType.WALL, status)
	# The approved fixture does not prescribe coordinates. A symmetric, tightly
	# packed center line reaches combat immediately and keeps batch verification
	# practical without changing physics, stats, power, or arena bounds.
	var positions: Array[FixVec2] = [FixVec2.from_ints(337, 320, status), FixVec2.from_ints(407, 320, status), FixVec2.from_ints(477, 320, status), FixVec2.from_ints(547, 320, status), FixVec2.from_ints(617, 320, status), FixVec2.from_ints(687, 320, status)]
	var keys: Array[int] = [10, 20, 30, 40, 50, 60]
	var bodies: Array[SimBody] = []
	for position: FixVec2 in positions: bodies.append(SimBody.create_unassigned(position, FixVec2.zero(), RADIUS * FixMath.SCALE, MASS * FixMath.SCALE, status))
	if reverse_insertion: keys.reverse(); bodies.reverse()
	world.add_initial_bodies(keys, bodies, status)
	while status.is_ok() and world.event_cursor() < world.event_count(): world.consume_next_event(status)
	var participants: Array[BattleParticipant] = []
	var combatants: Array[BattleCombatant] = []
	for index: int in range(6):
		var faction := BattleParticipant.Faction.PLAYER if index < 3 else BattleParticipant.Faction.ENEMY
		participants.append(BattleParticipant.create(index + 1, faction, true, faction == BattleParticipant.Faction.PLAYER, true, SPEEDS[index % 3], status))
		combatants.append(BattleCombatant.create(index + 1, faction, HP, ATTACK, 0, status))
	if not status.is_ok(): return BattleState.new()
	return BattleState.create_with_combatants(world, participants, combatants, status)
