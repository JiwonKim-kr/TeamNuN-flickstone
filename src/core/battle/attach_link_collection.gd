class_name AttachLinkCollection
extends RefCounted

var _items: Array[SimLink] = []

static func from_world(world: SimWorld, status: SimStatus) -> AttachLinkCollection:
	var result := AttachLinkCollection.new()
	if world == null: status.fail(SimStatus.Code.INVALID_ATTACH_LINK, SimStatus.Operation.WORLD_ADD_LINK); return result
	for index: int in range(world.link_count()): result._items.append(world.link_at(index, status))
	return result
func count() -> int: return _items.size()
func item_at(index: int, status: SimStatus) -> SimLink:
	if index < 0 or index >= _items.size(): status.fail(SimStatus.Code.INVALID_RANGE, SimStatus.Operation.WORLD_ADD_LINK, index, _items.size()); return SimLink.new()
	return _items[index].copy()
