extends Node

## Global Enums for Five Parsecs Campaign Manager
## Production-Ready Enum System with Complete Type Safety
## All enums follow Five Parsecs From Home Core Rules compliance

## Edit Mode
enum EditMode {
	NONE,
	CREATE,
	EDIT,
	VIEW
}

## Official Five Parsecs Campaign Phases (Core Rulebook Compliance)
enum FiveParsecsCampaignPhase {
	NONE, # No active phase / initialization state
	SETUP, # Initial crew creation (not part of regular turn)
	TRAVEL, # Phase 1: Travel Phase
	WORLD, # Phase 2: World Phase
	BATTLE, # Phase 3: Tabletop Battle
	POST_BATTLE # Phase 4: Post-Battle Sequence
}

## Travel Phase Sub-Steps (Official Rules)
enum TravelSubPhase {
	NONE,
	FLEE_INVASION, # Step 1: Flee invasion (if applicable)
	DECIDE_TRAVEL, # Step 2: Decide whether to travel
	TRAVEL_EVENT, # Step 3: Starship travel event (if applicable)
	WORLD_ARRIVAL # Step 4: New world arrival steps (if applicable)
}

## World Phase Sub-Steps (Official Rules)
enum WorldSubPhase {
	NONE,
	UPKEEP, # Step 1: Upkeep and ship repairs
	CREW_TASKS, # Step 2: Assign and resolve crew tasks
	JOB_OFFERS, # Step 3: Determine job offers
	EQUIPMENT, # Step 4: Assign equipment
	RUMORS, # Step 5: Resolve any rumors
	BATTLE_CHOICE # Step 6: Choose your battle
}

## Post-Battle Phase Sub-Steps (Official Rules)
enum PostBattleSubPhase {
	NONE,
	RIVAL_STATUS, # Step 1: Resolve rival status
	PATRON_STATUS, # Step 2: Resolve patron status
	QUEST_PROGRESS, # Step 3: Determine quest progress
	GET_PAID, # Step 4: Get paid
	BATTLEFIELD_FINDS, # Step 5: Battlefield finds
	CHECK_INVASION, # Step 6: Check for invasion
	GATHER_LOOT, # Step 7: Gather the loot
	INJURIES, # Step 8: Determine injuries and recovery
	EXPERIENCE, # Step 9: Experience and character upgrades
	TRAINING, # Step 10: Invest in advanced training
	PURCHASES, # Step 11: Purchase items
	CAMPAIGN_EVENT, # Step 12: Roll for a campaign event
	CHARACTER_EVENT, # Step 13: Roll for a character event
	GALACTIC_WAR # Step 14: Check for galactic war progress
}

## Crew Task Types (World Phase Step 2)
enum CrewTaskType {
	NONE,
	FIND_PATRON, # Find a patron
	TRAIN, # Train (gain 1 XP)
	TRADE, # Trade (roll on trade table)
	RECRUIT, # Recruit (expand crew)
	EXPLORE, # Explore (roll on exploration table)
	TRACK, # Track (locate rivals)
	REPAIR_KIT, # Repair your kit
	DECOY # Decoy (help avoid rivals)
}

## Character Classes
## Character Background (based on Five Parsecs Core Rules)
enum CharacterBackground {
	MILITARY,
	CRIMINAL,
	ACADEMIC,
	COLONIST,
	CORPORATE,
	DRIFTER
}

## Character Motivation (Five Parsecs Core Rules compliance)
enum CharacterMotivation {
	WEALTH,
	FAME,
	REVENGE,
	REDEMPTION,
	KNOWLEDGE,
	FREEDOM
}

enum CharacterClass {
	NONE,
	BASELINE,
	CAPTAIN,
	SPECIALIST,
	SOLDIER,
	SCOUT,
	MEDIC,
	ENGINEER,
	PILOT,
	MERCHANT,
	SECURITY,
	BROKER,
	BOT_TECH,
	ROGUE,
	PSIONICIST,
	TECH,
	BRUTE,
	GUNSLINGER,
	ACADEMIC
}

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

## Character Skills System
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
	MIND_CONTROL,
	LEADERSHIP,
	TACTICS,
	PILOTING,
	ENGINEERING,
	MERCHANT_SKILLS,
	NEGOTIATION,
	INVESTIGATION,
	QUICK_REFLEXES,
	MARKSMAN,
	BRAWLING
}

## Character Abilities System
enum Ability {
	NONE,
	BATTLE_HARDENED,
	MIRACLE_WORKER,
	GHOST,
	TECH_MASTER,
	PSYCHIC_MASTER,
	NATURAL_LEADER,
	ACE_PILOT,
	MERCHANT_PRINCE,
	SECURITY_EXPERT,
	INFORMATION_BROKER,
	CRACK_SHOT,
	BERSERKER,
	VETERAN,
	ELITE_TRAINING
}

## Character Traits System
enum Trait {
	NONE,
	MILITARY_TRAINING,
	SURVIVALIST,
	SHARP_SENSES,
	MECHANICAL,
	EMOTIONLESS,
	QUICK,
	ANCIENT_KNOWLEDGE,
	TRADE_NETWORKS,
	UNDERWORLD_CONTACTS,
	RESEARCH_SKILLS,
	FRONTIER_SURVIVAL
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
	REPUTATION,
	WATER,
	FOOD,
	MINERALS,
	RARE_MATERIALS,
	LUXURY_GOODS,
	TECHNOLOGY
}

## Campaign System
enum CampaignType {
	NONE,
	STANDARD,
	FREELANCER,
	MERCENARY,
	EXPLORER,
	TRADER,
	BOUNTY_HUNTER
}

## Battle Event Categories
enum EventCategory {
	NONE,
	COMBAT,
	EQUIPMENT,
	TACTICAL,
	ENVIRONMENTAL,
	SPECIAL
}

## Battle Types
enum BattleType {
	NONE,
	STANDARD,
	RAID,
	DEFENSE,
	RESCUE,
	ESCORT,
	PATROL,
	ASSASSINATION,
	SABOTAGE,
	EXPLORATION
}

## Ship Types
enum ShipType {
	NONE,
	SCOUT,
	TRADER,
	MILITARY,
	EXPLORER,
	RAIDER,
	FREIGHTER,
	CORVETTE,
	FRIGATE,
	CRUISER
}

## Mission System
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

## Mission Objective System (Five Parsecs Core Rules)
enum MissionObjective {
	NONE,
	PATROL, # Patrol the designated area
	RESCUE, # Rescue the target
	SABOTAGE, # Sabotage the target
	ESCORT, # Escort the target to safety
	ASSASSINATION, # Eliminate the target
	DEFENSE, # Defend the position
	RAID, # Raid the location
	EXPLORE, # Explore the area
	RECOVER, # Recover the item
	INFILTRATE, # Infiltrate the facility
	EXTRACT, # Extract the target
	SECURE # Secure the location
}

## Item Types (Equipment Categories)
enum ItemType {
	NONE,
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	TOOL,
	UPGRADE,
	SPECIAL,
	MEDICAL,
	TECH,
	MISC # Miscellaneous items and general equipment
}

