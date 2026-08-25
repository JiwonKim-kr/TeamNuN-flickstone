class_name ShopOfferDefinition
extends RefCounted

var _offer_id: int = 0
var _item_kind_id: int = RunShopItemKind.Value.INVALID
var _item_ref: ContentIdRef
var _count: int = 0
var _cost: int = 0
var _initialized: bool = false

static func create(offer_id: int, item_kind_id: int, item_ref: ContentIdRef, count: int, cost: int, status: ContentStatus) -> ShopOfferDefinition:
	var result := ShopOfferDefinition.new()
	if not status.is_ok(): return result
	if offer_id < 1 or offer_id > ContentLimits.SHOP_OFFER_MAX_COUNT or not RunShopItemKind.is_valid(item_kind_id) or item_ref == null or not item_ref.is_initialized() or count < 1 or count > ContentLimits.RUN_ITEM_STACK_MAX or cost < 1 or cost > ContentLimits.RUN_EFFECT_GOLD_MAX:
		status.fail(ContentStatus.Code.INVALID_DOMAIN, ContentStatus.Operation.SHOP_VALIDATE, ContentIds.DocumentKind.SHOPS, 0, ContentStatus.FieldId.OFFERS)
		return result
	result._offer_id = offer_id; result._item_kind_id = item_kind_id; result._item_ref = item_ref.copy(); result._count = count; result._cost = cost; result._initialized = true
	return result

func copy() -> ShopOfferDefinition:
	var result := ShopOfferDefinition.new()
	if _initialized: result._offer_id = _offer_id; result._item_kind_id = _item_kind_id; result._item_ref = _item_ref.copy(); result._count = _count; result._cost = _cost; result._initialized = true
	return result
func is_initialized() -> bool: return _initialized
func offer_id() -> int: return _offer_id
func item_kind_id() -> int: return _item_kind_id
func item_ref() -> ContentIdRef: return _item_ref.copy() if _initialized else ContentIdRef.new()
func count() -> int: return _count
func cost() -> int: return _cost
