class_name ModifierResolver
extends RefCounted

var _catalog: ContentCatalog
var _identities: Array[BattlePieceIdentity] = []
var _tally: SynergyTally = SynergyTally.new()
var _initialized: bool = false

static func build(catalog: ContentCatalog, identities: Array[BattlePieceIdentity], tally: SynergyTally, status: SimStatus) -> ModifierResolver:
	var result := ModifierResolver.new()
	if not status.is_ok() or catalog == null or not catalog.is_initialized() or tally == null:
		status.fail(SimStatus.Code.INVALID_MODIFIER_DEFINITION, SimStatus.Operation.MODIFIER_AGGREGATE); return result
	result._catalog = catalog.copy(); result._tally = tally.copy()
	for identity: BattlePieceIdentity in identities: result._identities.append(identity.copy())
	result._identities.sort_custom(func(a: BattlePieceIdentity, b: BattlePieceIdentity) -> bool: return a.body_id() < b.body_id())
	result._initialized = true; return result

func copy() -> ModifierResolver:
	if not _initialized: return ModifierResolver.new()
	var status := SimStatus.new(); return build(_catalog, _identities, _tally, status)
func is_initialized() -> bool: return _initialized

func _identity(body_id: int) -> BattlePieceIdentity:
	for item: BattlePieceIdentity in _identities:
		if item.body_id() == body_id: return item
		if item.body_id() > body_id: break
	return BattlePieceIdentity.new()

static func _accumulate(sum: Array[int], definition: StatusModifierDefinition, scale: int, status: SimStatus) -> void:
	var value: int = definition.value()
	if definition.value_mode_id() == ModifierKind.ValueMode.SCALED: value = FixMath.multiply_int(value, scale, status)
	if not status.is_ok(): return
	var index: int = 0 if definition.operation_id() == ModifierKind.Operation.ADD else 1
	sum[index] = FixMath.add_raw(sum[index], value, status)

func aggregate(body_id: int, kind_id: int, statuses: StatusCollection, status: SimStatus) -> ModifierAggregate:
	if not status.is_ok() or not _initialized or not ModifierKind.is_known(kind_id): status.fail(SimStatus.Code.INVALID_MODIFIER_DEFINITION, SimStatus.Operation.MODIFIER_AGGREGATE, body_id, kind_id); return ModifierAggregate.new()
	var sum: Array[int] = [0, 0]; var identity: BattlePieceIdentity = _identity(body_id)
	if identity.is_initialized():
		var cs := ContentStatus.new(); var piece: PieceDefinition = _catalog.piece_by_numeric_id(identity.piece_numeric_id(), cs)
		if not cs.is_ok(): status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.MODIFIER_AGGREGATE, body_id, identity.piece_numeric_id()); return ModifierAggregate.new()
		for tally_index: int in range(_tally.count()):
			var tag_id: int = _tally.tag_numeric_id_at(tally_index)
			if not piece.has_tag_numeric_id(tag_id): continue
			var synergy: SynergyDefinition = _catalog.synergy_by_tag_numeric_id(tag_id, cs)
			if not cs.is_ok(): status.fail(SimStatus.Code.INVALID_SYNERGY_TALLY, SimStatus.Operation.MODIFIER_AGGREGATE, tag_id, body_id); return ModifierAggregate.new()
			if synergy.scope_id() == SynergyDefinition.Scope.OWN_FACTION and identity.faction() != _tally.faction_id_at(tally_index): continue
			var effective_count: int = mini(_tally.value_at(tally_index), synergy.count_cap())
			for tier_index: int in range(synergy.tier_count()):
				var tier: SynergyTierDefinition = synergy.tier_at(tier_index, cs)
				if tier.min_count() > effective_count: break
				for modifier_index: int in range(tier.modifier_count()):
					var modifier: StatusModifierDefinition = tier.modifier_at(modifier_index, cs)
					if modifier.kind_id() == kind_id: _accumulate(sum, modifier, effective_count, status)
	if statuses != null:
		for item_index: int in range(statuses.count()):
			var item: StatusInstance = statuses.item_at(item_index, status)
			if item.target_body_id() != body_id: continue
			var cs := ContentStatus.new(); var definition: StatusDefinition = _catalog.status_by_numeric_id(item.status_numeric_id(), cs)
			if not cs.is_ok(): status.fail(SimStatus.Code.INVALID_STATUS_DEFINITION, SimStatus.Operation.MODIFIER_AGGREGATE, body_id, item.status_numeric_id()); return ModifierAggregate.new()
			for modifier_index: int in range(definition.modifier_count()):
				var modifier: StatusModifierDefinition = definition.modifier_at(modifier_index, cs)
				if modifier.kind_id() == kind_id: _accumulate(sum, modifier, item.stacks(), status)
				if not status.is_ok(): return ModifierAggregate.new()
	return ModifierAggregate.create(kind_id, sum[0], sum[1], status)
