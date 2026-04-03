class_name FPCM_BattlefieldGenerator
extends RefCounted

## Battlefield Terrain Generator for Five Parsecs From Home
##
## Generates text-based terrain suggestions following the Compendium 5-step process
## (pp.96-100) for the player to set up their physical tabletop.
## Also supports world trait terrain modifications (Core Rules pp.72-75).

# Signals for integration with the battle workflow
signal generation_started(theme_name: String)
signal generation_completed(battlefield_data: Dictionary)
signal generation_error(error_message: String)

## Terrain data for text-based suggestions (loaded lazily)
var _compendium_data: Dictionary = {}

func _init() -> void:
	pass  # compendium data loaded lazily by _ensure_compendium_loaded()

# ============================================================================
# PUBLIC API
# ============================================================================

## Generate text-based terrain suggestions following the Compendium 5-step process.
## Returns readable text descriptions per sector telling the player what to place.
##
## theme: "industrial_zone", "wilderness", "alien_ruin", "crash_site", etc.
## world_traits: Array of trait ID strings from world_traits.json (e.g., ["overgrown", "haze"])
## deployment_condition: Dictionary with deployment condition data (e.g., {"id": "toxic_environment"})
func generate_terrain_suggestions(theme: String = "wilderness",
		world_traits: Array = [], deployment_condition: Dictionary = {}) -> Dictionary:
	_ensure_compendium_loaded()

	var themes: Dictionary = _compendium_data.get("themes", {})
	if not themes.has(theme):
		return {"error": "Unknown theme: %s. Available: %s" % [
			theme, ", ".join(themes.keys())]}

	var theme_data: Dictionary = themes[theme]
	var grid_info: Dictionary = _compendium_data.get("sector_grid", {})
	var sector_labels: Array = grid_info.get("labels", [])
	var quarters: Dictionary = grid_info.get("quarters", {})
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = Time.get_unix_time_from_system()

	generation_started.emit(theme_data.get("name", theme))

	# Initialize sector feature lists
	var sector_features: Dictionary = {}  # sector_label -> Array[String]
	for label: String in sector_labels:
		sector_features[label] = []

	# ---- Compendium Step 1: Quarters and Sectors (already defined in JSON) ----

	# ---- Compendium Step 2: The Center ----
	# "The center of the table always contains a notable terrain feature."
	# Roll 1D6 on the Notable Features table.
	var notable_d6: Array = theme_data.get("notable_features_d6", [])
	var center_feature: String = ""
	if notable_d6.size() >= 6:
		var roll: int = local_rng.randi_range(0, 5)
		center_feature = notable_d6[roll]
	elif not notable_d6.is_empty():
		center_feature = notable_d6[local_rng.randi_range(0, notable_d6.size() - 1)]
	else:
		# Fallback to large_features pool
		var large_pool: Array = theme_data.get("large_features", [])
		if not large_pool.is_empty():
			center_feature = "LARGE: %s" % large_pool[local_rng.randi_range(0, large_pool.size() - 1)]

	# Place notable feature in a center sector (B2, B3, C2, or C3)
	var center_sectors: Array[String] = ["B2", "B3", "C2", "C3"]
	var center_pick: String = center_sectors[local_rng.randi_range(0, center_sectors.size() - 1)]
	if not center_feature.is_empty():
		# Ensure it has a category prefix for the shape library
		if not center_feature.begins_with("LARGE:"):
			center_feature = "LARGE: %s" % center_feature
		sector_features[center_pick].append(center_feature)

	# ---- Compendium Step 3: The Quarters ----
	# "For each quarter, roll four D6s and consult the Regular Features table."
	# "Each sector must have at least part of a terrain feature."
	var regular_d6: Array = theme_data.get("regular_features_d6", [])
	var quarter_names: Array = ["top_left", "top_right", "bottom_left", "bottom_right"]
	var open_ground_count_per_quarter: Dictionary = {}  # track for "second open = hill" rule

	for q_name: String in quarter_names:
		var q_sectors: Array = quarters.get(q_name, [])
		if q_sectors.is_empty():
			continue

		open_ground_count_per_quarter[q_name] = 0
		var quarter_features: Array[String] = []

		# Roll 4D6 on regular features table
		for roll_i: int in range(4):
			var feature_text: String = ""
			if regular_d6.size() >= 6:
				var roll: int = local_rng.randi_range(0, 5)
				feature_text = regular_d6[roll]
			elif not regular_d6.is_empty():
				feature_text = regular_d6[local_rng.randi_range(0, regular_d6.size() - 1)]
			else:
				# Fallback: pick from small/linear pools
				feature_text = _pick_fallback_feature(theme_data, local_rng)

			# Handle "Open ground" results — second open in a quarter becomes a hill
			if feature_text.to_lower().begins_with("open"):
				open_ground_count_per_quarter[q_name] += 1
				if open_ground_count_per_quarter[q_name] >= 2:
					feature_text = "SMALL: Hill or elevated ground"
			quarter_features.append(feature_text)

		# Distribute features across the 4 sectors in this quarter.
		# Each sector must have at least one feature (Compendium: "each sector must have
		# at least part of a terrain feature located within it").
		_shuffle_array(quarter_features, local_rng)
		for i: int in range(quarter_features.size()):
			var target_label: String = str(q_sectors[i % q_sectors.size()])
			sector_features[target_label].append(quarter_features[i])

	# ---- Compendium Step 4: Add Scatter Terrain ----
	# "After you finish each quarter, add D6 pieces of scatter terrain."
	var scatter_items: Array = theme_data.get("scatter_terrain", [])
	if not scatter_items.is_empty():
		for q_name: String in quarter_names:
			var q_sectors: Array = quarters.get(q_name, [])
			var scatter_count: int = local_rng.randi_range(1, 6)
			# Distribute scatter across sectors in this quarter
			for si: int in range(scatter_count):
				var target_label: String = str(q_sectors[local_rng.randi_range(0, q_sectors.size() - 1)])
				var scatter_pick: String = scatter_items[local_rng.randi_range(0, scatter_items.size() - 1)]
				# Append to existing scatter line or create new one
				_append_scatter_to_sector(sector_features, target_label, scatter_pick)

	# ---- Compendium Step 5: Final Evaluation ----
	# Validate terrain minimums (Core Rules p.109)
	_validate_terrain_minimums_in_sectors(sector_features, theme_data, local_rng)

	# ---- World Trait Terrain Modifications (Core Rules pp.72-75) ----
	_apply_world_trait_modifications(sector_features, sector_labels, world_traits, local_rng)

	# ---- Deployment Condition Terrain Effects (Core Rules p.88) ----
	var visibility_limit: String = ""
	var condition_id: String = deployment_condition.get("id", "")
	if condition_id == "toxic_environment":
		# Add a hazard marker to a random sector
		var hazard_sector: String = sector_labels[local_rng.randi_range(0, sector_labels.size() - 1)]
		sector_features[hazard_sector].append("HAZARD: Toxic environment zone")
	elif condition_id == "poor_visibility":
		visibility_limit = "1D6+8 inches (reroll each round)"
	elif condition_id == "gloomy":
		visibility_limit = "9 inches (firing reveals position)"
	elif condition_id == "slippery_ground":
		# Note in summary, no terrain feature needed
		pass

	# ---- Build output ----
	var sectors: Array[Dictionary] = []
	for label: String in sector_labels:
		sectors.append({
			"label": label,
			"features": sector_features.get(label, []),
		})

	# Count placed features (non-scatter, non-open)
	var feature_count: int = 0
	for label: String in sector_labels:
		for feat: String in sector_features.get(label, []):
			if not feat.begins_with("Scatter:") and not feat.to_lower().begins_with("open"):
				feature_count += 1

	# Build summary text
	var summary_lines: Array[String] = []
	summary_lines.append("Theme: %s" % theme_data.get("name", theme))
	summary_lines.append(theme_data.get("description", ""))
	summary_lines.append("Compendium terrain generation (pp.96-100): Notable center + 4D6 per quarter + scatter")
	summary_lines.append("Placed features: %d" % feature_count)
	if not visibility_limit.is_empty():
		summary_lines.append("Visibility limit: %s" % visibility_limit)
	summary_lines.append("")
	for sector: Dictionary in sectors:
		if sector.features.size() > 0:
			summary_lines.append("Sector %s:" % sector.label)
			for feat: String in sector.features:
				summary_lines.append("  - %s" % feat)
		else:
			summary_lines.append("Sector %s: Open ground" % sector.label)

	var result: Dictionary = {
		"theme": theme,
		"theme_name": theme_data.get("name", theme),
		"sectors": sectors,
		"summary": "\n".join(summary_lines),
		"notable_count": 1,  # Always 1 center notable per Compendium
		"feature_count": feature_count,
		"terrain_set": {"notable": 1, "regular_per_quarter": 4, "scatter_per_quarter": "1D6"},
	}
	if not visibility_limit.is_empty():
		result["visibility_limit"] = visibility_limit

	generation_completed.emit(result)
	return result

