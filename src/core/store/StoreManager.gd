extends Node

## StoreManager - Orchestrates platform-specific store operations.
## Autoloaded singleton. Do NOT add class_name (autoload provides global name).
##
## Bridges platform store adapters to DLCManager for DLC ownership.
## On purchase_completed -> DLCManager.set_dlc_owned() + save_ownership().
## On startup -> syncs store entitlements with DLCManager.

signal purchase_started(dlc_id: String)
signal purchase_completed(dlc_id: String)
signal purchase_failed(dlc_id: String, reason: String)
signal purchase_cancelled(dlc_id: String)
signal products_loaded(products: Array[Dictionary])
signal restore_started()
signal restore_completed(owned_dlc_ids: Array[String])
signal store_ready()
signal store_error(message: String)

## Adapter scripts loaded at runtime (not preload) because autoloads parse
## before the import system processes new files. load() defers resolution.

## Product ID mapping: DLC ID -> { steam, android, ios }
## Replace placeholder IDs with real store product IDs before release.
const PRODUCT_IDS: Dictionary = {
	"trailblazers_toolkit": {
		"steam": "STEAM_DLC_APP_ID_1",
		"android": "com.reptarus.fiveparsecs.dlc.trailblazers_toolkit",
		"ios": "com.reptarus.fiveparsecs.dlc.trailblazers_toolkit",
	},
	"freelancers_handbook": {
		"steam": "STEAM_DLC_APP_ID_2",
		"android": "com.reptarus.fiveparsecs.dlc.freelancers_handbook",
		"ios": "com.reptarus.fiveparsecs.dlc.freelancers_handbook",
	},
	"fixers_guidebook": {
		"steam": "STEAM_DLC_APP_ID_3",
		"android": "com.reptarus.fiveparsecs.dlc.fixers_guidebook",
		"ios": "com.reptarus.fiveparsecs.dlc.fixers_guidebook",
	},
}

## Display metadata for DLC packs (prices are placeholder; real prices come from store)
const DLC_METADATA: Dictionary = {
	"trailblazers_toolkit": {
		"name": "Trailblazer's Toolkit",
		"description": "New species (Krag, Skulker), Psionics system, advanced training, bot upgrades, ship parts, psionic equipment.",
		"default_price": "$4.99",
		"feature_count": 7,
	},
	"freelancers_handbook": {
		"name": "Freelancer's Handbook",
		"description": "Progressive difficulty, combat options, PvP/Co-op battles, AI variations, elite enemies, expanded missions, no-minis combat, grid movement.",
		"default_price": "$7.99",
		"feature_count": 17,
	},
	"fixers_guidebook": {
		"name": "Fixer's Guidebook",
		"description": "Stealth missions, street fights, salvage jobs, expanded factions, world strife, loans, name generation, introductory campaign.",
		"default_price": "$4.99",
		"feature_count": 9,
	},
}

var _adapter: RefCounted = null  # StoreAdapter (use RefCounted to avoid class_name resolution issues)
var _dlc_mgr: Node = null
var _platform: String = ""
var _is_ready: bool = false
var _product_cache: Dictionary = {}  # dlc_id -> product info dict
var _purchase_in_progress: bool = false
var _pending_dlc_id: String = ""

func _ready() -> void:
	_dlc_mgr = get_node_or_null("/root/DLCManager")
	_platform = _detect_platform()
	_adapter = _create_adapter()
	_connect_adapter_signals()
	_adapter.initialize()
	# Query products after short delay (let store connection establish)
	get_tree().create_timer(0.5).timeout.connect(_initial_product_query)

func _detect_platform() -> String:
	var os_name := OS.get_name()
	match os_name:
		"Android":
			if Engine.has_singleton("AndroidIAPP"):
				return "android"
			return "offline"
		"iOS":
			if ClassDB.class_exists(&"StoreKitManager"):
				return "ios"
			return "offline"
		"Windows", "Linux", "macOS":
			if Engine.has_singleton("Steam"):
				return "steam"
			# macOS also supports StoreKit via GodotApplePlugins
			if os_name == "macOS" and ClassDB.class_exists(&"StoreKitManager"):
				return "ios"
			return "offline"
		_:
			return "offline"

