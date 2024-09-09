extends Control

@onready var crew_list: ItemList = $CrewList
@onready var character_sheet: Control = $CharacterSheet
@onready var edit_stats_button: Button = $CharacterSheet/EditStatsButton
@onready var edit_equipment_button: Button = $CharacterSheet/EditEquipmentButton
@onready var save_changes_button: Button = $CharacterSheet/SaveChangesButton
@onready var back_button: Button = $BackButton
@onready var customize_panel: Control = $CustomizePanel

var game_state: GameState
var crew: Crew
var selected_crew_member: Character = null


signal crew_creation_completed(crew: Crew)

func _ready():
	crew_list.connect("item_selected", Callable(self, "_on_crew_member_selected"))
	edit_stats_button.connect("pressed", Callable(self, "_on_edit_stats_pressed"))
	edit_equipment_button.connect("pressed", Callable(self, "_on_edit_equipment_pressed"))
	save_changes_button.connect("pressed", Callable(self, "_on_save_changes_pressed"))
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	customize_panel.connect("customization_completed", Callable(self, "_on_customization_completed"))
	self.connect("crew_creation_completed", Callable(self, "_on_crew_creation_completed"))

func initialize(_game_state: GameState):
	game_state = _game_state
	crew = game_state.current_crew
	update_crew_list()

func update_crew_list() -> void:
	crew_list.clear()
	for i in range(crew.members.size()):
		var member: Character = crew.members[i]
		crew_list.add_item(member.name + " - " + str(member.background))

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
		# Use the existing game_state variable
		game_state.set_current_crew(crew)
		
		# Generate initial world
		var world_generator = WorldGenerator.new(game_state)
		var initial_world = world_generator.generate_world()
		game_state.set_current_location(initial_world)
		
		# Set initial game parameters
		game_state.credits = 10  # Starting credits
		game_state.story_points = randi() % 6 + 1  # 1D6 story points
		
		# Emit signal to indicate crew creation is complete
		emit_signal("crew_creation_completed", crew)
		
		# Transition to the main game screen or campaign dashboard
		get_tree().change_scene_to_file("res://scenes/CampaignDashboard.tscn")
	else:
		_show_error_message("Error: Crew is not valid. Please ensure all members are properly created.")

func _show_error_message(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

# Add this function at the end of the file
func _on_crew_creation_completed(_crew: Crew) -> void:
	pass  # This function can be empty or used for additional logic if needed
