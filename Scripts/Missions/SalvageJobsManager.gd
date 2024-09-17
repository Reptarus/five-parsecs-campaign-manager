# SalvageJobsManager.gd
class_name SalvageJobsManager
extends Node

var game_state: GameState

const SALVAGE_MARKERS_COUNT = 6
const POINTS_OF_INTEREST_COUNT = 4

var tension: int = 0
var encounter_number: int = 1
var salvage_units: int = 0
var discoveries: int = 0

func _init(_game_state: GameState):
    game_state = _game_state

func setup_salvage_mission():
    _place_salvage_markers()
    _place_points_of_interest()
    _set_initial_tension()

func _place_salvage_markers():
    var salvage_markers = SALVAGE_MARKERS_COUNT + game_state.crew_size + 1
    for i in range(salvage_markers):
        _place_marker("Salvage")

func _place_points_of_interest():
    for i in range(POINTS_OF_INTEREST_COUNT):
        _place_marker("PointOfInterest")

func _place_marker(type: String):
    var marker = Marker2D.new()
    marker.name = type + str(randi())
    marker.position = Vector2(randf() * game_state.table_size.x, randf() * game_state.table_size.y)
    add_child(marker)

func _set_initial_tension():
    tension = game_state.crew_size / 2

func play_exploration_round():
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

func resolve_tension():
    var roll = randi() % 6 + 1
    if roll > tension:
        tension += 1
    elif roll <= tension:
        tension -= roll
        _spawn_contact()

func _spawn_contact():
    var contact = _place_marker("Contact")
    _resolve_contact(contact)

func _resolve_contact(contact):
    var roll = randi() % 6 + 1
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

func _handle_hostiles():
    var roll = randi() % 100 + 1
    if roll <= 25:
        print("Free for all! Looters, renegades, or other suspicious characters are roaming around.")
        # Determine a random opponent type from the Criminal Elements table
    elif roll <= 40:
        print("Toughs. Someone hired a bunch of goons to make sure nobody snoops around.")
        # Determine a random opponent type from the Hired Muscle table
    # ... implement other hostiles results

func pick_up_salvage(crew_member):
    var salvage_marker = _find_nearest_salvage_marker(crew_member)
    if salvage_marker:
        game_state.add_salvage_unit(1)
        salvage_marker.queue_free()

func _find_nearest_salvage_marker(crew_member):
    # Implement logic to find the nearest salvage marker to the crew member
    pass

func investigate_point_of_interest(crew_member):
    var poi = _find_nearest_point_of_interest(crew_member)
    if poi:
        _resolve_point_of_interest(poi)
        poi.queue_free()

func _find_nearest_point_of_interest(crew_member):
    # Implement logic to find the nearest point of interest to the crew member
    pass

func _resolve_point_of_interest(poi):
    var roll = randi() % 100 + 1
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

func _handle_rival_trap():
    tension = 9
    # Implement logic for rival trap scenario

func _handle_valuable_find():
    salvage_units += randi() % 3 + 1  # 1-3 Salvage units

func _handle_epic_scene():
    tension = max(0, tension - 10)
    # Implement logic for epic scene scenario

func _handle_doomsday_protocol():
    tension = max(0, tension - 10)
    # Implement logic for doomsday protocol scenario

func check_mission_completion() -> bool:
    var all_poi_investigated = get_tree().get_nodes_in_group("PointOfInterest").size() == 0
    return all_poi_investigated

func enemy_scanner_check():
    var roll = randi() % 6 + 1
    if roll > 4:
        print("Enemy forces have detected your presence!")
        _spawn_enemy_forces()

func _spawn_enemy_forces():
    var enemy_count = 2
    if encounter_number >= 3:
        enemy_count += 1
    if encounter_number >= 2:
        # Add 1 specialist
        pass
    # Implement enemy spawning logic
    encounter_number += 1

