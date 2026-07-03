class_name FPCM_BattlefieldGenerator
extends RefCounted

## Battlefield Terrain Generator for Five Parsecs From Home
##
## Generates text-based terrain suggestions following the Compendium 5-step process
## (pp.94-98: steps pp.94-95, terrain tables pp.96-98) for the player to set
## up their physical tabletop. (pp.99-100 are the Casualty Tables, not terrain.)
## Also supports world trait terrain modifications (Core Rules pp.72-75) and
## book table sizes 2x2 / 2.5x2.5 / 3x3 ft (Core Rules p.108).

const BattlefieldGrid = preload("res://src/core/battle/BattlefieldGrid.gd")

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
## theme: "industrial_zone", "wilderness", "alien_ruin", "crash_site" (Compendium pp.96-98)
## world_traits: Array of trait ID strings from world_traits.json (e.g., ["overgrown", "haze"])
## deployment_condition: Dictionary with deployment condition data (e.g., {"id": "toxic_environment"})
## rng_seed: 0 = random; non-zero = reproducible output (persist result["seed"])
## table_size_ft: 2.0 / 2.5 / 3.0 (Core Rules p.108). Does NOT change the dice —
##   the 5-step process is table-size-independent (Compendium p.94); size only
##   affects the summary guidance and downstream grid math.
func generate_terrain_suggestions(theme: String = "wilderness",
		world_traits: Array = [], deployment_condition: Dictionary = {},
		rng_seed: int = 0, table_size_ft: float = 3.0) -> Dictionary:
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
	if rng_seed != 0:
		local_rng.seed = rng_seed
	else:
		# hash() the time: Godot's RNG has no avalanche effect, so raw
		# sequential unix-second seeds would produce correlated streams
		# (and the float truncates to whole seconds — same-second collisions).
		local_rng.seed = hash(Time.get_unix_time_from_system())

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

			# "If more than one area of open ground exist in a quarter, one of
			# them should be a hill" — this rule is part of the INDUSTRIAL
			# Regular Features table entry 3 ONLY (Compendium p.97). The other
			# themes' "Open..." entries carry no hill rule, so it must not
			# fire for them (fixed 2026-07-02; was applied to all themes).
			if feature_text.to_lower().begins_with("open"):
				open_ground_count_per_quarter[q_name] += 1
				if theme == "industrial_zone" \
						and open_ground_count_per_quarter[q_name] >= 2:
					feature_text = "SMALL: Hill or elevated ground"
			# Normalize: unprefixed non-open features default to SMALL
			elif not _has_known_prefix(feature_text):
				feature_text = "SMALL: %s" % feature_text
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
	# Check if "flat" trait is active — suppresses elevated minimum (Core Rules p.75)
	var has_flat_trait: bool = false
	for trait_id in world_traits:
		var tid_check: String = str(trait_id).to_lower() if trait_id is String else str(trait_id.get("id", "")).to_lower()
		if tid_check == "flat":
			has_flat_trait = true
			break
	_validate_terrain_minimums_in_sectors(
		sector_features, theme_data, local_rng, has_flat_trait)

	# ---- World Trait Terrain Modifications (Core Rules pp.72-75) ----
	var combat_notes: Array[String] = _apply_world_trait_modifications(
		sector_features, sector_labels, world_traits, local_rng)

	# ---- Deployment Condition Effects (Core Rules p.88) ----
	var visibility_limit: String = ""
	var condition_id: String = deployment_condition.get("id", "")
	if condition_id == "toxic_environment":
		# Book rule is a Stun->casualty roll, NOT terrain — the old HAZARD
		# feature injection was fabricated and removed 2026-07-02 (p.88).
		combat_notes.append(
			"Toxic environment: whenever a combatant is Stunned, roll "
			+ "1D6+Savvy (0 for enemies) — failing a 4+ becomes a casualty "
			+ "(Core Rules p.88)")
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
	summary_lines.append("Compendium terrain generation (pp.94-98): Notable center + 4D6 per quarter + scatter")
	summary_lines.append("Table size: %s (Core Rules p.108)"
		% BattlefieldGrid.table_size_label(table_size_ft))
	var set_counts: Dictionary = _standard_set_for_size(table_size_ft)
	if not set_counts.is_empty():
		summary_lines.append(
			"Standard set guideline: %d large / %d small / %d linear (Core Rules p.109)" % [
				int(set_counts.get("large", 0)), int(set_counts.get("small", 0)),
				int(set_counts.get("linear", 0))])
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
		"table_size_ft": BattlefieldGrid.sanitize_table_size(table_size_ft),
	}
	if not visibility_limit.is_empty():
		result["visibility_limit"] = visibility_limit
	if not combat_notes.is_empty():
		result["combat_notes"] = combat_notes
	result["seed"] = local_rng.seed

	generation_completed.emit(result)
	return result

