@tool
extends RefCounted
class_name GameEnums

## Enumeration for difficulty levels in the game
enum DifficultyLevel {
	EASY, # Easy difficulty - more forgiving gameplay
	NORMAL, # Normal difficulty - balanced gameplay
	HARD, # Hard difficulty - challenging gameplay
	NIGHTMARE, # Nightmare difficulty - extremely challenging gameplay
	HARDCORE, # Hardcore difficulty - permadeath
	ELITE # Elite difficulty - maximum challenge
}

## Edit Mode
enum EditMode {
	NONE, # No edit mode
	CREATE, # Creating new item
	EDIT, # Editing existing item
	VIEW # Viewing item details
}

## Enumeration for game phases
enum GamePhase {
	SETUP, # Initial game setup
	CAMPAIGN, # Main campaign phase
	MISSION, # Active mission
	UPKEEP, # Between-mission maintenance
	END_GAME # Game over or campaign conclusion
}

## Enumeration for Five Parsecs campaign phases
enum FiveParcsecsCampaignPhase {
	NONE, # No active campaign phase
	SETUP, # Campaign setup
	STORY, # Story events phase
	TRAVEL, # Travel between locations
	PRE_MISSION, # Pre-mission preparations
	MISSION, # Active mission
	BATTLE_SETUP, # Battle preparation
	BATTLE_RESOLUTION, # Battle aftermath
	POST_MISSION, # Post-mission resolution
	UPKEEP, # Campaign maintenance
	ADVANCEMENT, # Character advancement
	TRADING, # Trading and resource management
	CHARACTER, # Character development and management
	RETIREMENT # Campaign retirement/end
}

## Campaign Sub-Phases for more granular campaign flow management
enum CampaignSubPhase {
	NONE, # No sub-phase
	TRAVEL, # Traveling between locations
	WORLD_ARRIVAL, # Arriving at a new world
	WORLD_EVENTS, # World-specific events
	PATRON_CONTACT, # Contacting patrons
	MISSION_SELECTION # Selecting missions
}

## Enumeration for game states (previously GameState)
enum GameState {
	NONE, # No state
	SETUP, # Initial setup
	CAMPAIGN, # Campaign mode
	BATTLE, # Battle mode
	GAME_OVER # Game over state
}

## Enumeration for character status effects
enum StatusEffect {
	NONE, # No status effect
	WOUNDED, # Character is wounded
	STUNNED, # Character is stunned
	POISONED, # Character is poisoned
	BLESSED, # Character has positive effect
	CURSED # Character has negative effect
}

## Enumeration for mission types
enum MissionType {
	NONE, # No mission type
	BATTLE, # Standard battle mission
	RETRIEVAL, # Item retrieval mission
	ESCORT, # Escort mission
	DEFENSE, # Defend location mission
	SABOTAGE, # Sabotage mission
	PATROL, # Patrol mission
	RESCUE, # Rescue mission
	PATRON, # Patron mission
	BLACK_ZONE, # Black zone mission (high danger)
	GREEN_ZONE, # Green zone mission (low danger)
	RED_ZONE, # Red zone mission (medium danger)
	ASSASSINATION, # Assassination mission
	RAID # Raid mission
}

## Enumeration for mission objectives
enum MissionObjective {
	NONE, # No objective
	WIN_BATTLE, # Win the battle
	PATROL, # Patrol an area
	RESCUE, # Rescue someone
	SABOTAGE, # Sabotage an object
	RECON, # Gather information
	CAPTURE_POINT, # Capture a location
	DEFEND, # Defend a location
	SEEK_AND_DESTROY, # Find and eliminate target
	TUTORIAL # Tutorial objective
}

## Enumeration for UI screen types
enum ScreenType {
	MAIN_MENU, # Main menu screen
	CAMPAIGN_HUB, # Campaign management hub
	CHARACTER, # Character management
	EQUIPMENT, # Equipment management
	MISSION, # Mission screen
	SETTINGS # Game settings
}

## Enumeration for resource types
enum ResourceType {
	NONE, # No resource
	CREDITS, # In-game currency
	SUPPLIES, # Basic supplies
	TECH_PARTS, # Technology parts
	SCRAP, # Crafting materials
	MEDICINE, # Medical supplies
	MEDICAL_SUPPLIES, # Medical kits and gear
	FUEL, # Ship fuel
	DATA, # Information/intelligence
	PATRON, # Patron contacts
	STORY_POINT, # Story progression points
	REPUTATION # Reputation with factions
}

## Enumeration for weapon types
enum WeaponType {
	NONE, # No weapon type
	BASIC, # Basic weapon
	ADVANCED, # Advanced weapon
	ELITE, # Elite weapon
	PISTOL, # Pistol weapon
	RIFLE, # Rifle weapon
	HEAVY, # Heavy weapon
	MELEE, # Melee weapon
	SPECIAL # Special weapon
}

## Enumeration for armor types
enum ArmorType {
	NONE, # No armor type
	LIGHT, # Light armor
	MEDIUM, # Medium armor
	HEAVY, # Heavy armor
	POWERED, # Powered armor
	HAZARD, # Hazard protection armor
	STEALTH # Stealth-enhancing armor
}

## Character Status
enum CharacterStatus {
	HEALTHY, # Character is in good health
	INJURED, # Character is injured
	CRITICAL, # Character is critically injured
	INCAPACITATED, # Character is incapacitated
	DEAD, # Character is dead
	CAPTURED, # Character has been captured
	MISSING # Character is missing
}

