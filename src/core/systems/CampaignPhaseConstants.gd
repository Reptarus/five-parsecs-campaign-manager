class_name CampaignPhaseConstants
## Campaign Phase Constants for Five Parsecs Campaign Manager
## Transferred from test helpers to production code
## Based on Five Parsecs Core Rulebook campaign turn structure
##
## Sprint 28.1: AUTHORITATIVE SOURCE for phase transition rules
## All phase transition validation should reference these constants.
## Other validators (CampaignPhaseManager, DataConsistencyValidator) should
## either delegate to this class or mirror its rules exactly.
##
## Usage: Reference these constants for campaign phase transitions and validation
## Architecture: Pure constants class - no state, no dependencies
##
## NOTE: This class uses its own CampaignPhase enum. CampaignPhaseManager uses
## GlobalEnums.FiveParsecsCampaignPhase which has different ordinal values
## but represents the same phases. When validating, use the appropriate enum.

## Campaign phase enumeration
enum CampaignPhase {
	NONE,          # Initial state before campaign starts
	TRAVEL,        # Travel phase - movement between worlds (Phase 1-5)
	WORLD,         # World phase - starship travel events, jobs, trade (Phase 6-11)
	BATTLE,        # Battle phase - tactical combat (Phase 12-18)
	POST_BATTLE    # Post-battle phase - casualties, rewards, experience (Phase 19-25)
}

## Phase names for UI display
const PHASE_NAMES: Dictionary = {
	CampaignPhase.NONE: "Campaign Setup",
	CampaignPhase.TRAVEL: "Travel Phase",
	CampaignPhase.WORLD: "World Phase",
	CampaignPhase.BATTLE: "Battle Phase",
	CampaignPhase.POST_BATTLE: "Post-Battle Phase"
}

## Phase descriptions for tooltips/help
const PHASE_DESCRIPTIONS: Dictionary = {
	CampaignPhase.NONE: "Set up campaign parameters and create initial crew",
	CampaignPhase.TRAVEL: "Plan route, check for invasion, travel events, upkeep costs",
	CampaignPhase.WORLD: "Arrival, new world events, patron jobs, trade, crew tasks",
	CampaignPhase.BATTLE: "Tactical combat - deployment, rounds, victory/defeat",
	CampaignPhase.POST_BATTLE: "Casualties, injuries, experience, loot, story points"
}

## Valid phase transitions (Five Parsecs campaign turn flow)
## Each phase can only transition to specific next phases
const VALID_TRANSITIONS: Dictionary = {
	CampaignPhase.NONE: [CampaignPhase.TRAVEL],
	CampaignPhase.TRAVEL: [CampaignPhase.WORLD],
	CampaignPhase.WORLD: [
		CampaignPhase.BATTLE,   # Accept mission and fight
		CampaignPhase.TRAVEL    # Skip battle, move to next turn
	],
	CampaignPhase.BATTLE: [CampaignPhase.POST_BATTLE],
	CampaignPhase.POST_BATTLE: [CampaignPhase.TRAVEL]  # Return to travel for next turn
}

## Invalid transitions that should be blocked (for validation)
## Format: [from_phase, to_phase, reason]
const INVALID_TRANSITIONS: Array[Dictionary] = [
	{
		"from": CampaignPhase.TRAVEL,
		"to": CampaignPhase.BATTLE,
		"reason": "Must go through WORLD phase first"
	},
	{
		"from": CampaignPhase.TRAVEL,
		"to": CampaignPhase.POST_BATTLE,
		"reason": "Must go through WORLD and BATTLE phases"
	},
	{
		"from": CampaignPhase.WORLD,
		"to": CampaignPhase.POST_BATTLE,
		"reason": "Must go through BATTLE phase first"
	},
	{
		"from": CampaignPhase.BATTLE,
		"to": CampaignPhase.TRAVEL,
		"reason": "Must complete POST_BATTLE phase first"
	},
	{
		"from": CampaignPhase.BATTLE,
		"to": CampaignPhase.WORLD,
		"reason": "Cannot return to previous phase"
	},
	{
		"from": CampaignPhase.POST_BATTLE,
		"to": CampaignPhase.WORLD,
		"reason": "Cannot return to previous phase"
	},
	{
		"from": CampaignPhase.POST_BATTLE,
		"to": CampaignPhase.BATTLE,
		"reason": "Cannot return to previous phase"
	}
]

## Phase order for full campaign turn (normal path with battle)
const STANDARD_TURN_SEQUENCE: Array[CampaignPhase] = [
	CampaignPhase.TRAVEL,
	CampaignPhase.WORLD,
	CampaignPhase.BATTLE,
	CampaignPhase.POST_BATTLE
]

## Phases that can be skipped (optional phases)
const OPTIONAL_PHASES: Array[CampaignPhase] = [
	CampaignPhase.BATTLE  # Can skip battle by not accepting jobs
]

## Phases that increment the turn counter
const TURN_INCREMENTING_PHASES: Array[CampaignPhase] = [
	CampaignPhase.TRAVEL  # New turn starts when entering travel phase
]

