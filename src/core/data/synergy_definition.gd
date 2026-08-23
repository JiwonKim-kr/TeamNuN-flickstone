class_name SynergyDefinition
extends RefCounted

enum TagKind { INVALID = 0, ROLE = 1, THEME = 2 }
enum Scope { INVALID = 0, OWN_FACTION = 1, BOTH_FACTIONS = 2 }

var _id_ref: ContentIdRef
var _tag_ref: ContentIdRef
var _tag_kind_id: int = 0
var _scope_id: int = 0
var _count_cap: int = 0
var _tiers: Array[SynergyTierDefinition] = []
var _initialized: bool = false

static func create(id_ref: ContentIdRef, tag_ref: ContentIdRef, tag_kind_id: int, scope_id: int, count_cap: int, tiers: Array[SynergyTierDefinition], status: ContentStatus) -> SynergyDefinition:
	var result := SynergyDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or tag_ref == null or not tag_ref.is_initialized() or tag_kind_id < TagKind.ROLE or tag_kind_id > TagKind.THEME or scope_id < Scope.OWN_FACTION or scope_id > Scope.BOTH_FACTIONS or count_cap < 2 or count_cap > ContentLimits.SYNERGY_COUNT_MAX or tiers.size() > ContentLimits.SYNERGY_TIERS_MAX_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return result
	var previous: int = 0
	for tier: SynergyTierDefinition in tiers:
		if tier == null or not tier.is_initialized() or tier.min_count() <= previous or tier.min_count() > count_cap: status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return SynergyDefinition.new()
		result._tiers.append(tier.copy()); previous = tier.min_count()
	result._id_ref = id_ref.copy(); result._tag_ref = tag_ref.copy(); result._tag_kind_id = tag_kind_id; result._scope_id = scope_id; result._count_cap = count_cap; result._initialized = true; return result

func copy() -> SynergyDefinition:
	var status := ContentStatus.new(); return create(_id_ref, _tag_ref, _tag_kind_id, _scope_id, _count_cap, _tiers, status) if _initialized else SynergyDefinition.new()
func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _id_ref.numeric_id() if _initialized else 0
func string_id() -> String: return _id_ref.string_id() if _initialized else ""
func tag_ref() -> ContentIdRef: return _tag_ref.copy() if _initialized else ContentIdRef.new()
func tag_kind_id() -> int: return _tag_kind_id
func scope_id() -> int: return _scope_id
func count_cap() -> int: return _count_cap
func tier_count() -> int: return _tiers.size()
func tier_at(index: int, status: ContentStatus) -> SynergyTierDefinition:
	if index < 0 or index >= _tiers.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP); return SynergyTierDefinition.new()
	return _tiers[index].copy()
