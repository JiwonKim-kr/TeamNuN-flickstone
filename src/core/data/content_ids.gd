class_name ContentIds
extends RefCounted
## Append-only IDs and exact P2-1 document names.

enum DocumentKind {
	INVALID = 0,
	ID_REGISTRY = 1,
	PIECES = 2,
	ABILITIES = 3,
	STATUSES = 4,
	SYNERGIES = 5,
}

enum Namespace {
	INVALID = 0,
	PIECE = 1,
	ABILITY = 2,
	STATUS = 3,
	SYNERGY = 4,
	PROJECTILE = 5,
	ENEMY = 6,
	MAP = 7,
	TAG = 8,
}

enum EntryState {
	INVALID = 0,
	ACTIVE = 1,
	RETIRED = 2,
}

const CATALOG_FILE: String = "catalog.json"
const REGISTRY_FILE: String = "id_registry.json"
const PIECES_FILE: String = "pieces.json"
const ABILITIES_FILE: String = "abilities.json"
const STATUSES_FILE: String = "statuses.json"
const SYNERGIES_FILE: String = "synergies.json"

const CATALOG_SCHEMA_VERSION: int = 3
const REGISTRY_SCHEMA_VERSION: int = 1
const PIECES_SCHEMA_VERSION: int = 2
const ABILITIES_SCHEMA_VERSION: int = 3
const STATUSES_SCHEMA_VERSION: int = 1
const SYNERGIES_SCHEMA_VERSION: int = 1
const FINGERPRINT_FORMAT_VERSION: int = 3


static func is_known_namespace(value: int) -> bool:
	return value >= Namespace.PIECE and value <= Namespace.TAG


static func is_known_document_kind(value: int) -> bool:
	return value >= DocumentKind.ID_REGISTRY and value <= DocumentKind.SYNERGIES


static func valid_string_id(value: String) -> bool:
	var bytes: PackedByteArray = value.to_utf8_buffer()
	if bytes.is_empty() or bytes.size() > 64:
		return false
	for index: int in range(bytes.size()):
		var byte: int = bytes[index]
		if index == 0:
			if byte < 97 or byte > 122:
				return false
		elif not ((byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57) or byte == 95):
			return false
	return true


static func expected_json_files() -> PackedStringArray:
	return PackedStringArray([
		ABILITIES_FILE,
		CATALOG_FILE,
		REGISTRY_FILE,
		PIECES_FILE,
		STATUSES_FILE,
		SYNERGIES_FILE,
	])


static func file_for_document_kind(kind_id: int) -> String:
	match kind_id:
		DocumentKind.ID_REGISTRY: return REGISTRY_FILE
		DocumentKind.PIECES: return PIECES_FILE
		DocumentKind.ABILITIES: return ABILITIES_FILE
		DocumentKind.STATUSES: return STATUSES_FILE
		DocumentKind.SYNERGIES: return SYNERGIES_FILE
	return ""


static func schema_for_document_kind(kind_id: int) -> int:
	match kind_id:
		DocumentKind.ID_REGISTRY: return REGISTRY_SCHEMA_VERSION
		DocumentKind.PIECES: return PIECES_SCHEMA_VERSION
		DocumentKind.ABILITIES: return ABILITIES_SCHEMA_VERSION
		DocumentKind.STATUSES: return STATUSES_SCHEMA_VERSION
		DocumentKind.SYNERGIES: return SYNERGIES_SCHEMA_VERSION
	return 0
