class_name OnboardItemService
extends RefCounted

## On-board Items — Core Rules pp.57-58.
##
## "These items are not carried into battle by a specific crew member. Instead,
## they are usually left behind on the ship, and used at other points of the
## campaign turn." (p.57)
##
## THE DEFECT THIS CLOSES (audit row 98): all 19 items were loaded into
## `EquipmentManager._onboard_items` and exposed by `get_onboard_item_effect()`,
## whose ONLY caller repo-wide lived in `src/core/campaign/phases/TravelPhase.gd`
## — a file with zero instantiations. So every on-board item in the Stash was
## inert: a Purifier produced nothing, Repair Bot added nothing to a Repair, a
## Teach-bot taught nothing. The data was complete and byte-exact against the
## book; nothing ever asked it a question.
##
## WHY A SERVICE AND NOT MORE METHODS ON EquipmentManager:
## these effects are read from a dozen unrelated rule sites (Repair Your Kit,
## Recruit, Train, licences, Upkeep, the Quest roll). One SSOT that every site
## calls is the only shape that survives the "guard applied to N-1 of N sites"
## failure this codebase keeps hitting.
##
## CREDITS ARE NEVER WRITTEN HERE. Per the Data Ownership table, credits are
## owned by FiveParsecsCampaignCore and mutated through GameStateManager. This
## service RETURNS a credit delta and the caller applies it, so the ownership
## lint stays clean and no `# lint:ignore` is needed.
##
## Usage:
##   var bonus := OnboardItemService.repair_bonus(campaign)   # {value, sources}
##   if OnboardItemService.has_item(campaign, "fake_id"): ...
##   OnboardItemService.consume(campaign, "teach_bot")

const DATA_PATH := "res://data/onboard_items.json"

## Turn-stamp key for the once-per-turn income step (Purifier + the two dice).
const INCOME_TURN_KEY := "onboard_income_turn"

static var _items: Array = []
static var _loaded: bool = false


