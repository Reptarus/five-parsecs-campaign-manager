@tool
extends Node

## Production-Grade Data Management System for Five Parsecs
## Hybrid architecture combining type-safe enums with rich JSON content
## Provides caching, validation, and hot-reloading capabilities

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Cached data structures for performance
static var _character_data: Dictionary = {}
static var _background_data: Dictionary = {}
static var _equipment_data: Dictionary = {}
static var _mission_data: Dictionary = {}
static var _crew_task_data: Dictionary = {}
static var _is_data_loaded: bool = false

# Performance monitoring
static var _load_time_ms: int = 0
static var _cache_hits: int = 0
static var _cache_misses: int = 0

## Data Loading Strategy - Production Optimized
static func initialize_data_system() -> bool:
	## Initialize the complete data management system with performance monitoring
	var start_time = Time.get_ticks_msec()
	print("DataManager: Initializing hybrid data system...")
	
	var success = true
	success = success and _load_character_system()
	success = success and _load_equipment_system()
	success = success and _load_mission_system()
	success = success and _load_crew_task_system()
	success = success and _validate_data_integrity()
	
	_load_time_ms = Time.get_ticks_msec() - start_time
	_is_data_loaded = success
	
	print("DataManager: System initialization %s in %d ms" % ["completed" if success else "failed", _load_time_ms])
	return success

## Character System Data Loading
static func _load_character_system() -> bool:
	## Load all character-related data with validation
	# Load character creation data (your rich JSON)
	_character_data = _load_json_safe("res://data/character_creation_data.json", "Character Creation")
	if _character_data.is_empty():
		push_error("DataManager: Failed to load character creation data")
		return false
	
	# Load background data (more detailed definitions)  
	_background_data = _load_json_safe("res://data/character_backgrounds.json", "Character Backgrounds")
	if _background_data.is_empty():
		push_error("DataManager: Failed to load background data")
		return false
	
	# Validate data consistency
	return _validate_character_data()

static func _load_equipment_system() -> bool:
	## Load equipment and gear databases
	_equipment_data["weapons"] = _load_json_safe("res://data/weapons.json", "Weapons Database")
	_equipment_data["armor"] = _load_json_safe("res://data/armor.json", "Armor Database")
	_equipment_data["gear"] = _load_json_safe("res://data/gear_database.json", "Gear Database")
	
	if _equipment_data.size() == 0:
		push_error("DataManager: Failed to load equipment system data")
		return false
	
	return true

static func _load_mission_system() -> bool:
	## Load mission templates and campaign data
	_mission_data["templates"] = _load_json_safe("res://data/mission_templates.json", "Mission Templates")
	_mission_data["events"] = _load_json_safe("res://data/event_tables.json", "Event Tables")
	
	if _mission_data.size() == 0:
		push_error("DataManager: Failed to load mission system data")
		return false
	
	return true

static func _load_crew_task_system() -> bool:
	## Load Five Parsecs crew task tables and resolution data
	_crew_task_data["main"] = _load_json_safe("res://data/campaign_tables/crew_tasks/crew_task_resolution.json", "Crew Task Resolution")
	_crew_task_data["trade"] = _load_json_safe("res://data/campaign_tables/crew_tasks/trade_results.json", "Trade Results")
	_crew_task_data["exploration"] = _load_json_safe("res://data/campaign_tables/crew_tasks/exploration_events.json", "Exploration Events")
	_crew_task_data["recruitment"] = _load_json_safe("res://data/campaign_tables/crew_tasks/recruitment_opportunities.json", "Recruitment Opportunities")
	_crew_task_data["training"] = _load_json_safe("res://data/campaign_tables/crew_tasks/training_outcomes.json", "Training Outcomes")
	
	if _crew_task_data.size() == 0:
		push_error("DataManager: Failed to load crew task system data")
		return false
	
	return true

## Safe JSON Loading with Validation
static func _load_json_safe(file_path: String, context: String) -> Dictionary:
	## Production-grade JSON loading with comprehensive error handling
	if not FileAccess.file_exists(file_path):
		push_error("DataManager: File not found: %s (%s)" % [file_path, context])
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("DataManager: Cannot open file: %s (%s)" % [file_path, context])
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	if json_text.is_empty():
		push_error("DataManager: Empty file: %s (%s)" % [file_path, context])
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("DataManager: JSON parse error in %s (%s): %s" % [file_path, context, json.get_error_message()])
		return {}
	
	var data = json.get_data()
	if not data is Dictionary:
		push_error("DataManager: Invalid JSON structure in %s (%s)" % [file_path, context])
		return {}
	
	print("DataManager: Loaded %s successfully (%d entries)" % [context, data.size()])
	return data

