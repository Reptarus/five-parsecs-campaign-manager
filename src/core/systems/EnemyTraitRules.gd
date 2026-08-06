class_name EnemyTraitRules
extends RefCounted

## The named traits on the encounter tables (Core Rules pp.94-103).
##
## THE GAP THIS FILLS: every entry on the four encounter tables carries its
## trait as a `special_rules` string, and PreBattleUI printed them. Three of them
## are campaign-level rules with real consequences and none of the three had a
## consumer:
##
##   Grudge     (Renegade Soldiers, p.99) "If encountered as Rivals, they bring
##              one additional figure." A Renegade Soldier Rival brought the same
##              force as anyone else, every battle, for the whole campaign.
##   Persistent (Vigilantes, p.99) "If encountered as Rivals, all rolls to remove
##              them from Rival status are at -1." The one enemy in the book
##              designed to be a long-term nuisance was as easy to shake as any
##              other: 50% on a 4+ instead of the intended 33%.
##   Intrigue   (Bounty Hunters, p.99) "Roll 2D6 and add +1 if you killed a
##              Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest
##              Rumor." Since Quest Rumors are how a Quest starts (p.85), this
##              silently closed one of the two doors into the Quest arc.
##
## MATCHING: on the trait NAME before the colon — "Grudge:", "Persistent:",
## "Intrigue:" — which is the book's own identifier for the rule and is stable in
## a way the prose after it is not. Matching the paraphrase instead is how the
## Patron BHC tables ended up needing a second hardcoded copy of themselves.
##
## Note the collision: "Persistent" is ALSO a p.84 Patron Benefit ("Patron
## remains available if you travel"). Different subject, different rule — that
## one lives in PatronJobEffects. Do not merge them.

const ENEMY_TYPES_PATH := "res://data/enemy_types.json"

static var _traits_by_enemy: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(ENEMY_TYPES_PATH, FileAccess.READ)
	if not file:
		push_warning("EnemyTraitRules: cannot open %s" % ENEMY_TYPES_PATH)
		return
	var json := JSON.new()
	var ok: int = json.parse(file.get_as_text())
	file.close()
	if ok != OK or not json.data is Dictionary:
		push_warning("EnemyTraitRules: cannot parse %s" % ENEMY_TYPES_PATH)
		return
	for category in json.data.get("enemy_categories", []):
		if not category is Dictionary:
			continue
		for enemy in category.get("enemies", []):
			if enemy is Dictionary and enemy.has("name"):
				_traits_by_enemy[str(enemy["name"]).to_lower()] = enemy.get(
					"special_rules", [])


## The special_rules strings for an enemy type name ([] if unknown).
static func rules_for(enemy_name: String) -> Array:
	_ensure_loaded()
	var r: Variant = _traits_by_enemy.get(enemy_name.strip_edges().to_lower(), [])
	return r if r is Array else []


## Does this rule list carry the named book trait? Matched on the name before
## the colon, case-insensitively.
static func has_trait(rules: Array, trait_name: String) -> bool:
	var wanted: String = trait_name.strip_edges().to_lower()
	for rule in rules:
		var text: String = str(rule).strip_edges().to_lower()
		if text == wanted or text.begins_with(wanted + ":"):
			return true
	return false


## The same question starting from an enemy type name, which is what the battle
## result and mission data actually carry.
static func enemy_has_trait(enemy_name: String, trait_name: String) -> bool:
	return has_trait(rules_for(enemy_name), trait_name)


# ── The three campaign-level traits ─────────────────────────────────────────

## "Grudge: If encountered as Rivals, they bring one additional figure" (p.99).
## Only when they are fought AS Rivals — a Renegade Soldier opportunity job is an
## ordinary fight.
static func rival_extra_figures(enemy_name: String, is_rival_battle: bool) -> int:
	if not is_rival_battle:
		return 0
	return 1 if enemy_has_trait(enemy_name, "Grudge") else 0


