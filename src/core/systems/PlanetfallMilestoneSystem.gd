class_name PlanetfallMilestoneSystem
extends RefCounted

## Tracks milestone progression and applies milestone effects.
## 7 milestones required for End Game. Each triggers lifeform evolution
## and additional replacement. Milestones earned from Buildings, Research,
## Augmentations, and Alien Artifacts.
## Source: Planetfall pp.156-160

const LifeformScript := preload("res://src/core/systems/PlanetfallLifeformGenerator.gd")
const EnemyScript := preload("res://src/core/systems/PlanetfallTacticalEnemyGenerator.gd")
const MissionDataScript := preload("res://src/core/systems/PlanetfallMissionDataSystem.gd")
const CalamityScript := preload("res://src/core/systems/PlanetfallCalamitySystem.gd")
const ConditionScript := preload("res://src/core/systems/PlanetfallConditionSystem.gd")
const MapScript := preload("res://src/core/systems/PlanetfallMap.gd")

## The four kinds of source on p.156's "Tech that Grants Milestones" list, in the order a
## step checks them, with the name a receipt uses.
const SOURCE_CATEGORIES := {
	"buildings": "Building",
	"research_applications": "Research Application",
	"augmentations": "Augmentation",
	"alien_artifacts": "Alien Artifact",
}
const MILESTONES_REQUIRED := 7

var _milestone_data: Dictionary = {}
var _milestones: Array = []
var _tech_grants: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	_milestone_data = _load_json("res://data/planetfall/milestone_effects.json")
	_milestones = _milestone_data.get("milestones", [])
	_tech_grants = _milestone_data.get("tech_that_grants_milestones", {})
	_loaded = not _milestones.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallMilestoneSystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallMilestoneSystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## MILESTONE EFFECTS
## ============================================================================

func get_milestone_effects(index: int) -> Array:
	## Returns the effects array for the given milestone number (1-7).
	for milestone in _milestones:
		if milestone is Dictionary and milestone.get("index", 0) == index:
			return milestone.get("effects", [])
	return []


## The milestone numbers whose effects include `effect_type`, ascending. A screen that
## names when something happens reads it here: the Enemy Tracker printed "Milestones
## 1, 2, and 5" for the Tactical Enemy arrivals, which p.50 and this table put at 1-3.
func milestones_with_effect(effect_type: String) -> Array:
	var out: Array = []
	for index in range(1, MILESTONES_REQUIRED + 1):
		for effect in get_milestone_effects(index):
			if effect is Dictionary and str(effect.get("type", "")) == effect_type:
				out.append(index)
				break
	return out


