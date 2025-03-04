extends BasePhasePanel
class_name FPCM_AdvancementPhasePanel

const Character = preload("res://src/core/character/Base/Character.gd")

@onready var crew_list = $VBoxContainer/CrewList
@onready var advancement_options = $VBoxContainer/AdvancementOptions
@onready var character_info = $VBoxContainer/CharacterInfo
@onready var apply_button = $VBoxContainer/ApplyButton

var selected_crew_member: Character
var available_advancements: Array = []
var selected_advancement: Dictionary = {}

# XP costs from core rules
var advancement_costs: Dictionary = {
	"REACTION": 7,
	"COMBAT": 7,
	"SPEED": 5,
	"SAVVY": 5,
	"TOUGHNESS": 6,
	"LUCK": 10,
	"TRAINING": {
		"PILOT": 20,
		"MECHANIC": 15,
		"MEDICAL": 20,
		"MERCHANT": 10,
		"SECURITY": 10,
		"BROKER": 15,
		"BOT_TECH": 10
	}
}

# Maximum values from core rules
var max_stats: Dictionary = {
	"REACTION": 6,
	"COMBAT": 5,
	"SPEED": 8,
	"SAVVY": 5,
	"TOUGHNESS": 6,
	"LUCK": 1 # Humans can have 3
}

func _ready() -> void:
	super._ready()
	_connect_signals()

func _connect_signals() -> void:
	crew_list.item_selected.connect(_on_crew_selected)
	advancement_options.item_selected.connect(_on_advancement_selected)
	apply_button.pressed.connect(_on_apply_pressed)

func setup_phase() -> void:
	super.setup_phase()
	_load_crew()
	_update_ui()

func _load_crew() -> void:
	crew_list.clear()
	for member in game_state.campaign.crew_members:
		# Bots don't get XP
		if member.is_bot:
			continue
			
		var text = "%s (Level %d)" % [member.character_name, member.level]
		if member.experience >= member.get_experience_for_next_level():
			text += " - LEVEL UP AVAILABLE"
		crew_list.add_item(text)

func _update_ui() -> void:
	if not selected_crew_member:
		character_info.text = "Select a crew member"
		advancement_options.clear()
		apply_button.disabled = true
		return
	
	_update_character_info()
	_update_advancement_options()

func _update_character_info() -> void:
	var info := "[b]%s[/b]\n" % selected_crew_member.character_name
	info += "Class: %s\n" % GameEnums.get_character_class_name(selected_crew_member.character_class)
	info += "Level: %d\n" % selected_crew_member.level
	info += "Experience: %d/%d\n" % [
		selected_crew_member.experience,
		selected_crew_member.get_experience_for_next_level()
	]
	
	info += "\n[b]Stats:[/b]\n"
	info += "Health: %d/%d\n" % [selected_crew_member.health, selected_crew_member.max_health]
	info += "Reaction: %d/%d\n" % [selected_crew_member.reaction, max_stats.REACTION]
	info += "Combat: %d/%d\n" % [selected_crew_member.combat, max_stats.COMBAT]
	info += "Speed: %d/%d\n" % [selected_crew_member.speed, max_stats.SPEED]
	info += "Savvy: %d/%d\n" % [selected_crew_member.savvy, max_stats.SAVVY]
	info += "Toughness: %d/%d\n" % [selected_crew_member.toughness, max_stats.TOUGHNESS]
	info += "Luck: %d/%d\n" % [selected_crew_member.luck, max_stats.LUCK]
	
	info += "\n[b]Training:[/b]\n"
	if selected_crew_member.training == GameEnums.Training.NONE:
		info += "None\n"
	else:
		info += "• %s\n" % GameEnums.get_training_name(selected_crew_member.training)
	
	info += "\n[b]Skills:[/b]\n"
	if selected_crew_member.skills.is_empty():
		info += "None\n"
	else:
		for skill_name in selected_crew_member.skills:
			info += "• %s\n" % skill_name
	
	info += "\n[b]Abilities:[/b]\n"
	if selected_crew_member.abilities.is_empty():
		info += "None\n"
	else:
		for ability_name in selected_crew_member.abilities:
			info += "• %s\n" % ability_name
	
	info += "\n[b]Traits:[/b]\n"
	if selected_crew_member.traits.is_empty():
		info += "None\n"
	else:
		for trait_name in selected_crew_member.traits:
			info += "• %s\n" % trait_name
	
	character_info.text = info

func _update_advancement_options() -> void:
	advancement_options.clear()
	available_advancements = _get_available_advancements()
	
	for advancement in available_advancements:
		var text = advancement.name
		if selected_crew_member.is_bot:
			text += " (%d credits)" % advancement.cost
		else:
			text += " (%d XP)" % advancement.cost
		advancement_options.add_item(text)
		
		if not _can_apply_advancement(advancement):
			var idx = advancement_options.item_count - 1
			advancement_options.set_item_disabled(idx, true)
			advancement_options.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
			advancement_options.set_item_tooltip(idx, _get_requirement_tooltip(advancement))

