class_name SalvageSystem
extends Resource

signal salvage_started(battlefield: Dictionary)
signal salvage_completed(results: Dictionary)
signal salvage_item_found(item: Dictionary)
signal hazard_encountered(hazard: Dictionary)

var game_state: GameState
var current_salvage_operation: Dictionary
var salvage_results: Array = []

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func start_salvage_operation(battlefield: Dictionary) -> void:
    if not _validate_battlefield(battlefield):
        push_error("Invalid battlefield data")
        return
    
    current_salvage_operation = {
        "battlefield": battlefield,
        "areas_searched": [],
        "items_found": [],
        "hazards_encountered": [],
        "time_started": Time.get_unix_time_from_system()
    }
    
    salvage_started.emit(battlefield)

func search_area(area: Dictionary) -> Dictionary:
    if not current_salvage_operation or area in current_salvage_operation.areas_searched:
        return {}
    
    var result = {
        "items": [],
        "hazards": [],
        "time_spent": 0
    }
    
    # Check for hazards first
    var hazards = _check_for_hazards(area)
    if not hazards.is_empty():
        result.hazards = hazards
        for hazard in hazards:
            hazard_encountered.emit(hazard)
            if hazard.severity == "CRITICAL":
                return result
    
    # Search for salvageable items
    var items = _search_for_items(area)
    result.items = items
    for item in items:
        salvage_item_found.emit(item)
    
    current_salvage_operation.areas_searched.append(area)
    current_salvage_operation.items_found.append_array(items)
    current_salvage_operation.hazards_encountered.append_array(hazards)
    
    return result

func complete_salvage_operation() -> Dictionary:
    if not current_salvage_operation:
        return {}
    
    var results = _compile_salvage_results()
    salvage_results.append(results)
    salvage_completed.emit(results)
    
    var operation = current_salvage_operation
    current_salvage_operation = {}
    
    return results

func get_salvage_progress() -> float:
    if not current_salvage_operation or current_salvage_operation.battlefield.areas.is_empty():
        return 0.0
    
    return float(current_salvage_operation.areas_searched.size()) / current_salvage_operation.battlefield.areas.size()

func get_current_hazards() -> Array:
    if not current_salvage_operation:
        return []
    
    return current_salvage_operation.hazards_encountered

func get_found_items() -> Array:
    if not current_salvage_operation:
        return []
    
    return current_salvage_operation.items_found

func can_salvage_area(area: Dictionary) -> bool:
    if not current_salvage_operation:
        return false
    
    # Check if area has already been searched
    if area in current_salvage_operation.areas_searched:
        return false
    
    # Check if area is accessible
    if not _is_area_accessible(area):
        return false
    
    # Check if crew has required equipment
    if not _has_required_equipment(area):
        return false
    
    return true

# Helper Functions
func _validate_battlefield(battlefield: Dictionary) -> bool:
    return battlefield.has_all(["areas", "difficulty", "environment"])

func _check_for_hazards(area: Dictionary) -> Array:
    var hazards = []
    var base_hazard_chance = _calculate_base_hazard_chance(area)
    
    # Check for environmental hazards
    if randf() <= base_hazard_chance:
        hazards.append(_generate_environmental_hazard(area))
    
    # Check for combat hazards (remaining enemies, traps)
    if randf() <= base_hazard_chance * 0.5:
        hazards.append(_generate_combat_hazard(area))
    
    # Check for special hazards based on battlefield type
    var special_hazards = _check_special_hazards(area)
    hazards.append_array(special_hazards)
    
    return hazards

func _search_for_items(area: Dictionary) -> Array:
    var items = []
    var search_efficiency = _calculate_search_efficiency()
    
    # Search for basic salvage
    var basic_items = _find_basic_salvage(area, search_efficiency)
    items.append_array(basic_items)
    
    # Search for valuable items
    var valuable_items = _find_valuable_items(area, search_efficiency)
    items.append_array(valuable_items)
    
    # Search for special items based on battlefield type
    var special_items = _find_special_items(area, search_efficiency)
    items.append_array(special_items)
    
    return items

func _calculate_base_hazard_chance(area: Dictionary) -> float:
    var base_chance = 0.2  # 20% base chance
    
    # Modify based on area condition
    base_chance *= area.get("danger_level", 1.0)
    
    # Modify based on environment
    var environment = current_salvage_operation.battlefield.environment
    base_chance *= environment.get("hazard_multiplier", 1.0)
    
    # Modify based on time spent salvaging
    var time_factor = (Time.get_unix_time_from_system() - current_salvage_operation.time_started) / 3600.0
    base_chance += time_factor * 0.05  # Increase by 5% per hour
    
    return clamp(base_chance, 0.1, 0.8)

