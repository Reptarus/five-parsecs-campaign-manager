@tool
class_name CombatLootIntegration
extends RefCounted

## Combat-Loot Integration System for Five Parsecs Campaign Manager
##
## Integrates combat resolution with loot generation and economic processing,
## creating a seamless post-battle experience that leverages all systems.

const EnemyLootGenerator = preload("res://src/game/economy/loot/EnemyLootGenerator.gd")
const LootEconomyIntegrator = preload("res://src/game/economy/loot/LootEconomyIntegrator.gd")
const GameItem = preload("res://src/core/economy/loot/GameItem.gd")
const BattleTracker = preload("res://src/core/battle/BattleTracker.gd")

# Define Enemy type for type safety
class Enemy:
	extends RefCounted
	var _max_health: int = 10
	var _enemy_type: String = "generic"
	
	func get_enemy_type() -> String:
		return _enemy_type

# Integration components
var loot_generator: EnemyLootGenerator
var economy_integrator: LootEconomyIntegrator
var battle_tracker: BattleTracker

# Post-battle processing configuration
@export var auto_process_loot: bool = true
@export var apply_tactical_bonuses: bool = true
@export var track_combat_statistics: bool = true

# Integration signals
signal post_battle_processing_complete(results: Dictionary)
signal loot_distribution_ready(crew_shares: Dictionary)
signal combat_experience_gained(experience_data: Dictionary)
signal mission_rewards_calculated(total_rewards: Dictionary)

func _init() -> void:
	loot_generator = EnemyLootGenerator.new()
	economy_integrator = LootEconomyIntegrator.new()
	battle_tracker = BattleTracker.new()
	
	# Connect subsystem signals
	_connect_subsystem_signals()

## Process complete post-battle sequence
func process_post_battle(battle_result: Dictionary, mission_context: Dictionary = {}) -> Dictionary:
	var processing_result: Dictionary = {
		"battle_summary": {},
		"loot_generated": {},
		"economic_impact": {},
		"crew_rewards": {},
		"experience_gained": {},
		"mission_completion": {},
		"next_actions": []
	}
	
	# Extract battle data
	var defeated_enemies: Array[Enemy] = battle_result.get("defeated_enemies", [])
	var battle_conditions: Dictionary = battle_result.get("conditions", {})
	var crew_performance: Dictionary = battle_result.get("crew_performance", {})
	
	# Generate battle summary
	processing_result.battle_summary = _generate_battle_summary(battle_result, mission_context)
	
	# Process loot generation
	if defeated_enemies.size() > 0:
		processing_result.loot_generated = _process_battle_loot_generation(
			defeated_enemies,
			battle_conditions,
			mission_context
		)
		
		# Integrate with economy
		processing_result.economic_impact = _process_economic_integration(
			processing_result.loot_generated,
			mission_context
		)
	
	# Calculate crew rewards and experience
	processing_result.crew_rewards = _calculate_crew_rewards(
		processing_result.loot_generated,
		crew_performance,
		mission_context
	)
	
	processing_result.experience_gained = _calculate_experience_rewards(
		battle_result,
		mission_context
	)
	
	# Mission completion processing
	processing_result.mission_completion = _process_mission_completion(
		battle_result,
		mission_context
	)
	
	# Determine next actions
	processing_result.next_actions = _determine_next_actions(processing_result, mission_context)
	
	post_battle_processing_complete.emit(processing_result)
	return processing_result

## Generate loot with tactical performance bonuses
func generate_enhanced_loot(defeated_enemies: Array[Enemy], tactical_performance: Dictionary) -> Dictionary:
	var enhanced_context: Dictionary = {
		"tactical_bonuses": _calculate_tactical_bonuses(tactical_performance),
		"crew_skill_bonuses": tactical_performance.get("crew_skills", {}),
		"battle_conditions": tactical_performance.get("battle_conditions", {})
	}
	
	# Generate base loot - cast to generic Array for compatibility
	var enemy_array: Array = []
	for enemy in defeated_enemies:
		enemy_array.append(enemy)
	var base_loot = loot_generator.generate_battle_loot(enemy_array, enhanced_context)
	
	# Apply tactical bonuses
	var enhanced_loot = _apply_tactical_bonuses(base_loot, enhanced_context)
	
	return enhanced_loot

