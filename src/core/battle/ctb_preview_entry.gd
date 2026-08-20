class_name CtbPreviewEntry
extends RefCounted

var _order_index: int = 0
var _body_id: int = 0
var _faction: int = 0
var _ready_at_abstract_time: int = 0
var _simultaneous_group: int = 0
var _is_simultaneous: bool = false


static func create(order_index: int, participant: BattleParticipant, ready_at: int, group: int) -> CtbPreviewEntry:
	var result := CtbPreviewEntry.new()
	result._order_index = order_index
	result._body_id = participant.body_id()
	result._faction = participant.faction()
	result._ready_at_abstract_time = ready_at
	result._simultaneous_group = group
	return result


func mark_simultaneous() -> void: _is_simultaneous = true
func copy() -> CtbPreviewEntry:
	var result := CtbPreviewEntry.new()
	result._order_index = _order_index
	result._body_id = _body_id
	result._faction = _faction
	result._ready_at_abstract_time = _ready_at_abstract_time
	result._simultaneous_group = _simultaneous_group
	result._is_simultaneous = _is_simultaneous
	return result
func order_index() -> int: return _order_index
func body_id() -> int: return _body_id
func faction() -> int: return _faction
func ready_at_abstract_time() -> int: return _ready_at_abstract_time
func simultaneous_group() -> int: return _simultaneous_group
func is_simultaneous() -> bool: return _is_simultaneous
