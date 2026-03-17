extends Control

## Five Parsecs Character Progression UI
## Handles character advancement, skill development, and stat improvements

# Safe imports
# Removed UniversalNodeValidator dependency - using simple Godot node validation
# GlobalEnums available as autoload singleton

# Character Stat Types
enum CharacterStatType {
	NONE,
	REACTIONS,
	SPEED,
	COMBAT_SKILL,
	TOUGHNESS,
	SAVVY,
	LUCK,
	TECH
}

# UI Components - Header
@onready var title_label: Label = get_node("MainContainer/HeaderPanel/MarginContainer/HeaderContent/TitleLabel")
@onready var name_label: Label = get_node("MainContainer/HeaderPanel/MarginContainer/HeaderContent/CharacterInfo/NameLabel")
@onready var level_label: Label = get_node("MainContainer/HeaderPanel/MarginContainer/HeaderContent/CharacterInfo/LevelLabel")
@onready var xp_label: Label = get_node("MainContainer/HeaderPanel/MarginContainer/HeaderContent/CharacterInfo/XPLabel")
@onready var xp_bar: ProgressBar = get_node("MainContainer/HeaderPanel/MarginContainer/HeaderContent/XPBar")

# UI Components - Stats Panel
@onready var stats_container: VBoxContainer = get_node("MainContainer/ContentContainer/LeftPanel/MarginContainer/VBoxContainer/StatsContainer")
@onready var stat_points_label: Label = get_node("MainContainer/ContentContainer/LeftPanel/MarginContainer/VBoxContainer/StatPointsLabel")

# UI Components - Skills Panel
@onready var skill_points_label: Label = get_node("MainContainer/ContentContainer/RightPanel/MarginContainer/VBoxContainer/SkillPointsLabel")
@onready var skill_list: VBoxContainer = get_node("MainContainer/ContentContainer/RightPanel/MarginContainer/VBoxContainer/SkillList")

# UI Components - Bottom Buttons
@onready var apply_button: Button = get_node("MainContainer/ButtonContainer/ApplyButton")
@onready var cancel_button: Button = get_node("MainContainer/ButtonContainer/CancelButton")
@onready var auto_advance_button: Button = get_node("MainContainer/ButtonContainer/AutoAdvanceButton")

# State
var current_character: Character = null
var available_stat_points: int = 0
var available_skill_points: int = 0
var pending_stat_changes: Dictionary = {}
var pending_skill_changes: Dictionary = {}

# Stat controls
var stat_controls: Dictionary = {}

# Skill definitions (Five Parsecs skills)
var available_skills: Array[Dictionary] = [
	{"name": "Combat Training", "description": "+1 to Combat rolls", "cost": 2, "max_level": 3},
	{"name": "Medical Training", "description": "Can treat injuries", "cost": 2, "max_level": 2},
	{"name": "Technical Training", "description": "+1 to tech-related Savvy rolls", "cost": 2, "max_level": 2},
	{"name": "Pilot Training", "description": "+1 to ship-related rolls", "cost": 2, "max_level": 2},
	{"name": "Stealth Training", "description": "+1 to stealth-related rolls", "cost": 2, "max_level": 2},
	{"name": "Leadership", "description": "Improves crew morale", "cost": 3, "max_level": 1},
	{"name": "Lucky", "description": "Reroll one die per battle", "cost": 3, "max_level": 1},
	{"name": "Resilient", "description": "+1 to injury recovery", "cost": 2, "max_level": 2}
]

signal progression_applied(character: Character)
signal progression_cancelled()

func _ready() -> void:
	_setup_ui_validation()
	_setup_ui_components()

func _setup_ui_validation() -> void:
	## Setup UI validation using Universal Safety System
	var required_nodes: Array[String] = [
		"MainContainer/HeaderPanel/MarginContainer/HeaderContent/TitleLabel",
		"MainContainer/ContentContainer/LeftPanel/MarginContainer/VBoxContainer/StatsContainer",
		"MainContainer/ContentContainer/RightPanel/MarginContainer/VBoxContainer/SkillList"
	]

	# Simple Godot-native node validation - no over-engineered Universal framework
	var missing_nodes = []
	for node_path in required_nodes:
		if not has_node(node_path):
			missing_nodes.append(node_path)
	
	if missing_nodes.size() > 0:
		push_warning("CharacterProgression: Missing UI nodes: " + str(missing_nodes))

