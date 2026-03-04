class_name AdvancementManagerUI
extends Control

signal character_advanced(character: Dictionary, advancement: Dictionary)
signal injury_healed(character: Dictionary, injury: Dictionary)
signal training_purchased(character: Dictionary, training: Dictionary)

@onready var crew_container: VBoxContainer = %CrewContainer
@onready var character_name: Label = %CharacterName
@onready var stats: GridContainer = %Stats
@onready var experience_container: VBoxContainer = %ExperienceContainer
@onready var injuries_container: VBoxContainer = %InjuriesContainer
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var apply_advancement_button: Button = %ApplyAdvancementButton

var crew_roster: Array[Dictionary] = []
var selected_character: Dictionary = {}
var selected_advancement: Dictionary = {}

func _ready() -> void:
	_load_crew_roster()
	_refresh_crew_list()
	_setup_advancement_icons()

func _load_crew_roster() -> void:
	## Load crew roster from campaign data
	# Connected to campaign manager via GameStateManager
	crew_roster = [
		{
			"name": "Captain Reynolds",
			"class": "Soldier",
			"reactions": 1,
			"speed": 5,
			"combat_skill": 1,
			"toughness": 4,
			"savvy": 0,
			"experience": 5,
			"injuries": ["Hurt Leg"],
			"advancements": []
		},
		{
			"name": "Dr. Chen",
			"class": "Scientist",
			"reactions": 1,
			"speed": 4,
			"combat_skill": 0,
			"toughness": 3,
			"savvy": 2,
			"experience": 3,
			"injuries": [],
			"advancements": ["Improved Savvy"]
		},
		{
			"name": "Sgt. Martinez",
			"class": "Military",
			"reactions": 2,
			"speed": 4,
			"combat_skill": 1,
			"toughness": 4,
			"savvy": 0,
			"experience": 7,
			"injuries": ["Serious Injury"],
			"advancements": ["Improved Reactions"]
		}
	]

func _refresh_crew_list() -> void:
	## Refresh the crew list display
	# Clear existing items
	for child in crew_container.get_children():
		child.queue_free()

	# Add crew members
	for character in crew_roster:
		var character_panel: Panel = _create_character_panel(character)
		crew_container.add_child(character_panel)

func _create_character_panel(character: Dictionary) -> Control:
	## Create a panel for a crew member
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Character name and class
	var name_label: Label = Label.new()
	name_label.text = character.name + " (" + character.class +")"
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Experience points
	var xp_label: Label = Label.new()
	xp_label.text = "XP: " + str(character.experience)
	vbox.add_child(xp_label)

	# Injuries
	if character.injuries.size() > 0:
		var injury_label: Label = Label.new()
		injury_label.text = "Injured: " + str(character.injuries.size())
		injury_label.modulate = UIColors.COLOR_RED
		vbox.add_child(injury_label)

	# Select button
	var select_button: Button = Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_character_selected.bind(character))
	vbox.add_child(select_button)

	return panel

func _update_character_details(character: Dictionary) -> void:
	## Update the character details display
	if character.is_empty():
		character_name.text = "Select Character"
		return

	character_name.text = character.name + " (" + character.class +")"

	# Update stats
	_refresh_stats_display(character)
	_refresh_experience_display(character)
	_refresh_injuries_display(character)
	_refresh_advancement_options(character)

func _refresh_stats_display(character: Dictionary) -> void:
	## Refresh the character stats display
	# Clear existing stats
	for child in stats.get_children():
		child.queue_free()

	# Add stat labels and values
	var stat_names = ["Reactions", "Speed", "Combat Skill", "Toughness", "Savvy"]
	var stat_keys = ["reactions", "speed", "combat_skill", "toughness", "savvy"]

	for i: int in range(stat_names.size()):
		var name_label: Label = Label.new()
		name_label.text = stat_names[i] + ":"
		stats.add_child(name_label)

		var value_label: Label = Label.new()
		var _value = character.get(stat_keys[i], 0)
		if stat_keys[i] == "speed":
			value_label.text = str(_value) + "\""
		elif stat_keys[i] == "combat_skill" or stat_keys[i] == "savvy":
			value_label.text = "+" + str(_value) if _value >= 0 else str(_value)
		else:
			value_label.text = str(_value)
		stats.add_child(value_label)

