class_name EliteEnemySystem
extends Node

## EliteEnemySystem
##
## Manages elite enemies from Freelancer's Handbook DLC.
## Handles elite enemy generation, special abilities, and deployment.
##
## Usage:
##   var elite := EliteEnemySystem.get_elite_version("Mercenary")
##   var should_replace := EliteEnemySystem.should_replace_with_elite(enemy_type)
##   EliteEnemySystem.set_deployment_mode("mixed_squads")
##   var cost := EliteEnemySystem.get_deployment_cost(elite_enemy)

signal elite_enemy_deployed(elite_enemy: Dictionary)
signal elite_ability_triggered(elite_enemy: Dictionary, ability: Dictionary)

## Available elite enemy types (loaded from JSON)
var elite_enemies: Array = []

## Elite deployment rules
var deployment_rules: Dictionary = {}

## Current deployment mode
## Options: "standard_replacement", "elite_only_battles", "mixed_squads", "boss_battles"
var deployment_mode: String = "standard_replacement"

## Elite replacement rate (0.0 to 1.0)
## In standard mode, this is chance to replace standard enemy with elite
var elite_replacement_rate: float = 0.0

## Content filter for DLC checking
var content_filter: ContentFilter = null

func _ready() -> void:
	content_filter = ContentFilter.new()
	_load_elite_enemies()

## Load elite enemies from DLC data
func _load_elite_enemies() -> void:
	if not content_filter.is_content_type_available("elite_enemies"):
		push_warning("EliteEnemySystem: Freelancer's Handbook not available. Elite enemies disabled.")
		return

	var expansion_manager := get_node_or_null("/root/ExpansionManager")
	if not expansion_manager:
		push_error("EliteEnemySystem: ExpansionManager not found.")
		return

	var elite_data = expansion_manager.load_expansion_data("freelancers_handbook", "elite_enemies.json")
	if elite_data:
		if elite_data.has("elite_enemies"):
			elite_enemies = elite_data.elite_enemies
			print("EliteEnemySystem: Loaded %d elite enemy types." % elite_enemies.size())

		if elite_data.has("elite_enemy_deployment_rules"):
			deployment_rules = elite_data.elite_enemy_deployment_rules
			print("EliteEnemySystem: Loaded elite deployment rules.")
	else:
		push_error("EliteEnemySystem: Failed to load elite enemies data.")

## Get all available elite enemies
func get_all_elite_enemies() -> Array:
	return elite_enemies.duplicate()

## Get elite version of a standard enemy type
func get_elite_version(base_enemy_type: String) -> Dictionary:
	for elite in elite_enemies:
		if elite.get("enemy_type", "") == base_enemy_type:
			return elite
	return {}

## Get elite enemy by name
func get_elite_enemy(elite_name: String) -> Dictionary:
	for elite in elite_enemies:
		if elite.name == elite_name:
			return elite
	return {}

## Check if should replace standard enemy with elite version
func should_replace_with_elite(enemy_type: String) -> bool:
	# Check if elite version exists
	var elite_version := get_elite_version(enemy_type)
	if elite_version.is_empty():
		return false

	# Check deployment mode
	match deployment_mode:
		"elite_only_battles":
			return true # Always use elite
		"standard_replacement":
			return randf() < elite_replacement_rate
		"mixed_squads":
			# Use specific mixing rule (1 elite per 3 standard)
			return false # Handled by generate_mixed_squad()
		"boss_battles":
			return false # Boss battles use specific elite selection
		_:
			return false

## Generate enemy with possible elite replacement
func generate_enemy(base_enemy_type: String) -> Dictionary:
	if should_replace_with_elite(base_enemy_type):
		var elite := get_elite_version(base_enemy_type)
		if not elite.is_empty():
			print("EliteEnemySystem: Replaced %s with elite version: %s" % [base_enemy_type, elite.name])
			elite_enemy_deployed.emit(elite)
			return elite

	# Return standard enemy (would need to fetch from core enemy system)
	return {"enemy_type": base_enemy_type, "is_elite": false}

## Generate mixed squad (1 elite per 3 standard)
func generate_mixed_squad(enemy_type: String, total_count: int) -> Array:
	var squad := []

	# Calculate elite count (1 per 3 standard)
	var elite_count := int(floor(total_count / 3.0))
	var standard_count := total_count - elite_count

	# Add elite enemies
	var elite_version := get_elite_version(enemy_type)
	for i in range(elite_count):
		if not elite_version.is_empty():
			squad.append(elite_version.duplicate(true))
			elite_enemy_deployed.emit(elite_version)

	# Add standard enemies
	for i in range(standard_count):
		squad.append({"enemy_type": enemy_type, "is_elite": false})

	return squad