func _setup_ui_components() -> void:
	## Setup UI components and controls
	_create_stat_controls()
	_create_skill_controls()
	_update_display()

func _create_stat_controls() -> void:
	## Create stat improvement controls
	if not stats_container:
		return

	# Clear existing controls
	for child: Node in stats_container.get_children():
		child.queue_free()

	var stat_names: Array[String] = ["Reaction", "Combat", "Toughness", "Speed", "Savvy", "Luck"]

	for stat_name: String in stat_names:
		var stat_row: HBoxContainer = HBoxContainer.new()
		stats_container.add_child(stat_row)

		# Stat name label
		var stat_name_label: Label = Label.new()
		stat_name_label.text = str(stat_name) + ":"
		stat_name_label.custom_minimum_size = Vector2(80, 0)
		stat_row.add_child(stat_name_label)

		# Current value label
		var value_label: Label = Label.new()
		value_label.text = "0"
		value_label.custom_minimum_size = Vector2(30, 0)
		stat_row.add_child(value_label)

		# Decrease button
		var decrease_button: Button = Button.new()
		decrease_button.text = "-"
		decrease_button.custom_minimum_size = Vector2(30, 30)
		# Handle signal connection with proper error handling
		var decrease_error: Error = decrease_button.pressed.connect(_on_stat_decrease_pressed.bind(stat_name))
		if decrease_error != OK:
			push_error("Failed to connect decrease button signal: " + str(decrease_error))
		stat_row.add_child(decrease_button)

		# Pending changes label
		var pending_label: Label = Label.new()
		pending_label.text = "0"
		pending_label.custom_minimum_size = Vector2(30, 0)
		pending_label.modulate = UIColors.COLOR_AMBER
		stat_row.add_child(pending_label)

		# Increase button
		var increase_button: Button = Button.new()
		increase_button.text = "+"
		increase_button.custom_minimum_size = Vector2(30, 30)
		# Handle signal connection with proper error handling
		var increase_error: Error = increase_button.pressed.connect(_on_stat_increase_pressed.bind(stat_name))
		if increase_error != OK:
			push_error("Failed to connect increase button signal: " + str(increase_error))
		stat_row.add_child(increase_button)

		# Cost label
		var cost_label: Label = Label.new()
		cost_label.text = "(Cost: 2)"
		cost_label.modulate = UIColors.COLOR_TEXT_SECONDARY
		stat_row.add_child(cost_label)

		# Store references
		stat_controls[stat_name] = {
			"value_label": value_label,
			"pending_label": pending_label,
			"decrease_button": decrease_button,
			"increase_button": increase_button
		}

func _create_skill_controls() -> void:
	## Create skill advancement controls
	if not skill_list:
		return

	# Clear existing controls
	for child: Node in skill_list.get_children():
		child.queue_free()

	for skill: Dictionary in available_skills:
		var skill_container: VBoxContainer = VBoxContainer.new()
		skill_list.add_child(skill_container)

		# Skill header
		var skill_header: HBoxContainer = HBoxContainer.new()
		skill_container.add_child(skill_header)

		# Skill name and level
		var skill_label: Label = Label.new()
		skill_label.text = skill.name + " (Level: 0/" + str(skill.max_level) + ")"
		skill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_header.add_child(skill_label)

		# Improve button
		var improve_button: Button = Button.new()
		improve_button.text = "Improve (Cost: " + str(skill.cost) + ")"
		# Handle signal connection with proper error handling
		var skill_error: Error = improve_button.pressed.connect(_on_skill_improve_pressed.bind(skill.name))
		if skill_error != OK:
			push_error("Failed to connect skill button signal: " + str(skill_error))
		skill_header.add_child(improve_button)

		# Description
		var desc_label: Label = Label.new()
		desc_label.text = skill.description
		desc_label.modulate = UIColors.COLOR_TEXT_SECONDARY
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		skill_container.add_child(desc_label)

		# Separator
		var separator: HSeparator = HSeparator.new()
		skill_container.add_child(separator)