## Process crew experience and advancement
func process_combat_experience(battle_result: Dictionary, crew_data: Dictionary) -> Dictionary:
	var experience_result: Dictionary = {
		"individual_experience": {},
		"crew_bonuses": {},
		"skill_advancements": {},
		"reputation_changes": {},
		"relationship_impacts": {}
	}
	
	var enemies_defeated: Array[Enemy] = battle_result.get("defeated_enemies", [])
	var battle_duration: int = battle_result.get("turn_count", 5)
	var victory_type: String = battle_result.get("victory_type", "standard")
	
	# Calculate base experience
	var base_experience: int = _calculate_base_experience(enemies_defeated, battle_duration)
	
	# Individual crew member experience
	for crew_member in crew_data.get("active_crew", []):
		var member_experience: Dictionary = _calculate_member_experience(
			crew_member,
			battle_result,
			base_experience
		)
		experience_result.individual_experience[crew_member.get("id", "")] = member_experience
	
	# Crew-wide bonuses
	experience_result.crew_bonuses = _calculate_crew_bonuses(battle_result, victory_type)
	
	# Check for skill advancements
	experience_result.skill_advancements = _check_skill_advancements(
		experience_result.individual_experience
	)
	
	# Reputation changes
	experience_result.reputation_changes = _calculate_reputation_changes(
		battle_result,
		enemies_defeated
	)
	
	combat_experience_gained.emit(experience_result)
	return experience_result

## Calculate mission completion rewards
func calculate_mission_rewards(mission_data: Dictionary, battle_results: Array[Dictionary]) -> Dictionary:
	var mission_rewards: Dictionary = {
		"base_payment": 0,
		"performance_bonuses": {},
		"completion_bonuses": {},
		"patron_relationship": {},
		"story_progression": {},
		"total_value": 0
	}
	
	# Base mission payment
	mission_rewards.base_payment = mission_data.get("base_payment", 1000)
	
	# Performance evaluation
	var performance_score: float = _evaluate_mission_performance(battle_results, mission_data)
	mission_rewards.performance_bonuses = _calculate_performance_bonuses(performance_score, mission_data)
	
	# Completion bonuses
	var completion_type: String = mission_data.get("completion_status", "partial")
	mission_rewards.completion_bonuses = _calculate_completion_bonuses(completion_type, mission_data)
	
	# Patron relationship impacts
	mission_rewards.patron_relationship = _calculate_patron_relationship_changes(
		performance_score,
		mission_data
	)
	
	# Story progression rewards
	mission_rewards.story_progression = _calculate_story_progression_rewards(mission_data)
	
	# Calculate total value
	mission_rewards.total_value = _calculate_total_mission_value(mission_rewards)
	
	mission_rewards_calculated.emit(mission_rewards)
	return mission_rewards

## Distribute loot among crew members
func distribute_crew_loot(loot_data: Dictionary, crew_data: Dictionary, distribution_method: String = "equal") -> Dictionary:
	var distribution_result: Dictionary = {
		"individual_shares": {},
		"crew_fund_contribution": 0,
		"special_allocations": {},
		"distribution_method": distribution_method
	}
	
	var total_credits: int = loot_data.get("total_credits", 0)
	var valuable_items: Array[GameItem] = loot_data.get("rare_items", [])
	var crew_size: int = crew_data.get("active_crew", []).size()
	
	match distribution_method:
		"equal":
			distribution_result = _distribute_equal_shares(total_credits, valuable_items, crew_size)
		
		"merit_based":
			distribution_result = _distribute_merit_based(
				total_credits,
				valuable_items,
				crew_data,
				loot_data.get("battle_performance", {})
			)
		
		"specialist_priority":
			distribution_result = _distribute_specialist_priority(
				total_credits,
				valuable_items,
				crew_data,
				loot_data.get("specialized_loot", [])
			)
		
		"captain_decides":
			distribution_result = _distribute_captain_allocation(
				total_credits,
				valuable_items,
				crew_data
			)
	
	loot_distribution_ready.emit(distribution_result)
	return distribution_result

