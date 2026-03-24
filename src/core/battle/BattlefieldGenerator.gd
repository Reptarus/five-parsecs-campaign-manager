class_name FPCM_BattlefieldGenerator
extends RefCounted

## Data-Driven Battlefield Generator for Five Parsecs
## Interprets JSON definitions to produce thematic and rule-compliant battlefields.

# Signals for integration with the battle workflow
signal generation_started(theme_name: String)
signal generation_progress(step: String, progress: float)
signal generation_completed(battlefield_data: Dictionary)
signal generation_error(error_message: String)

# Loaded data from JSON files
var feature_library: Dictionary = {}
var objective_library: Dictionary = {}
var deployment_rules: Dictionary = {}
var validation_rules: Dictionary = {}

# Generation constants (Five Parsecs terrain rules)
const NOTABLE_FEATURE_MIN := 1  # 1d3 notable features placed across battlefield
const NOTABLE_FEATURE_MAX := 3
const SCATTER_DICE := 6  # 1d6+2 scatter items per sector
const SCATTER_BASE := 2
const DEPLOYMENT_ZONE_DEPTH := 4  # Columns for crew/enemy deployment zones
const FEATURE_PLACEMENT_MAX_ATTEMPTS := 50
const OBJECTIVE_PLACEMENT_MAX_ATTEMPTS := 30
const OBJECTIVE_EDGE_MARGIN := 2  # Min cells from edge for objectives

# Internal state for a single generation pass
var battlefield_grid: Array = []
var rng: RandomNumberGenerator
var context: Dictionary

# Performance optimization caches
var _feature_cache: Dictionary = {}
var _placement_cache: Dictionary = {}
var _zone_cache: Dictionary = {}

func _init() -> void:
	_load_all_data_files()

## Terrain data for text-based suggestions (loaded lazily)
var _compendium_data: Dictionary = {}

