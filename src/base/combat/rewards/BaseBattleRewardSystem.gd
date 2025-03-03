@tool
extends Node
class_name BaseBattleRewardSystem

# Signals
signal rewards_calculated(rewards: Dictionary)
signal reward_granted(reward_type: String, reward_data: Dictionary)
signal all_rewards_granted()

# Reward types
enum RewardType {
	EXPERIENCE,
	CURRENCY,
	ITEM,
	RESOURCE,
	REPUTATION,
	UNLOCK,
	CUSTOM
}

# Reward storage
var calculated_rewards: Dictionary = {}
var granted_rewards: Array = []
var pending_rewards: Array = []

# Reward modifiers
var reward_multipliers: Dictionary = {
	RewardType.EXPERIENCE: 1.0,
	RewardType.CURRENCY: 1.0,
	RewardType.ITEM: 1.0,
	RewardType.RESOURCE: 1.0,
	RewardType.REPUTATION: 1.0,
	RewardType.UNLOCK: 1.0,
	RewardType.CUSTOM: 1.0
}

# Battle data reference
var battle_data: Node = null
var objective_system: Node = null

# Virtual methods to be implemented by derived classes
func initialize(battle_data_ref: Node = null, objective_system_ref: Node = null) -> void:
	battle_data = battle_data_ref
	objective_system = objective_system_ref
	
	calculated_rewards.clear()
	granted_rewards.clear()
	pending_rewards.clear()

func calculate_rewards() -> Dictionary:
	# This method should be implemented by derived classes
	# to calculate rewards based on battle performance
	# Example implementation:
	var rewards = {
		"experience": _calculate_experience_reward(),
		"currency": _calculate_currency_reward(),
		"items": _calculate_item_rewards(),
		"resources": _calculate_resource_rewards(),
		"reputation": _calculate_reputation_rewards(),
		"unlocks": _calculate_unlock_rewards(),
		"custom": _calculate_custom_rewards()
	}
	
	calculated_rewards = rewards
	rewards_calculated.emit(rewards)
	
	# Prepare pending rewards
	_prepare_pending_rewards()
	
	return rewards

func grant_rewards() -> void:
	# Grant all pending rewards
	var rewards_to_grant = pending_rewards.duplicate()
	
	for reward in rewards_to_grant:
		grant_reward(reward.type, reward.data)
	
	all_rewards_granted.emit()

func grant_reward(reward_type: String, reward_data: Dictionary) -> void:
	# This method should be implemented by derived classes
	# to actually grant the rewards to the player
	# Mark as granted
	granted_rewards.append({
		"type": reward_type,
		"data": reward_data
	})
	
	# Remove from pending
	for i in range(pending_rewards.size() - 1, -1, -1):
		if pending_rewards[i].type == reward_type and pending_rewards[i].data == reward_data:
			pending_rewards.remove_at(i)
			break
	
	# Emit signal
	reward_granted.emit(reward_type, reward_data)

func set_reward_multiplier(reward_type: int, multiplier: float) -> void:
	reward_multipliers[reward_type] = max(0.0, multiplier)

func get_reward_multiplier(reward_type: int) -> float:
	return reward_multipliers.get(reward_type, 1.0)

func get_calculated_rewards() -> Dictionary:
	return calculated_rewards

func get_granted_rewards() -> Array:
	return granted_rewards

func get_pending_rewards() -> Array:
	return pending_rewards

# Helper methods
func _prepare_pending_rewards() -> void:
	pending_rewards.clear()
	
	# Experience
	if "experience" in calculated_rewards and calculated_rewards.experience > 0:
		pending_rewards.append({
			"type": "experience",
			"data": {"amount": calculated_rewards.experience}
		})
	
	# Currency
	if "currency" in calculated_rewards and calculated_rewards.currency > 0:
		pending_rewards.append({
			"type": "currency",
			"data": {"amount": calculated_rewards.currency}
		})
	
	# Items
	if "items" in calculated_rewards and calculated_rewards.items.size() > 0:
		for item in calculated_rewards.items:
			pending_rewards.append({
				"type": "item",
				"data": item
			})
	
	# Resources
	if "resources" in calculated_rewards and calculated_rewards.resources.size() > 0:
		for resource_id in calculated_rewards.resources:
			pending_rewards.append({
				"type": "resource",
				"data": {
					"id": resource_id,
					"amount": calculated_rewards.resources[resource_id]
				}
			})
	
	# Reputation
	if "reputation" in calculated_rewards and calculated_rewards.reputation.size() > 0:
		for faction_id in calculated_rewards.reputation:
			pending_rewards.append({
				"type": "reputation",
				"data": {
					"faction_id": faction_id,
					"amount": calculated_rewards.reputation[faction_id]
				}
			})
	
	# Unlocks
	if "unlocks" in calculated_rewards and calculated_rewards.unlocks.size() > 0:
		for unlock in calculated_rewards.unlocks:
			pending_rewards.append({
				"type": "unlock",
				"data": unlock
			})
	
	# Custom
	if "custom" in calculated_rewards and calculated_rewards.custom.size() > 0:
		for custom in calculated_rewards.custom:
			pending_rewards.append({
				"type": "custom",
				"data": custom
			})

# Calculation methods - to be overridden by derived classes
func _calculate_experience_reward() -> int:
	# Base implementation - should be overridden
	var base_xp = 100
	
	# Apply multiplier
	return int(base_xp * get_reward_multiplier(RewardType.EXPERIENCE))

func _calculate_currency_reward() -> int:
	# Base implementation - should be overridden
	var base_currency = 50
	
	# Apply multiplier
	return int(base_currency * get_reward_multiplier(RewardType.CURRENCY))

func _calculate_item_rewards() -> Array:
	# Base implementation - should be overridden
	return []

func _calculate_resource_rewards() -> Dictionary:
	# Base implementation - should be overridden
	return {}

func _calculate_reputation_rewards() -> Dictionary:
	# Base implementation - should be overridden
	return {}

func _calculate_unlock_rewards() -> Array:
	# Base implementation - should be overridden
	return []

func _calculate_custom_rewards() -> Array:
	# Base implementation - should be overridden
	return []

# Utility methods
func get_reward_description(reward_type: String, reward_data: Dictionary) -> String:
	match reward_type:
		"experience":
			return "%d XP" % reward_data.amount
		"currency":
			return "%d Credits" % reward_data.amount
		"item":
			var name = reward_data.get("name", "Unknown Item")
			var quantity = reward_data.get("quantity", 1)
			if quantity > 1:
				return "%s x%d" % [name, quantity]
			else:
				return name
		"resource":
			var name = reward_data.get("name", reward_data.get("id", "Unknown Resource"))
			return "%s x%d" % [name, reward_data.amount]
		"reputation":
			var faction = reward_data.get("faction_name", reward_data.get("faction_id", "Unknown Faction"))
			var amount = reward_data.amount
			if amount > 0:
				return "+%d Reputation with %s" % [amount, faction]
			else:
				return "%d Reputation with %s" % [amount, faction]
		"unlock":
			return "Unlocked: %s" % reward_data.get("name", "Unknown Unlock")
		"custom":
			return reward_data.get("description", "Custom Reward")
		_:
			return "Unknown Reward"