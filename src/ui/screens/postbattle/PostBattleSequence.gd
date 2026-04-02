class_name PostBattleSequenceUI
extends Control

# Backend Service Integrations - using explicit preloads to fix linter issues
const FPCM_InjuryService = preload("res://src/core/services/InjurySystemService.gd")
const FPCM_HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const AdvancementService = preload("res://src/core/services/CharacterAdvancementService.gd")
const LootSystemConstants = preload("res://src/core/systems/LootSystemConstants.gd")
const DataLoader = preload("res://src/utils/GameDataLoader.gd")
const WarPanel = preload("res://src/ui/components/postbattle/GalacticWarPanel.tscn")
const TrainingDialog = preload("res://src/ui/components/postbattle/TrainingSelectionDialog.tscn")
const AdvancementSystemClass = preload("res://src/core/character/advancement/AdvancementSystem.gd")
const NarrativeInjuryDialog = preload("res://src/ui/components/postbattle/NarrativeInjuryDialog.gd")
const PurchaseItemsComponent = preload("res://src/ui/screens/world/components/PurchaseItemsComponent.tscn")

# Bot upgrade system instance
var _advancement_system: RefCounted = null
# Cached for _exit_tree() signal cleanup
var _post_battle_phase: Node = null

signal post_battle_completed(results: Dictionary)
signal step_completed(step_index: int, results: Dictionary)

@onready var step_counter: Label = %StepCounter
@onready var steps_container: VBoxContainer = %StepsContainer
@onready var step_title: Label = %StepTitle
@onready var step_content: VBoxContainer = %StepContent
@onready var results_container: VBoxContainer = %ResultsContainer
@onready var previous_button: Button = %PreviousButton
@onready var next_button: Button = %NextButton
@onready var roll_button: Button = %RollButton
@onready var finish_button: Button = %FinishButton

var current_step: int = 0
var max_steps: int = 14
var battle_results: Dictionary = {}
var step_results: Array[Dictionary] = []

## Helper to work around static function linter issues with InjurySystemService
func _is_narrative_injuries_mode() -> bool:
	# Use preloaded HouseRulesHelper (same logic as InjurySystemService.is_narrative_injuries_enabled)
	return FPCM_HouseRulesHelper.is_enabled("narrative_injuries")

var post_battle_steps: Array[Dictionary] = [
	{"name": "1. Resolve Rival Status", "description": "Check if rivals follow you", "requires_roll": true},
	{"name": "2. Resolve Patron Status", "description": "Update patron relationships", "requires_roll": false},
	{"name": "3. Determine Quest Progress", "description": "Check quest advancement", "requires_roll": false},
	{"name": "4. Get Paid", "description": "Receive mission payment", "requires_roll": false},
	{"name": "5. Battlefield Finds", "description": "Search the battlefield", "requires_roll": true},
	{"name": "6. Check for Invasion", "description": "Roll for invasion threat", "requires_roll": true},
	{"name": "7. Gather the Loot", "description": "Roll on loot tables", "requires_roll": true},
	{"name": "8. Determine Injuries", "description": "Check crew injuries and recovery", "requires_roll": true},
	{"name": "9. Experience & Upgrades", "description": "Gain XP and character upgrades", "requires_roll": false},
	{"name": "10. Advanced Training", "description": "Invest in advanced training", "requires_roll": false},
	{"name": "11. Purchase Items", "description": "Buy equipment and supplies", "requires_roll": false},
	{"name": "12. Campaign Events", "description": "Roll for campaign events", "requires_roll": true},
	{"name": "13. Character Events", "description": "Roll for character events", "requires_roll": true},
	{"name": "14. Galactic War", "description": "Check Galactic War progress", "requires_roll": true}
]

func _ready() -> void:
	_initialize_advancement_system()
	_initialize_steps()
	_load_battle_results()
	_connect_backend_signals()  # Sprint 20.1: Connect to PostBattlePhase backend signals
	_show_current_step()
	_setup_postbattle_icons()
	_style_step_content_panel()


func _initialize_advancement_system() -> void:
	## Initialize the advancement system for bot upgrades
	_advancement_system = AdvancementSystemClass.new()

func _initialize_steps() -> void:
	## Initialize the post-battle sequence
	# Initialize step results array
	step_results.resize(max_steps)
	for i: int in range(max_steps):
		step_results[i] = {}

	# Create step list display
	_refresh_steps_list()

func _load_battle_results() -> void:
	## Load battle results from GameState (stored by CampaignTurnController)
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_battle_results"):
		var stored = gs.get_battle_results()
		if not stored.is_empty():
			battle_results = stored
			return

	# Fallback for testing when no battle was run
	battle_results = {
		"victory": true,
		"mission_type": "Opportunist",
		"enemy_defeated": 0,
		"crew_casualties": 0,
		"crew_injuries": 0,
		"loot_opportunities": 0,
		"payment": 0,
		"story_points_earned": 0,
		"loot_found": []
	}

## Sprint 20.1: Connect backend signals from PostBattlePhase
## This wires UI to all backend signals for real-time updates
func _connect_backend_signals() -> void:
	## Connect to PostBattlePhase backend signals for UI updates
	# Try to get PostBattlePhase from CampaignPhaseManager
	var phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	var post_battle_phase: Node = null

	if phase_manager and phase_manager.has_method("get_phase_handler"):
		post_battle_phase = phase_manager.get_phase_handler("post_battle")

	# Alternative: check for direct autoload
	if not post_battle_phase:
		post_battle_phase = get_node_or_null("/root/PostBattlePhase")

	if not post_battle_phase:
		# Backend is optional during _ready() — panel may be hidden and not in use yet.
		# Error dialog is deferred to when the panel is actually shown via setup_post_battle().
		return

	# Cache reference for _exit_tree() cleanup
	_post_battle_phase = post_battle_phase


	# Connect all backend signals to UI handlers
	if post_battle_phase.has_signal("payment_received"):
		post_battle_phase.payment_received.connect(_on_backend_payment_received)

	if post_battle_phase.has_signal("quest_progress_updated"):
		post_battle_phase.quest_progress_updated.connect(_on_backend_quest_progress)

	if post_battle_phase.has_signal("invasion_checked"):
		post_battle_phase.invasion_checked.connect(_on_backend_invasion_checked)

	if post_battle_phase.has_signal("experience_awarded"):
		post_battle_phase.experience_awarded.connect(_on_backend_experience_awarded)

	if post_battle_phase.has_signal("campaign_event_occurred"):
		post_battle_phase.campaign_event_occurred.connect(_on_backend_campaign_event)

	if post_battle_phase.has_signal("character_event_occurred"):
		post_battle_phase.character_event_occurred.connect(_on_backend_character_event)

	if post_battle_phase.has_signal("galactic_war_updated"):
		post_battle_phase.galactic_war_updated.connect(_on_backend_galactic_war_updated)

	if post_battle_phase.has_signal("training_completed"):
		post_battle_phase.training_completed.connect(_on_backend_training_result)

	if post_battle_phase.has_signal("precursor_event_choice_available"):
		post_battle_phase.precursor_event_choice_available.connect(_on_backend_precursor_event_choice)

	if post_battle_phase.has_signal("loot_gathered"):
		post_battle_phase.loot_gathered.connect(_on_backend_loot_generated)

	if post_battle_phase.has_signal("injuries_resolved"):
		post_battle_phase.injuries_resolved.connect(_on_backend_injury_result)

	if post_battle_phase.has_signal("battlefield_finds_completed"):
		post_battle_phase.battlefield_finds_completed.connect(_on_backend_battlefield_finds)

	if post_battle_phase.has_signal("rival_status_resolved"):
		post_battle_phase.rival_status_resolved.connect(_on_backend_rival_status)

	if post_battle_phase.has_signal("patron_status_resolved"):
		post_battle_phase.patron_status_resolved.connect(_on_backend_patron_status)

	if post_battle_phase.has_signal("purchases_made"):
		post_battle_phase.purchases_made.connect(_on_backend_purchases_made)

	if post_battle_phase.has_signal("post_battle_substep_changed"):
		post_battle_phase.post_battle_substep_changed.connect(_on_backend_substep_changed)