## Phase validation requirements (minimum data needed to enter phase)
const PHASE_REQUIREMENTS: Dictionary = {
	CampaignPhase.TRAVEL: {
		"min_credits": 0,        # Upkeep will be deducted
		"min_crew": 1,           # Need at least one crew member
		"requires_ship": true
	},
	CampaignPhase.WORLD: {
		"min_credits": 0,        # Can be broke
		"min_crew": 1,
		"requires_ship": true
	},
	CampaignPhase.BATTLE: {
		"min_crew": 1,           # Need crew for combat
		"min_weapons": 0,        # Technically optional but not recommended
		"requires_mission": true
	},
	CampaignPhase.POST_BATTLE: {
		"requires_battle_results": true
	}
}

## ==========================================
## HELPER FUNCTIONS
## ==========================================

## Check if phase transition is valid
static func is_valid_transition(from_phase: CampaignPhase, to_phase: CampaignPhase) -> bool:
	## Check if transition between phases is allowed
	##
	## Args:
	## 	from_phase: Current phase
	## 	to_phase: Target phase
	##
	## Returns:
	## 	True if transition is valid
	if not VALID_TRANSITIONS.has(from_phase):
		return false

	var valid_next_phases: Array = VALID_TRANSITIONS[from_phase]
	return to_phase in valid_next_phases

## Get valid next phases for current phase
static func get_valid_next_phases(current_phase: CampaignPhase) -> Array[CampaignPhase]:
	## Get valid next phases from current phase
	##
	## Args:
	## 	current_phase: Current campaign phase
	##
	## Returns:
	## 	Array of valid next phase enum values
	if not VALID_TRANSITIONS.has(current_phase):
		return []

	return VALID_TRANSITIONS[current_phase].duplicate()

## Get phase name for display
static func get_phase_name(phase: CampaignPhase) -> String:
	## Get human-readable name for phase
	##
	## Args:
	## 	phase: Campaign phase enum value
	##
	## Returns:
	## 	Phase name string
	return PHASE_NAMES.get(phase, "Unknown Phase")

## Get phase description
static func get_phase_description(phase: CampaignPhase) -> String:
	## Get description text for phase
	##
	## Args:
	## 	phase: Campaign phase enum value
	##
	## Returns:
	## 	Phase description string
	return PHASE_DESCRIPTIONS.get(phase, "No description available")

## Check if phase is optional
static func is_optional_phase(phase: CampaignPhase) -> bool:
	## Check if phase can be skipped in campaign turn
	##
	## Args:
	## 	phase: Campaign phase to check
	##
	## Returns:
	## 	True if phase can be skipped
	return phase in OPTIONAL_PHASES

## Check if phase increments turn counter
static func increments_turn_counter(phase: CampaignPhase) -> bool:
	## Check if entering this phase increments the turn number
	##
	## Args:
	## 	phase: Campaign phase to check
	##
	## Returns:
	## 	True if phase increments turn number
	return phase in TURN_INCREMENTING_PHASES

## Get phase requirements
static func get_phase_requirements(phase: CampaignPhase) -> Dictionary:
	## Get minimum requirements to enter phase
	##
	## Args:
	## 	phase: Campaign phase to check
	##
	## Returns:
	## 	Dictionary of requirements (credits, crew, etc.)
	return PHASE_REQUIREMENTS.get(phase, {})

## Validate transition with reason
static func validate_transition(from_phase: CampaignPhase, to_phase: CampaignPhase) -> Dictionary:
	## Validate a phase transition and return reason if invalid
	##
	## Args:
	## 	from_phase: Current phase
	## 	to_phase: Target phase
	##
	## Returns:
	## 	Dictionary with "valid" bool and "reason" string
	if is_valid_transition(from_phase, to_phase):
		return {
			"valid": true,
			"reason": "Valid transition"
		}

	# Find specific reason for invalid transition
	for invalid_transition in INVALID_TRANSITIONS:
		if invalid_transition.from == from_phase and invalid_transition.to == to_phase:
			return {
				"valid": false,
				"reason": invalid_transition.reason
			}

	return {
		"valid": false,
		"reason": "Invalid phase transition"
	}

## Get next phase in standard sequence
static func get_next_standard_phase(current_phase: CampaignPhase) -> CampaignPhase:
	## Get next phase in standard turn sequence (assumes battle is taken)
	##
	## Args:
	## 	current_phase: Current phase
	##
	## Returns:
	## 	Next phase in standard sequence, or TRAVEL if at end
	var current_index: int = STANDARD_TURN_SEQUENCE.find(current_phase)

	if current_index == -1:
		return CampaignPhase.TRAVEL  # Default to starting new turn

	var next_index: int = current_index + 1
	if next_index >= STANDARD_TURN_SEQUENCE.size():
		return CampaignPhase.TRAVEL  # Loop back to start new turn

	return STANDARD_TURN_SEQUENCE[next_index]
