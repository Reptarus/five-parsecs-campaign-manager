extends Node

# Core Game States
enum GameState {
	SETUP,
	TUTORIAL,
	CAMPAIGN,
	BATTLE,
	GAME_OVER,
	CAMPAIGN_VICTORY
}

# UI States
enum UIState {
	MAIN_MENU,
	CHARACTER_CREATION,
	CAMPAIGN_SETUP,
	INVENTORY_MENU,
	MISSION_SELECT,
	CREW_MANAGEMENT,
	SETTINGS,
	PAUSE_MENU
}

# Campaign Flow
enum CampaignPhase {
	UPKEEP,
	WORLD_STEP,
	TRAVEL,
	PATRONS,
	BATTLE,
	POST_BATTLE,
	TRACK_RIVALS,
	PATRON_JOB,
	RIVAL_ATTACK,
	ASSIGN_EQUIPMENT,
	READY_FOR_BATTLE,
	MISSION,
	COMBAT,
	MANAGEMENT,
	EVENT,
	CREW_CREATION,
	STORY_POINT,
	MAIN_MENU
}

# Character System
enum CharacterStatus {
	HEALTHY,
	INJURED,
	CRITICAL,
	STRESSED,
	RESTING,
	TRAINING,
	DEAD,
	BAILED,
	CAPTURED
}

enum CharacterStats {
	REACTIONS,
	COMBAT_SKILL,
	TOUGHNESS,
	SAVVY,
	SPEED,
	WILL,
	LUCK,
	TECHNICAL,
	AGILITY,
	STRENGTH,
	INTELLIGENCE,
	SURVIVAL,
	STEALTH,
	PILOTING,
	LEADERSHIP,
	MEDICAL
}

# Character Origins (formerly Species)
enum Origin {
	HUMAN,
	ENGINEER,
	KERIN,
	SOULLESS,
	PRECURSOR,
	FERAL,
	SWIFT,
	BOT
}

# Remove or comment out old Species enum if it exists
# enum Species { ... }

enum Background {
	SOLDIER,
	MERCHANT,
	SCIENTIST,
	EXPLORER,
	OUTLAW,
	DIPLOMAT
}

enum Motivation {
	WEALTH,
	REVENGE,
	DISCOVERY,
	POWER,
	REDEMPTION,
	SURVIVAL
}

enum Class {
	WARRIOR,
	SCOUT,
	TECH,
	MEDIC,
	LEADER,
	SPECIALIST,
	SUPPORT,
	GUNNER
}

# Character Creation and Advancement System
enum CrewCreationCost {
	BASIC = 100,      # Basic crew member cost
	SPECIALIST = 150, # Specialist crew member cost
	VETERAN = 200,    # Veteran crew member cost
	ELITE = 300       # Elite crew member cost
}

enum CrewSizeLimit {
	MINIMUM = 3,      # Minimum crew size to start campaign
	MAXIMUM = 8,      # Maximum crew size allowed
	STARTING = 5      # Default starting crew size
}

enum CharacterRecruitmentType {
	RANDOM,           # Random character from available pool
	SPECIFIC,         # Specific character type (if available)
	STORY,            # Story-based recruitment
	QUEST_REWARD      # Character gained as quest reward
}

enum CharacterAdvancement {
	SKILL_INCREASE,   # Increase a specific skill
	NEW_ABILITY,      # Gain a new ability
	STAT_BOOST,       # Boost a core stat
	SPECIALIZATION    # Gain a specialization
}

enum CharacterExperience {
	NOVICE = 0,
	EXPERIENCED = 5,
	VETERAN = 10,
	ELITE = 15,
	LEGENDARY = 20
}

# Crew System
enum CrewRole {
	BROKER,
	SOLDIER,
	MEDIC,
	ENGINEER,
	PILOT,
	SCOUT
}

enum CrewTask {
	TRADE,
	EXPLORE,
	TRAIN,
	RECRUIT,
	FIND_PATRON,
	REPAIR_KIT,
	DECOY,
	REST
}

