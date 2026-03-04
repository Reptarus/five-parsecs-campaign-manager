extends "res://src/core/store/StoreAdapter.gd"
class_name IOSStoreAdapter

## iOS adapter using GodotApplePlugins StoreKit2.
## StoreKitManager is a GDExtension class (NOT a singleton).
## Instantiated via ClassDB.instantiate("StoreKitManager").
##
## Key differences from Engine singleton pattern:
## - purchase() takes a StoreProduct object, not a string ID
## - Products must be cached from request_products() before purchasing
## - StoreTransaction.finish() must be called after delivering content
## - restore_completed returns (status, message), not an array of owned IDs
## - Entitlements arrive via transaction_updated signal individually

var _store_kit: RefCounted = null
var _owned_cache: Dictionary = {}
## Cache of StoreProduct objects keyed by product_id string.
## Needed because purchase() requires a StoreProduct, not a string.
var _product_cache: Dictionary = {}

func get_platform_name() -> String:
	return "iOS"

func is_available() -> bool:
	return _store_kit != null

func initialize() -> void:
	if not ClassDB.class_exists(&"StoreKitManager"):
		store_error.emit("StoreKitManager class not found")
		return
	_store_kit = ClassDB.instantiate(&"StoreKitManager") as RefCounted
	if not _store_kit:
		store_error.emit("Failed to instantiate StoreKitManager")
		return
	# Connect signals BEFORE calling start() — start() may emit
	# transaction_updated immediately for existing entitlements
	_safe_connect("products_request_completed", _on_products_received)
	_safe_connect("purchase_completed", _on_purchase_completed)
	_safe_connect("restore_completed", _on_restore_completed)
	_safe_connect("transaction_updated", _on_transaction_updated)
	_safe_connect("unverified_transaction_updated", _on_unverified_transaction)
	# start() begins listening for transaction updates and purchase intents
	if _store_kit.has_method("start"):
		_store_kit.call("start")

func query_products(product_ids: Array[String]) -> void:
	if not _store_kit:
		store_error.emit("StoreKit not available")
		return
	if _store_kit.has_method("request_products"):
		_store_kit.call("request_products", PackedStringArray(product_ids))

func purchase(product_id: String) -> void:
	if not _store_kit:
		purchase_failed.emit(product_id, "StoreKit not available")
		return
	# purchase() requires a StoreProduct object, not a string
	var product: RefCounted = _product_cache.get(product_id) as RefCounted
	if not product:
		purchase_failed.emit(
			product_id,
			"Product not loaded. Call query_products first.")
		return
	if _store_kit.has_method("purchase"):
		_store_kit.call("purchase", product)
	else:
		purchase_failed.emit(product_id, "Purchase method not available")

func restore_purchases() -> void:
	if not _store_kit:
		store_error.emit("StoreKit not available")
		return
	if _store_kit.has_method("restore_purchases"):
		_store_kit.call("restore_purchases")

func is_product_owned(product_id: String) -> bool:
	return _owned_cache.get(product_id, false)

func _safe_connect(sig_name: String, callback: Callable) -> void:
	if _store_kit and _store_kit.has_signal(sig_name):
		_store_kit.connect(sig_name, callback)

## products_request_completed(products: Array[StoreProduct], status: int)
func _on_products_received(products: Variant, status: int) -> void:
	var results: Array[Dictionary] = []
	if status != 0:  # StoreKitStatus.OK = 0
		store_error.emit("Product request failed (status %d)" % status)
		products_loaded.emit(results)
		return
	if products is Array:
		for p: Variant in products:
			if p == null:
				continue
			# p is a StoreProduct (RefCounted with properties)
			var product: RefCounted = p as RefCounted
			if not product:
				continue
			var pid: String = str(product.get("product_id"))
			_product_cache[pid] = product
			results.append({
				"product_id": pid,
				"dlc_id": "",
				"title": str(product.get("display_name")),
				"price": str(product.get("display_price")),
				"description": str(product.get("description_value")),
				"is_owned": _owned_cache.get(pid, false),
			})
	products_loaded.emit(results)

## purchase_completed(transaction: StoreTransaction, status: int, message: String)
func _on_purchase_completed(
	transaction: Variant, status: int, message: String
) -> void:
	# StoreKitStatus: OK=0, CANCELLED=2, USER_CANCELLED=4, PENDING=5
	if status == 0:
		# Success — extract product_id and finish transaction
		var pid: String = _extract_transaction_product_id(transaction)
		if not pid.is_empty():
			_owned_cache[pid] = true
			_finish_transaction(transaction)
			purchase_completed.emit(pid)
		else:
			purchase_failed.emit("", "Transaction has no product_id")
	elif status == 2 or status == 4:
		# Cancelled by user or system
		var pid: String = _extract_transaction_product_id(transaction)
		purchase_cancelled.emit(pid)
	elif status == 5:
		# Pending (e.g. Ask to Buy) — don't emit yet
		pass
	else:
		var pid: String = _extract_transaction_product_id(transaction)
		purchase_failed.emit(pid, message if not message.is_empty() else (
			"Purchase failed (status %d)" % status))

## restore_completed(status: int, message: String)
func _on_restore_completed(status: int, message: String) -> void:
	# Restore doesn't return a list of owned IDs directly.
	# Individual transaction_updated signals fire for each restored product.
	# Collect whatever we know from _owned_cache.
	var owned: Array[String] = []
	for pid: String in _owned_cache:
		if _owned_cache[pid]:
			owned.append(pid)
	if status != 0:
		store_error.emit("Restore failed: %s" % message)
	restore_completed.emit(owned)

## transaction_updated(transaction: StoreTransaction)
## Fires at startup for existing entitlements and after restores.
func _on_transaction_updated(transaction: Variant) -> void:
	var pid: String = _extract_transaction_product_id(transaction)
	if not pid.is_empty():
		_owned_cache[pid] = true
		_finish_transaction(transaction)

func _on_unverified_transaction(
	_transaction: Variant, _verification_error: int
) -> void:
	push_warning("IOSStoreAdapter: Unverified transaction received")

func _extract_transaction_product_id(transaction: Variant) -> String:
	if transaction == null:
		return ""
	if transaction is RefCounted:
		return str((transaction as RefCounted).get("product_id"))
	return ""

func _finish_transaction(transaction: Variant) -> void:
	## Notify App Store that content has been delivered.
	if transaction and transaction is RefCounted:
		var tx: RefCounted = transaction as RefCounted
		if tx.has_method("finish"):
			tx.call("finish")