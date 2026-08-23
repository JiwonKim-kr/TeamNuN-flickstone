class_name StatusCollection
extends RefCounted

const BODY_MAX: int = 64
const BATTLE_MAX: int = 4096

var _items: Array[StatusInstance] = []
var _next_sequence: int = 1

static func _less(a: StatusInstance, b: StatusInstance) -> bool:
	if a.target_body_id() != b.target_body_id(): return a.target_body_id() < b.target_body_id()
	if a.status_numeric_id() != b.status_numeric_id(): return a.status_numeric_id() < b.status_numeric_id()
	if a.source_body_id() != b.source_body_id(): return a.source_body_id() < b.source_body_id()
	return a.application_sequence() < b.application_sequence()

func copy() -> StatusCollection:
	var result := StatusCollection.new(); result._next_sequence = _next_sequence
	for item: StatusInstance in _items: result._items.append(item.copy())
	return result

func count() -> int: return _items.size()
func next_sequence() -> int: return _next_sequence
func item_at(index: int, status: SimStatus) -> StatusInstance:
	if index < 0 or index >= _items.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.BATTLE_STATE_READ, index, _items.size()); return StatusInstance.new()
	return _items[index].copy()

func restore(items: Array[StatusInstance], next_sequence: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if next_sequence < 1 or items.size() > BATTLE_MAX: status.fail(SimStatus.Code.INVALID_STATUS_INSTANCE, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE, next_sequence, items.size()); return false
	var copied: Array[StatusInstance] = []; var previous: StatusInstance
	for item: StatusInstance in items:
		if item == null or not item.is_initialized() or (previous != null and not _less(previous, item)) or item.application_sequence() >= next_sequence:
			status.fail(SimStatus.Code.INVALID_STATUS_INSTANCE, SimStatus.Operation.CONTENT_SNAPSHOT_VALIDATE); return false
		copied.append(item.copy()); previous = item
	_items = copied; _next_sequence = next_sequence; return true

func _body_count(body_id: int) -> int:
	var result: int = 0
	for item: StatusInstance in _items:
		if item.target_body_id() == body_id: result += 1
	return result

func _find_merge_index(definition: StatusDefinition, target_body_id: int, source_body_id: int) -> int:
	if definition.stack_policy_id() == StatusDefinition.StackPolicy.INDEPENDENT:
		return -1
	for index: int in range(_items.size()):
		var item: StatusInstance = _items[index]
		if item.target_body_id() != target_body_id or item.status_numeric_id() != definition.numeric_id(): continue
		if not definition.merge_sources() and item.source_body_id() != source_body_id: continue
		return index
	return -1

func would_update(definition: StatusDefinition, target_body_id: int, source_body_id: int) -> bool:
	return definition != null and definition.is_initialized() and _find_merge_index(definition, target_body_id, source_body_id) >= 0

func apply(definition: StatusDefinition, target_body_id: int, source_body_id: int, add_stacks: int, turn_index: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if definition == null or not definition.is_initialized() or add_stacks < 1 or add_stacks > definition.max_stacks(): status.fail(SimStatus.Code.INVALID_STATUS_DEFINITION, SimStatus.Operation.STATUS_APPLY, target_body_id, 0); return false
	var merge_index: int = _find_merge_index(definition, target_body_id, source_body_id)
	if merge_index >= 0:
		var item: StatusInstance = _items[merge_index]
		var stacks: int = 1 if definition.stack_policy_id() == StatusDefinition.StackPolicy.SINGLE else mini(item.stacks() + add_stacks, definition.max_stacks())
		var remaining: int = item.remaining()
		match definition.refresh_policy_id():
			StatusDefinition.RefreshPolicy.MAX: remaining = maxi(remaining, definition.default_duration())
			StatusDefinition.RefreshPolicy.REPLACE: remaining = definition.default_duration()
			StatusDefinition.RefreshPolicy.EXTEND: remaining = mini(remaining + definition.default_duration(), definition.max_duration())
			StatusDefinition.RefreshPolicy.KEEP: pass
		_items[merge_index] = item.with_values(stacks, remaining, turn_index, status); return status.is_ok()
	if _items.size() >= BATTLE_MAX or _body_count(target_body_id) >= BODY_MAX or _next_sequence > UInt32Math.U32_MAX:
		status.fail(SimStatus.Code.STATUS_LIMIT_EXCEEDED, SimStatus.Operation.STATUS_APPLY, target_body_id, _items.size()); return false
	var remaining: int = 0 if definition.duration_kind_id() == StatusDefinition.DurationKind.BATTLE else definition.default_duration()
	_items.append(StatusInstance.create(definition.numeric_id(), target_body_id, source_body_id, mini(add_stacks, definition.max_stacks()), remaining, turn_index, _next_sequence, status))
	if status.is_ok(): _next_sequence += 1; _items.sort_custom(_less)
	return status.is_ok()

func remove(target_body_id: int, status_numeric_id: int, stack_count: int, status: SimStatus, definition: StatusDefinition = null) -> int:
	if not status.is_ok(): return 0
	if target_body_id <= 0 or status_numeric_id <= 0 or stack_count < 0: status.fail(SimStatus.Code.INVALID_STATUS_INSTANCE, SimStatus.Operation.STATUS_REMOVE, target_body_id, status_numeric_id); return 0
	var removed: int = 0; var remaining_to_remove: int = stack_count; var index: int = 0
	while index < _items.size():
		var item: StatusInstance = _items[index]
		if item.target_body_id() != target_body_id or item.status_numeric_id() != status_numeric_id:
			index += 1; continue
		if stack_count == 0:
			removed += item.stacks(); _items.remove_at(index); continue
		if remaining_to_remove <= 0: break
		if definition != null and definition.is_initialized() and definition.duration_kind_id() == StatusDefinition.DurationKind.CHARGES:
			var charge_take: int = mini(remaining_to_remove, item.remaining()); removed += charge_take; remaining_to_remove -= charge_take
			if charge_take == item.remaining(): _items.remove_at(index)
			else:
				_items[index] = item.with_values(item.stacks(), item.remaining() - charge_take, item.applied_turn_index(), status)
				index += 1
			continue
		var take: int = mini(remaining_to_remove, item.stacks()); removed += take; remaining_to_remove -= take
		if take == item.stacks(): _items.remove_at(index)
		else:
			_items[index] = item.with_values(item.stacks() - take, item.remaining(), item.applied_turn_index(), status)
			index += 1
	return removed

func expire_target_turn(target_body_id: int, turn_index: int, catalog: ContentCatalog, status: SimStatus) -> Array[int]:
	var updated: int = 0; var expired: int = 0; var index: int = 0
	while index < _items.size():
		var item: StatusInstance = _items[index]
		if item.target_body_id() != target_body_id or item.applied_turn_index() >= turn_index:
			index += 1; continue
		var content_status := ContentStatus.new(); var definition: StatusDefinition = catalog.status_by_numeric_id(item.status_numeric_id(), content_status)
		if not content_status.is_ok(): status.fail(SimStatus.Code.INVALID_STATUS_DEFINITION, SimStatus.Operation.STATUS_EXPIRE, target_body_id, item.status_numeric_id()); return [updated, expired]
		if definition.duration_kind_id() != StatusDefinition.DurationKind.TARGET_TURNS:
			index += 1; continue
		if item.remaining() <= 1: _items.remove_at(index); expired += 1
		else:
			_items[index] = item.with_values(item.stacks(), item.remaining() - 1, item.applied_turn_index(), status)
			updated += 1
			index += 1
	return [updated, expired]

func remove_target(body_id: int) -> int:
	var before: int = _items.size(); _items = _items.filter(func(item: StatusInstance) -> bool: return item.target_body_id() != body_id); return before - _items.size()
func clear() -> void: _items.clear()