# Combat System
enum WeaponType {
	# Pistols
	HAND_GUN,
	HAND_LASER,
	BLAST_PISTOL,
	HOLDOUT_PISTOL,
	MACHINE_PISTOL,
	SCRAP_PISTOL,
	CLINGFIRE_PISTOL,
	
	# Rifles
	HUNTING_RIFLE,
	INFANTRY_LASER,
	MARKSMANS_RIFLE,
	MILITARY_RIFLE,
	COLONY_RIFLE,
	AUTO_RIFLE,
	FURY_RIFLE,
	
	# Heavy
	SHELL_GUN,
	PLASMA_RIFLE,
	RATTLE_GUN,
	HYPER_BLASTER,
	HAND_FLAMER,
	
	# Melee
	BLADE,
	POWER_CLAW,
	RIPPER_SWORD,
	GLARE_SWORD,
	
	# Enemy Tiers
	TIER_1,
	TIER_2,
	TIER_3,
	
	# Special
	MISSILE,
	ION,
	BEAM
}

enum CoverType {
	NONE,
	PARTIAL,
	FULL
}

enum BattlePhase {
	SETUP,
	COMBAT,
	REACTION_ROLL,
	QUICK_ACTIONS,
	ENEMY_ACTIONS,
	SLOW_ACTIONS,
	END_PHASE,
	CLEANUP
}

enum BattleOutcome {
	VICTORY,
	DEFEAT,
	RETREAT,
	DRAW
}

# Mission System
enum MissionType {
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
	ESCORT,
	STREET_FIGHT,
	INFILTRATION,
	ASSAULT,
	STORY
}

enum MissionStatus {
	ACTIVE,
	COMPLETED,
	FAILED,
	ABANDONED
}

enum MissionObjective {
	ACQUIRE,
	MOVE_THROUGH,
	DEFEND,
	ESCORT,
	SURVIVE,
	DESTROY,
	CONTROL_POINT,
	RETRIEVE,
	PROTECT,
	ELIMINATE,
	EXPLORE,
	NEGOTIATE,
	RESCUE,
	DESTROY_STRONGPOINT,
	HOLD_POSITION,
	ELIMINATE_TARGET,
	DESTROY_PLATOON,
	PENETRATE_LINES,
	SABOTAGE,
	SECURE_INTEL,
	CLEAR_ZONE
}

# AI System
enum AIBehavior {
	CAUTIOUS,
	AGGRESSIVE,
	TACTICAL,
	DEFENSIVE,
	RAMPAGE,
	BEAST,
	GUARDIAN
}

enum EnemyType {
	GRUNT,
	ELITE,
	BOSS,
	MINION,
	SUPPORT,
	HEAVY,
	SPECIALIST,
	COMMANDER,
	STANDARD,
	ROVING_THREATS,
	BLACK_ZONE_THREATS
}

enum EnemyAction {
	NONE,
	FIRE,
	MOVE,
	MOVE_AND_FIRE,
	TAKE_COVER,
	RETREAT,
	CHARGE,
	OVERWATCH,
	DEFEND,
	PROTECT
}

# Equipment and Items
enum ItemType {
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	UTILITY,
	ANALYZER,
	COLONIST_RATION_PACKS,
	DUPLICATOR,
	FAKE_ID,
	FIXER,
	GENETIC_RECONFIG_KIT,
	LOADED_DICE,
	LUCKY_DICE,
	MK2_TRANSLATOR,
	MEDITATION_ORB,
	PURIFIER,
	REPAIR_BOT,
	SECTOR_PERMIT,
	SPARE_PARTS,
	TEACH_BOT,
	TRANSCENDER
}

enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum ArmorType {
	NONE,
	LIGHT,
	MEDIUM,
	HEAVY,
	POWERED,
	STEALTH,
	HAZARD,
	BATTLE_DRESS,
	COMBAT_ARMOR,
	CAMO_CLOAK,
	SCREEN
}

