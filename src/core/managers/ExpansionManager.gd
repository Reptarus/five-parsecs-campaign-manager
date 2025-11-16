extends Node

## ExpansionManager
## Central system for managing DLC content and expansion integrations
## Autoload singleton: Access via ExpansionManager.method_name()

# DLC identifiers
const DLC_TRAILBLAZERS_TOOLKIT := "trailblazers_toolkit"
const DLC_FREELANCERS_HANDBOOK := "freelancers_handbook"
const DLC_FIXERS_GUIDEBOOK := "fixers_guidebook"
const DLC_BUG_HUNT := "bug_hunt"
const DLC_COMPLETE_COMPENDIUM := "complete_compendium"

# Expansion metadata registry
var registered_expansions: Dictionary = {}

# Content cache to avoid repeated file I/O
var content_cache: Dictionary = {}

# Signal emitted when DLC ownership changes
signal dlc_ownership_changed(dlc_id: String, is_owned: bool)

# Signal emitted when expansion content is loaded
signal expansion_content_loaded(dlc_id: String, content_type: String)


func _ready() -> void:
	_register_all_expansions()
	_connect_dlc_signals()
	print("[ExpansionManager] Initialized with %d expansions" % registered_expansions.size())


## Register all available expansions with their metadata
func _register_all_expansions() -> void:
	# Trailblazer's Toolkit - Character & Powers Expansion
	register_expansion(DLC_TRAILBLAZERS_TOOLKIT, {
		"name": "Trailblazer's Toolkit",
		"display_name": "Trailblazer's Toolkit",
		"data_path": "res://data/dlc/trailblazers_toolkit/",
		"description": "New species (Krag, Skulker), complete psionics system, bot upgrades, and advanced training",
		"version": "1.0.0",
		"systems": ["PsionicSystem", "ExpandedSpeciesSystem"],
		"content_types": ["species", "psionic_powers", "equipment", "world_traits", "bot_upgrades"],
		"price_usd": 4.99,
		"standalone": false,
		"dependencies": []
	})

	# Freelancer's Handbook - Combat & Challenge Expansion
	register_expansion(DLC_FREELANCERS_HANDBOOK, {
		"name": "Freelancer's Handbook",
		"display_name": "Freelancer's Handbook",
		"data_path": "res://data/dlc/freelancers_handbook/",
		"description": "Elite enemies, difficulty scaling, progressive AI, and alternative combat modes",
		"version": "1.0.0",
		"systems": ["EliteEnemySystem", "DifficultyScalingSystem", "AdvancedCombatSystem"],
		"content_types": ["elite_enemies", "difficulty_modifiers", "ai_behaviors", "combat_modes"],
		"price_usd": 6.99,
		"standalone": false,
		"dependencies": []
	})

	# Fixer's Guidebook - Mission & Campaign Expansion
	register_expansion(DLC_FIXERS_GUIDEBOOK, {
		"name": "Fixer's Guidebook",
		"display_name": "Fixer's Guidebook",
		"data_path": "res://data/dlc/fixers_guidebook/",
		"description": "Stealth missions, salvage jobs, street fights, loans system, and world strife",
		"version": "1.0.0",
		"systems": ["StealthMissionSystem", "SalvageJobSystem", "LoanManager", "FringeWorldStrifeSystem"],
		"content_types": ["mission_templates", "world_events", "faction_rules", "equipment"],
		"price_usd": 6.99,
		"standalone": false,
		"dependencies": []
	})

	# Bug Hunt - Standalone Campaign Variant
	register_expansion(DLC_BUG_HUNT, {
		"name": "Bug Hunt",
		"display_name": "Bug Hunt",
		"data_path": "res://data/dlc/bug_hunt/",
		"description": "Standalone military campaign mode with bug enemies, panic system, and character transfer",
		"version": "1.0.0",
		"systems": ["BugHuntCampaignSystem", "PanicSystem", "MotionTrackerSystem", "InfestationSystem", "MilitaryHierarchySystem", "CharacterTransferSystem"],
		"content_types": ["bug_enemies", "military_equipment", "campaign_mode", "missions"],
		"price_usd": 9.99,
		"standalone": true,
		"dependencies": []
	})

	# Complete Compendium Bundle
	register_expansion(DLC_COMPLETE_COMPENDIUM, {
		"name": "Complete Compendium",
		"display_name": "Complete Compendium Bundle",
		"data_path": "",
		"description": "All DLC content in one bundle with exclusive bonuses",
		"version": "1.0.0",
		"systems": [],
		"content_types": [],
		"price_usd": 19.99,
		"standalone": false,
		"dependencies": [DLC_TRAILBLAZERS_TOOLKIT, DLC_FREELANCERS_HANDBOOK, DLC_FIXERS_GUIDEBOOK, DLC_BUG_HUNT],
		"is_bundle": true,
		"bundle_bonuses": {
			"starting_credits": 500,
			"story_points": 2,
			"unique_background": "Veteran Adventurer"
		}
	})


