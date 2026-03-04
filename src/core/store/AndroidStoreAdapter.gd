extends "res://src/core/store/StoreAdapter.gd"
class_name AndroidStoreAdapter

## Android adapter using godot-google-play-iapp plugin.
## Uses Engine.get_singleton("AndroidIAPP") for Google Play Billing v7.
##
## Purchase data format from plugin:
##   purchases_list: Array of { "products": ["pid"], "purchase_state": int,
##     "purchase_token": "...", "is_acknowledged": bool }
## purchase_state: 0=UNSPECIFIED, 1=PURCHASED, 2=PENDING

var _iapp: Object = null
var _owned_cache: Dictionary = {}
var _pending_purchase_id: String = ""

func get_platform_name() -> String:
	return "Android"

func is_available() -> bool:
	return _iapp != null

func initialize() -> void:
	if Engine.has_singleton("AndroidIAPP"):
		_iapp = Engine.get_singleton("AndroidIAPP")
	if not _iapp:
		store_error.emit("AndroidIAPP plugin not found")
		return
	_safe_connect("connected", _on_connected)
	_safe_connect("disconnected", _on_disconnected)
	_safe_connect("purchase_updated", _on_purchases_updated)
	_safe_connect("purchase_cancelled", _on_purchase_cancelled)
	_safe_connect("purchase_error", _on_purchase_error)
	_safe_connect("purchase_consumed", _on_purchase_consumed)
	_safe_connect("purchase_consumed_error", _on_purchase_consumed_error)
	_safe_connect("purchase_acknowledged", _on_purchase_acknowledged)
	_safe_connect("purchase_acknowledged_error", _on_purchase_acknowledged_error)
	_safe_connect("query_purchases", _on_query_purchases)
	_safe_connect("query_purchases_error", _on_query_purchases_error)
	_safe_connect("query_product_details", _on_query_product_details)
	_safe_connect("query_product_details_error", _on_query_product_details_error)
	if _iapp.has_method("startConnection"):
		_iapp.startConnection()

func query_products(product_ids: Array[String]) -> void:
	if not _iapp:
		store_error.emit("AndroidIAPP not available")
		return
	if _iapp.has_method("queryProductDetails"):
		_iapp.queryProductDetails(product_ids, "inapp")

func purchase(product_id: String) -> void:
	if not _iapp:
		purchase_failed.emit(product_id, "AndroidIAPP not available")
		return
	_pending_purchase_id = product_id
	# Plugin expects array of product IDs, isOfferPersonalized = false
	if _iapp.has_method("purchase"):
		_iapp.purchase([product_id], false)

func restore_purchases() -> void:
	if not _iapp:
		store_error.emit("AndroidIAPP not available")
		return
	if _iapp.has_method("queryPurchases"):
		_iapp.queryPurchases("inapp", false)

func is_product_owned(product_id: String) -> bool:
	return _owned_cache.get(product_id, false)

func _safe_connect(signal_name: String, callback: Callable) -> void:
	if _iapp and _iapp.has_signal(signal_name):
		_iapp.connect(signal_name, callback)

func _on_connected() -> void:
	pass

func _on_disconnected(_data: Variant) -> void:
	push_warning("AndroidStoreAdapter: Billing disconnected")

## Extract product ID from a purchase dict. Plugin uses "products" array.
func _extract_product_id(purchase_dict: Dictionary) -> String:
	var products: Variant = purchase_dict.get("products", [])
	if products is Array and not (products as Array).is_empty():
		return str((products as Array)[0])
	# Fallback for older plugin versions
	var pid: String = str(purchase_dict.get("product_id", ""))
	if pid.is_empty():
		pid = str(purchase_dict.get("productId", ""))
	return pid

func _on_purchases_updated(data: Dictionary) -> void:
	var purchases: Array = data.get("purchases_list", [])
	for p: Variant in purchases:
		var purchase_dict: Dictionary = p as Dictionary if p is Dictionary else {}
		var pid: String = _extract_product_id(purchase_dict)
		if pid.is_empty():
			continue
		var state: int = purchase_dict.get("purchase_state", 0) as int
		if state != 1:  # Only process PURCHASED state (not PENDING)
			continue
		_owned_cache[pid] = true
		# Acknowledge non-consumable if not already acknowledged
		var is_acked: bool = purchase_dict.get("is_acknowledged", false)
		if not is_acked:
			var token: String = str(purchase_dict.get("purchase_token", ""))
			if not token.is_empty() and _iapp and _iapp.has_method("acknowledgePurchase"):
				_iapp.acknowledgePurchase(token)
		if pid == _pending_purchase_id:
			purchase_completed.emit(pid)
			_pending_purchase_id = ""

func _on_purchase_cancelled(_data: Variant) -> void:
	if not _pending_purchase_id.is_empty():
		purchase_cancelled.emit(_pending_purchase_id)
		_pending_purchase_id = ""

func _on_purchase_error(data: Variant) -> void:
	var reason: String = "Unknown error"
	if data is Dictionary:
		reason = str(data.get("debug_message", data.get("response_code", "Unknown")))
	if not _pending_purchase_id.is_empty():
		purchase_failed.emit(_pending_purchase_id, reason)
		_pending_purchase_id = ""

func _on_purchase_consumed(_data: Variant) -> void:
	pass

func _on_purchase_consumed_error(_data: Variant) -> void:
	pass

func _on_purchase_acknowledged(_data: Variant) -> void:
	pass

func _on_purchase_acknowledged_error(_data: Variant) -> void:
	push_warning("AndroidStoreAdapter: Failed to acknowledge purchase")

func _on_query_purchases(data: Dictionary) -> void:
	var purchases: Array = data.get("purchases_list", [])
	var owned: Array[String] = []
	for p: Variant in purchases:
		var purchase_dict: Dictionary = p as Dictionary if p is Dictionary else {}
		var pid: String = _extract_product_id(purchase_dict)
		if not pid.is_empty():
			_owned_cache[pid] = true
			owned.append(pid)
	restore_completed.emit(owned)

func _on_query_purchases_error(data: Variant) -> void:
	store_error.emit("Failed to query purchases: %s" % str(data))

func _on_query_product_details(data: Dictionary) -> void:
	var details: Array = data.get("product_details_list", [])
	var results: Array[Dictionary] = []
	for d: Variant in details:
		var detail: Dictionary = d as Dictionary if d is Dictionary else {}
		var pid: String = str(detail.get("product_id", ""))
		var price_info: Variant = detail.get(
			"one_time_purchase_offer_details", {})
		var formatted_price: String = ""
		if price_info is Dictionary:
			formatted_price = str(
				(price_info as Dictionary).get("formatted_price", ""))
		results.append({
			"product_id": pid,
			"dlc_id": "",
			"title": str(detail.get("name", detail.get("title", ""))),
			"price": formatted_price,
			"description": str(detail.get("description", "")),
			"is_owned": _owned_cache.get(pid, false),
		})
	products_loaded.emit(results)

func _on_query_product_details_error(data: Variant) -> void:
	store_error.emit("Failed to query product details: %s" % str(data))