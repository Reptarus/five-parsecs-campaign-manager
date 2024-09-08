extends Control

const Weapon = preload("res://Scripts/Weapons/Weapon.gd")

@onready var species_option_button: OptionButton = $CrewStatsAndInfo/SpeciesSelection/SpeciesSelection
@onready var character_portrait: TextureRect = $CrewPictureAndStats/PictureandBMCcontrols/CharacterPortrait
@onready var background_info: RichTextLabel = $CrewPictureAndStats/CharacterFlavorBreakdown/SpeciesInfoLabel
@onready var save_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Save
@onready var clear_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Clear
@onready var import_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Import
@onready var export_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Export
@onready var background_left: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/BackgroundSelection/LeftArrow
@onready var background_right: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/BackgroundSelection/RightArrow
@onready var motivation_left: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/MotivationSelection/LeftArrow
@onready var motivation_right: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/MotivationSelection/RightArrow
@onready var class_left: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/ClassSelection/LeftArrow
@onready var class_right: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/ClassSelection/RightArrow
@onready var user_notes: TextEdit = $CrewStatsAndInfo/UserNotes

var current_character: Character
var background_index: int = 0
var motivation_index: int = 0
var class_index: int = 0


func _ready():
	species_option_button.connect("item_selected", _on_species_selected)
	save_button.connect("pressed", _on_save_pressed)
	clear_button.connect("pressed", _on_clear_pressed)
	import_button.connect("pressed", _on_import_pressed)
	export_button.connect("pressed", _on_export_pressed)
	background_left.connect("pressed", _on_background_left_pressed)
	background_right.connect("pressed", _on_background_right_pressed)
	motivation_left.connect("pressed", _on_motivation_left_pressed)
	motivation_right.connect("pressed", _on_motivation_right_pressed)
	class_left.connect("pressed", _on_class_left_pressed)
	class_right.connect("pressed", _on_class_right_pressed)
	user_notes.connect("text_changed", _on_user_notes_changed)
	
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spin_box = get_node("CrewStatsAndInfo/StatDistribution/" + stat + "/" + stat + "SpinBox")
		spin_box.connect("value_changed", _on_stat_changed.bind(stat.to_lower()))
	
	_generate_random_character()

func _generate_random_character():
	current_character = Character.new()
	current_character.generate_random()
	print("Generated random character: ", current_character.name)
	print("Character stats: ", current_character.stats)
	update_ui()

func update_ui():
	print("Updating UI for character: ", current_character.name if current_character else "None")
	if not current_character:
		print("Warning: No current character to update UI")
		return
	
	character_portrait.texture = load(current_character.portrait)
	species_option_button.selected = current_character.race
	
	# Use a ternary operator to handle the notes
	user_notes.text = current_character.notes if "notes" in current_character else ""
	
	update_character_info()
	update_stats()
	update_weapons_and_gear()

func update_character_info():
	var info_text = "Species: %s\n\n" % GlobalEnums.Race.keys()[current_character.race]
	info_text += "%s\n\n" % CharacterCreationData.get_race_traits(current_character.race)
	
	info_text += "Background: %s\n" % GlobalEnums.Background.keys()[background_index]
	info_text += "%s\n\n" % CharacterCreationData.get_background_info(GlobalEnums.Background.keys()[background_index])
	
	info_text += "Motivation: %s\n" % GlobalEnums.Motivation.keys()[motivation_index]
	var motivation_stats = CharacterCreationData.get_motivation_stats(current_character.motivation)
	if motivation_stats is Dictionary and motivation_stats.has("description"):
		info_text += "%s\n\n" % motivation_stats["description"]
	
	info_text += "Class: %s\n" % GlobalEnums.Class.keys()[class_index]
	var class_stats = CharacterCreationData.get_class_stats(current_character.character_class)
	if class_stats is Dictionary and class_stats.has("description"):
		info_text += "%s\n\n" % class_stats["description"]
	
	info_text += "Stats:\n"
	for stat in current_character.stats:
		info_text += "%s: %d\n" % [stat.capitalize(), current_character.stats[stat]]
	
	background_info.text = info_text

func update_stats():
	for stat in ["reactions", "speed", "combat_skill", "toughness", "savvy", "luck"]:
		var spin_box = get_node_or_null("CrewStatsAndInfo/StatDistribution/" + stat.capitalize() + "/" + stat.capitalize() + "SpinBox")
		if spin_box and current_character.stats.has(stat):
			spin_box.value = current_character.stats[stat]
			print("Updated ", stat, " to ", current_character.stats[stat])
		else:
			print("Warning: SpinBox not found or stat missing for: " + stat)

