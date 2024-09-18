class_name CampaignDashboard
extends Control

@export var game_state: GameState
@export var campaign_manager: CampaignManager
@onready var phase_label: Label = $PhaseLabel
@onready var instruction_label: Label = $InstructionLabel
@onready var action_button: Button = $ActionButton
@onready var options_container: VBoxContainer = $OptionsContainer
@onready var crew_info_label: Label = $CrewInfoLabel
@onready var credits_label: Label = $CreditsLabel
@onready var story_points_label: Label = $StoryPointsLabel
@onready var tutorial_panel: Panel = $TutorialPanel
@onready var tutorial_event_description: Label = $TutorialPanel/EventDescription

func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	campaign_manager.phase_changed.connect(_on_phase_changed)
	update_display()

func _process(_delta: float) -> void:
	if game_state.is_tutorial_active:
		update_tutorial_ui()

func _on_phase_changed(_new_phase: CampaignManager.TurnPhase) -> void:
	update_display()

func update_display() -> void:
	if game_state.is_tutorial_active:
		phase_label.text = "Tutorial"
	else:
		phase_label.text = CampaignManager.TurnPhase.keys()[campaign_manager.current_phase].capitalize().replace("_", " ")
	
	crew_info_label.text = "Crew: " + game_state.current_crew.name + " (" + str(game_state.current_crew.get_member_count()) + " members)"
	credits_label.text = "Credits: " + str(game_state.current_crew.credits)
	story_points_label.text = "Story Points: " + str(game_state.story_points)

	if game_state.is_tutorial_active:
		instruction_label.text = campaign_manager.story_track.current_event.instruction
		action_button.text = campaign_manager.story_track.current_event.action_text
	else:
		_update_phase_specific_ui()

func update_tutorial_ui() -> void:
	tutorial_panel.visible = true
	tutorial_event_description.text = campaign_manager.story_track.current_event.description
	# Update other tutorial-specific UI elements as needed

func _update_phase_specific_ui() -> void:
	# Existing phase-specific UI update logic
	pass

func _on_action_button_pressed() -> void:
	if game_state.is_tutorial_active:
		campaign_manager.story_track.progress_story(game_state, true)  # Assuming tutorial always succeeds
	else:
		# Existing action button logic for normal gameplay
		pass

# ... (other existing methods remain unchanged)