## Private Methods

func _connect_subsystem_signals() -> void:
	# Connect loot generator signals
	loot_generator.loot_generated.connect(_on_loot_generated)
	loot_generator.rare_loot_found.connect(_on_rare_loot_found)
	
	# Connect economy integrator signals
	economy_integrator.loot_processed.connect(_on_loot_processed)
	economy_integrator.contraband_detected.connect(_on_contraband_detected)

func _generate_battle_summary(battle_result: Dictionary, mission_context: Dictionary) -> Dictionary:
	var summary: Dictionary = {
		"enemy_types_faced": [],
		"total_enemies_defeated": 0,
		"battle_duration": 0,
		"casualties_taken": 0,
		"tactical_performance": "standard",
		"environmental_factors": [],
		"notable_events": []
	}
	
	var defeated_enemies: Array[Enemy] = battle_result.get("defeated_enemies", [])
	summary.total_enemies_defeated = defeated_enemies.size()
	
	# Analyze enemy types
	var enemy_types: Array[String] = []
	for enemy in defeated_enemies:
		var enemy_type: String = enemy.get_script().get_global_name()
		if enemy_type not in enemy_types:
			enemy_types.append(enemy_type)
	summary.enemy_types_faced = enemy_types
	
	# Battle metrics
	summary.battle_duration = battle_result.get("turn_count", 0)
	summary.casualties_taken = battle_result.get("crew_casualties", 0)
	
	# Tactical performance assessment
	summary.tactical_performance = _assess_tactical_performance(battle_result)
	
	return summary

func _process_battle_loot_generation(enemies: Array[Enemy], conditions: Dictionary, context: Dictionary) -> Dictionary:
	# Enhance context with battle conditions
	var enhanced_context: Dictionary = context.duplicate()
	enhanced_context.merge(conditions)
	
	# Generate loot - cast to generic Array for compatibility
	var enemy_array: Array = []
	for enemy in enemies:
		enemy_array.append(enemy)
	var battle_loot: Dictionary = loot_generator.generate_battle_loot(enemy_array, enhanced_context)
	
	# Apply any post-generation modifications
	battle_loot = _apply_battle_condition_modifiers(battle_loot, conditions)
	
	return battle_loot

func _process_economic_integration(loot_data: Dictionary, context: Dictionary) -> Dictionary:
	# Process loot through economy system
	var economic_result: Dictionary = economy_integrator.process_battle_loot(loot_data, context)
	
	# Track market impacts
	var items_for_market: Array[GameItem] = loot_data.get("combined_items", [])
	economy_integrator.update_market_demand(items_for_market, context.get("location", ""))
	
	return economic_result

func _calculate_crew_rewards(loot_data: Dictionary, performance: Dictionary, context: Dictionary) -> Dictionary:
	var rewards: Dictionary = {
		"credits_per_member": 0,
		"bonus_allocations": {},
		"equipment_claims": {},
		"special_rewards": {}
	}
	
	var total_credits: int = loot_data.get("total_credits", 0)
	var crew_size: int = context.get("crew_size", 4)
	
	# Base credit distribution
	rewards.credits_per_member = total_credits / crew_size if crew_size > 0 else total_credits
	
	# Performance bonuses
	var performance_multiplier: float = _calculate_performance_multiplier(performance)
	rewards.credits_per_member = roundi(rewards.credits_per_member * performance_multiplier)
	
	return rewards

