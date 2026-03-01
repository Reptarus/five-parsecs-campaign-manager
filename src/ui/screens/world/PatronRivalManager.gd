class_name PatronRivalManagerUI
extends Control

signal patron_selected(patron: Dictionary)
signal rival_selected(rival: Dictionary)
signal job_assigned(patron: Dictionary, job: Dictionary)

@onready var patrons_list: VBoxContainer = %PatronsList
@onready var rivals_list: VBoxContainer = %RivalsList
@onready var details_container: VBoxContainer = %DetailsContainer

# DataManager accessed via autoload singleton

var patrons: Array[Dictionary] = []
var rivals: Array[Dictionary] = []
var selected_patron: Dictionary = {}
var selected_rival: Dictionary = {}

# JSON data storage
var patron_templates: Dictionary = {}
var rival_templates: Dictionary = {}
var job_templates: Dictionary = {}

func _ready() -> void:
	print("PatronRivalManager: Initializing with JSON data support...")
	_load_json_templates()
	_load_patrons_and_rivals()
	_refresh_displays()

func _load_json_templates() -> void:
	## Load JSON template data for enhanced patron/rival generation
	# Load patron templates
	patron_templates = DataManager.load_json_file("res://data/patrons/patron_templates.json")
	if patron_templates.is_empty():
		print("PatronRivalManager: patron_templates.json not found, creating fallback data")
		_create_patron_templates_fallback()
	else:
		print("PatronRivalManager: Loaded %d patron categories from JSON" % patron_templates.get("patron_categories", []).size())
	
	# Load rival templates
	rival_templates = DataManager.load_json_file("res://data/rivals/rival_templates.json")
	if rival_templates.is_empty():
		print("PatronRivalManager: rival_templates.json not found, creating fallback data")
		_create_rival_templates_fallback()
	else:
		print("PatronRivalManager: Loaded %d rival categories from JSON" % rival_templates.get("rival_categories", []).size())
	
	# Load job templates
	job_templates = DataManager.load_json_file("res://data/jobs/job_templates.json")
	if job_templates.is_empty():
		print("PatronRivalManager: job_templates.json not found, creating fallback data")
		_create_job_templates_fallback()
	else:
		print("PatronRivalManager: Loaded %d job types from JSON" % job_templates.get("job_types", []).size())

func _create_patron_templates_fallback() -> void:
	## Create fallback patron templates when JSON is not available
	patron_templates = {
		"patron_categories": [
			{
				"type": "Corporate",
				"names": ["Director Johnson", "Executive Martinez", "Chairman Wu", "VP Anderson"],
				"base_jobs": 3,
				"relationship_range": ["Neutral", "Friendly", "Business"],
				"special_rules": ["High-paying missions", "Corporate resources", "Dangerous assignments"],
				"job_multiplier": 1.5
			},
			{
				"type": "Government",
				"names": ["Captain Torres", "Sheriff Blake", "Commander Singh", "Marshal Carter"],
				"base_jobs": 2,
				"relationship_range": ["Neutral", "Friendly", "Allied"],
				"special_rules": ["Law enforcement", "Public safety", "Authority backing"],
				"job_multiplier": 1.2
			},
			{
				"type": "Independent",
				"names": ["Trader Kim", "Explorer Voss", "Merchant Chen", "Captain Reeves"],
				"base_jobs": 2,
				"relationship_range": ["Neutral", "Friendly"],
				"special_rules": ["Flexible missions", "Trade bonuses", "Exploration focus"],
				"job_multiplier": 1.0
			},
			{
				"type": "Faction",
				"names": ["Agent Smith", "Delegate Rhodes", "Representative Liu", "Ambassador Kane"],
				"base_jobs": 3,
				"relationship_range": ["Neutral", "Allied", "Hostile"],
				"special_rules": ["Faction politics", "Territory disputes", "Diplomatic missions"],
				"job_multiplier": 1.3
			}
		]
	}

