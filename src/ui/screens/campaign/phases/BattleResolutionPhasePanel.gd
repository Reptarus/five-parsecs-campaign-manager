extends BasePhasePanel
class_name BattleResolutionPhasePanel

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

@onready var battle_summary = $VBoxContainer/BattleSummary
@onready var objectives_list = $VBoxContainer/ObjectivesList
@onready var casualties_list = $VBoxContainer/CasualtiesList
@onready var rewards_list = $VBoxContainer/RewardsList
@onready var complete_button = $VBoxContainer/CompleteButton

var escalating_battles_manager: EscalatingBattlesManager
var completed_objectives: Array = []
var failed_objectives: Array = []
var casualties: Array = []
var rewards: Dictionary = {}
var battle_state: Dictionary = {}

func _ready() -> void:
	super._ready()
	escalating_battles_manager = EscalatingBattlesManager.new(game_state)
	_connect_signals()

func _connect_signals() -> void:
	complete_button.pressed.connect(_on_complete_pressed)

func setup_phase() -> void:
	super.setup_phase()
	
	# Get battle state from campaign
	battle_state = game_state.campaign.battle_state
	
	_resolve_battle()
	_calculate_rewards()
	_update_ui()

func _resolve_battle() -> void:
	var mission = game_state.campaign.current_mission
	var crew_members = battle_state.crew_members
	var equipment = battle_state.equipment
	
	# Handle escalation if present
	if battle_state.has("escalation"):
		_apply_escalation(battle_state.escalation)
	
	# Resolve objectives
	for objective in mission.objectives:
		var success_chance = _calculate_objective_success_chance(objective, crew_members, equipment)
		if randf() <= success_chance:
			completed_objectives.append(objective)
		else:
			failed_objectives.append(objective)
	
	# Resolve casualties
	for crew_member in crew_members:
		var casualty_chance = _calculate_casualty_chance(crew_member, equipment)
		if randf() <= casualty_chance:
			casualties.append({
				"member": crew_member,
				"type": _determine_casualty_type(crew_member)
			})

func _apply_escalation(escalation: Dictionary) -> void:
	var summary_text = battle_summary.text
	summary_text += "\n[b]Battle Escalation:[/b]\n"
	summary_text += escalation.description + "\n"
	
	# Apply escalation effects
	match escalation.effect.target:
		"player":
			for crew_member in battle_state.crew_members:
				_apply_escalation_effect(crew_member, escalation.effect)
		"enemy":
			# Increase difficulty of objectives
			for objective in game_state.campaign.current_mission.objectives:
				objective.difficulty += 1
		"all":
			for crew_member in battle_state.crew_members:
				_apply_escalation_effect(crew_member, escalation.effect)
			for objective in game_state.campaign.current_mission.objectives:
				objective.difficulty += 1
	
	battle_summary.text = summary_text

func _apply_escalation_effect(crew_member: Character, effect: Dictionary) -> void:
	if effect.has("damage"):
		crew_member.take_damage(effect.damage)
	
	if effect.has("disable_item"):
		var equipped_item = battle_state.equipment.get(crew_member.id)
		if equipped_item:
			battle_state.equipment.erase(crew_member.id)
	
	if effect.has("psionic_boost") and crew_member.has_psionic_powers():
		crew_member.boost_psionic_power(effect.get("psionic_intensity", 1))

func _calculate_objective_success_chance(objective: Dictionary, crew: Array, equipment: Dictionary) -> float:
	var base_chance = 0.7 # 70% base chance
	
	# Adjust for crew size
	base_chance += 0.05 * crew.size() # +5% per crew member
	
	# Adjust for equipment
	for item_id in equipment.values():
		if _is_item_beneficial_for_objective(item_id, objective):
			base_chance += 0.1 # +10% per beneficial item
	
	# Adjust for objective difficulty
	base_chance -= 0.1 * objective.get("difficulty", 1) # -10% per difficulty level
	
	# Adjust for crew skills
	for member in crew:
		if _has_relevant_skill(member, objective):
			base_chance += 0.15 # +15% per relevant skill
	
	# Clamp between 0.1 and 0.9
	return clampf(base_chance, 0.1, 0.9)

func _is_item_beneficial_for_objective(item_id: String, objective: Dictionary) -> bool:
	# TODO: Implement proper item benefit checking
	return true

func _has_relevant_skill(member: Character, objective: Dictionary) -> bool:
	# TODO: Implement proper skill relevance checking
	return false

func _calculate_casualty_chance(member: Character, equipment: Dictionary) -> float:
	var base_chance = 0.2 # 20% base chance
	
	# Reduce chance based on armor and equipment
	if equipment.has(member.id):
		base_chance -= 0.05 # -5% if equipped
	
	# Adjust for member's stats
	base_chance -= 0.02 * member.get_defense() # -2% per defense point
	
	# Increase chance if objectives failed
	base_chance += 0.1 * failed_objectives.size()
	
	# Clamp between 0.05 and 0.5
	return clampf(base_chance, 0.05, 0.5)

func _determine_casualty_type(member: Character) -> String:
	var death_chance = 0.3 # 30% chance of death vs injury
	
	# Adjust based on member's resilience
	death_chance -= 0.05 * member.get_resilience()
	
	# Adjust based on failed objectives
	death_chance += 0.1 * failed_objectives.size()
	
	return "DEATH" if randf() <= death_chance else "INJURY"

