class_name PostBattleSequenceUI
extends Control

# Backend Service Integrations
const InjurySystemService = preload("res://src/core/services/InjurySystemService.gd")
const CharacterAdvancementService = preload("res://src/core/services/CharacterAdvancementService.gd")
const EnemyLootGenerator = preload("res://src/game/economy/loot/EnemyLootGenerator.gd")
const GameDataLoader = preload("res://src/utils/GameDataLoader.gd")

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
	print("PostBattleSequence: Initializing...")
	_initialize_steps()
	_load_battle_results()
	_show_current_step()
	_setup_postbattle_icons()

func _initialize_steps() -> void:
	"""Initialize the post-battle sequence"""
	# Initialize step results array
	step_results.resize(max_steps)
	for i: int in range(max_steps):
		step_results[i] = {}

	# Create step list display
	_refresh_steps_list()

func _load_battle_results() -> void:
	"""Load battle results from the completed battle"""
	# Connect to battle system and load actual results
	var battle_manager = get_node_or_null("/root/BattleManager")
	if battle_manager and battle_manager.has_method("get_last_battle_result"):
		battle_results = battle_manager.get_last_battle_result()
	else:
		# Fallback to default results for testing
		battle_results = {
			"victory": true,
			"mission_type": "Opportunist",
			"enemy_defeated": 4,
			"crew_casualties": 1,
			"crew_injuries": 0,
			"loot_opportunities": 2,
			"payment": 5,
			"story_points_earned": 1,
			"loot_found": []
		}

func _refresh_steps_list() -> void:
	"""Refresh the steps list display"""
	# Clear existing steps
	for child in steps_container.get_children():
		child.queue_free()

	# Add step items
	for i: int in range(max_steps):
		var step_panel: Panel = _create_step_panel(i)
		steps_container.add_child(step_panel)

func _create_step_panel(step_index: int) -> Control:
	"""Create a panel for a post-battle step"""
	var panel: PanelContainer = PanelContainer.new()
	var label: Label = Label.new()
	panel.add_child(label)

	var step = post_battle_steps[step_index]
	label.text = step.name

	# Color coding based on completion status
	if step_index < current_step:
		label.modulate = Color.GREEN # Completed
	elif step_index == current_step:
		label.modulate = Color.YELLOW # Current
	else:
		label.modulate = Color.WHITE # Pending

	return panel

func _show_current_step() -> void:
	"""Display the current step content"""
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
	"""Add specific content for each step"""
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
	"""Add rival status check content with Five Parsecs rules"""
	var label: Label = Label.new()
	label.text = "Roll D6 for each rival to see if they follow you to the next world.\nRival follows on 1-3, stays behind on 4-6."
	step_content.add_child(label)
	
	# Get current rivals from campaign data
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	if campaign_manager and campaign_manager.has_method("get_active_rivals"):
		var rivals = campaign_manager.get_active_rivals()
		for rival in rivals:
			var rival_panel = _create_rival_status_panel(rival)
			step_content.add_child(rival_panel)

func _create_rival_status_panel(rival: Dictionary) -> Control:
	"""Create a panel for rival status checking"""
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
	"""Add patron status content"""
	var label: Label = Label.new()
	label.text = "Update patron relationships based on mission success."
	step_content.add_child(label)

func _add_quest_progress_content() -> void:
	"""Add quest progress content"""
	var label: Label = Label.new()
	label.text = "Check if any active quests advance based on mission results."
	step_content.add_child(label)

func _add_payment_content() -> void:
	"""Add payment content with automatic credit application"""
	var payment = battle_results.get("payment", 0)
	var victory_bonus = 0
	
	if battle_results.get("victory", false):
		victory_bonus = payment * 0.5 # 50% bonus for victory
	
	var total_payment = payment + victory_bonus
	
	var label: Label = Label.new()
	label.text = "Base payment: %d credits\nVictory bonus: %d credits\nTotal received: %d credits" % [payment, victory_bonus, total_payment]
	step_content.add_child(label)
	
	# Apply payment to campaign
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	if campaign_manager and campaign_manager.has_method("add_credits"):
		campaign_manager.add_credits(total_payment)
		_add_result_to_log("Received %d credits" % total_payment)
	
	var apply_button = Button.new()
	apply_button.text = "Apply Payment"
	apply_button.pressed.connect(_on_apply_payment.bind(total_payment))
	step_content.add_child(apply_button)

