extends Node

enum Type {
    RED_ZONE,
    YELLOW_ZONE,
    GREEN_ZONE,
    BLACK_ZONE,
    OPPORTUNITY,
    QUEST,
    TUTORIAL,
    RIVAL,
    PATRON,
    ASSASSINATION,
    SABOTAGE,
    RESCUE,
    DEFENSE,
    ESCORT
}

enum Origin {
    HUMAN,
    SYNTHETIC,
    HYBRID,
    MUTANT,
    UPLIFTED
}

enum Background {
    MILITARY,
    CORPORATE,
    ACADEMIC,
    FRONTIER,
    CRIMINAL,
    NOMAD,
    MILITARY_BRAT,
    MINING_COLONY,
    HIGH_TECH_COLONY
}

enum Motivation {
    WEALTH,
    REVENGE,
    DISCOVERY,
    GLORY,
    SURVIVAL,
    POWER
}

enum Class {
    SOLDIER,
    SCOUT,
    TECHNICIAN,
    MEDIC,
    DIPLOMAT,
    PSION
}

enum WeaponType {
    PISTOL,
    RIFLE,
    HEAVY,
    MELEE,
    SPECIAL,
    MILITARY,
    HIGH_TECH,
    LAUNCHER,
    GRENADE
}

enum CampaignPhase {
    MAIN_MENU,
    CREW_CREATION,
    UPKEEP,
    MISSION,
    BATTLE,
    POST_BATTLE,
    STORY_POINT
}

enum TerrainType {
    CITY,
    WILDERNESS,
    SPACE,
    STATION,
    UNDERGROUND
}

enum FactionType {
    NEUTRAL,
    HOSTILE,
    FRIENDLY,
    CORPORATE,
    MILITARY,
    CRIMINAL
}

enum StrifeType {
    RESOURCE_CONFLICT,
    CIVIL_UNREST,
    CORPORATE_WAR,
    ALIEN_THREAT,
    NATURAL_DISASTER,
    POLITICAL_UPRISING,
    ALIEN_INCURSION,
    CORPORATE_WARFARE
}

enum MissionStatus {
    ACTIVE,
    COMPLETED,
    FAILED,
    EXPIRED
}

enum MissionObjective {
    EXPLORE,
    FIGHT_OFF,
    RESCUE,
    RETRIEVE,
    ELIMINATE,
    NEGOTIATE,
    DEFEND,
    ESCORT,
    MOVE_THROUGH,
    PROTECT,
    DESTROY
}

enum TerrainGenerationType {
    INDUSTRIAL,
    URBAN,
    WILDERNESS,
    SPACE,
    UNDERGROUND
}

enum DeploymentType {
    LINE,
    SCATTERED,
    FLANKING,
    DEFENSIVE,
    AGGRESSIVE,
    HALF_FLANK,
    FORWARD_POSITIONS,
    BOLSTERED_LINE,
    INFILTRATION,
    BOLSTERED_FLANK,
    CONCEALED,
    IMPROVED_POSITIONS,
    REINFORCED
}

enum VictoryConditionType {
    TURNS,
    ELIMINATION,
    OBJECTIVE,
    SURVIVAL,
    EXTRACTION
}

enum AIBehavior {
    TACTICAL,
    AGGRESSIVE,
    DEFENSIVE,
    OPPORTUNISTIC,
    CAUTIOUS
}

enum WorldTrait {
    RICH,
    POOR,
    LAWLESS,
    ORDERLY,
    TECHNOLOGICAL,
    PRIMITIVE
}

enum SkillType {
    COMBAT,
    TECHNICAL,
    SOCIAL,
    SURVIVAL,
    LEADERSHIP,
    PILOTING
}

enum AIType {
    GRUNT,
    ELITE,
    BOSS,
    CIVILIAN,
    SECURITY,
    CAUTIOUS,
    AGGRESSIVE,
    TACTICAL,
    DEFENSIVE,
    RAMPAGE,
    BEAST,
    GUARDIAN
}

enum Faction {
    CORPORATE,
    MILITARY,
    CRIMINAL,
    SCIENTIFIC,
    POLITICAL,
    RELIGIOUS,
    MERCENARY,
    INDEPENDENT,
    UNITY,
    FRINGE
}

