class_name ConsumableDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _max_stack: int = 0
var _use_phase_id: int = 0
var _effect: RunEffectDefinition
var _initialized: bool = false

static func create(id_ref: ContentIdRef, max_stack: int, use_phase_id: int, effect: RunEffectDefinition, status: ContentStatus) -> ConsumableDefinition:
	var result := ConsumableDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or max_stack < 1 or max_stack > ContentLimits.RUN_ITEM_STACK_MAX or use_phase_id != RunPhase.Value.MAP_CHOICE or effect == null or not effect.is_initialized() or effect.kind_id() != RunEffectKind.Value.RECOVER_LIFE:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CONSUMABLE_VALIDATE, ContentIds.DocumentKind.CONSUMABLES, 0, ContentStatus.FieldId.EFFECT)
		return result
	result._id_ref = id_ref.copy(); result._max_stack = max_stack; result._use_phase_id = use_phase_id; result._effect = effect.copy(); result._initialized = true
	return result

func copy() -> ConsumableDefinition:
	var result := ConsumableDefinition.new()
	if _initialized: result._id_ref = _id_ref.copy(); result._max_stack = _max_stack; result._use_phase_id = _use_phase_id; result._effect = _effect.copy(); result._initialized = true
	return result
func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _id_ref.numeric_id() if _initialized else 0
func string_id() -> String: return _id_ref.string_id() if _initialized else ""
func id_ref() -> ContentIdRef: return _id_ref.copy() if _initialized else ContentIdRef.new()
func max_stack() -> int: return _max_stack
func use_phase_id() -> int: return _use_phase_id
func effect() -> RunEffectDefinition: return _effect.copy() if _initialized else RunEffectDefinition.new()
