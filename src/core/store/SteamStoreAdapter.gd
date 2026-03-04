extends "res://src/core/store/StoreAdapter.gd"
class_name SteamStoreAdapter

## Steam DLC adapter using GodotSteam plugin.
## Steam handles DLC purchases through the Steam client overlay.
## We detect ownership via isDLCInstalled() and open the store page for purchase.

var _steam: Object = null
var _owned_cache: Dictionary = {}

func get_platform_name() -> String:
	return "Steam"

func is_available() -> bool:
	return _steam != null

func initialize() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
	if not _steam:
		store_error.emit("GodotSteam plugin not found")
		return
	# Initialize Steam API — required before any calls work
	if _steam.has_method("steamInitEx"):
		var result: Dictionary = _steam.steamInitEx(false)
		var status: int = result.get("status", -1)
		if status > 0:
			push_warning("SteamStoreAdapter: steamInitEx failed: %s" % str(result))
			_steam = null
			store_error.emit("Steam initialization failed (status %d)" % status)
			return
	if _steam.has_signal("dlc_installed"):
		_steam.dlc_installed.connect(_on_dlc_installed)

func query_products(product_ids: Array[String]) -> void:
	if not _steam:
		store_error.emit("Steam not available")
		return
	var results: Array[Dictionary] = []
	for pid: String in product_ids:
		var app_id := int(pid)
		var owned: bool = _steam.isDLCInstalled(app_id)
		_owned_cache[pid] = owned
		results.append({
			"product_id": pid,
			"dlc_id": "",
			"title": "",
			"price": "",
			"description": "",
			"is_owned": owned,
		})
	products_loaded.emit(results)

func purchase(product_id: String) -> void:
	if not _steam:
		purchase_failed.emit(product_id, "Steam not available")
		return
	var app_id := int(product_id)
	if _steam.isDLCInstalled(app_id):
		purchase_completed.emit(product_id)
		return
	# Open Steam overlay to DLC store page
	if _steam.has_method("activateGameOverlayToStore"):
		_steam.activateGameOverlayToStore(app_id)
	else:
		purchase_failed.emit(product_id, "Steam overlay not available")

func restore_purchases() -> void:
	var owned: Array[String] = []
	for pid: String in _owned_cache:
		var app_id := int(pid)
		if _steam and _steam.isDLCInstalled(app_id):
			owned.append(pid)
			_owned_cache[pid] = true
	restore_completed.emit(owned)

func is_product_owned(product_id: String) -> bool:
	return _owned_cache.get(product_id, false)

func _on_dlc_installed(app_id: int) -> void:
	var pid := str(app_id)
	_owned_cache[pid] = true
	purchase_completed.emit(pid)