func apply_milestone(campaign: Resource, milestone_index: int) -> Dictionary:
	## Apply all effects for this milestone to the campaign.
	## Does NOT create sub-systems — returns what needs to happen so the
	## caller can orchestrate (e.g., TurnController creates enemy generators).
	## Returns a summary dict of actions taken and actions needed.
	var result: Dictionary = {
		"milestone": milestone_index,
		"effects_applied": [],
		"actions_needed": []
	}

	if not campaign:
		return result

	var effects: Array = get_milestone_effects(milestone_index)

	for effect in effects:
		if effect is not Dictionary:
			continue
		var etype: String = effect.get("type", "")

		match etype:
			"story_points":
				var amount: int = effect.get("amount", 0)
				if campaign.has_method("add_story_points"):
					campaign.add_story_points(amount)
				result["effects_applied"].append("+%d Story Points" % amount)

			"colony_integrity":
				var amount: int = effect.get("amount", 0)
				# p.87: an Integrity BONUS raises the maximum with the current score.
				if campaign.has_method("raise_integrity"):
					campaign.raise_integrity(amount)
				result["effects_applied"].append("+%d Colony Integrity" % amount)

			"augmentation_points":
				var amount: int = effect.get("amount", 0)
				if "augmentation_points" in campaign:
					campaign.augmentation_points += amount
				result["effects_applied"].append("+%d Augmentation Points" % amount)

			"grunts":
				var amount: int = effect.get("amount", 0)
				if campaign.has_method("gain_grunts"):
					campaign.gain_grunts(amount)
				result["effects_applied"].append("+%d grunts" % amount)

			"ancient_sign":
				var amount: int = effect.get("amount", 0)
				result["effects_applied"].append("+%d Ancient Sign(s)" % amount)
				# p.61: each Sign is tested for an Ancient Site as it is obtained.
				result["effects_applied"].append_array(
						MapScript.obtain_ancient_signs(campaign, amount))

			"mission_data":
				var amount: int = effect.get("amount", 0)
				result["actions_needed"].append({
					"action": "add_mission_data",
					"amount": amount
				})

			"calamity_points":
				var amount: int = effect.get("amount", 0)
				if "calamity_points" in campaign:
					campaign.calamity_points += amount
				result["actions_needed"].append({
					"action": "check_calamity",
					"calamity_points_added": amount
				})

			"tactical_enemy_emerges":
				result["actions_needed"].append({
					"action": "create_tactical_enemy"
				})

			# The extra rolls are queued for their own steps (pp.156-157 "in addition to
			# the normal event you would receive each turn"). Milestones arrive at Steps
			# 14-15, so Character Events fall at Step 17 this turn and Colony Event /
			# Enemy Activity at Steps 5 / 4 of the next.
			"character_events":
				var count: int = effect.get("count", 0)
				if campaign.has_method("queue_extra_roll"):
					campaign.queue_extra_roll("character_event", count)
				result["effects_applied"].append(
						"%d extra Character Events, rolled at Step 17 this turn" % count)

			"colony_event":
				if campaign.has_method("queue_extra_roll"):
					campaign.queue_extra_roll("colony_event", 1)
				result["effects_applied"].append(
						"1 extra Colony Event, rolled at Step 5 next turn")

			"enemy_expansion":
				result["actions_needed"].append({
					"action": "expand_enemies"
				})

			"enemy_activity_roll":
				if campaign.has_method("queue_extra_roll"):
					campaign.queue_extra_roll("enemy_activity", 1)
				result["effects_applied"].append(
						"1 extra Enemy Activity roll, made at Step 4 next turn")

			"tactical_enemy_buff":
				if campaign.has_method("set_milestone_flag"):
					campaign.set_milestone_flag("tactical_panic_reduction", 1)
					campaign.set_milestone_flag("tactical_specialist_kp", 1)
				result["effects_applied"].append("From now on Tactical Enemies reduce their "
						+ "Panic range by 1, and every tactical specialist has +1 KP")

			"tactical_enemy_specialist_buff":
				if campaign.has_method("set_milestone_flag"):
					campaign.set_milestone_flag("tactical_extra_specialists", 1)
				result["effects_applied"].append(
						"From now on every Tactical Enemy encounter adds 1 specialist figure")

			"enemy_activity_all":
				if campaign.has_method("set_milestone_flag"):
					campaign.set_milestone_flag("enemy_activity_every_enemy", true)
				result["effects_applied"].append(
						"From now on Step 4 rolls Enemy Activity for every enemy on the map")

			"replace_condition":
				# p.156: these effects "occur immediately", so a table with nothing
				# written in it yet has nothing to erase, and nothing is owed later.
				if ConditionScript.get_condition_count(campaign) == 0:
					result["effects_applied"].append("No campaign battlefield condition "
							+ "has been generated yet, so there is none to erase")
				elif "pending_condition_replacements" in campaign:
					campaign.pending_condition_replacements += 1
					result["effects_applied"].append("Erase one campaign battlefield "
							+ "condition and generate a new one: choose which on the "
							+ "dashboard's Milestones & Progression card")

			"slyn_tracking_begins":
				# p.157: "Victories prior to this point are not counted."
				if "slyn_victories" in campaign:
					campaign.slyn_victories = 0
				if campaign.has_method("set_milestone_flag"):
					campaign.set_milestone_flag("slyn_tracking", true)
				result["effects_applied"].append("Victories over the Slyn are tracked from now on")

			"endgame_launches":
				if "game_phase" in campaign:
					campaign.game_phase = "endgame"
				result["effects_applied"].append("The End Game launches at the end of this turn")

	# Every milestone also rolls a Lifeform Evolution (p.158). Its "one additional
	# replacement" needs no action: Step 13 already allows 1 attempt + 1 per Milestone
	# (p.68), counted from milestones_completed.
	result["actions_needed"].append({"action": "roll_lifeform_evolution"})
	result["effects_applied"].append("One more replacement attempt each turn from now on")

	# Increment milestone count
	if campaign.has_method("add_milestone"):
		campaign.add_milestone()

	return result


## ============================================================================
## MILESTONE CHECKING
## ============================================================================

func check_tech_grants_milestone(tech_type: String, tech_id: String) -> bool:
	## Check if a building/research/augmentation/artifact grants a milestone.
	var grant_list: Array = _tech_grants.get(tech_type, [])
	return tech_id in grant_list


func get_milestone_granting_tech() -> Dictionary:
	## Returns the full tech_that_grants_milestones dict for UI display.
	return _tech_grants.duplicate(true)