func _create_adapter() -> RefCounted:
	var script: GDScript = null
	match _platform:
		"steam":
			script = load("res://src/core/store/SteamStoreAdapter.gd") as GDScript
		"android":
			script = load("res://src/core/store/AndroidStoreAdapter.gd") as GDScript
		"ios":
			script = load("res://src/core/store/IOSStoreAdapter.gd") as GDScript
		_:
			script = load("res://src/core/store/OfflineStoreAdapter.gd") as GDScript
	if script:
		return script.new() as RefCounted
	# Final fallback: create offline adapter directly
	push_warning("StoreManager: Failed to load adapter script, using inline fallback")
	script = load("res://src/core/store/OfflineStoreAdapter.gd") as GDScript
	return script.new() as RefCounted if script else null

func _connect_adapter_signals() -> void:
	_adapter.purchase_completed.connect(_on_adapter_purchase_completed)
	_adapter.purchase_failed.connect(_on_adapter_purchase_failed)
	_adapter.purchase_cancelled.connect(_on_adapter_purchase_cancelled)
	_adapter.products_loaded.connect(_on_adapter_products_loaded)
	_adapter.restore_completed.connect(_on_adapter_restore_completed)
	_adapter.store_error.connect(_on_adapter_store_error)

func _initial_product_query() -> void:
	var platform_ids: Array[String] = []
	for dlc_id: String in PRODUCT_IDS:
		var pid: String = PRODUCT_IDS[dlc_id].get(_platform, "")
		if not pid.is_empty():
			platform_ids.append(pid)
	if not platform_ids.is_empty():
		_adapter.query_products(platform_ids)
	else:
		_is_ready = true
		store_ready.emit()

# ── Public API ──────────────────────────────────────────────────────

func get_platform_name() -> String:
	return _adapter.get_platform_name() if _adapter else "unknown"

func is_store_available() -> bool:
	return _adapter != null and _adapter.is_available()

func is_offline_mode() -> bool:
	return _platform == "offline"

func is_ready() -> bool:
	return _is_ready

func is_purchase_in_progress() -> bool:
	return _purchase_in_progress

func get_dlc_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in PRODUCT_IDS:
		ids.append(key)
	return ids

func get_dlc_price(dlc_id: String) -> String:
	var cached: Dictionary = _product_cache.get(dlc_id, {})
	if cached.has("price") and not str(cached.get("price", "")).is_empty():
		return str(cached.get("price", ""))
	return str(DLC_METADATA.get(dlc_id, {}).get("default_price", ""))

func get_dlc_info(dlc_id: String) -> Dictionary:
	## Returns merged metadata + store data for a DLC pack.
	var info: Dictionary = DLC_METADATA.get(dlc_id, {}).duplicate()
	var cached: Dictionary = _product_cache.get(dlc_id, {})
	if not cached.is_empty():
		info.merge(cached, true)
	info["dlc_id"] = dlc_id
	info["is_owned"] = _dlc_mgr.has_dlc(dlc_id) if _dlc_mgr else false
	return info

func purchase_dlc(dlc_id: String) -> void:
	## Initiate purchase for a DLC pack.
	if _purchase_in_progress:
		store_error.emit("A purchase is already in progress")
		return
	if not _adapter or not _adapter.is_available():
		purchase_failed.emit(dlc_id, "Store not available")
		return
	if _dlc_mgr and _dlc_mgr.has_dlc(dlc_id):
		purchase_failed.emit(dlc_id, "Already owned")
		return
	var pid: String = _get_platform_product_id(dlc_id)
	if pid.is_empty():
		purchase_failed.emit(dlc_id, "No product ID for platform: %s" % _platform)
		return
	_purchase_in_progress = true
	_pending_dlc_id = dlc_id
	purchase_started.emit(dlc_id)
	_adapter.purchase(pid)

