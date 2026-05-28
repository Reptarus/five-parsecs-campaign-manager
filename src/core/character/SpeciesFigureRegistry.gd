## SpeciesFigureRegistry — full-body figure art keyed by species, for scene slots.
##
## Parallel to SpeciesPortraitRegistry (which serves bust portraits). This one
## serves full-figure, transparent-background, feet-at-bottom-center PNGs used
## to composite the player's crew into NarrativeScreen / SceneStage scenes.
## Resolution is deterministic per character_id so the same crew member always
## shows the same figure variant (two crew of one species can still differ).
##
## Figures are NOT guaranteed to exist on disk: consumers (SceneStage) must
## guard with ResourceLoader.exists() and degrade to an empty slot. This lets
## the registry list the full species namespace while art is still being made.
##
## Not an autoload. Stateless. Path-loaded (no class_name) to keep load order
## clean for callers that also preload Character.gd.
extends RefCounted

## species_id -> Array of figure paths. Keys mirror SpeciesPortraitRegistry so
## the same character resolves consistently across portrait + figure systems.
const FIGURES := {
	"engineer": ["res://assets/figures/species/engineer_01.png"],
	"feral": ["res://assets/figures/species/feral_01.png"],
	"k_erin": ["res://assets/figures/species/k_erin_01.png"],
	"kerin": ["res://assets/figures/species/k_erin_01.png"],
	"krag": ["res://assets/figures/species/krag_01.png"],
	"skulker": ["res://assets/figures/species/skulker_01.png"],
	"soulless": ["res://assets/figures/species/soulless_01.png"],
	"swift": [
		"res://assets/figures/species/swift_01.png",
		"res://assets/figures/species/swift_02.png",
	],
	"precursor": ["res://assets/figures/species/precursor_01.png"],
	"hulker": ["res://assets/figures/species/hulker_01.png"],
	"de_converted": ["res://assets/figures/species/de_converted_01.png"],
	"unity_agent": ["res://assets/figures/species/unity_agent_01.png"],
	"psionic": ["res://assets/figures/species/psionic_01.png"],
}


static func get_figures_for(species_id: String) -> Array:
	if species_id.is_empty():
		return []
	return FIGURES.get(species_id.to_lower(), [])


## Deterministic pick by character_id so a given crew member is stable across
## sessions. Returns "" when the species has no figure catalogued.
static func get_figure_for(species_id: String, character_id: String = "") -> String:
	var pool: Array = get_figures_for(species_id)
	if pool.is_empty():
		return ""
	# Prefer variants that actually exist on disk. Figure art may be partial
	# (e.g. swift_01 shipped but swift_02 not yet), and a deterministic pick
	# must never land on a missing file and blank the slot.
	var usable: Array = []
	for p in pool:
		if ResourceLoader.exists(p):
			usable.append(p)
	if usable.is_empty():
		usable = pool
	if usable.size() == 1 or character_id.is_empty():
		return usable[0]
	var idx: int = absi(character_id.hash()) % usable.size()
	return usable[idx]


static func has_figure(species_id: String) -> bool:
	return not get_figures_for(species_id).is_empty()


static func all_species_with_figures() -> Array:
	return FIGURES.keys()
