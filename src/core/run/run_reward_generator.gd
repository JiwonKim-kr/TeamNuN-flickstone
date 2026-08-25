class_name RunRewardGenerator
extends RefCounted


static func _fail(status: SimStatus, detail_a: int = 0, detail_b: int = 0) -> void:
	status.fail(SimStatus.Code.INVALID_RUN_REWARD, SimStatus.Operation.RUN_REWARD_GENERATE, detail_a, detail_b)


static func _active_tag_distinct_counts(state: RunState, catalog: ContentCatalog, status: SimStatus) -> Dictionary:
	var result: Dictionary = {}
	for synergy_index: int in range(catalog.synergy_count()):
		var content_status := ContentStatus.new()
		var synergy: SynergyDefinition = catalog.synergy_at(synergy_index, content_status)
		if not content_status.is_ok(): _fail(status, synergy_index, 0); return {}
		var tag_numeric_id: int = synergy.tag_ref().numeric_id()
		var tally: int = 0
		var distinct_piece_ids: Array[int] = []
		for deployment_index: int in range(state.deployment_count()):
			var instance_id: int = state.deployment_instance_id_at(deployment_index, status)
			var instance: RunPieceInstance = state.roster_by_instance_id(instance_id, status)
			var piece: PieceDefinition = catalog.piece_by_numeric_id(instance.piece_numeric_id(), content_status)
			if not status.is_ok() or not content_status.is_ok(): _fail(status, instance_id, tag_numeric_id); return {}
			if not piece.has_tag_numeric_id(tag_numeric_id): continue
			var contribution: int = instance.level() if synergy.tag_kind_id() == SynergyDefinition.TagKind.THEME else 1
			if tally > ContentLimits.UINT32_MAX - contribution: _fail(status, tag_numeric_id, tally); return {}
			tally += contribution
			if not distinct_piece_ids.has(instance.piece_numeric_id()): distinct_piece_ids.append(instance.piece_numeric_id())
		if tally >= 2: result[tag_numeric_id] = distinct_piece_ids.size()
	return result


static func _candidate_weight(piece: PieceDefinition, active_counts: Dictionary, status: SimStatus) -> int:
	var weight: int = 1
	var content_status := ContentStatus.new()
	for tag_index: int in range(piece.tag_ref_count()):
		var tag_id: int = piece.tag_ref_at(tag_index, content_status).numeric_id()
		if not content_status.is_ok(): _fail(status, piece.numeric_id(), tag_index); return 0
		if active_counts.has(tag_id):
			var contribution: int = int(active_counts[tag_id])
			if contribution < 0 or weight > ContentLimits.UINT32_MAX - contribution: _fail(status, piece.numeric_id(), weight); return 0
			weight += contribution
	return weight


static func generate_victory(state: RunState, catalog: ContentCatalog, profile: RewardProfileDefinition, status: SimStatus) -> RunPendingChoice:
	if not status.is_ok(): return RunPendingChoice.new()
	if state == null or not state.is_initialized() or catalog == null or not catalog.is_initialized() or profile == null or not profile.is_initialized() or state.phase_id() != RunPhase.Value.REWARD or state.deployment_count() < ContentLimits.MAP_DEPLOY_MIN_COUNT or state.next_transition_sequence() < 2:
		_fail(status, 0 if state == null else state.phase_id(), 0 if profile == null else profile.numeric_id()); return RunPendingChoice.new()
	var active_counts: Dictionary = _active_tag_distinct_counts(state, catalog, status)
	if not status.is_ok(): return RunPendingChoice.new()
	var candidate_ids: Array[int] = []
	var weights: Array[int] = []
	var content_status := ContentStatus.new()
	for index: int in range(profile.recruit_pool_count()):
		var ref: ContentIdRef = profile.recruit_pool_ref_at(index, content_status)
		var piece: PieceDefinition = catalog.piece_by_numeric_id(ref.numeric_id(), content_status)
		if not content_status.is_ok() or piece.is_token() or piece.level_count() < 1:
			_fail(status, profile.numeric_id(), ref.numeric_id()); return RunPendingChoice.new()
		candidate_ids.append(piece.numeric_id())
		weights.append(_candidate_weight(piece, active_counts, status))
		if not status.is_ok(): return RunPendingChoice.new()
	var rng: SimRng = SimRng.derive(state.seed_hi(), state.seed_lo(), RunRandomPurpose.RUN_REWARD, state.act_numeric_id(), state.current_node_id(), status)
	var entries: Array[RunChoiceEntry] = []
	for choice_index: int in range(profile.recruit_choice_count()):
		var selected_index: int = 0
		if candidate_ids.size() > 1:
			var total_weight: int = 0
			for weight: int in weights:
				if weight < 1 or total_weight > ContentLimits.UINT32_MAX - weight: _fail(status, profile.numeric_id(), total_weight); return RunPendingChoice.new()
				total_weight += weight
			var draw: int = rng.next_below(total_weight, status)
			if not status.is_ok(): return RunPendingChoice.new()
			var cumulative: int = 0
			for index: int in range(weights.size()):
				cumulative += weights[index]
				if draw < cumulative: selected_index = index; break
		var selected_piece_id: int = candidate_ids[selected_index]
		entries.append(RunChoiceEntry.create(choice_index + 1, RunChoiceKind.Value.RECRUIT_PIECE, selected_piece_id, 0, 1, 0, true, status))
		candidate_ids.remove_at(selected_index); weights.remove_at(selected_index)
		if not status.is_ok(): return RunPendingChoice.new()
	return RunPendingChoice.create(RunPendingKind.Value.REWARD, state.current_node_id(), state.next_transition_sequence() - 1, entries, status)
