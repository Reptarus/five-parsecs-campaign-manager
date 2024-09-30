# Logbook.gd
extends Control

const LOGBOOK_DIR = "user://logbook/"
var current_campaign_turn: int = 0
var game_state: GameStateManager
var current_crew: String = ""

const CampaignDashboardScene = preload("res://Scenes/Scene Container/CampaignDashboard.tscn")

func _ready():
	create_logbook_directory()
	connect_signals()
	load_crews()

func create_logbook_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(LOGBOOK_DIR):
		dir.make_dir(LOGBOOK_DIR)

func connect_signals():
	$MarginContainer/HBoxContainer/Sidebar/CrewSelect.item_selected.connect(_on_crew_selected)
	$MarginContainer/HBoxContainer/Sidebar/EntryList.item_selected.connect(_on_entry_selected)
	$MarginContainer/HBoxContainer/Sidebar/ButtonsContainer/NewEntryButton.pressed.connect(_on_new_entry_pressed)
	$MarginContainer/HBoxContainer/Sidebar/ButtonsContainer/DeleteEntryButton.pressed.connect(_on_delete_entry_pressed)
	$MarginContainer/HBoxContainer/Sidebar/ExportButton.pressed.connect(_on_export_pressed)
	$MarginContainer/HBoxContainer/Sidebar/BackButton.pressed.connect(_on_back_pressed)
	$MarginContainer/HBoxContainer/MainContent/SaveButton.pressed.connect(_on_save_notes_pressed)

func load_crews():
	var crews = game_state.get_all_crews()  # Assuming this method exists in GameStateManager
	for crew in crews:
		$MarginContainer/HBoxContainer/Sidebar/CrewSelect.add_item(crew)

func _on_crew_selected(index):
	current_crew = $MarginContainer/HBoxContainer/Sidebar/CrewSelect.get_item_text(index)
	load_crew_entries()

func load_crew_entries():
	$MarginContainer/HBoxContainer/Sidebar/EntryList.clear()
	var dir = DirAccess.open(LOGBOOK_DIR + current_crew)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".txt"):
				$MarginContainer/HBoxContainer/Sidebar/EntryList.add_item(file_name.get_basename())
			file_name = dir.get_next()

func _on_entry_selected(index):
	var entry_name = $MarginContainer/HBoxContainer/Sidebar/EntryList.get_item_text(index)
	var content = load_entry(entry_name)
	$MarginContainer/HBoxContainer/MainContent/EntryContent.text = content

func _on_new_entry_pressed():
	current_campaign_turn += 1
	var entry_content = create_campaign_turn_summary(game_state)
	$MarginContainer/HBoxContainer/MainContent/EntryContent.text = entry_content
	save_entry("Turn_" + str(current_campaign_turn), entry_content)
	load_crew_entries()  # Refresh the entry list

func _on_delete_entry_pressed():
	var selected = $MarginContainer/HBoxContainer/Sidebar/EntryList.get_selected_items()
	if selected.size() > 0:
		var entry_name = $MarginContainer/HBoxContainer/Sidebar/EntryList.get_item_text(selected[0])
		delete_entry(entry_name)
		load_crew_entries()  # Refresh the entry list
		$MarginContainer/HBoxContainer/MainContent/EntryContent.text = ""

func _on_export_pressed():
	export_logbook()

func _on_back_pressed():
	SaveGame.change_scene_to_file(CampaignDashboardScene)

func _on_save_notes_pressed():
	var notes = $MarginContainer/HBoxContainer/MainContent/NotesEdit.text
	save_notes(notes)

func save_entry(entry_name, content):
	var file = FileAccess.open(LOGBOOK_DIR + current_crew + "/" + entry_name + ".txt", FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	else:
		push_error("Failed to save entry: " + entry_name)

func load_entry(entry_name):
	var file = FileAccess.open(LOGBOOK_DIR + current_crew + "/" + entry_name + ".txt", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	else:
		push_error("Failed to open file: " + entry_name)
		return ""

func delete_entry(entry_name):
	var dir = DirAccess.open(LOGBOOK_DIR + current_crew)
	dir.remove(entry_name + ".txt")

func save_notes(notes):
	var file = FileAccess.open(LOGBOOK_DIR + current_crew + "/notes.txt", FileAccess.WRITE)
	file.store_string(notes)
	file.close()

func load_notes():
	var file = FileAccess.open(LOGBOOK_DIR + current_crew + "/notes.txt", FileAccess.READ)
	if file:
		var notes = file.get_as_text()
		file.close()
		return notes
	return ""

func export_logbook():
	var export_path = "user://exported_logbook_" + current_crew + ".txt"
	var export_file = FileAccess.open(export_path, FileAccess.WRITE)
	if not export_file:
		push_error("Failed to create export file")
		return

	var dir = DirAccess.open(LOGBOOK_DIR + current_crew)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".txt"):
				var content = load_entry(file_name.get_basename())
				export_file.store_string(file_name + ":\n" + content + "\n\n")
			file_name = dir.get_next()
	else:
		push_error("Failed to open directory: " + LOGBOOK_DIR + current_crew)

	export_file.close()
	print("Logbook exported to: " + export_path)

# This function generates the campaign turn summary
func create_campaign_turn_summary(state: GameStateManager) -> String:
	var summary = ""
	
	# Add current turn number
	summary += "Turn " + str(state.campaign_turn) + "\n\n"
	
	# Add crew information
	summary += "Crew: " + state.current_crew.name + "\n"
	summary += "Credits: " + str(state.credits) + "\n"
	summary += "Reputation: " + str(state.reputation) + "\n\n"
	
	# Add information about each crew member
	summary += "Crew Members:\n"
	for member in state.current_crew.members:
		summary += "- " + member.name + " (" + GlobalEnums.Background.keys()[member.background] + ")\n"
		summary += "  Health: " + str(member.health_status) + "\n"
		summary += "  XP: " + str(member.experience) + "\n"
	summary += "\n"
	
	# Add information about current mission (if any)
	if state.current_mission:
		summary += "Current Mission: " + state.current_mission.name + "\n"
		summary += "Type: " + GlobalEnums.MissionType.keys()[state.current_mission.type] + "\n"
		summary += "Difficulty: " + str(state.current_mission.difficulty) + "\n\n"
	else:
		summary += "No current mission\n\n"
	
	# Add information about current location
	summary += "Current Location: " + state.current_location.name + "\n\n"
	
	# Add any notable events or changes from the last turn
	if state.last_mission_results:
		summary += "Notable Events:\n"
		summary += "- " + state.last_mission_results + "\n"
	
	return summary
