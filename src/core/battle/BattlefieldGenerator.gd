class_name FPCM_BattlefieldGenerator
extends RefCounted

## Data-Driven Battlefield Generator for Five Parsecs
## Interprets JSON definitions to produce thematic and rule-compliant battlefields.

# Signals for integration with the battle workflow
signal generation_started(theme_name: String)
signal generation_progress(step: String, progress: float)
signal generation_completed(battlefield_data: Dictionary)
signal generation_error(error_message: String)

# Text-based terrain suggestion system (active path)
# The grid-based pipeline was removed — it used fabricated JSON data.
# All terrain generation now flows through generate_terrain_suggestions().

func _init() -> void:
	pass  # compendium data loaded lazily by _ensure_compendium_loaded()

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

	# Core Rules Standard Terrain Set counts (p.109, 3x3 table)
	var large_count: int = terrain_set.get("large", 3)
	var small_count: int = terrain_set.get("small", 6)
	var linear_count: int = terrain_set.get("linear", 3)

	# Load categorized feature pools
	var large_pool: Array = theme_data.get("large_features", [])
	var small_pool: Array = theme_data.get("small_features", [])
	var linear_pool: Array = theme_data.get("linear_features", [])
	var scatter_items: Array = theme_data.get("scatter_terrain", [])

	# Select features from each category (no duplicates)
	var selected_large: Array[String] = _pick_unique(large_pool, large_count, local_rng)
	var selected_small: Array[String] = _pick_unique(small_pool, small_count, local_rng)
	var selected_linear: Array[String] = _pick_unique(linear_pool, linear_count, local_rng)

	# Core Rules p.109: Validate feature-type minimums
	# At least 2 climbable, 1 elevated, 1 enterable
	_validate_terrain_minimums(selected_large, selected_small,
		large_pool, small_pool, local_rng)

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

## Core Rules p.109 feature-type validation.
## Ensures at least 2 climbable, 1 elevated, 1 enterable after random selection.
## Best-effort: swaps from pool if available, no-op if pool lacks variety.
func _validate_terrain_minimums(
		selected_large: Array[String], selected_small: Array[String],
		large_pool: Array, small_pool: Array,
		local_rng: RandomNumberGenerator) -> void:
	var has_elevated: bool = false
	var has_enterable: bool = false
	var climbable_count: int = 0

	for feat: String in selected_large + selected_small:
		var lower: String = feat.to_lower()
		if _text_has_terrain_keyword(lower, ["hill", "elevated", "platform", "ridge"]):
			has_elevated = true
		if _text_has_terrain_keyword(lower, ["forest", "rubble", "cluster", "bushes", "enter"]):
			has_enterable = true
		if _text_has_terrain_keyword(lower, ["building", "structure", "outcrop", "climb", "tower"]):
			climbable_count += 1

	if not has_elevated:
		_try_swap_for_keyword(selected_small, small_pool, large_pool,
			["hill", "elevated", "ridge"], local_rng)
	if not has_enterable:
		_try_swap_for_keyword(selected_small, small_pool, large_pool,
			["forest", "rubble", "bushes", "cluster"], local_rng)
	while climbable_count < 2:
		if _try_swap_for_keyword(selected_small, small_pool, large_pool,
				["building", "structure", "outcrop", "tower"], local_rng):
			climbable_count += 1
		else:
			break

## Check if text contains any of the given keywords.
func _text_has_terrain_keyword(text: String, keywords: Array) -> bool:
	for kw: String in keywords:
		if kw in text:
			return true
	return false

## Swap a non-matching item in selected list for a matching item from pools.
## Returns true if a swap was made.
func _try_swap_for_keyword(
		selected: Array[String], pool_a: Array, pool_b: Array,
		keywords: Array, local_rng: RandomNumberGenerator) -> bool:
	# Find a matching item in either pool that isn't already selected
	var candidate: String = ""
	for pool: Array in [pool_a, pool_b]:
		for item in pool:
			var lower: String = str(item).to_lower()
			if _text_has_terrain_keyword(lower, keywords) and str(item) not in selected:
				candidate = str(item)
				break
		if not candidate.is_empty():
			break

	if candidate.is_empty():
		return false

	# Swap with last non-matching item in selected
	for i: int in range(selected.size() - 1, -1, -1):
		if not _text_has_terrain_keyword(selected[i].to_lower(), keywords):
			selected[i] = candidate
			return true
	return false

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

func _load_json_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load JSON file: %s" % path)
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data else {}
