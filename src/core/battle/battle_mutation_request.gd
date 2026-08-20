class_name BattleMutationRequest
extends RefCounted

enum Kind { INVALID = 0, SPAWN = 1, REMOVE = 2 }

var kind: int = Kind.INVALID
var tick: int = 0
var cause_body_id: int = 0
var event_type_id: int = 0
var ordinal: int = 0
var body_template: SimBody
var participant_template: BattleParticipant
var combatant_template: BattleCombatant
var body_id: int = 0

func copy() -> BattleMutationRequest:
	var result := BattleMutationRequest.new()
	result.kind = kind
	result.tick = tick
	result.cause_body_id = cause_body_id
	result.event_type_id = event_type_id
	result.ordinal = ordinal
	result.body_template = null if body_template == null else body_template.copy()
	result.participant_template = null if participant_template == null else participant_template.copy()
	result.combatant_template = null if combatant_template == null else combatant_template.copy()
	result.body_id = body_id
	return result