func _calculate_experience_rewards(battle_result: Dictionary, context: Dictionary) -> Dictionary:
	var experience: Dictionary = {
		"base_experience": 0,
		"combat_experience": 0,
		"tactical_experience": 0,
		"specialization_experience": {},
		"milestone_bonuses": {}
	}
	
	var enemies_defeated: Array[Enemy] = battle_result.get("defeated_enemies", [])
	
	# Base experience from enemy difficulty
	for enemy in enemies_defeated:
		experience.base_experience += maxi(enemy._max_health / 15, 1)
	
	# Combat experience from battle conditions
	var battle_difficulty: int = battle_result.get("difficulty_rating", 3)
	experience.combat_experience = battle_difficulty * 10
	
	# Tactical bonuses
	var tactical_score: int = battle_result.get("tactical_score", 0)
	experience.tactical_experience = tactical_score * 5
	
	return experience

func _process_mission_completion(battle_result: Dictionary, context: Dictionary) -> Dictionary:
	var completion: Dictionary = {
		"status": "in_progress",
		"objectives_completed": [],
		"bonus_objectives": [],
		"mission_complications": [],
		"next_phase": ""
	}
	
	# Determine completion status based on battle outcome
	var victory: bool = battle_result.get("victory", false)
	var objectives: Array = context.get("mission_objectives", [])
	
	if victory:
		completion.status = "phase_complete"
		completion.objectives_completed = objectives.duplicate()
	
	return completion

func _determine_next_actions(processing_result: Dictionary, context: Dictionary) -> Array[String]:
	var actions: Array[String] = []
	
	# Based on mission status
	var mission_status: String = processing_result.mission_completion.get("status", "")
	if mission_status == "phase_complete":
		actions.append("proceed_to_next_phase")
	elif mission_status == "mission_complete":
		actions.append("return_to_patron")
	
	# Based on loot
	var contraband_items: Array = processing_result.loot_generated.get("contraband_items", [])
	if contraband_items.size() > 0:
		actions.append("find_contraband_buyer")
	
	# Based on crew condition
	var casualties: int = processing_result.battle_summary.get("casualties_taken", 0)
	if casualties > 0:
		actions.append("seek_medical_treatment")
	
	return actions

func _calculate_tactical_bonuses(performance: Dictionary) -> Dictionary:
	var bonuses: Dictionary = {
		"coordination_bonus": 0.0,
		"efficiency_bonus": 0.0,
		"minimal_casualties_bonus": 0.0,
		"speed_bonus": 0.0
	}
	
	# Coordination bonus
	var coordination_score: int = performance.get("coordination", 3)
	bonuses.coordination_bonus = (coordination_score - 3) * 0.1
	
	# Efficiency bonus
	var turns_taken: int = performance.get("turns_taken", 10)
	var expected_turns: int = performance.get("expected_turns", 10)
	if turns_taken < expected_turns:
		bonuses.efficiency_bonus = 0.2
	
	return bonuses

func _apply_tactical_loot_bonuses(loot: Dictionary, bonuses: Dictionary) -> Dictionary:
	var enhanced_loot: Dictionary = loot.duplicate()
	
	# Apply coordination bonus to item quality
	var coordination_bonus: float = bonuses.get("coordination_bonus", 0.0)
	if coordination_bonus > 0.0:
		var items: Array[GameItem] = enhanced_loot.get("combined_items", [])
		for item in items:
			if randf() < coordination_bonus:
				item.quality = mini(item.quality + 1, 5) # MASTERWORK = 5 (integer value)
	
	# Apply efficiency bonus to credits
	var efficiency_bonus: float = bonuses.get("efficiency_bonus", 0.0)
	if efficiency_bonus > 0.0:
		var credits: int = enhanced_loot.get("total_credits", 0)
		enhanced_loot["total_credits"] = roundi(credits * (1.0 + efficiency_bonus))
	
	return enhanced_loot

