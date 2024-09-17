# FringeWorldStrifeManager.gd
class_name FringeWorldStrifeManager
extends Node

var game_state: GameState
var mission_generator: MissionGenerator

const STRIFE_TYPES = ["Resource Conflict", "Political Uprising", "Alien Incursion", "Corporate Warfare"]

var instability: int = 0

func _init(_game_state: GameState):
    game_state = _game_state
    mission_generator = game_state.mission_generator

func generate_fringe_world_strife() -> Mission:
    var mission = Mission.new()
    mission.type = Mission.Type.FRINGE_WORLD_STRIFE
    mission.objective = _generate_strife_objective()
    mission.location = _generate_strife_location()
    mission.difficulty = _calculate_difficulty()
    mission.rewards = _generate_strife_rewards(mission.difficulty)
    mission.special_rules = _generate_strife_special_rules()
    return mission

func _generate_strife_objective() -> String:
    return "Resolve " + STRIFE_TYPES[randi() % STRIFE_TYPES.size()]

func _generate_strife_location() -> String:
    var locations = ["Desert Planet", "Jungle World", "Ice Planet", "Mining Colony", "Frontier Settlement"]
    return locations[randi() % locations.size()]

func _calculate_difficulty() -> int:
    var base_difficulty = randi() % 5 + 1  # 1 to 5
    return base_difficulty + instability

func _generate_strife_rewards(difficulty: int) -> Dictionary:
    return {
        "credits": 1500 * difficulty,
        "influence": difficulty,
        "rare_technology": randf() < 0.3  # 30% chance for rare technology
    }

func _generate_strife_special_rules() -> Array:
    var rules = []
    if randf() < 0.5:
        rules.append("Shifting Alliances")
    if randf() < 0.5:
        rules.append("Environmental Challenges")
    return rules

func setup_fringe_world_strife(mission: Mission):
    _calculate_initial_instability()
    mission.involved_factions = _determine_involved_factions()
    mission.strife_intensity = _calculate_strife_intensity()
    mission.key_npcs = _generate_key_npcs()
    mission.environmental_factors = _generate_environmental_factors()
    mission.available_resources = _determine_available_resources()
    mission.time_pressure = _calculate_time_pressure()
    
    # Set up mission-specific signals
    mission.connect("strife_escalated", self, "_on_strife_escalated")
    mission.connect("faction_influence_changed", self, "_on_faction_influence_changed")

func _determine_involved_factions() -> Array:
    var factions = []
    for faction in game_state.active_factions:
        if randf() < 0.5:  # 50% chance for each faction to be involved
            factions.append(faction)
    return factions

func _calculate_strife_intensity() -> int:
    return instability + randi() % 3  # Base on instability plus some randomness

func _generate_key_npcs() -> Array:
    var npcs = []
    var npc_types = ["Faction Leader", "Local Authority", "Rebel Commander", "Influential Merchant"]
    for _i in range(randi() % 3 + 1):  # 1 to 3 key NPCs
        npcs.append(npc_types[randi() % npc_types.size()])
    return npcs

func _generate_environmental_factors() -> Array:
    var factors = []
    var possible_factors = ["Extreme Weather", "Toxic Atmosphere", "Unstable Terrain", "Electromagnetic Interference"]
    for factor in possible_factors:
        if randf() < 0.3:  # 30% chance for each factor
            factors.append(factor)
    return factors

func _determine_available_resources() -> Dictionary:
    return {
        "medical_supplies": randi() % 5,
        "weaponry": randi() % 5,
        "credits": randi() % 1000 + 500,
        "information": randi() % 3
    }

func _calculate_time_pressure() -> int:
    return randi() % 5 + 1  # 1 to 5, with 5 being the highest pressure

func _on_strife_escalated(intensity_increase: int):
    instability += intensity_increase

func _on_faction_influence_changed(faction_id: String, influence_change: int):
    game_state.update_faction_influence(faction_id, influence_change)

func _calculate_initial_instability():
    instability = 1
    instability += game_state.active_rivals.size()
    
    if game_state.completed_patron_job_this_turn:
        instability -= 1
    
    if game_state.held_the_field_against_roving_threat:
        instability -= 1