func _refresh_experience_display(character: Dictionary) -> void:
	## Refresh the experience display
	# Clear existing experience info
	for child in experience_container.get_children():
		child.queue_free()

	var xp = character.get("experience", 0)

	# Current XP
	var current_xp_label: Label = Label.new()
	current_xp_label.text = "Current XP: " + str(xp)
	experience_container.add_child(current_xp_label)

	# XP needed for advancement
	var xp_needed: int = 5 - (xp % 5) if xp % 5 != 0 else 5
	var needed_label: Label = Label.new()
	needed_label.text = "XP for next advancement: " + str(xp_needed)
	experience_container.add_child(needed_label)

	# Available advancements
	var available_advancements = xp / 5.0
	var available_label: Label = Label.new()
	available_label.text = "Available advancements: " + str(available_advancements)
	experience_container.add_child(available_label)

func _refresh_injuries_display(character: Dictionary) -> void:
	## Refresh the injuries display
	# Clear existing injuries
	for child in injuries_container.get_children():
		child.queue_free()

	var injuries = character.get("injuries", [])

	if injuries.is_empty():
		var no_injuries_label: Label = Label.new()
		no_injuries_label.text = "No injuries"
		no_injuries_label.modulate = UIColors.COLOR_EMERALD
		injuries_container.add_child(no_injuries_label)
	else:
		for injury in injuries:
			var injury_panel: Panel = _create_injury_panel(injury)
			injuries_container.add_child(injury_panel)

func _create_injury_panel(injury: String) -> Control:
	## Create a panel for an injury
	var panel: PanelContainer = PanelContainer.new()
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	# Injury icon - Phase 4: Character Injury Status Integration
	var injury_icon: TextureRect = TextureRect.new()
	# Icon asset not yet created — will be assigned when available
	#injury_icon.texture = preload("res://assets/basic icons/icon_character_injury.svg")
	injury_icon.custom_minimum_size = Vector2(24, 24)
	injury_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	injury_icon.modulate = UIColors.COLOR_RED  # Red tint to indicate injury status
	hbox.add_child(injury_icon)

	# Injury name
	var injury_label: Label = Label.new()
	injury_label.text = injury
	injury_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	injury_label.modulate = UIColors.COLOR_RED  # Red text to match injury theme
	hbox.add_child(injury_label)

	# Heal button
	var heal_button: Button = Button.new()
	heal_button.text = "Heal"
	heal_button.pressed.connect(_on_heal_injury.bind(injury))
	hbox.add_child(heal_button)

	return panel

func _refresh_advancement_options(character: Dictionary) -> void:
	## Refresh advancement options display
	# Clear existing options
	for child in options_container.get_children():
		child.queue_free()

	var available_advancements = character.get("experience", 0) / 5
	if available_advancements == 0:
		var no_advancement_label: Label = Label.new()
		no_advancement_label.text = "No advancements available"
		options_container.add_child(no_advancement_label)
		return

	# Add advancement options
	var advancement_options = _get_advancement_options(character)
	for option in advancement_options:
		var option_panel: Panel = _create_advancement_option_panel(option)
		options_container.add_child(option_panel)

func _get_advancement_options(character: Dictionary) -> Array[Dictionary]:
	## Get available advancement options for character
	var options: Array[Dictionary] = []

	# Basic stat improvements
	options.append({"name": "Improve Reactions", "type": "stat", "stat": "reactions", "cost": 1})
	options.append({"name": "Improve Speed", "type": "stat", "stat": "speed", "cost": 1})
	options.append({"name": "Improve Combat Skill", "type": "stat", "stat": "combat_skill", "cost": 1})
	options.append({"name": "Improve Toughness", "type": "stat", "stat": "toughness", "cost": 1})
	options.append({"name": "Improve Savvy", "type": "stat", "stat": "savvy", "cost": 1})

	# Special abilities based on class
	match character.get("class", ""):
		"Soldier":
			options.append({"name": "Combat Veteran", "type": "ability", "description": "Bonus in combat", "cost": 1})
		"Scientist":
			options.append({"name": "Tech Expert", "type": "ability", "description": "Bonus with gadgets", "cost": 1})
		"Military":
			options.append({"name": "Tactical Mind", "type": "ability", "description": "Bonus to initiative", "cost": 1})

	return options