## Item Types
enum ItemType {
	NONE, # No item type
	WEAPON, # Weapon item
	ARMOR, # Armor item
	MISC, # Miscellaneous item
	CONSUMABLE, # Consumable item
	QUEST, # Quest item
	GEAR, # Gear item
	MODIFICATION, # Modification item
	SPECIAL # Special item
}

## Character Classes
enum CharacterClass {
	NONE, # No character class
	SOLDIER, # Soldier class
	MEDIC, # Medic class
	ENGINEER, # Engineer class
	PILOT, # Pilot class
	MERCHANT, # Merchant class
	SECURITY, # Security class
	BROKER, # Broker class
	BOT_TECH # Bot Tech class
}

## Character Origins
enum Origin {
	NONE, # No specific origin
	HUMAN, # Human origin
	ENGINEER, # Engineer origin
	FERAL, # Feral origin
	KERIN, # Kerin origin
	PRECURSOR, # Precursor origin
	SOULLESS, # Soulless origin
	SWIFT, # Swift origin
	BOT, # Bot origin
	CORE_WORLDS, # Core Worlds origin
	FRONTIER, # Frontier origin
	DEEP_SPACE, # Deep Space origin
	COLONY, # Colony origin
	HIVE_WORLD, # Hive World origin
	FORGE_WORLD # Forge World origin
}

## Character Background
enum Background {
	NONE, # No background
	MILITARY, # Military background
	MERCENARY, # Mercenary background
	CRIMINAL, # Criminal background
	COLONIST, # Colonist background
	ACADEMIC, # Academic background
	EXPLORER, # Explorer background
	TRADER, # Trader background
	NOBLE, # Noble background
	OUTCAST, # Outcast background
	SOLDIER, # Soldier background
	MERCHANT # Merchant background
}

## Character Motivation
enum Motivation {
	NONE, # No motivation
	WEALTH, # Wealth as motivation
	REVENGE, # Revenge as motivation
	GLORY, # Glory as motivation
	KNOWLEDGE, # Knowledge as motivation
	POWER, # Power as motivation
	JUSTICE, # Justice as motivation
	SURVIVAL, # Survival as motivation
	LOYALTY, # Loyalty as motivation
	FREEDOM, # Freedom as motivation
	DISCOVERY, # Discovery as motivation
	REDEMPTION, # Redemption as motivation
	DUTY # Duty as motivation
}

## Training Levels
enum Training {
	NONE, # No training
	PILOT, # Pilot training
	MECHANIC, # Mechanic training
	MEDICAL, # Medical training
	MERCHANT, # Merchant training
	SECURITY, # Security training
	BROKER, # Broker training
	BOT_TECH, # Bot Tech training
	SPECIALIST, # Specialist training
	ELITE # Elite training
}

## World/Location Traits
enum WorldTrait {
	NONE, # No special traits
	TRADE_CENTER, # Centers of commerce
	TECH_CENTER, # Centers of technology
	INDUSTRIAL_HUB, # Manufacturing hubs
	PIRATE_HAVEN, # Lawless territories
	FRONTIER_WORLD, # Remote worlds
	FREE_PORT, # Unrestricted trading
	CORPORATE_CONTROLLED, # Corporate governance
	MINING_COLONY, # Resource extraction
	AGRICULTURAL_WORLD # Food production
}

## Item Rarities
enum ItemRarity {
	NONE, # No rarity
	COMMON, # Common item
	UNCOMMON, # Uncommon item
	RARE, # Rare item
	EPIC, # Epic item
	LEGENDARY # Legendary item
}

## Equipment Types
enum EquipmentType {
	NONE, # No equipment
	WEAPON, # Weapon equipment
	ARMOR, # Armor equipment
	GEAR, # Gear item
	UTILITY, # Utility item
	MEDICAL, # Medical equipment
	COMPUTING, # Computing equipment
	VEHICLE, # Vehicle equipment
	HEAVY, # Heavy equipment
	SPECIAL # Special equipment
}

## Campaign Types
enum FiveParcsecsCampaignType {
	NONE, # No campaign type
	STANDARD, # Standard campaign
	CUSTOM, # Custom campaign
	TUTORIAL, # Tutorial campaign
	STORY, # Story-driven campaign
	SANDBOX # Open sandbox campaign
}

## Campaign Victory Types
enum FiveParcsecsCampaignVictoryType {
	NONE, # No victory condition
	STANDARD, # Standard victory
	WEALTH_GOAL, # Accumulate wealth
	REPUTATION_GOAL, # Build reputation
	FACTION_DOMINANCE, # Dominate factions
	STORY_COMPLETE, # Complete story
	CREDITS_THRESHOLD, # Reach credits target
	REPUTATION_THRESHOLD, # Reach reputation target
	MISSION_COUNT, # Complete specific missions
	TURNS_20, # Survive 20 turns
	TURNS_50, # Survive 50 turns
	TURNS_100, # Survive 100 turns
	QUESTS_3, # Complete 3 quests
	QUESTS_5, # Complete 5 quests
	QUESTS_10 # Complete 10 quests
}

## Market States
enum MarketState {
	NONE, # No specific state
	NORMAL, # Normal market conditions
	CRISIS, # Economic crisis
	BOOM, # Economic boom
	RESTRICTED # Trade restrictions
}

