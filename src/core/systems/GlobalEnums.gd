@tool
extends Node

## Edit Mode
enum EditMode {
	NONE,
	CREATE,
	EDIT,
	VIEW
}

## Phase Names and Descriptions
enum FiveParcsecsCampaignPhase {
	NONE,
	SETUP,
	UPKEEP,
	STORY,
	CAMPAIGN,
	BATTLE_SETUP,
	BATTLE_RESOLUTION,
	ADVANCEMENT,
	TRADE,
	END
}

## Campaign Sub-Phases for more granular campaign flow management
enum CampaignSubPhase {
	NONE,
	TRAVEL,
	WORLD_ARRIVAL,
	WORLD_EVENTS,
	PATRON_CONTACT,
	MISSION_SELECTION
}

const PHASE_NAMES = {
	FiveParcsecsCampaignPhase.NONE: "None",
	FiveParcsecsCampaignPhase.SETUP: "Setup",
	FiveParcsecsCampaignPhase.UPKEEP: "Upkeep",
	FiveParcsecsCampaignPhase.STORY: "Story",
	FiveParcsecsCampaignPhase.CAMPAIGN: "Campaign",
	FiveParcsecsCampaignPhase.BATTLE_SETUP: "Battle Setup",
	FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Battle Resolution",
	FiveParcsecsCampaignPhase.ADVANCEMENT: "Advancement",
	FiveParcsecsCampaignPhase.TRADE: "Trade",
	FiveParcsecsCampaignPhase.END: "End"
}

const PHASE_DESCRIPTIONS = {
	FiveParcsecsCampaignPhase.NONE: "No active phase",
	FiveParcsecsCampaignPhase.SETUP: "Create your crew and prepare for adventure",
	FiveParcsecsCampaignPhase.UPKEEP: "Maintain your crew and resources",
	FiveParcsecsCampaignPhase.STORY: "Progress through story events",
	FiveParcsecsCampaignPhase.CAMPAIGN: "Engage in campaign activities",
	FiveParcsecsCampaignPhase.BATTLE_SETUP: "Prepare for combat",
	FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Handle battle aftermath",
	FiveParcsecsCampaignPhase.ADVANCEMENT: "Improve your crew",
	FiveParcsecsCampaignPhase.TRADE: "Buy and sell equipment",
	FiveParcsecsCampaignPhase.END: "Campaign phase complete"
}

## Difficulty Levels
enum DifficultyLevel {
	NONE,
	EASY,
	NORMAL,
	HARD,
	NIGHTMARE,
	HARDCORE,
	ELITE
}

## Character System
enum ArmorCharacteristic {
	NONE,
	LIGHT,
	MEDIUM,
	HEAVY,
	POWERED,
	STEALTH,
	HAZARD,
	SHIELD
}

## Character Classes
enum CharacterClass {
	NONE,
	SOLDIER,
	MEDIC,
	ENGINEER,
	PILOT,
	MERCHANT,
	SECURITY,
	BROKER,
	BOT_TECH
}

## Training Levels
enum Training {
	NONE,
	PILOT,
	MECHANIC,
	MEDICAL,
	MERCHANT,
	SECURITY,
	BROKER,
	BOT_TECH,
	SPECIALIST,
	ELITE
}

const TRAINING_NAMES = {
	Training.NONE: "None",
	Training.PILOT: "Pilot",
	Training.MECHANIC: "Mechanic",
	Training.MEDICAL: "Medical",
	Training.MERCHANT: "Merchant",
	Training.SECURITY: "Security",
	Training.BROKER: "Broker",
	Training.BOT_TECH: "Bot Tech",
	Training.SPECIALIST: "Specialist",
	Training.ELITE: "Elite"
}

static func get_training_name(training: Training) -> String:
	return TRAINING_NAMES.get(training, "Unknown Training")

## Character Origins
enum Origin {
	NONE,
	HUMAN,
	ENGINEER,
	FERAL,
	KERIN,
	PRECURSOR,
	SOULLESS,
	SWIFT,
	BOT,
	CORE_WORLDS,
	FRONTIER,
	DEEP_SPACE,
	COLONY,
	HIVE_WORLD,
	FORGE_WORLD
}

