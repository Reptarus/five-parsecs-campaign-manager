# PostBattle.gd
extends Control
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal phase_completed
signal level_up_triggered(character: Character)

var step_label: Label = null
var step_description: Label = null
var step_content: Control = null

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_CONTENT_RATIO := 0.7

var current_step := 0
var steps: Array[String] = [
	"Resolve Combat Results",
	"Apply Injuries",
	"Collect Loot",
	"Update Mission Status",
	"Record Experience"
]

var game_state: FiveParsecsGameState
var loot_generator: Node # Will be typed when LootGenerator is available

func _init(_game_state: FiveParsecsGameState) -> void:
	if not _game_state:
		push_error("Invalid game state provided to PostBattlePhase")
		return
	game_state = _game_state

func _ready() -> void:
	# Only set up UI if we have child nodes (scene-instanced, not .new())
	step_label = get_node_or_null("VBoxContainer/StepLabel")
	step_description = get_node_or_null("VBoxContainer/StepDescription")
	step_content = get_node_or_null("VBoxContainer/ScrollContainer/StepContent")
	if step_label:
		_setup_post_battle_ui()
		_show_current_step()

func process_post_battle() -> void:
	## Backend post-battle processing.
	## Note: Most post-battle logic is handled by PostBattleSequence (UI).
	## This backend only handles journal persistence and story track advancement.
	_persist_battle_journal()
	_advance_story_track()
	phase_completed.emit()

func _persist_battle_journal() -> void:
	## Log battle results to CampaignJournal for persistence
	var journal = get_node_or_null("/root/CampaignJournal")
	if not journal or not journal.has_method("auto_create_battle_entry"):
		return
	var battle_results: Dictionary = game_state.get_battle_results() if game_state else {}
	if battle_results.is_empty():
		return
	var victory: bool = battle_results.get("victory", false)
	var battle_entry: Dictionary = {
		"turn": game_state.current_turn if "current_turn" in game_state else 0,
		"outcome": "victory" if victory else "defeat",
		"casualties": 0,
		"location": "Unknown",
		"loot": 0,
		"xp": 0,
		"crew_ids": []
	}
	journal.auto_create_battle_entry(battle_entry)

func _advance_story_track() -> void:
	## Advance story track if enabled (Core Rules Appendix V)
	if not game_state:
		return
	var campaign = game_state.campaign if "campaign" in game_state else null
	if not campaign:
		return
	# Check if story track is enabled for this campaign
	var story_enabled: bool = campaign.story_track_enabled if "story_track_enabled" in campaign else false
	if not story_enabled:
		return
	# Instantiate story track system and load existing state
	var story_track := FPCM_StoryTrackSystem.new()
	var progress: Dictionary = campaign.progress_data if "progress_data" in campaign else {}
	var story_state: Dictionary = progress.get("story_track", {})
	if not story_state.is_empty():
		story_track.deserialize(story_state)
	elif not story_track.is_story_track_active:
		story_track.start_story_track()
	# Advance turn with current campaign data
	var current_turn: int = game_state.current_turn if "current_turn" in game_state else 0
	var quest_rumors: int = campaign.quest_rumors if "quest_rumors" in campaign else 0
	var result: Dictionary = story_track.advance_turn(current_turn, quest_rumors)
	# Persist updated state back to campaign progress_data
	campaign.progress_data["story_track"] = story_track.serialize()
	# Log milestone to journal if event was triggered
	if result.get("event_triggered", false):
		var journal = get_node_or_null("/root/CampaignJournal")
		if journal and journal.has_method("add_entry"):
			journal.add_entry("Story Track: Event triggered (clock advanced)")
	pass

func _resolve_combat_results() -> void:
	var battle_results: Dictionary = game_state.get_battle_results() if game_state else {}
	if battle_results.is_empty():
		push_warning("PostBattlePhase: No battle results available, skipping combat resolution")
		return
	if battle_results.get("victory", false):
		_handle_victory()
	else:
		_handle_defeat()

func _handle_victory() -> void:
	game_state.current_mission.complete()
	_apply_victory_rewards()
	_update_faction_relations(true)

