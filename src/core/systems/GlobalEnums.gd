## Global enums for the Five Parsecs battle system
extends Node

## Character related enums
enum CharacterStatus {
	HEALTHY,
	INJURED,
	CRITICAL,
	DEAD
}

enum Origin {
	NONE,
	HUMAN,
	FERAL,
	SOULLESS,
	ALIEN,
	ROBOT,
	ENGINEER,
	KERIN,
	PRECURSOR,
	SWIFT,
	BOT
}

enum CharacterClass {
	NONE,
	SOLDIER,
	MEDIC,
	TECH,
	ENGINEER,
	SCOUT,
	LEADER,
	SPECIALIST,
	GLORY
}

## Unit actions in combat
enum UnitAction {
	NONE,
	MOVE,
	ATTACK,
	DASH,
	ITEMS,
	BRAWL,
	SNAP_FIRE,
	OVERWATCH,
	TAKE_COVER,
	RELOAD,
	INTERACT,
	PROTECT,
	DEFEND
}

## Combat phases
enum CombatPhase {
	NONE,
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTION,
	REACTION,
	MOVEMENT,
	END_TURN,
	CLEANUP
}

## Battle phases
enum BattlePhase {
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTIVATION,
	MOVEMENT,
	ACTION,
	REACTION,
	CLEANUP,
	END
}

## Combat tactics
enum CombatTactic {
	NONE,
	AGGRESSIVE,
	DEFENSIVE,
	BALANCED,
	EVASIVE,
	SUPPORTIVE
}

## Combat results
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

## Terrain modifiers
enum TerrainModifier {
	NONE,
	COVER_BONUS,
	LINE_OF_SIGHT_BLOCKED,
	DIFFICULT_TERRAIN,
	WATER_HAZARD,
	MOVEMENT_PENALTY,
	ELEVATION_BONUS,
	HAZARDOUS,
	FULL_COVER,
	PARTIAL_COVER
}

## Terrain feature types
enum TerrainFeatureType {
	NONE,
	COVER_HIGH,
	COVER_LOW,
	WALL,
	WATER,
	HAZARD,
	HIGH_GROUND,
	DIFFICULT
}

## Combat advantage states
enum CombatAdvantage {
	NONE,
	MINOR,
	MAJOR,
	OVERWHELMING
}

## Combat status effects
enum CombatStatus {
	NONE,
	STUNNED,
	WOUNDED,
	SUPPRESSED,
	FLANKED,
	PROTECTED,
	PINNED,
	SURROUNDED
}

## Mission types
enum MissionType {
	NONE,
	TUTORIAL,
	STORY,
	SIDE,
	PATROL,
	BOUNTY,
	RAID,
	DEFENSE,
	ESCORT,
	GREEN_ZONE,
	RED_ZONE,
	BLACK_ZONE,
	PATRON,
	ASSASSINATION,
	RESCUE,
	SABOTAGE
}

## Mission objectives
enum MissionObjective {
	NONE,
	PATROL,
	SEEK_AND_DESTROY,
	RESCUE,
	DEFEND,
	ESCORT,
	SABOTAGE,
	RECON,
	MOVE_THROUGH,
	WIN_BATTLE,
	ELIMINATE,
	CAPTURE_POINT,
	SURVIVE,
	PROTECT_VIP,
	RETRIEVE_ITEM,
	ESCAPE,
	HOLD_POSITION
}

## Deployment types
enum DeploymentType {
	NONE,
	STANDARD,
	LINE,
	AMBUSH,
	SCATTERED,
	DEFENSIVE,
	CONCEALED,
	INFILTRATION,
	REINFORCEMENT,
	BOLSTERED_LINE,
	OFFENSIVE
}

