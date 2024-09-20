# CrewManagement.gd
extends Control

@onready var content_container = $HBoxContainer/MainContent/MarginContainer/ContentContainer
@onready var crew_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/CrewContent
@onready var ship_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/ShipContent
@onready var quests_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/QuestsContent
@onready var stash_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/StashContent

var game_state: GameState

signal crew_finalized

func _ready() -> void:
	game_state = get_node("/root/GameState")
	if not game_state:
		push_error("GameState not found. Make sure it's properly set up as an AutoLoad.")
		return
	update_all_content()
	show_content("crew")
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func update_all_content() -> void:
	update_crew_display()
	update_ship_info()
	update_quests_tab()
	update_ship_stash()

func update_crew_display() -> void:
	var crew_grid = crew_content.get_node("CrewGrid")
	for child in crew_grid.get_children():
		child.queue_free()
	
	var character_box_scene = preload("res://Scenes/Scene Container/campaigncreation/scenes/CharacterBox.tscn")
	for character in game_state.get_current_crew().characters:
		var character_box = character_box_scene.instantiate()
		character_box.set_character(character)
		character_box.pressed.connect(_on_character_selected.bind(character))
		crew_grid.add_child(character_box)

func update_ship_info() -> void:
	var ship = game_state.current_ship
	ship_content.get_node("ShipInfo/ShipName").text = "Ship: %s" % ship.name
	ship_content.get_node("ShipInfo/HullPoints").text = "Hull: %d/%d" % [ship.current_hull, ship.max_hull]
	ship_content.get_node("ShipInfo/Fuel").text = "Fuel: %d" % ship.fuel
	
	var components_list = ship_content.get_node("ShipInfo/ComponentsList")
	components_list.clear()
	for component in ship.components:
		components_list.add_item(component.name)
	
	ship_content.get_node("ShipInfo/Traits").text = "Traits: %s" % ", ".join(ship.traits)
	ship_content.get_node("ShipInfo/Debt").text = "Debt: %d" % ship.debt if ship.debt > 0 else ""

func update_quests_tab() -> void:
	for node in ["MissionResults", "MissionDetails", "NoMission", "MissionSelection"]:
		quests_content.get_node(node).hide()
	
	match game_state.current_state:
		GameState.State.POST_MISSION:
			var mission_results = quests_content.get_node("MissionResults")
			mission_results.show()
			mission_results.text = game_state.last_mission_results
		GameState.State.CAMPAIGN_TURN:
			if game_state.current_mission:
				var mission_details = quests_content.get_node("MissionDetails")
				mission_details.show()
				mission_details.text = game_state.current_mission.description
			else:
				quests_content.get_node("NoMission").show()
		GameState.State.MISSION:
			var mission_selection = quests_content.get_node("MissionSelection")
			mission_selection.show()
			var mission_list = mission_selection.get_node("MissionList")
			mission_list.clear()
			for mission in game_state.available_missions:
				mission_list.add_item(mission.title)

func update_ship_stash() -> void:
	var stash_list = stash_content.get_node("VBoxContainer/StashList")
	stash_list.clear()
	for item in game_state.get_ship_stash():
		stash_list.add_item(item.name)

func show_content(content_name: String) -> void:
	for child in content_container.get_children():
		child.hide()
	
	content_container.get_node(content_name.capitalize() + "Content").show()
	
	if get_viewport().size.x < 600:
		$HBoxContainer/Sidebar.visible = false
		$HBoxContainer/MainContent.visible = true

func _on_viewport_size_changed() -> void:
	var is_mobile = get_viewport().size.x < 600
	$HBoxContainer/Sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$HBoxContainer/Sidebar.size_flags_stretch_ratio = 1 if is_mobile else 0.2
	$HBoxContainer/MainContent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$HBoxContainer/MainContent.size_flags_stretch_ratio = 0 if is_mobile else 0.8
	$HBoxContainer/MainContent.visible = not is_mobile

func _on_crew_button_pressed() -> void:
	show_content("crew")

func _on_ship_button_pressed() -> void:
	show_content("ship")

func _on_quests_button_pressed() -> void:
	show_content("quests")

func _on_stash_button_pressed() -> void:
	show_content("stash")

func _on_character_selected(character) -> void:
	show_character_sheet(character)

func _on_sort_by_name_pressed() -> void:
	game_state.sort_ship_stash("name")
	update_ship_stash()

func _on_sort_by_recency_pressed() -> void:
	game_state.sort_ship_stash("recency")
	update_ship_stash()

func _on_sort_by_type_pressed() -> void:
	game_state.sort_ship_stash("type")
	update_ship_stash()

func show_character_sheet(character) -> void:
	var character_sheet = preload("res://Scenes/Scene Container/campaigncreation/scenes/CharacterSheet.tscn").instantiate()
	character_sheet.set_character(character)
	add_child(character_sheet)

func _on_finalize_crew_button_pressed() -> void:
	crew_finalized.emit()
