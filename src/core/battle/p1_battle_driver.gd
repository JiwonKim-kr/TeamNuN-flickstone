class_name P1BattleDriver
extends RefCounted

const TURN_LIMIT := 128

static func run(state: BattleState, status: SimStatus) -> P1BattleReport:
	var turns := 0
	var forced_count := 0
	while status.is_ok() and state.phase() != BattleState.Phase.BATTLE_END:
		match state.phase():
			BattleState.Phase.BATTLE_START: state.complete_battle_start(status)
			BattleState.Phase.TURN_START: state.complete_turn_start(status)
			BattleState.Phase.AIM:
				if turns >= TURN_LIMIT:
					status.fail(SimStatus.Code.BATTLE_TURN_LIMIT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, turns, TURN_LIMIT); break
				var command := P1DeterministicShotSupplier.command_for(state, status)
				if status.is_ok(): LaunchVelocitySolver.commit(state, command, status)
				turns += 1
			BattleState.Phase.RESOLVE:
				var was_forced := state.forced_settle_used(); state.advance_resolve(status)
				if not was_forced and state.forced_settle_used(): forced_count += 1
			BattleState.Phase.TURN_END: state.complete_turn_end(status)
			BattleState.Phase.CHECK: state.resolve_check(status)
			_: status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, state.phase(), 0)
	return P1BattleReport.create(state, turns, forced_count, status) if status.is_ok() else P1BattleReport.new()
