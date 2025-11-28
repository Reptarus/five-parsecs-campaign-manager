extends Control

## Post-Battle Results UI - Five Parsecs Campaign Manager
## Displays battle outcome, casualties, loot, and experience gained
## Handles post-battle processing according to Five Parsecs Core Rules

# UI Node References
@onready var battle_outcome_label: Label = $MainContainer/ResultsPanel/BattleOutcome
@onready var casualties_list: ItemList = $MainContainer/ResultsPanel/CasualtiesSection/CasualtiesList
@onready var injuries_list: ItemList = $MainContainer/ResultsPanel/InjuriesSection/InjuriesList
@onready var loot_list: ItemList = $MainContainer/ResultsPanel/LootSection/LootList
@onready var credits_earned_label: Label = $MainContainer/ResultsPanel/RewardsSection/CreditsEarned
@onready var experience_list: ItemList = $MainContainer/ResultsPanel/ExperienceSection/ExperienceList
@onready var continue_button: Button = $MainContainer/ButtonPanel/ContinueButton
@onready var save_results_button: Button = $MainContainer/ButtonPanel/SaveResultsButton

# Core Dependencies
const Character = preload("res://src/core/character/Character.gd")
const Mission = preload("res://src/core/systems/Mission.gd")

# Battle Results Data
var battle_results: Dictionary = {}
var crew_casualties: Array[Character] = []
var crew_injuries: Array[Character] = []
var loot_gained: Array = []  # Changed to untyped for flexibility
var credits_earned: int = 0
var experience_gained: Array[Dictionary] = []

# PHASE 5: Equipment and loot management
var equipment_manager: Node = null
var loot_assignments: Dictionary = {}  # loot_index -> character_id or "stash"
var surviving_crew: Array = []

# Signals
signal results_processed()
signal continue_to_campaign()
signal results_saved()
signal loot_distributed(loot_item: Dictionary, destination: String)

func _ready() -> void:
	"""Initialize the post-battle results UI"""
	_setup_ui_components()
	_connect_signals()
	_connect_to_equipment_manager()
	print("PostBattleResultsUI: Initialized")

func _setup_ui_components() -> void:
	"""Configure UI components"""
	# Initially hide all sections until results are loaded
	_hide_empty_sections()
	
	# Disable continue button until results are processed
	continue_button.disabled = true

func _connect_signals() -> void:
	"""Connect UI signals"""
	continue_button.pressed.connect(_on_continue_pressed)
	save_results_button.pressed.connect(_on_save_results_pressed)

func _connect_to_equipment_manager() -> void:
	"""PHASE 5: Connect to EquipmentManager for loot distribution"""
	equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager:
		print("PostBattleResultsUI: Connected to EquipmentManager")
	else:
		push_warning("PostBattleResultsUI: EquipmentManager not found")

## Public Interface

func display_battle_results(results: Dictionary) -> void:
	"""Display the battle results data"""
	battle_results = results
	
	# Extract battle outcome data
	_extract_battle_data(results)
	
	# PHASE 5: Setup surviving crew for loot distribution
	_setup_surviving_crew(results)
	
	# Generate loot if not provided
	if loot_gained.is_empty() and results.get("victory", false):
		var difficulty = results.get("difficulty", 2)
		loot_gained = generate_battle_loot(difficulty, true)
	
	# Update UI displays
	_update_battle_outcome()
	_update_casualties_display()
	_update_injuries_display()
	_update_loot_display()
	_update_rewards_display()
	_update_experience_display()
	
	# Show relevant sections
	_show_relevant_sections()
	
	# Enable continue button
	continue_button.disabled = false
	
	print("PostBattleResultsUI: Battle results displayed with %d loot items" % loot_gained.size())

