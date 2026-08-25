class_name ShopDefinition
extends RefCounted

var _id_ref: ContentIdRef
var _offers: Array[ShopOfferDefinition] = []
var _initialized: bool = false

static func create(id_ref: ContentIdRef, offers: Array[ShopOfferDefinition], status: ContentStatus) -> ShopDefinition:
	var result := ShopDefinition.new()
	if not status.is_ok(): return result
	if id_ref == null or not id_ref.is_initialized() or offers.is_empty() or offers.size() > ContentLimits.SHOP_OFFER_MAX_COUNT:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.SHOP_VALIDATE, ContentIds.DocumentKind.SHOPS, 0, ContentStatus.FieldId.OFFERS); return result
	var seen: Dictionary = {}
	for index: int in range(offers.size()):
		var offer: ShopOfferDefinition = offers[index]
		if offer == null or not offer.is_initialized() or offer.offer_id() != index + 1:
			status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.SHOP_VALIDATE, ContentIds.DocumentKind.SHOPS, id_ref.numeric_id(), ContentStatus.FieldId.OFFER_ID); return ShopDefinition.new()
		var key: String = "%d:%d" % [offer.item_kind_id(), offer.item_ref().numeric_id()]
		if seen.has(key): status.fail(ContentStatus.Code.DUPLICATE_ID, ContentStatus.Operation.SHOP_VALIDATE, ContentIds.DocumentKind.SHOPS, id_ref.numeric_id(), ContentStatus.FieldId.ITEM_REF); return ShopDefinition.new()
		seen[key] = true; result._offers.append(offer.copy())
	result._id_ref = id_ref.copy(); result._initialized = true
	return result

func copy() -> ShopDefinition:
	var result := ShopDefinition.new()
	if _initialized:
		result._id_ref = _id_ref.copy()
		for offer: ShopOfferDefinition in _offers: result._offers.append(offer.copy())
		result._initialized = true
	return result
func is_initialized() -> bool: return _initialized
func numeric_id() -> int: return _id_ref.numeric_id() if _initialized else 0
func string_id() -> String: return _id_ref.string_id() if _initialized else ""
func id_ref() -> ContentIdRef: return _id_ref.copy() if _initialized else ContentIdRef.new()
func offer_count() -> int: return _offers.size()
func offer_at(index: int, status: ContentStatus) -> ShopOfferDefinition:
	if index < 0 or index >= _offers.size(): status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.LOOKUP, ContentIds.DocumentKind.SHOPS, numeric_id(), ContentStatus.FieldId.OFFERS); return ShopOfferDefinition.new()
	return _offers[index].copy()
