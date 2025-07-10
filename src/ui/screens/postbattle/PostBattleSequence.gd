class_name PostBattleSequenceUI
extends Control

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
	# TODO: Connect to battle system
	battle_results = {
		"victory": true,
		"mission_type": "Opportunist",
		"enemy_defeated": 4,
		"crew_casualties": 1,
		"loot_opportunities": 2,
		"payment": 5
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
	"""Add rival status check content"""
	var label: Label = Label.new()
	label.text = "Roll D6 for each rival to see if they follow you to the next world."
	step_content.add_child(label)

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
	"""Add payment content"""
	var label: Label = Label.new()
	label.text = "Receive payment: " + str(battle_results.get("payment", 0)) + " credits"
	step_content.add_child(label)

func _add_battlefield_finds_content() -> void:
	"""Add battlefield finds content"""
	var label: Label = Label.new()
	label.text = "Roll D6 for battlefield finds based on enemy types defeated."
	step_content.add_child(label)

func _add_invasion_check_content() -> void:
	"""Add invasion check content"""
	var label: Label = Label.new()
	label.text = "Roll D6 to check for invasion threats."
	step_content.add_child(label)

func _add_loot_content() -> void:
	"""Add loot content"""
	var label: Label = Label.new()
	label.text = "Roll on loot tables for items found."
	step_content.add_child(label)

func _add_injury_content() -> void:
	"""Add injury content"""
	var label: Label = Label.new()
	label.text = "Check crew injuries and roll for recovery."
	step_content.add_child(label)

func _add_experience_content() -> void:
	"""Add experience content"""
	var label: Label = Label.new()
	label.text = "Gain experience points and apply character upgrades."
	step_content.add_child(label)

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
	"""Add campaign events content"""
	var label: Label = Label.new()
	label.text = "Roll D100 on campaign events table."
	step_content.add_child(label)

func _add_character_events_content() -> void:
	"""Add character events content"""
	var label: Label = Label.new()
	label.text = "Roll D100 on character events table for each crew member."
	step_content.add_child(label)

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
	"""Handle roll dice button press"""
	var roll_result = randi_range(1, 6)
	var result_text: String = "Rolled: " + str(roll_result)

	# Add step-specific roll interpretation
	match current_step:
		0: # Rival Status
			result_text += " - " + ("Rival follows" if roll_result <= 3 else "Rival doesn't follow")
		4: # Battlefield Finds
			result_text += " - " + ("Found item" if roll_result >= 4 else "No finds")
		5: # Invasion Check
			result_text += " - " + ("Invasion threat" if roll_result == 1 else "No invasion")

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

func _on_back_pressed() -> void:
	"""Handle back button press"""
	print("PostBattleSequence: Back pressed")
	if has_node("/root/SceneRouter"):
		var scene_router = get_node("/root/SceneRouter")
		scene_router.navigate_back()
	else:
		get_tree().change_scene_to_file("res://src/ui/screens/main/MainMenu.tscn")
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