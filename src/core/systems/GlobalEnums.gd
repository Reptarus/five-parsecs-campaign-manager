extends RefCounted

## Character related enums
enum CharacterStatus {
	HEALTHY,
	INJURED,
	CRITICAL,
	DEAD
}

enum Origin {
	HUMAN,
	ENGINEER,
	FERAL,
	KERIN,
	PRECURSOR,
	SOULLESS,
	SWIFT,
	BOT
}

enum CharacterClass {
	SOLDIER,
	MEDIC,
	TECH,
	SCOUT,
	LEADER,
	SPECIALIST
}

## Combat related enums
enum UnitAction {
	NONE = 0,
	MOVE = 1,
	ATTACK = 2,
	DASH = 3,
	ITEMS = 4,
	BRAWL = 5,
	SNAP_FIRE = 6,
	OVERWATCH = 7,
	TAKE_COVER = 8,
	RELOAD = 9,
	INTERACT = 10
}

enum CombatPhase {
	NONE,
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	UNIT_ACTION,
	REACTION,
	END_TURN,
	CLEANUP
}

enum CombatModifier {
	NONE,
	COVER_LIGHT,
	COVER_HEAVY,
	HIGH_GROUND,
	LOW_GROUND,
	FLANKING,
	SUPPRESSED,
	OVERWATCH,
	WOUNDED,
	INSPIRED,
	FOCUSED
}

enum CombatResult {
	NONE = 0,
	HIT = 1,
	MISS = 2,
	CRITICAL = 3,
	GRAZE = 4,
	DODGE = 5,
	BLOCK = 6,
	COUNTER = 7
}

## Mission related enums
enum MissionType {
	NONE,
	PATROL,
	RAID,
	DEFENSE,
	ESCORT,
	SABOTAGE,
	RESCUE,
	ASSASSINATION,
	INVESTIGATION,
	GREEN_ZONE,
	RED_ZONE,
	BLACK_ZONE,
	PATRON,
	TUTORIAL,
	STORY
}

enum MissionObjective {
	NONE,
	WIN_BATTLE,
	MOVE_THROUGH,
	PATROL,
	SEEK_AND_DESTROY,
	RECON,
	RESCUE,
	DEFEND,
	ESCORT,
	SABOTAGE,
	ELIMINATE,
	ELIMINATE_TARGET
}

enum DeploymentType {
	STANDARD,
	SCATTERED,
	AMBUSH,
	REINFORCEMENT,
	DEFENSIVE,
	OFFENSIVE,
	INFILTRATION,
	CONCEALED,
	BOLSTERED_LINE,
	LINE
}

enum DifficultyMode {
	EASY,
	NORMAL,
	CHALLENGING,
	HARDCORE,
	INSANITY
}

## Terrain related enums
enum TerrainModifier {
	NONE,
	COVER_BONUS,
	LINE_OF_SIGHT_BLOCKED,
	DIFFICULT_TERRAIN,
	HAZARDOUS,
	FULL_COVER,
	PARTIAL_COVER,
	ELEVATION_BONUS,
	MOVEMENT_PENALTY,
	WATER_HAZARD
}

## Victory condition enums
enum VictoryConditionType {
	NONE,
	STANDARD,
	ELIMINATION,
	EXTRACTION,
	SURVIVAL,
	CONTROL_POINTS,
	OBJECTIVE,
	TURNS_20,
	WEALTH_GOAL,
	REPUTATION_GOAL,
	FACTION_DOMINANCE,
	STORY_COMPLETE
}

## Faction related enums
enum FactionType {
	NONE,
	IMPERIAL,
	REBEL,
	MERCENARY,
	PIRATE,
	CORPORATE,
	NEUTRAL,
	HOSTILE
}

## Type related enums
enum Type {
	STORY,
	SIDE_MISSION,
	RANDOM_ENCOUNTER,
	SPECIAL_EVENT,
	CAMPAIGN_MISSION
}