func get_progress_summary(campaign: Resource) -> Dictionary:
	if not campaign:
		return {}
	var completed: int = campaign.milestones_completed if "milestones_completed" in campaign else 0
	return {
		"completed": completed,
		"total_required": _milestone_data.get("total_required", 7),
		"endgame_eligible": completed >= 7,
		"next_milestone": completed + 1 if completed < 7 else 0,
		"next_effects": get_milestone_effects(completed + 1) if completed < 7 else []
	}


## ============================================================================
## CALAMITY CHECK
## ============================================================================

func check_calamity_trigger(campaign: Resource) -> bool:
	## Planetfall p.165 — Roll 1D6, if <= calamity_points, a Calamity occurs.
	## Subtract the roll from calamity_points. Never once Calamities have ended (p.158).
	if not campaign or not "calamity_points" in campaign:
		return false
	if campaign.has_method("get_milestone_flag") \
			and bool(campaign.get_milestone_flag("calamities_ended", false)):
		return false
	var points: int = campaign.calamity_points
	if points <= 0:
		return false
	var roll: int = _d6("Planetfall Calamity Check")
	if roll <= points:
		campaign.calamity_points -= roll
		return true
	return false


## The p.165 check plus its D100, as receipt lines. At the 7th Milestone a check that
## raises no Calamity ends them for good (p.158).
func resolve_calamity_check(campaign: Resource, final_milestone: bool) -> Array:
	if campaign.has_method("get_milestone_flag") \
			and bool(campaign.get_milestone_flag("calamities_ended", false)):
		return ["Calamities have ended for this campaign"]
	if check_calamity_trigger(campaign):
		# "Calamity Table", not "Calamity": forcing matches a SUBSTRING, so a value armed
		# for "Planetfall Calamity" would be eaten by the "Planetfall Calamity Check" D6.
		var calamity: Dictionary = CalamityScript.new().trigger_calamity(
				campaign, _d100("Planetfall Calamity Table"))
		if calamity.is_empty():
			return ["A Calamity would strike, but every Calamity has already occurred"]
		return ["Calamity: %s" % str(calamity.get("name", "Unknown"))]
	var lines: Array = ["No Calamity; %d Calamity Points carried forward"
			% int(campaign.calamity_points)]
	if final_milestone and campaign.has_method("set_milestone_flag"):
		campaign.set_milestone_flag("calamities_ended", true)
		lines.append("No Calamity at the 7th Milestone: Calamities end for the rest "
				+ "of the campaign")
	return lines


## ============================================================================
## MILESTONE DELIVERY (pp.156-158)
## ============================================================================

## Every owned item on p.156's list, as "category:id", in a fixed order.
func owned_granting_sources(campaign: Resource) -> Array:
	var out: Array = []
	if not campaign:
		return out
	var owned: Dictionary = {
		"buildings": _owned(campaign, "buildings_data", "constructed"),
		"research_applications": _owned(campaign, "research_data", "unlocked_applications"),
		"augmentations": _owned(campaign, "research_data", "augmentations_owned"),
		"alien_artifacts": [],
	}
	if "artifacts_found" in campaign:
		for artifact in campaign.artifacts_found:
			if artifact is Dictionary:
				owned["alien_artifacts"].append(str(artifact.get("id", "")))
	for category in SOURCE_CATEGORIES:
		for id in owned[category]:
			var key := "%s:%s" % [category, str(id)]
			if check_tech_grants_milestone(category, str(id)) and not out.has(key):
				out.append(key)
	return out


## The sources that have not granted yet, now claimed. A save from before
## milestone_sources existed claims what it owns WITHOUT granting (see the core).
func claim_new_sources(campaign: Resource) -> Array:
	if not campaign or not "milestone_sources" in campaign:
		return []
	var owned: Array = owned_granting_sources(campaign)
	if campaign.milestone_sources_unseeded:
		campaign.milestone_sources = owned.duplicate()
		campaign.milestone_sources_unseeded = false
		return []
	var fresh: Array = []
	for key in owned:
		if not campaign.milestone_sources.has(key):
			campaign.milestone_sources.append(key)
			fresh.append(key)
	return fresh


