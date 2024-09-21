# SalvageJobsManager.gd
class_name SalvageJobsManager
extends RefCounted

var game_state: GameStateManager

const SALVAGE_MARKERS_COUNT: int = 6
const POINTS_OF_INTEREST_COUNT: int = 4
const TIME_LIMIT: float = 3600.0  # Time limit in seconds (e.g., 1 hour)

var tension: int = 0
var encounter_number: int = 1
var salvage_units: int = 0
var discoveries: int = 0

const TENSION_ADJUSTMENTS: Dictionary = {
    "Head canon": 1,
    "We need to hurry": 1,
    "Shut end": -1,
    "Information station": -1,  # Special case handled separately
    "Hot find": 1,
    "Survivors discovered": 2,
    "Hornet's nest": -2,
    "Loot?": -1,
    "All clear": -3
}

var mission_time: float = 0.0

func initialize(state: GameStateManager) -> void:
    game_state = state

func setup_salvage_mission() -> void:
    _place_salvage_markers()
    _place_points_of_interest()
    _set_initial_tension()

func _place_salvage_markers() -> void:
    var salvage_markers: int = SALVAGE_MARKERS_COUNT + game_state.current_crew.get_size() + 1
    for i in range(salvage_markers):
        _place_marker("Salvage")

func _place_points_of_interest() -> void:
    for i in range(POINTS_OF_INTEREST_COUNT):
        _place_marker("PointOfInterest")

func _place_marker(type: String) -> Marker2D:
    var marker: Marker2D = Marker2D.new()
    marker.name = type + str(randi())
    marker.position = Vector2(randf() * game_state.current_location.size.x, randf() * game_state.current_location.size.y)
    game_state.current_location.add_child(marker)
    return marker

func _set_initial_tension() -> void:
    tension = int(float(game_state.current_crew.get_size()) / 2)

func play_exploration_round() -> String:
    if _check_for_contacts_or_enemies():
        return "Normal battle round"
    else:
        return _perform_exploration_actions()

func _check_for_contacts_or_enemies() -> bool:
    # Implement logic to check for contacts or enemies
    return false

func _perform_exploration_actions() -> String:
    # Crew can move but not Dash or use equipment
    # Implement crew movement logic here
    return "Exploration round completed"

func resolve_tension() -> void:
    var roll: int = randi() % 6 + 1
    if roll > tension:
        tension += 1
    elif roll <= tension:
        tension -= roll
        _spawn_contact()

func _spawn_contact() -> void:
    var contact: Marker2D = _place_marker("Contact")
    _resolve_contact(contact)

func _resolve_contact(_contact: Marker2D) -> void:
    var roll: int = randi() % 6 + 1
    match roll:
        1:
            print("Obstacle: Avoid industrial waste, radiation or collapsing ceilings.")
            tension -= 2
        2, 3, 4, 5:
            print("Environmental Issue: Some old equipment that is falling apart.")
            tension -= 1
        6:
            print("Secure device: You find a secured lockbox of some sort.")
            # No immediate modifier

func _handle_hostiles() -> void:
    var roll: int = randi() % 100 + 1
    if roll <= 25:
        print("Free for all! Looters, renegades, or other suspicious characters are roaming around.")
        _spawn_criminal_elements()
    elif roll <= 40:
        print("Toughs. Someone hired a bunch of goons to make sure nobody snoops around.")
        _spawn_hired_muscle()
    elif roll <= 60:
        print("Rival salvagers. Looks like we're not the only ones interested in this place.")
        _spawn_rival_salvagers()
    elif roll <= 75:
        print("Security systems. Old automated defenses have been triggered.")
        _spawn_security_systems()
    elif roll <= 90:
        print("Local wildlife. Creatures have made this place their home.")
        _spawn_local_wildlife()
    else:
        print("Something worse. A particularly dangerous threat lurks here.")
        _spawn_major_threat()

func _spawn_criminal_elements() -> void:
    # Implement logic to spawn opponents from the Criminal Elements table
    pass

func _spawn_hired_muscle() -> void:
    # Implement logic to spawn opponents from the Hired Muscle table
    pass

func _spawn_rival_salvagers() -> void:
    # Implement logic to spawn rival salvager opponents
    pass

func _spawn_security_systems() -> void:
    # Implement logic to spawn automated security system opponents
    pass