## Weather Types
enum WeatherType {
	NONE, # Clear weather
	CLEAR, # Clear skies
	RAIN, # Rainy condition
	STORM, # Stormy weather
	FOG, # Foggy condition
	HAZARDOUS # Hazardous weather
}

## AI Behavior
enum AIBehavior {
	NONE, # Default behavior
	AGGRESSIVE, # Aggressive tactics
	DEFENSIVE, # Defensive tactics
	TACTICAL, # Tactical approach
	CAUTIOUS, # Cautious behavior
	SUPPORTIVE # Support-focused
}

## Planet Types
enum PlanetType {
	NONE, # Unknown type
	DESERT, # Desert planet
	ICE, # Ice planet
	JUNGLE, # Jungle planet
	OCEAN, # Ocean planet
	ROCKY, # Rocky planet
	TEMPERATE, # Temperate planet
	VOLCANIC # Volcanic planet
}

## Planet Environments
enum PlanetEnvironment {
	NONE, # No specific environment
	URBAN, # Urban environment
	FOREST, # Forest environment
	DESERT, # Desert environment
	ICE, # Ice environment
	RAIN, # Rainy environment
	STORM, # Stormy environment
	HAZARDOUS, # Hazardous environment
	VOLCANIC, # Volcanic environment
	OCEANIC, # Ocean environment
	TEMPERATE, # Temperate environment
	JUNGLE # Jungle environment
}

## Threat Types
enum ThreatType {
	NONE, # No threat
	LOW, # Low threat
	MEDIUM, # Medium threat
	HIGH, # High threat
	EXTREME, # Extreme threat
	BOSS # Boss-level threat
}

## Strife Types (levels of conflict)
enum StrifeType {
	NONE, # No conflict
	PEACEFUL, # Peaceful conditions
	UNREST, # Social unrest
	CIVIL_WAR, # Civil conflict
	INVASION, # External invasion
	LOW, # Low conflict level
	MEDIUM, # Medium conflict level
	HIGH, # High conflict level
	CRITICAL # Critical conflict level
}

## Relation Types
enum RelationType {
	NONE, # No relation
	FRIENDLY, # Friendly relation
	NEUTRAL, # Neutral relation
	HOSTILE, # Hostile relation
	ALLIED, # Allied relation
	ENEMY # Enemy relation
}

## Ship Conditions
enum ShipCondition {
	NONE, # Unknown condition
	PRISTINE, # Perfect condition
	GOOD, # Good condition
	DAMAGED, # Damaged condition
	CRITICAL, # Critical condition
	DESTROYED # Destroyed
}

## Victory Condition Types
enum VictoryConditionType {
	NONE, # No condition
	ELIMINATION, # Eliminate enemies
	OBJECTIVE, # Complete objectives
	SURVIVAL, # Survive
	EXTRACTION # Extract assets
}

## Enemy Ranks
enum EnemyRank {
	NONE, # No rank
	MINION, # Minion rank
	ELITE, # Elite rank
	BOSS # Boss rank
}

## Enemy Traits
enum EnemyTrait {
	NONE, # No trait
	SCAVENGER, # Collects resources
	TOUGH_FIGHT, # Harder to defeat
	ALERT, # Easily detects players
	FEROCIOUS, # Aggressive attacks
	LEG_IT, # Quick to flee
	FRIDAY_NIGHT_WARRIORS, # Weekend fighters
	AGGRO, # Very aggressive
	UP_CLOSE, # Prefers close combat
	FEARLESS, # Never retreats
	GRUESOME, # Causes fear
	SAVING_THROW, # Chance to survive
	TRICK_SHOT, # Special attacks
	CARELESS, # Makes mistakes
	BAD_SHOTS # Poor accuracy
}

## Location Types
enum LocationType {
	NONE, # No specific type
	INDUSTRIAL_HUB, # Manufacturing center
	FRONTIER_WORLD, # Undeveloped world
	TRADE_CENTER, # Commerce hub
	PIRATE_HAVEN, # Outlaw territory
	FREE_PORT, # Unrestricted trade
	CORPORATE_CONTROLLED, # Corporate ownership
	TECH_CENTER, # Advanced technology
	MINING_COLONY, # Resource extraction
	AGRICULTURAL_WORLD # Food production
}

## Battle Types
enum BattleType {
	NONE, # No battle type
	STANDARD, # Standard combat
	BOSS, # Boss encounter
	STORY, # Story battle
	EVENT # Event battle
}

## Battle Phases
enum BattlePhase {
	NONE, # No phase
	SETUP, # Setup phase
	DEPLOYMENT, # Deployment phase
	INITIATIVE, # Initiative phase
	ACTIVATION, # Unit activation
	REACTION, # Reaction phase
	CLEANUP # Cleanup phase
}

## Campaign Phases
enum CampaignPhase {
	NONE, # No active phase
	SETUP, # Initial setup
	UPKEEP, # Resource maintenance
	STORY, # Story progression
	CAMPAIGN, # Main campaign
	BATTLE_SETUP, # Pre-battle
	BATTLE_RESOLUTION, # Post-battle
	ADVANCEMENT, # Character growth
	TRADE, # Trading phase
	END # Campaign conclusion
}