func _exit_tree() -> void:
	# Disconnect PostBattlePhase signals to prevent memory leaks
	# (PostBattlePhase is a child of CampaignPhaseManager autoload — persists across scenes)
	if _post_battle_phase and is_instance_valid(_post_battle_phase):
		var _pbp := _post_battle_phase
		if _pbp.has_signal("payment_received") and _pbp.payment_received.is_connected(_on_backend_payment_received):
			_pbp.payment_received.disconnect(_on_backend_payment_received)
		if _pbp.has_signal("quest_progress_updated") and _pbp.quest_progress_updated.is_connected(_on_backend_quest_progress):
			_pbp.quest_progress_updated.disconnect(_on_backend_quest_progress)
		if _pbp.has_signal("invasion_checked") and _pbp.invasion_checked.is_connected(_on_backend_invasion_checked):
			_pbp.invasion_checked.disconnect(_on_backend_invasion_checked)
		if _pbp.has_signal("experience_awarded") and _pbp.experience_awarded.is_connected(_on_backend_experience_awarded):
			_pbp.experience_awarded.disconnect(_on_backend_experience_awarded)
		if _pbp.has_signal("campaign_event_occurred") and _pbp.campaign_event_occurred.is_connected(_on_backend_campaign_event):
			_pbp.campaign_event_occurred.disconnect(_on_backend_campaign_event)
		if _pbp.has_signal("character_event_occurred") and _pbp.character_event_occurred.is_connected(_on_backend_character_event):
			_pbp.character_event_occurred.disconnect(_on_backend_character_event)
		if _pbp.has_signal("galactic_war_updated") and _pbp.galactic_war_updated.is_connected(_on_backend_galactic_war_updated):
			_pbp.galactic_war_updated.disconnect(_on_backend_galactic_war_updated)
		if _pbp.has_signal("training_completed") and _pbp.training_completed.is_connected(_on_backend_training_result):
			_pbp.training_completed.disconnect(_on_backend_training_result)
		if _pbp.has_signal("precursor_event_choice_available") and _pbp.precursor_event_choice_available.is_connected(_on_backend_precursor_event_choice):
			_pbp.precursor_event_choice_available.disconnect(_on_backend_precursor_event_choice)
		if _pbp.has_signal("loot_gathered") and _pbp.loot_gathered.is_connected(_on_backend_loot_generated):
			_pbp.loot_gathered.disconnect(_on_backend_loot_generated)
		if _pbp.has_signal("injuries_resolved") and _pbp.injuries_resolved.is_connected(_on_backend_injury_result):
			_pbp.injuries_resolved.disconnect(_on_backend_injury_result)
		if _pbp.has_signal("battlefield_finds_completed") and _pbp.battlefield_finds_completed.is_connected(_on_backend_battlefield_finds):
			_pbp.battlefield_finds_completed.disconnect(_on_backend_battlefield_finds)
		if _pbp.has_signal("rival_status_resolved") and _pbp.rival_status_resolved.is_connected(_on_backend_rival_status):
			_pbp.rival_status_resolved.disconnect(_on_backend_rival_status)
		if _pbp.has_signal("patron_status_resolved") and _pbp.patron_status_resolved.is_connected(_on_backend_patron_status):
			_pbp.patron_status_resolved.disconnect(_on_backend_patron_status)
		if _pbp.has_signal("purchases_made") and _pbp.purchases_made.is_connected(_on_backend_purchases_made):
			_pbp.purchases_made.disconnect(_on_backend_purchases_made)
		if _pbp.has_signal("post_battle_substep_changed") and _pbp.post_battle_substep_changed.is_connected(_on_backend_substep_changed):
			_pbp.post_battle_substep_changed.disconnect(_on_backend_substep_changed)
	_post_battle_phase = null

## Backend Signal Handlers - Sprint 20.1
## These receive data from PostBattlePhase and update UI accordingly

func _on_backend_payment_received(amount: int) -> void:
	## Handle payment received from backend
	battle_results["payment"] = amount
	battle_results["credits_earned"] = amount
	_add_result_to_log("Payment received: %d credits" % amount)

func _on_backend_quest_progress(progress: int) -> void:
	## Handle quest progress update from backend
	var outcome_text: String
	if progress <= 0:
		outcome_text = "Quest Dead End - No progress this mission"
	elif progress == 1:
		outcome_text = "Quest Progress - +1 Rumor gained!"
	else:
		outcome_text = "Quest Finale Available! Prepare for final confrontation."
	_add_result_to_log(outcome_text)

func _on_backend_invasion_checked(invasion_pending: bool) -> void:
	## Handle invasion check result from backend
	if invasion_pending:
		_add_result_to_log("[color=#DC2626]INVASION IMMINENT![/color] Unity forces detected!")
	else:
		_add_result_to_log("Sector Clear - No invasion threat detected")

func _on_backend_experience_awarded(xp_awards: Array) -> void:
	## Handle XP awards from backend
	for award in xp_awards:
		if award is Dictionary:
			var crew_name = award.get("crew_name", "Unknown")
			var xp_amount = award.get("xp", 0)
			_add_result_to_log("%s gained %d XP" % [crew_name, xp_amount])

func _on_backend_campaign_event(event: Dictionary) -> void:
	## Handle campaign event from backend - apply effect!
	var event_name = event.get("name", "Unknown Event")
	var event_desc = event.get("description", "")
	_add_result_to_log("Campaign Event: %s - %s" % [event_name, event_desc])

	# CRITICAL: Apply the event effect via backend
	var phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if phase_manager and phase_manager.has_method("get_phase_handler"):
		var post_battle_phase = phase_manager.get_phase_handler("post_battle")
		if post_battle_phase and post_battle_phase.has_method("apply_campaign_event_effect"):
			post_battle_phase.apply_campaign_event_effect(event)

func _on_backend_character_event(event: Dictionary) -> void:
	## Handle character event from backend - apply effect!
	var char_name = event.get("character_name", "Unknown")
	var event_name = event.get("name", "Unknown Event")
	_add_result_to_log("%s: %s" % [char_name, event_name])

	# Apply the event effect
	var phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if phase_manager and phase_manager.has_method("get_phase_handler"):
		var post_battle_phase = phase_manager.get_phase_handler("post_battle")
		if post_battle_phase and post_battle_phase.has_method("apply_character_event_effect"):
			post_battle_phase.apply_character_event_effect(event)

func _on_backend_galactic_war_updated(progress: Dictionary) -> void:
	## Handle Galactic War update from backend
	var planet_results = progress.get("planet_results", [])
	for result in planet_results:
		var planet_name = result.get("planet", "Unknown")
		var outcome = result.get("result", "unknown")
		_add_result_to_log("Galactic War - %s: %s" % [planet_name, outcome])

	# Update GalacticWarPanel if visible
	var war_panel = step_content.find_child("GalacticWarPanel") if step_content else null
	if war_panel and war_panel.has_method("update_war_status"):
		war_panel.update_war_status(progress)

func _on_backend_training_result(training: Array) -> void:
	## Handle training enrollment result from backend
	for result in training:
		if result is Dictionary:
			var crew_name = result.get("crew_name", "Unknown")
			var course = result.get("course", "Unknown")
			var success = result.get("success", false)
			if success:
				_add_result_to_log("%s enrolled in %s training!" % [crew_name, course])
			else:
				var reason = result.get("reason", "unknown")
				_add_result_to_log("%s training application denied: %s" % [crew_name, reason])

func _on_backend_precursor_event_choice(event1: Dictionary, event2: Dictionary) -> void:
	## Handle Precursor event choice available - auto-select first event for now
	# NOTE: Deferred — show PrecursorEventChoiceDialog for player selection instead of auto-selecting
	_handle_precursor_choice(1, event1, event2)

func _handle_precursor_choice(choice: int, event1: Dictionary, event2: Dictionary) -> void:

	var phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if phase_manager and phase_manager.has_method("get_phase_handler"):
		var post_battle_phase = phase_manager.get_phase_handler("post_battle")
		if post_battle_phase and post_battle_phase.has_method("select_precursor_event"):
			post_battle_phase.select_precursor_event(choice)
		else:
			push_warning("PostBattleSequence: PostBattlePhase missing select_precursor_event method")
	else:
		# Fallback: emit the chosen event directly
		var chosen_event: Dictionary = event1 if choice == 1 else event2
		_add_result_to_log("Precursor Vision: %s" % chosen_event.get("name", "Unknown Event"))

func _on_backend_loot_generated(loot: Array) -> void:
	## Handle loot generated from backend
	for item in loot:
		if item is Dictionary:
			var item_name = item.get("name", "Unknown Item")
			_add_result_to_log("Loot found: %s" % item_name)

func _on_backend_injury_result(injuries: Array) -> void:
	## Handle injury results from backend
	for injury in injuries:
		if injury is Dictionary:
			var crew_name = injury.get("crew_name", "Unknown")
			var severity = injury.get("severity", "Unknown")
			var recovery = injury.get("recovery_turns", 0)
			if injury.get("is_fatal", false):
				_add_result_to_log("[color=#DC2626]%s: FATAL - %s[/color]" % [crew_name, severity])
			elif recovery > 0:
				_add_result_to_log("%s: %s (%d turns recovery)" % [crew_name, severity, recovery])
			else:
				_add_result_to_log("%s: %s" % [crew_name, severity])

func _on_backend_battlefield_finds(finds: Array) -> void:
	## Handle battlefield finds from backend
	for find in finds:
		if find is Dictionary:
			var description = find.get("description", "Unknown find")
			var credits = find.get("credits", 0)
			if credits > 0:
				_add_result_to_log("Battlefield: %s (+%d credits)" % [description, credits])
			else:
				_add_result_to_log("Battlefield: %s" % description)

func _on_backend_rival_status(rivals_removed: Array) -> void:
	## Handle rival status resolution from backend
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	var turn: int = _get_current_turn()
	for rival in rivals_removed:
		if rival is Dictionary:
			var rival_name = rival.get("name", "Unknown Rival")
			var rival_id = rival.get("rival_id", rival.get("id", rival_name))
			var follows = rival.get("follows", false)
			if follows:
				_add_result_to_log("Rival %s follows you to the next world" % rival_name)
			else:
				_add_result_to_log("Rival %s stays behind" % rival_name)
			# Track rival encounter in NPCTracker
			if npc_tracker and npc_tracker.has_method("track_rival_encounter"):
				var result = "victory" if not follows else "ongoing"
				npc_tracker.track_rival_encounter(str(rival_id), result, turn)

