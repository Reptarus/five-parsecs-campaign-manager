@tool
extends Node
class_name PostBattlePhase

## Post-Battle Phase Orchestrator — Official Five Parsecs Rules
## Delegates to subsystems in post_battle/ for domain logic.
## Preserves all public API methods and signals unchanged.
##
## Phase 33 Sprint 8: Decomposed from 4,240-line god object into
## 10 subsystem files + this ~350-line orchestrator.

# Subsystem imports
const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const RivalPatronResolverClass = preload("res://src/core/campaign/phases/post_battle/RivalPatronResolver.gd")
const PaymentProcessorClass = preload("res://src/core/campaign/phases/post_battle/PaymentProcessor.gd")
const LootProcessorClass = preload("res://src/core/campaign/phases/post_battle/LootProcessor.gd")
const InjuryProcessorClass = preload("res://src/core/campaign/phases/post_battle/InjuryProcessor.gd")
const ExperienceTrainingClass = preload("res://src/core/campaign/phases/post_battle/ExperienceTrainingProcessor.gd")
const CampaignEventEffectsClass = preload("res://src/core/campaign/phases/post_battle/CampaignEventEffects.gd")
const CharacterEventEffectsClass = preload("res://src/core/campaign/phases/post_battle/CharacterEventEffects.gd")
const GalacticWarProcessorClass = preload("res://src/core/campaign/phases/post_battle/GalacticWarProcessor.gd")
const PostBattleCompletionClass = preload("res://src/core/campaign/phases/post_battle/PostBattleCompletion.gd")
const PsionicSystemRef = preload("res://src/core/systems/PsionicSystem.gd")

# Autoload references (resolved in _ready())
var dice_manager: Variant = null
var game_state_manager: Variant = null
var _game_state: Variant = null

## Post-Battle Phase Signals
signal post_battle_phase_started()
signal post_battle_phase_completed()
signal post_battle_substep_changed(substep: int)
signal rival_status_resolved(rivals_removed: Array)
signal patron_status_resolved(patrons_added: Array)
signal quest_progress_updated(progress: int)
signal payment_received(amount: int)
signal battlefield_finds_completed(finds: Array)
signal invasion_checked(invasion_pending: bool)
signal loot_gathered(loot: Array)
signal injuries_resolved(injuries: Array)
signal experience_awarded(xp_awards: Array)
signal training_completed(training: Array)
signal purchases_made(purchases: Array)
signal campaign_event_occurred(event: Dictionary)
signal character_event_occurred(event: Dictionary)
signal galactic_war_updated(progress: Dictionary)
signal precursor_event_choice_available(event1: Dictionary, event2: Dictionary)
signal precursor_event_chosen(chosen_event: Dictionary)
signal traveler_event_occurred(results: Array)
signal manipulator_bonus_earned(bonus: int)
signal bitter_day_sp_earned()  ## "A Bitter Day" (Core Rules p.67): +1 SP for holding field after character death

## Current post-battle state
var current_substep: int = 0
var battle_result: Dictionary = {}
var defeated_enemies: Array = []
var crew_participants: Array = []

## Battle outcome data
var mission_successful: bool = false
var enemies_defeated: int = 0
var loot_earned: Array = []
var injuries_sustained: Array = []

## Campaign reference — set by CampaignPhaseManager
var _campaign: Variant = null

# Subsystem instances (lazy-initialized)
var _ctx: PostBattleContextClass = null
var _rival_patron: RivalPatronResolverClass = null
var _payment: PaymentProcessorClass = null
var _loot: LootProcessorClass = null
var _injury: InjuryProcessorClass = null
var _experience: ExperienceTrainingClass = null
var _campaign_events: CampaignEventEffectsClass = null
var _character_events: CharacterEventEffectsClass = null
var _galactic_war: GalacticWarProcessorClass = null
var _completion: PostBattleCompletionClass = null

func set_campaign(campaign: Variant) -> void:
	_campaign = campaign

func _ready() -> void:
	dice_manager = DiceManager
	game_state_manager = get_node_or_null("/root/GameStateManager")
	_game_state = get_node_or_null("/root/GameState")
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.NONE

