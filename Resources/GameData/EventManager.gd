class_name EventManager
extends Resource

signal event_triggered(event: Dictionary)
signal event_completed(event: Dictionary)
signal event_failed(event: Dictionary)
signal encounter_started(encounter: Dictionary)
signal encounter_resolved(encounter: Dictionary)

var game_state: GameState
var active_events: Array = []
var event_history: Array = []
var current_encounter: Dictionary = {}

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func check_for_events() -> void:
    if _should_trigger_event():
        var event = _generate_event()
        _trigger_event(event)

func check_for_encounters() -> void:
    if _should_trigger_encounter():
        var encounter = _generate_encounter()
        _start_encounter(encounter)

func resolve_event(event_id: String, choice: Dictionary) -> void:
    var event = _find_event(event_id)
    if event.is_empty():
        return
    
    var outcome = _process_event_choice(event, choice)
    if outcome.success:
        _complete_event(event, outcome)
    else:
        _fail_event(event, outcome)

func resolve_encounter(choice: Dictionary) -> void:
    if current_encounter.is_empty():
        return
    
    var outcome = _process_encounter_choice(current_encounter, choice)
    _resolve_encounter(outcome)

func get_active_events() -> Array:
    return active_events

func get_current_encounter() -> Dictionary:
    return current_encounter

func get_event_history() -> Array:
    return event_history

# Helper Functions
func _should_trigger_event() -> bool:
    var base_chance = 0.1  # 10% base chance per check
    
    # Modify based on world conditions
    var world = game_state.current_world
    if world:
        base_chance *= world.event_rate
    
    # Modify based on active events
    base_chance *= max(0.5, 1.0 - float(active_events.size()) / 3.0)
    
    return randf() <= base_chance

func _should_trigger_encounter() -> bool:
    if not current_encounter.is_empty():
        return false
    
    var base_chance = 0.05  # 5% base chance per check
    
    # Modify based on location
    var location = game_state.current_location
    if location:
        base_chance *= location.encounter_rate
    
    return randf() <= base_chance

func _generate_event() -> Dictionary:
    var event_type = _select_event_type()
    
    return {
        "id": "event_" + str(randi()),
        "type": event_type,
        "title": _generate_event_title(event_type),
        "description": _generate_event_description(event_type),
        "choices": _generate_event_choices(event_type),
        "requirements": _generate_event_requirements(event_type),
        "time_limit": _calculate_event_time_limit(event_type),
        "risk_level": _calculate_event_risk(event_type),
        "rewards": _generate_event_rewards(event_type)
    }

func _generate_encounter() -> Dictionary:
    var encounter_type = _select_encounter_type()
    
    return {
        "id": "encounter_" + str(randi()),
        "type": encounter_type,
        "title": _generate_encounter_title(encounter_type),
        "description": _generate_encounter_description(encounter_type),
        "participants": _generate_encounter_participants(encounter_type),
        "choices": _generate_encounter_choices(encounter_type),
        "conditions": _generate_encounter_conditions(encounter_type),
        "rewards": _generate_encounter_rewards(encounter_type)
    }

func _select_event_type() -> String:
    var types = ["DISTRESS", "DISCOVERY", "MYSTERY", "OPPORTUNITY", "CRISIS"]
    return types[randi() % types.size()]

func _select_encounter_type() -> String:
    var types = ["TRADER", "PATROL", "PIRATE", "DERELICT", "ANOMALY"]
    return types[randi() % types.size()]

func _generate_event_title(event_type: String) -> String:
    var titles = {
        "DISTRESS": ["Desperate Call", "Emergency Signal", "Urgent Request"],
        "DISCOVERY": ["Strange Finding", "Hidden Cache", "Ancient Secret"],
        "MYSTERY": ["Unexplained Phenomenon", "Cryptic Message", "Unusual Reading"],
        "OPPORTUNITY": ["Lucky Break", "Golden Chance", "Perfect Timing"],
        "CRISIS": ["Imminent Danger", "Critical Situation", "Dire Emergency"]
    }
    
    var type_titles = titles.get(event_type, ["Unknown Event"])
    return type_titles[randi() % type_titles.size()]

