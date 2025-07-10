class_name PatronRivalManagerUI
extends Control

signal patron_selected(patron: Dictionary)
signal rival_selected(rival: Dictionary)
signal job_assigned(patron: Dictionary, job: Dictionary)

@onready var patrons_list: VBoxContainer = %PatronsList
@onready var rivals_list: VBoxContainer = %RivalsList
@onready var details_container: VBoxContainer = %DetailsContainer

var patrons: Array[Dictionary] = []
var rivals: Array[Dictionary] = []
var selected_patron: Dictionary = {}
var selected_rival: Dictionary = {}

func _ready() -> void:
	print("PatronRivalManager: Initializing...")
	_load_patrons_and_rivals()
	_refresh_displays()

func _load_patrons_and_rivals() -> void:
	"""Load patrons and rivals from campaign data"""
	var systems_autoload: Node = get_node_or_null("/root/SystemsAutoload")
	if not systems_autoload:
		push_error("SystemsAutoload not available")
		return

	# Load patrons from the consolidated PatronSystem
	patrons = systems_autoload.get_active_patrons()

	# Load rivals from the consolidated FactionSystem
	rivals = systems_autoload.get_active_rivals()

	# Fallback to sample data if systems aren't ready
	if (safe_call_method(patrons, "is_empty") == true):
		patrons = [
			{
				"name": "Corporate Executive",
				"type": "Corporate",
				"status": "Active",
				"jobs_offered": 3,
				"relationship": "Neutral",
				"special_rules": "Pays well but dangerous jobs"
			},
			{
				"name": "Frontier Sheriff",
				"type": "Government",
				"status": "Active",
				"jobs_offered": 2,
				"relationship": "Friendly",
				"special_rules": "Law enforcement missions"
			}
		]

	if (safe_call_method(rivals, "is_empty") == true):
		rivals = [
			{
				"name": "Black Squadron",
				"type": "Military",
				"status": "Active",
				"threat_level": "High",
				"relationship": "Hostile",
				"special_rules": "Elite mercenary unit, advanced equipment"
			},
			{
				"name": "The Syndicate",
				"type": "Criminal",
				"status": "Active",
				"threat_level": "Medium",
				"relationship": "Hostile",
				"special_rules": "Criminal organization, underhanded tactics"
			}
		]

func _refresh_displays() -> void:
	"""Refresh all display lists"""
	_refresh_patrons_list()
	_refresh_rivals_list()

func _refresh_patrons_list() -> void:
	"""Refresh the patrons list display"""
	# Clear existing items
	for child in patrons_list.get_children():
		child.queue_free()

	# Add patron items
	for patron in patrons:
		var patron_panel: Panel = _create_patron_panel(patron)
		patrons_list.add_child(patron_panel)

func _refresh_rivals_list() -> void:
	"""Refresh the rivals list display"""
	# Clear existing items
	for child in rivals_list.get_children():
		child.queue_free()

	# Add rival items
	for rival in rivals:
		var rival_panel: Panel = _create_rival_panel(rival)
		rivals_list.add_child(rival_panel)

func _create_patron_panel(patron: Dictionary) -> Control:
	"""Create a panel for a patron"""
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
	"""Create a panel for a rival"""
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
	"""Update the details panel"""
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
	"""Generate a new patron using tables"""
	var patron_types = ["Corporate", "Government", "Independent", "Faction", "Criminal"]
	var patron_names = ["Director Johnson", "Captain Torres", "Elder Voss", "Agent Smith", "Boss Carrera"]

	var new_patron = {
		"name": patron_names[randi() % patron_names.size()],
		"type": patron_types[randi() % patron_types.size()],
		"status": "Active",
		"jobs_offered": randi_range(1, 3),
		"relationship": "Neutral",
		"special_rules": "Standard patron rules apply"
	}

	return new_patron

func _generate_rival() -> Dictionary:
	"""Generate a new rival using tables"""
	var rival_types = ["Military", "Criminal", "Corporate", "Alien", "Raider"]
	var rival_names = ["Shadow Company", "Steel Legion", "Iron Wolves", "Red Hawks", "Void Hunters"]
	var threat_levels = ["Low", "Medium", "High"]

	var new_rival = {
		"name": rival_names[randi() % rival_names.size()],
		"type": rival_types[randi() % rival_types.size()],
		"status": "Active",
		"threat_level": threat_levels[randi() % threat_levels.size()],
		"relationship": "Hostile",
		"special_rules": "Standard rival rules apply"
	}

	return new_rival

func _on_patron_selected(patron: Dictionary) -> void:
	"""Handle patron selection"""
	selected_patron = patron
	selected_rival = {}
	_update_details(patron, true)
	patron_selected.emit(patron)

func _on_rival_selected(rival: Dictionary) -> void:
	"""Handle rival selection"""
	selected_rival = rival
	selected_patron = {}
	_update_details(rival, false)
	rival_selected.emit(rival)

func _on_request_job(patron: Dictionary) -> void:
	"""Request a job from selected patron"""
	if patron.jobs_offered > 0:
		var job = _generate_job_offer(patron)
		patron["jobs_offered"] -= 1
		_refresh_displays()
		job_assigned.emit(patron, job)
		print("Job offered by ", patron.name, ": ", job.description)

func _generate_job_offer(patron: Dictionary) -> Dictionary:
	"""Generate a job offer from a patron"""
	var job_types = ["Opportunist", "Patron", "Rivals"]
	var descriptions = [
		"Escort valuable cargo through dangerous territory",
		"Investigate suspicious activity at mining facility",
		"Recover stolen data from criminal hideout",
		"Protect civilians during evacuation",
		"Hunt down escaped prisoners"
	]

	return {
		"type": job_types[randi() % job_types.size()],
		"description": descriptions[randi() % descriptions.size()],
		"payment": randi_range(3, 8),
		"patron": patron.name
	}

func _on_back_pressed() -> void:
	"""Handle back button press"""
	print("PatronRivalManager: Back pressed")
	if has_node("/root/SceneRouter"):
		var scene_router = get_node("/root/SceneRouter")
		scene_router.navigate_back()
	else:
		get_tree().change_scene_to_file("res://src/ui/screens/main/MainMenu.tscn")

func _on_add_patron_pressed() -> void:
	"""Handle add patron button press"""
	print("PatronRivalManager: Add patron pressed")

func _on_add_rival_pressed() -> void:
	"""Handle add rival button press"""
	print("PatronRivalManager: Add rival pressed")

func _on_generate_patron_pressed() -> void:
	"""Handle generate patron button press"""
	var new_patron = _generate_patron()
	patrons.append(new_patron)
	_refresh_displays()
	print("Generated new patron: ", new_patron.name)

func _on_generate_rival_pressed() -> void:
	"""Handle generate rival button press"""
	var new_rival = _generate_rival()
	rivals.append(new_rival)
	_refresh_displays()
	print("Generated new rival: ", new_rival.name)

func _on_manage_jobs_pressed() -> void:
	"""Handle manage jobs button press"""
	print("PatronRivalManager: Manage jobs pressed")
	# TODO: Open job management interface
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null