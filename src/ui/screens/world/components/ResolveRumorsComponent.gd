extends WorldPhaseComponent
class_name ResolveRumorsComponent

## Resolve Rumors Component - Quest Generation System
## Implements Core Rules p.85 - Resolve rumors to generate quests
## Roll D6 - if equal or below number of rumors, convert to Quest

# UI Components
@onready var rumors_count_label: Label = %RumorsCountLabel
@onready var rumors_list: ItemList = %RumorsList
@onready var quest_status_label: Label = %QuestStatusLabel
@onready var roll_button: Button = %RollButton
@onready var result_label: Label = %ResultLabel
@onready var quest_description_label: Label = %QuestDescriptionLabel

# State
var rumors: Array = []
var quest_rumors: Array = []  # Rumors specifically for current quest
var current_quest: Dictionary = {}
var has_active_quest: bool = false
var rumors_resolved: bool = false
var last_roll: int = 0

func _ready() -> void:
	name = "ResolveRumorsComponent"
	super._ready()
	_apply_touch_target_sizing()
	# Portrait: stack the rumor-list + roll panes vertically (r16).
	_register_responsive_box($VBoxContainer/MainContainer)

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)

## Sprint C: Apply 48px minimum touch targets for mobile UX
func _apply_touch_target_sizing() -> void:
	const TOUCH_TARGET_MIN := 48
	if rumors_list:
		rumors_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)

func _connect_ui_signals() -> void:
	## Connect UI button signals
	if roll_button:
		roll_button.pressed.connect(_on_roll_pressed)

func _setup_initial_state() -> void:
	## Initialize component state
	rumors_resolved = false
	last_roll = 0
	_update_ui_display()

## Public API
func initialize_rumors_phase(rumor_list: Array, active_quest: Dictionary) -> void:
	## Initialize rumors phase with current rumors and quest status
	rumors = rumor_list.duplicate(true)
	current_quest = active_quest.duplicate(true)
	has_active_quest = not current_quest.is_empty()
	rumors_resolved = false
	last_roll = 0

	_populate_rumors_list()
	_update_ui_display()

	# AUTO-COMPLETE: If no rumors to resolve, mark as complete
	if rumors.size() == 0:
		rumors_resolved = true
		if result_label:
			result_label.text = "No rumors to resolve"
			result_label.modulate = Color(0.7, 0.7, 0.7)
		_update_ui_display()
		# Emit completion (deferred so PHASE_STARTED fires first below)
		call_deferred("_emit_auto_complete")

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "resolve_rumors",
			"rumor_count": rumors.size(),
			"has_quest": has_active_quest
		})

func _emit_auto_complete() -> void:
	## Emit PHASE_COMPLETED event for auto-complete (0 rumors case)
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "resolve_rumors",
			"roll": 0,
			"rumor_count": 0,
			"quest_generated": false
		})

func _populate_rumors_list() -> void:
	## Populate rumors list
	if not rumors_list:
		return

	rumors_list.clear()
	for i in range(rumors.size()):
		var rumor = rumors[i]
		var rumor_text = ""
		if rumor is Dictionary:
			rumor_text = rumor.get("description", "Rumor %d" % (i + 1))
		elif rumor is String:
			rumor_text = rumor
		else:
			rumor_text = "Rumor %d" % (i + 1)
		rumors_list.add_item(rumor_text)

## Core Mechanic - Resolve Rumors (Core Rules p.85)
func _on_roll_pressed() -> void:
	## Roll to resolve rumors
	if has_active_quest:
		if result_label:
			result_label.text = "Cannot resolve - Quest already active"
			result_label.modulate = Color(1.0, 0.5, 0.5)
		return

	if rumors.is_empty():
		if result_label:
			result_label.text = "No rumors to resolve"
			result_label.modulate = Color(0.8, 0.8, 0.8)
		return

	# Roll D6 - if equal or below rumor count, generate quest
	last_roll = randi() % 6 + 1
	var rumor_count = rumors.size()


	if last_roll <= rumor_count:
		# Success! Convert rumors to quest
		_generate_quest_from_rumors()
		if result_label:
			result_label.text = "Rolled %d ≤ %d rumors - QUEST GENERATED!" % [last_roll, rumor_count]
			result_label.modulate = Color(0.5, 1.0, 0.5)
	else:
		# Failed - rumors remain
		if result_label:
			result_label.text = "Rolled %d > %d rumors - No quest this turn" % [last_roll, rumor_count]
			result_label.modulate = Color(1.0, 0.8, 0.5)

	rumors_resolved = true
	_update_ui_display()

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "resolve_rumors",
			"roll": last_roll,
			"rumor_count": rumor_count,
			"quest_generated": last_roll <= rumor_count
		})

