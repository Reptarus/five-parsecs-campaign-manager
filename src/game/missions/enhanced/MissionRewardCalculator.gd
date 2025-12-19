@tool
class_name MissionRewardCalculator
extends RefCounted

## Mission Reward Calculation System for Five Parsecs Campaign Manager
##
## Calculates mission rewards based on difficulty, performance, and Five Parsecs rules.
## Integrates with existing reward data and provides dynamic bonus calculations.

# GlobalEnums available as autoload singleton
const MissionTypeRegistry = preload("res://src/game/missions/enhanced/MissionTypeRegistry.gd")
const MissionDifficultyScaler = preload("res://src/game/missions/enhanced/MissionDifficultyScaler.gd")
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")

# Reward data paths - loaded at runtime
const REWARDS_DATA_PATH: String = "res://data/mission_tables/mission_rewards.json"
static var _rewards_data: Dictionary = {}

# Performance multipliers based on mission completion quality
const PERFORMANCE_MULTIPLIERS: Dictionary = {
	"failed": 0.0,
	"partial": 0.5,
	"completed": 1.0,
	"exceptional": 1.3,
	"legendary": 1.5
}

# Patron relationship bonuses (Five Parsecs patron system)
const PATRON_RELATIONSHIP_BONUSES: Dictionary = {
	"hostile": 0.5,
	"neutral": 1.0,
	"friendly": 1.2,
	"loyal": 1.4,
	"devoted": 1.6
}

# Danger pay scaling (Five Parsecs core rule)
const DANGER_PAY_SCALING: Array[int] = [0, 100, 250, 500, 750, 1000]

## Load reward data if not already loaded
static func _ensure_rewards_data_loaded() -> void:
	if _rewards_data.is_empty():
		_rewards_data = _load_json_safe(REWARDS_DATA_PATH, "rewards_data")

