extends RefCounted
## Bot upgrades: what they cost and what they do, read by every surface that sells
## or shows one. No class_name; preload it by path.
##
## Two kinds exist, sold in two places:
##   Core Rules p.123 (sold on the character sheet): "Bot characters may install
##     upgrades to any ability score by paying credits equal to the XP cost. Each
##     ability score can be upgraded only once."
##   Compendium p.26 "New Bot Upgrades" (sold in Trading): "Any of the following
##     upgrades may be applied to a Bot character for the listed cost during
##     post-battle step 11. Purchase Items ...
##     Only one upgrade can be installed per campaign turn. The Bot technician
##     Advanced Training applies to these costs. A Bot character can have one of
##     each upgrade installed over time."
## Core Rules p.125, Bot technician: "All Bot upgrades cost 1 credit less."
##
## All six p.26 upgrades were purchasable and had no consumer, so a Bot paid for
## each and nothing changed. Three change a number the app computes (the built-in
## save, that save against Piercing with the Deflection module, and Seize the
## Initiative); the other three are table rules the player applies, so the sheet
## shows their text.

const EQUIPMENT_PATH := "res://data/equipment_database.json"

const BUILTIN_WEAPON := "builtin_weapon"
const IMPROVED_ARMOR := "improved_armor"
const MULTI_SCANNER := "multi_scanner"
## p.26: the built-in save "becomes both a Screen and Armor".
const DEFLECTION := "deflection_module"

static var _weapons: Dictionary = {}


## p.26 Built-in weapon: "3 Credits per Shot on weapon profile +1 Credit per point
## of weapon Damage." The data file carried `cost: 0` for this row, so it was free.
## Returns -1 for a weapon the equipment database does not know, so a caller can
## refuse it rather than charge a guess.
static func builtin_weapon_cost(weapon_name: String) -> int:
	var profile: Dictionary = weapon_profile(weapon_name)
	if profile.is_empty():
		return -1
	return 3 * int(profile.get("shots", 0)) + int(profile.get("damage", 0))


static func weapon_profile(weapon_name: String) -> Dictionary:
	if _weapons.is_empty():
		var file := FileAccess.open(EQUIPMENT_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for w: Variant in (parsed as Dictionary).get("weapons", []):
					if w is Dictionary:
						_weapons[weapon_key(str(w.get("name", "")))] = w
	return _weapons.get(weapon_key(weapon_name), {})


## The one key a weapon name is looked up by: case, spaces, hyphens, apostrophes
## and dots ignored, so a legacy "Handgun" finds the book's "Hand Gun" and
## "Marksmans Rifle" finds "Marksman's Rifle". No two database weapons share a key.
static func weapon_key(raw: String) -> String:
	var out: String = raw.strip_edges().to_lower()
	for ch in [" ", "-", "'", "’", "."]:
		out = out.replace(ch, "")
	return out


## A Bot that can take a p.26 upgrade: "Soulless characters cannot use these
## upgrades".
static func is_upgradeable(member: Variant) -> bool:
	return bool(_read(member, "is_bot", false)) \
		and not bool(_read(member, "is_soulless", false))


## The weapon names `member` carries: the p.26 Built-in weapon is "any weapon
## available", read here as one the Bot already has.
static func carried_weapons(member: Variant) -> Array[String]:
	var out: Array[String] = []
	var gear: Variant = _read(member, "equipment", [])
	for entry: Variant in (gear if gear is Array else []):
		var weapon: String = str(entry.get("name", "")) if entry is Dictionary \
			else str(entry)
		if not weapon_profile(weapon).is_empty() and weapon not in out:
			out.append(weapon)
	return out


## The ids installed on `member` (a Character or a crew Dictionary).
static func installed(member: Variant) -> Array:
	var ids: Variant = _read(member, "bot_upgrades", [])
	return ids if ids is Array else []


## A Bot (never a Soulless, Compendium p.26) with `upgrade_id` installed.
static func has_upgrade(member: Variant, upgrade_id: String) -> bool:
	if not bool(_read(member, "is_bot", false)) or bool(_read(member, "is_soulless", false)):
		return false
	return upgrade_id in installed(member)


## p.26 Improved armor casing: "Improve the Bot's built-in Armor Saving Throw to 5+."
## The base is 6+ (Core Rules p.15).
static func built_in_save(member: Variant) -> int:
	return 5 if has_upgrade(member, IMPROVED_ARMOR) else 6


## The built-in Armor Saving Throw a figure brings to a battle: Core Rules p.46
## plating (Bot, Soulless, De-converted 6+; Assault Bot 5+), or 5+ for a Bot with
## Improved armor casing. 7 (BattleCalculations.ARMOR_SAVE_NONE) for anyone else.
static func innate_save(member: Variant) -> int:
	if has_upgrade(member, IMPROVED_ARMOR):
		return 5
	var species: String = str(_read(member, "species_id", ""))
	if species.is_empty():
		species = str(_read(member, "origin", ""))
	var save: int = BattleCalculations.get_innate_armor_save(species)
	# A Bot or Soulless whose species key reads otherwise still has its plating.
	if save >= BattleCalculations.ARMOR_SAVE_NONE \
			and (bool(_read(member, "is_bot", false)) or bool(_read(member, "is_soulless", false))):
		save = BattleCalculations.ARMOR_SAVE_LIGHT
	return save


## p.26 Multi-wave scanner: "Add +1 to all rolls to Seize the Initiative.
## Cumulative with a party-carried Motion Tracker." A second scanner on a second Bot
## is not stated to stack, so the crew gets +1 once.
static func seize_bonus(crew: Array) -> int:
	for member: Variant in crew:
		if has_upgrade(member, MULTI_SCANNER):
			return 1
	return 0


static func _read(member: Variant, key: String, fallback: Variant) -> Variant:
	if member is Dictionary:
		return (member as Dictionary).get(key, fallback)
	if member is Object and key in member:
		return member.get(key)
	return fallback
