# CampaignSetup.gd
extends Control

signal campaign_created(campaign)

@onready var crew_creation = $CrewCreation
@onready var ship_creation = $ShipCreation
@onready var equipment_selection = $EquipmentSelection
@onready var flavor_details = $FlavorDetails
@onready var victory_condition_selection = $VictoryConditionSelection
@onready var start_campaign_button = $StartCampaignButton

var game_state: GameState
var world_generator: WorldGenerator

func _ready():
	game_state = get_node("/root/GameState") as GameState
	if game_state == null:
		push_error("Failed to get GameState node")
		return
	
	world_generator = WorldGenerator.new(game_state)
	crew_creation.connect("crew_created", Callable(self, "_on_crew_created"))
	ship_creation.connect("ship_selected", Callable(self, "_on_ship_selected"))
	equipment_selection.connect("equipment_selected", Callable(self, "_on_equipment_selected"))
	flavor_details.connect("flavor_details_set", Callable(self, "_on_flavor_details_set"))
	victory_condition_selection.connect("victory_condition_selected", Callable(self, "_on_victory_condition_selected"))
	start_campaign_button.connect("pressed", Callable(self, "_on_start_campaign_pressed"))
	start_campaign_button.disabled = true
	show_tutorial_selection_popup()

func _on_crew_created(crew: Crew):
	game_state.current_crew = crew
	_update_start_button()

func _on_ship_selected(ship: Ship):
	game_state.current_crew.ship = ship
	_update_start_button()

func _on_equipment_selected(equipment: Array):
	game_state.current_crew.equipment = equipment
	_update_start_button()

func _on_flavor_details_set(details: Dictionary):
	game_state.flavor_details = details
	_update_start_button()

func _on_victory_condition_selected(condition: Dictionary):
	game_state.victory_condition = condition
	_update_start_button()

func _update_start_button():
	start_campaign_button.disabled = not _is_setup_complete()

func _is_setup_complete() -> bool:
	return game_state.current_crew != null and \
		   game_state.current_crew.ship != null and \
		   not game_state.current_crew.equipment.is_empty() and \
		   not game_state.flavor_details.is_empty() and \
		   game_state.victory_condition != null

func _on_start_campaign_button_pressed():
	if _validate_campaign_setup():
		var campaign = _create_campaign()
		emit_signal("campaign_created", campaign)

func _validate_campaign_setup():
	# Implement validation logic
	return true

func _create_campaign():
	# Create and return a new campaign based on the setup
	return GameState

func show_tutorial_selection_popup():
	var tutorial_popup = ConfirmationDialog.new()
	tutorial_popup.dialog_text = "Choose a tutorial option:"
	tutorial_popup.get_ok_button().text = "Story Track Tutorial"
	tutorial_popup.add_button("Compendium Tutorial", true, "compendium_tutorial")
	tutorial_popup.add_cancel_button("Skip Tutorial")
	tutorial_popup.connect("confirmed", Callable(self, "_start_story_track_tutorial"))
	tutorial_popup.connect("custom_action", Callable(self, "_start_compendium_tutorial"))
	tutorial_popup.connect("cancelled", Callable(self, "_skip_tutorial"))
	add_child(tutorial_popup)
	tutorial_popup.popup_centered()

func _start_story_track_tutorial():
	print("Starting Story Track tutorial...")
	# Implement Story Track tutorial logic here
	game_state.start_story_track_tutorial()

func _start_compendium_tutorial():
	print("Starting Compendium tutorial...")
	# Implement Compendium tutorial logic here
	game_state.start_compendium_tutorial()

func _skip_tutorial():
	print("Skipping tutorial...")
	crew_creation.start_creation()