func _generate_event_description(event_type: String) -> String:
    var descriptions = {
        "DISTRESS": "A desperate signal calls for immediate assistance.",
        "DISCOVERY": "Sensors detect something of interest nearby.",
        "MYSTERY": "Strange readings suggest unusual activity in the area.",
        "OPPORTUNITY": "A potentially profitable situation presents itself.",
        "CRISIS": "A dangerous situation requires immediate attention."
    }
    
    return descriptions.get(event_type, "An event requires your attention.")

func _generate_event_choices(event_type: String) -> Array:
    var base_choices = [
        {
            "id": "investigate",
            "text": "Investigate",
            "requirements": {},
            "risk": 0.3
        },
        {
            "id": "ignore",
            "text": "Ignore",
            "requirements": {},
            "risk": 0.0
        }
    ]
    
    match event_type:
        "DISTRESS":
            base_choices.append({
                "id": "assist",
                "text": "Offer Assistance",
                "requirements": {"medical": 1},
                "risk": 0.2
            })
        "DISCOVERY":
            base_choices.append({
                "id": "analyze",
                "text": "Analyze",
                "requirements": {"science": 1},
                "risk": 0.1
            })
        "MYSTERY":
            base_choices.append({
                "id": "research",
                "text": "Research",
                "requirements": {"technical": 1},
                "risk": 0.2
            })
        "OPPORTUNITY":
            base_choices.append({
                "id": "exploit",
                "text": "Take Advantage",
                "requirements": {},
                "risk": 0.4
            })
        "CRISIS":
            base_choices.append({
                "id": "intervene",
                "text": "Intervene",
                "requirements": {"combat": 1},
                "risk": 0.5
            })
    
    return base_choices

func _generate_event_requirements(event_type: String) -> Dictionary:
    var requirements = {
        "min_crew": 1,
        "required_skills": {},
        "required_equipment": []
    }
    
    match event_type:
        "DISTRESS":
            requirements.min_crew = 2
            requirements.required_skills = {"medical": 1}
            requirements.required_equipment = ["med_kit"]
        "DISCOVERY":
            requirements.min_crew = 1
            requirements.required_skills = {"science": 1}
            requirements.required_equipment = ["scanner"]
        "MYSTERY":
            requirements.min_crew = 2
            requirements.required_skills = {"technical": 1}
            requirements.required_equipment = ["analyzer"]
        "OPPORTUNITY":
            requirements.min_crew = 1
            requirements.required_skills = {}
            requirements.required_equipment = []
        "CRISIS":
            requirements.min_crew = 3
            requirements.required_skills = {"combat": 1}
            requirements.required_equipment = ["weapons"]
    
    return requirements

func _calculate_event_time_limit(event_type: String) -> int:
    var base_time = 3600  # 1 hour in seconds
    
    match event_type:
        "DISTRESS":
            return base_time
        "DISCOVERY":
            return base_time * 4
        "MYSTERY":
            return base_time * 6
        "OPPORTUNITY":
            return base_time * 2
        "CRISIS":
            return base_time / 2
        _:
            return base_time * 3

func _calculate_event_risk(event_type: String) -> float:
    match event_type:
        "DISTRESS":
            return 0.3
        "DISCOVERY":
            return 0.2
        "MYSTERY":
            return 0.4
        "OPPORTUNITY":
            return 0.3
        "CRISIS":
            return 0.6
        _:
            return 0.3