## Combat Modifiers
enum CombatModifier {
	NONE, # No modifier
	COVER_LIGHT, # Light cover
	COVER_MEDIUM, # Medium cover
	COVER_HEAVY, # Heavy cover
	FLANKING, # Flanking position
	ELEVATION, # Height advantage
	SUPPRESSED, # Under suppression
	PINNED, # Pinned down
	STEALTH, # Stealth advantage
	OVERWATCH # Overwatch position
}

## Terrain Modifiers
enum TerrainModifier {
	NONE, # No modifier
	COVER_BONUS, # Cover advantage
	FULL_COVER, # Complete cover
	PARTIAL_COVER, # Partial cover
	LINE_OF_SIGHT_BLOCKED, # Blocked vision
	DIFFICULT_TERRAIN, # Movement hindrance
	ELEVATION_BONUS, # Height advantage
	HAZARDOUS, # Dangerous terrain
	WATER_HAZARD, # Water hazard
	MOVEMENT_PENALTY # Slowed movement
}

## Crew Size
enum CrewSize {
	NONE, # Unspecified
	TWO, # Two members
	THREE, # Three members
	FOUR, # Four members
	FIVE, # Five members
	SIX # Six members
}

## Character Skills
enum Skill {
	NONE, # No skill
	COMBAT, # Combat proficiency
	TECHNICAL, # Technical expertise
	SCIENCE, # Scientific knowledge
	SOCIAL, # Social interactions
	SURVIVAL, # Survival skills
	PILOTING, # Piloting ability
	MEDICAL, # Medical knowledge
	LEADERSHIP # Leadership ability
}

## Character Abilities
enum Ability {
	NONE, # No ability
	QUICK_SHOT, # Faster shooting
	STEADY_AIM, # Better accuracy
	BATTLE_HARDENED, # Improved combat resilience
	TECH_SAVVY, # Technology bonus
	MEDIC, # Medical expertise
	LEADER # Leadership bonus
}

## Character Traits
enum Trait {
	NONE, # No trait
	BRAVE, # Courage in the face of danger
	CAUTIOUS, # Extra careful approach
	RECKLESS, # Risk-taking behavior
	RESOURCEFUL, # Finding creative solutions
	HOTHEADED, # Quick to anger
	CALCULATING # Strategic thinking
}

## Faction Types
enum FactionType {
	NONE, # No faction
	NEUTRAL, # Neutral faction
	IMPERIAL, # Imperial/government faction
	REBEL, # Rebel/resistance faction
	PIRATE, # Pirate/outlaw faction
	CORPORATE, # Corporate/business faction
	MERCENARY, # Mercenary/hired guns faction
	ALIEN # Alien/non-human faction
}

## Terrain Feature Types
enum TerrainFeatureType {
	NONE, # No terrain feature
	FOREST, # Forest terrain
	MOUNTAIN, # Mountain terrain
	WATER, # Water terrain
	STRUCTURE, # Structure/building
	DEBRIS, # Debris/wreckage
	ROADS, # Roads/paths
	URBAN, # Urban terrain
	RIDGE, # Ridges/hills
	CRATER, # Craters/depressions
	WALL, # Walls/barriers
	COVER, # Cover objects
	OBSTACLE, # Movement obstacles
	HAZARD, # General hazards
	RADIATION, # Radiation areas
	FIRE, # Fire areas
	ACID, # Acid pools
	SMOKE # Smoke clouds
}

## Terrain Effect Types
enum TerrainEffectType {
	NONE, # No effect
	HAZARD, # General hazard
	ELEVATED, # Elevation advantage
	COVER, # Provides cover
	RADIATION, # Radiation damage
	BURNING, # Fire damage
	ACID, # Acid damage
	OBSCURED # Visibility reduction
}

## Unit Actions
enum UnitAction {
	NONE, # No action
	MOVE, # Move action
	ATTACK, # Attack action
	DEFEND, # Defend action
	USE_ITEM, # Use item action
	SPECIAL, # Special action
	WAIT, # Wait/pass action
	OVERWATCH # Overwatch action
}

## Constants for phase names
const PHASE_NAMES = {
	FiveParcsecsCampaignPhase.NONE: "None",
	FiveParcsecsCampaignPhase.SETUP: "Setup",
	FiveParcsecsCampaignPhase.UPKEEP: "Upkeep",
	FiveParcsecsCampaignPhase.STORY: "Story",
	FiveParcsecsCampaignPhase.TRAVEL: "Travel",
	FiveParcsecsCampaignPhase.PRE_MISSION: "Pre-Mission",
	FiveParcsecsCampaignPhase.MISSION: "Mission",
	FiveParcsecsCampaignPhase.BATTLE_SETUP: "Battle Setup",
	FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Battle Resolution",
	FiveParcsecsCampaignPhase.POST_MISSION: "Post-Mission",
	FiveParcsecsCampaignPhase.ADVANCEMENT: "Advancement",
	FiveParcsecsCampaignPhase.TRADING: "Trading",
	FiveParcsecsCampaignPhase.CHARACTER: "Character",
	FiveParcsecsCampaignPhase.RETIREMENT: "Retirement"
}

