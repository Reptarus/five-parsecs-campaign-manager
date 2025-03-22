@tool
# Removed class_name to prevent cyclic inheritance
extends RefCounted

## Global test helper that fixes the GameEnums reference problem by providing
## a centralized way to access the GlobalEnums constants.
##
## This solves the issue of having multiple files trying to declare the same
## GlobalEnums constant, which causes "already exists in parent class" errors.

# Direct access to GlobalEnums
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Make this available as a static property
static func get_global_enums():
	return GlobalEnums

## Game system and test specific enums that are not in GlobalEnums

# Status Effects
enum StatusEffect {
	NONE,
	STUNNED,
	BLEEDING,
	POISONED,
	BURNING,
	FROZEN,
	CONFUSED,
	WEAKENED
}

# Damage Types
enum DamageType {
	NONE,
	PHYSICAL,
	ENERGY,
	FIRE,
	ICE,
	RADIATION,
	SHOCK,
	POISON,
	PIERCING
}

# Unit States
enum UnitState {
	NONE,
	READY,
	ENGAGED,
	STUNNED,
	PANICKED,
	EXHAUSTED,
	DOWN,
	DEAD
}

# Mission States
enum MissionState {
	NONE,
	PREPARATION,
	ACTIVE,
	COMPLETE,
	FAILED
}

# Mission Phases
enum MissionPhase {
	NONE,
	PREPARATION,
	DEPLOYMENT,
	COMBAT,
	RESOLUTION
}

# Objective Types
enum ObjectiveType {
	NONE,
	ELIMINATE,
	CAPTURE,
	DEFEND,
	COLLECT,
	EXTRACT,
	SABOTAGE,
	SURVIVE
}

# Component Types
enum ComponentType {
	NONE,
	WEAPON,
	ENGINE,
	SHIELD,
	SCANNER,
	MEDIC_BAY,
	CARGO_BAY,
	SPECIAL
}

# Mission Data
enum MissionData {
	NONE,
	TARGET,
	LOCATION,
	REWARD,
	DIFFICULTY,
	TIME_LIMIT
}

# AI Personality
enum AIPersonality {
	NONE,
	AGGRESSIVE,
	CAUTIOUS,
	TACTICAL,
	PROTECTIVE,
	UNPREDICTABLE
}

# Group Tactics
enum GroupTactic {
	NONE,
	COORDINATED_ATTACK,
	DEFENSIVE_FORMATION,
	FLANKING_MANEUVER,
	SUPPRESSION_PATTERN
}

# Ability Types
enum AbilityType {
	NONE,
	PASSIVE,
	ACTIVE,
	TRIGGERED,
	SPECIAL
}

# Constants used in tests
const MAX_PATRON_QUESTS = 5
const MIN_THREAT_LEVEL = 1
const NEUTRAL_HOSTILITY = 0
const MIN_RESOURCES = 0
const MAX_RESOURCES = 1000
const HOSTILITY_INCREASE_AMOUNT = 10
const HOSTILITY_DECREASE_AMOUNT = 5
const MAX_HOSTILITY = 100
const MIN_HOSTILITY = 0
const THREAT_LEVEL_INCREASE = 5
const THREAT_LEVEL_DECREASE = 3
const MAX_THREAT_LEVEL = 10
const RESOURCE_GAIN_AMOUNT = 50
const RESOURCE_SPEND_AMOUNT = 25
const MIN_ENCOUNTER_DIFFICULTY = 1
const DEFAULT_THREAT_LEVEL = 5
const DEFAULT_HOSTILITY = 0
const DEFAULT_RESOURCES = 100
const REPUTATION_GAIN_AMOUNT = 10
const REPUTATION_LOSS_AMOUNT = 5
const INFLUENCE_GAIN_AMOUNT = 20
const INFLUENCE_LOSS_AMOUNT = 10
const MAX_INFLUENCE = 100
const DEFAULT_INFLUENCE = 10
const DEFAULT_REPUTATION = 0
const MIN_REPUTATION_REQUIREMENT = 5
const QUEST_REWARD_MULTIPLIER = 10
const REPUTATION_REWARD_THRESHOLD = 50
const COMPONENT_BASE_LEVEL = 1
const COMPONENT_MAX_DURABILITY = 100
const COMPONENT_MAX_EFFICIENCY = 100
const SHIP_MAX_HEALTH = 1000

## Replace all GameEnums references in test files with TestEnums.GlobalEnums
## For example:
##     Instead of: GameEnums.DifficultyLevel.NORMAL
##     Use: TestEnums.GlobalEnums.DifficultyLevel.NORMAL
##
## This avoids the "identifier not declared in current scope" errors while also
## preventing the "member already exists in parent class" errors.

## Singleton instance for easy access
static var instance = null

static func get_instance():
	if not instance:
		instance = load("res://tests/fixtures/base/test_helper.gd").new()
	return instance

## Static accessors for common enum types
static func get_enums():
	return GlobalEnums