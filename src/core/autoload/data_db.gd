extends Node
## Godot-facing I/O adapter for the immutable P2-1 content catalog.

const DEFAULT_ROOT: String = "res://src/core/data"

var _catalog: ContentCatalog = ContentCatalog.new()
var _ready_ok: bool = false


func _ready() -> void:
	var status := ContentStatus.new()
	if not reload_catalog(DEFAULT_ROOT, status):
		push_error(
			"DataDB load failed code=%d op=%d doc=%d record=%d field=%d line=%d col=%d byte=%d"
			% [
				status.code(), status.operation(), status.document_kind_id(),
				status.record_numeric_id(), status.field_id(), status.line(),
				status.column(), status.byte_offset(),
			]
		)


func _json_files(root_path: String, status: ContentStatus) -> PackedStringArray:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		status.fail(ContentStatus.Code.IO_ERROR, ContentStatus.Operation.FILE_ENUMERATE)
		return PackedStringArray()
	var result: PackedStringArray = PackedStringArray()
	directory.list_dir_begin()
	while status.is_ok():
		var name: String = directory.get_next()
		if name.is_empty(): break
		if directory.current_is_dir(): continue
		if name.to_lower().ends_with(".json"): result.append(name)
	directory.list_dir_end()
	result.sort()
	return result


func _read_bytes(root_path: String, file_name: String, status: ContentStatus) -> PackedByteArray:
	var path: String = root_path.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		status.fail(ContentStatus.Code.IO_ERROR, ContentStatus.Operation.FILE_READ)
		return PackedByteArray()
	var length: int = file.get_length()
	if length < 0 or length > ContentLimits.FILE_MAX_BYTES:
		status.fail(ContentStatus.Code.FILE_TOO_LARGE, ContentStatus.Operation.FILE_READ)
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(length)
	if bytes.size() != length:
		status.fail(ContentStatus.Code.IO_ERROR, ContentStatus.Operation.FILE_READ)
		return PackedByteArray()
	return bytes


func _parse_object(bytes: PackedByteArray, kind_id: int, status: ContentStatus) -> Dictionary:
	status.set_context(kind_id)
	var parsed: Variant = StrictJsonParser.parse_utf8(bytes, status)
	if not status.is_ok(): return {}
	if typeof(parsed) != TYPE_DICTIONARY:
		status.fail(ContentStatus.Code.INVALID_TYPE, ContentStatus.Operation.DOCUMENT_VALIDATE, kind_id)
		return {}
	return parsed as Dictionary


func reload_catalog(root_path: String, status: ContentStatus) -> bool:
	if not status.is_ok(): return false
	var actual_files: PackedStringArray = _json_files(root_path, status)
	if not status.is_ok(): return false
	var expected_files: PackedStringArray = ContentIds.expected_json_files()
	if actual_files != expected_files:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.FILE_ENUMERATE, 0, 0, ContentStatus.FieldId.DOCUMENTS)
		return false

	var bytes_by_name: Dictionary = {}
	var total_bytes: int = 0
	for file_name: String in expected_files:
		var bytes: PackedByteArray = _read_bytes(root_path, file_name, status)
		if not status.is_ok(): return false
		total_bytes += bytes.size()
		if total_bytes > ContentLimits.CATALOG_MAX_BYTES:
			status.fail(ContentStatus.Code.CATALOG_LIMIT, ContentStatus.Operation.FILE_READ)
			return false
		bytes_by_name[file_name] = bytes

	var catalog_document: Dictionary = _parse_object(bytes_by_name[ContentIds.CATALOG_FILE], ContentIds.DocumentKind.INVALID, status)
	if not status.is_ok(): return false
	var source_documents: Array[ContentSourceFile] = []
	for kind_id: int in range(ContentIds.DocumentKind.ID_REGISTRY, ContentIds.DocumentKind.ENEMIES + 1):
		var file_name: String = ContentIds.file_for_document_kind(kind_id)
		var root: Dictionary = _parse_object(bytes_by_name[file_name], kind_id, status)
		if not status.is_ok(): return false
		var source: ContentSourceFile = ContentSourceFile.create(
			kind_id,
			file_name,
			ContentIds.schema_for_document_kind(kind_id),
			root,
			status
		)
		if not status.is_ok(): return false
		source_documents.append(source)

	var next_catalog: ContentCatalog = ContentCatalogBuilder.build(catalog_document, source_documents, status)
	if not status.is_ok() or not next_catalog.is_initialized():
		if status.is_ok(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DATA_DB_LOAD)
		return false
	_catalog = next_catalog
	_ready_ok = true
	return true


func is_ready() -> bool: return _ready_ok and _catalog.is_initialized()


func catalog_copy(status: ContentStatus) -> ContentCatalog:
	if not status.is_ok(): return ContentCatalog.new()
	if not is_ready():
		status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return ContentCatalog.new()
	return _catalog.copy()


func catalog_schema_version(status: ContentStatus) -> int:
	if not status.is_ok(): return 0
	if not is_ready():
		status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return 0
	return _catalog.catalog_schema_version()


func piece_by_numeric_id(id: int, status: ContentStatus) -> PieceDefinition:
	if not is_ready():
		if status.is_ok(): status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return PieceDefinition.new()
	return _catalog.piece_by_numeric_id(id, status)


func ability_by_numeric_id(id: int, status: ContentStatus) -> AbilityDefinition:
	if not is_ready():
		if status.is_ok(): status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return AbilityDefinition.new()
	return _catalog.ability_by_numeric_id(id, status)

func status_by_numeric_id(id: int, status: ContentStatus) -> StatusDefinition:
	if not is_ready():
		if status.is_ok(): status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return StatusDefinition.new()
	return _catalog.status_by_numeric_id(id, status)

func synergy_by_numeric_id(id: int, status: ContentStatus) -> SynergyDefinition:
	if not is_ready():
		if status.is_ok(): status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return SynergyDefinition.new()
	return _catalog.synergy_by_numeric_id(id, status)

func map_by_numeric_id(id: int, status: ContentStatus) -> MapDefinition:
	if not is_ready():
		if status.is_ok(): status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return MapDefinition.new()
	return _catalog.map_by_numeric_id(id, status)

func enemy_by_numeric_id(id: int, status: ContentStatus) -> EnemyDefinition:
	if not is_ready():
		if status.is_ok(): status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return EnemyDefinition.new()
	return _catalog.enemy_by_numeric_id(id, status)


func fingerprint_bytes(status: ContentStatus) -> PackedByteArray:
	if not status.is_ok(): return PackedByteArray()
	if not is_ready():
		status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return PackedByteArray()
	return _catalog.fingerprint_bytes()


func fingerprint_hex(status: ContentStatus) -> String:
	if not status.is_ok(): return ""
	if not is_ready():
		status.fail(ContentStatus.Code.CATALOG_UNAVAILABLE, ContentStatus.Operation.LOOKUP)
		return ""
	return _catalog.fingerprint_hex()
