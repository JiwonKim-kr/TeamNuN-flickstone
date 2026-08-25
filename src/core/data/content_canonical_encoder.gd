class_name ContentCanonicalEncoder
extends RefCounted
## Canonical compatibility bytes v5. Never delegates to Variant serialization.

const MAGIC: PackedByteArray = [70, 76, 73, 67, 75, 67, 65, 84] # FLICKCAT


class ByteWriter:
	var data: PackedByteArray = PackedByteArray()
	var status: ContentStatus

	func _init(p_status: ContentStatus) -> void:
		status = p_status

	func u8(value: int) -> void:
		data.append(value & 0xFF)

	func u16(value: int) -> void:
		for shift: int in range(0, 16, 8): u8(value >> shift)

	func u32(value: int) -> void:
		for shift: int in range(0, 32, 8): u8(value >> shift)

	func i64(value: int) -> void:
		for shift: int in range(0, 64, 8): u8(value >> shift)

	func vec2(value: FixVec2) -> void:
		i64(value.x_raw()); i64(value.y_raw())

	func string_utf8(value: String) -> void:
		var bytes: PackedByteArray = value.to_utf8_buffer()
		if bytes.size() > 0xFFFF:
			status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE)
			return
		u16(bytes.size())
		data.append_array(bytes)


