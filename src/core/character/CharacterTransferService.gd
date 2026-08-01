class_name CharacterTransferService
extends RefCounted

## Handles character transfer between Five Parsecs campaigns:
##   - 5PFH ↔ Bug Hunt (Compendium pp.212-213)
##   - 5PFH → Planetfall (Planetfall pp.26-27)
##   - Bug Hunt → Planetfall (Planetfall pp.26-27)
##   - Planetfall → 5PFH (Planetfall p.164, varies by ending)
##
## Enlistment (5PFH → Bug Hunt, Compendium p.212):
##   - Roll 2D6 + Combat Skill: need 7+ to succeed
##   - All equipment stashed (except one Pistol)
##   - Stats carry over, game_mode set to "bug_hunt"
##   - completed_missions/reputation reset to 0
##
## Mustering Out (Bug Hunt → 5PFH):
##   - Military equipment stripped
##   - Stats carry over, game_mode set to "standard"
##   - Luck stat restored to base value
##   - Added as new crew member in target campaign
##
## Planetfall Import (5PFH/Bug Hunt → Planetfall, Planetfall pp.26-27):
##   - All ability scores keep. Luck → 1 KP per Luck point (5PFH). Tech → Savvy (Bug Hunt).
##   - 5PFH: personal equipment IF has Planetfall function. Bug Hunt: no equipment (military property).
##   - Up to 3 imported chars can receive Class Training (D6 aptitude test).
##   - Imported characters start as Loyal.
##   - Credits/Reputation have no value in Planetfall.
##
## INTENTIONALLY NOT transferred: Stars of the Story options (Compendium p.214):
##   "You cannot carry over 'Stars of the Story' options or Story Points to Bug Hunt.
##    Keep a record of them, in case you want to return to 5PFH play."
## The 5PFH campaign retains its stars_of_the_story field; Bug Hunt and Planetfall
## campaign cores DO NOT have this field by design. Do not "fix" this by plumbing
## stars through transfer — it would violate the book.

const ENLISTMENT_TARGET := 7  # 2D6 + Combat Skill >= 7+ (Compendium p.212)

## Canonical mode identifiers (match each campaign core's campaign_type field;
## FiveParsecsCampaignCore has no such field and is detected as "five_parsecs").
const MODE_5PFH := "five_parsecs"
const MODE_BUG_HUNT := "bug_hunt"
const MODE_PLANETFALL := "planetfall"
const MODE_TACTICS := "tactics"

## Stashed equipment storage: character_id -> Array of equipment dicts
var _stashed_equipment: Dictionary = {}


func _sector_government_patron_bonus() -> int:
	## Compendium p.214: +1 (MAX — one, however many you hold) to the enlistment
	## examination if any Sector Government Patron is on the contacts list.
	## Patrons are owned by the campaign (data-ownership table).
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") \
		if Engine.get_main_loop() else null
	if gs == null or gs.current_campaign == null:
		return 0
	var campaign = gs.current_campaign
	if not ("patrons" in campaign) or not (campaign.patrons is Array):
		return 0
	for p in campaign.patrons:
		if not (p is Dictionary):
			continue
		var ptype: String = str(p.get("type", "")).to_lower()
		var pname: String = str(p.get("name", "")).to_lower()
		if ptype == "sector_government" or pname.contains("sector government"):
			return 1
	return 0

func validate_enlistment(character_data: Dictionary) -> Dictionary:
	## Check if a standard character is eligible for Bug Hunt enlistment.
	## Returns {eligible: bool, reason: String, combat_bonus: int}
	var game_mode: String = character_data.get("game_mode", "standard")
	if game_mode != "standard":
		return {"eligible": false, "reason": "Character is already in Bug Hunt mode", "combat_bonus": 0}

	var status: String = character_data.get("status", "active")
	if status != "active":
		return {"eligible": false, "reason": "Character must be active (not injured/dead)", "combat_bonus": 0}

	var combat: int = character_data.get("combat_skill", character_data.get("combat", 0))
	return {"eligible": true, "reason": "Eligible", "combat_bonus": combat}


func attempt_enlistment(character_data: Dictionary) -> Dictionary:
	## Roll 2D6 + Combat Skill. On 7+, character enlists as Bug Hunter (Compendium p.212).
	## Returns {success: bool, roll: int, target: int, transferred_character: Dictionary}
	var validation := validate_enlistment(character_data)
	if not validation.eligible:
		return {"success": false, "roll": 0, "target": ENLISTMENT_TARGET, "reason": validation.reason}

	var combat_bonus: int = validation.combat_bonus
	# Compendium p.214: "Add +1 (max) if you have any Sector Government Patrons on
	# your contacts list." This modifier was simply absent, so a crew that had done
	# the work to earn a Sector Government contact got nothing for it — and that
	# patron is itself the standard Bug Hunt muster-out reward, so the rule exists
	# precisely to make a second enlistment easier.
	var patron_bonus: int = _sector_government_patron_bonus()
	var die1: int = (randi() % 6) + 1
	var die2: int = (randi() % 6) + 1
	var total: int = die1 + die2 + combat_bonus + patron_bonus
	var success: bool = total >= ENLISTMENT_TARGET

	if not success:
		return {
			"success": false,
			"roll": total,
			"dice": [die1, die2],
			"combat_bonus": combat_bonus,
			"patron_bonus": patron_bonus,
			"target": ENLISTMENT_TARGET,
			# Compendium p.214: "If the roll fails, 1 Story Point will get you in
			# with any suitable explanation." Surfaced so the UI can offer it.
			"story_point_rescue_available": true,
			"reason": "Enlistment rejected (rolled %d+%d+%d+%d=%d, needed %d)" % [
				die1, die2, combat_bonus, patron_bonus, total, ENLISTMENT_TARGET]
		}

	# Transfer successful — create Bug Hunt version.
	#
	# Route through the canonical hub rather than calling _convert_to_bug_hunt()
	# directly. This leg is reached from CharacterTransferPanel:311 and was the ONLY
	# one of the four that bypassed import_from_canonical(), so it was also the only
	# one that never attached the lossless `snapshot`. A 5PFH veteran who enlisted and
	# later mustered out came back as a stat-only husk: export_to_canonical() found no
	# snapshot and fell through to _convert_to_standard(), which rebuilds from the Bug
	# Hunt shape and cannot recover species, class, traits or implants.
	#
	# For a 5PFH source with no snapshot, export_to_canonical() returns
	# char_data.duplicate(true) — the same input _convert_to_bug_hunt() got before —
	# so the enlistment result is otherwise unchanged.
	var canonical := export_to_canonical(character_data, MODE_5PFH)
	var transferred := import_from_canonical(canonical, MODE_BUG_HUNT)

	return {
		"success": true,
		"roll": total,
		"dice": [die1, die2],
		"combat_bonus": combat_bonus,
		"target": ENLISTMENT_TARGET,
		"transferred_character": transferred,
		"stashed_equipment": _stashed_equipment.get(character_data.get("id", character_data.get("character_id", "")), [])
	}


