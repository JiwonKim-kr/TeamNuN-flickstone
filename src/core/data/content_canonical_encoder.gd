class_name ContentCanonicalEncoder
extends RefCounted
## P2-1 compatibility bytes v1. Never delegates to Variant serialization.

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

	writer.u16(2)
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
	if not status.is_ok(): return PackedByteArray()
	return writer.data