func _ensure_subsystems() -> void:
	if _ctx != null:
		return
	_ctx = PostBattleContextClass.new()
	_ctx.dice_manager = dice_manager
	_ctx.game_state_manager = game_state_manager
	_ctx.game_state = _game_state
	_ctx.planet_data_manager = get_node_or_null("/root/PlanetDataManager")
	_ctx.campaign_journal = get_node_or_null("/root/CampaignJournal")
	_ctx.equipment_manager = get_node_or_null("/root/EquipmentManager")
	_ctx.dlc_manager = get_node_or_null("/root/DLCManager")
	_ctx.galactic_war_manager = get_node_or_null("/root/GalacticWarManager")
	_rival_patron = RivalPatronResolverClass.new()
	_payment = PaymentProcessorClass.new()
	_loot = LootProcessorClass.new()
	_injury = InjuryProcessorClass.new()
	_experience = ExperienceTrainingClass.new()
	_campaign_events = CampaignEventEffectsClass.new()
	_character_events = CharacterEventEffectsClass.new()
	_galactic_war = GalacticWarProcessorClass.new()
	_completion = PostBattleCompletionClass.new()

func _sync_context() -> void:
	## Sync orchestrator state to context before each pipeline run.
	_ctx.campaign = _campaign
	_ctx.battle_result = battle_result
	_ctx.crew_participants = crew_participants
	_ctx.defeated_enemies = defeated_enemies
	_ctx.injuries_sustained = injuries_sustained
	_ctx.loot_earned = loot_earned
	_ctx.mission_successful = mission_successful
	_ctx.enemies_defeated = enemies_defeated

# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — Preserved identically for external callers
# ═══════════════════════════════════════════════════════════════════════════════

func start_post_battle_phase(battle_data: Dictionary = {}) -> void:
	## Begin the Post-Battle Phase sequence (14 steps).
	_ensure_subsystems()

	# Handle battle-skipped path
	if battle_data.get("battle_skipped", false):
		battle_result = {"battle_skipped": true}
		post_battle_phase_started.emit()
		_complete_post_battle_phase()
		return

	# Store battle result data
	battle_result = battle_data.duplicate(true)
	mission_successful = battle_data.get("success", false)
	enemies_defeated = battle_data.get("enemies_defeated", 0)
	defeated_enemies = battle_data.get("defeated_enemy_list", [])
	crew_participants = battle_data.get("crew_participants", [])
	injuries_sustained = battle_data.get("injuries_sustained", [])

	_sync_context()
	post_battle_phase_started.emit()

	# Step 1: Resolve Rival Status
	_emit_substep(GlobalEnums.PostBattleSubPhase.RIVAL_STATUS)
	var rival_result: Dictionary = _rival_patron.process_rival_status(_ctx)
	rival_status_resolved.emit(rival_result.get("rivals_removed", []))

	# Step 2: Resolve Patron Status
	_emit_substep(GlobalEnums.PostBattleSubPhase.PATRON_STATUS)
	var patrons_added: Array = _rival_patron.process_patron_status(_ctx)
	patron_status_resolved.emit(patrons_added)

	# Step 3: Determine Quest Progress
	_emit_substep(GlobalEnums.PostBattleSubPhase.QUEST_PROGRESS)
	var quest_progress: int = _rival_patron.process_quest_progress(_ctx)
	quest_progress_updated.emit(quest_progress)

	# Step 4: Get Paid
	_emit_substep(GlobalEnums.PostBattleSubPhase.GET_PAID)
	var total_payment: int = _payment.process_payment(_ctx)
	payment_received.emit(total_payment)

	# Step 4b: Black Zone Rewards (Core Rules Appendix III pp.150-151)
	_payment.process_black_zone_rewards(_ctx)

	# Step 5: Battlefield Finds
	_emit_substep(GlobalEnums.PostBattleSubPhase.BATTLEFIELD_FINDS)
	var finds: Array = _payment.process_battlefield_finds(_ctx)
	battlefield_finds_completed.emit(finds)

	# Step 6: Check for Invasion
	_emit_substep(GlobalEnums.PostBattleSubPhase.CHECK_INVASION)
	var invasion_pending: bool = _payment.process_invasion_check(_ctx)
	invasion_checked.emit(invasion_pending)

	# Step 7: Gather the Loot
	_emit_substep(GlobalEnums.PostBattleSubPhase.GATHER_LOOT)
	var gathered_loot: Array = _loot.process_loot_gathering(_ctx)
	loot_gathered.emit(gathered_loot)

	# Step 8: Determine Injuries
	_emit_substep(GlobalEnums.PostBattleSubPhase.INJURIES)
	var processed_injuries: Array = _injury.process_injuries(_ctx)
	injuries_resolved.emit(processed_injuries)

	# Step 9: Experience & Upgrades
	_emit_substep(GlobalEnums.PostBattleSubPhase.EXPERIENCE)
	var xp_awards: Array = _experience.process_experience(_ctx)
	experience_awarded.emit(xp_awards)

	# Step 10: Advanced Training
	_emit_substep(GlobalEnums.PostBattleSubPhase.TRAINING)
	var training_results: Array = _experience.process_training(_ctx)
	training_completed.emit(training_results)

	# Step 11: Purchase Items
	_emit_substep(GlobalEnums.PostBattleSubPhase.PURCHASES)
	var purchase_results: Array = _experience.process_purchases(_ctx)
	purchases_made.emit(purchase_results)

	# Step 12: Campaign Events
	_emit_substep(GlobalEnums.PostBattleSubPhase.CAMPAIGN_EVENT)
	var campaign_event: Dictionary = _campaign_events.process_campaign_event(_ctx)
	if campaign_event.get("precursor_choice", false):
		# Precursor crew: emit choice for UI, wait for select_precursor_event()
		if precursor_event_choice_available.get_connections().size() > 0:
			precursor_event_choice_available.emit(campaign_event.event1, campaign_event.event2)
			return  # UI will call select_precursor_event() to continue
		else:
			# Auto-pick: prefer non-"none" event
			var auto_event: Dictionary = campaign_event.event1
			if campaign_event.event1.get("type", "none") == "none" and campaign_event.event2.get("type", "none") != "none":
				auto_event = campaign_event.event2
			_campaign_events.waiting_for_precursor_choice = false
			_campaign_events.finalize_event(auto_event, _ctx)
			campaign_event_occurred.emit(auto_event)
	else:
		_campaign_events.finalize_event(campaign_event, _ctx)
		campaign_event_occurred.emit(campaign_event)

	# Step 13: Character Events
	_process_character_event_step()

