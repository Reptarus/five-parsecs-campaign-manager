extends RefCounted
class_name IconRegistry

## Maps game concepts to Lorc RPG icon assets (Assets/789_Lorc_RPG_icons/)
## Usage: var tex = IconRegistry.get_icon("stat", "savvy")
## All icons are monochrome white-on-black PNGs. Tint via modulate.

const ICON_BASE := "res://Assets/789_Lorc_RPG_icons/"

# Icon mapping: category -> { key -> filename }
const ICON_MAP := {
	# ── Character Stats ──────────────────────────────────────────────────
	"stat": {
		"combat": "Icon.5_50.png",       # Explosion/burst
		"reaction": "Icon.1_10.png",     # Mechanical eye
		"toughness": "Icons8_10.png",    # Shield/crest
		"speed": "Icon.3_50.png",        # Turbine/motion
		"savvy": "Icon.7_20.png",        # Brain
		"luck": "Icon.4_40.png",         # Star burst
		"xp": "Icon.5_10.png",          # Medal
		"health": "Icon.1_01.png",       # Heart (broken)
		"morale": "Icon.1_30.png",       # Yin-yang orbs
	},

	# ── Status Effects ───────────────────────────────────────────────────
	"status": {
		"wounded": "Icon.1_01.png",      # Broken heart
		"dead": "Icon.2_50.png",         # Crossed bones
		"stunned": "Icons8_30.png",      # Spiral
		"healthy": "Icon.1_30.png",      # Orbs/balance
		"leader": "Icon.1_05.png",       # Knight helmet
	},

	# ── Campaign Phases ──────────────────────────────────────────────────
	"phase": {
		"story": "Icon.7_20.png",        # Brain/narrative
		"travel": "Icons8_50.png",       # Bird/flight
		"upkeep": "Icon.6_50.png",       # Needle/repair
		"mission": "Icon.4_40.png",      # Star/target
		"battle": "Icon.5_50.png",       # Explosion
		"post_battle": "Icon.5_10.png",  # Medal/aftermath
		"advancement": "Icon.1_30.png",  # Orbs/growth
		"trading": "Icon.2_15.png",      # Apple/goods
		"character": "Icon.1_05.png",    # Helmet/persona
		"retirement": "Icons8_50.png",   # Bird/freedom
		"world": "Icon.1_20.png",        # Vortex/exploration
		"loot": "Icon.4_40.png",         # Star/treasure
		"end_turn": "Icon.5_10.png",     # Medal/completion
	},

	# ── Equipment Categories ─────────────────────────────────────────────
	"equipment": {
		"weapon": "Icon.7_50.png",       # Sword
		"melee": "Icon.4_10.png",        # Axe
		"ranged": "Icon.5_50.png",       # Explosion/blast
		"armor": "Icons8_10.png",        # Shield/crest
		"gear": "Icon.6_50.png",         # Needle/utility
		"implant": "Icon.7_20.png",      # Brain/cybernetic
		"credits": "Icon.4_40.png",      # Star burst
	},

	# ── Mission Types ────────────────────────────────────────────────────
	"mission_type": {
		"stealth": "Icon.6_10.png",      # Masked face
		"street_fight": "Icon.5_50.png", # Explosion
		"salvage": "Icon.6_50.png",      # Utility/repair
		"patrol": "Icon.1_10.png",       # Eye/surveillance
		"patron": "Icon.5_10.png",       # Medal/contract
	},

	# ── Character Classes (portraits) ────────────────────────────────────
	"class": {
		"none": "Icon.1_05.png",           # Knight helmet (default)
		"working_class": "Icon.6_50.png",  # Needle/tools
		"technician": "Icon.6_50.png",     # Needle/repair
		"scientist": "Icon.7_20.png",      # Brain
		"hacker": "Icon.7_20.png",         # Brain/tech
		"soldier": "Icon.1_05.png",        # Knight helmet
		"mercenary": "Icon.7_50.png",      # Sword
		"agitator": "Icon.1_01.png",       # Broken heart/passion
		"primitive": "Icon.4_10.png",      # Axe
		"artist": "Icon.1_30.png",         # Orbs/creativity
		"negotiator": "Icon.2_15.png",     # Apple/diplomacy
		"trader": "Icon.2_15.png",         # Apple/goods
		"starship_crew": "Icon.3_50.png",  # Turbine/engine
		"petty_criminal": "Icon.6_10.png", # Masked face
		"ganger": "Icon.3_25.png",         # Chains
		"scoundrel": "Icon.6_10.png",      # Masked face
		"enforcer": "Icons8_10.png",       # Shield/authority
		"special_agent": "Icon.1_10.png",  # Eye/surveillance
		"troubleshooter": "Icon.5_50.png", # Explosion/action
		"bounty_hunter": "Icon.1_10.png",  # Eye/tracking
		"nomad": "Icons8_50.png",          # Bird/wanderer
		"explorer": "Icons8_50.png",       # Bird/explorer
		"punk": "Icon.3_25.png",           # Chains/rebellion
		"scavenger": "Icon.6_50.png",      # Needle/salvage
	},

	# ── UI Actions ───────────────────────────────────────────────────────
	"action": {
		"save": "Icons8_10.png",           # Shield/protect
		"export": "Icons8_50.png",         # Bird/send
		"import": "Icon.3_25.png",         # Chains/link
		"new_campaign": "Icon.4_40.png",   # Star/new
		"continue": "Icon.1_30.png",       # Orbs/continue
		"settings": "Icon.6_50.png",       # Needle/configure
		"dlc": "Icon.5_10.png",            # Medal/premium
		"history": "Icon.7_20.png",        # Brain/memory
		"journal": "Icon.7_20.png",        # Brain/records
	},

	# ── Species ──────────────────────────────────────────────────────────
	"species": {
		"human": "Icon.1_05.png",          # Knight helmet
		"krag": "Icon.3_25.png",           # Chains/tough
		"skulker": "Icon.6_10.png",        # Masked face/sneaky
		"bot": "Icon.3_50.png",            # Turbine/mechanical
		"precursor": "Icon.7_20.png",      # Brain/ancient
		"soulless": "Icon.1_10.png",       # Eye/mechanical
	},
}

static var _cache: Dictionary = {}

static func get_icon(category: String, key: String) -> Texture2D:
	var cache_key := category + ":" + key
	if _cache.has(cache_key):
		return _cache[cache_key]

	if not ICON_MAP.has(category):
		return null
	var cat: Dictionary = ICON_MAP[category]
	if not cat.has(key):
		return null

	var path: String = ICON_BASE + cat[key]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[cache_key] = tex
		return tex
	return null

static func get_icon_path(category: String, key: String) -> String:
	if ICON_MAP.has(category) and ICON_MAP[category].has(key):
		return ICON_BASE + str(ICON_MAP[category][key])
	return ""

static func has_icon(category: String, key: String) -> bool:
	return ICON_MAP.has(category) and ICON_MAP[category].has(key)
