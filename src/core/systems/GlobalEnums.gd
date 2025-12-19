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
	POST_BATTLE, # Phase 4: Post-Battle Sequence
	COMPLETED # Campaign/phase completed state
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
	# Official Five Parsecs Rulebook Classes:
	WORKING_CLASS,     # Roll 1-5
	TECHNICIAN,        # Roll 6-9
	SCIENTIST,         # Roll 10-13
	HACKER,            # Roll 14-17
	SOLDIER,           # Roll 18-22
	MERCENARY,         # Roll 23-27
	AGITATOR,          # Roll 28-32
	PRIMITIVE,         # Roll 33-36
	ARTIST,            # Roll 37-40
	# Custom/Expansion (for variety):
	BASELINE,
	ENGINEER,
	MEDIC,
	PILOT,
	SCOUT,
	ROGUE,
	# GameStateManager modifier table classes:
	NEGOTIATOR,        # From CLASS_MODIFIERS
	SCAVENGER,         # From CLASS_MODIFIERS
	TRADER,            # From CLASS_MODIFIERS
	EXPLORER,          # From CLASS_MODIFIERS
	GANGER,            # From CLASS_MODIFIERS
	# Legacy (for backward compatibility):
	CAPTAIN,
	SPECIALIST,
	MERCHANT,
	SECURITY,
	BROKER,
	BOT_TECH,
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
	# Official Five Parsecs Rulebook Backgrounds:
	PEACEFUL_HIGH_TECH_COLONY,        # Roll 1-4
	OVERCROWDED_DYSTOPIAN_CITY,       # Roll 5-9
	LOW_TECH_COLONY,                  # Roll 10-13
	MINING_COLONY,                    # Roll 14-17
	MILITARY_BRAT,                    # Roll 18-21
	SPACE_STATION,                    # Roll 22-25
	MILITARY_OUTPOST,                 # Roll 26-29
	DRIFTER,                          # Roll 30-34
	LOWER_MEGACITY_CLASS,             # Roll 35-39
	WEALTHY_MERCHANT,                 # Roll 40-42 (Family)
	FRONTIER_GANG,                    # Roll 43-46
	RELIGIOUS_CULT,                   # Roll 47-49
	# Custom/Expansion (for variety):
	TECH_GUILD,                       # Tech specialist background
	WAR_TORN,                         # War survivor
	ORPHAN,                           # Outcast variant
	# Legacy (for backward compatibility):
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
	# Official Five Parsecs Rulebook Motivations:
	WEALTH,        # Roll 1-8
	FAME,          # Roll 9-14
	GLORY,         # Roll 15-19
	SURVIVAL,      # Roll 20-26
	ESCAPE,        # Roll 27-32
	ADVENTURE,     # Roll 33-39
	TRUTH,         # Roll 40-44
	TECHNOLOGY,    # Roll 45-49
	DISCOVERY,     # Roll 50-56
	# Custom/Expansion (for variety):
	REVENGE,
	KNOWLEDGE,
	POWER,
	JUSTICE,
	LOYALTY,
	FREEDOM,
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
	DEFENSE,
	QUEST
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
	# Official Five Parsecs Core Rules Victory Conditions
	TURNS_20, # Play 20 campaign turns
	TURNS_50, # Play 50 campaign turns
	TURNS_100, # Play 100 campaign turns
	BATTLES_20, # Fight 20 battles
	BATTLES_50, # Fight 50 battles  
	BATTLES_100, # Fight 100 battles
	QUESTS_3, # Complete 3 story quests
	QUESTS_5, # Complete 5 story quests
	QUESTS_10, # Complete 10 story quests
	STORY_POINTS_10, # Reach 10 story points
	STORY_POINTS_20, # Reach 20 story points
	CREDITS_50K, # Accumulate 50,000 credits
	CREDITS_100K, # Accumulate 100,000 credits
	REPUTATION_10, # Achieve reputation level 10
	REPUTATION_20, # Achieve reputation level 20
	CHARACTER_SURVIVAL, # Specific character survives campaign
	CREW_SIZE_10, # Reach crew size of 10 members
	STORY_COMPLETE, # Complete the story track
	# Character upgrade victory conditions
	UPGRADE_1_CHARACTER_10_TIMES, # Upgrade 1 character 10 times
	UPGRADE_3_CHARACTERS_10_TIMES, # Upgrade 3 characters 10 times each
	UPGRADE_5_CHARACTERS_10_TIMES, # Upgrade 5 characters 10 times each
	# Difficulty-based turn conditions
	TURNS_50_CHALLENGING, # 50 turns on Challenging difficulty
	TURNS_50_HARDCORE, # 50 turns on Hardcore difficulty
	TURNS_50_INSANITY # 50 turns on Insanity difficulty
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
static func get_character_class_name(class_type: int) -> String:
	@warning_ignore("untyped_declaration")
	var keys = CharacterClass.keys()
	if class_type >= 0 and class_type < keys.size():
		return keys[class_type]
	return "Unknown Class"

