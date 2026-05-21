## ModeInfoCatalog - per-mode marketing data for MainMenu.
##
## Data lives in `data/mode_info.json` (verbatim rulebook copy). This module
## exposes typed accessors and a one-line DLC ownership check via the
## /root/DLCManager autoload. Mirrors the DLCContentCatalog pattern.
##
## Stateless RefCounted. JSON cached after first load. No autoload, no
## class_name - keeps load order clean for MainMenu preload.
extends RefCounted

const DATA_PATH := "res://data/mode_info.json"

static var _cache: Dictionary = {}


static func _load() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not f:
		push_warning("ModeInfoCatalog: missing %s" % DATA_PATH)
		_cache = {"modes": {}}
		return _cache
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("ModeInfoCatalog: parse failed for %s" % DATA_PATH)
		_cache = {"modes": {}}
		return _cache
	_cache = parsed
	return _cache


## All mode entries as a dictionary keyed by mode id.
static func get_all() -> Dictionary:
	return _load().get("modes", {})


## Single mode entry. Returns empty dict if id unknown.
static func get_mode(mode_id: String) -> Dictionary:
	return get_all().get(mode_id, {})


## Mode ids in stable order matching JSON.
static func mode_ids() -> Array:
	return get_all().keys()


## Does this mode require a DLC pack? Returns "" if free.
static func get_required_dlc(mode_id: String) -> String:
	var m := get_mode(mode_id)
	var dlc = m.get("required_dlc", null)
	return dlc if dlc != null else ""


## Is this mode unlocked? Free modes are always unlocked; paid modes consult
## the DLCManager autoload. If the autoload is missing (e.g. tests, headless
## tooling) we conservatively treat paid modes as locked.
static func is_unlocked(mode_id: String) -> bool:
	var dlc_id := get_required_dlc(mode_id)
	if dlc_id.is_empty():
		return true
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr or not dlc_mgr.has_method("has_dlc"):
		return false
	return dlc_mgr.has_dlc(dlc_id)


## CTA label appropriate for the unlock state.
static func get_cta_label(mode_id: String) -> String:
	var m := get_mode(mode_id)
	if is_unlocked(mode_id):
		return m.get("cta_label_owned", "Play")
	return m.get("cta_label_locked", "Unlock")