func resolve_fringe_world_strife(mission: Mission) -> Dictionary:
    var outcome = {}
    
    # Roll for mission success
    var success_roll = randi() % 20 + 1  # 1d20
    var difficulty = mission.difficulty + instability
    var success = success_roll >= difficulty
    
    outcome["success"] = success
    outcome["roll"] = success_roll
    outcome["difficulty"] = difficulty
    
    # Determine consequences based on success/failure
    if success:
        outcome["instability_decrease"] = randi() % 3 + 1  # 1-3
        outcome["credits_earned"] = mission.rewards.get("credits", 0)
        outcome["influence_gained"] = mission.rewards.get("influence", 0)
        
        if randf() < 0.1:  # 10% chance
            outcome["story_milestone_reached"] = true
        
        if randf() < 0.2:  # 20% chance
            outcome["side_quest_unlocked"] = true
            outcome["side_quest_id"] = _generate_side_quest_id()
    else:
        outcome["instability_increase"] = randi() % 2 + 1  # 1-2
        
        if randf() < 0.15:  # 15% chance
            outcome["new_rival_appeared"] = true
            outcome["new_rival_id"] = _generate_rival_id()
        
        if randf() < 0.25:  # 25% chance
            outcome["crew_member_injured"] = true
            outcome["injured_crew_member_id"] = _get_random_crew_member_id()
    
    # Handle faction relations changes
    outcome["faction_relations_changes"] = _calculate_faction_relations_changes(success)
    
    # Check for rare technology discovery
    if mission.rewards.get("rare_technology", false) and success:
        outcome["rare_technology_discovered"] = true
    
    # Trigger a random event
    if randf() < 0.3:  # 30% chance
        outcome["random_event"] = _trigger_random_event()
    
    return outcome

func _generate_side_quest_id() -> String:
    # Implement logic to generate a unique side quest ID
    return "SQ_" + str(randi() % 1000)

func _generate_rival_id() -> String:
    # Implement logic to generate a unique rival ID
    return "RIV_" + str(randi() % 1000)

func _get_random_crew_member_id() -> String:
    # Implement logic to get a random crew member ID
    var crew_members = game_state.current_crew.get_members()
    return crew_members[randi() % crew_members.size()].id

func _calculate_faction_relations_changes(success: bool) -> Dictionary:
    var changes = {}
    var factions = ["Rebels", "Empire", "Traders", "Pirates"]
    for faction in factions:
        changes[faction] = randi() % 3 - 1  # -1 to 1
        if success:
            changes[faction] += 1
    return changes

func _trigger_random_event() -> String:
    var events = ["Resource Discovery", "Natural Disaster", "Alien Artifact", "Local Uprising"]
    return events[randi() % events.size()]

func apply_strife_aftermath(mission: Mission, outcome: Dictionary):
    _update_instability(outcome)
    _trigger_chaos_event()
    _apply_rewards(mission, outcome)
    _update_story_progression(outcome)
    _update_faction_relations(outcome)
    _handle_special_consequences(outcome)

func _apply_rewards(mission: Mission, outcome: Dictionary):
    if outcome.get("success", false):
        game_state.add_credits(mission.rewards.get("credits", 0))
        game_state.add_influence(mission.rewards.get("influence", 0))
        if mission.rewards.get("rare_technology", false):
            game_state.add_rare_technology()

func _update_story_progression(outcome: Dictionary):
    if outcome.get("story_milestone_reached", false):
        game_state.advance_main_story()
    if outcome.get("side_quest_unlocked", false):
        game_state.unlock_side_quest(outcome.get("side_quest_id"))

func _update_faction_relations(outcome: Dictionary):
    for faction, change in outcome.get("faction_relations_changes", {}).items():
        game_state.update_faction_relation(faction, change)

func _handle_special_consequences(outcome: Dictionary):
    if outcome.get("new_rival_appeared", false):
        game_state.add_rival(outcome.get("new_rival_id"))
    if outcome.get("resource_discovered", false):
        game_state.add_resource(outcome.get("resource_type"), outcome.get("resource_amount"))
    if outcome.get("crew_member_injured", false):
        game_state.injure_crew_member(outcome.get("injured_crew_member_id"))

func _update_instability(outcome: Dictionary):
    if outcome.get("instability_increase", 0) > 0:
        instability += outcome["instability_increase"]
    
    if instability >= 10:
        _trigger_high_instability_event()
    elif instability <= 0:
        instability = 0
        print("The fringe world has stabilized... for now.")