func _on_backend_patron_status(patrons_added: Array) -> void:
	## Handle patron status resolution from backend
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	var turn: int = _get_current_turn()
	for patron in patrons_added:
		if patron is Dictionary:
			var patron_name = patron.get("name", "Unknown Patron")
			var patron_id = patron.get("patron_id", patron.get("id", patron_name))
			_add_result_to_log("Patron update: %s" % patron_name)
			# Track patron interaction in NPCTracker
			if npc_tracker and npc_tracker.has_method("track_patron_interaction"):
				npc_tracker.track_patron_interaction(str(patron_id), "job_completed", {"turn": turn})

func _on_backend_purchases_made(purchases: Array) -> void:
	## Handle purchases made from backend
	for purchase in purchases:
		if purchase is Dictionary:
			var item_name = purchase.get("name", "Unknown Item")
			var cost = purchase.get("cost", 0)
			_add_result_to_log("Purchased: %s (-%d credits)" % [item_name, cost])

func _on_backend_substep_changed(substep: int) -> void:
	## Handle substep change from backend - sync UI
	if substep != current_step and substep < max_steps:
		current_step = substep
		_show_current_step()

## Step group headers inserted before specific step indices
const STEP_GROUP_HEADERS: Dictionary = {
	0: "── RESOLUTION ──",
	3: "── REWARDS ──",
	7: "── CASUALTIES ──",
	8: "── GROWTH ──",
	10: "── ECONOMY ──",
	11: "── EVENTS ──",
}

func _refresh_steps_list() -> void:
	## Refresh the steps list display with status icons and group headers
	# Clear existing steps
	for child in steps_container.get_children():
		child.queue_free()

	# Add step items with group headers
	for i: int in range(max_steps):
		# Insert group header before certain steps
		if i in STEP_GROUP_HEADERS:
			var header: Label = Label.new()
			header.text = STEP_GROUP_HEADERS[i]
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_color_override("font_color", Color("#808080"))
			header.add_theme_font_size_override("font_size", 11)
			steps_container.add_child(header)

		var step_panel: Control = _create_step_panel(i)
		steps_container.add_child(step_panel)

func _create_step_panel(step_index: int) -> Control:
	## Create a panel for a post-battle step with status icon
	var panel: PanelContainer = PanelContainer.new()
	var label: Label = Label.new()
	panel.add_child(label)

	var step = post_battle_steps[step_index]

	# Prepend status indicator based on completion
	var icon: String
	if step_index < current_step:
		icon = "✓ "
		label.modulate = UIColors.COLOR_EMERALD # Completed
	elif step_index == current_step:
		icon = "► "
		label.modulate = UIColors.COLOR_AMBER # Current
	else:
		icon = "○ "
		label.modulate = Color("#808080") # Future (gray)

	label.text = icon + step.name

	return panel

func _show_current_step() -> void:
	## Display the current step content
	if current_step >= max_steps:
		_finish_post_battle()
		return

	var step = post_battle_steps[current_step]

	# Update UI
	step_counter.text = "Step " + str(current_step + 1) + " of " + str(max_steps)
	step_title.text = step.name

	# Clear step content
	for child in step_content.get_children():
		child.queue_free()

	# Add step description
	var description_label: Label = Label.new()
	description_label.text = step.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step_content.add_child(description_label)

	# Add step-specific content
	_add_step_specific_content(current_step)

	# Update button states
	previous_button.disabled = (current_step == 0)
	roll_button.visible = step.requires_roll
	finish_button.visible = (current_step == max_steps - 1)

	# Refresh steps list
	_refresh_steps_list()

func _add_step_specific_content(step_index: int) -> void:
	## Add specific content for each step
	match step_index:
		0: # Rival Status
			_add_rival_status_content()
		1: # Patron Status
			_add_patron_status_content()
		2: # Quest Progress
			_add_quest_progress_content()
		3: # Get Paid
			_add_payment_content()
		4: # Battlefield Finds
			_add_battlefield_finds_content()
		5: # Invasion Check
			_add_invasion_check_content()
		6: # Loot
			_add_loot_content()
		7: # Injuries
			_add_injury_content()
		8: # Experience
			_add_experience_content()
		9: # Advanced Training
			_add_training_content()
		10: # Purchase Items
			_add_purchase_content()
		11: # Campaign Events
			_add_campaign_events_content()
		12: # Character Events
			_add_character_events_content()
		13: # Galactic War
			_add_galactic_war_content()

func _add_rival_status_content() -> void:
	## Add rival status check content with Five Parsecs rules
	var label: Label = Label.new()
	label.text = "Roll D6 for each rival to see if they follow you to the next world.\nRival follows on 1-3, stays behind on 4-6."
	step_content.add_child(label)
	
	# Get current rivals from campaign data
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("get_rivals"):
		var rivals = gsm.get_rivals()
		for rival in rivals:
			var rival_panel = _create_rival_status_panel(rival)
			step_content.add_child(rival_panel)

func _create_rival_status_panel(rival: Dictionary) -> Control:
	## Create a panel for rival status checking
	var panel = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = rival.get("name", "Unknown Rival")
	name_label.custom_minimum_size.x = 150
	panel.add_child(name_label)
	
	var roll_button = Button.new()
	roll_button.text = "Roll for " + rival.get("name", "Rival")
	roll_button.pressed.connect(_on_rival_status_roll.bind(rival))
	panel.add_child(roll_button)
	
	var result_label = Label.new()
	result_label.name = "result_" + str(rival.get("id", 0))
	result_label.text = "Not rolled"
	panel.add_child(result_label)
	
	return panel

func _add_patron_status_content() -> void:
	## Add patron status content
	var label: Label = Label.new()
	label.text = "Update patron relationships based on mission success."
	step_content.add_child(label)

func _add_quest_progress_content() -> void:
	## Add quest progress content
	var label: Label = Label.new()
	label.text = "Check if any active quests advance based on mission results."
	step_content.add_child(label)

func _add_payment_content() -> void:
	## Add payment content with automatic credit application
	var payment = battle_results.get("payment", 0)
	var victory_bonus = 0
	
	if battle_results.get("victory", false):
		victory_bonus = payment * 0.5 # 50% bonus for victory
	
	var total_payment = payment + victory_bonus
	
	var label: Label = Label.new()
	label.text = "Base payment: %d credits\nVictory bonus: %d credits\nTotal received: %d credits" % [payment, victory_bonus, total_payment]
	step_content.add_child(label)
	
	# Apply payment to campaign
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("get_credits") and gsm.has_method("set_credits"):
		gsm.set_credits(gsm.get_credits() + total_payment)
		_add_result_to_log("Received %d credits" % total_payment)
	
	var apply_button = Button.new()
	apply_button.text = "Apply Payment"
	apply_button.pressed.connect(_on_apply_payment.bind(total_payment))
	step_content.add_child(apply_button)

func _add_battlefield_finds_content() -> void:
	## Add battlefield finds content with Five Parsecs loot tables
	var label: Label = Label.new()
	label.text = "Search the battlefield for equipment and supplies.\nRoll D6 for each enemy defeated."
	step_content.add_child(label)
	
	var enemies_defeated = battle_results.get("enemy_defeated", 0)
	var finds_container = VBoxContainer.new()
	
	for i in range(enemies_defeated):
		var find_panel = _create_battlefield_find_panel(i + 1)
		finds_container.add_child(find_panel)
	
	step_content.add_child(finds_container)

func _create_battlefield_find_panel(enemy_num: int) -> Control:
	## Create a panel for battlefield finds
	var panel = HBoxContainer.new()
	
	var label = Label.new()
	label.text = "Enemy %d:" % enemy_num
	label.custom_minimum_size.x = 80
	panel.add_child(label)
	
	var roll_button = Button.new()
	roll_button.text = "Search"
	roll_button.pressed.connect(_on_battlefield_find_roll.bind(enemy_num))
	panel.add_child(roll_button)
	
	var result_label = Label.new()
	result_label.name = "find_result_" + str(enemy_num)
	result_label.text = "Not searched"
	panel.add_child(result_label)
	
	return panel

func _add_invasion_check_content() -> void:
	## Add invasion check content
	var label: Label = Label.new()
	label.text = "Roll D6 to check for invasion threats."
	step_content.add_child(label)

func _add_loot_content() -> void:
	## Add loot content — Core Rules pp.120-121, 131-133
	## Step 5: Battlefield Finds (if Held Field) — D100 roll
	## Step 7: Gather the Loot — D100 roll on Main Loot Table
	var label: Label = Label.new()
	label.text = "Roll on the Loot Table (Core Rules p.131) for items earned."
	step_content.add_child(label)

	var loot_button: Button = Button.new()
	loot_button.text = "Roll on Loot Tables"
	loot_button.pressed.connect(_on_generate_loot_pressed)
	step_content.add_child(loot_button)

	var loot_results_container: VBoxContainer = VBoxContainer.new()
	loot_results_container.name = "LootResultsContainer"
	step_content.add_child(loot_results_container)