func validate_muster_out(character_data: Dictionary) -> Dictionary:
	## Check if a Bug Hunt character is eligible for mustering out to 5PFH.
	var game_mode: String = character_data.get("game_mode", "standard")
	if game_mode != "bug_hunt":
		return {"eligible": false, "reason": "Character is not in Bug Hunt mode"}

	if character_data.get("is_grunt", false):
		return {"eligible": false, "reason": "Grunts cannot muster out to individual campaigns"}

	var status: String = character_data.get("status", "active")
	if status != "active":
		return {"eligible": false, "reason": "Character must be active"}

	return {"eligible": true, "reason": "Eligible for transfer"}


func muster_out(character_data: Dictionary) -> Dictionary:
	## Transfer a Bug Hunt character to a standard Five Parsecs campaign.
	## Returns {success: bool, transferred_character: Dictionary}
	var validation := validate_muster_out(character_data)
	if not validation.eligible:
		return {"success": false, "reason": validation.reason}

	# Route through the canonical hub, NOT _convert_to_standard() directly.
	# _convert_to_standard rebuilds a character from its Bug Hunt stats, so calling
	# it here ignored the lossless `snapshot` an imported 5PFH veteran carries —
	# muster-out handed back a reconstruction instead of the original, silently
	# losing everything Bug Hunt does not model (species rules, traits, XP history,
	# implants). export_to_canonical() short-circuits on the snapshot and layers the
	# p.213 muster-out rewards on top.
	var transferred := export_to_canonical(character_data, MODE_BUG_HUNT)
	return {
		"success": true,
		"transferred_character": transferred
	}


func _current_campaign() -> Variant:
	## Reach the live campaign from a detached RefCounted. Null-safe by design:
	## the service is also constructed in tests with no tree.
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var root := (loop as SceneTree).root
	if root == null:
		return null
	var gs = root.get_node_or_null("/root/GameState")
	if gs == null:
		return null
	return gs.get("current_campaign")


func _store_stashed_equipment(character_id: String, items: Array) -> void:
	## Persist the stash on the CAMPAIGN, not just on this service instance.
	##
	## `_stashed_equipment` is a member of a RefCounted that CharacterTransferPanel
	## creates per-panel and BugHuntDashboard queue_free()s immediately after the
	## enlistment completes. Muster-out then builds a BRAND NEW service, so the
	## instance dict was always empty and `_convert_to_standard` restored nothing —
	## a 5PFH character's entire loadout was destroyed by enlisting, permanently and
	## irrecoverably, while CharacterTransferPanel.gd:346 told the player
	## "Equipment has been stashed safely."
	##
	## BugHuntCampaignCore already declares `stashed_equipment` (:71) and already
	## round-trips it (serialise :376, restore :434), so the canonical home existed
	## the whole time and simply was not being written. No schema change needed.
	_stashed_equipment[character_id] = items
	var c = _current_campaign()
	if c != null and "stashed_equipment" in c:
		var store: Dictionary = c.stashed_equipment
		store[character_id] = items.duplicate(true)
		c.stashed_equipment = store


func get_stashed_equipment(character_id: String) -> Array:
	## Retrieve equipment stashed when a character enlisted. Prefers the campaign
	## (survives the panel teardown and a process restart); falls back to this
	## instance for tests and for any in-flight single-instance use.
	var c = _current_campaign()
	if c != null and "stashed_equipment" in c:
		var persisted = c.stashed_equipment.get(character_id, null)
		if persisted is Array:
			return (persisted as Array).duplicate(true)
	return _stashed_equipment.get(character_id, [])


func _convert_to_bug_hunt(char_data: Dictionary) -> Dictionary:
	## Strip equipment, keep stats, change game_mode.
	var char_id: String = char_data.get("id", char_data.get("character_id", ""))

	# Stash all equipment except pistols
	var all_equipment: Array = char_data.get("equipment", [])
	var stashed: Array = []
	var kept_pistol: bool = false

	for item in all_equipment:
		var item_name: String = ""
		if item is Dictionary:
			item_name = item.get("name", item.get("id", "")).to_lower()
		elif item is String:
			item_name = item.to_lower()

		if not kept_pistol and ("pistol" in item_name):
			kept_pistol = true
			# Keep this pistol
		else:
			stashed.append(item)

	_store_stashed_equipment(char_id, stashed)

	# Build transferred character
	return {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"character_name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"game_mode": "bug_hunt",
		"is_grunt": false,
		"reactions": char_data.get("reactions", char_data.get("reaction", 1)),
		"reaction": char_data.get("reactions", char_data.get("reaction", 1)),
		"speed": char_data.get("speed", 4),
		"combat_skill": char_data.get("combat_skill", char_data.get("combat", 0)),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"luck": 0,  # Bug Hunt doesn't use Luck
		"xp": 0,
		"completed_missions_count": 0,
		"reputation_contribution": 0,
		"muster_number": 0,
		"equipment": ["service_pistol", "trooper_armor"],
		# "species" is NOT a key Character.to_dictionary() emits — the canonical
		# form carries species_id (always a String) with legacy saves using
		# origin. Reading "species" made EVERY enlistee "Transfer from Unknown".
		"origin": "Transfer from %s" % str(char_data.get("species_id",
			char_data.get("origin", char_data.get("species", "Unknown")))),
		"status": "active",
		"transferred_from_campaign": true
	}


