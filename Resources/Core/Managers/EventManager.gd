class_name EventManager
extends Resource

signal event_triggered(event_data: Dictionary)
signal event_completed(event_id: String)
signal event_chain_progressed(chain_id: String, stage: int)

const EVENT_TYPES = {
    "combat": {
        "weight": 3,
        "min_reputation": 0,
        "rewards": {
            "credits": [50, 200],
            "reputation": [1, 3]
        }
    },
    "trade": {
        "weight": 2,
        "min_reputation": 0,
        "rewards": {
            "credits": [100, 300],
            "supplies": [10, 30]
        }
    },
    "exploration": {
        "weight": 2,
        "min_reputation": 1,
        "rewards": {
            "credits": [150, 400],
            "fuel": [20, 50]
        }
    },
    "rescue": {
        "weight": 1,
        "min_reputation": 2,
        "rewards": {
            "credits": [200, 500],
            "reputation": [2, 4]
        }
    }
}

const TRAVEL_EVENTS = {
    "pirate_ambush": {
        "type": "combat",
        "weight": 3,
        "conditions": {
            "min_cargo_value": 100,
            "max_reputation": 5
        }
    },
    "distress_signal": {
        "type": "rescue",
        "weight": 2,
        "conditions": {
            "min_reputation": 2
        }
    },
    "trade_opportunity": {
        "type": "trade",
        "weight": 2,
        "conditions": {
            "min_credits": 200
        }
    },
    "salvage_opportunity": {
        "type": "exploration",
        "weight": 2,
        "conditions": {
            "min_fuel": 20
        }
    },
    "system_malfunction": {
        "type": "hazard",
        "weight": 1,
        "conditions": {}
    }
}

var active_events: Array[Dictionary] = []
var completed_events: Array[Dictionary] = []
var event_chains: Dictionary = {}
var current_location_events: Array[Dictionary] = []

# Event generation state
var rng = RandomNumberGenerator.new()
var last_event_type: String = ""
var event_cooldowns: Dictionary = {}

func _init() -> void:
    rng.randomize()

func generate_event(location: Location, campaign_state: Dictionary) -> Dictionary:
    var available_types = _get_available_event_types(campaign_state)
    if available_types.is_empty():
        return {}
    
    var event_type = _select_event_type(available_types)
    var event = _create_event(event_type, location, campaign_state)
    
    if not event.is_empty():
        active_events.append(event)
        event_triggered.emit(event)
    
    return event

func generate_travel_event(route: Dictionary, campaign_state: Dictionary) -> Dictionary:
    var available_events = _get_available_travel_events(campaign_state)
    if available_events.is_empty():
        return {}
    
    var event_id = _select_travel_event(available_events, route)
    var event = _create_travel_event(event_id, route, campaign_state)
    
    if not event.is_empty():
        active_events.append(event)
        event_triggered.emit(event)
    
    return event

func _get_available_event_types(campaign_state: Dictionary) -> Array:
    var available = []
    var reputation = campaign_state.get("reputation", 0)
    
    for type in EVENT_TYPES:
        if reputation >= EVENT_TYPES[type].min_reputation and \
           not _is_on_cooldown(type):
            available.append(type)
    
    return available

func _get_available_travel_events(campaign_state: Dictionary) -> Array:
    var available = []
    
    for event_id in TRAVEL_EVENTS:
        if _meets_travel_event_conditions(event_id, campaign_state) and \
           not _is_on_cooldown(event_id):
            available.append(event_id)
    
    return available

func _meets_travel_event_conditions(event_id: String, campaign_state: Dictionary) -> bool:
    var event = TRAVEL_EVENTS[event_id]
    var conditions = event.conditions
    
    for condition in conditions:
        match condition:
            "min_cargo_value":
                if _calculate_cargo_value(campaign_state) < conditions[condition]:
                    return false
            "max_reputation":
                if campaign_state.get("reputation", 0) > conditions[condition]:
                    return false
            "min_reputation":
                if campaign_state.get("reputation", 0) < conditions[condition]:
                    return false
            "min_credits":
                if campaign_state.get("credits", 0) < conditions[condition]:
                    return false
            "min_fuel":
                if campaign_state.get("fuel", 0) < conditions[condition]:
                    return false
    
    return true