## "Persistent: If encountered as Rivals, all rolls to remove them from Rival
## status are at -1" (p.99). The p.119 removal roll succeeds on a 4+, so this
## makes it an effective 5+.
static func rival_removal_modifier(enemy_name: String) -> int:
	return -1 if enemy_has_trait(enemy_name, "Persistent") else 0


## "Intrigue: Roll 2D6 and add +1 if you killed a Lieutenant and/or Unique
## Individual. On a 9+, you obtain a Quest Rumor" (p.99).
static func has_intrigue(enemy_name: String) -> bool:
	return enemy_has_trait(enemy_name, "Intrigue")


const INTRIGUE_TARGET := 9


## Resolve an Intrigue check from an already-rolled 2D6. Kept RNG-free so the
## caller owns the dice and the rule stays unit-testable.
static func intrigue_succeeds(roll_2d6: int, killed_lieutenant_or_unique: bool) -> bool:
	var total: int = roll_2d6 + (1 if killed_lieutenant_or_unique else 0)
	return total >= INTRIGUE_TARGET


## "Cop killer: If you ever fight Enforcers as Rivals, add +2 to their numbers"
## (Core Rules p.96). Same shape as Grudge but twice the size, and it is the
## book's own punishment for making an enemy of the law.
static func rival_number_bonus(enemy_name: String, is_rival_battle: bool) -> int:
	if not is_rival_battle:
		return 0
	var bonus: int = 0
	if enemy_has_trait(enemy_name, "Grudge"):
		bonus += 1
	if enemy_has_trait(enemy_name, "Cop killer"):
		bonus += 2
	return bonus


## "Scavengers: Roll twice on the Battlefield Finds Table" (pp.97, 100). Returns
## the number of rolls this enemy grants, so a caller can take the larger of this
## and any other source rather than stacking them into a fourth reading.
static func battlefield_finds_rolls(enemy_name: String) -> int:
	return 2 if enemy_has_trait(enemy_name, "Scavengers") else 1


## "Tough fight: A random survivor gains +1 XP" (pp.97, 102).
static func bonus_survivor_xp(enemy_name: String) -> int:
	return 1 if enemy_has_trait(enemy_name, "Tough fight") else 0


## The enemy's own Seize the Initiative modifier, from the CREW's point of view
## (Core Rules pp.95-101). "Careless: You are +1 to Seize the Initiative";
## "Alert: You are -1". Both are stated as modifiers to the player's roll.
##
## The parenthetical totals the book prints for some entries ("for a final
## modifier of 0", "for a total of -2") are the CATEGORY modifier already folded
## in — Hired Muscle is -1 across the board (p.112) — so this returns the trait's
## own contribution only, and the caller adds the category modifier as before.
## Double-counting the parenthetical would silently cancel the category rule.
static func seize_modifier(enemy_name: String) -> int:
	var mod: int = 0
	if enemy_has_trait(enemy_name, "Careless"):
		mod += 1
	if enemy_has_trait(enemy_name, "Alert"):
		mod -= 1
	return mod


## "Prediction: You cannot Seize the Initiative" (p.100, Precursor Exiles) — the
## roll is not made at all, which no modifier can overcome.
static func blocks_seize(enemy_name: String) -> bool:
	return enemy_has_trait(enemy_name, "Prediction")


## "Going medieval: Instead of normal weapons, each carries a Blade. Specialists
## carry a Brutal Melee Weapon" (Core Rules p.99, Primitives). Returns
## [rank_and_file_weapon, specialist_weapon], or [] when the trait is absent.
##
## Both names are entries in equipment_database.json, so the battle math picks up
## their real traits (Blade: Melee; Brutal Melee Weapon: Melee + Clumsy) rather
## than treating them as bare strings.
static func going_medieval_loadout(enemy_name: String) -> Array:
	if not enemy_has_trait(enemy_name, "Going medieval"):
		return []
	return ["Blade", "Brutal Melee Weapon"]


## "Unpredictable: Seize the Initiative roll is always unmodified" (p.100, Swift
## War Swarm). Every modifier is discarded, favourable ones included.
static func seize_is_unmodified(enemy_name: String) -> bool:
	return enemy_has_trait(enemy_name, "Unpredictable")