## Compute objective marker positions based on mission type (Core Rules pp.89-91).
## Returns array of {type, grid_pos, label} dictionaries.
## dims: grid dimensions from BattlefieldGrid.dims_for_table() (default 3x3).
func compute_objective_positions(mission_objective: String, sectors: Array,
		local_rng: RandomNumberGenerator, dims: Dictionary = {}) -> Array[Dictionary]:
	var obj_lower: String = mission_objective.to_lower().strip_edges()
	var d: Dictionary = dims if not dims.is_empty() else BattlefieldGrid.dims_for_table()

	match obj_lower:
		"access", "acquire", "deliver", "secure", "protect":
			# Center of table (Core Rules pp.90-91). The center placement is the
			# verbatim tabletop rule ("exact center of the battlefield/table"),
			# so the marker carries a rule cite to read as intentional, not a bug.
			return [{
				"type": "center", "grid_pos": BattlefieldGrid.center_cell(d),
				"label": mission_objective.capitalize(),
				"rule": _center_objective_rule(obj_lower)}]
		"move_through":
			# No marker — crew crosses to opposite edge
			return []
		"fight_off", "defend":
			# No objective marker
			return []
		"patrol":
			# 3 random large terrain features (Core Rules p.90)
			return _pick_patrol_objectives(sectors, local_rng, d)
		"search":
			# Token on each medium/large feature (Core Rules p.91)
			return _pick_search_objectives(sectors, d)
		"eliminate":
			# Target is a random enemy figure, not a map position
			return []
		_:
			# Unknown objective — default to center
			if not obj_lower.is_empty():
				return [{
					"type": "center", "grid_pos": BattlefieldGrid.center_cell(d),
					"label": mission_objective.capitalize(),
					"rule": _center_objective_rule(obj_lower)}]
			return []

## Verbatim-faithful rule cite for a center-placed objective marker, so the
## dead-center placement reads as the intended tabletop rule, not a defect.
## Wording is transcribed from Core Rules "Types of Objective" (p.90), verified
## against the rulebook PDF. NOT invented data — provenance text only.
func _center_objective_rule(obj_lower: String) -> String:
	match obj_lower:
		"access":
			return "Console at exact center of battlefield (Core Rules p.90)"
		"acquire":
			return "Item at center of table (Core Rules p.90)"
		"secure":
			return "Hold within 2\" of center of table (Core Rules p.90)"
		"deliver":
			return "Deliver to exact center of table (Core Rules p.90)"
		"protect":
			return "VIP escort; center is the rally point (Core Rules p.90)"
		_:
			return "Center of table (Core Rules p.90)"

## Regenerate a single sector's features (Compendium Step 5 sanctions swapping
## pieces for playability, p.95). seed_override != 0 makes the re-roll
## deterministic — callers derive it as hash(base_seed | label | reroll_count).
func regenerate_sector(theme: String, sector_label: String,
		seed_override: int = 0) -> Dictionary:
	_ensure_compendium_loaded()

	var themes: Dictionary = _compendium_data.get("themes", {})
	if not themes.has(theme):
		return {}

	var theme_data: Dictionary = themes[theme]
	var regular_d6: Array = theme_data.get("regular_features_d6", [])
	var scatter_items: Array = theme_data.get("scatter_terrain", [])
	var local_rng := RandomNumberGenerator.new()
	if seed_override != 0:
		local_rng.seed = seed_override
	else:
		local_rng.seed = hash(Time.get_unix_time_from_system())

	var features: Array[String] = []

	# Re-roll: one D6 regular feature (normalized like Step 3 output)
	var feature_text: String = ""
	if regular_d6.size() >= 6:
		feature_text = regular_d6[local_rng.randi_range(0, 5)]
	elif not regular_d6.is_empty():
		feature_text = regular_d6[local_rng.randi_range(0, regular_d6.size() - 1)]
	else:
		feature_text = _pick_fallback_feature(theme_data, local_rng)
	if not feature_text.to_lower().begins_with("open") \
			and not _has_known_prefix(feature_text):
		feature_text = "SMALL: %s" % feature_text
	features.append(feature_text)

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

