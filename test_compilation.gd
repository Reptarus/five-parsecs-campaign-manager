# Five Parsecs Campaign Manager - Compilation Test
# Tests all previously failing enum references

extends RefCounted

func test_all_enum_references() -> bool:
	print("Testing Five Parsecs Campaign Manager Enum Compilation...")
	
	# Test 1: DifficultyLevel.NORMAL (was failing)
	var difficulty_normal = GlobalEnums.DifficultyLevel.NORMAL
	var difficulty_standard = GlobalEnums.DifficultyLevel.STANDARD
	print("✅ DifficultyLevel.NORMAL: ", difficulty_normal)
	print("✅ DifficultyLevel.STANDARD: ", difficulty_standard)
	
	# Test 2: MarketState enum (was completely missing)
	var market_normal = GlobalEnums.MarketState.NORMAL
	var market_boom = GlobalEnums.MarketState.BOOM
	var market_restricted = GlobalEnums.MarketState.RESTRICTED
	var market_crisis = GlobalEnums.MarketState.CRISIS
	print("✅ MarketState.NORMAL: ", market_normal)
	print("✅ MarketState.BOOM: ", market_boom)
	print("✅ MarketState.RESTRICTED: ", market_restricted)
	print("✅ MarketState.CRISIS: ", market_crisis)
	
	# Test 3: PlanetType enum (was missing)
	var planet_terrestrial = GlobalEnums.PlanetType.TERRESTRIAL
	var planet_desert = GlobalEnums.PlanetType.DESERT
	var planet_space_station = GlobalEnums.PlanetType.SPACE_STATION
	print("✅ PlanetType.TERRESTRIAL: ", planet_terrestrial)
	print("✅ PlanetType.DESERT: ", planet_desert)
	print("✅ PlanetType.SPACE_STATION: ", planet_space_station)
	
	# Test 4: FactionType enum (was missing)
	var faction_neutral = GlobalEnums.FactionType.NEUTRAL
	var faction_unity = GlobalEnums.FactionType.UNITY
	var faction_corporate = GlobalEnums.FactionType.CORPORATE
	print("✅ FactionType.NEUTRAL: ", faction_neutral)
	print("✅ FactionType.UNITY: ", faction_unity)
	print("✅ FactionType.CORPORATE: ", faction_corporate)
	
	# Test 5: PlanetEnvironment enum (was missing)
	var env_habitable = GlobalEnums.PlanetEnvironment.HABITABLE
	var env_toxic = GlobalEnums.PlanetEnvironment.TOXIC
	var env_vacuum = GlobalEnums.PlanetEnvironment.VACUUM
	print("✅ PlanetEnvironment.HABITABLE: ", env_habitable)
	print("✅ PlanetEnvironment.TOXIC: ", env_toxic)
	print("✅ PlanetEnvironment.VACUUM: ", env_vacuum)
	
	# Test 6: StrifeType enum (was missing)
	var strife_peaceful = GlobalEnums.StrifeType.PEACEFUL
	var strife_war = GlobalEnums.StrifeType.WAR
	var strife_chaos = GlobalEnums.StrifeType.CHAOS
	print("✅ StrifeType.PEACEFUL: ", strife_peaceful)
	print("✅ StrifeType.WAR: ", strife_war)
	print("✅ StrifeType.CHAOS: ", strife_chaos)
	
	# Test helper functions
	print("✅ Market state name: ", GlobalEnums.get_market_state_name(GlobalEnums.MarketState.BOOM))
	print("✅ Planet type name: ", GlobalEnums.get_planet_type_name(GlobalEnums.PlanetType.TERRESTRIAL))
	print("✅ Faction name: ", GlobalEnums.get_faction_type_name(GlobalEnums.FactionType.UNITY))
	
	print("🎉 ALL ENUM COMPILATION TESTS PASSED!")
	return true

func _init() -> void:
	test_all_enum_references()
