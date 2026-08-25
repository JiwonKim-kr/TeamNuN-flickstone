class_name BattleSetupBuilder
extends RefCounted


static func _deployment_less(left: BattleDeploymentEntry, right: BattleDeploymentEntry) -> bool:
	if left.side_id() != right.side_id(): return left.side_id() < right.side_id()
	return left.slot_index() < right.slot_index()


static func _fail(status: SimStatus, side_id: int = 0, slot_index: int = 0) -> BattleState:
	status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.BATTLE_SETUP_BUILD, side_id, slot_index)
	return BattleState.new()


static func _append_bindings(owner_body_id: int, level: PieceLevelDefinition, bindings: Array[AbilityBinding], status: SimStatus) -> void:
	var content_status := ContentStatus.new()
	for index: int in range(level.ability_ref_count()):
		bindings.append(AbilityBinding.create(owner_body_id, level.ability_ref_at(index, content_status).numeric_id(), status))
	if not content_status.is_ok() and status.is_ok(): status.fail(SimStatus.Code.INVALID_DEPLOYMENT, SimStatus.Operation.BATTLE_SETUP_BUILD, owner_body_id, 0)


static func build(catalog: ContentCatalog, map_numeric_id: int, deployment: Array[BattleDeploymentEntry], seed_hi: int, seed_lo: int, status: SimStatus, encounter_numeric_id: int = 0) -> BattleState:
	if not status.is_ok(): return BattleState.new()
	if catalog == null or not catalog.is_initialized(): return _fail(status)
	var content_status := ContentStatus.new()
	var map_definition: MapDefinition = catalog.map_by_numeric_id(map_numeric_id, content_status)
	if not content_status.is_ok(): return _fail(status)
	var encounter: EncounterDefinition = EncounterDefinition.new()
	if encounter_numeric_id > 0:
		encounter = catalog.encounter_by_numeric_id(encounter_numeric_id, content_status)
		if not content_status.is_ok() or encounter.map_ref().numeric_id() != map_numeric_id: return _fail(status, encounter_numeric_id, map_numeric_id)
	var normalized: Array[BattleDeploymentEntry] = []
	for entry: BattleDeploymentEntry in deployment:
		if entry == null or not entry.is_initialized(): return _fail(status)
		normalized.append(entry.copy())
	normalized.sort_custom(_deployment_less)
	var player_count: int = 0; var enemy_count: int = 0
	var next_player_slot: int = 0; var next_enemy_slot: int = 0
	for index: int in range(normalized.size()):
		var entry: BattleDeploymentEntry = normalized[index]
		if index > 0 and entry.side_id() == normalized[index - 1].side_id() and entry.slot_index() == normalized[index - 1].slot_index(): return _fail(status, entry.side_id(), entry.slot_index())
		if entry.side_id() == BattleDeploymentEntry.Side.PLAYER:
			if entry.slot_index() != next_player_slot: return _fail(status, entry.side_id(), entry.slot_index())
			player_count += 1
			next_player_slot += 1
			if entry.slot_index() >= map_definition.player_slot_count(): return _fail(status, entry.side_id(), entry.slot_index())
		else:
			if entry.slot_index() != next_enemy_slot: return _fail(status, entry.side_id(), entry.slot_index())
			enemy_count += 1
			next_enemy_slot += 1
			if entry.slot_index() >= map_definition.enemy_slot_count(): return _fail(status, entry.side_id(), entry.slot_index())
	if player_count < ContentLimits.MAP_DEPLOY_MIN_COUNT or player_count > map_definition.deploy_count() or enemy_count != map_definition.deploy_count(): return _fail(status, player_count, enemy_count)

	var world: SimWorld = SimWorld.create(seed_hi, seed_lo, status)
	world.configure_boundary(map_definition.boundary_vertices_copy(), map_definition.boundary_type_id(), status)
	var zone_keys: Array[int] = []; var zone_templates: Array[SimZone] = []
	for index: int in range(map_definition.zone_count()):
		var zone: MapZoneDefinition = map_definition.zone_at(index, content_status)
		zone_keys.append(zone_keys.size() + 1); zone_templates.append(zone.sim_template(status))
	if encounter.is_initialized():
		for index: int in range(encounter.damage_zone_count()):
			var damage_zone: EncounterDamageZoneDefinition = encounter.damage_zone_at(index, content_status)
			zone_keys.append(zone_keys.size() + 1); zone_templates.append(damage_zone.sim_template(status))
	world.add_initial_zones(zone_keys, zone_templates, status)
	if not status.is_ok() or not content_status.is_ok(): return BattleState.new()

	var spawn_keys: Array[int] = []; var bodies: Array[SimBody] = []
	var pieces: Array[PieceDefinition] = []; var levels: Array[PieceLevelDefinition] = []; var factions: Array[int] = []
	for entry: BattleDeploymentEntry in normalized:
		var piece: PieceDefinition
		var level: PieceLevelDefinition
		var position: FixVec2
		if entry.side_id() == BattleDeploymentEntry.Side.PLAYER:
			var piece_ref: ContentIdRef = entry.piece_ref(); piece = catalog.piece_by_numeric_id(piece_ref.numeric_id(), content_status)
			if content_status.is_ok() and piece.string_id() != piece_ref.string_id(): content_status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.PIECES, piece_ref.numeric_id())
			level = piece.level_definition(entry.level(), content_status); position = map_definition.player_slot_at(entry.slot_index(), content_status).position()
			factions.append(BattleParticipant.Faction.PLAYER)
		else:
			var enemy_ref: ContentIdRef = entry.enemy_ref(); var enemy: EnemyDefinition = catalog.enemy_by_numeric_id(enemy_ref.numeric_id(), content_status)
			if content_status.is_ok() and enemy.string_id() != enemy_ref.string_id(): content_status.fail(ContentStatus.Code.INVALID_ID, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENEMIES, enemy_ref.numeric_id())
			var base_ref: ContentIdRef = enemy.base_piece_ref(); piece = catalog.piece_by_numeric_id(base_ref.numeric_id(), content_status); level = enemy.resolved_level(catalog, content_status)
			position = map_definition.enemy_slot_at(entry.slot_index(), content_status).position(); factions.append(BattleParticipant.Faction.ENEMY)
		if not content_status.is_ok() or piece.is_token(): return _fail(status, entry.side_id(), entry.slot_index())
		pieces.append(piece); levels.append(level); spawn_keys.append(spawn_keys.size() + 1)
		bodies.append(SimBody.create_unassigned(position, FixVec2.zero(), level.radius_raw(), level.mass_raw(), status, level.friction_multiplier_raw(), piece.destructible(), level.elasticity_multiplier_raw()))
		if not status.is_ok(): return BattleState.new()
	world.add_initial_bodies(spawn_keys, bodies, status)
	if not status.is_ok(): return BattleState.new()
	for expected_id: int in range(1, bodies.size() + 1):
		var event: SimEvent = world.consume_next_event(status)
		if not status.is_ok() or event.type_id() != SimEvent.TypeId.BODY_ADDED or event.source_body_id() != expected_id: return _fail(status, 0, expected_id)
	if world.event_cursor() != world.event_count(): return _fail(status)

	var participants: Array[BattleParticipant] = []; var combatants: Array[BattleCombatant] = []; var identities: Array[BattlePieceIdentity] = []; var bindings: Array[AbilityBinding] = []
	for index: int in range(pieces.size()):
		var body_id: int = index + 1; var piece: PieceDefinition = pieces[index]; var level: PieceLevelDefinition = levels[index]; var faction: int = factions[index]
		participants.append(BattleParticipant.create(body_id, faction, piece.has_turn(), faction == BattleParticipant.Faction.PLAYER and piece.has_turn(), piece.counts_for_victory(), level.speed_stat(), status))
		if piece.destructible(): combatants.append(BattleCombatant.create_with_clean_hit_multiplier(body_id, faction, level.max_hp(), level.attack(), level.critical_basis_points(), level.clean_hit_damage_multiplier_raw(), status))
		identities.append(BattlePieceIdentity.create(body_id, piece.numeric_id(), normalized[index].level(), faction, false, status))
		_append_bindings(body_id, level, bindings, status)
		if not status.is_ok(): return BattleState.new()
	var state: BattleState = BattleState.create_with_combatants(world, participants, combatants, status)
	if not status.is_ok() or not state.attach_content(catalog, identities, bindings, status): return BattleState.new()
	if encounter.is_initialized():
		for index: int in range(encounter.damage_zone_count()):
			var damage_zone: EncounterDamageZoneDefinition = encounter.damage_zone_at(index, content_status)
			var assigned_zone_id: int = map_definition.zone_count() + index + 1
			state.register_initial_damage_zone(assigned_zone_id, damage_zone.turn_start_damage(), damage_zone.duration_turns(), status)
			if not status.is_ok(): return BattleState.new()
	if not state.complete_battle_start(status): return BattleState.new()
	return state
