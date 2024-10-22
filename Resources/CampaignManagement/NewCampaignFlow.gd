extends Control

signal flow_completed

@onready var tutorial_selection = $TutorialSelection if has_node("TutorialSelection") else null
@onready var crew_size_selection = $CrewSizeSelection
@onready var character_creator = $CharacterCreation
@onready var crew_management = $CrewManagement
@onready var campaign_setup = $CampaignSetup

var game_state: GlobalEnums.CampaignPhase
var game_manager: GameManager

enum FlowState {
	TUTORIAL_SELECTION,
	CREW_SIZE_SELECTION,
	CHARACTER_CREATION,
	CREW_MANAGEMENT,
	CAMPAIGN_SETUP,
	FINISHED
}

var current_state: FlowState = FlowState.TUTORIAL_SELECTION

func _ready() -> void:
	var _game_state: GlobalEnums.CampaignPhase = GameStateManager.get_game_state()
	game_manager = GameManager.new()
	init()
	flow_completed.connect(_on_flow_completed)

func init() -> void:
	_connect_signals()
	_update_visible_content()

func _connect_signals() -> void:
	var nodes_to_connect = [
		[tutorial_selection, "tutorial_selected", "_on_tutorial_selected"],
		[crew_size_selection, "size_selected", "_on_crew_size_selected"],
		[character_creator, "character_created", "_on_character_created"],
		[crew_management, "crew_finalized", "_on_crew_finalized"],
		[campaign_setup, "campaign_created", "_on_campaign_created"]
	]
	
	for node_info in nodes_to_connect:
		var node = node_info[0]
		var signal_name = node_info[1]
		var method_name = node_info[2]
		if node and node.has_signal(signal_name):
			if not node.is_connected(signal_name, Callable(self, method_name)):
				node.connect(signal_name, Callable(self, method_name))
		else:
			push_error("Warning: %s node not found or signal %s not available" % [node.get_name() if node else "Unknown", signal_name])

func _exit_tree() -> void:
	_disconnect_signals()

func _disconnect_signals() -> void:
	var nodes_to_disconnect = [tutorial_selection, crew_size_selection, character_creator, crew_management, campaign_setup]
	for node in nodes_to_disconnect:
		if node:
			if node.has_signal("tutorial_selected"):
				node.disconnect("tutorial_selected", Callable(self, "_on_tutorial_selected"))
			if node.has_signal("size_selected"):
				node.disconnect("size_selected", Callable(self, "_on_crew_size_selected"))
			if node.has_signal("character_created"):
				node.disconnect("character_created", Callable(self, "_on_character_created"))
			if node.has_signal("crew_finalized"):
				node.disconnect("crew_finalized", Callable(self, "_on_crew_finalized"))
			if node.has_signal("campaign_created"):
				node.disconnect("campaign_created", Callable(self, "_on_campaign_created"))

func _update_visible_content() -> void:
	if tutorial_selection:
		tutorial_selection.visible = (current_state == FlowState.TUTORIAL_SELECTION)
	crew_size_selection.visible = (current_state == FlowState.CREW_SIZE_SELECTION)
	character_creator.visible = (current_state == FlowState.CHARACTER_CREATION)
	crew_management.visible = (current_state == FlowState.CREW_MANAGEMENT)
	campaign_setup.visible = (current_state == FlowState.CAMPAIGN_SETUP)

func transition_to_state(new_state: FlowState) -> void:
	current_state = new_state
	_update_visible_content()

func _on_tutorial_selected(tutorial_type: String) -> void:
	print("Tutorial selected: ", tutorial_type)
	transition_to_state(FlowState.CREW_SIZE_SELECTION)

func _on_crew_size_selected(crew_size: int) -> void:
	print("Crew size selected: ", crew_size)
	GameStateManager.set_crew_size(crew_size)  # Assuming GameStateManager is a global singleton
	transition_to_state(FlowState.CHARACTER_CREATION)

func _on_character_created(character: Character) -> void:
	print("Character created: ", character.name)
	GameStateManager.current_crew.add_member(character)
	if GameStateManager.current_crew.is_full():
		transition_to_state(FlowState.CREW_MANAGEMENT)
	else:
		character_creator.reset()

func _on_crew_finalized() -> void:
	print("Crew finalized")
	transition_to_state(FlowState.CAMPAIGN_SETUP)

func _on_campaign_created() -> void:
	print("Campaign created")
	game_manager.start_new_game()
	transition_to_state(FlowState.FINISHED)
	emit_signal("flow_completed")

func complete_flow() -> void:
	emit_signal("flow_completed")

func _on_flow_completed() -> void:
	print("Flow completed")
	get_tree().change_scene_to_file("res://Scenes/Management/GameOverScreen.tscn")