func display_character(character: Character, stat_points: int = 0, skill_points: int = 0) -> void:
	## Display character and available advancement points
	current_character = character
	available_stat_points = stat_points
	available_skill_points = skill_points

	# Reset pending changes
	pending_stat_changes.clear()
	pending_skill_changes.clear()

	_update_display()

	if character:
		pass

func _update_display() -> void:
	## Update all UI displays
	_update_character_info()
	_update_stat_display()
	_update_skill_display()
	_update_points_display()
	_update_button_states()

func _update_character_info() -> void:
	## Update character header information
	if not current_character:
		if name_label:
			name_label.text = "No Character Selected"
		if level_label:
			level_label.text = "Level: 0"
		if xp_label:
			xp_label.text = "XP: 0 / 0.0"
		if xp_bar:
			xp_bar.value = 0
		return

	if name_label:
		name_label.text = current_character.character_name

	# Calculate level and XP (basic progression system)
	var level: int = _calculate_character_level(current_character)
	var xp_current: int = _get_character_xp(current_character)
	var xp_needed: int = _get_xp_needed_for_next_level(level)

	if level_label:
		level_label.text = "Level: " + str(level)

	if xp_label:
		xp_label.text = "XP: " + str(xp_current) + "/" + str(xp_needed)

	if xp_bar:
		xp_bar.max_value = xp_needed
		xp_bar.value = xp_current

func _update_stat_display() -> void:
	## Update stat controls display
	if not current_character:
		return

	var stats: Dictionary = {
		"Reaction": current_character.reactions,
		"Combat": current_character.combat,
		"Toughness": current_character.toughness,
		"Speed": current_character.speed,
		"Savvy": current_character.savvy,
		"Luck": current_character.luck
	}

	for stat_name: String in stats.keys():
		if stat_controls.has(stat_name):
			var controls: Dictionary = stat_controls[stat_name]
			var current_value: int = stats[stat_name]
			var pending_change: int = pending_stat_changes.get(stat_name, 0)

			controls.value_label.text = str(current_value)
			controls.pending_label.text = "+" + str(pending_change) if pending_change > 0 else str(pending_change)
			controls.pending_label.visible = pending_change != 0

func _update_skill_display() -> void:
	## Update skill controls display
	# This would be enhanced based on character's current skills
	# For now, it just updates button states
	pass

func _update_points_display() -> void:
	## Update available points display
	var used_stat_points: int = 0
	for change: int in pending_stat_changes.values():
		used_stat_points += change * 2 # Each stat point costs 2 advancement points

	var used_skill_points: int = 0
	for skill_name: String in pending_skill_changes.keys():
		var skill_cost: int = _get_skill_cost(skill_name)
		used_skill_points += pending_skill_changes[skill_name] * skill_cost

	if stat_points_label:
		stat_points_label.text = "Available Stat Points: " + str(available_stat_points - used_stat_points)

	if skill_points_label:
		skill_points_label.text = "Available Skill Points: " + str(available_skill_points - used_skill_points)

func _update_button_states() -> void:
	## Update button enabled/disabled states
	var can_apply: bool = (pending_stat_changes.size() > 0 or pending_skill_changes.size() > 0)

	if apply_button:
		apply_button.disabled = not can_apply

func _get_skill_cost(skill_name: String) -> int:
	## Get the cost of a specific skill
	for skill: Dictionary in available_skills:
		if skill.name == skill_name:
			return skill.cost
	return 1

func _calculate_character_level(character: Character) -> int:
	## Calculate character level based on stats and experience
	if not character:
		return 1

	# Simple level calculation based on total stats above starting values
	var base_stats: int = 12 # Minimum starting stats
	var current_stats: int = character.reactions + character.combat + character.toughness + character.speed + character.savvy + character.luck
	var bonus_stats: int = current_stats - base_stats

	# Fix narrowing conversion - explicit int conversion
	return 1 + int(bonus_stats / 3.0) # Level up every 3 stat points

func _get_character_xp(character: Character) -> int:
	## Get character's current XP
	if not character:
		return 0
	
	# Safe property access - check if character has experience tracking
	if character.has_method("get_experience_points"):
		return character.get_experience_points()
	elif character.has("experience_points"):
		return character.experience_points
	else:
		# Fallback: calculate based on character progression
		return (_calculate_character_level(character) - 1) * 100

