class_name ContentCatalog
extends RefCounted
## Immutable, numeric-ID-sorted P2-1 catalog.

var _catalog_schema_version: int = 0
var _registry_entries: Array[ContentRegistryEntry] = []
var _pieces: Array[PieceDefinition] = []
var _abilities: Array[AbilityDefinition] = []
var _statuses: Array[StatusDefinition] = []
var _synergies: Array[SynergyDefinition] = []
var _maps: Array[MapDefinition] = []
var _enemies: Array[EnemyDefinition] = []
var _acts: Array[ActDefinition] = []
var _encounters: Array[EncounterDefinition] = []
var _reward_profiles: Array[RewardProfileDefinition] = []
var _compatibility_bytes: PackedByteArray = PackedByteArray()
var _fingerprint: PackedByteArray = PackedByteArray()
var _initialized: bool = false


static func create(
		catalog_schema_version: int,
		registry_entries: Array[ContentRegistryEntry],
		pieces: Array[PieceDefinition],
		abilities: Array[AbilityDefinition],
		statuses: Array[StatusDefinition],
		synergies: Array[SynergyDefinition],
		maps: Array[MapDefinition],
		enemies: Array[EnemyDefinition],
		acts: Array[ActDefinition],
		encounters: Array[EncounterDefinition],
		reward_profiles: Array[RewardProfileDefinition],
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
	for definition: StatusDefinition in statuses:
		if definition == null or not definition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
		result._statuses.append(definition.copy())
	for definition: SynergyDefinition in synergies:
		if definition == null or not definition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
		result._synergies.append(definition.copy())
	for definition: MapDefinition in maps:
		if definition == null or not definition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
		result._maps.append(definition.copy())
	for definition: EnemyDefinition in enemies:
		if definition == null or not definition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
		result._enemies.append(definition.copy())
	for definition: ActDefinition in acts:
		if definition == null or not definition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
		result._acts.append(definition.copy())
	for definition: EncounterDefinition in encounters:
		if definition == null or not definition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
		result._encounters.append(definition.copy())
	for definition: RewardProfileDefinition in reward_profiles:
		if definition == null or not definition.is_initialized(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.CATALOG_BUILD); return ContentCatalog.new()
		result._reward_profiles.append(definition.copy())
	result._catalog_schema_version = catalog_schema_version
	result._compatibility_bytes = compatibility_bytes.duplicate()
	result._fingerprint = fingerprint.duplicate()
	result._initialized = true
	return result


func copy() -> ContentCatalog:
	if not _initialized: return ContentCatalog.new()
	var status := ContentStatus.new()
	return create(_catalog_schema_version, _registry_entries, _pieces, _abilities, _statuses, _synergies, _maps, _enemies, _acts, _encounters, _reward_profiles, _compatibility_bytes, _fingerprint, status)


func is_initialized() -> bool: return _initialized
func catalog_schema_version() -> int: return _catalog_schema_version
func piece_count() -> int: return _pieces.size()
func ability_count() -> int: return _abilities.size()
func status_count() -> int: return _statuses.size()
func synergy_count() -> int: return _synergies.size()
func map_count() -> int: return _maps.size()
func enemy_count() -> int: return _enemies.size()
func act_count() -> int: return _acts.size()
func encounter_count() -> int: return _encounters.size()
func reward_profile_count() -> int: return _reward_profiles.size()
func relic_count() -> int: return 0
func consumable_count() -> int: return 0
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

func status_at(index: int, status: ContentStatus) -> StatusDefinition:
	if index < 0 or index >= _statuses.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.STATUSES); return StatusDefinition.new()
	return _statuses[index].copy()

func synergy_at(index: int, status: ContentStatus) -> SynergyDefinition:
	if index < 0 or index >= _synergies.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.SYNERGIES); return SynergyDefinition.new()
	return _synergies[index].copy()