func _add_battlefield_finds_content() -> void:
	"""Add battlefield finds content with Five Parsecs loot tables"""
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
	"""Create a panel for battlefield finds"""
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
	"""Add invasion check content"""
	var label: Label = Label.new()
	label.text = "Roll D6 to check for invasion threats."
	step_content.add_child(label)

func _add_loot_content() -> void:
	"""Add loot content with EnemyLootGenerator integration"""
	var label: Label = Label.new()
	label.text = "Roll on loot tables for items found from defeated enemies."
	step_content.add_child(label)

	# Add button to generate loot
	var loot_button: Button = Button.new()
	loot_button.text = "Generate Loot from Defeated Enemies"
	loot_button.pressed.connect(_on_generate_loot_pressed)
	step_content.add_child(loot_button)

	# Display area for loot results
	var loot_results_container: VBoxContainer = VBoxContainer.new()
	loot_results_container.name = "LootResultsContainer"
	step_content.add_child(loot_results_container)

func _add_injury_content() -> void:
	"""Add injury content with Five Parsecs injury tables"""
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
		no_injuries_label.modulate = Color.GREEN
		step_content.add_child(no_injuries_label)

func _create_injury_panel(type: String, num: int, is_casualty: bool) -> Control:
	"""Create a panel for injury resolution"""
	var panel = HBoxContainer.new()
	
	var label = Label.new()
	label.text = "%s %d:" % [type, num]
	label.custom_minimum_size.x = 100
	panel.add_child(label)
	
	var roll_button = Button.new()
	roll_button.text = "Roll Injury" if not is_casualty else "Roll Severity"
	roll_button.pressed.connect(_on_injury_roll.bind(type, num, is_casualty))
	panel.add_child(roll_button)
	
	var result_label = Label.new()
	result_label.name = "injury_result_%s_%d" % [type.to_lower(), num]
	result_label.text = "Not rolled"
	panel.add_child(result_label)
	
	return panel

func _add_experience_content() -> void:
	"""Add experience content with Five Parsecs advancement"""
	var label: Label = Label.new()
	label.text = "Crew members gain experience from battle. Roll for advancement!"
	step_content.add_child(label)
	
	# Get crew from campaign
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	if campaign_manager and campaign_manager.has_method("get_crew_members"):
		var crew = campaign_manager.get_crew_members()
		var exp_container = VBoxContainer.new()
		
		for crew_member in crew:
			# Skip if crew member was a casualty
			if not _was_crew_casualty(crew_member):
				var exp_panel = _create_experience_panel(crew_member)
				exp_container.add_child(exp_panel)
		
		step_content.add_child(exp_container)
	
	var story_points = battle_results.get("story_points_earned", 1)
	var story_label = Label.new()
	story_label.text = "Story Points earned this battle: %d" % story_points
	story_label.modulate = Color.CYAN
	step_content.add_child(story_label)

func _create_experience_panel(crew_member: Dictionary) -> Control:
	"""Create experience gain panel for crew member"""
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

func _add_training_content() -> void:
	"""Add training content"""
	var label: Label = Label.new()
	label.text = "Invest credits in advanced training for crew members."
	step_content.add_child(label)

func _add_purchase_content() -> void:
	"""Add purchase content"""
	var label: Label = Label.new()
	label.text = "Purchase new equipment and supplies."
	step_content.add_child(label)

func _add_campaign_events_content() -> void:
	"""Add campaign events content with Five Parsecs event tables"""
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
	"""Handle campaign event roll"""
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_dice("Campaign Event", "D100")
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
	"""Get color for event based on roll"""
	if roll >= 90:
		return Color.CYAN # Major positive
	elif roll >= 70:
		return Color.GREEN # Minor positive
	elif roll >= 30:
		return Color.WHITE # Neutral
	elif roll >= 10:
		return Color.ORANGE # Minor negative
	else:
		return Color.RED # Major negative