func _get_available_advancements() -> Array:
	var advancements = []
	
	# Add stat improvements
	advancements.append_array([
		{
			"name": "Increase Reaction",
			"type": "STAT",
			"stat": "reaction",
			"amount": 1,
			"cost": advancement_costs.REACTION,
			"max": max_stats.REACTION
		},
		{
			"name": "Increase Combat",
			"type": "STAT",
			"stat": "combat",
			"amount": 1,
			"cost": advancement_costs.COMBAT,
			"max": max_stats.COMBAT
		},
		{
			"name": "Increase Speed",
			"type": "STAT",
			"stat": "speed",
			"amount": 1,
			"cost": advancement_costs.SPEED,
			"max": max_stats.SPEED
		},
		{
			"name": "Increase Savvy",
			"type": "STAT",
			"stat": "savvy",
			"amount": 1,
			"cost": advancement_costs.SAVVY,
			"max": max_stats.SAVVY
		},
		{
			"name": "Increase Toughness",
			"type": "STAT",
			"stat": "toughness",
			"amount": 1,
			"cost": advancement_costs.TOUGHNESS,
			"max": max_stats.TOUGHNESS if selected_crew_member.character_class != GameEnums.CharacterClass.ENGINEER else 4
		},
		{
			"name": "Increase Luck",
			"type": "STAT",
			"stat": "luck",
			"amount": 1,
			"cost": advancement_costs.LUCK,
			"max": 3 if selected_crew_member.is_human else max_stats.LUCK
		}
	])
	
	# Add training options if character doesn't have any yet
	if selected_crew_member.training == GameEnums.Training.NONE:
		advancements.append_array([
			{
				"name": "Pilot Training",
				"type": "TRAINING",
				"training": GameEnums.Training.PILOT,
				"cost": advancement_costs.TRAINING.PILOT
			},
			{
				"name": "Mechanic Training",
				"type": "TRAINING",
				"training": GameEnums.Training.MECHANIC,
				"cost": advancement_costs.TRAINING.MECHANIC
			},
			{
				"name": "Medical Training",
				"type": "TRAINING",
				"training": GameEnums.Training.MEDICAL,
				"cost": advancement_costs.TRAINING.MEDICAL
			},
			{
				"name": "Merchant Training",
				"type": "TRAINING",
				"training": GameEnums.Training.MERCHANT,
				"cost": advancement_costs.TRAINING.MERCHANT
			},
			{
				"name": "Security Training",
				"type": "TRAINING",
				"training": GameEnums.Training.SECURITY,
				"cost": advancement_costs.TRAINING.SECURITY
			},
			{
				"name": "Broker Training",
				"type": "TRAINING",
				"training": GameEnums.Training.BROKER,
				"cost": advancement_costs.TRAINING.BROKER
			},
			{
				"name": "Bot Tech Training",
				"type": "TRAINING",
				"training": GameEnums.Training.BOT_TECH,
				"cost": advancement_costs.TRAINING.BOT_TECH
			}
		])
	
	return advancements

func _can_apply_advancement(advancement: Dictionary) -> bool:
	# Check if bot or soulless for training restrictions
	if advancement.type == "TRAINING":
		if selected_crew_member.is_soulless:
			return false
		if selected_crew_member.is_bot and not game_state.campaign.credits >= advancement.cost:
			return false
	
	# Check XP cost for non-bots
	if not selected_crew_member.is_bot and selected_crew_member.experience < advancement.cost:
		return false
		
	# Check credit cost for bots
	if selected_crew_member.is_bot and game_state.campaign.credits < advancement.cost:
		return false
	
	# Check stat maximums
	if advancement.type == "STAT":
		var current_value = selected_crew_member.get(advancement.stat)
		if current_value >= advancement.max:
			return false
			
		# Special case for engineer toughness limit
		if advancement.stat == "toughness" and selected_crew_member.character_class == GameEnums.CharacterClass.ENGINEER and current_value >= 4:
			return false
	
	return true

func _get_requirement_tooltip(advancement: Dictionary) -> String:
	var tooltip = ""
	
	if advancement.type == "TRAINING":
		if selected_crew_member.is_soulless:
			tooltip = "Soulless characters cannot receive training"
		elif selected_crew_member.is_bot and game_state.campaign.credits < advancement.cost:
			tooltip = "Not enough credits (need %d)" % advancement.cost
	
	if not selected_crew_member.is_bot and selected_crew_member.experience < advancement.cost:
		tooltip = "Not enough XP (need %d)" % advancement.cost
		
	if selected_crew_member.is_bot and game_state.campaign.credits < advancement.cost:
		tooltip = "Not enough credits (need %d)" % advancement.cost
	
	if advancement.type == "STAT":
		var current_value = selected_crew_member.get(advancement.stat)
		if current_value >= advancement.max:
			tooltip = "Maximum value reached"
			
		if advancement.stat == "toughness" and selected_crew_member.character_class == GameEnums.CharacterClass.ENGINEER and current_value >= 4:
			tooltip = "Engineers cannot raise Toughness above 4"
	
	return tooltip

func _on_crew_selected(index: int) -> void:
	selected_crew_member = game_state.campaign.crew_members[index]
	_update_ui()

func _on_advancement_selected(index: int) -> void:
	selected_advancement = available_advancements[index]
	apply_button.disabled = not _can_apply_advancement(selected_advancement)

func _on_apply_pressed() -> void:
	if not _can_apply_advancement(selected_advancement):
		return
		
	match selected_advancement.type:
		"STAT":
			selected_crew_member.set(selected_advancement.stat, selected_crew_member.get(selected_advancement.stat) + selected_advancement.amount)
		"TRAINING":
			selected_crew_member.training = selected_advancement.training
	
	# Deduct cost
	if selected_crew_member.is_bot:
		game_state.campaign.credits -= selected_advancement.cost
	else:
		selected_crew_member.experience -= selected_advancement.cost
	
	_update_ui()
