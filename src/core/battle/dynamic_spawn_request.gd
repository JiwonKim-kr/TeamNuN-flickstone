class_name DynamicSpawnRequest
extends RefCounted

var body_template: SimBody
var participant_template: BattleParticipant
var combatant_template: BattleCombatant
var piece_numeric_id: int = 0
var faction: int = BattleParticipant.Faction.INVALID
var ability_numeric_ids: Array[int] = []
var expire_kind_id: int = PieceDefinition.ExpireKind.INVALID
var expire_value: int = 0
var applied_turn_index: int = 0
var cause_body_id: int = 0
var event_type_id: int = 0
var ordinal: int = 0

func copy() -> DynamicSpawnRequest:
	var result := DynamicSpawnRequest.new()
	result.body_template = null if body_template == null else body_template.copy(); result.participant_template = null if participant_template == null else participant_template.copy(); result.combatant_template = null if combatant_template == null else combatant_template.copy()
	result.piece_numeric_id = piece_numeric_id; result.faction = faction; result.ability_numeric_ids = ability_numeric_ids.duplicate(); result.expire_kind_id = expire_kind_id; result.expire_value = expire_value; result.applied_turn_index = applied_turn_index
	result.cause_body_id = cause_body_id; result.event_type_id = event_type_id; result.ordinal = ordinal
	return result
