class_name PatronJobEffects
extends RefCounted

## Benefits, Hazards and Conditions on a Patron job (Core Rules pp.83-84), plus
## the Time Frame deadline (p.83) that decides when an unfinished job lapses.
##
## THE GAP THIS FILLS: every Patron job played identically. All three categories
## were rolled with the correct per-patron thresholds, forwarded into
## `mission_data`, and rendered by TacticalBattleUI as a "PATRON CONDITIONS"
## block of coloured text — and then consumed by nothing. A "Dangerous Job"
## fielded the same number of enemies as a "Security Team"; a "Small Squad" job
## still let you deploy six; a "Vengeful" patron shrugged off a failed mission;
## "Demanding" paid Danger Pay on a loss; "One-time Contract" patrons were
## retained anyway. Thirty book entries, thirty pieces of flavour text.
##
## Time Frame was worse: a display String ("This campaign turn") with zero
## readers anywhere in src/. Offers did not persist between turns at all, so the
## deadline had nothing to count against — a player could decline every job
## forever and the same Patron re-offered fresh work next turn, at no cost.
##
## SHAPE: pure statics over the entry ids, mirroring WorldTraitEffects. Values
## live in data/patron_generation.json `effects`; this file is the ONLY reader
## of those blocks and the ONLY roller of the three subtables (JobOfferComponent
## used to carry a second hardcoded copy of all 30 rows).
##
## USAGE — pass the whole job/mission dict, never re-derive the lists:
##     var n := PatronJobEffects.enemy_count_modifier(mission_data)
##     if PatronJobEffects.has_effect(job, "small_squad"): ...

const GEN_PATH := "res://data/patron_generation.json"

## The three BHC categories, in the book's roll order (p.83).
const CATEGORIES := ["benefits", "hazards", "conditions"]

static var _tables: Dictionary = {}
static var _by_id: Dictionary = {}
static var _thresholds: Dictionary = {}
static var _law_enforcement: Array = []
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(GEN_PATH, FileAccess.READ)
	if not file:
		push_warning("PatronJobEffects: cannot open %s" % GEN_PATH)
		return
	var json := JSON.new()
	var ok: int = json.parse(file.get_as_text())
	file.close()
	if ok != OK or not json.data is Dictionary:
		push_warning("PatronJobEffects: cannot parse %s" % GEN_PATH)
		return
	var data: Dictionary = json.data
	for cat in CATEGORIES:
		var entries: Array = data.get("%s_subtable" % cat, {}).get("entries", [])
		_tables[cat] = entries
		for entry in entries:
			if entry is Dictionary and entry.has("id"):
				_by_id[str(entry["id"])] = entry
	_thresholds = data.get("bhc_thresholds", {}).get("by_patron_type", {})
	_law_enforcement = data.get("law_enforcement_enemy_types", {}).get("names", [])