func _add_injury_content() -> void:
	## Add injury content with Five Parsecs injury tables
	var label: Label = Label.new()
	label.text = "Determine injuries for crew members and recovery time."
	step_content.add_child(label)
	
	var casualties = battle_results.get("crew_casualties", 0)
	var injuries = battle_results.get("crew_injuries", 0)
	
	if casualties > 0 or injuries > 0:
		var injury_container = VBoxContainer.new()
		
		# Handle casualties
		for i in range(casualties):
			var casualty_panel = _create_injury_panel("Casualty", i + 1, true)
			injury_container.add_child(casualty_panel)
		
		# Handle injuries
		for i in range(injuries):
			var injury_panel = _create_injury_panel("Injury", i + 1, false)
			injury_container.add_child(injury_panel)
		
		step_content.add_child(injury_container)
	else:
		var no_injuries_label = Label.new()
		no_injuries_label.text = "No crew injuries to resolve!"
		no_injuries_label.modulate = UIColors.COLOR_EMERALD
		step_content.add_child(no_injuries_label)

func _create_injury_panel(type: String, num: int, is_casualty: bool) -> Control:
	## Create a panel for injury resolution
	var panel = HBoxContainer.new()

	var label = Label.new()
	label.text = "%s %d:" % [type, num]
	label.custom_minimum_size.x = 100
	panel.add_child(label)

	var roll_button = Button.new()
	# Check if narrative_injuries house rule is enabled
	if _is_narrative_injuries_mode():
		roll_button.text = "Choose Injury" if not is_casualty else "Choose Severity"
		roll_button.tooltip_text = "Narrative Injuries: You decide the outcome!"
	else:
		roll_button.text = "Roll Injury" if not is_casualty else "Roll Severity"
	roll_button.pressed.connect(_on_injury_roll.bind(type, num, is_casualty))
	panel.add_child(roll_button)

	var result_label = Label.new()
	result_label.name = "injury_result_%s_%d" % [type.to_lower(), num]
	result_label.text = "Not rolled" if not _is_narrative_injuries_mode() else "Not selected"
	panel.add_child(result_label)

	return panel

func _add_experience_content() -> void:
	## Add experience content with Five Parsecs advancement
	##
	## Per Core Rules p.98: Bots don't gain XP - they purchase upgrades with credits instead.
	var label: Label = Label.new()
	label.text = "Crew members gain experience from battle. Roll for advancement!"
	step_content.add_child(label)

	# Get crew from campaign
	var gsm_crew = get_node_or_null("/root/GameStateManager")
	if gsm_crew and gsm_crew.has_method("get_crew_members"):
		var crew = gsm_crew.get_crew_members()

		# Separate bots from regular crew
		var regular_crew_container = VBoxContainer.new()
		var bot_crew_container = VBoxContainer.new()
		var has_bots: bool = false
		var has_regular_crew: bool = false

		for crew_member in crew:
			# Skip if crew member was a casualty
			if not _was_crew_casualty(crew_member):
				if _is_crew_member_bot(crew_member):
					# Bot: Show upgrade panel instead of XP roll
					var bot_panel = _create_bot_upgrade_panel(crew_member)
					bot_crew_container.add_child(bot_panel)
					has_bots = true
				else:
					# Regular crew: XP advancement roll
					var exp_panel = _create_experience_panel(crew_member)
					regular_crew_container.add_child(exp_panel)
					has_regular_crew = true

		# Add regular crew section
		if has_regular_crew:
			step_content.add_child(regular_crew_container)

		# Add bot section with header if there are bots
		if has_bots:
			var bot_header = Label.new()
			bot_header.text = "\n🤖 Bot Upgrades (Credits-Based)"
			bot_header.modulate = Color("#4FC3F7")  # Cyan accent
			step_content.add_child(bot_header)

			var bot_info = Label.new()
			bot_info.text = "Bots don't gain XP - purchase upgrades with credits instead."
			bot_info.modulate = Color("#808080")  # Dimmed
			bot_info.add_theme_font_size_override("font_size", 12)
			step_content.add_child(bot_info)

			step_content.add_child(bot_crew_container)

	var story_points = battle_results.get("story_points_earned", 1)
	var story_label = Label.new()
	story_label.text = "Story Points earned this battle: %d" % story_points
	story_label.modulate = UIColors.COLOR_CYAN
	step_content.add_child(story_label)

func _create_experience_panel(crew_member: Dictionary) -> Control:
	## Create experience gain panel for crew member
	var panel = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = crew_member.get("name", "Unknown")
	name_label.custom_minimum_size.x = 120
	panel.add_child(name_label)
	
	var roll_button = Button.new()
	roll_button.text = "Roll Advancement"
	roll_button.pressed.connect(_on_experience_roll.bind(crew_member))
	panel.add_child(roll_button)
	
	var result_label = Label.new()
	result_label.name = "exp_result_" + str(crew_member.get("id", 0))
	result_label.text = "Not rolled"
	panel.add_child(result_label)
	
	return panel


func _is_crew_member_bot(crew_member: Dictionary) -> bool:
	## Check if crew member is a bot (Five Parsecs p.98)
	# Check is_bot field from serialized character
	if crew_member.get("is_bot", false):
		return true

	# Fallback: check origin field
	var origin = str(crew_member.get("origin", ""))
	return origin == "BOT" or origin == "Bot"


func _create_bot_upgrade_panel(crew_member: Dictionary) -> Control:
	## Create bot upgrade panel showing available credit-based upgrades
	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)

	# Bot name header
	var header = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "🤖 %s" % crew_member.get("name", "Unknown Bot")
	name_label.custom_minimum_size.x = 150
	header.add_child(name_label)

	# Current credits display
	var game_state = get_node_or_null("/root/GameStateManager")
	var current_credits: int = 0
	if game_state and game_state.has_method("get_credits"):
		current_credits = game_state.get_credits()

	var credits_label = Label.new()
	credits_label.text = "Credits: %d" % current_credits
	credits_label.modulate = Color("#10B981")  # Green
	header.add_child(credits_label)
	panel.add_child(header)

	# Get available upgrades for this bot
	if _advancement_system:
		var installed_upgrades: Array = crew_member.get("bot_upgrades", [])
		var available_upgrades = _advancement_system.get_available_bot_upgrades(null)

		# Create upgrade options
		var upgrade_container = HBoxContainer.new()
		upgrade_container.add_theme_constant_override("separation", 12)

		for upgrade_data in available_upgrades:
			var upgrade_id: String = upgrade_data.get("id", "")

			# Skip if already installed
			if upgrade_id in installed_upgrades:
				continue

			var upgrade_button = Button.new()
			var cost: int = upgrade_data.get("cost", 0)
			var can_afford: bool = current_credits >= cost

			upgrade_button.text = "%s (%d cr)" % [upgrade_data.get("name", upgrade_id), cost]
			upgrade_button.tooltip_text = upgrade_data.get("description", "")
			upgrade_button.custom_minimum_size = Vector2(0, 40)
			upgrade_button.disabled = not can_afford

			if can_afford:
				upgrade_button.pressed.connect(_on_bot_upgrade_selected.bind(crew_member, upgrade_id, upgrade_button))
			else:
				upgrade_button.modulate = Color("#808080")  # Dimmed if can't afford

			upgrade_container.add_child(upgrade_button)

		# Check if all upgrades are installed
		if upgrade_container.get_child_count() == 0:
			var all_done_label = Label.new()
			all_done_label.text = "All upgrades installed!"
			all_done_label.modulate = Color("#10B981")
			upgrade_container.add_child(all_done_label)

		panel.add_child(upgrade_container)

		# Show installed upgrades count
		var installed_label = Label.new()
		installed_label.text = "Installed: %d upgrades" % installed_upgrades.size()
		installed_label.modulate = Color("#808080")
		installed_label.add_theme_font_size_override("font_size", 11)
		panel.add_child(installed_label)

	return panel


func _on_bot_upgrade_selected(crew_member: Dictionary, upgrade_id: String, button: Button) -> void:
	## Handle bot upgrade purchase
	# Get game state for credit deduction
	var game_state = get_node_or_null("/root/GameStateManager")
	if not game_state:
		push_error("PostBattleSequence: Cannot find GameStateManager for bot upgrade")
		return

	# Get the actual character Resource from campaign
	var gs = get_node_or_null("/root/GameState")
	var bot_resource: Resource = null
	if gs and gs.has_method("get_current_campaign"):
		var campaign = gs.get_current_campaign()
		if campaign and campaign.has_method("get_crew_member_by_id"):
			bot_resource = campaign.get_crew_member_by_id(str(crew_member.get("id", -1)))

	if not bot_resource:
		push_error("PostBattleSequence: Could not find bot Resource for upgrade")
		return

	# Install the upgrade via AdvancementSystem
	if _advancement_system:
		var success = _advancement_system.install_bot_upgrade(bot_resource, upgrade_id, game_state)
		if success:
			# Update button to show installed
			button.text = "✅ Installed!"
			button.disabled = true
			button.modulate = Color("#10B981")

			# Record in step results
			if step_results.size() > current_step:
				var current_results = step_results[current_step]
				if not current_results.has("bot_upgrades"):
					current_results["bot_upgrades"] = []
				current_results["bot_upgrades"].append({
					"bot_name": crew_member.get("name", "Unknown"),
					"upgrade_id": upgrade_id
				})

		else:
			# Show error feedback
			button.text = "❌ Failed"
			button.modulate = Color("#DC2626")