## Register a single expansion
func register_expansion(dlc_id: String, config: Dictionary) -> void:
	if registered_expansions.has(dlc_id):
		push_warning("[ExpansionManager] Expansion '%s' already registered, overwriting" % dlc_id)

	registered_expansions[dlc_id] = config
	print("[ExpansionManager] Registered expansion: %s" % config.get("display_name", dlc_id))


## Connect to DLCManager signals
func _connect_dlc_signals() -> void:
	if DLCManager.has_signal("dlc_ownership_changed"):
		DLCManager.dlc_ownership_changed.connect(_on_dlc_ownership_changed)


## Handle DLC ownership changes
func _on_dlc_ownership_changed(dlc_id: String, is_owned: bool) -> void:
	print("[ExpansionManager] DLC ownership changed: %s = %s" % [dlc_id, is_owned])

	# Clear cache for this DLC
	_clear_dlc_cache(dlc_id)

	# Emit our own signal for other systems to react
	dlc_ownership_changed.emit(dlc_id, is_owned)


## Clear cached content for a specific DLC
func _clear_dlc_cache(dlc_id: String) -> void:
	var keys_to_remove := []
	for cache_key in content_cache.keys():
		if cache_key.begins_with(dlc_id + ":"):
			keys_to_remove.append(cache_key)

	for key in keys_to_remove:
		content_cache.erase(key)

	if keys_to_remove.size() > 0:
		print("[ExpansionManager] Cleared %d cached entries for %s" % [keys_to_remove.size(), dlc_id])


## Check if an expansion is available (owned and enabled)
func is_expansion_available(dlc_id: String) -> bool:
	# Development override - unlock all in editor
	if OS.has_feature("editor") and ProjectSettings.get_setting("dlc/unlock_all_in_editor", true):
		return true

	# Check if it's a bundle
	if registered_expansions.has(dlc_id):
		var expansion := registered_expansions[dlc_id]
		if expansion.get("is_bundle", false):
			# Bundle is available if we own the bundle itself
			return DLCManager.is_dlc_owned(dlc_id)

	# Check if owned via bundle
	if is_dlc_included_in_owned_bundle(dlc_id):
		return true

	# Check individual ownership
	return DLCManager.is_dlc_owned(dlc_id)


## Check if a DLC is included in any owned bundle
func is_dlc_included_in_owned_bundle(dlc_id: String) -> bool:
	for bundle_id in registered_expansions.keys():
		var expansion := registered_expansions[bundle_id]
		if not expansion.get("is_bundle", false):
			continue

		if DLCManager.is_dlc_owned(bundle_id):
			var dependencies: Array = expansion.get("dependencies", [])
			if dlc_id in dependencies:
				return true

	return false


## Get expansion data path
func get_expansion_data_path(dlc_id: String) -> String:
	if not registered_expansions.has(dlc_id):
		push_error("[ExpansionManager] Unknown expansion: %s" % dlc_id)
		return ""

	return registered_expansions[dlc_id].get("data_path", "")


## Get expansion metadata
func get_expansion_info(dlc_id: String) -> Dictionary:
	return registered_expansions.get(dlc_id, {})


## Load expansion data from JSON file
func load_expansion_data(dlc_id: String, file_name: String) -> Variant:
	if not is_expansion_available(dlc_id):
		return null

	# Check cache first
	var cache_key := "%s:%s" % [dlc_id, file_name]
	if content_cache.has(cache_key):
		return content_cache[cache_key]

	var data_path := get_expansion_data_path(dlc_id)
	if data_path.is_empty():
		return null

	var full_path := data_path.path_join(file_name)
	var data = DataManager.load_json(full_path)

	if data != null:
		# Cache the loaded data
		content_cache[cache_key] = data
		expansion_content_loaded.emit(dlc_id, file_name)
		print("[ExpansionManager] Loaded %s from %s" % [file_name, dlc_id])

	return data