func _trigger_high_instability_event():
    var roll = randi() % 6 + 1
    instability -= roll
    print("High instability event triggered! Roll: ", roll)
    
    match roll:
        1:
            _handle_mass_exodus()
        2:
            _handle_government_collapse()
        3:
            _handle_widespread_riots()
        4:
            _handle_resource_crisis()
        5:
            _handle_planetary_lockdown()
        6:
            _handle_faction_war()

func _handle_mass_exodus():
    print("Mass Exodus: Large portions of the population are fleeing the planet.")
    game_state.reduce_planet_population(0.3)  # Reduce population by 30%
    game_state.reduce_economic_output(0.2)    # Reduce economic output by 20%

func _handle_government_collapse():
    print("Government Collapse: The planetary government has fallen apart.")
    game_state.set_government_status("collapsed")
    game_state.increase_criminal_activity(0.5)  # Increase criminal activity by 50%

func _handle_widespread_riots():
    print("Widespread Riots: Chaos engulfs major cities across the planet.")
    game_state.damage_infrastructure(0.4)  # Damage 40% of infrastructure
    game_state.block_all_actions_next_turn()

func _handle_resource_crisis():
    print("Resource Crisis: Critical shortages of essential resources.")
    game_state.deplete_random_resource()
    game_state.increase_prices(0.5)  # Increase prices by 50%

func _handle_planetary_lockdown():
    print("Planetary Lockdown: The planet is completely sealed off.")
    game_state.set_travel_status("locked")
    game_state.block_trade_actions(3)  # Block trade actions for 3 turns

func _handle_faction_war():
    print("Faction War: Major factions have begun open warfare.")
    game_state.trigger_faction_conflict()
    game_state.increase_military_presence(0.7)  # Increase military presence by 70%

func _trigger_chaos_event():
    var roll = randi() % 100 + 1
    match roll:
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10:
            _handle_hooligans()
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24:
            _handle_criminal_gang()
        25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36:
            _handle_enemy_infiltration()
        37, 38, 39, 40, 41, 42, 43, 44, 45, 46:
            _handle_heating_up()
        47, 48, 49, 50, 51, 52, 53, 54:
            _handle_sabotage()
        55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66:
            _handle_raiders()
        67, 68, 69, 70, 71, 72:
            _handle_crackdown()
        73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86:
            _handle_economic_collapse()
        87, 88, 89, 90, 91, 92, 93, 94:
            _handle_invasion_imminent()
        95, 96, 97, 98, 99, 100:
            _handle_civil_war()
        _:
            print("No chaos event triggered.")

func _handle_hooligans():
    instability -= 5
    print("Hooligans: While trying to go about your business, a bunch of 'roided-up hooligans cause a riot.")
    print("You cannot perform any Explore or Trade crew actions during the next campaign turn.")
    game_state.block_explore_and_trade_actions()

func _handle_criminal_gang():
    instability -= 5
    print("Criminal Gang: Roll once on the Criminal Elements encounter subtable.")
    print("This gang has set up shop threatening local businesses. Until you clear them out, all post-battle payouts on this world are reduced by 1 Credit.")
    game_state.setup_fight_off_mission("Criminal Gang")
    game_state.reduce_post_battle_payouts(1)

func _handle_enemy_infiltration():
    instability -= 5
    print("Enemy Infiltration: A Converted infiltrator squad has arrived on the planet.")
    print("To go after them, use the Track crew action, similar to tracking down a Rival.")
    game_state.setup_fight_off_mission("Converted Infiltrator Squad", true)

func _handle_heating_up():
    instability -= 3
    print("Heating Up: Tensions are getting out of hand, and people want to scrap.")
    game_state.add_random_rival_from_criminal_elements()

func _handle_sabotage():
    instability -= 7
    print("Sabotage: During a running gun battle, your ship was caught in the crossfire and took a beating.")
    game_state.damage_ship(randi() % 6 + 1)  # 1D6+1 points of hull damage

func _handle_raiders():
    instability -= 7
    print("Raiders: Next campaign turn, you will be attacked by scavengers.")
    game_state.setup_rival_attack_raid()

func _handle_crackdown():
    instability -= 10
    print("Crackdown: The authorities decide to make examples of the crew.")
    game_state.apply_upkeep_penalties()

func _handle_economic_collapse():
    instability -= 10
    print("Economic Collapse: The economy has fallen to pieces. For now, you cannot take Trade actions, and all mission payouts are -1 Credit.")
    game_state.block_trade_actions()
    game_state.reduce_mission_payouts(1)