func _add_training_content() -> void:
	## Add training content with TrainingSelectionDialog integration
	if not step_content:
		return

	# Clear existing content
	for child in step_content.get_children():
		child.queue_free()

	# Instantiate training dialog
	var dialog = TrainingDialog.instantiate()
	if dialog:
		# Add to tree FIRST so @onready vars resolve
		step_content.add_child(dialog)

		# Connect signals before setup to catch any immediate emissions
		if dialog.has_signal("training_completed"):
			dialog.training_completed.connect(_on_training_completed)
		if dialog.has_signal("dialog_closed"):
			dialog.dialog_closed.connect(_on_training_closed)

		# Setup AFTER add_child so @onready node refs are valid
		var crew = _get_current_crew()
		var credits = _get_current_credits()
		if dialog.has_method("setup"):
			dialog.setup(crew, credits)

func _add_purchase_content() -> void:
	## Add purchase content using PurchaseItemsComponent (Core Rules p.123)
	if not step_content:
		return

	# Clear existing content
	for child in step_content.get_children():
		child.queue_free()

	# Instantiate purchase items component
	var purchase_component = PurchaseItemsComponent.instantiate()
	if purchase_component:
		# Get current credits and stash from campaign
		var credits = _get_current_credits()
		var stash = _get_ship_stash()

		# Initialize component with campaign data
		if purchase_component.has_method("initialize_purchase_phase"):
			purchase_component.initialize_purchase_phase(credits, stash)

		step_content.add_child(purchase_component)
	else:
		# Fallback to simple label if component fails to load
		var label: Label = Label.new()
		label.text = "Purchase new equipment and supplies.\n(Component failed to load)"
		step_content.add_child(label)
		push_warning("PostBattleSequence: Failed to instantiate PurchaseItemsComponent")

func _get_ship_stash() -> Array:
	## Get ship stash items from EquipmentManager
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager and equipment_manager.has_method("get_ship_stash"):
		return equipment_manager.get_ship_stash()
	return []

func _add_campaign_events_content() -> void:
	## Add campaign events content with Five Parsecs event tables
	var label: Label = Label.new()
	label.text = "Roll D100 on campaign events table for random encounters and opportunities."
	step_content.add_child(label)
	
	var roll_panel = HBoxContainer.new()
	
	var roll_button = Button.new()
	roll_button.text = "Roll Campaign Event"
	roll_button.pressed.connect(_on_campaign_event_roll)
	roll_panel.add_child(roll_button)
	
	var result_label = Label.new()
	result_label.name = "campaign_event_result"
	result_label.text = "Not rolled"
	roll_panel.add_child(result_label)
	
	step_content.add_child(roll_panel)

func _on_campaign_event_roll() -> void:
	## Handle campaign event roll
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_d100("Campaign Event")
	else:
		roll = randi_range(1, 100)
	
	var event_result = _interpret_campaign_event(roll)
	var result_text = "Rolled %d - %s" % [roll, event_result]
	
	# Update UI
	var result_label = step_content.find_child("campaign_event_result")
	if result_label:
		result_label.text = result_text
		result_label.modulate = _get_event_color(roll)
	
	_add_result_to_log("Campaign Event: %s" % result_text)

func _get_event_color(roll: int) -> Color:
	## Get color for event based on roll
	if roll >= 90:
		return UIColors.COLOR_CYAN # Major positive
	elif roll >= 70:
		return UIColors.COLOR_EMERALD # Minor positive
	elif roll >= 30:
		return Color.WHITE # Neutral
	elif roll >= 10:
		return UIColors.COLOR_AMBER # Minor negative
	else:
		return UIColors.COLOR_RED # Major negative

func _add_character_events_content() -> void:
	## Add character events content with individual crew rolls
	var label: Label = Label.new()
	label.text = "Roll D100 on character events table for each crew member."
	step_content.add_child(label)
	
	# Get crew from campaign
	var gsm_char = get_node_or_null("/root/GameStateManager")
	if gsm_char and gsm_char.has_method("get_crew_members"):
		var crew = gsm_char.get_crew_members()
		var char_events_container = VBoxContainer.new()
		
		for crew_member in crew:
			if not _was_crew_casualty(crew_member):
				var char_panel = _create_character_event_panel(crew_member)
				char_events_container.add_child(char_panel)
		
		step_content.add_child(char_events_container)

func _create_character_event_panel(crew_member: Dictionary) -> Control:
	## Create character event panel for crew member
	var panel = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = crew_member.get("name", "Unknown")
	name_label.custom_minimum_size.x = 120
	panel.add_child(name_label)
	
	var roll_button = Button.new()
	roll_button.text = "Roll Event"
	roll_button.pressed.connect(_on_character_event_roll.bind(crew_member))
	panel.add_child(roll_button)
	
	var result_label = Label.new()
	result_label.name = "char_event_" + str(crew_member.get("id", 0))
	result_label.text = "Not rolled"
	panel.add_child(result_label)
	
	return panel

func _on_character_event_roll(crew_member: Dictionary) -> void:
	## Handle character event roll
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_d100("Character Event: " + crew_member.get("name", "Unknown"))
	else:
		roll = randi_range(1, 100)
	
	var event_result = _interpret_character_event(roll)
	var result_text = "Rolled %d - %s" % [roll, event_result]
	
	# Update UI
	var result_label = step_content.find_child("char_event_" + str(crew_member.get("id", 0)))
	if result_label:
		result_label.text = result_text
		result_label.modulate = _get_event_color(roll)
	
	_add_result_to_log("%s Character Event: %s" % [crew_member.get("name", "Crew"), result_text])

func _add_galactic_war_content() -> void:
	## Add galactic war content using GalacticWarPanel
	if not step_content:
		return

	# Clear existing content
	for child in step_content.get_children():
		child.queue_free()

	# Instantiate war panel
	var panel = WarPanel.instantiate()
	if panel:
		# Add to tree FIRST so @onready vars resolve
		step_content.add_child(panel)

		# Connect signals before setup
		if panel.has_signal("war_panel_closed"):
			panel.war_panel_closed.connect(_on_war_panel_closed)

		# Setup AFTER add_child so @onready node refs are valid
		if panel.has_method("setup"):
			var war_events = _get_war_events()
			panel.setup(war_events)

func _get_current_turn() -> int:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.current_campaign and "progress_data" in gs.current_campaign:
		return gs.current_campaign.progress_data.get("turns_played", 0)
	return 0

func _add_result_to_log(result: String) -> void:
	## Add a result to the results log
	var result_label: Label = Label.new()
	result_label.text = "Step " + str(current_step + 1) + ": " + result
	results_container.add_child(result_label)

func _on_previous_pressed() -> void:
	## Handle previous button press
	if current_step > 0:
		current_step -= 1
		_show_current_step()

func _on_next_pressed() -> void:
	## Handle next button press
	# Store current step result
	var result: Variant = _get_current_step_result()
	# Sprint 26.9 ERR-1: Bounds check before array access
	if current_step >= 0 and current_step < step_results.size():
		step_results[current_step] = result
		step_completed.emit(current_step, result)
	else:
		push_warning("PostBattleSequence: current_step %d out of bounds (size: %d)" % [current_step, step_results.size()])

	# Move to next step
	current_step += 1
	_show_current_step()

func _on_roll_pressed() -> void:
	## Handle roll dice button press with proper dice system integration
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll_result = 0
	
	# Determine dice type based on step
	var dice_type = "D6"
	match current_step:
		11, 12: # Campaign and Character Events
			dice_type = "D100"
	
	if dice_manager:
		roll_result = dice_manager.roll_d100("Post-Battle Step %d" % (current_step + 1)) if dice_type == "D100" else dice_manager.roll_d6("Post-Battle Step %d" % (current_step + 1))
	else:
		roll_result = randi_range(1, 6) if dice_type == "D6" else randi_range(1, 100)
	
	var result_text: String = "Rolled %s: %d" % [dice_type, roll_result]

	# Add step-specific roll interpretation using Five Parsecs tables
	match current_step:
		0: # Rival Status
			result_text += " - " + ("Rival follows" if roll_result <= 3 else "Rival stays behind")
		4: # Battlefield Finds
			result_text += " - " + _interpret_battlefield_find(roll_result)
		5: # Invasion Check
			result_text += " - " + ("Invasion threat!" if roll_result == 1 else "No invasion")
		6: # Loot
			result_text += " - " + _interpret_loot_roll(roll_result)
		11: # Campaign Events
			result_text += " - " + _interpret_campaign_event(roll_result)
		12: # Character Events
			result_text += " - " + _interpret_character_event(roll_result)

	_add_result_to_log(result_text)

func _on_finish_pressed() -> void:
	## Handle finish button press
	_finish_post_battle()

func _get_current_step_result() -> Dictionary:
	## Get the result data for the current step
	return {
		"step_index": current_step,
		"step_name": post_battle_steps[current_step].name,
		"completed": true,
		"timestamp": Time.get_unix_time_from_system()
	}

