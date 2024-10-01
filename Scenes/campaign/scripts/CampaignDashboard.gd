class_name CampaignDashboard
extends Control

@export var campaign_manager: CampaignManager = null
@onready var phase_label: Label = $PhaseLabel
@onready var instruction_label: Label = $InstructionLabel
@onready var action_button: Button = $ActionButton
@onready var options_container: VBoxContainer = $OptionsContainer
@onready var crew_info_label: Label = $CrewInfoLabel
@onready var credits_label: Label = $CreditsLabel
@onready var story_points_label: Label = $StoryPointsLabel
@onready var tutorial_panel: Panel = $TutorialPanel
@onready var tutorial_event_description: Label = $TutorialPanel/EventDescription
@onready var game_state: GameState = get_node("/root/GameState")

func _ready() -> void:
	if game_state == null:
		push_error("Failed to get GameState. Check if it's properly set up as an autoload in project settings.")
		return
	
	action_button.pressed.connect(_on_action_button_pressed)
	campaign_manager.phase_changed.connect(_on_phase_changed)
	update_display()

func _process(_delta: float) -> void:
	if game_state.is_tutorial_active:
		update_tutorial_ui()

func _on_phase_changed(_new_phase: GlobalEnums.CampaignPhase) -> void:
	update_display()

func update_display() -> void:
	if game_state.is_tutorial_active:
		phase_label.text = "Tutorial"
	else:
		phase_label.text = GlobalEnums.CampaignPhase.keys()[game_state.current_phase].capitalize().replace("_", " ")
	
	crew_info_label.text = "Crew: %s (%d members)" % [game_state.current_crew.name, game_state.current_crew.get_member_count()]
	credits_label.text = "Credits: %d" % game_state.current_crew.credits
	story_points_label.text = "Story Points: %d" % game_state.story_points

	if game_state.is_tutorial_active:
		instruction_label.text = game_state.story_track.current_event.instruction
		action_button.text = game_state.story_track.current_event.action_text
	else:
		_update_phase_specific_ui()

func update_tutorial_ui() -> void:
	tutorial_panel.visible = true
	tutorial_event_description.text = game_state.story_track.current_event.description
	# Update other tutorial-specific UI elements as needed

func _update_phase_specific_ui() -> void:
	match game_state.current_phase:
		GlobalEnums.CampaignPhase.UPKEEP:
			instruction_label.text = "Perform upkeep tasks"
			action_button.text = "Start Upkeep"
		GlobalEnums.CampaignPhase.STORY_POINT:
			instruction_label.text = "Choose a story point action"
			action_button.text = "Use Story Point"
		GlobalEnums.CampaignPhase.TRAVEL:
			instruction_label.text = "Select a destination"
			action_button.text = "Travel"
		GlobalEnums.CampaignPhase.PATRONS:
			instruction_label.text = "Check for available patrons"
			action_button.text = "Find Patrons"
		GlobalEnums.CampaignPhase.MISSION:
			instruction_label.text = "Prepare for the mission"
			action_button.text = "Start Mission"
		GlobalEnums.CampaignPhase.BATTLE:
			instruction_label.text = "Engage in battle"
			action_button.text = "Enter Battle"
		GlobalEnums.CampaignPhase.POST_BATTLE:
			instruction_label.text = "Review battle results"
			action_button.text = "Continue"
		_:
			instruction_label.text = "Proceed to next phase"
			action_button.text = "Continue"

func _on_action_button_pressed() -> void:
	if game_state.is_tutorial_active:
		game_state.story_track.progress_story(game_state.current_phase)
	else:
		match game_state.current_phase:
			GlobalEnums.CampaignPhase.UPKEEP:
				game_state.start_campaign_turn()
			GlobalEnums.CampaignPhase.STORY_POINT:
				var story_track_manager = StoryTrackManager.new(game_state)
				story_track_manager.use_story_point()
			GlobalEnums.CampaignPhase.TRAVEL:
				var travel_phase = TravelPhase.new()
				travel_phase.initialize_game_components()
				travel_phase._on_travel_button_pressed()
			GlobalEnums.CampaignPhase.PATRONS:
				var patron_job_manager = PatronJobManager.new()
				patron_job_manager.game_state = game_state
				var patrons_result = patron_job_manager.determine_job_offers()
				for job in patrons_result:
					print(job)  # Replace with proper UI update
			GlobalEnums.CampaignPhase.MISSION:
				var mission_generator = MissionGenerator.new()
				mission_generator.initialize(game_state)
				var mission = mission_generator.generate_mission()
				if mission:
					game_state.current_mission = mission
					print("Mission started: ", mission.title)  # Replace with proper UI update
			GlobalEnums.CampaignPhase.BATTLE:
				var battle_scene: PackedScene = load("res://Scenes/Scene Container/Battle.tscn")
				var battle_instance: Node = battle_scene.instantiate()
				battle_instance.initialize(game_state, game_state.current_mission)
				get_tree().root.add_child(battle_instance)
				game_state.transition_to_state(GlobalEnums.CampaignPhase.BATTLE)
			GlobalEnums.CampaignPhase.POST_BATTLE:
				var post_battle_phase = PostBattlePhase.new(game_state)
				post_battle_phase.execute_post_battle_sequence(true)  # Assuming player victory, adjust as needed
			_:
				game_state.transition_to_next_phase()
	
	update_display()