# MARK: - Data

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not file:
		push_warning("OnboardItemService: %s not found" % DATA_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("OnboardItemService: failed to parse %s" % DATA_PATH)
		return
	if json.data is Dictionary:
		_items = (json.data as Dictionary).get("onboard_items", [])


## Every on-board item definition (pp.57-58).
static func all() -> Array:
	_load()
	return _items


## Definition for an id, or {} if the id is not an on-board item.
static func definition(item_id: String) -> Dictionary:
	for entry in all():
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			return entry
	return {}


## Is this id one of the 19 on-board items?
static func is_onboard_item(item_id: String) -> bool:
	return not definition(item_id).is_empty()


## Stash items carry display NAMES ("Lucky Dice"); the book table is keyed by id
## ("lucky_dice"). Normalises either spelling to the id, or "" if it is not an
## on-board item at all. Matching on the normalised form rather than on the raw
## name is what lets a looted, purchased or hand-typed item all resolve.
static func normalize_id(name_or_id: String) -> String:
	var slug: String = name_or_id.strip_edges().to_lower().replace(" ", "_") \
		.replace("-", "_").replace("'", "")
	if is_onboard_item(slug):
		return slug
	# A few book names do not slugify to their id (the JSON abbreviates).
	match slug:
		"genetic_reconfiguration_kit", "genetic_reconfig_kit":
			return "genetic_reconfiguration_kit"
		"mk_2_translator", "mkii_translator":
			return "mk_ii_translator"
		"medpatch":
			return "med_patch"
		"nanodoc":
			return "nano_doc"
		_:
			return ""


# MARK: - Stash queries

static func _stash(campaign: Variant) -> Array:
	if campaign == null or not ("equipment_data" in campaign):
		return []
	var data: Variant = campaign.equipment_data
	if not (data is Dictionary):
		return []
	var items: Variant = (data as Dictionary).get("equipment", null)
	return items if items is Array else []


## Every stash index holding the given on-board item id.
static func indices_in_stash(campaign: Variant, item_id: String) -> Array[int]:
	var out: Array[int] = []
	var stash: Array = _stash(campaign)
	for i in range(stash.size()):
		var entry: Variant = stash[i]
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		var resolved: String = normalize_id(str(d.get("id", "")))
		if resolved.is_empty():
			resolved = normalize_id(str(d.get("name", "")))
		if resolved == item_id:
			out.append(i)
	return out


static func has_item(campaign: Variant, item_id: String) -> bool:
	return not indices_in_stash(campaign, item_id).is_empty()


static func count_in_stash(campaign: Variant, item_id: String) -> int:
	return indices_in_stash(campaign, item_id).size()


## Remove one copy from the Stash. Used for the "Single-use." items and for the
## two that "can be lost" (Loaded/Lucky Dice on a 6, Spare Parts on a natural 1).
## Returns true if a copy was actually removed.
static func consume(campaign: Variant, item_id: String) -> bool:
	var idx: Array[int] = indices_in_stash(campaign, item_id)
	if idx.is_empty():
		return false
	var stash: Array = _stash(campaign)
	stash.remove_at(idx[0])
	return true


## Every on-board item currently in the Stash, as {id, name, description,
## single_use}. Drives the "Use On-board Item" list.
static func in_stash(campaign: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stash: Array = _stash(campaign)
	for entry in stash:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		var resolved: String = normalize_id(str(d.get("id", "")))
		if resolved.is_empty():
			resolved = normalize_id(str(d.get("name", "")))
		if resolved.is_empty():
			continue
		var def: Dictionary = definition(resolved)
		out.append({
			"id": resolved,
			"name": str(def.get("name", d.get("name", resolved))),
			"description": str(def.get("description", "")),
			"single_use": bool(def.get("single_use", false)),
		})
	return out


# MARK: - Passive bonuses (no player decision — the item simply applies)

## Repair Bot "+1 to all Repair attempts" + Spare parts "Add +1 when making a
## Repair attempt" (p.58). Both are flat and both stack — they are separate
## items with separate entries, and the book gives no non-stacking clause.
## Returns {value: int, sources: Array[String], spare_parts: bool}.
static func repair_bonus(campaign: Variant) -> Dictionary:
	var value: int = 0
	var sources: Array[String] = []
	var uses_spare_parts: bool = false
	if has_item(campaign, "repair_bot"):
		value += 1
		sources.append("+1 Repair Bot")
	if has_item(campaign, "spare_parts"):
		value += 1
		uses_spare_parts = true
		sources.append("+1 Spare Parts")
	return {"value": value, "sources": sources, "spare_parts": uses_spare_parts}


## Fake ID "+1 to all attempts to obtain a license or other legal document" (p.57).
static func license_bonus(campaign: Variant) -> int:
	return 1 if has_item(campaign, "fake_id") else 0


## Sector permit: "Whenever you arrive at a planet where a license is required,
## roll 1D6. On a 4+, the Sector Permit is accepted." (p.58)
## Rolls when the permit is present. Returns {applies, roll, accepted}.
static func roll_sector_permit(campaign: Variant) -> Dictionary:
	if not has_item(campaign, "sector_permit"):
		return {"applies": false, "roll": 0, "accepted": false}
	var roll: int = randi_range(1, 6)
	return {"applies": true, "roll": roll, "accepted": roll >= 4}


## Analyzer "+1 when rolling to see if Rumors result in a Quest and when rolling
## for Quest resolution" (p.57).
static func quest_roll_bonus(campaign: Variant) -> int:
	return 1 if has_item(campaign, "analyzer") else 0


## Mk II translator "When rolling to Recruit, you may roll an additional D6" (p.58).
## Returns the number of EXTRA dice, not a flat bonus — the book says an extra
## die, and with a 6+ target an extra die is materially better than +1.
static func recruit_extra_dice(campaign: Variant) -> int:
	return 1 if has_item(campaign, "mk_ii_translator") else 0


## Teach-bot "A character engaging in the Train crew task will earn 1D6
## additional XP. Single-use." (p.58)
## Rolls AND consumes. Returns 0 when absent. Call once per Train resolution.
static func consume_teach_bot(campaign: Variant) -> int:
	if not has_item(campaign, "teach_bot"):
		return 0
	if not consume(campaign, "teach_bot"):
		return 0
	return randi_range(1, 6)


## Genetic reconfiguration kit "Reduce the cost of an ability score upgrade by
## 2 XP. Has no effect on Bots or Soulless. K'Erin may only use this to increase
## Toughness. Single-use." (p.57)
## Pure eligibility test — the caller consumes only if the upgrade goes through.
static func genetic_kit_allows(species_id: String, is_bot: bool, is_soulless: bool,
		stat_name: String) -> bool:
	if is_bot or is_soulless:
		return false
	var species: String = species_id.strip_edges().to_lower()
	if species == "bot" or species == "soulless":
		return false
	if species == "kerin" or species == "k_erin" or species == "kerin_colonist":
		return stat_name.strip_edges().to_lower() == "toughness"
	return true


# MARK: - Once-per-turn income (p.58 Purifier, Lucky dice, Loaded dice)

static func _progress(campaign: Variant) -> Dictionary:
	if campaign == null or not ("progress_data" in campaign):
		return {}
	var pd: Variant = campaign.progress_data
	return pd if pd is Dictionary else {}


static func income_available(campaign: Variant, turn: int) -> bool:
	var pd: Dictionary = _progress(campaign)
	if pd.is_empty():
		return false
	if int(pd.get(INCOME_TURN_KEY, -1)) == turn:
		return false
	return has_item(campaign, "purifier") \
		or has_item(campaign, "lucky_dice") \
		or has_item(campaign, "loaded_dice")


## Resolve the three "Each campaign turn" items in one step.
##
## Purifier (p.58): "Each campaign turn, the Purifier can be used to generate
## clean water which can be sold off for 1 credit... only one Purifier may be
## used at a time." — so the credit is 1 however many Purifiers are aboard.
##
## Lucky dice (p.58): "+1 credit."
## Loaded dice (p.58): "Roll 1D6. On a 1-4, earn that many credits. On a 5, earn
## nothing. On a 6... The dice are lost and the crew member must roll on the
## post-battle Injury Table."
## "If you have both Lucky and Loaded Dice, you can use both, but rolling a 6 for
## the Loaded dice means you lose BOTH sets of dice."
##
## Returns {credits, lines, injury_roll_required, lost}. Credits are NOT applied
## here — the caller writes them through GameStateManager (see the header note).
static func resolve_turn_income(campaign: Variant, turn: int) -> Dictionary:
	var out: Dictionary = {
		"credits": 0, "lines": [], "injury_roll_required": false, "lost": [],
	}
	if not income_available(campaign, turn):
		return out
	var lines: Array[String] = []
	var lost: Array[String] = []
	var credits: int = 0

	if has_item(campaign, "purifier"):
		credits += 1
		lines.append("Purifier: clean water sold for 1 credit.")

	var had_lucky: bool = has_item(campaign, "lucky_dice")
	if had_lucky:
		credits += 1
		lines.append("Lucky Dice: gambled on the side for +1 credit.")

	if has_item(campaign, "loaded_dice"):
		var roll: int = randi_range(1, 6)
		if roll <= 4:
			credits += roll
			lines.append("Loaded Dice: rolled %d — earned %d credits." % [roll, roll])
		elif roll == 5:
			lines.append("Loaded Dice: rolled 5 — earned nothing.")
		else:
			# p.58: a 6 loses the Loaded dice, AND the Lucky dice if both were used.
			lines.append("Loaded Dice: rolled 6 — the locals do not take kindly to"
				+ " losing. The dice are lost and the gambler must roll on the"
				+ " post-battle Injury Table.")
			if consume(campaign, "loaded_dice"):
				lost.append("Loaded Dice")
			if had_lucky and consume(campaign, "lucky_dice"):
				lost.append("Lucky Dice")
			out["injury_roll_required"] = true

	var pd: Dictionary = _progress(campaign)
	if not pd.is_empty():
		pd[INCOME_TURN_KEY] = turn

	out["credits"] = credits
	out["lines"] = lines
	out["lost"] = lost
	return out


# MARK: - Colonist ration packs (p.57)

## "Ignore Upkeep costs for one campaign turn. +1 story point. Single-use."
## Consumes the packs and reports what the caller must apply.
static func consume_ration_packs(campaign: Variant) -> Dictionary:
	if not has_item(campaign, "colonist_ration_packs"):
		return {"used": false}
	if not consume(campaign, "colonist_ration_packs"):
		return {"used": false}
	return {"used": true, "ignore_upkeep": true, "story_points": 1}


# MARK: - Player-chosen single-use items
#
# Ten of the nineteen items are "Single-use." and require a decision the book
# leaves to the player ("You must decide before rolling the dice", "Give to any
# character that isn't Soulless, K'Erin, or a Bot"). They are surfaced by
# OnboardItemUseDialog; the rules live here so they are testable without the UI.
#
# Three of them cannot resolve at the moment they are chosen — they modify a roll
# that happens later — so choosing them ARMS a flag their own system consumes:
#   nano_doc                     -> ARMED_INJURY_KEY, read by InjuryProcessor
#   genetic_reconfiguration_kit  -> ARMED_XP_KEY,     read by the XP spend
#   colonist_ration_packs        -> ARMED_UPKEEP_KEY, read by UpkeepPhaseComponent
# Arming is the honest model: p.58's Nano-doc explicitly says the decision comes
# BEFORE the dice, so a "use it now" button that silently waited would be wrong.

const ARMED_INJURY_KEY := "onboard_nano_doc_armed"
const ARMED_XP_KEY := "onboard_genetic_kit_armed"
const ARMED_UPKEEP_KEY := "onboard_ignore_upkeep_turn"

## What kind of target the player must pick before an item can be used.
## "" = none, "character", "damaged_item", "stash_item".
static func target_kind(item_id: String) -> String:
	match item_id:
		"transcender", "novelty_stuffed_animal", "med_patch":
			return "character"
		"fixer":
			return "damaged_item"
		"duplicator":
			return "stash_item"
		_:
			return ""


## The single-use items the player elects to use, filtered to those in the Stash.
static func usable_items(campaign: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in in_stash(campaign):
		if not bool(entry.get("single_use", false)):
			continue
		var eid: String = str(entry.get("id", ""))
		# The Fixer is single-use but is spent through Repair Your Kit's own flow.
		var row: Dictionary = entry.duplicate()
		row["target_kind"] = target_kind(eid)
		out.append(row)
	return out


static func is_nano_doc_armed(campaign: Variant) -> bool:
	return bool(_progress(campaign).get(ARMED_INJURY_KEY, false))


## Spend the armed Nano-doc. p.58: "Prevent one roll on the post-battle Injury
## Table, no matter the source of the injury." ONE roll, so the flag clears.
static func consume_armed_nano_doc(campaign: Variant) -> bool:
	var pd: Dictionary = _progress(campaign)
	if pd.is_empty() or not bool(pd.get(ARMED_INJURY_KEY, false)):
		return false
	pd.erase(ARMED_INJURY_KEY)
	return true


static func is_genetic_kit_armed(campaign: Variant) -> bool:
	return bool(_progress(campaign).get(ARMED_XP_KEY, false))


## Spend the armed Genetic reconfiguration kit (-2 XP on ONE ability upgrade).
## Caller must have already checked genetic_kit_allows() for the target.
static func consume_armed_genetic_kit(campaign: Variant) -> bool:
	var pd: Dictionary = _progress(campaign)
	if pd.is_empty() or not bool(pd.get(ARMED_XP_KEY, false)):
		return false
	pd.erase(ARMED_XP_KEY)
	return true


## True while Colonist ration packs are covering this campaign turn's Upkeep.
static func upkeep_is_waived(campaign: Variant, turn: int) -> bool:
	var pd: Dictionary = _progress(campaign)
	if pd.is_empty():
		return false
	return int(pd.get(ARMED_UPKEEP_KEY, -1)) == turn


## Apply a player-chosen single-use item.
##
## Returns {ok, summary, story_points, xp_targets, armed}. `story_points` and
## `xp_targets` are handed BACK rather than written, for the same
## data-ownership reason credits are (see the header): a static service must not
## reach into GameStateManager.
##
## `turn` is only read by colonist_ration_packs, which is scoped to one turn.
static func use(
	campaign: Variant, item_id: String, target: Variant = null, turn: int = 0,
	crew: Array = []
) -> Dictionary:
	var fail: Dictionary = {"ok": false, "summary": "", "story_points": 0,
		"xp_targets": [], "armed": ""}
	if not has_item(campaign, item_id):
		return fail

	match item_id:
		"meditation_orb":
			# p.58: "+2 story points. All Swift or Precursor in the crew may also
			# add +1 XP." Crew-wide, no target.
			if not consume(campaign, item_id):
				return fail
			var blessed: Array = []
			for member in crew:
				if _species_of(member) in ["swift", "precursor"]:
					blessed.append(_id_of(member))
			return {
				"ok": true, "story_points": 2, "xp_targets": _xp_list(blessed, 1),
				"armed": "",
				"summary": "Meditation Orb: +2 story points."
					+ ("" if blessed.is_empty()
						else " %d Swift/Precursor crew gain +1 XP." % blessed.size()),
			}

		"transcender":
			# p.58: "The character activating this mysterious device receives
			# +1 XP... Add +2 story points."
			if target == null or not consume(campaign, item_id):
				return fail
			return {
				"ok": true, "story_points": 2,
				"xp_targets": _xp_list([_id_of(target)], 1), "armed": "",
				"summary": "Transcender: %s gains +1 XP; the crew gains +2 story points."
					% _name_of(target),
			}

		"novelty_stuffed_animal":
			# p.58: "Give to any character that isn't Soulless, K'Erin, or a Bot.
			# The character receives +1 XP, and may roll 1D6. On a 6, you may add
			# +1 story point as well."
			if target == null or not stuffed_animal_allows(target):
				return fail
			if not consume(campaign, item_id):
				return fail
			var d6: int = randi_range(1, 6)
			return {
				"ok": true, "story_points": 1 if d6 == 6 else 0,
				"xp_targets": _xp_list([_id_of(target)], 1), "armed": "",
				"summary": "Novelty Stuffed Animal: %s gains +1 XP. Rolled %d%s."
					% [_name_of(target), d6,
						" — +1 story point" if d6 == 6 else ""],
			}

		"med_patch":
			# p.58: "A character recovering from an Injury may subtract one
			# campaign turn from the recovery duration required."
			if target == null or not consume(campaign, item_id):
				return fail
			return {
				"ok": true, "story_points": 0, "xp_targets": [], "armed": "",
				"summary": "Med-patch: %s recovers one campaign turn sooner."
					% _name_of(target),
			}

		"colonist_ration_packs":
			var packs: Dictionary = consume_ration_packs(campaign)
			if not bool(packs.get("used", false)):
				return fail
			var pd: Dictionary = _progress(campaign)
			if not pd.is_empty():
				pd[ARMED_UPKEEP_KEY] = turn
			return {
				"ok": true, "story_points": 1, "xp_targets": [],
				"armed": ARMED_UPKEEP_KEY,
				"summary": "Colonist Ration Packs: Upkeep is waived this campaign"
					+ " turn. +1 story point.",
			}

		"nano_doc":
			if not consume(campaign, item_id):
				return fail
			var pd_n: Dictionary = _progress(campaign)
			if not pd_n.is_empty():
				pd_n[ARMED_INJURY_KEY] = true
			return {
				"ok": true, "story_points": 0, "xp_targets": [],
				"armed": ARMED_INJURY_KEY,
				"summary": "Nano-doc: armed. The next post-battle Injury Table roll"
					+ " is prevented, whatever its source (p.58).",
			}

		"genetic_reconfiguration_kit":
			if not consume(campaign, item_id):
				return fail
			var pd_g: Dictionary = _progress(campaign)
			if not pd_g.is_empty():
				pd_g[ARMED_XP_KEY] = true
			return {
				"ok": true, "story_points": 0, "xp_targets": [],
				"armed": ARMED_XP_KEY,
				"summary": "Genetic Reconfiguration Kit: armed. The next ability"
					+ " score upgrade costs 2 XP less (not Bots or Soulless;"
					+ " K'Erin may only raise Toughness).",
			}

		"duplicator":
			# p.57: "Create a perfect copy of any one item in your inventory. A
			# Duplicator cannot copy a Duplicator."
			if not (target is Dictionary):
				return fail
			var src: Dictionary = target
			if normalize_id(str(src.get("name", src.get("id", "")))) == "duplicator":
				return fail
			if not consume(campaign, item_id):
				return fail
			var copy: Dictionary = src.duplicate(true)
			copy["id"] = "dup_%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
			_stash(campaign).append(copy)
			return {
				"ok": true, "story_points": 0, "xp_targets": [], "armed": "",
				"summary": "Duplicator: a perfect copy of %s is now in the Stash."
					% str(src.get("name", "the item")),
			}

		_:
			return fail


## p.58 Novelty stuffed animal: "Give to any character that isn't Soulless,
## K'Erin, or a Bot."
static func stuffed_animal_allows(member: Variant) -> bool:
	if member == null:
		return false
	if member is Dictionary:
		var d: Dictionary = member
		if bool(d.get("is_bot", false)) or bool(d.get("is_soulless", false)):
			return false
	else:
		if "is_bot" in member and bool(member.is_bot):
			return false
		if "is_soulless" in member and bool(member.is_soulless):
			return false
	return not (_species_of(member) in ["soulless", "kerin", "k_erin", "bot"])


static func _species_of(member: Variant) -> String:
	if member == null:
		return ""
	var raw: Variant = null
	if member is Dictionary:
		var d: Dictionary = member
		raw = d.get("species_id", d.get("origin", ""))
	elif "species_id" in member:
		raw = member.species_id
	elif "origin" in member:
		raw = member.origin
	# str() guard: legacy saves persist `origin` as a numeric enum (a float), and
	# .to_lower() on a float ABORTS the calling function rather than erroring.
	return str(raw).to_lower().replace("'", "").replace(" ", "_")


static func _id_of(member: Variant) -> String:
	if member is Dictionary:
		var d: Dictionary = member
		return str(d.get("id", d.get("character_id", "")))
	if member == null:
		return ""
	if "character_id" in member:
		return str(member.character_id)
	return str(member.get_instance_id()) if member is Object else ""


static func _name_of(member: Variant) -> String:
	if member is Dictionary:
		var d: Dictionary = member
		return str(d.get("character_name", d.get("name", "The character")))
	if member != null and "character_name" in member:
		return str(member.character_name)
	return "The character"


static func _xp_list(ids: Array, amount: int) -> Array:
	var out: Array = []
	for cid in ids:
		if str(cid).is_empty():
			continue
		out.append({"character_id": str(cid), "xp": amount})
	return out