func _handle_invasion_imminent():
    print("Invasion Imminent: An alien invasion force is en route, and everyone is scrambling to get away.")
    print("After the next campaign turn, the world is automatically invaded.")
    game_state.schedule_world_invasion()

func _handle_civil_war():
    print("Civil War: The world erupts in a shooting war next campaign turn.")
    var decision = yield(game_state.prompt_player_decision("Do you want to remain and get caught up in the fighting?"), "completed")
    
    if decision:
        _start_civil_war()
    else:
        print("You decide to leave before the war breaks out.")

func _start_civil_war():
    print("You've decided to stay and participate in the civil war.")
    var interested_parties = _roll_interested_parties()
    print("The two sides struggling for control are: ", interested_parties[0], " and ", interested_parties[1])
    var chosen_side = yield(game_state.prompt_player_choice("Which side do you choose?", interested_parties), "completed")
    
    game_state.start_opportunity_missions(chosen_side)
    
    # Placeholder for Galactic War Progress
    _check_galactic_war_progress()

func _roll_interested_parties() -> Array:
    var parties = [
        "Local Government",
        "Rebel Faction",
        "Corporate Interests",
        "Religious Movement",
        "Criminal Syndicate",
        "Foreign Power"
    ]
    var roll1 = mission_generator._roll_mission_type() if mission_generator else randi() % parties.size()
    var roll2 = mission_generator._roll_mission_type() if mission_generator else randi() % parties.size()
    while roll2 == roll1:
        roll2 = mission_generator._roll_mission_type() if mission_generator else randi() % parties.size()
    return [parties[roll1], parties[roll2]]

func _check_galactic_war_progress():
    print("Checking for Galactic War Progress...")
    # Placeholder for Galactic War Progress logic
    var roll = randi() % 100 + 1
    if roll <= 20:
        print("Unity Victorious: Your faction has won the war!")
        _handle_unity_victory()
    elif roll >= 80:
        print("Lost to Unity: Your side lost. You must leave immediately.")
        _handle_unity_loss()
    else:
        print("The war continues...")

func _handle_unity_victory():
    var missions_completed = game_state.get_completed_missions_count()
    var bonus_credits = min(missions_completed * 100, 600)
    game_state.add_credits(bonus_credits)
    game_state.remove_random_rival()
    print("You receive ", bonus_credits, " Credits as a bonus and remove 1 random Rival from your list.")

func _handle_unity_loss():
    print("You must leave immediately. If unable to leave, your ship and all Credits are confiscated.")
    if not game_state.attempt_emergency_departure():
        game_state.confiscate_ship_and_credits()

# Additional methods for handling fringe world strife-specific mechanics

func _handle_faction_influence():
    for faction in game_state.active_factions:
        var influence_change = randi() % 3 - 1  # -1 to 1
        game_state.update_faction_influence(faction.id, influence_change)

func _resolve_environmental_crisis():
    var crisis_types = ["Natural Disaster", "Resource Depletion", "Ecological Imbalance"]
    var crisis = crisis_types[randi() % crisis_types.size()]
    print("Environmental crisis: ", crisis)
    
    match crisis:
        "Natural Disaster":
            _handle_natural_disaster()
        "Resource Depletion":
            _handle_resource_depletion()
        "Ecological Imbalance":
            _handle_ecological_imbalance()
    
    _update_strife_intensity(2)  # Increase strife intensity due to crisis

func _handle_natural_disaster():
    var disaster_types = ["Earthquake", "Flood", "Wildfire"]
    var disaster = disaster_types[randi() % disaster_types.size()]
    print("Handling natural disaster: ", disaster)
    game_state.reduce_population(randi() % 1000 + 500)  # Random population reduction
    game_state.reduce_resources("food", randi() % 50 + 25)  # Random food resource reduction

func _handle_resource_depletion():
    var resources = ["water", "fuel", "minerals"]
    var depleted_resource = resources[randi() % resources.size()]
    print("Handling resource depletion: ", depleted_resource)
    game_state.reduce_resources(depleted_resource, randi() % 75 + 50)  # Significant resource reduction
    game_state.increase_resource_price(depleted_resource, randf() * 0.5 + 0.5)  # 50-100% price increase

func _handle_ecological_imbalance():
    var imbalances = ["Invasive Species", "Pollution", "Climate Shift"]
    var imbalance = imbalances[randi() % imbalances.size()]
    print("Handling ecological imbalance: ", imbalance)
    game_state.reduce_resources("food", randi() % 30 + 20)  # Food production affected
    game_state.increase_health_issues(randi() % 20 + 10)  # Increase in health issues