func _add_character_events_content() -> void:
	"""Add character events content with individual crew rolls"""
	var label: Label = Label.new()
	label.text = "Roll D100 on character events table for each crew member."
	step_content.add_child(label)
	
	# Get crew from campaign
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	if campaign_manager and campaign_manager.has_method("get_crew_members"):
		var crew = campaign_manager.get_crew_members()
		var char_events_container = VBoxContainer.new()
		
		for crew_member in crew:
			if not _was_crew_casualty(crew_member):
				var char_panel = _create_character_event_panel(crew_member)
				char_events_container.add_child(char_panel)
		
		step_content.add_child(char_events_container)

func _create_character_event_panel(crew_member: Dictionary) -> Control:
	"""Create character event panel for crew member"""
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
	"""Handle character event roll"""
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_dice("Character Event: " + crew_member.get("name", "Unknown"), "D100")
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
	"""Add galactic war content"""
	var label: Label = Label.new()
	label.text = "Check Galactic War progression and effects."
	step_content.add_child(label)

func _add_result_to_log(result: String) -> void:
	"""Add a result to the results log"""
	var result_label: Label = Label.new()
	result_label.text = "Step " + str(current_step + 1) + ": " + result
	results_container.add_child(result_label)

func _on_previous_pressed() -> void:
	"""Handle previous button press"""
	if current_step > 0:
		current_step -= 1
		_show_current_step()

func _on_next_pressed() -> void:
	"""Handle next button press"""
	# Store current step result
	var result: Variant = _get_current_step_result()
	step_results[current_step] = result
	step_completed.emit(current_step, result)

	# Move to next step
	current_step += 1
	_show_current_step()

func _on_roll_pressed() -> void:
	"""Handle roll dice button press with proper dice system integration"""
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll_result = 0
	
	# Determine dice type based on step
	var dice_type = "D6"
	match current_step:
		11, 12: # Campaign and Character Events
			dice_type = "D100"
	
	if dice_manager and dice_manager.has_method("roll_dice"):
		roll_result = dice_manager.roll_dice("Post-Battle Step %d" % (current_step + 1), dice_type)
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
	print("PostBattleSequence: Rolled ", roll_result, " for step ", current_step + 1)

func _on_finish_pressed() -> void:
	"""Handle finish button press"""
	_finish_post_battle()

func _get_current_step_result() -> Dictionary:
	"""Get the result data for the current step"""
	return {
		"step_index": current_step,
		"step_name": post_battle_steps[current_step].name,
		"completed": true,
		"timestamp": Time.get_unix_time_from_system()
	}

func _finish_post_battle() -> void:
	"""Complete the post-battle sequence"""
	var final_results = {
		"battle_results": battle_results,
		"step_results": step_results,
		"completion_time": Time.get_unix_time_from_system()
	}

	post_battle_completed.emit(final_results)
	print("PostBattleSequence: Completed all steps")

	# Bridge UI to backend: Notify CampaignPhaseManager to complete post-battle phase
	var phase_manager = get_node_or_null("/root/CampaignPhaseManager")
	if phase_manager and phase_manager.has_method("_on_post_battle_phase_completed"):
		print("PostBattleSequence: Triggering CampaignPhaseManager post-battle completion")
		phase_manager._on_post_battle_phase_completed()
	else:
		push_warning("PostBattleSequence: CampaignPhaseManager not found - turn will not advance")

	# Navigate to Campaign Dashboard to show new turn
	await get_tree().create_timer(0.5).timeout  # Brief delay for user to see completion
	if has_node("/root/SceneRouter"):
		var scene_router = get_node("/root/SceneRouter")
		scene_router.navigate_to("campaign_dashboard")
	else:
		get_tree().change_scene_to_file("res://src/ui/screens/campaign/CampaignDashboard.tscn")