## Equipment related enums
enum ArmorType {
	NONE,
	LIGHT,
	MEDIUM,
	HEAVY,
	SCREEN,
	POWERED
}

enum ItemType {
	NONE,
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	QUEST_ITEM,
	MODIFICATION,
	SPECIAL,
	EQUIPMENT,
	ACCESSORY
}

enum WeaponType {
	NONE,
	PISTOL,
	RIFLE,
	HEAVY,
	MELEE,
	SPECIAL,
	BASIC,
	ADVANCED,
	ELITE
}

## Battlefield related enums
enum BattlefieldType {
	NONE,
	OPEN,
	URBAN,
	DENSE,
	HAZARDOUS,
	MIXED
}

enum BattlefieldSize {
	SMALL,
	MEDIUM,
	LARGE,
	HUGE
}

enum BattlefieldFeature {
	NONE,
	COVER, # Basic cover piece
	BARRICADE, # Linear cover
	RUINS, # Destroyed structure
	HAZARD, # Dangerous area
	HIGH_GROUND, # Elevated position
	OBSTACLE, # Impassable object
	OBJECTIVE_MARKER, # Mission objective
	DEPLOYMENT_ZONE # Starting area
}

enum BattlefieldZone {
	DEPLOYMENT,
	NEUTRAL,
	OBJECTIVE,
	HAZARD,
	RESTRICTED
}

## Combat system enums
enum CombatRange {
	POINT_BLANK = 0,
	SHORT = 1,
	MEDIUM = 2,
	LONG = 3,
	EXTREME = 4
}

enum CombatAdvantage {
	NONE = 0,
	MINOR = 1,
	MAJOR = 2,
	OVERWHELMING = 3
}

enum CombatStatus {
	NONE = 0,
	ENGAGED = 1,
	PINNED = 2,
	FLANKED = 3,
	SURROUNDED = 4
}

enum CombatTactic {
	NONE = 0,
	AGGRESSIVE = 1,
	DEFENSIVE = 2,
	EVASIVE = 3,
	SUPPORTIVE = 4
}

## Quest related enums
enum QuestType {
	NONE,
	MAIN,
	SIDE,
	SPECIAL,
	EVENT,
	CAMPAIGN,
	PATRON
}

enum QuestStatus {
	NONE,
	ACTIVE,
	COMPLETED,
	FAILED,
	EXPIRED
}

enum BattleType {
	NONE,
	STANDARD,
	BOSS,
	AMBUSH,
	DEFENSE,
	RAID,
	SPECIAL
}

## AI behavior enums
enum AIBehavior {
	NONE,
	AGGRESSIVE,
	DEFENSIVE,
	TACTICAL,
	CAUTIOUS,
	SUPPORTIVE
}

## Item rarity enums
enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Campaign related enums
enum CampaignPhase {
	NONE = -1,
	SETUP = 0,
	UPKEEP = 1,
	STORY = 2,
	CAMPAIGN = 3,
	BATTLE_SETUP = 4,
	BATTLE = 5,
	POST_BATTLE = 6,
	MANAGEMENT = 7,
	TRAVEL = 8,
	BATTLE_RESOLUTION = 9,
	ADVANCEMENT = 10
}

const PHASE_NAMES = {
	CampaignPhase.NONE: "None",
	CampaignPhase.SETUP: "Setup",
	CampaignPhase.UPKEEP: "Upkeep",
	CampaignPhase.STORY: "Story",
	CampaignPhase.CAMPAIGN: "Campaign",
	CampaignPhase.BATTLE_SETUP: "Battle Setup",
	CampaignPhase.BATTLE_RESOLUTION: "Battle Resolution",
	CampaignPhase.ADVANCEMENT: "Advancement"
}