# Ship Systems
enum ShipComponentType {
	HULL,
	ENGINE,
	WEAPON,
	MEDICAL_BAY,
	SHIELD,
	CARGO,
	DROP_POD,
	SHUTTLE
}

enum ShipComponentTier {
	BASIC,
	ADVANCED,
	EXPERIMENTAL,
	PROTOTYPE
}

enum ShipSystemStatus {
	OPERATIONAL,
	DAMAGED,
	DISABLED,
	DESTROYED
}

# World and Environment
enum TerrainType {
	URBAN,
	WILDERNESS,
	SPACE_STATION,
	UNDERGROUND,
	INDUSTRIAL,
	SHIP,
	CITY
}

enum TerrainFeature {
	FIELD,
	BLOCK,
	INDIVIDUAL,
	LINEAR,
	AREA,
	COVER,
	BUILDING,
	HAZARD,
	ELEVATION
}

enum DeploymentType {
	STANDARD,
	LINE,
	FLANK,
	SCATTERED,
	DEFENSIVE,
	CONCEALED,
	INFILTRATION,
	BOLSTERED_LINE,
	BOLSTERED_FLANK,
	REINFORCED
}

enum HazardType {
	RADIATION,
	TOXIC,
	FIRE,
	ELECTRICAL,
	GRAVITY,
	VACUUM
}

# Resource and Skills
enum ResourceType {
	CREDITS,
	FUEL,
	SUPPLIES,
	MATERIALS,
	INFORMATION,
	STORY_POINTS,
	LOYALTY,
	INFLUENCE,
	POWER
}

enum SkillType {
	COMBAT,
	TECHNICAL,
	SOCIAL,
	SURVIVAL,
	LEADERSHIP
}

enum PsionicAbility {
	TELEKINESIS,
	TELEPATHY,
	PYROKINESIS,
	HEALING,
	BARRIER
}

# Status and Effects
enum StatusEffectType {
	STUN,
	POISON,
	BUFF,
	DEBUFF,
	NEUTRAL,
	REGENERATION,
	SHIELD
}

# World Events and Factions
enum GlobalEvent {
	MARKET_CRASH,
	ALIEN_INVASION,
	CORPORATE_WAR,
	PIRATE_RAIDS,
	PLAGUE_OUTBREAK
}

enum FactionType {
	NEUTRAL,
	HOSTILE,
	FRIENDLY,
	CORPORATE,
	REBEL,
	GOVERNMENT,
	CRIMINAL,
	MERCENARY
}

# Game Settings and Victory Conditions
enum DifficultyMode {
	EASY,
	NORMAL,
	CHALLENGING,
	HARDCORE,
	INSANITY
}

enum VictoryConditionType {
	TURNS,
	BATTLES,
	QUESTS,
	WEALTH,
	REPUTATION,
	DOMINANCE,
	EXTRACTION,
	SURVIVAL,
	ELIMINATION,
	CAPTURE,
	DEFENSE
}

# Quest System
enum QuestType {
	MAIN,
	SIDE,
	FACTION,
	PATRON,
	EVENT,
	RIVAL,
	STORY
}

enum QuestStatus {
	INACTIVE,
	ACTIVE,
	COMPLETED,
	FAILED,
	EXPIRED
}

enum QuestRewardType {
	CREDITS,
	EXPERIENCE,
	ITEM,
	STORY_POINTS,
	LOYALTY,
	INFLUENCE,
	POWER,
	RIVAL,
	FACTION_DESTRUCTION,
	NEW_CHARACTER,
	QUEST_RUMORS,
	PATRON
}

# Elite Enemy System
enum EliteAbility {
	REGENERATION,
	TELEPORT,
	ENERGY_SHIELD,
	BERSERKER,
	CAMOUFLAGE
}

# Fringe World System
enum FringeWorldInstability {
	STABLE,
	UNREST,
	CONFLICT,
	CRISIS,
	COLLAPSE
}