## Item Rarity System (Five Parsecs Core Rules)
enum ItemRarity {
	NONE,
	COMMON, # Standard equipment
	UNCOMMON, # Better quality gear
	RARE, # Hard to find items
	EPIC, # Elite-level gear
	LEGENDARY, # Unique artifacts
	EXOTIC # Alien/experimental tech
}

## Enemy Characteristics (Elite Enemy System)
enum EnemyCharacteristic {
	NONE,
	VETERAN, # +1 to all stats
	ELITE, # +2 to Combat Skill
	TOUGH, # +1 Toughness
	QUICK, # +1 Speed
	AGGRESSIVE, # +1 Combat Skill
	CAUTIOUS, # +1 Reactions
	TECH_SAVVY, # +1 Tech
	LEADER, # Nearby allies get +1 to rolls
	BERSERKER, # Ignores first wound
	SHARPSHOOTER, # +2 to ranged attacks
	HEAVY_ARMOR, # Damage -1 (minimum 1)
	REGENERATIVE, # Heals 1 wound per turn
	PSIONIC, # Has psionic abilities
	COMMANDER, # Can coordinate multiple enemies
	BOSS # Ultimate enemy variant with multiple bonuses
}

## Character Stats Enum (for referencing stat types)
enum CharacterStats {
	NONE,
	REACTIONS,
	SPEED,
	COMBAT_SKILL,
	TOUGHNESS,
	SAVVY,
	LUCK,
	TECH
}