## Entry ids are lowercase-with-underscores. Jobs saved before ids existed carry
## only the display name ("One-time Contract"), and a missed entry is
## indistinguishable from a job that never had it — so normalise both forms.
static func _normalize(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


# ── Rolling (p.83) ──────────────────────────────────────────────────────────

## The D10 threshold this patron type must MEET OR BEAT for the category to
## apply. Corporation Conditions 5+, Wealthy Individual Benefits 5+, Secretive
## Group Hazards 5+, everything else 8+ (p.83 BHC table).
static func threshold(patron_type: String, category: String) -> int:
	_ensure_loaded()
	var row: Dictionary = _thresholds.get(patron_type, {})
	return int(row.get(category, 8))


## Resolve a D10 into one subtable entry. Returns {} for an unknown category.
static func entry_for_roll(category: String, roll: int) -> Dictionary:
	_ensure_loaded()
	for entry in _tables.get(category, []):
		if not entry is Dictionary:
			continue
		var r: Array = entry.get("roll_range", [])
		if r.size() >= 2 and roll >= int(r[0]) and roll <= int(r[1]):
			return entry
	return {}


## The full entry for a known id ({} if unknown).
static func entry_by_id(entry_id: String) -> Dictionary:
	_ensure_loaded()
	var e: Variant = _by_id.get(_normalize(entry_id), {})
	return e if e is Dictionary else {}


# ── Reading a job ───────────────────────────────────────────────────────────

## Does this job carry the named entry, in ANY of the three categories? Ids are
## unique across all three subtables, so a category argument would only be a
## chance to pass the wrong one.
static func has_effect(job: Dictionary, entry_id: String) -> bool:
	var wanted: String = _normalize(entry_id)
	for cat in CATEGORIES:
		for item in _as_array(job.get(cat, [])):
			if _entry_matches(item, wanted):
				return true
	return false


## Every entry attached to this job, as {id, name, effect, effects} dicts.
static func entries_on(job: Dictionary) -> Array:
	var out: Array = []
	for cat in CATEGORIES:
		for item in _as_array(job.get(cat, [])):
			var resolved: Dictionary = _resolve(item)
			if not resolved.is_empty():
				out.append(resolved)
	return out


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	if value is Dictionary and not (value as Dictionary).is_empty():
		return [value]
	if value is String and not (value as String).is_empty():
		return [value]
	return []


## An attached item may be the id, the display name, or the whole {name, effect}
## dict a pre-fix save wrote. All three must resolve to the canonical entry.
static func _resolve(item: Variant) -> Dictionary:
	if item is Dictionary:
		var d: Dictionary = item
		if d.has("id"):
			var by_id: Dictionary = entry_by_id(str(d["id"]))
			if not by_id.is_empty():
				return by_id
		if d.has("name"):
			return entry_by_id(str(d["name"]))
		return {}
	return entry_by_id(str(item))


static func _entry_matches(item: Variant, wanted_id: String) -> bool:
	var resolved: Dictionary = _resolve(item)
	return not resolved.is_empty() and str(resolved.get("id", "")) == wanted_id


## Sum one integer key across every entry on the job. Two entries CAN both carry
## enemy_count_modifier (a Security Team benefit alongside a Dangerous Job
## hazard), and the book gives no precedence rule — so they add.
static func _sum_int(job: Dictionary, key: String) -> int:
	var total: int = 0
	for entry in entries_on(job):
		var eff: Dictionary = entry.get("effects", {})
		if eff.has(key):
			total += int(eff[key])
	return total


static func _any_flag(job: Dictionary, key: String) -> bool:
	for entry in entries_on(job):
		var eff: Dictionary = entry.get("effects", {})
		if eff.has(key) and bool(eff[key]):
			return true
	return false


static func _first_int(job: Dictionary, key: String, fallback: int) -> int:
	for entry in entries_on(job):
		var eff: Dictionary = entry.get("effects", {})
		if eff.has(key):
			return int(eff[key])
	return fallback


# ── Battle setup ────────────────────────────────────────────────────────────

## Security Team (-1), Dangerous Job (+1), Low Priority (-1) — p.83-84. Applied
## on top of the crew-size dice and the enemy type's own Numbers modifier.
static func enemy_count_modifier(job: Dictionary) -> int:
	return _sum_int(job, "enemy_count_modifier")


## "Small Squad — You cannot deploy more than 4 crew" (p.84). The raw ceiling, 0
## when no Condition imposes one — an ABSOLUTE cap, not a modifier, so it holds
## at 4 whether the campaign crew size is 4, 5 or 6.
static func max_deploy_crew(job: Dictionary) -> int:
	return _first_int(job, "max_deploy_crew", 0)


## The same ceiling applied to a caller's own limit. Never WIDENS a tighter cap.
static func deploy_cap(job: Dictionary, base_cap: int) -> int:
	var capped: int = max_deploy_crew(job)
	if capped <= 0:
		return base_cap
	return mini(base_cap, capped)


## "Full Squad — You must have 6 available crew" (p.84). 0 = no requirement.
static func required_available_crew(job: Dictionary) -> int:
	return _first_int(job, "required_available_crew", 0)


## "Clean — You cannot ever have made law enforcement Rivals" (p.84).
static func forbids_law_enforcement_rivals(job: Dictionary) -> bool:
	return _any_flag(job, "forbids_law_enforcement_rivals")


## The enemy entries the book calls law enforcement in so many words — Enforcers
## (p.96) and Colonial Militia (p.100). The "Clean" Condition names no list of
## its own, so this stays in the data file next to that reasoning rather than
## being guessed at a call site.
static func law_enforcement_names() -> Array:
	_ensure_loaded()
	return _law_enforcement


## Does this rival list contain anyone the book calls law enforcement?
static func has_law_enforcement_rival(rivals: Array) -> bool:
	var names: Array = law_enforcement_names()
	for rival in rivals:
		var label: String = ""
		if rival is Dictionary:
			label = "%s %s" % [rival.get("name", ""), rival.get("enemy_type", "")]
		else:
			label = str(rival)
		for wanted in names:
			if label.to_lower().contains(str(wanted).to_lower()):
				return true
	return false


## "Reputation Required — You must have completed a prior Patron job on this
## world" (p.84).
static func requires_prior_patron_job_here(job: Dictionary) -> bool:
	return _any_flag(job, "requires_prior_patron_job_here")


## "VIP — A random enemy will have +1 Toughness and a final Combat Skill of +2
## (regardless of current value)" (p.84). The Combat Skill is a SET, not a bonus.
static func vip_toughness_bonus(job: Dictionary) -> int:
	return _first_int(job, "vip_toughness_bonus", 0)


static func vip_combat_skill_final(job: Dictionary) -> int:
	return _first_int(job, "vip_combat_skill_final", 0)


static func has_vip_enemy(job: Dictionary) -> bool:
	return vip_toughness_bonus(job) > 0 or vip_combat_skill_final(job) > 0


## "Veteran Opposition — Enemy is -1 to Bail Range" (p.84). Bail is the enemy's
## morale check: a LOWER range means they hold on longer.
static func enemy_bail_modifier(job: Dictionary) -> int:
	return _sum_int(job, "enemy_bail_modifier")


# ── Pay ─────────────────────────────────────────────────────────────────────

## "Demanding — Danger Pay is only upon success" (p.84). The p.83 default is the
## opposite: Danger Pay "is paid even if the mission fails, but only if the
## mission is attempted".
static func danger_pay_on_success_only(job: Dictionary) -> bool:
	return _any_flag(job, "danger_pay_on_success_only")


## "Negotiable — If you accept this job, you may reroll the Danger Pay roll and
## pick the better of the two rolls" (p.84). Offered AT ACCEPTANCE, not after.
static func danger_pay_rerollable(job: Dictionary) -> bool:
	return _any_flag(job, "danger_pay_reroll_keep_better")


# ── Patron status and Rivals ────────────────────────────────────────────────

## "Hot Job — After the job, you will earn an enemy on 1-2 instead of the normal
## roll of a 1" (p.84). Same p.119 Step 1 roll the Vendetta system world trait
## widens; both raise the threshold, so pass the running value through.
static func rival_conversion_threshold(base_threshold: int, job: Dictionary) -> int:
	return maxi(base_threshold, _first_int(job, "rival_conversion_threshold", base_threshold))


## "Vengeful — If the mission fails, the Patron becomes a Rival" (p.84).
static func patron_becomes_rival_on_failure(job: Dictionary) -> bool:
	return _any_flag(job, "patron_becomes_rival_on_failure")


## "Persistent — Patron remains available if you travel" (p.84), the named
## exception to p.119 Step 2 "When you travel to a new planet, all Patrons
## become unavailable, unless they are Persistent".
static func patron_persists_on_travel(job: Dictionary) -> bool:
	return _any_flag(job, "patron_persists_on_travel")


## "One-time Contract — This Patron cannot be retained as a contact" (p.84);
## p.119 Step 2 names it as the exception to adding the Patron on success.
static func patron_is_retainable(job: Dictionary) -> bool:
	for entry in entries_on(job):
		var eff: Dictionary = entry.get("effects", {})
		if eff.has("patron_retainable") and not bool(eff["patron_retainable"]):
			return false
	return true


## "Private Transport — If you have Rivals, they cannot track you this campaign
## turn" (p.84), i.e. the p.85 Check for Rivals roll is skipped.
static func blocks_rival_tracking(job: Dictionary) -> bool:
	return _any_flag(job, "blocks_rival_tracking")


## "Busy — If the mission is a success, the Patron offers a new job next
## campaign turn" (p.84).
static func offers_new_job_on_success(job: Dictionary) -> bool:
	return _any_flag(job, "new_job_next_turn_on_success")


# ── Benefits paid out (p.83: "Benefits are paid out ONLY if the mission is a
#    success") ────────────────────────────────────────────────────────────────

## The payout-type Benefits earned by winning: "loot_roll" (Fringe Benefit),
## "rumor" (Connections), "trade_roll" (Company Store), "injury_recovery"
## (Health Insurance). The other three Benefits are structural — Security Team
## shapes the battle, Persistent and Negotiable shape the Patron relationship —
## so they are not "paid out" and do not appear here.
static func success_rewards(job: Dictionary) -> Array:
	var out: Array = []
	for entry in entries_on(job):
		var eff: Dictionary = entry.get("effects", {})
		if eff.has("success_reward"):
			out.append({
				"reward": str(eff["success_reward"]),
				"name": str(entry.get("name", "")),
				"effect": str(entry.get("effect", "")),
				"recovery_turns": int(eff.get("recovery_turns", 0)),
			})
	return out


# ── Time Frame (p.83) ───────────────────────────────────────────────────────

## Campaign turns the job stays open for, from the D10 (already modified by the
## Secretive Group's +1). 1-5 this turn, 6-7 this or next, 8-9 this or the
## following 2, 10+ any time. -1 means no deadline.
static func time_frame_turns(roll: int) -> int:
	_ensure_loaded()
	if roll <= 5:
		return 1
	if roll <= 7:
		return 2
	if roll <= 9:
		return 3
	return -1


## The last campaign turn on which the job can still be carried out. -1 = never
## expires. "This campaign turn" is turns=1, so the deadline is the offer turn
## itself, not the one after it.
static func deadline_turn(offered_on_turn: int, turns: int) -> int:
	if turns < 0:
		return -1
	return offered_on_turn + maxi(1, turns) - 1


## "If the job isn't done when the time runs out, it counts as a failure"
## (p.83); "a Patron job will fail if the time to complete it has expired"
## (p.85).
static func is_expired(job: Dictionary, current_turn: int) -> bool:
	if not job.has("deadline_turn"):
		return false
	var deadline: int = int(job["deadline_turn"])
	if deadline < 0:
		return false
	return current_turn > deadline


## Player-facing deadline text, recomputed against the CURRENT turn so a held
## offer reads "Expires this turn" rather than the wording it was born with.
static func deadline_label(job: Dictionary, current_turn: int) -> String:
	if not job.has("deadline_turn"):
		return str(job.get("time_frame", ""))
	var deadline: int = int(job["deadline_turn"])
	if deadline < 0:
		return "Any time"
	var remaining: int = deadline - current_turn
	if remaining < 0:
		return "Expired"
	if remaining == 0:
		return "Expires this campaign turn"
	if remaining == 1:
		return "This or the next campaign turn"
	return "This or the following %d campaign turns" % remaining