func _convert_to_standard(char_data: Dictionary) -> Dictionary:
	## Mustering Out to 5PFH — Compendium p.213
	## - Retain profile and unused XP
	## - Retain Service Pistol if 10+ Completed Missions
	## - 1 Credit per 2 Completed Missions
	## - +1 Story Point
	## - Add Sector Government Patron to contacts
	var char_id: String = char_data.get("id", char_data.get("character_id", ""))
	var completed_missions: int = char_data.get("completed_missions_count", 0)

	# Restore stashed equipment if available
	var restored_equipment: Array = get_stashed_equipment(char_id)

	# Retain Service Pistol only if 10+ completed missions (Compendium p.213)
	if completed_missions >= 10:
		var has_pistol := false
		for item in restored_equipment:
			var item_name: String = ""
			if item is Dictionary:
				item_name = item.get("name", item.get("id", "")).to_lower()
			elif item is String:
				item_name = item.to_lower()
			if "service pistol" in item_name or "service_pistol" in item_name:
				has_pistol = true
				break
		if not has_pistol:
			restored_equipment.append({"id": "service_pistol", "name": "Service Pistol"})

	# Mustering out benefit: 1 Credit per 2 Completed Missions
	var mustering_credits: int = completed_missions / 2

	var result := {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"character_name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"game_mode": "standard",
		"is_grunt": false,
		# DUAL KEY (see Character.to_dictionary): battle reads "reactions",
		# the crew UI reads "reaction". Emitting only the singular here meant a
		# transferred veteran fought at Reactions 1 whatever their real stat.
		"reactions": char_data.get("reactions", char_data.get("reaction", 1)),
		"reaction": char_data.get("reactions", char_data.get("reaction", 1)),
		"speed": char_data.get("speed", 4),
		"combat": char_data.get("combat_skill", 0),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		# Preserve tech in the canonical so a downstream Planetfall import can apply
		# its Tech->Savvy rule (Planetfall p.26). Bug Hunt itself doesn't use it.
		"tech": char_data.get("tech", char_data.get("savvy", 0)),
		"luck": 1,  # Restore base Luck for standard campaigns
		"equipment": restored_equipment,
		"status": "active",
		"transferred_from_bug_hunt": true,
		"bug_hunt_missions_completed": completed_missions,
		# Mustering out rewards (Compendium p.213)
		"mustering_credits": mustering_credits,
		"bonus_story_points": 1,
		"add_sector_government_patron": true
	}
	# "Retain profile and unused XP" (Compendium p.213, the docblock above). The
	# retained value was being written under "xp", which nothing in 5PFH reads, so a
	# mustered-out veteran arrived with their full XP recorded and none of it usable.
	_set_xp_5pfh(result, _xp_of(char_data))
	return result


## ============================================================================
## CANONICAL-HUB ROUTER (any-to-any character transfer)
## ============================================================================
##
## Every mode converts TO and FROM one canonical representation: the full
## 5PFH-standard character dict. This mirrors the rulebooks' own model — each
## expansion documents how a character "returns to 5PFH play" and how a standard
## character enters that mode. Any-to-any is then the COMPOSITION of two
## book-defined legs (export-to-canonical + import-from-canonical), so the three
## routes no book defines directly (Planetfall->Bug Hunt, Tactics->Bug Hunt,
## Tactics->Planetfall) are offered WITHOUT inventing any values.
##
## Reward-suppression rule: 5PFH-specific exit rewards (Bug Hunt mustering
## credits / Story Point / Sector Government patron; Planetfall ending bonuses)
## attach ONLY when the final destination is 5PFH.

func export_to_canonical(char_data: Dictionary, source_mode: String) -> Dictionary:
	## Produce the canonical 5PFH-standard form of a character leaving source_mode.
	## Prefers an embedded lossless snapshot when present (the character was itself
	## imported) so a round-trip restores the original verbatim.
	var snap := _restore_from_snapshot(char_data)
	match source_mode:
		MODE_BUG_HUNT:
			# Muster-out rewards depend on SERVICE (missions completed), not on
			# stats, so they apply to a snapshot-restored veteran too — exactly as
			# the Planetfall branch below layers ending bonuses onto a snapshot.
			# Returning the bare snapshot dropped all three, so a 5PFH character who
			# enlisted and later mustered out received no mustering credits, no
			# Story Point and no Sector Government Patron.
			if snap.is_empty():
				return _convert_to_standard(char_data)
			return _layer_bug_hunt_muster_rewards(snap, char_data)
		MODE_PLANETFALL:
			# Planetfall end-of-campaign bonuses depend on the ending, not stats, so
			# they apply even to a snapshot-restored imported veteran (Planetfall
			# pp.165-166). Born-in colonists get stats + bonuses from convert_from_*.
			var ending := str(char_data.get("planetfall_ending", ""))
			if snap.is_empty():
				return convert_from_planetfall(char_data, ending)
			return _layer_planetfall_ending(snap, char_data, ending)
		MODE_TACTICS:
			return snap if not snap.is_empty() else convert_from_tactics(char_data)
		_:  # MODE_5PFH or unknown — already canonical
			return snap if not snap.is_empty() else char_data.duplicate(true)


func _layer_bug_hunt_muster_rewards(
		base: Dictionary, char_data: Dictionary) -> Dictionary:
	## Layer the Compendium p.213 muster-out rewards onto a snapshot-restored
	## veteran. Stats come from `base` (the lossless snapshot); the rewards depend
	## only on Bug Hunt service, so they apply either way. Mirrors
	## _layer_planetfall_ending().
	var completed: int = int(char_data.get("completed_missions_count",
		char_data.get("bug_hunt_missions_completed", 0)))
	base["mustering_credits"] = completed / 2  # 1 Credit per 2 Completed Missions
	base["bonus_story_points"] = 1
	base["add_sector_government_patron"] = true
	base["bug_hunt_missions_completed"] = completed
	base["transferred_from_bug_hunt"] = true
	return base

