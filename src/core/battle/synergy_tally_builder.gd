class_name SynergyTallyBuilder
extends RefCounted

static func build(catalog: ContentCatalog, identities: Array[BattlePieceIdentity], status: SimStatus) -> SynergyTally:
	if not status.is_ok() or catalog == null or not catalog.is_initialized(): status.fail(SimStatus.Code.INVALID_SYNERGY_TALLY, SimStatus.Operation.SYNERGY_TALLY_BUILD); return SynergyTally.new()
	var sorted: Array[BattlePieceIdentity] = []
	for identity: BattlePieceIdentity in identities: sorted.append(identity.copy())
	sorted.sort_custom(func(a: BattlePieceIdentity, b: BattlePieceIdentity) -> bool: return a.body_id() < b.body_id())
	var counts: Dictionary = {}
	for identity: BattlePieceIdentity in sorted:
		if identity == null or not identity.is_initialized() or identity.is_token() or identity.faction() == BattleParticipant.Faction.NEUTRAL: continue
		var cs := ContentStatus.new(); var piece: PieceDefinition = catalog.piece_by_numeric_id(identity.piece_numeric_id(), cs)
		if not cs.is_ok(): status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.SYNERGY_TALLY_BUILD, identity.body_id(), identity.piece_numeric_id()); return SynergyTally.new()
		for tag_index: int in range(piece.tag_ref_count()):
			var tag_id: int = piece.tag_ref_at(tag_index, cs).numeric_id(); var synergy: SynergyDefinition = catalog.synergy_by_tag_numeric_id(tag_id, cs)
			if not cs.is_ok(): status.fail(SimStatus.Code.INVALID_SYNERGY_TALLY, SimStatus.Operation.SYNERGY_TALLY_BUILD, tag_id, identity.body_id()); return SynergyTally.new()
			var key: String = "%d:%d" % [tag_id, identity.faction()]; var contribution: int = 1 if synergy.tag_kind_id() == SynergyDefinition.TagKind.ROLE else identity.level()
			counts[key] = int(counts.get(key, 0)) + contribution
	var entries: Array[SynergyTally.Entry] = []
	for key_value: Variant in counts.keys():
		var key: String = String(key_value); var parts: PackedStringArray = key.split(":"); var value: int = int(counts[key])
		if value >= 2: entries.append(SynergyTally.Entry.new(int(parts[0]), int(parts[1]), mini(value, ContentLimits.SYNERGY_COUNT_MAX)))
	entries.sort_custom(func(a: SynergyTally.Entry, b: SynergyTally.Entry) -> bool: return a.tag_numeric_id < b.tag_numeric_id or (a.tag_numeric_id == b.tag_numeric_id and a.faction_id < b.faction_id))
	return SynergyTally.create(entries, status)