func _finish_post_battle() -> void:
	## Complete the post-battle sequence
	var final_results = {
		"battle_results": battle_results,
		"step_results": step_results,
		"completion_time": Time.get_unix_time_from_system()
	}

	post_battle_completed.emit(final_results)

	# Phase advancement is handled by CampaignTurnController via post_battle_completed signal.
	# Do NOT call complete_current_phase() here — it would cause double phase advance.

	# Navigate to Campaign Dashboard to show new turn
	# Sprint 26.9 ERR-10: Guard await with tree check to prevent crash if freed
	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout  # Brief delay for user to see completion
	if not is_inside_tree():
		return  # Node was freed during await, abort navigation
	SceneRouter.navigate_to("campaign_turn_controller")

func _on_back_pressed() -> void:
	## Handle back button press - return to Campaign Dashboard
	SceneRouter.navigate_to("campaign_turn_controller")

## Setup post-battle phase icons for enhanced visual navigation
func _setup_postbattle_icons() -> void:
	## Setup icons for post-battle phase buttons to improve visual clarity
	# Phase 2: Post-Battle Phase Icons Integration
	
	# Next Button (primary post-battle action)
	if next_button:
		next_button.expand_icon = true
		next_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Finish Button (completion action)
	if finish_button:
		finish_button.expand_icon = true
		finish_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _style_step_content_panel() -> void:
	## Apply Deep Space card styling to the step content panel
	# The step_content VBoxContainer is inside a PanelContainer ("CurrentStep")
	var panel_container: PanelContainer = step_content.get_parent().get_parent() as PanelContainer
	if not panel_container:
		return

	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = Color("#252542")  # COLOR_ELEVATED
	stylebox.border_color = Color("#3A3A5C")  # COLOR_BORDER
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.content_margin_left = 16  # SPACING_MD
	stylebox.content_margin_top = 16
	stylebox.content_margin_right = 16
	stylebox.content_margin_bottom = 16
	panel_container.add_theme_stylebox_override("panel", stylebox)

# Enhanced roll interpretation functions using Five Parsecs tables

func _interpret_battlefield_find(roll: int) -> String:
	## Interpret battlefield find roll using Five Parsecs tables
	if roll >= 5:
		return "Found equipment!"
	elif roll >= 3:
		return "Found supplies"
	else:
		return "Nothing useful found"

func _interpret_loot_roll(roll: int) -> String:
	## Interpret loot roll using Five Parsecs loot tables
	if roll == 6:
		return "Rare equipment found!"
	elif roll >= 4:
		return "Standard equipment found"
	elif roll >= 2:
		return "Credits found"
	else:
		return "No loot"

func _interpret_campaign_event(roll: int) -> String:
	## Interpret campaign event roll
	if roll >= 90:
		return "Major positive event!"
	elif roll >= 70:
		return "Minor positive event"
	elif roll >= 30:
		return "No significant event"
	elif roll >= 10:
		return "Minor complication"
	else:
		return "Major complication!"

func _interpret_character_event(roll: int) -> String:
	## Interpret character event roll
	if roll >= 95:
		return "Character gains special ability!"
	elif roll >= 80:
		return "Character makes useful contact"
	elif roll >= 60:
		return "Character gains minor benefit"
	elif roll >= 40:
		return "No event"
	else:
		return "Character faces personal challenge"

# Enhanced signal handlers for specific rolls

func _on_rival_status_roll(rival: Dictionary) -> void:
	## Handle rival status roll
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_d6("Rival Status: " + rival.get("name", "Unknown"))
	else:
		roll = randi_range(1, 6)
	
	var follows = roll <= 3
	var result_text = "Rolled %d - %s" % [roll, "Follows" if follows else "Stays behind"]
	
	# Update UI
	var result_label = step_content.find_child("result_" + str(rival.get("id", 0)))
	if result_label:
		result_label.text = result_text
		result_label.modulate = UIColors.COLOR_EMERALD if follows else UIColors.COLOR_RED
	
	_add_result_to_log("%s: %s" % [rival.get("name", "Rival"), result_text])

func _on_apply_payment(amount: int) -> void:
	## Apply payment to campaign
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("get_credits") and gsm.has_method("set_credits"):
		gsm.set_credits(gsm.get_credits() + amount)
		_add_result_to_log("Applied %d credits to campaign" % amount)

func _on_battlefield_find_roll(enemy_num: int) -> void:
	## Handle battlefield find roll using JSON data table
	# Load battlefield finds table
	var finds_table = DataLoader.get_battlefield_finds_table()
	
	if finds_table.is_empty():
		push_error("PostBattleSequence: Failed to load battlefield_finds.json")
		_add_result_to_log("Enemy %d search: ERROR - Could not load loot table" % enemy_num)
		return
	
	# Roll d6 using DataLoader helper
	var roll = DataLoader.roll_d6()
	
	# Look up result in table
	var result_data = DataLoader.roll_on_table(finds_table, roll)
	
	if result_data.is_empty():
		push_error("PostBattleSequence: No result for battlefield find roll %d" % roll)
		_add_result_to_log("Enemy %d search: ERROR - Invalid roll result" % enemy_num)
		return
	
	# Extract result information
	var outcome = result_data.get("outcome", "unknown")
	var credits = result_data.get("credits", 0)
	var description = result_data.get("description", "Unknown result")
	var narrative = result_data.get("narrative", "")
	var needs_item_roll = result_data.get("item_roll", false)
	var item_table = result_data.get("item_table", "")
	
	# Build result text
	var result_text = "Rolled %d - %s" % [roll, description]
	if credits > 0:
		result_text += " (+%d cr)" % credits
	if needs_item_roll:
		result_text += " [Roll on %s table]" % item_table
	
	# Update UI
	var result_label = step_content.find_child("find_result_" + str(enemy_num))
	if result_label:
		result_label.text = result_text
		# Color based on outcome quality
		if roll >= 5:
			result_label.modulate = UIColors.COLOR_EMERALD  # Valuable/rare
		elif roll >= 3:
			result_label.modulate = UIColors.COLOR_AMBER  # Equipment/weapon
		else:
			result_label.modulate = UIColors.COLOR_TEXT_SECONDARY  # Nothing/minor salvage
	
	# Apply credits to campaign
	if credits > 0:
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.has_method("get_credits") and gsm.has_method("set_credits"):
			gsm.set_credits(gsm.get_credits() + credits)
	
	# Store result for later item table rolls if needed
	if current_step >= 0 and current_step < step_results.size():
		if not step_results[current_step].has("battlefield_finds"):
			step_results[current_step]["battlefield_finds"] = []
		step_results[current_step]["battlefield_finds"].append({
			"enemy_num": enemy_num,
			"roll": roll,
			"outcome": outcome,
			"credits": credits,
			"needs_item_roll": needs_item_roll,
			"item_table": item_table,
			"narrative": narrative
		})
	
	# Log with narrative
	var log_message = "Enemy %d: %s" % [enemy_num, narrative if not narrative.is_empty() else description]
	if credits > 0:
		log_message += " (+%d credits)" % credits
	_add_result_to_log(log_message)
	

func _on_injury_roll(type: String, num: int, is_casualty: bool) -> void:
	## Handle injury severity roll or narrative selection using FPCM_InjuryService
	# HOUSE RULE: narrative_injuries - Player chooses injury instead of rolling
	if _is_narrative_injuries_mode():
		_show_narrative_injury_dialog(type, num, is_casualty)
		return

	# Standard roll-based injury determination
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0

	if dice_manager:
		roll = dice_manager.roll_d100("%s %d Injury" % [type, num])
	else:
		roll = randi_range(1, 100)

	# Use FPCM_InjuryService for proper injury determination
	var injury_data = FPCM_InjuryService.determine_injury(roll)
	_apply_injury_result(type, num, injury_data, roll)

func _show_narrative_injury_dialog(type: String, num: int, _is_casualty: bool) -> void:
	## Show narrative injury selection dialog
	var dialog = NarrativeInjuryDialog.new()
	dialog.setup("Crew Member %s %d" % [type, num])

	# Connect signals
	dialog.injury_selected.connect(_on_narrative_injury_selected.bind(type, num))
	dialog.dialog_closed.connect(_on_narrative_injury_cancelled.bind(type, num))

	# Add as popup in center of screen
	add_child(dialog)
	dialog.anchor_left = 0.5
	dialog.anchor_top = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_bottom = 0.5
	dialog.position = -dialog.size / 2

func _on_narrative_injury_selected(injury_data: Dictionary, type: String, num: int) -> void:
	## Handle narrative injury selection from dialog
	_apply_injury_result(type, num, injury_data, -1)  # -1 indicates narrative selection

func _on_narrative_injury_cancelled(type: String, num: int) -> void:
	## Handle narrative injury dialog cancelled - fall back to rolling
	# Roll instead
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0

	if dice_manager:
		roll = dice_manager.roll_d100("%s %d Injury (cancelled narrative)" % [type, num])
	else:
		roll = randi_range(1, 100)

	var injury_data = FPCM_InjuryService.determine_injury(roll)
	_apply_injury_result(type, num, injury_data, roll)

