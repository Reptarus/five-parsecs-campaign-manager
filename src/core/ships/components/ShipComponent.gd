# Scripts/ShipAndCrew/ShipComponent.gd
@tool
extends Resource
class_name FPCM_ShipComponent

@export var name: String = "Component"
@export var description: String = ""
@export var component_id: String = ""
@export var cost: int = 100
@export var level: int = 1
@export var max_level: int = 3
@export var is_active: bool = true
@export var upgrade_cost: int = 100
@export var maintenance_cost: int = 10
@export var durability: float = 100.0
@export var max_durability: float = 100.0
@export var efficiency: float = 1.0
@export var power_draw: int = 1

# Five Parsecs specific attributes
@export var wear_level: int = 0 # Tracks wear and tear (0-5)
@export var quality_level: int = 2 # Component quality (1-5, higher is better)
@export var component_type: String = "" # For specific component bonuses
@export var is_scavenged: bool = false # Scavenged parts are cheaper but less reliable
@export var tech_level: int = 1 # Tech level (1-5, affects cost and effectiveness)

# Effects
@export var status_effects: Array = []

# Signals
signal component_repaired(amount: int)
signal component_damaged(amount: int)
signal component_activated()
signal component_deactivated()
signal wear_increased(new_level: int)
signal component_upgraded(new_level: int)

func _init() -> void:
    name = "Component"
    description = ""
    cost = 100
    level = 1
    max_level = 3
    is_active = true
    upgrade_cost = 100
    maintenance_cost = 10
    durability = 100.0
    max_durability = 100.0
    efficiency = 1.0
    power_draw = 1
    
    # Five Parsecs specific initialization
    wear_level = 0
    quality_level = 2
    component_type = ""
    is_scavenged = false
    tech_level = 1
    
    status_effects = []

func can_upgrade() -> bool:
    return level < max_level

func upgrade() -> bool:
    if not can_upgrade():
        return false
    level += 1
    _apply_upgrade_effects()
    component_upgraded.emit(level)
    return true

func repair(amount: float) -> float:
    var before = durability
    durability = min(durability + amount, max_durability)
    var actual_repair = durability - before
    if actual_repair > 0:
        component_repaired.emit(actual_repair)
    return actual_repair

# Full repair (used during maintenance)
func repair_full() -> void:
    var repair_amount = max_durability - durability
    if repair_amount > 0:
        repair(repair_amount)

func damage(amount: float) -> float:
    var before = durability
    durability = max(durability - amount, 0)
    var actual_damage = before - durability
    
    # Potentially increase wear level based on damage
    if actual_damage > 0:
        component_damaged.emit(actual_damage)
        
        # Chance to increase wear based on damage severity
        var wear_chance = actual_damage / float(max_durability) * 100
        if randf() * 100 < wear_chance:
            increase_wear()
    
    if durability == 0:
        deactivate()
    return actual_damage

func activate() -> void:
    is_active = true
    component_activated.emit()

func deactivate() -> void:
    is_active = false
    component_deactivated.emit()

# Five Parsecs specific methods

# Increase component wear and tear
func increase_wear() -> bool:
    if wear_level < 5:
        wear_level += 1
        wear_increased.emit(wear_level)
        
        # Apply penalties based on wear level
        match wear_level:
            1: # Minor wear - no effect
                pass
            2: # Moderate wear - slight efficiency loss
                efficiency *= 0.95
            3: # Significant wear - noticeable efficiency loss
                efficiency *= 0.90
            4: # Heavy wear - major efficiency loss
                efficiency *= 0.80
            5: # Critical wear - component may fail
                efficiency *= 0.60
                # Random chance of component failure
                if randf() < 0.2:
                    deactivate()
        
        return true
    return false

# Reset wear during maintenance
func reset_wear() -> void:
    var old_wear = wear_level
    wear_level = 0
    
    # Recover efficiency based on previous wear
    match old_wear:
        1:
            efficiency /= 0.95
        2:
            efficiency /= 0.95
        3:
            efficiency /= 0.90
        4:
            efficiency /= 0.80
        5:
            efficiency /= 0.60
    
    # Cap efficiency at 1.0 + level bonuses
    efficiency = minf(1.0 + (level - 1) * 0.2, efficiency)