func _create_rival_templates_fallback() -> void:
	## Create fallback rival templates when JSON is not available
	rival_templates = {
		"rival_categories": [
			{
				"type": "Military",
				"names": ["Black Squadron", "Steel Legion", "Iron Guard", "Crimson Company"],
				"threat_levels": ["Medium", "High", "Extreme"],
				"special_rules": ["Military tactics", "Advanced equipment", "Coordinated attacks"],
				"equipment_bonus": 1.5
			},
			{
				"type": "Criminal",
				"names": ["The Syndicate", "Shadow Cartel", "Blood Ravens", "Void Pirates"],
				"threat_levels": ["Low", "Medium", "High"],
				"special_rules": ["Underhanded tactics", "Criminal networks", "Illegal equipment"],
				"equipment_bonus": 1.2
			},
			{
				"type": "Corporate",
				"names": ["SecCorp Strike Team", "Industrial Enforcers", "Corporate Security", "Executive Guard"],
				"threat_levels": ["Medium", "High"],
				"special_rules": ["Corporate backing", "High-tech gear", "Professional training"],
				"equipment_bonus": 1.4
			},
			{
				"type": "Raider",
				"names": ["Iron Wolves", "Red Hawks", "Void Hunters", "Storm Riders"],
				"threat_levels": ["Low", "Medium", "High"],
				"special_rules": ["Hit-and-run tactics", "Salvaged equipment", "Tribal warfare"],
				"equipment_bonus": 0.8
			}
		]
	}

func _create_job_templates_fallback() -> void:
	## Create fallback job templates when JSON is not available
	job_templates = {
		"job_types": [
			{
				"type": "Escort",
				"descriptions": [
					"Escort valuable cargo through dangerous territory",
					"Protect VIP during dangerous journey",
					"Guard supply convoy to frontier outpost"
				],
				"base_payment": [4, 6],
				"difficulty_range": [1, 3]
			},
			{
				"type": "Investigation",
				"descriptions": [
					"Investigate suspicious activity at mining facility",
					"Uncover corporate espionage operation",
					"Research mysterious alien artifacts"
				],
				"base_payment": [3, 5],
				"difficulty_range": [2, 4]
			},
			{
				"type": "Recovery",
				"descriptions": [
					"Recover stolen data from criminal hideout",
					"Retrieve lost expedition equipment",
					"Salvage valuable technology from crash site"
				],
				"base_payment": [3, 7],
				"difficulty_range": [2, 4]
			},
			{
				"type": "Defense",
				"descriptions": [
					"Protect civilians during evacuation",
					"Defend settlement from raider attacks",
					"Hold strategic position against enemy forces"
				],
				"base_payment": [4, 6],
				"difficulty_range": [2, 5]
			},
			{
				"type": "Pursuit",
				"descriptions": [
					"Hunt down escaped prisoners",
					"Track notorious bounty targets",
					"Pursue fleeing enemy operatives"
				],
				"base_payment": [5, 8],
				"difficulty_range": [3, 5]
			}
		]
	}

func _load_patrons_and_rivals() -> void:
	## Load patrons and rivals from GameStateManager (single source of truth)
	# Primary: Load from GameStateManager
	if GameStateManager:
		var loaded_patrons: Array = GameStateManager.get_patrons()
		var loaded_rivals: Array = GameStateManager.get_rivals()

		# Convert to typed arrays
		patrons.clear()
		for p in loaded_patrons:
			if p is Dictionary:
				patrons.append(p)

		rivals.clear()
		for r in loaded_rivals:
			if r is Dictionary:
				rivals.append(r)

		print("PatronRivalManager: Loaded %d patrons, %d rivals from GameStateManager" % [patrons.size(), rivals.size()])
	else:
		push_warning("PatronRivalManager: GameStateManager not available")

	# Enhanced fallback using JSON templates if no data exists
	if patrons.is_empty():
		_generate_patrons_from_templates()
		# Save generated patrons to GameState for persistence
		_save_patrons_to_gamestate()

	if rivals.is_empty():
		_generate_rivals_from_templates()
		# Save generated rivals to GameState for persistence
		_save_rivals_to_gamestate()

func _save_patrons_to_gamestate() -> void:
	## Save current patrons to GameStateManager for persistence
	if not GameStateManager:
		return

	if not GameStateManager.game_state or not "current_campaign" in GameStateManager.game_state:
		return

	var campaign = GameStateManager.game_state.current_campaign
	campaign.patrons = patrons.duplicate(true)
	print("PatronRivalManager: Saved %d patrons to GameState" % patrons.size())

func _save_rivals_to_gamestate() -> void:
	## Save current rivals to GameStateManager for persistence
	if not GameStateManager:
		return

	if not GameStateManager.game_state or not "current_campaign" in GameStateManager.game_state:
		return

	var campaign = GameStateManager.game_state.current_campaign
	campaign.rivals = rivals.duplicate(true)
	print("PatronRivalManager: Saved %d rivals to GameState" % rivals.size())

