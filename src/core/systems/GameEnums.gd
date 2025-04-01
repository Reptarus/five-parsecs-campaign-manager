@tool
extends Node
# GameEnums - Compatibility module to provide consistent enum access
# This file helps convert between GlobalEnums and enum usage in the code

# Re-export all enums from GlobalEnums for compatibility
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Item Types
enum ItemType {
	NONE = 0,
	WEAPON = 1,
	ARMOR = 2,
	GEAR = 3,
	CYBERNETIC = 4,
	CONSUMABLE = 5,
	SPECIAL = 6
}

# Planet Environments
enum PlanetEnvironment {
	NONE = 0,
	EARTH_LIKE = 1,
	DESERT = 2,
	ICE = 3,
	JUNGLE = 4,
	OCEAN = 5,
	VOLCANIC = 6,
	TOXIC = 7,
	WASTELAND = 8
}

# Verification types
enum VerificationType {
	NONE = 0,
	STRUCTURE = 1,
	LOGIC = 2,
	STATE = 3,
	CONTENT = 4,
	PERFORMANCE = 5
}

# Campaign phases - mirrors GlobalEnums for type safety
enum FiveParcsecsCampaignPhase {
	NONE = 0,
	SETUP = 1,
	UPKEEP = 2,
	STORY = 3,
	CAMPAIGN = 4,
	BATTLE_SETUP = 5,
	BATTLE_RESOLUTION = 6,
	ADVANCEMENT = 7,
	TRADE = 8,
	END = 9
}

# Conversion helpers
static func global_to_game_item_type(global_type) -> ItemType:
	# If we're getting a direct integer, just return it
	if typeof(global_type) == TYPE_INT:
		return global_type
		
	# For GlobalEnums.gd.ItemType objects, convert to int
	if typeof(global_type) == TYPE_OBJECT and str(global_type).begins_with("GlobalEnums.gd.ItemType."):
		var as_int = int(global_type)
		return as_int
	
	# For string representations
	if typeof(global_type) == TYPE_STRING:
		match global_type:
			"NONE": return ItemType.NONE
			"WEAPON": return ItemType.WEAPON
			"ARMOR": return ItemType.ARMOR
			"GEAR": return ItemType.GEAR
			"CYBERNETIC": return ItemType.CYBERNETIC
			"CONSUMABLE": return ItemType.CONSUMABLE
			"SPECIAL": return ItemType.SPECIAL
	
	# Default fallback
	return ItemType.NONE

static func global_to_game_planet_environment(global_env) -> PlanetEnvironment:
	# If we're getting a direct integer, just return it
	if typeof(global_env) == TYPE_INT:
		return global_env
		
	# For GlobalEnums.gd.PlanetEnvironment objects, convert to int
	if typeof(global_env) == TYPE_OBJECT and str(global_env).begins_with("GlobalEnums.gd.PlanetEnvironment."):
		var as_int = int(global_env)
		return as_int
	
	# For string representations
	if typeof(global_env) == TYPE_STRING:
		match global_env:
			"NONE": return PlanetEnvironment.NONE
			"EARTH_LIKE": return PlanetEnvironment.EARTH_LIKE
			"DESERT": return PlanetEnvironment.DESERT
			"ICE": return PlanetEnvironment.ICE
			"JUNGLE": return PlanetEnvironment.JUNGLE
			"OCEAN": return PlanetEnvironment.OCEAN
			"VOLCANIC": return PlanetEnvironment.VOLCANIC
			"TOXIC": return PlanetEnvironment.TOXIC
			"WASTELAND": return PlanetEnvironment.WASTELAND
	
	# Default fallback
	return PlanetEnvironment.NONE

static func global_to_game_verification_type(global_type) -> VerificationType:
	# If we're getting a direct integer, just return it
	if typeof(global_type) == TYPE_INT:
		return global_type
		
	# For GlobalEnums.gd.VerificationType objects, convert to int
	if typeof(global_type) == TYPE_OBJECT and str(global_type).begins_with("GlobalEnums.gd.VerificationType."):
		var as_int = int(global_type)
		return as_int
	
	# For string representations
	if typeof(global_type) == TYPE_STRING:
		match global_type:
			"NONE": return VerificationType.NONE
			"STRUCTURE": return VerificationType.STRUCTURE
			"LOGIC": return VerificationType.LOGIC
			"STATE": return VerificationType.STATE
			"CONTENT": return VerificationType.CONTENT
			"PERFORMANCE": return VerificationType.PERFORMANCE
	
	# Default fallback
	return VerificationType.NONE

static func global_to_game_campaign_phase(global_phase) -> FiveParcsecsCampaignPhase:
	# If we're getting a direct integer, just return it
	if typeof(global_phase) == TYPE_INT:
		return global_phase
		
	# For GlobalEnums.gd.CampaignPhase objects, convert to int
	if typeof(global_phase) == TYPE_OBJECT and str(global_phase).begins_with("GlobalEnums.gd.CampaignPhase."):
		var as_int = int(global_phase)
		return as_int
	
	# For string representations
	if typeof(global_phase) == TYPE_STRING:
		match global_phase:
			"NONE": return FiveParcsecsCampaignPhase.NONE
			"SETUP": return FiveParcsecsCampaignPhase.SETUP
			"UPKEEP": return FiveParcsecsCampaignPhase.UPKEEP
			"STORY": return FiveParcsecsCampaignPhase.STORY
			"CAMPAIGN": return FiveParcsecsCampaignPhase.CAMPAIGN
			"BATTLE_SETUP": return FiveParcsecsCampaignPhase.BATTLE_SETUP
			"BATTLE_RESOLUTION": return FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
			"ADVANCEMENT": return FiveParcsecsCampaignPhase.ADVANCEMENT
			"TRADE": return FiveParcsecsCampaignPhase.TRADE
			"END": return FiveParcsecsCampaignPhase.END
	
	# Default fallback
	return FiveParcsecsCampaignPhase.NONE