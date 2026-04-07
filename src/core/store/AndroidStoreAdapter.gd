extends "res://src/core/store/StoreAdapter.gd"

## Android adapter using official GodotGooglePlayBilling plugin.
## Uses BillingClient class (Godot 4.2+ first-party plugin).
## Requires GodotGooglePlayBilling plugin installed and Android Gradle Builds enabled.
##
## Purchase data format from BillingClient:
##   purchases: Array of { "product_ids": ["pid"], "purchase_state": int,
##     "purchase_token": "...", "is_acknowledged": bool }
## purchase_state: BillingClient.PurchaseState.PURCHASED = 1

var _billing: RefCounted = null  # BillingClient instance
var _owned_cache: Dictionary = {}
var _pending_purchase_id: String = ""

func get_platform_name() -> String:
	return "Android"

func is_available() -> bool:
	return _billing != null

func initialize() -> void:
	if not ClassDB.class_exists(&"BillingClient"):
		store_error.emit("BillingClient class not found — GodotGooglePlayBilling plugin not installed")
		return
	_billing = ClassDB.instantiate(&"BillingClient")
	if not _billing:
		store_error.emit("Failed to instantiate BillingClient")
		return
	# Connect all 8 BillingClient signals
	_safe_connect("connected", _on_connected)
	_safe_connect("disconnected", _on_disconnected)
	_safe_connect("connect_error", _on_connect_error)
	_safe_connect("query_product_details_response", _on_query_product_details_response)
	_safe_connect("query_purchases_response", _on_query_purchases_response)
	_safe_connect("on_purchase_updated", _on_purchase_updated)
	_safe_connect("acknowledge_purchase_response", _on_acknowledge_purchase_response)
	_safe_connect("consume_purchase_response", _on_consume_purchase_response)
	if _billing.has_method("start_connection"):
		_billing.start_connection()

func query_products(product_ids: Array[String]) -> void:
	if not _billing:
		store_error.emit("BillingClient not available")
		return
	if _billing.has_method("query_product_details"):
		# BillingClient.ProductType.INAPP for one-time purchases (DLC packs)
		_billing.query_product_details(product_ids, _get_product_type_inapp())

func purchase(product_id: String) -> void:
	if not _billing:
		purchase_failed.emit(product_id, "BillingClient not available")
		return
	_pending_purchase_id = product_id
	if _billing.has_method("purchase"):
		var result: Variant = _billing.purchase(product_id)
		# Check immediate return for billing flow launch failure
		if result is Dictionary:
			var response_code: int = (result as Dictionary).get("response_code", -1)
			if response_code != _get_response_ok():
				var msg: String = str((result as Dictionary).get("debug_message", "Billing flow launch failed"))
				purchase_failed.emit(product_id, msg)
				_pending_purchase_id = ""

func restore_purchases() -> void:
	if not _billing:
		store_error.emit("BillingClient not available")
		return
	if _billing.has_method("query_purchases"):
		_billing.query_purchases(_get_product_type_inapp())

func is_product_owned(product_id: String) -> bool:
	return _owned_cache.get(product_id, false)

# ── Helpers ────────────────────────────────────────────────────────

func _safe_connect(signal_name: String, callback: Callable) -> void:
	if _billing and _billing.has_signal(signal_name):
		_billing.connect(signal_name, callback)

## Get BillingClient.ProductType.INAPP value safely
func _get_product_type_inapp() -> Variant:
	if _billing and "ProductType" in _billing and "INAPP" in _billing.ProductType:
		return _billing.ProductType.INAPP
	# Fallback string if enum not accessible
	return "inapp"

## Get BillingClient.BillingResponseCode.OK value safely
func _get_response_ok() -> int:
	if _billing and "BillingResponseCode" in _billing and "OK" in _billing.BillingResponseCode:
		return _billing.BillingResponseCode.OK
	return 0  # OK is typically 0

## Get BillingClient.PurchaseState.PURCHASED value safely
func _get_purchase_state_purchased() -> int:
	if _billing and "PurchaseState" in _billing and "PURCHASED" in _billing.PurchaseState:
		return _billing.PurchaseState.PURCHASED
	return 1  # PURCHASED is typically 1

## Extract product ID from a purchase dict
func _extract_product_id(purchase_dict: Dictionary) -> String:
	var product_ids: Variant = purchase_dict.get("product_ids", [])
	if product_ids is Array and not (product_ids as Array).is_empty():
		return str((product_ids as Array)[0])
	return ""

# ── Signal handlers ────────────────────────────────────────────────