## Get all available content of a specific type (core + owned DLC)
func get_available_content(content_type: String) -> Array:
	var content := []

	# Always include core content first
	content.append_array(_load_core_content(content_type))

	# Add DLC content if owned
	for dlc_id in registered_expansions.keys():
		if not is_expansion_available(dlc_id):
			continue

		var expansion := registered_expansions[dlc_id]
		var content_types: Array = expansion.get("content_types", [])

		if content_type in content_types:
			var dlc_content := _load_dlc_content(dlc_id, content_type)
			content.append_array(dlc_content)

	return content


## Load core content (base game)
func _load_core_content(content_type: String) -> Array:
	match content_type:
		"species":
			return _load_core_species()
		"equipment":
			return _load_core_equipment()
		"enemies":
			return _load_core_enemies()
		"missions":
			return _load_core_missions()
		"backgrounds":
			return _load_core_backgrounds()
		"motivations":
			return _load_core_motivations()
		"classes":
			return _load_core_classes()
		_:
			push_warning("[ExpansionManager] Unknown core content type: %s" % content_type)
			return []


## Load DLC content
func _load_dlc_content(dlc_id: String, content_type: String) -> Array:
	match dlc_id:
		DLC_TRAILBLAZERS_TOOLKIT:
			return _load_trailblazers_toolkit_content(content_type)
		DLC_FREELANCERS_HANDBOOK:
			return _load_freelancers_handbook_content(content_type)
		DLC_FIXERS_GUIDEBOOK:
			return _load_fixers_guidebook_content(content_type)
		DLC_BUG_HUNT:
			return _load_bug_hunt_content(content_type)
		_:
			return []


## Load Trailblazer's Toolkit content
func _load_trailblazers_toolkit_content(content_type: String) -> Array:
	var base_path := get_expansion_data_path(DLC_TRAILBLAZERS_TOOLKIT)

	match content_type:
		"species":
			var data = load_expansion_data(DLC_TRAILBLAZERS_TOOLKIT, "trailblazers_toolkit_species.json")
			return data.get("species", []) if data else []

		"psionic_powers":
			var data = load_expansion_data(DLC_TRAILBLAZERS_TOOLKIT, "trailblazers_toolkit_psionic_powers.json")
			return data.get("psionic_powers", []) if data else []

		"equipment":
			var data = load_expansion_data(DLC_TRAILBLAZERS_TOOLKIT, "trailblazers_toolkit_psionic_equipment.json")
			return data.get("equipment", []) if data else []

		"bot_upgrades":
			var data = load_expansion_data(DLC_TRAILBLAZERS_TOOLKIT, "trailblazers_toolkit_bot_upgrades.json")
			return data.get("upgrades", []) if data else []

		"world_traits":
			var data = load_expansion_data(DLC_TRAILBLAZERS_TOOLKIT, "trailblazers_toolkit_world_traits.json")
			return data.get("traits", []) if data else []

		_:
			return []


## Load Freelancer's Handbook content
func _load_freelancers_handbook_content(content_type: String) -> Array:
	match content_type:
		"elite_enemies":
			var data = load_expansion_data(DLC_FREELANCERS_HANDBOOK, "freelancers_handbook_elite_enemies.json")
			return data.get("elite_enemies", []) if data else []

		"difficulty_modifiers":
			var data = load_expansion_data(DLC_FREELANCERS_HANDBOOK, "freelancers_handbook_difficulty_modifiers.json")
			return data.get("difficulty_modifiers", []) if data else []

		"enemies":
			# Include elite enemies when requesting all enemies
			return _load_freelancers_handbook_content("elite_enemies")

		_:
			return []


## Load Fixer's Guidebook content
func _load_fixers_guidebook_content(content_type: String) -> Array:
	match content_type:
		"missions", "mission_templates":
			var missions := []

			# Load all mission types from combined file
			var missions_data = load_expansion_data(DLC_FIXERS_GUIDEBOOK, "fixers_guidebook_missions.json")
			if missions_data:
				missions.append_array(missions_data.get("stealth_missions", []))
				missions.append_array(missions_data.get("salvage_jobs", []))
				missions.append_array(missions_data.get("street_fights", []))
				missions.append_array(missions_data.get("expanded_opportunities", []))

			return missions

		"equipment":
			var data = load_expansion_data(DLC_FIXERS_GUIDEBOOK, "fixers_guidebook_equipment.json")
			return data.get("equipment", []) if data else []

		_:
			return []