static func get_background_name(background_type: Background) -> String:
	@warning_ignore("untyped_declaration")
	var keys = Background.keys()
	if background_type >= 0 and background_type < keys.size():
		return keys[background_type]
	return "Unknown Background"

static func victory_condition_string_to_enum(victory_string: String) -> FiveParsecsCampaignVictoryType:
	"""Convert victory condition string to enum value"""
	match victory_string:
		"none":
			return FiveParsecsCampaignVictoryType.NONE
		"play_20_turns":
			return FiveParsecsCampaignVictoryType.TURNS_20
		"play_50_turns":
			return FiveParsecsCampaignVictoryType.TURNS_50
		"play_100_turns":
			return FiveParsecsCampaignVictoryType.TURNS_100
		"complete_3_quests":
			return FiveParsecsCampaignVictoryType.QUESTS_3
		"complete_5_quests":
			return FiveParsecsCampaignVictoryType.QUESTS_5
		"complete_10_quests":
			return FiveParsecsCampaignVictoryType.QUESTS_10
		"win_20_battles":
			return FiveParsecsCampaignVictoryType.BATTLES_20
		"win_50_battles":
			return FiveParsecsCampaignVictoryType.BATTLES_50
		_:
			return FiveParsecsCampaignVictoryType.NONE

static func get_origin_name(origin_type: Origin) -> String:
	@warning_ignore("untyped_declaration")
	var keys = Origin.keys()
	if origin_type >= 0 and origin_type < keys.size():
		return keys[origin_type]
	return "Unknown Origin"

static func get_motivation_name(motivation_type: Motivation) -> String:
	@warning_ignore("untyped_declaration")
	var keys = Motivation.keys()
	if motivation_type >= 0 and motivation_type < keys.size():
		return keys[motivation_type]
	return "Unknown Motivation"

## Enhanced Display Name Functions (UI-Friendly)
@warning_ignore("untyped_declaration")
static func get_class_display_name(class_type) -> String:
	# Handle both string and int inputs for backward compatibility
	var class_id: int
	if class_type is String:
		@warning_ignore("unsafe_call_argument")
		class_id = string_to_character_class_enum(class_type)
	elif class_type is int:
		class_id = class_type
	else:
		return "Unknown Class"
	
	match class_id:
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

## Helper function to convert string class names to enum values
static func string_to_character_class_enum(class_string: String) -> int:
	match class_string.to_upper():
		"SOLDIER": return CharacterClass.SOLDIER
		"SCOUT": return CharacterClass.SCOUT
		"MEDIC": return CharacterClass.MEDIC
		"ENGINEER": return CharacterClass.ENGINEER
		"PILOT": return CharacterClass.PILOT
		"MERCHANT": return CharacterClass.MERCHANT
		"SECURITY": return CharacterClass.SECURITY
		"BROKER": return CharacterClass.BROKER
		"BOT_TECH": return CharacterClass.BOT_TECH
		"ROGUE": return CharacterClass.ROGUE
		"PSIONICIST": return CharacterClass.PSIONICIST
		"TECH", "TECHNICIAN": return CharacterClass.TECH
		"BRUTE": return CharacterClass.BRUTE
		"GUNSLINGER": return CharacterClass.GUNSLINGER
		"ACADEMIC": return CharacterClass.ACADEMIC
		"BASELINE": return CharacterClass.BASELINE
		"SPECIALIST": return CharacterClass.SPECIALIST
		"CAPTAIN": return CharacterClass.CAPTAIN
		_: return CharacterClass.NONE

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
	@warning_ignore("untyped_declaration")
	var keys = Skill.keys()
	if skill_type >= 0 and skill_type < keys.size():
		return keys[skill_type]
	return "Unknown Skill"

