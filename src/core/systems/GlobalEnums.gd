@tool
extends Node

## Edit Mode
enum EditMode {
	NONE,
	CREATE,
	EDIT,
	VIEW
}

## Phase Names and Descriptions — ordinals MUST match GameEnums.FiveParcsecsCampaignPhase
enum FiveParcsecsCampaignPhase {
	NONE,
	SETUP,
	STORY,
	TRAVEL,
	PRE_MISSION,
	MISSION,
	BATTLE_SETUP,
	BATTLE_RESOLUTION,
	POST_MISSION,
	UPKEEP,
	ADVANCEMENT,
	TRADING,
	CHARACTER,
	RETIREMENT
}

## Correctly-spelled alias — ordinals MUST match GameEnums.FiveParcsecsCampaignPhase
enum FiveParsecsCampaignPhase {
	NONE,
	SETUP,
	STORY,
	TRAVEL,
	PRE_MISSION,
	MISSION,
	BATTLE_SETUP,
	BATTLE_RESOLUTION,
	POST_MISSION,
	UPKEEP,
	ADVANCEMENT,
	TRADING,
	CHARACTER,
	RETIREMENT
}

## Alias for CrewTask (some files reference CrewTaskType)
enum CrewTaskType {
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

## Campaign Sub-Phases for more granular campaign flow management
enum CampaignSubPhase {
	NONE,
	TRAVEL,
	WORLD_ARRIVAL,
	WORLD_EVENTS,
	PATRON_CONTACT,
	MISSION_SELECTION
}

enum PostBattleSubPhase {
	NONE,
	RIVAL_STATUS,
	PATRON_STATUS,
	QUEST_PROGRESS,
	GET_PAID,
	BATTLEFIELD_FINDS,
	CHECK_INVASION,
	GATHER_LOOT,
	INJURIES,
	EXPERIENCE,
	TRAINING,
	PURCHASES,
	CAMPAIGN_EVENT,
	CHARACTER_EVENT,
	GALACTIC_WAR
}

const PHASE_NAMES = {
	FiveParcsecsCampaignPhase.NONE: "None",
	FiveParcsecsCampaignPhase.SETUP: "Setup",
	FiveParcsecsCampaignPhase.STORY: "Story",
	FiveParcsecsCampaignPhase.TRAVEL: "Travel",
	FiveParcsecsCampaignPhase.PRE_MISSION: "Pre-Mission",
	FiveParcsecsCampaignPhase.MISSION: "Mission",
	FiveParcsecsCampaignPhase.BATTLE_SETUP: "Battle Setup",
	FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Battle Resolution",
	FiveParcsecsCampaignPhase.POST_MISSION: "Post-Mission",
	FiveParcsecsCampaignPhase.UPKEEP: "Upkeep",
	FiveParcsecsCampaignPhase.ADVANCEMENT: "Advancement",
	FiveParcsecsCampaignPhase.TRADING: "Trading",
	FiveParcsecsCampaignPhase.CHARACTER: "Character",
	FiveParcsecsCampaignPhase.RETIREMENT: "Retirement"
}

const PHASE_DESCRIPTIONS = {
	FiveParcsecsCampaignPhase.NONE: "No active phase",
	FiveParcsecsCampaignPhase.SETUP: "Create your crew and prepare for adventure",
	FiveParcsecsCampaignPhase.STORY: "Progress through story events",
	FiveParcsecsCampaignPhase.TRAVEL: "Travel between worlds",
	FiveParcsecsCampaignPhase.PRE_MISSION: "Prepare for your upcoming mission",
	FiveParcsecsCampaignPhase.MISSION: "Complete your mission",
	FiveParcsecsCampaignPhase.BATTLE_SETUP: "Prepare for combat",
	FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Handle battle aftermath",
	FiveParcsecsCampaignPhase.POST_MISSION: "Handle post-mission activities",
	FiveParcsecsCampaignPhase.UPKEEP: "Maintain your crew and resources",
	FiveParcsecsCampaignPhase.ADVANCEMENT: "Improve your crew",
	FiveParcsecsCampaignPhase.TRADING: "Buy and sell equipment",
	FiveParcsecsCampaignPhase.CHARACTER: "Resolve character events",
	FiveParcsecsCampaignPhase.RETIREMENT: "Campaign phase complete"
}

## Difficulty Levels
## Core Rules pp.64-65: EASY, NORMAL, CHALLENGING, HARDCORE, INSANITY
## HARD/NIGHTMARE/ELITE are DEPRECATED — not in Core Rules or Compendium.
## Kept for save compatibility; aliased to nearest real mode in difficulty_modifiers.json.
enum DifficultyLevel {
	NONE,
	EASY,          # Core Rules p.64
	NORMAL,        # Core Rules p.65
	HARD,          # DEPRECATED — alias of NORMAL. Not a real difficulty mode
	CHALLENGING,   # Core Rules p.65
	NIGHTMARE,     # DEPRECATED — alias of INSANITY. Not a real difficulty mode
	HARDCORE,      # Core Rules p.65
	ELITE,         # DEPRECATED — alias of INSANITY. Not a real difficulty mode
	INSANITY       # Core Rules p.65
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
	BOT_TECH,
	WORKING_CLASS,
	TECHNICIAN,
	SCIENTIST,
	HACKER,
	MERCENARY,
	AGITATOR,
	PRIMITIVE,
	ARTIST,
	NEGOTIATOR,
	TRADER,
	STARSHIP_CREW,
	PETTY_CRIMINAL,
	GANGER,
	SCOUNDREL,
	ENFORCER,
	SPECIAL_AGENT,
	TROUBLESHOOTER,
	BOUNTY_HUNTER,
	NOMAD,
	EXPLORER,
	PUNK,
	SCAVENGER
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
	FORGE_WORLD,
	KRAG,           # Compendium DLC — Trailblazer's Toolkit
	SKULKER,        # Compendium DLC — Trailblazer's Toolkit
	PRISON_PLANET   # Compendium DLC — Fixer's Guidebook
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
	MERCHANT,
	PEACEFUL_HIGH_TECH_COLONY,
	GIANT_OVERCROWDED_CITY,
	LOW_TECH_COLONY,
	MINING_COLONY,
	MILITARY_BRAT,
	SPACE_STATION,
	MILITARY_OUTPOST,
	DRIFTER,
	LOWER_MEGACITY_CLASS,
	WEALTHY_MERCHANT_FAMILY,
	FRONTIER_GANG,
	RELIGIOUS_CULT,
	WAR_TORN_HELLHOLE,
	TECH_GUILD,
	SUBJUGATED_COLONY,
	LONG_TERM_SPACE_MISSION,
	RESEARCH_OUTPOST,
	PRIMITIVE_WORLD,
	ORPHAN_UTILITY_PROGRAM,
	ISOLATIONIST_ENCLAVE,
	COMFORTABLE_MEGACITY,
	INDUSTRIAL_WORLD,
	BUREAUCRAT,
	WASTELAND_NOMADS,
	ALIEN_CULTURE
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
	DUTY,
	FAME,
	ESCAPE,
	ADVENTURE,
	TRUTH,
	TECHNOLOGY,
	ROMANCE,
	FAITH,
	POLITICAL,
	ORDER
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
	QUESTS_10,
	BATTLES_20,
	BATTLES_50,
	BATTLES_100
}

## Correctly-spelled alias for FiveParcsecsCampaignVictoryType
enum FiveParsecsCampaignVictoryType {
	NONE,
	STANDARD,
	TURNS_20,
	TURNS_50,
	TURNS_100,
	CREDITS_THRESHOLD,
	CREDITS_50K,
	CREDITS_100K,
	REPUTATION_THRESHOLD,
	REPUTATION_10,
	REPUTATION_20,
	QUESTS_3,
	QUESTS_5,
	QUESTS_10,
	BATTLES_20,
	BATTLES_50,
	BATTLES_100,
	STORY_COMPLETE,
	STORY_POINTS_10,
	STORY_POINTS_20,
	WEALTH_GOAL,
	REPUTATION_GOAL,
	FACTION_DOMINANCE,
	MISSION_COUNT
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
	TUTORIAL,
	DEFENSE
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

## Enemy Categories (Core Rules p.94)
enum EnemyCategory {
	NONE,
	CRIMINAL_ELEMENTS,
	HIRED_MUSCLE,
	INTERESTED_PARTIES, # Was MILITARY_FORCES (renamed to match book)
	ROVING_THREATS # Was ALIEN_THREATS (renamed to match book)
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

## Enemy Types (Core Rules pp.94-103)
## Legacy values preserved at original positions for save compat
enum EnemyType {
	NONE, # 0
	GANGERS, # 1
	PUNKS, # 2
	RAIDERS, # 3
	PIRATES, # 4
	CULTISTS, # 5
	PSYCHOS, # 6
	WAR_BOTS, # 7
	SECURITY_BOTS, # 8
	BLACK_OPS_TEAM, # 9
	SECRET_AGENTS, # 10
	ELITE, # 11 (legacy)
	BOSS, # 12 (legacy)
	MINION, # 13 (legacy)
	ENFORCERS, # 14
	ASSASSINS, # 15
	UNITY_GRUNTS, # 16
	BLACK_DRAGON_MERCS, # 17
	# Criminal Elements (new)
	BRAT_GANG, # 18
	GENE_RENEGADES, # 19
	ANARCHISTS, # 20
	KERIN_OUTLAWS, # 21
	SKULKER_BRIGANDS, # 22
	TECH_GANGERS, # 23
	STARPORT_SCUM, # 24
	HULKER_GANG, # 25
	GUN_SLINGERS, # 26
	# Hired Muscle (new)
	UNKNOWN_MERCS, # 27
	GUILD_TROOPS, # 28
	ROID_GANGERS, # 29
	FERAL_MERCENARIES, # 30
	SKULKER_MERCENARIES, # 31
	CORPORATE_SECURITY, # 32
	RAGE_LIZARD_MERCS, # 33
	BLOOD_STORM_MERCS, # 34
	# Interested Parties (new)
	RENEGADE_SOLDIERS, # 35
	BOUNTY_HUNTERS_ENEMY, # 36
	ABANDONED, # 37
	VIGILANTES, # 38
	ISOLATIONISTS, # 39
	ZEALOTS, # 40
	MUTANTS_ENEMY, # 41
	PRIMITIVES_ENEMY, # 42
	PRECURSOR_EXILES, # 43
	KERIN_COLONISTS, # 44
	SWIFT_WAR_SQUAD, # 45
	SOULLESS_TASK_FORCE, # 46
	TECH_ZEALOTS, # 47
	COLONIAL_MILITIA, # 48
	PLANETARY_NOMADS, # 49
	SALVAGE_TEAM, # 50
	# Roving Threats (new)
	CONVERTED_ACQUISITION, # 51
	CONVERTED_INFILTRATORS, # 52
	ABDUCTOR_RAIDERS, # 53
	SWARM_BROOD, # 54
	HAYWIRE_ROBOTS, # 55
	RAZOR_LIZARDS, # 56
	SAND_RUNNERS, # 57
	VOID_RIPPERS, # 58
	KRORG, # 59
	LARGE_BUGS, # 60
	CARNIVORE_CHASERS, # 61
	VENT_CRAWLERS, # 62
	DISTORTS, # 63
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
	AGRICULTURAL_WORLD,
	FRONTIER,
	TRADE_HUB,
	INDUSTRIAL,
	RESEARCH,
	CRIMINAL,
	AFFLUENT,
	DANGEROUS,
	CORPORATE,
	MILITARY
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
	SMOKE,
	SPAWN_POINT,
	EXIT_POINT,
	OBJECTIVE,
	SPECIAL
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

## Helper: convert enum value to display string
static func to_string_value(enum_name: String, value: int) -> String:
	match enum_name:
		"character_class":
			var keys = CharacterClass.keys()
			return keys[value] if value >= 0 and value < keys.size() else "UNKNOWN"
		"background":
			var keys = Background.keys()
			return keys[value] if value >= 0 and value < keys.size() else "UNKNOWN"
		"origin":
			var keys = Origin.keys()
			return keys[value] if value >= 0 and value < keys.size() else "UNKNOWN"
		"motivation":
			var keys = Motivation.keys()
			return keys[value] if value >= 0 and value < keys.size() else "UNKNOWN"
		_:
			return "UNKNOWN"

static func get_class_display_name(char_class) -> String:
	if char_class is int:
		var keys = CharacterClass.keys()
		if char_class >= 0 and char_class < keys.size():
			return keys[char_class].capitalize().replace("_", " ")
	elif char_class is String:
		return char_class.capitalize().replace("_", " ")
	return "Unknown"

static func get_background_display_name(bg) -> String:
	if bg is int:
		var keys = Background.keys()
		if bg >= 0 and bg < keys.size():
			return keys[bg].capitalize().replace("_", " ")
	elif bg is String:
		return bg.capitalize().replace("_", " ")
	return "Unknown"

static func get_origin_display_name(origin) -> String:
	if origin is int:
		var keys = Origin.keys()
		if origin >= 0 and origin < keys.size():
			return keys[origin].capitalize().replace("_", " ")
	elif origin is String:
		return origin.capitalize().replace("_", " ")
	return "Unknown"

static func get_background_name(bg: Background) -> String:
	var keys = Background.keys()
	var idx = int(bg)
	return keys[idx] if idx >= 0 and idx < keys.size() else "Unknown"