func _on_connected() -> void:
	pass  # Connection established, products can now be queried

func _on_disconnected() -> void:
	push_warning("AndroidStoreAdapter: Billing disconnected")

func _on_connect_error(response_code: int, debug_message: String) -> void:
	store_error.emit("Billing connect error (code %d): %s" % [response_code, debug_message])

func _on_query_product_details_response(result: Dictionary) -> void:
	var response_code: int = result.get("response_code", -1) as int
	if response_code != _get_response_ok():
		store_error.emit("Product details query failed (code %d): %s" % [
			response_code, str(result.get("debug_message", ""))])
		products_loaded.emit([] as Array[Dictionary])
		return
	var details: Array = result.get("product_details", [])
	var results: Array[Dictionary] = []
	for d: Variant in details:
		var detail: Dictionary = d as Dictionary if d is Dictionary else {}
		var pid: String = str(detail.get("product_id", ""))
		# Extract formatted price from one_time_purchase_offer_details
		var price_info: Variant = detail.get("one_time_purchase_offer_details", {})
		var formatted_price: String = ""
		if price_info is Dictionary:
			formatted_price = str((price_info as Dictionary).get("formatted_price", ""))
		results.append({
			"product_id": pid,
			"dlc_id": "",  # Mapped by StoreManager
			"title": str(detail.get("name", detail.get("title", ""))),
			"price": formatted_price,
			"description": str(detail.get("description", "")),
			"is_owned": _owned_cache.get(pid, false),
		})
	products_loaded.emit(results)

func _on_query_purchases_response(result: Dictionary) -> void:
	var response_code: int = result.get("response_code", -1) as int
	if response_code != _get_response_ok():
		store_error.emit("Purchase query failed (code %d): %s" % [
			response_code, str(result.get("debug_message", ""))])
		return
	var purchases: Array = result.get("purchases", [])
	var owned: Array[String] = []
	for p: Variant in purchases:
		var purchase: Dictionary = p as Dictionary if p is Dictionary else {}
		_process_purchase(purchase)
		var pid: String = _extract_product_id(purchase)
		if not pid.is_empty():
			owned.append(pid)
	restore_completed.emit(owned)

func _on_purchase_updated(result: Dictionary) -> void:
	var response_code: int = result.get("response_code", -1) as int
	if response_code != _get_response_ok():
		# Purchase failed or cancelled
		var debug_msg: String = str(result.get("debug_message", ""))
		# Response code 1 = USER_CANCELED in BillingResponseCode
		if response_code == 1:
			if not _pending_purchase_id.is_empty():
				purchase_cancelled.emit(_pending_purchase_id)
				_pending_purchase_id = ""
		else:
			var reason: String = debug_msg if not debug_msg.is_empty() else (
				"Purchase failed (code %d)" % response_code)
			if not _pending_purchase_id.is_empty():
				purchase_failed.emit(_pending_purchase_id, reason)
				_pending_purchase_id = ""
		return
	var purchases: Array = result.get("purchases", [])
	for p: Variant in purchases:
		var purchase: Dictionary = p as Dictionary if p is Dictionary else {}
		_process_purchase(purchase)
		var pid: String = _extract_product_id(purchase)
		if pid == _pending_purchase_id:
			purchase_completed.emit(pid)
			_pending_purchase_id = ""

func _on_acknowledge_purchase_response(result: Dictionary) -> void:
	var response_code: int = result.get("response_code", -1) as int
	if response_code != _get_response_ok():
		push_warning("AndroidStoreAdapter: Acknowledge failed (code %d): %s" % [
			response_code, str(result.get("debug_message", ""))])

func _on_consume_purchase_response(_result: Dictionary) -> void:
	pass  # DLC packs are non-consumable, this handler is a safety net

## Process a single purchase — acknowledge if needed, update cache
func _process_purchase(purchase: Dictionary) -> void:
	var pid: String = _extract_product_id(purchase)
	if pid.is_empty():
		return
	var state: int = purchase.get("purchase_state", 0) as int
	if state != _get_purchase_state_purchased():
		return  # Only process PURCHASED state, not PENDING or UNSPECIFIED
	_owned_cache[pid] = true
	# Acknowledge non-consumable if not already acknowledged (must be within 3 days)
	var is_acked: bool = purchase.get("is_acknowledged", false)
	if not is_acked:
		var token: String = str(purchase.get("purchase_token", ""))
		if not token.is_empty() and _billing and _billing.has_method("acknowledge_purchase"):
			_billing.acknowledge_purchase(token)