func _calculate_cargo_value(campaign_state: Dictionary) -> int:
    var total_value = 0
    var inventory = campaign_state.get("inventory", {})
    
    for item in inventory:
        total_value += inventory[item].get("value", 0) * inventory[item].get("quantity", 0)
    
    return total_value

func _select_event_type(available_types: Array) -> String:
    var total_weight = 0
    for type in available_types:
        total_weight += EVENT_TYPES[type].weight
    
    var roll = rng.randi_range(1, total_weight)
    var current_weight = 0
    
    for type in available_types:
        current_weight += EVENT_TYPES[type].weight
        if roll <= current_weight:
            return type
    
    return available_types[-1]  # Fallback to last type

func _select_travel_event(available_events: Array, route: Dictionary) -> String:
    var weighted_events = []
    
    for event_id in available_events:
        var event = TRAVEL_EVENTS[event_id]
        var weight = event.weight
        
        # Adjust weight based on route properties
        match event.type:
            "combat":
                weight *= (1.0 + route.get("hazard_level", 0) * 0.2)
            "rescue":
                weight *= (1.0 + route.get("distance", 1) * 0.1)
            "exploration":
                weight *= (1.0 + route.get("terrain_difficulty", 0) * 0.15)
        
        weighted_events.append({
            "id": event_id,
            "weight": weight
        })
    
    var total_weight = weighted_events.reduce(
        func(acc, event): return acc + event.weight,
        0.0
    )
    
    var roll = randf() * total_weight
    var current_weight = 0.0
    
    for event in weighted_events:
        current_weight += event.weight
        if roll <= current_weight:
            return event.id
    
    return weighted_events[-1].id  # Fallback to last event

func _create_event(event_type: String, location: Location, campaign_state: Dictionary) -> Dictionary:
    var event = {
        "id": "event_" + str(randi()),
        "type": event_type,
        "location": location,
        "rewards": _generate_rewards(event_type),
        "requirements": _generate_requirements(event_type, campaign_state),
        "description": _generate_event_description(event_type, location)
    }
    
    # Add type-specific data
    match event_type:
        "combat":
            event.merge(_generate_combat_event(campaign_state))
        "trade":
            event.merge(_generate_trade_event(campaign_state))
        "exploration":
            event.merge(_generate_exploration_event(location))
        "rescue":
            event.merge(_generate_rescue_event(campaign_state))
    
    return event

func _create_travel_event(event_id: String, route: Dictionary, campaign_state: Dictionary) -> Dictionary:
    var event_template = TRAVEL_EVENTS[event_id]
    
    var event = {
        "id": "travel_" + str(randi()),
        "type": event_template.type,
        "event_id": event_id,
        "route": route,
        "description": _generate_travel_event_description(event_id, route)
    }
    
    # Add type-specific data
    match event_template.type:
        "combat":
            event.merge(_generate_travel_combat_event(campaign_state))
        "rescue":
            event.merge(_generate_travel_rescue_event(route))
        "trade":
            event.merge(_generate_travel_trade_event(campaign_state))
        "exploration":
            event.merge(_generate_travel_exploration_event(route))
        "hazard":
            event.merge(_generate_travel_hazard_event(route))
    
    return event

func _generate_rewards(event_type: String) -> Dictionary:
    var rewards = {}
    var event_rewards = EVENT_TYPES[event_type].rewards
    
    for reward_type in event_rewards:
        var min_value = event_rewards[reward_type][0]
        var max_value = event_rewards[reward_type][1]
        rewards[reward_type] = rng.randi_range(min_value, max_value)
    
    return rewards

func _generate_requirements(event_type: String, campaign_state: Dictionary) -> Dictionary:
    var requirements = {}
    
    match event_type:
        "combat":
            requirements["min_crew"] = 2
            requirements["min_combat_rating"] = 1
        "trade":
            requirements["min_credits"] = 100
        "exploration":
            requirements["min_fuel"] = 10
        "rescue":
            requirements["min_medical_supplies"] = 1
    
    return requirements

func _generate_event_description(event_type: String, location: Location) -> String:
    var descriptions = {
        "combat": [
            "Local threats have been spotted in the area.",
            "Reports of hostile activity nearby.",
            "Security alert in the vicinity."
        ],
        "trade": [
            "A merchant caravan is passing through.",
            "Local market has special offerings.",
            "Trade opportunity detected."
        ],
        "exploration": [
            "Unusual readings detected nearby.",
            "Unexplored territory ahead.",
            "Strange signals coming from the area."
        ],
        "rescue": [
            "Distress signal detected.",
            "Emergency situation reported.",
            "Rescue operation requested."
        ]
    }
    
    var type_descriptions = descriptions[event_type]
    return type_descriptions[rng.randi() % type_descriptions.size()]