func _spawn_local_wildlife() -> void:
    # Implement logic to spawn local wildlife opponents
    pass

func _spawn_major_threat() -> void:
    # Implement logic to spawn a major threat opponent
    pass

func pick_up_salvage(_crew: Crew) -> void:
    var salvage_marker: Marker2D = _find_nearest_salvage_marker(_crew)
    if salvage_marker:
        salvage_units += 1
        salvage_marker.queue_free()

func _find_nearest_salvage_marker(_crew: Crew) -> Marker2D:
    # Implement logic to find the nearest salvage marker to the crew member
    return null

func investigate_point_of_interest(_crew: Crew) -> void:
    var poi: Marker2D = _find_nearest_point_of_interest(_crew)
    if poi:
        _resolve_point_of_interest(poi)
        poi.queue_free()

func _find_nearest_point_of_interest(_crew: Crew) -> Marker2D:
    # Implement logic to find the nearest point of interest to the crew member
    return null

func _resolve_point_of_interest(_poi: Marker2D) -> void:
    var roll: int = randi() % 100 + 1
    if roll <= 83:
        print("Rival trap: It was all a set-up!")
        _handle_rival_trap()
    elif roll <= 91:
        print("Valuable find: Something of value to loot.")
        _handle_valuable_find()
    elif roll <= 96:
        print("Interesting find: This will need to be examined later.")
        discoveries += 1
    elif roll <= 99:
        print("Epic scene: The entire area is unstable, collapsing or being filled with something bad!")
        _handle_epic_scene()
    else:
        print("Doomsday protocol: You have uncovered something dreadful!")
        _handle_doomsday_protocol()

func _handle_rival_trap() -> void:
    tension = 9
    # Implement logic for rival trap scenario

func _handle_valuable_find() -> void:
    salvage_units += randi() % 3 + 1  # 1-3 Salvage units

func _handle_epic_scene() -> void:
    tension = max(0, tension - 10)
    # Implement logic for epic scene scenario

func _handle_doomsday_protocol() -> void:
    tension = max(0, tension - 10)
    # Implement logic for doomsday protocol scenario

func check_mission_completion() -> bool:
    var all_poi_investigated: bool = game_state.current_location.get_tree().get_nodes_in_group("PointOfInterest").is_empty()
    return all_poi_investigated

func enemy_scanner_check() -> void:
    var roll: int = randi() % 6 + 1
    if roll > 4:
        print("Enemy forces have detected your presence!")
        _spawn_enemy_forces()

func _spawn_enemy_forces() -> void:
    var _enemy_count: int = 2
    if encounter_number >= 3:
        _enemy_count += 1
    if encounter_number >= 2:
        # Add 1 specialist
        pass
    # Implement enemy spawning logic
    encounter_number += 1

func adjust_tension_for_event(event: String) -> void:
    if event in TENSION_ADJUSTMENTS:
        if event == "Information station":
            tension = max(0, tension - game_state.current_crew.get_size())
        else:
            tension += TENSION_ADJUSTMENTS[event]

func end_mission() -> void:
    if _check_mission_completion():
        _calculate_post_game_rewards()
    else:
        print("Mission failed. No rewards.")

func _check_mission_completion() -> bool:
    return game_state.current_location.get_tree().get_nodes_in_group("PointOfInterest").is_empty()

func _calculate_post_game_rewards() -> void:
    var experience_points: int = _calculate_experience_points()
    game_state.current_crew.add_experience(experience_points)
    
    _roll_for_discoveries()
    _convert_salvage_to_credits()

func _calculate_experience_points() -> int:
    var base_xp: int = 10  # Base XP for completing the mission
    var bonus_xp: int = 0
    
    # Bonus XP for each enemy defeated
    var defeated_enemies: int = game_state.current_location.get_tree().get_nodes_in_group("DefeatedEnemies").size()
    bonus_xp += defeated_enemies * 5
    
    # Bonus XP for each point of interest investigated
    var investigated_poi: int = game_state.current_location.get_tree().get_nodes_in_group("InvestigatedPOI").size()
    bonus_xp += investigated_poi * 3
    
    # Bonus XP for completing the mission without casualties
    if game_state.current_crew.get_size() == game_state.current_crew.initial_size:
        bonus_xp += 20
    
    # Bonus XP for completing the mission quickly (assuming a time limit)
    if mission_time < TIME_LIMIT:
        bonus_xp += 15
    
    # Bonus XP for difficulty level (assuming a difficulty setting)
    bonus_xp += 5 * game_state.difficulty_settings.level
    
    return base_xp + bonus_xp

