class_name DifficultyScalingSystem
extends Node

## DifficultyScalingSystem
##
## Manages difficulty modifiers from Freelancer's Handbook DLC.
## Applies modifiers to enemy stats, battle conditions, rewards, and campaign pressure.
##
## Usage:
##   DifficultyScalingSystem.set_difficulty_preset("challenging")
##   DifficultyScalingSystem.enable_modifier("Brutal Foes")
##   var modified_enemy := DifficultyScalingSystem.apply_to_enemy(base_enemy)
##   var deployment_points := DifficultyScalingSystem.modify_deployment_points(base_points)

signal difficulty_changed(preset_name: String)
signal modifier_enabled(modifier_name: String)
signal modifier_disabled(modifier_name: String)
signal difficulty_stats_updated(stats: Dictionary)

## Available difficulty modifiers (loaded from JSON)
var difficulty_modifiers: Array = []

## Available difficulty presets
var difficulty_presets: Dictionary = {}

## Currently active modifiers (by name)
var active_modifiers: Array = []

## Current difficulty preset
var current_preset: String = "standard"

## Progressive difficulty settings
var progressive_difficulty_enabled: bool = false
var progressive_difficulty_rules: Array = []

## Adaptive difficulty settings
var adaptive_difficulty_enabled: bool = false
var adaptive_difficulty_rules: Array = []

## Campaign statistics for adaptive difficulty
var campaign_stats := {
	"consecutive_victories": 0,
	"consecutive_defeats": 0,
	"crew_deaths": 0,
	"credits": 0
}

## Content filter for DLC checking
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()
	_load_difficulty_data()

## Load difficulty modifiers and presets from DLC data
func _load_difficulty_data() -> void:
	if not content_filter.is_content_type_available("difficulty_modifiers"):
		push_warning("DifficultyScalingSystem: Freelancer's Handbook not available. Difficulty modifiers disabled.")
		return

	var expansion_manager := get_node_or_null("/root/ExpansionManager")
	if not expansion_manager:
		push_error("DifficultyScalingSystem: ExpansionManager not found.")
		return

	var difficulty_data = expansion_manager.load_expansion_data("freelancers_handbook", "difficulty_modifiers.json")
	if difficulty_data:
		if difficulty_data.has("difficulty_modifiers"):
			difficulty_modifiers = difficulty_data.difficulty_modifiers
			print("DifficultyScalingSystem: Loaded %d difficulty modifiers." % difficulty_modifiers.size())

		if difficulty_data.has("difficulty_presets"):
			difficulty_presets = difficulty_data.difficulty_presets
			print("DifficultyScalingSystem: Loaded %d difficulty presets." % difficulty_presets.size())

		if difficulty_data.has("difficulty_scaling"):
			var scaling := difficulty_data.difficulty_scaling
			if scaling.has("progressive_difficulty"):
				var progressive := scaling.progressive_difficulty
				progressive_difficulty_enabled = progressive.get("enabled", false)
				progressive_difficulty_rules = progressive.get("scaling_rules", [])

			if scaling.has("adaptive_difficulty"):
				var adaptive := scaling.adaptive_difficulty
				adaptive_difficulty_enabled = adaptive.get("enabled", false)
				adaptive_difficulty_rules = adaptive.get("rules", [])
	else:
		push_error("DifficultyScalingSystem: Failed to load difficulty data.")

## Set difficulty using a preset
func set_difficulty_preset(preset_name: String) -> void:
	if not difficulty_presets.has(preset_name):
		push_error("DifficultyScalingSystem: Unknown preset '%s'." % preset_name)
		return

	var preset: Dictionary = difficulty_presets[preset_name]
	current_preset = preset_name

	# Clear current modifiers
	active_modifiers.clear()

	# Enable preset modifiers
	if preset.has("active_modifiers"):
		for modifier_name in preset.active_modifiers:
			enable_modifier(modifier_name)

	print("DifficultyScalingSystem: Set difficulty to '%s' preset." % preset_name)
	difficulty_changed.emit(preset_name)
	_emit_difficulty_stats()