## Enemy types
enum EnemyType {
	NONE,
	GRUNT,
	ELITE,
	HEAVY,
	SPECIALIST,
	BOSS,
	GANGERS,
	PIRATES,
	ENFORCERS,
	RAIDERS,
	WAR_BOTS,
	BLACK_OPS_TEAM,
	ASSASSINS,
	UNITY_GRUNTS,
	BLACK_DRAGON_MERCS,
	PUNKS,
	CULTISTS,
	PSYCHOS,
	BRAT_GANG,
	GENE_RENEGADES,
	ANARCHISTS,
	K_ERIN_OUTLAWS,
	SKULKER_BRIGANDS,
	TECH_GANGERS,
	STARPORT_SCUM,
	HULKER_GANG,
	GUN_SLINGERS,
	UNKNOWN_MERCS,
	GUILD_TROOPS,
	ROID_GANGERS,
	SECRET_AGENTS,
	SECURITY_BOTS,
	RAGE_LIZARD_MERCS,
	BLOOD_STORM_MERCS,
	FERAL_MERCENARIES,
	SKULKER_MERCENARIES,
	CORPORATE_SECURITY,
	MINION
}

## Enemy behavior patterns
enum EnemyBehavior {
	AGGRESSIVE,
	CAUTIOUS,
	TACTICAL,
	DEFENSIVE,
	BEAST,
	RAMPAGE,
	GUARDIAN
}

## Campaign phases
enum CampaignPhase {
	NONE,
	SETUP,
	UPKEEP,
	STORY,
	CAMPAIGN,
	BATTLE_SETUP,
	BATTLE,
	POST_BATTLE,
	MANAGEMENT,
	TRAVEL,
	BATTLE_RESOLUTION,
	ADVANCEMENT
}

## Game states
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

## Equipment types
enum ItemType {
	NONE,
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	QUEST_ITEM,
	MODIFICATION,
	SPECIAL
}

## Battlefield types
enum BattlefieldType {
	NONE,
	URBAN,
	WILDERNESS,
	SPACE_STATION,
	STARSHIP,
	RUINS,
	INDUSTRIAL,
	OUTPOST,
	SETTLEMENT
}

## Battlefield features
enum BattlefieldFeature {
	NONE,
	COVER,
	BARRICADE,
	RUINS,
	HAZARD,
	HIGH_GROUND,
	OBSTACLE
}

## Battlefield zones
enum BattlefieldZone {
	NONE,
	DEPLOYMENT,
	OBJECTIVE,
	NEUTRAL,
	HAZARDOUS,
	RESTRICTED,
	SPECIAL
}

## Character backgrounds
enum CharacterBackground {
	NONE,
	MILITARY,
	CRIMINAL,
	ACADEMIC,
	CORPORATE,
	COLONIST,
	DRIFTER
}

## Character motivations
enum CharacterMotivation {
	NONE,
	GLORY,
	WEALTH,
	SURVIVAL,
	REVENGE,
	POWER,
	KNOWLEDGE,
	JUSTICE
}

## Battle types
enum BattleType {
	NONE,
	STANDARD,
	SKIRMISH,
	RAID,
	ASSAULT,
	DEFENSE,
	AMBUSH,
	ESCORT,
	SABOTAGE,
	RESCUE,
	INVESTIGATION
}

## Enemy weapon classes
enum EnemyWeaponClass {
	NONE,
	BASIC,
	ADVANCED,
	ELITE,
	SPECIAL,
	EXPERIMENTAL,
	LEGENDARY
}

## Campaign victory types
enum CampaignVictoryType {
	NONE,
	STANDARD,
	REPUTATION_THRESHOLD,
	CREDITS_THRESHOLD,
	MISSION_COUNT,
	STORY_COMPLETE,
	FACTION_DOMINANCE,
	WEALTH_GOAL,
	REPUTATION_GOAL,
	TURNS_20,
	TURNS_50,
	TURNS_100,
	QUESTS_3,
	QUESTS_5,
	QUESTS_10
}

## Quest types
enum QuestType {
	NONE,
	MAIN,
	SIDE,
	STORY,
	FACTION,
	PATRON,
	SPECIAL
}