static func get_ability_name(ability_type: Ability) -> String:
	@warning_ignore("untyped_declaration")
	var keys = Ability.keys()
	if ability_type >= 0 and ability_type < keys.size():
		return keys[ability_type]
	return "Unknown Ability"

static func get_trait_name(trait_type: Trait) -> String:
	@warning_ignore("untyped_declaration")
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
static func clamp_to_valid_class(class_type: int) -> int:
	if is_valid_character_class(class_type):
		return class_type
	return CharacterClass.SOLDIER # Safe default

static func clamp_to_valid_background(background_type: int) -> int:
	if is_valid_background(background_type):
		return background_type
	return Background.MILITARY # Safe default

static func clamp_to_valid_origin(origin_type: int) -> int:
	if is_valid_origin(origin_type):
		return origin_type
	return Origin.HUMAN # Safe default

static func clamp_to_valid_motivation(motivation_type: int) -> int:
	if is_valid_motivation(motivation_type):
		return motivation_type
	return Motivation.SURVIVAL # Safe default

static func clamp_to_valid_item_type(item_type: int) -> int:
	if is_valid_item_type(item_type):
		return item_type
	return ItemType.GEAR # Safe default

static func clamp_to_valid_item_rarity(rarity: int) -> int:
	if is_valid_item_rarity(rarity):
		return rarity
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
static func clamp_to_valid_market_state(state: int) -> int:
	if is_valid_market_state(state):
		return state
	return MarketState.NORMAL

static func clamp_to_valid_planet_type(planet_type: int) -> int:
	if is_valid_planet_type(planet_type):
		return planet_type
	return PlanetType.TERRESTRIAL

static func clamp_to_valid_faction_type(faction_type: int) -> int:
	if is_valid_faction_type(faction_type):
		return faction_type
	return FactionType.NEUTRAL

static func clamp_to_valid_planet_environment(environment: int) -> int:
	if is_valid_planet_environment(environment):
		return environment
	return PlanetEnvironment.HABITABLE

static func clamp_to_valid_strife_type(strife_type: int) -> int:
	if is_valid_strife_type(strife_type):
		return strife_type
	return StrifeType.PEACEFUL

static func clamp_to_valid_threat_type(threat_type: int) -> int:
	if is_valid_threat_type(threat_type):
		return threat_type
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

static func clamp_to_valid_location_type(location: int) -> int:
	if is_valid_location_type(location):
		return location
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

static func clamp_to_valid_weapon_category(category: int) -> int:
	if is_valid_weapon_category(category):
		return category
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

static func clamp_to_valid_armor_category(category: int) -> int:
	if is_valid_armor_category(category):
		return category
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

# ====================== CHARACTER PROPERTY MIGRATION SYSTEM ======================
# Production-Ready Validation Layer with Full Observability
# Handles migration from enum-based character properties to string-based properties
# Includes performance monitoring, error tracking, and automatic rollback capability

# Performance tracking with percentile metrics
@warning_ignore("untyped_declaration")
static var _conversion_metrics = {
	"conversions": 0,
	"failures": 0,
	"p50_us": 0,
	"p95_us": 0, 
	"p99_us": 0,
	"samples": [],
	"last_reset": 0
}

# Pre-computed conversion tables for O(1) performance
@warning_ignore("untyped_declaration")
static var _string_cache = {}
@warning_ignore("untyped_declaration")
static var _enum_cache = {}
@warning_ignore("untyped_declaration")
static var _validation_cache = {}