enum FringeWorldInstability {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

enum WorldPhase {
    UPKEEP,
    SHIP_REPAIRS,
    LOAN_CHECK,
    CREW_TASKS,
    JOB_OFFERS,
    EQUIPMENT,
    RUMORS,
    BATTLE_PREP
}

enum WeaponTrait {
    AREA,
    CLUMSY,
    CRITICAL,
    ELEGANT,
    FOCUSED,
    HEAVY,
    IMPACT,
    MELEE,
    PIERCING,
    PISTOL,
    SINGLE_USE,
    SNAP_SHOT,
    STUN,
    TERRIFYING,
    RAPID_FIRE,
    ACCURATE,
    SPREAD,
    ENERGY,
    BLAST,
    OVERHEAT,
    AIMED
}

enum ArmorTrait {
    LIGHT,
    MEDIUM,
    HEAVY,
    POWERED,
    CUMBERSOME,
    ENERGY,
    RECHARGEABLE
}

enum ItemType {
    WEAPON,
    ARMOR,
    CONSUMABLE,
    TOOL,
    MODIFICATION,
    GEAR,
    MEDICAL,
    UTILITY,
    TECH,
    MOBILITY,
    EXPLOSIVE,
    IMPLANT
}

enum EquipmentSlot {
    PRIMARY_WEAPON,
    SECONDARY_WEAPON,
    ARMOR,
    GEAR,
    IMPLANT,
    CONSUMABLE
}

enum EquipmentRarity {
    COMMON,
    UNCOMMON,
    RARE,
    UNIQUE,
    LEGENDARY
}

enum EquipmentCategory {
    MILITARY,
    HIGH_TECH,
    CIVILIAN,
    EXPERIMENTAL,
    ALIEN
}

enum GameState {
    SETUP,
    CAMPAIGN,
    BATTLE,
    PAUSE,
    GAME_OVER
}

enum BattlePhase {
    REACTION_ROLL,
    MOVEMENT,
    SHOOTING,
    MELEE,
    MORALE,
    END_TURN
}

enum CoverType {
    NONE,
    LIGHT,
    MEDIUM,
    HEAVY,
    FULL
}

enum GlobalEvent {
    NONE,
    MARKET_CRASH,
    ECONOMIC_BOOM,
    TRADE_EMBARGO,
    RESOURCE_SHORTAGE,
    TECHNOLOGICAL_BREAKTHROUGH,
    ALIEN_INVASION,
    CORPORATE_TAKEOVER,
    RESOURCE_CRISIS,
    POLITICAL_UPHEAVAL,
    NATURAL_DISASTER
}

enum CharacterState {
    ACTIVE,
    STUNNED,
    WOUNDED,
    PANICKED,
    OUT_OF_ACTION
}

enum BattleState {
    SETUP,
    DEPLOYMENT,
    IN_PROGRESS,
    ENDED
}

enum PostBattlePhase {
    REWARDS,
    RECOVERY,
    DEBRIEF,
    ADVANCEMENT
}

enum PatronType {
    MERCHANT,
    NOBLE,
    MERCENARY,
    SCIENTIST,
    DIPLOMAT,
    CRIMINAL
}

enum QuestType {
    STORY,
    SIDE,
    PATRON,
    RIVAL,
    EVENT
}

enum ShipSystem {
    ENGINES,
    WEAPONS,
    SHIELDS,
    LIFE_SUPPORT,
    SENSORS,
    CARGO
}

enum TutorialStage {
    INTRODUCTION,
    MOVEMENT,
    COMBAT,
    OBJECTIVES,
    EQUIPMENT,
    CREW_MANAGEMENT,
    COMPLETED
}

enum DifficultyLevel {
    EASY,
    NORMAL,
    HARD,
    IRONMAN
}

enum CharacterAttribute {
    STRENGTH,
    AGILITY,
    INTELLIGENCE,
    WILLPOWER,
    CHARISMA,
    TECH
}

enum ComponentType {
    HULL,
    ENGINE,
    WEAPONS,
    MEDICAL_BAY,
    SHIELD,
    CARGO,
    DROP_POD,
    SHUTTLE
}

enum StreetFightType {
    AMBUSH,
    BRAWL,
    CHASE,
    SIEGE,
    RAID
}

enum LoanType {
    STANDARD,
    PREDATORY,
    BLACK_MARKET
}

enum ArmorType {
    LIGHT,
    MEDIUM,
    HEAVY,
    SCREEN
}

# Make sure this is registered as an autoload in project settings





