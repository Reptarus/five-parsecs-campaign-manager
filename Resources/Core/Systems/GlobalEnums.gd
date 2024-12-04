extends Node

# Character and Crew Enums
enum CharacterStatus {
	ACTIVE,
	HEALTHY,
	INJURED,
	RESTING,
	CRITICAL,
	DEAD,
	MISSING
}

enum Class {
	WARRIOR,
	SCOUT,
	MEDIC,
	TECH,
	LEADER,
	SPECIALIST,
	SUPPORT,
	GUNNER
}

enum Background {
	SOLDIER,
	MERCHANT,
	SCIENTIST,
	EXPLORER,
	OUTLAW,
	DIPLOMAT,
	COLONIST,
	DRIFTER
}

enum Origin {
	CORE_WORLDS,
	FRONTIER,
	DEEP_SPACE,
	HIVE_WORLD,
	FORGE_WORLD,
	FERAL_WORLD
}

enum Motivation {
	WEALTH,
	REVENGE,
	DISCOVERY,
	REDEMPTION,
	POWER,
	SURVIVAL
}

enum CrewRole {
	LEADER,
	SPECIALIST,
	SUPPORT,
	COMBAT,
	TECHNICAL,
	MEDICAL
}

# Equipment and Item Enums
enum ItemType {
	WEAPON,
	ARMOR,
	TOOL,
	DEVICE,
	CONSUMABLE,
	GEAR
}

enum WeaponType {
	PISTOL,
	RIFLE,
	HEAVY,
	MELEE,
	EXPLOSIVE,
	SPECIAL
}

enum ArmorType {
	LIGHT,
	MEDIUM,
	HEAVY,
	POWERED,
	SHIELD,
	SPECIAL
}

# Campaign and Mission Enums
enum CampaignPhase {
	SETUP,
	UPKEEP,
	EVENT,
	MISSION,
	BATTLE,
	POST_BATTLE,
	CLEANUP
}

enum GameState {
	SETUP,
	CAMPAIGN,
	BATTLE,
	GAME_OVER
}

enum BattlePhase {
	SETUP,
	DEPLOYMENT,
	BATTLE,
	RESOLUTION,
	CLEANUP
}

# Difficulty Settings
enum DifficultyMode {
	EASY,
	NORMAL,
	HARD,
	VETERAN,
	CHALLENGING,
	HARDCORE,
	INSANITY
}

enum MissionType {
	OPPORTUNITY,
	GREEN_ZONE,
	YELLOW_ZONE,
	RED_ZONE,
	BLACK_ZONE,
	ASSASSINATION,
	SABOTAGE,
	RESCUE,
	DEFENSE,
	ESCORT
}

enum MissionObjective {
	MOVE_THROUGH,
	RETRIEVE,
	SURVIVE,
	CONTROL_POINT,
	DEFEND,
	ELIMINATE,
	DESTROY_STRONGPOINT,
	ELIMINATE_TARGET,
	PENETRATE_LINES,
	SABOTAGE,
	SECURE_INTEL,
	CLEAR_ZONE,
	RESCUE,
	ESCORT,
	DESTROY
}

enum VictoryConditionType {
	ELIMINATION,
	EXTRACTION,
	SURVIVAL,
	TURNS,
	QUESTS
}

enum CampaignVictoryType {
	NONE,
	STORY_COMPLETE,
	WEALTH_GOAL,
	REPUTATION_GOAL,
	FACTION_DOMINANCE,
	SURVIVAL,
	CUSTOM
}

# World and Location Enums
enum TerrainType {
	CITY,
	URBAN,
	WILDERNESS,
	SPACE_STATION
}

enum TerrainFeature {
	FIELD,
	AREA,
	INDIVIDUAL,
	LINEAR
}

enum LocationType {
	SPACEPORT,
	SETTLEMENT,
	RUINS,
	WILDERNESS,
	STATION,
	SPECIAL
}

# Combat and Tactical Enums
enum AIBehavior {
	AGGRESSIVE,
	CAUTIOUS,
	TACTICAL,
	DEFENSIVE
}

enum DeploymentType {
	STANDARD,
	LINE,
	FLANK,
	SCATTERED,
	DEFENSIVE,
	INFILTRATION,
	REINFORCED,
	BOLSTERED_LINE,
	BOLSTERED_FLANK,
	CONCEALED,
	SURROUNDED,
	ASYMMETRIC,
	CORNER,
	DIAGONAL,
	RANDOM
}