static func encode(
		registry_entries: Array[ContentRegistryEntry],
		pieces: Array[PieceDefinition],
		abilities: Array[AbilityDefinition],
		statuses: Array[StatusDefinition],
		synergies: Array[SynergyDefinition],
		maps: Array[MapDefinition],
		enemies: Array[EnemyDefinition],
		acts: Array[ActDefinition],
		encounters: Array[EncounterDefinition],
		status: ContentStatus
) -> PackedByteArray:
	if not status.is_ok(): return PackedByteArray()
	var writer := ByteWriter.new(status)
	writer.data.append_array(MAGIC)
	writer.u16(ContentIds.FINGERPRINT_FORMAT_VERSION)
	writer.u16(ContentIds.CATALOG_SCHEMA_VERSION)
	writer.u16(ContentIds.REGISTRY_SCHEMA_VERSION)
	writer.u16(ContentIds.Namespace.CONSUMABLE)
	for namespace_id: int in range(ContentIds.Namespace.PIECE, ContentIds.Namespace.CONSUMABLE + 1):
		writer.u16(namespace_id)
		var count: int = 0
		for entry: ContentRegistryEntry in registry_entries:
			if entry.namespace_id() == namespace_id: count += 1
		writer.u32(count)
		for entry: ContentRegistryEntry in registry_entries:
			if entry.namespace_id() != namespace_id: continue
			writer.u32(entry.numeric_id())
			writer.string_utf8(entry.string_id())
			writer.u8(entry.state_id())

	writer.u16(10)
	writer.u16(ContentIds.DocumentKind.PIECES)
	writer.u16(ContentIds.PIECES_SCHEMA_VERSION)
	writer.u32(pieces.size())
	for piece: PieceDefinition in pieces:
		writer.u32(piece.numeric_id())
		writer.string_utf8(piece.string_id())
		var flags: int = 0
		if piece.has_turn(): flags |= 1 << 0
		if piece.destructible(): flags |= 1 << 1
		if piece.transformable(): flags |= 1 << 2
		if piece.counts_for_victory(): flags |= 1 << 3
		if piece.is_token(): flags |= 1 << 4
		writer.u32(flags)
		writer.u8(1 if piece.spawnable() else 0)
		writer.u16(piece.spawn_faction_mode_id())
		writer.u16(piece.expire_kind_id())
		writer.u32(piece.expire_value())
		writer.u16(piece.attach_anchor_mode_id())
		writer.vec2(piece.attach_anchor_offset())
		writer.u16(piece.tag_ref_count())
		for tag_index: int in range(piece.tag_ref_count()):
			var tag_status := ContentStatus.new(); var tag_ref: ContentIdRef = piece.tag_ref_at(tag_index, tag_status)
			if not tag_status.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE); return PackedByteArray()
			writer.u32(tag_ref.numeric_id()); writer.string_utf8(tag_ref.string_id())
		writer.u8(piece.level_count())
		for level_index: int in range(piece.level_count()):
			var level_status := ContentStatus.new()
			var level: PieceLevelDefinition = piece.level_at(level_index, level_status)
			if not level_status.is_ok():
				status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE, ContentIds.DocumentKind.PIECES, piece.numeric_id())
				return PackedByteArray()
			writer.u8(level.level())
			writer.i64(level.max_hp())
			writer.i64(level.attack())
			writer.i64(level.speed_stat())
			writer.i64(level.mass_raw())
			writer.i64(level.radius_raw())
			writer.i64(level.friction_multiplier_raw())
			writer.i64(level.critical_basis_points())
			writer.u16(level.ability_ref_count())
			for ref_index: int in range(level.ability_ref_count()):
				var ref_status := ContentStatus.new()
				var ability_ref: ContentIdRef = level.ability_ref_at(ref_index, ref_status)
				if not ref_status.is_ok():
					status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE, ContentIds.DocumentKind.PIECES, piece.numeric_id())
					return PackedByteArray()
				writer.u32(ability_ref.numeric_id())
				writer.string_utf8(ability_ref.string_id())

	writer.u16(ContentIds.DocumentKind.ABILITIES)
	writer.u16(ContentIds.ABILITIES_SCHEMA_VERSION)
	writer.u32(abilities.size())
	for ability: AbilityDefinition in abilities:
		writer.u32(ability.numeric_id())
		writer.string_utf8(ability.string_id())
		writer.u16(ability.trigger_id())
		writer.u16(ability.condition_count())
		for condition_index: int in range(ability.condition_count()):
			var condition_status := ContentStatus.new()
			var condition: AbilityConditionDefinition = ability.condition_at(condition_index, condition_status)
			if not condition_status.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE); return PackedByteArray()
			writer.u16(condition.kind_id()); writer.u16(condition.relation_id()); writer.i64(condition.value_a()); writer.i64(condition.value_b())
		writer.u16(ability.effect_count())
		for effect_index: int in range(ability.effect_count()):
			var effect_status := ContentStatus.new()
			var effect: AbilityEffectDefinition = ability.effect_at(effect_index, effect_status)
			if not effect_status.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE); return PackedByteArray()
			var selector: AbilitySelectorDefinition = effect.selector()
			writer.u16(effect.kind_id()); writer.u16(selector.kind_id()); writer.u16(selector.relation_id()); writer.u16(selector.limit())
			writer.i64(effect.value_a()); writer.i64(effect.value_b()); writer.u16(effect.operation_id())
			if effect.kind_id() == AbilityEffectDefinition.Kind.SPAWN_PIECE or effect.kind_id() == AbilityEffectDefinition.Kind.SPAWN_PROJECTILE:
				writer.u8(1); var payload: SpawnPayloadDefinition = effect.spawn_payload(); var piece_ref: ContentIdRef = payload.piece_ref()
				writer.u32(piece_ref.numeric_id()); writer.string_utf8(piece_ref.string_id()); writer.vec2(payload.offset()); writer.i64(payload.speed_raw()); writer.u16(payload.direction_mode_id())
			elif effect.kind_id() == AbilityEffectDefinition.Kind.TRANSFORM_PIECE:
				writer.u8(2); var payload: TransformPayloadDefinition = effect.transform_payload(); var piece_ref: ContentIdRef = payload.piece_ref()
				writer.u32(piece_ref.numeric_id()); writer.string_utf8(piece_ref.string_id())
			elif effect.kind_id() == AbilityEffectDefinition.Kind.ATTACH:
				writer.u8(3); var payload: AttachPayloadDefinition = effect.attach_payload()
				writer.u16(payload.owner_role_id()); writer.u16(payload.anchor_mode_id()); writer.vec2(payload.anchor_offset()); writer.i64(payload.attach_distance_raw()); writer.u16(payload.inertia_basis_points()); writer.u32(payload.duration_turns())
			elif effect.kind_id() == AbilityEffectDefinition.Kind.SPAWN_ZONE:
				writer.u8(4); var payload: ZoneSpawnPayloadDefinition = effect.zone_payload()
				writer.u32(payload.flags()); writer.i64(payload.friction_multiplier_raw()); writer.vec2(payload.acceleration()); writer.i64(payload.turn_start_damage()); writer.vec2(payload.offset()); writer.u32(payload.vertex_count())
				var payload_status := ContentStatus.new()
				for vertex_index: int in range(payload.vertex_count()): writer.vec2(payload.vertex_at(vertex_index, payload_status))
				writer.u32(payload.duration_turns())
			else:
				writer.u8(0)

	writer.u16(ContentIds.DocumentKind.STATUSES); writer.u16(ContentIds.STATUSES_SCHEMA_VERSION); writer.u32(statuses.size())
	for definition: StatusDefinition in statuses:
		writer.u32(definition.numeric_id()); writer.string_utf8(definition.string_id()); writer.u16(definition.stack_policy_id()); writer.u16(definition.max_stacks())
		writer.u16(definition.duration_kind_id()); writer.u32(definition.default_duration()); writer.u32(definition.max_duration()); writer.u16(definition.refresh_policy_id()); writer.u8(1 if definition.merge_sources() else 0)
		writer.u16(definition.modifier_count())
		for index: int in range(definition.modifier_count()):
			var cs := ContentStatus.new(); var modifier: StatusModifierDefinition = definition.modifier_at(index, cs)
			if not cs.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE); return PackedByteArray()
			writer.u16(modifier.kind_id()); writer.u16(modifier.operation_id()); writer.u16(modifier.value_mode_id()); writer.i64(modifier.value())

	writer.u16(ContentIds.DocumentKind.SYNERGIES); writer.u16(ContentIds.SYNERGIES_SCHEMA_VERSION); writer.u32(synergies.size())
	for definition: SynergyDefinition in synergies:
		writer.u32(definition.numeric_id()); writer.string_utf8(definition.string_id()); var tag_ref: ContentIdRef = definition.tag_ref(); writer.u32(tag_ref.numeric_id()); writer.string_utf8(tag_ref.string_id())
		writer.u16(definition.tag_kind_id()); writer.u16(definition.scope_id()); writer.u16(definition.count_cap()); writer.u16(definition.tier_count())
		for tier_index: int in range(definition.tier_count()):
			var cs := ContentStatus.new(); var tier: SynergyTierDefinition = definition.tier_at(tier_index, cs)
			if not cs.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE); return PackedByteArray()
			writer.u16(tier.min_count()); writer.u16(tier.modifier_count())
			for modifier_index: int in range(tier.modifier_count()):
				var modifier: StatusModifierDefinition = tier.modifier_at(modifier_index, cs); writer.u16(modifier.kind_id()); writer.u16(modifier.operation_id()); writer.u16(modifier.value_mode_id()); writer.i64(modifier.value())

	writer.u16(ContentIds.DocumentKind.MAPS); writer.u16(ContentIds.MAPS_SCHEMA_VERSION); writer.u32(maps.size())
	for definition: MapDefinition in maps:
		writer.u32(definition.numeric_id()); writer.string_utf8(definition.string_id()); writer.u16(definition.boundary_type_id())
		var map_status := ContentStatus.new(); var boundary_vertices: Array[FixVec2] = definition.boundary_vertices_copy()
		writer.u32(boundary_vertices.size())
		for vertex: FixVec2 in boundary_vertices: writer.vec2(vertex)
		writer.u16(definition.deploy_count()); writer.u32(definition.player_slot_count())
		for index: int in range(definition.player_slot_count()): writer.vec2(definition.player_slot_at(index, map_status).position())
		writer.u32(definition.enemy_slot_count())
		for index: int in range(definition.enemy_slot_count()): writer.vec2(definition.enemy_slot_at(index, map_status).position())
		writer.u32(definition.zone_count())
		for index: int in range(definition.zone_count()):
			var zone: MapZoneDefinition = definition.zone_at(index, map_status)
			writer.u32(zone.local_id()); writer.u32(zone.flags()); writer.i64(zone.friction_multiplier_raw()); writer.vec2(zone.acceleration()); writer.u32(zone.vertex_count())
			for vertex_index: int in range(zone.vertex_count()): writer.vec2(zone.vertex_at(vertex_index, map_status))
		writer.u32(0)
		if not map_status.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE); return PackedByteArray()

	writer.u16(ContentIds.DocumentKind.ENEMIES); writer.u16(ContentIds.ENEMIES_SCHEMA_VERSION); writer.u32(enemies.size())
	for definition: EnemyDefinition in enemies:
		writer.u32(definition.numeric_id()); writer.string_utf8(definition.string_id())
		var base_ref: ContentIdRef = definition.base_piece_ref(); writer.u32(base_ref.numeric_id()); writer.string_utf8(base_ref.string_id())
		writer.u16(definition.ai_grade_id())
		var override_definition: EnemyOverrideDefinition = definition.override_definition(); var mask: int = override_definition.presence_mask(); writer.u16(mask)
		if override_definition.has_value(EnemyOverrideDefinition.MAX_HP_BIT): writer.i64(override_definition.max_hp())
		if override_definition.has_value(EnemyOverrideDefinition.ATTACK_BIT): writer.i64(override_definition.attack())
		if override_definition.has_value(EnemyOverrideDefinition.SPEED_STAT_BIT): writer.i64(override_definition.speed_stat())
		if override_definition.has_value(EnemyOverrideDefinition.MASS_RAW_BIT): writer.i64(override_definition.mass_raw())
		if override_definition.has_value(EnemyOverrideDefinition.RADIUS_RAW_BIT): writer.i64(override_definition.radius_raw())
		if override_definition.has_value(EnemyOverrideDefinition.FRICTION_RAW_BIT): writer.i64(override_definition.friction_multiplier_raw())
		if override_definition.has_value(EnemyOverrideDefinition.CRITICAL_BIT): writer.i64(override_definition.critical_basis_points())
		if override_definition.has_value(EnemyOverrideDefinition.ABILITY_REFS_BIT):
			writer.u16(override_definition.ability_ref_count()); var enemy_status := ContentStatus.new()
			for index: int in range(override_definition.ability_ref_count()):
				var ability_ref: ContentIdRef = override_definition.ability_ref_at(index, enemy_status); writer.u32(ability_ref.numeric_id()); writer.string_utf8(ability_ref.string_id())
			if not enemy_status.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE); return PackedByteArray()

	writer.u16(ContentIds.DocumentKind.ACTS); writer.u16(ContentIds.ACTS_SCHEMA_VERSION); writer.u32(acts.size())
	for definition: ActDefinition in acts:
		writer.u32(definition.numeric_id()); writer.string_utf8(definition.string_id()); writer.u8(1 if definition.is_development() else 0); writer.u16(definition.floor_count())
		var act_status := ContentStatus.new()
		for floor_index: int in range(definition.floor_count()):
			var floor: ActFloorDefinition = definition.floor_at(floor_index, act_status)
			writer.u16(floor.floor_index()); writer.u16(floor.slot_count())
			for slot_index: int in range(floor.slot_count()):
				var slot: ActNodeSlotDefinition = floor.slot_at(slot_index, act_status)
				writer.u16(slot.slot_index()); writer.u16(slot.option_count())
				for option_index: int in range(slot.option_count()):
					var option: ActNodeOptionDefinition = slot.option_at(option_index, act_status)
					writer.u16(option.node_type_id()); writer.u32(option.weight()); writer.u16(option.content_ref_count())
					for ref_index: int in range(option.content_ref_count()):
						var ref: ActContentRef = option.content_ref_at(ref_index, act_status)
						writer.u32(ref.numeric_id()); writer.string_utf8(ref.string_id())
		if not act_status.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE, ContentIds.DocumentKind.ACTS, definition.numeric_id()); return PackedByteArray()

	writer.u16(ContentIds.DocumentKind.ENCOUNTERS); writer.u16(ContentIds.ENCOUNTERS_SCHEMA_VERSION); writer.u32(encounters.size())
	for definition: EncounterDefinition in encounters:
		writer.u32(definition.numeric_id()); writer.string_utf8(definition.string_id()); writer.u16(definition.node_type_id())
		var map_ref: ContentIdRef = definition.map_ref(); writer.u32(map_ref.numeric_id()); writer.string_utf8(map_ref.string_id())
		writer.u16(definition.enemy_ref_count()); var encounter_status := ContentStatus.new()
		for ref_index: int in range(definition.enemy_ref_count()):
			var enemy_ref: ContentIdRef = definition.enemy_ref_at(ref_index, encounter_status); writer.u32(enemy_ref.numeric_id()); writer.string_utf8(enemy_ref.string_id())
		writer.u32(definition.reward_profile_numeric_id())
		writer.u32(definition.damage_zone_count())
		for zone_index: int in range(definition.damage_zone_count()):
			var zone: EncounterDamageZoneDefinition = definition.damage_zone_at(zone_index, encounter_status)
			writer.u32(zone.local_id()); writer.i64(zone.turn_start_damage()); writer.u32(zone.duration_turns()); writer.u32(zone.vertex_count())
			for vertex_index: int in range(zone.vertex_count()): writer.vec2(zone.vertex_at(vertex_index, encounter_status))
		if not encounter_status.is_ok(): status.fail(ContentStatus.Code.FINGERPRINT_ERROR, ContentStatus.Operation.CANONICAL_ENCODE, ContentIds.DocumentKind.ENCOUNTERS, definition.numeric_id()); return PackedByteArray()

	writer.u16(ContentIds.DocumentKind.RELICS); writer.u16(ContentIds.RELICS_SCHEMA_VERSION); writer.u32(0)
	writer.u16(ContentIds.DocumentKind.CONSUMABLES); writer.u16(ContentIds.CONSUMABLES_SCHEMA_VERSION); writer.u32(0)
	if not status.is_ok(): return PackedByteArray()
	return writer.data