func _setup_surviving_crew(results: Dictionary) -> void:
	"""Setup surviving crew list for loot distribution"""
	surviving_crew.clear()
	
	# Get all crew from results
	var all_crew = results.get("crew", [])
	var casualties_ids: Array = []
	
	# Get casualty IDs
	for casualty in crew_casualties:
		if casualty is Dictionary:
			casualties_ids.append(casualty.get("id", casualty.get("character_name", "")))
		elif casualty is Character:
			casualties_ids.append(casualty.id if casualty.id else casualty.character_name)
	
	# Filter to surviving crew only
	for member in all_crew:
		var member_id: String = ""
		if member is Dictionary:
			member_id = member.get("id", member.get("character_name", ""))
		elif member is Character:
			member_id = member.id if member.id else member.character_name
		
		if member_id not in casualties_ids:
			surviving_crew.append(member)
	
	print("PostBattleResultsUI: %d surviving crew members for loot distribution" % surviving_crew.size())

func process_post_battle_sequence() -> void:
	"""Process the complete post-battle sequence according to Five Parsecs rules"""
	print("PostBattleResultsUI: Processing post-battle sequence...")
	
	# Step 1: Determine casualties and injuries (Core Rules p.89-91)
	_process_casualties_and_injuries()
	
	# Step 2: Calculate loot and rewards (Core Rules p.91-93)
	_process_loot_and_rewards()
	
	# Step 3: Award experience and advancement (Core Rules p.93-95)
	_process_experience_and_advancement()
	
	# Step 4: Update character states
	_apply_results_to_characters()
	
	# Step 5: Save campaign state
	_save_campaign_state()
	
	results_processed.emit()

## Private Methods

func _extract_battle_data(results: Dictionary) -> void:
	"""Extract battle data from results dictionary"""
	# Battle outcome
	var victory = results.get("victory", false)
	
	# Casualties and injuries
	crew_casualties = results.get("casualties", [])
	crew_injuries = results.get("injuries", [])
	
	# Loot and rewards
	loot_gained = results.get("loot", [])
	credits_earned = results.get("credits", 0)
	
	# Experience
	experience_gained = results.get("experience", [])

func _update_battle_outcome() -> void:
	"""Update battle outcome display"""
	var victory = battle_results.get("victory", false)
	var rounds_fought = battle_results.get("rounds_fought", 0)
	
	if victory:
		battle_outcome_label.text = "VICTORY! (%d rounds)" % rounds_fought
		battle_outcome_label.modulate = Color.GREEN
	else:
		battle_outcome_label.text = "DEFEAT (%d rounds)" % rounds_fought
		battle_outcome_label.modulate = Color.RED

func _update_casualties_display() -> void:
	"""Update casualties list"""
	casualties_list.clear()
	
	for casualty in crew_casualties:
		if casualty and casualty.has_method("get_display_name"):
			casualties_list.add_item("† " + casualty.get_display_name())
		else:
			casualties_list.add_item("† Unknown Crew Member")

func _update_injuries_display() -> void:
	"""Update injuries list"""
	injuries_list.clear()
	
	for injured in crew_injuries:
		if injured and injured.has_method("get_display_name"):
			var injury_type = _determine_injury_type(injured)
			injuries_list.add_item("⚡ " + injured.get_display_name() + " - " + injury_type)
		else:
			injuries_list.add_item("⚡ Unknown Crew Member - Injury")

func _update_loot_display() -> void:
	"""Update loot list with assignment options"""
	loot_list.clear()
	loot_assignments.clear()
	
	for i in range(loot_gained.size()):
		var item = loot_gained[i]
		var item_name: String = "Unknown Item"
		
		# Get item display name based on type
		if item is Resource and item.has_method("get_display_name"):
			item_name = item.get_display_name()
		elif item is Dictionary:
			item_name = item.get("name", item.get("display_name", "Unknown Item"))
		elif item is String:
			item_name = item
		
		# Default assignment to ship stash
		loot_assignments[i] = "stash"
		
		loot_list.add_item("📦 " + item_name)
	
	# Connect item selection for assignment
	if not loot_list.item_selected.is_connected(_on_loot_item_selected):
		loot_list.item_selected.connect(_on_loot_item_selected)

func _on_loot_item_selected(index: int) -> void:
	"""Handle loot item selection for assignment"""
	if index < 0 or index >= loot_gained.size():
		return
	
	# Show assignment popup
	_show_loot_assignment_popup(index)