# Feature flags for gradual rollout and emergency rollback
@warning_ignore("untyped_declaration")
static var MIGRATION_FLAGS = {
	"use_string_validation": true,
	"enable_performance_monitoring": true,
	"allow_legacy_format": true,
	"log_type_conversions": false,  # Only in debug
	"auto_rollback_enabled": true,
	"error_threshold_percent": 1.0
}

# Initialize caches at startup
@warning_ignore("untyped_declaration")
static func _static_init():
	_warm_caches()
	_init_performance_monitoring()

@warning_ignore("untyped_declaration")
static func _warm_caches():
	"""Pre-compute ALL conversions at startup for O(1) performance"""
	print("[MIGRATION] Warming conversion caches...")
	
	@warning_ignore("untyped_declaration")
	var enum_types = {
		"background": Background,
		"motivation": Motivation, 
		"origin": Origin,
		"character_class": CharacterClass
	}
	
	@warning_ignore("untyped_declaration")
	for type_name in enum_types:
		_string_cache[type_name] = {}
		_enum_cache[type_name] = {}
		
		@warning_ignore("untyped_declaration")
		var enum_dict = enum_types[type_name]
		@warning_ignore("unsafe_method_access", "untyped_declaration")
		var keys = enum_dict.keys()
		
		@warning_ignore("untyped_declaration")
		for key in keys:
			@warning_ignore("untyped_declaration")
			var value = enum_dict[key]
			@warning_ignore("unsafe_method_access", "untyped_declaration")
			var key_upper = key.to_upper()
			
			# int -> string conversion
			_string_cache[type_name][value] = key_upper
			
			# string -> int conversion  
			_enum_cache[type_name][key_upper] = value
			
			# O(1) validation lookup
			_validation_cache[key_upper] = true
		
		@warning_ignore("unsafe_method_access")
		print("[MIGRATION] Cached %d conversions for %s" % [keys.size(), type_name])

@warning_ignore("untyped_declaration")
static func _init_performance_monitoring():
	"""Initialize performance monitoring system"""
	_conversion_metrics.last_reset = Time.get_ticks_msec()
	print("[MIGRATION] Performance monitoring initialized")

# CRITICAL: High-performance conversion with optimized fast paths  
static func to_string_value(enum_type: String, value: Variant) -> String:
	"""Convert any format to validated string with ultra-fast O(1) lookups"""
	if not MIGRATION_FLAGS.use_string_validation:
		return _legacy_conversion(enum_type, value)
	
	# ULTRA-FAST PATH: Direct int->string lookup (most performance critical)
	if value is int:
		@warning_ignore("untyped_declaration")
		var type_cache = _string_cache.get(enum_type)
		if type_cache:
			@warning_ignore("unsafe_method_access", "untyped_declaration")
			var cached_result = type_cache.get(value)
			if cached_result:
				_conversion_metrics.conversions += 1
				return cached_result
		# Invalid int - use fallback
		_record_failure("invalid_int", enum_type, value)
		_conversion_metrics.conversions += 1
		return _get_default(enum_type)
	
	# FAST PATH: String validation (already correct format) 
	if value is String:
		@warning_ignore("unsafe_method_access", "untyped_declaration")
		var upper = value.to_upper()
		if _validation_cache.get(upper, false):
			_conversion_metrics.conversions += 1
			return upper
		# Invalid string - use fallback  
		_record_failure("invalid_string", enum_type, value)
		_conversion_metrics.conversions += 1
		return _get_default(enum_type)
	
	# SLOW PATH: Unsupported types (rare case)
	_record_failure("unsupported_type", enum_type, value)
	_conversion_metrics.conversions += 1
	return _get_default(enum_type)

static func from_string_value(enum_type: String, string_value: String) -> int:
	"""Convert validated string back to enum value for legacy compatibility"""
	@warning_ignore("untyped_declaration")
	var upper = string_value.to_upper()
	@warning_ignore("unsafe_method_access")
	if _enum_cache.has(enum_type) and _enum_cache[enum_type].has(upper):
		return _enum_cache[enum_type][upper]
	
	push_warning("[MIGRATION] Cannot convert string to enum: %s.%s" % [enum_type, string_value])
	return 0