func update_weapons_and_gear():
	var containers = {
		"Weapon": $CrewStatsAndInfo/StartingWeapons/Weapon,
		"Range": $CrewStatsAndInfo/StartingWeapons/Range,
		"Shots": $CrewStatsAndInfo/StartingWeapons/Shots,
		"Damage": $CrewStatsAndInfo/StartingWeapons/Damage,
		"Traits": $CrewStatsAndInfo/StartingWeapons/Traits
	}
	
	# Clear all value labels
	for container in containers.values():
		for i in range(1, 4):  # We have 3 value labels
			var label = container.get_node("Value" + str(i))
			if label:
				label.text = ""
	
	# Populate with character's weapons
	var weapons = current_character.inventory.items.filter(func(item): return item is Weapon)
	for i in range(min(weapons.size(), 3)):  # Display up to 3 weapons
		var weapon = weapons[i]
		containers["Weapon"].get_node("Value" + str(i + 1)).text = weapon.name
		containers["Range"].get_node("Value" + str(i + 1)).text = str(weapon.weapon_range)
		containers["Shots"].get_node("Value" + str(i + 1)).text = str(weapon.shots)
		containers["Damage"].get_node("Value" + str(i + 1)).text = str(weapon.weapon_damage)
		containers["Traits"].get_node("Value" + str(i + 1)).text = ", ".join(weapon.traits)

func _on_species_selected(index: int):
	current_character.race = GlobalEnums.Race.values()[index]
	update_ui()

func _on_background_selected(index: int):
	background_index = index
	current_character.background = GlobalEnums.Background.values()[index]
	update_ui()

func _on_motivation_selected(index: int):
	motivation_index = index
	current_character.motivation = GlobalEnums.Motivation.values()[index]
	update_ui()

func _on_class_selected(index: int):
	class_index = index
	current_character.character_class = GlobalEnums.Class.values()[index]
	update_ui()

func _on_stat_changed(value: int, stat: String):
	current_character.stats[stat] = value
	update_ui()
	
func _on_background_left_pressed():
	background_index = (background_index - 1 + GlobalEnums.Background.size()) % GlobalEnums.Background.size()
	current_character.background = GlobalEnums.Background.values()[background_index]
	update_ui()

func _on_background_right_pressed():
	background_index = (background_index + 1) % GlobalEnums.Background.size()
	current_character.background = GlobalEnums.Background.values()[background_index]
	update_ui()

func _on_motivation_left_pressed():
	motivation_index = (motivation_index - 1 + GlobalEnums.Motivation.size()) % GlobalEnums.Motivation.size()
	current_character.motivation = GlobalEnums.Motivation.values()[motivation_index]
	update_ui()

func _on_motivation_right_pressed():
	motivation_index = (motivation_index + 1) % GlobalEnums.Motivation.size()
	current_character.motivation = GlobalEnums.Motivation.values()[motivation_index]
	update_ui()

func _on_class_left_pressed():
	class_index = (class_index - 1 + GlobalEnums.Class.size()) % GlobalEnums.Class.size()
	current_character.character_class = GlobalEnums.Class.values()[class_index]
	update_ui()

func _on_class_right_pressed():
	class_index = (class_index + 1) % GlobalEnums.Class.size()
	current_character.character_class = GlobalEnums.Class.values()[class_index]
	update_ui()


func _on_user_notes_changed():
	current_character.notes = user_notes.text

func _on_save_pressed():
	if current_character:
		var save_path = "user://characters/" + current_character.name + ".json"
		var dir = DirAccess.open("user://characters")
		if not dir:
			DirAccess.make_dir_recursive_absolute("user://characters")
		
		var file = FileAccess.open(save_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(current_character.serialize()))
			file.close()
			print("Character saved successfully!")
		else:
			print("Error: Could not save character.")

func _on_clear_pressed():
	_generate_random_character()

func _on_import_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_USERDATA
	file_dialog.filters = ["*.json ; JSON Files"]
	file_dialog.connect("file_selected", _load_character)
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

func _on_export_pressed():
	if current_character:
		var file_dialog = FileDialog.new()
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_USERDATA
		file_dialog.filters = ["*.json ; JSON Files"]
		file_dialog.connect("file_selected", _save_character)
		add_child(file_dialog)
		file_dialog.popup_centered(Vector2(800, 600))

func _load_character(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var character_data = json.get_data()
			current_character = Character.deserialize(character_data)
			update_ui()
			print("Character loaded successfully!")
		else:
			print("JSON Parse Error: ", json.get_error_message())
		file.close()
	else:
		print("Error: Could not open file.")

func _save_character(path: String):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_character.serialize()))
		file.close()
		print("Character exported successfully!")
	else:
		print("Error: Could not save character.")
