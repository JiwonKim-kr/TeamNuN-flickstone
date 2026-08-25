class_name RunBattleBridge
extends RefCounted

static func _fail(status: SimStatus, detail_a: int = 0, detail_b: int = 0) -> void:
	status.fail(SimStatus.Code.INVALID_RUN_BATTLE_REQUEST, SimStatus.Operation.RUN_BATTLE_BUILD, detail_a, detail_b)

static func _origin_piece_id(state: BattleState, body_id: int, status: SimStatus) -> int:
	for index: int in range(state.piece_origin_count()):
		var origin: BattlePieceOrigin = state.piece_origin_at(index, status)
		if origin.body_id() == body_id: return origin.original_piece_numeric_id()
		if origin.body_id() > body_id: break
	if status.is_ok(): status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_CREATE, body_id, 0)
	return 0

static func _body_survived(state: BattleState, body_id: int, status: SimStatus) -> bool:
	for index: int in range(state.participant_count()):
		var participant: BattleParticipant = state.participant_at(index, status)
		if participant.body_id() == body_id: return true
		if participant.body_id() > body_id: break
	return false

static func build_state(request: RunBattleRequest, catalog: ContentCatalog, status: SimStatus) -> BattleState:
	if not status.is_ok(): return BattleState.new()
	if request == null or not request.is_initialized() or catalog == null or not catalog.is_initialized(): _fail(status); return BattleState.new()
	if request.content_fingerprint_bytes() != catalog.fingerprint_bytes(): status.fail(SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH, SimStatus.Operation.RUN_BATTLE_BUILD); return BattleState.new()
	var content_status := ContentStatus.new()
	var encounter: EncounterDefinition = catalog.encounter_by_numeric_id(request.encounter_numeric_id(), content_status)
	if not content_status.is_ok() or encounter.node_type_id() != request.node_type_id() or encounter.map_ref().numeric_id() != request.map_numeric_id() or encounter.enemy_ref_count() != request.enemy_count(): _fail(status, request.encounter_numeric_id(), request.map_numeric_id()); return BattleState.new()
	var map_definition: MapDefinition = catalog.map_by_numeric_id(request.map_numeric_id(), content_status)
	if not content_status.is_ok() or request.player_count() < ContentLimits.MAP_DEPLOY_MIN_COUNT or request.player_count() > map_definition.deploy_count() or request.enemy_count() != map_definition.deploy_count(): _fail(status, request.player_count(), request.enemy_count()); return BattleState.new()
	var deployment: Array[BattleDeploymentEntry] = []
	for index: int in range(request.player_count()):
		var entry: RunBattlePlayerEntry = request.player_at(index, status)
		var piece: PieceDefinition = catalog.piece_by_numeric_id(entry.piece_numeric_id(), content_status)
		if not content_status.is_ok() or piece.is_token() or entry.level() > piece.level_count() or entry.slot_index() != index or entry.expected_body_id() != index + 1:
			_fail(status, entry.run_instance_id(), index); return BattleState.new()
		deployment.append(BattleDeploymentEntry.create_player(index, piece.id_ref(), entry.level(), status))
	for index: int in range(request.enemy_count()):
		var entry: RunBattleEnemyEntry = request.enemy_at(index, status)
		var expected_ref: ContentIdRef = encounter.enemy_ref_at(index, content_status)
		var enemy: EnemyDefinition = catalog.enemy_by_numeric_id(entry.enemy_numeric_id(), content_status)
		if not content_status.is_ok() or expected_ref.numeric_id() != entry.enemy_numeric_id() or entry.slot_index() != index or entry.expected_body_id() != request.player_count() + index + 1:
			_fail(status, entry.enemy_numeric_id(), index); return BattleState.new()
		var enemy_ref: ContentIdRef = ContentIdRef.create(enemy.numeric_id(), enemy.string_id(), content_status)
		if not content_status.is_ok(): _fail(status, entry.enemy_numeric_id(), index); return BattleState.new()
		deployment.append(BattleDeploymentEntry.create_enemy(index, enemy_ref, status))
	if not status.is_ok(): return BattleState.new()
	var state: BattleState = BattleSetupBuilder.build(catalog, request.map_numeric_id(), deployment, request.battle_seed_hi(), request.battle_seed_lo(), status, request.encounter_numeric_id())
	if not status.is_ok(): return BattleState.new()
	for index: int in range(request.player_count()):
		var player: RunBattlePlayerEntry = request.player_at(index, status)
		if _origin_piece_id(state, player.expected_body_id(), status) != player.piece_numeric_id(): _fail(status, player.expected_body_id(), player.piece_numeric_id()); return BattleState.new()
	for index: int in range(request.enemy_count()):
		var enemy_entry: RunBattleEnemyEntry = request.enemy_at(index, status)
		var enemy: EnemyDefinition = catalog.enemy_by_numeric_id(enemy_entry.enemy_numeric_id(), content_status)
		if not content_status.is_ok() or _origin_piece_id(state, enemy_entry.expected_body_id(), status) != enemy.base_piece_ref().numeric_id(): _fail(status, enemy_entry.expected_body_id(), enemy_entry.enemy_numeric_id()); return BattleState.new()
	if request.opening_status_numeric_id() != 0:
		var player_body_ids: Array[int] = []
		for index: int in range(request.player_count()): player_body_ids.append(request.player_at(index, status).expected_body_id())
		if not status.is_ok() or not state.apply_run_opening_status(player_body_ids, request.opening_status_numeric_id(), status): return BattleState.new()
	return state

static func outcome_from(request: RunBattleRequest, state: BattleState, status: SimStatus) -> RunBattleOutcome:
	if not status.is_ok(): return RunBattleOutcome.new()
	if request == null or not request.is_initialized() or state == null or not state.is_initialized() or state.phase() != BattleState.Phase.BATTLE_END or not BattleResult.is_terminal(state.battle_result()) or state.has_pending_mutations():
		status.fail(SimStatus.Code.INVALID_RUN_BATTLE_OUTCOME, SimStatus.Operation.RUN_BATTLE_OUTCOME_CREATE, 0 if request == null else request.request_sequence(), 0 if state == null else state.phase()); return RunBattleOutcome.new()
	if request.content_fingerprint_bytes() != state.content_fingerprint_bytes(): status.fail(SimStatus.Code.CONTENT_FINGERPRINT_MISMATCH, SimStatus.Operation.RUN_BATTLE_OUTCOME_CREATE); return RunBattleOutcome.new()
	var facts: Array[RunBattlePlayerFact] = []
	for index: int in range(request.player_count()):
		var entry: RunBattlePlayerEntry = request.player_at(index, status)
		if _origin_piece_id(state, entry.expected_body_id(), status) != entry.piece_numeric_id(): return RunBattleOutcome.new()
		facts.append(RunBattlePlayerFact.create(index, entry.expected_body_id(), entry.run_instance_id(), _body_survived(state, entry.expected_body_id(), status), state.kill_count_for_body(entry.expected_body_id()), status))
	return RunBattleOutcome.create(request.content_fingerprint_bytes(), request.request_sequence(), request.act_numeric_id(), request.node_id(), request.node_type_id(), state.battle_result(), facts, status)