func _on_back_pressed() -> void:
	"""Handle back button press - return to Campaign Dashboard"""
	print("PostBattleSequence: Back pressed - returning to Campaign Dashboard")
	if has_node("/root/SceneRouter"):
		var scene_router = get_node("/root/SceneRouter")
		scene_router.navigate_to("campaign_dashboard")
	else:
		get_tree().change_scene_to_file("res://src/ui/screens/campaign/CampaignDashboard.tscn")
## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

## Setup post-battle phase icons for enhanced visual navigation
func _setup_postbattle_icons() -> void:
	"""Setup icons for post-battle phase buttons to improve visual clarity"""
	# Phase 2: Post-Battle Phase Icons Integration
	
	# Next Button (primary post-battle action) - icon_campaign_post_battle.svg
	if next_button:
		next_button.icon = preload("res://assets/basic icons/icon_campaign_post_battle.svg")
		next_button.expand_icon = true
		next_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		print("PostBattleSequence: Post-battle phase icon applied to next button successfully")
	else:
		push_warning("PostBattleSequence: Next button not found for icon assignment")
	
	# Finish Button (completion action) - also use post-battle icon
	if finish_button:
		finish_button.icon = preload("res://assets/basic icons/icon_campaign_post_battle.svg")
		finish_button.expand_icon = true
		finish_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		print("PostBattleSequence: Post-battle phase icon applied to finish button successfully")
	else:
		push_warning("PostBattleSequence: Finish button not found for icon assignment")

# Enhanced roll interpretation functions using Five Parsecs tables

func _interpret_battlefield_find(roll: int) -> String:
	"""Interpret battlefield find roll using Five Parsecs tables"""
	if roll >= 5:
		return "Found equipment!"
	elif roll >= 3:
		return "Found supplies"
	else:
		return "Nothing useful found"

func _interpret_loot_roll(roll: int) -> String:
	"""Interpret loot roll using Five Parsecs loot tables"""
	if roll == 6:
		return "Rare equipment found!"
	elif roll >= 4:
		return "Standard equipment found"
	elif roll >= 2:
		return "Credits found"
	else:
		return "No loot"

func _interpret_campaign_event(roll: int) -> String:
	"""Interpret campaign event roll"""
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
	"""Interpret character event roll"""
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
	"""Handle rival status roll"""
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_dice("Rival Status: " + rival.get("name", "Unknown"), "D6")
	else:
		roll = randi_range(1, 6)
	
	var follows = roll <= 3
	var result_text = "Rolled %d - %s" % [roll, "Follows" if follows else "Stays behind"]
	
	# Update UI
	var result_label = step_content.find_child("result_" + str(rival.get("id", 0)))
	if result_label:
		result_label.text = result_text
		result_label.modulate = Color.GREEN if follows else Color.RED
	
	_add_result_to_log("%s: %s" % [rival.get("name", "Rival"), result_text])

func _on_apply_payment(amount: int) -> void:
	"""Apply payment to campaign"""
	var campaign_manager = get_node_or_null("/root/CampaignManager")
	if campaign_manager and campaign_manager.has_method("add_credits"):
		campaign_manager.add_credits(amount)
		_add_result_to_log("Applied %d credits to campaign" % amount)

func _on_battlefield_find_roll(enemy_num: int) -> void:
	"""Handle battlefield find roll using JSON data table"""
	# Load battlefield finds table
	var finds_table = GameDataLoader.get_battlefield_finds_table()
	
	if finds_table.is_empty():
		push_error("PostBattleSequence: Failed to load battlefield_finds.json")
		_add_result_to_log("Enemy %d search: ERROR - Could not load loot table" % enemy_num)
		return
	
	# Roll d6 using GameDataLoader helper
	var roll = GameDataLoader.roll_d6()
	
	# Look up result in table
	var result_data = GameDataLoader.roll_on_table(finds_table, roll)
	
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
			result_label.modulate = Color.GREEN  # Valuable/rare
		elif roll >= 3:
			result_label.modulate = Color.YELLOW  # Equipment/weapon
		else:
			result_label.modulate = Color.GRAY  # Nothing/minor salvage
	
	# Apply credits to campaign
	if credits > 0:
		var campaign_manager = get_node_or_null("/root/CampaignManager")
		if campaign_manager and campaign_manager.has_method("add_credits"):
			campaign_manager.add_credits(credits)
	
	# Store result for later item table rolls if needed
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
	
	print("PostBattleSequence: Battlefield find - roll=%d, outcome=%s, credits=%d" % [roll, outcome, credits])