func _generate_patrons_from_templates() -> void:
	## Generate patrons using JSON template data
	var patron_categories = patron_templates.get("patron_categories", [])
	
	for i in range(2): # Generate 2 patrons initially
		if not patron_categories.is_empty():
			var category = patron_categories[randi() % patron_categories.size()]
			var new_patron = _create_patron_from_template(category)
			patrons.append(new_patron)

func _generate_rivals_from_templates() -> void:
	## Generate rivals using JSON template data
	var rival_categories = rival_templates.get("rival_categories", [])
	
	for i in range(2): # Generate 2 rivals initially
		if not rival_categories.is_empty():
			var category = rival_categories[randi() % rival_categories.size()]
			var new_rival = _create_rival_from_template(category)
			rivals.append(new_rival)

func _create_patron_from_template(template: Dictionary) -> Dictionary:
	## Create a patron from a JSON template
	var names = template.get("names", ["Unknown Patron"])
	var relationships = template.get("relationship_range", ["Neutral"])
	var rules = template.get("special_rules", ["Standard patron"])
	
	return {
		"name": names[randi() % names.size()],
		"type": template.get("type", "Unknown"),
		"status": "Active",
		"jobs_offered": template.get("base_jobs", 2) + randi_range(-1, 1),
		"relationship": relationships[randi() % relationships.size()],
		"special_rules": rules[randi() % rules.size()],
		"job_multiplier": template.get("job_multiplier", 1.0)
	}

func _create_rival_from_template(template: Dictionary) -> Dictionary:
	## Create a rival from a JSON template
	var names = template.get("names", ["Unknown Rival"])
	var threat_levels = template.get("threat_levels", ["Medium"])
	var rules = template.get("special_rules", ["Standard rival"])
	
	return {
		"name": names[randi() % names.size()],
		"type": template.get("type", "Unknown"),
		"status": "Active",
		"threat_level": threat_levels[randi() % threat_levels.size()],
		"relationship": "Hostile",
		"special_rules": rules[randi() % rules.size()],
		"equipment_bonus": template.get("equipment_bonus", 1.0)
	}

func _refresh_displays() -> void:
	## Refresh all display lists
	_refresh_patrons_list()
	_refresh_rivals_list()

func _refresh_patrons_list() -> void:
	## Refresh the patrons list display
	# Clear existing items
	for child in patrons_list.get_children():
		child.queue_free()

	# Add patron items
	for patron in patrons:
		var patron_panel: Panel = _create_patron_panel(patron)
		patrons_list.add_child(patron_panel)

func _refresh_rivals_list() -> void:
	## Refresh the rivals list display
	# Clear existing items
	for child in rivals_list.get_children():
		child.queue_free()

	# Add rival items
	for rival in rivals:
		var rival_panel: Panel = _create_rival_panel(rival)
		rivals_list.add_child(rival_panel)

func _create_patron_panel(patron: Dictionary) -> Control:
	## Create a panel for a patron
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Name and type
	var name_label: Label = Label.new()
	name_label.text = patron.name + " (" + patron.type + ")"
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Status and relationship
	var status_label: Label = Label.new()
	status_label.text = "Status: " + patron.status + " | " + patron.relationship
	vbox.add_child(status_label)

	# Jobs offered
	var jobs_label: Label = Label.new()
	jobs_label.text = "Jobs Available: " + str(patron.jobs_offered)
	vbox.add_child(jobs_label)

	# Select button
	var select_button: Button = Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_patron_selected.bind(patron))
	vbox.add_child(select_button)

	return panel

func _create_rival_panel(rival: Dictionary) -> Control:
	## Create a panel for a rival
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Name and type
	var name_label: Label = Label.new()
	name_label.text = rival.name + " (" + rival.type + ")"
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# Threat level and relationship
	var threat_label: Label = Label.new()
	threat_label.text = "Threat: " + rival.threat_level + " | " + rival.relationship
	vbox.add_child(threat_label)

	# Status
	var status_label: Label = Label.new()
	status_label.text = "Status: " + rival.status
	vbox.add_child(status_label)

	# Select button
	var select_button: Button = Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_rival_selected.bind(rival))
	vbox.add_child(select_button)

	return panel