## Public API: Generate text-based terrain suggestions for physical table setup.
## Returns readable text descriptions per sector telling the player what to place.
## Uses Core Rules Standard Terrain Set: 3 Large + 6 Small + 4 Linear = 13 features max.
## theme: "industrial_zone", "wilderness", "alien_ruin", "crash_site", etc.
func generate_terrain_suggestions(theme: String = "wilderness") -> Dictionary:
	_ensure_compendium_loaded()

	var themes: Dictionary = _compendium_data.get("themes", {})
	if not themes.has(theme):
		return {"error": "Unknown theme: %s. Available: %s" % [
			theme, ", ".join(themes.keys())]}

	var theme_data: Dictionary = themes[theme]
	var grid_info: Dictionary = _compendium_data.get("sector_grid", {})
	var sector_labels: Array = grid_info.get("labels", [])
	var terrain_set: Dictionary = _compendium_data.get("standard_terrain_set", {})
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = Time.get_unix_time_from_system()

	# Core Rules Standard Terrain Set counts (3x3 table)
	var large_count: int = terrain_set.get("large", 3)
	var small_count: int = terrain_set.get("small", 6)
	var linear_count: int = terrain_set.get("linear", 4)

	# Load categorized feature pools
	var large_pool: Array = theme_data.get("large_features", [])
	var small_pool: Array = theme_data.get("small_features", [])
	var linear_pool: Array = theme_data.get("linear_features", [])
	var scatter_items: Array = theme_data.get("scatter_terrain", [])

	# Select features from each category (no duplicates)
	var selected_large: Array[String] = _pick_unique(large_pool, large_count, local_rng)
	var selected_small: Array[String] = _pick_unique(small_pool, small_count, local_rng)
	var selected_linear: Array[String] = _pick_unique(linear_pool, linear_count, local_rng)

	# Build a flat list of all features with their category tags
	var all_features: Array[Dictionary] = []
	for feat: String in selected_large:
		all_features.append({"text": feat, "category": "LARGE"})
	for feat: String in selected_small:
		all_features.append({"text": feat, "category": "SMALL"})
	for feat: String in selected_linear:
		all_features.append({"text": feat, "category": "LINEAR"})

	# Distribute features across sectors with center priority
	# Center sectors (B2, B3, C2, C3) get first large feature for objective missions
	var center_sectors: Array[int] = []
	for label: String in ["B2", "B3", "C2", "C3"]:
		var idx: int = sector_labels.find(label)
		if idx >= 0:
			center_sectors.append(idx)

	# Initialize sector feature lists
	var sector_features: Dictionary = {}  # sector_idx -> Array[String]
	for i: int in range(sector_labels.size()):
		sector_features[i] = []

	# Place first large feature in a center sector (for objective missions)
	if all_features.size() > 0 and center_sectors.size() > 0:
		var center_idx: int = center_sectors[local_rng.randi_range(0, center_sectors.size() - 1)]
		var first_large: Dictionary = all_features[0]
		sector_features[center_idx].append("%s: %s" % [first_large.category, first_large.text])
		all_features.remove_at(0)

	# Shuffle remaining features and distribute evenly
	_shuffle_array(all_features, local_rng)
	var sector_order: Array[int] = []
	for i: int in range(sector_labels.size()):
		sector_order.append(i)
	_shuffle_array(sector_order, local_rng)

	var slot: int = 0
	for feat: Dictionary in all_features:
		var target_sector: int = sector_order[slot % sector_order.size()]
		# Skip sectors that already have 2+ features (spread evenly)
		var attempts: int = 0
		while sector_features[target_sector].size() >= 2 and attempts < sector_labels.size():
			slot += 1
			target_sector = sector_order[slot % sector_order.size()]
			attempts += 1
		sector_features[target_sector].append("%s: %s" % [feat.category, feat.text])
		slot += 1

	# Add scatter as flavor text (not counted features) to sectors with features
	for sector_idx: int in sector_features:
		if sector_features[sector_idx].size() > 0 and scatter_items.size() > 0:
			var scatter_count: int = local_rng.randi_range(1, 3)
			var scatter_list: Array[String] = []
			for _si: int in range(scatter_count):
				scatter_list.append(scatter_items[local_rng.randi_range(0, scatter_items.size() - 1)])
			sector_features[sector_idx].append("Scatter: %s" % ", ".join(scatter_list))

	# Build sector array output
	var sectors: Array[Dictionary] = []
	for sector_idx: int in range(sector_labels.size()):
		sectors.append({
			"label": sector_labels[sector_idx],
			"features": sector_features.get(sector_idx, []),
		})

	# Build summary text
	var total_placed: int = selected_large.size() + selected_small.size() + selected_linear.size()
	var summary_lines: Array[String] = []
	summary_lines.append("Theme: %s" % theme_data.get("name", theme))
	summary_lines.append(theme_data.get("description", ""))
	summary_lines.append("Standard Terrain Set: %d Large, %d Small, %d Linear (%d total)" % [
		selected_large.size(), selected_small.size(), selected_linear.size(), total_placed])
	summary_lines.append("")
	for sector: Dictionary in sectors:
		if sector.features.size() > 0:
			summary_lines.append("Sector %s:" % sector.label)
			for feat: String in sector.features:
				summary_lines.append("  - %s" % feat)
		else:
			summary_lines.append("Sector %s: Open ground" % sector.label)

	return {
		"theme": theme,
		"theme_name": theme_data.get("name", theme),
		"sectors": sectors,
		"summary": "\n".join(summary_lines),
		"notable_count": selected_large.size(),
		"terrain_set": {"large": selected_large.size(), "small": selected_small.size(), "linear": selected_linear.size()},
	}