func _generate_event_rewards(event_type: String) -> Dictionary:
    var base_rewards = {
        "credits": randi_range(100, 500),
        "reputation": randi_range(1, 5),
        "items": []
    }
    
    match event_type:
        "DISTRESS":
            base_rewards.credits *= 2
            base_rewards.reputation *= 2
        "DISCOVERY":
            base_rewards.items.append(_generate_discovery_item())
        "MYSTERY":
            base_rewards.items.append(_generate_mystery_item())
        "OPPORTUNITY":
            base_rewards.credits *= 3
        "CRISIS":
            base_rewards.reputation *= 3
            base_rewards.credits *= 2
    
    return base_rewards

func _generate_encounter_title(encounter_type: String) -> String:
    var titles = {
        "TRADER": ["Merchant Ship", "Trading Vessel", "Commerce Opportunity"],
        "PATROL": ["System Patrol", "Security Check", "Authority Presence"],
        "PIRATE": ["Hostile Contact", "Raider Threat", "Bandit Encounter"],
        "DERELICT": ["Abandoned Ship", "Ghost Vessel", "Floating Wreck"],
        "ANOMALY": ["Strange Reading", "Unknown Signal", "Mysterious Object"]
    }
    
    var type_titles = titles.get(encounter_type, ["Unknown Encounter"])
    return type_titles[randi() % type_titles.size()]

func _generate_encounter_description(encounter_type: String) -> String:
    var descriptions = {
        "TRADER": "A merchant vessel signals interest in trade.",
        "PATROL": "Local authorities request identification.",
        "PIRATE": "Hostile ships detected on an intercept course.",
        "DERELICT": "A seemingly abandoned vessel drifts nearby.",
        "ANOMALY": "Unusual energy readings detected in the vicinity."
    }
    
    return descriptions.get(encounter_type, "An encounter awaits.")

func _generate_encounter_participants(encounter_type: String) -> Array:
    var participants = []
    
    match encounter_type:
        "TRADER":
            participants.append(_generate_trader())
        "PATROL":
            participants.append_array(_generate_patrol_ships())
        "PIRATE":
            participants.append_array(_generate_hostile_ships())
        "DERELICT":
            participants.append(_generate_derelict())
        "ANOMALY":
            participants.append(_generate_anomaly())
    
    return participants

func _generate_encounter_choices(encounter_type: String) -> Array:
    var base_choices = [
        {
            "id": "approach",
            "text": "Approach",
            "requirements": {},
            "risk": 0.2
        },
        {
            "id": "avoid",
            "text": "Avoid",
            "requirements": {},
            "risk": 0.0
        }
    ]
    
    match encounter_type:
        "TRADER":
            base_choices.append({
                "id": "trade",
                "text": "Initiate Trade",
                "requirements": {"negotiation": 1},
                "risk": 0.1
            })
        "PATROL":
            base_choices.append({
                "id": "cooperate",
                "text": "Submit to Inspection",
                "requirements": {},
                "risk": 0.1
            })
        "PIRATE":
            base_choices.append({
                "id": "fight",
                "text": "Engage",
                "requirements": {"combat": 1},
                "risk": 0.6
            })
        "DERELICT":
            base_choices.append({
                "id": "salvage",
                "text": "Salvage",
                "requirements": {"technical": 1},
                "risk": 0.3
            })
        "ANOMALY":
            base_choices.append({
                "id": "study",
                "text": "Study",
                "requirements": {"science": 1},
                "risk": 0.4
            })
    
    return base_choices

func _generate_encounter_conditions(encounter_type: String) -> Dictionary:
    return {
        "time_limit": _calculate_encounter_time_limit(encounter_type),
        "escape_difficulty": _calculate_escape_difficulty(encounter_type),
        "combat_difficulty": _calculate_combat_difficulty(encounter_type),
        "special_conditions": _generate_special_conditions(encounter_type)
    }

func _generate_encounter_rewards(encounter_type: String) -> Dictionary:
    var base_rewards = {
        "credits": randi_range(200, 1000),
        "reputation": randi_range(1, 3),
        "items": []
    }
    
    match encounter_type:
        "TRADER":
            base_rewards.credits = 0  # Trading is handled separately
        "PATROL":
            base_rewards.reputation *= 2
        "PIRATE":
            base_rewards.credits *= 2
            base_rewards.items.append(_generate_combat_loot())
        "DERELICT":
            base_rewards.items.append(_generate_salvage_loot())
        "ANOMALY":
            base_rewards.items.append(_generate_anomaly_loot())
    
    return base_rewards