const PHASE_DESCRIPTIONS = {
	CampaignPhase.NONE: "No active phase",
	CampaignPhase.SETUP: "Set up your crew and campaign parameters",
	CampaignPhase.UPKEEP: "Handle maintenance costs and resource management",
	CampaignPhase.STORY: "Check and resolve story events and world developments",
	CampaignPhase.CAMPAIGN: "Manage crew, equipment, and select missions",
	CampaignPhase.BATTLE_SETUP: "Prepare the battlefield and deploy your crew",
	CampaignPhase.BATTLE_RESOLUTION: "Resolve combat outcomes and handle aftermath",
	CampaignPhase.ADVANCEMENT: "Level up characters and update equipment"
}

## Global event enums
enum GlobalEvent {
	NONE,
	MARKET_CRASH,
	ALIEN_INVASION,
	TECH_BREAKTHROUGH,
	CIVIL_UNREST,
	RESOURCE_BOOM,
	PIRATE_RAID,
	TRADE_OPPORTUNITY,
	TRADE_DISRUPTION,
	ECONOMIC_BOOM,
	RESOURCE_SHORTAGE,
	NEW_TECHNOLOGY,
	RESOURCE_CONFLICT
}

# Add these missing enums
enum GameState {
    NONE,
    SETUP,
    PLAYING,
    PAUSED,
    BATTLE,
    CAMPAIGN,
    ENDED,
    GAME_OVER
}

enum MarketState {
    NORMAL,
    CRISIS,
    BOOM,
    RESTRICTED
}

enum BattlePhase {
    NONE = 0,
    SETUP = 1,
    DEPLOYMENT = 2,
    INITIATIVE = 3,
    ACTIVATION = 4,
    REACTION = 5,
    CLEANUP = 6
}

enum CampaignVictoryType {
    NONE,
    STANDARD,
    WEALTH,
    REPUTATION,
    CONQUEST,
    STORY,
    SURVIVAL,
    TURNS_20,
    TURNS_50,
    TURNS_100,
    QUESTS_3,
    QUESTS_5,
    QUESTS_10,
    WEALTH_GOAL,
    REPUTATION_GOAL,
    FACTION_DOMINANCE,
    STORY_COMPLETE,
    ELIMINATION,
    EXTRACTION,
    CONTROL_POINTS,
    OBJECTIVE
}

enum MissionVictoryType {
    NONE,
    ELIMINATION, # Eliminate all enemies
    OBJECTIVE, # Complete specific objective
    EXTRACTION, # Reach extraction point
    SURVIVAL, # Survive specified duration
    CONTROL_POINTS, # Control specific points
    CUSTOM # Custom victory conditions
}

enum ShipComponentType {
    NONE,
    # Hull types
    HULL_LIGHT,
    HULL_MEDIUM,
    HULL_HEAVY,
    # Engine types
    ENGINE_BASIC,
    ENGINE_IMPROVED,
    ENGINE_ADVANCED,
    # Weapon types
    WEAPON_LIGHT,
    WEAPON_MEDIUM,
    WEAPON_HEAVY,
    # Medical bay types
    MEDICAL_BASIC,
    MEDICAL_IMPROVED,
    MEDICAL_ADVANCED
}

enum PlanetType {
    NONE,
    FRONTIER,
    CORE_WORLD,
    COLONY,
    MINING_WORLD,
    INDUSTRIAL,
    AGRICULTURAL,
    RESEARCH_STATION
}

enum ResourceType {
    NONE,
    MINERALS,
    FUEL,
    FOOD,
    TECHNOLOGY,
    LUXURY_GOODS,
    MEDICAL_SUPPLIES,
    WEAPONS,
    RARE_MATERIALS,
    CREDITS,
    SUPPLIES,
    STORY_POINT,
    PATRON,
    RIVAL,
    QUEST_RUMOR,
    XP,
    REPUTATION,
    STORY_POINTS,
    EXPERIENCE,
    MATERIALS,
    MEDICAL,
    AMMUNITION
}

enum WorldTrait {
    NONE,
    INDUSTRIAL_HUB,
    FRONTIER_WORLD,
    TRADE_CENTER,
    PIRATE_HAVEN,
    FREE_PORT,
    CORPORATE_CONTROLLED,
    TECH_CENTER,
    MINING_COLONY,
    AGRICULTURAL_WORLD
}