## Compute objective marker positions based on mission type (Core Rules pp.89-91).
## Returns array of {type, grid_pos, label} dictionaries.
func compute_objective_positions(mission_objective: String, sectors: Array,
		local_rng: RandomNumberGenerator) -> Array[Dictionary]:
	var obj_lower: String = mission_objective.to_lower().strip_edges()

	match obj_lower:
		"access", "acquire", "deliver", "secure", "protect":
			# Center of table (Core Rules pp.90-91)
			return [{"type": "center", "grid_pos": Vector2(12, 8), "label": mission_objective.capitalize()}]
		"move_through":
			# No marker — crew crosses to opposite edge
			return []
		"fight_off", "defend":
			# No objective marker
			return []
		"patrol":
			# 3 random large terrain features (Core Rules p.90)
			return _pick_patrol_objectives(sectors, local_rng)
		"search":
			# Token on each medium/large feature (Core Rules p.91)
			return _pick_search_objectives(sectors)
		"eliminate":
			# Target is a random enemy figure, not a map position
			return []
		_:
			# Unknown objective — default to center
			if not obj_lower.is_empty():
				return [{"type": "center", "grid_pos": Vector2(12, 8), "label": mission_objective.capitalize()}]
			return []

## Regenerate a single sector's features.
func regenerate_sector(theme: String, sector_label: String) -> Dictionary:
	_ensure_compendium_loaded()

	var themes: Dictionary = _compendium_data.get("themes", {})
	if not themes.has(theme):
		return {}

	var theme_data: Dictionary = themes[theme]
	var regular_d6: Array = theme_data.get("regular_features_d6", [])
	var scatter_items: Array = theme_data.get("scatter_terrain", [])
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = Time.get_unix_time_from_system()

	var features: Array[String] = []

	# Re-roll: one D6 regular feature
	if regular_d6.size() >= 6:
		features.append(regular_d6[local_rng.randi_range(0, 5)])
	elif not regular_d6.is_empty():
		features.append(regular_d6[local_rng.randi_range(0, regular_d6.size() - 1)])
	else:
		features.append(_pick_fallback_feature(theme_data, local_rng))

	# Scatter
	if not scatter_items.is_empty():
		var scatter_count: int = local_rng.randi_range(1, 3)
		var scatter_list: Array[String] = []
		for si: int in range(scatter_count):
			scatter_list.append(scatter_items[local_rng.randi_range(0, scatter_items.size() - 1)])
		if not scatter_list.is_empty():
			features.append("Scatter: %s" % ", ".join(scatter_list))

	return {"label": sector_label, "features": features}

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
	var td: Dictionary = _compendium_data.get("themes", {}).get(theme_key, {})
	return td.get("name", theme_key)