func _generate_trader() -> Dictionary:
    return {
        "type": "TRADER",
        "ship_class": _select_trader_ship(),
        "inventory": _generate_trade_inventory(),
        "prices": _generate_trade_prices(),
        "disposition": randf_range(0.5, 1.0)
    }

func _generate_patrol_ships() -> Array:
    var num_ships = randi_range(1, 3)
    var ships = []
    
    for i in range(num_ships):
        ships.append({
            "type": "PATROL",
            "ship_class": _select_patrol_ship(),
            "combat_rating": randi_range(2, 4),
            "disposition": randf_range(0.4, 0.8)
        })
    
    return ships

func _generate_hostile_ships() -> Array:
    var num_ships = randi_range(1, 4)
    var ships = []
    
    for i in range(num_ships):
        ships.append({
            "type": "PIRATE",
            "ship_class": _select_pirate_ship(),
            "combat_rating": randi_range(1, 3),
            "disposition": randf_range(0.0, 0.3)
        })
    
    return ships

func _generate_derelict() -> Dictionary:
    return {
        "type": "DERELICT",
        "ship_class": _select_derelict_ship(),
        "condition": randf_range(0.2, 0.6),
        "hazard_level": randi_range(1, 3),
        "salvage_difficulty": randi_range(1, 4)
    }

func _generate_anomaly() -> Dictionary:
    return {
        "type": "ANOMALY",
        "category": _select_anomaly_type(),
        "intensity": randi_range(1, 5),
        "stability": randf_range(0.3, 0.8),
        "research_value": randi_range(1, 5)
    }

func _select_trader_ship() -> String:
    var ships = ["Merchant Vessel", "Trading Ship", "Cargo Hauler"]
    return ships[randi() % ships.size()]

func _select_patrol_ship() -> String:
    var ships = ["System Security", "Patrol Craft", "Authority Vessel"]
    return ships[randi() % ships.size()]

func _select_pirate_ship() -> String:
    var ships = ["Raider", "Corsair", "Marauder"]
    return ships[randi() % ships.size()]

func _select_derelict_ship() -> String:
    var ships = ["Abandoned Freighter", "Ghost Ship", "Wrecked Vessel"]
    return ships[randi() % ships.size()]

func _select_anomaly_type() -> String:
    var types = ["TEMPORAL", "SPATIAL", "QUANTUM", "ENERGY"]
    return types[randi() % types.size()]

func _generate_trade_inventory() -> Array:
    var inventory = []
    var num_items = randi_range(3, 8)
    
    for i in range(num_items):
        inventory.append({
            "item": _generate_trade_item(),
            "quantity": randi_range(1, 5)
        })
    
    return inventory

func _generate_trade_prices() -> Dictionary:
    return {
        "buy_modifier": randf_range(0.8, 1.2),
        "sell_modifier": randf_range(0.8, 1.2)
    }

func _calculate_encounter_time_limit(encounter_type: String) -> int:
    var base_time = 1800  # 30 minutes in seconds
    
    match encounter_type:
        "TRADER":
            return base_time * 2
        "PATROL":
            return base_time
        "PIRATE":
            return base_time / 2
        "DERELICT":
            return base_time * 3
        "ANOMALY":
            return base_time * 4
        _:
            return base_time

func _calculate_escape_difficulty(encounter_type: String) -> float:
    match encounter_type:
        "TRADER":
            return 0.1
        "PATROL":
            return 0.4
        "PIRATE":
            return 0.6
        "DERELICT":
            return 0.2
        "ANOMALY":
            return 0.3
        _:
            return 0.3

