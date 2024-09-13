extends Panel

signal customization_completed(index: int, new_data: Dictionary)

var current_index: int = -1

@onready var name_input: LineEdit = $NameInput
@onready var background_option: OptionButton = $BackgroundOption
@onready var skills_container: VBoxContainer = $SkillsContainer
@onready var portrait_option: TextureRect = $PortraitOption

func show_member(member: Character) -> void:
	current_index = member.get_index()
	name_input.text = member.name
	background_option.select(int(member.background))
	if member.portrait:
		portrait_option.texture = load(member.portrait)
	else:
		portrait_option.texture = null

func _on_save_pressed() -> void:
	var new_data: Dictionary = {
		"name": name_input.text,
		"background": background_option.get_item_text(background_option.selected),
		"portrait": portrait_option.texture.resource_path
	}
	customization_completed.emit(current_index, new_data)
	hide()

func get_selected_skills() -> Array[String]:
	var selected: Array[String] = []
	for skill in skills_container.get_children():
		if skill.button_pressed:
			selected.append(skill.text)
	return selected

func _on_cancel_pressed() -> void:
	hide()