# Faction and Reputation Enums
enum FactionType {
	NEUTRAL,
	FRIENDLY,
	HOSTILE,
	ALLIED,
	ENEMY,
	CORPORATE,
	MILITARY,
	MERCENARY,
	OUTLAW,
	SCAVENGER,
	COLONIST,
	TRADER
}

enum ReputationType {
	ADMIRED = 2,    # Maximum reputation
	TRUSTED = 1,    # High reputation
	NEUTRAL = 0,    # Starting reputation
	DISLIKED = -1,  # Low reputation
	HATED = -2      # Minimum reputation
}

# Quest and Story Enums
enum QuestType {
	MAIN,
	SIDE,
	STORY,
	FACTION,
	SPECIAL
}

enum QuestStatus {
	ACTIVE,
	COMPLETED,
	FAILED
}

# Resource and Economy Enums
enum ResourceType {
	CREDITS,
	FUEL,
	SUPPLIES,
	MATERIALS,
	INFORMATION
}

enum WorldTrait {
	MILITARY_PRESENCE,
	MILITARY_BASE,
	PIRATE_HAVEN,
	LAWLESS
}

enum FringeWorldInstability {
	STABLE,
	UNREST,
	CONFLICT,
	CRISIS,
	COLLAPSE
}

# Character Stats
enum CharacterStats {
	COMBAT_SKILL,
	SAVVY,
	INTELLIGENCE,
	SURVIVAL,
	STEALTH,
	LEADERSHIP
}

# Helper functions
static func get_enum_keys(enum_name: String) -> Array:
	var enum_dict = {}
	match enum_name:
		"AIBehavior": enum_dict = AIBehavior
		"ArmorType": enum_dict = ArmorType
		"Background": enum_dict = Background
		"CampaignPhase": enum_dict = CampaignPhase
		"CampaignVictoryType": enum_dict = CampaignVictoryType
		"CharacterStatus": enum_dict = CharacterStatus
		"CharacterStats": enum_dict = CharacterStats
		"Class": enum_dict = Class
		"CrewRole": enum_dict = CrewRole
		"DeploymentType": enum_dict = DeploymentType
		"DifficultyMode": enum_dict = DifficultyMode
		"FactionType": enum_dict = FactionType
		"ItemType": enum_dict = ItemType
		"LocationType": enum_dict = LocationType
		"MissionObjective": enum_dict = MissionObjective
		"MissionType": enum_dict = MissionType
		"Motivation": enum_dict = Motivation
		"Origin": enum_dict = Origin
		"QuestStatus": enum_dict = QuestStatus
		"QuestType": enum_dict = QuestType
		"ReputationType": enum_dict = ReputationType
		"ResourceType": enum_dict = ResourceType
		"TerrainFeature": enum_dict = TerrainFeature
		"TerrainType": enum_dict = TerrainType
		"VictoryConditionType": enum_dict = VictoryConditionType
		"WeaponType": enum_dict = WeaponType
		"WorldTrait": enum_dict = WorldTrait
	return enum_dict.keys()

static func get_enum_value(enum_name: String, key: String) -> int:
	var enum_dict = {}
	match enum_name:
		"AIBehavior": enum_dict = AIBehavior
		"ArmorType": enum_dict = ArmorType
		"Background": enum_dict = Background
		"CampaignPhase": enum_dict = CampaignPhase
		"CampaignVictoryType": enum_dict = CampaignVictoryType
		"CharacterStatus": enum_dict = CharacterStatus
		"CharacterStats": enum_dict = CharacterStats
		"Class": enum_dict = Class
		"CrewRole": enum_dict = CrewRole
		"DeploymentType": enum_dict = DeploymentType
		"DifficultyMode": enum_dict = DifficultyMode
		"FactionType": enum_dict = FactionType
		"ItemType": enum_dict = ItemType
		"LocationType": enum_dict = LocationType
		"MissionObjective": enum_dict = MissionObjective
		"MissionType": enum_dict = MissionType
		"Motivation": enum_dict = Motivation
		"Origin": enum_dict = Origin
		"QuestStatus": enum_dict = QuestStatus
		"QuestType": enum_dict = QuestType
		"ReputationType": enum_dict = ReputationType
		"ResourceType": enum_dict = ResourceType
		"TerrainFeature": enum_dict = TerrainFeature
		"TerrainType": enum_dict = TerrainType
		"VictoryConditionType": enum_dict = VictoryConditionType
		"WeaponType": enum_dict = WeaponType
		"WorldTrait": enum_dict = WorldTrait
	return enum_dict.get(key, 0)