func _show_loot_assignment_popup(loot_index: int) -> void:
	"""Show popup to assign loot to crew or stash"""
	var popup = PopupMenu.new()
	popup.name = "LootAssignmentPopup"
	
	# Add ship stash option
	popup.add_item("📦 Ship Stash", 0)
	popup.add_separator()
	
	# Add surviving crew options
	for i in range(surviving_crew.size()):
		var member = surviving_crew[i]
		var member_name: String = "Crew Member"
		
		if member is Dictionary:
			member_name = member.get("character_name", member.get("name", "Crew Member"))
		elif member is Character:
			member_name = member.character_name if member.character_name else member.name
		
		popup.add_item("👤 " + member_name, i + 1)
	
	popup.id_pressed.connect(_on_loot_assignment_selected.bind(loot_index))
	
	add_child(popup)
	popup.popup_centered()

func _on_loot_assignment_selected(selected_id: int, loot_index: int) -> void:
	"""Handle loot assignment selection"""
	if loot_index < 0 or loot_index >= loot_gained.size():
		return
	
	var item = loot_gained[loot_index]
	var item_name: String = "item"
	
	if item is Dictionary:
		item_name = item.get("name", "item")
	elif item is Resource and item.has_method("get_display_name"):
		item_name = item.get_display_name()
	
	if selected_id == 0:
		# Assign to ship stash
		loot_assignments[loot_index] = "stash"
		print("PostBattleResultsUI: Assigned %s to ship stash" % item_name)
		_update_loot_item_display(loot_index, "Ship Stash")
	elif selected_id > 0 and selected_id <= surviving_crew.size():
		# Assign to crew member
		var crew_index = selected_id - 1
		var member = surviving_crew[crew_index]
		var member_id: String = ""
		var member_name: String = ""
		
		if member is Dictionary:
			member_id = member.get("id", member.get("character_name", str(crew_index)))
			member_name = member.get("character_name", member.get("name", "Crew"))
		elif member is Character:
			member_id = member.id if member.id else member.character_name
			member_name = member.character_name if member.character_name else member.name
		
		loot_assignments[loot_index] = member_id
		print("PostBattleResultsUI: Assigned %s to %s" % [item_name, member_name])
		_update_loot_item_display(loot_index, member_name)

func _update_loot_item_display(index: int, assignment: String) -> void:
	"""Update loot list item to show assignment"""
	if index < 0 or index >= loot_list.item_count:
		return
	
	var item = loot_gained[index]
	var item_name: String = "Unknown Item"
	
	if item is Resource and item.has_method("get_display_name"):
		item_name = item.get_display_name()
	elif item is Dictionary:
		item_name = item.get("name", "Unknown Item")
	
	loot_list.set_item_text(index, "📦 %s → %s" % [item_name, assignment])

func _update_rewards_display() -> void:
	"""Update rewards display"""
	credits_earned_label.text = "Credits Earned: %d" % credits_earned

func _update_experience_display() -> void:
	"""Update experience list"""
	experience_list.clear()
	
	for exp_entry in experience_gained:
		var character_name = exp_entry.get("character", "Unknown")
		var exp_amount = exp_entry.get("experience", 0)
		var advancement = exp_entry.get("advancement", false)
		
		var display_text = "⭐ %s: +%d XP" % [character_name, exp_amount]
		if advancement:
			display_text += " (ADVANCEMENT!)"
		
		experience_list.add_item(display_text)

func _hide_empty_sections() -> void:
	"""Hide sections that have no content"""
	# Implementation depends on actual scene structure
	pass