func _generate_quest_from_rumors() -> void:
	## Generate a quest from accumulated rumors
	# Remove all rumors - they've resolved into a quest
	var old_rumors = rumors.duplicate()
	rumors.clear()

	# A Quest carries no content in the book. Core Rules p.85 says only that you
	# "received a Quest which you may pursue immediately"; every mechanical
	# detail is rolled per battle (the p.89 D10 Quest objective table) or per
	# post-battle step (the p.120 progress roll). The old record also carried a
	# `type` off an invented list, three invented `objectives`, and a `rewards`
	# block promising 2D6 credits and +1 reputation that NOTHING ever paid —
	# fabricated mechanics displayed to the player as if they were rules. What
	# survives is bookkeeping the book does define, plus flavour text that has
	# no mechanical effect.
	var gs_node = get_node_or_null("/root/GameState")
	var turn_received: int = 0
	if gs_node and gs_node.current_campaign and "progress_data" in gs_node.current_campaign:
		turn_received = int(gs_node.current_campaign.progress_data.get("turns_played", 0))
	current_quest = {
		"id": "quest_%d" % randi(),
		"name": _generate_quest_name(),
		"description": _generate_quest_description(old_rumors),
		"turn_received": turn_received,
		"rumors_spent": old_rumors.size(),
		"stages_completed": 0,
	}

	has_active_quest = true

	_populate_rumors_list()
	_update_ui_display()

	if quest_description_label:
		quest_description_label.text = "New Quest: %s\n%s" % [current_quest.name, current_quest.description]
		quest_description_label.visible = true


	# Save quest to campaign data. FiveParsecsCampaignCore is a Resource, so the
	# old `campaign["active_quest"] = ...` was guarded by `is Dictionary` and thus
	# never ran (the quest was silently lost). Route through GameState.set_active_quest
	# which stores it in progress_data (Resource-safe) so has_active_quest() and the
	# p.119 post-battle quest-progress roll can actually see it.
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			campaign["active_quest"] = current_quest
			campaign["rumors"] = []
		elif game_state.has_method("set_active_quest"):
			game_state.set_active_quest(current_quest)

	# p.85: "remove all Rumors from your roster." The local `rumors` array was
	# cleared above, but that array is rebuilt from campaign.quest_rumors every
	# time the World step opens — so the Rumors were never actually spent. A
	# crew that banked 5 Rumors kept all 5 and re-rolled the Quest trigger every
	# single campaign turn (and, with the "already on a Quest" gate also dead,
	# overwrote its own Quest each time). Zeroing the canonical counter here is
	# what makes the Quest cost something.
	#
	# The same counter then accumulates again during the Quest: p.85 says "any
	# time you would receive a Rumor, you receive a Quest Rumor instead", and
	# p.120 adds "+1 for each Rumor you have accumulated while on this Quest" to
	# the progress roll. One counter serves both roles, which is exactly how the
	# book uses the term (p.36: "Quest Rumors (also referred to as Rumors)").
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("set_quest_rumors"):
		gsm.set_quest_rumors(0)

func _generate_quest_name() -> String:
	## Generate random quest name
	var prefixes = ["The Lost", "Hidden", "Ancient", "Stolen", "Mysterious", "Dangerous"]
	var subjects = ["Artifact", "Cargo", "Data", "Weapon", "Ship", "Coordinates"]
	return "%s %s" % [prefixes[randi() % prefixes.size()], subjects[randi() % subjects.size()]]

