class_name P1BattleDriver
extends RefCounted

const TURN_LIMIT := 128

static func run(state: BattleState, status: SimStatus) -> P1BattleReport:
	return run_with_restore_after_turn(state, 0, status)


static func run_with_restore_after_turn(state: BattleState, restore_after_turn: int, status: SimStatus) -> P1BattleReport:
	if restore_after_turn < 0 or restore_after_turn >= TURN_LIMIT:
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, restore_after_turn, TURN_LIMIT)
		return P1BattleReport.new()
	var turns := 0
	var forced_count := 0
	var restored := false
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
			BattleState.Phase.CHECK:
				state.resolve_check(status)
				if status.is_ok() and not restored and restore_after_turn > 0 and turns == restore_after_turn and state.phase() != BattleState.Phase.BATTLE_END:
					var bytes := BattleSnapshot.capture(state, status).encode(status)
					state = BattleSnapshot.decode(bytes, status).restore_state(status)
					restored = status.is_ok()
			_: status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, state.phase(), 0)
	if status.is_ok() and restore_after_turn > 0 and not restored:
		status.fail(SimStatus.Code.INVALID_BATTLE_REPORT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, restore_after_turn, turns)
	return P1BattleReport.create(state, turns, forced_count, status) if status.is_ok() else P1BattleReport.new()
