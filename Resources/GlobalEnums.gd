class_name GlobalEnums
extends Resource

enum Species {
    HUMAN,
    ENGINEER,
    KERIN,
    SOULLESS,
    PRECURSOR,
    FERAL,
    SWIFT,
    BOT,
    SKULKER,
    KRAG
}

enum Background {
    HIGH_TECH_COLONY,
    OVERCROWDED_CITY,
    LOW_TECH_COLONY,
    MINING_COLONY,
    MILITARY_BRAT,
    SPACE_STATION
}

enum Motivation {
    WEALTH,
    FAME,
    GLORY,
    SURVIVAL,
    ESCAPE,
    ADVENTURE
}

enum Class {
    WORKING_CLASS,
    TECHNICIAN,
    SCIENTIST,
    HACKER,
    SOLDIER,
    MERCENARY
}

enum PsionicPower {
    BARRIER,
    GRAB,
    LIFT,
    SHROUD,
    ENRAGE,
    PREDICT,
    SHOCK,
    REJUVENATE,
    GUIDE,
    PSIONIC_SCARE,
    CRUSH,
    DIRECT,
    DOMINATE
    # Ensure this matches your Psionics.json file
}

enum PsionicLegality {
    LEGAL,
    RESTRICTED,
    ILLEGAL
}

enum WeaponType {
    PISTOL,
    RIFLE,
    HEAVY,
    MELEE,
    GRENADE
}

enum ArmorType {
    LIGHT,
    MEDIUM,
    HEAVY,
    SCREEN
}

enum MissionType {
    PATROL,
    RESCUE,
    SABOTAGE,
    ESCORT,
    ASSASSINATION,
    RETRIEVAL
}

enum TerrainType {
    CITY,
    FOREST,
    SPACE_STATION,
    STARSHIP,
    ALIEN_LANDSCAPE
}

enum CampaignPhase {
    UPKEEP,
    STORY_POINT,
    TRAVEL,
    PATRONS,
    MISSION,
    BATTLE,
    POST_BATTLE,
    TRACK_RIVALS,
    PATRON_JOB,
    RIVAL_ATTACK,
    ASSIGN_EQUIPMENT,
    READY_FOR_BATTLE,
    MAIN_MENU,
    CREW_CREATION 
}

enum CharacterStatus {
    ACTIVE,
    INJURED,
    DEAD
}

enum SkillType {
    COMBAT,
    TECHNICAL,
    SOCIAL,
    SURVIVAL
}

enum ItemRarity {
    COMMON,
    UNCOMMON,
    RARE,
    UNIQUE
}

enum FactionType {
    NEUTRAL,
    FRIENDLY,
    HOSTILE
}

enum BattleOutcome {
    VICTORY,
    DEFEAT,
    DRAW
}

enum ShipUpgrade {
    ENGINE,
    WEAPONS,
    SHIELDS,
    CARGO,
    LIVING_QUARTERS
}

enum StrifeType {
    RESOURCE_CONFLICT,
    POLITICAL_UPRISING,
    ALIEN_INCURSION,
    CORPORATE_WARFARE
}

enum ComponentType {
    HULL,
    ENGINE,
    WEAPONS,
    MEDICAL_BAY,
    SHIELDS,
    CARGO_HOLD,
    DROP_POD,
    SHUTTLE_BAY,
    LIFE_SUPPORT
}

enum Type {
    INFILTRATION,
    STREET_FIGHT,
    SALVAGE_JOB,
    FRINGE_WORLD_STRIFE,
    OPPORTUNITY,
    PATRON,
    QUEST,
    RIVAL,
    TUTORIAL,
    STANDARD,
    ASSASSINATION,
    SABOTAGE,
    RESCUE,
    DEFENSE,
    ESCORT
}

enum MissionObjective {
    INFILTRATION,
    FIGHT_OFF,
    ACQUIRE,
    DEFEND,
    DELIVER,
    ELIMINATE,
    EXPLORE,
    MOVE_THROUGH,
    SABOTAGE,
    DESTROY,
    RESCUE,
    PROTECT
}

enum MissionStatus {
    ACTIVE,
    COMPLETED,
    FAILED
}

enum CrewTask {
    FIND_PATRON,
    TRAIN,
    TRADE,
    RECRUIT,
    EXPLORE,
    TRACK,
    REPAIR_KIT,
    DECOY
}

enum ItemType {
    WEAPON,
    ARMOR,
    GEAR,
    CONSUMABLE
}

enum WeaponTrait {
    CLUMSY,
    CRITICAL,
    ELEGANT,
    FOCUSED,
    TERRIFYING,
    HEAVY,
    AREA,
    SINGLE_USE,
    PIERCING,
    SNAP_SHOT,
    IMPACT
}

enum AIType {
    AGGRESSIVE,
    CAUTIOUS,
    DEFENSIVE,
    GUARDIAN,
    RAMPAGE,
    TACTICAL,
    BEAST
}

enum Faction {
    UNITY,
    CORPORATE,
    FRINGE,
    ALIEN
}

enum WorldTrait {
    BUSTLING,
    QUIET,
    DANGEROUS,
    SAFE,
    RICH,
    POOR
}

enum DifficultyMode {
    NORMAL,
    CHALLENGING,
    HARDCORE,
    INSANITY
}

enum SalvageType {
    TECH,
    RESOURCES,
    ARTIFACTS
}

enum StreetFightType {
    GANG_WAR,
    TURF_DEFENSE,
    REVENGE_HIT
}

enum FringeWorldInstability {
    STABLE,
    UNREST,
    CONFLICT,
    CHAOS
}

enum LoanType {
    STANDARD,
    PREDATORY,
    BLACK_MARKET
}

enum ReputationLevel {
    UNKNOWN,
    NOTORIOUS,
    RESPECTED,
    LEGENDARY
}

enum TerrainSize {
    SMALL,
    MEDIUM,
    LARGE
}

enum TerrainFeature {
    LINEAR,
    AREA,
    FIELD,
    INDIVIDUAL,
    BLOCK,
    INTERIOR
}

enum TerrainGenerationType {
    INDUSTRIAL,
    WILDERNESS,
    ALIEN_RUIN,
    CRASH_SITE
}

enum TerrainEffect {
    LINE_OF_SIGHT,
    COVER,
    MOVEMENT
}

# Expanded Campaign Phases
enum ExpandedCampaignPhase {
    UPKEEP,
    STORY_POINT,
    TRAVEL,
    PATRONS,
    MISSION,
    BATTLE,
    POST_BATTLE,
    TRACK_RIVALS,
    PATRON_JOB,
    RIVAL_ATTACK,
    ASSIGN_EQUIPMENT,
    READY_FOR_BATTLE
}

# Gameplay Modifiers
@export var use_expanded_campaign_phases: bool = false