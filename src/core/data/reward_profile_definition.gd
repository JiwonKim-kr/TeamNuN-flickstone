class_name RewardProfileDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _victory_gold: int = 0
var _recruit_choice_count: int = 0
var _recruit_pool_refs: Array[ContentIdRef] = []
var _revenge_status_ref: ContentIdRef
var _initialized: bool = false


static func create(
		id_ref: ContentIdRef,
		victory_gold: int,
		recruit_choice_count: int,
		recruit_pool_refs: Array[ContentIdRef],
		revenge_status_ref: ContentIdRef,
		status: ContentStatus
) -> RewardProfileDefinition:
	var result := RewardProfileDefinition.new()
	if not status.is_ok(): return result
	if (
		id_ref == null
		or not id_ref.is_initialized()
		or victory_gold < 0
		or victory_gold > ContentLimits.REWARD_VICTORY_GOLD_MAX
		or recruit_choice_count < 1
		or recruit_choice_count > ContentLimits.REWARD_RECRUIT_CHOICE_MAX
		or recruit_pool_refs.is_empty()
		or recruit_pool_refs.size() > ContentLimits.REWARD_RECRUIT_POOL_MAX
		or recruit_choice_count > recruit_pool_refs.size()
		or revenge_status_ref == null
		or not revenge_status_ref.is_initialized()
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, ContentIds.DocumentKind.REWARD_PROFILES, 0)
		return result
	var previous_id: int = 0
	for ref: ContentIdRef in recruit_pool_refs:
		if ref == null or not ref.is_initialized() or ref.numeric_id() <= previous_id:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.REWARD_PROFILE_VALIDATE, ContentIds.DocumentKind.REWARD_PROFILES, id_ref.numeric_id(), ContentStatus.FieldId.RECRUIT_POOL_REFS)
			return RewardProfileDefinition.new()
		result._recruit_pool_refs.append(ref.copy())
		previous_id = ref.numeric_id()
	result._id_ref = id_ref.copy()
	result._victory_gold = victory_gold
	result._recruit_choice_count = recruit_choice_count
	result._revenge_status_ref = revenge_status_ref.copy()
	result._initialized = true
	return result


func copy() -> RewardProfileDefinition:
	if not _initialized: return RewardProfileDefinition.new()
	var status := ContentStatus.new()
	return create(_id_ref, _victory_gold, _recruit_choice_count, _recruit_pool_refs, _revenge_status_ref, status)


func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _id_ref.numeric_id() if _initialized else 0
func string_id() -> String: return _id_ref.string_id() if _initialized else ""
func id_ref() -> ContentIdRef: return _id_ref.copy() if _initialized else ContentIdRef.new()
func victory_gold() -> int: return _victory_gold
func recruit_choice_count() -> int: return _recruit_choice_count
func recruit_pool_count() -> int: return _recruit_pool_refs.size()
func recruit_pool_ref_at(index: int, status: ContentStatus) -> ContentIdRef:
	if index < 0 or index >= _recruit_pool_refs.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.REWARD_PROFILES, numeric_id(), ContentStatus.FieldId.RECRUIT_POOL_REFS)
		return ContentIdRef.new()
	return _recruit_pool_refs[index].copy()
func revenge_status_ref() -> ContentIdRef: return _revenge_status_ref.copy() if _initialized else ContentIdRef.new()
