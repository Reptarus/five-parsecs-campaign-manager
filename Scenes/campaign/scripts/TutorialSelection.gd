extends Control

signal tutorial_selected(tutorial_type: String)

@onready var story_track_button: Button = $StoryTrackButton
@onready var compendium_button: Button = $CompendiumButton
@onready var skip_button: Button = $SkipButton

var tutorial_manager: TutorialManager
var game_manager: GameManager

func _ready() -> void:
	tutorial_manager = TutorialManager.new(game_manager)

	story_track_button.pressed.connect(_on_story_track_pressed)
	compendium_button.pressed.connect(_on_compendium_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

	_setup_tutorial_text()

func _setup_tutorial_text() -> void:
	$TutorialText.text = """
	Welcome to Five Parsecs From Home!
	
	You can choose to follow the Story Track tutorial, explore the Compendium,
	or skip the tutorial entirely.
	
	Story Track: Learn the basics of crew creation, ship management, and campaign play.
	Compendium: Explore detailed rules and lore of the game universe.
	Skip: Jump right into creating your crew and starting your adventure.
	"""

func _on_story_track_pressed() -> void:
	tutorial_manager.start_tutorial("story_track")
	tutorial_selected.emit("story_track")
	game_manager.game_state.transition_to_state(GameStateManager.State.CREW_CREATION)
	game_manager.game_state_changed.emit(GlobalEnums.CampaignPhase.CREW_CREATION)

func _on_compendium_pressed() -> void:
	tutorial_manager.start_tutorial("compendium")
	tutorial_selected.emit("compendium")
	# Load compendium scene or display compendium information

func _on_skip_pressed() -> void:
	tutorial_manager.end_tutorial()
	tutorial_selected.emit("skip")
	game_manager.game_state.transition_to_state(GameStateManager.State.CREW_CREATION)
	game_manager.game_state_changed.emit(GlobalEnums.CampaignPhase.CREW_CREATION)

func _on_tutorial_step_changed(step: String) -> void:
	match step:
		"crew_size_selection":
			$TutorialText.text = tutorial_manager.get_tutorial_text("crew_size_selection")
		"campaign_setup":
			$TutorialText.text = tutorial_manager.get_tutorial_text("campaign_setup")
		"character_creation":
			$TutorialText.text = tutorial_manager.get_tutorial_text("character_creation")
		"ship_creation":
			$TutorialText.text = tutorial_manager.get_tutorial_text("ship_creation")
		"connections_creation":
			$TutorialText.text = tutorial_manager.get_tutorial_text("connections_creation")
		"save_campaign":
			$TutorialText.text = tutorial_manager.get_tutorial_text("save_campaign")