func _update_details(entity: Dictionary, is_patron: bool) -> void:
	## Update the details panel
	# Clear existing details
	for child in details_container.get_children():
		child.queue_free()

	if entity.is_empty():
		return

	# Entity name
	var name_label: Label = Label.new()
	name_label.text = entity.name
	name_label.add_theme_font_size_override("font_size", 20)
	details_container.add_child(name_label)

	# Type
	var type_label: Label = Label.new()
	type_label.text = "Type: " + entity.type
	details_container.add_child(type_label)

	# Status
	var status_label: Label = Label.new()
	status_label.text = "Status: " + entity.status
	details_container.add_child(status_label)

	# Relationship
	var relationship_label: Label = Label.new()
	relationship_label.text = "Relationship: " + entity.relationship
	details_container.add_child(relationship_label)

	if is_patron:
		# Jobs offered
		var jobs_label: Label = Label.new()
		jobs_label.text = "Jobs Available: " + str(entity.jobs_offered)
		details_container.add_child(jobs_label)

		# Offer job button
		var job_button: Button = Button.new()
		job_button.text = "Get Job Offer"
		job_button.pressed.connect(_on_request_job.bind(entity))
		details_container.add_child(job_button)
	else:
		# Threat level
		var threat_label: Label = Label.new()
		threat_label.text = "Threat Level: " + entity.threat_level
		details_container.add_child(threat_label)

	# Special rules
	if entity.has("special_rules"):
		var rules_label: Label = Label.new()
		rules_label.text = "Special Rules:"
		rules_label.add_theme_font_size_override("font_size", 14)
		details_container.add_child(rules_label)

		var rules_text = Label.new()
		rules_text.text = entity.special_rules
		rules_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details_container.add_child(rules_text)

func _generate_patron() -> Dictionary:
	## Generate a new patron using JSON templates
	var patron_categories = patron_templates.get("patron_categories", [])
	
	if patron_categories.is_empty():
		push_warning("PatronRivalManager: No patron categories available for generation")
		return {}
	
	var category = patron_categories[randi() % patron_categories.size()]
	return _create_patron_from_template(category)

func _generate_rival() -> Dictionary:
	## Generate a new rival using JSON templates
	var rival_categories = rival_templates.get("rival_categories", [])
	
	if rival_categories.is_empty():
		push_warning("PatronRivalManager: No rival categories available for generation")
		return {}
	
	var category = rival_categories[randi() % rival_categories.size()]
	return _create_rival_from_template(category)

func _on_patron_selected(patron: Dictionary) -> void:
	## Handle patron selection
	selected_patron = patron
	selected_rival = {}
	_update_details(patron, true)
	patron_selected.emit(patron)

func _on_rival_selected(rival: Dictionary) -> void:
	## Handle rival selection
	selected_rival = rival
	selected_patron = {}
	_update_details(rival, false)
	rival_selected.emit(rival)

func _on_request_job(patron: Dictionary) -> void:
	## Request a job from selected patron
	if patron.jobs_offered > 0:
		var job = _generate_job_offer(patron)
		patron["jobs_offered"] -= 1
		_refresh_displays()
		job_assigned.emit(patron, job)
		print("Job offered by ", patron.name, ": ", job.description)

func _generate_job_offer(patron: Dictionary) -> Dictionary:
	## Generate a job offer from a patron using JSON templates
	var job_types = job_templates.get("job_types", [])
	
	if job_types.is_empty():
		push_warning("PatronRivalManager: No job types available for generation")
		return {
			"type": "Unknown",
			"description": "Generic job assignment",
			"payment": 3,
			"patron": patron.get("name", "Unknown Patron")
		}
	
	var job_type = job_types[randi() % job_types.size()]
	var descriptions = job_type.get("descriptions", ["Unknown job"])
	var payment_range = job_type.get("base_payment", [3, 5])
	var difficulty_range = job_type.get("difficulty_range", [1, 3])
	
	# Apply patron job multiplier if available
	var base_payment = randi_range(payment_range[0], payment_range[1])
	var patron_multiplier = patron.get("job_multiplier", 1.0)
	var final_payment = int(base_payment * patron_multiplier)
	
	return {
		"type": job_type.get("type", "Unknown"),
		"description": descriptions[randi() % descriptions.size()],
		"payment": final_payment,
		"difficulty": randi_range(difficulty_range[0], difficulty_range[1]),
		"patron": patron.get("name", "Unknown Patron"),
		"patron_type": patron.get("type", "Unknown")
	}

func _on_back_pressed() -> void:
	## Handle back button press
	print("PatronRivalManager: Back pressed")
	SceneRouter.navigate_back()

