class_name TransformPayloadDefinition
extends RefCounted

var _piece_ref: ContentIdRef
var _initialized: bool = false

static func create(piece_ref: ContentIdRef, status: ContentStatus) -> TransformPayloadDefinition:
	var result := TransformPayloadDefinition.new()
	if not status.is_ok(): return result
	if piece_ref == null or not piece_ref.is_initialized():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.TRANSFORM_PAYLOAD)
		return result
	result._piece_ref = piece_ref.copy(); result._initialized = true
	return result

func copy() -> TransformPayloadDefinition:
	if not _initialized: return TransformPayloadDefinition.new()
	var status := ContentStatus.new()
	return create(_piece_ref, status)

func is_initialized() -> bool: return _initialized
func piece_ref() -> ContentIdRef: return ContentIdRef.new() if not _initialized else _piece_ref.copy()
