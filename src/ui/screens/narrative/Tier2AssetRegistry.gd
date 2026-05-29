## Tier2AssetRegistry — named-asset map for non-figure scene fragments.
##
## SceneStage's `character_slots` was designed for uniform humanoid figures
## resolved through SpeciesFigureRegistry (feet at bottom-center). The
## Planetfall asset delivery includes wider scene-fragment compositions that
## don't fit that contract — a 6000x3500 Stalker, the 5152x3192 Engineer Twins,
## a 1920x1120 Hulker. They want different anchoring (center/top-left) and
## render as scene-foreground rather than figures behind actor layers.
##
## A scene slot can opt into this path by setting `anchor_mode != "feet"`, and
## the assignment supplies `source` instead of `species_id`. `source` may be:
##   - A direct `res://...` path
##   - A `tier2:<key>` shorthand resolved through this registry
##
## Paths are guard-loaded with ResourceLoader.exists(); missing assets degrade
## to an empty slot (no warning spam), so a manifest can declare a slot for an
## asset that hasn't shipped yet without breaking the runtime.
##
## Path-loaded — no class_name to keep load order clean.
extends RefCounted

## Named-asset map. Values use res:// paths under `assets/scenes/tier2/` —
## copy/rename the Planetfall source PNGs into that folder to populate.
##
## Keys are stable IDs that survive PNG renames; consumers (scene manifests,
## test scripts) reference `tier2:<key>` not the raw path.
const NAMED_ASSETS := {
	"planetfall_stalker":        "res://assets/scenes/tier2/stalker.png",
	"planetfall_engineer_twins": "res://assets/scenes/tier2/engineer_twins.png",
	"planetfall_hulker_wide":    "res://assets/scenes/tier2/hulker_wide.png",
}


static func resolve(source: String) -> String:
	if source.is_empty():
		return ""
	if source.begins_with("res://"):
		return source
	if source.begins_with("tier2:"):
		var key := source.substr(6)
		return NAMED_ASSETS.get(key, "")
	# Bare key (no scheme) is treated as a tier2 key for convenience.
	return NAMED_ASSETS.get(source, "")


static func get_keys() -> Array:
	return NAMED_ASSETS.keys()


static func has_key(key: String) -> bool:
	return NAMED_ASSETS.has(key)