func _handle_defeat() -> void:
	game_state.current_mission.fail()
	_apply_defeat_penalties()
	_update_faction_relations(false)

func _apply_injuries() -> void:
	for character in game_state.current_crew.get_active_members():
		if character.current_health < character.max_health:
			_apply_injury_effects(character)

func _apply_injury_effects(character: Character) -> void:
	var injury_severity = _calculate_injury_severity(character)
	var injury_type = _determine_injury_type(injury_severity)
	character.apply_injury(injury_type)

func _collect_loot() -> void:
	if not loot_generator:
		push_error("LootGenerator not initialized")
		return
	
	var loot = loot_generator.generate_post_battle_loot(
		game_state.current_mission,
		game_state.get_battle_results()
	)
	loot_generator.apply_loot(game_state.current_crew, loot)

func _update_mission_status() -> void:
	if game_state.get_battle_results().get("victory", false):
		_process_mission_completion()
	else:
		_process_mission_failure()

func _record_experience() -> void:
	for character in game_state.current_crew.get_active_members():
		var xp_gained = _calculate_experience_gain(character)
		character.gain_experience(xp_gained)
		_check_level_up(character)

# Helper functions
func _calculate_injury_severity(character: Character) -> int:
	var health_percentage = (character.current_health / character.max_health) * 100
	if health_percentage <= 25:
		return 3 # Severe
	elif health_percentage <= 50:
		return 2 # Moderate
	return 1 # Light

func _determine_injury_type(severity: int) -> String:
	var injury_types = {
		1: ["Bruised", "Scratched", "Winded"],
		2: ["Sprained", "Concussed", "Fractured"],
		3: ["Broken", "Traumatized", "Critical"]
	}
	var possible_types = injury_types[severity]
	return possible_types[randi() % possible_types.size()]

func _calculate_experience_gain(character: Character) -> int:
	var base_xp = 10
	if game_state.get_battle_results().get("victory", false):
		base_xp += 5
	if character.current_health < character.max_health:
		base_xp += 3
	return base_xp

func _check_level_up(character: Character) -> void:
	if character.can_level_up():
		character.trigger_level_up() # Changed to use trigger_level_up() instead of level_up signal
		level_up_triggered.emit(character)

func _update_faction_relations(victory: bool) -> void:
	var faction = game_state.current_mission.faction
	if faction:
		var relation_change = 10 if victory else -5
		game_state.update_faction_relation(faction, relation_change)

# UI related functions
func _setup_post_battle_ui() -> void:
	_setup_step_content()
	_setup_buttons()

func _show_current_step() -> void:
	if not step_label or not step_description or not step_content:
		return
	
	step_label.text = steps[current_step]
	step_description.text = _get_step_description(current_step)
	_update_step_content(current_step)

func _get_step_description(step: int) -> String:
	match step:
		0: return "Determining final battle results..."
		1: return "Checking crew for injuries..."
		2: return "Gathering battlefield salvage..."
		3: return "Updating mission objectives..."
		4: return "Calculating experience gained..."
		_: return ""

func _update_step_content(step: int) -> void:
	# Clear previous content
	for child in step_content.get_children():
		child.queue_free()
	
	# Add new content based on step
	match step:
		0: _show_combat_results()
		1: _show_injury_report()
		2: _show_loot_collection()
		3: _show_mission_update()
		4: _show_experience_gains()

func _show_combat_results() -> void:
	# Implementation
	pass

func _show_injury_report() -> void:
	# Implementation
	pass

func _show_loot_collection() -> void:
	# Implementation
	pass

func _show_mission_update() -> void:
	# Implementation
	pass

func _show_experience_gains() -> void:
	# Implementation
	pass

func _setup_step_content() -> void:
	# Implementation
	pass

func _setup_buttons() -> void:
	# Implementation
	pass

func _apply_victory_rewards() -> void:
	# Implementation
	pass

func _apply_defeat_penalties() -> void:
	# Implementation
	pass

func _process_mission_completion() -> void:
	# Implementation
	pass

func _process_mission_failure() -> void:
	# Implementation
	pass
