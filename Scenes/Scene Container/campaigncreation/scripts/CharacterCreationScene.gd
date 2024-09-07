extends Control

@onready var species_option_button: OptionButton = $CrewStatsAndInfo/SpeciesSelection/SpeciesSelection
@onready var character_portrait: TextureRect = $CrewPictureAndStats/PictureandBMCcontrols/CharacterPortrait
@onready var background_info: RichTextLabel = $CrewPictureAndStats/CharacterFlavorBreakdown/SpeciesInfoLabel
@onready var save_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Save
@onready var clear_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Clear
@onready var import_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Import
@onready var export_button: Button = $CrewPictureAndStats/PictureandBMCcontrols/HBoxContainer/Export
@onready var background_selection: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/BackgroundSelection/RightArrow
@onready var motivation_selection: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/MotivationSelection/RightArrow
@onready var class_selection: Button = $CrewPictureAndStats/PictureandBMCcontrols/PortraitControls/ClassSelection/RightArrow
@onready var user_notes: TextEdit = $CrewStatsAndInfo/UserNotes

var current_character: Character

func _ready():
	species_option_button.connect("item_selected", _on_species_selected)
	save_button.connect("pressed", _on_save_pressed)
	clear_button.connect("pressed", _on_clear_pressed)
	import_button.connect("pressed", _on_import_pressed)
	export_button.connect("pressed", _on_export_pressed)
	background_selection.connect("item_selected", _on_background_selected)
	motivation_selection.connect("item_selected", _on_motivation_selected)
	class_selection.connect("item_selected", _on_class_selected)
	user_notes.connect("text_changed", _on_user_notes_changed)
	
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spin_box = get_node("CrewStatsAndInfo/StatDistribution/" + stat + "/" + stat + "SpinBox")
		spin_box.connect("value_changed", _on_stat_changed.bind(stat))
	
	_generate_random_character()

func _generate_random_character():
	current_character = Character.new()
	current_character.race = GlobalEnums.Race.values()[randi() % GlobalEnums.Race.size()]
	current_character.background = GlobalEnums.Background.values()[randi() % GlobalEnums.Background.size()]
	current_character.motivation = GlobalEnums.Motivation.values()[randi() % GlobalEnums.Motivation.size()]
	current_character.character_class = GlobalEnums.Class.values()[randi() % GlobalEnums.Class.size()]
	
	for stat in current_character.stats.keys():
		current_character.stats[stat] = randi() % 6 + 1  # Random value between 1 and 6
	
	# Generate starting equipment based on background, motivation, and class
	var background_data = CharacterCreationData.get_background_stats(current_character.background)
	var motivation_data = CharacterCreationData.get_motivation_stats(current_character.motivation)
	var class_data = CharacterCreationData.get_class_stats(current_character.character_class)
	
	# Apply stat bonuses
	for stat in background_data.keys():
		if stat in current_character.stats:
			current_character.stats[stat] += background_data[stat]
	
	for stat in motivation_data.keys():
		if stat in current_character.stats:
			current_character.stats[stat] += motivation_data[stat]
	
	for stat in class_data.keys():
		if stat in current_character.stats:
			current_character.stats[stat] += class_data[stat]
	
	# Add starting equipment
	if "gear" in background_data:
		current_character.inventory.add_item(Equipment.new(background_data["gear"], Equipment.Type.GEAR, 1))
	if "military_weapon" in motivation_data:
		current_character.inventory.add_item(Equipment.new("Military Weapon", Equipment.Type.WEAPON, 1))
	if "low_tech_weapon" in motivation_data:
		current_character.inventory.add_item(Equipment.new("Low-tech Weapon", Equipment.Type.WEAPON, 1))
	if "gear" in class_data:
		current_character.inventory.add_item(Equipment.new(class_data["gear"], Equipment.Type.GEAR, 1))
	
	update_ui()

func update_ui():
	if not current_character:
		return
	
	character_portrait.texture = load(current_character.portrait)
	species_option_button.selected = current_character.race
	background_selection.selected = current_character.background
	motivation_selection.selected = current_character.motivation
	class_selection.selected = current_character.character_class
	
	update_character_info()
	update_stats()
	update_weapons_and_gear()
	user_notes.text = current_character.notes

func update_character_info():
	var info_text = "Species: %s\n\n" % GlobalEnums.Race.keys()[current_character.race]
	info_text += CharacterCreationData.get_race_traits(current_character.race) + "\n\n"
	info_text += "Background: %s\n" % GlobalEnums.Background.keys()[current_character.background]
	info_text += CharacterCreationData.get_background_info(GlobalEnums.Background.keys()[current_character.background]) + "\n\n"
	info_text += "Motivation: %s\n" % GlobalEnums.Motivation.keys()[current_character.motivation]
	info_text += CharacterCreationData.get_motivation_stats(current_character.motivation).get("description", "") + "\n\n"
	info_text += "Class: %s\n" % GlobalEnums.Class.keys()[current_character.character_class]
	info_text += CharacterCreationData.get_class_stats(current_character.character_class).get("description", "")
	
	background_info.text = info_text

func update_stats():
	for stat in ["Reactions", "Speed", "Combat", "Toughness", "Savvy", "Luck"]:
		var spin_box = get_node("CrewStatsAndInfo/StatDistribution/" + stat + "/" + stat + "SpinBox")
		spin_box.value = current_character.stats[stat.to_lower()]

func update_weapons_and_gear():
	var weapons_container = $CrewStatsAndInfo/StartingWeapons/Weapon
	var range_container = $CrewStatsAndInfo/StartingWeapons/Range
	var shots_container = $CrewStatsAndInfo/StartingWeapons/Shots
	var damage_container = $CrewStatsAndInfo/StartingWeapons/Damage
	var traits_container = $CrewStatsAndInfo/StartingWeapons/Traits
	
	for container in [weapons_container, range_container, shots_container, damage_container, traits_container]:
		for child in container.get_children():
			if child is Label and child.name != container.name:
				child.text = ""
	
	for i in range(current_character.inventory.items.size()):
		var item = current_character.inventory.items[i]
		if item is Weapon:
			weapons_container.get_node("WeaponValue" + str(i + 1)).text = item.name
			range_container.get_node("RangeValue" + str(i + 1)).text = str(item.range)
			shots_container.get_node("ShotsValue" + str(i + 1)).text = str(item.shots)
			damage_container.get_node("DamageValue" + str(i + 1)).text = str(item.damage)
			traits_container.get_node("TraitsValue" + str(i + 1)).text = ", ".join(item.traits)

func _on_species_selected(index):
	current_character.race = GlobalEnums.Race.values()[index]
	update_ui()

func _on_background_selected(index):
	current_character.background = GlobalEnums.Background.values()[index]
	update_ui()

func _on_motivation_selected(index):
	current_character.motivation = GlobalEnums.Motivation.values()[index]
	update_ui()

func _on_class_selected(index):
	current_character.character_class = GlobalEnums.Class.values()[index]
	update_ui()

func _on_stat_changed(value, stat):
	current_character.stats[stat.to_lower()] = value
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
