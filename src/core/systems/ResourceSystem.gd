extends Resource

signal resource_changed(type: int, amount: int)
signal resource_depleted(type: int)
signal loot_generated(loot: Array)
signal salvage_completed(results: Dictionary)

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Resource Management
var resources: Dictionary = {}
var consumption_rates: Dictionary = {}

# Loot Tables
var loot_tables: Dictionary = {}
var rarity_weights: Dictionary = {}
var equipment_pools: Dictionary = {}

# Salvage Rules
var salvage_values: Dictionary = {}
var salvage_chances: Dictionary = {}

# Resource Types (since they're not in GlobalEnums)
enum ResourceType {
    CREDITS,
    FUEL,
    AMMO,
    MEDICAL,
    SPECIAL
}

var STARTING_RESOURCES = {
    ResourceType.CREDITS: 1000,
    ResourceType.FUEL: 100,
    ResourceType.AMMO: 50,
    ResourceType.MEDICAL: 25,
    ResourceType.SPECIAL: 0
}

func _init() -> void:
    reset_resources()
    _initialize_loot_tables()
    _initialize_salvage_rules()

func reset_resources() -> void:
    resources = STARTING_RESOURCES.duplicate()
    for type in ResourceType.values():
        consumption_rates[type] = 0.0

# Resource Management
func modify_resource(type: int, amount: int) -> bool:
    if not resources.has(type):
        push_error("Invalid resource type")
        return false
        
    resources[type] = max(0, resources[type] + amount)
    resource_changed.emit(type, resources[type])
    
    if resources[type] <= 0:
        resource_depleted.emit(type)
    return true

func has_sufficient_resources(requirements: Dictionary) -> bool:
    for type in requirements:
        if not resources.has(type) or resources[type] < requirements[type]:
            return false
    return true

func process_consumption() -> void:
    for type in consumption_rates:
        if consumption_rates[type] > 0:
            modify_resource(type, -consumption_rates[type] as int)

# Loot Generation
func generate_loot(params: Dictionary = {}) -> Array:
    var loot_level = params.get("level", 1)
    var loot_quality = params.get("quality", 1.0)
    var loot_count = params.get("count", 1)
    
    var generated_loot = []
    for i in range(loot_count):
        var item = _generate_single_item(loot_level, loot_quality)
        if item:
            generated_loot.append(item)
    
    loot_generated.emit(generated_loot)
    return generated_loot

func generate_mission_rewards(mission: Mission) -> Dictionary:
    var rewards = {
        "credits": _calculate_credit_reward(mission),
        "items": _generate_mission_items(mission),
        "resources": _generate_resource_rewards(mission)
    }
    return rewards

# Salvage System
func salvage_item(item: Item) -> Dictionary:
    var salvage_result = {
        "resources": _calculate_salvage_resources(item),
        "components": _extract_components(item),
        "success": true
    }
    
    salvage_completed.emit(salvage_result)
    return salvage_result

func salvage_multiple_items(items: Array) -> Dictionary:
    var total_salvage = {
        "resources": {},
        "components": [],
        "success": true
    }
    
    for item in items:
        var result = salvage_item(item)
        _merge_salvage_results(total_salvage, result)
    
    return total_salvage

# Private Methods
func _initialize_loot_tables() -> void:
    # Initialize loot tables based on game data
    pass

func _initialize_salvage_rules() -> void:
    # Initialize salvage rules based on game data
    pass

func _generate_single_item(level: int, quality: float) -> Item:
    var item_type = _select_item_type()
    var rarity = _determine_rarity(quality)
    
    var item = Item.new()
    item.type = item_type
    item.level = level
    item.rarity = rarity
    
    _apply_item_properties(item)
    return item

func _select_item_type() -> int:
    # Select item type based on weighted probabilities
    return GameEnums.ItemType.WEAPON

func _determine_rarity(quality: float) -> int:
    # Determine item rarity based on quality factor
    return GameEnums.ItemRarity.COMMON

func _apply_item_properties(item: Item) -> void:
    # Apply properties based on item type and rarity
    pass

func _calculate_credit_reward(mission: Mission) -> int:
    return mission.difficulty * 100 + mission.danger_level as int * 50

func _generate_mission_items(mission: Mission) -> Array:
    return generate_loot({
        "level": mission.difficulty,
        "quality": 1.0 + mission.danger_level * 0.1,
        "count": 1 + mission.difficulty / 2
    })

func _generate_resource_rewards(mission: Mission) -> Dictionary:
    var resources = {}
    for type in ResourceType.values():
        if randf() < 0.3:  # 30% chance for each resource type
            resources[type] = (1 + mission.difficulty) * 10
    return resources

func _calculate_salvage_resources(item: Item) -> Dictionary:
    var resources = {}
    var base_value = item.level * (item.rarity + 1)
    
    resources[ResourceType.CREDITS] = base_value * 10
    if randf() < 0.5:  # 50% chance for additional resources
        resources[ResourceType.SPECIAL] = base_value
    
    return resources

func _extract_components(item: Item) -> Array:
    var components = []
    if item.has_components and randf() < salvage_chances.get(item.type, 0.5):
        # Extract components based on item type and condition
        pass
    return components

func _merge_salvage_results(total: Dictionary, result: Dictionary) -> void:
    # Merge resources
    for resource_type in result.resources:
        if not total.resources.has(resource_type):
            total.resources[resource_type] = 0
        total.resources[resource_type] += result.resources[resource_type]
    
    # Merge components
    total.components.append_array(result.components)
    
    # Update success flag
    total.success = total.success and result.success

func serialize() -> Dictionary:
    return {
        "resources": resources,
        "consumption_rates": consumption_rates,
        "loot_tables": loot_tables,
        "salvage_values": salvage_values
    }

func deserialize(data: Dictionary) -> void:
    resources = data.get("resources", {})
    consumption_rates = data.get("consumption_rates", {})
    loot_tables = data.get("loot_tables", {})
    salvage_values = data.get("salvage_values", {}) 