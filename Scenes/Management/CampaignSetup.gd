# CampaignSetup.gd
extends Control

signal campaign_created

@onready var ship_selection: Control = $ShipSelection
@onready var equipment_selection: Control = $EquipmentSelection
@onready var flavor_details: Control = $FlavorDetails
@onready var victory_condition_selection: Control = $VictoryConditionSelection
@onready var start_campaign_button: Button = $StartCampaignButton

var game_state: GameStateManager

func _ready() -> void:
	game_state = GameStateManager.get_game_state()
	if not game_state:
		push_error("GameState not found. Make sure GameState is properly set up as an AutoLoad.")
		return

	_connect_signals()
	_update_start_button()

func _connect_signals() -> void:
	if ship_selection.has_signal("ship_selected"):
		ship_selection.ship_selected.connect(_on_ship_selected)
	if equipment_selection.has_signal("equipment_selected"):
		equipment_selection.equipment_selected.connect(_on_equipment_selected)
	if flavor_details.has_signal("details_set"):
		flavor_details.details_set.connect(_on_flavor_details_set)
	if victory_condition_selection.has_signal("condition_selected"):
		victory_condition_selection.condition_selected.connect(_on_victory_condition_selected)
	start_campaign_button.pressed.connect(_on_start_campaign_pressed)

func _on_ship_selected(ship: Ship) -> void:
	game_state.current_ship = ship
	_update_start_button()

func _on_equipment_selected(equipment: Array) -> void:
	game_state.ship_equipment = equipment
	_update_start_button()

func _on_flavor_details_set(details: Dictionary) -> void:
	game_state.flavor_details = details
	_update_start_button()

func _on_victory_condition_selected(condition: Dictionary) -> void:
	game_state.victory_condition = condition
	_update_start_button()

func _update_start_button() -> void:
	start_campaign_button.disabled = not _is_setup_complete()

func _is_setup_complete() -> bool:
	return game_state.get_current_crew().size() > 0 and \
		   game_state.current_ship != null and \
		   not game_state.ship_equipment.is_empty() and \
		   not game_state.flavor_details.is_empty() and \
		   game_state.victory_condition != null

func _on_start_campaign_pressed() -> void:
	if _validate_campaign_setup():
		campaign_created.emit()
		var new_campaign_flow = get_node("/root/NewCampaignFlow")
		if new_campaign_flow:
			new_campaign_flow.transition_to_state("FINISHED")
		else:
			push_error("NewCampaignFlow node not found")
		
		# Transition to the campaign turn state
		game_state.transition_to_state(GlobalEnums.CampaignPhase.UPKEEP)
		get_tree().change_scene_to_file("res://Scenes/Management/Scenes/BattlefieldGenerator.tscn")

func _validate_campaign_setup() -> bool:
	if not game_state:
		push_error("GameState not initialized")
		return false
	
	if game_state.get_current_crew().size() == 0:
		push_error("No crew members selected")
		return false
	
	if not game_state.current_ship:
		push_error("No ship selected")
		return false
	
	if game_state.ship_equipment.is_empty():
		push_error("No equipment selected")
		return false
	
	if game_state.flavor_details.is_empty():
		push_error("Flavor details not set")
		return false
	
	if not game_state.victory_condition:
		push_error("Victory condition not selected")
		return false
	
	return true

func start_setup() -> void:
	$CrewSizeContainer.show()
	$ShipSelection.hide()
	$EquipmentSelection.hide()
	$FlavorDetails.hide()
	$VictoryConditionSelection.hide()

# New method to progress to the next setup step
func progress_setup() -> void:
	var game_state: GameStateManager = get_node("/root/GameState")
	
	if $CrewSizeContainer.visible:
		$CrewSizeContainer.hide()
		$ShipSelection.show()
	elif $ShipSelection.visible:
		$ShipSelection.hide()
		$EquipmentSelection.show()
	elif $EquipmentSelection.visible:
		$EquipmentSelection.hide()
		$FlavorDetails.show()
	elif $FlavorDetails.visible:
		$FlavorDetails.hide()
		$VictoryConditionSelection.show()
	else:
		# All steps completed, enable start button
		$StartCampaignButton.disabled = false
		game_state.transition_to_state(GlobalEnums.CampaignPhase.UPKEEP)