func _on_add_patron_pressed() -> void:
	## Handle add patron button press
	print("PatronRivalManager: Add patron pressed")

func _on_add_rival_pressed() -> void:
	## Handle add rival button press
	print("PatronRivalManager: Add rival pressed")

func _on_generate_patron_pressed() -> void:
	## Handle generate patron button press
	var new_patron = _generate_patron()
	patrons.append(new_patron)
	_refresh_displays()
	print("Generated new patron: ", new_patron.name)

func _on_generate_rival_pressed() -> void:
	## Handle generate rival button press
	var new_rival = _generate_rival()
	rivals.append(new_rival)
	_refresh_displays()
	print("Generated new rival: ", new_rival.name)

func _on_manage_jobs_pressed() -> void:
	## Handle manage jobs button press
	print("PatronRivalManager: Manage jobs pressed")
	_open_job_management_interface()

func _open_job_management_interface() -> void:
	## Open job management interface for patron job assignment
	# Create job management dialog
	var job_dialog = _create_job_management_dialog()
	
	if job_dialog:
		# Add to scene tree and display
		get_tree().current_scene.add_child(job_dialog)
		job_dialog.popup_centered_ratio(0.8)
		
		# Connect job assignment signal
		if not job_dialog.job_assigned.is_connected(_on_job_assigned_from_dialog):
			job_dialog.job_assigned.connect(_on_job_assigned_from_dialog)
		
		print("PatronRivalManager: Job management interface opened")
	else:
		push_error("PatronRivalManager: Failed to create job management dialog")

func _create_job_management_dialog() -> Control:
	## Create job management dialog with patron job assignment functionality
	var dialog = AcceptDialog.new()
	dialog.title = "Job Management"
	dialog.set_flag(Window.FLAG_RESIZE_DISABLED, false)
	
	# Create main container
	var main_container = VBoxContainer.new()
	dialog.add_child(main_container)
	
	# Create job assignment section
	var job_section = _create_job_assignment_section()
	main_container.add_child(job_section)
	
	# Create available jobs section
	var available_jobs_section = _create_available_jobs_section()
	main_container.add_child(available_jobs_section)
	
	# Create action buttons
	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)
	
	var assign_button = Button.new()
	assign_button.text = "Assign Selected Job"
	assign_button.pressed.connect(_on_assign_job_pressed.bind(dialog))
	button_container.add_child(assign_button)
	
	var generate_button = Button.new()
	generate_button.text = "Generate New Job"
	generate_button.pressed.connect(_on_generate_job_pressed.bind(dialog))
	button_container.add_child(generate_button)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(dialog.queue_free)
	button_container.add_child(close_button)
	
	# Add custom signal for job assignment
	dialog.add_user_signal("job_assigned", [{"name": "patron", "type": TYPE_DICTIONARY}, {"name": "job", "type": TYPE_DICTIONARY}])
	
	return dialog

func _create_job_assignment_section() -> Control:
	## Create job assignment section with patron selection
	var section = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Available Patrons:"
	section.add_child(label)
	
	var patron_list = ItemList.new()
	patron_list.name = "PatronList"
	patron_list.custom_minimum_size = Vector2(300, 150)
	
	# Populate with current patrons
	for i in range(patrons.size()):
		var patron = patrons[i]
		var patron_text = "%s (%s)" % [patron.get("name", "Unknown"), patron.get("type", "Unknown")]
		patron_list.add_item(patron_text)
	
	section.add_child(patron_list)
	
	return section

func _create_available_jobs_section() -> Control:
	## Create available jobs section with job listings
	var section = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Available Jobs:"
	section.add_child(label)
	
	var job_list = ItemList.new()
	job_list.name = "JobList"
	job_list.custom_minimum_size = Vector2(300, 200)
	
	# Generate and populate available jobs
	var available_jobs = _generate_available_jobs()
	for i in range(available_jobs.size()):
		var job = available_jobs[i]
		var job_text = "%s - %s credits (%s)" % [job.get("title", "Unknown Job"), job.get("payment", 0), job.get("difficulty", "Normal")]
		job_list.add_item(job_text)
		job_list.set_item_metadata(i, job)
	
	section.add_child(job_list)
	
	return section