func _on_injury_roll(type: String, num: int, is_casualty: bool) -> void:
	"""Handle injury severity roll using InjurySystemService"""
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0

	if dice_manager:
		roll = dice_manager.roll_dice("%s %d Injury" % [type, num], "D100")
	else:
		roll = randi_range(1, 100)

	# Use InjurySystemService for proper injury determination
	var injury_data = InjurySystemService.determine_injury(roll)
	var severity = injury_data.get("type_name", "Unknown")
	var description = injury_data.get("description", "")
	var recovery_turns = injury_data.get("recovery_turns", 0)
	var is_fatal = injury_data.get("is_fatal", false)

	var result_text = "Rolled %d - %s" % [roll, severity]
	if is_fatal:
		result_text += " (FATAL)"
	elif recovery_turns > 0:
		result_text += " (%d turns recovery)" % recovery_turns

	# Store injury data for campaign integration
	step_results[current_step]["%s_%d" % [type.to_lower(), num]] = injury_data

	# Update UI
	var result_label = step_content.find_child("injury_result_%s_%d" % [type.to_lower(), num])
	if result_label:
		result_label.text = result_text
		result_label.modulate = _get_injury_color(severity)

	_add_result_to_log("%s %d: %s" % [type, num, result_text])

func _on_generate_loot_pressed() -> void:
	"""Generate loot using EnemyLootGenerator"""
	# Note: EnemyLootGenerator requires Enemy objects, but we only have battle results
	# For now, generate generic loot based on enemy count
	var enemies_defeated = battle_results.get("enemy_defeated", 0)
	var enemy_type = battle_results.get("enemy_type", "Unknown Hostiles")

	var loot_results_container = step_content.find_child("LootResultsContainer")
	if not loot_results_container:
		return

	# Clear previous results
	for child in loot_results_container.get_children():
		child.queue_free()

	# Generate loot for each defeated enemy
	var loot_generator = EnemyLootGenerator.new()
	var total_loot: Array = []

	for i in range(enemies_defeated):
		# Simple D6 roll for loot quality
		var quality_roll = randi_range(1, 6)
		var loot_desc = ""

		if quality_roll >= 5:
			loot_desc = "Equipment found!"
			total_loot.append({"type": "equipment", "enemy": i + 1})
		elif quality_roll >= 3:
			loot_desc = "Supplies found"
			total_loot.append({"type": "supplies", "enemy": i + 1})
		else:
			loot_desc = "Nothing useful"

		var loot_label = Label.new()
		loot_label.text = "Enemy %d: %s (rolled %d)" % [i + 1, loot_desc, quality_roll]
		loot_results_container.add_child(loot_label)

	# Store loot data for campaign integration
	step_results[current_step]["loot_found"] = total_loot

	# Persist loot to EquipmentManager
	_add_loot_to_inventory(total_loot)

	_add_result_to_log("Generated loot from %d enemies: %d items found" % [enemies_defeated, total_loot.size()])

