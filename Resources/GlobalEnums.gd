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
    DOMINATE,
    NONE
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
    RETRIEVAL,
    FRINGE_WORLD_STRIFE  # Add this to match the error in the image
}

enum TerrainType {
    CITY,
    FOREST,
    SPACE_STATION,
    STARSHIP,
    ALIEN_LANDSCAPE
}

enum CampaignPhase {
    INITIAL_SETUP,
    CREW_CREATION,
    CREW_MANAGEMENT,
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
}

enum CharacterStatus {
    ACTIVE,
    INJURED,
    STUNNED,
    FLEEING,
    DEAD,
    BUSY,
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
    NONE,
    FIND_PATRON,
    TRAIN,
    TRADE,
    RECRUIT,
    EXPLORE,
    TRACK,
    REPAIR_KIT,
    DECOY,
    TRACK_RIVAL,
    REPAIR,
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
    EASY,
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
    WORLD,
    POST_BATTLE,
    TRACK_RIVALS,
    PATRON_JOB,
    RIVAL_ATTACK,
    ASSIGN_EQUIPMENT,
    READY_FOR_BATTLE
}

# Gameplay Modifiers
@export var use_expanded_campaign_phases: bool = false

# Added missing enums
enum GlobalEvent {
    MARKET_CRASH,
    ECONOMIC_BOOM,
    TRADE_EMBARGO,
    RESOURCE_SHORTAGE,
    TECHNOLOGICAL_BREAKTHROUGH,
    ALIEN_INVASION,
    CORPORATE_TAKEOVER,
    RESOURCE_CRISIS,
    POLITICAL_UPHEAVAL,
    NATURAL_DISASTER,
    GALACTIC_WAR
}

enum StatusEffectType {
    BUFF,
    DEBUFF,
    NEUTRAL,
    STUN,
    POISON,
    REGENERATION,
    SHIELD
}

enum DeploymentType {
    LINE,
    HALF_FLANK,
    IMPROVED_POSITIONS,
    FORWARD_POSITIONS,
    BOLSTERED_LINE,
    INFILTRATION,
    REINFORCED,
    BOLSTERED_FLANK,
    CONCEALED
}

enum VictoryConditionType {
    TURNS,
    QUESTS,
    BATTLES,
    UNIQUE_KILLS,
    CHARACTER_UPGRADES,
    MULTI_CHARACTER_UPGRADES
}

enum AIBehavior {
    AGGRESSIVE,
    CAUTIOUS,
    DEFENSIVE,
    TACTICAL,
    RAMPAGE,
    BEAST,
    GUARDIAN
}

# Add these new enums at the end of the file

enum TrainingType {
    BASIC,
    ADVANCED,
    SPECIALIZED
}

enum BasicTrainingCourse {
    COMBAT_BASICS,
    TECHNICAL_FUNDAMENTALS,
    SOCIAL_SKILLS,
    SURVIVAL_TECHNIQUES
}

enum AdvancedTrainingCourse {
    PILOT_TRAINING,
    HACKING_MASTERY,
    ADVANCED_COMBAT_TACTICS,
    XENOBIOLOGY,
    NEGOTIATION_EXPERTISE
}

enum SpecializedTrainingCourse {
    PSIONIC_DEVELOPMENT,
    ALIEN_TECH_MASTERY,
    COVERT_OPS,
    LEADERSHIP,
    ADVANCED_ENGINEERING
}

# You can also add a constant for training costs if needed
const BASIC_TRAINING_COST = 10
const ADVANCED_TRAINING_COST = 20
const SPECIALIZED_TRAINING_COST = 30

# Function to get training cost based on type
static func get_training_cost(training_type: TrainingType) -> int:
    match training_type:
        TrainingType.BASIC:
            return BASIC_TRAINING_COST
        TrainingType.ADVANCED:
            return ADVANCED_TRAINING_COST
        TrainingType.SPECIALIZED:
            return SPECIALIZED_TRAINING_COST
    return 0  # Default case

enum BattlePhase {
    REACTION_ROLL,
    QUICK_ACTIONS,
    ENEMY_ACTIONS,
    SLOW_ACTIONS,
    END_PHASE,
    END_ROUND,
}

enum CoverType {
    NONE,
    PARTIAL,
    FULL
}

enum GameState {SETUP, CAMPAIGN, BATTLE, VICTORY_CHECK}