# Calculate reliability based on quality and wear
func get_reliability() -> float:
    var base_reliability = 0.7 + (quality_level * 0.05) # 0.75 to 0.95 base on quality
    var wear_penalty = wear_level * 0.1 # 0 to 0.5 penalty based on wear
    var scavenge_penalty = 0.0
    
    if is_scavenged:
        scavenge_penalty = 0.1
        
    return maxf(0.1, base_reliability - wear_penalty - scavenge_penalty)

# Check if component fails during operation
func check_failure() -> bool:
    var reliability = get_reliability()
    return randf() > reliability

# Calculate cost based on quality and tech level
func calculate_cost() -> int:
    var base_cost = cost
    var quality_multiplier = 1.0 + (quality_level - 1) * 0.2 # 1.0 to 1.8
    var tech_multiplier = 1.0 + (tech_level - 1) * 0.3 # 1.0 to 2.2
    var scavenge_discount = 1.0
    
    if is_scavenged:
        scavenge_discount = 0.6 # 40% discount for scavenged parts
        
    return int(base_cost * quality_multiplier * tech_multiplier * scavenge_discount)

func get_efficiency() -> float:
    var base_efficiency = efficiency * (float(durability) / float(max_durability))
    var quality_bonus = (quality_level - 2) * 0.05 # -0.05 to +0.15 based on quality
    var tech_bonus = (tech_level - 1) * 0.05 # 0 to +0.2 based on tech level
    
    return base_efficiency * (1.0 + (level - 1) * 0.2) + quality_bonus + tech_bonus

func get_power_consumption() -> int:
    return power_draw * level

func get_maintenance_cost() -> int:
    var base_cost = maintenance_cost * level
    var wear_multiplier = 1.0 + (wear_level * 0.2) # +20% per wear level
    
    return int(base_cost * wear_multiplier)

func get_upgrade_cost() -> int:
    var base_cost = upgrade_cost * level
    var tech_multiplier = 1.0 + (tech_level - 1) * 0.2 # Higher tech is more expensive to upgrade
    
    return int(base_cost * tech_multiplier)

func add_status_effect(effect: Dictionary) -> void:
    if not status_effects.has(effect):
        status_effects.append(effect)

func remove_status_effect(effect: Dictionary) -> void:
    status_effects.erase(effect)

func clear_status_effects() -> void:
    status_effects.clear()

func _apply_upgrade_effects() -> void:
    durability = max_durability
    efficiency += 0.1
    max_durability += 25
    durability = max_durability
    maintenance_cost = get_maintenance_cost()
    power_draw = get_power_consumption()

# Enhanced serialization to include Five Parsecs specific attributes
func serialize() -> Dictionary:
    return {
        "name": name,
        "description": description,
        "component_id": component_id,
        "cost": cost,
        "level": level,
        "max_level": max_level,
        "is_active": is_active,
        "upgrade_cost": upgrade_cost,
        "maintenance_cost": maintenance_cost,
        "durability": durability,
        "max_durability": max_durability,
        "efficiency": efficiency,
        "power_draw": power_draw,
        "wear_level": wear_level,
        "quality_level": quality_level,
        "component_type": component_type,
        "is_scavenged": is_scavenged,
        "tech_level": tech_level,
        "status_effects": status_effects
    }

static func deserialize(data: Dictionary) -> Dictionary:
    return {
        "name": data.get("name", "Component"),
        "description": data.get("description", ""),
        "component_id": data.get("component_id", ""),
        "cost": data.get("cost", 100),
        "level": data.get("level", 1),
        "max_level": data.get("max_level", 3),
        "is_active": data.get("is_active", true),
        "upgrade_cost": data.get("upgrade_cost", 100),
        "maintenance_cost": data.get("maintenance_cost", 10),
        "durability": data.get("durability", 100.0),
        "max_durability": data.get("max_durability", 100.0),
        "efficiency": data.get("efficiency", 1.0),
        "power_draw": data.get("power_draw", 1),
        "wear_level": data.get("wear_level", 0),
        "quality_level": data.get("quality_level", 2),
        "component_type": data.get("component_type", ""),
        "is_scavenged": data.get("is_scavenged", false),
        "tech_level": data.get("tech_level", 1),
        "status_effects": data.get("status_effects", [])
    }