# Red Zone System
enum RedZoneCondition {
	COMMS_INTERFERENCE,
	ELITE_OPPOSITION,
	PITCH_BLACK,
	HEAVY_OPPOSITION,
	ARMORED_OPPONENTS,
	ENEMY_CAPTAIN
}

enum RedZoneTimeConstraint {
	NONE,
	REINFORCEMENTS,
	SIGNIFICANT_REINFORCEMENTS,
	COUNT_DOWN,
	EVAC_NOW,
	ELITE_REINFORCEMENTS
}

# Patron and Rival System
enum PatronType {
	CORPORATION,
	LOCAL_GOVERNMENT,
	SECTOR_GOVERNMENT,
	WEALTHY_INDIVIDUAL,
	PRIVATE_ORGANIZATION,
	SECRETIVE_GROUP,
	CRIMINAL_SYNDICATE,
	REBEL_FACTION
}

enum RivalThreatLevel {
	LOW,
	MEDIUM,
	HIGH,
	DEADLY
}

enum RivalAction {
	SABOTAGE,
	AMBUSH,
	RAID,
	ASSASSINATE,
	BLACKMAIL,
	FRAME
}

# Equipment Attachments and Consumables
enum WeaponAttachment {
	NONE,
	STABILIZER,
	SHOCK_ATTACHMENT,
	UPGRADE_KIT,
	LASER_SIGHT,
	QUALITY_SIGHT,
	SEEKER_SIGHT,
	TRACKER_SIGHT,
	UNITY_BATTLE_SIGHT
}

enum ConsumableType {
	BOOSTER_PILLS,
	COMBAT_SERUM,
	KIRANIN_CRYSTALS,
	RAGE_OUT,
	STILL,
	STIM_PACK,
	MED_PATCH,
	NANO_DOC
}

enum UtilityType {
	JUMP_BELT,
	MOTION_TRACKER,
	MULTI_CUTTER,
	ROBO_RABBIT_FOOT,
	SCANNER_BOT,
	SNOOPER_BOT,
	SONIC_EMITTER,
	STEEL_BOOTS,
	TIME_DISTORTER
}

# Enemy Categories (Missing from current enums)
enum EnemyCategory {
	CRIMINAL_ELEMENTS,
	HIRED_MUSCLE,
	INTERESTED_PARTIES,
	ROVING_THREATS
}

# Enemy Weapon Groups (Missing from current enums)
enum EnemyWeaponGroup {
	GROUP_1,  # Basic weapons
	GROUP_2,  # Military grade
	GROUP_3,   # Advanced weapons
	SPECIALIST_A, # Power claw, Shotgun
	SPECIALIST_B, # Marksman's rifle, Auto rifle
	SPECIALIST_C  # Advanced weapons like Plasma rifle
}

# Enemy Ranks (Missing from current enums)
enum EnemyRank {
	REGULAR,
	SPECIALIST,
	LIEUTENANT,
	UNIQUE_INDIVIDUAL
}

# Enemy Special Rules (Missing from current enums)
enum EnemySpecialRule {
	FEARLESS,
	SAVING_THROW,
	STUBBORN,
	CARELESS,
	FEROCIOUS,
	QUICK_FEET,
	PREDICTION,
	INVASION_THREAT,
	SCAVENGER
}

# Weapon Traits (Missing from current enums)
enum WeaponTrait {
	MELEE,
	PISTOL,
	HEAVY,
	AREA,
	FOCUSED,
	CRITICAL,
	IMPACT,
	RAPID_FIRE,
	ACCURATE
}

# Enemy Combat Stats (New)
enum EnemyCombatStats {
	ATTACK_POWER,
	DEFENSE,
	MORALE,
	THREAT_LEVEL
}

# Enemy Special Flags (New)
enum EnemyFlags {
	LEG_IT,
	CARELESS,
	BAD_SHOT
}