func _apply_injury_result(type: String, num: int, injury_data: Dictionary, roll: int) -> void:
	## Apply injury result to UI and step results
	var severity = injury_data.get("type_name", "Unknown")
	var recovery_turns = injury_data.get("recovery_turns", 0)
	var is_fatal = injury_data.get("is_fatal", false)
	var is_narrative = injury_data.get("narrative_choice", false)

	var result_text: String
	if is_narrative:
		result_text = "Selected: %s" % severity
	else:
		result_text = "Rolled %d - %s" % [roll, severity]

	if is_fatal:
		result_text += " (FATAL)"
	elif recovery_turns > 0:
		result_text += " (%d turns recovery)" % recovery_turns

	# Store injury data for campaign integration
	if current_step >= 0 and current_step < step_results.size():
		step_results[current_step]["%s_%d" % [type.to_lower(), num]] = injury_data

	# Update UI
	var result_label = step_content.find_child("injury_result_%s_%d" % [type.to_lower(), num])
	if result_label:
		result_label.text = result_text
		result_label.modulate = _get_injury_color(severity)

	_add_result_to_log("%s %d: %s" % [type, num, result_text])

func _on_generate_loot_pressed() -> void:
	## Core Rules pp.120-121, 131-133:
	## Step 5: Battlefield Finds — if Held the Field, roll D100 once
	## Step 7: Gather the Loot — roll D100 once on Main Loot Table
	##   (3 rolls if final Quest stage; 0 if Invasion Battle)
	var loot_results_container = step_content.find_child("LootResultsContainer")
	if not loot_results_container:
		return

	for child in loot_results_container.get_children():
		child.queue_free()

	var total_loot: Array = []
	var held_field: bool = battle_results.get("held_field", false)
	var is_invasion: bool = battle_results.get("is_invasion", false)
	var is_final_quest: bool = battle_results.get("final_quest_stage", false)

	# Step 5: Battlefield Finds (Core Rules p.121)
	if held_field and not is_invasion:
		var bf_roll: int = randi_range(1, 100)
		var bf_result: Dictionary = _resolve_battlefield_find(bf_roll)
		var bf_label: Label = Label.new()
		bf_label.text = "Battlefield Finds (D100: %d): %s" % [bf_roll, bf_result.get("description", "Nothing")]
		loot_results_container.add_child(bf_label)
		total_loot.append(bf_result)

	# Step 7: Gather the Loot (Core Rules p.121, pp.131-133)
	if not is_invasion:
		var loot_rolls: int = 1
		if is_final_quest:
			loot_rolls = 3  # Core Rules p.121: "roll three times and claim all"
		for i in range(loot_rolls):
			var loot_roll: int = randi_range(1, 100)
			var loot_result: Dictionary = _resolve_main_loot(loot_roll)
			var loot_label: Label = Label.new()
			loot_label.text = "Loot roll %d (D100: %d): %s" % [
				i + 1, loot_roll, loot_result.get("description", "Nothing")]
			loot_results_container.add_child(loot_label)
			total_loot.append(loot_result)
	else:
		var no_loot: Label = Label.new()
		no_loot.text = "Invasion Battle — no loot or battlefield finds (Core Rules p.121)"
		loot_results_container.add_child(no_loot)

	# Persist loot to campaign inventory
	_add_loot_to_inventory(total_loot)

	if current_step >= 0 and current_step < step_results.size():
		step_results[current_step]["loot_found"] = total_loot

	_add_result_to_log("Loot: %d items found" % total_loot.size())


## ==========================================
## LOOT TABLE RESOLUTION (Core Rules pp.121, 131-133)
## ==========================================

## Resolve a D100 roll on the Battlefield Finds table (Core Rules p.121)
## Returns a dict with the resolved item/effect ready for persistence.
func _resolve_battlefield_find(roll: int) -> Dictionary:
	var bf_data: Array = LootSystemConstants.get_battlefield_finds_data()
	for entry in bf_data:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			var cat: String = entry.get("category", "NOTHING")
			var result: Dictionary = {
				"source": "battlefield_finds",
				"roll": roll,
				"category": cat,
				"description": entry.get("description", "Nothing"),
			}
			match cat:
				"WEAPON":
					# Core Rules p.121: "Randomly select a slain enemy. Keep their weapons."
					var item_name: String = _roll_on_subtable(
						LootSystemConstants.get_weapon_subtable_data())
					result["item_name"] = item_name
					result["description"] = "Weapon: %s" % item_name
				"CONSUMABLE":
					var item_name: String = _roll_on_subtable(
						LootSystemConstants.get_odds_and_ends_data())
					result["item_name"] = item_name
					result["description"] = "Consumable: %s" % item_name
				"QUEST_RUMOR":
					result["quest_rumor"] = true
					result["description"] = "Quest Rumor gained"
				"SHIP_PART":
					result["credits"] = 2
					result["description"] = "Starship part (worth 2 credits for components)"
				"TRINKET":
					result["description"] = "Personal trinket (future loot roll on 9+ per planet)"
				"DEBRIS":
					var debris_credits: int = randi_range(1, 3)
					result["credits"] = debris_credits
					result["description"] = "Debris: %d credits" % debris_credits
				"VITAL_INFO":
					result["patron_opportunity"] = true
					result["description"] = "Vital info (free Corporate Patron on this world)"
				"NOTHING":
					result["description"] = "Nothing of value"
			return result
	return {"source": "battlefield_finds", "roll": roll, "category": "NOTHING",
		"description": "Nothing of value"}

## Resolve a D100 roll on the Main Loot Table (Core Rules pp.131-133)
## Rolls the main table, then the appropriate subtable to get the specific item.
func _resolve_main_loot(roll: int) -> Dictionary:
	var main_data: Array = LootSystemConstants.get_main_loot_data()
	for entry in main_data:
		var r: Array = entry.get("roll_range", [0, 0])
		if roll >= r[0] and roll <= r[1]:
			var cat: String = entry.get("category", "NOTHING")
			var needs_repair: bool = entry.get("requires_repair", false)
			var count: int = entry.get("count", 1)
			var result: Dictionary = {
				"source": "main_loot",
				"roll": roll,
				"category": cat,
				"needs_repair": needs_repair,
			}
			match cat:
				"WEAPON", "DAMAGED_WEAPONS":
					var items: Array = []
					for _i in range(count):
						var name: String = _roll_on_subtable(
							LootSystemConstants.get_weapon_subtable_data())
						items.append(name)
					result["items"] = items
					var suffix: String = " (damaged)" if needs_repair else ""
					result["description"] = "Weapon: %s%s" % [", ".join(items), suffix]
				"GEAR", "DAMAGED_GEAR":
					var items: Array = []
					for _i in range(count):
						var name: String = _roll_on_subtable(
							LootSystemConstants.get_gear_subtable_data())
						items.append(name)
					result["items"] = items
					var suffix: String = " (damaged)" if needs_repair else ""
					result["description"] = "Gear: %s%s" % [", ".join(items), suffix]
				"ODDS_AND_ENDS":
					var item_name: String = _roll_on_subtable(
						LootSystemConstants.get_odds_and_ends_data())
					result["items"] = [item_name]
					result["description"] = "Odds & Ends: %s" % item_name
				"REWARDS":
					result = _resolve_rewards_subtable(result)
			return result
	return {"source": "main_loot", "roll": roll, "category": "NOTHING",
		"description": "Nothing of value"}

## Roll on a subtable that has roll_range + items arrays.
## Picks a random item from the matched range's items list.
func _roll_on_subtable(subtable_data: Array) -> String:
	var sub_roll: int = randi_range(1, 100)
	for entry in subtable_data:
		var r: Array = entry.get("roll_range", [0, 0])
		if sub_roll >= r[0] and sub_roll <= r[1]:
			var items: Array = entry.get("items", [])
			if items.is_empty():
				return entry.get("item", "Unknown item")
			return items[randi() % items.size()]
	return "Unknown item"

## Resolve the Rewards subtable (Core Rules p.133) — credits, rumors, story points
func _resolve_rewards_subtable(result: Dictionary) -> Dictionary:
	var rewards_data: Array = LootSystemConstants.get_rewards_subtable_data()
	var sub_roll: int = randi_range(1, 100)
	for entry in rewards_data:
		var r: Array = entry.get("roll_range", [0, 0])
		if sub_roll >= r[0] and sub_roll <= r[1]:
			var item_name: String = entry.get("item", "Reward")
			result["reward_name"] = item_name
			if entry.has("rumors"):
				result["quest_rumors"] = entry["rumors"]
				result["description"] = "%s: +%d Quest Rumor(s)" % [item_name, entry["rumors"]]
			elif entry.has("credits"):
				result["credits"] = entry["credits"]
				result["description"] = "%s: +%d credits" % [item_name, entry["credits"]]
			elif entry.has("credits_dice"):
				var dice_str: String = entry["credits_dice"]
				var credits: int = _roll_credits_dice(dice_str)
				result["credits"] = credits
				result["description"] = "%s: +%d credits (%s)" % [item_name, credits, dice_str]
			elif entry.has("discount_dice"):
				var dice_str: String = entry["discount_dice"]
				var discount: int = _roll_credits_dice(dice_str)
				result["ship_discount"] = discount
				result["description"] = "%s: %d credits ship component discount" % [
					item_name, discount]
			elif entry.has("story_points"):
				result["story_points"] = entry["story_points"]
				result["description"] = "%s: +%d story point(s)" % [
					item_name, entry["story_points"]]
			return result
	result["description"] = "Nothing notable"
	return result