func _calculate_search_efficiency() -> float:
    var base_efficiency = 0.5  # 50% base efficiency
    
    # Modify based on crew skills
    for crew_member in game_state.crew.active_members:
        base_efficiency += crew_member.get_skill_level("salvage") * 0.1
    
    # Modify based on equipment
    if game_state.has_equipment("scanner"):
        base_efficiency += 0.2
    if game_state.has_equipment("salvage_tools"):
        base_efficiency += 0.15
    
    # Modify based on visibility conditions
    var environment = current_salvage_operation.battlefield.environment
    base_efficiency *= environment.get("visibility_modifier", 1.0)
    
    return clamp(base_efficiency, 0.1, 0.9)

func _generate_environmental_hazard(area: Dictionary) -> Dictionary:
    var hazard_types = ["RADIATION", "TOXIC", "STRUCTURAL", "ELECTRICAL"]
    var selected_type = hazard_types[randi() % hazard_types.size()]
    
    return {
        "type": "ENVIRONMENTAL",
        "subtype": selected_type,
        "severity": _determine_hazard_severity(),
        "area": area,
        "effects": _generate_hazard_effects(selected_type)
    }

func _generate_combat_hazard(area: Dictionary) -> Dictionary:
    var hazard_types = ["ENEMY", "TRAP", "MINE"]
    var selected_type = hazard_types[randi() % hazard_types.size()]
    
    return {
        "type": "COMBAT",
        "subtype": selected_type,
        "severity": _determine_hazard_severity(),
        "area": area,
        "effects": _generate_hazard_effects(selected_type)
    }

func _determine_hazard_severity() -> String:
    var roll = randf()
    if roll < 0.6:
        return "MINOR"
    elif roll < 0.9:
        return "MAJOR"
    else:
        return "CRITICAL"

func _generate_hazard_effects(hazard_type: String) -> Dictionary:
    match hazard_type:
        "RADIATION":
            return {
                "damage_type": "radiation",
                "damage_per_turn": randi_range(5, 15),
                "duration": randi_range(3, 8)
            }
        "TOXIC":
            return {
                "damage_type": "poison",
                "damage_per_turn": randi_range(3, 10),
                "duration": randi_range(5, 12)
            }
        "STRUCTURAL":
            return {
                "damage_type": "physical",
                "damage": randi_range(10, 30),
                "area_denial": true
            }
        "ELECTRICAL":
            return {
                "damage_type": "electrical",
                "damage": randi_range(15, 25),
                "equipment_damage": true
            }
        "ENEMY":
            return {
                "enemy_type": _select_enemy_type(),
                "count": randi_range(1, 3)
            }
        "TRAP":
            return {
                "trap_type": _select_trap_type(),
                "damage": randi_range(10, 20)
            }
        "MINE":
            return {
                "explosion_radius": randi_range(2, 4),
                "damage": randi_range(20, 40)
            }
        _:
            return {}

func _find_basic_salvage(area: Dictionary, efficiency: float) -> Array:
    var items = []
    var num_searches = int(5 * efficiency)
    
    for i in range(num_searches):
        if randf() <= 0.7:  # 70% chance per search
            items.append(_generate_basic_salvage_item())
    
    return items

func _find_valuable_items(area: Dictionary, efficiency: float) -> Array:
    var items = []
    var num_searches = int(3 * efficiency)
    
    for i in range(num_searches):
        if randf() <= 0.3:  # 30% chance per search
            items.append(_generate_valuable_salvage_item())
    
    return items

func _find_special_items(area: Dictionary, efficiency: float) -> Array:
    var items = []
    var battlefield_type = current_salvage_operation.battlefield.type
    
    # Check for special items based on battlefield type
    match battlefield_type:
        "MILITARY":
            if randf() <= 0.2 * efficiency:
                items.append(_generate_military_salvage())
        "INDUSTRIAL":
            if randf() <= 0.25 * efficiency:
                items.append(_generate_industrial_salvage())
        "RESEARCH":
            if randf() <= 0.15 * efficiency:
                items.append(_generate_research_salvage())
    
    return items

func _generate_basic_salvage_item() -> Dictionary:
    var types = ["SCRAP", "PARTS", "MATERIALS"]
    var selected_type = types[randi() % types.size()]
    
    return {
        "type": "BASIC",
        "subtype": selected_type,
        "quantity": randi_range(1, 5),
        "value": randi_range(10, 50)
    }

func _generate_valuable_salvage_item() -> Dictionary:
    var types = ["TECH", "WEAPONS", "EQUIPMENT"]
    var selected_type = types[randi() % types.size()]
    
    return {
        "type": "VALUABLE",
        "subtype": selected_type,
        "quantity": 1,
        "value": randi_range(100, 500),
        "quality": _determine_item_quality()
    }

func _generate_military_salvage() -> Dictionary:
    var types = ["WEAPON", "ARMOR", "AMMO", "TACTICAL"]
    var selected_type = types[randi() % types.size()]
    
    return {
        "type": "MILITARY",
        "subtype": selected_type,
        "quantity": 1,
        "value": randi_range(200, 1000),
        "quality": _determine_item_quality(),
        "special_properties": _generate_special_properties(selected_type)
    }

