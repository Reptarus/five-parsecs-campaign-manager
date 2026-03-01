## DLCManager - Manages DLC ownership and per-feature content flags
## Autoloaded singleton. Do NOT add class_name (autoload provides global name).
##
## Three DLC packs:
##   Trailblazer's Toolkit  - Species, Psionics, New Kit
##   Freelancer's Handbook  - Difficulty, Combat Options, PvP/Co-op
##   Fixer's Guidebook      - Missions, Factions, World Systems
##
## ContentFlags are granular per-feature toggles saved per-campaign.
## DLC ownership is persistent across campaigns (user prefs).
extends Node

signal dlc_ownership_changed(dlc_id: String, owned: bool)
signal feature_flag_changed(flag: int, enabled: bool)


## ============================================================================
## DLC IDENTIFIERS
## ============================================================================

const DLC_IDS := {
	"trailblazers_toolkit": "Trailblazer's Toolkit",
	"freelancers_handbook": "Freelancer's Handbook",
	"fixers_guidebook": "Fixer's Guidebook",
	"bug_hunt": "Bug Hunt",  # Future, separate game mode
}


## ============================================================================
## CONTENT FLAGS (granular per-feature toggles)
## ============================================================================

enum ContentFlag {
	# Trailblazer's Toolkit
	SPECIES_KRAG,
	SPECIES_SKULKER,
	PSIONICS,
	NEW_TRAINING,
	BOT_UPGRADES,
	NEW_SHIP_PARTS,
	PSIONIC_EQUIPMENT,

	# Freelancer's Handbook
	PROGRESSIVE_DIFFICULTY,
	DIFFICULTY_TOGGLES,
	PVP_BATTLES,
	COOP_BATTLES,
	AI_VARIATIONS,
	DEPLOYMENT_VARIABLES,
	ESCALATING_BATTLES,
	ELITE_ENEMIES,
	EXPANDED_MISSIONS,
	EXPANDED_QUESTS,
	EXPANDED_CONNECTIONS,
	DRAMATIC_COMBAT,
	NO_MINIS_COMBAT,
	GRID_BASED_MOVEMENT,
	TERRAIN_GENERATION,
	CASUALTY_TABLES,
	DETAILED_INJURIES,

	# Fixer's Guidebook
	STEALTH_MISSIONS,
	STREET_FIGHTS,
	SALVAGE_JOBS,
	EXPANDED_FACTIONS,
	FRINGE_WORLD_STRIFE,
	EXPANDED_LOANS,
	NAME_GENERATION,
	INTRODUCTORY_CAMPAIGN,
	PRISON_PLANET_CHARACTER,
}


## Maps each DLC pack to its ContentFlags
const DLC_CONTENT_MAP: Dictionary = {
	"trailblazers_toolkit": [
		ContentFlag.SPECIES_KRAG,
		ContentFlag.SPECIES_SKULKER,
		ContentFlag.PSIONICS,
		ContentFlag.NEW_TRAINING,
		ContentFlag.BOT_UPGRADES,
		ContentFlag.NEW_SHIP_PARTS,
		ContentFlag.PSIONIC_EQUIPMENT,
	],
	"freelancers_handbook": [
		ContentFlag.PROGRESSIVE_DIFFICULTY,
		ContentFlag.DIFFICULTY_TOGGLES,
		ContentFlag.PVP_BATTLES,
		ContentFlag.COOP_BATTLES,
		ContentFlag.AI_VARIATIONS,
		ContentFlag.DEPLOYMENT_VARIABLES,
		ContentFlag.ESCALATING_BATTLES,
		ContentFlag.ELITE_ENEMIES,
		ContentFlag.EXPANDED_MISSIONS,
		ContentFlag.EXPANDED_QUESTS,
		ContentFlag.EXPANDED_CONNECTIONS,
		ContentFlag.DRAMATIC_COMBAT,
		ContentFlag.NO_MINIS_COMBAT,
		ContentFlag.GRID_BASED_MOVEMENT,
		ContentFlag.TERRAIN_GENERATION,
		ContentFlag.CASUALTY_TABLES,
		ContentFlag.DETAILED_INJURIES,
	],
	"fixers_guidebook": [
		ContentFlag.STEALTH_MISSIONS,
		ContentFlag.STREET_FIGHTS,
		ContentFlag.SALVAGE_JOBS,
		ContentFlag.EXPANDED_FACTIONS,
		ContentFlag.FRINGE_WORLD_STRIFE,
		ContentFlag.EXPANDED_LOANS,
		ContentFlag.NAME_GENERATION,
		ContentFlag.INTRODUCTORY_CAMPAIGN,
		ContentFlag.PRISON_PLANET_CHARACTER,
	],
}


## ============================================================================
## STATE
## ============================================================================

## Persistent DLC ownership (saved in user prefs, NOT per-campaign)
var _owned_dlcs: Dictionary = {}  # dlc_id -> bool

## Per-campaign feature toggles (saved with campaign data)
var _enabled_flags: Dictionary = {}  # ContentFlag int -> bool


## ============================================================================
## DLC OWNERSHIP
## ============================================================================