func _update_strife_intensity(amount: int):
    instability += amount
    print("Strife intensity updated. New level: ", instability)

func _manage_strife_intensity():
    if instability > 5:
        print("Strife intensity is high. Increasing mission difficulty.")
        _increase_mission_difficulty()
    elif instability < 2:
        print("Strife intensity is low. Decreasing mission difficulty.")
        _decrease_mission_difficulty()

func _increase_mission_difficulty():
    var difficulty_settings = DifficultySettings.new()
    difficulty_settings.increase_enemy_count(1)
    difficulty_settings.increase_enemy_toughness(0.1)
    difficulty_settings.decrease_loot_quality(-0.1)
    difficulty_settings.increase_environmental_hazards(1)
    
    # Adjust mission parameters based on Five Parsecs From Home rules
    mission.enemy_count += difficulty_settings.enemy_count_increase
    mission.enemy_toughness_modifier += difficulty_settings.enemy_toughness_increase
    mission.loot_quality_modifier -= difficulty_settings.loot_quality_decrease
    mission.environmental_hazard_count += difficulty_settings.environmental_hazard_increase
    
    print("Mission difficulty increased. New parameters: ", 
          "Enemy Count: ", mission.enemy_count,
          "Enemy Toughness Modifier: ", mission.enemy_toughness_modifier,
          "Loot Quality Modifier: ", mission.loot_quality_modifier,
          "Environmental Hazards: ", mission.environmental_hazard_count)

func _decrease_mission_difficulty():
    var difficulty_settings = DifficultySettings.new()
    difficulty_settings.decrease_enemy_count(1)
    difficulty_settings.decrease_enemy_toughness(0.1)
    difficulty_settings.increase_loot_quality(0.1)
    difficulty_settings.decrease_environmental_hazards(1)
    
    # Adjust mission parameters based on Five Parsecs From Home rules
    mission.enemy_count = max(1, mission.enemy_count - difficulty_settings.enemy_count_decrease)
    mission.enemy_toughness_modifier = max(0, mission.enemy_toughness_modifier - difficulty_settings.enemy_toughness_decrease)
    mission.loot_quality_modifier = min(1, mission.loot_quality_modifier + difficulty_settings.loot_quality_increase)
    mission.environmental_hazard_count = max(0, mission.environmental_hazard_count - difficulty_settings.environmental_hazard_decrease)
    
    print("Mission difficulty decreased. New parameters: ", 
          "Enemy Count: ", mission.enemy_count,
          "Enemy Toughness Modifier: ", mission.enemy_toughness_modifier,
          "Loot Quality Modifier: ", mission.loot_quality_modifier,
          "Environmental Hazards: ", mission.environmental_hazard_count)

func _handle_npc_interactions():
    for npc in mission.key_npcs:
        var interaction_result = _simulate_npc_interaction(npc)
        _apply_interaction_consequences(interaction_result)

func _simulate_npc_interaction(npc: String) -> Dictionary:
    var interaction_result = {}
    interaction_result["npc"] = npc
    
    # Get the character's savvy stat from the Character instance
    var savvy = character.savvy
    
    # Calculate success chance based on savvy (20% increase per point)
    var success_chance = 0.5 + (savvy * 0.2)
    success_chance = clamp(success_chance, 0.0, 1.0)  # Ensure it doesn't exceed 100%
    
    # Simulate interaction outcome
    var roll = randf()
    
    # Critical fail on a roll of 0.01 or less (1% chance)
    if roll <= 0.01:
        interaction_result["outcome"] = "critical_fail"
    elif roll > success_chance:
        interaction_result["outcome"] = "negative"
    else:
        interaction_result["outcome"] = "positive"
    
    # Simulate potential psionic influence (if implemented in the future)
    if randf() < 0.1:  # 10% chance of psionic involvement
        interaction_result["psionic_influence"] = true
        print("Psionic influence detected in NPC interaction with ", npc)
    
    print("NPC Interaction Result: ", interaction_result)
    return interaction_result

func _apply_interaction_consequences(interaction_result: Dictionary):
    if interaction_result.outcome == "positive":
        instability -= 1
    else:
        instability += 1

func _update_available_resources():
    for resource in mission.available_resources:
        mission.available_resources[resource] += randi() % 3 - 1  # -1 to 1
    print("Updated available resources: ", mission.available_resources)
