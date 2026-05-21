## SpeciesPortraitRegistry — bundled Modiphius portrait fallback by species.
##
## Resolves portrait_path when a character has none explicitly set. Returns a
## deterministic per-character pick so the same character always shows the same
## portrait across sessions (but two characters of the same species can show
## different variants).
##
## Not an autoload. Stateless. Path-loaded (no class_name) to keep load order
## clean for Character.gd preload.
extends RefCounted

const PORTRAITS := {
	"engineer": ["res://assets/portraits/species/engineer_01.png"],
	"feral": ["res://assets/portraits/species/feral_01.png"],
	"k_erin": ["res://assets/portraits/species/k_erin_01.png"],
	"kerin": ["res://assets/portraits/species/k_erin_01.png"],
	"krag": ["res://assets/portraits/species/krag_01.png"],
	"skulker": ["res://assets/portraits/species/skulker_01.png"],
	"soulless": ["res://assets/portraits/species/soulless_01.png"],
	"swift": [
		"res://assets/portraits/species/swift_01.png",
		"res://assets/portraits/species/swift_02.png",
	],
	"precursor": ["res://assets/portraits/species/precursor_01.png"],
	"hulker": ["res://assets/portraits/species/hulker_01.png"],
	"de_converted": ["res://assets/portraits/species/de_converted_01.png"],
	"unity_agent": ["res://assets/portraits/species/unity_agent_01.png"],
}

const PSIONIC_PORTRAIT := "res://assets/portraits/species/psionic_01.png"
const DEFAULT_PORTRAIT := "res://assets/portraits/default.png"


static func get_portraits_for(species_id: String) -> Array:
	if species_id.is_empty():
		return []
	return PORTRAITS.get(species_id.to_lower(), [])


static func get_portrait_for(species_id: String, character_id: String = "") -> String:
	var pool: Array = get_portraits_for(species_id)
	if pool.is_empty():
		return ""
	if pool.size() == 1 or character_id.is_empty():
		return pool[0]
	var idx: int = absi(character_id.hash()) % pool.size()
	return pool[idx]


static func has_portrait(species_id: String) -> bool:
	return not get_portraits_for(species_id).is_empty()


static func all_species_with_portraits() -> Array:
	return PORTRAITS.keys()
