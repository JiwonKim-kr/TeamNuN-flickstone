class_name SimLink
extends RefCounted

enum AnchorMode { INVALID = 0, SURFACE_FOLLOW = 1, FIXED_POINT = 2, CONTACT_POINT = 3 }

var _link_id: int = 0
var _anchor_body_id: int = 0
var _attached_body_id: int = 0
var _anchor_mode_id: int = AnchorMode.INVALID
var _anchor_offset: FixVec2 = FixVec2.zero()
var _attach_distance_raw: int = 0
var _inertia_basis_points: int = 0
var _remaining_turns: int = 0
var _applied_turn_index: int = 0
var _initialized: bool = false

static func _build(link_id: int, anchor_body_id: int, attached_body_id: int, anchor_mode_id: int, anchor_offset: FixVec2, attach_distance_raw: int, inertia_basis_points: int, remaining_turns: int, applied_turn_index: int) -> SimLink:
	var result := SimLink.new()
	result._link_id = link_id; result._anchor_body_id = anchor_body_id; result._attached_body_id = attached_body_id
	result._anchor_mode_id = anchor_mode_id; result._anchor_offset = anchor_offset.copy(); result._attach_distance_raw = attach_distance_raw
	result._inertia_basis_points = inertia_basis_points; result._remaining_turns = remaining_turns; result._applied_turn_index = applied_turn_index; result._initialized = true
	return result

static func _valid(link_id: int, allow_unassigned: bool, anchor_body_id: int, attached_body_id: int, anchor_mode_id: int, anchor_offset: FixVec2, attach_distance_raw: int, inertia_basis_points: int, remaining_turns: int, applied_turn_index: int, status: SimStatus) -> bool:
	if not status.is_ok(): return false
	if not UInt32Math.is_u32(link_id) or (link_id == 0 and not allow_unassigned) or anchor_body_id == 0 or attached_body_id == 0 or anchor_body_id == attached_body_id or not UInt32Math.is_u32(anchor_body_id) or not UInt32Math.is_u32(attached_body_id) or anchor_mode_id < AnchorMode.SURFACE_FOLLOW or anchor_mode_id > AnchorMode.CONTACT_POINT or anchor_offset == null or not SimLimits.is_position_valid(anchor_offset) or attach_distance_raw < 0 or attach_distance_raw > SimLimits.RADIUS_MAX_RAW or inertia_basis_points < 1 or inertia_basis_points > 10000 or remaining_turns < 1 or remaining_turns > 1024 or applied_turn_index < 0 or not UInt32Math.is_u32(applied_turn_index):
		status.fail(SimStatus.Code.INVALID_ATTACH_LINK, SimStatus.Operation.WORLD_ADD_LINK, anchor_body_id, attached_body_id); return false
	return true

static func create_unassigned(anchor_body_id: int, attached_body_id: int, anchor_mode_id: int, anchor_offset: FixVec2, attach_distance_raw: int, inertia_basis_points: int, remaining_turns: int, applied_turn_index: int, status: SimStatus) -> SimLink:
	if not _valid(0, true, anchor_body_id, attached_body_id, anchor_mode_id, anchor_offset, attach_distance_raw, inertia_basis_points, remaining_turns, applied_turn_index, status): return SimLink.new()
	return _build(0, anchor_body_id, attached_body_id, anchor_mode_id, anchor_offset, attach_distance_raw, inertia_basis_points, remaining_turns, applied_turn_index)

static func restore(link_id: int, anchor_body_id: int, attached_body_id: int, anchor_mode_id: int, anchor_offset: FixVec2, attach_distance_raw: int, inertia_basis_points: int, remaining_turns: int, applied_turn_index: int, status: SimStatus) -> SimLink:
	if not _valid(link_id, false, anchor_body_id, attached_body_id, anchor_mode_id, anchor_offset, attach_distance_raw, inertia_basis_points, remaining_turns, applied_turn_index, status): return SimLink.new()
	return _build(link_id, anchor_body_id, attached_body_id, anchor_mode_id, anchor_offset, attach_distance_raw, inertia_basis_points, remaining_turns, applied_turn_index)

func assigned_copy(link_id: int, status: SimStatus) -> SimLink:
	if _link_id != 0 or not _valid(link_id, false, _anchor_body_id, _attached_body_id, _anchor_mode_id, _anchor_offset, _attach_distance_raw, _inertia_basis_points, _remaining_turns, _applied_turn_index, status): return SimLink.new()
	return _build(link_id, _anchor_body_id, _attached_body_id, _anchor_mode_id, _anchor_offset, _attach_distance_raw, _inertia_basis_points, _remaining_turns, _applied_turn_index)

func with_remaining_turns(value: int, status: SimStatus) -> SimLink:
	if value < 1 or value > 1024:
		status.fail(SimStatus.Code.INVALID_ATTACH_LINK, SimStatus.Operation.WORLD_REMOVE_LINK, _link_id, value); return SimLink.new()
	return _build(_link_id, _anchor_body_id, _attached_body_id, _anchor_mode_id, _anchor_offset, _attach_distance_raw, _inertia_basis_points, value, _applied_turn_index)

func copy() -> SimLink: return SimLink.new() if not _initialized else _build(_link_id, _anchor_body_id, _attached_body_id, _anchor_mode_id, _anchor_offset, _attach_distance_raw, _inertia_basis_points, _remaining_turns, _applied_turn_index)
func is_initialized() -> bool: return _initialized
func link_id() -> int: return _link_id
func anchor_body_id() -> int: return _anchor_body_id
func attached_body_id() -> int: return _attached_body_id
func anchor_mode_id() -> int: return _anchor_mode_id
func anchor_offset() -> FixVec2: return _anchor_offset.copy()
func attach_distance_raw() -> int: return _attach_distance_raw
func inertia_basis_points() -> int: return _inertia_basis_points
func remaining_turns() -> int: return _remaining_turns
func applied_turn_index() -> int: return _applied_turn_index
func contains_body(body_id: int) -> bool: return body_id == _anchor_body_id or body_id == _attached_body_id
func is_pair(left: int, right: int) -> bool: return (left == _anchor_body_id and right == _attached_body_id) or (right == _anchor_body_id and left == _attached_body_id)
