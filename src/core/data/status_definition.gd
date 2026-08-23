class_name StatusDefinition
extends RefCounted

enum StackPolicy { INVALID = 0, SINGLE = 1, STACKED = 2, INDEPENDENT = 3 }
enum DurationKind { INVALID = 0, TARGET_TURNS = 1, BATTLE = 2, CHARGES = 3 }
enum RefreshPolicy { INVALID = 0, MAX = 1, REPLACE = 2, EXTEND = 3, KEEP = 4 }

var _id_ref: ContentIdRef
var _stack_policy_id: int = 0
var _max_stacks: int = 0
var _duration_kind_id: int = 0
var _default_duration: int = 0
var _max_duration: int = 0
var _refresh_policy_id: int = 0
var _merge_sources: bool = false
var _modifiers: Array[StatusModifierDefinition] = []
var _initialized: bool = false

static func create(id_ref: ContentIdRef, stack_policy_id: int, max_stacks: int, duration_kind_id: int, default_duration: int, max_duration: int, refresh_policy_id: int, merge_sources: bool, modifiers: Array[StatusModifierDefinition], status: ContentStatus) -> StatusDefinition:
	var result := StatusDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or stack_policy_id < StackPolicy.SINGLE or stack_policy_id > StackPolicy.INDEPENDENT or max_stacks < 1 or max_stacks > ContentLimits.STATUS_MAX_STACKS or duration_kind_id < DurationKind.TARGET_TURNS or duration_kind_id > DurationKind.CHARGES or refresh_policy_id < RefreshPolicy.MAX or refresh_policy_id > RefreshPolicy.KEEP or modifiers.size() > ContentLimits.STATUS_MODIFIERS_MAX_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD, ContentIds.DocumentKind.STATUSES, 0, ContentStatus.FieldId.RECORDS); return result
	var duration_max: int = ContentLimits.STATUS_CHARGES_MAX if duration_kind_id == DurationKind.CHARGES else ContentLimits.STATUS_TURNS_MAX
	if duration_kind_id == DurationKind.BATTLE:
		if default_duration != 0 or max_duration != 0: status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return result
	elif default_duration < 1 or default_duration > duration_max or max_duration < default_duration or max_duration > duration_max:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return result
	for modifier: StatusModifierDefinition in modifiers:
		if modifier == null or not modifier.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return StatusDefinition.new()
		result._modifiers.append(modifier.copy())
	result._id_ref = id_ref.copy(); result._stack_policy_id = stack_policy_id; result._max_stacks = max_stacks; result._duration_kind_id = duration_kind_id
	result._default_duration = default_duration; result._max_duration = max_duration; result._refresh_policy_id = refresh_policy_id; result._merge_sources = merge_sources; result._initialized = true
	return result

func copy() -> StatusDefinition:
	var status := ContentStatus.new(); return create(_id_ref, _stack_policy_id, _max_stacks, _duration_kind_id, _default_duration, _max_duration, _refresh_policy_id, _merge_sources, _modifiers, status) if _initialized else StatusDefinition.new()
func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _id_ref.numeric_id() if _initialized else 0
func string_id() -> String: return _id_ref.string_id() if _initialized else ""
func stack_policy_id() -> int: return _stack_policy_id
func max_stacks() -> int: return _max_stacks
func duration_kind_id() -> int: return _duration_kind_id
func default_duration() -> int: return _default_duration
func max_duration() -> int: return _max_duration
func refresh_policy_id() -> int: return _refresh_policy_id
func merge_sources() -> bool: return _merge_sources
func modifier_count() -> int: return _modifiers.size()
func modifier_at(index: int, status: ContentStatus) -> StatusModifierDefinition:
	if index < 0 or index >= _modifiers.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP); return StatusModifierDefinition.new()
	return _modifiers[index].copy()
