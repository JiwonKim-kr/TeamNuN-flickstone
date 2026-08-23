class_name EffectApplication
extends RefCounted

var owner_body_id: int = 0
var ability_numeric_id: int = 0
var effect_index: int = 0
var target_body_id: int = 0
var kind_id: int = 0

static func create(owner: int, ability_id: int, index: int, target: int, kind: int) -> EffectApplication:
	var result := EffectApplication.new(); result.owner_body_id = owner; result.ability_numeric_id = ability_id; result.effect_index = index; result.target_body_id = target; result.kind_id = kind; return result
func copy() -> EffectApplication: return create(owner_body_id, ability_numeric_id, effect_index, target_body_id, kind_id)