func _show_relevant_sections() -> void:
	"""Show sections based on available data"""
	# Show casualties section if there are casualties
	var casualties_section = get_node_or_null("MainContainer/ResultsPanel/CasualtiesSection")
	if casualties_section:
		casualties_section.visible = crew_casualties.size() > 0
	
	# Show injuries section if there are injuries
	var injuries_section = get_node_or_null("MainContainer/ResultsPanel/InjuriesSection")
	if injuries_section:
		injuries_section.visible = crew_injuries.size() > 0
	
	# Show loot section if there is loot
	var loot_section = get_node_or_null("MainContainer/ResultsPanel/LootSection")
	if loot_section:
		loot_section.visible = loot_gained.size() > 0
	
	# Always show rewards and experience sections
	var rewards_section = get_node_or_null("MainContainer/ResultsPanel/RewardsSection")
	if rewards_section:
		rewards_section.visible = true
	
	var experience_section = get_node_or_null("MainContainer/ResultsPanel/ExperienceSection")
	if experience_section:
		experience_section.visible = experience_gained.size() > 0

func _process_casualties_and_injuries() -> void:
	"""Process casualties and injuries according to Five Parsecs rules"""
	# Five Parsecs Post-Battle Casualty Rules (Core Rules p.89-91)
	for character in crew_casualties:
		print("PostBattleResultsUI: Processing casualty for %s" % character.get_display_name() if character.has_method("get_display_name") else "Unknown")
		# Character is permanently removed from crew
		# Handle will and equipment inheritance
	
	for character in crew_injuries:
		print("PostBattleResultsUI: Processing injury for %s" % character.get_display_name() if character.has_method("get_display_name") else "Unknown")
		# Apply injury effects and recovery time

func _process_loot_and_rewards() -> void:
	"""Process loot and rewards according to Five Parsecs rules"""
	# Five Parsecs Post-Battle Loot Rules (Core Rules p.91-93)
	print("PostBattleResultsUI: Processing %d credits and %d loot items" % [credits_earned, loot_gained.size()])
	
	# Add credits to campaign funds
	if GameState:
		GameState.add_credits(credits_earned)
	
	# PHASE 5: Apply loot assignments using EquipmentManager
	_apply_loot_assignments()

func _apply_loot_assignments() -> void:
	"""Apply loot assignments to crew or ship stash via EquipmentManager"""
	for loot_index in loot_assignments.keys():
		if loot_index < 0 or loot_index >= loot_gained.size():
			continue
		
		var item = loot_gained[loot_index]
		var destination = loot_assignments[loot_index]
		
		# Convert item to dictionary if needed
		var item_data: Dictionary = {}
		if item is Dictionary:
			item_data = item.duplicate()
		elif item is Resource:
			item_data = {
				"name": item.get_meta("name") if item.has_meta("name") else "Unknown",
				"type": item.get_meta("type") if item.has_meta("type") else "misc",
				"value": item.get_meta("value") if item.has_meta("value") else 5,
				"id": "loot_%d_%d" % [Time.get_ticks_msec(), loot_index]
			}
		else:
			item_data = {"name": str(item), "type": "misc", "id": "loot_%d" % loot_index}
		
		# Ensure item has ID
		if not item_data.has("id"):
			item_data["id"] = "loot_%d_%d" % [Time.get_ticks_msec(), loot_index]
		
		if destination == "stash":
			# Add to ship stash
			if equipment_manager and equipment_manager.has_method("add_to_ship_stash"):
				if equipment_manager.add_to_ship_stash(item_data):
					print("PostBattleResultsUI: Added %s to ship stash" % item_data.get("name", "item"))
					loot_distributed.emit(item_data, "ship_stash")
				else:
					print("PostBattleResultsUI: Failed to add %s to stash (may be full)" % item_data.get("name", "item"))
			else:
				# Fallback to GameState
				if GameState and GameState.has_method("add_item_to_inventory"):
					GameState.add_item_to_inventory(item)
		else:
			# Assign to character
			if equipment_manager and equipment_manager.has_method("assign_equipment_to_character"):
				# First add to storage, then assign
				equipment_manager.add_equipment(item_data)
				if equipment_manager.assign_equipment_to_character(destination, item_data.id):
					print("PostBattleResultsUI: Assigned %s to %s" % [item_data.get("name", "item"), destination])
					loot_distributed.emit(item_data, destination)
				else:
					# Fall back to stash if assignment fails
					equipment_manager.add_to_ship_stash(item_data)
					print("PostBattleResultsUI: Assignment failed, added %s to stash" % item_data.get("name", "item"))