func _calculate_combat_difficulty(encounter_type: String) -> float:
    match encounter_type:
        "TRADER":
            return 0.2
        "PATROL":
            return 0.5
        "PIRATE":
            return 0.7
        "DERELICT":
            return 0.3
        "ANOMALY":
            return 0.4
        _:
            return 0.4

func _generate_special_conditions(encounter_type: String) -> Array:
    var conditions = []
    
    match encounter_type:
        "TRADER":
            if randf() <= 0.3:
                conditions.append("RARE_GOODS")
        "PATROL":
            if randf() <= 0.2:
                conditions.append("HIGH_ALERT")
        "PIRATE":
            if randf() <= 0.25:
                conditions.append("AMBUSH")
        "DERELICT":
            if randf() <= 0.4:
                conditions.append("UNSTABLE")
        "ANOMALY":
            if randf() <= 0.5:
                conditions.append("FLUCTUATING")
    
    return conditions

func _generate_discovery_item() -> Dictionary:
    return {
        "type": "ARTIFACT",
        "rarity": "RARE",
        "value": randi_range(500, 2000)
    }

func _generate_mystery_item() -> Dictionary:
    return {
        "type": "DATA",
        "rarity": "UNCOMMON",
        "value": randi_range(300, 1500)
    }

func _generate_combat_loot() -> Dictionary:
    return {
        "type": "WEAPON",
        "rarity": "UNCOMMON",
        "value": randi_range(400, 1200)
    }

func _generate_salvage_loot() -> Dictionary:
    return {
        "type": "COMPONENTS",
        "rarity": "COMMON",
        "value": randi_range(200, 800)
    }

func _generate_anomaly_loot() -> Dictionary:
    return {
        "type": "EXOTIC",
        "rarity": "RARE",
        "value": randi_range(1000, 3000)
    }

func _generate_trade_item() -> Dictionary:
    var types = ["SUPPLIES", "MATERIALS", "EQUIPMENT", "LUXURY"]
    return {
        "type": types[randi() % types.size()],
        "rarity": "COMMON",
        "value": randi_range(100, 500)
    }

func _trigger_event(event: Dictionary) -> void:
    active_events.append(event)
    event_triggered.emit(event)

func _start_encounter(encounter: Dictionary) -> void:
    current_encounter = encounter
    encounter_started.emit(encounter)

func _find_event(event_id: String) -> Dictionary:
    for event in active_events:
        if event.id == event_id:
            return event
    return {}

func _process_event_choice(event: Dictionary, choice: Dictionary) -> Dictionary:
    var success = _calculate_choice_success(event, choice)
    var rewards = _calculate_choice_rewards(event, choice) if success else {}
    var consequences = _calculate_choice_consequences(event, choice)
    
    return {
        "success": success,
        "rewards": rewards,
        "consequences": consequences
    }

func _process_encounter_choice(encounter: Dictionary, choice: Dictionary) -> Dictionary:
    var success = _calculate_encounter_success(encounter, choice)
    var rewards = _calculate_encounter_rewards(encounter, choice) if success else {}
    var consequences = _calculate_encounter_consequences(encounter, choice)
    
    return {
        "success": success,
        "rewards": rewards,
        "consequences": consequences
    }

func _calculate_choice_success(event: Dictionary, choice: Dictionary) -> bool:
    var base_chance = 0.7
    
    # Modify based on requirements
    if "requirements" in choice:
        for skill in choice.requirements:
            if not game_state.crew.has_skill_level(skill, choice.requirements[skill]):
                base_chance *= 0.5
    
    # Modify based on risk
    base_chance *= (1.0 - (choice.get("risk", 0.0) * 0.5))
    
    return randf() <= base_chance

func _calculate_choice_rewards(event: Dictionary, choice: Dictionary) -> Dictionary:
    var rewards = event.rewards.duplicate()
    
    # Modify based on choice
    match choice.id:
        "investigate":
            rewards.credits = int(rewards.credits * 1.2)
        "assist":
            rewards.reputation = int(rewards.reputation * 1.5)
        "analyze":
            rewards.items.append(_generate_discovery_item())
        "research":
            rewards.items.append(_generate_mystery_item())
    
    return rewards