## Enable a specific difficulty modifier
func enable_modifier(modifier_name: String) -> void:
	if modifier_name in active_modifiers:
		push_warning("DifficultyScalingSystem: Modifier '%s' already enabled." % modifier_name)
		return

	var modifier := get_modifier(modifier_name)
	if modifier.is_empty():
		push_error("DifficultyScalingSystem: Unknown modifier '%s'." % modifier_name)
		return

	# Check if modifier is stackable
	if not modifier.get("stackable", false):
		# Check if another modifier of same category is active
		for active_mod_name in active_modifiers:
			var active_mod := get_modifier(active_mod_name)
			if active_mod.get("category", "") == modifier.get("category", ""):
				push_warning("DifficultyScalingSystem: Cannot enable '%s' - non-stackable modifier '%s' already active in category '%s'." % [
					modifier_name, active_mod_name, modifier.get("category", "")
				])
				return

	active_modifiers.append(modifier_name)
	print("DifficultyScalingSystem: Enabled modifier '%s'." % modifier_name)
	modifier_enabled.emit(modifier_name)
	_emit_difficulty_stats()

## Disable a specific difficulty modifier
func disable_modifier(modifier_name: String) -> void:
	if not modifier_name in active_modifiers:
		push_warning("DifficultyScalingSystem: Modifier '%s' not active." % modifier_name)
		return

	active_modifiers.erase(modifier_name)
	print("DifficultyScalingSystem: Disabled modifier '%s'." % modifier_name)
	modifier_disabled.emit(modifier_name)
	_emit_difficulty_stats()

## Get a specific modifier by name
func get_modifier(modifier_name: String) -> Dictionary:
	for modifier in difficulty_modifiers:
		if modifier.name == modifier_name:
			return modifier
	return {}

## Get all active modifiers
func get_active_modifiers() -> Array:
	var modifiers := []
	for modifier_name in active_modifiers:
		var modifier := get_modifier(modifier_name)
		if not modifier.is_empty():
			modifiers.append(modifier)
	return modifiers

## Apply difficulty modifiers to an enemy
func apply_to_enemy(enemy: Dictionary) -> Dictionary:
	var modified_enemy := enemy.duplicate(true)

	for modifier_name in active_modifiers:
		var modifier := get_modifier(modifier_name)
		if modifier.is_empty():
			continue

		var changes: Dictionary = modifier.get("mechanical_changes", {})

		# Apply stat modifications
		if changes.has("enemy_toughness"):
			modified_enemy.toughness = modified_enemy.get("toughness", 3) + changes.enemy_toughness

		if changes.has("enemy_combat_skill"):
			var current_skill := _parse_combat_skill(modified_enemy.get("combat_skill", "+0"))
			var new_skill := current_skill + changes.enemy_combat_skill
			modified_enemy.combat_skill = "+%d" % new_skill if new_skill >= 0 else str(new_skill)

		if changes.has("elite_replacement_rate"):
			# Mark that this enemy could be replaced with elite version
			modified_enemy.elite_replacement_chance = changes.elite_replacement_rate

	return modified_enemy

## Modify deployment points based on active modifiers
func modify_deployment_points(base_points: int) -> int:
	var modified_points := float(base_points)

	for modifier_name in active_modifiers:
		var modifier := get_modifier(modifier_name)
		if modifier.is_empty():
			continue

		var changes: Dictionary = modifier.get("mechanical_changes", {})

		if changes.has("deployment_points_multiplier"):
			modified_points *= changes.deployment_points_multiplier

	return int(ceil(modified_points))

## Modify loot/rewards based on active modifiers
func modify_rewards(base_credits: int, base_loot_rolls: int) -> Dictionary:
	var modified := {
		"credits": float(base_credits),
		"loot_rolls": base_loot_rolls
	}

	for modifier_name in active_modifiers:
		var modifier := get_modifier(modifier_name)
		if modifier.is_empty():
			continue

		var changes: Dictionary = modifier.get("mechanical_changes", {})

		if changes.has("loot_multiplier"):
			modified.credits *= changes.loot_multiplier
			# Also apply to loot rolls
			modified.loot_rolls = int(ceil(modified.loot_rolls * changes.loot_multiplier))

	modified.credits = int(ceil(modified.credits))
	return modified

## Modify injury rolls based on active modifiers
func modify_injury_roll(base_roll: int) -> int:
	var modified_roll := base_roll

	for modifier_name in active_modifiers:
		var modifier := get_modifier(modifier_name)
		if modifier.is_empty():
			continue

		var changes: Dictionary = modifier.get("mechanical_changes", {})

		if changes.has("injury_roll_modifier"):
			modified_roll += changes.injury_roll_modifier

	return modified_roll