func _get_xp_needed_for_next_level(current_level: int) -> int:
	## Get XP needed for next level
	return current_level * 100 # Simple progression: 100, 200, 300, etc.

# Signal handlers
func _on_stat_increase_pressed(stat_name: String) -> void:
	## Handle stat increase button
	var current_pending: int = pending_stat_changes.get(stat_name, 0)
	var cost: int = 2 # Each stat point costs 2 advancement points

	var used_points: int = 0
	for change: int in pending_stat_changes.values():
		used_points += change * 2

	if available_stat_points - used_points >= cost:
		pending_stat_changes[stat_name] = current_pending + 1
		_update_display()

func _on_stat_decrease_pressed(stat_name: String) -> void:
	## Handle stat decrease button
	var current_pending: int = pending_stat_changes.get(stat_name, 0)
	if current_pending > 0:
		pending_stat_changes[stat_name] = current_pending - 1
		if pending_stat_changes[stat_name] == 0:
			# Handle erase() return value by explicitly ignoring it
			var _was_erased: bool = pending_stat_changes.erase(stat_name)
		_update_display()

func _on_skill_improve_pressed(skill_name: String) -> void:
	## Handle skill improvement button
	var skill_cost: int = _get_skill_cost(skill_name)
	var current_level: int = pending_skill_changes.get(skill_name, 0)

	# Find skill max level
	var max_level: int = 1
	for skill: Dictionary in available_skills:
		if skill.name == skill_name:
			max_level = skill.max_level
			break

	if current_level < max_level:
		var used_points: int = 0
		for skill: String in pending_skill_changes.keys():
			used_points += pending_skill_changes[skill] * _get_skill_cost(skill)

		if available_skill_points - used_points >= skill_cost:
			pending_skill_changes[skill_name] = current_level + 1
			_update_display()

func _on_apply_pressed() -> void:
	## Apply all pending changes
	if not current_character:
		return

	# Apply stat changes
	for stat_name: String in pending_stat_changes.keys():
		var change: int = pending_stat_changes[stat_name]
		match stat_name:
			"Reaction":
				current_character.reactions += change
			"Combat":
				current_character.combat += change
			"Toughness":
				current_character.toughness += change
				# Update health when toughness changes
				current_character.max_health = current_character.toughness + 2
				current_character.health = min(current_character.health, current_character.max_health)
			"Speed":
				current_character.speed += change
			"Savvy":
				current_character.savvy += change
			"Luck":
				current_character.luck += change

	# Apply skill changes (would add to character's skill list)
	for skill_name: String in pending_skill_changes.keys():
		var level: int = pending_skill_changes[skill_name]
		# Add skill to character (implementation depends on character skill system)
		if current_character and current_character.has_method("add_skill"):
			current_character.add_skill(skill_name)
		else:
			# Fallback: add as trait
			if current_character.has_method("add_trait"):
				current_character.add_trait(str(skill_name) + " (Level " + str(level) + ")")

	progression_applied.emit(current_character)

func _on_cancel_pressed() -> void:
	## Cancel progression changes
	progression_cancelled.emit()

func _on_auto_advance_pressed() -> void:
	## Automatically advance character with balanced improvements
	if not current_character:
		return

	# Clear pending changes
	pending_stat_changes.clear()
	pending_skill_changes.clear()

	# Auto-distribute stat points (balanced approach)
	var remaining_stat_points: int = available_stat_points
	var stats_to_improve: Array[String] = ["Combat", "Toughness", "Savvy"] # Priority stats

	while remaining_stat_points >= 2: # Each stat costs 2 points
		for stat: String in stats_to_improve:
			if remaining_stat_points >= 2:
				pending_stat_changes[stat] = pending_stat_changes.get(stat, 0) + 1
				remaining_stat_points -= 2
			if remaining_stat_points < 2:
				break

	# Auto-select skills
	var remaining_skill_points: int = available_skill_points
	var priority_skills: Array[String] = ["Combat Training", "Medical Training"]

	for skill: String in priority_skills:
		var cost: int = _get_skill_cost(skill)
		if remaining_skill_points >= cost:
			pending_skill_changes[skill] = 1
			remaining_skill_points -= cost

	_update_display()

func get_character() -> Character:
	## Get the current character
	return current_character

