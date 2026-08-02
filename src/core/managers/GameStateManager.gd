extends Node

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const _ShipComponentQuery = preload("res://src/core/ship/ShipComponentQuery.gd")

signal game_state_changed(new_state: int)
signal credits_changed(new_amount: int)
signal supplies_changed(new_amount: int)
signal reputation_changed(new_amount: int)
signal story_progress_changed(new_amount: int)

@export var initial_credits: int = 0  # Set during campaign creation (Core Rules p.28)
@export var initial_supplies: int = 5
@export var initial_reputation: int = 0

var game_state: GameState = null
var campaign_phase: int = 0 # Using 0 as default (equivalent to NONE)
var difficulty_level: int = GameEnums.DifficultyLevel.NORMAL
var credits: int = initial_credits
var supplies: int = initial_supplies
var reputation: int = initial_reputation
var story_progress: int = 0

# Settings
var enable_tutorials: bool = true
var auto_save_enabled: bool = true
var language: String = "English"
var settings: Dictionary = {
	"disable_tutorial_popup": false,
	"tutorial_active": false,
}

# Temp data keys for inter-screen communication
const TEMP_KEY_SELECTED_CHARACTER := "selected_character"

# Temp data storage (cleared on scene change)
var _temp_data: Dictionary = {}

func _ready() -> void:
	# Initialize with default values
	set_credits(initial_credits)
	set_supplies(initial_supplies)
	set_reputation(initial_reputation)
	set_story_progress(0)
	load_settings()
	# Defer campaign sync to ensure all autoloads are ready
	call_deferred("_connect_campaign_signals")

func _connect_campaign_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		return
	# BUG-031 FIX: Assign game_state so set_credits()/set_supplies()/etc.
	# can write back to campaign Resource for save persistence
	game_state = gs
	if gs.has_signal("campaign_loaded"):
		gs.campaign_loaded.connect(_on_campaign_loaded)
	# If a campaign was already auto-loaded before we connected, sync now
	var campaign = gs.get("current_campaign")
	if campaign != null:
		_on_campaign_loaded(campaign)

## Sync internal resource tracking from loaded campaign data
func _on_campaign_loaded(campaign) -> void:
	if campaign == null:
		return
	var loaded_credits = campaign.get("credits")
	if loaded_credits != null:
		set_credits(int(loaded_credits))
	var loaded_supplies = campaign.get("supplies")
	if loaded_supplies != null:
		set_supplies(int(loaded_supplies))
	var loaded_reputation = campaign.get("reputation")
	if loaded_reputation != null:
		set_reputation(int(loaded_reputation))
	var loaded_story = campaign.get("story_points")
	if loaded_story != null:
		set_story_progress(int(loaded_story))

# State management
func set_game_state(new_state: GameState) -> void:
	if game_state != new_state:
		game_state = new_state
		game_state_changed.emit(game_state)



# Settings management
	
func set_auto_save_enabled(enabled: bool) -> void:
	auto_save_enabled = enabled
	

# Resource management.
# PHASE 2.1 (persistence audit): the canonical owner of credits / supplies /
# reputation / story_points is the FiveParsecsCampaignCore Resource. These
# setters write through to the campaign and mirror into the local instance
# var for UI consumers that still read GameStateManager directly. The legacy
# `progress_data["credits"/"supplies"/"reputation"/"story_points"]` sync was
# a dead write target (nobody read it back) and has been removed.
## All three setters below follow the shape set_story_progress already uses
## (see its comment at the "Write through ... UNCONDITIONALLY" block): the owner
## write is NOT change-guarded, because the local mirror can already equal
## new_amount while the campaign Resource is stale — right after a campaign
## switch, or after any code that wrote campaign.<field> directly. Only the mirror
## update and the signal are guarded. The guard itself compares against the FRESH
## value via the getter, so a direct owner write is never mistaken for "no change".