func select_precursor_event(choice: int) -> void:
	## PUBLIC API: Select which precursor event to use (1 or 2).
	_ensure_subsystems()
	var chosen: Dictionary = _campaign_events.select_precursor_event(choice)
	precursor_event_chosen.emit(chosen)
	_campaign_events.finalize_event(chosen, _ctx)
	campaign_event_occurred.emit(chosen)
	# Continue pipeline
	_process_character_event_step()

func attempt_training_enrollment(crew_id: String, course: String, available_credits: int) -> Dictionary:
	## PUBLIC API: Enroll crew in training course.
	_ensure_subsystems()
	_sync_context()
	return _experience.attempt_training_enrollment(_ctx, crew_id, course, available_credits)

func get_completion_data() -> Dictionary:
	## PUBLIC API: Return phase completion summary.
	return {
		"mission_successful": mission_successful,
		"injuries_sustained": injuries_sustained.duplicate(),
		"loot_earned": loot_earned.duplicate(),
		"enemies_defeated": enemies_defeated,
		"crew_participants": crew_participants.duplicate(),
		"battle_result": battle_result.duplicate(true),
		"defeated_enemies": defeated_enemies.duplicate(),
	}

func apply_campaign_event_effect(event_title: String) -> String:
	## PUBLIC API: Apply campaign event effects (called by CampaignEventComponent).
	_ensure_subsystems()
	_sync_context()
	return _campaign_events.apply_effect(event_title, _ctx)

func apply_character_event_effect(event_title: String, character: Variant) -> String:
	## PUBLIC API: Apply character event effects (called by CharacterEventComponent).
	_ensure_subsystems()
	_sync_context()
	return _character_events.apply_effect(event_title, character, _ctx)

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL — Pipeline continuation and completion
# ═══════════════════════════════════════════════════════════════════════════════

func _process_character_event_step() -> void:
	## Steps 13-14: Character Event → Galactic War → Complete
	_emit_substep(GlobalEnums.PostBattleSubPhase.CHARACTER_EVENT)
	var character_event: Dictionary = _character_events.process_character_event(_ctx)
	if character_event.has("type") and character_event.type != "none":
		_character_events.finalize_event(character_event, _ctx)
	character_event_occurred.emit(character_event)

	# Step 13b: Faction Event (Compendium pp.115-117, after character events)
	var faction_sys = Engine.get_main_loop().root.get_node_or_null(
		"/root/FactionSystem"
	) if Engine.get_main_loop() else null
	if faction_sys and faction_sys.has_method("process_faction_event"):
		var faction_event: Dictionary = faction_sys.process_faction_event()
		if not faction_event.is_empty():
			# Log to journal
			var journal = get_node_or_null("/root/CampaignJournal")
			if journal and journal.has_method("create_entry"):
				journal.create_entry({
					"type": "story",
					"title": "Faction: " + faction_event.get("event", ""),
					"description": faction_event.get("effect", ""),
					"auto_generated": true,
					"turn_number": _ctx.battle_result.get("turn", 0),
				})

	# Step 13c: Faction Activities (Compendium p.115, during Check for Invasion)
	if faction_sys and faction_sys.has_method("process_faction_activities"):
		var job_faction_id: String = _ctx.battle_result.get(
			"faction_job_id", ""
		)
		faction_sys.process_faction_activities(job_faction_id)

	# Step 14: Galactic War
	_emit_substep(GlobalEnums.PostBattleSubPhase.GALACTIC_WAR)
	var war_progress: Dictionary = _galactic_war.process_galactic_war(_ctx)
	galactic_war_updated.emit(war_progress)

	# Step 14b: Psionic detection check (DLC-gated, Core Rules p.97)
	_check_psionic_detection()

	# Complete
	_complete_post_battle_phase()