func _generate_available_jobs() -> Array[Dictionary]:
	## Generate available jobs using JSON template data
	var available_jobs: Array[Dictionary] = []
	
	if job_templates.has("job_categories"):
		var job_categories = job_templates.job_categories
		
		# Generate 3-5 random jobs
		var num_jobs = randi_range(3, 5)
		for i in range(num_jobs):
			var category = job_categories[randi() % job_categories.size()]
			var job = _create_job_from_template(category)
			available_jobs.append(job)
	else:
		# Fallback job generation
		available_jobs = [
			{"title": "Escort Convoy", "payment": 2000, "difficulty": "Normal", "type": "escort", "danger_level": 2},
			{"title": "Investigate Outpost", "payment": 1500, "difficulty": "Easy", "type": "investigation", "danger_level": 1},
			{"title": "Clear Pirate Base", "payment": 3500, "difficulty": "Hard", "type": "combat", "danger_level": 4},
			{"title": "Deliver Supplies", "payment": 1200, "difficulty": "Easy", "type": "delivery", "danger_level": 1}
		]
	
	return available_jobs

func _create_job_from_template(category: Dictionary) -> Dictionary:
	## Create job from template category
	var base_payment = category.get("base_payment", 1000)
	var payment_variance = randi_range(-200, 500)
	
	return {
		"title": category.get("name", "Unknown Job"),
		"description": category.get("description", "A job that needs doing."),
		"payment": base_payment + payment_variance,
		"difficulty": category.get("difficulty", "Normal"),
		"type": category.get("type", "general"),
		"danger_level": category.get("danger_level", 2),
		"requirements": category.get("requirements", []),
		"estimated_duration": category.get("estimated_duration", "1-2 hours")
	}

func _on_assign_job_pressed(dialog: Control) -> void:
	## Handle job assignment button press
	var patron_list = dialog.find_child("PatronList")
	var job_list = dialog.find_child("JobList")
	
	if patron_list and job_list:
		var selected_patron_idx = patron_list.get_selected_items()
		var selected_job_idx = job_list.get_selected_items()
		
		if selected_patron_idx.size() > 0 and selected_job_idx.size() > 0:
			var patron = patrons[selected_patron_idx[0]]
			var job = job_list.get_item_metadata(selected_job_idx[0])
			
			# Emit job assignment signal
			dialog.emit_signal("job_assigned", patron, job)
			
			print("PatronRivalManager: Assigned job '%s' to patron '%s'" % [job.get("title", "Unknown"), patron.get("name", "Unknown")])
		else:
			_show_assignment_error("Please select both a patron and a job to assign.")
	else:
		push_error("PatronRivalManager: Could not find patron or job lists in dialog")

func _on_generate_job_pressed(dialog: Control) -> void:
	## Handle generate new job button press
	var job_list = dialog.find_child("JobList")
	
	if job_list:
		# Generate new job
		var new_jobs = _generate_available_jobs()
		if new_jobs.size() > 0:
			var new_job = new_jobs[0]  # Take first generated job
			var job_text = "%s - %s credits (%s)" % [new_job.get("title", "Unknown Job"), new_job.get("payment", 0), new_job.get("difficulty", "Normal")]
			
			var item_idx = job_list.add_item(job_text)
			job_list.set_item_metadata(item_idx, new_job)
			
			print("PatronRivalManager: Generated new job: %s" % new_job.get("title", "Unknown"))
		else:
			push_error("PatronRivalManager: Failed to generate new job")
	else:
		push_error("PatronRivalManager: Could not find job list in dialog")

func _on_job_assigned_from_dialog(patron: Dictionary, job: Dictionary) -> void:
	## Handle job assignment from dialog
	# Add job to patron's active jobs
	if not patron.has("active_jobs"):
		patron["active_jobs"] = []

	patron.active_jobs.append(job)

	# Emit the main job assignment signal
	job_assigned.emit(patron, job)

	# Save updated patrons to GameState for persistence
	_save_patrons_to_gamestate()

	# Refresh displays to show updated patron information
	_refresh_displays()

	print("PatronRivalManager: Job assignment completed - '%s' assigned to '%s'" % [job.get("title", "Unknown"), patron.get("name", "Unknown")])

func _show_assignment_error(message: String) -> void:
	## Show error message for job assignment
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Assignment Error"
	
	get_tree().current_scene.add_child(error_dialog)
	error_dialog.popup_centered()
	
	# Auto-remove after user closes
	error_dialog.confirmed.connect(error_dialog.queue_free)
	error_dialog.canceled.connect(error_dialog.queue_free)