# Add this to GlobalEnums.gd
enum AdvancedTrainingCourse {
	PILOT_TRAINING,
	COMBAT_SPECIALIST,
	TECH_EXPERT,
	SURVIVAL_EXPERT,
	LEADERSHIP,
	STEALTH_SPECIALIST,
	MEDICAL_TRAINING,
	ENGINEERING,
	HACKING,
	NEGOTIATION,
	TACTICS,
	PSIONICS
}

# Add WorldPhase enum (needs to be added)
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

# Add these enums to match world.gd requirements

enum StrifeType {
	RESOURCE_CONFLICT,
	POLITICAL_UNREST,
	CRIMINAL_WARFARE,
	CORPORATE_RIVALRY,
	ALIEN_INCURSION,
	RELIGIOUS_DISPUTE,
	TECHNOLOGICAL_CRISIS
}

enum WorldTrait {
	INDUSTRIAL_HUB,
	TRADE_CENTER,
	MILITARY_OUTPOST,
	FRONTIER_WORLD,
	CORE_WORLD,
	MINING_COLONY,
	RESEARCH_STATION,
	AGRICULTURAL_WORLD,
	PLEASURE_WORLD,
	QUARANTINED,
	RESTRICTED_ACCESS,
	BLACK_MARKET,
	HEAVY_SECURITY,
	UNSTABLE_GOVERNMENT,
	TECHNOLOGICAL_HAVEN,
	CULTURAL_CENTER
}

enum TutorialType {
	INACTIVE,
	QUICK_START,
	ADVANCED,
	BATTLE_TUTORIAL,
	CAMPAIGN_TUTORIAL,
	STORY_TUTORIAL,
	COMPLETED
}

enum TutorialStage {
	INTRODUCTION,
	CREW_MANAGEMENT,
	BASIC_COMBAT,
	MISSION_SYSTEM,
	WORLD_EXPLORATION,
	FACTION_INTERACTION,
	CAMPAIGN_FINALE
}

enum TutorialTrack {
	CORE_RULES,
	TRAILBLAZER,
	BUG_HUNT,
	FREELANCER,
	FIXER
}

# Update CampaignVictoryType enum with all conditions
enum CampaignVictoryType {
	NONE,                # No victory condition set
	
	# Wealth Based
	WEALTH_5000,        # Accumulate 5000 credits
	
	# Reputation Based
	REPUTATION_NOTORIOUS, # Become a notorious crew
	
	# Story Based
	STORY_COMPLETE,      # Complete the 7-stage narrative campaign
	
	# Combat Based
	BLACK_ZONE_MASTER,   # Complete 3 super-hard Black Zone jobs
	RED_ZONE_VETERAN,    # Complete 5 high-risk Red Zone jobs
	
	# Quest Based
	QUEST_MASTER,        # Complete 10 quests
	
	# Faction Based
	FACTION_DOMINANCE,   # Become dominant in a faction
	
	# Fleet Based
	FLEET_COMMANDER,     # Build up a significant fleet
	
	# Custom
	CUSTOM              # Custom victory condition
}

# Add custom victory metrics enum
enum CustomVictoryMetric {
	CAMPAIGN_TURNS,     # Number of campaign turns completed
	QUEST_COMPLETIONS,  # Number of quests completed
	BATTLE_VICTORIES,   # Number of battles won
	CREDITS_EARNED,     # Total credits accumulated
	CHARACTER_LEVEL,    # Reach specific character level
	REPUTATION_LEVEL,   # Reach specific reputation level
	FLEET_SIZE,        # Build fleet to specific size
	BLACK_ZONE_JOBS,   # Complete specific number of Black Zone jobs
	RED_ZONE_JOBS,     # Complete specific number of Red Zone jobs
	STORY_MISSIONS,    # Complete specific number of story missions
	RIVAL_DEFEATS,     # Defeat specific number of rivals
	FACTION_STANDING   # Reach specific standing with any faction
}

# Add victory progress tracking enum
enum VictoryProgressStatus {
	NOT_STARTED,
	IN_PROGRESS,
	COMPLETED,
	FAILED
}
