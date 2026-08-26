class_name CombatAudioCueRouter
extends RefCounted
## Battle trigger facts -> presentation-only audio cues.

enum Cue { IMPACT = 1, BOUNCY_REBOUND = 2, CLEAN_HIT = 3 }

const BOUNCE_COOLDOWN_MSEC := 80

var _traits_by_body_id: Dictionary = {}
var _last_bounce_msec_by_body_id: Dictionary = {}
var _clean_contact_blocked: bool = false


func reset_battle() -> void:
	_traits_by_body_id.clear()
	_last_bounce_msec_by_body_id.clear()
	_clean_contact_blocked = false


func reset_launch() -> void:
	_clean_contact_blocked = false


func _refresh_traits(state: BattleState, catalog: ContentCatalog, status: SimStatus) -> void:
	for index: int in range(state.piece_identity_count()):
		var identity: BattlePieceIdentity = state.piece_identity_at(index, status)
		if not status.is_ok(): return
		var content_status := ContentStatus.new()
		var piece: PieceDefinition = catalog.piece_by_numeric_id(identity.piece_numeric_id(), content_status)
		var level: PieceLevelDefinition = piece.level_definition(identity.level(), content_status)
		if not content_status.is_ok():
			status.fail(SimStatus.Code.INVALID_PIECE_IDENTITY, SimStatus.Operation.BATTLE_PIECE_IDENTITY_READ, identity.body_id(), identity.piece_numeric_id())
			return
		_traits_by_body_id[identity.body_id()] = Vector2i(
			level.elasticity_multiplier_raw(), level.clean_hit_damage_multiplier_raw()
		)


func _has_elasticity(body_id: int) -> bool:
	return _traits_by_body_id.has(body_id) and (_traits_by_body_id[body_id] as Vector2i).x > FixMath.ONE_RAW


func _has_clean_hit(body_id: int) -> bool:
	return _traits_by_body_id.has(body_id) and (_traits_by_body_id[body_id] as Vector2i).y > FixMath.ONE_RAW


func _append_bounce(cues: Array[int], body_id: int, source_sequence: int, seen: Dictionary, now_msec: int) -> void:
	if body_id <= 0 or not _has_elasticity(body_id) or seen.has(source_sequence): return
	var last_msec: int = int(_last_bounce_msec_by_body_id.get(body_id, now_msec - BOUNCE_COOLDOWN_MSEC))
	if now_msec - last_msec < BOUNCE_COOLDOWN_MSEC: return
	seen[source_sequence] = true
	_last_bounce_msec_by_body_id[body_id] = now_msec
	cues.append(Cue.BOUNCY_REBOUND)


func route(state: BattleState, catalog: ContentCatalog, records: Array[BattleTriggerRecord], now_msec: int, status: SimStatus) -> Array[int]:
	var cues: Array[int] = []
	if not status.is_ok() or state == null or not state.is_initialized() or catalog == null or not catalog.is_initialized(): return cues
	_refresh_traits(state, catalog, status)
	if not status.is_ok(): return cues
	var impact_sequences: Dictionary = {}
	var bounce_sequences: Dictionary = {}
	var clean_hit_sequences: Dictionary = {}
	var actor_id: int = state.current_actor_body_id()
	for record: BattleTriggerRecord in records:
		var trigger_id: int = record.trigger_id()
		var source_sequence: int = record.source_sim_sequence()
		if trigger_id == BattleTriggerId.Value.ON_ALLY_COLLIDE:
			if record.subject_body_id() == actor_id or record.other_body_id() == actor_id:
				_clean_contact_blocked = true
			_append_bounce(cues, record.subject_body_id(), source_sequence, bounce_sequences, now_msec)
			_append_bounce(cues, record.other_body_id(), source_sequence, bounce_sequences, now_msec)
		elif trigger_id == BattleTriggerId.Value.ON_WALL_BOUNCE:
			_append_bounce(cues, record.subject_body_id(), source_sequence, bounce_sequences, now_msec)
			if record.subject_body_id() == actor_id: _clean_contact_blocked = true
		elif trigger_id == BattleTriggerId.Value.ON_HIT_DEAL:
			if record.value_a() > 0 and source_sequence > 0 and not impact_sequences.has(source_sequence):
				impact_sequences[source_sequence] = true
				cues.append(Cue.IMPACT)
			if record.subject_body_id() == actor_id and not _clean_contact_blocked and _has_clean_hit(actor_id) and record.value_a() > 0 and source_sequence > 0 and not clean_hit_sequences.has(source_sequence):
				clean_hit_sequences[source_sequence] = true
				cues.append(Cue.CLEAN_HIT)
			_append_bounce(cues, record.subject_body_id(), source_sequence, bounce_sequences, now_msec)
			_append_bounce(cues, record.other_body_id(), source_sequence, bounce_sequences, now_msec)
		elif trigger_id == BattleTriggerId.Value.ON_HIT_TAKE:
			_append_bounce(cues, record.subject_body_id(), source_sequence, bounce_sequences, now_msec)
			_append_bounce(cues, record.other_body_id(), source_sequence, bounce_sequences, now_msec)
	return cues