## Character Background
enum Background {
	NONE,
	MILITARY,
	MERCENARY,
	CRIMINAL,
	COLONIST,
	ACADEMIC,
	EXPLORER,
	TRADER,
	NOBLE,
	OUTCAST,
	SOLDIER,
	MERCHANT
}

## Character Motivation
enum Motivation {
	NONE,
	WEALTH,
	REVENGE,
	GLORY,
	KNOWLEDGE,
	POWER,
	JUSTICE,
	SURVIVAL,
	LOYALTY,
	FREEDOM,
	DISCOVERY,
	REDEMPTION,
	DUTY
}

## Resource System
enum ResourceType {
	NONE,
	CREDITS,
	SUPPLIES,
	TECH_PARTS,
	PATRON,
	FUEL,
	MEDICAL_SUPPLIES,
	WEAPONS,
	STORY_POINT,
	REPUTATION
}

## Campaign System
enum FiveParcsecsCampaignType {
	NONE,
	STANDARD,
	CUSTOM,
	TUTORIAL,
	STORY,
	SANDBOX
}

enum FiveParcsecsCampaignVictoryType {
	NONE,
	STANDARD,
	WEALTH_GOAL,
	REPUTATION_GOAL,
	FACTION_DOMINANCE,
	STORY_COMPLETE,
	CREDITS_THRESHOLD,
	REPUTATION_THRESHOLD,
	MISSION_COUNT,
	TURNS_20,
	TURNS_50,
	TURNS_100,
	QUESTS_3,
	QUESTS_5,
	QUESTS_10
}

## Market System
enum MarketState {
	NONE,
	NORMAL,
	CRISIS,
	BOOM,
	RESTRICTED
}

## Mission System
enum MissionObjective {
	NONE,
	WIN_BATTLE,
	SABOTAGE,
	RECON,
	RESCUE,
	PATROL,
	SEEK_AND_DESTROY,
	DEFEND,
	CAPTURE_POINT,
	TUTORIAL
}

## Weather System
enum WeatherType {
	NONE,
	CLEAR,
	RAIN,
	STORM,
	FOG,
	HAZARDOUS
}

## Mission Types
enum MissionType {
	NONE,
	SABOTAGE,
	RESCUE,
	BLACK_ZONE,
	GREEN_ZONE,
	RED_ZONE,
	PATROL,
	ESCORT,
	ASSASSINATION,
	PATRON,
	RAID,
	DEFENSE
}

## Weapon Types
enum WeaponType {
	NONE,
	BASIC,
	ADVANCED,
	ELITE,
	PISTOL,
	RIFLE,
	HEAVY,
	MELEE,
	SPECIAL
}

## AI Behavior
enum AIBehavior {
	NONE,
	AGGRESSIVE,
	DEFENSIVE,
	TACTICAL,
	CAUTIOUS,
	SUPPORTIVE
}

## Planet Types
enum PlanetType {
	NONE,
	DESERT,
	ICE,
	JUNGLE,
	OCEAN,
	ROCKY,
	TEMPERATE,
	VOLCANIC
}

## Threat Types
enum ThreatType {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
	EXTREME,
	BOSS
}

## Relation Types
enum RelationType {
	NONE,
	FRIENDLY,
	NEUTRAL,
	HOSTILE,
	ALLIED,
	ENEMY
}

## Ship Conditions
enum ShipCondition {
	NONE,
	PRISTINE,
	GOOD,
	DAMAGED,
	CRITICAL,
	DESTROYED
}

## Victory Conditions
enum VictoryConditionType {
	NONE,
	ELIMINATION,
	OBJECTIVE,
	SURVIVAL,
	EXTRACTION
}

## Enemy Ranks
enum EnemyRank {
	NONE,
	MINION,
	ELITE,
	BOSS
}

## Enemy Traits
enum EnemyTrait {
	NONE,
	SCAVENGER,
	TOUGH_FIGHT,
	ALERT,
	FEROCIOUS,
	LEG_IT,
	FRIDAY_NIGHT_WARRIORS,
	AGGRO,
	UP_CLOSE,
	FEARLESS,
	GRUESOME,
	SAVING_THROW,
	TRICK_SHOT,
	CARELESS,
	BAD_SHOTS
}

