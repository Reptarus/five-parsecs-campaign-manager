class_name EquipmentManager
extends Resource

signal equipment_updated(crew_member_id: String, equipment: Dictionary)
signal equipment_removed(crew_member_id: String, equipment_id: String)

var game_state: GameState
var equipped_items: Dictionary = {}

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func equip_item(item: Dictionary, crew_member) -> bool:
    if not _validate_equipment_requirements(item, crew_member):
        return false
        
    if not _has_available_slot(item, crew_member):
        return false
        
    var crew_id = crew_member.id
    if not equipped_items.has(crew_id):
        equipped_items[crew_id] = {}
        
    equipped_items[crew_id][item.id] = item
    equipment_updated.emit(crew_id, item)
    return true

func remove_item(item_id: String, crew_member) -> void:
    var crew_id = crew_member.id
    if equipped_items.has(crew_id) and equipped_items[crew_id].has(item_id):
        equipped_items[crew_id].erase(item_id)
        equipment_removed.emit(crew_id, item_id)

func get_equipped_items(crew_member) -> Array:
    var crew_id = crew_member.id
    if not equipped_items.has(crew_id):
        return []
    return equipped_items[crew_id].values()

func get_equipped_item_by_type(crew_member, item_type: int) -> Dictionary:
    var items = get_equipped_items(crew_member)
    for item in items:
        if item.type == item_type:
            return item
    return {}

func has_equipped_item(crew_member, item_id: String) -> bool:
    var crew_id = crew_member.id
    return equipped_items.has(crew_id) and equipped_items[crew_id].has(item_id)

func get_equipment_bonus(crew_member, stat: String) -> int:
    var total_bonus = 0
    var items = get_equipped_items(crew_member)
    
    for item in items:
        if item.has("bonuses") and item.bonuses.has(stat):
            total_bonus += item.bonuses[stat]
            
    return total_bonus

func _validate_equipment_requirements(item: Dictionary, crew_member) -> bool:
    if not item.has("requirements"):
        return true
        
    var requirements = item.requirements
    
    # Check stat requirements
    if requirements.has("stats"):
        for stat_name in requirements.stats:
            var required_value = requirements.stats[stat_name]
            if crew_member.get_stat(stat_name) < required_value:
                return false
    
    # Check skill requirements
    if requirements.has("skills"):
        for skill_name in requirements.skills:
            var required_level = requirements.skills[skill_name]
            if crew_member.get_skill_level(skill_name) < required_level:
                return false
    
    # Check trait requirements
    if requirements.has("traits"):
        for trait_name in requirements.traits:
            if not crew_member.has_trait(trait_name):
                return false
    
    return true

func _has_available_slot(item: Dictionary, crew_member) -> bool:
    if not crew_member.id in equipped_items:
        return true
        
    var equipped = equipped_items[crew_member.id]
    var max_slots = _get_max_slots_for_type(item.type)
    
    var used_slots = 0
    for equipped_item in equipped.values():
        if equipped_item.type == item.type:
            used_slots += 1
            
    return used_slots < max_slots

func _get_max_slots_for_type(item_type: int) -> int:
    match item_type:
        GlobalEnums.ItemType.WEAPON:
            return 2
        GlobalEnums.ItemType.ARMOR:
            return 1
        GlobalEnums.ItemType.TOOL:
            return 3
        GlobalEnums.ItemType.DEVICE:
            return 2
        GlobalEnums.ItemType.CONSUMABLE:
            return 4
        _:
            return 1