func _generate_quest_description(source_rumors: Array) -> String:
	## Generate quest description based on rumors
	var descriptions = [
		"Your accumulated intel has revealed the location of something valuable.",
		"Multiple sources confirm a significant opportunity awaits.",
		"The rumors point to a dangerous but potentially rewarding mission.",
		"Cross-referencing your leads has uncovered a hidden threat that must be addressed."
	]
	return descriptions[randi() % descriptions.size()]

## _get_random_quest_type / _generate_quest_objectives / _generate_quest_rewards
## were DELETED 2026-08-02. None of the three had any grounding in the rulebook
## and none of them was read by any consumer: the "rewards" block in particular
## showed the player a 2D6-credit and +1-reputation payout that no code path
## ever granted. A Quest's objective is rolled per battle on the p.89 D10 table
## and its payout is the p.120 Step 4 double-roll — both already implemented.
## Do not reintroduce quest content tables; the book has none.

## UI Updates
func _update_ui_display() -> void:
	## Update all UI elements
	if rumors_count_label:
		rumors_count_label.text = "Rumors: %d" % rumors.size()

	if quest_status_label:
		if has_active_quest:
			quest_status_label.text = "Quest Active: %s" % current_quest.get("name", "Unknown")
			quest_status_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			quest_status_label.text = "No Active Quest"
			quest_status_label.modulate = Color(0.8, 0.8, 0.8)

	if roll_button:
		roll_button.disabled = has_active_quest or rumors.is_empty() or rumors_resolved
		if has_active_quest:
			roll_button.text = "Quest Already Active"
		elif rumors.is_empty():
			roll_button.text = "No Rumors"
		elif rumors_resolved:
			roll_button.text = "Already Resolved"
		else:
			roll_button.text = "Roll to Resolve (D6 ≤ %d)" % rumors.size()

## Event Handlers
func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "resolve_rumors":
		pass

## Public API
func is_rumors_resolved() -> bool:
	## Check if rumors phase is completed
	return rumors_resolved

func get_blocker_hint() -> String:
	## Human-readable reason this step can't advance yet ("" if it can).
	if rumors_resolved:
		return ""
	return "Resolve your rumors (or skip if you have none) to continue."

func get_current_quest() -> Dictionary:
	## Get current quest data
	return current_quest.duplicate(true)

func get_remaining_rumors() -> Array:
	## Get remaining rumors
	return rumors.duplicate(true)

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	## Get step results for phase completion (standardized interface)
	return {
		"rumors_resolved": rumors_resolved,
		"current_quest": current_quest.duplicate(true),
		"remaining_rumors": rumors.duplicate(true),
		"quest_rumors": quest_rumors.duplicate(true),
		"has_active_quest": has_active_quest,
		"last_roll": last_roll
	}

func add_rumor(rumor: Variant) -> void:
	## Add a new rumor (or quest rumor if quest active)
	if has_active_quest:
		# During quest, rumors become quest rumors
		quest_rumors.append(rumor)
	else:
		rumors.append(rumor)
		_populate_rumors_list()
		_update_ui_display()

## Consume quest rumors when advancing quest progress (Five Parsecs p.85)
func consume_quest_rumor() -> bool:
	## Consume one quest rumor to advance quest progress. Returns true if rumor was consumed.
	if not has_active_quest:
		push_warning("ResolveRumorsComponent: Cannot consume quest rumor - no active quest")
		return false

	if quest_rumors.is_empty():
		push_warning("ResolveRumorsComponent: No quest rumors to consume")
		return false

	# Remove the first quest rumor (FIFO)
	var consumed_rumor = quest_rumors.pop_front()

	# Save to campaign data
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign and "active_quest" in campaign and campaign.active_quest:
			# Update quest_rumors in saved quest
			campaign.active_quest["quest_rumors"] = quest_rumors.duplicate()

	return true

## Get count of quest rumors available for quest progression
func get_quest_rumor_count() -> int:
	## Get number of quest rumors available to advance quest
	return quest_rumors.size()

func reset_rumors_phase() -> void:
	## Reset for new turn
	rumors_resolved = false
	last_roll = 0
	if result_label:
		result_label.text = ""
	_update_ui_display()