enum ThreatType {
    NONE,
    PIRATES,
    RAIDERS,
    HOSTILE_FAUNA,
    NATURAL_DISASTERS,
    DISEASE,
    REBELLION,
    INVASION,
    CORRUPTION,
    UNREST
}

enum StrifeType {
    NONE,
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL,
    RESOURCE_CONFLICT,
    POLITICAL_UNREST,
    CRIMINAL_UPRISING,
    CORPORATE_WAR
}

enum FringeWorldInstability {
    STABLE,
    UNREST,
    UNSTABLE,
    CHAOTIC,
    COLLAPSING
}

enum BattleEnvironment {
    NONE,
    URBAN, # City/built-up area
    WILDERNESS, # Natural environment
    SPACE_STATION, # Space station interior
    SHIP_INTERIOR, # Starship interior
    INDUSTRIAL # Factory/industrial area
}

enum BattleObjective {
    NONE,
    CAPTURE_POINT,
    DEFEND_POINT,
    ELIMINATE_TARGET,
    RETRIEVE_ITEM,
    ESCAPE
}

enum TerrainFeatureType {
    NONE,
    WALL,
    COVER_LOW,
    COVER_HIGH,
    HIGH_GROUND,
    WATER,
    HAZARD,
    DIFFICULT
}

enum CharacterBackground {
    NONE,
    MILITARY,
    ACADEMIC,
    CRIMINAL
}

enum CharacterMotivation {
    NONE,
    GLORY,
    WEALTH,
    SURVIVAL
}

enum DeploymentZone {
    PLAYER,
    ENEMY,
    NEUTRAL,
    OBJECTIVE
}

enum CrewSize {
    FOUR = 4,
    FIVE = 5,
    SIX = 6
}

enum CharacterStats {
    REACTIONS,
    SPEED,
    COMBAT_SKILL,
    TOUGHNESS,
    SAVVY,
    LUCK
}

enum EnemyType {
    NONE,
    GRUNT,
    ELITE,
    BOSS,
    MINION,
    GANGERS,
    PUNKS,
    RAIDERS,
    CULTISTS,
    PSYCHOS,
    BRAT_GANG,
    GENE_RENEGADES,
    ANARCHISTS,
    PIRATES,
    K_ERIN_OUTLAWS,
    SKULKER_BRIGANDS,
    TECH_GANGERS,
    STARPORT_SCUM,
    HULKER_GANG,
    GUN_SLINGERS,
    UNKNOWN_MERCS,
    ENFORCERS,
    GUILD_TROOPS,
    ROID_GANGERS,
    BLACK_OPS_TEAM,
    WAR_BOTS,
    SECRET_AGENTS,
    ASSASSINS,
    CORPORATE_SECURITY,
    UNITY_GRUNTS,
    SECURITY_BOTS,
    BLACK_DRAGON_MERCS,
    RAGE_LIZARD_MERCS,
    BLOOD_STORM_MERCS,
    FERAL_MERCENARIES,
    SKULKER_MERCENARIES
}

enum EnemyCategory {
    CRIMINAL_ELEMENTS,
    HIRED_MUSCLE,
    MILITARY_FORCES,
    ALIEN_THREATS
}

enum EnemyBehavior {
    AGGRESSIVE,
    CAUTIOUS,
    TACTICAL,
    DEFENSIVE,
    BEAST,
    RAMPAGE,
    GUARDIAN
}

enum EnemyWeaponClass {
    BASIC = 1,
    ADVANCED = 2,
    ELITE = 3
}

enum EnemyTrait {
    FEARLESS,
    STUBBORN,
    CARELESS,
    ALERT,
    FEROCIOUS,
    SCAVENGER,
    QUICK,
    GRUESOME,
    INTRIGUE,
    TOUGH_FIGHT,
    SAVING_THROW,
    BAD_SHOTS,
    TRICK_SHOT,
    LEG_IT,
    AGGRO,
    UP_CLOSE,
    FRIDAY_NIGHT_WARRIORS
}

