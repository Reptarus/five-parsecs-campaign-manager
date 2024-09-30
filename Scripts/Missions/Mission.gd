class_name Mission
extends Resource

@export var title: String
@export var description: String
@export var type: GlobalEnums.Type
@export var status: GlobalEnums.MissionStatus = GlobalEnums.MissionStatus.ACTIVE
@export var objective: GlobalEnums.MissionObjective
@export var patron: Patron
@export var rewards: Dictionary
@export var time_limit: int # in campaign turns
@export var difficulty: int # 1-5
@export var location: Location
@export var required_crew_size: int

# Expanded mission properties
@export var is_expanded: bool = false
@export var faction: Dictionary
@export var loyalty_requirement: int = 0
@export var power_requirement: int = 0

# Specific mission type properties
@export var instability: GlobalEnums.FringeWorldInstability = GlobalEnums.FringeWorldInstability.STABLE
@export var salvage_units: int = 0
@export var detection_level: int = 0
@export var street_fight_type: GlobalEnums.StreetFightType

# Additional fields
@export var special_rules: Array[String]
@export var involved_factions: Array[GlobalEnums.Faction]
@export var strife_intensity: int
@export var key_npcs: Array[String]
@export var environmental_factors: Array[String]
@export var available_resources: Dictionary
@export var time_pressure: int

var result: String = ""
var is_tutorial_mission: bool = false

func _init(p_title: String = "", p_description: String = "", p_type: GlobalEnums.Type = GlobalEnums.Type.OPPORTUNITY, 
           p_objective: GlobalEnums.MissionObjective = GlobalEnums.MissionObjective.MOVE_THROUGH, p_location: Location = null, 
           p_difficulty: int = 1, p_rewards: Dictionary = {}, p_time_limit: int = 3,
           p_is_expanded: bool = false, p_faction: Dictionary = {}):
    title = p_title
    description = p_description
    type = p_type
    objective = p_objective
    location = p_location
    difficulty = p_difficulty
    rewards = p_rewards
    time_limit = p_time_limit
    is_expanded = p_is_expanded
    faction = p_faction

func complete() -> void:
    status = GlobalEnums.MissionStatus.COMPLETED
    result = "Mission completed successfully"
    if is_expanded and faction:
        faction["loyalty"] = faction.get("loyalty", 0) + 1

func fail() -> void:
    status = GlobalEnums.MissionStatus.FAILED
    result = "Mission failed"
    if is_expanded and faction:
        faction["loyalty"] = faction.get("loyalty", 0) - 1

func is_expired(current_turn: int) -> bool:
    return current_turn >= time_limit

func start_mission(crew: Array[Character]) -> bool:
    if crew.size() < required_crew_size:
        return false
    if is_expanded and faction and _get_crew_loyalty(crew) < loyalty_requirement:
        return false
    return true

func _get_crew_loyalty(crew: Array[Character]) -> int:
    var total_loyalty = 0
    for character in crew:
        total_loyalty += character.get_faction_standing(faction.get("name", ""))
    return total_loyalty / crew.size() if crew.size() > 0 else 0

func get_reward() -> Dictionary:
    var final_rewards = rewards.duplicate()
    if is_expanded and faction:
        final_rewards["credits"] = final_rewards.get("credits", 0) * (1 + (faction.get("power", 0) * 0.1))
    return final_rewards

func increase_instability(amount: int) -> void:
    instability = min(instability + amount, GlobalEnums.FringeWorldInstability.CHAOS)

func add_salvage_units(amount: int) -> void:
    salvage_units += amount

func increase_detection_level() -> void:
    detection_level = min(detection_level + 1, 2)  # Max detection level is 2

func set_street_fight_type(fight_type: GlobalEnums.StreetFightType) -> void:
    street_fight_type = fight_type

func add_special_rule(rule: String) -> void:
    special_rules.append(rule)

func add_involved_faction(faction: GlobalEnums.Faction) -> void:
    involved_factions.append(faction)

func set_strife_intensity(intensity: int) -> void:
    strife_intensity = intensity

func add_key_npc(npc: String) -> void:
    key_npcs.append(npc)

func add_environmental_factor(factor: String) -> void:
    environmental_factors.append(factor)

func set_available_resources(resources: Dictionary) -> void:
    available_resources = resources

func set_time_pressure(pressure: int) -> void:
    time_pressure = pressure

func serialize() -> Dictionary:
    var data = {
        "title": title,
        "description": description,
        "type": GlobalEnums.Type.keys()[type],
        "status": GlobalEnums.MissionStatus.keys()[status],
        "objective": GlobalEnums.MissionObjective.keys()[objective],
        "rewards": rewards,
        "time_limit": time_limit,
        "difficulty": difficulty,
        "required_crew_size": required_crew_size,
        "is_expanded": is_expanded,
        "faction": faction,
        "loyalty_requirement": loyalty_requirement,
        "power_requirement": power_requirement,
        "instability": GlobalEnums.FringeWorldInstability.keys()[instability],
        "salvage_units": salvage_units,
        "detection_level": detection_level,
        "street_fight_type": GlobalEnums.StreetFightType.keys()[street_fight_type],
        "special_rules": special_rules,
        "involved_factions": involved_factions.map(func(f): return GlobalEnums.Faction.keys()[f]),
        "strife_intensity": strife_intensity,
        "key_npcs": key_npcs,
        "environmental_factors": environmental_factors,
        "available_resources": available_resources,
        "time_pressure": time_pressure,
        "result": result,
        "is_tutorial_mission": is_tutorial_mission
    }
    if patron:
        data["patron"] = patron.serialize()
    if location:
        data["location"] = location.serialize()
    return data

static func deserialize(data: Dictionary) -> Mission:
    var mission = Mission.new(
        data["title"],
        data["description"],
        GlobalEnums.Type[data["type"]],
        GlobalEnums.MissionObjective[data["objective"]],
        Location.deserialize(data["location"]) if "location" in data else null,
        data["difficulty"],
        data["rewards"],
        data["time_limit"],
        data["is_expanded"],
        data["faction"] if "faction" in data else {}
    )
    mission.status = GlobalEnums.MissionStatus[data["status"]]
    mission.patron = Patron.deserialize(data["patron"]) if "patron" in data else null
    mission.required_crew_size = data["required_crew_size"]
    mission.loyalty_requirement = data["loyalty_requirement"]
    mission.power_requirement = data["power_requirement"]
    mission.instability = GlobalEnums.FringeWorldInstability[data["instability"]]
    mission.salvage_units = data["salvage_units"]
    mission.detection_level = data["detection_level"]
    mission.street_fight_type = GlobalEnums.StreetFightType[data["street_fight_type"]]
    mission.special_rules = data["special_rules"]
    mission.involved_factions = data["involved_factions"].map(func(f): return GlobalEnums.Faction[f])
    mission.strife_intensity = data["strife_intensity"]
    mission.key_npcs = data["key_npcs"]
    mission.environmental_factors = data["environmental_factors"]
    mission.available_resources = data["available_resources"]
    mission.time_pressure = data["time_pressure"]
    mission.result = data["result"]
    mission.is_tutorial_mission = data["is_tutorial_mission"]
    return mission