func _add_loot_to_inventory(loot_items: Array) -> void:
	"""Persist battle loot to EquipmentManager ship stash"""
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if not equipment_manager:
		push_error("PostBattle: EquipmentManager not found - loot will be LOST!")
		_add_result_to_log("[ERROR] EquipmentManager missing - loot not saved!")
		return
	
	var credits_gained: int = 0
	var items_added: int = 0
	var items_lost: int = 0  # Stash full
	
	for loot_item: Dictionary in loot_items:
		var loot_type: String = loot_item.get("type", "unknown")
		
		# Handle credits separately (if loot has credits value)
		if loot_type == "credits" or loot_item.has("credits"):
			var credit_amount: int = loot_item.get("credits", 10)  # Default 10 credits
			credits_gained += credit_amount
			# TODO: Add credits to campaign treasury via CampaignManager
			continue
		
		# Handle equipment items - convert to proper equipment data format
		if loot_type == "equipment" or loot_type == "supplies":
			var equipment_data: Dictionary = {
				"id": "loot_%d_%d" % [Time.get_ticks_msec(), loot_item.get("enemy", randi() % 1000)],
				"name": _generate_loot_item_name(loot_type),
				"category": "GEAR" if loot_type == "supplies" else "WEAPON",
				"description": "Found on battlefield from Enemy %d" % loot_item.get("enemy", 0),
				"value": 10 if loot_type == "supplies" else 20,
				"location": "ship_stash"
			}
			
			# Try to add to ship stash
			var added: bool = equipment_manager.add_to_ship_stash(equipment_data)
			if added:
				items_added += 1
				print("PostBattle: Added %s to ship stash" % equipment_data.get("name", "item"))
			else:
				items_lost += 1
				push_warning("PostBattle: Ship stash full - lost %s" % equipment_data.get("name", "item"))
	
	# Show summary in results log
	var summary: String = "Loot Summary: "
	if credits_gained > 0:
		summary += "+%d credits, " % credits_gained
	if items_added > 0:
		summary += "+%d items added to stash" % items_added
	if items_lost > 0:
		summary += " (%d items lost - stash full)" % items_lost
	
	print("PostBattle Loot: +%d credits, +%d items, %d lost (stash full)" % [credits_gained, items_added, items_lost])
	_add_result_to_log(summary)

func _generate_loot_item_name(loot_type: String) -> String:
	"""Generate procedural loot item names based on type"""
	if loot_type == "equipment":
		var weapons: Array[String] = ["Rusty Blade", "Salvaged Pistol", "Combat Knife", "Energy Cell"]
		return weapons[randi() % weapons.size()]
	elif loot_type == "supplies":
		var supplies: Array[String] = ["Medkit", "Ration Pack", "Ammo Clip", "Tool Kit"]
		return supplies[randi() % supplies.size()]
	else:
		return "Unknown Item"

func _on_experience_roll(crew_member: Dictionary) -> void:
	"""Handle experience advancement roll"""
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll = 0
	
	if dice_manager:
		roll = dice_manager.roll_dice("Advancement: " + crew_member.get("name", "Unknown"), "D6")
	else:
		roll = randi_range(1, 6)
	
	var advancement = _interpret_advancement_roll(roll)
	var result_text = "Rolled %d - %s" % [roll, advancement]
	
	# Update UI
	var result_label = step_content.find_child("exp_result_" + str(crew_member.get("id", 0)))
	if result_label:
		result_label.text = result_text
		result_label.modulate = Color.GREEN if roll >= 4 else Color.GRAY
	
	_add_result_to_log("%s: %s" % [crew_member.get("name", "Crew"), result_text])

func _interpret_injury_roll(roll: int, is_casualty: bool) -> String:
	"""Interpret injury roll using Five Parsecs injury table"""
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
	"""Interpret advancement roll"""
	if roll == 6:
		return "Major advancement - gain 2 skill points!"
	elif roll >= 4:
		return "Advancement - gain 1 skill point"
	else:
		return "No advancement this time"

func _get_injury_color(severity: String) -> Color:
	"""Get color for injury severity"""
	if "Critical" in severity or "permanent" in severity:
		return Color.RED
	elif "Severe" in severity or "Serious" in severity:
		return Color.ORANGE
	elif "Light" in severity or "Minor" in severity:
		return Color.YELLOW
	else:
		return Color.GREEN

func _was_crew_casualty(crew_member: Dictionary) -> bool:
	"""Check if crew member was a casualty in battle"""
	# This would need to check against actual battle results
	return false # Placeholder implementation