## Location Types
enum LocationType {
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

## Armor Classes
enum ArmorClass {
	NONE,
	LIGHT,
	MEDIUM,
	HEAVY
}

## Enemy Categories
enum EnemyCategory {
	NONE,
	CRIMINAL_ELEMENTS,
	HIRED_MUSCLE,
	MILITARY_FORCES,
	ALIEN_THREATS
}

## Enemy Behaviors
enum EnemyBehavior {
	NONE,
	AGGRESSIVE,
	DEFENSIVE,
	TACTICAL,
	BEAST,
	RAMPAGE,
	GUARDIAN,
	CAUTIOUS
}

## Enemy Types
enum EnemyType {
	NONE,
	GANGERS,
	PUNKS,
	RAIDERS,
	PIRATES,
	CULTISTS,
	PSYCHOS,
	WAR_BOTS,
	SECURITY_BOTS,
	BLACK_OPS_TEAM,
	SECRET_AGENTS,
	ELITE,
	BOSS,
	MINION,
	ENFORCERS,
	ASSASSINS,
	UNITY_GRUNTS,
	BLACK_DRAGON_MERCS
}

## Item Types
enum ItemType {
	NONE,
	WEAPON,
	ARMOR,
	MISC,
	CONSUMABLE,
	QUEST,
	GEAR,
	MODIFICATION,
	SPECIAL
}

## Item Rarities
enum ItemRarity {
	NONE,
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Global Events
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

## Quest Types
enum QuestType {
	NONE,
	MAIN,
	SIDE,
	STORY,
	EVENT
}

## Quest Status
enum QuestStatus {
	NONE,
	ACTIVE,
	COMPLETED,
	FAILED
}

## Battle Types
enum BattleType {
	NONE,
	STANDARD,
	BOSS,
	STORY,
	EVENT
}

## Mission Victory Types
enum MissionVictoryType {
	NONE,
	ELIMINATION,
	EXTRACTION,
	SURVIVAL,
	CONTROL_POINTS,
	OBJECTIVE
}

## World System
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

enum PlanetEnvironment {
	NONE,
	URBAN,
	FOREST,
	DESERT,
	ICE,
	RAIN,
	STORM,
	HAZARDOUS,
	VOLCANIC,
	OCEANIC,
	TEMPERATE,
	JUNGLE
}

enum StrifeType {
	NONE,
	PEACEFUL,
	UNREST,
	CIVIL_WAR,
	INVASION,
	LOW,
	MEDIUM,
	HIGH,
	CRITICAL
}

## Deployment Types
enum DeploymentType {
	NONE,
	STANDARD,
	LINE,
	AMBUSH,
	SCATTERED,
	DEFENSIVE,
	INFILTRATION,
	REINFORCEMENT,
	BOLSTERED_LINE,
	CONCEALED,
	OFFENSIVE
}

enum EnemyDeploymentPattern {
	NONE,
	STANDARD,
	SCATTERED,
	AMBUSH,
	OFFENSIVE,
	DEFENSIVE,
	BOLSTERED_LINE,
	CONCEALED
}

## Enemy Equipment
enum EnemyWeaponClass {
	NONE,
	BASIC,
	ADVANCED,
	ELITE,
	BOSS
}

## Armor Types
enum ArmorType {
	NONE,
	LIGHT,
	MEDIUM,
	HEAVY,
	POWERED,
	HAZARD,
	STEALTH,
	SHIELD
}

## Campaign Phases
enum CampaignPhase {
	NONE,
	SETUP,
	UPKEEP,
	STORY,
	CAMPAIGN,
	BATTLE_SETUP,
	BATTLE_RESOLUTION,
	ADVANCEMENT,
	TRADE,
	END
}

## Combat Modifiers
enum CombatModifier {
	NONE,
	COVER_LIGHT,
	COVER_MEDIUM,
	COVER_HEAVY,
	FLANKING,
	ELEVATION,
	SUPPRESSED,
	PINNED,
	STEALTH,
	OVERWATCH
}

## Combat Phases
enum CombatPhase {
	NONE,
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTION,
	REACTION,
	END
}

## Terrain Features
enum TerrainFeatureType {
	NONE,
	WALL,
	COVER,
	OBSTACLE,
	HAZARD,
	RADIATION,
	FIRE,
	ACID,
	SMOKE
}

## Battle States
enum BattleState {
	NONE,
	SETUP,
	ROUND,
	CLEANUP
}

## Battle System Enums
enum BattlePhase {
	NONE,
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTIVATION,
	REACTION,
	CLEANUP
}

## Unit Actions
enum UnitAction {
	NONE,
	MOVE,
	ATTACK,
	DEFEND,
	OVERWATCH,
	RELOAD,
	USE_ITEM,
	SPECIAL,
	TAKE_COVER,
	DASH,
	BRAWL,
	SNAP_FIRE,
	END_TURN,
	SPECIAL_ABILITY
}

enum CombatAdvantage {
	NONE,
	MINOR,
	MAJOR,
	OVERWHELMING
}

enum CombatStatus {
	NONE,
	PINNED,
	FLANKED,
	SURROUNDED,
	SUPPRESSED
}

enum CombatTactic {
	NONE,
	AGGRESSIVE,
	DEFENSIVE,
	BALANCED,
	EVASIVE
}

enum CombatResult {
	NONE,
	HIT,
	MISS,
	CRITICAL,
	GRAZE,
	DODGE,
	BLOCK
}

enum TerrainModifier {
	NONE,
	COVER_BONUS,
	FULL_COVER,
	PARTIAL_COVER,
	LINE_OF_SIGHT_BLOCKED,
	DIFFICULT_TERRAIN,
	ELEVATION_BONUS,
	HAZARDOUS,
	WATER_HAZARD,
	MOVEMENT_PENALTY
}

enum TerrainEffectType {
	NONE,
	COVER,
	ELEVATED,
	HAZARD,
	RADIATION,
	BURNING,
	ACID,
	OBSCURED
}

enum VerificationType {
	NONE,
	COMBAT,
	STATE,
	RULES,
	DEPLOYMENT,
	MOVEMENT,
	OBJECTIVES
}

enum VerificationScope {
	NONE,
	SINGLE,
	ALL,
	SELECTED,
	GROUP
}

enum VerificationResult {
	NONE,
	SUCCESS,
	WARNING,
	ERROR,
	CRITICAL
}

enum EventCategory {
	NONE,
	COMBAT,
	EQUIPMENT,
	TACTICAL,
	ENVIRONMENT,
	SPECIAL
}

enum CombatRange {
	NONE,
	POINT_BLANK,
	SHORT,
	MEDIUM,
	LONG,
	EXTREME
}

## Crew Tasks
enum CrewTask {
	NONE,
	FIND_PATRON,
	RECRUIT,
	EXPLORE,
	TRACK,
	DECOY,
	GUARD,
	SCOUT,
	SABOTAGE,
	GATHER_INFO,
	REPAIR,
	HEAL,
	TRAIN,
	TRADE,
	RESEARCH,
	MAINTENANCE,
	REST,
	SPECIAL
}

enum JobType {
	NONE,
	COMBAT,
	EXPLORATION,
	ESCORT,
	RECOVERY,
	DEFENSE,
	SABOTAGE,
	ASSASSINATION
}

enum StrangeCharacterType {
	NONE,
	ALIEN,
	DE_CONVERTED,
	UNITY_AGENT,
	BOT,
	ASSAULT_BOT,
	PRECURSOR,
	FERAL
}

## Enemy Characteristics
enum EnemyCharacteristic {
	NONE,
	ELITE,
	BOSS,
	MINION,
	LEADER,
	SUPPORT,
	TANK,
	SCOUT,
	SNIPER,
	MEDIC,
	TECH,
	BERSERKER,
	COMMANDER
}

## Game States
enum GameState {
	NONE,
	SETUP,
	CAMPAIGN,
	BATTLE,
	GAME_OVER
}

## Helper Functions
static func get_character_class_name(class_type: CharacterClass) -> String:
	return CharacterClass.keys()[class_type]

static func get_skill_name(skill_type: int) -> String:
	return Skill.keys()[skill_type]

static func get_ability_name(ability_type: int) -> String:
	return Ability.keys()[ability_type]

static func get_trait_name(trait_type: int) -> String:
	return Trait.keys()[trait_type]

## Skills
enum Skill {
	NONE,
	COMBAT_TRAINING,
	HEAVY_WEAPONS,
	FIELD_MEDICINE,
	COMBAT_MEDIC,
	STEALTH,
	SURVIVAL,
	TECH_REPAIR,
	HACKING,
	PSYCHIC_FOCUS,
	MIND_CONTROL
}

## Abilities
enum Ability {
	NONE,
	BATTLE_HARDENED,
	MIRACLE_WORKER,
	GHOST,
	TECH_MASTER,
	PSYCHIC_MASTER
}

## Traits
enum Trait {
	NONE,
	TACTICAL_MIND,
	STREET_SMART,
	QUICK_LEARNER
}

## Character Status
enum CharacterStatus {
	NONE,
	HEALTHY,
	INJURED,
	CRITICAL,
	DEAD,
	CAPTURED,
	MISSING
}

## Verification Status
enum VerificationStatus {
	NONE,
	PENDING,
	VERIFIED,
	REJECTED
}

## Crew Size
enum CrewSize {
	NONE,
	TWO,
	THREE,
	FOUR,
	FIVE,
	SIX
}

enum ShipComponentType {
	NONE,
	HULL_BASIC,
	HULL_REINFORCED,
	HULL_ADVANCED,
	ENGINE_BASIC,
	ENGINE_IMPROVED,
	ENGINE_ADVANCED,
	WEAPON_BASIC_LASER,
	WEAPON_BASIC_KINETIC,
	WEAPON_ADVANCED_LASER,
	WEAPON_ADVANCED_KINETIC,
	WEAPON_HEAVY_LASER,
	WEAPON_HEAVY_KINETIC,
	MEDICAL_BASIC,
	MEDICAL_ADVANCED
}

## Character Stats
enum CharacterStats {
	NONE,
	REACTIONS,
	COMBAT_SKILL,
	TOUGHNESS,
	SAVVY,
	TECH,
	NAVIGATION,
	SOCIAL
}

enum FactionType {
	NONE,
	NEUTRAL,
	FRIENDLY,
	HOSTILE,
	CORPORATE,
	PIRATE,
	REBEL,
	IMPERIAL,
	ENEMY,
	ALLIED
}

const BATTLE_STATE_NAMES = {
	BattleState.NONE: "None",
	BattleState.SETUP: "Setup",
	BattleState.ROUND: "Round",
	BattleState.CLEANUP: "Cleanup"
}

const COMBAT_PHASE_NAMES = {
	CombatPhase.NONE: "None",
	CombatPhase.SETUP: "Setup",
	CombatPhase.DEPLOYMENT: "Deployment",
	CombatPhase.INITIATIVE: "Initiative",
	CombatPhase.ACTION: "Action",
	CombatPhase.REACTION: "Reaction",
	CombatPhase.END: "End"
}

const UNIT_ACTION_NAMES = {
	UnitAction.NONE: "None",
	UnitAction.MOVE: "Move",
	UnitAction.ATTACK: "Attack",
	UnitAction.DEFEND: "Defend",
	UnitAction.OVERWATCH: "Overwatch",
	UnitAction.RELOAD: "Reload",
	UnitAction.USE_ITEM: "Use Item",
	UnitAction.SPECIAL: "Special",
	UnitAction.TAKE_COVER: "Take Cover",
	UnitAction.DASH: "Dash",
	UnitAction.BRAWL: "Brawl",
	UnitAction.SNAP_FIRE: "Snap Fire",
	UnitAction.END_TURN: "End Turn"
}

const VICTORY_CONDITION_NAMES = {
	VictoryConditionType.NONE: "None",
	VictoryConditionType.ELIMINATION: "Elimination",
	VictoryConditionType.OBJECTIVE: "Objective",
	VictoryConditionType.SURVIVAL: "Survival",
	VictoryConditionType.EXTRACTION: "Extraction"
}
