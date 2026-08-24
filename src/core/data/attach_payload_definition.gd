class_name AttachPayloadDefinition
extends RefCounted

enum LinkRole { INVALID = 0, ANCHOR = 1, ATTACHED = 2 }
enum AnchorMode { INVALID = 0, SURFACE_FOLLOW = 1, FIXED_POINT = 2, CONTACT_POINT = 3 }

var _owner_role_id: int = LinkRole.INVALID
var _anchor_mode_id: int = AnchorMode.INVALID
var _anchor_offset: FixVec2 = FixVec2.zero()
var _attach_distance_raw: int = 0
var _inertia_basis_points: int = 0
var _duration_turns: int = 0
var _initialized: bool = false

static func create(owner_role_id: int, anchor_mode_id: int, anchor_offset: FixVec2, attach_distance_raw: int, inertia_basis_points: int, duration_turns: int, status: ContentStatus) -> AttachPayloadDefinition:
	var result := AttachPayloadDefinition.new()
	if not status.is_ok(): return result
	if owner_role_id < LinkRole.ANCHOR or owner_role_id > LinkRole.ATTACHED or anchor_mode_id < AnchorMode.SURFACE_FOLLOW or anchor_mode_id > AnchorMode.CONTACT_POINT or anchor_offset == null or not SimLimits.is_position_valid(anchor_offset) or attach_distance_raw < 0 or attach_distance_raw > SimLimits.RADIUS_MAX_RAW or inertia_basis_points < 1 or inertia_basis_points > 10000 or duration_turns < 1 or duration_turns > 1024 or (anchor_mode_id != AnchorMode.FIXED_POINT and not anchor_offset.is_zero()):
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.DOCUMENT_VALIDATE, ContentIds.DocumentKind.ABILITIES, 0, ContentStatus.FieldId.ATTACH_PAYLOAD)
		return result
	result._owner_role_id = owner_role_id; result._anchor_mode_id = anchor_mode_id; result._anchor_offset = anchor_offset.copy()
	result._attach_distance_raw = attach_distance_raw; result._inertia_basis_points = inertia_basis_points; result._duration_turns = duration_turns; result._initialized = true
	return result

func copy() -> AttachPayloadDefinition:
	if not _initialized: return AttachPayloadDefinition.new()
	var status := ContentStatus.new()
	return create(_owner_role_id, _anchor_mode_id, _anchor_offset, _attach_distance_raw, _inertia_basis_points, _duration_turns, status)

func is_initialized() -> bool: return _initialized
func owner_role_id() -> int: return _owner_role_id
func anchor_mode_id() -> int: return _anchor_mode_id
func anchor_offset() -> FixVec2: return _anchor_offset.copy()
func attach_distance_raw() -> int: return _attach_distance_raw
func inertia_basis_points() -> int: return _inertia_basis_points
func duration_turns() -> int: return _duration_turns