func generate_battle_loot(difficulty: int, victory: bool) -> Array:
	"""Generate loot using EquipmentManager based on battle outcome"""
	var generated_loot: Array = []
	
	if equipment_manager and equipment_manager.has_method("generate_battle_loot"):
		generated_loot = equipment_manager.generate_battle_loot(difficulty, victory)
		print("PostBattleResultsUI: Generated %d loot items" % generated_loot.size())
	else:
		# Fallback: Generate basic loot
		if victory:
			var basic_loot = _generate_fallback_loot(difficulty)
			generated_loot.append_array(basic_loot)
	
	return generated_loot

func _generate_fallback_loot(difficulty: int) -> Array:
	"""Generate fallback loot if EquipmentManager unavailable"""
	var loot: Array = []
	
	# Basic loot generation based on difficulty
	var item_count = 1 + (difficulty / 2)
	
	var possible_items = [
		{"name": "Credits", "type": "credits", "value": 50 + randi() % 50},
		{"name": "Military Rifle", "type": "weapon", "value": 12},
		{"name": "Combat Armor", "type": "armor", "value": 15},
		{"name": "Med-Kit", "type": "gear", "value": 4},
		{"name": "Scanner", "type": "gear", "value": 7}
	]
	
	for i in range(item_count):
		var item = possible_items[randi() % possible_items.size()].duplicate()
		item["id"] = "fallback_loot_%d" % i
		loot.append(item)
	
	return loot

func _process_experience_and_advancement() -> void:
	"""Process experience and advancement according to Five Parsecs rules"""
	# Five Parsecs Experience Rules (Core Rules p.93-95)
	for exp_entry in experience_gained:
		var character = exp_entry.get("character_ref")
		var exp_amount = exp_entry.get("experience", 0)
		
		if character and character.has_method("add_experience"):
			character.add_experience(exp_amount)
			print("PostBattleResultsUI: Awarded %d XP to %s" % [exp_amount, character.get_display_name() if character.has_method("get_display_name") else "Unknown"])

func _apply_results_to_characters() -> void:
	"""Apply all battle results to character states"""
	# Remove casualties from active crew
	for casualty in crew_casualties:
		# GameStateManagerAutoload not available - use GameState fallback
		if GameState and GameState.has_method("remove_character"):
			GameState.remove_character(casualty)
	
	# Apply injury states to injured characters
	for injured in crew_injuries:
		if injured.has_method("apply_injury"):
			var injury_type = _determine_injury_type(injured)
			injured.apply_injury(injury_type)

func _determine_injury_type(character: Character) -> String:
	"""Determine injury type according to Five Parsecs rules"""
	# Five Parsecs Injury Table (Core Rules p.90)
	var injury_roll = randi() % 6 + 1
	
	match injury_roll:
		1, 2:
			return "Light Wound"
		3, 4:
			return "Serious Wound"
		5:
			return "Severe Injury"
		6:
			return "Critical Injury"
		_:
			return "Unknown Injury"

func _save_campaign_state() -> void:
	"""Save campaign state with post-battle results"""
	if GameState:
		GameState.save_game_state()
		print("PostBattleResultsUI: Campaign state saved")

## Signal Handlers

func _on_continue_pressed() -> void:
	"""Handle continue button press"""
	print("PostBattleResultsUI: Continue to campaign")
	continue_to_campaign.emit()

func _on_save_results_pressed() -> void:
	"""Handle save results button press"""
	print("PostBattleResultsUI: Saving battle results")
	_save_campaign_state()
	results_saved.emit()

## Utility Methods

func get_battle_summary() -> Dictionary:
	"""Get a summary of battle results for logging"""
	return {
		"victory": battle_results.get("victory", false),
		"rounds_fought": battle_results.get("rounds_fought", 0),
		"casualties": crew_casualties.size(),
		"injuries": crew_injuries.size(),
		"loot_items": loot_gained.size(),
		"credits_earned": credits_earned,
		"experience_awards": experience_gained.size()
	}