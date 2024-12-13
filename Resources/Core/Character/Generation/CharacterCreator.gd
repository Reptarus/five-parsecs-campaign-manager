@tool
extends Control

const Character = preload("res://Resources/Core/Character/Base/Character.gd")
const CharacterStats = preload("res://Resources/Core/Character/Base/CharacterStats.gd")
const CharacterTableRoller = preload("res://Resources/Core/Character/Generation/CharacterTableRoller.gd")
const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

enum CreatorMode {
	CHARACTER,
	CAPTAIN,
	INITIAL_CREW
}

signal character_created(character: Character)
signal character_edited(character: Character)
signal back_pressed

# Node References
@onready var name_input: LineEdit = %NameInput
@onready var origin_options: OptionButton = %OriginOptions
@onready var background_options: OptionButton = %BackgroundOptions
@onready var class_options: OptionButton = %ClassOptions
@onready var motivation_options: OptionButton = %MotivationOptions
@onready var preview_info: RichTextLabel = %PreviewInfo
@onready var portrait_dialog: FileDialog = %PortraitDialog

@onready var randomize_button: Button = %RandomizeButton
@onready var clear_button: Button = %ClearButton
@onready var add_to_crew_button: Button = %AddToCrewButton
@onready var back_button: Button = %BackButton

var current_character: Character
var creator_mode: CreatorMode = CreatorMode.CHARACTER
var parent_node: Node
var current_bonuses: Dictionary = {
	"background": {},
	"class": {},
	"motivation": {}
}

func _ready() -> void:
	_setup_ui()
	_setup_signals()
	clear()

func _setup_ui() -> void:
	# Setup Origin Options
	origin_options.clear()
	for origin in GlobalEnums.Origin.values():
		var origin_name = GlobalEnums.Origin.keys()[origin].capitalize().replace("_", " ")
		origin_options.add_item(origin_name, origin)
	
	# Setup Background Options
	background_options.clear()
	for background in GlobalEnums.CharacterBackground.values():
		var bg_name = GlobalEnums.CharacterBackground.keys()[background].capitalize().replace("_", " ")
		background_options.add_item(bg_name, background)
	
	# Setup Class Options
	class_options.clear()
	for char_class in GlobalEnums.CharacterClass.values():
		var class_display_name = GlobalEnums.CharacterClass.keys()[char_class].capitalize().replace("_", " ")
		class_options.add_item(class_display_name, char_class)
	
	# Setup Motivation Options
	motivation_options.clear()
	for motivation in GlobalEnums.CharacterMotivation.values():
		var mot_name = GlobalEnums.CharacterMotivation.keys()[motivation].capitalize().replace("_", " ")
		motivation_options.add_item(mot_name, motivation)
	
	# Setup Portrait Dialog
	portrait_dialog.file_selected.connect(_on_portrait_selected)