func _calculate_rewards() -> void:
	var mission = game_state.campaign.current_mission
	
	# Base reward
	rewards["credits"] = mission.reward_credits
	
	# Bonus for completed objectives
	for objective in completed_objectives:
		rewards["credits"] += objective.get("bonus_credits", 50)
	
	# Bonus for completing all objectives
	if failed_objectives.is_empty():
		rewards["credits"] += mission.get("completion_bonus", 200)
	
	# Penalty for casualties
	rewards["credits"] -= casualties.size() * 50
	
	# Generate loot based on mission type and success
	rewards["items"] = _generate_loot()
	
	# Add bonus rewards from mission
	if mission.has("bonus_rewards"):
		for reward in mission.bonus_rewards:
			if reward.type == "credits":
				rewards["credits"] += reward.amount
			elif reward.type == "item":
				rewards["items"].append(reward)

func _generate_loot() -> Array:
	var loot = []
	var mission = game_state.campaign.current_mission
	
	# Base loot
	if completed_objectives.size() > failed_objectives.size():
		loot.append({
			"name": "Salvage Crate",
			"quantity": completed_objectives.size()
		})
	
	# Special loot based on mission type
	match mission.type:
		"SCAVENGING":
			loot.append({
				"name": "Tech Components",
				"quantity": randi() % 3 + 1
			})
		"COMBAT":
			loot.append({
				"name": "Weapon Parts",
				"quantity": randi() % 2 + 1
			})
		"EXPLORATION":
			loot.append({
				"name": "Data Crystal",
				"quantity": 1
			})
	
	return loot

func _update_ui() -> void:
	_update_battle_summary()
	_update_objectives()
	_update_casualties()
	_update_rewards()

func _update_battle_summary() -> void:
	var summary = "[b]Battle Summary[/b]\n\n"
	summary += "Mission: %s\n" % game_state.campaign.current_mission.title
	summary += "Location: %s\n" % game_state.campaign.current_location.name
	
	if battle_state.has("escalation"):
		summary += "\n[b]Battle Escalation:[/b]\n"
		summary += battle_state.escalation.description + "\n"
	
	summary += "\nObjectives Completed: %d/%d\n" % [
		completed_objectives.size(),
		completed_objectives.size() + failed_objectives.size()
	]
	
	summary += "Casualties: %d\n" % casualties.size()
	
	if not casualties.is_empty():
		summary += "\n[b]Casualty Details:[/b]\n"
		var deaths = casualties.filter(func(c): return c.type == "DEATH").size()
		var injuries = casualties.filter(func(c): return c.type == "INJURY").size()
		summary += "Deaths: %d\n" % deaths
		summary += "Injuries: %d\n" % injuries
	
	battle_summary.text = summary

func _update_objectives() -> void:
	objectives_list.clear()
	
	for objective in completed_objectives:
		objectives_list.add_item("✓ " + objective.description)
		objectives_list.set_item_custom_fg_color(objectives_list.item_count - 1, Color(0, 1, 0))
		if objective.has("bonus_credits"):
			objectives_list.add_item("  Bonus: %d credits" % objective.bonus_credits)
	
	for objective in failed_objectives:
		objectives_list.add_item("✗ " + objective.description)
		objectives_list.set_item_custom_fg_color(objectives_list.item_count - 1, Color(1, 0, 0))

func _update_casualties() -> void:
	casualties_list.clear()
	
	if casualties.is_empty():
		casualties_list.add_item("No casualties")
		return
	
	for casualty in casualties:
		var text = "%s - %s" % [casualty.member.character_name, casualty.type]
		if casualty.type == "INJURY":
			text += " (Recovery: %d days)" % _calculate_recovery_time(casualty.member)
		casualties_list.add_item(text)
		casualties_list.set_item_custom_fg_color(
			casualties_list.item_count - 1,
			Color(1, 0, 0) if casualty.type == "DEATH" else Color(1, 0.5, 0)
		)

func _calculate_recovery_time(member: Character) -> int:
	var base_time = 3 # Base 3 days
	base_time -= member.get_resilience() # Reduce by resilience
	base_time = maxi(1, base_time) # Minimum 1 day
	return base_time

func _update_rewards() -> void:
	rewards_list.clear()
	
	rewards_list.add_item("Credits: %d" % rewards.credits)
	
	if rewards.has("items"):
		rewards_list.add_item("\nLoot:")
		for item in rewards.items:
			rewards_list.add_item("• %s x%d" % [item.name, item.quantity])

func _apply_battle_results() -> void:
	# Update campaign credits
	game_state.campaign.credits += rewards.credits
	
	# Add items to inventory
	if rewards.has("items"):
		for item in rewards.items:
			game_state.campaign.add_to_inventory(item)
	
	# Handle casualties
	for casualty in casualties:
		if casualty.type == "DEATH":
			game_state.campaign.remove_crew_member(casualty.member)
		else:
			casualty.member.set_injured(_calculate_recovery_time(casualty.member))
	
	# Update mission status
	game_state.campaign.complete_mission(
		completed_objectives.size(),
		failed_objectives.size(),
		casualties.size()
	)
	
	# Clear battle state
	game_state.campaign.battle_state = {}

func _on_complete_pressed() -> void:
	_apply_battle_results()
	complete_phase()

func validate_phase_requirements() -> bool:
	if not game_state or not game_state.campaign:
		return false
	
	if not game_state.campaign.current_mission:
		return false
	
	if not game_state.campaign.battle_state:
		return false
	
	return true