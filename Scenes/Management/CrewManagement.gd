# CrewManagement.gd
extends Control

@onready var content_container = $HBoxContainer/MainContent/MarginContainer/ContentContainer
@onready var crew_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/CrewContent
@onready var ship_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/ShipContent
@onready var quests_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/QuestsContent
@onready var stash_content = $HBoxContainer/MainContent/MarginContainer/ContentContainer/StashContent

var game_state: GameState

# warning-ignore:unused_signal
signal crew_finalized

func _ready():
    game_state = get_node("/root/GameState")
    update_all_content()
    show_content("crew")
    get_viewport().connect("size_changed", _on_viewport_size_changed)
    _on_viewport_size_changed()

func update_all_content():
    update_crew_display()
    update_ship_info()
    update_quests_tab()
    update_ship_stash()

func update_crew_display():
    for child in crew_content.get_node("CrewGrid").get_children():
        child.queue_free()
    
    for character in game_state.get_current_crew().characters:
        var character_box = preload("res://Scenes/Scene Container/campaigncreation/scenes/CharacterBox.tscn").instantiate()
        character_box.set_character(character)
        character_box.connect("pressed", _on_character_selected.bind(character))
        crew_content.get_node("CrewGrid").add_child(character_box)

func update_ship_info():
    var ship = game_state.current_ship
    ship_content.get_node("ShipInfo/ShipName").text = "Ship: " + ship.name
    ship_content.get_node("ShipInfo/HullPoints").text = "Hull: %d/%d" % [ship.current_hull, ship.max_hull]
    ship_content.get_node("ShipInfo/Fuel").text = "Fuel: %d" % ship.fuel
    
    var components_list = ship_content.get_node("ShipInfo/ComponentsList")
    components_list.clear()
    for component in ship.components:
        components_list.add_item(component.name)
    
    ship_content.get_node("ShipInfo/Traits").text = "Traits: " + ", ".join(ship.traits)
    ship_content.get_node("ShipInfo/Debt").text = "Debt: %d" % ship.debt if ship.debt > 0 else ""

func update_quests_tab():
    quests_content.get_node("MissionResults").hide()
    quests_content.get_node("MissionDetails").hide()
    quests_content.get_node("NoMission").hide()
    quests_content.get_node("MissionSelection").hide()
    
    match game_state.current_state:
        GameState.State.POST_MISSION:
            quests_content.get_node("MissionResults").show()
            quests_content.get_node("MissionResults").text = game_state.last_mission_results
        GameState.State.CAMPAIGN_TURN:
            if game_state.current_mission:
                quests_content.get_node("MissionDetails").show()
                quests_content.get_node("MissionDetails").text = game_state.current_mission.description
            else:
                quests_content.get_node("NoMission").show()
        GameState.State.MISSION:
            quests_content.get_node("MissionSelection").show()
            var mission_list = quests_content.get_node("MissionSelection/MissionList")
            mission_list.clear()
            for mission in game_state.available_missions:
                mission_list.add_item(mission.title)

func update_ship_stash():
    var stash_list = stash_content.get_node("VBoxContainer/StashList")
    stash_list.clear()
    for item in game_state.get_ship_stash():
        stash_list.add_item(item.name)

func show_content(content_name: String):
    for child in content_container.get_children():
        child.hide()
    
    match content_name:
        "crew":
            crew_content.show()
        "ship":
            ship_content.show()
        "quests":
            quests_content.show()
        "stash":
            stash_content.show()
    
    if get_viewport().size.x < 600:
        $HBoxContainer/Sidebar.visible = false
        $HBoxContainer/MainContent.visible = true

func _on_viewport_size_changed():
    var viewport_size = get_viewport().size
    if viewport_size.x < 600:  # Adjust this value as needed
        # Mobile layout
        $HBoxContainer/Sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        $HBoxContainer/Sidebar.size_flags_stretch_ratio = 1
        $HBoxContainer/MainContent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        $HBoxContainer/MainContent.size_flags_stretch_ratio = 0
        $HBoxContainer/MainContent.visible = false
    else:
        # Desktop layout
        $HBoxContainer/Sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        $HBoxContainer/Sidebar.size_flags_stretch_ratio = 0.2
        $HBoxContainer/MainContent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        $HBoxContainer/MainContent.size_flags_stretch_ratio = 0.8
        $HBoxContainer/MainContent.visible = true

func _on_crew_button_pressed():
    show_content("crew")

func _on_ship_button_pressed():
    show_content("ship")

func _on_quests_button_pressed():
    show_content("quests")

func _on_stash_button_pressed():
    show_content("stash")

func _on_character_selected(character):
    show_character_sheet(character)

func _on_sort_by_name_pressed():
    game_state.sort_ship_stash("name")
    update_ship_stash()

func _on_sort_by_recency_pressed():
    game_state.sort_ship_stash("recency")
    update_ship_stash()

func _on_sort_by_type_pressed():
    game_state.sort_ship_stash("type")
    update_ship_stash()

func show_character_sheet(character):
    var character_sheet = preload("res://Scenes/Scene Container/campaigncreation/scenes/CharacterSheet.tscn").instantiate()
    character_sheet.set_character(character)
    add_child(character_sheet)

func _on_finalize_crew_button_pressed():
    emit_signal("crew_finalized")