func _complete_post_battle_phase() -> void:
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.NONE
	_ensure_subsystems()
	_sync_context()
	_completion.update_character_lifetime_statistics(_ctx)
	_completion.create_battle_journal_entry(_ctx)
	_completion.record_planet_mission(_ctx)

	# Strange Character post-battle checks (Core Rules pp.19-22)
	var traveler_results: Array = _completion.check_traveler_disappearance(_ctx)
	if not traveler_results.is_empty():
		_log_traveler_events(traveler_results)
		traveler_event_occurred.emit(traveler_results)

	var manip_bonus: int = _completion.check_manipulator_bonus(_ctx)
	if manip_bonus > 0:
		_log_manipulator_bonus(manip_bonus)
		manipulator_bonus_earned.emit(manip_bonus)

	# "A Bitter Day" (Core Rules p.67): +1 SP if held field AND character killed
	_check_bitter_day_story_point()

	post_battle_phase_completed.emit()

func _emit_substep(substep: int) -> void:
	if GlobalEnums:
		current_substep = substep
		post_battle_substep_changed.emit(current_substep)

func _check_psionic_detection() -> void:
	## Post-battle psionic detection when legality is OUTLAWED (Core Rules p.97)
	## DLC-gated behind ContentFlag.PSIONICS
	var dlc = get_node_or_null("/root/DLCManager")
	if not dlc or not dlc.is_feature_enabled(dlc.ContentFlag.PSIONICS):
		return
	if not _campaign or not "progress_data" in _campaign:
		return
	var pd: Dictionary = _campaign.progress_data
	var legality: int = pd.get("psionic_legality", -1)
	if legality != PsionicSystemRef.PsionicLegality.OUTLAWED:
		return
	# Check if any crew used psionics this battle
	var times_used: int = battle_result.get("psionic_uses", 0)
	if times_used <= 0:
		return
	var detection: Dictionary = PsionicSystemRef.check_outlawed_detection(
		times_used)
	pd["psionic_enforcement"] = detection
	# Log to journal
	if _ctx and _ctx.campaign_journal:
		var j = _ctx.campaign_journal
		if j.has_method("create_entry"):
			var msg: String = "Psionic detection roll: %d" % detection.get(
				"roll", 0)
			if detection.get("detected", false):
				var etype: Dictionary = detection.get("enforcement", {})
				msg += " — DETECTED! %s" % etype.get("type", "Enforcers")
			j.create_entry({"type": "battle", "text": msg})

func _log_traveler_events(results: Array) -> void:
	## Log Traveler post-battle events to journal and character history
	for result in results:
		var char_name: String = result.get("character", "Traveler")
		var roll: int = result.get("roll", 0)
		var char_id: String = _find_crew_id_by_name(char_name)

		if result.get("type") == "disappear":
			# Character history: disappearance event
			if _ctx.campaign_journal \
					and _ctx.campaign_journal.has_method(
						"auto_create_character_event"):
				_ctx.campaign_journal.auto_create_character_event(
					char_id, "traveler_disappearance", {
						"turn": _ctx.battle_result.get("turn", 0),
						"description": (
							"%s vanished mysteriously after the battle"
							+ " (rolled %d). Crew gained 2 story points."
							% [char_name, roll]),
					})
			# Milestone: dramatic crew departure
			if _ctx.campaign_journal \
					and _ctx.campaign_journal.has_method(
						"auto_create_milestone_entry"):
				_ctx.campaign_journal.auto_create_milestone_entry(
					"crew_departure", {
						"turn": _ctx.battle_result.get("turn", 0),
						"character": char_name,
						"reason": "Traveler vanished mysteriously",
						"stats": {"story_points_gained": 2},
					})
			# Remove Traveler from crew
			_remove_crew_member_by_id(char_id)

		elif result.get("type") == "quest":
			# General journal: quest discovery
			if _ctx.campaign_journal \
					and _ctx.campaign_journal.has_method("create_entry"):
				_ctx.campaign_journal.create_entry({
					"turn_number": _ctx.battle_result.get("turn", 0),
					"type": "event",
					"auto_generated": true,
					"title": "Traveler's Gift",
					"description": (
						"%s revealed a Quest lead (rolled %d)."
						% [char_name, roll]),
					"mood": "discovery",
					"tags": ["traveler", "quest", "strange_character"],
				})