## Constants for phase descriptions
const PHASE_DESCRIPTIONS = {
	FiveParcsecsCampaignPhase.NONE: "No active phase",
	FiveParcsecsCampaignPhase.SETUP: "Create your crew and prepare for adventure",
	FiveParcsecsCampaignPhase.UPKEEP: "Maintain your crew and resources",
	FiveParcsecsCampaignPhase.STORY: "Progress through story events",
	FiveParcsecsCampaignPhase.TRAVEL: "Travel to new locations",
	FiveParcsecsCampaignPhase.PRE_MISSION: "Prepare for your next mission",
	FiveParcsecsCampaignPhase.MISSION: "Complete mission objectives",
	FiveParcsecsCampaignPhase.BATTLE_SETUP: "Prepare for combat",
	FiveParcsecsCampaignPhase.BATTLE_RESOLUTION: "Handle battle aftermath",
	FiveParcsecsCampaignPhase.POST_MISSION: "Resolve mission outcomes",
	FiveParcsecsCampaignPhase.ADVANCEMENT: "Improve your crew",
	FiveParcsecsCampaignPhase.TRADING: "Buy and sell equipment",
	FiveParcsecsCampaignPhase.CHARACTER: "Develop your characters",
	FiveParcsecsCampaignPhase.RETIREMENT: "End your campaign"
}

## Constants for training names
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

## Utility function to get string representation of an enum value
static func get_enum_string(enum_type: Dictionary, value: int) -> String:
	for key in enum_type:
		if enum_type[key] == value:
			return key
	return "UNKNOWN"

## Get the size of a specific enum
static func size(enum_type: Dictionary) -> int:
	return enum_type.size()

## Convert a string to an equipment type enum value
static func get_equipment_type_from_string(equipment_string: String) -> int:
	equipment_string = equipment_string.to_upper()
	if equipment_string in EquipmentType:
		return EquipmentType[equipment_string]
	
	# Check for common variations
	var mapping = {
		"WEAPONS": EquipmentType.WEAPON,
		"ARMORS": EquipmentType.ARMOR,
		"GEARS": EquipmentType.GEAR,
		"UTILITIES": EquipmentType.UTILITY,
		"MEDICAL_KIT": EquipmentType.MEDICAL,
		"COMPUTER": EquipmentType.COMPUTING,
		"VEHICLES": EquipmentType.VEHICLE,
		"HEAVY_EQUIPMENT": EquipmentType.HEAVY
	}
	
	if equipment_string in mapping:
		return mapping[equipment_string]
		
	return EquipmentType.NONE

## Get training name from enum value
static func get_training_name(training: int) -> String:
	return TRAINING_NAMES.get(training, "Unknown Training")

## Get character class name from enum value
static func get_character_class_name(class_type: int) -> String:
	if class_type >= 0 and class_type < CharacterClass.size():
		return CharacterClass.keys()[class_type]
	return "UNKNOWN"

## Get skill name from enum value
static func get_skill_name(skill_type: int) -> String:
	if skill_type >= 0 and skill_type < Skill.size():
		return Skill.keys()[skill_type]
	return "UNKNOWN"

## Get ability name from enum value
static func get_ability_name(ability_type: int) -> String:
	if ability_type >= 0 and ability_type < Ability.size():
		return Ability.keys()[ability_type]
	return "UNKNOWN"

## Get trait name from enum value
static func get_trait_name(trait_type: int) -> String:
	if trait_type >= 0 and trait_type < Trait.size():
		return Trait.keys()[trait_type]
	return "UNKNOWN"

## Armor Classes
enum ArmorClass {
	NONE, # No armor class
	LIGHT, # Light armor class
	MEDIUM, # Medium armor class
	HEAVY # Heavy armor class
}

## Enemy Categories
enum EnemyCategory {
	NONE, # No category
	CRIMINAL_ELEMENTS, # Criminal gangs and outlaws
	HIRED_MUSCLE, # Mercenaries and hired forces
	MILITARY_FORCES, # Organized military units
	ALIEN_THREATS # Non-human hostile forces
}

## Enemy Behaviors
enum EnemyBehavior {
	NONE, # Default behavior
	AGGRESSIVE, # Attack-focused
	DEFENSIVE, # Defense-focused
	TACTICAL, # Strategic approach
	BEAST, # Wild, unpredictable
	RAMPAGE, # Destructive, reckless
	GUARDIAN, # Protective, territorial
	CAUTIOUS # Risk-averse
}

## Global Events
enum GlobalEvent {
	NONE, # No event
	MARKET_CRASH, # Economic downturn
	ALIEN_INVASION, # Large-scale alien attack
	TECH_BREAKTHROUGH, # Technological innovation
	CIVIL_UNREST, # Social upheaval
	RESOURCE_BOOM, # Resource discovery
	PIRATE_RAID, # Pirate attack
	TRADE_OPPORTUNITY, # Favorable trade conditions
	TRADE_DISRUPTION, # Trade route problems
	ECONOMIC_BOOM, # Economic prosperity
	RESOURCE_SHORTAGE, # Resource scarcity
	NEW_TECHNOLOGY, # New tech introduced
	RESOURCE_CONFLICT # Conflict over resources
}

## Quest Types
enum QuestType {
	NONE, # No quest type
	MAIN, # Main storyline quest
	SIDE, # Side quest
	STORY, # Story-related quest
	EVENT # Event-triggered quest
}

## Deployment Types
enum DeploymentType {
	NONE, # No deployment type
	STANDARD, # Standard deployment
	LINE, # Linear deployment
	AMBUSH, # Ambush deployment
	SCATTERED, # Scattered deployment
	DEFENSIVE, # Defensive deployment
	REINFORCEMENT, # Reinforcement deployment
	INFILTRATION, # Stealth deployment
	OFFENSIVE, # Aggressive deployment
	BOLSTERED_LINE, # Reinforced line
	CONCEALED # Hidden deployment
}