# ============================================================================
# OBJECTIVE HELPERS (Phase 3)
# ============================================================================

func _pick_patrol_objectives(sectors: Array, local_rng: RandomNumberGenerator) -> Array[Dictionary]:
	## Patrol: "Select 3 large terrain features at random" (Core Rules p.90)
	var large_sectors: Array[Dictionary] = []
	for sector: Dictionary in sectors:
		for feat: String in sector.get("features", []):
			if feat.begins_with("LARGE:"):
				var label: String = sector.get("label", "")
				var grid_pos: Vector2 = _sector_label_to_grid_center(label)
				large_sectors.append({"type": "patrol", "grid_pos": grid_pos,
					"label": "Patrol #%d" % (large_sectors.size() + 1)})
				break  # one per sector
	# Shuffle and pick 3
	_shuffle_array(large_sectors, local_rng)
	var result: Array[Dictionary] = []
	for i: int in range(mini(3, large_sectors.size())):
		var obj: Dictionary = large_sectors[i]
		obj["label"] = "Patrol #%d" % (i + 1)
		result.append(obj)
	return result

func _pick_search_objectives(sectors: Array) -> Array[Dictionary]:
	## Search: "Put a token on each medium or large terrain feature" (Core Rules p.91)
	var result: Array[Dictionary] = []
	var idx: int = 1
	for sector: Dictionary in sectors:
		for feat: String in sector.get("features", []):
			if feat.begins_with("LARGE:") or feat.begins_with("SMALL:"):
				var label: String = sector.get("label", "")
				var grid_pos: Vector2 = _sector_label_to_grid_center(label)
				result.append({"type": "search", "grid_pos": grid_pos,
					"label": "Search #%d" % idx})
				idx += 1
				break  # one per sector
	return result

func _sector_label_to_grid_center(label: String) -> Vector2:
	## Convert sector label (e.g. "B3") to grid center coordinates.
	## Grid is 24 cols x 16 rows, sectors are 6x4 each.
	if label.length() < 2:
		return Vector2(12, 8)
	var row_idx: int = ["A", "B", "C", "D"].find(label[0])
	var col_idx: int = ["1", "2", "3", "4"].find(label[1])
	if row_idx < 0 or col_idx < 0:
		return Vector2(12, 8)
	return Vector2(col_idx * 6.0 + 3.0, row_idx * 4.0 + 2.0)

