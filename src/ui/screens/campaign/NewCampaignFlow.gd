extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const CampaignSetupDialog = preload("res://src/ui/screens/campaign/CampaignSetupDialog.tscn")

signal campaign_created(campaign: Resource)
signal campaign_setup_completed
signal character_created(character: Resource)
signal starting_location_selected(location: Resource)
signal starting_equipment_selected(equipment: Array[Resource])
signal tutorial_step_completed(step: String)
signal tutorial_completed

var game_state: FiveParsecsGameState
var campaign_config: Dictionary = {}
var starting_characters: Array[Resource] = []
var starting_location: Resource
var starting_equipment: Array[Resource] = []
var current_tutorial_step: String = ""

func _init(_game_state: FiveParsecsGameState) -> void:
	game_state = _game_state

func start_campaign_setup() -> void:
	var setup_dialog = CampaignSetupDialog.instantiate()
	setup_dialog.setup_completed.connect(_on_setup_completed)
	setup_dialog.setup_cancelled.connect(_on_setup_cancelled)
	
	# Add to scene tree
	var root = Engine.get_main_loop().get_root()
	root.add_child(setup_dialog)

func _on_setup_completed(config: Dictionary) -> void:
	campaign_config = config
	
	# Initialize campaign state
	game_state.initialize_campaign(config)
	campaign_created.emit(self)
	
	if config.get("enable_tutorial", true):
		start_tutorial()
	else:
		complete_setup()

func _on_setup_cancelled() -> void:
	# Return to main menu or previous screen
	get_tree().change_scene_to_file("res://src/data/resources/UI/Screens/MainMenu.tscn")

func start_tutorial() -> void:
	current_tutorial_step = "welcome"
	_process_tutorial_step()

func advance_tutorial() -> void:
	match current_tutorial_step:
		"welcome":
			current_tutorial_step = "crew_creation"
		"crew_creation":
			current_tutorial_step = "campaign_setup"
		"campaign_setup":
			current_tutorial_step = "basic_combat"
		"basic_combat":
			current_tutorial_step = "campaign_turn"
		"campaign_turn":
			complete_tutorial()
			return
	
	_process_tutorial_step()

func _process_tutorial_step() -> void:
	match current_tutorial_step:
		"welcome":
			_show_welcome_tutorial()
		"crew_creation":
			_show_crew_creation_tutorial()
		"campaign_setup":
			_show_campaign_setup_tutorial()
		"basic_combat":
			_show_basic_combat_tutorial()
		"campaign_turn":
			_show_campaign_turn_tutorial()

func _show_welcome_tutorial() -> void:
	var tutorial_text = """Welcome to Five Parsecs Campaign Manager!

This tutorial will guide you through:
1. Creating your crew
2. Setting up your campaign
3. Basic combat mechanics
4. Campaign turn structure

Press Next to continue."""
	
	tutorial_step_completed.emit("welcome")

func _show_crew_creation_tutorial() -> void:
	var tutorial_text = """Crew Creation

Your crew is the heart of your campaign:
- Choose crew size (4-6 members)
- Select backgrounds and skills
- Equip starting gear
- Set crew name and details

Let's create your first crew member."""
	
	tutorial_step_completed.emit("crew_creation")

func _show_campaign_setup_tutorial() -> void:
	var tutorial_text = """Campaign Setup

Important campaign settings:
- Difficulty level affects rewards and challenges
- Victory conditions determine campaign goals
- Story tracks add narrative elements
- Starting resources impact early game

Configure these settings carefully."""
	
	tutorial_step_completed.emit("campaign_setup")

func _show_basic_combat_tutorial() -> void:
	var tutorial_text = """Basic Combat

Combat follows these steps:
1. Setup battlefield
2. Deploy forces
3. Initiative and activation
4. Combat resolution
5. Post-battle sequence

We'll do a practice battle next."""
	
	tutorial_step_completed.emit("basic_combat")

func _show_campaign_turn_tutorial() -> void:
	var tutorial_text = """Campaign Turn Structure

Each turn consists of:
1. Travel Phase
2. World Phase
3. Battle Phase
4. Post-Battle Phase

Let's start your first turn!"""
	
	tutorial_step_completed.emit("campaign_turn")

func complete_tutorial() -> void:
	tutorial_completed.emit()
	complete_setup()

func complete_setup() -> void:
	# Validate all required components
	if not _validate_setup():
		push_error("Campaign setup validation failed")
		return
	
	# Apply final configuration
	_apply_campaign_config()
	
	campaign_setup_completed.emit()

func _validate_setup() -> bool:
	# Check required components
	if starting_characters.is_empty():
		return false
	
	if not starting_location:
		return false
	
	if starting_equipment.is_empty():
		return false
	
	# Validate configuration
	if campaign_config.crew_name.strip_edges().is_empty():
		return false
	
	return true

func _apply_campaign_config() -> void:
	# Apply crew setup
	game_state.crew = starting_characters
	game_state.crew_name = campaign_config.crew_name
	
	# Apply starting location
	game_state.current_location = starting_location
	
	# Apply starting equipment
	game_state.inventory.add_items(starting_equipment)
	
	# Apply campaign settings
	game_state.difficulty_mode = campaign_config.difficulty_mode
	game_state.campaign_victory_condition = campaign_config.victory_condition
	game_state.use_story_track = campaign_config.use_story_track
	game_state.enable_permadeath = campaign_config.enable_permadeath
	
	# Initialize resources
	game_state.credits = campaign_config.starting_credits
	game_state.supplies = campaign_config.starting_supplies
	
	# Set initial campaign state
	game_state.campaign_turn = 0
	game_state.current_phase = GameEnums.CampaignPhase.SETUP