## Unit States
enum UnitState {
	NONE, # Default state
	ACTIVE, # Currently active
	WAITING, # Waiting for activation
	REACTING, # Performing reaction
	STUNNED, # Temporarily stunned
	PANICKED, # Panicking
	PINNED, # Pinned down by fire
	OVERWATCH # In overwatch state
}

## Initiative States
enum InitiativeState {
	NONE, # No state
	UNACTIVATED, # Not yet activated this turn
	ACTIVATED, # Has activated this turn
	PASSED, # Passed activation
	REACTED, # Has reacted this turn
	DELAYED # Delayed activation
}

## Damage Types
enum DamageType {
	NONE, # No damage type
	KINETIC, # Physical impact damage
	ENERGY, # Energy-based damage
	EXPLOSIVE, # Explosive damage
	PIERCING, # Armor-piercing damage
	FIRE, # Fire damage
	TOXIC, # Toxic/poison damage
	EMP, # Electronic disruption
	PSIONIC # Mental/psionic damage
}

## Roll Results
enum RollResult {
	NONE, # No result
	CRITICAL_FAILURE, # Critical failure
	FAILURE, # Failure
	PARTIAL_SUCCESS, # Partial success
	SUCCESS, # Success
	CRITICAL_SUCCESS # Critical success
}

## Cover Types
enum CoverType {
	NONE, # No cover
	LIGHT, # Light cover (25% protection)
	MEDIUM, # Medium cover (50% protection)
	HEAVY, # Heavy cover (75% protection)
	FULL # Full cover (100% protection)
}

## Weapon Modifications
enum WeaponModification {
	NONE, # No modification
	SCOPE, # Improved accuracy
	EXTENDED_BARREL, # Increased range
	SILENCER, # Suppressed firing
	AUTO_LOADER, # Faster reload
	ELEMENTAL, # Adds elemental damage
	OVERCHARGED, # Increased damage
	LIGHTWEIGHT, # Reduced weight
	STABILIZER, # Reduced recoil
	ENHANCED_GRIP # Improved handling
}

## Character Experience Levels
enum ExperienceLevel {
	ROOKIE, # New character
	EXPERIENCED, # Some experience
	VETERAN, # Significant experience
	ELITE, # High-level experience
	LEGENDARY # Maximum experience level
}

## Line of Sight Status
enum LOSStatus {
	NONE, # No line of sight information
	CLEAR, # Clear line of sight
	PARTIAL, # Partially obstructed
	BLOCKED, # Completely blocked
	UNKNOWN # Not yet determined
}

## Team Formations
enum Formation {
	NONE, # No formation
	LINE, # Line formation
	COLUMN, # Column formation
	WEDGE, # Wedge formation
	DIAMOND, # Diamond formation
	SCATTERED, # Scattered formation
	FLANKING, # Flanking formation
	DEFENSIVE # Defensive formation
}

## User Interface States
enum UIState {
	NONE, # Default state
	LOADING, # Loading data
	READY, # Ready for input
	PROCESSING, # Processing input
	TRANSITIONING, # Transitioning between states
	ERROR # Error state
}

## Dialog Result Types
enum DialogResult {
	NONE, # No result
	CONFIRM, # User confirmed
	CANCEL, # User canceled
	YES, # User selected yes
	NO, # User selected no
	RETRY, # User selected retry
	IGNORE # User selected ignore
}

## Save Game States
enum SaveState {
	NONE, # No save state
	SAVING, # Currently saving
	LOADING, # Currently loading
	SUCCESS, # Operation successful
	FAILED, # Operation failed
	CORRUPTED # Save data corrupted
}

## Game Mode Types
enum GameMode {
	NONE, # No specific game mode
	CAMPAIGN, # Full campaign mode
	SKIRMISH, # One-off battles
	SCENARIO, # Pre-defined scenarios
	TUTORIAL, # Tutorial mode
	SANDBOX # Open sandbox play
}

## Difficulty Modifiers
enum DifficultyModifier {
	NONE, # No modifier
	ENEMIES_INCREASED, # More enemies
	ENEMY_QUALITY_UP, # Better enemy equipment
	REDUCED_REWARDS, # Lower rewards
	LIMITED_RESOURCES, # Fewer resources
	TIME_PRESSURE, # Time constraints
	PERMADEATH, # No character revival
	IRONMAN # No manual saves
}

## Objective Types
enum ObjectiveType {
	NONE, # No specific objective
	ELIMINATION, # Eliminate targets
	ACQUISITION, # Acquire item/resource
	PROTECTION, # Protect entity/location
	EXPLORATION, # Explore area
	INFILTRATION, # Infiltrate location
	ESCAPE, # Escape from area
	HOLDOUT, # Hold position for time
	CAPTURE, # Capture entity/location
	STEALTH # Remain undetected
}

## Mission Result Types
enum MissionResult {
	NONE, # No result yet
	SUCCESS, # Mission successful
	PARTIAL_SUCCESS, # Partial success
	FAILURE, # Mission failed
	ABANDONED, # Mission abandoned
	DISASTER # Critical failure
}