func _generate_travel_event_description(event_id: String, route: Dictionary) -> String:
    var descriptions = {
        "pirate_ambush": [
            "Warning: Hostile ships detected!",
            "Pirates incoming!",
            "Ambush alert!"
        ],
        "distress_signal": [
            "Picking up an SOS signal...",
            "Emergency beacon detected.",
            "Distress call incoming."
        ],
        "trade_opportunity": [
            "Trade convoy spotted.",
            "Merchant ship hailing.",
            "Commerce opportunity detected."
        ],
        "salvage_opportunity": [
            "Debris field detected.",
            "Abandoned vessel nearby.",
            "Salvage opportunity ahead."
        ],
        "system_malfunction": [
            "Warning: System malfunction detected.",
            "Critical system error.",
            "Emergency maintenance required."
        ]
    }
    
    var event_descriptions = descriptions[event_id]
    return event_descriptions[rng.randi() % event_descriptions.size()]

func _generate_combat_event(campaign_state: Dictionary) -> Dictionary:
    return {
        "enemies": _generate_enemy_group(campaign_state),
        "difficulty": 1 + floori(campaign_state.get("reputation", 0) / 3.0),
        "terrain_modifiers": _generate_terrain_modifiers()
    }

func _generate_trade_event(campaign_state: Dictionary) -> Dictionary:
    return {
        "offers": _generate_trade_offers(campaign_state),
        "duration": 2,  # Available for 2 days
        "reputation_requirement": maxi(0, campaign_state.get("reputation", 0) - 1)
    }

func _generate_exploration_event(location: Location) -> Dictionary:
    return {
        "area_size": 2 + randi() % 3,
        "hazard_level": location.threat_level,
        "special_discoveries": _generate_discoveries()
    }

func _generate_rescue_event(campaign_state: Dictionary) -> Dictionary:
    return {
        "time_limit": 3,  # 3 days to complete
        "difficulty": 1 + floori(campaign_state.get("reputation", 0) / 2.0),
        "complications": _generate_complications()
    }

func _generate_travel_combat_event(campaign_state: Dictionary) -> Dictionary:
    return {
        "enemies": _generate_enemy_group(campaign_state),
        "escape_chance": 0.3 + (campaign_state.get("pilot_skill", 0) * 0.1),
        "ambush_modifier": -2
    }

func _generate_travel_rescue_event(route: Dictionary) -> Dictionary:
    return {
        "time_limit": 2,
        "distance_modifier": route.get("distance", 1) * 0.5,
        "reward_multiplier": 1.0 + (route.get("hazard_level", 0) * 0.2)
    }

func _generate_travel_trade_event(campaign_state: Dictionary) -> Dictionary:
    return {
        "offers": _generate_trade_offers(campaign_state),
        "negotiation_bonus": campaign_state.get("trade_skill", 0) * 0.05,
        "limited_time": true
    }

func _generate_travel_exploration_event(route: Dictionary) -> Dictionary:
    return {
        "scan_difficulty": 1 + route.get("terrain_difficulty", 0),
        "resource_multiplier": 1.0 + (route.get("distance", 1) * 0.1),
        "discoveries": _generate_discoveries()
    }

func _generate_travel_hazard_event(route: Dictionary) -> Dictionary:
    return {
        "severity": 1 + floori(route.get("hazard_level", 0) / 2.0),
        "repair_difficulty": 1 + route.get("terrain_difficulty", 0),
        "affected_systems": _generate_affected_systems()
    }

func _generate_enemy_group(campaign_state: Dictionary) -> Array:
    var enemies = []
    var difficulty = 1 + floori(campaign_state.get("reputation", 0) / 3.0)
    var group_size = 1 + difficulty + randi() % 3
    
    for i in range(group_size):
        enemies.append({
            "type": _select_enemy_type(difficulty),
            "level": 1 + randi() % difficulty
        })
    
    return enemies