func _calculate_choice_consequences(event: Dictionary, choice: Dictionary) -> Array:
    var consequences = []
    
    if "risk" in choice and randf() <= choice.risk:
        consequences.append(_generate_consequence(event.type))
    
    return consequences

func _calculate_encounter_success(encounter: Dictionary, choice: Dictionary) -> bool:
    var base_chance = 0.6
    
    # Modify based on encounter type
    match encounter.type:
        "TRADER":
            base_chance = 0.8
        "PATROL":
            base_chance = 0.7
        "PIRATE":
            base_chance = 0.5
        "DERELICT":
            base_chance = 0.6
        "ANOMALY":
            base_chance = 0.5
    
    # Modify based on choice
    match choice.id:
        "avoid":
            base_chance = 0.9
        "fight":
            base_chance = 0.5
        "trade":
            base_chance = 0.8
    
    return randf() <= base_chance

func _calculate_encounter_rewards(encounter: Dictionary, choice: Dictionary) -> Dictionary:
    var rewards = encounter.rewards.duplicate()
    
    # Modify based on choice
    match choice.id:
        "trade":
            rewards.credits = int(rewards.credits * 1.5)
        "fight":
            rewards.credits = int(rewards.credits * 2.0)
        "salvage":
            rewards.items.append(_generate_salvage_loot())
        "study":
            rewards.items.append(_generate_anomaly_loot())
    
    return rewards

func _calculate_encounter_consequences(encounter: Dictionary, choice: Dictionary) -> Array:
    var consequences = []
    
    # Add consequences based on encounter type and choice
    match encounter.type:
        "PIRATE":
            if choice.id == "fight" and randf() <= 0.3:
                consequences.append("SHIP_DAMAGE")
        "DERELICT":
            if choice.id == "salvage" and randf() <= 0.2:
                consequences.append("CREW_INJURY")
        "ANOMALY":
            if choice.id == "study" and randf() <= 0.25:
                consequences.append("SYSTEM_MALFUNCTION")
    
    return consequences

func _generate_consequence(event_type: String) -> String:
    var consequences = {
        "DISTRESS": ["CREW_INJURY", "REPUTATION_LOSS", "RESOURCE_LOSS"],
        "DISCOVERY": ["EQUIPMENT_DAMAGE", "CREW_FATIGUE", "DATA_CORRUPTION"],
        "MYSTERY": ["SYSTEM_MALFUNCTION", "CREW_CONFUSION", "ENERGY_DRAIN"],
        "OPPORTUNITY": ["MISSED_CHANCE", "RIVAL_GAIN", "RESOURCE_WASTE"],
        "CRISIS": ["SHIP_DAMAGE", "CREW_CASUALTY", "SYSTEM_FAILURE"]
    }
    
    var type_consequences = consequences.get(event_type, ["MINOR_SETBACK"])
    return type_consequences[randi() % type_consequences.size()]

func _complete_event(event: Dictionary, outcome: Dictionary) -> void:
    active_events.erase(event)
    event_history.append({
        "event": event,
        "outcome": outcome,
        "completion_time": Time.get_unix_time_from_system(),
        "success": true
    })
    
    event_completed.emit(event)

func _fail_event(event: Dictionary, outcome: Dictionary) -> void:
    active_events.erase(event)
    event_history.append({
        "event": event,
        "outcome": outcome,
        "completion_time": Time.get_unix_time_from_system(),
        "success": false
    })
    
    event_failed.emit(event)

func _resolve_encounter(outcome: Dictionary) -> void:
    if not current_encounter.is_empty():
        var encounter = current_encounter
        current_encounter = {}
        
        encounter_resolved.emit({
            "encounter": encounter,
            "outcome": outcome,
            "resolution_time": Time.get_unix_time_from_system()
        }) 