## Battle Report Categories
enum BattleReportCategory {
	NONE, # No category
	COMBAT, # Combat statistics
	RESOURCES, # Resource gains/losses
	CHARACTERS, # Character performance
	OBJECTIVES, # Objective status
	REWARDS, # Mission rewards
	LOSSES, # Personnel/equipment losses
	TACTICAL # Tactical evaluation
}

## Achievement Types
enum AchievementType {
	NONE, # No achievement type
	PROGRESSION, # Story progress achievements
	CHALLENGE, # Challenge-based achievements
	COLLECTION, # Collection-based achievements
	HIDDEN, # Hidden/secret achievements
	MASTERY # Mastery achievements
}

## Animation States
enum AnimationState {
	NONE, # No animation
	IDLE, # Idle animation
	WALKING, # Walking animation
	RUNNING, # Running animation
	ATTACKING, # Attack animation
	DAMAGED, # Taking damage animation
	DYING, # Death animation
	SPECIAL # Special action animation
}

## Sound Categories
enum SoundCategory {
	NONE, # No category
	MUSIC, # Background music
	SFX, # Sound effects
	AMBIENT, # Ambient sounds
	UI, # UI interaction sounds
	VOICE, # Voice/dialogue
	WEAPON # Weapon sounds
}

## Time Units
enum TimeUnit {
	NONE, # No time unit
	TURN, # Game turn
	DAY, # In-game day
	WEEK, # In-game week
	MONTH, # In-game month
	YEAR # In-game year
}

## Transaction Types
enum TransactionType {
	NONE, # No transaction
	PURCHASE, # Buying items
	SALE, # Selling items
	REWARD, # Mission rewards
	EXPENSE, # Required expenses
	REPAIR, # Repair costs
	MEDICAL, # Medical expenses
	TRAINING # Training costs
}

## Ally Relations
enum AllyRelation {
	NONE, # No relation
	TEMPORARY, # Temporary ally
	PERMANENT, # Permanent ally
	MERCENARY, # Hired ally
	FACTION, # Faction-based ally
	STORY # Story-related ally
}

## Debug Levels
enum DebugLevel {
	NONE, # No debugging
	INFO, # Basic information
	WARNING, # Warning messages
	ERROR, # Error messages
	CRITICAL, # Critical issues
	VERBOSE # All debug messages
}

## Enemy Types
enum EnemyType {
	NONE, # No specific type
	GANGERS, # Street gang members
	PUNKS, # Urban troublemakers
	RAIDERS, # Aggressive scavengers
	PIRATES, # Space pirates
	CULTISTS, # Religious fanatics
	PSYCHOS, # Unhinged individuals
	WAR_BOTS, # Combat robots
	SECURITY_BOTS, # Law enforcement robots
	BLACK_OPS_TEAM, # Covert operatives
	SECRET_AGENTS, # Intelligence agents
	ELITE, # Superior forces
	BOSS, # Leader enemies
	MINION, # Basic followers
	ENFORCERS, # Law enforcement
	ASSASSINS, # Professional killers
	UNITY_GRUNTS, # Unity faction soldiers
	BLACK_DRAGON_MERCS # Black Dragon mercenaries
}

## Character Stats
enum CharacterStats {
	NONE, # No specific stat
	REACTIONS, # Reflexes and initiative
	COMBAT_SKILL, # Fighting ability
	TOUGHNESS, # Physical resilience
	SAVVY, # General knowledge
	TECH, # Technical aptitude
	NAVIGATION, # Pathfinding skill
	SOCIAL # Social interaction skill
}

## Enemy Weapon Classes
enum EnemyWeaponClass {
	NONE, # No weapons
	BASIC, # Simple weaponry
	ADVANCED, # Improved weaponry
	ELITE, # High-end weaponry
	BOSS # Unique powerful weapons
}

## Enemy Deployment Patterns
enum EnemyDeploymentPattern {
	NONE, # No specific pattern
	STANDARD, # Default formation
	SCATTERED, # Spread out formation
	AMBUSH, # Surprise attack position
	OFFENSIVE, # Aggressive positioning
	DEFENSIVE, # Fortified positioning
	BOLSTERED_LINE, # Reinforced line formation
	CONCEALED # Hidden positioning
}

## Combat Result Types
enum CombatResult {
	NONE, # No result
	HIT, # Successful hit
	MISS, # Attack missed
	CRITICAL, # Critical hit
	GRAZE, # Glancing hit
	DODGE, # Target dodged
	BLOCK # Target blocked
}

## Combat Range Categories
enum CombatRange {
	NONE, # No range specified
	POINT_BLANK, # Extremely close range
	SHORT, # Short range
	MEDIUM, # Medium range
	LONG, # Long range
	EXTREME # Maximum range
}

## Verification Types
enum VerificationType {
	NONE, # No verification
	COMBAT, # Combat verification
	STATE, # State verification
	RULES, # Rules verification
	DEPLOYMENT, # Deployment verification
	MOVEMENT, # Movement verification
	OBJECTIVES # Objectives verification
}

## Verification Scope
enum VerificationScope {
	NONE, # No scope
	SINGLE, # Single entity
	ALL, # All entities
	SELECTED, # Selected entities
	GROUP # Group of entities
}

## Verification Results
enum VerificationResult {
	NONE, # No result
	SUCCESS, # Verification passed
	WARNING, # Warning level issues
	ERROR, # Error level issues
	CRITICAL # Critical level issues
}