## Roll dice strings like "1d6", "1d6+2", "2d6_pick_highest", "1d3"
func _roll_credits_dice(dice_str: String) -> int:
	match dice_str:
		"1d6":
			return randi_range(1, 6)
		"1d3":
			return randi_range(1, 3)
		"1d6+2":
			return randi_range(1, 6) + 2
		"2d6_pick_highest":
			return maxi(randi_range(1, 6), randi_range(1, 6))
		_:
			return randi_range(1, 6)


## ==========================================
## LOOT PERSISTENCE — add resolved items to campaign inventory
## ==========================================

func _add_loot_to_inventory(loot_items: Array) -> void:
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	var game_state_ref = get_node_or_null("/root/GameState")
	var credits_gained: int = 0
	var items_added: int = 0
	var rumors_gained: int = 0
	var story_points_gained: int = 0

	for loot: Dictionary in loot_items:
		# Credits
		if loot.has("credits"):
			credits_gained += int(loot["credits"])

		# Quest Rumors
		if loot.get("quest_rumor", false):
			rumors_gained += 1
		if loot.has("quest_rumors"):
			rumors_gained += int(loot["quest_rumors"])

		# Story Points
		if loot.has("story_points"):
			story_points_gained += int(loot["story_points"])

		# Equipment items — add to ship stash
		var item_names: Array = loot.get("items", [])
		var needs_repair: bool = loot.get("needs_repair", false)
		for item_name in item_names:
			if equipment_manager:
				var eq_data: Dictionary = {
					"id": "loot_%d_%d" % [Time.get_ticks_msec(), randi() % 10000],
					"name": str(item_name),
					"category": loot.get("category", "GEAR"),
					"description": "Found as battle loot",
					"needs_repair": needs_repair,
					"location": "ship_stash",
					"value": 1,  # Core Rules p.125: sell value = 1 credit
				}
				if equipment_manager.add_equipment(eq_data):
					items_added += 1

	# Apply credits to campaign
	if credits_gained > 0 and game_state_ref:
		if game_state_ref.has_method("add_credits"):
			game_state_ref.add_credits(credits_gained)
		elif game_state_ref.campaign and "credits" in game_state_ref.campaign:
			game_state_ref.campaign.credits += credits_gained

	# Apply quest rumors
	if rumors_gained > 0 and game_state_ref:
		if game_state_ref.has_method("add_quest_rumors"):
			game_state_ref.add_quest_rumors(rumors_gained)

	# Apply story points
	if story_points_gained > 0 and game_state_ref:
		if game_state_ref.has_method("add_story_points"):
			game_state_ref.add_story_points(story_points_gained)

	# Log summary
	var parts: Array[String] = []
	if credits_gained > 0:
		parts.append("+%d credits" % credits_gained)
	if items_added > 0:
		parts.append("+%d items to stash" % items_added)
	if rumors_gained > 0:
		parts.append("+%d quest rumor(s)" % rumors_gained)
	if story_points_gained > 0:
		parts.append("+%d story point(s)" % story_points_gained)
	if not parts.is_empty():
		_add_result_to_log("Added to campaign: %s" % ", ".join(parts))

func _on_experience_roll(crew_member: Dictionary) -> void:
	## Handle experience advancement roll
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_d6("Advancement: " + crew_member.get("name", "Unknown"))
	else:
		roll = randi_range(1, 6)
	
	var advancement = _interpret_advancement_roll(roll)
	var result_text = "Rolled %d - %s" % [roll, advancement]
	
	# Update UI
	var result_label = step_content.find_child("exp_result_" + str(crew_member.get("id", 0)))
	if result_label:
		result_label.text = result_text
		result_label.modulate = UIColors.COLOR_EMERALD if roll >= 4 else UIColors.COLOR_TEXT_SECONDARY
	
	_add_result_to_log("%s: %s" % [crew_member.get("name", "Crew"), result_text])

func _interpret_injury_roll(roll: int, is_casualty: bool) -> String:
	## Interpret injury roll using Five Parsecs injury table
	if is_casualty:
		if roll >= 80:
			return "Light injury - 1 turn recovery"
		elif roll >= 50:
			return "Serious injury - 2 turns recovery"
		elif roll >= 20:
			return "Severe injury - 3 turns recovery"
		else:
			return "Critical injury - permanent effect"
	else:
		if roll >= 70:
			return "Minor wound - no effect"
		elif roll >= 40:
			return "Light injury - 1 turn recovery"
		else:
			return "Serious injury - 2 turns recovery"

func _interpret_advancement_roll(roll: int) -> String:
	## Interpret advancement roll
	if roll == 6:
		return "Major advancement - gain 2 skill points!"
	elif roll >= 4:
		return "Advancement - gain 1 skill point"
	else:
		return "No advancement this time"

func _get_injury_color(severity: String) -> Color:
	## Get color for injury severity
	if "Critical" in severity or "permanent" in severity:
		return UIColors.COLOR_RED
	elif "Severe" in severity or "Serious" in severity:
		return UIColors.COLOR_AMBER
	elif "Light" in severity or "Minor" in severity:
		return UIColors.COLOR_AMBER
	else:
		return UIColors.COLOR_EMERALD

func _was_crew_casualty(crew_member: Dictionary) -> bool:
	## Check if crew member was a casualty in battle
	# Get crew member ID
	var crew_id = str(crew_member.get("id", ""))
	if crew_id == "" or crew_id == "0":
		crew_id = str(crew_member.get("character_id", ""))
	if crew_id == "":
		return false

	# Check casualties array from battle results
	# BattleResults structure: casualties = [{crew_id, type, round, cause}]
	if battle_results and battle_results.has("casualties"):
		var casualties_array = battle_results.get("casualties", [])
		for casualty in casualties_array:
			if casualty is Dictionary:
				var casualty_id = str(casualty.get("crew_id", ""))
				if casualty_id == str(crew_id):
					# Check if it's a fatal casualty type
					var casualty_type = casualty.get("type", "")
					if casualty_type in ["killed", "critically_wounded", "missing", "fatal"]:
						return true

	# Also check legacy format: injuries_sustained with is_fatal flag
	if battle_results and battle_results.has("injuries_sustained"):
		for injury in battle_results.get("injuries_sustained", []):
			if injury is Dictionary:
				var injury_crew_id = str(injury.get("crew_id", ""))
				if injury_crew_id == str(crew_id) and injury.get("is_fatal", false):
					return true

	return false

func _get_war_events() -> Array:
	## Return war events from battle results or state manager
	if battle_results and battle_results.has("war_events"):
		return battle_results.get("war_events", [])
	return []

func _on_war_panel_closed() -> void:
	## Handle war panel closed signal
	_advance_to_next_step()

func _advance_to_next_step() -> void:
	## Advance to next step (used by war panel and other components)
	_on_next_pressed()

func _get_current_crew() -> Array[Resource]:
	## Get current crew members as Resource array for training dialog
	var crew_array: Array[Resource] = []
	var gsm_get_crew = get_node_or_null("/root/GameStateManager")

	if gsm_get_crew and gsm_get_crew.has_method("get_crew_members"):
		var crew = gsm_get_crew.get_crew_members()
		# Convert to Resource array if needed
		for crew_member in crew:
			if crew_member is Resource:
				crew_array.append(crew_member)

	return crew_array

func _get_current_credits() -> int:
	## Get current campaign credits from GameStateManager
	var game_state = get_node_or_null("/root/GameStateManager")
	if game_state and game_state.has_method("get_credits"):
		return game_state.get_credits()
	return 0

func _on_training_completed(character: Resource, training_type: String) -> void:
	## Handle training completion from TrainingSelectionDialog
	# Store training result
	if current_step >= 0 and current_step < step_results.size():
		if not step_results[current_step].has("training_completed"):
			step_results[current_step]["training_completed"] = []
		step_results[current_step]["training_completed"].append({
			"character": character,
			"training_type": training_type,
			"timestamp": Time.get_unix_time_from_system()
		})

	# Add to results log
	var char_name = character.get("character_name") if character else "Unknown"
	_add_result_to_log("%s completed %s training" % [char_name, training_type])

func _on_training_closed() -> void:
	## Handle training dialog closed signal
	# Note: Do NOT auto-advance - user may want to train multiple characters
	# They will manually click Next when done
	pass

## BP-6: Show error dialog instead of silent failure
func _show_error_dialog(title: String, message: String) -> void:
	## Display a user-visible error dialog for critical failures
	# Try to use the project's ConfirmationDialog component
	var dialog_scene = load("res://src/ui/components/common/ConfirmationDialog.tscn")
	if dialog_scene:
		var dialog = dialog_scene.instantiate()
		add_child(dialog)
		if dialog.has_method("show_error"):
			dialog.show_error(title, message)
		elif dialog.has_method("popup_centered"):
			# Fallback to basic popup
			dialog.title = title
			if dialog.has_node("Label"):
				dialog.get_node("Label").text = message
			dialog.popup_centered()
		return

	# Fallback: Use built-in AcceptDialog
	var fallback_dialog := AcceptDialog.new()
	fallback_dialog.title = title
	fallback_dialog.dialog_text = message
	fallback_dialog.ok_button_text = "OK"
	add_child(fallback_dialog)
	fallback_dialog.popup_centered()
	# Clean up when closed
	fallback_dialog.confirmed.connect(fallback_dialog.queue_free)
	fallback_dialog.canceled.connect(fallback_dialog.queue_free)
