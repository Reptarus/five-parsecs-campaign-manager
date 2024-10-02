extends Panel

signal customization_completed(index: int, new_data: Dictionary)

var current_index: int = -1
var game_manager: GameManager

@onready var name_input: LineEdit = $NameInput
@onready var background_option: OptionButton = $BackgroundOption
@onready var skills_container: VBoxContainer = $SkillsContainer
@onready var portrait_option: TextureRect = $PortraitOption
@onready var species_option: OptionButton = $SpeciesOption
@onready var motivation_option: OptionButton = $MotivationOption
@onready var class_option: OptionButton = $ClassOption

func _ready() -> void:
	game_manager = get_node("/root/GameStateManager").get_game_state()
	_populate_option_buttons()

func _populate_option_buttons() -> void:
	for background in GlobalEnums.Background.keys():
		background_option.add_item(background)
	for species in GlobalEnums.Species.keys():
		species_option.add_item(species)
	for motivation in GlobalEnums.Motivation.keys():
		motivation_option.add_item(motivation)
	for character_class in GlobalEnums.Class.keys():
		class_option.add_item(character_class)

func show_member(member: Character) -> void:
	current_index = member.get_index()
	name_input.text = member.name
	background_option.select(int(member.background))
	species_option.select(int(member.species))
	motivation_option.select(int(member.motivation))
	class_option.select(int(member.character_class))
	if member.portrait:
		portrait_option.texture = load(member.portrait)
	else:
		portrait_option.texture = null
	_update_skills_display(member)

func _update_skills_display(member: Character) -> void:
	for skill_button in skills_container.get_children():
		skill_button.button_pressed = member.skills.has(skill_button.text)

func _on_save_pressed() -> void:
	var new_data: Dictionary = {
		"name": name_input.text,
		"background": GlobalEnums.Background.keys()[background_option.selected],
		"species": GlobalEnums.Species.keys()[species_option.selected],
		"motivation": GlobalEnums.Motivation.keys()[motivation_option.selected],
		"character_class": GlobalEnums.Class.keys()[class_option.selected],
		"portrait": portrait_option.texture.resource_path if portrait_option.texture else "",
		"skills": get_selected_skills()
	}
	customization_completed.emit(current_index, new_data)
	hide()

func get_selected_skills() -> Array[String]:
	var selected: Array[String] = []
	for skill in skills_container.get_children():
		if skill is CheckBox and skill.button_pressed:
			selected.append(skill.text)
	return selected

func _on_cancel_pressed() -> void:
	hide()

func _on_portrait_option_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_file_dialog()

func _open_file_dialog() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png, *.jpg, *.jpeg ; Supported Images"]
	file_dialog.connect("file_selected", Callable(self, "_on_portrait_selected"))
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2(800, 600))

func _on_portrait_selected(path: String) -> void:
	var texture = load(path)
	if texture:
		portrait_option.texture = texture
	else:
		game_manager.ui_manager.show_message("Failed to load image.")