func has_dlc(dlc_id: String) -> bool:
	return _owned_dlcs.get(dlc_id, false)


func set_dlc_owned(dlc_id: String, owned: bool) -> void:
	_owned_dlcs[dlc_id] = owned
	dlc_ownership_changed.emit(dlc_id, owned)
	# If DLC was removed, disable all its features
	if not owned:
		for flag in get_features_for_dlc(dlc_id):
			set_feature_enabled(flag, false)


func get_owned_dlcs() -> Array[String]:
	var result: Array[String] = []
	for dlc_id in _owned_dlcs:
		if _owned_dlcs[dlc_id]:
			result.append(dlc_id)
	return result


## ============================================================================
## FEATURE FLAG MANAGEMENT
## ============================================================================

## Which DLC pack owns a given feature
func get_dlc_for_feature(flag: ContentFlag) -> String:
	for dlc_id in DLC_CONTENT_MAP:
		var flags: Array = DLC_CONTENT_MAP[dlc_id]
		if flag in flags:
			return dlc_id
	return ""


## Is the DLC owned for this feature? (ignores toggle state)
func is_feature_available(flag: ContentFlag) -> bool:
	var dlc_id := get_dlc_for_feature(flag)
	if dlc_id.is_empty():
		return false
	return has_dlc(dlc_id)


## Is the feature both available (DLC owned) AND toggled on?
func is_feature_enabled(flag: ContentFlag) -> bool:
	if not is_feature_available(flag):
		return false
	return _enabled_flags.get(flag, false)


## Toggle a feature on/off (only works if DLC is owned)
func set_feature_enabled(flag: ContentFlag, enabled: bool) -> void:
	if enabled and not is_feature_available(flag):
		push_warning("DLCManager: Cannot enable flag %d - DLC not owned" % flag)
		return
	_enabled_flags[flag] = enabled
	feature_flag_changed.emit(flag, enabled)


## Get all features whose DLC is owned (regardless of toggle state)
func get_available_features() -> Array:
	var result := []
	for dlc_id in DLC_CONTENT_MAP:
		if has_dlc(dlc_id):
			for flag in DLC_CONTENT_MAP[dlc_id]:
				result.append(flag)
	return result


## Get all features for a specific DLC pack
func get_features_for_dlc(dlc_id: String) -> Array:
	return DLC_CONTENT_MAP.get(dlc_id, [])


## ============================================================================
## SERIALIZATION (per-campaign save/load)
## ============================================================================

func serialize_campaign_flags() -> Dictionary:
	var data := {}
	for flag_int in _enabled_flags:
		data[str(flag_int)] = _enabled_flags[flag_int]
	return data


func deserialize_campaign_flags(data: Dictionary) -> void:
	_enabled_flags.clear()
	for key in data:
		var flag_int := int(key)
		# Validate the flag still exists (handles forward-compat)
		if flag_int >= 0 and flag_int < ContentFlag.size():
			var enabled: bool = data[key]
			# Only restore flags whose DLC is still owned
			if enabled and is_feature_available(flag_int as ContentFlag):
				_enabled_flags[flag_int] = true
			elif not enabled:
				_enabled_flags[flag_int] = false
		else:
			push_warning("DLCManager: Skipping unknown flag %d from save data" % flag_int)


func reset_campaign_flags() -> void:
	_enabled_flags.clear()


## ============================================================================
## USER PREFS (persistent DLC ownership across campaigns)
## ============================================================================

const PREFS_PATH := "user://dlc_ownership.cfg"


func save_ownership() -> void:
	var config := ConfigFile.new()
	for dlc_id in _owned_dlcs:
		config.set_value("dlc", dlc_id, _owned_dlcs[dlc_id])
	config.save(PREFS_PATH)


func load_ownership() -> void:
	var config := ConfigFile.new()
	var err := config.load(PREFS_PATH)
	if err != OK:
		return  # No prefs file yet, all DLCs unowned
	for dlc_id in DLC_IDS:
		_owned_dlcs[dlc_id] = config.get_value("dlc", dlc_id, false)


## Null-safe check: is a feature flag enabled?
## Use from any context. Returns false if DLC system unavailable.
## For Resource-based code that can't access scene tree, use:
##   var dlc = Engine.get_main_loop().root.get_node_or_null(
##       "/root/DLCManager"
##   ) if Engine.get_main_loop() else null
##   if dlc and dlc.is_feature_enabled(dlc.ContentFlag.X): ...
func check_flag(flag: ContentFlag) -> bool:
	return is_feature_enabled(flag)

## Static helper for scripts without scene tree access.
## Usage: DLCManagerScript.is_flag_enabled_safe(flag)
## where DLCManagerScript = preload("res://src/core/systems/DLCManager.gd")
static func is_flag_enabled_safe(flag: int) -> bool:
	var ml = Engine.get_main_loop()
	if not ml:
		return false
	var root = ml.root
	if not root:
		return false
	var dlc = root.get_node_or_null("/root/DLCManager")
	if not dlc:
		return false
	if not dlc.has_method("is_feature_enabled"):
		return false
	return dlc.is_feature_enabled(flag)

func _ready() -> void:
	load_ownership()
