class_name SynergyTierDefinition
extends RefCounted

var _min_count: int = 0
var _modifiers: Array[StatusModifierDefinition] = []
var _initialized: bool = false

static func create(min_count: int, modifiers: Array[StatusModifierDefinition], status: ContentStatus) -> SynergyTierDefinition:
	var result := SynergyTierDefinition.new()
	if not status.is_ok(): return result
	if min_count < 2 or min_count > ContentLimits.SYNERGY_COUNT_MAX or modifiers.size() > ContentLimits.SYNERGY_TIER_MODIFIERS_MAX_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return result
	for modifier: StatusModifierDefinition in modifiers:
		if modifier == null or not modifier.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return SynergyTierDefinition.new()
		result._modifiers.append(modifier.copy())
	result._min_count = min_count; result._initialized = true; return result

func copy() -> SynergyTierDefinition:
	var status := ContentStatus.new(); return create(_min_count, _modifiers, status) if _initialized else SynergyTierDefinition.new()
func is_initialized() -> bool: return _initialized
func min_count() -> int: return _min_count
func modifier_count() -> int: return _modifiers.size()
func modifier_at(index: int, status: ContentStatus) -> StatusModifierDefinition:
	if index < 0 or index >= _modifiers.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP); return StatusModifierDefinition.new()
	return _modifiers[index].copy()
