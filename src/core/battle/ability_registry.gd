class_name AbilityRegistry
extends RefCounted

var _bindings: Array[AbilityBinding] = []
var _catalog: ContentCatalog
var _initialized: bool = false

static func _less(left: AbilityBinding, right: AbilityBinding) -> bool:
	return left.owner_body_id() < right.owner_body_id() or (left.owner_body_id() == right.owner_body_id() and left.ability_numeric_id() < right.ability_numeric_id())

static func bind(catalog: ContentCatalog, bindings: Array[AbilityBinding], status: SimStatus) -> AbilityRegistry:
	var result := AbilityRegistry.new()
	if not status.is_ok(): return result
	if catalog == null or not catalog.is_initialized(): status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.ABILITY_BIND); return result
	result._catalog = catalog.copy()
	for binding: AbilityBinding in bindings:
		if binding == null or not binding.is_initialized(): status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.ABILITY_BIND); return AbilityRegistry.new()
		var content_status := ContentStatus.new()
		result._catalog.ability_by_numeric_id(binding.ability_numeric_id(), content_status)
		if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.ABILITY_BIND, binding.owner_body_id(), binding.ability_numeric_id()); return AbilityRegistry.new()
		result._bindings.append(binding.copy())
	result._bindings.sort_custom(_less)
	for index: int in range(1, result._bindings.size()):
		if result._bindings[index - 1].owner_body_id() == result._bindings[index].owner_body_id() and result._bindings[index - 1].ability_numeric_id() == result._bindings[index].ability_numeric_id():
			status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.ABILITY_BIND, result._bindings[index].owner_body_id(), result._bindings[index].ability_numeric_id()); return AbilityRegistry.new()
	result._initialized = true
	return result

func is_initialized() -> bool: return _initialized
func binding_count() -> int: return _bindings.size()
func fingerprint_bytes() -> PackedByteArray: return _catalog.fingerprint_bytes() if _initialized else PackedByteArray()
func binding_at(index: int, status: SimStatus) -> AbilityBinding:
	if index < 0 or index >= _bindings.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.ABILITY_BIND, index, _bindings.size()); return AbilityBinding.new()
	return _bindings[index].copy()
func abilities_for_trigger(owner_body_id: int, trigger_id: int, status: SimStatus) -> Array[AbilityDefinition]:
	var result: Array[AbilityDefinition] = []
	if not status.is_ok() or not _initialized: return result
	for binding: AbilityBinding in _bindings:
		if binding.owner_body_id() != owner_body_id: continue
		var content_status := ContentStatus.new()
		var ability: AbilityDefinition = _catalog.ability_by_numeric_id(binding.ability_numeric_id(), content_status)
		if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_ABILITY_BINDING, SimStatus.Operation.ABILITY_BIND, owner_body_id, binding.ability_numeric_id()); return []
		if ability.trigger_id() == trigger_id: result.append(ability)
	return result
