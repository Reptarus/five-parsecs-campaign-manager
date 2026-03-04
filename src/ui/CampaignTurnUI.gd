extends Control
class_name CampaignTurnUI

## Simple Five Parsecs Campaign Turn Manager
## Single screen with phase tabs - no complex orchestration or state machines
## Handles complete Five Parsecs campaign turn in unified interface

const Campaign = preload("res://src/core/Campaign.gd")
const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

# Five Parsecs campaign phases
enum Phase {
	UPKEEP,
	WORLD, 
	TRAVEL,
	BATTLE,
	POST_BATTLE
}

# UI node references
@onready var turn_label: Label = %TurnLabel
@onready var credits_label: Label = %CreditsLabel
@onready var phase_tabs: TabContainer = %PhaseTabs
@onready var next_phase_button: Button = %NextPhaseButton
@onready var save_campaign_button: Button = %SaveCampaignButton

# Core systems
var campaign: Campaign
var dice_system: FPCM_DiceSystem
var current_phase: Phase = Phase.UPKEEP

# Campaign turn signals
signal turn_completed()
signal phase_changed(new_phase: Phase)

func _ready() -> void:
	_initialize_campaign_turn()
	_connect_signals()
	_update_ui()

func _initialize_campaign_turn() -> void:
	campaign = Campaign.new()
	dice_system = FPCM_DiceSystem.new()
	
	# Connect campaign signals
	campaign.campaign_data_updated.connect(_on_campaign_data_updated)
	campaign.credits_changed.connect(_on_credits_changed)
	

func _connect_signals() -> void:
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	save_campaign_button.pressed.connect(_on_save_campaign_pressed)
	phase_tabs.tab_changed.connect(_on_phase_tab_changed)

func _update_ui() -> void:
	# Update turn and credits display
	turn_label.text = "Turn: " + str(campaign.campaign_data["turn"])
	credits_label.text = "Credits: " + str(campaign.campaign_data["credits"])
	
	# Update phase tabs
	phase_tabs.current_tab = current_phase
	
	# Update next phase button
	match current_phase:
		Phase.UPKEEP:
			next_phase_button.text = "Go to World Phase"
		Phase.WORLD:
			next_phase_button.text = "Go to Travel Phase"
		Phase.TRAVEL:
			next_phase_button.text = "Go to Battle Phase"
		Phase.BATTLE:
			next_phase_button.text = "Go to Post-Battle Phase"
		Phase.POST_BATTLE:
			next_phase_button.text = "Complete Turn"

## Execute Upkeep Phase
func execute_upkeep_phase() -> void:

	# Simple Five Parsecs upkeep mechanics
	var crew_upkeep = campaign.campaign_data["crew"].size() * 1  # 1 credit per crew member
	var ship_upkeep = 1  # Basic ship upkeep
	var total_upkeep = crew_upkeep + ship_upkeep

	# Deduct upkeep costs
	var new_credits = max(0, campaign.campaign_data["credits"] - total_upkeep)
	campaign.update_credits(new_credits, campaign.campaign_data["debt"])

	# Story point progression
	if campaign.campaign_data["turn"] % 5 == 0:
		campaign.campaign_data["story_points"] += 1


## Execute World Phase  
func execute_world_phase() -> void:
	
	# Simple world phase mechanics
	# - Check for patron jobs
	# - Handle market activities
	# - Process world events
	
	# Generate job opportunity using Five Parsecs dice system
	var job_roll = dice_system.roll_custom(2, 6, 0, "Job Payment")

## Execute Travel Phase
func execute_travel_phase() -> void:
	
	# Simple travel mechanics
	# - Hyperspace travel events
	# - Fuel costs
	# - Random encounters
	
	var travel_cost = 1  # Simple fuel cost
	var new_credits = max(0, campaign.campaign_data["credits"] - travel_cost)
	campaign.update_credits(new_credits, campaign.campaign_data["debt"])
	

## Execute Battle Phase
func execute_battle_phase() -> void:
	# Simple battle resolution
	# - Setup battlefield
	# - Deploy crew
	# - Resolve combat
	pass

## Execute Post-Battle Phase
func execute_post_battle_phase() -> void:
	
	# Simple post-battle mechanics
	# - Injury recovery
	# - Loot distribution
	# - Experience points
	
	# Generate battle reward using Five Parsecs dice system
	var reward_roll = dice_system.roll_dice(FPCM_DiceSystem.DicePattern.D6, "Battle Reward")
	var battle_reward = reward_roll.total * 2  # Double the roll for reward
	var new_credits = campaign.campaign_data["credits"] + battle_reward
	campaign.update_credits(new_credits, campaign.campaign_data["debt"])
	

## Signal handlers
func _on_next_phase_pressed() -> void:
	# Execute current phase
	match current_phase:
		Phase.UPKEEP:
			execute_upkeep_phase()
		Phase.WORLD:
			execute_world_phase()
		Phase.TRAVEL:
			execute_travel_phase()
		Phase.BATTLE:
			execute_battle_phase()
		Phase.POST_BATTLE:
			execute_post_battle_phase()
	
	# Advance to next phase or complete turn
	if current_phase == Phase.POST_BATTLE:
		# Complete turn and start new one
		campaign.advance_turn()
		current_phase = Phase.UPKEEP
		turn_completed.emit()
	else:
		# Advance to next phase - type-safe enum access
		current_phase = current_phase + 1
		campaign.set_phase(_get_phase_name(current_phase))
		phase_changed.emit(current_phase)
	
	_update_ui()

func _on_phase_tab_changed(tab: int) -> void:
	# Allow manual phase navigation - type-safe enum access
	current_phase = tab
	campaign.set_phase(_get_phase_name(current_phase))
	_update_ui()

func _on_save_campaign_pressed() -> void:
	# Simple save to JSON file
	var save_data = campaign.get_campaign_state()
	var save_file = FileAccess.open("user://campaign_save.json", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()

func _on_campaign_data_updated(data: Dictionary) -> void:
	_update_ui()

func _on_credits_changed(credits: int, debt: int) -> void:
	credits_label.text = "Credits: %d (Debt: %d)" % [credits, debt]

func _get_phase_name(phase: Phase) -> String:
	match phase:
		Phase.UPKEEP: return "upkeep"
		Phase.WORLD: return "world"
		Phase.TRAVEL: return "travel"
		Phase.BATTLE: return "battle"
		Phase.POST_BATTLE: return "post_battle"
		_: return "unknown"

## Load existing campaign
func load_campaign() -> void:
	var save_file = FileAccess.open("user://campaign_save.json", FileAccess.READ)
	if save_file:
		var json_string = save_file.get_as_text()
		save_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var save_data = json.data
			campaign.load_campaign_state(save_data)
			_update_ui()
	else:
		pass