# ============================================================================
# TERRAIN VALIDATION & MODIFICATION
# ============================================================================

func _validate_terrain_minimums_in_sectors(sector_features: Dictionary,
		theme_data: Dictionary, local_rng: RandomNumberGenerator) -> void:
	## Core Rules p.109: At least 2 climbable, 1 elevated, 1 enterable.
	## Scan all placed features and swap if needed.
	var has_elevated: bool = false
	var has_enterable: bool = false
	var climbable_count: int = 0

	for label: String in sector_features:
		for feat: String in sector_features[label]:
			var lower: String = feat.to_lower()
			if _text_has_keyword(lower, ["hill", "elevated", "platform", "ridge", "high ground"]):
				has_elevated = true
			if _text_has_keyword(lower, ["forest", "rubble", "cluster", "bushes", "enter", "swamp"]):
				has_enterable = true
			if _text_has_keyword(lower, ["building", "structure", "outcrop", "climb", "tower", "hab-block"]):
				climbable_count += 1

	# If missing, inject the needed feature type into a random sector
	var all_labels: Array = sector_features.keys()
	if not has_elevated and not all_labels.is_empty():
		var target: String = str(all_labels[local_rng.randi_range(0, all_labels.size() - 1)])
		sector_features[target].append("SMALL: Hill or elevated ground")
	if not has_enterable and not all_labels.is_empty():
		var target: String = str(all_labels[local_rng.randi_range(0, all_labels.size() - 1)])
		sector_features[target].append("SMALL: Dense vegetation cluster (enterable)")
	while climbable_count < 2 and not all_labels.is_empty():
		var target: String = str(all_labels[local_rng.randi_range(0, all_labels.size() - 1)])
		sector_features[target].append("SMALL: Climbable structure or rocky outcrop")
		climbable_count += 1

func _apply_world_trait_modifications(sector_features: Dictionary,
		sector_labels: Array, world_traits: Array,
		local_rng: RandomNumberGenerator) -> void:
	## Apply world trait terrain effects (Core Rules pp.72-75).
	for trait_id in world_traits:
		var tid: String = str(trait_id).to_lower() if trait_id is String else str(trait_id.get("id", "")).to_lower()
		match tid:
			"overgrown":
				# "Add 1D6+2 individual plant features or 1D3 areas of vegetation"
				var plant_count: int = local_rng.randi_range(1, 6) + 2
				for pi: int in range(plant_count):
					var target: String = str(sector_labels[local_rng.randi_range(0, sector_labels.size() - 1)])
					sector_features[target].append("SMALL: Vegetation (world trait: Overgrown)")
			"warzone":
				# "Add 1D3 ruined buildings or craters"
				var ruin_count: int = local_rng.randi_range(1, 3)
				for ri: int in range(ruin_count):
					var target: String = str(sector_labels[local_rng.randi_range(0, sector_labels.size() - 1)])
					if local_rng.randi_range(0, 1) == 0:
						sector_features[target].append("SMALL: Ruined building (world trait: Warzone)")
					else:
						sector_features[target].append("SMALL: Crater (world trait: Warzone)")

# ============================================================================
# UTILITY HELPERS
# ============================================================================

func _pick_fallback_feature(theme_data: Dictionary, local_rng: RandomNumberGenerator) -> String:
	## Fallback for themes without D6 tables — pick from small/linear pools.
	var small_pool: Array = theme_data.get("small_features", [])
	var linear_pool: Array = theme_data.get("linear_features", [])
	var combined: Array = small_pool + linear_pool
	if combined.is_empty():
		return "SMALL: Basic cover feature"
	var pick: String = str(combined[local_rng.randi_range(0, combined.size() - 1)])
	if pick in small_pool:
		return "SMALL: %s" % pick
	return "LINEAR: %s" % pick

func _append_scatter_to_sector(sector_features: Dictionary, label: String, scatter_item: String) -> void:
	## Append scatter to existing Scatter: line or create a new one.
	var features: Array = sector_features.get(label, [])
	for i: int in range(features.size()):
		if str(features[i]).begins_with("Scatter: "):
			features[i] = "%s, %s" % [features[i], scatter_item]
			return
	features.append("Scatter: %s" % scatter_item)

func _text_has_keyword(text: String, keywords: Array) -> bool:
	for kw: String in keywords:
		if kw in text:
			return true
	return false

## Fisher-Yates shuffle for any array.
func _shuffle_array(arr: Array, local_rng: RandomNumberGenerator) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = local_rng.randi_range(0, i)
		var temp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func _ensure_compendium_loaded() -> void:
	if _compendium_data.is_empty():
		_compendium_data = _load_json_file(
			"res://data/battlefield/themes/compendium_terrain.json")

func _load_json_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load JSON file: %s" % path)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data else {}