func _layer_planetfall_ending(
		base: Dictionary, char_data: Dictionary, ending: String) -> Dictionary:
	## Layer Planetfall ending bonuses onto a snapshot-restored character. Stats come
	## from `base` (the lossless snapshot); the bonuses depend only on the ending.
	if ending.is_empty():
		return base
	var bonused := convert_from_planetfall(char_data, ending)
	for k in ["bonus_ship", "ship_debt", "ship_debt_prepaid", "add_rival",
			"bonus_story_points", "gains_psionic", "isolation_single_char",
			"from_isolation_victory", "psionic_powers"]:
		if bonused.has(k):
			base[k] = bonused[k]
	if ending == "isolation":
		base["luck"] = int(base.get("luck", 0)) + 1  # +1 on top of restored Luck
	return base


func import_from_canonical(canonical: Dictionary, target_mode: String) -> Dictionary:
	## Down-convert a canonical character into target_mode's shape using that mode's
	## documented entry rules, then embed the lossless snapshot for later export-back.
	var result: Dictionary
	match target_mode:
		MODE_BUG_HUNT:
			result = _convert_to_bug_hunt(canonical)
		MODE_PLANETFALL:
			result = convert_to_planetfall(canonical, "5pfh")
		MODE_TACTICS:
			result = convert_to_tactics(canonical, "5pfh")
		_:  # MODE_5PFH or unknown — canonical IS the 5PFH form
			result = canonical.duplicate(true)
	_attach_snapshot(result, canonical)
	return result


func transfer_character(
		char_data: Dictionary, source_mode: String, target_mode: String) -> Dictionary:
	## Build a transfer envelope routing a character from source_mode to target_mode by
	## composing export-to-canonical + import-from-canonical (both book-defined legs).
	var canonical := export_to_canonical(char_data, source_mode)
	var down := import_from_canonical(canonical, target_mode)
	var cid := str(char_data.get("id", char_data.get("character_id", "")))

	var envelope := {
		"schema_version": 2,
		"direction": "%s_to_%s" % [source_mode, target_mode],
		"source_mode": source_mode,
		"target_mode": target_mode,
		"character": down,
		"snapshot": canonical.duplicate(true),
		"stashed_equipment": _stashed_equipment.get(cid, []),
		"mustering_credits": 0,
		"bonus_story_points": 0,
		"add_sector_government_patron": false,
		"transferred_at": Time.get_datetime_string_from_system()
	}

	# Reward-suppression rule: exit rewards apply ONLY when returning to 5PFH.
	if target_mode == MODE_5PFH:
		envelope["mustering_credits"] = int(canonical.get("mustering_credits", 0))
		# READ `down` FIRST. Bug Hunt's muster-out rewards are stamped on the
		# canonical by export_to_canonical, but the Planetfall ENDING bonuses are
		# applied on the way DOWN by _layer_planetfall_ending() and never touch
		# the canonical. Reading only the canonical meant the Planetfall p.164
		# "+2 additional Story Points (win or lose)" for both Independence
		# endings silently resolved to 0 every time.
		envelope["bonus_story_points"] = int(
			down.get("bonus_story_points", canonical.get("bonus_story_points", 0)))
		envelope["add_sector_government_patron"] = bool(
			down.get("add_sector_government_patron",
				canonical.get("add_sector_government_patron", false)))

	return envelope


func _attach_snapshot(down_converted: Dictionary, canonical: Dictionary) -> void:
	## Embed the canonical form as a lossless "return ticket". Strips any nested
	## snapshot first so snapshots never recurse.
	var clean := canonical.duplicate(true)
	clean.erase("snapshot")
	down_converted["snapshot"] = clean


func _xp_of(char_data: Dictionary) -> int:
	## Read a character's experience regardless of which mode's key it carries.
	##
	## The two sides of a transfer name this field differently and BOTH are correct
	## in their own mode:
	##   5PFH      -> "experience"  (Character.to_dictionary():1306 / from_dictionary():1404;
	##                CharacterAdvancementService:62/152 spends against it, and
	##                CampaignPhaseManager:500 + PostBattleContext:435 award into it)
	##   Bug Hunt  -> "xp"          (BugHuntPhaseManager:177, BugHuntCharacterGeneration)
	##   Planetfall-> "xp"
	##
	## Every conversion below used to read "xp" unconditionally, so any leg whose
	## SOURCE was 5PFH read a key that does not exist there and silently got 0.
	## Reading both keys makes the helper direction-agnostic.
	if char_data.has("experience"):
		return int(char_data.get("experience", 0))
	return int(char_data.get("xp", 0))


func _set_xp_5pfh(result: Dictionary, xp: int) -> void:
	## Write experience onto a 5PFH-bound dict under BOTH keys.
	##
	## "experience" is the one 5PFH actually reads — writing only "xp" (as every
	## return-to-5PFH leg did) meant a transferred veteran landed in the roster with
	## 0 usable XP no matter how much they had earned. "xp" is kept alongside it for
	## the same reason Character.to_dictionary() emits both "id"/"character_id" and
	## "name"/"character_name": mixed-vintage consumers read either.
	result["experience"] = xp
	result["xp"] = xp


func _restore_from_snapshot(char_data: Dictionary) -> Dictionary:
	## Return the embedded canonical snapshot if present, else an empty dict.
	var snap = char_data.get("snapshot", {})
	if snap is Dictionary and not (snap as Dictionary).is_empty():
		return (snap as Dictionary).duplicate(true)
	return {}


## ============================================================================
## PENDING TRANSFER PERSISTENCE (user://transfers/)
## ============================================================================

