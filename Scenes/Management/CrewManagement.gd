class_name CrewManagement
extends Control

signal crew_creation_completed(crew: Crew)

const MAX_CREW_SIZE: int = 8
const MIN_CREW_SIZE: int = 3

@onready var crew_list: ItemList = $MarginContainer/HBoxContainer/CrewList
@onready var customize_panel: CustomizePanel = $CustomizePanel
@onready var character_sheet: Control = $MarginContainer/HBoxContainer/CharacterSheet
@onready var edit_stats_button: Button = $MarginContainer/HBoxContainer/CharacterSheet/EditStatsButton
@onready var edit_equipment_button: Button = $MarginContainer/HBoxContainer/CharacterSheet/EditEquipmentButton
@onready var save_changes_button: Button = $MarginContainer/HBoxContainer/CharacterSheet/SaveChangesButton
@onready var back_button: Button = $BackButton

var selected_crew_member: Character = null
var crew: Crew

func _ready() -> void:
	crew_list.item_selected.connect(Callable(self, "_on_crew_member_selected"))
	edit_stats_button.pressed.connect(Callable(self, "_on_edit_stats_pressed"))
	edit_equipment_button.pressed.connect(Callable(self, "_on_edit_equipment_pressed"))
	save_changes_button.pressed.connect(Callable(self, "_on_save_changes_pressed"))
	back_button.pressed.connect(Callable(self, "_on_back_pressed"))
	customize_panel.customization_completed.connect(Callable(self, "_on_customization_completed"))

	# Initialize crew with a default size
	initialize(MIN_CREW_SIZE)

func initialize(crew_size: int) -> void:
	crew = Crew.new(&"New Crew", null, crew_size)  # Use StringName for crew name
	crew.generate_random_crew()
	update_crew_list()

func update_crew_list() -> void:
	crew_list.clear()
	for i in range(crew.members.size()):
		var member: Character = crew.members[i]
		crew_list.add_item(member.name + " - " + str(member.background))  # Convert background to string

func _on_crew_member_selected(index: int) -> void:
	selected_crew_member = crew.get_member(index)
	update_character_sheet()

func _on_edit_stats_pressed() -> void:
	# TODO: Implement stat editing
	print("Stat editing not implemented yet")

func _on_edit_equipment_pressed() -> void:
	# TODO: Implement equipment editing
	print("Equipment editing not implemented yet")

func _on_save_changes_pressed() -> void:
	# TODO: Implement saving changes
	print("Saving changes not implemented yet")

func _on_back_pressed() -> void:
	# TODO: Implement proper scene management
	get_tree().change_scene_to_file("res://scenes/campaign/CampaignDashboard.tscn")

func update_character_sheet() -> void:
	assert(selected_crew_member != null, "No crew member selected")
	# TODO: Update character sheet display with selected crew member's data
	print("Updating character sheet for: ", selected_crew_member.name)

func _on_generate_random_pressed() -> void:
	crew.generate_random_crew()
	update_crew_list()

func _on_customize_pressed(index: int) -> void:
	var member: Character = crew.get_member(index)
	if member:
		customize_panel.show_member(member)

func _on_reroll_pressed(index: int) -> void:
	crew.reroll_member(index)
	update_crew_list()

func _on_customization_completed(index: int, new_data: Dictionary) -> void:
	crew.customize_member(index, new_data)
	update_crew_list()

func _on_confirm_crew_pressed() -> void:
	if crew.is_valid():
		crew_creation_completed.emit(crew)
		# TODO: Implement proper game state management
		# GameState.change_state(GameState.State.CAMPAIGN_TURN)
	else:
		_show_error_message("Error: Crew is not valid. Please ensure all members are properly created.")

func _show_error_message(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