func set_credits(new_amount: int) -> void:
	var current := get_credits()
	if game_state and game_state.current_campaign and "credits" in game_state.current_campaign:
		game_state.current_campaign.credits = new_amount
	if current != new_amount:
		credits = new_amount
		credits_changed.emit(credits)

func set_supplies(new_amount: int) -> void:
	var current := get_supplies()
	var camp = game_state.current_campaign if game_state else null
	if camp and "supplies" in camp:
		camp.supplies = new_amount
	if current != new_amount:
		supplies = new_amount
		supplies_changed.emit(supplies)

func set_reputation(new_amount: int) -> void:
	var current := get_reputation()
	var camp = game_state.current_campaign if game_state else null
	if camp and "reputation" in camp:
		camp.reputation = new_amount
	if current != new_amount:
		reputation = new_amount
		reputation_changed.emit(reputation)

func set_story_progress(new_amount: int) -> void:
	# Write through to the canonical owner UNCONDITIONALLY: the local mirror
	# can already equal new_amount while the campaign Resource is stale
	# (e.g. right after a campaign switch), and skipping the write inside the
	# change-guard would leave the owner out of sync. Mirror update + signal
	# stay change-guarded.
	var camp = game_state.current_campaign if game_state else null
	if camp and "story_points" in camp:
		camp.story_points = new_amount
	if story_progress != new_amount:
		story_progress = new_amount
		story_progress_changed.emit(story_progress)

# Getters

func _canonical_int(field: String, cached: int) -> int:
	## Re-read a resource value from its CANONICAL OWNER before returning it.
	##
	## `credits` / `supplies` / `reputation` / `story_progress` on this manager are
	## CACHES. FiveParsecsCampaignCore's top-level @vars own them (data-ownership
	## table, CLAUDE.md). Returning the cache unchecked is what made the resource
	## arithmetic lossy: add_credits/remove_credits/modify_credits/modify_story_progress
	## all compute `set_X(f(get_X()))`, so they derived the new canonical value FROM
	## THE CACHE. Any code that wrote the owner directly was therefore invisible to
	## them and got silently reverted by the next write.
	##
	## Concretely (RedZoneSystem.gd:108): `campaign.credits -= 15` for the Red Zone
	## licence, then `_commit_zone_travel` calls modify_credits(-5) computed from the
	## stale cache — the 15cr fee is refunded and the player keeps the licence.
	## Core Rules Appendix III's endgame gate was free. Other direct writers with the
	## same exposure: AdvancementPhasePanel.gd:553/557, PostBattleSequence.gd:2594,
	## ShiplessSystem.gd:53/135, CharacterGeneration.gd:443.
	##
	## Note `c.get(field)` is the ONE-arg Object.get(), which is valid. The two-arg
	## Dictionary-style .get(key, default) on a Resource is an invalid call that
	## silently aborts the caller — do not "improve" this into that.
	var c = _get_campaign()
	if c and field in c:
		return int(c.get(field))
	return cached


func get_game_state() -> GameState:
	return game_state


func get_difficulty() -> int:
	return difficulty_level

func get_credits() -> int:
	credits = _canonical_int("credits", credits)
	return credits


func get_supplies() -> int:
	supplies = _canonical_int("supplies", supplies)
	return supplies


func get_reputation() -> int:
	reputation = _canonical_int("reputation", reputation)
	return reputation

func get_story_progress() -> int:
	story_progress = _canonical_int("story_points", story_progress)
	return story_progress

# Campaign lifecycle
func has_active_campaign() -> bool:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("has_active_campaign"):
		return gs.has_active_campaign()
	return false

func start_new_campaign() -> void:
	# Clear all residual state from previous sessions
	# (Battle Simulator, Bug Hunt, etc.) so campaign creation
	# starts with a clean slate
	clear_all_temp_data()

	# Null out any stale campaign reference in GameState
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.current_campaign = null

func set_tutorial_state(enabled: bool) -> void:
	settings["tutorial_active"] = enabled

# Temp data methods for inter-screen communication
func set_temp_data(key: String, value) -> void:
	_temp_data[key] = value