func _setup_signals() -> void:
	name_input.text_changed.connect(_on_name_changed)
	origin_options.item_selected.connect(_on_origin_selected)
	background_options.item_selected.connect(_on_background_selected)
	class_options.item_selected.connect(_on_class_selected)
	motivation_options.item_selected.connect(_on_motivation_selected)
	
	randomize_button.pressed.connect(_on_randomize_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	add_to_crew_button.pressed.connect(_on_add_to_crew_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func initialize(mode: CreatorMode = CreatorMode.CHARACTER, parent: Node = null) -> void:
	creator_mode = mode
	parent_node = parent
	clear()

func clear() -> void:
	current_character = Character.new()
	if creator_mode == CreatorMode.CAPTAIN:
		_setup_captain_bonuses()
	elif creator_mode == CreatorMode.INITIAL_CREW:
		_setup_initial_crew_bonuses()
	
	name_input.text = ""
	origin_options.selected = 0
	background_options.selected = 0
	class_options.selected = 0
	motivation_options.selected = 0
	
	current_bonuses.clear()
	current_bonuses = {
		"background": {},
		"class": {},
		"motivation": {}
	}
	
	_update_preview()
	_validate_character()

func _on_name_changed(new_text: String) -> void:
	if current_character:
		current_character.character_name = new_text
		_update_preview()
		_validate_character()

func _on_origin_selected(index: int) -> void:
	if current_character:
		current_character.origin = index
		_update_preview()
		_validate_character()

func _on_background_selected(index: int) -> void:
	if current_character:
		current_character.background = GlobalEnums.CharacterBackground.keys()[index]
		_apply_background_bonuses(index)
		_update_preview()
		_validate_character()

func _on_class_selected(index: int) -> void:
	if current_character:
		current_character.character_class = index
		_apply_class_bonuses(index)
		_update_preview()
		_validate_character()

func _on_motivation_selected(index: int) -> void:
	if current_character:
		current_character.motivation = GlobalEnums.CharacterMotivation.keys()[index]
		_apply_motivation_bonuses(index)
		_update_preview()
		_validate_character()

func _on_randomize_pressed() -> void:
	if current_character == null:
		return
	
	# Randomize all fields
	name_input.text = CharacterTableRoller.new().generate_random_name()
	origin_options.selected = randi() % origin_options.item_count
	background_options.selected = randi() % background_options.item_count
	class_options.selected = randi() % class_options.item_count
	motivation_options.selected = randi() % motivation_options.item_count
	
	# Update character with random values
	_on_name_changed(name_input.text)
	_on_origin_selected(origin_options.selected)
	_on_background_selected(background_options.selected)
	_on_class_selected(class_options.selected)
	_on_motivation_selected(motivation_options.selected)

func _on_clear_pressed() -> void:
	clear()

func _on_add_to_crew_pressed() -> void:
	if current_character and _validate_character():
		match creator_mode:
			CreatorMode.CAPTAIN:
				character_created.emit(current_character)
			CreatorMode.INITIAL_CREW:
				character_created.emit(current_character)
			_:
				character_edited.emit(current_character)

func _on_portrait_selected(path: String) -> void:
	if current_character:
		current_character.portrait_path = path
		_update_preview()

func _validate_character() -> bool:
	var is_valid = current_character != null and \
				   current_character.character_name.length() > 0
	
	add_to_crew_button.disabled = not is_valid
	return is_valid

func _setup_captain_bonuses() -> void:
	if not current_character or not current_character.stats:
		return
	
	# Apply captain-specific bonuses
	current_character.stats.combat_skill += 1
	current_character.stats.luck += 1

func _setup_initial_crew_bonuses() -> void:
	if not current_character or not current_character.stats:
		return
	
	# Initial crew members get standard starting stats
	current_character.stats.reset_to_base_stats()

func _apply_background_bonuses(background_index: int) -> void:
	current_bonuses.background.clear()
	
	# Get background data from CharacterTableRoller
	var table_roller = CharacterTableRoller.new()
	var background_data = table_roller.get_background_data(background_index)
	
	if background_data:
		# Apply stat bonuses
		if background_data.stat_bonus:
			for stat_name in background_data.stat_bonus:
				var bonus = background_data.stat_bonus[stat_name]
				match stat_name:
					"REACTIONS": current_character.stats.reactions += bonus
					"SPEED": current_character.stats.speed += bonus
					"COMBAT_SKILL": current_character.stats.combat_skill += bonus
					"TOUGHNESS": current_character.stats.toughness += bonus
					"SAVVY": current_character.stats.savvy += bonus
					"LUCK": current_character.stats.luck += bonus
				current_bonuses.background["+" + str(bonus) + " " + stat_name.capitalize()] = true
		
		# Apply resource bonuses
		for resource in background_data.resources:
			match resource:
				"credits_1d6":
					var roll = (randi() % 6) + 1
					current_character.add_credits(roll, "1d6 = " + str(roll))
					current_bonuses.background["+" + str(roll) + " Credits (1d6)"] = true
				"credits_2d6":
					var roll = (randi() % 6) + (randi() % 6) + 2
					current_character.add_credits(roll, "2d6 = " + str(roll))
					current_bonuses.background["+" + str(roll) + " Credits (2d6)"] = true
				"story_point":
					current_character.add_story_points(1)
					current_bonuses.background["+1 Story Point"] = true
				"patron":
					current_bonuses.background["Gain a Patron"] = true
				"quest_rumor":
					current_bonuses.background["Gain a Quest Rumor"] = true
		
		# Apply equipment bonuses
		for roll in background_data.starting_rolls:
			match roll:
				"low_tech_weapon":
					current_character.roll_and_add_weapon("low_tech")
					current_bonuses.background["Low-Tech Weapon"] = true
				"military_weapon":
					current_character.roll_and_add_weapon("military")
					current_bonuses.background["Military Weapon"] = true
				"high_tech_weapon":
					current_character.roll_and_add_weapon("high_tech")
					current_bonuses.background["High-Tech Weapon"] = true
				"gear":
					current_character.roll_and_add_gear()
					current_bonuses.background["Random Gear"] = true

func _apply_class_bonuses(class_index: int) -> void:
	current_bonuses.class.clear()
	
	# Get class data from CharacterTableRoller
	var table_roller = CharacterTableRoller.new()
	var class_data = table_roller.get_class_data(class_index)
	
	if class_data:
		# Apply stat bonuses
		if class_data.stat_bonus:
			for stat_name in class_data.stat_bonus:
				var bonus = class_data.stat_bonus[stat_name]
				match stat_name:
					"REACTIONS": current_character.stats.reactions += bonus
					"SPEED": current_character.stats.speed += bonus
					"COMBAT_SKILL": current_character.stats.combat_skill += bonus
					"TOUGHNESS": current_character.stats.toughness += bonus
					"SAVVY": current_character.stats.savvy += bonus
					"LUCK": current_character.stats.luck += bonus
				current_bonuses.class["+" + str(bonus) + " " + stat_name.capitalize()] = true
		
		# Apply resource bonuses
		for resource in class_data.resources:
			match resource:
				"credits_1d6":
					var roll = (randi() % 6) + 1
					current_character.add_credits(roll, "1d6 = " + str(roll))
					current_bonuses.class["+" + str(roll) + " Credits (1d6)"] = true
				"credits_2d6":
					var roll = (randi() % 6) + (randi() % 6) + 2
					current_character.add_credits(roll, "2d6 = " + str(roll))
					current_bonuses.class["+" + str(roll) + " Credits (2d6)"] = true
				"story_point":
					current_character.add_story_points(1)
					current_bonuses.class["+1 Story Point"] = true
				"patron":
					current_bonuses.class["Gain a Patron"] = true
				"rival":
					current_bonuses.class["Gain a Rival"] = true
		
		# Apply equipment bonuses
		for roll in class_data.starting_rolls:
			match roll:
				"low_tech_weapon":
					current_character.roll_and_add_weapon("low_tech")
					current_bonuses.class["Low-Tech Weapon"] = true
				"military_weapon":
					current_character.roll_and_add_weapon("military")
					current_bonuses.class["Military Weapon"] = true
				"high_tech_weapon":
					current_character.roll_and_add_weapon("high_tech")
					current_bonuses.class["High-Tech Weapon"] = true
				"gear":
					current_character.roll_and_add_gear()
					current_bonuses.class["Random Gear"] = true

func _apply_motivation_bonuses(motivation_index: int) -> void:
	current_bonuses.motivation.clear()
	
	# Get motivation data from CharacterTableRoller
	var table_roller = CharacterTableRoller.new()
	var motivation_data = table_roller.get_motivation_data(motivation_index)
	
	if motivation_data:
		# Apply stat bonuses
		if motivation_data.stat_bonus:
			for stat_name in motivation_data.stat_bonus:
				var bonus = motivation_data.stat_bonus[stat_name]
				match stat_name:
					"REACTIONS": current_character.stats.reactions += bonus
					"SPEED": current_character.stats.speed += bonus
					"COMBAT_SKILL": current_character.stats.combat_skill += bonus
					"TOUGHNESS": current_character.stats.toughness += bonus
					"SAVVY": current_character.stats.savvy += bonus
					"LUCK": current_character.stats.luck += bonus
				current_bonuses.motivation["+" + str(bonus) + " " + stat_name.capitalize()] = true
		
		# Apply resource bonuses
		for resource in motivation_data.resources:
			match resource:
				"credits_1d6":
					var roll = (randi() % 6) + 1
					current_character.add_credits(roll, "1d6 = " + str(roll))
					current_bonuses.motivation["+" + str(roll) + " Credits (1d6)"] = true
				"credits_2d6":
					var roll = (randi() % 6) + (randi() % 6) + 2
					current_character.add_credits(roll, "2d6 = " + str(roll))
					current_bonuses.motivation["+" + str(roll) + " Credits (2d6)"] = true
				"story_point":
					current_character.add_story_points(1)
					current_bonuses.motivation["+1 Story Point"] = true
				"patron":
					current_bonuses.motivation["Gain a Patron"] = true
				"rival":
					current_bonuses.motivation["Gain a Rival"] = true
				"quest_rumor":
					current_bonuses.motivation["Gain a Quest Rumor"] = true
		
		# Apply equipment bonuses
		for roll in motivation_data.starting_rolls:
			match roll:
				"low_tech_weapon":
					current_character.roll_and_add_weapon("low_tech")
					current_bonuses.motivation["Low-Tech Weapon"] = true
				"military_weapon":
					current_character.roll_and_add_weapon("military")
					current_bonuses.motivation["Military Weapon"] = true
				"high_tech_weapon":
					current_character.roll_and_add_weapon("high_tech")
					current_bonuses.motivation["High-Tech Weapon"] = true
				"gear":
					current_character.roll_and_add_gear()
					current_bonuses.motivation["Random Gear"] = true

func _update_preview() -> void:
	if current_character == null or preview_info == null:
		return
		
	# Disconnect existing signal connection if it exists
	if preview_info.meta_clicked.is_connected(_on_preview_meta_clicked):
		preview_info.meta_clicked.disconnect(_on_preview_meta_clicked)
	
	var preview_text = ""
	
	# Portrait Preview Box with selection button
	preview_text += "[center][bgcolor=black]"
	if current_character.portrait_path and FileAccess.file_exists(current_character.portrait_path):
		preview_text += "[img=100x100]" + current_character.portrait_path + "[/img]"
	else:
		preview_text += "[img=100x100]res://assets/BookImages/portrait_02.png[/img]"
	preview_text += "[/bgcolor]\n"
	preview_text += "[url=select_portrait]Select Portrait[/url][/center]\n\n"
	
	# Basic Info
	preview_text += "[color=lime]Name:[/color] " + current_character.character_name + "\n\n"
	
	# Origin with description
	preview_text += "[color=lime]Origin:[/color] " + GlobalEnums.Origin.keys()[current_character.origin].capitalize().replace("_", " ") + "\n"
	preview_text += _get_origin_description(current_character.origin) + "\n\n"
	
	# Background and Class
	preview_text += "[color=lime]Background:[/color] " + current_character.background + "\n"
	if current_bonuses.background.size() > 0:
		preview_text += "[color=yellow]Background Bonuses:[/color]\n"
		for bonus in current_bonuses.background:
			preview_text += "• " + bonus + "\n"
	preview_text += "\n"
	
	preview_text += "[color=lime]Class:[/color] " + GlobalEnums.CharacterClass.keys()[current_character.character_class].capitalize().replace("_", " ") + "\n"
	if current_bonuses.class.size() > 0:
		preview_text += "[color=yellow]Class Bonuses:[/color]\n"
		for bonus in current_bonuses.class:
			preview_text += "• " + bonus + "\n"
	preview_text += "\n"
	
	preview_text += "[color=lime]Motivation:[/color] " + current_character.motivation + "\n"
	if current_bonuses.motivation.size() > 0:
		preview_text += "[color=yellow]Motivation Bonuses:[/color]\n"
		for bonus in current_bonuses.motivation:
			preview_text += "• " + bonus + "\n"
	preview_text += "\n"
	
	# Stats
	preview_text += "[color=lime]Stats:[/color]\n"
	preview_text += "[color=yellow]Reactions:[/color] " + str(current_character.stats.reactions) + "\n"
	preview_text += "[color=yellow]Speed:[/color] " + str(current_character.stats.speed) + "\"\n"
	preview_text += "[color=yellow]Combat Skill:[/color] +" + str(current_character.stats.combat_skill) + "\n"
	preview_text += "[color=yellow]Toughness:[/color] " + str(current_character.stats.toughness) + "\n"
	preview_text += "[color=yellow]Savvy:[/color] +" + str(current_character.stats.savvy) + "\n"
	preview_text += "[color=yellow]Luck:[/color] " + str(current_character.stats.luck) + "\n\n"
	
	# Equipment Section
	preview_text += "[color=lime]Equipment:[/color]\n"
	
	# Weapon
	if current_character.equipped_weapon != null:
		preview_text += "[color=yellow]Weapon:[/color] "
		preview_text += current_character.equipped_weapon.name
		if current_character.weapon_roll_result and current_character.weapon_roll_result.length() > 0:
			preview_text += " (" + current_character.weapon_roll_result + ")"
		preview_text += "\n"
		preview_text += "• Range: " + str(current_character.equipped_weapon.range) + "\"\n"
		preview_text += "• Shots: " + str(current_character.equipped_weapon.shots) + "\n"
		preview_text += "• Damage: " + str(current_character.equipped_weapon.damage) + "\n"
		if current_character.equipped_weapon.special_rules.size() > 0:
			preview_text += "• Traits: " + ", ".join(current_character.equipped_weapon.special_rules)
		preview_text += "\n"
	else:
		preview_text += "[color=#666666]No weapon equipped[/color]\n"
	
	preview_text += "\n"
	
	# Resources
	preview_text += "[color=lime]Resources:[/color]\n"
	preview_text += "[color=yellow]Credits:[/color] " + str(current_character.credits)
	if current_character.credits_roll_result and current_character.credits_roll_result.length() > 0:
		preview_text += " (" + current_character.credits_roll_result + ")"
	preview_text += "\n"
	preview_text += "[color=yellow]Story Points:[/color] " + str(current_character.story_points) + "\n"
	preview_text += "[color=yellow]Experience:[/color] " + str(current_character.experience)
	
	preview_info.text = preview_text
	preview_info.meta_clicked.connect(_on_preview_meta_clicked)

func _on_preview_meta_clicked(meta: String) -> void:
	if meta == "select_portrait":
		portrait_dialog.popup_centered()

func _get_origin_description(origin: int) -> String:
	match origin:
		GlobalEnums.Origin.HUMAN:
			return "[color=#666666]Baseline humans are plain, ordinary people distributed across thousands of worlds, cultures and environments. Their appearance, customs and outlook on life can vary tremendously.[/color]"
		GlobalEnums.Origin.ENGINEER:
			return "[color=#666666]Slim humanoids with a fragile physique. They have an innate talent for interfacing with machinery.[/color]"
		GlobalEnums.Origin.KERIN:
			return "[color=#666666]Proud and warlike aliens with a penchant for brutality and a peculiar sense of honor.[/color]"
		GlobalEnums.Origin.SOULLESS:
			return "[color=#666666]A species of cybernetic organisms, connected into a combined hive-intelligence.[/color]"
		GlobalEnums.Origin.PRECURSOR:
			return "[color=#666666]Graceful and refined alien humanoids who were traveling the stars when other species were still lingering in caves.[/color]"
		GlobalEnums.Origin.SWIFT:
			return "[color=#666666]Diminutive, winged, lizard people who received their nickname due to their erratic, jerky motions.[/color]"
		_:
			return ""

func _on_back_pressed() -> void:
	back_pressed.emit()
