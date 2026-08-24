class_name P2ContentBattleDriver
extends RefCounted
## P2 content-aware orchestration adapter. It composes approved core APIs only.

const TURN_LIMIT := 128


static func resolve_last_transition(state: BattleState, status: SimStatus) -> Array[BattleTriggerRecord]:
	var observed: Array[BattleTriggerRecord] = []
	if not status.is_ok() or state == null or not state.is_initialized():
		if status.is_ok(): status.fail(SimStatus.Code.INVALID_BATTLE_STATE, SimStatus.Operation.EFFECT_RESOLVE_TRANSITION)
		return observed
	var inputs: Array[BattleTriggerRecord] = []
	for index: int in range(state.trigger_record_count()):
		var record: BattleTriggerRecord = state.trigger_record_at(index, status)
		inputs.append(record)
		observed.append(record.copy())
	if not status.is_ok() or inputs.is_empty():
		return observed
	var report: EffectResolutionReport = EffectResolver.resolve_transition(
		state,
		state.ability_registry(status),
		inputs,
		state.content_fingerprint_bytes(),
		status
	)
	if not status.is_ok():
		return []
	for index: int in range(report.generated_record_count()):
		observed.append(report.generated_record_at(index, status))
	return observed


static func _faction_for(body_id: int, participants: Array[BattleParticipant]) -> int:
	for item: BattleParticipant in participants:
		if item.body_id() == body_id:
			return item.faction()
	return BattleParticipant.Faction.INVALID


static func _observe(records: Array[BattleTriggerRecord], participants: Array[BattleParticipant], metrics: Array[int], status: SimStatus) -> void:
	for record: BattleTriggerRecord in records:
		if record.trigger_id() == BattleTriggerId.Value.ON_HIT_DEAL:
			var faction: int = _faction_for(record.subject_body_id(), participants)
			if faction == BattleParticipant.Faction.PLAYER: metrics[0] += record.value_a()
			elif faction == BattleParticipant.Faction.ENEMY: metrics[1] += record.value_a()
			else: status.fail(SimStatus.Code.INVALID_BATTLE_REPORT, SimStatus.Operation.BATTLE_REPORT_CREATE, record.subject_body_id(), faction)
		elif record.trigger_id() == BattleTriggerId.Value.ON_DEATH_SELF:
			match record.cause_id():
				SimEvent.CauseId.DAMAGE: metrics[2] += 1
				SimEvent.CauseId.KILL_BOUNDARY: metrics[3] += 1
				SimEvent.CauseId.KILL_ZONE: metrics[4] += 1


static func run(catalog: ContentCatalog, state: BattleState, status: SimStatus) -> P1BattleReport:
	return run_with_restore_after_turn(catalog, state, 0, status)


static func run_with_restore_after_turn(catalog: ContentCatalog, state: BattleState, restore_after_turn: int, status: SimStatus) -> P1BattleReport:
	if restore_after_turn < 0 or restore_after_turn >= TURN_LIMIT or catalog == null or not catalog.is_initialized():
		status.fail(SimStatus.Code.INVALID_ARGUMENT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, restore_after_turn, TURN_LIMIT)
		return P1BattleReport.new()
	var turns := 0
	var metrics: Array[int] = [0, 0, 0, 0, 0, 0]
	var initial_participants: Array[BattleParticipant] = []
	for index: int in range(state.participant_count()): initial_participants.append(state.participant_at(index, status))
	var restored := false
	_observe(resolve_last_transition(state, status), initial_participants, metrics, status)
	while status.is_ok() and state.phase() != BattleState.Phase.BATTLE_END:
		var records: Array[BattleTriggerRecord] = []
		match state.phase():
			BattleState.Phase.BATTLE_START:
				state.complete_battle_start(status); records = resolve_last_transition(state, status)
			BattleState.Phase.TURN_START:
				state.complete_turn_start(status); records = resolve_last_transition(state, status)
			BattleState.Phase.AIM:
				if turns >= TURN_LIMIT:
					status.fail(SimStatus.Code.BATTLE_TURN_LIMIT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, turns, TURN_LIMIT)
					break
				var command := P1DeterministicShotSupplier.command_for(state, status)
				if status.is_ok(): LaunchVelocitySolver.commit(state, command, status); records = resolve_last_transition(state, status)
				turns += 1
			BattleState.Phase.RESOLVE:
				var was_forced := state.forced_settle_used()
				state.advance_resolve(status); records = resolve_last_transition(state, status)
				if not was_forced and state.forced_settle_used(): metrics[5] += 1
			BattleState.Phase.TURN_END:
				state.complete_turn_end(status); records = resolve_last_transition(state, status)
			BattleState.Phase.CHECK:
				state.resolve_check(status); records = resolve_last_transition(state, status)
				if status.is_ok() and not restored and restore_after_turn > 0 and turns == restore_after_turn and state.phase() != BattleState.Phase.BATTLE_END:
					var bytes := BattleSnapshot.capture(state, status).encode(status)
					state = BattleSnapshot.decode(bytes, status).restore_state_with_catalog(catalog, status)
					restored = status.is_ok()
			_:
				status.fail(SimStatus.Code.INVALID_PHASE, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, state.phase(), 0)
		if status.is_ok(): _observe(records, initial_participants, metrics, status)
	if status.is_ok() and restore_after_turn > 0 and not restored:
		status.fail(SimStatus.Code.INVALID_BATTLE_REPORT, SimStatus.Operation.BATTLE_DRIVER_ADVANCE, restore_after_turn, turns)
	return P1BattleReport.create(state, turns, metrics, status) if status.is_ok() else P1BattleReport.new()