func _generate_trade_offers(campaign_state: Dictionary) -> Array:
    var offers = []
    var offer_count = 2 + randi() % 3
    
    for i in range(offer_count):
        offers.append({
            "item": _select_trade_item(),
            "quantity": 5 + randi() % 16,
            "price": (50 + randi() % 151) * (1.0 - campaign_state.get("reputation", 0) * 0.05)
        })
    
    return offers

func _generate_discoveries() -> Array:
    var discoveries = []
    var discovery_count = 1 + randi() % 3
    
    for i in range(discovery_count):
        discoveries.append({
            "type": _select_discovery_type(),
            "value": 100 + randi() % 401,
            "rarity": 1 + randi() % 3
        })
    
    return discoveries

func _generate_complications() -> Array:
    var complications = []
    var complication_count = 1 + randi() % 2
    
    for i in range(complication_count):
        complications.append({
            "type": _select_complication_type(),
            "severity": 1 + randi() % 3
        })
    
    return complications

func _generate_terrain_modifiers() -> Array:
    var modifiers = []
    var modifier_count = 1 + randi() % 3
    
    for i in range(modifier_count):
        modifiers.append({
            "type": _select_terrain_modifier(),
            "effect": _generate_modifier_effect()
        })
    
    return modifiers

func _generate_affected_systems() -> Array:
    var systems = []
    var system_count = 1 + randi() % 3
    var possible_systems = ["engines", "weapons", "shields", "life_support", "sensors"]
    
    for i in range(system_count):
        if possible_systems.is_empty():
            break
        var system_index = randi() % possible_systems.size()
        systems.append({
            "name": possible_systems[system_index],
            "damage": 1 + randi() % 3
        })
        possible_systems.remove_at(system_index)
    
    return systems

func _select_enemy_type(difficulty: int) -> String:
    var types = ["grunt", "elite", "specialist", "commander"]
    return types[mini(difficulty - 1, types.size() - 1)]

func _select_trade_item() -> String:
    var items = ["fuel", "supplies", "weapons", "equipment", "medical"]
    return items[randi() % items.size()]

func _select_discovery_type() -> String:
    var types = ["artifact", "resource", "technology", "data"]
    return types[randi() % types.size()]

func _select_complication_type() -> String:
    var types = ["time_pressure", "environmental", "enemy_reinforcements", "equipment_failure"]
    return types[randi() % types.size()]

func _select_terrain_modifier() -> String:
    var modifiers = ["cover", "hazard", "visibility", "movement"]
    return modifiers[randi() % modifiers.size()]

func _generate_modifier_effect() -> Dictionary:
    return {
        "stat": ["accuracy", "defense", "movement", "detection"][randi() % 4],
        "value": [-2, -1, 1, 2][randi() % 4]
    }

func _is_on_cooldown(event_type: String) -> bool:
    if not event_cooldowns.has(event_type):
        return false
    return event_cooldowns[event_type] > 0

func update_cooldowns() -> void:
    var keys = event_cooldowns.keys()
    for key in keys:
        event_cooldowns[key] = maxi(0, event_cooldowns[key] - 1)

func complete_event(event_id: String) -> void:
    var event_index = -1
    for i in range(active_events.size()):
        if active_events[i].id == event_id:
            event_index = i
            break
    
    if event_index >= 0:
        var event = active_events[event_index]
        completed_events.append(event)
        active_events.remove_at(event_index)
        
        # Set cooldown for this event type
        event_cooldowns[event.type] = 3  # 3 days cooldown
        
        event_completed.emit(event_id)

func get_active_events() -> Array[Dictionary]:
    return active_events

func get_completed_events() -> Array[Dictionary]:
    return completed_events

func serialize() -> Dictionary:
    return {
        "active_events": active_events,
        "completed_events": completed_events,
        "event_chains": event_chains,
        "current_location_events": current_location_events,
        "last_event_type": last_event_type,
        "event_cooldowns": event_cooldowns
    }

static func deserialize(data: Dictionary) -> EventManager:
    var manager = EventManager.new()
    
    manager.active_events = data.get("active_events", [])
    manager.completed_events = data.get("completed_events", [])
    manager.event_chains = data.get("event_chains", {})
    manager.current_location_events = data.get("current_location_events", [])
    manager.last_event_type = data.get("last_event_type", "")
    manager.event_cooldowns = data.get("event_cooldowns", {})
    
    return manager 