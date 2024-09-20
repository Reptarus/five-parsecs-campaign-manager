extends Control

signal flow_completed

@onready var tutorial_selection = TutorialManager if TutorialManager else null
@onready var crew_size_selection = $CrewSizeSelection
@onready var character_creator = $CharacterCreation
@onready var crew_management = $CrewManagement
@onready var campaign_setup = $CampaignSetup

enum FlowState {
	TUTORIAL_SELECTION,
	CREW_SIZE_SELECTION,
	CHARACTER_CREATION,
	CREW_MANAGEMENT,
	CAMPAIGN_SETUP,
	FINISHED
}

var current_state: FlowState = FlowState.TUTORIAL_SELECTION

func _ready():
	init()
	# Example usage
	flow_completed.connect(_on_flow_completed)

func init():
	_connect_signals()
	_update_visible_content()

func _connect_signals():
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
			push_error("Warning: %s node not found or signal %s not available" % [node_info[0].get_name(), signal_name])

func _exit_tree():
	_disconnect_signals()

func _disconnect_signals():
	var nodes_to_disconnect = [tutorial_selection, crew_size_selection, character_creator, crew_management, campaign_setup]
	for node in nodes_to_disconnect:
		if node:
			node.disconnect("tutorial_selected", Callable(self, "_on_tutorial_selected"))
			node.disconnect("size_selected", Callable(self, "_on_crew_size_selected"))
			node.disconnect("character_created", Callable(self, "_on_character_created"))
			node.disconnect("crew_finalized", Callable(self, "_on_crew_finalized"))
			node.disconnect("campaign_created", Callable(self, "_on_campaign_created"))

func _update_visible_content():
	tutorial_selection.visible = (current_state == FlowState.TUTORIAL_SELECTION)
	crew_size_selection.visible = (current_state == FlowState.CREW_SIZE_SELECTION)
	character_creator.visible = (current_state == FlowState.CHARACTER_CREATION)
	crew_management.visible = (current_state == FlowState.CREW_MANAGEMENT)
	campaign_setup.visible = (current_state == FlowState.CAMPAIGN_SETUP)

func transition_to_state(new_state: FlowState):
	current_state = new_state
	_update_visible_content()

func _on_tutorial_selected(tutorial_type: String):
	print("Tutorial selected: ", tutorial_type)
	transition_to_state(FlowState.CREW_SIZE_SELECTION)

func _on_crew_size_selected(size: int):
	print("Crew size selected: ", size)
	transition_to_state(FlowState.CHARACTER_CREATION)

func _on_character_created(character):
	print("Character created: ", character)
	if crew_management.crew_size_reached():
		transition_to_state(FlowState.CREW_MANAGEMENT)
	else:
		character_creator.reset()

func _on_crew_finalized():
	print("Crew finalized")
	transition_to_state(FlowState.CAMPAIGN_SETUP)

func _on_campaign_created():
	print("Campaign created")
	transition_to_state(FlowState.FINISHED)
	emit_signal("flow_completed")

func complete_flow():
	emit_signal("flow_completed")

func _on_flow_completed():
	print("Flow completed")