## Legacy alias for backwards compatibility
enum CharacterStatType {
	NONE,
	REACTIONS,
	SPEED,
	COMBAT_SKILL,
	TOUGHNESS,
	SAVVY,
	LUCK,
	TECH
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

## Armor Types (Enhanced)
enum ArmorType {
	NONE,
	LIGHT,
	MEDIUM,
	HEAVY,
	POWERED,
	SHIELD,
	SPECIAL
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

## Combat System
enum CombatPhase {
	NONE,
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTION,
	REACTION,
	END
}

## Battle State System (Five Parsecs Combat)
enum BattleState {
	NONE,
	SETUP, # Initial battle setup
	ROUND, # Active combat round
	CLEANUP # Battle conclusion
}

## Battle System
enum BattlePhase {
	NONE,
	SETUP,
	DEPLOYMENT,
	INITIATIVE,
	ACTIVATION,
	REACTION,
	CLEANUP
}

## Victory Condition System (Mission Completion)
enum VictoryConditionType {
	NONE,
	ELIMINATION, # Eliminate all enemies
	EXTRACTION, # Reach extraction point
	DEFENSE, # Defend position for time limit
	ESCORT, # Escort target to safety
	RECOVERY, # Recover specific item
	INFILTRATION, # Infiltrate facility
	SABOTAGE, # Sabotage target
	ASSASSINATION, # Eliminate specific target
	PATROL, # Patrol area
	EXPLORATION, # Explore location
	TIME_LIMIT, # Complete within time
	OBJECTIVE_BASED # Complete specific objectives
}

## Game States
enum GameState {
	NONE,
	SETUP,
	CAMPAIGN,
	BATTLE,
	GAME_OVER
}

## World Traits System (Five Parsecs Core Rules)
enum WorldTrait {
	NONE,
	AFFLUENT, # +1 to trade rolls
	DANGEROUS, # +1 to enemy deployment
	INDUSTRIAL, # Better equipment availability
	PEACEFUL, # -1 to combat encounters
	PRIMITIVE, # Limited technology access
	QUARANTINED, # Special travel restrictions
	RESEARCH, # Enhanced mission rewards
	TRADE_HUB, # Better market prices
	HOSTILE, # Increased danger
	FRONTIER, # Limited services
	CORPORATE, # Controlled by mega-corps
	CRIMINAL, # High crime rates
	MILITARY, # Heavy security presence
	RUINS, # Ancient structures
	ENERGY_STORMS, # Environmental hazards
	# Additional missing traits
	TRADE_CENTER, # Major commercial hub
	INDUSTRIAL_HUB, # Manufacturing center
	FRONTIER_WORLD, # Remote settlement world
	TECH_CENTER, # Advanced technology hub
	MINING_COLONY, # Resource extraction colony
	AGRICULTURAL_WORLD, # Food production world
	PIRATE_HAVEN, # Criminal safe harbor
	CORPORATE_CONTROLLED, # Corporate-owned world
	FREE_PORT # Unregulated trade port
}

## Difficulty Levels (Campaign Scaling)
enum DifficultyLevel {
	NONE,
	STORY, # Casual play, reduced difficulty
	STANDARD, # Core rules as written
	CHALLENGING, # Increased enemy strength
	HARDCORE, # Maximum difficulty
	NIGHTMARE, # Custom ultra-hard mode
	# Legacy compatibility aliases
	EASY, # Alias for STORY mode
	NORMAL, # Alias for STANDARD mode
	HARD # Alias for CHALLENGING mode
}

## Market Economic States (Economy System)
enum MarketState {
	NONE,
	NORMAL, # Standard market conditions
	BOOM, # High demand, increased prices
	RESTRICTED, # Limited availability, regulated trade
	CRISIS # Economic collapse, scarce resources
}

## Planet Types (World Generation System) - Enhanced with TEMPERATE and ROCKY

## Faction Control Types (Political System)
enum FactionType {
	NONE,
	NEUTRAL, # No major faction control
	UNITY, # Unity government control
	CORPORATE, # Mega-corporation control
	CRIMINAL, # Criminal syndicate control
	MILITARY, # Military junta control
	RELIGIOUS, # Theocratic control
	REBEL, # Resistance movement control
	PIRATE, # Pirate confederation control
	ALIEN, # Non-human faction control
	AI, # Artificial intelligence control
	INDEPENDENT, # Free city-states
	TRADE_GUILD, # Merchant consortium control
	NOBLE_HOUSE, # Aristocratic family control
	TECHNOCRAT, # Scientific council control
	ANARCHIST # No government structure
}

## Planet Environment Types (Environmental System)
enum PlanetEnvironment {
	NONE,
	HABITABLE, # Standard breathable atmosphere
	TOXIC, # Poisonous air requiring protection
	VACUUM, # No atmosphere, space suits required
	HIGH_GRAVITY, # Movement penalties
	LOW_GRAVITY, # Movement bonuses
	EXTREME_HEAT, # Heat damage risks
	EXTREME_COLD, # Cold damage risks
	RADIATION, # Radiation exposure risks
	MAGNETIC_STORM, # Electronic interference
	CORROSIVE, # Equipment degradation
	UNSTABLE, # Seismic activity
	DENSE_FOG, # Visibility limitations
	ARTIFICIAL, # Controlled environment
	PSYCHIC_FIELD, # Psionic interference
	TEMPORAL_FLUX, # Time distortion effects
	URBAN, # City environments with cover and obstacles
	FOREST, # Dense vegetation with difficult terrain
	VOLCANIC, # Lava and ash with hazardous conditions
	OCEANIC, # Water environments with movement penalties
	TEMPERATE, # Standard environments with no modifiers
	HAZARDOUS, # Dangerous environments with multiple hazards
	RAIN # Wet conditions with visibility penalties
}

## Terrain Modifiers System (Combat)
enum TerrainModifier {
	NONE, # No terrain effects
	DIFFICULT_TERRAIN, # Movement cost doubled
	COVER_BONUS, # +1 to cover saves
	FULL_COVER, # Complete cover (75% save)
	PARTIAL_COVER, # Partial cover (50% save)
	LINE_OF_SIGHT_BLOCKED, # Blocks ranged attacks
	ELEVATION_BONUS, # Height advantage
	HAZARDOUS, # Dangerous terrain
	WATER_HAZARD, # Water-based hazards
	MOVEMENT_PENALTY # Reduced movement
}

## Terrain Feature Types System (Combat)
enum TerrainFeatureType {
	NONE, # No special features
	WALL, # Solid barrier
	COVER, # Partial cover
	OBSTACLE, # Movement blocking
	HAZARD, # Dangerous feature
	RADIATION, # Radioactive area
	FIRE, # Burning area
	ACID, # Corrosive area
	SMOKE # Obscuring area
}

## Terrain Effect Types System (Combat)
enum TerrainEffectType {
	NONE, # No effects
	COVER, # Cover protection
	ELEVATED, # Height advantage
	HAZARD, # Dangerous effects
	RADIATION, # Radiation damage
	BURNING, # Fire damage
	ACID, # Acid damage
	OBSCURED # Visibility reduction
}

## Strife and Conflict Levels (World State System)
enum StrifeType {
	NONE,
	PEACEFUL, # No significant conflicts
	TENSIONS, # Minor disagreements
	UNREST, # Civil disturbances
	CONFLICT, # Active skirmishes
	WAR, # Open warfare
	CHAOS, # Complete breakdown
	INVASION, # External force attack
	REVOLUTION, # Government overthrow
	PLAGUE, # Disease outbreak
	ECONOMIC, # Financial collapse
	NATURAL, # Environmental disaster
	ALIEN, # Extraterrestrial threat
	CORPORATE, # Mega-corp conflicts
	RELIGIOUS, # Sectarian violence
	CRIMINAL # Gang warfare
}

## Threat Types (Enemy and Danger Classification)
enum ThreatType {
	NONE,
	MINOR, # Low-level threats
	MODERATE, # Standard danger level
	MAJOR, # Significant threats
	EXTREME, # Maximum danger
	BOSS, # Boss-level threats
	ENVIRONMENTAL, # Environmental hazards
	MECHANICAL, # Automated threats
	BIOLOGICAL, # Living threats
	ENERGY, # Energy-based threats
	PSIONIC, # Psychic threats
	UNKNOWN # Unidentified threats
}


## Combat Modifiers System (Combat Effects)
enum CombatModifier {
	NONE, # No modifier
	COVER_LIGHT, # Light cover bonus
	COVER_HEAVY, # Heavy cover bonus
	HEIGHT_ADVANTAGE, # Elevated position
	FLANKING_BONUS, # Side/rear attack
	SUPPRESSION_PENALTY, # Under suppressive fire
	MOVEMENT_PENALTY, # Moving while shooting
	RANGE_PENALTY, # Long range penalty
	CLOSE_QUARTERS, # Point blank bonus
	WEAPON_FAMILIARITY, # Weapon training bonus
	TACTICAL_ADVANTAGE, # Strategic positioning
	ENVIRONMENTAL_HAZARD # Environmental penalty
}

## Psionic Powers System (Five Parsecs Core Rules)
enum PsionicPower {
	NONE,
	BARRIER, # Create protective barriers
	GRAB, # Telekinetic grab and push/pull
	LIFT, # Telekinetic movement of allies
	SHROUD, # Create fog walls
	ENRAGE, # Force movement toward enemies
	PREDICT, # Grant rerolls to allies
	SHOCK, # Stun enemies
	REJUVENATE, # Remove stun from allies
	GUIDE, # Grant free shots to allies
	PSIONIC_SCARE # Force morale checks
}

## Character Status System (Health and State)
enum CharacterStatus {
	NONE,
	HEALTHY, # Full health and functionality
	INJURED, # Minor injuries, reduced effectiveness
	SERIOUSLY_INJURED, # Major injuries, significant penalties
	CRITICALLY_INJURED, # Critical injuries, severe penalties
	INCAPACITATED, # Unable to function
	STUNNED, # Temporarily disabled
	SUPPRESSED, # Under fire, reduced effectiveness
	DEAD # Character has died
}

## Combat System Enums (Missing from current file)
enum CombatAdvantage {
	NONE,
	HEIGHT_ADVANTAGE, # Higher elevation
	FLANKING, # Attacking from side/rear
	COVER_BONUS, # Additional cover protection
	SUPPRESSION, # Target is suppressed
	STUNNED, # Target is stunned
	INSPIRED, # Character is inspired
	FOCUSED, # Character is focused
	ENRAGED # Character is enraged
}

enum CombatStatus {
	NONE,
	ACTIVE, # Ready for action
	INACTIVE, # Cannot act
	STUNNED, # Temporarily disabled
	SUPPRESSED, # Under fire
	PINNED, # Cannot move
	INSPIRED, # Enhanced performance
	FOCUSED, # Improved accuracy
	ENRAGED, # Enhanced combat
	INJURED, # Reduced effectiveness
	CRITICAL # Severely wounded
}

enum CombatRange {
	NONE,
	POINT_BLANK, # Very close range
	SHORT, # Short range
	MEDIUM, # Medium range
	LONG, # Long range
	EXTREME # Extreme range
}

enum CombatTactic {
	NONE,
	AGGRESSIVE, # Offensive approach
	DEFENSIVE, # Defensive stance
	CAUTIOUS, # Careful approach
	TACTICAL, # Strategic positioning
	SUPPRESSION, # Area denial
	FLANKING, # Side/rear attacks
	COORDINATED, # Team tactics
	INDEPENDENT # Solo operations
}

enum UnitAction {
	NONE,
	MOVE, # Movement action
	ATTACK, # Combat action
	RELOAD, # Reload weapon
	USE_ABILITY, # Special ability
	INTERACT, # Object interaction
	OVERWATCH, # Reaction shot
	SUPPRESS, # Area suppression
	HEAL, # Medical action
	HACK, # Technical action
	PICKUP, # Item pickup
	DROP, # Item drop
	SWAP, # Equipment swap
	END_TURN # End unit turn
}

## Deployment System (Missing from current file)
enum DeploymentType {
	NONE,
	STANDARD, # Normal deployment
	AMBUSH, # Hidden deployment
	DEFENSIVE, # Defensive positions
	OFFENSIVE, # Aggressive positions
	SCATTERED, # Spread out
	CONCENTRATED, # Grouped together
	SPECIALIZED, # Role-specific positions
	RANDOM # Random placement
}

## Victory Condition System (Missing from current file)
enum MissionVictoryType {
	NONE,
	ELIMINATION, # Eliminate all enemies
	EXTRACTION, # Reach extraction point
	DEFENSE, # Defend position
	ESCORT, # Escort target
	RECOVERY, # Recover item
	INFILTRATION, # Infiltrate facility
	SABOTAGE, # Sabotage target
	ASSASSINATION, # Eliminate specific target
	PATROL, # Patrol area
	EXPLORATION, # Explore location
	TIME_LIMIT, # Complete within time
	OBJECTIVE_BASED # Complete specific objectives
}

enum FiveParsecsCampaignVictoryType {
	NONE,
	TURNS_20, # Play 20 campaign turns
	TURNS_50, # Play 50 campaign turns
	TURNS_100, # Play 100 campaign turns
	QUESTS_3, # Complete 3 story quests
	QUESTS_5, # Complete 5 story quests
	QUESTS_10, # Complete 10 story quests
	STORY_COMPLETE, # Complete the main story
	WEALTH_GOAL, # Accumulate specified wealth
	REPUTATION_GOAL, # Achieve specified reputation
	FACTION_DOMINANCE, # Become the dominant faction
	CREDITS_THRESHOLD, # Reach credit threshold
	REPUTATION_THRESHOLD, # Reach reputation threshold
	MISSION_COUNT # Complete specific number of missions
}

## Planet Type System (Enhanced - Missing TEMPERATE and ROCKY)
enum PlanetType {
	NONE,
	TERRESTRIAL, # Earth-like worlds
	DESERT, # Arid, sand-covered worlds
	ICE, # Frozen, glacial planets
	JUNGLE, # Dense vegetation worlds
	TEMPERATE, # Moderate climate worlds
	ROCKY, # Rugged, mountainous worlds
	VOLCANIC, # Lava and ash-covered planets
	GAS_GIANT, # Gaseous worlds with floating stations
	ASTEROID, # Mining colonies on asteroids
	SPACE_STATION, # Artificial orbital habitats
	MOON, # Natural satellites
	OCEAN, # Water-covered worlds
	TOXIC, # Poisonous atmospheres
	CRYSTAL, # Crystalline formations
	MECHANICAL, # Ancient machine worlds
	ENERGY, # Pure energy manifestations
	VOID # Mysterious empty spaces
}

## Location Type System (Enhanced - Missing some types)
enum LocationType {
	NONE,
	SPACEPORT, # Major travel hub
	SETTLEMENT, # Small community
	INDUSTRIAL_COMPLEX, # Manufacturing facility
	RESEARCH_FACILITY, # Scientific installation
	MILITARY_OUTPOST, # Military base
	TRADING_POST, # Commercial center
	MINING_OPERATION, # Resource extraction
	AGRICULTURAL_CENTER, # Food production
	SMUGGLER_DEN, # Illegal activities
	CORPORATE_HEADQUARTERS, # Corporate center
	RUINS, # Ancient structures
	PIRATE_HAVEN, # Criminal base
	FREE_PORT, # Unregulated trade
	BLACK_MARKET, # Illegal trade
	REFUGEE_CENTER, # Displaced persons
	RELIGIOUS_COMMUNITY, # Faith-based settlement
	FRONTIER_OUTPOST, # Remote settlement
	RESEARCH_OUTPOST, # Scientific station
	MINING_WORLD, # Resource extraction world
	AGRICULTURAL_WORLD, # Food production world
	TRADE_CENTER, # Commercial hub
	CORPORATE_WORLD, # Corporate controlled
	MILITARY_BASE, # Military installation
	INDUSTRIAL_HUB, # Manufacturing center
	FRONTIER_WORLD, # Remote settlement
	PIRATE_HAVEN_WORLD, # Criminal controlled
	RESEARCH_WORLD, # Scientific focus
	HIGH_SECURITY, # Heavily defended
	CORPORATE_CONTROLLED, # Corporate authority
	DANGEROUS_WILDLIFE, # Hazardous fauna
	BLACK_MARKET_WORLD, # Illegal trade hub
	REFUGEE_CENTER_WORLD, # Displaced persons
	RELIGIOUS_WORLD, # Faith-based society
	MINING_COLONY, # Mining settlement
	TECH_CENTER # Technology hub
}

## Weapon Categories System (Equipment)
enum WeaponCategory {
	NONE,
	PISTOLS, # One-handed ranged weapons
	RIFLES, # Two-handed ranged weapons
	HEAVY_WEAPONS, # Powerful area weapons
	MELEE_WEAPONS, # Close combat weapons
	GRENADES, # Thrown explosives
	SPECIAL_WEAPONS # Unique/exotic weapons
}

## Armor Category System (Equipment)
enum ArmorCategory {
	NONE,
	LIGHT_ARMOR, # Basic protection
	MEDIUM_ARMOR, # Standard protection
	HEAVY_ARMOR, # Enhanced protection
	POWERED_ARMOR, # Advanced powered protection
	SHIELDS, # Energy shields
	SPECIALIZED_PROTECTION # Specialized protection types
}

## Helper Functions - Production Ready with Complete Type Safety

## Primary Character System Helpers
static func get_character_class_name(class_type: CharacterClass) -> String:
	var keys = CharacterClass.keys()
	if class_type >= 0 and class_type < keys.size():
		return keys[class_type]
	return "Unknown Class"

static func get_background_name(background_type: Background) -> String:
	var keys = Background.keys()
	if background_type >= 0 and background_type < keys.size():
		return keys[background_type]
	return "Unknown Background"

static func get_origin_name(origin_type: Origin) -> String:
	var keys = Origin.keys()
	if origin_type >= 0 and origin_type < keys.size():
		return keys[origin_type]
	return "Unknown Origin"

static func get_motivation_name(motivation_type: Motivation) -> String:
	var keys = Motivation.keys()
	if motivation_type >= 0 and motivation_type < keys.size():
		return keys[motivation_type]
	return "Unknown Motivation"

## Enhanced Display Name Functions (UI-Friendly)
static func get_class_display_name(class_type: CharacterClass) -> String:
	match class_type:
		CharacterClass.SOLDIER: return "Soldier"
		CharacterClass.SCOUT: return "Scout"
		CharacterClass.MEDIC: return "Medic"
		CharacterClass.ENGINEER: return "Engineer"
		CharacterClass.PILOT: return "Pilot"
		CharacterClass.MERCHANT: return "Merchant"
		CharacterClass.SECURITY: return "Security"
		CharacterClass.BROKER: return "Broker"
		CharacterClass.BOT_TECH: return "Bot Technician"
		CharacterClass.ROGUE: return "Rogue"
		CharacterClass.PSIONICIST: return "Psionicist"
		CharacterClass.TECH: return "Technician"
		CharacterClass.BRUTE: return "Brute"
		CharacterClass.GUNSLINGER: return "Gunslinger"
		CharacterClass.ACADEMIC: return "Academic"
		_: return "Unknown Class"

static func get_background_display_name(background_type: Background) -> String:
	match background_type:
		Background.MILITARY: return "Military"
		Background.MERCENARY: return "Mercenary"
		Background.CRIMINAL: return "Criminal"
		Background.COLONIST: return "Colonist"
		Background.ACADEMIC: return "Academic"
		Background.EXPLORER: return "Explorer"
		Background.TRADER: return "Trader"
		Background.NOBLE: return "Noble"
		Background.OUTCAST: return "Outcast"
		Background.SOLDIER: return "Soldier"
		Background.MERCHANT: return "Merchant"
		_: return "Unknown Background"

static func get_origin_display_name(origin_type: Origin) -> String:
	match origin_type:
		Origin.HUMAN: return "Human"
		Origin.ENGINEER: return "Engineer"
		Origin.FERAL: return "Feral"
		Origin.KERIN: return "Kerin"
		Origin.PRECURSOR: return "Precursor"
		Origin.SOULLESS: return "Soulless"
		Origin.SWIFT: return "Swift"
		Origin.BOT: return "Bot"
		Origin.CORE_WORLDS: return "Core Worlds"
		Origin.FRONTIER: return "Frontier"
		Origin.DEEP_SPACE: return "Deep Space"
		Origin.COLONY: return "Colony"
		Origin.HIVE_WORLD: return "Hive World"
		Origin.FORGE_WORLD: return "Forge World"
		_: return "Unknown Origin"

static func get_motivation_display_name(motivation_type: Motivation) -> String:
	match motivation_type:
		Motivation.WEALTH: return "Wealth"
		Motivation.REVENGE: return "Revenge"
		Motivation.GLORY: return "Glory"
		Motivation.KNOWLEDGE: return "Knowledge"
		Motivation.POWER: return "Power"
		Motivation.JUSTICE: return "Justice"
		Motivation.SURVIVAL: return "Survival"
		Motivation.LOYALTY: return "Loyalty"
		Motivation.FREEDOM: return "Freedom"
		Motivation.DISCOVERY: return "Discovery"
		Motivation.REDEMPTION: return "Redemption"
		Motivation.DUTY: return "Duty"
		_: return "Unknown Motivation"

## Secondary System Helpers
static func get_skill_name(skill_type: Skill) -> String:
	var keys = Skill.keys()
	if skill_type >= 0 and skill_type < keys.size():
		return keys[skill_type]
	return "Unknown Skill"

static func get_ability_name(ability_type: Ability) -> String:
	var keys = Ability.keys()
	if ability_type >= 0 and ability_type < keys.size():
		return keys[ability_type]
	return "Unknown Ability"

static func get_trait_name(trait_type: Trait) -> String:
	var keys = Trait.keys()
	if trait_type >= 0 and trait_type < keys.size():
		return keys[trait_type]
	return "Unknown Trait"

static func get_training_name(training_type: Training) -> String:
	match training_type:
		Training.PILOT: return "Pilot"
		Training.MECHANIC: return "Mechanic"
		Training.MEDICAL: return "Medical"
		Training.MERCHANT: return "Merchant"
		Training.SECURITY: return "Security"
		Training.BROKER: return "Broker"
		Training.BOT_TECH: return "Bot Tech"
		Training.SPECIALIST: return "Specialist"
		Training.ELITE: return "Elite"
		_: return "Unknown Training"

## Validation Helpers
static func is_valid_character_class(class_type: int) -> bool:
	return class_type > CharacterClass.NONE and class_type < CharacterClass.size()

static func is_valid_background(background_type: int) -> bool:
	return background_type > Background.NONE and background_type < Background.size()

static func is_valid_origin(origin_type: int) -> bool:
	return origin_type > Origin.NONE and origin_type < Origin.size()

static func is_valid_motivation(motivation_type: int) -> bool:
	return motivation_type > Motivation.NONE and motivation_type < Motivation.size()

## New Enum Helper Functions
static func get_item_type_name(item_type: ItemType) -> String:
	match item_type:
		ItemType.WEAPON: return "Weapon"
		ItemType.ARMOR: return "Armor"
		ItemType.GEAR: return "Gear"
		ItemType.CONSUMABLE: return "Consumable"
		ItemType.TOOL: return "Tool"
		ItemType.UPGRADE: return "Upgrade"
		ItemType.SPECIAL: return "Special"
		ItemType.MEDICAL: return "Medical"
		ItemType.TECH: return "Tech"
		_: return "Unknown Item"

static func get_item_rarity_name(rarity: ItemRarity) -> String:
	match rarity:
		ItemRarity.COMMON: return "Common"
		ItemRarity.UNCOMMON: return "Uncommon"
		ItemRarity.RARE: return "Rare"
		ItemRarity.EPIC: return "Epic"
		ItemRarity.LEGENDARY: return "Legendary"
		ItemRarity.EXOTIC: return "Exotic"
		_: return "Unknown Rarity"

static func get_enemy_characteristic_name(characteristic: EnemyCharacteristic) -> String:
	match characteristic:
		EnemyCharacteristic.VETERAN: return "Veteran"
		EnemyCharacteristic.ELITE: return "Elite"
		EnemyCharacteristic.TOUGH: return "Tough"
		EnemyCharacteristic.QUICK: return "Quick"
		EnemyCharacteristic.AGGRESSIVE: return "Aggressive"
		EnemyCharacteristic.CAUTIOUS: return "Cautious"
		EnemyCharacteristic.TECH_SAVVY: return "Tech Savvy"
		EnemyCharacteristic.LEADER: return "Leader"
		EnemyCharacteristic.BERSERKER: return "Berserker"
		EnemyCharacteristic.SHARPSHOOTER: return "Sharpshooter"
		EnemyCharacteristic.HEAVY_ARMOR: return "Heavy Armor"
		EnemyCharacteristic.REGENERATIVE: return "Regenerative"
		EnemyCharacteristic.PSIONIC: return "Psionic"
		EnemyCharacteristic.COMMANDER: return "Commander"
		_: return "Unknown Characteristic"

## Validation Functions
static func is_valid_item_type(item_type: int) -> bool:
	return item_type > ItemType.NONE and item_type < ItemType.size()

static func is_valid_item_rarity(rarity: int) -> bool:
	return rarity > ItemRarity.NONE and rarity < ItemRarity.size()

static func is_valid_enemy_characteristic(characteristic: int) -> bool:
	return characteristic > EnemyCharacteristic.NONE and characteristic < EnemyCharacteristic.size()

## Utility Functions for Array Bounds Safety
static func clamp_to_valid_class(class_type: int) -> CharacterClass:
	if is_valid_character_class(class_type):
		return class_type as CharacterClass
	return CharacterClass.SOLDIER # Safe default

static func clamp_to_valid_background(background_type: int) -> Background:
	if is_valid_background(background_type):
		return background_type as Background
	return Background.MILITARY # Safe default

static func clamp_to_valid_origin(origin_type: int) -> Origin:
	if is_valid_origin(origin_type):
		return origin_type as Origin
	return Origin.HUMAN # Safe default

static func clamp_to_valid_motivation(motivation_type: int) -> Motivation:
	if is_valid_motivation(motivation_type):
		return motivation_type as Motivation
	return Motivation.SURVIVAL # Safe default

static func clamp_to_valid_item_type(item_type: int) -> ItemType:
	if is_valid_item_type(item_type):
		return item_type as ItemType
	return ItemType.GEAR # Safe default

static func clamp_to_valid_item_rarity(rarity: int) -> ItemRarity:
	if is_valid_item_rarity(rarity):
		return rarity as ItemRarity
	return ItemRarity.COMMON # Safe default

## Phase Management Constants
const PHASE_NAMES = {
	FiveParsecsCampaignPhase.NONE: "None",
	FiveParsecsCampaignPhase.SETUP: "Crew Creation",
	FiveParsecsCampaignPhase.TRAVEL: "Travel Phase",
	FiveParsecsCampaignPhase.WORLD: "World Phase",
	FiveParsecsCampaignPhase.BATTLE: "Battle Phase",
	FiveParsecsCampaignPhase.POST_BATTLE: "Post-Battle Phase"
}

const PHASE_DESCRIPTIONS = {
	FiveParsecsCampaignPhase.NONE: "No active phase",
	FiveParsecsCampaignPhase.SETUP: "Create your crew and prepare for adventure",
	FiveParsecsCampaignPhase.TRAVEL: "Decide travel, handle events, and arrive at new worlds",
	FiveParsecsCampaignPhase.WORLD: "Handle crew tasks, jobs, equipment, and mission selection",
	FiveParsecsCampaignPhase.BATTLE: "Resolve tactical combat on the tabletop",
	FiveParsecsCampaignPhase.POST_BATTLE: "Handle battle aftermath, advancement, and events"
}

## Crew Task Names
const CREW_TASK_NAMES = {
	CrewTaskType.NONE: "None",
	CrewTaskType.FIND_PATRON: "Find Patron",
	CrewTaskType.TRAIN: "Train",
	CrewTaskType.TRADE: "Trade",
	CrewTaskType.RECRUIT: "Recruit",
	CrewTaskType.EXPLORE: "Explore",
	CrewTaskType.TRACK: "Track",
	CrewTaskType.REPAIR_KIT: "Repair Kit",
	CrewTaskType.DECOY: "Decoy"
}

## Item Type Names Lookup
const ITEM_TYPE_NAMES = {
	ItemType.NONE: "None",
	ItemType.WEAPON: "Weapon",
	ItemType.ARMOR: "Armor",
	ItemType.GEAR: "Gear",
	ItemType.CONSUMABLE: "Consumable",
	ItemType.TOOL: "Tool",
	ItemType.UPGRADE: "Upgrade",
	ItemType.SPECIAL: "Special",
	ItemType.MEDICAL: "Medical",
	ItemType.TECH: "Tech"
}

## Item Rarity Names Lookup
const ITEM_RARITY_NAMES = {
	ItemRarity.NONE: "None",
	ItemRarity.COMMON: "Common",
	ItemRarity.UNCOMMON: "Uncommon",
	ItemRarity.RARE: "Rare",
	ItemRarity.EPIC: "Epic",
	ItemRarity.LEGENDARY: "Legendary",
	ItemRarity.EXOTIC: "Exotic"
}

## Enemy Characteristic Names Lookup
const ENEMY_CHARACTERISTIC_NAMES = {
	EnemyCharacteristic.NONE: "None",
	EnemyCharacteristic.VETERAN: "Veteran",
	EnemyCharacteristic.ELITE: "Elite",
	EnemyCharacteristic.TOUGH: "Tough",
	EnemyCharacteristic.QUICK: "Quick",
	EnemyCharacteristic.AGGRESSIVE: "Aggressive",
	EnemyCharacteristic.CAUTIOUS: "Cautious",
	EnemyCharacteristic.TECH_SAVVY: "Tech Savvy",
	EnemyCharacteristic.LEADER: "Leader",
	EnemyCharacteristic.BERSERKER: "Berserker",
	EnemyCharacteristic.SHARPSHOOTER: "Sharpshooter",
	EnemyCharacteristic.HEAVY_ARMOR: "Heavy Armor",
	EnemyCharacteristic.REGENERATIVE: "Regenerative",
	EnemyCharacteristic.PSIONIC: "Psionic",
	EnemyCharacteristic.COMMANDER: "Commander"
}

## Training Names Lookup
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

## Market State Names Lookup
const MARKET_STATE_NAMES = {
	MarketState.NONE: "None",
	MarketState.NORMAL: "Normal",
	MarketState.BOOM: "Boom",
	MarketState.RESTRICTED: "Restricted",
	MarketState.CRISIS: "Crisis"
}

## Planet Type Names Lookup
const PLANET_TYPE_NAMES = {
	PlanetType.NONE: "None",
	PlanetType.TERRESTRIAL: "Terrestrial",
	PlanetType.DESERT: "Desert",
	PlanetType.ICE: "Ice World",
	PlanetType.JUNGLE: "Jungle",
	PlanetType.VOLCANIC: "Volcanic",
	PlanetType.GAS_GIANT: "Gas Giant",
	PlanetType.ASTEROID: "Asteroid",
	PlanetType.SPACE_STATION: "Space Station",
	PlanetType.MOON: "Moon",
	PlanetType.OCEAN: "Ocean World",
	PlanetType.TOXIC: "Toxic",
	PlanetType.CRYSTAL: "Crystal",
	PlanetType.MECHANICAL: "Mechanical",
	PlanetType.ENERGY: "Energy",
	PlanetType.VOID: "Void"
}

## Faction Type Names Lookup
const FACTION_TYPE_NAMES = {
	FactionType.NONE: "None",
	FactionType.NEUTRAL: "Neutral",
	FactionType.UNITY: "Unity",
	FactionType.CORPORATE: "Corporate",
	FactionType.CRIMINAL: "Criminal",
	FactionType.MILITARY: "Military",
	FactionType.RELIGIOUS: "Religious",
	FactionType.REBEL: "Rebel",
	FactionType.PIRATE: "Pirate",
	FactionType.ALIEN: "Alien",
	FactionType.AI: "AI",
	FactionType.INDEPENDENT: "Independent",
	FactionType.TRADE_GUILD: "Trade Guild",
	FactionType.NOBLE_HOUSE: "Noble House",
	FactionType.TECHNOCRAT: "Technocrat",
	FactionType.ANARCHIST: "Anarchist"
}

## Planet Environment Names Lookup
const PLANET_ENVIRONMENT_NAMES = {
	PlanetEnvironment.NONE: "None",
	PlanetEnvironment.HABITABLE: "Habitable",
	PlanetEnvironment.TOXIC: "Toxic",
	PlanetEnvironment.VACUUM: "Vacuum",
	PlanetEnvironment.HIGH_GRAVITY: "High Gravity",
	PlanetEnvironment.LOW_GRAVITY: "Low Gravity",
	PlanetEnvironment.EXTREME_HEAT: "Extreme Heat",
	PlanetEnvironment.EXTREME_COLD: "Extreme Cold",
	PlanetEnvironment.RADIATION: "Radiation",
	PlanetEnvironment.MAGNETIC_STORM: "Magnetic Storm",
	PlanetEnvironment.CORROSIVE: "Corrosive",
	PlanetEnvironment.UNSTABLE: "Unstable",
	PlanetEnvironment.DENSE_FOG: "Dense Fog",
	PlanetEnvironment.ARTIFICIAL: "Artificial",
	PlanetEnvironment.PSYCHIC_FIELD: "Psychic Field",
	PlanetEnvironment.TEMPORAL_FLUX: "Temporal Flux",
	PlanetEnvironment.URBAN: "Urban",
	PlanetEnvironment.FOREST: "Forest",
	PlanetEnvironment.VOLCANIC: "Volcanic",
	PlanetEnvironment.OCEANIC: "Oceanic",
	PlanetEnvironment.TEMPERATE: "Temperate",
	PlanetEnvironment.HAZARDOUS: "Hazardous",
	PlanetEnvironment.RAIN: "Rain"
}

## Strife Type Names Lookup
const STRIFE_TYPE_NAMES = {
	StrifeType.NONE: "None",
	StrifeType.PEACEFUL: "Peaceful",
	StrifeType.TENSIONS: "Tensions",
	StrifeType.UNREST: "Unrest",
	StrifeType.CONFLICT: "Conflict",
	StrifeType.WAR: "War",
	StrifeType.CHAOS: "Chaos",
	StrifeType.INVASION: "Invasion",
	StrifeType.REVOLUTION: "Revolution",
	StrifeType.PLAGUE: "Plague",
	StrifeType.ECONOMIC: "Economic Crisis",
	StrifeType.NATURAL: "Natural Disaster",
	StrifeType.ALIEN: "Alien Threat",
	StrifeType.CORPORATE: "Corporate War",
	StrifeType.RELIGIOUS: "Religious Conflict",
	StrifeType.CRIMINAL: "Criminal War"
}

## Threat Type Names Lookup
const THREAT_TYPE_NAMES = {
	ThreatType.NONE: "None",
	ThreatType.MINOR: "Minor Threat",
	ThreatType.MODERATE: "Moderate Threat",
	ThreatType.MAJOR: "Major Threat",
	ThreatType.EXTREME: "Extreme Threat",
	ThreatType.BOSS: "Boss Threat",
	ThreatType.ENVIRONMENTAL: "Environmental Hazard",
	ThreatType.MECHANICAL: "Mechanical Threat",
	ThreatType.BIOLOGICAL: "Biological Threat",
	ThreatType.ENERGY: "Energy Threat",
	ThreatType.PSIONIC: "Psionic Threat",
	ThreatType.UNKNOWN: "Unknown Threat"
}

## Enhanced Helper Functions for New Enums
static func get_market_state_name(market_state: MarketState) -> String:
	return MARKET_STATE_NAMES.get(market_state, "Unknown Market State")

static func get_planet_type_name(planet_type: PlanetType) -> String:
	return PLANET_TYPE_NAMES.get(planet_type, "Unknown Planet Type")

static func get_faction_type_name(faction_type: FactionType) -> String:
	return FACTION_TYPE_NAMES.get(faction_type, "Unknown Faction")

static func get_planet_environment_name(environment: PlanetEnvironment) -> String:
	return PLANET_ENVIRONMENT_NAMES.get(environment, "Unknown Environment")

static func get_strife_type_name(strife_type: StrifeType) -> String:
	return STRIFE_TYPE_NAMES.get(strife_type, "Unknown Strife")

static func get_threat_type_name(threat_type: ThreatType) -> String:
	return THREAT_TYPE_NAMES.get(threat_type, "Unknown Threat")

## Validation Functions for New Enums
static func is_valid_market_state(state: int) -> bool:
	return state >= MarketState.NONE and state < MarketState.size()

static func is_valid_planet_type(planet_type: int) -> bool:
	return planet_type >= PlanetType.NONE and planet_type < PlanetType.size()

static func is_valid_faction_type(faction_type: int) -> bool:
	return faction_type >= FactionType.NONE and faction_type < FactionType.size()

static func is_valid_planet_environment(environment: int) -> bool:
	return environment >= PlanetEnvironment.NONE and environment < PlanetEnvironment.size()

static func is_valid_strife_type(strife_type: int) -> bool:
	return strife_type >= StrifeType.NONE and strife_type < StrifeType.size()

static func is_valid_threat_type(threat_type: int) -> bool:
	return threat_type >= ThreatType.NONE and threat_type < ThreatType.size()

## Enhanced Difficulty Level Support (Legacy Compatibility)
static func get_difficulty_level_name(difficulty: DifficultyLevel) -> String:
	match difficulty:
		DifficultyLevel.STORY: return "Story Mode"
		DifficultyLevel.STANDARD: return "Standard"
		DifficultyLevel.CHALLENGING: return "Challenging"
		DifficultyLevel.HARDCORE: return "Hardcore"
		DifficultyLevel.NIGHTMARE: return "Nightmare"
		_: return "Unknown Difficulty"

## Safe Clamping Functions for New Enums
static func clamp_to_valid_market_state(state: int) -> MarketState:
	if is_valid_market_state(state):
		return state as MarketState
	return MarketState.NORMAL

static func clamp_to_valid_planet_type(planet_type: int) -> PlanetType:
	if is_valid_planet_type(planet_type):
		return planet_type as PlanetType
	return PlanetType.TERRESTRIAL

static func clamp_to_valid_faction_type(faction_type: int) -> FactionType:
	if is_valid_faction_type(faction_type):
		return faction_type as FactionType
	return FactionType.NEUTRAL

static func clamp_to_valid_planet_environment(environment: int) -> PlanetEnvironment:
	if is_valid_planet_environment(environment):
		return environment as PlanetEnvironment
	return PlanetEnvironment.HABITABLE

static func clamp_to_valid_strife_type(strife_type: int) -> StrifeType:
	if is_valid_strife_type(strife_type):
		return strife_type as StrifeType
	return StrifeType.PEACEFUL

static func clamp_to_valid_threat_type(threat_type: int) -> ThreatType:
	if is_valid_threat_type(threat_type):
		return threat_type as ThreatType
	return ThreatType.MINOR

## New Enum Helper Functions


## Psionic Power Helpers
static func get_psionic_power_name(power: PsionicPower) -> String:
	match power:
		PsionicPower.BARRIER: return "Barrier"
		PsionicPower.GRAB: return "Grab"
		PsionicPower.LIFT: return "Lift"
		PsionicPower.SHROUD: return "Shroud"
		PsionicPower.ENRAGE: return "Enrage"
		PsionicPower.PREDICT: return "Predict"
		PsionicPower.SHOCK: return "Shock"
		PsionicPower.REJUVENATE: return "Rejuvenate"
		PsionicPower.GUIDE: return "Guide"
		PsionicPower.PSIONIC_SCARE: return "Psionic Scare"
		_: return "Unknown Power"

static func is_valid_psionic_power(power: int) -> bool:
	return power >= PsionicPower.NONE and power < PsionicPower.size()

static func clamp_to_valid_psionic_power(power: int) -> int:
	if is_valid_psionic_power(power):
		return power
	return PsionicPower.NONE

## Location Type Helpers
static func get_location_type_name(location: LocationType) -> String:
	match location:
		LocationType.SPACEPORT: return "Spaceport"
		LocationType.SETTLEMENT: return "Settlement"
		LocationType.INDUSTRIAL_COMPLEX: return "Industrial Complex"
		LocationType.RESEARCH_FACILITY: return "Research Facility"
		LocationType.MILITARY_OUTPOST: return "Military Outpost"
		LocationType.TRADING_POST: return "Trading Post"
		LocationType.MINING_OPERATION: return "Mining Operation"
		LocationType.AGRICULTURAL_CENTER: return "Agricultural Center"
		LocationType.SMUGGLER_DEN: return "Smuggler Den"
		LocationType.CORPORATE_HEADQUARTERS: return "Corporate Headquarters"
		LocationType.RUINS: return "Ruins"
		LocationType.PIRATE_HAVEN: return "Pirate Haven"
		LocationType.FREE_PORT: return "Free Port"
		LocationType.BLACK_MARKET: return "Black Market"
		LocationType.REFUGEE_CENTER: return "Refugee Center"
		LocationType.RELIGIOUS_COMMUNITY: return "Religious Community"
		LocationType.FRONTIER_OUTPOST: return "Frontier Outpost"
		LocationType.RESEARCH_OUTPOST: return "Research Outpost"
		LocationType.MINING_WORLD: return "Mining World"
		LocationType.AGRICULTURAL_WORLD: return "Agricultural World"
		LocationType.TRADE_CENTER: return "Trade Center"
		LocationType.CORPORATE_WORLD: return "Corporate World"
		LocationType.MILITARY_BASE: return "Military Base"
		LocationType.INDUSTRIAL_HUB: return "Industrial Hub"
		LocationType.FRONTIER_WORLD: return "Frontier World"
		LocationType.PIRATE_HAVEN_WORLD: return "Pirate Haven"
		LocationType.RESEARCH_WORLD: return "Research World"
		LocationType.HIGH_SECURITY: return "High Security"
		LocationType.CORPORATE_CONTROLLED: return "Corporate Controlled"
		LocationType.DANGEROUS_WILDLIFE: return "Dangerous Wildlife"
		LocationType.BLACK_MARKET_WORLD: return "Black Market"
		LocationType.REFUGEE_CENTER_WORLD: return "Refugee Center"
		LocationType.RELIGIOUS_WORLD: return "Religious World"
		_: return "Unknown Location"

static func is_valid_location_type(location: int) -> bool:
	return location >= LocationType.NONE and location < LocationType.size()

static func clamp_to_valid_location_type(location: int) -> LocationType:
	if is_valid_location_type(location):
		return location as LocationType
	return LocationType.SETTLEMENT

## Weapon Category Helpers
static func get_weapon_category_name(category: WeaponCategory) -> String:
	match category:
		WeaponCategory.PISTOLS: return "Pistols"
		WeaponCategory.RIFLES: return "Rifles"
		WeaponCategory.HEAVY_WEAPONS: return "Heavy Weapons"
		WeaponCategory.MELEE_WEAPONS: return "Melee Weapons"
		WeaponCategory.GRENADES: return "Grenades"
		WeaponCategory.SPECIAL_WEAPONS: return "Special Weapons"
		_: return "Unknown Category"

static func is_valid_weapon_category(category: int) -> bool:
	return category >= WeaponCategory.NONE and category < WeaponCategory.size()

static func clamp_to_valid_weapon_category(category: int) -> WeaponCategory:
	if is_valid_weapon_category(category):
		return category as WeaponCategory
	return WeaponCategory.PISTOLS

## Armor Category Helpers
static func get_armor_category_name(category: ArmorCategory) -> String:
	match category:
		ArmorCategory.LIGHT_ARMOR: return "Light Armor"
		ArmorCategory.MEDIUM_ARMOR: return "Medium Armor"
		ArmorCategory.HEAVY_ARMOR: return "Heavy Armor"
		ArmorCategory.POWERED_ARMOR: return "Powered Armor"
		ArmorCategory.SHIELDS: return "Shields"
		ArmorCategory.SPECIALIZED_PROTECTION: return "Specialized Protection"
		_: return "Unknown Category"

static func is_valid_armor_category(category: int) -> bool:
	return category >= ArmorCategory.NONE and category < ArmorCategory.size()

static func clamp_to_valid_armor_category(category: int) -> ArmorCategory:
	if is_valid_armor_category(category):
		return category as ArmorCategory
	return ArmorCategory.LIGHT_ARMOR

## Phase Sub-Step Names (Required by CampaignPhaseManager)
const TRAVEL_SUBSTEP_NAMES = {
	TravelSubPhase.NONE: "None",
	TravelSubPhase.FLEE_INVASION: "Flee Invasion",
	TravelSubPhase.DECIDE_TRAVEL: "Decide Travel",
	TravelSubPhase.TRAVEL_EVENT: "Travel Event",
	TravelSubPhase.WORLD_ARRIVAL: "World Arrival"
}

const WORLD_SUBSTEP_NAMES = {
	WorldSubPhase.NONE: "None",
	WorldSubPhase.UPKEEP: "Upkeep & Ship Repairs",
	WorldSubPhase.CREW_TASKS: "Assign Crew Tasks",
	WorldSubPhase.JOB_OFFERS: "Determine Job Offers",
	WorldSubPhase.EQUIPMENT: "Assign Equipment",
	WorldSubPhase.RUMORS: "Resolve Rumors",
	WorldSubPhase.BATTLE_CHOICE: "Choose Your Battle"
}

const POST_BATTLE_SUBSTEP_NAMES = {
	PostBattleSubPhase.NONE: "None",
	PostBattleSubPhase.RIVAL_STATUS: "Resolve Rival Status",
	PostBattleSubPhase.PATRON_STATUS: "Resolve Patron Status",
	PostBattleSubPhase.QUEST_PROGRESS: "Determine Quest Progress",
	PostBattleSubPhase.GET_PAID: "Get Paid",
	PostBattleSubPhase.BATTLEFIELD_FINDS: "Battlefield Finds",
	PostBattleSubPhase.CHECK_INVASION: "Check for Invasion",
	PostBattleSubPhase.GATHER_LOOT: "Gather the Loot",
	PostBattleSubPhase.INJURIES: "Determine Injuries",
	PostBattleSubPhase.EXPERIENCE: "Experience & Upgrades",
	PostBattleSubPhase.TRAINING: "Advanced Training",
	PostBattleSubPhase.PURCHASES: "Purchase Items",
	PostBattleSubPhase.CAMPAIGN_EVENT: "Campaign Event",
	PostBattleSubPhase.CHARACTER_EVENT: "Character Event",
	PostBattleSubPhase.GALACTIC_WAR: "Galactic War Progress"
}
