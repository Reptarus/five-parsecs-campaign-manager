class_name BugHuntCreationCoordinator
extends Node

## Orchestrates Bug Hunt campaign creation - 4-step wizard.
## Follows the same coordinator pattern as CampaignCreationCoordinator
## but simplified for Bug Hunt's needs.

const BugHuntStateManager := preload("res://src/core/campaign/creation/BugHuntCreationStateManager.gd")
const BugHuntCharGen := preload("res://src/core/character/BugHuntCharacterGeneration.gd")

signal navigation_updated(can_back: bool, can_forward: bool, can_finish: bool)
signal step_changed(step: int, total_steps: int)

var state_manager: BugHuntStateManager
var char_gen: BugHuntCharGen
var current_step: int = 0
var total_steps: int = 4


func _ready() -> void:
	state_manager = BugHuntStateManager.new()
	char_gen = BugHuntCharGen.new()


func go_to_step(step: int) -> void:
	if step < 0 or step >= total_steps:
		return
	current_step = step
	# Equipment panel is read-only (Bug Hunt uses standard issue) — auto-complete
	if current_step == 2:
		state_manager.mark_step_complete(BugHuntStateManager.Step.EQUIPMENT)
	step_changed.emit(current_step, total_steps)
	_update_navigation()


func next_step() -> void:
	if current_step < total_steps - 1:
		go_to_step(current_step + 1)


func previous_step() -> void:
	if current_step > 0:
		go_to_step(current_step - 1)


func _update_navigation() -> void:
	var can_back := current_step > 0
	var can_forward := current_step < total_steps - 1 and state_manager.can_advance_from(current_step)
	var can_finish := state_manager.can_finish() and current_step == total_steps - 1
	navigation_updated.emit(can_back, can_forward, can_finish)


## ============================================================================
## STATE UPDATE METHODS (called by panels)
## ============================================================================

func update_config(data: Dictionary) -> void:
	state_manager.update_config(data)
	_update_navigation()


func update_squad(data: Dictionary) -> void:
	state_manager.update_squad(data)
	_update_navigation()


func update_equipment(data: Dictionary) -> void:
	state_manager.update_equipment(data)
	_update_navigation()


## ============================================================================
## CHARACTER GENERATION
## ============================================================================

func generate_squad(names: Array = []) -> Dictionary:
	return char_gen.generate_squad(names)


func generate_regiment_name() -> Dictionary:
	return char_gen.generate_regiment_name()


## ============================================================================
## FINALIZATION
## ============================================================================

func finalize() -> void:
	if not state_manager.can_finish():
		push_warning("BugHuntCreationCoordinator: Cannot finalize - incomplete steps")
		return

	var all_data := state_manager.get_all_data()
	var campaign := BugHuntCampaignCore.create_new_campaign(
		all_data.config.campaign_name,
		all_data.config.difficulty
	)

	# Apply config
	campaign.set_config(all_data.config)

	# Initialize squad
	var squad: Dictionary = all_data.squad
	campaign.initialize_squad(squad.main_characters, [])
	campaign.reputation = squad.get("total_reputation", 0)

	# Generate initial free fire team
	var fire_team := char_gen.generate_fire_team(4)
	campaign.grunts = fire_team

	# Register with GameState before saving
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("set_current_campaign"):
		game_state.set_current_campaign(campaign)
	elif game_state:
		game_state.current_campaign = campaign

	campaign.start_campaign()

	# Save once after start_campaign() so game_phase is correct
	var save_dir := "user://saves/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	var save_path := save_dir + campaign.get_campaign_id() + ".save"
	var err := campaign.save_to_file(save_path)
	if err != OK:
		push_error("BugHuntCreationCoordinator: Failed to save campaign: %d" % err)

	# Navigate to Bug Hunt dashboard/turn controller
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("bug_hunt_dashboard")