func _assess_tactical_performance(battle_result: Dictionary) -> String:
	var score: int = 0
	
	# Factors that improve performance
	if battle_result.get("victory", false):
		score += 2
	
	var casualties: int = battle_result.get("crew_casualties", 0)
	if casualties == 0:
		score += 2
	elif casualties == 1:
		score += 1
	
	var turn_efficiency: float = battle_result.get("turn_efficiency", 1.0)
	if turn_efficiency > 1.2:
		score += 1
	
	# Return assessment
	if score >= 4:
		return "excellent"
	elif score >= 2:
		return "good"
	elif score >= 0:
		return "standard"
	else:
		return "poor"

func _calculate_base_experience(enemies: Array[Enemy], battle_duration: int) -> int:
	var base_exp: int = 0
	
	for enemy in enemies:
		base_exp += maxi(enemy._max_health / 15, 1)
	
	# Duration modifier
	if battle_duration <= 3:
		base_exp = roundi(base_exp * 1.2)
	elif battle_duration >= 8:
		base_exp = roundi(base_exp * 0.8)
	
	return base_exp

func _calculate_member_experience(member: Dictionary, battle_result: Dictionary, base_exp: int) -> Dictionary:
	var member_exp: Dictionary = {
		"combat_experience": base_exp,
		"specialization_experience": 0,
		"leadership_experience": 0,
		"survival_experience": 0
	}
	
	# Role-based bonuses
	var role: String = member.get("role", "crew")
	match role:
		"captain":
			member_exp.leadership_experience = roundi(base_exp * 0.5)
		"medic":
			if battle_result.get("casualties_treated", 0) > 0:
				member_exp.specialization_experience = roundi(base_exp * 0.3)
		"engineer":
			if battle_result.get("equipment_used", false):
				member_exp.specialization_experience = roundi(base_exp * 0.3)
	
	return member_exp

func _distribute_equal_shares(credits: int, items: Array[GameItem], crew_size: int) -> Dictionary:
	var result: Dictionary = {
		"individual_shares": {},
		"crew_fund_contribution": 0,
		"credits_per_member": 0
	}
	
	if crew_size > 0:
		result.credits_per_member = credits / crew_size
		
		# Distribute items randomly
		for i in range(items.size()):
			var member_index: int = i % crew_size
			if not result.individual_shares.has(member_index):
				result.individual_shares[member_index] = []
			result.individual_shares[member_index].append(items[i])
	
	return result

# Signal handlers
func _on_loot_generated(loot_items: Array[GameItem], total_value: int) -> void:
	if track_combat_statistics:
		battle_tracker.record_loot_generation(loot_items, total_value)

func _on_rare_loot_found(item: GameItem, enemy_type: String) -> void:
	# Handle rare loot discovery
	pass

func _on_loot_processed(processed_items: Array[GameItem], market_value: int) -> void:
	# Handle economic processing completion
	pass

func _on_contraband_detected(item: GameItem, heat_increase: int) -> void:
	# Handle contraband detection
	pass

func _calculate_crew_bonuses(battle_result: Dictionary, victory_type: String) -> Dictionary:
	# Stub implementation
	return {}

func _check_skill_advancements(individual_experience: Dictionary) -> Array[Dictionary]:
	# Stub implementation
	return []

func _calculate_reputation_changes(battle_result: Dictionary, enemies_defeated: Array[Enemy]) -> Dictionary:
	# Stub implementation
	return {}

func _evaluate_mission_performance(battle_results: Array[Dictionary], mission_data: Dictionary) -> float:
	# Stub implementation
	return 0.5

func _calculate_performance_bonuses(performance_score: float, mission_data: Dictionary) -> Dictionary:
	# Stub implementation
	return {}

func _calculate_completion_bonuses(completion_type: String, mission_data: Dictionary) -> Dictionary:
	# Stub implementation
	return {}