func _roll_for_discoveries() -> void:
    for i in range(discoveries):
        var roll: int = randi() % 100 + 1
        if roll <= 5:
            print("Found an interesting bit of tech worth 1 unit of Salvage.")
            salvage_units += 1
        elif roll <= 6:
            print("Something notable. Roll for a Discovery below.")
            _roll_for_notable_discovery()

func _roll_for_notable_discovery() -> void:
    var roll: int = randi() % 100 + 1
    if roll <= 40:
        print("You found something that might be valuable with some restoration.")
        # Implement logic for Loot table roll
    elif roll <= 70:
        print("Just a bit of scrap after all. Add 1 unit of Salvage.")
        salvage_units += 1
    elif roll <= 85:
        print("Interesting data. Add 1 Quest Rumor.")
        game_state.add_quest_rumor()
    else:
        var credits: int = randi() % 98 + 3  # 3-100 credits
        print("Valuable trinket. Add " + str(credits) + " Credits.")
        game_state.add_credits(credits)

func _convert_salvage_to_credits() -> void:
    var total_credits: int = 0
    for i in range(3):
        var roll: int = randi() % 6 + 1
        total_credits += roll * 10
    game_state.add_credits(total_credits)
    print("Converted " + str(salvage_units) + " Salvage units to " + str(total_credits) + " Credits.")
    salvage_units = 0

func sell_salvage() -> void:
    var total_credits: int = 0
    for i in range(3):
        var roll: int = randi() % 6 + 1
        var salvage_value: int = roll * 10
        total_credits += salvage_value
        print("Roll " + str(i+1) + ": " + str(roll) + " x 10 = " + str(salvage_value) + " credits")
    
    game_state.add_credits(total_credits)
    print("Total credits from salvage: " + str(total_credits))
    salvage_units = 0

func visit_scrapper() -> void:
    print("Visiting the Scrapper to trade salvage.")
    var tradeable_units: int = min(salvage_units, 3)  # Can only trade up to 3 units per visit
    for i in range(tradeable_units):
        var roll: int = randi() % 6 + 1
        if roll <= 2:
            print("No trade for this salvage unit.")
        else:
            _trade_salvage_unit()
    
    print("Scrapper visit complete.")

func _trade_salvage_unit() -> void:
    salvage_units -= 1
    var options: Array[String] = ["Ship repairs", "Ship modules", "Bot upgrades"]
    var chosen_option: String = options[randi() % options.size()]
    print("Traded 1 Salvage unit for: " + chosen_option)
    # Implement the effect of the chosen option
    match chosen_option:
        "Ship repairs":
            game_state.current_ship.repair()
        "Ship modules":
            game_state.current_ship.add_module()
        "Bot upgrades":
            game_state.upgrade_bot()

func use_salvage_for_purchase(cost_in_credits: int) -> bool:
    var salvage_value: int = salvage_units * 10
    if salvage_value >= cost_in_credits:
        var units_used: int = ceili(cost_in_credits / 10.0)
        salvage_units -= units_used
        print("Used " + str(units_used) + " Salvage units for purchase.")
        return true
    return false

func adjust_difficulty(adjustment: String) -> void:
    match adjustment:
        "easier":
            tension = 0
        "harder":
            tension += 1
            _remove_random_contact_marker()

func _remove_random_contact_marker() -> void:
    var contact_markers: Array = game_state.current_location.get_tree().get_nodes_in_group("ContactMarkers")
    if not contact_markers.is_empty():
        var marker_to_remove: Marker2D = contact_markers[randi() % contact_markers.size()]
        marker_to_remove.queue_free()
        print("Removed a Contact marker to increase difficulty.")

func serialize() -> Dictionary:
    return {
        "tension": tension,
        "encounter_number": encounter_number,
        "salvage_units": salvage_units,
        "discoveries": discoveries,
        "mission_time": mission_time
    }

func deserialize(data: Dictionary) -> void:
    tension = data.get("tension", 0)
    encounter_number = data.get("encounter_number", 1)
    salvage_units = data.get("salvage_units", 0)
    discoveries = data.get("discoveries", 0)
    mission_time = data.get("mission_time", 0.0)
