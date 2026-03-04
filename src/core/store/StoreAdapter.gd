extends RefCounted
class_name StoreAdapter

## Abstract base class for platform-specific store implementations.
## Subclasses override all methods; base methods push warnings.
##
## Product info Dictionary schema:
## {
##   "product_id": String,    # Platform-specific ID
##   "dlc_id": String,        # Internal DLC ID (mapped by StoreManager)
##   "title": String,         # Localized title from store
##   "price": String,         # Formatted price string "$4.99"
##   "description": String,   # Localized description
##   "is_owned": bool,        # Whether already purchased
## }

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal purchase_cancelled(product_id: String)
signal products_loaded(products: Array[Dictionary])
signal restore_completed(owned_ids: Array[String])
signal store_error(message: String)

func get_platform_name() -> String:
	return "unknown"

func is_available() -> bool:
	return false

func initialize() -> void:
	push_warning("StoreAdapter.initialize() not overridden")

func query_products(_product_ids: Array[String]) -> void:
	push_warning("StoreAdapter.query_products() not overridden")

func purchase(_product_id: String) -> void:
	push_warning("StoreAdapter.purchase() not overridden")

func restore_purchases() -> void:
	push_warning("StoreAdapter.restore_purchases() not overridden")

func is_product_owned(_product_id: String) -> bool:
	return false