enum EnemyDeploymentPattern {
    STANDARD,
    LINE,
    SCATTERED,
    AMBUSH,
    DEFENSIVE,
    OFFENSIVE,
    INFILTRATION,
    CONCEALED,
    REINFORCEMENT,
    BOLSTERED_LINE
}

enum EnemyReward {
    NONE,
    CREDITS,
    ITEM,
    INFORMATION,
    QUEST_RUMOR,
    REPUTATION,
    SPECIAL
}

enum RedZoneMissionObjective {
    NONE,
    DESTROY_STRONGPOINT,
    HOLD_POSITION,
    ELIMINATE_TARGET,
    DESTROY_PLATOON,
    PENETRATE_LINES,
    SABOTAGE,
    RESCUE,
    SECURE_INTEL,
    CLEAR_ZONE
}

enum EnemyCharacteristic {
    NONE,
    FEARLESS,
    STUBBORN,
    CARELESS,
    ALERT,
    FEROCIOUS,
    SCAVENGER,
    QUICK,
    GRUESOME,
    INTRIGUE,
    TOUGH_FIGHT,
    SAVING_THROW,
    BAD_SHOTS,
    TRICK_SHOT,
    LEG_IT,
    AGGRO,
    UP_CLOSE,
    FRIDAY_NIGHT_WARRIORS
}

enum TechLevel {
    NONE,
    PRIMITIVE,
    BASIC,
    STANDARD,
    ADVANCED,
    CUTTING_EDGE
}

enum PopulationLevel {
    NONE,
    OUTPOST,
    SETTLEMENT,
    COLONY,
    CITY,
    METROPOLIS
}

enum GovernmentType {
    NONE,
    ANARCHY,
    DEMOCRACY,
    OLIGARCHY,
    CORPORATE,
    MILITARY,
    TECHNOCRACY
}

enum WeatherType {
    NONE,
    CLEAR,
    CLOUDY,
    RAIN,
    STORM,
    HAZARDOUS
}

enum RelationType {
    NONE,
    HOSTILE,
    NEUTRAL,
    FRIENDLY,
    ALLIED
}

enum ShipCondition {
    PERFECT,
    GOOD,
    DAMAGED,
    BROKEN
}

enum PlanetEnvironment {
    NONE,
    DESERT,
    JUNGLE,
    ICE,
    VOLCANIC,
    URBAN,
    OCEAN,
    FOREST,
    MOUNTAIN,
    SWAMP,
    WASTELAND
}

enum CrewTask {
    NONE,
    FIND_PATRON,
    TRAIN,
    TRADE,
    RECRUIT,
    EXPLORE,
    TRACK,
    REPAIR,
    DECOY
}

enum JobType {
    NONE,
    BOUNTY,
    ESCORT,
    DELIVERY,
    PROTECTION,
    SABOTAGE,
    INVESTIGATION,
    RECOVERY,
    ELIMINATION
}

enum PatronType {
    NONE,
    MERCHANT,
    NOBLE,
    CRIMINAL,
    CORPORATE,
    MILITARY,
    REBEL,
    MYSTERIOUS
}

enum TerrainTypes {
    INVALID,
    EMPTY,
    WALL,
    COVER_LOW,
    COVER_HIGH,
    WATER,
    HAZARD,
    DIFFICULT,
    BLOCKED,
    ELEVATED
}

static func get_enum_name(category: String, value: int) -> String:
    match category:
        "difficulty":
            if value in DifficultyMode.values():
                return DifficultyMode.keys()[value]
        "species":
            if value in Origin.values():
                return Origin.keys()[value]
        "class":
            if value in CharacterClass.values():
                return CharacterClass.keys()[value]
        "victory":
            if value in VictoryConditionType.values():
                return VictoryConditionType.keys()[value]
    return ""
