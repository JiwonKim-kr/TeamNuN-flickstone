class_name SynergyTally
extends RefCounted

class Entry:
	extends RefCounted
	var tag_numeric_id: int
	var faction_id: int
	var count: int
	func _init(p_tag: int, p_faction: int, p_count: int) -> void: tag_numeric_id = p_tag; faction_id = p_faction; count = p_count
	func copy() -> Entry: return Entry.new(tag_numeric_id, faction_id, count)

var _entries: Array[Entry] = []

static func create(entries: Array[Entry], status: SimStatus) -> SynergyTally:
	var result := SynergyTally.new(); var previous_tag: int = 0; var previous_faction: int = 0
	for entry: Entry in entries:
		if entry == null or entry.tag_numeric_id <= 0 or entry.faction_id < BattleParticipant.Faction.PLAYER or entry.faction_id > BattleParticipant.Faction.ENEMY or entry.count < 2 or entry.count > ContentLimits.SYNERGY_COUNT_MAX or (not result._entries.is_empty() and (entry.tag_numeric_id < previous_tag or (entry.tag_numeric_id == previous_tag and entry.faction_id <= previous_faction))):
			status.fail(SimStatus.Code.INVALID_SYNERGY_TALLY, SimStatus.Operation.SYNERGY_TALLY_BUILD); return SynergyTally.new()
		result._entries.append(entry.copy()); previous_tag = entry.tag_numeric_id; previous_faction = entry.faction_id
	return result
func copy() -> SynergyTally:
	var status := SimStatus.new(); return create(_entries, status)
func count() -> int: return _entries.size()
func tag_numeric_id_at(index: int) -> int: return _entries[index].tag_numeric_id
func faction_id_at(index: int) -> int: return _entries[index].faction_id
func value_at(index: int) -> int: return _entries[index].count