## Data Validation System
static func _validate_data_integrity() -> bool:
	## Validate data consistency and cross-references
	var validation_errors = []
	
	# Validate character data structure
	if "origins" not in _character_data:
		validation_errors.append("Missing 'origins' in character data")
	
	if "backgrounds" not in _character_data:
		validation_errors.append("Missing 'backgrounds' in character data")
	
	# Validate background data structure
	if "backgrounds" not in _background_data:
		validation_errors.append("Missing 'backgrounds' array in background data")
	
	# Cross-reference validation
	if not _validate_background_references():
		validation_errors.append("Background references are inconsistent")
	
	if validation_errors.size() > 0:
		push_error("DataManager: Data validation failed:")
		for error in validation_errors:
			push_error("  - %s" % error)
		return false
	
	print("DataManager: Data validation passed successfully")
	return true

static func _validate_character_data() -> bool:
	## Validate character creation data against enum constraints
	if "origins" not in _character_data:
		return false
	
	# Validate that JSON origins match enum definitions
	var json_origins = _character_data["origins"].keys()
	var enum_origins = GlobalEnums.Origin.keys()
	
	for origin_key in json_origins:
		if not origin_key.to_upper() in enum_origins:
			push_warning("DataManager: JSON origin '%s' not found in enum" % origin_key)
	
	return true

static func _validate_background_references() -> bool:
	## Validate cross-references between data files
	if "backgrounds" not in _background_data:
		return false
	
	var backgrounds = _background_data["backgrounds"]
	for background in backgrounds:
		if "id" not in background or "name" not in background:
			push_error("DataManager: Background missing required fields: %s" % background)
			return false
	
	return true

## High-Performance Data Access API

## Character Data Access (Cached)
static func get_origin_data(origin_key: String) -> Dictionary:
	## Get rich origin data from JSON with enum validation
	_cache_hits += 1
	
	if not _is_data_loaded:
		push_error("DataManager: Data system not initialized")
		return {}
	
	var upper_key = origin_key.to_upper()
	
	# Validate against enum first (type safety)
	if not GlobalEnums.Origin.has(upper_key):
		push_error("DataManager: Invalid origin key: %s" % origin_key)
		return {}
	
	# Return rich JSON data
	if "origins" in _character_data and upper_key in _character_data["origins"]:
		return _character_data["origins"][upper_key]
	
	push_warning("DataManager: Origin data not found: %s" % origin_key)
	return {}

static func get_background_data(background_id: String) -> Dictionary:
	## Get rich background data with full stat bonuses and abilities
	_cache_hits += 1
	
	if not _is_data_loaded:
		push_error("DataManager: Data system not initialized")
		return {}
	
	if "backgrounds" not in _background_data:
		return {}
	
	# Search by ID in background array
	for background in _background_data["backgrounds"]:
		if background.get("id", "") == background_id:
			return background
	
	# Try default background as fallback
	var default_bg = _background_data.get("default_background", {})
	if default_bg.get("id", "") == background_id:
		return default_bg
	
	push_warning("DataManager: Background data not found: %s" % background_id)
	return {}

static func get_character_class_data(class_id: String) -> Dictionary:
	## Get character class data with skills and progression
	if "classes" not in _character_data:
		return {}
	
	return _character_data.get("classes", {}).get(class_id.to_upper(), {})

## Equipment Data Access
static func get_weapon_data(weapon_id: String) -> Dictionary:
	## Get weapon data with stats and characteristics
	if "weapons" not in _equipment_data:
		return {}
	
	return _equipment_data["weapons"].get(weapon_id, {})

static func get_armor_data(armor_id: String) -> Dictionary:
	## Get armor data with protection values and special properties
	if "armor" not in _equipment_data:
		return {}
	
	return _equipment_data["armor"].get(armor_id, {})

## Data Lookup Utilities
static func get_all_backgrounds() -> Array:
	## Get list of all available backgrounds for UI population
	if "backgrounds" not in _background_data:
		return []
	
	return _background_data["backgrounds"]

static func get_backgrounds_for_species(species_id: String) -> Array:
	## Get backgrounds compatible with specific species
	var compatible_backgrounds = []
	var all_backgrounds = get_all_backgrounds()
	
	for background in all_backgrounds:
		var suitable_species = background.get("suitable_species", [])
		if species_id in suitable_species:
			compatible_backgrounds.append(background)
	
	return compatible_backgrounds

## Performance Monitoring API
static func get_performance_stats() -> Dictionary:
	## Get data system performance metrics
	return {
		"is_loaded": _is_data_loaded,
		"load_time_ms": _load_time_ms,
		"cache_hits": _cache_hits,
		"cache_misses": _cache_misses,
		"cache_hit_ratio": float(_cache_hits) / max(1, _cache_hits + _cache_misses)
	}

