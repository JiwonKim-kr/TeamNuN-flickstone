class_name AbilityEffectDefinition
extends RefCounted

enum Kind { INVALID = 0, DAMAGE = 1, HEAL = 2, KNOCKBACK = 3, PULL = 4, MODIFY_CT = 5, MODIFY_VELOCITY = 6, MODIFY_STAT = 7, TELEPORT = 8, SET_FLAG = 9, APPLY_STATUS = 10, REMOVE_STATUS = 11, SPAWN_PIECE = 12, SPAWN_PROJECTILE = 13, TRANSFORM_PIECE = 14, ATTACH = 15 }

var _kind_id: int = Kind.INVALID
var _selector: AbilitySelectorDefinition
var _value_a: int = 0
var _value_b: int = 0
var _operation_id: int = 0
var _spawn_payload: SpawnPayloadDefinition
var _transform_payload: TransformPayloadDefinition
var _attach_payload: AttachPayloadDefinition
var _initialized: bool = false

static func create(kind_id: int, selector: AbilitySelectorDefinition, value_a: int, value_b: int, operation_id: int, status: ContentStatus, spawn_payload: SpawnPayloadDefinition = null, transform_payload: TransformPayloadDefinition = null, attach_payload: AttachPayloadDefinition = null) -> AbilityEffectDefinition:
	var result := AbilityEffectDefinition.new()
	if not status.is_ok(): return result
	if kind_id < Kind.DAMAGE or kind_id > Kind.ATTACH or kind_id == Kind.TELEPORT or kind_id == Kind.SET_FLAG or selector == null or not selector.is_initialized():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECT_KIND_ID); return result
	var dynamic: bool = kind_id >= Kind.SPAWN_PIECE
	var payload_count: int = (1 if spawn_payload != null else 0) + (1 if transform_payload != null else 0) + (1 if attach_payload != null else 0)
	if (dynamic and (value_a != 0 or value_b != 0 or operation_id != 0 or payload_count != 1)) or (not dynamic and payload_count != 0):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	if (kind_id == Kind.SPAWN_PIECE or kind_id == Kind.SPAWN_PROJECTILE) and (spawn_payload == null or not spawn_payload.is_initialized()):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.SPAWN_PAYLOAD); return result
	if kind_id == Kind.SPAWN_PIECE and (spawn_payload.speed_raw() != 0 or spawn_payload.direction_mode_id() != SpawnPayloadDefinition.DirectionMode.OWNER_VELOCITY):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.SPAWN_PAYLOAD); return result
	if kind_id == Kind.SPAWN_PROJECTILE and spawn_payload.speed_raw() <= 0:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.SPAWN_PAYLOAD); return result
	if kind_id == Kind.TRANSFORM_PIECE and (transform_payload == null or not transform_payload.is_initialized()):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.TRANSFORM_PAYLOAD); return result
	if kind_id == Kind.ATTACH and (attach_payload == null or not attach_payload.is_initialized()):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.ATTACH_PAYLOAD); return result
	if kind_id == Kind.MODIFY_STAT:
		if value_a < ModifierKind.Value.ATTACK or value_a > ModifierKind.Value.CRITICAL_BASIS_POINTS or value_b == 0 or operation_id != ModifierKind.Operation.ADD:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	elif operation_id != 0:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.OPERATION_ID); return result
	if kind_id == Kind.APPLY_STATUS and (value_a <= 0 or value_b <= 0): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	if kind_id == Kind.REMOVE_STATUS and (value_a <= 0 or value_b < 0): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	if (kind_id == Kind.DAMAGE or kind_id == Kind.HEAL or kind_id == Kind.KNOCKBACK or kind_id == Kind.PULL) and (value_a <= 0 or value_b != 0):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.EFFECTS); return result
	if kind_id == Kind.MODIFY_VELOCITY and value_a == 0 and value_b == 0:
		pass
	result._kind_id = kind_id; result._selector = selector.copy(); result._value_a = value_a; result._value_b = value_b; result._operation_id = operation_id
	result._spawn_payload = null if spawn_payload == null else spawn_payload.copy()
	result._transform_payload = null if transform_payload == null else transform_payload.copy()
	result._attach_payload = null if attach_payload == null else attach_payload.copy()
	result._initialized = true
	return result

func copy() -> AbilityEffectDefinition:
	var status := ContentStatus.new(); return create(_kind_id, _selector, _value_a, _value_b, _operation_id, status, _spawn_payload, _transform_payload, _attach_payload) if _initialized else AbilityEffectDefinition.new()
func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func selector() -> AbilitySelectorDefinition: return _selector.copy()
func value_a() -> int: return _value_a
func value_b() -> int: return _value_b
func operation_id() -> int: return _operation_id
func spawn_payload() -> SpawnPayloadDefinition: return SpawnPayloadDefinition.new() if _spawn_payload == null else _spawn_payload.copy()
func transform_payload() -> TransformPayloadDefinition: return TransformPayloadDefinition.new() if _transform_payload == null else _transform_payload.copy()
func attach_payload() -> AttachPayloadDefinition: return AttachPayloadDefinition.new() if _attach_payload == null else _attach_payload.copy()