func _generate_industrial_salvage() -> Dictionary:
    var types = ["MACHINERY", "TOOLS", "RESOURCES"]
    var selected_type = types[randi() % types.size()]
    
    return {
        "type": "INDUSTRIAL",
        "subtype": selected_type,
        "quantity": randi_range(1, 3),
        "value": randi_range(150, 750),
        "quality": _determine_item_quality()
    }

func _generate_research_salvage() -> Dictionary:
    var types = ["DATA", "PROTOTYPE", "SAMPLES"]
    var selected_type = types[randi() % types.size()]
    
    return {
        "type": "RESEARCH",
        "subtype": selected_type,
        "quantity": 1,
        "value": randi_range(300, 1500),
        "quality": _determine_item_quality(),
        "research_value": randi_range(1, 5)
    }

func _determine_item_quality() -> int:
    var roll = randf()
    if roll < 0.6:
        return 1  # Common
    elif roll < 0.85:
        return 2  # Uncommon
    elif roll < 0.95:
        return 3  # Rare
    else:
        return 4  # Exceptional

func _generate_special_properties(item_type: String) -> Dictionary:
    match item_type:
        "WEAPON":
            return {
                "damage_bonus": randi_range(1, 5),
                "special_effect": _select_weapon_effect()
            }
        "ARMOR":
            return {
                "protection_bonus": randi_range(1, 3),
                "special_resistance": _select_damage_type()
            }
        "TACTICAL":
            return {
                "tactical_bonus": randi_range(1, 3),
                "special_ability": _select_tactical_ability()
            }
        _:
            return {}

func _select_enemy_type() -> String:
    var types = ["SURVIVOR", "SCAVENGER", "HOSTILE"]
    return types[randi() % types.size()]

func _select_trap_type() -> String:
    var types = ["SNARE", "PITFALL", "EXPLOSIVE"]
    return types[randi() % types.size()]

func _select_weapon_effect() -> String:
    var effects = ["BURNING", "SHOCKING", "FREEZING"]
    return effects[randi() % effects.size()]

func _select_damage_type() -> String:
    var types = ["ENERGY", "EXPLOSIVE", "PROJECTILE"]
    return types[randi() % types.size()]

func _select_tactical_ability() -> String:
    var abilities = ["SCAN", "SHIELD", "STEALTH"]
    return abilities[randi() % abilities.size()]

func _is_area_accessible(area: Dictionary) -> bool:
    # Check if area is blocked by hazards
    for hazard in current_salvage_operation.hazards_encountered:
        if hazard.area == area and hazard.effects.get("area_denial", false):
            return false
    
    # Check if area requires special equipment
    var required_equipment = area.get("required_equipment", [])
    for equipment in required_equipment:
        if not game_state.has_equipment(equipment):
            return false
    
    return true

func _has_required_equipment(area: Dictionary) -> bool:
    var basic_equipment = ["salvage_tools", "protective_gear"]
    
    # Check basic equipment
    for equipment in basic_equipment:
        if not game_state.has_equipment(equipment):
            return false
    
    # Check special equipment requirements
    var special_equipment = area.get("required_equipment", [])
    for equipment in special_equipment:
        if not game_state.has_equipment(equipment):
            return false
    
    return true

func _check_special_hazards(area: Dictionary) -> Array:
    var hazards = []
    var environment = current_salvage_operation.battlefield.environment
    
    match environment.type:
        "RADIOACTIVE":
            if randf() <= 0.4:
                hazards.append({
                    "type": "ENVIRONMENTAL",
                    "subtype": "RADIATION_POCKET",
                    "severity": "MAJOR",
                    "area": area,
                    "effects": {
                        "damage_type": "radiation",
                        "damage_per_turn": randi_range(10, 20),
                        "duration": randi_range(5, 10)
                    }
                })
        "UNSTABLE":
            if randf() <= 0.3:
                hazards.append({
                    "type": "ENVIRONMENTAL",
                    "subtype": "COLLAPSE",
                    "severity": "CRITICAL",
                    "area": area,
                    "effects": {
                        "damage_type": "physical",
                        "damage": randi_range(30, 50),
                        "area_denial": true
                    }
                })
    
    return hazards

func _compile_salvage_results() -> Dictionary:
    var total_value = 0
    var items_by_type = {}
    var hazards_by_type = {}
    
    # Compile items
    for item in current_salvage_operation.items_found:
        total_value += item.value
        if item.type in items_by_type:
            items_by_type[item.type].append(item)
        else:
            items_by_type[item.type] = [item]
    
    # Compile hazards
    for hazard in current_salvage_operation.hazards_encountered:
        if hazard.type in hazards_by_type:
            hazards_by_type[hazard.type].append(hazard)
        else:
            hazards_by_type[hazard.type] = [hazard]
    
    return {
        "total_value": total_value,
        "items_found": items_by_type,
        "hazards_encountered": hazards_by_type,
        "areas_searched": current_salvage_operation.areas_searched.size(),
        "time_taken": Time.get_unix_time_from_system() - current_salvage_operation.time_started,
        "completion_percentage": get_salvage_progress() * 100
    }