# PHASE 6: Safe enum conversion with comprehensive fallback handling
static func safe_enum_to_string(enum_type: String, value: Variant, fallback: String = "") -> String:
	"""Ultra-safe enum to string conversion with multiple fallback layers"""
	
	# Layer 1: Try the optimized conversion system
	@warning_ignore("untyped_declaration")
	var result = to_string_value(enum_type, value)
	if result != "UNKNOWN" and result != _get_default(enum_type):
		return result
	
	# Layer 2: Try direct enum lookup for specific types
	match enum_type:
		"background":
			if value is int and value >= 0 and value < Background.size():
				return Background.keys()[value]
		"motivation":
			if value is int and value >= 0 and value < Motivation.size():
				return Motivation.keys()[value]
		"origin":
			if value is int and value >= 0 and value < Origin.size():
				return Origin.keys()[value]
		"character_class":
			if value is int and value >= 0 and value < CharacterClass.size():
				return CharacterClass.keys()[value]
	
	# Layer 3: Use provided fallback
	if fallback != "":
		print("[MIGRATION WORKAROUND] Using provided fallback for %s: %s" % [enum_type, fallback])
		return fallback
	
	# Layer 4: Use default fallback
	@warning_ignore("untyped_declaration")
	var default = _get_default(enum_type)
	print("[MIGRATION WORKAROUND] Using default fallback for %s: %s" % [enum_type, default])
	return default

@warning_ignore("untyped_declaration")
static func _record_performance_sample(duration: int):
	"""Record performance sample and update percentiles"""
	# Keep rolling window of 1000 samples for statistical accuracy
	@warning_ignore("unsafe_method_access")
	_conversion_metrics.samples.append(duration)
	@warning_ignore("unsafe_method_access")
	if _conversion_metrics.samples.size() > 1000:
		@warning_ignore("unsafe_method_access")
		_conversion_metrics.samples.pop_front()
	
	# Calculate percentiles (requires minimum samples for accuracy)
	@warning_ignore("unsafe_method_access")
	if _conversion_metrics.samples.size() >= 100:
		@warning_ignore("unsafe_method_access", "untyped_declaration")
		var sorted = _conversion_metrics.samples.duplicate()
		@warning_ignore("unsafe_method_access")
		sorted.sort()
		@warning_ignore("unsafe_method_access", "untyped_declaration")
		var size = sorted.size()
		
		_conversion_metrics.p50_us = sorted[size * 50 / 100]
		_conversion_metrics.p95_us = sorted[size * 95 / 100] 
		_conversion_metrics.p99_us = sorted[size * 99 / 100]

@warning_ignore("untyped_declaration")
static func _record_failure(failure_type: String, enum_type: String, value: Variant):
	"""Record conversion failure for monitoring and debugging"""
	_conversion_metrics.failures += 1
	
	if OS.is_debug_build():
		push_error("[MIGRATION] %s failure: %s.%s" % [failure_type, enum_type, str(value)])
	
	# Check for auto-rollback threshold
	if MIGRATION_FLAGS.auto_rollback_enabled:
		@warning_ignore("unsafe_call_argument", "untyped_declaration")
		var error_rate = float(_conversion_metrics.failures) / max(_conversion_metrics.conversions, 1)
		if error_rate > MIGRATION_FLAGS.error_threshold_percent / 100.0:
			_trigger_emergency_rollback("Error rate %.2f%% exceeds threshold" % (error_rate * 100))

static func _get_default(enum_type: String) -> String:
	"""Get safe default value for each enum type"""
	match enum_type:
		"background":
			return "COLONIST"
		"motivation":
			return "SURVIVAL"
		"origin":
			return "HUMAN"
		"character_class":
			return "BASELINE"
		_:
			return "UNKNOWN"

static func _legacy_conversion(enum_type: String, value: Variant) -> String:
	"""Legacy conversion for emergency rollback"""
	if value is String:
		@warning_ignore("unsafe_method_access")
		return value.to_upper()
	elif value is int:
		# Simple fallback without caching
		match enum_type:
			"background":
				if value < Background.size():
					return Background.keys()[value]
			"motivation":
				if value < Motivation.size():
					return Motivation.keys()[value]
			"origin":
				if value < Origin.size():
					return Origin.keys()[value]
			"character_class":
				if value < CharacterClass.size():
					return CharacterClass.keys()[value]
	
	return _get_default(enum_type)

