class_name ContentCanonicalEncoder
extends RefCounted
## Canonical compatibility bytes v4. Never delegates to Variant serialization.

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
		status: ContentStatus
) -> PackedByteArray:
	if not status.is_ok(): return PackedByteArray()
	var writer := ByteWriter.new(status)
	writer.data.append_array(MAGIC)
	writer.u16(ContentIds.FINGERPRINT_FORMAT_VERSION)
	writer.u16(ContentIds.CATALOG_SCHEMA_VERSION)
	writer.u16(ContentIds.REGISTRY_SCHEMA_VERSION)
	writer.u16(ContentIds.Namespace.TAG)
	for namespace_id: int in range(ContentIds.Namespace.PIECE, ContentIds.Namespace.TAG + 1):
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

	writer.u16(4)
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
	if not status.is_ok(): return PackedByteArray()
	return writer.data
