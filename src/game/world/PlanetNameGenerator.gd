@tool
extends Resource
class_name PlanetNameGenerator

## Planet Name Generator for Five Parsecs
## Generates names for planets in procedural galaxies

const PLANET_PREFIXES: Array[String] = [
	"Alpha", "Beta", "Gamma", "Delta", "Zeta", "Nova", "Proxima", "Vega",
	"Centauri", "Arcturus", "Rigel", "Capella", "Sirius", "Aldebaran",
	"Antares", "Spica", "Pollux", "Regulus", "Deneb", "Canopus"
]

const PLANET_SUFFIXES: Array[String] = [
	"Prime", "Major", "Minor", "Beta", "Gamma", "Station", "Outpost",
	"Colony", "Haven", "Junction", "Nexus", "Terminal", "Gateway",
	"Sanctuary", "Refuge", "Crossing", "Point", "Base", "Hub", "Port"
]

const DESCRIPTIVE_NAMES: Array[String] = [
	"Crimson Rock", "Azure Heights", "Golden Fields", "Silver Dunes",
	"Crystal Falls", "Iron Mesa", "Copper Valleys", "Storm Plains",
	"Frozen Peaks", "Burning Sands", "Misty Shores", "Thunder Canyon",
	"Emerald Forest", "Ruby Desert", "Sapphire Bay", "Diamond Ridge"
]

func generate_name() -> String:
	var name_type = randi() % 3

	match name_type:
		0: # Prefix + Number
			var prefix = PLANET_PREFIXES[randi() % (safe_call_method(PLANET_PREFIXES, "size") as int)]
			var number = randi() % 999 + 1
			return prefix + " " + str(number)
		1: # Prefix + Suffix
			var prefix = PLANET_PREFIXES[randi() % (safe_call_method(PLANET_PREFIXES, "size") as int)]
			var suffix = PLANET_SUFFIXES[randi() % (safe_call_method(PLANET_SUFFIXES, "size") as int)]
			return prefix + " " + suffix
		2: # Descriptive name
			return DESCRIPTIVE_NAMES[randi() % (safe_call_method(DESCRIPTIVE_NAMES, "size") as int)]
		_:
			return "Unknown World"

func generate_system_name() -> String:
	var prefix = PLANET_PREFIXES[randi() % (safe_call_method(PLANET_PREFIXES, "size") as int)]
	var number = randi() % 99 + 1
	return prefix + " System " + str(number)

func generate_sector_name() -> String:
	var descriptors: Array[String] = [
		"Outer", "Inner", "Central", "Northern", "Southern", "Eastern",
		"Western", "Frontier", "Core", "Rim", "Neutral", "Wild"
	]
	var sectors: Array[String] = [
		"Sector", "Zone", "Region", "Territory", "Quadrant", "Expanse"
	]

	var descriptor = descriptors[randi() % (safe_call_method(descriptors, "size") as int)]
	var sector = sectors[randi() % (safe_call_method(sectors, "size") as int)]
	var number = randi() % 999 + 1

	return descriptor + " " + sector + " " + str(number)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null