func _pick_patrol_objectives(sectors: Array, local_rng: RandomNumberGenerator,
		dims: Dictionary) -> Array[Dictionary]:
	## Patrol: "Select 3 large terrain features at random" (Core Rules p.90)
	var large_sectors: Array[Dictionary] = []
	for sector: Dictionary in sectors:
		for feat: String in sector.get("features", []):
			if feat.begins_with("LARGE:"):
				var label: String = sector.get("label", "")
				var grid_pos: Vector2 = BattlefieldGrid.sector_label_to_grid_center(label, dims)
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

func _pick_search_objectives(sectors: Array, dims: Dictionary) -> Array[Dictionary]:
	## Search: "Put a token on each medium or large terrain feature" (Core Rules p.91)
	var result: Array[Dictionary] = []
	var idx: int = 1
	for sector: Dictionary in sectors:
		for feat: String in sector.get("features", []):
			if feat.begins_with("LARGE:") or feat.begins_with("SMALL:"):
				var label: String = sector.get("label", "")
				var grid_pos: Vector2 = BattlefieldGrid.sector_label_to_grid_center(label, dims)
				result.append({"type": "search", "grid_pos": grid_pos,
					"label": "Search #%d" % idx})
				idx += 1
				break  # one per sector
	return result

# ============================================================================
# TERRAIN VALIDATION & MODIFICATION
# ============================================================================

func _validate_terrain_minimums_in_sectors(sector_features: Dictionary,
		theme_data: Dictionary, local_rng: RandomNumberGenerator,
		skip_elevated: bool = false) -> void:
	## Core Rules p.109: At least 2 climbable, 1 elevated, 1 enterable.
	## skip_elevated: true when "Flat" world trait is active (no hills/elevated).
	var has_elevated: bool = skip_elevated  # If flat, pretend we have elevated
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

	# If missing, inject the needed feature type into a random sector.
	# These are APP SUGGESTIONS from the p.109 terrain-set guidelines, not
	# table rolls — label them so the player can tell rolls from assistance.
	# Enterable suggestion uses rubble (a p.109 example) rather than plants
	# so the Barren world trait's vegetation strip can't erase it.
	var all_labels: Array = sector_features.keys()
	if not has_elevated and not all_labels.is_empty():
		var target: String = str(all_labels[local_rng.randi_range(0, all_labels.size() - 1)])
		sector_features[target].append(
			"SMALL: Hill or elevated ground (suggested — Core Rules p.109 guideline)")
	if not has_enterable and not all_labels.is_empty():
		var target: String = str(all_labels[local_rng.randi_range(0, all_labels.size() - 1)])
		sector_features[target].append(
			"SMALL: Enterable rubble cluster (suggested — Core Rules p.109 guideline)")
	while climbable_count < 2 and not all_labels.is_empty():
		var target: String = str(all_labels[local_rng.randi_range(0, all_labels.size() - 1)])
		sector_features[target].append(
			"SMALL: Climbable structure or rocky outcrop (suggested — Core Rules p.109 guideline)")
		climbable_count += 1

