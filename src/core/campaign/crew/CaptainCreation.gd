class_name CaptainCreation
extends Control

const Character = preload("res://src/core/character/Base/Character.gd")
const CharacterStats = preload("res://src/core/character/Base/CharacterStats.gd")
const CharacterTableRoller = preload("res://src/core/character/Generation/CharacterTableRoller.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var name_input: LineEdit = %NameInput
@onready var origin_option: OptionButton = %OriginOption
@onready var background_option: OptionButton = %BackgroundOption
@onready var class_option: OptionButton = %ClassOption
@onready var motivation_option: OptionButton = %MotivationOption
@onready var preview_label: RichTextLabel = %PreviewLabel
@onready var stat_container: VBoxContainer = %StatContainer
@onready var confirm_button: Button = %ConfirmButton
@onready var randomize_button: Button = %RandomizeButton
@onready var clear_button: Button = %ClearButton
@onready var back_button: Button = %BackButton

var current_captain: Character
var stat_points_remaining: int = 5
var current_bonuses: Dictionary = {
	"background": {},
	"class": {},
	"motivation": {}
}

signal captain_created(captain: Character)
signal back_pressed

func _ready() -> void:
	# Create character first
	current_captain = Character.new()
	
	# Setup UI in correct order
	_setup_options()
	_initialize_stats()
	_connect_signals()
	_update_preview()

func _initialize_stats() -> void:
	# Reset character stats to base values
	current_captain.stats = CharacterStats.new()
	current_captain.stats.reactions = 0
	current_captain.stats.speed = 0
	current_captain.stats.combat_skill = 0
	current_captain.stats.toughness = 0
	current_captain.stats.savvy = 0
	current_captain.stats.luck = 0
	
	# Add Leader bonus Luck point
	current_captain.stats.luck += 1
	stat_points_remaining = 5

func _setup_options() -> void:
	# Setup Origin options
	origin_option.clear()
	for origin in GlobalEnums.Origin.values():
		var origin_display = str(GlobalEnums.Origin.keys()[origin]).replace("_", " ")
		if origin_display.length() > 0:
			origin_display = origin_display[0].to_upper() + origin_display.substr(1).to_lower()
		origin_option.add_item(origin_display, origin)
	
	# Setup Background options
	background_option.clear()
	for background in GlobalEnums.CharacterBackground.values():
		var bg_display = str(GlobalEnums.CharacterBackground.keys()[background]).replace("_", " ")
		if bg_display.length() > 0:
			bg_display = bg_display[0].to_upper() + bg_display.substr(1).to_lower()
		background_option.add_item(bg_display, background)
	
	# Setup Class options
	class_option.clear()
	for char_class in GlobalEnums.CharacterClass.values():
		var class_display = str(GlobalEnums.CharacterClass.keys()[char_class]).replace("_", " ")
		if class_display.length() > 0:
			class_display = class_display[0].to_upper() + class_display.substr(1).to_lower()
		class_option.add_item(class_display, char_class)
	
	# Setup Motivation options
	motivation_option.clear()
	for motivation in GlobalEnums.CharacterMotivation.values():
		var mot_display = str(GlobalEnums.CharacterMotivation.keys()[motivation]).replace("_", " ")
		if mot_display.length() > 0:
			mot_display = mot_display[0].to_upper() + mot_display.substr(1).to_lower()
		motivation_option.add_item(mot_display, motivation)

func _connect_signals() -> void:
	name_input.text_changed.connect(_on_name_changed)
	origin_option.item_selected.connect(_on_origin_selected)
	background_option.item_selected.connect(_on_background_selected)
	class_option.item_selected.connect(_on_class_selected)
	motivation_option.item_selected.connect(_on_motivation_selected)
	confirm_button.pressed.connect(_on_confirm_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_name_changed(new_name: String) -> void:
	current_captain.character_name = new_name
	_update_preview()

func _on_origin_selected(index: int) -> void:
	current_captain.origin = origin_option.get_item_id(index)
	_update_preview()

func _on_background_selected(index: int) -> void:
	var background = background_option.get_item_id(index)
	current_captain.background = GlobalEnums.CharacterBackground.keys()[background]
	_apply_background_bonuses(background)
	_update_preview()

func _apply_background_bonuses(background_id: int) -> void:
	current_bonuses.background.clear()
	
	# Get background data from CharacterTableRoller
	var table_roller = CharacterTableRoller.new()
	var background_data = table_roller.get_background_data(background_id)
	
	if background_data:
		# Apply stat bonuses
		if background_data.stat_bonus:
			for stat_name in background_data.stat_bonus:
				var bonus = background_data.stat_bonus[stat_name]
				match stat_name:
					"REACTIONS": current_captain.stats.reactions += bonus
					"SPEED": current_captain.stats.speed += bonus
					"COMBAT_SKILL": current_captain.stats.combat_skill += bonus
					"TOUGHNESS": current_captain.stats.toughness += bonus
					"SAVVY": current_captain.stats.savvy += bonus
					"LUCK": current_captain.stats.luck += bonus
				current_bonuses.background["+" + str(bonus) + " " + stat_name.capitalize()] = true

func _on_class_selected(index: int) -> void:
	current_captain.character_class = class_option.get_item_id(index)
	_apply_class_bonuses(current_captain.character_class)
	_update_preview()

func _apply_class_bonuses(class_id: int) -> void:
	current_bonuses.class.clear()
	
	match class_id:
		GlobalEnums.CharacterClass.SOLDIER:
			current_captain.stats.combat_skill += 1
			current_captain.stats.toughness += 1
			current_bonuses.class["COMBAT_SKILL"] = true
			current_bonuses.class["TOUGHNESS"] = true
		GlobalEnums.CharacterClass.MEDIC:
			current_captain.stats.savvy += 1
			current_captain.stats.luck += 1
			current_bonuses.class["SAVVY"] = true
			current_bonuses.class["LUCK"] = true
		GlobalEnums.CharacterClass.TECH:
			current_captain.stats.savvy += 1
			current_captain.stats.speed += 1
			current_bonuses.class["SAVVY"] = true
			current_bonuses.class["SPEED"] = true
		GlobalEnums.CharacterClass.SCOUT:
			current_captain.stats.speed += 1
			current_captain.stats.reactions += 1
			current_bonuses.class["SPEED"] = true
			current_bonuses.class["REACTIONS"] = true
		GlobalEnums.CharacterClass.LEADER:
			current_captain.stats.combat_skill += 1
			current_captain.stats.luck += 1
			current_bonuses.class["COMBAT_SKILL"] = true
			current_bonuses.class["LUCK"] = true
		GlobalEnums.CharacterClass.SPECIALIST:
			current_captain.stats.savvy += 1
			current_captain.stats.combat_skill += 1
			current_bonuses.class["SAVVY"] = true
			current_bonuses.class["COMBAT_SKILL"] = true

func _on_motivation_selected(index: int) -> void:
	var motivation = motivation_option.get_item_id(index)
	current_captain.motivation = GlobalEnums.CharacterMotivation.keys()[motivation]
	_apply_motivation_bonuses(motivation)
	_update_preview()

func _apply_motivation_bonuses(motivation_id: int) -> void:
	current_bonuses.motivation.clear()
	
	match motivation_id:
		GlobalEnums.CharacterMotivation.GLORY:
			current_captain.stats.combat_skill += 1
			current_bonuses.motivation["COMBAT_SKILL"] = true
		GlobalEnums.CharacterMotivation.WEALTH:
			current_captain.stats.savvy += 1
			current_bonuses.motivation["SAVVY"] = true
		GlobalEnums.CharacterMotivation.SURVIVAL:
			current_captain.stats.reactions += 1
			current_bonuses.motivation["REACTIONS"] = true

func _on_confirm_pressed() -> void:
	if current_captain.character_name.is_empty():
		return
	
	# Emit signal with created captain
	captain_created.emit(current_captain)

func _on_randomize_pressed() -> void:
	# Randomize all fields
	name_input.text = CharacterTableRoller.new().generate_random_name()
	origin_option.selected = randi() % origin_option.item_count
	background_option.selected = randi() % background_option.item_count
	class_option.selected = randi() % class_option.item_count
	motivation_option.selected = randi() % motivation_option.item_count
	
	# Update captain with random values
	_on_name_changed(name_input.text)
	_on_origin_selected(origin_option.selected)
	_on_background_selected(background_option.selected)
	_on_class_selected(class_option.selected)
	_on_motivation_selected(motivation_option.selected)

func _on_clear_pressed() -> void:
	# Reset all fields
	name_input.text = ""
	origin_option.selected = 0
	background_option.selected = 0
	class_option.selected = 0
	motivation_option.selected = 0
	
	# Reset stats and bonuses
	current_bonuses.clear()
	current_bonuses = {
		"background": {},
		"class": {},
		"motivation": {}
	}
	
	# Create new captain
	current_captain = Character.new()
	_initialize_stats()
	_update_preview()

func _on_back_pressed() -> void:
	back_pressed.emit()

func _update_preview() -> void:
	if not current_captain:
		return
	
	var preview_text = ""
	
	# Name and basic info
	preview_text += "[color=lime]Name:[/color] " + (current_captain.character_name if not current_captain.character_name.is_empty() else "---") + "\n\n"
	
	# Origin info
	var origin_text = "Human"
	if current_captain.origin >= 0 and current_captain.origin < GlobalEnums.Origin.size():
		origin_text = str(GlobalEnums.Origin.keys()[current_captain.origin]).capitalize().replace("_", " ")
	preview_text += "[color=lime]Origin:[/color] " + origin_text + "\n"
	
	# Background info
	preview_text += "[color=lime]Background:[/color] " + \
		(GlobalEnums.CharacterBackground.keys()[current_captain.background] \
		if current_captain.background >= 0 else "---") + "\n"
	if current_bonuses.background.size() > 0:
		preview_text += "[color=yellow]Background Bonuses:[/color]\n"
		for bonus in current_bonuses.background:
			preview_text += "• +" + str(current_bonuses.background[bonus]) + " " + bonus + "\n"
	preview_text += "\n"
	
	# Class info
	var class_text = "---"
	if current_captain.character_class >= 0 and current_captain.character_class < GlobalEnums.CharacterClass.size():
		class_text = str(GlobalEnums.CharacterClass.keys()[current_captain.character_class]).capitalize().replace("_", " ")
	preview_text += "[color=lime]Class:[/color] " + class_text + "\n"
	if current_bonuses.class.size() > 0:
		preview_text += "[color=yellow]Class Bonuses:[/color]\n"
		for bonus in current_bonuses.class:
			preview_text += "• +" + str(current_bonuses.class[bonus]) + " " + bonus + "\n"
	preview_text += "\n"
	
	# Motivation
	preview_text += "[color=lime]Motivation:[/color] " + \
		(GlobalEnums.CharacterMotivation.keys()[current_captain.motivation] \
		if current_captain.motivation >= 0 else "---") + "\n"
	if current_bonuses.motivation.size() > 0:
		preview_text += "[color=yellow]Motivation Bonuses:[/color]\n"
		for bonus in current_bonuses.motivation:
			preview_text += "• +" + str(current_bonuses.motivation[bonus]) + " " + bonus + "\n"
	preview_text += "\n"
	
	# Stats
	preview_text += "[color=lime]Stats:[/color]\n"
	preview_text += "[color=yellow]Reactions:[/color] " + str(current_captain.stats.reactions) + "\n"
	preview_text += "[color=yellow]Speed:[/color] " + str(current_captain.stats.speed) + "\"\n"
	preview_text += "[color=yellow]Combat Skill:[/color] +" + str(current_captain.stats.combat_skill) + "\n"
	preview_text += "[color=yellow]Toughness:[/color] " + str(current_captain.stats.toughness) + "\n"
	preview_text += "[color=yellow]Savvy:[/color] +" + str(current_captain.stats.savvy) + "\n"
	preview_text += "[color=yellow]Luck:[/color] " + str(current_captain.stats.luck) + "\n"
	
	preview_label.text = preview_text