func get_temp_data(key: String, default = null):
	return _temp_data.get(key, default)

func has_temp_data(key: String) -> bool:
	return _temp_data.has(key)

func clear_temp_data(key: String) -> void:
	_temp_data.erase(key)

func clear_all_temp_data() -> void:
	_temp_data.clear()

func mark_campaign_modified() -> void:
	pass

# Navigation helpers
func navigate_to_screen(screen_name: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router:
		router.navigate_to(screen_name)
	else:
		push_error("GameStateManager: SceneRouter not found")

func navigate_to_scene_path(scene_path: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to_scene"):
		router.navigate_to_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

# Save/load settings
func save_settings() -> void:
	var config = ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save("user://game_settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://game_settings.cfg") == OK:
		for key in settings:
			settings[key] = config.get_value("settings", key, settings[key])

# --- Campaign data helper ---

func _get_campaign() -> Resource:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_current_campaign"):
		return gs.get_current_campaign()
	return null

# --- Narrative event gating ---
#
# Canonical helper for the 4 narrative integrations (StoryPhasePanel,
# CharacterPhasePanel, CrewTaskComponent, TravelPhaseUI). Returns the
# combined gate: per-campaign override (if set) wins, otherwise the
# global Settings checkbox. The B2 battle bridge in CampaignTurnController
# has its own 3-tier gate (this helper + per-battle override) but reads
# the same `narrative_wrap_override` field so the override is consistent
# across every narrative surface.
#
# Per-campaign override lives on `campaign.progress_data["narrative_wrap_override"]`:
#   null  → use global setting (default)
#   true  → always on for this campaign
#   false → always off for this campaign

func are_narrative_events_enabled() -> bool:
	var campaign := _get_campaign()
	if campaign and "progress_data" in campaign:
		var pd: Dictionary = campaign.progress_data
		var override = pd.get("narrative_wrap_override", null)
		if override != null:
			return bool(override)
	var settings = get_node_or_null("/root/SettingsManager")
	if settings == null or not settings.has_method("are_narrative_events_enabled"):
		return false
	return bool(settings.are_narrative_events_enabled())


func set_narrative_wrap_override(value) -> void:
	# Pass null to clear, true/false to set. Persists via progress_data.
	var campaign := _get_campaign()
	if campaign == null or not ("progress_data" in campaign):
		return
	if value == null:
		campaign.progress_data.erase("narrative_wrap_override")
	else:
		campaign.progress_data["narrative_wrap_override"] = bool(value)



# --- Credit arithmetic ---

## Adds `amount` (may be negative) to credits, clamped at 0 — credits can never
## go negative (Core Rules: you cannot spend below 0). This clamp is the safety
## net that a "Life Support Upgrade" style unaffordable cost once bypassed.
## For cost deductions prefer `modify_credits(-cost)` (identical clamp, clearer
## intent) or `remove_credits(cost)` (gates on affordability, returns bool).
func add_credits(amount: int) -> void:
	set_credits(max(0, get_credits() + amount))

func remove_credits(amount: int) -> bool:
	var current = get_credits()
	if current < amount:
		return false
	set_credits(current - amount)
	return true

func modify_credits(amount: int) -> void:
	set_credits(max(0, get_credits() + amount))

# --- Story point / progress arithmetic ---

func add_story_points(amount: int) -> void:
	var c = _get_campaign()
	if c:
		# Insanity mode: story points disabled entirely (Core Rules p.65)
		if DifficultyModifiers.are_story_points_disabled(c.difficulty):
			return
		set_story_progress(c.story_points + amount)

func modify_story_progress(amount: int) -> void:
	var c = _get_campaign()
	if c and DifficultyModifiers.are_story_points_disabled(c.difficulty):
		return
	set_story_progress(max(0, get_story_progress() + amount))

# --- Progress counter increments (BUG-031 fix) ---

func increment_turns_played() -> void:
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["turns_played"] = c.progress_data.get("turns_played", 0) + 1

## Directly set the campaign turn counter (progress_data["turns_played"]). Sanctioned
## write-through for the Campaign Editor (onboarding a mid-campaign game / corrections);
## CampaignPhaseManager remains the normal advance path via increment_turns_played().
## Clamped to >= 0. NOTE: the Story Track clock is a separate field — this only moves the
## turn counter (display + a few turn-gate reads), not the story clock.
func set_turns_played(n: int) -> void:
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["turns_played"] = max(0, n)

func increment_missions_completed() -> void:
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["missions_completed"] = c.progress_data.get("missions_completed", 0) + 1

func increment_battles_won() -> void:
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["battles_won"] = c.progress_data.get("battles_won", 0) + 1

func increment_battles_lost() -> void:
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["battles_lost"] = c.progress_data.get("battles_lost", 0) + 1

func increment_unique_individual_kills(count: int = 1) -> void:
	## Campaign-level tally behind the "Kill 10/25 Unique Individuals" Victory
	## Conditions (Core Rules p.64). Per-battle unique kills already travel on the
	## battle result (BattleResultsInputForm -> ExperienceTrainingProcessor), but
	## nothing has ever ACCUMULATED them, so the two conditions had no number to
	## read even once they were mapped.
	if count <= 0:
		return
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["unique_individuals_killed"] = \
			c.progress_data.get("unique_individuals_killed", 0) + count

func record_character_upgrade_milestone(count: int = 1) -> void:
	## Counts CHARACTERS who have reached 10 Upgrades, for the three "Upgrade N
	## Characters 10 Times" Victory Conditions (Core Rules p.64).
	##
	## Deliberately a count of characters, not of upgrades: "the characters do not
	## have to be in the crew at the same time. If one character Upgrades 10 times
	## and dies, all 10 Character Upgrades still count" — so once a character has
	## banked the milestone it survives their death, and the live roster is the
	## wrong place to compute it from.
	if count <= 0:
		return
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["characters_upgraded_10"] = \
			c.progress_data.get("characters_upgraded_10", 0) + count

# --- Reputation arithmetic ---

func add_reputation(amount: int) -> void:
	set_reputation(get_reputation() + amount)

# --- Crew data delegation ---

func get_crew_members() -> Array:
	var c = _get_campaign()
	if c and c.has_method("get_crew_members"):
		return c.get_crew_members()
	return []

func get_crew_size() -> int:
	var c = _get_campaign()
	if c and c.has_method("get_crew_size"):
		return c.get_crew_size()
	return 0

func get_deployable_crew() -> Array:
	## Returns crew members eligible for battle deployment (single filter authority).
	## Excludes, per the Core Rules:
	##  - DEAD / MISSING / RETIRED (status);
	##  - Sick Bay / recovering from an Injury — recovery_turns > 0 (p.55 "cannot
	##    participate in battles"; p.76 they may rejoin only once recovery reaches 0);
	##  - Character-Events status effects "departed" or "skip_next_battle" (pp.128-130).
	## (Note: p.156 allows Sick Bay crew as "Impaired" in one special scenario — not the
	##  general deployment case; handle at that scenario if/when built.)
	return filter_deployable(get_crew_members())

## Filters a given crew array down to battle-deployable members (single filter
## authority — the battle-deployment sites route their get_active_crew() result
## through this so "what you can select" and "what deploys" cannot drift).
func filter_deployable(crew: Array) -> Array:
	var deployable: Array = []
	for member in crew:
		if _is_deployable_member(member):
			deployable.append(member)
	return deployable

## True if a crew member may be selected/deployed for battle. See get_deployable_crew.
func _is_deployable_member(member) -> bool:
	# 1) Out-of-action status
	var status_val: String = ""
	if member is Resource and "status" in member:
		status_val = str(member.status)
	elif member is Dictionary:
		status_val = str(member.get("status", "ACTIVE"))
	if status_val in ["DEAD", "RETIRED", "MISSING"]:
		return false
	# 2) Sick Bay / recovering (recovery_turns > 0 = unavailable, p.55/p.76)
	var recovery: int = 0
	var in_sick_bay: bool = false
	if member is Resource:
		if "current_recovery_turns" in member:
			recovery = int(member.current_recovery_turns)
		if "in_sick_bay" in member:
			in_sick_bay = bool(member.in_sick_bay)
	elif member is Dictionary:
		in_sick_bay = bool(member.get("in_sick_bay", false))
		recovery = int(member.get("recovery_turns", 0))
	if in_sick_bay or recovery > 0:
		return false
	# 3) Character-Events status effects: departed / skip_next_battle exclude this battle
	var effects: Array = []
	if member is Resource and "status_effects" in member:
		effects = member.status_effects
	elif member is Dictionary:
		effects = member.get("status_effects", [])
	for eff in effects:
		if eff is Dictionary and str(eff.get("type", "")) in ["departed", "skip_next_battle"]:
			return false
	return true

## Returns the campaign crew size SETTING (4, 5, or 6) from Core Rules p.63.
## Used for enemy numbers, deployment limits, reaction dice — NOT roster count.
func get_campaign_crew_size() -> int:
	var c = _get_campaign()
	if c and c.has_method("get_campaign_crew_size"):
		return c.get_campaign_crew_size()
	return 6

# --- Ship data delegation ---

func get_ship() -> Dictionary:
	var c = _get_campaign()
	if c and c.has_method("get_ship"):
		return c.get_ship()
	return {}

func get_ship_data() -> Dictionary:
	## Alias for get_ship() — needed by TravelPhase and WorldPhase
	return get_ship()

func set_invasion_pending(pending: bool) -> void:
	## Set invasion state (Core Rules p.88). Called by PaymentProcessor.
	var gs = game_state if game_state else get_node_or_null(
		"/root/GameState")
	if gs and gs.has_method("set_invasion_pending"):
		gs.set_invasion_pending(pending)

func has_pending_invasion() -> bool:
	## Check invasion state. Called by TravelPhase.
	var gs = game_state if game_state else get_node_or_null(
		"/root/GameState")
	if gs and gs.has_method("has_pending_invasion"):
		return gs.has_pending_invasion()
	return false

func apply_ship_damage(amount: int) -> int:
	## Apply hull damage with trait modifiers (Core Rules p.30)
	## Returns actual damage dealt after trait effects
	var c = _get_campaign()
	if not c:
		return amount
	var ship: Dictionary = c.ship_data
	var traits: Array = ship.get("traits", [])
	var final_amount: int = amount

	# Armored: reduce all hull damage by 1 (Core Rules p.30)
	for t in traits:
		if str(t).to_lower() == "armored":
			final_amount = maxi(0, final_amount - 1)
			break

	# Improved Shielding: reduce each hit by 1 HP (Core Rules p.62)
	if _ShipComponentQuery.has_component("improved_shielding"):
		var pre_shield: int = final_amount
		final_amount = maxi(0, final_amount - 1)
		if pre_shield != final_amount:
			var journal: Node = Engine.get_main_loop().root.get_node_or_null(
				"/root/CampaignJournal") if Engine.get_main_loop() else null
			if journal and journal.has_method("create_entry"):
				journal.create_entry({
					"type": "ship",
					"title": "Shields Absorbed Impact",
					"description": (
						"Improved Shielding reduced hull damage"
						+ " by 1 (took %d instead of %d HP)." % [
						final_amount, pre_shield]),
					"tags": ["ship_component", "improved_shielding"],
					"auto_generated": true,
					"mood": "neutral",
					"stats": {"damage_reduced": 1},
				})

	# Dodgy Drive: 2D6 <= damage => +2 extra (Core Rules p.30)
	for t in traits:
		if "dodgy" in str(t).to_lower():
			var dodgy_roll: int = randi_range(1, 6) + randi_range(1, 6)
			if dodgy_roll <= final_amount:
				final_amount += 2
			break

	var current_hull: int = ship.get("hull_points", 0)
	ship["hull_points"] = maxi(0, current_hull - final_amount)
	return final_amount

func repair_hull(amount: int) -> void:
	## Repair hull points (Core Rules p.59: 1 free/turn + paid)
	var c = _get_campaign()
	if not c:
		return
	var ship: Dictionary = c.ship_data
	var current: int = ship.get("hull_points", 0)
	var max_hull: int = ship.get("max_hull", current)
	ship["hull_points"] = mini(max_hull, current + amount)

func get_emergency_takeoff_damage() -> int:
	## Emergency takeoff: 3D6 hull damage (Core Rules p.60)
	## Emergency Drives trait: reduce by 3 (Core Rules p.30)
	var base_damage: int = (randi_range(1, 6)
		+ randi_range(1, 6) + randi_range(1, 6))
	var c = _get_campaign()
	if c:
		var traits: Array = c.ship_data.get("traits", [])
		for t in traits:
			var tl: String = str(t).to_lower()
			if "emergency" in tl and "drive" in tl:
				base_damage = maxi(0, base_damage - 3)
				break
	return base_damage

## Ship debt lived in TWO places that nothing reconciled:
##   campaign.ship_debt      - what the RULES code reads/writes (Black Zone loan
##                             payoff PaymentProcessor.gd:205-209, the Planetfall
##                             independence prepayment, ShiplessSystem's interest
##                             ladder and p.76 seizure roll)
##   ship_data["debt"]       - what CREATION and every DISPLAY use (ShipPanel:921,
##                             ShipManager:269/315, TradePhasePanel:780)
##
## The bridge meant to join them, CampaignFinalizationService.gd:347-351, called
## set_ship_debt(ship_data.get("debt", 0)) — and set_ship_debt did
## `c.ship_data["debt"] = amount`, i.e. it read the nested field and wrote the same
## nested field back. A self-copy. campaign.ship_debt was never touched.
##
## Measured across all 15 real 5PFH saves on disk: ship_debt = 0 in every one while
## ship.debt ranged 12-36. So the starting ship loan the player took at creation was
## invisible to the rules, and — live today — the Black Zone victory decremented a
## field that is always 0 while writing a journal milestone reading "Ship loan
## reduced by 5" (PaymentProcessor.gd:222-225). The player is told it happened and
## the displayed debt never moves.
##
## `campaign.ship_debt` is now the OWNER (it is what the rules code already uses).
## `ship_data["debt"]` is kept in sync as a DISPLAY MIRROR so the existing ship and
## trade screens keep working without rewiring them during release week — but it is
## written only through this setter, so there is exactly one writer.
func get_ship_debt() -> int:
	var c = _get_campaign()
	if c == null:
		return 0
	var owner_value: int = int(c.ship_debt) if "ship_debt" in c else 0
	if owner_value > 0:
		return owner_value
	# Self-heal: legacy saves, and the creation/ship screens that still write the
	# nested field directly, leave the owner at 0. Fall back rather than reporting
	# a debt-free ship.
	if "ship_data" in c and c.ship_data is Dictionary:
		return int(c.ship_data.get("debt", 0))
	return 0

func set_ship_debt(amount: int) -> void:
	var c = _get_campaign()
	if c == null:
		return
	if "ship_debt" in c:
		c.ship_debt = amount
	if "ship_data" in c and c.ship_data is Dictionary:
		c.ship_data["debt"] = amount

# --- World / Location delegation ---

func get_current_world() -> Dictionary:
	var c = _get_campaign()
	if c:
		return c.world_data
	return {}

func get_current_world_data() -> Dictionary:
	return get_current_world()

func get_location() -> String:
	var c = _get_campaign()
	if c:
		return c.world_data.get("current_location", "")
	return ""

func set_location(loc: String) -> void:
	var c = _get_campaign()
	if c:
		c.world_data["current_location"] = loc

# --- Patrons / Rivals delegation ---

func get_patrons() -> Array:
	var c = _get_campaign()
	if c:
		return c.patrons.duplicate()
	return []

func set_patrons(p: Array) -> void:
	var c = _get_campaign()
	if c:
		c.patrons = p.duplicate()

func get_rivals() -> Array:
	var c = _get_campaign()
	if c:
		return c.rivals.duplicate()
	return []

func set_rivals(r: Array) -> void:
	var c = _get_campaign()
	if c:
		c.rivals = r.duplicate()

# --- Unity Agent "Call in a Favor" outcomes (Core Rules p.20) ---
# On a 10-12 the player picks one: remove a Rival, gain a Quest Rumor, or gain a Patron.

## Remove one Rival. Returns true if a rival was removed.
func remove_random_rival() -> bool:
	var rivals: Array = get_rivals()
	if rivals.is_empty():
		return false
	rivals.remove_at(randi() % rivals.size())
	set_rivals(rivals)
	return true

## Gain a Quest Rumor. quest_rumors is an int count on the campaign.
func add_quest_rumor() -> void:
	var c = _get_campaign()
	if c and "quest_rumors" in c:
		set_quest_rumors(int(c.quest_rumors) + 1)

## Gain a Patron. Adds a display-safe campaign patron (every field PatronRivalManager
## reads via `.` access must be present). Reuses the game's patron generator when
## available, else falls back to a minimal book-typed patron.
func add_patron() -> Dictionary:
	var patron: Dictionary = {}
	var pm_script = load("res://src/core/managers/PatronManager.gd")
	if pm_script:
		var pm = pm_script.new(get_node_or_null("/root/GameState"))
		if pm and pm.has_method("generate_patron"):
			var g = pm.generate_patron()
			if g is Dictionary:
				patron = g.duplicate()
	# Guarantee the complete schema campaign consumers read.
	if not patron.has("id"):
		patron["id"] = "patron_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)
	if not patron.has("name"):
		patron["name"] = "New Contact"
	if not patron.has("type"):
		patron["type"] = "Corporation"
	patron["status"] = patron.get("status", "Active")
	patron["relationship"] = patron.get("relationship", 0)
	patron["jobs_offered"] = patron.get("jobs_offered", 0)
	var patrons: Array = get_patrons()
	patrons.append(patron)
	set_patrons(patrons)
	return patron

# --- Mission / Battle (temp_data based) ---

func set_current_mission(mission: Dictionary) -> void:
	## Store the active mission on the LIVE channel that get_current_mission reads —
	## campaign.progress_data["current_mission"] (FiveParsecsCampaignCore.get_current_mission).
	## Previously wrote temp_data (dead: nothing read it) so a mission persisted here for
	## the battle phase (e.g. WorldPhaseController JOB_OFFERS) never reached the battle.
	var c = _get_campaign()
	if c and "progress_data" in c:
		c.progress_data["current_mission"] = mission

# --- Victory conditions / Story track delegation ---

func get_victory_conditions() -> Dictionary:
	var c = _get_campaign()
	if c and c.has_method("get_victory_conditions"):
		return c.get_victory_conditions()
	return {}

func set_victory_conditions(conditions: Dictionary) -> void:
	var c = _get_campaign()
	if c and c.has_method("set_victory_conditions"):
		c.set_victory_conditions(conditions)

func is_story_track_enabled() -> bool:
	var c = _get_campaign()
	if c and c.has_method("get_story_track_enabled"):
		return c.get_story_track_enabled()
	return false

func set_story_track_enabled(enabled: bool) -> void:
	var c = _get_campaign()
	if c and c.has_method("set_story_track_enabled"):
		c.set_story_track_enabled(enabled)

func set_custom_victory_targets(targets: Dictionary) -> void:
	var c = _get_campaign()
	if c:
		c.victory_conditions["custom_targets"] = targets

func set_quest_rumors(count: int) -> void:
	var c = _get_campaign()
	if c:
		c.quest_rumors = count