func _log_manipulator_bonus(bonus: int) -> void:
	## Log Manipulator story point bonus to journal
	if _ctx.campaign_journal \
			and _ctx.campaign_journal.has_method("create_entry"):
		_ctx.campaign_journal.create_entry({
			"turn_number": _ctx.battle_result.get("turn", 0),
			"type": "event",
			"auto_generated": true,
			"title": "Manipulator Insight",
			"description": (
				"Manipulator crew member(s) contributed %d"
				+ " bonus story point(s)." % bonus),
			"mood": "discovery",
			"tags": [
				"manipulator", "story_points",
				"strange_character"],
		})

func _check_bitter_day_story_point() -> void:
	## "A Bitter Day" (Core Rules p.67): +1 SP if crew held the field
	## AND a character was killed in that battle.
	if not _ctx or not _ctx.campaign:
		return
	# Check Insanity mode — story points disabled entirely
	if _is_story_points_disabled():
		return
	var held: bool = battle_result.get("held_field", false)
	if not held:
		return
	var has_fatal: bool = false
	for casualty in battle_result.get("casualties", []):
		if casualty.get("type", "") in ["killed", "fatal"]:
			has_fatal = true
			break
	if not has_fatal:
		return
	# Award +1 story point
	_ctx.campaign.story_points += 1
	_log_bitter_day_sp()
	bitter_day_sp_earned.emit()


func _log_bitter_day_sp() -> void:
	## Log "A Bitter Day" story point to journal
	if _ctx.campaign_journal \
			and _ctx.campaign_journal.has_method("create_entry"):
		_ctx.campaign_journal.create_entry({
			"turn_number": _ctx.battle_result.get("turn", 0),
			"type": "event",
			"auto_generated": true,
			"title": "A Bitter Day",
			"description": (
				"The crew held the field despite losing a"
				+ " comrade. Gained 1 story point."),
			"mood": "bittersweet",
			"tags": ["story_points", "bitter_day", "held_field"],
		})


func _is_story_points_disabled() -> bool:
	## Check if story points are disabled (Insanity mode)
	if not _ctx or not _ctx.campaign:
		return false
	var campaign = _ctx.campaign
	if "config" in campaign:
		var config = campaign.config
		if config is Dictionary and "difficulty" in config:
			return config["difficulty"] == GlobalEnums.DifficultyLevel.INSANITY
		elif config is Object and "difficulty" in config:
			return config.difficulty == GlobalEnums.DifficultyLevel.INSANITY
	return false


func _find_crew_id_by_name(char_name: String) -> String:
	## Find character_id by display name in participating crew
	for member in _ctx.get_participating_crew():
		var name_val: String = ""
		if member is Dictionary:
			name_val = member.get("character_name", "")
		elif "character_name" in member:
			name_val = str(member.character_name)
		if name_val == char_name:
			if member is Dictionary:
				return member.get("character_id", "")
			elif "character_id" in member:
				return str(member.character_id)
	return ""

func _remove_crew_member_by_id(char_id: String) -> void:
	## Remove a crew member from the campaign (Traveler disappearance)
	if char_id.is_empty():
		return
	var campaign = _ctx.get_current_campaign() \
		if _ctx.has_method("get_current_campaign") else null
	if campaign == null and _ctx.game_state:
		campaign = _ctx.game_state.get_current_campaign() \
			if _ctx.game_state.has_method(
				"get_current_campaign") else null
	if campaign == null:
		return
	var members: Array = []
	if "crew_data" in campaign:
		members = campaign.crew_data.get("members", [])
	elif campaign is Dictionary:
		members = campaign.get(
			"crew_data", {}).get("members", [])
	for i in range(members.size()):
		var member = members[i]
		var mid: String = ""
		if member is Dictionary:
			mid = member.get(
				"character_id", member.get("id", ""))
		elif "character_id" in member:
			mid = str(member.character_id)
		if mid == char_id:
			members.remove_at(i)
			break
