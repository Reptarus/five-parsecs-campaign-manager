class_name DLCContentCatalog
extends RefCounted

## Single source of truth for all DLC marketing copy and feature descriptions.
## Publisher-reviewable: all player-facing text lives here.
## Used by StoreScreen, DLCPackCard, DLCUpsellBanner, and ExpansionFeatureSection.

# ── Pack Catalog ──────────────────────────────────────────────────

const PACK_CATALOG: Dictionary = {
	"trailblazers_toolkit": {
		"name": "Trailblazer's Toolkit",
		"tagline": "Unlock alien species, psionics, and advanced gear",
		"description": (
			"Expand your crew with two new alien species — the brutal Krag"
			+ " and cunning Skulker. Unlock the Psionics system for"
			+ " mind-bending abilities, advanced training options, bot"
			+ " upgrades, new ship components, and psionic equipment."
		),
		"price_default": "$4.99",
		"categories": [
			{
				"name": "New Species",
				"features": [
					{
						"flag": "SPECIES_KRAG",
						"label": "Krag Species",
						"preview": "Hulking alien bruisers with natural armor",
					},
					{
						"flag": "SPECIES_SKULKER",
						"label": "Skulker Species",
						"preview": "Stealthy aliens with enhanced reflexes",
					},
				],
			},
			{
				"name": "Psionics",
				"features": [
					{
						"flag": "PSIONICS",
						"label": "Psionics System",
						"preview": "Psychic powers for crew members",
					},
					{
						"flag": "PSIONIC_EQUIPMENT",
						"label": "Psionic Equipment",
						"preview": "Gear that channels psionic energy",
					},
				],
			},
			{
				"name": "Crew Upgrades",
				"features": [
					{
						"flag": "NEW_TRAINING",
						"label": "Advanced Training",
						"preview": "Additional training courses for crew",
					},
					{
						"flag": "BOT_UPGRADES",
						"label": "Bot Upgrades",
						"preview": "Enhanced modifications for bot crew",
					},
					{
						"flag": "NEW_SHIP_PARTS",
						"label": "New Ship Parts",
						"preview": "Additional components for your ship",
					},
				],
			},
		],
	},
	"freelancers_handbook": {
		"name": "Freelancer's Handbook",
		"tagline": "Master combat variants, difficulty options, and new missions",
		"description": (
			"The ultimate combat expansion. Progressive difficulty scales"
			+ " with your crew's power. Deploy with new variables, face"
			+ " elite enemies, tackle expanded missions and quests,"
			+ " or try no-minis and grid-based combat for a fresh"
			+ " tactical experience."
		),
		"price_default": "$7.99",
		"categories": [
			{
				"name": "Difficulty & Scaling",
				"features": [
					{
						"flag": "PROGRESSIVE_DIFFICULTY",
						"label": "Progressive Difficulty",
						"preview": "Enemies scale with campaign progress",
					},
					{
						"flag": "DIFFICULTY_TOGGLES",
						"label": "Difficulty Toggles",
						"preview": "Fine-tune challenge with toggle options",
					},
					{
						"flag": "ELITE_ENEMIES",
						"label": "Elite Enemies",
						"preview": "Tougher foes with special abilities",
					},
					{
						"flag": "ESCALATING_BATTLES",
						"label": "Escalating Battles",
						"preview": "Reinforcements and rising tension",
					},
				],
			},
			{
				"name": "Combat Variants",
				"features": [
					{
						"flag": "DRAMATIC_COMBAT",
						"label": "Dramatic Combat",
						"preview": "Cinematic combat with narrative beats",
					},
					{
						"flag": "NO_MINIS_COMBAT",
						"label": "No-Minis Combat",
						"preview": "Play without miniatures or a grid",
					},
					{
						"flag": "GRID_BASED_MOVEMENT",
						"label": "Grid-Based Movement",
						"preview": "Square grid tactical movement",
					},
					{
						"flag": "AI_VARIATIONS",
						"label": "AI Variations",
						"preview": "Varied enemy behavior patterns",
					},
					{
						"flag": "DEPLOYMENT_VARIABLES",
						"label": "Deployment Variables",
						"preview": "Randomized deployment conditions",
					},
					{
						"flag": "TERRAIN_GENERATION",
						"label": "Terrain Generation",
						"preview": "Procedural battlefield terrain",
					},
				],
			},
			{
				"name": "Missions & Connections",
				"features": [
					{
						"flag": "EXPANDED_MISSIONS",
						"label": "Expanded Missions",
						"preview": "Additional mission types and objectives",
					},
					{
						"flag": "EXPANDED_QUESTS",
						"label": "Expanded Quests",
						"preview": "More quest chains and storylines",
					},
					{
						"flag": "EXPANDED_CONNECTIONS",
						"label": "Expanded Connections",
						"preview": "Deeper patron and rival relationships",
					},
				],
			},
			{
				"name": "Multiplayer & Casualties",
				"features": [
					{
						"flag": "PVP_BATTLES",
						"label": "PvP Battles",
						"preview": "Crew vs crew competitive play",
					},
					{
						"flag": "COOP_BATTLES",
						"label": "Co-op Battles",
						"preview": "Team up with another player",
					},
					{
						"flag": "CASUALTY_TABLES",
						"label": "Casualty Tables",
						"preview": "Detailed casualty outcomes",
					},
					{
						"flag": "DETAILED_INJURIES",
						"label": "Detailed Injuries",
						"preview": "Expanded injury and recovery system",
					},
				],
			},
		],
	},
	"fixers_guidebook": {
		"name": "Fixer's Guidebook",
		"tagline": "New mission types, factions, and world systems",
		"description": (
			"Take on stealth missions, brutal street fights, and"
			+ " salvage jobs. Build deeper relationships with expanded"
			+ " factions, navigate fringe world politics, manage loans,"
			+ " and use the name generator for richer worldbuilding."
		),
		"price_default": "$4.99",
		"categories": [
			{
				"name": "Mission Types",
				"features": [
					{
						"flag": "STEALTH_MISSIONS",
						"label": "Stealth Missions",
						"preview": "Infiltrate without being detected",
					},
					{
						"flag": "STREET_FIGHTS",
						"label": "Street Fights",
						"preview": "Close-quarters urban combat",
					},
					{
						"flag": "SALVAGE_JOBS",
						"label": "Salvage Jobs",
						"preview": "Scavenge battlefields for loot",
					},
				],
			},
			{
				"name": "World Systems",
				"features": [
					{
						"flag": "EXPANDED_FACTIONS",
						"label": "Expanded Factions",
						"preview": "More factions with unique traits",
					},
					{
						"flag": "FRINGE_WORLD_STRIFE",
						"label": "Fringe World Strife",
						"preview": "Planetary conflict and politics",
					},
					{
						"flag": "EXPANDED_LOANS",
						"label": "Expanded Loans",
						"preview": "Borrow credits with consequences",
					},
					{
						"flag": "NAME_GENERATION",
						"label": "Name Generation",
						"preview": "Procedural names for NPCs and places",
					},
				],
			},
			{
				"name": "Campaign Modes",
				"features": [
					{
						"flag": "INTRODUCTORY_CAMPAIGN",
						"label": "Introductory Campaign",
						"preview": "Guided tutorial campaign for new players",
					},
					{
						"flag": "PRISON_PLANET_CHARACTER",
						"label": "Prison Planet Character",
						"preview": "New character origin with unique story",
					},
				],
			},
		],
	},
}