func _apply_world_trait_modifications(sector_features: Dictionary,
		sector_labels: Array, world_traits: Array,
		local_rng: RandomNumberGenerator) -> Array[String]:
	## Apply world trait terrain effects (Core Rules pp.72-75).
	## Returns combat notes for non-terrain traits (visibility, movement, etc.).
	var notes: Array[String] = []
	var vegetation_keywords: Array = ["tree", "bush", "grass", "vegetation",
		"vine", "growth", "plant", "mushroom", "flower", "spore", "fungal"]
	var elevation_keywords: Array = ["hill", "elevated", "ridge",
		"high ground", "mound", "hilltop"]

	for trait_id in world_traits:
		var tid: String = str(trait_id).to_lower() if trait_id is String \
			else str(trait_id.get("id", "")).to_lower()
		match tid:
			"overgrown":
				# "Add 1D6+2 individual plant features" (Core Rules p.73)
				var plant_count: int = local_rng.randi_range(1, 6) + 2
				for pi: int in range(plant_count):
					var target: String = str(sector_labels[
						local_rng.randi_range(0, sector_labels.size() - 1)])
					sector_features[target].append(
						"SMALL: Vegetation (world trait: Overgrown)")
			"warzone":
				# "Add 1D3 ruined buildings or craters" (Core Rules p.73)
				var ruin_count: int = local_rng.randi_range(1, 3)
				for ri: int in range(ruin_count):
					var target: String = str(sector_labels[
						local_rng.randi_range(0, sector_labels.size() - 1)])
					if local_rng.randi_range(0, 1) == 0:
						sector_features[target].append(
							"SMALL: Ruined building (world trait: Warzone)")
					else:
						sector_features[target].append(
							"SMALL: Crater (world trait: Warzone)")
			"haze":
				# "Visibility reduced to 1D6+8\"" (Core Rules p.73). World-trait
				# visibility is rolled at the START OF EACH CAMPAIGN TURN
				# (p.72 preamble) — NOT per round; that cadence belongs to the
				# Poor Visibility deployment condition (fixed 2026-07-02).
				notes.append(
					"Haze: Visibility reduced to 1D6+8\" "
					+ "(roll at the start of each campaign turn)")
			"gloom":
				# "Maximum visibility restricted to 1D6+6\"" (Core Rules p.74)
				notes.append("Gloom: Max visibility 1D6+6\"")
			"fog":
				# "All shots beyond 8\" are -1 to Hit" (Core Rules p.75)
				notes.append("Fog: All shots beyond 8\" are -1 to Hit")
			"barren":
				# "No plant features can be used" (Core Rules p.74)
				for label: String in sector_labels:
					var feats: Array = sector_features.get(label, [])
					var filtered: Array = []
					for feat in feats:
						var dominated: bool = false
						for kw: String in vegetation_keywords:
							if kw in str(feat).to_lower():
								dominated = true
								break
						if not dominated:
							filtered.append(feat)
					sector_features[label] = filtered
				notes.append("Barren: No plant features on battlefield")
			"flat":
				# "Do not place any hills or raised ground" (Core Rules p.75)
				for label: String in sector_labels:
					var feats: Array = sector_features.get(label, [])
					var filtered: Array = []
					for feat in feats:
						var dominated: bool = false
						for kw: String in elevation_keywords:
							if kw in str(feat).to_lower():
								dominated = true
								break
						if not dominated:
							filtered.append(feat)
					sector_features[label] = filtered
				notes.append("Flat: No hills or raised ground on battlefield")
			"crystals":
				# "Place 2D6 crystals on the battlefield" (Core Rules p.75)
				var crystal_count: int = local_rng.randi_range(1, 6) \
					+ local_rng.randi_range(1, 6)
				for ci: int in range(crystal_count):
					var target: String = str(sector_labels[
						local_rng.randi_range(0, sector_labels.size() - 1)])
					sector_features[target].append(
						"SMALL: Crystal formation (world trait: Crystals)")
			"frozen":
				# Movement modifier, not terrain (Core Rules p.75)
				notes.append(
					"Frozen: Dash slide — move 1D6\" straight, " \
					+ "collision = both Stunned + knocked 1\"")
			"reflective_dust":
				# Combat modifier (Core Rules p.75)
				notes.append(
					"Reflective Dust: Laser/Beam/Blast weapons " \
					+ "-1 to Hit beyond 9\"")
			"null_zone":
				# Equipment restriction (Core Rules p.75)
				notes.append(
					"Null Zone: No teleportation devices work")
	return notes

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

func _has_known_prefix(text: String) -> bool:
	## Check if a feature text starts with a recognized size/type prefix.
	for prefix: String in ["LARGE:", "SMALL:", "LINEAR:", "Scatter:", "HAZARD:", "NOTABLE:"]:
		if text.begins_with(prefix):
			return true
	return false

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

## Standard Terrain Set counts for a table size (Core Rules p.109).
func _standard_set_for_size(table_size_ft: float) -> Dictionary:
	var by_size: Dictionary = _compendium_data.get(
		"standard_terrain_set", {}).get("by_table_size", {})
	return by_size.get(BattlefieldGrid.table_size_json_key(table_size_ft), {})

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