## Strife levels for battle escalation
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

## Planet types
enum PlanetType {
	NONE,
	CORE_WORLD,
	COLONY,
	FRONTIER,
	MINING_WORLD,
	AGRICULTURAL,
	INDUSTRIAL,
	RESEARCH_STATION,
	FRINGE_WORLD
}

## Fringe world instability
enum FringeWorldInstability {
	NONE,
	STABLE,
	UNREST,
	CONFLICT,
	CHAOS,
	ANARCHY,
	COLLAPSE
}

## Ship component types
enum ShipComponentType {
	NONE,
	ENGINE,
	WEAPONS,
	SHIELDS,
	CARGO,
	LIFE_SUPPORT,
	NAVIGATION,
	SPECIAL
}

## Relation types
enum RelationType {
	NONE,
	FRIENDLY,
	NEUTRAL,
	HOSTILE,
	ALLIED,
	WAR,
	TRADE_PARTNER
}

## State verification types
enum StateVerificationType {
	NONE,
	STATE_CHECK,
	CONDITION_CHECK,
	REQUIREMENT_CHECK,
	RULE_CHECK,
	SYSTEM_CHECK
}

## Resource types
enum ResourceType {
	NONE,
	CREDITS,
	STORY_POINT,
	EXPERIENCE,
	REPUTATION,
	INFLUENCE,
	SUPPLIES,
	FUEL,
	AMMO,
	MEDICAL,
	PATRON,
	XP,
	STORY_POINTS,
	MEDICAL_SUPPLIES,
	WEAPONS
}

## Weapon types
enum WeaponType {
	NONE,
	BASIC,
	ADVANCED,
	ELITE,
	SPECIAL,
	RIFLE,
	PISTOL,
	MELEE,
	HEAVY
}

## Armor types
enum ArmorType {
	NONE,
	LIGHT,
	MEDIUM,
	HEAVY,
	POWERED,
	SHIELD,
	SPECIAL
}

