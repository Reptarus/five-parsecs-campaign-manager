# CampaignSetup.gd
extends Control

signal campaign_created(game_state)

@onready var crew_creation = $CrewCreation
@onready var ship_creation = $ShipCreation
@onready var equipment_selection = $EquipmentSelection
@onready var flavor_details = $FlavorDetails
@onready var victory_condition_selection = $VictoryConditionSelection
@onready var start_campaign_button = $StartCampaignButton

var game_state: GameState
var world_generator: WorldGenerator

func _ready():
	world_generator = WorldGenerator.new(game_state)
	crew_creation.connect("crew_created", Callable(self, "_on_crew_created"))
	ship_creation.connect("ship_selected", Callable(self, "_on_ship_selected"))
	equipment_selection.connect("equipment_selected", Callable(self, "_on_equipment_selected"))
	flavor_details.connect("flavor_details_set", Callable(self, "_on_flavor_details_set"))
	victory_condition_selection.connect("victory_condition_selected", Callable(self, "_on_victory_condition_selected"))
	start_campaign_button.connect("pressed", Callable(self, "_on_start_campaign_pressed"))
	start_campaign_button.disabled = true

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

func _on_start_campaign_pressed():
	var initial_world = world_generator.generate_world()
	game_state.current_location = Location.new(initial_world["name"], Location.Type.PLANET)
	game_state.current_location.traits = initial_world["traits"]
	game_state.current_location.licensing_requirement = initial_world["licensing_requirement"]
	
	game_state.campaign_turn = 1
	game_state.story_points = randi() % 6 + 1  # 1D6+1 story points
	
	# Apply any difficulty modifiers
	match game_state.difficulty_mode:
		DifficultySettings.DifficultyLevel.HARDCORE:
			game_state.story_points = max(0, game_state.story_points - 1)
		DifficultySettings.DifficultyLevel.INSANITY:
			game_state.story_points = 0
	
	emit_signal("campaign_created", game_state)