## Load Bug Hunt content
func _load_bug_hunt_content(content_type: String) -> Array:
	match content_type:
		"enemies", "bug_enemies":
			var data = load_expansion_data(DLC_BUG_HUNT, "bug_enemies.json")
			return data.get("bug_enemies", []) if data else []

		"equipment":
			var data = load_expansion_data(DLC_BUG_HUNT, "military_equipment.json")
			return data.get("equipment", []) if data else []

		"missions":
			var data = load_expansion_data(DLC_BUG_HUNT, "bug_hunt_missions.json")
			return data.get("missions", []) if data else []

		_:
			return []


## Core content loaders (stub implementations - to be filled with actual data loading)
func _load_core_species() -> Array:
	# Load from core_rules/core_species.json
	var data = DataManager.load_json("res://data/core_rules/core_species.json")
	return data.get("species", []) if data else []


func _load_core_equipment() -> Array:
	var data = DataManager.load_json("res://data/core_rules/core_equipment.json")
	return data.get("equipment", []) if data else []


func _load_core_enemies() -> Array:
	var data = DataManager.load_json("res://data/core_rules/core_enemies.json")
	return data.get("enemies", []) if data else []


func _load_core_missions() -> Array:
	var data = DataManager.load_json("res://data/core_rules/core_missions.json")
	return data.get("missions", []) if data else []


func _load_core_backgrounds() -> Array:
	var data = DataManager.load_json("res://data/core_rules/character_backgrounds.json")
	return data.get("backgrounds", []) if data else []


func _load_core_motivations() -> Array:
	var data = DataManager.load_json("res://data/core_rules/character_motivations.json")
	return data.get("motivations", []) if data else []


func _load_core_classes() -> Array:
	var data = DataManager.load_json("res://data/core_rules/character_classes.json")
	return data.get("classes", []) if data else []


## Get list of all registered expansion IDs
func get_all_expansion_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(registered_expansions.keys())
	return ids


## Get list of owned expansion IDs
func get_owned_expansion_ids() -> Array[String]:
	var owned: Array[String] = []
	for dlc_id in registered_expansions.keys():
		if is_expansion_available(dlc_id):
			owned.append(dlc_id)
	return owned


## Get list of available (but not owned) expansions for store
func get_available_for_purchase() -> Array[Dictionary]:
	var available := []

	for dlc_id in registered_expansions.keys():
		if not DLCManager.is_dlc_owned(dlc_id):
			var expansion := registered_expansions[dlc_id].duplicate()
			expansion["id"] = dlc_id
			expansion["owned"] = false
			available.append(expansion)

	return available


## Check if any content requires a specific DLC
func content_requires_dlc(content_item: Dictionary) -> String:
	return content_item.get("dlc_required", "")


## Filter content array by DLC ownership
func filter_owned_content(content_array: Array) -> Array:
	var filtered := []

	for item in content_array:
		if item is Dictionary:
			var required_dlc := content_requires_dlc(item)

			# Include if no DLC required (core content)
			if required_dlc.is_empty():
				filtered.append(item)
				continue

			# Include if DLC is owned
			if is_expansion_available(required_dlc):
				filtered.append(item)

	return filtered


## Get DLC status summary for debugging
func get_dlc_status_summary() -> Dictionary:
	var summary := {
		"registered_count": registered_expansions.size(),
		"owned_count": 0,
		"cache_size": content_cache.size(),
		"expansions": []
	}

	for dlc_id in registered_expansions.keys():
		var owned := is_expansion_available(dlc_id)
		if owned:
			summary.owned_count += 1

		summary.expansions.append({
			"id": dlc_id,
			"name": registered_expansions[dlc_id].get("display_name", dlc_id),
			"owned": owned,
			"is_bundle": registered_expansions[dlc_id].get("is_bundle", false)
		})

	return summary


## Clear all cached content
func clear_all_cache() -> void:
	var count := content_cache.size()
	content_cache.clear()
	print("[ExpansionManager] Cleared %d cached entries" % count)


## Reload all expansion data
func reload_expansions() -> void:
	clear_all_cache()
	_register_all_expansions()
	print("[ExpansionManager] Reloaded all expansions")