static func reset_performance_stats() -> void:
	## Reset performance counters for testing
	_cache_hits = 0
	_cache_misses = 0
	_load_time_ms = 0

## Hot Reloading Support (Development)
static func reload_data() -> bool:
	## Reload all data from files (development feature)
	print("DataManager: Hot reloading data system...")
	_is_data_loaded = false
	_character_data.clear()
	_background_data.clear()
	_equipment_data.clear()
	_mission_data.clear()
	_crew_task_data.clear()
	
	return initialize_data_system()

## System Status Check
static func is_system_ready() -> bool:
	## Check if the data system is fully initialized and ready
	return _is_data_loaded

## Export character data for external systems
static func export_character_data() -> Dictionary:
	## Export all character-related data for external use
	return {
		"origins": _character_data.get("origins", {}),
		"backgrounds": _background_data.get("backgrounds", []),
		"classes": _character_data.get("classes", {}),
		"last_updated": Time.get_unix_time_from_system()
	}

## Data Validation API
static func validate_character_creation(character_config: Dictionary) -> Dictionary:
	## Validate character creation configuration against loaded data
	var validation_result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Validate origin
	var origin = character_config.get("origin", "")
	var origin_data = get_origin_data(origin)
	if origin_data.is_empty():
		validation_result.valid = false
		validation_result.errors.append("Invalid origin: %s" % origin)
	
	# Validate background
	var background = character_config.get("background", "")
	var background_data = get_background_data(background)
	if background_data.is_empty():
		validation_result.valid = false
		validation_result.errors.append("Invalid background: %s" % background)
	
	# Validate species-background compatibility
	if not origin_data.is_empty() and not background_data.is_empty():
		var suitable_species = background_data.get("suitable_species", [])
		var species_name = origin_data.get("name", "")
		if not species_name in suitable_species:
			validation_result.warnings.append("Background '%s' may not be suitable for species '%s'" % [background, species_name])
	
	return validation_result

## Crew Task Data Access API
static func get_crew_task_data(task_name: String) -> Dictionary:
	## Get crew task configuration data for specific task type
	_cache_hits += 1
	
	if not _is_data_loaded:
		push_error("DataManager: Data system not initialized")
		return {}
	
	if "main" not in _crew_task_data:
		push_error("DataManager: Crew task data not loaded")
		return {}
	
	var main_data = _crew_task_data["main"]
	if "tasks" in main_data and task_name in main_data["tasks"]:
		return main_data["tasks"][task_name]
	
	push_warning("DataManager: Crew task data not found: %s" % task_name)
	return {}

static func get_trade_result(roll: int) -> Dictionary:
	## Get trade result from trade table based on dice roll
	_cache_hits += 1
	
	if "trade" not in _crew_task_data:
		return {}
	
	var trade_data = _crew_task_data["trade"]
	if "results" in trade_data:
		var result_key = str(roll)
		if result_key in trade_data["results"]:
			return trade_data["results"][result_key]
	
	return {}

static func get_exploration_result(roll: int) -> Dictionary:
	## Get exploration result from exploration table based on D100 roll
	_cache_hits += 1
	
	if "exploration" not in _crew_task_data:
		return {}
	
	var exploration_data = _crew_task_data["exploration"]
	if "results" in exploration_data:
		# Check range-based results (e.g., "1-15", "16-25")
		for key in exploration_data["results"].keys():
			if "-" in key:
				var parts = key.split("-")
				if parts.size() == 2:
					var min_roll = parts[0].to_int()
					var max_roll = parts[1].to_int()
					if roll >= min_roll and roll <= max_roll:
						return exploration_data["results"][key]
	
	return {}

static func get_recruitment_result(roll: int) -> Dictionary:
	## Get recruitment result from recruitment table based on dice roll
	_cache_hits += 1
	
	if "recruitment" not in _crew_task_data:
		return {}
	
	var recruitment_data = _crew_task_data["recruitment"]
	if "results" in recruitment_data:
		var result_key = str(roll)
		if result_key in recruitment_data["results"]:
			return recruitment_data["results"][result_key]
	
	return {}

static func get_training_outcome() -> Dictionary:
	## Get training outcome data (training is always successful)
	_cache_hits += 1
	
	if "training" not in _crew_task_data:
		return {}
	
	var training_data = _crew_task_data["training"]
	if "results" in training_data and "standard_outcome" in training_data["results"]:
		return training_data["results"]["standard_outcome"]
	
	return {}

static func get_task_modifiers(task_name: String) -> Dictionary:
	## Get modifiers for specific crew task type
	var task_data = get_crew_task_data(task_name)
	return task_data.get("skill_modifiers", {})

static func get_world_modifiers(task_name: String) -> Dictionary:
	## Get world-specific modifiers for crew tasks
	var task_data = get_crew_task_data(task_name)
	return task_data.get("world_modifiers", {})