## Pick up to count unique items from a pool (no duplicates).
func _pick_unique(pool: Array, count: int, local_rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	if pool.is_empty():
		return result
	var indices: Array[int] = []
	for i: int in range(pool.size()):
		indices.append(i)
	_shuffle_array(indices, local_rng)
	for i: int in range(mini(count, indices.size())):
		result.append(str(pool[indices[i]]))
	return result

## Fisher-Yates shuffle for any array.
func _shuffle_array(arr: Array, local_rng: RandomNumberGenerator) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = local_rng.randi_range(0, i)
		var temp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

## Regenerate a single sector's features.
func regenerate_sector(
		theme: String, sector_label: String) -> Dictionary:
	_ensure_compendium_loaded()

	var themes: Dictionary = _compendium_data.get("themes", {})
	if not themes.has(theme):
		return {}

	var theme_data: Dictionary = themes[theme]
	var small_pool: Array = theme_data.get("small_features", [])
	var linear_pool: Array = theme_data.get("linear_features", [])
	var scatter_items: Array = theme_data.get("scatter_terrain", [])
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = Time.get_unix_time_from_system()

	var features: Array[String] = []

	# Re-roll places one small or linear feature
	var combined_pool: Array = small_pool + linear_pool
	if combined_pool.size() > 0:
		var pick: String = str(combined_pool[local_rng.randi_range(0, combined_pool.size() - 1)])
		var category: String = "SMALL" if pick in small_pool else "LINEAR"
		features.append("%s: %s" % [category, pick])

	# Scatter
	if scatter_items.size() > 0:
		var scatter_count: int = local_rng.randi_range(1, 3)
		var scatter_list: Array[String] = []
		for _si: int in range(scatter_count):
			scatter_list.append(scatter_items[local_rng.randi_range(0, scatter_items.size() - 1)])
		if scatter_list.size() > 0:
			features.append("Scatter: %s" % ", ".join(scatter_list))

	return {
		"label": sector_label,
		"features": features,
	}

## Get available theme names.
func get_terrain_themes() -> Array[String]:
	_ensure_compendium_loaded()
	var themes: Array[String] = []
	for key: String in _compendium_data.get("themes", {}).keys():
		themes.append(key)
	return themes

## Get display name for a theme.
func get_theme_display_name(theme_key: String) -> String:
	_ensure_compendium_loaded()
	var td: Dictionary = _compendium_data.get(
		"themes", {}).get(theme_key, {})
	return td.get("name", theme_key)

func _ensure_compendium_loaded() -> void:
	if _compendium_data.is_empty():
		_compendium_data = _load_json_file(
			"res://data/battlefield/themes/compendium_terrain.json")

## Public API: Main generation function
func generate_battlefield(p_context: Dictionary) -> Dictionary:
	self.context = p_context
	self.rng = RandomNumberGenerator.new()
	rng.seed = context.get("generation_seed", Time.get_unix_time_from_system())

	var theme_data = _load_and_merge_theme()
	if theme_data.is_empty():
		var error_msg = "Failed to load theme data."
		push_error(error_msg)
		generation_error.emit(error_msg)
		return {}

	var theme_name = theme_data.get("name", "Unknown Theme")
	generation_started.emit(theme_name)

	_initialize_grid(theme_data.get("battlefield_size", Vector2i(36, 24)))

	# Execute the generation pipeline from the theme
	var pipeline_steps = theme_data.get("generation_pipeline", [])
	var total_steps = pipeline_steps.size()

	for i in range(total_steps):
		var step = pipeline_steps[i]
		_execute_pipeline_step(step)

		# Emit progress after each step
		var progress = float(i + 1) / float(total_steps)
		generation_progress.emit(step.get("action", "unknown"), progress)

	var result = {
		"grid": battlefield_grid,
		"theme": theme_name,
		"seed": rng.seed,
		"terrain_features": _extract_terrain_features(),
		"objectives": _extract_objectives(),
		"deployment_zones": _generate_deployment_zones()
	}

	# Performance optimization - clear temporary caches
	_optimize_grid_operations()

	generation_completed.emit(result)
	return result

## Data Loading and Preparation
func _load_all_data_files() -> void:
	# In a real implementation, this would scan directories.
	# For now, we load the files we know we created.
	feature_library = _load_json_file("res://data/battlefield/features/common_features.json")
	var urban_features = _load_json_file("res://data/battlefield/features/urban_features.json")
	var natural_features = _load_json_file("res://data/battlefield/features/natural_features.json")
	feature_library.features.append_array(urban_features.get("features", []))
	feature_library.features.append_array(natural_features.get("features", []))

	objective_library = _load_json_file("res://data/battlefield/objectives/objective_markers.json")
	deployment_rules = _load_json_file("res://data/battlefield/rules/deployment_rules.json")
	validation_rules = _load_json_file("res://data/battlefield/rules/validation_rules.json")

func _load_json_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load JSON file: %s" % path)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data else {}

func _load_and_merge_theme() -> Dictionary:
	var mission_resource = context.get("mission_resource")
	if not mission_resource or not mission_resource.has("battlefield_theme"):
		push_error("Mission resource is missing or does not specify a battlefield theme.")
		return {}

	var theme_path = mission_resource.battlefield_theme
	var theme_data = _load_json_file(theme_path)

	# Deep merge the overrides from the mission
	if mission_resource.has("battlefield_overrides"):
		_deep_merge_dictionaries(theme_data, mission_resource.battlefield_overrides)

	return theme_data

func _initialize_grid(size: Vector2i) -> void:
	battlefield_grid.clear()
	battlefield_grid.resize(size.y)
	for y in range(size.y):
		battlefield_grid[y] = []
		battlefield_grid[y].resize(size.x)
		for x in range(size.x):
			battlefield_grid[y][x] = { "base_terrain": null, "feature": null, "objective": null }

## Pipeline Execution
func _execute_pipeline_step(step: Dictionary) -> void:
	var action = step.get("action", "")
	var params = step.get("params", {})

	match action:
		"fill_background":
			_action_fill_background(params)
		"place_large_features":
			_action_place_large_features(params)
		"add_scatter":
			_action_add_scatter(params)
		"place_objectives":
			_action_place_objectives(params)
		"run_validation":
			_action_run_validation(params)
		_:
			push_warning("Unknown generator action: %s" % action)

# --- ACTION IMPLEMENTATIONS ---

func _action_fill_background(params: Dictionary) -> void:
	var feature_tag = params.get("feature_tag", "")
	var background_feature = _find_feature_by_tag(feature_tag)

	if not background_feature:
		var error_msg = "Background feature not found: %s" % feature_tag
		generation_error.emit(error_msg)
		return

	# Optimized grid population with batch operations
	for y in range(battlefield_grid.size()):
		var row = battlefield_grid[y]
		for x in range(row.size()):
			row[x]["base_terrain"] = background_feature.duplicate()

func _action_place_large_features(params: Dictionary) -> void:
	var feature_tag = params.get("feature_tag", "")
	var count_expression = params.get("count", "1")
	var placement_rules = params.get("placement", {})

	var features = _find_features_by_tag(feature_tag)
	if features.is_empty():
		var error_msg = "Large features not found: %s" % feature_tag
		generation_error.emit(error_msg)
		return

	var count = _evaluate_dice_expression(count_expression)
	var placed_count = 0

	# Attempt placement with collision detection
	for i in range(count * 3): # Try 3x count to handle placement failures
		if placed_count >= count:
			break

		var feature = features[rng.randi() % features.size()].duplicate()
		var position = _find_valid_placement_position(feature, placement_rules)

		if position != Vector2i(-1, -1):
			_place_feature_at_position(feature, position)
			placed_count += 1

func _action_add_scatter(params: Dictionary) -> void:
	var feature_tag = params.get("feature_tag", "")
	var zone = params.get("zone", "entire")
	var density = params.get("density", 0.1)

	var scatter_features = _find_features_by_tag(feature_tag)
	if scatter_features.is_empty():
		var error_msg = "Scatter features not found: %s" % feature_tag
		generation_error.emit(error_msg)
		return

	var zone_cells = _get_zone_cells(zone)

	# Scatter placement with density control
	for cell_pos in zone_cells:
		if rng.randf() < density:
			var feature = scatter_features[rng.randi() % scatter_features.size()].duplicate()
			if _is_cell_available(cell_pos):
				battlefield_grid[cell_pos.y][cell_pos.x]["feature"] = feature

func _action_place_objectives(params: Dictionary) -> void:
	var objective_tag = params.get("objective_tag", "")
	var count_expression = params.get("count", "1")
	var placement_rules = params.get("placement", {})

	var objectives = _find_objectives_by_tag(objective_tag)
	if objectives.is_empty():
		var error_msg = "Objectives not found: %s" % objective_tag
		generation_error.emit(error_msg)
		return

	var count = _evaluate_dice_expression(count_expression)
	var placed_count = 0

	# Place objectives with spacing rules
	for i in range(count * 2): # Try 2x count for objective placement
		if placed_count >= count:
			break

		var objective = objectives[rng.randi() % objectives.size()].duplicate()
		var position = _find_valid_objective_position(objective, placement_rules)

		if position != Vector2i(-1, -1):
			battlefield_grid[position.y][position.x]["objective"] = objective
			placed_count += 1

func _action_run_validation(params: Dictionary) -> void:
	var rulesets = params.get("rulesets", [])

	for ruleset_name in rulesets:
		var ruleset = validation_rules.get("rulesets", {}).get(ruleset_name, {})
		if not ruleset.is_empty():
			var validation_result = _execute_validation_ruleset(ruleset)
			if not validation_result.valid:
				var error_msg = "Validation failed for %s: %s" % [ruleset_name, validation_result.error]
				generation_error.emit(error_msg)
				return


# --- UTILITY FUNCTIONS ---

func _find_feature_by_tag(tag: String) -> Dictionary:
	# Use cache for repeated lookups
	if _feature_cache.has(tag):
		return _feature_cache[tag]

	var features = feature_library.get("features", [])
	for feature in features:
		var tags = feature.get("tags", [])
		if tag in tags:
			_feature_cache[tag] = feature
			return feature

	return {}

func _find_features_by_tag(tag: String) -> Array:
	var cache_key = "multi_" + tag
	if _feature_cache.has(cache_key):
		return _feature_cache[cache_key]

	var result = []
	var features = feature_library.get("features", [])
	for feature in features:
		var tags = feature.get("tags", [])
		if tag in tags:
			result.append(feature)

	_feature_cache[cache_key] = result
	return result

func _find_objectives_by_tag(tag: String) -> Array:
	var result = []
	var objectives = objective_library.get("objectives", [])
	for objective in objectives:
		var tags = objective.get("tags", [])
		if tag in tags:
			result.append(objective)
	return result

func _evaluate_dice_expression(expression: String) -> int:
	## Enhanced dice parser supporting Five Parsecs notation with modifiers
	if expression.is_empty():
		return 0

	# Handle simple integers
	if expression.is_valid_int():
		return expression.to_int()

	# Parse dice expressions (XdY, XdY+Z, XdY-Z)
	if "d" not in expression:
		return 1  # Fallback for invalid expressions

	var parts: PackedStringArray = expression.split("d")
	if parts.size() != 2:
		return 0

	# Parse number of dice (default to 1 if empty)
	var rolls_count: int = 1
	if not parts[0].is_empty():
		if not parts[0].is_valid_int():
			return 0
		rolls_count = parts[0].to_int()
		if rolls_count <= 0:
			return 0

	# Parse dice size and optional modifier
	var dice_and_mod_str: String = parts[1]
	var modifier: int = 0
	var dice_sides: int = 0

	# Check for modifiers (+N or -N)
	var modifier_pos: int = -1
	var modifier_sign: int = 1

	for i in range(dice_and_mod_str.length()):
		var char = dice_and_mod_str[i]
		if char == "+":
			modifier_pos = i
			modifier_sign = 1
			break
		elif char == "-":
			modifier_pos = i
			modifier_sign = -1
			break

	if modifier_pos != -1:
		# Extract dice size and modifier
		var dice_str = dice_and_mod_str.substr(0, modifier_pos)
		var mod_str = dice_and_mod_str.substr(modifier_pos + 1)

		if not dice_str.is_valid_int() or not mod_str.is_valid_int():
			return 0

		dice_sides = dice_str.to_int()
		modifier = mod_str.to_int() * modifier_sign
	else:
		# No modifier, just dice size
		if not dice_and_mod_str.is_valid_int():
			return 0
		dice_sides = dice_and_mod_str.to_int()

	if dice_sides <= 0:
		return 0

	# Roll dice and apply modifier
	var total_roll: int = 0
	for i in range(rolls_count):
		total_roll += rng.randi_range(1, dice_sides)

	return total_roll + modifier

func _find_valid_placement_position(feature: Dictionary, placement_rules: Dictionary) -> Vector2i:
	var size = feature.get("size", Vector2i(1, 1))
	var max_attempts = FEATURE_PLACEMENT_MAX_ATTEMPTS

	for attempt in range(max_attempts):
		var x = rng.randi_range(0, battlefield_grid[0].size() - size.x)
		var y = rng.randi_range(0, battlefield_grid.size() - size.y)
		var position = Vector2i(x, y)

		if _can_place_feature_at(position, size, placement_rules):
			return position

	return Vector2i(-1, -1)  # No valid position found

func _find_valid_objective_position(objective: Dictionary, placement_rules: Dictionary) -> Vector2i:
	var min_distance = placement_rules.get("min_distance_from_features", OBJECTIVE_EDGE_MARGIN)
	var max_attempts = OBJECTIVE_PLACEMENT_MAX_ATTEMPTS

	for attempt in range(max_attempts):
		var x = rng.randi_range(OBJECTIVE_EDGE_MARGIN, battlefield_grid[0].size() - OBJECTIVE_EDGE_MARGIN - 1)
		var y = rng.randi_range(OBJECTIVE_EDGE_MARGIN, battlefield_grid.size() - OBJECTIVE_EDGE_MARGIN - 1)
		var position = Vector2i(x, y)

		if _is_cell_available(position) and _has_minimum_distance_from_features(position, min_distance):
			return position

	return Vector2i(-1, -1)

func _can_place_feature_at(position: Vector2i, size: Vector2i, placement_rules: Dictionary) -> bool:
	# Check bounds
	if position.x + size.x > battlefield_grid[0].size() or position.y + size.y > battlefield_grid.size():
		return false

	# Check for collisions
	for dy in range(size.y):
		for dx in range(size.x):
			var cell_pos = Vector2i(position.x + dx, position.y + dy)
			if not _is_cell_available(cell_pos):
				return false

	return true

func _place_feature_at_position(feature: Dictionary, position: Vector2i) -> void:
	var size = feature.get("size", Vector2i(1, 1))

	for dy in range(size.y):
		for dx in range(size.x):
			var cell_pos = Vector2i(position.x + dx, position.y + dy)
			battlefield_grid[cell_pos.y][cell_pos.x]["feature"] = feature.duplicate()

func _is_cell_available(position: Vector2i) -> bool:
	if position.x < 0 or position.y < 0:
		return false
	if position.y >= battlefield_grid.size() or position.x >= battlefield_grid[position.y].size():
		return false

	var cell = battlefield_grid[position.y][position.x]
	return cell.get("feature") == null and cell.get("objective") == null

func _has_minimum_distance_from_features(position: Vector2i, min_distance: int) -> bool:
	for dy in range(-min_distance, min_distance + 1):
		for dx in range(-min_distance, min_distance + 1):
			var check_pos = Vector2i(position.x + dx, position.y + dy)
			if check_pos.x >= 0 and check_pos.y >= 0 and check_pos.y < battlefield_grid.size() and check_pos.x < battlefield_grid[check_pos.y].size():
				var cell = battlefield_grid[check_pos.y][check_pos.x]
				if cell.get("feature") != null:
					return false
	return true

func _get_zone_cells(zone: String) -> Array[Vector2i]:
	var cache_key = "zone_" + zone
	if _zone_cache.has(cache_key):
		return _zone_cache[cache_key]

	var cells: Array[Vector2i] = []
	var grid_width = battlefield_grid[0].size()
	var grid_height = battlefield_grid.size()

	match zone:
		"entire":
			for y in range(grid_height):
				for x in range(grid_width):
					cells.append(Vector2i(x, y))
		"center":
			var start_x = grid_width / 4
			var end_x = 3 * grid_width / 4
			var start_y = grid_height / 4
			var end_y = 3 * grid_height / 4
			for y in range(start_y, end_y):
				for x in range(start_x, end_x):
					cells.append(Vector2i(x, y))
		"edges":
			# Perimeter cells only
			for x in range(grid_width):
				cells.append(Vector2i(x, 0))  # Top edge
				cells.append(Vector2i(x, grid_height - 1))  # Bottom edge
			for y in range(1, grid_height - 1):
				cells.append(Vector2i(0, y))  # Left edge
				cells.append(Vector2i(grid_width - 1, y))  # Right edge

	_zone_cache[cache_key] = cells
	return cells

func _execute_validation_ruleset(ruleset: Dictionary) -> Dictionary:
	# Simple validation implementation
	var result = {"valid": true, "error": ""}

	# Check for minimum feature count
	if ruleset.has("min_features"):
		var feature_count = _count_placed_features()
		var min_required = ruleset["min_features"]
		if feature_count < min_required:
			result["valid"] = false
			result["error"] = "Insufficient features placed: %d < %d" % [feature_count, min_required]

	return result

func _count_placed_features() -> int:
	var count = 0
	for row in battlefield_grid:
		for cell in row:
			if cell.get("feature") != null:
				count += 1
	return count

func _extract_terrain_features() -> Array[FPCM_BattlefieldTypes.TerrainFeature]:
	var terrain_features: Array[FPCM_BattlefieldTypes.TerrainFeature] = []

	for y in range(battlefield_grid.size()):
		for x in range(battlefield_grid[y].size()):
			var cell = battlefield_grid[y][x]
			var feature_data = cell.get("feature")

			if feature_data:
				var terrain_feature = FPCM_BattlefieldTypes.TerrainFeature.new()
				terrain_feature.feature_id = feature_data.get("id", "unknown")
				terrain_feature.feature_type = StringName(feature_data.get("type", ""))
				terrain_feature.title = feature_data.get("name", "")
				terrain_feature.description = feature_data.get("description", "")
				terrain_feature.positions = [Vector2i(x, y)]
				terrain_feature.properties = feature_data.get("properties", {})
				terrain_features.append(terrain_feature)

	return terrain_features

func _extract_objectives() -> Array[FPCM_BattlefieldTypes.FPCM_ObjectiveMarker]:
	var objectives: Array[FPCM_BattlefieldTypes.FPCM_ObjectiveMarker] = []

	for y in range(battlefield_grid.size()):
		for x in range(battlefield_grid[y].size()):
			var cell = battlefield_grid[y][x]
			var objective_data = cell.get("objective")

			if objective_data:
				var objective = FPCM_BattlefieldTypes.FPCM_ObjectiveMarker.new()
				objective.objective_id = objective_data.get("id", "unknown")
				objective.objective_type = StringName(objective_data.get("type", ""))
				objective.title = objective_data.get("name", "")
				objective.description = objective_data.get("description", "")
				objective.node_position = Vector2i(x, y)
				objective.victory_points = objective_data.get("victory_points", 1)
				objectives.append(objective)

	return objectives

func _generate_deployment_zones() -> Dictionary:
	var grid_width = battlefield_grid[0].size()
	var grid_height = battlefield_grid.size()

	var crew_zone: Array[Vector2i] = []
	var enemy_zone: Array[Vector2i] = []

	# Standard Five Parsecs deployment: crew on left, enemies on right
	for y in range(grid_height):
		# Crew deploys in leftmost columns
		for x in range(min(DEPLOYMENT_ZONE_DEPTH, grid_width)):
			crew_zone.append(Vector2i(x, y))

		# Enemies deploy in rightmost columns
		for x in range(max(0, grid_width - DEPLOYMENT_ZONE_DEPTH), grid_width):
			enemy_zone.append(Vector2i(x, y))

	return {
		"crew_deployment": crew_zone,
		"enemy_deployment": enemy_zone
	}

func _deep_merge_dictionaries(base: Dictionary, overrides: Dictionary) -> void:
	for key in overrides:
		if base.has(key) and typeof(base[key]) == TYPE_DICTIONARY and typeof(overrides[key]) == TYPE_DICTIONARY:
			_deep_merge_dictionaries(base[key], overrides[key])
		else:
			base[key] = overrides[key]

# --- PERFORMANCE OPTIMIZATION ---

func _optimize_grid_operations() -> void:
	## Optimize grid operations for 60fps performance targets
	# Clear caches that are no longer needed after generation
	_placement_cache.clear()

	# Keep feature cache for potential regenerations
	# Keep zone cache for UI interactions

func clear_caches() -> void:
	## Clear all performance caches
	_feature_cache.clear()
	_placement_cache.clear()
	_zone_cache.clear()

func get_cache_info() -> Dictionary:
	## Get cache information for debugging
	return {
		"feature_cache_size": _feature_cache.size(),
		"placement_cache_size": _placement_cache.size(),
		"zone_cache_size": _zone_cache.size()
	}
