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
	MAPS = 6,
	ENEMIES = 7,
	ACTS = 8,
	ENCOUNTERS = 9,
	RELICS = 10,
	CONSUMABLES = 11,
	REWARD_PROFILES = 12,
	SHOPS = 13,
	EVENTS = 14,
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
	ACT = 9,
	ENCOUNTER = 10,
	RELIC = 11,
	CONSUMABLE = 12,
	REWARD_PROFILE = 13,
	SHOP = 14,
	EVENT = 15,
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
const MAPS_FILE: String = "maps.json"
const ENEMIES_FILE: String = "enemies.json"
const ACTS_FILE: String = "acts.json"
const ENCOUNTERS_FILE: String = "encounters.json"
const RELICS_FILE: String = "relics.json"
const CONSUMABLES_FILE: String = "consumables.json"
const REWARD_PROFILES_FILE: String = "reward_profiles.json"
const SHOPS_FILE: String = "shops.json"
const EVENTS_FILE: String = "events.json"

const CATALOG_SCHEMA_VERSION: int = 10
const REGISTRY_SCHEMA_VERSION: int = 1
const PIECES_SCHEMA_VERSION: int = 3
const ABILITIES_SCHEMA_VERSION: int = 6
const STATUSES_SCHEMA_VERSION: int = 1
const SYNERGIES_SCHEMA_VERSION: int = 1
const MAPS_SCHEMA_VERSION: int = 1
const ENEMIES_SCHEMA_VERSION: int = 2
const ACTS_SCHEMA_VERSION: int = 1
const ENCOUNTERS_SCHEMA_VERSION: int = 2
const RELICS_SCHEMA_VERSION: int = 2
const CONSUMABLES_SCHEMA_VERSION: int = 2
const REWARD_PROFILES_SCHEMA_VERSION: int = 1
const SHOPS_SCHEMA_VERSION: int = 1
const EVENTS_SCHEMA_VERSION: int = 1
const FINGERPRINT_FORMAT_VERSION: int = 10


static func is_known_namespace(value: int) -> bool:
	return value >= Namespace.PIECE and value <= Namespace.EVENT


static func is_known_document_kind(value: int) -> bool:
	return value >= DocumentKind.ID_REGISTRY and value <= DocumentKind.EVENTS


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
		ACTS_FILE,
		CATALOG_FILE,
		CONSUMABLES_FILE,
		ENCOUNTERS_FILE,
		ENEMIES_FILE,
		EVENTS_FILE,
		REGISTRY_FILE,
		MAPS_FILE,
		PIECES_FILE,
		RELICS_FILE,
		REWARD_PROFILES_FILE,
		SHOPS_FILE,
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
		DocumentKind.MAPS: return MAPS_FILE
		DocumentKind.ENEMIES: return ENEMIES_FILE
		DocumentKind.ACTS: return ACTS_FILE
		DocumentKind.ENCOUNTERS: return ENCOUNTERS_FILE
		DocumentKind.RELICS: return RELICS_FILE
		DocumentKind.CONSUMABLES: return CONSUMABLES_FILE
		DocumentKind.REWARD_PROFILES: return REWARD_PROFILES_FILE
		DocumentKind.SHOPS: return SHOPS_FILE
		DocumentKind.EVENTS: return EVENTS_FILE
	return ""


static func schema_for_document_kind(kind_id: int) -> int:
	match kind_id:
		DocumentKind.ID_REGISTRY: return REGISTRY_SCHEMA_VERSION
		DocumentKind.PIECES: return PIECES_SCHEMA_VERSION
		DocumentKind.ABILITIES: return ABILITIES_SCHEMA_VERSION
		DocumentKind.STATUSES: return STATUSES_SCHEMA_VERSION
		DocumentKind.SYNERGIES: return SYNERGIES_SCHEMA_VERSION
		DocumentKind.MAPS: return MAPS_SCHEMA_VERSION
		DocumentKind.ENEMIES: return ENEMIES_SCHEMA_VERSION
		DocumentKind.ACTS: return ACTS_SCHEMA_VERSION
		DocumentKind.ENCOUNTERS: return ENCOUNTERS_SCHEMA_VERSION
		DocumentKind.RELICS: return RELICS_SCHEMA_VERSION
		DocumentKind.CONSUMABLES: return CONSUMABLES_SCHEMA_VERSION
		DocumentKind.REWARD_PROFILES: return REWARD_PROFILES_SCHEMA_VERSION
		DocumentKind.SHOPS: return SHOPS_SCHEMA_VERSION
		DocumentKind.EVENTS: return EVENTS_SCHEMA_VERSION
	return 0