static func load_pending_transfers(target_mode: String = "") -> Array:
	## Load pending transfer files from user://transfers/. When target_mode is set,
	## only transfers destined for that mode are returned (one loader serves all modes).
	## Returns Array of validated transfer Dictionaries.
	var transfers: Array = []
	var dir := DirAccess.open("user://transfers/")
	if not dir:
		return transfers

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := "user://transfers/" + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var data = JSON.parse_string(file.get_as_text())
				file.close()
				if _validate_transfer_data(data):
					if target_mode.is_empty() or _transfer_targets_mode(data, target_mode):
						data["_file_path"] = path
						transfers.append(data)
				else:
					# QUARANTINE an unusable envelope instead of leaving it in place.
					#
					# A malformed or truncated transfer file silently failed validation
					# and was skipped — forever. It stayed in user://transfers/, was
					# re-read and re-skipped on every single dashboard open, and the
					# character it represented was already gone from the source roster.
					# Nothing ever told the player, and nothing ever cleaned it up.
					#
					# Renaming to .corrupt takes it out of the scan (the loop only reads
					# .json) while KEEPING the bytes, so the character is recoverable by
					# hand rather than lost or endlessly retried.
					var quarantined := path + ".corrupt"
					if DirAccess.rename_absolute(path, quarantined) == OK:
						push_error("CharacterTransferService: unreadable transfer file "
							+ "quarantined as %s — the character it held could not be "
							% quarantined + "imported")
					else:
						push_error("CharacterTransferService: unreadable transfer file "
							+ "%s could not be quarantined" % path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return transfers


static func _transfer_targets_mode(data: Dictionary, target_mode: String) -> bool:
	## v2 files carry an explicit target_mode. v1 muster-out files predate it and
	## always targeted 5PFH (the only route that existed).
	if data.has("target_mode"):
		return str(data["target_mode"]) == target_mode
	return target_mode == MODE_5PFH


static func _validate_transfer_data(data) -> bool:
	## Validate a transfer file has required fields and safe types.
	if not data is Dictionary:
		return false
	if not data.has("character") or not data.character is Dictionary:
		return false
	var char_dict: Dictionary = data.character
	# Must have an ID
	if not char_dict.has("id") and not char_dict.has("character_id"):
		return false
	# Must have core stats
	for stat in ["toughness", "speed"]:
		if not char_dict.has(stat):
			return false
	# Rewards must be non-negative if present
	var credits = data.get("mustering_credits", 0)
	if not (credits is int or credits is float) or credits < 0:
		return false
	var sp = data.get("bonus_story_points", 0)
	if not (sp is int or sp is float) or sp < 0:
		return false
	return true


static func remove_character_from_save(save_path: String, character_id: String) -> bool:
	## Delete a character from a save file on disk. Returns true if one was removed.
	##
	## THE PULL-IMPORT HOLE THIS CLOSES: the PUSH direction (muster-out) is careful —
	## it writes the destination transfer file first and only then removes the
	## character from the source roster. The PULL direction (Planetfall "Import
	## Veterans", Tactics "Commission Veteran") only ever ADDED to the destination,
	## so the character stayed in the source campaign too and now existed in BOTH.
	## That breaks the same "one item, one home" invariant the equipment layer
	## enforces, and the duplicate could then be imported again, and again.
	##
	## Handles both roster shapes: 5PFH crew.members and Bug Hunt
	## squad.main_characters. Writes atomically via SaveFileWriter, so a failure
	## mid-write leaves the original intact and the character is never lost.
	if save_path.is_empty() or character_id.is_empty():
		return false
	var SaveWriter = load("res://src/core/state/SaveFileWriter.gd")
	var data: Dictionary = SaveWriter.read_json_with_fallback(save_path)
	if data.is_empty():
		return false

	var roster: Array = []
	var container: Dictionary = {}
	var key: String = ""
	if data.has("crew") and data["crew"] is Dictionary \
			and (data["crew"] as Dictionary).has("members"):
		container = data["crew"]
		key = "members"
	elif data.has("squad") and data["squad"] is Dictionary \
			and (data["squad"] as Dictionary).has("main_characters"):
		container = data["squad"]
		key = "main_characters"
	else:
		return false
	roster = container[key]

	var removed := false
	for i in range(roster.size() - 1, -1, -1):
		var m: Variant = roster[i]
		if not (m is Dictionary):
			continue
		var mid: String = str((m as Dictionary).get("character_id",
			(m as Dictionary).get("id", "")))
		if mid == character_id:
			roster.remove_at(i)
			removed = true
			break
	if not removed:
		return false
	container[key] = roster
	return SaveWriter.write_text_atomic(save_path, JSON.stringify(data, "\t")) == OK

static func _roll_starting_psionic_powers() -> Array:
	## Compendium p.17 starting powers as String ids: two rolls on the D10 power
	## table, shifting +-1 on a duplicate (p.22). Mirrors
	## PsionicSystem.determine_starting_powers(), which returns PsionicPower
	## OBJECTS — Character.psionic_powers stores the JSON keys instead, which is
	## also what AdvancementPhasePanel appends.
	var ids: Array = []
	if FileAccess.file_exists("res://data/psionic_powers.json"):
		var f := FileAccess.open("res://data/psionic_powers.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				ids = (parsed as Dictionary).keys()
	if ids.is_empty():
		return []
	var chosen: Array = []
	for _i in range(2):
		var idx: int = randi() % ids.size()
		if str(ids[idx]) in chosen and ids.size() > 1:
			idx = (idx + 1) % ids.size()
		if str(ids[idx]) not in chosen:
			chosen.append(str(ids[idx]))
	return chosen

static func peek_character(transfer_data: Dictionary) -> Dictionary:
	## The character a transfer envelope carries, deep-copied, WITHOUT applying
	## any reward or touching the campaign.
	##
	## Exists so a caller can prove the roster add succeeds BEFORE granting
	## rewards. apply_transfer_rewards() used to run first, so a failed
	## _add_character_to_mode() left the player holding the mustering credits,
	## the Story Point and the Sector Government patron with no character to
	## show for them — and the transfer file was (correctly) kept, so importing
	## again re-granted the lot.
	var char_data: Dictionary = transfer_data.get("character", {})
	if char_data.is_empty():
		return {}
	return char_data.duplicate(true)

static func apply_transfer_rewards(
		campaign, transfer_data: Dictionary) -> Dictionary:
	## Apply mustering-out rewards to a standard campaign.
	## Returns {success: bool, character: Dictionary, summary: String}.
	## IMPORTANT: deep-copies the character to prevent shared references.
	if not campaign:
		return {"success": false, "summary": "No campaign provided"}

	var char_data: Dictionary = transfer_data.get("character", {})
	if char_data.is_empty():
		return {"success": false, "summary": "No character data in transfer"}

	# Deep copy to prevent cross-campaign reference sharing
	var safe_char: Dictionary = char_data.duplicate(true)

	var summary_parts: Array = []
	var gsm = Engine.get_main_loop().root.get_node_or_null(
		"/root/GameStateManager") if Engine.get_main_loop() else null

	# Apply credits (Compendium p.213: 1 credit per 2 completed missions)
	var credits: int = int(transfer_data.get("mustering_credits", 0))
	if credits > 0:
		if gsm and gsm.has_method("add_credits"):
			gsm.add_credits(credits)
		summary_parts.append("+%d credits" % credits)

	# Apply Story Points (Compendium p.213). add_story_points respects Insanity
	# mode (story points disabled), so the grant is rules-safe.
	var sp: int = int(transfer_data.get("bonus_story_points", 0))
	if sp > 0:
		if gsm and gsm.has_method("add_story_points"):
			gsm.add_story_points(sp)
		summary_parts.append("+%d Story Point(s)" % sp)

	# Sector Government Patron — append to the campaign's patron contacts (owner).
	if transfer_data.get("add_sector_government_patron", false):
		if "patrons" in campaign and campaign.patrons is Array:
			campaign.patrons.append({
				"name": "Sector Government",
				"type": "sector_government",
				"source": "bug_hunt_muster_out"
			})
		summary_parts.append("+Sector Government Patron")

	# Planetfall end-of-campaign bonuses (Planetfall pp.165-166). These ride on the
	# character dict (set by convert_from_planetfall / _layer_planetfall_ending) and
	# are applied to the campaign here. bonus_story_points already flowed via the
	# Story Point path above.
	if safe_char.get("bonus_ship", false):
		if "has_ship" in campaign:
			campaign.has_ship = true
		summary_parts.append("+Ship")
	if safe_char.has("ship_debt") and "ship_debt" in campaign:
		campaign.ship_debt = int(safe_char["ship_debt"])
		summary_parts.append("debt cleared")
	var prepaid: int = int(safe_char.get("ship_debt_prepaid", 0))
	if prepaid > 0 and "ship_debt" in campaign:
		campaign.ship_debt = maxi(0, int(campaign.ship_debt) - prepaid)
		summary_parts.append("%d cr prepaid on debt" % prepaid)
	var rival_name: String = str(safe_char.get("add_rival", ""))
	if not rival_name.is_empty() and "rivals" in campaign and campaign.rivals is Array:
		campaign.rivals.append({
			"name": rival_name, "type": "rival", "source": "planetfall_independence_lost"
		})
		summary_parts.append("+Rival (%s)" % rival_name)
	if safe_char.get("gains_psionic", false):
		summary_parts.append("+Psionic")  # rides on the character into the roster

	# Gear the character had STASHED on the source side (Compendium p.213 — a
	# mustering-out veteran's kit does not evaporate). transfer_character() has
	# always written this key into the envelope and NOTHING has ever read it, so
	# every stashed item was recorded in the transfer file and dropped on
	# arrival. Routed through EquipmentTransferService.add_loot_to_stash(), the
	# sanctioned way items enter a ship stash — it assigns an id when the item
	# lacks one, which matters because these have crossed a campaign boundary.
	var stashed: Array = transfer_data.get("stashed_equipment", [])
	if stashed is Array and not stashed.is_empty():
		var TransferSvc = load("res://src/core/equipment/EquipmentTransferService.gd")
		var eq_svc = TransferSvc.new(campaign)
		var moved: int = 0
		for item in stashed:
			if item is Dictionary:
				eq_svc.add_loot_to_stash(item as Dictionary)
				moved += 1
			elif item != null:
				eq_svc.add_loot_to_stash({"name": str(item)})
				moved += 1
		if moved > 0:
			summary_parts.append("+%d stashed item(s)" % moved)

	# The transfer file is NOT deleted here. It is reported back as `consumed_file`
	# so the caller can delete it only AFTER the receiving campaign has been
	# successfully written to disk.
	#
	# Deleting inline meant the source was destroyed while the destination existed
	# only in memory: this function applies rewards and returns, but the campaign is
	# not saved until after the caller's loop, and that save's result was never
	# checked. Anything failing in between — the roster mutator missing, the save
	# erroring, a crash — lost the character permanently, with the rewards already
	# granted. Commit the destination first, then drop the source.
	return {
		"success": true,
		"character": safe_char,
		"consumed_file": str(transfer_data.get("_file_path", "")),
		"summary": ", ".join(summary_parts) if not summary_parts.is_empty() else "Character transferred"
	}


## ============================================================================
## PLANETFALL TRANSFERS (Planetfall pp.26-27, p.164)
## ============================================================================

func convert_to_planetfall(char_data: Dictionary, source: String = "5pfh") -> Dictionary:
	## Convert a 5PFH or Bug Hunt character for Planetfall import.
	## Source: "5pfh" or "bug_hunt"
	## Returns a Planetfall-compatible character dict (no class assigned yet — needs Class Training).
	var char_id: String = char_data.get("id", char_data.get("character_id", ""))

	var result := {
		"id": char_id,
		"name": char_data.get("name", char_data.get("character_name", "Unknown")),
		"class": "",  # Must be assigned via Class Training aptitude test
		"subspecies": "",
		"reactions": char_data.get("reactions", char_data.get("reaction", 1)),
		"reaction": char_data.get("reactions", char_data.get("reaction", 1)),
		"speed": char_data.get("speed", 4),
		"combat_skill": char_data.get("combat_skill", char_data.get("combat", 0)),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		# Planetfall's own key IS "xp" — the bug was on the READ side. This leg's
		# source is a 5PFH (or Bug Hunt) character, and a 5PFH character stores
		# "experience", so get("xp", 0) always returned 0 and every imported veteran
		# started the colony with nothing.
		"xp": _xp_of(char_data),
		"kp": 0,
		"loyalty": "loyal",  # Imported characters start as Loyal (p.24)
		"motivation": "",
		"prior_experience": char_data.get("background", ""),
		"notable_event": "",
		"abilities": [],
		"is_imported": true,
		"source_campaign": source,
		"game_mode": "planetfall"
	}

	if source == "5pfh":
		# Luck → Kill Points: 1 KP per Luck point (Planetfall p.26)
		var luck: int = char_data.get("luck", 0)
		result.kp = luck
		# Personal equipment carries over IF it has Planetfall function
		# (Items that affect Seize Initiative have no function — Planetfall p.27)
		var equipment: Array = char_data.get("equipment", [])
		result["imported_equipment"] = equipment.duplicate(true)
	elif source == "bug_hunt":
		# Tech → Savvy conversion (Planetfall p.26)
		var tech: int = char_data.get("tech", char_data.get("savvy", 0))
		result.savvy = tech
		# Bug Hunt equipment is military property — not transferred (p.27)
		result["imported_equipment"] = []
		# Keep KP as-is
		result.kp = char_data.get("kp", char_data.get("kill_points", 0))

	return result


func attempt_class_training(char_data: Dictionary, desired_class: String = "") -> Dictionary:
	## Attempt the Class Training aptitude test for an imported character (Planetfall p.27).
	## Up to 3 characters total can be trained (1 per class).
	## Returns {success: bool, assigned_class: String, method: String}
	var background: String = char_data.get("prior_experience", "")
	var char_class: String = char_data.get("character_class", "")

	# Load auto-qualify data
	var classes_json := _load_planetfall_json("res://data/planetfall/character_classes.json")
	var training_data: Dictionary = classes_json.get("class_training", {})
	var auto_quals: Dictionary = training_data.get("auto_qualify_backgrounds", {})

	# Check auto-qualification
	for cls in auto_quals:
		var qualifying: Array = auto_quals[cls]
		if background in qualifying or char_class in qualifying:
			if desired_class.is_empty() or desired_class == cls:
				return {"success": true, "assigned_class": cls, "method": "auto_qualify"}

	# Manual aptitude test (D6)
	var dice = Engine.get_main_loop().root.get_node_or_null("/root/DiceManager") if Engine.get_main_loop() else null
	var roll: int
	if dice and dice.has_method("roll_d6"):
		roll = dice.roll_d6()
	else:
		roll = randi_range(1, 6)

	if roll <= 2:
		return {"success": false, "assigned_class": "", "method": "aptitude_test_failed", "roll": roll}
	elif roll == 3:
		# Random class assignment
		var class_roll: int = randi_range(1, 6)
		var assigned: String
		if class_roll <= 2:
			assigned = "trooper"
		elif class_roll <= 4:
			assigned = "scientist"
		else:
			assigned = "scout"
		return {"success": true, "assigned_class": assigned, "method": "aptitude_test_random", "roll": roll}
	else:  # 4-6
		var chosen: String = desired_class if not desired_class.is_empty() else "trooper"
		return {"success": true, "assigned_class": chosen, "method": "aptitude_test_choice", "roll": roll}


func convert_from_planetfall(char_data: Dictionary, ending: String = "") -> Dictionary:
	## Convert a Planetfall character for export to 5PFH (Planetfall pp.165-166).
	## Export rules vary by campaign ending.
	## NOTE: Luck is NOT derived from KP on export. The book is silent on a
	## KP->Luck export conversion (the "prefer the Luck system" note on p.27 is an
	## IMPORT-side option only), so inventing one would violate data integrity.
	## Imported characters restore their real Luck losslessly via the snapshot;
	## a character born in Planetfall returns with base Luck (1).
	var char_id: String = char_data.get("id", "")

	var result := {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", "Unknown"),
		"character_name": char_data.get("name", "Unknown"),
		"game_mode": "standard",
		# DUAL KEY (see Character.to_dictionary): battle reads "reactions",
		# the crew UI reads "reaction". Emitting only the singular here meant a
		# transferred veteran fought at Reactions 1 whatever their real stat.
		"reactions": char_data.get("reactions", char_data.get("reaction", 1)),
		"reaction": char_data.get("reactions", char_data.get("reaction", 1)),
		"speed": char_data.get("speed", 4),
		"combat": char_data.get("combat_skill", 0),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"luck": 1,  # Restore base Luck
		"equipment": [],
		"status": "active",
		"transferred_from_planetfall": true,
		"planetfall_ending": ending
	}
	# Planetfall stores "xp"; 5PFH reads "experience". This dict is 5PFH-bound, so a
	# returning colonist's XP has to change key or it lands unusable.
	_set_xp_5pfh(result, _xp_of(char_data))

	# Ending-specific bonuses (Planetfall pp.165-166)
	match ending:
		"independence_won":
			# "begin with a ship. Pay off the debt normally, but you begin with
			# 2D6 Credits of it already paid off." (NOT full debt forgiveness.)
			result["bonus_ship"] = true
			result["ship_debt_prepaid"] = ((randi() % 6) + 1) + ((randi() % 6) + 1)
			result["bonus_story_points"] = 2  # "In addition (win or lose), +2 Story Points"
		"independence_lost":
			# "1 Rival (even chance Enforcers or Bounty Hunters)."
			result["add_rival"] = "Enforcers" if (randi() % 2) == 0 else "Bounty Hunters"
			result["bonus_story_points"] = 2  # win OR lose
		"loyalty":
			# "begin the campaign with a random ship and no debt."
			result["bonus_ship"] = true
			result["ship_debt"] = 0
		"isolation":
			# Planetfall p.164: "select one character: They gain 1 point of Luck.
			# You may only bring one character from an Isolation victory into each
			# new campaign." The cap is enforced at import — see
			# CampaignScreenBase._apply_pending_transfers(). `isolation_single_char`
			# alone was set and read NOWHERE, so the cap did not exist.
			result.luck += 1
			result["isolation_single_char"] = true
			result["from_isolation_victory"] = true
		"ascension":
			# Planetfall p.164: "select one character: They gain psionic abilities
			# (see 5PFH Compendium, p.17)."
			#
			# `gains_psionic` was set here and read only to append "+Psionic" to a
			# summary STRING — the character arrived with no psionic powers at all.
			# Grant the real thing: Compendium p.17 starting powers, mirroring
			# PsionicSystem.determine_starting_powers() (two rolls on the D10 power
			# table with the p.22 shift on a duplicate), in the String-id shape
			# Character.psionic_powers actually stores.
			result["gains_psionic"] = true
			result["psionic_powers"] = _roll_starting_psionic_powers()

	# Each character can export only 1 artifact (p.164)
	# Planetfall-specific weapons cannot be replaced in other campaigns
	var imported_eq: Array = char_data.get("imported_equipment", [])
	if not imported_eq.is_empty():
		result.equipment = imported_eq.duplicate(true)

	return result


func _load_planetfall_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.data if json.data is Dictionary else {}


## ============================================================================
## TACTICS TRANSFERS (Tactics rulebook p.184)
## ============================================================================

func validate_tactics_enlistment(character_data: Dictionary) -> Dictionary:
	## Check if a 5PFH character is eligible for Tactics enlistment.
	var game_mode: String = character_data.get("game_mode", "standard")
	if game_mode != "standard":
		return {
			"eligible": false,
			"reason": "Character must be from a standard 5PFH campaign",
		}
	var status: String = character_data.get("status", "active")
	if status != "active":
		return {
			"eligible": false,
			"reason": "Character must be active (not injured/dead)",
		}
	return {"eligible": true, "reason": "Eligible for Tactics transfer"}


func convert_to_tactics(
		char_data: Dictionary, source: String = "5pfh") -> Dictionary:
	## Convert a canonical (5PFH-standard) character INTO Tactics (Tactics p.184,
	## "Converting Characters"). Reactions/Speed/Savvy unchanged; Combat capped at
	## +2; Toughness capped at 5; 1 Kill Point per Luck point; Training +1 (+2 with a
	## military-type background); weapons carry over as-is. No points cost — the book
	## says "eyeball the closest equivalent figure". `source` is retained only for
	## provenance flags; the canonical hub always routes the 5PFH-standard form here.
	var char_id: String = char_data.get(
		"id", char_data.get("character_id", ""))

	var combat: int = char_data.get(
		"combat_skill", char_data.get("combat", 0))
	combat = mini(combat, 2)  # Capped at +2

	var toughness: int = char_data.get("toughness", 3)
	toughness = mini(toughness, 5)  # Capped at 5

	# Kill Points: "Crew transferred to Tactics receive 1 Kill Point for each point
	# of Luck" (Tactics p.184). The canonical interchange form carries Luck.
	var kp: int = char_data.get("luck", 0)

	# Training: "+1, or +2 with a military-type background" (Tactics p.184). The book
	# gives NO enumerated list — "military-type" is its sanctioned judgment call — so
	# we classify against the real 5PFH backgrounds (gear_database.json): the two
	# "Military …" backgrounds and "War-Torn Hell-Hole" (a wartime upbringing).
	var training: int = 1
	var background: String = char_data.get(
		"background", char_data.get("prior_experience", "")).to_lower()
	if "military" in background or "war-torn" in background:
		training = 2

	var result := {
		"id": char_id,
		"name": char_data.get(
			"name", char_data.get("character_name", "Unknown")),
		"game_mode": "tactics",
		"speed": char_data.get("speed", 4),
		"reactions": char_data.get(
			"reactions", char_data.get("reaction", 2)),
		"reaction": char_data.get(
			"reactions", char_data.get("reaction", 2)),
		"combat_skill": combat,
		"toughness": toughness,
		"kill_points": kp,
		"savvy": char_data.get("savvy", 0),
		"training": training,
		"saving_throw": 0,
		"is_imported": true,
		"source_campaign": source,
		"transferred_from_5pfh": source == "5pfh",
		"transferred_from_bug_hunt": source == "bug_hunt",
		"transferred_from_planetfall": source == "planetfall",
	}

	# "Carry weapons over as they are" (Tactics p.184) — Tactics does NOT strip
	# equipment as military property (that is a Planetfall / Bug Hunt rule).
	result["imported_equipment"] = char_data.get("equipment", []).duplicate(true)

	return result


func convert_from_tactics(char_data: Dictionary) -> Dictionary:
	## Convert a Tactics character for export to 5PFH (Tactics p.184).
	##   - Reactions / Speed / Combat / Toughness / Savvy: no change
	##   - Each Kill Point after the first becomes 1 point of Luck
	##   - Training is not used in 5PFH (dropped)
	##   - Weapons carry over as they are
	var char_id: String = char_data.get("id", "")

	var kp: int = char_data.get(
		"kill_points", char_data.get("kp", 1))
	# "When transferring from Tactics, each Kill Point after the first becomes
	# 1 point of Luck" (Tactics p.184).
	var luck: int = maxi(kp - 1, 0)

	return {
		"id": char_id,
		"character_id": char_id,
		"name": char_data.get("name", "Unknown"),
		"character_name": char_data.get("name", "Unknown"),
		"game_mode": "standard",
		# DUAL KEY — see Character.to_dictionary().
		"reactions": char_data.get("reactions", char_data.get("reaction", 2)),
		"reaction": char_data.get("reactions", char_data.get("reaction", 2)),
		"speed": char_data.get("speed", 4),
		"combat": char_data.get("combat_skill", 0),
		"toughness": char_data.get("toughness", 3),
		"savvy": char_data.get("savvy", 0),
		"luck": luck,
		# Tactics has no XP track (it converts Kill Points to Luck above), so a
		# born-in-Tactics veteran genuinely returns with 0. Written under both keys
		# purely for consistency with the other return legs — no behaviour change,
		# since a missing "experience" already reads as 0.
		"experience": 0,
		"xp": 0,
		# "Carry weapons over as they are" (Tactics p.184).
		"equipment": char_data.get("imported_equipment", char_data.get("equipment", [])),
		"status": "active",
		"transferred_from_tactics": true,
	}
