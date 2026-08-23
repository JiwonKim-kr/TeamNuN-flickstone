class_name ContentSourceFile
extends RefCounted
## Temporary typed wrapper around one parsed source document.

var _kind_id: int = ContentIds.DocumentKind.INVALID
var _file_name: String = ""
var _schema_version: int = 0
var _root: Dictionary = {}
var _initialized: bool = false


static func create(
		kind_id: int,
		file_name: String,
		schema_version: int,
		root: Dictionary,
		status: ContentStatus
) -> ContentSourceFile:
	var result := ContentSourceFile.new()
	if not status.is_ok():
		return result
	if (
		not ContentIds.is_known_document_kind(kind_id)
		or file_name != ContentIds.file_for_document_kind(kind_id)
		or schema_version != ContentIds.schema_for_document_kind(kind_id)
	):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, kind_id)
		return result
	result._kind_id = kind_id
	result._file_name = file_name
	result._schema_version = schema_version
	result._root = root.duplicate(true)
	result._initialized = true
	return result


func is_initialized() -> bool: return _initialized
func kind_id() -> int: return _kind_id
func file_name() -> String: return _file_name
func schema_version() -> int: return _schema_version
func root_copy() -> Dictionary: return _root.duplicate(true)
