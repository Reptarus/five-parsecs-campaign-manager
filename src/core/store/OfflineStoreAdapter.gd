extends "res://src/core/store/StoreAdapter.gd"
class_name OfflineStoreAdapter

## Fallback adapter when no store plugin is available.
## Used in: editor testing, desktop builds without Steam, dev mode.
## Allows manual toggle of ownership via DLCManagementDialog (existing behavior).

func get_platform_name() -> String:
	return "Offline"

func is_available() -> bool:
	return true

func initialize() -> void:
	pass

func query_products(_product_ids: Array[String]) -> void:
	products_loaded.emit([])

func purchase(product_id: String) -> void:
	purchase_failed.emit(product_id, "Store not available in offline mode")

func restore_purchases() -> void:
	restore_completed.emit([] as Array[String])

func is_product_owned(_product_id: String) -> bool:
	return false