## Item rarity
enum ItemRarity {
	NONE,
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Item quality
enum ItemQuality {
	NONE,
	POOR,
	STANDARD,
	GOOD,
	EXCELLENT,
	PRISTINE
}

## Mod slots
enum ModSlot {
	NONE,
	WEAPON,
	ARMOR,
	GEAR,
	SPECIAL
}

## Damage types
enum DamageType {
	NONE,
	KINETIC,
	ENERGY,
	EXPLOSIVE,
	FIRE,
	ACID,
	POISON,
	SPECIAL
}

## Status effect types
enum StatusEffectType {
	NONE,
	BUFF,
	DEBUFF,
	CONDITION,
	SPECIAL
}

## Skill types
enum SkillType {
	NONE,
	COMBAT,
	TECH,
	MEDICAL,
	SURVIVAL,
	SOCIAL,
	SPECIAL
}

## Experience sources
enum ExperienceSource {
	NONE,
	COMBAT,
	QUEST,
	EXPLORATION,
	CRAFTING,
	SPECIAL
}

## Difficulty levels
enum DifficultyLevel {
	NONE,
	EASY,
	NORMAL,
	HARD,
	VETERAN,
	ELITE
}

## Zone types
enum ZoneType {
	NONE,
	SAFE,
	DANGEROUS,
	RESTRICTED,
	SPECIAL
}

## Weather conditions
enum WeatherCondition {
	NONE,
	CLEAR,
	RAIN,
	STORM,
	FOG,
	SNOW,
	SANDSTORM,
	SPECIAL
}

## Time of day
enum TimeOfDay {
	NONE,
	DAWN,
	DAY,
	DUSK,
	NIGHT
}

## Visibility conditions
enum VisibilityCondition {
	NONE,
	CLEAR,
	LIMITED,
	POOR,
	ZERO
}

## Battle event types
enum BattleEventType {
	NONE,
	COMBAT,
	MOVEMENT,
	OBJECTIVE,
	REINFORCEMENT,
	ENVIRONMENT,
	INJURY,
	EQUIPMENT_LOSS,
	RESOURCE_GAIN,
	RESOURCE_LOSS,
	MORALE_BOOST,
	MORALE_DROP,
	SPECIAL
}

## Event categories
enum EventCategory {
	NONE,
	STORY,
	COMBAT,
	EXPLORATION,
	TRADE,
	SOCIAL,
	SPECIAL,
	EQUIPMENT,
	TACTICAL
}

## Strange character types
enum StrangeCharacterType {
	NONE,
	TRADER,
	MERCENARY,
	INFORMANT,
	RIVAL,
	ALLY,
	ENEMY,
	SPECIAL,
	DE_CONVERTED,
	UNITY_AGENT,
	BOT,
	ASSAULT_BOT,
	PRECURSOR,
	FERAL,
	ALIEN
}

## Battle environments
enum BattleEnvironment {
	NONE,
	URBAN,
	WILDERNESS,
	SPACE_STATION,
	SHIP_INTERIOR,
	UNDERGROUND,
	WATER,
	SPECIAL
}

## Faction types
enum FactionType {
	NONE,
	MILITARY,
	CRIMINAL,
	CORPORATE,
	REBEL,
	NEUTRAL,
	REBELS,
	EMPIRE,
	PIRATES,
	MERCHANTS,
	GUILD,
	SYNDICATE,
	CORPORATION,
	CULT,
	ENEMY,
	HOSTILE,
	FRIENDLY,
	ALLIED,
	SPECIAL
}

## Relationship status
enum RelationshipStatus {
	NONE,
	FRIENDLY,
	NEUTRAL,
	HOSTILE,
	ALLIED,
	WAR
}

## Victory condition types
enum VictoryConditionType {
	NONE,
	STANDARD,
	ELIMINATION,
	OBJECTIVE,
	SURVIVAL,
	EXTRACTION,
	CONTROL_POINTS,
	CUSTOM
}

## Rival involvement
enum RivalInvolvement {
	NONE,
	DIRECT,
	INDIRECT,
	PASSIVE,
	SPECIAL
}

## Global events
enum GlobalEvent {
	NONE,
	STORY,
	FACTION,
	WORLD,
	CREW,
	SPECIAL,
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

## Market states
enum MarketState {
	NONE,
	NORMAL,
	BOOM,
	BUST,
	CRISIS,
	RESTRICTED
}

## World traits
enum WorldTrait {
	NONE,
	PEACEFUL,
	DANGEROUS,
	WEALTHY,
	POOR,
	ADVANCED,
	PRIMITIVE,
	INDUSTRIAL_HUB,
	FRONTIER_WORLD,
	TRADE_CENTER,
	PIRATE_HAVEN,
	FREE_PORT,
	CORPORATE_CONTROLLED,
	TECH_CENTER,
	MINING_COLONY,
	AGRICULTURAL_WORLD,
	SPECIAL
}

## Planet environments
enum PlanetEnvironment {
	NONE,
	TEMPERATE,
	DESERT,
	ICE,
	JUNGLE,
	OCEAN,
	VOLCANIC,
	URBAN,
	FOREST,
	SPECIAL
}

## Weather types
enum WeatherType {
	NONE,
	CLEAR,
	RAIN,
	STORM,
	SNOW,
	SANDSTORM,
	HAZARDOUS,
	SPECIAL
}

## Enemy traits
enum EnemyTrait {
	NONE,
	AGGRESSIVE,
	CAUTIOUS,
	TACTICAL,
	DEFENSIVE,
	CARELESS,
	LEG_IT,
	BAD_SHOTS,
	FEARLESS,
	AGGRO,
	UP_CLOSE,
	ALERT,
	TOUGH_FIGHT,
	TRICK_SHOT,
	SPECIAL
}

## Mission victory types
enum MissionVictoryType {
	NONE,
	ELIMINATION,
	EXTRACTION,
	OBJECTIVE_COMPLETE,
	SURVIVAL,
	ESCAPE,
	OBJECTIVE,
	CONTROL_POINTS
}

## Quest status
enum QuestStatus {
	NONE,
	ACTIVE,
	COMPLETED,
	FAILED,
	EXPIRED
}

## Ship conditions
enum ShipCondition {
	NONE,
	PERFECT,
	GOOD,
	DAMAGED,
	CRITICAL,
	DESTROYED,
	BROKEN
}

## Enemy categories
enum EnemyCategory {
	NONE,
	INFANTRY,
	HEAVY,
	ELITE,
	BOSS,
	SPECIAL,
	CRIMINAL_ELEMENTS,
	HIRED_MUSCLE,
	MILITARY_FORCES,
	ALIEN_THREATS,
	CORPORATE_SECURITY,
	PIRATES,
	CULTISTS,
	ROBOTS
}

## Character stats
enum CharacterStats {
	NONE,
	HEALTH,
	ARMOR,
	SPEED,
	ACCURACY,
	STRENGTH,
	REACTIONS,
	COMBAT_SKILL,
	TOUGHNESS,
	SAVVY,
	LUCK,
	SPECIAL
}

## Enemy deployment patterns
enum EnemyDeploymentPattern {
	STANDARD,
	OFFENSIVE,
	DEFENSIVE,
	SCATTERED,
	AMBUSH,
	CONCEALED,
	BOLSTERED_LINE
}

## Enemy characteristics
enum EnemyCharacteristic {
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
	TRICK_SHOT
}

## Enemy rewards
enum EnemyReward {
	CREDITS,
	EQUIPMENT,
	INTEL,
	RESOURCES,
	REPUTATION,
	SPECIAL_ITEM
}

## Combat ranges
enum CombatRange {
	NONE,
	POINT_BLANK,
	SHORT,
	MEDIUM,
	LONG,
	EXTREME
}

## Combat modifiers
enum CombatModifier {
	NONE,
	COVER,
	ELEVATION,
	FLANKING,
	SUPPRESSED,
	SPECIAL,
	COVER_LIGHT,
	COVER_HEAVY
}

## AI behaviors
enum AIBehavior {
	NONE,
	TACTICAL,
	AGGRESSIVE,
	DEFENSIVE,
	CAUTIOUS,
	SUPPORTIVE
}

## Crew tasks
enum CrewTask {
	NONE,
	FIND_PATRON,
	TRAIN,
	TRADE,
	RECRUIT,
	EXPLORE,
	TRACK,
	REPAIR,
	DECOY,
	COMBAT,
	MEDICAL,
	SCOUT,
	SPECIAL
}

## Suspect types for investigations
enum SuspectType {
	CIVILIAN,
	CRIMINAL,
	GANG_MEMBER,
	ELITE
}

## Status effects
enum StatusEffect {
	NONE,
	HAZARD,
	PSIONIC_BOOST,
	DISABLED,
	ENVIRONMENTAL_PROTECTION
}

## Event types
enum EventType {
	NONE,
	UPKEEP_FAILED,
	LOCAL_EVENTS,
	NOTABLE_SIGHTS,
	JOB_OFFERS,
	BATTLE_SETUP,
	PATRON_UPDATE,
	MARKET_UPDATE,
	FACTION_UPDATE,
	POST_BATTLE_EVENTS
}

## Battle result types
enum BattleResultType {
	NONE,
	VICTORY,
	DEFEAT,
	DRAW,
	RETREAT,
	SPECIAL
}

## Management action types
enum ManagementActionType {
	NONE,
	CREW_MANAGEMENT,
	EQUIPMENT_MANAGEMENT,
	RESOURCE_ALLOCATION,
	SHIP_UPGRADES,
	STORY_PROGRESSION,
	SPECIAL
}

## Threat types
enum ThreatType {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
	CRITICAL,
	SPECIAL
}

## Verification types
enum VerificationType {
	NONE,
	COMBAT,
	POSITION,
	STATUS,
	RESOURCE,
	OVERRIDE,
	RULE,
	STATE,
	RULES,
	DEPLOYMENT,
	MOVEMENT,
	OBJECTIVES
}

## Verification scope
enum VerificationScope {
	NONE,
	SINGLE,
	UNIT,
	SQUAD,
	BATTLEFIELD,
	GAME
}

## Verification result
enum VerificationResult {
	NONE,
	SUCCESS,
	WARNING,
	ERROR,
	CRITICAL
}

## AI tactical approaches
enum AITactic {
	NONE,
	MAINTAIN_RANGE,
	SEEK_COVER,
	FLANK,
	SUPPORT,
	OVERWATCH,
	RETREAT
}

## Crew sizes
enum CrewSize {
	NONE,
	THREE,
	FOUR,
	FIVE,
	SIX
}

## Battle objectives
enum BattleObjective {
	NONE,
	CAPTURE_POINT,
	HOLD_POSITION,
	ELIMINATE_TARGET,
	SECURE_AREA,
	RETRIEVE_ITEM,
	PROTECT_ASSET,
	SABOTAGE,
	ESCAPE,
	SURVIVE
}

## Deployment zones
enum DeploymentZone {
	NONE,
	PLAYER,
	ENEMY,
	NEUTRAL,
	OBJECTIVE,
	REINFORCEMENT,
	SPECIAL
}

## Difficulty modes
enum DifficultyMode {
	NONE,
	EASY,
	NORMAL,
	HARD,
	HARDCORE,
	IRONMAN,
	CHALLENGING,
	INSANITY
}

## Job types
enum JobType {
	NONE,
	COMBAT,
	ESCORT,
	DELIVERY,
	PROTECTION,
	SABOTAGE,
	RESCUE,
	INVESTIGATION,
	SPECIAL
}

# Campaign phase descriptions and names
const PHASE_NAMES = {
	CampaignPhase.NONE: "No Phase",
	CampaignPhase.SETUP: "Setup Phase",
	CampaignPhase.UPKEEP: "Upkeep Phase",
	CampaignPhase.STORY: "Story Phase",
	CampaignPhase.CAMPAIGN: "Campaign Phase",
	CampaignPhase.BATTLE_SETUP: "Battle Setup",
	CampaignPhase.BATTLE: "Battle Phase",
	CampaignPhase.POST_BATTLE: "Post-Battle Phase",
	CampaignPhase.MANAGEMENT: "Management Phase",
	CampaignPhase.TRAVEL: "Travel Phase",
	CampaignPhase.BATTLE_RESOLUTION: "Battle Resolution",
	CampaignPhase.ADVANCEMENT: "Advancement Phase"
}

const PHASE_DESCRIPTIONS = {
	CampaignPhase.NONE: "No active phase",
	CampaignPhase.SETUP: "Create your crew and prepare for the campaign",
	CampaignPhase.UPKEEP: "Pay maintenance costs and manage resources",
	CampaignPhase.STORY: "Progress through story events and quests",
	CampaignPhase.CAMPAIGN: "Manage your campaign activities",
	CampaignPhase.BATTLE_SETUP: "Prepare for upcoming battle",
	CampaignPhase.BATTLE: "Engage in tactical combat",
	CampaignPhase.POST_BATTLE: "Handle post-battle consequences",
	CampaignPhase.MANAGEMENT: "Manage crew and resources",
	CampaignPhase.TRAVEL: "Travel to new locations",
	CampaignPhase.BATTLE_RESOLUTION: "Resolve battle outcomes",
	CampaignPhase.ADVANCEMENT: "Advance characters and equipment"
}