## Generate boss battle (single elite with boosted stats)
func generate_boss_enemy(enemy_type: String, deployment_points: int) -> Dictionary:
	var elite := get_elite_version(enemy_type)
	if elite.is_empty():
		# If no elite version, use random elite
		if elite_enemies.size() > 0:
			elite = elite_enemies[randi() % elite_enemies.size()].duplicate(true)

	if elite.is_empty():
		push_error("EliteEnemySystem: No elite enemies available for boss battle.")
		return {}

	# Boss battles get +50% to stats
	var boss := elite.duplicate(true)
	boss.is_boss = true
	boss.toughness = int(ceil(boss.get("toughness", 3) * 1.5))

	# Parse and boost combat skill
	var combat_skill := _parse_combat_skill(boss.get("combat_skill", "+0"))
	combat_skill = int(ceil(combat_skill * 1.5))
	boss.combat_skill = "+%d" % combat_skill if combat_skill >= 0 else str(combat_skill)

	print("EliteEnemySystem: Generated boss enemy: %s (Toughness: %d, Combat: %s)" % [
		boss.name, boss.toughness, boss.combat_skill
	])

	elite_enemy_deployed.emit(boss)
	return boss

## Get deployment point cost for elite enemy
func get_deployment_cost(elite_enemy: Dictionary) -> int:
	return elite_enemy.get("deployment_points", 3)

## Calculate total deployment points for elite squad
func calculate_elite_deployment_points(enemies: Array) -> int:
	var total := 0
	for enemy in enemies:
		if enemy.get("is_elite", false) or elite_enemies.any(func(e): return e.name == enemy.get("name", "")):
			total += get_deployment_cost(enemy)
		else:
			total += 1 # Standard enemy cost
	return total

## Set deployment mode
func set_deployment_mode(mode: String) -> void:
	if mode in ["standard_replacement", "elite_only_battles", "mixed_squads", "boss_battles"]:
		deployment_mode = mode
		print("EliteEnemySystem: Deployment mode set to '%s'." % mode)
	else:
		push_error("EliteEnemySystem: Invalid deployment mode '%s'." % mode)

## Set elite replacement rate (for standard_replacement mode)
func set_replacement_rate(rate: float) -> void:
	elite_replacement_rate = clamp(rate, 0.0, 1.0)
	print("EliteEnemySystem: Elite replacement rate set to %.1f%%." % (elite_replacement_rate * 100))

## Get elite enemy special abilities
func get_special_abilities(elite_enemy: Dictionary) -> Array:
	return elite_enemy.get("special_abilities", [])

## Trigger elite ability
func trigger_ability(elite_enemy: Dictionary, ability_name: String, context: Dictionary = {}) -> void:
	var abilities := get_special_abilities(elite_enemy)

	for ability in abilities:
		if ability.get("name", "") == ability_name:
			print("EliteEnemySystem: Triggering ability '%s' for %s: %s" % [
				ability_name, elite_enemy.get("name", "Unknown"), ability.get("effect", "")
			])
			elite_ability_triggered.emit(elite_enemy, ability)
			_apply_ability_effect(elite_enemy, ability, context)
			return

	push_warning("EliteEnemySystem: Ability '%s' not found for %s." % [ability_name, elite_enemy.get("name", "Unknown")])

## Check if elite has specific ability
func has_ability(elite_enemy: Dictionary, ability_name: String) -> bool:
	var abilities := get_special_abilities(elite_enemy)
	for ability in abilities:
		if ability.get("name", "") == ability_name:
			return true
	return false

## Get all elite enemies of a specific type
func get_elites_by_type(enemy_type: String) -> Array:
	var matching := []
	for elite in elite_enemies:
		if elite.get("enemy_type", "") == enemy_type:
			matching.append(elite)
	return matching

## Get elite enemies by deployment point cost
func get_elites_by_cost(min_cost: int, max_cost: int) -> Array:
	var matching := []
	for elite in elite_enemies:
		var cost := get_deployment_cost(elite)
		if cost >= min_cost and cost <= max_cost:
			matching.append(elite)
	return matching

## Get deployment point multiplier for elite-only battles
func get_elite_only_multiplier() -> float:
	return 1.5 # Elite-only battles multiply deployment points by 1.5x

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _parse_combat_skill(skill_string: String) -> int:
	if skill_string.begins_with("+"):
		return int(skill_string.substr(1))
	else:
		return int(skill_string)

func _apply_ability_effect(elite_enemy: Dictionary, ability: Dictionary, context: Dictionary) -> void:
	# Simplified ability effect application
	# Full implementation would integrate with combat system

	var ability_name := ability.get("name", "")

	match ability_name:
		"Combat Veteran":
			print("EliteEnemySystem: Combat Veteran allows re-roll of one missed attack.")
		"Tactical Positioning":
			print("EliteEnemySystem: Tactical Positioning grants 2\" move after ranged attack.")
		"Heavy Armor":
			if elite_enemy is Dictionary:
				elite_enemy.armor_save = 4
		"Fearless":
			if elite_enemy is Dictionary:
				elite_enemy.ignores_morale = true
		"Leadership":
			print("EliteEnemySystem: Leadership grants +1 to hit for nearby allies.")
		"Pack Leader":
			print("EliteEnemySystem: Pack Leader allows nearby allies to re-roll initiative.")
		"Psionic Powers":
			print("EliteEnemySystem: Psionic Adept uses psionic powers (requires Trailblazer's Toolkit).")
		_:
			print("EliteEnemySystem: Ability effect for '%s' not implemented." % ability_name)