# Production health monitoring endpoint
static func get_migration_health() -> Dictionary:
	"""Get comprehensive migration health status for monitoring dashboard"""
	@warning_ignore("unsafe_call_argument", "untyped_declaration")
	var error_rate = float(_conversion_metrics.failures) / max(_conversion_metrics.conversions, 1)
	@warning_ignore("untyped_declaration")
	var status = "healthy"
	
	# Determine status based on error rate and performance
	if error_rate > 0.01:  # 1%
		status = "critical"
	elif error_rate > 0.001 or _conversion_metrics.p99_us > 1000:  # 0.1% or 1ms P99
		status = "degraded"
	
	return {
		"status": status,
		"conversions": _conversion_metrics.conversions,
		"failures": _conversion_metrics.failures,
		"error_rate_percent": error_rate * 100,
		"p50_microseconds": _conversion_metrics.p50_us,
		"p95_microseconds": _conversion_metrics.p95_us,
		"p99_microseconds": _conversion_metrics.p99_us,
		"alert": error_rate > 0.001,  # Alert if >0.1% errors
		"uptime_minutes": (Time.get_ticks_msec() - _conversion_metrics.last_reset) / 60000.0,
		"feature_flags": MIGRATION_FLAGS,
		"cache_size": _validation_cache.size()
	}

@warning_ignore("untyped_declaration")
static func reset_migration_metrics():
	"""Reset metrics for testing or monitoring reset"""
	_conversion_metrics = {
		"conversions": 0,
		"failures": 0,
		"p50_us": 0,
		"p95_us": 0,
		"p99_us": 0,
		"samples": [],
		"last_reset": Time.get_ticks_msec()
	}
	print("[MIGRATION] Metrics reset")

@warning_ignore("untyped_declaration")
static func _trigger_emergency_rollback(reason: String):
	"""Emergency rollback trigger with logging"""
	push_error("[MIGRATION] EMERGENCY ROLLBACK: %s" % reason)
	
	# Disable string validation immediately
	MIGRATION_FLAGS.use_string_validation = false
	MIGRATION_FLAGS.allow_legacy_format = true
	
	# Log rollback for post-incident analysis
	print("[MIGRATION] Emergency rollback triggered - system reverted to legacy mode")
	
	# Emit signal if available for UI notification
	if Engine.has_singleton("EventManager"):
		@warning_ignore("untyped_declaration")
		var event_manager = Engine.get_singleton("EventManager")
		if event_manager.has_method("emit_system_alert"):
			@warning_ignore("unsafe_method_access")
			event_manager.emit_system_alert("CHARACTER_MIGRATION_ROLLBACK", reason)

# Manual rollback for testing and emergency situations
@warning_ignore("untyped_declaration")
static func manual_rollback():
	"""Manual rollback for testing or emergency situations"""
	_trigger_emergency_rollback("Manual rollback requested")
	return true

# Feature flag management for gradual rollout
@warning_ignore("untyped_declaration")
static func enable_migration_feature(feature_name: String, enabled: bool):
	"""Enable/disable specific migration features for gradual rollout"""
	if MIGRATION_FLAGS.has(feature_name):
		MIGRATION_FLAGS[feature_name] = enabled
		print("[MIGRATION] Feature %s %s" % [feature_name, "enabled" if enabled else "disabled"])
		return true
	else:
		push_warning("[MIGRATION] Unknown feature flag: %s" % feature_name)
		return false

# Validation helpers for specific enum types
static func is_valid_background_string(background: String) -> bool:
	return _validation_cache.get(background.to_upper(), false)

static func is_valid_motivation_string(motivation: String) -> bool:
	return _validation_cache.get(motivation.to_upper(), false)

static func is_valid_origin_string(origin: String) -> bool:
	return _validation_cache.get(origin.to_upper(), false)

static func is_valid_character_class_string(character_class: String) -> bool:
	return _validation_cache.get(character_class.to_upper(), false)
