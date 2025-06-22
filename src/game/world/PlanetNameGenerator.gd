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
			var prefix = PLANET_PREFIXES[randi() % PLANET_PREFIXES.size()]
			var number = randi() % 999 + 1
			return prefix + " " + str(number)
		1: # Prefix + Suffix
			var prefix = PLANET_PREFIXES[randi() % PLANET_PREFIXES.size()]
			var suffix = PLANET_SUFFIXES[randi() % PLANET_SUFFIXES.size()]
			return prefix + " " + suffix
		2: # Descriptive name
			return DESCRIPTIVE_NAMES[randi() % DESCRIPTIVE_NAMES.size()]
		_:
			return "Unknown World"

func generate_system_name() -> String:
	var prefix = PLANET_PREFIXES[randi() % PLANET_PREFIXES.size()]
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
	
	var descriptor = descriptors[randi() % descriptors.size()]
	var sector = sectors[randi() % sectors.size()]
	var number = randi() % 999 + 1
	
	return descriptor + " " + sector + " " + str(number)
