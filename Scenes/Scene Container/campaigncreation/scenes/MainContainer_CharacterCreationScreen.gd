extends MarginContainer

func _ready():
	setup_ui()

func setup_ui():
	var main_content = HBoxContainer.new()
	main_content.name = "MainContent"
	add_child(main_content)

	var left_column = VBoxContainer.new()
	left_column.name = "LeftColumn"
	main_content.add_child(left_column)

	var right_column = VBoxContainer.new()
	right_column.name = "RightColumn"
	main_content.add_child(right_column)

	setup_left_column(left_column)
	setup_right_column(right_column)

func setup_left_column(left_column):
	var portrait = TextureRect.new()
	portrait.name = "CharacterPortrait"
	left_column.add_child(portrait)

	var portrait_controls = VBoxContainer.new()
	portrait_controls.name = "PortraitControls"
	left_column.add_child(portrait_controls)

	var buttons = ["Face", "Clothes", "Accessories"]
	for button_name in buttons:
		var button = Button.new()
		button.text = button_name
		portrait_controls.add_child(button)

	var name_input = LineEdit.new()
	name_input.name = "CharacterNameInput"
	name_input.placeholder_text = "Enter character name"
	left_column.add_child(name_input)

	var random_button = Button.new()
	random_button.name = "RandomButton"
	random_button.text = "Randomize"
	left_column.add_child(random_button)

func setup_right_column(right_column):
	var type_label = Label.new()
	type_label.name = "CharacterTypeLabel"
	type_label.text = "Captain/Crewmate"
	right_column.add_child(type_label)

	var species_selection = HBoxContainer.new()
	species_selection.name = "SpeciesSelection"
	right_column.add_child(species_selection)

	var species_option = OptionButton.new()
	species_option.name = "SpeciesOption"
	species_selection.add_child(species_option)

	var random_species_button = Button.new()
	random_species_button.name = "RandomSpeciesButton"
	random_species_button.text = "Random"
	species_selection.add_child(random_species_button)

	setup_stat_distribution(right_column)

	var species_info = RichTextLabel.new()
	species_info.name = "SpeciesInfoLabel"
	right_column.add_child(species_info)

	var weapons_label = Label.new()
	weapons_label.name = "StartingWeaponsLabel"
	weapons_label.text = "Starting Weapons and Gear"
	right_column.add_child(weapons_label)

	var weapons_list = ItemList.new()
	weapons_list.name = "WeaponsList"
	right_column.add_child(weapons_list)

	var user_notes = TextEdit.new()
	user_notes.name = "UserNotes"
	user_notes.placeholder_text = "User notes"
	right_column.add_child(user_notes)

func setup_stat_distribution(parent):
	var stat_distribution = GridContainer.new()
	stat_distribution.name = "StatDistribution"
	stat_distribution.columns = 2
	parent.add_child(stat_distribution)

	var stats = ["Reactions", "Speed", "CombatSkill", "Toughness", "Savvy", "Luck"]
	for stat in stats:
		var label = Label.new()
		label.text = stat
		stat_distribution.add_child(label)

		var spin_box = SpinBox.new()
		spin_box.name = stat + "SpinBox"
		spin_box.min_value = 0
		spin_box.max_value = 10
		stat_distribution.add_child(spin_box)