func _create_advancement_option_panel(option: Dictionary) -> Control:
	## Create a panel for advancement option
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Option name
	var name_label: Label = Label.new()
	name_label.text = option.name
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Description if available
	if option.has("description"):
		var desc_label: Label = Label.new()
		desc_label.text = option.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

	# Cost and select button
	var controls = HBoxContainer.new()
	vbox.add_child(controls)

	var cost_label: Label = Label.new()
	cost_label.text = "Cost: " + str(option.cost) + " advancement"
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(cost_label)

	var select_button: Button = Button.new()
	select_button.text = "Select"
	# Icon asset not yet created — will be assigned when available
	#select_button.icon = preload("res://assets/basic icons/icon_character_advancement.svg")
	select_button.expand_icon = true
	select_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	select_button.pressed.connect(_on_advancement_selected.bind(option))
	controls.add_child(select_button)

	return panel

func _on_character_selected(character: Dictionary) -> void:
	## Handle character selection
	selected_character = character
	selected_advancement = {}
	_update_character_details(character)
	apply_advancement_button.disabled = true

func _on_advancement_selected(advancement: Dictionary) -> void:
	## Handle advancement selection
	selected_advancement = advancement
	apply_advancement_button.disabled = false

func _on_heal_injury(injury: String) -> void:
	## Handle injury healing
	if selected_character.is_empty():
		return

	# Remove injury from character
	var injuries = selected_character.get("injuries", [])
	injuries.erase(injury)

	# Refresh display
	_update_character_details(selected_character)

	injury_healed.emit(selected_character, {"name": injury})

func _on_back_pressed() -> void:
	## Handle back button press
	var scene_router = get_node("/root/SceneRouter")
	if scene_router and scene_router and scene_router.has_method("navigate_back"):
		scene_router.navigate_back()
	else:
		push_warning("SceneRouter not found or method unavailable")

func _on_apply_advancement_pressed() -> void:
	## Handle apply advancement button press
	if selected_character.is_empty() or selected_advancement.is_empty():
		return

	# Apply advancement
	if selected_advancement.type == "stat":
		var stat_key = selected_advancement.stat
		selected_character[stat_key] = selected_character.get(stat_key, 0) + 1

	# Deduct experience
	var cost = selected_advancement.get("cost", 1)
	selected_character["experience"] = selected_character.get("experience", 0) - (cost * 5)

	# Add to advancements list
	var advancements = selected_character.get("advancements", [])
	advancements.append(selected_advancement.name)
	selected_character["advancements"] = advancements

	# Refresh displays
	_refresh_crew_list()
	_update_character_details(selected_character)

	# Reset selection
	selected_advancement = {}
	apply_advancement_button.disabled = true

	character_advanced.emit(selected_character, selected_advancement)

func _on_advanced_training_pressed() -> void:
	## Handle advanced training button press
	# Open advanced training interface
	# Implementation would show specialized training options
	pass

func _on_heal_injuries_pressed() -> void:
	## Handle heal injuries button press
	# Open medical treatment interface
	# Implementation would show injury healing options and medical costs
	pass

## Setup advancement icons for enhanced visual clarity
func _setup_advancement_icons() -> void:
	## Setup icons for character advancement buttons to improve user experience
	# Phase 4: Character Advancement Icons Integration
	
	# Apply Advancement Button - icon_character_advancement.svg
	if apply_advancement_button:
		# Icon asset not yet created — will be assigned when available
		#apply_advancement_button.icon = preload("res://assets/basic icons/icon_character_advancement.svg")
		apply_advancement_button.expand_icon = true
		apply_advancement_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		push_warning("AdvancementManager: Apply advancement button not found for icon assignment")