## One Milestone per newly claimed source (p.156), each applied and every action it
## owes resolved now ("These occur immediately upon achieving that Milestone").
## Returns {milestones: [{index, source, lines}], lines}. Called by the phase manager
## when Research (Step 14) and Building (Step 15) complete.
func deliver_new_milestones(campaign: Resource) -> Dictionary:
	var receipt: Dictionary = {"milestones": [], "lines": []}
	if not campaign:
		return receipt
	for key in claim_new_sources(campaign):
		var index: int = int(campaign.milestones_completed) + 1
		if index > MILESTONES_REQUIRED:
			receipt.lines.append("%s is on the Milestone list, but all %d Milestones are "
					% [source_name(key), MILESTONES_REQUIRED] + "already achieved")
			continue
		var entry: Dictionary = deliver_milestone(campaign, index, key)
		receipt.milestones.append(entry)
		receipt.lines.append_array(entry.lines)
	return receipt


func deliver_milestone(campaign: Resource, index: int, source_key: String = "") -> Dictionary:
	var result: Dictionary = apply_milestone(campaign, index)
	var heading: String = "Milestone %d achieved" % index
	if source_key != "":
		heading += " (%s)" % source_name(source_key)
	var lines: Array = [heading]
	for text in result.get("effects_applied", []):
		lines.append(str(text))
	for action in result.get("actions_needed", []):
		if action is Dictionary:
			lines.append_array(_resolve_action(campaign, index, action))
	return {"index": index, "source": source_key, "lines": lines}


## "buildings:galactic_comms_relay" -> "Galactic Comms Relay (Building)".
func source_name(key: String) -> String:
	var parts: PackedStringArray = key.split(":", false, 1)
	if parts.size() < 2:
		return key
	return "%s (%s)" % [parts[1].replace("_", " ").capitalize(),
			str(SOURCE_CATEGORIES.get(parts[0], parts[0]))]


func _resolve_action(campaign: Resource, index: int, action: Dictionary) -> Array:
	match str(action.get("action", "")):
		"create_tactical_enemy":
			var enemy: Dictionary = EnemyScript.new().create_full_enemy(campaign)
			if enemy.is_empty():
				return ["No Tactical Enemy could be generated"]
			var enemy_type: Dictionary = enemy.get("type", {}) \
					if enemy.get("type") is Dictionary else {}
			# pp.156-157: the 1st keeps clear of the colony; the 2nd and 3rd of any other
			# enemy's sectors as well. The enemy takes its sector on the map here.
			var at: String = MapScript.emerge(campaign, campaign.tactical_enemies.size() - 1,
					index > 1)
			return ["A Tactical Enemy emerges: %s. It controls %s, clear of %s (p.%d)." % [
					str(enemy_type.get("name", "Tactical Enemy")),
					MapScript.label(at) if at != "" else "no free map sector",
					"your colony" if index == 1 else "your colony and every other enemy",
					156 if index <= 2 else 157]]
		"roll_lifeform_evolution":
			var evo: Dictionary = LifeformScript.new().evolve_random(campaign)
			var slot_no: int = int(evo.get("slot", 0)) + 1
			if bool(evo.get("exhausted", false)):
				return ["Lifeform Evolution: encounter entry %d already has every evolution"
						% slot_no]
			var picked: Dictionary = evo.get("evolution", {})
			if picked.is_empty():
				return ["Lifeform Evolution: no new evolution could be found for entry %d"
						% slot_no]
			var line: String = "Lifeform Evolution: encounter entry %d gains %s" % [
					slot_no, str(picked.get("name", picked.get("id", "")))]
			if bool(evo.get("pending", false)):
				line += " (noted; it applies when that entry is first filled)"
			return [line]
		"add_mission_data":
			return _add_mission_data(campaign, int(action.get("amount", 0)))
		"check_calamity":
			return resolve_calamity_check(campaign, index == MILESTONES_REQUIRED)
		"expand_enemies":
			# p.156 2nd Milestone: "Every enemy on the map expands to occupy a random map
			# sector adjacent to them." p.62's "If this would be your colony ... Raid" is the
			# Enemy Activity rule, so this expansion never picks the colony at all.
			var lines: Array = []
			for i in MapScript.active_indices(campaign):
				lines.append_array(MapScript.expand(campaign, i, 1, false).get("lines", []))
			return lines if not lines.is_empty() \
					else ["No Tactical Enemy is on the map to expand"]
	return []


func _add_mission_data(campaign: Resource, amount: int) -> Array:
	return MissionDataScript.new().receive(campaign, amount, "Milestone")

func _owned(campaign: Resource, store: String, key: String) -> Array:
	if not store in campaign:
		return []
	var d: Variant = campaign.get(store)
	var list: Variant = d.get(key, []) if d is Dictionary else []
	return list if list is Array else []


static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


func _d6(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d6(context)) if dm else randi_range(1, 6)


func _d100(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)


func is_loaded() -> bool:
	return _loaded