func map_at(index: int, status: ContentStatus) -> MapDefinition:
	if index < 0 or index >= _maps.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.MAPS); return MapDefinition.new()
	return _maps[index].copy()

func enemy_at(index: int, status: ContentStatus) -> EnemyDefinition:
	if index < 0 or index >= _enemies.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENEMIES); return EnemyDefinition.new()
	return _enemies[index].copy()

func act_at(index: int, status: ContentStatus) -> ActDefinition:
	if index < 0 or index >= _acts.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ACTS); return ActDefinition.new()
	return _acts[index].copy()

func encounter_at(index: int, status: ContentStatus) -> EncounterDefinition:
	if index < 0 or index >= _encounters.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENCOUNTERS); return EncounterDefinition.new()
	return _encounters[index].copy()

func reward_profile_at(index: int, status: ContentStatus) -> RewardProfileDefinition:
	if index < 0 or index >= _reward_profiles.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.REWARD_PROFILES); return RewardProfileDefinition.new()
	return _reward_profiles[index].copy()


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

func status_by_numeric_id(id: int, status: ContentStatus) -> StatusDefinition:
	for item: StatusDefinition in _statuses:
		if item.numeric_id() == id: return item.copy()
		if item.numeric_id() > id: break
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.STATUSES, id)
	return StatusDefinition.new()

func synergy_by_numeric_id(id: int, status: ContentStatus) -> SynergyDefinition:
	for item: SynergyDefinition in _synergies:
		if item.numeric_id() == id: return item.copy()
		if item.numeric_id() > id: break
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.SYNERGIES, id)
	return SynergyDefinition.new()

func map_by_numeric_id(id: int, status: ContentStatus) -> MapDefinition:
	for item: MapDefinition in _maps:
		if item.numeric_id() == id: return item.copy()
		if item.numeric_id() > id: break
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.MAPS, id)
	return MapDefinition.new()

func enemy_by_numeric_id(id: int, status: ContentStatus) -> EnemyDefinition:
	for item: EnemyDefinition in _enemies:
		if item.numeric_id() == id: return item.copy()
		if item.numeric_id() > id: break
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENEMIES, id)
	return EnemyDefinition.new()

func act_by_numeric_id(id: int, status: ContentStatus) -> ActDefinition:
	for item: ActDefinition in _acts:
		if item.numeric_id() == id: return item.copy()
		if item.numeric_id() > id: break
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ACTS, id)
	return ActDefinition.new()

func encounter_by_numeric_id(id: int, status: ContentStatus) -> EncounterDefinition:
	for item: EncounterDefinition in _encounters:
		if item.numeric_id() == id: return item.copy()
		if item.numeric_id() > id: break
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENCOUNTERS, id)
	return EncounterDefinition.new()

func reward_profile_by_numeric_id(id: int, status: ContentStatus) -> RewardProfileDefinition:
	for item: RewardProfileDefinition in _reward_profiles:
		if item.numeric_id() == id: return item.copy()
		if item.numeric_id() > id: break
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.REWARD_PROFILES, id)
	return RewardProfileDefinition.new()

func synergy_by_tag_numeric_id(id: int, status: ContentStatus) -> SynergyDefinition:
	for item: SynergyDefinition in _synergies:
		if item.tag_ref().numeric_id() == id: return item.copy()
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.SYNERGIES, id)
	return SynergyDefinition.new()


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

func act_by_string_id(id: String, status: ContentStatus) -> ActDefinition:
	for item: ActDefinition in _acts:
		if item.string_id() == id: return item.copy()
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ACTS)
	return ActDefinition.new()

func encounter_by_string_id(id: String, status: ContentStatus) -> EncounterDefinition:
	for item: EncounterDefinition in _encounters:
		if item.string_id() == id: return item.copy()
	if status.is_ok(): status.fail(ContentStatus.Code.MISSING_REFERENCE, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.ENCOUNTERS)
	return EncounterDefinition.new()
