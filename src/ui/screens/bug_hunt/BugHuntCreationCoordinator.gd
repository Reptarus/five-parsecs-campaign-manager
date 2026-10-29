class_name BugHuntCreationCoordinator
extends Node

## Orchestrates Bug Hunt campaign creation - 4-step wizard.
## Follows the same coordinator pattern as CampaignCreationCoordinator
## but simplified for Bug Hunt's needs.

const BugHuntStateManager := preload("res://src/core/campaign/creation/BugHuntCreationStateManager.gd")
const BugHuntCharGen := preload("res://src/core/character/BugHuntCharacterGeneration.gd")
const CoopView := preload("res://src/ui/screens/bug_hunt/BugHuntCoopView.gd")

signal navigation_updated(can_back: bool, can_forward: bool, can_finish: bool)
signal step_changed(step: int, total_steps: int)

var state_manager: BugHuntStateManager
var char_gen: BugHuntCharGen
var current_step: int = 0
var total_steps: int = 4
## The map-generation receipt of the last co-op campaign built (Compendium p.210), kept
## so the caller can show what the dice placed. {} for a campaign that is not co-op.
var coop_setup_receipt: Dictionary = {}


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
	# The co-op setup lives on the Config step, so a half-filled one holds that step.
	if current_step == 0 and not coop_config_ok():
		can_forward = false
	var can_finish := state_manager.can_finish() and current_step == total_steps - 1 \
		and coop_config_ok()
	navigation_updated.emit(can_back, can_forward, can_finish)


## True unless co-op is switched on and its setup is not one the map can be built from
## (no player named, a blank or duplicate name, sectors per player outside p.210's range).
func coop_config_ok() -> bool:
	return CoopView.coop_config_error(state_manager.config_data).is_empty()


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

func generate_squad(names: Array = [], count: int = 0) -> Dictionary:
	return char_gen.generate_squad(names, count)


func generate_regiment_name() -> Dictionary:
	return char_gen.generate_regiment_name()


## ============================================================================
## FINALIZATION
## ============================================================================

func finalize() -> void:
	if not state_manager.can_finish() or not coop_config_ok():
		push_warning("BugHuntCreationCoordinator: Cannot finalize - incomplete steps")
		return

	var campaign := build_campaign(state_manager.get_all_data())

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


## Create, register and seed the new campaign. Split out of finalize() so a test can
## inspect the campaign it produces without writing a save or navigating away.
func build_campaign(all_data: Dictionary) -> BugHuntCampaignCore:
	var campaign := BugHuntCampaignCore.create_new_campaign(
		all_data.config.campaign_name,
		all_data.config.difficulty
	)
	campaign.set_config(all_data.config)

	var squad: Dictionary = all_data.squad
	campaign.initialize_squad(squad.main_characters, [])

	# Generate initial free fire team
	campaign.grunts = char_gen.generate_fire_team(4)

	# Register BEFORE the Reputation write. GameStateManager.set_reputation() writes
	# through to GameState.current_campaign, and that write used to run first, so it
	# landed on the PREVIOUS campaign (overwriting a 5PFH crew's Reputation) while the
	# new squad started at 0.
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.has_method("set_current_campaign"):
		game_state.set_current_campaign(campaign)
	elif game_state:
		game_state.current_campaign = campaign

	var reputation: int = int(squad.get("total_reputation", 0))
	var _gsm = get_node_or_null("/root/GameStateManager")
	if _gsm and _gsm.has_method("set_reputation") and game_state \
			and game_state.current_campaign == campaign:
		_gsm.set_reputation(reputation)
	else:
		campaign.reputation = reputation  # lint:ignore — no live GameState to route through

	campaign.start_campaign()

	# Compendium pp.209-211: the co-op map is rolled now, once, through the core's one
	# writer -- after start_campaign(), so it is the active campaign the map belongs to,
	# and before finalize() saves, so the saved file carries it.
	coop_setup_receipt = {}
	var config: Dictionary = all_data.get("config", {})
	if bool(config.get("coop_enabled", false)):
		coop_setup_receipt = campaign.start_coop_campaign(
			CoopView.clean_players(config.get("coop_players", [])),
			int(config.get("coop_sectors_per_player", 0)))
		if not bool(coop_setup_receipt.get("ok", false)):
			push_error("BugHuntCreationCoordinator: the co-op map was refused: %s"
				% str(coop_setup_receipt.get("error", "")))
	return campaign