## Safe JSON loading method (similar to DataManager)
static func _load_json_safe(file_path: String, context: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_warning("MissionRewardCalculator: Data file not found: " + file_path)
		return {}
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("MissionRewardCalculator: Failed to open file: " + file_path)
		return {}
	
	var text: String = file.get_as_text()
	file.close()
	
	if text.is_empty():
		return {}
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(text)
	
	if parse_result != OK:
		push_warning("MissionRewardCalculator: JSON Parse Error in " + file_path)
		return {}
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	
	return data as Dictionary

## Calculate complete mission rewards
static func calculate_mission_rewards(mission_context: Dictionary, performance_context: Dictionary) -> Dictionary:
	var rewards: Dictionary = {
		"credits": 0,
		"reputation": 0,
		"experience": 0,
		"items": [],
		"special_bonuses": [],
		"patron_standing": {}
	}
	
	# Calculate base credit reward
	rewards.credits = _calculate_base_credits(mission_context, performance_context)
	
	# Calculate reputation gain
	rewards.reputation = _calculate_reputation_gain(mission_context, performance_context)
	
	# Calculate experience points
	rewards.experience = _calculate_experience_gain(mission_context, performance_context)
	
	# Generate item rewards
	rewards.items = _generate_item_rewards(mission_context, performance_context)
	
	# Calculate special bonuses
	rewards.special_bonuses = _calculate_special_bonuses(mission_context, performance_context)
	
	# Update patron standing
	rewards.patron_standing = _calculate_patron_standing_changes(mission_context, performance_context)
	
	return rewards

## Calculate total credit value of rewards
static func get_total_credit_value(rewards: Dictionary) -> int:
	var total: int = rewards.get("credits", 0)
	
	# Add estimated item values
	for item in rewards.get("items", []):
		total += item.get("estimated_value", 0)
	
	# Add special bonus values
	for bonus in rewards.get("special_bonuses", []):
		total += bonus.get("credit_value", 0)
	
	return total

## Get reward quality assessment
static func assess_reward_quality(rewards: Dictionary, mission_difficulty: int) -> String:
	var total_value: int = get_total_credit_value(rewards)
	var expected_value: int = _get_expected_reward_value(mission_difficulty)
	
	var ratio: float = float(total_value) / float(expected_value)
	
	if ratio >= 1.5:
		return "Exceptional"
	elif ratio >= 1.2:
		return "Good"
	elif ratio >= 0.8:
		return "Fair"
	elif ratio >= 0.5:
		return "Poor"
	else:
		return "Terrible"

## Calculate danger pay bonus
static func calculate_danger_pay(base_pay: int, danger_level: int) -> int:
	if danger_level <= 0 or danger_level >= DANGER_PAY_SCALING.size():
		return 0
	
	var danger_bonus: int = DANGER_PAY_SCALING[danger_level]
	return mini(danger_bonus, base_pay) # Cap at base pay amount

## Calculate patron job bonus
static func calculate_patron_bonus(base_reward: int, patron_relationship: String, job_complexity: int) -> Dictionary:
	var bonus: Dictionary = {
		"credits": 0,
		"reputation": 0,
		"special_items": []
	}
	
	var relationship_multiplier: float = PATRON_RELATIONSHIP_BONUSES.get(patron_relationship, 1.0)
	
	# Credit bonus
	bonus.credits = roundi(base_reward * (relationship_multiplier - 1.0))
	
	# Reputation bonus
	bonus.reputation = roundi(job_complexity * relationship_multiplier)
	
	# Special items for high-relationship patrons
	if patron_relationship in ["loyal", "devoted"] and randf() < 0.3:
		bonus.special_items.append({
			"type": "patron_gift",
			"quality": "unique",
			"estimated_value": base_reward * roundi(relationship_multiplier)
		})
	
	return bonus

## Private Methods

static func _calculate_base_credits(mission_context: Dictionary, performance_context: Dictionary) -> int:
	var mission_type: int = mission_context.get("mission_type", 0)
	var difficulty: int = mission_context.get("difficulty", 1)
	var performance: String = performance_context.get("completion_quality", "completed")
	
	# Get base reward from mission type data
	var mission_data: Dictionary = MissionTypeRegistry.get_mission_type_data(mission_type)
	var base_credits: int = 200 # Five Parsecs standard base
	var difficulty_bonus: int = difficulty * 100
	var type_multiplier: float = mission_data.get("reward_multiplier", 1.0)
	
	# Calculate base amount
	var total_credits: int = roundi((base_credits + difficulty_bonus) * type_multiplier)
	
	# Apply performance multiplier
	var performance_multiplier: float = PERFORMANCE_MULTIPLIERS.get(performance, 1.0)
	total_credits = roundi(total_credits * performance_multiplier)
	
	# Add danger pay
	var danger_level: int = mission_context.get("danger_pay", 0)
	total_credits += calculate_danger_pay(total_credits, danger_level)
	
	# Apply patron bonus if applicable
	if mission_context.has("patron_relationship"):
		var patron_bonus: Dictionary = calculate_patron_bonus(
			total_credits,
			mission_context.get("patron_relationship", "neutral"),
			difficulty
		)
		total_credits += patron_bonus.credits

		# HOUSE RULE: wealthy_patrons - Patron missions pay 50% more credits
		if HouseRulesHelper.is_enabled("wealthy_patrons"):
			total_credits = roundi(total_credits * 1.5)

	return maxi(total_credits, 50) # Minimum payment

static func _calculate_reputation_gain(mission_context: Dictionary, performance_context: Dictionary) -> int:
	var base_reputation: int = mission_context.get("difficulty", 1)
	var performance: String = performance_context.get("completion_quality", "completed")
	var mission_type: int = mission_context.get("mission_type", 0)
	
	# Performance modifier
	var performance_multiplier: float = PERFORMANCE_MULTIPLIERS.get(performance, 1.0)
	base_reputation = roundi(base_reputation * performance_multiplier)
	
	# Mission type modifier
	var mission_category: MissionTypeRegistry.MissionCategory = MissionTypeRegistry.get_mission_category(mission_type)
	match mission_category:
		MissionTypeRegistry.MissionCategory.PATRON_CONTRACT:
			base_reputation = roundi(base_reputation * 1.2) # Patron jobs build reputation faster
		MissionTypeRegistry.MissionCategory.OPPORTUNITY:
			base_reputation = roundi(base_reputation * 0.8) # Opportunity missions give less reputation
	
	# Bonus for exceptional performance
	if performance in ["exceptional", "legendary"]:
		base_reputation += 1
	
	return maxi(base_reputation, 0)

static func _calculate_experience_gain(mission_context: Dictionary, performance_context: Dictionary) -> int:
	var difficulty: int = mission_context.get("difficulty", 1)
	var crew_size: int = performance_context.get("crew_size", 3)
	var performance: String = performance_context.get("completion_quality", "completed")
	
	# Base experience per crew member
	var base_xp: int = difficulty * 2
	
	# Performance modifier
	var performance_multiplier: float = PERFORMANCE_MULTIPLIERS.get(performance, 1.0)
	base_xp = roundi(base_xp * performance_multiplier)
	
	# Distribute among crew
	var total_xp: int = base_xp * crew_size
	
	return maxi(total_xp, crew_size) # Minimum 1 XP per crew member

static func _generate_item_rewards(mission_context: Dictionary, performance_context: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var difficulty: int = mission_context.get("difficulty", 1)
	var performance: String = performance_context.get("completion_quality", "completed")
	var mission_type: int = mission_context.get("mission_type", 0)
	
	# Base item chance
	var item_chance: float = 0.2 + (difficulty * 0.1)
	
	# Performance modifier
	var performance_multiplier: float = PERFORMANCE_MULTIPLIERS.get(performance, 1.0)
	item_chance *= performance_multiplier
	
	# Mission type modifier
	var mission_category: MissionTypeRegistry.MissionCategory = MissionTypeRegistry.get_mission_category(mission_type)
	match mission_category:
		MissionTypeRegistry.MissionCategory.OPPORTUNITY:
			item_chance *= 1.5 # Opportunity missions often have loot
	
	# Generate items
	while item_chance > 0.0:
		if randf() < item_chance:
			items.append(_generate_single_item(difficulty, mission_type))
		item_chance -= 1.0
	
	return items

static func _generate_single_item(difficulty: int, mission_type: int) -> Dictionary:
	# Ensure rewards data is loaded
	_ensure_rewards_data_loaded()
	
	# Use existing reward data for item generation
	var reward_entries: Array = _rewards_data.get("entries", [])
	var selected_entry: Dictionary = {}
	
	# Weight selection by difficulty
	for entry in reward_entries:
		var roll_range: Array = entry.get("roll_range", [1, 100])
		var adjusted_roll: int = 50 + (difficulty * 10) # Higher difficulty = better items
		
		if adjusted_roll >= roll_range[0] and adjusted_roll <= roll_range[1]:
			selected_entry = entry.result
			break
	
	if selected_entry.is_empty():
		selected_entry = _rewards_data.get("default_result", {})
	
	# Generate item based on selected entry
	var item: Dictionary = {
		"type": "equipment",
		"quality": selected_entry.get("type", "STANDARD").to_lower(),
		"estimated_value": 100 + (difficulty * 50),
		"source": "mission_reward"
	}
	
	# Add bonus rewards from entry
	var bonus_rewards: Array = selected_entry.get("bonus_rewards", [])
	if not bonus_rewards.is_empty():
		item.bonus_type = bonus_rewards[randi() % bonus_rewards.size()]
	
	return item

static func _calculate_special_bonuses(mission_context: Dictionary, performance_context: Dictionary) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	var performance: String = performance_context.get("completion_quality", "completed")
	var difficulty: int = mission_context.get("difficulty", 1)
	
	# Exceptional performance bonuses
	if performance == "exceptional":
		bonuses.append({
			"type": "performance_bonus",
			"description": "Exceptional mission performance",
			"credit_value": difficulty * 50,
			"reputation_bonus": 1
		})
	elif performance == "legendary":
		bonuses.append({
			"type": "legendary_bonus",
			"description": "Legendary mission achievement",
			"credit_value": difficulty * 100,
			"reputation_bonus": 2,
			"special_unlock": "new_patron_contact"
		})
	
	# Perfect stealth bonus (mission type specific)
	if performance_context.get("stealth_maintained", false):
		bonuses.append({
			"type": "stealth_bonus",
			"description": "Mission completed without detection",
			"credit_value": difficulty * 25,
			"reputation_bonus": 1
		})
	
	# Speed bonus
	var completion_time: int = performance_context.get("completion_turns", 999)
	var expected_time: int = difficulty * 2
	if completion_time <= expected_time:
		bonuses.append({
			"type": "speed_bonus",
			"description": "Mission completed ahead of schedule",
			"credit_value": difficulty * 30
		})
	
	return bonuses

static func _calculate_patron_standing_changes(mission_context: Dictionary, performance_context: Dictionary) -> Dictionary:
	var standing_changes: Dictionary = {}
	
	if not mission_context.has("patron_id"):
		return standing_changes
	
	var patron_id: String = mission_context.patron_id
	var performance: String = performance_context.get("completion_quality", "completed")
	var difficulty: int = mission_context.get("difficulty", 1)
	
	# Calculate standing change
	var standing_delta: int = 0
	match performance:
		"failed": standing_delta = -2
		"partial": standing_delta = -1
		"completed": standing_delta = 1
		"exceptional": standing_delta = 2
		"legendary": standing_delta = 3
	
	# Higher difficulty missions provide more standing
	standing_delta += difficulty - 2
	
	standing_changes[patron_id] = standing_delta
	
	return standing_changes

static func _get_expected_reward_value(difficulty: int) -> int:
	# Expected reward values for balancing
	var base_values: Array[int] = [200, 300, 450, 650, 900]
	return base_values[clampi(difficulty - 1, 0, base_values.size() - 1)]