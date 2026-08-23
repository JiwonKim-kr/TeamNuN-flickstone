class_name ContentCatalog
extends RefCounted
## Immutable, numeric-ID-sorted P2-1 catalog.

var _catalog_schema_version: int = 0
var _registry_entries: Array[ContentRegistryEntry] = []
var _pieces: Array[PieceDefinition] = []
var _abilities: Array[AbilityDefinition] = []
var _compatibility_bytes: PackedByteArray = PackedByteArray()
var _fingerprint: PackedByteArray = PackedByteArray()
var _initialized: bool = false


static func create(
		catalog_schema_version: int,
		registry_entries: Array[ContentRegistryEntry],
		pieces: Array[PieceDefinition],
		abilities: Array[AbilityDefinition],
		compatibility_bytes: PackedByteArray,
		fingerprint: PackedByteArray,
		status: ContentStatus
) -> ContentCatalog:
	var result := ContentCatalog.new()
	if not status.is_ok(): return result
	if catalog_schema_version != ContentIds.CATALOG_SCHEMA_VERSION or fingerprint.size() != 32:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD)
		return result
	for entry: ContentRegistryEntry in registry_entries:
		if entry == null or not entry.is_initialized():
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD)
			return ContentCatalog.new()
		result._registry_entries.append(entry.copy())
	for piece: PieceDefinition in pieces:
		if piece == null or not piece.is_initialized():
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD)
			return ContentCatalog.new()
		result._pieces.append(piece.copy())
	for ability: AbilityDefinition in abilities:
		if ability == null or not ability.is_initialized():
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD)
			return ContentCatalog.new()
		result._abilities.append(ability.copy())
	result._catalog_schema_version = catalog_schema_version
	result._compatibility_bytes = compatibility_bytes.duplicate()
	result._fingerprint = fingerprint.duplicate()
	result._initialized = true
	return result


func copy() -> ContentCatalog:
	if not _initialized: return ContentCatalog.new()
	var status := ContentStatus.new()
	return create(_catalog_schema_version, _registry_entries, _pieces, _abilities, _compatibility_bytes, _fingerprint, status)


func is_initialized() -> bool: return _initialized
func catalog_schema_version() -> int: return _catalog_schema_version
func piece_count() -> int: return _pieces.size()
func ability_count() -> int: return _abilities.size()
func registry_entry_count() -> int: return _registry_entries.size()
func fingerprint_bytes() -> PackedByteArray: return _fingerprint.duplicate()
func compatibility_bytes_for_test() -> PackedByteArray: return _compatibility_bytes.duplicate()


func fingerprint_hex() -> String:
	const HEX: String = "0123456789abcdef"
	var result: String = ""
	for value: int in _fingerprint:
		result += HEX.substr((value >> 4) & 0xF, 1)
		result += HEX.substr(value & 0xF, 1)
	return result


func piece_at(index: int, status: ContentStatus) -> PieceDefinition:
	if not status.is_ok(): return PieceDefinition.new()
	if index < 0 or index >= _pieces.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.PIECES)
		return PieceDefinition.new()
	return _pieces[index].copy()


func ability_at(index: int, status: ContentStatus) -> AbilityDefinition:
	if not status.is_ok(): return AbilityDefinition.new()
	if index < 0 or index >= _abilities.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ABILITIES)
		return AbilityDefinition.new()
	return _abilities[index].copy()


func registry_entry_at(index: int, status: ContentStatus) -> ContentRegistryEntry:
	if not status.is_ok(): return ContentRegistryEntry.new()
	if index < 0 or index >= _registry_entries.size():
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ID_REGISTRY)
		return ContentRegistryEntry.new()
	return _registry_entries[index].copy()


func piece_by_numeric_id(id: int, status: ContentStatus) -> PieceDefinition:
	var low: int = 0
	var high: int = _pieces.size() - 1
	while status.is_ok() and low <= high:
		var middle: int = (low + high) >> 1
		var value: int = _pieces[middle].numeric_id()
		if value == id: return _pieces[middle].copy()
		if value < id: low = middle + 1
		else: high = middle - 1
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.PIECES, id)
	return PieceDefinition.new()


func ability_by_numeric_id(id: int, status: ContentStatus) -> AbilityDefinition:
	var low: int = 0
	var high: int = _abilities.size() - 1
	while status.is_ok() and low <= high:
		var middle: int = (low + high) >> 1
		var value: int = _abilities[middle].numeric_id()
		if value == id: return _abilities[middle].copy()
		if value < id: low = middle + 1
		else: high = middle - 1
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ABILITIES, id)
	return AbilityDefinition.new()


func piece_by_string_id(id: String, status: ContentStatus) -> PieceDefinition:
	for item: PieceDefinition in _pieces:
		if item.string_id() == id: return item.copy()
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.PIECES)
	return PieceDefinition.new()


func ability_by_string_id(id: String, status: ContentStatus) -> AbilityDefinition:
	for item: AbilityDefinition in _abilities:
		if item.string_id() == id: return item.copy()
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ABILITIES)
	return AbilityDefinition.new()
