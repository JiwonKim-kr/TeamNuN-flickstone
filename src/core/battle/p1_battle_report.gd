class_name P1BattleReport
extends RefCounted

var result := BattleResult.Value.ONGOING
var turn_count := 0
var sim_tick_count := 0
var player_alive := 0
var enemy_alive := 0
var forced_settle_count := 0
var terminal_hash := ""

static func create(state: BattleState, turns: int, forced: int, status: SimStatus) -> P1BattleReport:
	var report := P1BattleReport.new()
	if not status.is_ok() or state == null or not BattleResult.is_terminal(state.battle_result()):
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_REPORT, SimStatus.Operation.BATTLE_REPORT_CREATE, turns, 0)
		return report
	report.result = state.battle_result(); report.turn_count = turns; report.forced_settle_count = forced
	report.sim_tick_count = state.world_copy(status).tick()
	for index: int in range(state.participant_count()):
		var item := state.participant_at(index, status)
		if item.faction() == BattleParticipant.Faction.PLAYER: report.player_alive += 1
		elif item.faction() == BattleParticipant.Faction.ENEMY: report.enemy_alive += 1
	report.terminal_hash = SimStateHash.hex_digest(BattleSnapshot.capture(state, status).encode(status), status)
	return report
