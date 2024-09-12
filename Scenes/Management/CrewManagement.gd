# CrewManagement.gd
extends Control

signal crew_creation_completed(crew)

@onready var crew_list: ItemList = $VBoxContainer/HBoxContainer/CrewList
@onready var character_sheet: Panel = $VBoxContainer/HBoxContainer/CharacterSheet
@onready var edit_stats_button: Button = $VBoxContainer/HBoxContainer/CharacterSheet/EditStatsButton
@onready var edit_equipment_button: Button = $VBoxContainer/HBoxContainer/CharacterSheet/EditEquipmentButton
@onready var save_changes_button: Button = $VBoxContainer/HBoxContainer/CharacterSheet/SaveChangesButton
@onready var generate_random_button: Button = $VBoxContainer/ButtonsContainer/GenerateRandomButton
@onready var customize_button: Button = $VBoxContainer/ButtonsContainer/CustomizeButton
@onready var reroll_button: Button = $VBoxContainer/ButtonsContainer/RerollButton
@onready var confirm_crew_button: Button = $VBoxContainer/ButtonsContainer/ConfirmCrewButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var customize_panel: Control = $CustomizePanel

var game_state: GameState
var crew: Crew
var selected_crew_member: Character  # Changed from CrewMember to Character

func _ready() -> void:
	crew_list.connect("item_selected", _on_crew_member_selected)
	edit_stats_button.connect("pressed", _on_edit_stats_pressed)
	edit_equipment_button.connect("pressed", Callable(self, "_on_edit_equipment_pressed"))
	save_changes_button.connect("pressed", Callable(self, "_on_save_changes_pressed"))
	generate_random_button.connect("pressed", Callable(self, "_on_generate_random_pressed"))
	customize_button.connect("pressed", Callable(self, "_on_customize_pressed"))
	reroll_button.connect("pressed", Callable(self, "_on_reroll_pressed"))
	confirm_crew_button.connect("pressed", Callable(self, "_on_confirm_crew_pressed"))
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	customize_panel.connect("customization_completed", Callable(self, "_on_customization_completed"))
	self.connect("crew_creation_completed", Callable(self, "_on_crew_creation_completed"))

func set_game_state(state: GameState) -> void:
	game_state = state
	crew = game_state.current_crew
	update_crew_list()

func update_crew_list() -> void:
	crew_list.clear()
	for i in range(crew.members.size()):
		var member = crew.members[i]
		crew_list.add_item(member.name + " - " + str(member.background))

func _on_crew_member_selected(index: int) -> void:
	selected_crew_member = crew.members[index]
	update_character_sheet()

func update_character_sheet() -> void:
	assert(selected_crew_member != null, "No crew member selected")
	# TODO: Update character sheet display with selected crew member's data
	print("Updating character sheet for: ", selected_crew_member.name)

func _on_edit_stats_pressed() -> void:
	# TODO: Implement stat editing
	print("Stat editing not implemented yet")

func _on_edit_equipment_pressed() -> void:
	# TODO: Implement equipment editing
	print("Equipment editing not implemented yet")

func _on_save_changes_pressed() -> void:
	# TODO: Implement saving changes
	print("Saving changes not implemented yet")

func _on_generate_random_pressed() -> void:
	crew.generate_random_crew()
	update_crew_list()

func _on_customize_pressed() -> void:
	if selected_crew_member:
		customize_panel.show_member(selected_crew_member)

func _on_reroll_pressed() -> void:
	if selected_crew_member:
		var index = crew.members.find(selected_crew_member)
		crew.reroll_member(index)
		update_crew_list()

func _on_customization_completed(index: int, new_data: Dictionary) -> void:
	crew.customize_member(index, new_data)
	update_crew_list()

func _on_confirm_crew_pressed() -> void:
	if crew.is_valid():
		game_state.set_current_crew(crew)
		
		# Generate initial world
		var world_generator = WorldGenerator.new(game_state)
		var initial_world = world_generator.generate_world()
		game_state.set_current_location(initial_world)
		
		# Set initial game parameters
		game_state.credits = 10  # Starting credits
		game_state.story_points = randi() % 6 + 1  # 1D6 story points
		
		emit_signal("crew_creation_completed", crew)
		
		get_tree().root.get_node("Main").goto_scene("res://scenes/CampaignDashboard.tscn")