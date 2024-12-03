extends Control

signal flow_completed

enum FlowState {
	TUTORIAL_SELECTION,
	CREW_SIZE_SELECTION,
	CHARACTER_CREATION,
	CREW_MANAGEMENT,
	CAMPAIGN_SETUP,
	FINISHED
}

enum CampaignPhase {
	SETUP,
	TRAVEL,
	WORLD,
	BATTLE,
	POST_BATTLE,
	CAMPAIGN_END
}

@onready var tutorial_selection: Control = $TutorialSelection
@onready var crew_size_selection: Control = $CrewSizeSelection
@onready var character_creator: Control = $CharacterCreation
@onready var crew_management: Control = $CrewManagement
@onready var campaign_setup: Control = $CampaignSetup

var current_state: FlowState = FlowState.TUTORIAL_SELECTION
var game_state: CampaignPhase = CampaignPhase.SETUP
var game_manager: Node  # Will be cast to GameManager at runtime

func _connect_signals() -> void:
	var nodes_to_connect: Array[Dictionary] = [
		{
			"node": tutorial_selection,
			"signal": "tutorial_selected",
			"method": "_on_tutorial_selected"
		},
		{
			"node": crew_size_selection,
			"signal": "crew_size_selected",
			"method": "_on_crew_size_selected"
		},
		{
			"node": character_creator,
			"signal": "character_created",
			"method": "_on_character_created"
		},
		{
			"node": crew_management,
			"signal": "crew_management_completed",
			"method": "_on_crew_management_completed"
		},
		{
			"node": campaign_setup,
			"signal": "campaign_setup_completed",
			"method": "_on_campaign_setup_completed"
		}
	]
	
	for connection in nodes_to_connect:
		var node: Node = connection.node
		if node and node.has_signal(connection.signal):
			if not node.is_connected(connection.signal, Callable(self, connection.method)):
				node.connect(connection.signal, Callable(self, connection.method))