func adjust_tension_for_event(event: String):
    match event:
        "Head canon":
            tension += 1
        "We need to hurry":
            tension += 1
        "Shut end":
            tension -= 1
        "Information station":
            tension = max(0, tension - game_state.crew_size)
        "Hot find":
            tension += 1
        "Survivors discovered":
            tension += 2
        "Hornet's nest":
            tension -= 2
        "Loot?":
            tension -= 1
        "All clear":
            tension -= 3

func end_mission():
    if _check_mission_completion():
        _calculate_post_game_rewards()
    else:
        print("Mission failed. No rewards.")

func _check_mission_completion() -> bool:
    return get_tree().get_nodes_in_group("PointOfInterest").size() == 0

func _calculate_post_game_rewards():
    var experience_points = _calculate_experience_points()
    game_state.add_experience(experience_points)
    
    _roll_for_discoveries()
    _convert_salvage_to_credits()

func _calculate_experience_points() -> int:
    # Implement logic to calculate experience points based on mission performance
    return 100  # Placeholder value

func _roll_for_discoveries():
    for i in range(discoveries):
        var roll = randi() % 100 + 1
        if roll <= 5:
            print("Found an interesting bit of tech worth 1 unit of Salvage.")
            salvage_units += 1
        elif roll <= 6:
            print("Something notable. Roll for a Discovery below.")
            _roll_for_notable_discovery()

func _roll_for_notable_discovery():
    var roll = randi() % 100 + 1
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
        var credits = randi() % 98 + 3  # 3-100 credits
        print("Valuable trinket. Add " + str(credits) + " Credits.")
        game_state.add_credits(credits)

func _convert_salvage_to_credits():
    var total_credits = 0
    for i in range(3):
        var roll = randi() % 6 + 1
        total_credits += roll * 10
    game_state.add_credits(total_credits)
    print("Converted " + str(salvage_units) + " Salvage units to " + str(total_credits) + " Credits.")
    salvage_units = 0

func sell_salvage():
    var total_credits = 0
    for i in range(3):
        var roll = randi() % 6 + 1
        var salvage_value = roll * 10
        total_credits += salvage_value
        print("Roll " + str(i+1) + ": " + str(roll) + " x 10 = " + str(salvage_value) + " credits")
    
    game_state.add_credits(total_credits)
    print("Total credits from salvage: " + str(total_credits))
    salvage_units = 0

func visit_scrapper():
    print("Visiting the Scrapper to trade salvage.")
    var tradeable_units = min(salvage_units, 3)  # Can only trade up to 3 units per visit
    for i in range(tradeable_units):
        var roll = randi() % 6 + 1
        if roll <= 2:
            print("No trade for this salvage unit.")
        else:
            _trade_salvage_unit()
    
    print("Scrapper visit complete.")

func _trade_salvage_unit():
    salvage_units -= 1
    var options = ["Ship repairs", "Ship modules", "Bot upgrades"]
    var chosen_option = options[randi() % options.size()]
    print("Traded 1 Salvage unit for: " + chosen_option)
    # Implement the effect of the chosen option
    match chosen_option:
        "Ship repairs":
            game_state.repair_ship()
        "Ship modules":
            game_state.add_ship_module()
        "Bot upgrades":
            game_state.upgrade_bot()

func use_salvage_for_purchase(cost_in_credits: int) -> bool:
    var salvage_value = salvage_units * 10
    if salvage_value >= cost_in_credits:
        var units_used = ceil(cost_in_credits / 10.0)
        salvage_units -= units_used
        print("Used " + str(units_used) + " Salvage units for purchase.")
        return true
    return false

func adjust_difficulty(adjustment: String):
    match adjustment:
        "easier":
            tension = 0
        "harder":
            tension += 1
            _remove_random_contact_marker()

func _remove_random_contact_marker():
    var contact_markers = get_tree().get_nodes_in_group("ContactMarkers")
    if contact_markers.size() > 0:
        var marker_to_remove = contact_markers[randi() % contact_markers.size()]
        marker_to_remove.queue_free()
        print("Removed a Contact marker to increase difficulty.")