func _calculate_patron_relationship_changes(performance_score: float, mission_data: Dictionary) -> Dictionary:
	# Stub implementation
	return {}

func _calculate_story_progression_rewards(mission_data: Dictionary) -> Dictionary:
	# Stub implementation
	return {}

func _calculate_total_mission_value(mission_rewards: Dictionary) -> int:
	# Stub implementation
	return 0

func _distribute_merit_based(total_credits: int, valuable_items: Array, crew_data: Dictionary, battle_performance: Dictionary) -> Dictionary:
	# Distribute based on individual crew performance
	var distribution_result: Dictionary = {
		"individual_shares": {},
		"distribution_method": "merit_based",
		"performance_bonuses": {}
	}
	
	# Calculate individual merit scores
	for crew_member in crew_data.get("crew_members", []):
		var merit_score: float = _calculate_individual_merit(crew_member, battle_performance)
		var share: int = roundi(total_credits * merit_score)
		distribution_result.individual_shares[crew_member.get("name", "Unknown")] = share
	
	return distribution_result

func _distribute_specialist_priority(total_credits: int, valuable_items: Array, crew_data: Dictionary, specialized_loot: Array) -> Dictionary:
	# Prioritize specialists for relevant equipment
	var distribution_result: Dictionary = {
		"individual_shares": {},
		"distribution_method": "specialist_priority",
		"specialist_assignments": {}
	}
	
	# Base share for all crew
	var base_share: int = total_credits / maxf(crew_data.get("crew_members", []).size(), 1)
	
	for crew_member in crew_data.get("crew_members", []):
		distribution_result.individual_shares[crew_member.get("name", "Unknown")] = base_share
	
	return distribution_result

func _apply_tactical_bonuses(base_loot: Dictionary, enhanced_context: Dictionary) -> Dictionary:
	var enhanced_loot: Dictionary = base_loot.duplicate()
	var tactical_bonuses: Dictionary = enhanced_context.get("tactical_bonuses", {})
	
	# Apply coordination bonus to item quality
	if tactical_bonuses.has("coordination_bonus"):
		var coordination_bonus: float = tactical_bonuses.coordination_bonus
		var items: Array = enhanced_loot.get("items", [])
		for item in items:
			if randf() < coordination_bonus:
				item.quality = mini(item.quality + 1, 5) # MASTERWORK = 5 (integer value)
	
	# Apply efficiency bonus to credits
	if tactical_bonuses.has("efficiency_bonus"):
		var efficiency_bonus: float = tactical_bonuses.efficiency_bonus
		var current_credits: int = enhanced_loot.get("total_credits", 0)
		enhanced_loot.total_credits = roundi(current_credits * (1.0 + efficiency_bonus))
	
	return enhanced_loot

func _calculate_individual_merit(crew_member: Dictionary, battle_performance: Dictionary) -> float:
	# Calculate individual merit score (0.0 to 1.0)
	var base_merit: float = 0.25 # Base share
	
	# Add performance bonuses
	var crew_name: String = crew_member.get("name", "Unknown")
	var individual_performance: Dictionary = battle_performance.get("individual_performance", {})
	
	if individual_performance.has(crew_name):
		var performance: Dictionary = individual_performance[crew_name]
		base_merit += performance.get("damage_dealt", 0) * 0.01
		base_merit += performance.get("enemies_defeated", 0) * 0.1
		base_merit -= performance.get("damage_taken", 0) * 0.005
	
	return clampf(base_merit, 0.1, 0.5) # Ensure reasonable range

func _distribute_captain_allocation(total_credits: int, valuable_items: Array, crew_data: Dictionary) -> Dictionary:
	# Stub implementation
	return {}

func _apply_battle_condition_modifiers(battle_loot: Dictionary, conditions: Dictionary) -> Dictionary:
	# Stub implementation
	return battle_loot

func _calculate_performance_multiplier(performance: Dictionary) -> float:
	# Stub implementation
	return 1.0