# ── Bundle Info ───────────────────────────────────────────────────

const BUNDLE_INFO: Dictionary = {
	"name": "Compendium Bundle",
	"tagline": "Get all three expansions and save",
	"description": (
		"The complete Five Parsecs Compendium experience."
		+ " Includes Trailblazer's Toolkit, Freelancer's Handbook,"
		+ " and Fixer's Guidebook — everything you need to unlock"
		+ " every optional rule in the book."
	),
	"price_default": "$14.99",
	"individual_total": "$17.97",
	"savings": "$2.98",
	"included_packs": [
		"trailblazers_toolkit",
		"freelancers_handbook",
		"fixers_guidebook",
	],
}


# ── Bug Hunt Info ─────────────────────────────────────────────────

const BUG_HUNT_INFO: Dictionary = {
	"name": "Bug Hunt",
	"tagline": "Standalone military campaign mode",
	"description": (
		"Lead a military squad against alien infestations."
		+ " A streamlined 3-stage turn structure — no ship, no"
		+ " patrons, just you and your grunts against the swarm."
		+ " Separate from the main campaign with its own"
		+ " creation wizard and save system."
	),
	"price_default": "$2.99",
}


# ── Static Helpers ────────────────────────────────────────────────

static func get_pack_catalog(dlc_id: String) -> Dictionary:
	return PACK_CATALOG.get(dlc_id, {})


static func get_pack_name(dlc_id: String) -> String:
	if dlc_id == "compendium_bundle":
		return BUNDLE_INFO.get("name", "Compendium Bundle")
	if dlc_id == "bug_hunt":
		return BUG_HUNT_INFO.get("name", "Bug Hunt")
	var pack: Dictionary = PACK_CATALOG.get(dlc_id, {})
	return pack.get("name", dlc_id)


static func get_features_for_display(
	dlc_id: String,
) -> Array[Dictionary]:
	## Returns flat array of all features for a pack.
	## Each entry: { flag, label, preview, category }
	var pack: Dictionary = PACK_CATALOG.get(dlc_id, {})
	var categories: Array = pack.get("categories", [])
	var result: Array[Dictionary] = []
	for cat: Variant in categories:
		var cat_dict: Dictionary = cat as Dictionary
		var cat_name: String = cat_dict.get("name", "")
		var features: Array = cat_dict.get("features", [])
		for f: Variant in features:
			var feat: Dictionary = (f as Dictionary).duplicate()
			feat["category"] = cat_name
			result.append(feat)
	return result


static func get_bundle_savings_text() -> String:
	return "Save %s" % BUNDLE_INFO.get("savings", "$2.98")


static func get_feature_preview(flag_name: String) -> String:
	## Look up a feature's preview text by its ContentFlag name.
	for dlc_id: String in PACK_CATALOG:
		var pack: Dictionary = PACK_CATALOG[dlc_id]
		var categories: Array = pack.get("categories", [])
		for cat: Variant in categories:
			var features: Array = (cat as Dictionary).get(
				"features", [])
			for f: Variant in features:
				var feat: Dictionary = f as Dictionary
				if feat.get("flag", "") == flag_name:
					return feat.get("preview", "")
	return ""


static func get_pack_for_flag(flag_name: String) -> String:
	## Look up which DLC pack owns a given flag name.
	for dlc_id: String in PACK_CATALOG:
		var pack: Dictionary = PACK_CATALOG[dlc_id]
		var categories: Array = pack.get("categories", [])
		for cat: Variant in categories:
			var features: Array = (cat as Dictionary).get(
				"features", [])
			for f: Variant in features:
				if (f as Dictionary).get("flag", "") == flag_name:
					return dlc_id
	return ""