func restore_all_purchases() -> void:
	if not _adapter:
		store_error.emit("No store adapter")
		return
	restore_started.emit()
	_adapter.restore_purchases()

func refresh_products() -> void:
	_initial_product_query()

# ── Internal helpers ────────────────────────────────────────────────

func _get_platform_product_id(dlc_id: String) -> String:
	var ids: Dictionary = PRODUCT_IDS.get(dlc_id, {})
	return str(ids.get(_platform, ""))

func _get_dlc_id_from_product_id(product_id: String) -> String:
	for dlc_id: String in PRODUCT_IDS:
		var ids: Dictionary = PRODUCT_IDS[dlc_id]
		for platform_key: String in ids:
			if str(ids[platform_key]) == product_id:
				return dlc_id
	return ""

# ── Adapter signal handlers ─────────────────────────────────────────

func _on_adapter_purchase_completed(product_id: String) -> void:
	_purchase_in_progress = false
	var dlc_id := _get_dlc_id_from_product_id(product_id)
	if dlc_id.is_empty():
		dlc_id = _pending_dlc_id
	_pending_dlc_id = ""
	if dlc_id.is_empty():
		push_warning("StoreManager: Unknown product_id: %s" % product_id)
		return
	if _dlc_mgr:
		_dlc_mgr.set_dlc_owned(dlc_id, true)
		_dlc_mgr.save_ownership()
	purchase_completed.emit(dlc_id)

func _on_adapter_purchase_failed(product_id: String, reason: String) -> void:
	_purchase_in_progress = false
	var dlc_id := _get_dlc_id_from_product_id(product_id)
	if dlc_id.is_empty():
		dlc_id = _pending_dlc_id
	_pending_dlc_id = ""
	purchase_failed.emit(dlc_id if not dlc_id.is_empty() else product_id, reason)

func _on_adapter_purchase_cancelled(product_id: String) -> void:
	_purchase_in_progress = false
	var dlc_id := _get_dlc_id_from_product_id(product_id)
	if dlc_id.is_empty():
		dlc_id = _pending_dlc_id
	_pending_dlc_id = ""
	purchase_cancelled.emit(dlc_id if not dlc_id.is_empty() else product_id)

func _on_adapter_products_loaded(products: Array[Dictionary]) -> void:
	for p: Dictionary in products:
		var dlc_id := _get_dlc_id_from_product_id(str(p.get("product_id", "")))
		if not dlc_id.is_empty():
			p["dlc_id"] = dlc_id
			_product_cache[dlc_id] = p
	_is_ready = true
	products_loaded.emit(products)
	store_ready.emit()
	_sync_store_entitlements()

func _on_adapter_restore_completed(owned_ids: Array[String]) -> void:
	var dlc_ids: Array[String] = []
	for pid: String in owned_ids:
		var dlc_id := _get_dlc_id_from_product_id(pid)
		if not dlc_id.is_empty():
			dlc_ids.append(dlc_id)
			if _dlc_mgr:
				_dlc_mgr.set_dlc_owned(dlc_id, true)
	if _dlc_mgr:
		_dlc_mgr.save_ownership()
	restore_completed.emit(dlc_ids)

func _on_adapter_store_error(message: String) -> void:
	store_error.emit(message)
	push_warning("StoreManager: %s" % message)

func _sync_store_entitlements() -> void:
	## On startup, if store reports ownership, ensure DLCManager agrees.
	if not _dlc_mgr:
		return
	for dlc_id: String in PRODUCT_IDS:
		var pid := _get_platform_product_id(dlc_id)
		if not pid.is_empty() and _adapter.is_product_owned(pid):
			if not _dlc_mgr.has_dlc(dlc_id):
				_dlc_mgr.set_dlc_owned(dlc_id, true)
	_dlc_mgr.save_ownership()