## Modify critical hit damage based on active modifiers
func modify_critical_hit(base_damage: int) -> int:
	var modified_damage := base_damage

	for modifier_name in active_modifiers:
		var modifier := get_modifier(modifier_name)
		if modifier.is_empty():
			continue

		var changes: Dictionary = modifier.get("mechanical_changes", {})

		if changes.has("critical_hit_modifier"):
			modified_damage += changes.critical_hit_modifier

	return modified_damage

## Check for rival generation modifier
func get_rival_generation_modifier() -> int:
	var modifier_value := 0

	for modifier_name in active_modifiers:
		var modifier := get_modifier(modifier_name)
		if modifier.is_empty():
			continue

		var changes: Dictionary = modifier.get("mechanical_changes", {})

		if changes.has("rival_generation_modifier"):
			modifier_value += changes.rival_generation_modifier

	return modifier_value

## Process progressive difficulty (call each campaign turn)
func process_progressive_difficulty(current_turn: int) -> void:
	if not progressive_difficulty_enabled:
		return

	for rule in progressive_difficulty_rules:
		if rule.campaign_turn == current_turn:
			if rule.get("auto_enable", false):
				enable_modifier(rule.modifier)
				print("DifficultyScalingSystem: Progressive difficulty auto-enabled '%s' at turn %d." % [
					rule.modifier, current_turn
				])

## Process adaptive difficulty (call after battles)
func process_adaptive_difficulty() -> void:
	if not adaptive_difficulty_enabled:
		return

	# Example adaptive rules (simplified)
	# "After 3 consecutive victories, enable one random modifier"
	if campaign_stats.consecutive_victories >= 3:
		_enable_random_modifier()
		campaign_stats.consecutive_victories = 0

	# "After 2 crew deaths, disable one active modifier"
	if campaign_stats.crew_deaths >= 2 and active_modifiers.size() > 0:
		_disable_random_modifier()
		campaign_stats.crew_deaths = 0

	# "If credits exceed 50, enable 'Scarcity'"
	if campaign_stats.credits > 50:
		enable_modifier("Scarcity")

	# "If credits below 10, disable 'Scarcity'"
	if campaign_stats.credits < 10:
		disable_modifier("Scarcity")

## Update campaign statistics for adaptive difficulty
func update_campaign_stats(battle_result: String, crew_deaths: int, credits: int) -> void:
	match battle_result:
		"victory":
			campaign_stats.consecutive_victories += 1
			campaign_stats.consecutive_defeats = 0
		"defeat":
			campaign_stats.consecutive_defeats += 1
			campaign_stats.consecutive_victories = 0

	campaign_stats.crew_deaths += crew_deaths
	campaign_stats.credits = credits

	process_adaptive_difficulty()

## Get current difficulty statistics
func get_difficulty_stats() -> Dictionary:
	return {
		"preset": current_preset,
		"active_modifiers": active_modifiers.duplicate(),
		"modifier_count": active_modifiers.size(),
		"progressive_enabled": progressive_difficulty_enabled,
		"adaptive_enabled": adaptive_difficulty_enabled,
		"campaign_stats": campaign_stats.duplicate()
	}

## Enable progressive difficulty scaling
func enable_progressive_difficulty(enable: bool) -> void:
	progressive_difficulty_enabled = enable
	print("DifficultyScalingSystem: Progressive difficulty %s." % ("enabled" if enable else "disabled"))

## Enable adaptive difficulty scaling
func enable_adaptive_difficulty(enable: bool) -> void:
	adaptive_difficulty_enabled = enable
	print("DifficultyScalingSystem: Adaptive difficulty %s." % ("enabled" if enable else "disabled"))

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _parse_combat_skill(skill_string: String) -> int:
	if skill_string.begins_with("+"):
		return int(skill_string.substr(1))
	else:
		return int(skill_string)

func _enable_random_modifier() -> void:
	var available := []
	for modifier in difficulty_modifiers:
		if not modifier.name in active_modifiers:
			available.append(modifier.name)

	if available.size() > 0:
		var random_modifier := available[randi() % available.size()]
		enable_modifier(random_modifier)
		print("DifficultyScalingSystem: Adaptive difficulty enabled '%s'." % random_modifier)

func _disable_random_modifier() -> void:
	if active_modifiers.size() > 0:
		var random_modifier := active_modifiers[randi() % active_modifiers.size()]
		disable_modifier(random_modifier)
		print("DifficultyScalingSystem: Adaptive difficulty disabled '%s'." % random_modifier)

func _emit_difficulty_stats() -> void:
	difficulty_stats_updated.emit(get_difficulty_stats())