## Event Categories
enum EventCategory {
	NONE, # No category
	COMBAT, # Combat events
	EQUIPMENT, # Equipment events
	TACTICAL, # Tactical events
	ENVIRONMENT, # Environment events
	SPECIAL # Special events
}

## Enemy Characteristics
enum EnemyCharacteristic {
	NONE, # No characteristics
	ELITE, # Elite enemy
	BOSS, # Boss enemy
	MINION, # Basic enemy
	LEADER, # Leader type
	SUPPORT, # Support role
	TANK, # Heavy defense
	SCOUT, # Reconnaissance
	SNIPER, # Long-range specialist
	MEDIC, # Healing support
	TECH, # Technical specialist
	BERSERKER, # Aggressive fighter
	COMMANDER # Command unit
}

## Crew Tasks
enum CrewTask {
	NONE, # No task
	FIND_PATRON, # Search for work
	RECRUIT, # Find new crew
	EXPLORE, # Explore area
	TRACK, # Track target
	DECOY, # Act as decoy
	GUARD, # Guard duty
	SCOUT, # Scouting mission
	SABOTAGE, # Sabotage mission
	GATHER_INFO, # Intelligence gathering
	REPAIR, # Equipment repair
	HEAL, # Medical treatment
	TRAIN, # Training activity
	TRADE, # Trading activity
	RESEARCH, # Research task
	MAINTENANCE, # Maintenance work
	REST, # Rest and recovery
	SPECIAL # Special assignment
}

## Job Types
enum JobType {
	NONE, # No job type
	COMBAT, # Combat mission
	EXPLORATION, # Exploration mission
	ESCORT, # Escort duty
	RECOVERY, # Item recovery
	DEFENSE, # Defensive mission
	SABOTAGE, # Sabotage mission
	ASSASSINATION # Assassination mission
}

## Strange Character Types
enum StrangeCharacterType {
	NONE, # Normal character
	ALIEN, # Alien being
	DE_CONVERTED, # Reformed character
	UNITY_AGENT, # Unity faction agent
	BOT, # Robot character
	ASSAULT_BOT, # Combat robot
	PRECURSOR, # Ancient being
	FERAL # Wild character
}

## Combat Advantage Levels
enum CombatAdvantage {
	NONE, # No advantage
	MINOR, # Slight advantage
	MAJOR, # Significant advantage
	OVERWHELMING # Dominating advantage
}

## Combat Status Effects
enum CombatStatus {
	NONE, # No status effect
	PINNED, # Movement restricted
	FLANKED, # Attacked from side
	SURROUNDED, # Attacked from multiple sides
	SUPPRESSED # Under heavy fire
}

## Combat Tactics
enum CombatTactic {
	NONE, # No specific tactic
	AGGRESSIVE, # Offensive focus
	DEFENSIVE, # Defensive focus
	BALANCED, # Balanced approach
	EVASIVE # Evasion priority
}

## Battle States
enum BattleState {
	NONE, # No battle state
	SETUP, # Initial setup
	ROUND, # Active round
	CLEANUP # End of battle processing
}

## Combat Phases
enum CombatPhase {
	NONE, # No combat phase
	SETUP, # Setup phase
	DEPLOYMENT, # Deployment phase
	INITIATIVE, # Initiative determination
	ACTION, # Action phase
	REACTION, # Reaction phase
	END # End phase
}

## Ship Component Types
enum ShipComponentType {
	NONE, # No component type
	HULL_BASIC, # Basic hull structure
	HULL_REINFORCED, # Reinforced hull with better protection
	HULL_ADVANCED, # Advanced hull with integrated systems
	ENGINE_BASIC, # Basic propulsion system
	ENGINE_IMPROVED, # Improved propulsion with better efficiency
	ENGINE_ADVANCED, # Advanced high-performance propulsion
	WEAPON_BASIC_LASER, # Basic laser weapon system
	WEAPON_BASIC_KINETIC, # Basic kinetic weapon system
	WEAPON_ADVANCED_LASER, # Advanced laser weapon system
	WEAPON_ADVANCED_KINETIC, # Advanced kinetic weapon system
	WEAPON_HEAVY_LASER, # Heavy laser weapon system
	WEAPON_HEAVY_KINETIC, # Heavy kinetic weapon system
	MEDICAL_BASIC, # Basic medical facility
	MEDICAL_ADVANCED # Advanced medical facility
}

## Armor Characteristics
enum ArmorCharacteristic {
	NONE, # No special characteristics
	LIGHT, # Light armor classification
	MEDIUM, # Medium armor classification
	HEAVY, # Heavy armor classification
	POWERED, # Power-assisted armor
	SHIELD, # Energy shield component
	HAZARD, # Environmental protection
	STEALTH, # Stealth enhancement
	REACTIVE, # Reactive plating
	INSULATED, # Energy insulation
	REINFORCED, # Reinforced structure
	ADVANCED, # Advanced technology
	SPECIALIZED # Specialized purpose
}

## Verification Status
enum VerificationStatus {
	NONE, # No verification status
	PENDING, # Verification in progress
	VERIFIED, # Successfully verified
	REJECTED # Verification failed
}

## Quest Status
enum QuestStatus {
	NONE, # No status
	ACTIVE, # Active quest
	COMPLETED, # Completed quest
	FAILED, # Failed quest
	ABANDONED # Abandoned quest
}
