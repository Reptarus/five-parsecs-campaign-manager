extends WorldPhaseComponent
class_name JobOfferComponent

## Job Offer Phase Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs job offers only
## Implements Core Rules p.78-80 - Patron jobs and opportunities

# Five Parsecs dependencies
const GameDataLoader = preload("res://src/utils/GameDataLoader.gd")
const CompendiumMissionsExpanded = preload("res://src/data/compendium_missions_expanded.gd")
const PatronJobEffectsClass = preload("res://src/core/patrons/PatronJobEffects.gd")
const PatronContactRef = preload("res://src/core/patrons/PatronContact.gd")
const ExpandedQuestRef = preload("res://src/core/campaign/ExpandedQuestProgression.gd")
## Fixer's Guidebook mission types. Each generator self-gates on its own DLC
## ContentFlag and returns {} when the pack is not owned, so calling them
## unconditionally is correct — see _generate_compendium_missions().
const StealthMissionGenerator = preload("res://src/core/mission/StealthMissionGenerator.gd")
const StreetFightGenerator = preload("res://src/core/mission/StreetFightGenerator.gd")
const SalvageJobGenerator = preload("res://src/core/mission/SalvageJobGenerator.gd")
## Core Rules p.72 step 3 — the Freelancer License that gates Patron work.
const NewWorldArrivalRef = preload("res://src/core/campaign/NewWorldArrival.gd")
const RivalContactRef = preload("res://src/core/campaign/RivalContact.gd")

# UI Components
@onready var job_offer_container: VBoxContainer = %JobOfferContainer
@onready var job_list: ItemList = %AvailableJobsList
@onready var job_details_label: Label = %JobDetailsLabel
@onready var accept_button: Button = %AcceptJobButton
@onready var reroll_button: Button = %RerollJobsButton

# Job offer state
var available_jobs: Array[Dictionary] = []
var selected_job_index: int = -1
var job_accepted: bool = false
var automation_enabled: bool = false

# Enemy generation — uses JSON D100 tables instead of hardcoded list
var _enemy_generator: EnemyGenerator = null

func _ready() -> void:
	name = "JobOfferComponent"
	_enemy_generator = EnemyGenerator.new()
	super._ready()
	# Portrait: stack the job-list + details panes vertically (r15).
	_register_responsive_box($JobOfferContainer/ContentContainer)

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	_subscribe(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

func _connect_ui_signals() -> void:
	## Connect UI button and list signals
	if job_list:
		job_list.item_selected.connect(_on_job_selected)
		# Sprint 26.4: Ensure 48px minimum touch target for mobile
		job_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	else:
		push_warning("JobOfferComponent: job_list (AvailableJobsList) not found")
	if accept_button:
		accept_button.pressed.connect(_on_accept_job_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_jobs_pressed)

func _setup_initial_state() -> void:
	## Initialize the component state
	job_accepted = false
	selected_job_index = -1
	available_jobs.clear()
	_add_required_indicator()

func _add_required_indicator() -> void:
	## Add 'Required' indicator to the component title for UX clarity
	var title_label = get_node_or_null("JobOfferContainer/HeaderPanel/HeaderContent/TitleRow/Title")
	if title_label and title_label is Label:
		# Add required badge if not already present
		if not title_label.text.contains("Required"):
			title_label.text = "Job Offers [color=#D97706](Required)[/color]"
			# If using RichTextLabel, enable BBCode
			if title_label is RichTextLabel:
				title_label.bbcode_enabled = true
			else:
				# For regular Label, use simpler indicator
				title_label.text = "Job Offers  •  REQUIRED"
	_update_ui_display()

## Public API: Initialize job offers from WorldPhaseController
func initialize_job_offers(world_phase_data: Dictionary) -> void:
	## Initialize job offers from world phase data - wrapper for controller compatibility
	var patrons = world_phase_data.get("patrons", [])
	var location = world_phase_data.get("location", "Unknown Location")

	# Check for introductory campaign — provide guided missions instead of random
	var intro_mission: Dictionary = _check_introductory_mission()
	if not intro_mission.is_empty():
		job_accepted = false
		selected_job_index = -1
		available_jobs = [intro_mission]
		_update_ui_display()
		if event_bus:
			event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
				"location": location,
				"job_count": 1,
				"introductory": true
			})
		return

	# Patron offers PERSIST on the campaign; the Quest option is derived fresh
	# from campaign state every turn and must never be written into that store,
	# or it would be duplicated on the next visit to this step.
	var patron_offers: Array[Dictionary] = []

	# Offers the crew is still sitting on from earlier turns, minus any whose
	# Time Frame has now run out (Core Rules p.83). Before this, offers lived
	# only on this component and were rebuilt from scratch every turn, so the
	# rolled Time Frame had nothing to count against: a player could decline
	# every job forever and the same Patron re-offered fresh work next turn at no
	# cost, and "This campaign turn" meant precisely nothing.
	var current_turn: int = _current_campaign_turn()
	# Errata v1.06: a job already accepted keeps its Time Frame running, so
	# commitments are expired FIRST — one that lapsed while the crew was busy
	# elsewhere is a failure now, not next turn.
	var live_commitments: Array = _expire_stale_commitments(current_turn)
	var sifted: Dictionary = _expire_stale_offers(_stored_offers(), current_turn)
	for expired in sifted.expired:
		_fail_expired_job(expired, current_turn)
	for held in sifted.live:
		if held is Dictionary:
			patron_offers.append(held)

	# Errata v1.06: an accepted-but-unfought job is still on the plate, so it is
	# offered back rather than vanishing until its Time Frame runs out. Tagged so
	# the details pane can say which it is.
	for commitment in live_commitments:
		if not (commitment is Dictionary):
			continue
		var carried_job: Dictionary = (commitment as Dictionary).duplicate(true)
		carried_job["is_outstanding_commitment"] = true
		patron_offers.append(carried_job)

	# A Patron with a job still on the table does not hand you a second one. The
	# book's "Busy" Condition — "If the mission is a success, the Patron offers a
	# new job next campaign turn" (p.84) — is only worth a table slot because a
	# Patron does NOT automatically produce work every turn.
	var patrons_with_live_offers: Array[String] = []
	for held in patron_offers:
		patrons_with_live_offers.append(str(held.get("patron_id", "")))

	# ── p.77 gates whether a Patron job exists at all ─────────────────────────
	# "To find a Patron, roll 1D6 and add the number of crew members who are
	# LOOKING... If the result is a 5 or higher, you've found a Patron to hire you
	# for a job." And p.83 opens: "IF YOU RECEIVED A JOB OFFER FROM A PATRON, you
	# need to determine the details of the job."
	#
	# THE BUG THIS FIXES: this loop handed EVERY Patron on the list a fresh job
	# every campaign turn, with no roll anywhere. So you never needed to send
	# anyone to Find a Patron — the task gated nothing — and once the contact list
	# reached 4-5 Patrons (they only lapse on travel, p.72) the board was a
	# permanent wall of work. The p.77 roll, its crew-count bonus, its +1 per
	# existing contact and its credit spend were all decoration.
	#
	# `patron_offers_owed` is written by CrewTaskComponent._grant_patron_job_offers
	# on a successful roll and is SPENT here. Offers already on the table from
	# earlier turns are untouched (they persist until their Time Frame expires).
	var owed: int = _consume_patron_offers_owed()
	var eligible_patrons: Array = []
	for patron in patrons:
		var p_data: Dictionary = patron if patron is Dictionary else {"patron_name": str(patron)}
		var pid: String = _patron_identity(p_data, str(p_data.get("patron_name", "")))
		if pid in patrons_with_live_offers:
			continue
		eligible_patrons.append(p_data)

	# "it will always be a RANDOM, existing Patron" — random, not first-in-list.
	eligible_patrons.shuffle()
	for i in range(mini(owed, eligible_patrons.size())):
		patron_offers.append_array(_generate_job_offers(eligible_patrons[i], location))

	# Core Rules p.84 Conditions 7-8, verbatim: "Busy — If the mission is a
	# success, the Patron offers a new job NEXT CAMPAIGN TURN."
	#
	# Banked by RivalPatronResolver as a NAMED patron id, not folded into `owed`:
	# the p.77 entitlement draws a random existing Patron, and Busy names the
	# specific employer who was pleased with the work. Arrives whether or not the
	# crew rolled Find a Patron this turn — the offer is the Patron's initiative,
	# not the crew's search.
	for followup: Dictionary in _consume_patron_followups(
			eligible_patrons, patrons_with_live_offers):
		patron_offers.append_array(_generate_job_offers(followup, location))

	# p.85 Select Your Job: "Carry out an Opportunity mission — ALWAYS AVAILABLE".
	# This is the one option the book guarantees every turn, and it is what makes
	# gating Patron work above safe rather than a soft-lock: a crew that finds no
	# Patron still has a battle to fight.
	if patron_offers.is_empty():
		var market_jobs: Array[Dictionary] = _generate_job_offers({}, location)
		patron_offers.append_array(market_jobs)

	_store_offers(patron_offers)

	var all_jobs: Array[Dictionary] = []

	# "Continue a Quest — If you have an active Quest" (Core Rules p.85, Select
	# Your Job). This option did not exist. Resolve Rumors would hand the player
	# a Quest and there was then no way to go on it: the p.89 Quest objective
	# column was unreachable because nothing ever produced a mission with
	# mission_source "quest", the p.120 finale flag had no producer, and the
	# whole Quest arc dead-ended at the moment it began.
	var quest_job: Dictionary = _build_quest_job(location)
	if not quest_job.is_empty():
		all_jobs.append(quest_job)
	all_jobs.append_array(patron_offers)
	all_jobs.append_array(_generate_compendium_missions(location))

	# Store and display
	job_accepted = false
	selected_job_index = -1
	available_jobs = all_jobs
	_update_ui_display()

	# Publish event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
			"location": location,
			"job_count": available_jobs.size()
		})

	# Auto-process if enabled
	if automation_enabled and available_jobs.size() > 0:
		selected_job_index = 0
		accept_selected_job()

func _generate_compendium_missions(location: String = "") -> Array[Dictionary]:
	## Fixer's Guidebook mission types — Stealth Missions, Street Fights and
	## Salvage Jobs — offered alongside the Patron and Opportunity jobs.
	##
	## THE BUG THIS FIXES. Every layer of these three features already existed and
	## already agreed with every other layer: the data files, the loaders in
	## src/data/compendium_*.gd, these three generators, StealthResolver and
	## SalvageResolver behind BattleResolverRouter, and the three battle panels
	## that TacticalBattleUI instantiates and signal-wires. The generators stamp
	## `type` as "stealth" / "street_fight" / "salvage" and TacticalBattleUI
	## branches on exactly those strings.
	##
	## The chain was severed at ONE point: the only caller of all three
	## generators was src/core/campaign/phases/WorldPhase.gd, a file with zero
	## instantiations (WorldPhaseController preloads it and never uses it). So
	## nothing ever produced a mission of those types, the dispatch never matched,
	## the panels never opened, and three purchasable features were unreachable in
	## every campaign.
	##
	## That is the THIRD rule this same dead file has held hostage — CLAUDE.md
	## already records it holding the only callers of record_invaded_planet(),
	## repair_hull() and the fuel-credits consumer. When a file is described as
	## dead, check what its callers were before shelving it.
	##
	## Derived FRESH each turn and never written into the persisted patron store:
	## these are not Patron jobs, they carry no p.83 Time Frame, and persisting
	## them would duplicate the option every time the player revisits this step.
	## Same treatment as the Quest option above.
	var missions: Array[Dictionary] = []

	# Crew SIZE SETTING (4/5/6), not the fluctuating roster count — Compendium
	# p.124 stealth sentries and p.141 salvage tension both key off the setting.
	var campaign_crew_size: int = 6
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("get_campaign_crew_size"):
		campaign_crew_size = gsm.get_campaign_crew_size()

	# Each generator returns {} when its own ContentFlag is off, so ownership is
	# enforced inside the generator and needs no check here.
	var stealth: Dictionary = StealthMissionGenerator.generate_stealth_mission(
		campaign_crew_size)
	if not stealth.is_empty():
		stealth["type"] = "stealth"
		stealth["name"] = stealth.get("objective", {}).get("name", "Stealth Mission")
		stealth["mission_source"] = "opportunity"
		missions.append(stealth)

	var street: Dictionary = StreetFightGenerator.generate_street_fight()
	if not street.is_empty():
		street["type"] = "street_fight"
		street["name"] = street.get("objective", {}).get("name", "Street Fight")
		street["mission_source"] = "opportunity"
		missions.append(street)

	var salvage: Dictionary = SalvageJobGenerator.generate_salvage_job(
		campaign_crew_size)
	if not salvage.is_empty():
		salvage["type"] = "salvage"
		salvage["name"] = "Salvage Job"
		salvage["mission_source"] = "opportunity"
		missions.append(salvage)

	# Compendium p.111 Faction Jobs: "Before taking your crew tasks, each turn
	# your captain may check for a Faction job... Select a Faction you would like
	# to work for and roll 1D6. If the roll is equal to or below the Influence
	# score of the Faction, they have a job available."
	#
	# THE FOURTH RULE THE SAME DEAD FILE HELD HOSTAGE. The only caller of
	# get_faction_mission_opportunities() was WorldPhase.gd:939 — the zero-
	# instantiation file this docblock already names for the other three. The
	# check, the D6, the mission generator and the Loyalty payoff in
	# RivalPatronResolver were all correct and all unreachable.
	#
	# The DLC gate and the "does the crew have any factions" question are both
	# answered inside FactionSystem, so neither is repeated here.
	var faction_sys: Node = get_node_or_null("/root/FactionSystem")
	if faction_sys and faction_sys.has_method("get_faction_mission_opportunities"):
		for faction_job in faction_sys.get_faction_mission_opportunities():
			missions.append(_faction_job_offer(faction_job, location))

	return missions


## Public API: Initialize job offer phase with campaign data
func initialize_job_phase(patron_data: Dictionary, current_location: String) -> void:
	## Generate job offers for current location

	# Reset state for new job offers
	job_accepted = false
	selected_job_index = -1
	available_jobs = _generate_job_offers(patron_data, current_location)

	_update_ui_display()

	# Publish job offers generated event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
			"location": current_location,
			"job_count": available_jobs.size()
		})

	# AUTO-PROCESS: If automation enabled and jobs available, auto-accept first job
	if automation_enabled and available_jobs.size() > 0:
		selected_job_index = 0
		accept_selected_job()

## Core Five Parsecs job generation (Core Rules p.78-80)
## Compendium p.111: "Faction jobs are treated as a Patron job, but do not roll for
## Danger Pay or Benefits." So the Patron builder rolls the objective, Time Frame,
## Hazards and Conditions with the Faction as the employer, and FactionSystem says
## only who is asking. The extra opponent p.111 adds is applied by EnemyGenerator
## off mission_source "faction".
##
## No patron_id: p.119 Step 2 adds the employer of a won job as a Patron, and a
## Faction is not one. A won Faction job raises Loyalty instead (p.112), which the
## post-battle resolver reads off faction_id.
func _faction_job_offer(faction_job: Dictionary, location: String) -> Dictionary:
	var faction_name: String = str(faction_job.get("faction_name", "")).strip_edges()
	if faction_name.is_empty():
		faction_name = "Faction"
	var table: Dictionary = GameDataLoader.get_patron_jobs_table().get("job_type_table", {})
	var job: Dictionary = _create_job_offer_from_table(
		{"patron_name": faction_name, "patron_type": "Faction"}, location, 0, table)
	job.erase("patron_id")
	job["faction_id"] = str(faction_job.get("faction_id", ""))
	job["type"] = "faction_job"
	job["name"] = "Faction job: %s" % faction_name
	# p.115 Tensions rising, "Faction jobs next turn increase Danger Pay by +1": the
	# only Danger Pay a Faction job ever carries.
	if bool(faction_job.get("tensions_rising_bonus", false)):
		job["danger_pay"] = int(job.get("danger_pay", 0)) + 1
		job["pay"] = int(job.get("pay", 0)) + 1
		job["tensions_rising_bonus"] = true
	return job


func _generate_job_offers(patron_data: Dictionary, location: String) -> Array[Dictionary]:
	## Generate job offers based on Five Parsecs rules and JSON data tables
	var jobs: Array[Dictionary] = []

	# Load patron jobs table
	var patron_table = GameDataLoader.get_patron_jobs_table()
	
	if patron_table.is_empty():
		push_error("JobOfferComponent: Failed to load patron_jobs.json - falling back to basic generation")
		return _generate_job_offers_fallback(patron_data, location)
	
	# WHO is offering, resolved once here because every offer enters through this
	# function: an owed p.77 offer, a p.84 Busy follow-up and the p.85 Opportunity
	# mission. See _offer_patron().
	var effective_patron: Dictionary = _offer_patron(patron_data)

	# ONE job per offer. p.77 grants a job per Patron found ("you've found a Patron
	# to hire you for a job"; two on a 6+, each from its own Patron), and p.85's
	# Opportunity mission is one mission. Until 2026-10-29 a Patron handed out 1-3
	# jobs by an invented tier, and the Opportunity mission first rolled a 2D6
	# "contact table" in neither book that, on a 5+, turned it into a Patron job
	# from an employer the app made up.
	var job_type_table = patron_table.get("job_type_table", {})
	var job = _create_job_offer_from_table(effective_patron, location, 0, job_type_table)
	_enhance_job_with_compendium(job)
	jobs.append(job)
	return jobs

## Fallback job generation if JSON loading fails
func _generate_job_offers_fallback(patron_data: Dictionary, location: String) -> Array[Dictionary]:
	## Fallback to original job generation if JSON fails
	var jobs: Array[Dictionary] = []
	var job = _create_job_offer(_offer_patron(patron_data), location, 0)
	_enhance_job_with_compendium(job)
	jobs.append(job)
	return jobs

## The Patron behind an offer, resolved ONCE so both job builders agree.
##
## No Patron (the p.85 Opportunity mission) is the Open Market and stays that:
## its builders used to roll it a Patron type and a generated name, so it carried
## p.83 Benefits, Hazards and Conditions and a p.112 affiliation roll for an
## employer that does not exist.
##
## A real contact keeps who it is. Stored contacts carry `name`/`type` while the
## builders read `patron_name`/`patron_type`, so a job from the crew's OWN Patron
## re-rolled its type and showed a generated stranger's name. A contact with no
## type (creation tables store a bare name) rolls one on the p.83 Patron Table, as
## the book does when a job arrives ("As well as who the Patron is..."); before,
## its empty type read as an Opportunity mission.
func _offer_patron(patron_data: Dictionary) -> Dictionary:
	if patron_data.is_empty():
		return {"patron_name": "Open Market", "patron_type": "generic"}
	var p: Dictionary = patron_data.duplicate()
	var ptype: String = str(p.get("patron_type", p.get("type", ""))).strip_edges()
	if ptype.is_empty() or ptype == "generic":
		ptype = PatronContactRef.roll_type()
	p["patron_type"] = ptype
	var pname: String = str(p.get("patron_name", p.get("name", ""))).strip_edges()
	p["patron_name"] = pname if not pname.is_empty() else ptype
	return p

## Danger Pay and the Benefits/Hazards/Conditions subtables are PATRON tables: p.83
## opens "If you received a job offer from a Patron" and p.120 pays Danger Pay only
## "If you did a Patron job". Faction jobs are "treated as a Patron job" (Compendium
## p.111).
func _is_patron_source(mission_source: String) -> bool:
	return mission_source == "patron" or mission_source == "faction"

func _patron_bhc(dice_manager, patron_type: String, mission_source: String) -> Dictionary:
	if not _is_patron_source(mission_source):
		return {"benefits": [], "hazards": [], "conditions": []}
	# Compendium p.111: a Faction job does not roll for Benefits.
	if mission_source == "faction":
		return _roll_bhc(dice_manager, patron_type, ["hazards", "conditions"])
	return _roll_bhc(dice_manager, patron_type)

## Create job offer using JSON data tables
func _create_job_offer_from_table(patron_data: Dictionary, location: String, job_index: int,
		job_type_table: Dictionary) -> Dictionary:
	## Create job using patron_jobs.json table data (Core Rules pp.83-84)
	if job_type_table.is_empty():
		return _create_job_offer(patron_data, location, job_index)

	var dice_manager = get_node_or_null("/root/DiceManager")

	# The Patron is already resolved by _offer_patron(): a book type (p.83) and a
	# name, or the Open Market.
	var patron_type: String = str(patron_data.get("patron_type", ""))
	var patron_name: String = str(patron_data.get("patron_name", ""))
	var danger_pay_bonus: int = 0
	var time_frame_bonus: int = 0

	# Apply patron type bonuses (Core Rules p.83)
	if patron_type == "Corporation":
		danger_pay_bonus = 1
	elif patron_type == "Secretive Group":
		time_frame_bonus = 1

	# Roll on job type table (d10)
	var job_roll: int = GameDataLoader.roll_d10("Patron Job Type (Core Rules pp.83-84)")
	var job_result: Dictionary = GameDataLoader.roll_on_table(
		job_type_table, job_roll
	)

	if job_result.is_empty():
		push_warning(
			"JobOfferComponent: No job type for roll %d, fallback"
			% job_roll
		)
		return _create_job_offer(patron_data, location, job_index)

	# Extract job type data
	var job_type: String = str(job_result.get(
		"job_type", job_result.get("objective", "DELIVERY")
	))
	var job_description: String = str(job_result.get(
		"description", job_result.get("objective", "Unknown job")
	))
	var requirements: Array = job_result.get("typical_requirements", [])

	# Derive mission source for Compendium battle type selection (p.118)
	var mission_source: String = _derive_mission_source(patron_data)

	# Roll danger pay with patron bonus (Core Rules p.83). Compendium p.111: a
	# Faction job "does not roll for Danger Pay".
	var danger_pay_result: Dictionary = {"credits": 0, "double_roll_bonus": false} \
		if mission_source == "faction" else _roll_danger_pay(dice_manager, danger_pay_bonus)
	var danger_pay_credits: int = danger_pay_result.credits
	# What the offer adds on top of the p.120 base. The base itself is 1D6, rolled
	# at Get Paid after the battle, so an offer cannot quote it as a number. This
	# used to add an invented base of 4, a tier multiplier and a "danger level"
	# bonus, none of them in either book.
	var final_pay: int = danger_pay_credits

	# Roll time frame with patron bonus (Core Rules p.83)
	var time_frame_result: Dictionary = _roll_time_frame(
		dice_manager, time_frame_bonus
	)
	var time_frame: String = time_frame_result.label
	var offered_turn: int = _current_campaign_turn()

	# Danger Pay is a PATRON payment. The p.83 table sits under "3. Determine Job
	# Offers — If you received a job offer from a Patron", and p.120 Step 4 pays
	# it only "If you did a Patron job". These tables are rolled for the Open
	# Market offers too, so an Opportunity mission advertised — and Get Paid
	# handed over — 1 to 3 credits it was never entitled to. Zeroed HERE as well
	# as at the payment gate so the offer summary tells the truth rather than
	# promising money the post-battle step then withholds.
	if mission_source != "patron" and mission_source != "faction":
		final_pay -= danger_pay_credits
		danger_pay_credits = 0
		danger_pay_result.double_roll_bonus = false

	# Benefits/Hazards/Conditions (Core Rules p.83) — same roller the fallback
	# builder uses, so both paths produce a complete job offer. An Opportunity
	# mission rolls none (see _is_patron_source); it rolled all three until 2026-10-29.
	var bhc: Dictionary = _patron_bhc(dice_manager, patron_type, mission_source)
	if mission_source == "patron":
		_apply_remembered_benefit(bhc, _patron_identity(patron_data, patron_name))

	var job: Dictionary = {
		"id": "job_%d_%s" % [job_index, Time.get_ticks_msec()],
		"location": location,
		"patron_type": patron_type,
		"patron_name": patron_name,
		# WHICH Patron offered this. Core Rules p.119 Step 2 resolves the accepted
		# job against a specific Patron — added on success, and (errata v1.06)
		# removed on failure. The job carried only a display NAME, so the whole of
		# post-battle Step 2 was gated on a key that never arrived and did nothing
		# in either direction. Falls back to the name because campaign.patrons is a
		# MIXED array of Strings and Dictionaries.
		"patron_id": _patron_identity(patron_data, patron_name),
		"job_type": job_type,
		"objective": job_type.capitalize(),
		"objective_description": job_description,
		# danger_pay is the PURE Core Rules p.78 Danger Pay component that Get Paid
		# adds on top of the 1D6 base for a Patron job (Core Rules p.120). It is NOT
		# the total — "pay" carries the composite estimate for the offer summary.
		# (Previously both fields held final_pay, so the offer mislabeled the
		# inflated total as "Danger Pay" and Get Paid added 0.)
		"danger_pay": danger_pay_credits,
		"pay": final_pay,
		"time_frame": time_frame,
		# The deadline as a NUMBER, so it can actually run out. Core Rules p.83:
		# "the number of campaign turns within which you must finish the job. If
		# the job isn't done when the time runs out, it counts as a failure";
		# p.85 repeats it for the Rival ambush case. Offers now persist between
		# turns (progress_data["patron_job_offers"]) and are expired against
		# this. -1 = the 10+ "Any time" result, which never expires.
		"offered_on_turn": offered_turn,
		"time_frame_turns": time_frame_result.turns,
		"deadline_turn": PatronJobEffectsClass.deadline_turn(
			offered_turn, time_frame_result.turns),
		"requirements": requirements,
		# Benefits / Hazards / Conditions — Core Rules p.83, "Roll 1D10 for each
		# category". This is the PRIMARY (table-driven) job builder and it
		# hardcoded all three empty, so a Patron job generated through the normal
		# path could never carry a Benefit, a Hazard or a Condition; only the
		# fallback builder rolled them. _roll_bhc()'s per-patron thresholds are
		# verified against the p.83 BHC table (Corporation Conditions 5+, Wealthy
		# Individual Benefits 5+, Secretive Group Hazards 5+, all others 8+).
		"benefits": bhc.benefits,
		"hazards": bhc.hazards,
		"conditions": bhc.conditions,
		"enemy_type": _determine_enemy_type(mission_source),
		"double_roll_bonus": danger_pay_result.double_roll_bonus,
		"patron": patron_name,
		"source": mission_source,
		"mission_source": mission_source,
	}

	return job

## "Negotiable — If you accept this job, you may reroll the Danger Pay roll and
## pick the better of the two rolls" (Core Rules p.84). Mutates the job in place
## so the accepted mission carries the improved figure through to Get Paid.
func _apply_negotiable_reroll(job: Dictionary) -> void:
	var dice_manager = get_node_or_null("/root/DiceManager")
	var bonus: int = 1 if str(job.get("patron_type", "")) == "Corporation" else 0
	var reroll: Dictionary = _roll_danger_pay(dice_manager, bonus)

	var old_credits: int = int(job.get("danger_pay", 0))
	var new_credits: int = int(reroll.credits)
	# "the better of the two" — the 10+ result's extra mission-pay die is part of
	# what makes a roll better, so a tie on credits still upgrades if the reroll
	# carries the double-roll bonus and the original did not.
	var upgrades: bool = new_credits > old_credits \
		or (new_credits == old_credits and bool(reroll.double_roll_bonus) \
			and not bool(job.get("double_roll_bonus", false)))
	if not upgrades:
		return

	var gained: int = new_credits - old_credits
	job["danger_pay"] = new_credits
	job["pay"] = int(job.get("pay", 0)) + gained
	job["double_roll_bonus"] = bool(reroll.double_roll_bonus) \
		or bool(job.get("double_roll_bonus", false))

	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			# "campaign_event", not "campaign" — STRING_TO_TYPE has no "campaign",
			# so validate_entry() push_warning()s on every one of these and the
			# entry falls out of any type-filtered view.
			"type": "campaign_event",
			"title": "Negotiated a better rate",
			"description": "Danger Pay rerolled: %d credits instead of %d (Core Rules p.84)."
				% [new_credits, old_credits],
			"location": str(job.get("location", "")),
		})


func _campaign() -> Variant:
	## The live campaign, or null. FiveParsecsCampaignCore is a Resource, so all
	## turn state lives under `progress_data` rather than as bracket keys.
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		return null
	var campaign = gs.campaign if "campaign" in gs else null
	if campaign and "progress_data" in campaign:
		return campaign
	return null


func _current_campaign_turn() -> int:
	## The turn BEING PLAYED. `turns_played` counts COMPLETED turns, so the turn
	## in progress is +1 — the same convention the dashboard, the journal and the
	## Introductory Campaign check use. Getting this off by one would make every
	## "This campaign turn" job expire before the player could take it.
	var campaign = _campaign()
	if not campaign:
		return 1
	return int(campaign.progress_data.get("turns_played", 0)) + 1


## Job offers the crew is still sitting on, oldest first (Core Rules p.83). They
## live on the campaign, not on this component, because the whole point of the
## Time Frame is that an offer outlives the turn it was made on.
func _stored_offers() -> Array:
	var campaign = _campaign()
	if not campaign:
		return []
	var stored: Variant = campaign.progress_data.get("patron_job_offers", [])
	return stored if stored is Array else []


func _store_offers(offers: Array) -> void:
	var campaign = _campaign()
	if not campaign:
		return
	campaign.progress_data["patron_job_offers"] = offers


## How many Patron job offers the crew earned this turn on the p.77 roll, zeroing
## the counter as it reads.
##
## SPENT, not merely read: this step is re-entered on back-navigation through the
## World Phase wizard, and a counter that survived would mint a fresh job every
## time the player stepped back and forward again — which is the same
## unlimited-work bug this gate exists to close, just triggered differently.
func _consume_patron_offers_owed() -> int:
	var campaign = _campaign()
	if not campaign or not ("progress_data" in campaign):
		return 0
	var owed: int = int(campaign.progress_data.get("patron_offers_owed", 0))
	if owed > 0:
		campaign.progress_data["patron_offers_owed"] = 0
	return maxi(0, owed)


## The p.84 "Busy" follow-up offers owed this turn, resolved to real Patron
## records. Consumed on read — the Patron offers a new job NEXT campaign turn,
## once, not every turn forever.
##
## A patron who already has a live offer is skipped rather than dropped: the
## follow-up they owe would be indistinguishable from the offer already sitting
## on the table, so it is carried to the turn they are free.
func _consume_patron_followups(
	eligible: Array, patrons_with_live_offers: Array
) -> Array:
	var out: Array = []
	var campaign = _campaign()
	if not campaign or not ("progress_data" in campaign):
		return out
	if not (campaign.progress_data is Dictionary):
		return out
	var raw: Variant = campaign.progress_data.get("patron_followup_offers", [])
	if not (raw is Array) or (raw as Array).is_empty():
		return out

	var carried: Array = []
	for pid: Variant in raw:
		var wanted: String = str(pid)
		if wanted in patrons_with_live_offers:
			carried.append(wanted)
			continue
		# A Patron who has since been left behind (p.72) cannot offer anything, so
		# an unmatched id is simply DROPPED — carrying it would leave a dead id in
		# the list for the rest of the campaign.
		for p: Variant in eligible:
			var p_data: Dictionary = p
			if _patron_identity(p_data, str(p_data.get("patron_name", ""))) == wanted:
				out.append(p_data)
				break
	campaign.progress_data["patron_followup_offers"] = carried
	return out


## Drop every held offer whose Time Frame has run out and report them, so the
## caller can apply the consequences of the failure the book declares.
##
## Core Rules p.83: "If the job isn't done when the time runs out, it counts as
## a failure." p.85 says the same for the case where Rivals hijack your turn:
## "Quests and Rumors remain, but a Patron job will fail if the time to complete
## it has expired."
func _expire_stale_offers(offers: Array, current_turn: int) -> Dictionary:
	var live: Array = []
	var expired: Array = []
	for offer in offers:
		if offer is Dictionary and PatronJobEffectsClass.is_expired(offer, current_turn):
			expired.append(offer)
		else:
			live.append(offer)
	return {"live": live, "expired": expired}


## "If you have worked for this Patron before, the Benefit (if any) always
## remains the same" (Core Rules p.83, immediately under the BHC table).
##
## A loyal Patron the crew had worked for five times rolled a fresh Benefit — or
## none — on every single job, so building a relationship with one employer paid
## nothing and the sentence above described no behaviour in the app. Hazards and
## Conditions are deliberately left to re-roll: the book fixes only the Benefit.
##
## The remembered value is keyed by Patron identity and lives in progress_data,
## so it survives a save and a reload like the rest of the offer state.
func _apply_remembered_benefit(bhc: Dictionary, patron_id: String) -> void:
	if patron_id.is_empty():
		return
	var campaign = _campaign()
	if not campaign:
		return
	var memory: Dictionary = campaign.progress_data.get("patron_benefit_memory", {})

	if memory.has(patron_id):
		# Worked for them before: whatever they offered then, they offer now —
		# including "nothing", which is why an empty Array is stored rather than
		# the key simply being absent.
		var remembered: Variant = memory[patron_id]
		bhc["benefits"] = (remembered as Array).duplicate(true) if remembered is Array else []
		return

	memory[patron_id] = (bhc.get("benefits", []) as Array).duplicate(true)
	campaign.progress_data["patron_benefit_memory"] = memory


## The three Conditions that are REQUIREMENTS rather than effects (Core Rules
## p.84). Returns {} when the job can be taken, else {reason} for the UI.
##
## All three were rolled and printed and gated nothing: a "Small Squad" job still
## let you deploy six, a "Full Squad" job could be taken by two survivors, and
## "Reputation Required" could never even be satisfied because nothing recorded a
## completed Patron job per world.
func _acceptance_block_reason(job: Dictionary) -> Dictionary:
	# Core Rules p.72 New World Arrival step 3, verbatim: "On a 5-6 the world
	# requires a Freelancer License TO PERFORM PATRON JOBS."
	#
	# Scoped to Patron work exactly as the book scopes it — an Opportunity mission
	# needs no licence, so the p.85 fallback battle is always reachable and this
	# can never soft-lock the turn.
	if _is_patron_job(job) and _licence_required_here():
		return {"reason": "Freelancer License required: this world licenses Patron "
			+ "work (%d cr, Core Rules p.72). Buy or forge one below."
				% _licence_fee_here(),
			"licence": true}

	var required: int = PatronJobEffectsClass.required_available_crew(job)
	if required > 0:
		var available: int = _available_crew_count()
		# available < 0 means the ROSTER COULD NOT BE READ, which is not the same
		# as a short crew. Blocking on it fails CLOSED: any context where the
		# lookup misses (no GameStateManager, a campaign shape it does not
		# understand, a detached component) would make every Full Squad job
		# permanently unacceptable and silently remove a fifth of the p.84
		# Conditions table from play. The gate exists to enforce the crew's
		# state, not our ability to query it.
		if available >= 0 and available < required:
			return {"reason": "Full Squad: needs %d available crew, you have %d."
				% [required, available]}

	if PatronJobEffectsClass.forbids_law_enforcement_rivals(job):
		var campaign = _campaign()
		var rivals: Array = campaign.rivals if campaign and "rivals" in campaign else []
		if PatronJobEffectsClass.has_law_enforcement_rival(rivals):
			return {"reason": "Clean: you have law enforcement Rivals."}

	if PatronJobEffectsClass.requires_prior_patron_job_here(job):
		# Same unknown-is-not-zero rule as Full Squad above. On a real campaign a
		# genuine 0 SHOULD block — that is the whole Condition — but a campaign we
		# cannot read is not a campaign with no history.
		var completed_here: int = _patron_jobs_completed_here()
		if completed_here == 0:
			return {"reason": "Reputation Required: no prior Patron job completed on this world."}

	return {}


## ── Freelancer License (Core Rules p.72, New World Arrival step 3) ─────────
##
## The requirement is rolled on arrival by NewWorldArrival.roll_licensing_requirement();
## this is the consumer that makes it mean something. Without it the roll would be
## a key nothing reads.

## The two routes p.72 gives out of a licensing requirement, offered next to the
## Accept button because that is where the block is felt.
var _licence_buy_button: Button = null
var _licence_forge_button: Button = null


func _refresh_licence_controls() -> void:
	var bar: Node = accept_button.get_parent() if accept_button else null
	if bar == null:
		return
	var needed: bool = _licence_required_here() and not job_accepted

	if not needed:
		for btn in [_licence_buy_button, _licence_forge_button]:
			if btn != null and is_instance_valid(btn):
				btn.get_parent().remove_child(btn)
				btn.queue_free()
		_licence_buy_button = null
		_licence_forge_button = null
		return

	var fee: int = _licence_fee_here()
	var credits: int = int(GameStateManager.get_credits())

	if _licence_buy_button == null or not is_instance_valid(_licence_buy_button):
		_licence_buy_button = Button.new()
		_licence_buy_button.name = "BuyFreelancerLicenceButton"
		_licence_buy_button.custom_minimum_size.y = TOUCH_TARGET_MIN
		_licence_buy_button.tooltip_text = (
			"Core Rules p.72: this world requires a Freelancer License to perform "
			+ "Patron jobs. Once purchased it remains in effect for perpetuity.")
		_licence_buy_button.pressed.connect(_on_buy_licence)
		bar.add_child(_licence_buy_button)
	_licence_buy_button.text = "Buy Freelancer License (%d cr)" % fee
	_licence_buy_button.disabled = credits < fee

	var forged_used: bool = NewWorldArrivalRef.forgery_attempted(
		_campaign(), _current_planet_id())
	if forged_used:
		if _licence_forge_button != null and is_instance_valid(_licence_forge_button):
			_licence_forge_button.get_parent().remove_child(_licence_forge_button)
			_licence_forge_button.queue_free()
			_licence_forge_button = null
		return
	if _licence_forge_button == null or not is_instance_valid(_licence_forge_button):
		_licence_forge_button = Button.new()
		_licence_forge_button.name = "ForgeFreelancerLicenceButton"
		_licence_forge_button.custom_minimum_size.y = TOUCH_TARGET_MIN
		_licence_forge_button.tooltip_text = (
			"Core Rules p.72: roll 1D6+Savvy. On 6+ the forgery passes and the "
			+ "License is free. On a NATURAL 1 you gain a Rival on this world. "
			+ "Only one attempt is permitted.")
		_licence_forge_button.pressed.connect(_on_forge_licence)
		bar.add_child(_licence_forge_button)
	_licence_forge_button.text = "Forge a License (1D6+Savvy, 6+)"


func _on_buy_licence() -> void:
	var fee: int = _licence_fee_here()
	if int(GameStateManager.get_credits()) < fee:
		return
	GameStateManager.remove_credits(fee)
	NewWorldArrivalRef.grant_licence(_campaign(), _current_planet_id())
	if job_details_label:
		job_details_label.text = ("Freelancer License purchased for %d credits. "
			% fee + "It remains in effect on this world for perpetuity (p.72).")
	_update_ui_display()


func _on_forge_licence() -> void:
	# "Select a crew member and roll 1D6+Savvy" — the book lets the player pick, and
	# picking is trivially always the highest Savvy on the roster, so the best
	# candidate is chosen rather than asked for. Recorded in the message so the
	# player can see whose Savvy was used.
	var best_savvy: int = 0
	var best_name: String = "a crew member"
	var campaign: Variant = _campaign()
	var crew: Array = []
	if campaign != null and campaign.has_method("get_crew_members"):
		crew = campaign.get_crew_members()
	for member: Variant in crew:
		var sv: int = 0
		var nm: String = "Crew"
		if member is Dictionary:
			sv = int((member as Dictionary).get("savvy", 0))
			nm = str((member as Dictionary).get("name",
				(member as Dictionary).get("character_name", "Crew")))
		elif member is Object and "savvy" in member:
			sv = int(member.savvy)
			nm = str(member.character_name) if "character_name" in member else "Crew"
		if sv >= best_savvy:
			best_savvy = sv
			best_name = nm

	var result: Dictionary = NewWorldArrivalRef.attempt_forged_licence(
		campaign, _current_planet_id(), best_savvy)
	var lines: Array[String] = []
	if not str(result.get("reason", "")).is_empty():
		lines.append(str(result["reason"]))
	else:
		# Show the Fake ID +1 when it applied. A displayed total that silently
		# disagrees with its own breakdown is the trap this codebase keeps hitting.
		var fake_id: int = int(result.get("fake_id_bonus", 0))
		var bonus_text: String = ""
		if fake_id > 0:
			bonus_text = " + Fake ID %d" % fake_id
		lines.append("%s forges a License: 1D6 %d + Savvy %d%s = %d vs 6+." % [
			best_name, int(result.get("roll", 0)), best_savvy, bonus_text,
			int(result.get("total", 0))])
		lines.append("The forgery passes — License obtained free (p.72)."
			if bool(result.get("success", false))
			else "The forgery does not hold up.")
		if bool(result.get("adds_rival", false)):
			# "you must add a Rival on this world, as local law enforcement, crime
			# bosses, or business cartels take a dim view of your actions."
			if campaign != null and "rivals" in campaign and campaign.rivals is Array:
				# Through the one Rival producer, on THIS world. Enforcers is p.92's
				# "most appropriate entry" for the first of the three the page names.
				campaign.rivals.append(RivalContactRef.make("forged_licence",
					"Local Enforcers", {"type": "Enforcers",
						"planet_id": _current_planet_id(),
						"created_turn": _current_campaign_turn()}))
			lines.append("A natural 1 — local enforcement takes a dim view. Rival added.")
	if job_details_label:
		job_details_label.text = "
".join(lines)
	_update_ui_display()


func _current_planet_id() -> String:
	var pdm: Node = get_node_or_null("/root/PlanetDataManager")
	if pdm == null or not ("current_planet_id" in pdm):
		return ""
	return str(pdm.current_planet_id)


func _licence_required_here() -> bool:
	return NewWorldArrivalRef.requires_freelancer_licence(
		_campaign(), _current_planet_id())


func _licence_fee_here() -> int:
	return NewWorldArrivalRef.licence_fee(_campaign(), _current_planet_id())


## "If you received a job offer from a Patron" (p.83) — the licence gates PATRON
## work only, and Faction jobs are "treated as a Patron job" (Compendium p.111).
##
## Decided by mission_source. This used to answer true for any job with a
## patron_name or patron_id, and the Open Market offer always had both ("Open
## Market", or until 2026-10-29 a generated name), so on a world that requires a
## licence the p.85 "always available" Opportunity mission was blocked too, and an
## accepted one was banked as a Patron commitment. The name test survives only for
## a job saved before mission_source existed.
func _is_patron_job(job: Dictionary) -> bool:
	var source: String = str(job.get("mission_source", job.get("source", ""))).to_lower()
	if not source.is_empty():
		return _is_patron_source(source)
	var pname: String = str(job.get("patron_name", ""))
	if pname == "Open Market":
		return false
	return not pname.is_empty() or not str(job.get("patron_id", "")).is_empty()


## Crew who could actually take the field — the p.84 "Full Squad" Condition asks
## for "6 available crew", and someone in Sick Bay is not available.
##
## Returns **-1 when the roster cannot be read**, which callers must treat as
## "unknown", not as "zero". A campaign with genuinely zero crew members is over,
## so an empty roster here always means the lookup failed rather than that the
## crew died — and a failed lookup must not be allowed to enforce a rule.
func _available_crew_count() -> int:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("get_crew_members"):
		return -1
	var crew: Array = gsm.get_crew_members()
	if crew.is_empty():
		return -1
	var count: int = 0
	for member in crew:
		var in_sick_bay: bool = false
		var status: String = ""
		if member is Dictionary:
			in_sick_bay = bool(member.get("in_sick_bay", false)) \
				or int(member.get("recovery_turns", 0)) > 0
			status = str(member.get("status", ""))
		elif member != null:
			in_sick_bay = bool(member.get("in_sick_bay")) if "in_sick_bay" in member else false
			if not in_sick_bay and "recovery_turns" in member:
				in_sick_bay = int(member.recovery_turns) > 0
			status = str(member.status) if "status" in member else ""
		if in_sick_bay:
			continue
		if status.to_lower() in ["dead", "retired", "departed", "missing"]:
			continue
		count += 1
	return count


## Returns -1 when the campaign cannot be read — "unknown", not "none". A real
## campaign with zero prior jobs here SHOULD fail the p.84 Reputation Required
## check; an unreadable one must not, or the Condition enforces itself off a
## lookup failure instead of off the crew's actual history.
func _patron_jobs_completed_here() -> int:
	var campaign = _campaign()
	if not campaign:
		return -1
	var log: Dictionary = campaign.progress_data.get("patron_jobs_completed_by_world", {})
	var pdm = get_node_or_null("/root/PlanetDataManager")
	if pdm and "current_planet_id" in pdm:
		var pid: String = str(pdm.current_planet_id)
		if pid != "" and log.has(pid):
			return int(log[pid])
	var planet = pdm.get_current_planet() if pdm and pdm.has_method("get_current_planet") else null
	if planet:
		var pname: String = str(planet.get("name", "")) if planet is Dictionary else str(planet.name)
		if log.has(pname):
			return int(log[pname])
	return 0


## An offer whose Time Frame ran out. Core Rules p.83: "If the job isn't done
## when the time runs out, it counts as a failure."
##
## The one consequence the book attaches EXPLICITLY to a failed mission is the
## Vengeful Condition (p.84): "If the mission fails, the Patron becomes a Rival."
## The errata v1.06 rule that a failed job also drops the Patron from your
## contacts is deliberately NOT applied here — it lives in post-battle Step 2
## (p.119), which is gated on a battle having been fought, and an offer that was
## never accepted never reached it. Extending it to a lapsed offer would be our
## extrapolation, not the book's rule.
func _fail_expired_job(job: Dictionary, current_turn: int) -> void:
	var patron_name: String = str(job.get("patron_name", job.get("patron", "A patron")))
	var became_rival: bool = false

	if PatronJobEffectsClass.patron_becomes_rival_on_failure(job):
		var campaign = _campaign()
		if campaign and "rivals" in campaign:
			# p.84 Vengeful: the Patron becomes the Rival, so the name is theirs. The
			# book gives them no enemy type, which makes this p.92's "unexpected
			# Rival": two rolls, the player picks on the Rivals screen. The old
			# "Personal" type (in no enemy table), "hostility" and "resources" were
			# invented.
			campaign.rivals.append(RivalContactRef.make("vengeful_patron", patron_name,
				{"planet_id": _current_planet_id(),
					"created_turn": _current_campaign_turn()}))
			became_rival = true

	var summary: String = "%s's job expired unfinished (%s)." % [
		patron_name, str(job.get("objective", "job"))]
	if became_rival:
		summary += " Vengeful: they are now a Rival."

	var journal = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			# "campaign_event", not "campaign" — STRING_TO_TYPE has no "campaign",
			# so validate_entry() push_warning()s on every one of these and the
			# entry falls out of any type-filtered view.
			"type": "campaign_event",
			"title": "Patron job expired",
			"description": summary,
			"location": str(job.get("location", "")),
		})

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_OFFERS_GENERATED, {
			"expired_job": job,
			"patron_name": patron_name,
			"became_rival": became_rival,
		})


func _patron_identity(patron_data: Dictionary, patron_name: String) -> String:
	## Stable identity for the Patron behind a job offer (Core Rules p.119 Step 2).
	## campaign.patrons holds Strings AND Dictionaries depending on where the Patron
	## came from (creation tables append names, events append dicts), so an entry may
	## have no id at all. The NAME is then the only identity there is, and
	## PostBattleContext.remove_patron() matches on either.
	var pid: String = str(patron_data.get("id", patron_data.get("patron_id", "")))
	if pid != "":
		return pid
	return patron_name

func _roll_d10(dice_manager) -> int:
	## Roll a D10 using DiceManager or fallback to randi
	if dice_manager and dice_manager.has_method("roll_d10"):
		return dice_manager.roll_d10()
	return (randi() % 10) + 1

## Original job creation method (fallback)
func _create_job_offer(patron_data: Dictionary, location: String, job_index: int) -> Dictionary:
	## Create a single job offer using Core Rules tables
	var dice_manager = get_node_or_null("/root/DiceManager")

	# 1. The Patron, already resolved by _offer_patron() (a p.83 type and a name,
	# or the Open Market).
	var patron_type: String = str(patron_data.get("patron_type", ""))
	var patron_name: String = str(patron_data.get("patron_name", patron_type))
	var mission_source: String = _derive_mission_source(patron_data)

	# 2. Roll Danger Pay with patron bonus. A Patron payment (p.83, p.120), so an
	# Opportunity mission is offered none.
	var danger_pay_bonus: int = 1 if patron_type == "Corporation" else 0
	var danger_pay: Dictionary = _roll_danger_pay(dice_manager, danger_pay_bonus)
	if not _is_patron_source(mission_source):
		danger_pay = {"credits": 0, "double_roll_bonus": false}

	# 3. Roll Time Frame with patron bonus
	var time_frame_bonus: int = 1 if patron_type == "Secretive Group" else 0
	var time_frame_result: Dictionary = _roll_time_frame(dice_manager, time_frame_bonus)
	var time_frame: String = time_frame_result.label
	var offered_turn: int = _current_campaign_turn()

	# 4. Roll Objective
	var objective_info = _roll_objective(dice_manager)

	# 5. Roll Benefits/Hazards/Conditions (Patron jobs only, p.83)
	var bhc: Dictionary = _patron_bhc(dice_manager, patron_type, mission_source)

	# Build complete job structure
	var job = {
		"id": "job_%d_%s" % [job_index, Time.get_ticks_msec()],
		"location": location,
		"patron_type": patron_type,
		"patron_name": patron_name,
		"patron_id": _patron_identity(patron_data, patron_name),
		"objective": objective_info.name,
		"objective_description": objective_info.description,
		"danger_pay": danger_pay.credits,
		"double_roll_bonus": danger_pay.double_roll_bonus,
		"time_frame": time_frame,
		"offered_on_turn": offered_turn,
		"time_frame_turns": time_frame_result.turns,
		"deadline_turn": PatronJobEffectsClass.deadline_turn(
			offered_turn, time_frame_result.turns),
		"benefits": bhc.benefits,
		"hazards": bhc.hazards,
		"conditions": bhc.conditions,
		"enemy_type": _determine_enemy_type(mission_source),
		# Legacy fields for compatibility
		"pay": danger_pay.credits,
		"patron": patron_name,
		"source": mission_source,
		"mission_source": mission_source,
	}

	return job

## Core Rules Tables (p.83). The Patron type itself is PatronContact.roll_type().

func _roll_danger_pay(dice_manager, bonus: int = 0) -> Dictionary:
	## Roll on Danger Pay Table (D10) - Core Rules p.78
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10() + bonus
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1 + bonus

	var credits = 1
	var double_roll_bonus = false

	if roll <= 4:
		credits = 1
	elif roll <= 8:
		credits = 2
	elif roll == 9:
		credits = 3
	else:  # 10+
		credits = 3
		double_roll_bonus = true

	return {
		"credits": credits,
		"double_roll_bonus": double_roll_bonus
	}

func _roll_time_frame(dice_manager, bonus: int = 0) -> Dictionary:
	## Roll on the Time Frame Table (D10, Core Rules p.83): "the number of
	## campaign turns within which you must finish the job. If the job isn't done
	## when the time runs out, it counts as a failure."
	##
	## This used to return the display String ALONE, and that String had zero
	## readers anywhere in src/ — so the deadline existed only as a sentence in
	## the offer summary. Returning the turn count as well is what lets the job
	## carry a real `deadline_turn` that the World Phase can expire it against.
	var roll: int = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10() + bonus
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1 + bonus

	var turns: int = PatronJobEffectsClass.time_frame_turns(roll)
	var label: String = "Any time"
	if turns == 1:
		label = "This campaign turn"
	elif turns == 2:
		label = "This or the next campaign turn"
	elif turns == 3:
		label = "This or the following 2 campaign turns"

	return {"roll": roll, "turns": turns, "label": label}

func _roll_objective(dice_manager) -> Dictionary:
	## Roll on Patron Mission Objectives (D10) - Core Rules p.100
	var roll = 5
	if dice_manager and dice_manager.has_method("roll_d10"):
		roll = dice_manager.roll_d10()
	elif dice_manager:
		roll = (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1

	var objective = ""
	var description = ""

	match roll:
		1, 2:
			objective = "Deliver"
			description = "Deliver a package to the center of the battlefield"
		3:
			objective = "Eliminate"
			description = "Kill a specific target enemy"
		4, 5:
			objective = "Move Through"
			description = "Get at least 2 crew off the opposite edge"
		6, 7:
			objective = "Secure"
			description = "Hold the center objective until enemies flee"
		8:
			objective = "Protect"
			description = "Defend a VIP or location from attack"
		9, 10, _:
			objective = "Fight Off"
			description = "Drive off all enemies and hold the field"

	return {
		"name": objective,
		"description": description
	}

func _roll_bhc(dice_manager, patron_type: String,
		categories: Array = PatronJobEffectsClass.CATEGORIES) -> Dictionary:
	## Roll Benefits, Hazards and Conditions for this patron type (Core Rules
	## p.83: "Roll 1D10 for each category").
	##
	## The thresholds and all 21 subtable rows used to be hardcoded HERE, a second
	## copy of data that patron_generation.json already held — so the JSON was
	## decorative and a correction to it would have changed nothing in play.
	## PatronJobEffects is now the single reader AND roller, which is also what
	## gives each attached entry a stable `id` for the consumers to gate on.
	var result: Dictionary = {"benefits": [], "hazards": [], "conditions": []}

	for category in categories:
		var roll: int = _roll_d10_simulated(dice_manager)
		if roll < PatronJobEffectsClass.threshold(patron_type, category):
			continue
		var entry: Dictionary = PatronJobEffectsClass.entry_for_roll(
			category, _roll_d10_simulated(dice_manager))
		if not entry.is_empty():
			result[category].append({
				"id": entry.get("id", ""),
				"name": entry.get("name", ""),
				"effect": entry.get("effect", ""),
			})

	return result

func _roll_d10_simulated(dice_manager) -> int:
	## Roll D10, simulating with 2D6 if needed
	if dice_manager and dice_manager.has_method("roll_d10"):
		return dice_manager.roll_d10()
	elif dice_manager:
		return (dice_manager.roll_d6() + dice_manager.roll_d6()) % 10 + 1
	return 5

func _determine_enemy_type(mission_source: String = "patron") -> String:
	## Determine enemy type using D100 encounter tables from enemy_types.json.
	## Rolls on enemy_encounter_categories to pick a category, then
	## rolls within that category using per-enemy roll_range fields.
	## Core Rules pp.94-103.
	if _enemy_generator:
		var template: Dictionary = _enemy_generator.select_enemy_for_mission(
			mission_source
		)
		if not template.is_empty():
			return template.get("name", "Unknown Hostiles")

	# Fallback if EnemyGenerator unavailable
	var fallback_types := [
		"Raiders", "Rivals", "Criminals",
		"Pirates", "Bounty Hunters", "Unknown Hostiles"
	]
	var dice_manager = get_node_or_null("/root/DiceManager")
	if dice_manager:
		var index: int = dice_manager.roll_d6() - 1
		return fallback_types[index % fallback_types.size()]
	return fallback_types[randi() % fallback_types.size()]

## Build the "Continue a Quest" job option (Core Rules p.85).
##
## Returns {} when there is no active Quest, or when the Quest's next step is on
## another world and the crew has not travelled yet — p.120: "the next step is
## on another world, and you must travel before you are able to progress the
## Quest. You do not have to do so immediately, however. Quests will wait for
## you." Withholding the option IS that rule; the Quest is not lost, it simply
## cannot be pursued from here.
##
## A Quest job is NOT a Patron job, so it carries no Danger Pay and no
## Benefits/Hazards/Conditions (those are p.83 Patron mechanics). Pay is the
## plain 1D6 of p.120 Step 4, doubled-and-+1 on the finale — which the post-
## battle PaymentProcessor already implements off `is_quest_finale`.
func _build_quest_job(location: String) -> Dictionary:
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.has_method("has_active_quest") or not gs.has_active_quest():
		return {}

	if gs.has_method("get_quest_requires_travel"):
		var travel: Dictionary = gs.get_quest_requires_travel()
		if bool(travel.get("required", false)):
			return {}

	# Expanded Quest Progression (Compendium p.79). A pending step that is NOT
	# discharged by fighting — a purchase, a research effort, a run of crew tasks —
	# means there is no Quest battle to offer this turn: "until this has been done,
	# you cannot progress the Quest." The obligation itself is rendered in the
	# Upkeep step, so withholding the offer here is a statement, not a dead end.
	var campaign = gs.get_current_campaign() if gs.has_method("get_current_campaign") else null
	var quest_step: Dictionary = ExpandedQuestRef.get_pending_step(campaign)
	if not quest_step.is_empty() and not ExpandedQuestRef.pending_step_is_battle(campaign):
		return {}

	var quest: Dictionary = gs.get_active_quest() if gs.has_method("get_active_quest") else {}
	var is_finale: bool = gs.is_quest_finale_available() if gs.has_method(
		"is_quest_finale_available") else false
	var quest_name: String = str(quest.get("name", "Active Quest"))

	# p.89: "If this is the final battle of a Quest, it is always a Fight Off
	# objective." Stamped here so PreBattleUI shows the player the right
	# objective before deployment; CampaignTurnController honours the same flag
	# when it would otherwise roll the D10 table.
	var objective: String = "Fight Off" if is_finale else "Quest Objective (rolled at deployment)"
	var description: String = str(quest.get("description", ""))
	# A p.79 step that IS a battle names its own objective — Access (39-53),
	# Protect (66-80), none at all (54-65) — so the briefing stops guessing.
	if not is_finale and not quest_step.is_empty():
		description = str(quest_step.get("instruction", description))
		match str(quest_step.get("mission_objective", "")):
			"access": objective = "Access"
			"protect": objective = "Protect"
			"none": objective = "Survive (no objective — Compendium p.79)"
	if is_finale:
		description = ("The trail ends here. This is the final battle of the Quest: "
			+ "a straight-up fight against a reinforced enemy that will not break "
			+ "(Core Rules pp.89, 120).")

	return {
		"id": "quest_%s" % str(quest.get("id", "active")),
		"location": location,
		"patron_type": "Quest",
		"patron_name": quest_name,
		"patron_id": "",
		"job_type": "quest",
		"objective": objective,
		"objective_description": description,
		# Not a Patron job: p.120 Step 4 adds the Danger Pay bonus only "If you
		# did a Patron job". Leaving these at 0 keeps Get Paid honest.
		"danger_pay": 0,
		"pay": 0,
		"time_frame": "No time limit",
		"requirements": [],
		"benefits": [],
		"hazards": [],
		"conditions": [],
		"enemy_type": _determine_enemy_type("quest"),
		"double_roll_bonus": false,
		"patron": quest_name,
		"source": "quest",
		"mission_source": "quest",
		# The producer the entire finale chain was missing. Read by
		# CampaignTurnController (+1 enemy, forced Fight Off, fight-to-the-death),
		# PaymentProcessor (roll twice pick better, +1), LootProcessor (three
		# rolls, p.121) and ExperienceTrainingProcessor (+1 XP, p.123).
		"is_quest_finale": is_finale,
		"quest_id": str(quest.get("id", "")),
	}

## Derive mission source category for Compendium battle type selection (p.118)
## Maps patron_type to source: "patron", "opportunity", "rival", "faction", "quest"
func _derive_mission_source(patron_data: Dictionary) -> String:
	var pt: String = patron_data.get("patron_type", "generic").to_lower()
	if pt == "generic" or pt == "open market" or pt == "":
		return "opportunity"
	if "faction" in pt:
		return "faction"
	if "rival" in pt:
		return "rival"
	if "quest" in pt:
		return "quest"
	# All other patron types (minor, regular, major, elite, corporation, etc.)
	return "patron"

## Job acceptance/rejection
func accept_selected_job() -> bool:
	## Accept the currently selected job
	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		push_warning("JobOfferComponent: Invalid job selection (index=%d, jobs=%d)" % [selected_job_index, available_jobs.size()])
		return false

	var job = available_jobs[selected_job_index]

	# Core Rules p.84 Conditions that are REQUIREMENTS: Full Squad, Clean and
	# Reputation Required. Refusing here is the whole content of those three
	# table rows; before this they were printed in the offer and enforced nowhere.
	var gate: Dictionary = _acceptance_block_reason(job)
	if not gate.is_empty():
		push_warning("JobOfferComponent: job blocked — %s" % gate.reason)
		if job_details_label:
			job_details_label.text = "CANNOT ACCEPT\n\n%s" % gate.reason
		return false

	# "Negotiable — If you accept this job, you may reroll the Danger Pay roll and
	# pick the better of the two rolls" (Core Rules p.84). Fired HERE because the
	# book conditions it on acceptance, and "pick the better" is not a decision —
	# a worse result is never chosen — so it resolves without a prompt. The
	# Benefit was rolled and displayed and never rerolled anything.
	if PatronJobEffectsClass.danger_pay_rerollable(job):
		_apply_negotiable_reroll(job)

	# Compendium p.137 salvage availability roll 2-3: "Job available, but requires
	# 2 Credit non-refundable fee to accept." Charged HERE because the book
	# conditions it on acceptance, and NON-REFUNDABLE means it is spent whether or
	# not the job goes well — so it must not be refunded on a later failure.
	# The whole availability table was unrolled before the Aug 6 audit, so this
	# fee had never been charged in any campaign.
	var acceptance_fee: int = int(job.get("acceptance_fee", 0))
	if acceptance_fee > 0:
		if GameStateManager.get_credits() < acceptance_fee:
			var short_msg: String = "CANNOT ACCEPT\n\nThis salvage job needs a %d " \
				% acceptance_fee \
				+ "credit non-refundable fee (Compendium p.137).\nYou have %d." \
				% GameStateManager.get_credits()
			push_warning("JobOfferComponent: salvage fee unaffordable")
			if job_details_label:
				job_details_label.text = short_msg
			return false
		GameStateManager.remove_credits(acceptance_fee)

	job_accepted = true

	# Taking the job consumes the offer. Declining deliberately does NOT: Core
	# Rules p.83 gives the offer a Time Frame of up to three campaign turns, so
	# passing on it today leaves it on the table until that runs out. Matched by
	# id rather than index because the Quest option is prepended to the visible
	# list and is not part of the persisted store.
	var accepted_id: String = str(job.get("id", ""))
	if accepted_id != "":
		var remaining: Array = []
		for offer in _stored_offers():
			if offer is Dictionary and str(offer.get("id", "")) != accepted_id:
				remaining.append(offer)
		_store_offers(remaining)

	# -- Errata v1.06 (Campaign rules, Update) --------------------------------
	#
	# Verbatim: "If you are offered more than one Patron job at the same time,
	# you can ACCEPT ALL OF THEM but pay attention to the time-frames. Failure to
	# finish a job in the allotted time counts as a failure."
	#
	# The printed rules give no such permission, so accepting one job consumed it
	# and the rest sat on the board until their Time Frames lapsed. Now an
	# accepted job is ALSO banked as an outstanding commitment: the crew fights
	# ONE of them this turn (`get_accepted_job()` is unchanged, and
	# WorldPhaseController still builds the mission_dict from it), and the others
	# keep counting down and lapse into real failures through the same
	# `_fail_expired_job()` path a lapsed OFFER takes.
	_bank_accepted_commitment(job)

	# Publish job accepted event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.JOB_ACCEPTED, {
			"job_data": job
		})

	_update_ui_display()
	return true

## Errata v1.06: accepted-but-unfought jobs. Stored on the CAMPAIGN so they
## survive a save and the World Phase checkpoint.
const PENDING_KEY := "patron_jobs_accepted_pending"


func _pending_commitments() -> Array:
	var campaign = _campaign()
	if not campaign or not ("progress_data" in campaign):
		return []
	if not (campaign.progress_data is Dictionary):
		return []
	var raw: Variant = campaign.progress_data.get(PENDING_KEY, [])
	return (raw as Array) if raw is Array else []


func _store_commitments(entries: Array) -> void:
	var campaign = _campaign()
	if not campaign or not ("progress_data" in campaign):
		return
	if not (campaign.progress_data is Dictionary):
		return
	campaign.progress_data[PENDING_KEY] = entries


## Record an accepted job as an outstanding commitment.
##
## PATRON jobs only: the errata clause is about Patron jobs, and a Quest or an
## Opportunity mission is generated fresh each turn rather than offered with a
## Time Frame to miss.
func _bank_accepted_commitment(job: Dictionary) -> void:
	if not _is_patron_job(job):
		return
	var job_id: String = str(job.get("id", ""))
	if job_id.is_empty():
		return
	var entries: Array = _pending_commitments().duplicate()
	for existing in entries:
		if existing is Dictionary and str(existing.get("id", "")) == job_id:
			return
	var record: Dictionary = job.duplicate(true)
	record["accepted_on_turn"] = _current_campaign_turn()
	entries.append(record)
	_store_commitments(entries)


## Discharge a commitment once its battle has been fought, so a job the crew
## actually ran cannot later lapse as an unfinished one.
func discharge_commitment(job_id: String) -> void:
	if job_id.is_empty():
		return
	var kept: Array = []
	for entry in _pending_commitments():
		if entry is Dictionary and str(entry.get("id", "")) != job_id:
			kept.append(entry)
	_store_commitments(kept)


## Errata v1.06: "pay attention to the time-frames. Failure to finish a job in
## the allotted time counts as a failure."
##
## Lapsed commitments go through the same `_fail_expired_job()` as a lapsed
## OFFER — removal from known Patrons (errata Correction p.119) and the p.84
## Vengeful check — because the errata says a missed deadline COUNTS AS A
## FAILURE, not as a quietly forgotten offer.
func _expire_stale_commitments(current_turn: int) -> Array:
	var live: Array = []
	var lapsed: Array = []
	for entry in _pending_commitments():
		if not (entry is Dictionary):
			continue
		var accepted_on: int = int(entry.get("accepted_on_turn", current_turn))
		var frame: int = int(entry.get("time_frame_turns",
			entry.get("time_frame", 0)))
		if frame > 0 and current_turn - accepted_on >= frame:
			lapsed.append(entry)
		else:
			live.append(entry)
	if not lapsed.is_empty():
		_store_commitments(live)
	for job in lapsed:
		_fail_expired_job(job, current_turn)
	return live


func decline_selected_job() -> bool:
	## Decline (pass on) the currently selected job — removes it from the
	## offer list and clears the selection. Completes the "acceptance/
	## rejection" contract this section documents (accept existed alone).
	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		return false

	available_jobs.remove_at(selected_job_index)
	selected_job_index = -1
	_update_ui_display()
	return true

## UI Event Handlers
func _on_job_selected(index: int) -> void:
	## Handle job selection from list
	selected_job_index = index
	_update_job_details()
	_update_ui_display()

func _on_accept_job_pressed() -> void:
	## Handle accept job button press
	accept_selected_job()

func _on_reroll_jobs_pressed() -> void:
	## Handle reroll jobs button press (costs 1 credit)
	if GameStateManager.get_credits() >= 1:
		GameStateManager.remove_credits(1)

		# Regenerate jobs
		var patron_data = {}  # NOTE: Needs campaign patron data integration
		var location = ""     # NOTE: Needs campaign location integration
		initialize_job_phase(patron_data, location)


## UI Updates
func _update_ui_display() -> void:
	## Update UI display with current job offers
	if job_list:
		job_list.clear()
		var current_turn: int = _current_campaign_turn()
		for i in range(available_jobs.size()):
			var job = available_jobs[i]
			# The deadline is recomputed against the CURRENT turn: a job held over
			# from last turn must read "Expires this campaign turn", not repeat the
			# wording it was born with. Held offers made the stale label actively
			# misleading, which is the moment a rolled Time Frame started to matter.
			var job_text = "%s (%s) - +%d cr - %s" % [
				job.get("objective", "Unknown"),
				job.get("patron_type", "Unknown"),
				job.get("pay", job.get("danger_pay", 0)),  # Danger Pay on top of the p.120 1D6 base
				PatronJobEffectsClass.deadline_label(job, current_turn)
			]
			job_list.add_item(job_text)
	else:
		pass

	# Update button states
	var has_selection = selected_job_index >= 0 and selected_job_index < available_jobs.size()
	if accept_button:
		accept_button.disabled = not has_selection or job_accepted
	_refresh_licence_controls()
	# Lock reroll + job list after acceptance
	if reroll_button:
		reroll_button.disabled = job_accepted
	if job_list:
		if job_accepted:
			job_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
			job_list.modulate.a = 0.5
		else:
			# Restore interactivity when NOT accepted. Critical for turn 2+:
			# reset_job_phase() sets job_accepted=false but the old code only
			# ever LOCKED the list (in the job_accepted branch) and never
			# un-locked it, so a job accepted on turn 1 left the reused list
			# MOUSE_FILTER_IGNORE on every later turn — a hard soft-lock on the
			# REQUIRED Job Offers step (selection dead, no visible decline path).
			job_list.mouse_filter = Control.MOUSE_FILTER_STOP
			job_list.modulate.a = 1.0

	_update_job_details()

func _update_job_details() -> void:
	## Update job details display with Core Rules info
	if not job_details_label:
		return

	if selected_job_index < 0 or selected_job_index >= available_jobs.size():
		job_details_label.text = "Select a job to view details"
		return

	var job = available_jobs[selected_job_index]

	# Build rich details display
	var details = "=== JOB OFFER ===\n\n"

	# Patron info
	details += "PATRON: %s\n" % job.get("patron_name", job.get("patron", "Unknown"))
	details += "Type: %s\n\n" % job.get("patron_type", "Unknown")

	# NO objective row here, deliberately.
	#
	# T10-03, found on the tablet 2026-09-04: this card promised "OBJECTIVE: Secure"
	# and the battle then ran Protect — a VIP scenario needing a figure set up 12"
	# from centre, i.e. a different table from the one the player had built.
	#
	# The book is unambiguous about which of the two is right. Core Rules p.83
	# ("3. Determine Job Offers") lists a job as Patron, Time Frame, Danger Pay,
	# Benefits, Hazards and Conditions — there is no objective among them. Core
	# Rules p.89 ("5. Determine the Objective") then says "Opportunity, Patron and
	# Quest missions will ROLL for the objective you are undertaking", at battle
	# setup, after the job is accepted. So CampaignTurnController's p.89 roll is
	# correct and this display was inventing a value the rules do not grant yet.
	#
	# The objective reaches the player on the Battle Card, which is when the book
	# says they learn it. What a job legitimately advertises is below: pay, danger
	# pay, time frame, enemy, hazards and conditions.
	if not str(job.get("objective_description", "")).strip_edges().is_empty():
		details += "%s\n\n" % job.get("objective_description", "")

	# Pay and timing. Payout is a 1D6 base rolled at Get Paid (Core Rules p.120)
	# plus Danger Pay for a Patron job. The base cannot be quoted as a number before
	# the battle, so it is printed as the die; it read "~N credits" from an invented
	# base of 4 until 2026-10-29.
	details += "PAY: 1D6 credits after the battle (p.120)\n"
	details += "DANGER PAY: +%d credits\n" % job.get("danger_pay", 0)
	if job.get("double_roll_bonus", false):
		details += "(Bonus: Roll twice for mission pay, keep higher)\n"
	details += "TIME FRAME: %s\n" % PatronJobEffectsClass.deadline_label(
		job, _current_campaign_turn())
	# Requirements the player must satisfy BEFORE the Accept button will take
	# (Core Rules p.84 Conditions). Stated up front rather than only refusing.
	var gate: Dictionary = _acceptance_block_reason(job)
	if not gate.is_empty():
		details += "REQUIREMENT: %s\n" % gate.reason
	details += "\n"

	# Enemy
	details += "ENEMY: %s\n" % job.get("enemy_type", "Unknown")
	details += "\n"

	# Benefits
	var benefits = job.get("benefits", [])
	if benefits.size() > 0:
		details += "BENEFITS:\n"
		for benefit in benefits:
			details += "  • %s: %s\n" % [benefit.name, benefit.effect]
		details += "\n"

	# Hazards
	var hazards = job.get("hazards", [])
	if hazards.size() > 0:
		details += "HAZARDS:\n"
		for hazard in hazards:
			details += "  • %s: %s\n" % [hazard.name, hazard.effect]
		details += "\n"

	# Conditions
	var conditions = job.get("conditions", [])
	if conditions.size() > 0:
		details += "CONDITIONS:\n"
		for condition in conditions:
			details += "  • %s: %s\n" % [condition.name, condition.effect]
		details += "\n"

	# Location
	details += "LOCATION: %s\n" % job.get("location", "Unknown")

	# Compendium Expanded Missions (pp.118-125).
	#
	# THE BUG THIS FIXES: this block rendered "OVERVIEW: ", "SPECIFIC OBJECTIVE: ",
	# "TIME CONSTRAINT: ", "PATRON CONDITION: " and "EXTRACTION: " with NOTHING
	# after the colon, on every Expanded Missions job. The rows in
	# data/compendium/missions_expanded.json carry `id` and `instruction` and have
	# no `name` key at all, so every .get("name", "") was "" — a heading printed
	# for a value that has never existed.
	#
	# The `instruction` is the book's own line and is already self-labelled
	# ("OVERVIEW: Single objective. Generate 1 objective...", "TIME: No time
	# limit."), so the fix is to print it and drop the duplicate heading rather
	# than invent display names the table does not have.
	var dlc_lines: Array[String] = []
	var overview_line: String = str(job.get("dlc_objective_instruction", "")).strip_edges()
	if not overview_line.is_empty():
		dlc_lines.append(overview_line)

	# Compendium pp.74-76: a two-objective mission gets TWO objectives with TWO
	# separate time constraints, so the briefing numbers them. A one-objective
	# mission prints no number — there is nothing to distinguish.
	var objectives: Array = job.get("dlc_objectives", [])
	for i in range(objectives.size()):
		var entry: Dictionary = objectives[i]
		var prefix: String = "" if objectives.size() <= 1 else "[%d] " % (i + 1)
		for key in ["instruction", "time_instruction"]:
			var line: String = str(entry.get(key, "")).strip_edges()
			if not line.is_empty():
				dlc_lines.append(prefix + line)

	for key in ["dlc_patron_instruction", "dlc_extraction_instruction"]:
		var line: String = str(job.get(key, "")).strip_edges()
		if not line.is_empty():
			dlc_lines.append(line)
	if not dlc_lines.is_empty():
		details += "\n--- COMPENDIUM MISSION DETAILS ---\n"
		for line in dlc_lines:
			details += "%s\n" % line

	job_details_label.text = details

## Event Bus Handlers
func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "job_offers":
		pass

func _on_automation_toggled(data: Dictionary) -> void:
	## Handle automation toggle events
	automation_enabled = data.get("enabled", false)

	# AUTO-PROCESS: If enabled and jobs available, auto-accept first job
	if automation_enabled and available_jobs.size() > 0 and not job_accepted:
		selected_job_index = 0
		accept_selected_job()

## Public API for integration
func is_job_accepted() -> bool:
	## Check if a job has been accepted
	return job_accepted

func get_blocker_hint() -> String:
	## Human-readable reason this step can't advance yet ("" if it can).
	if is_job_accepted():
		return ""
	return "Accept a job offer (or decline all) to continue."

func get_accepted_job() -> Dictionary:
	## Get the accepted job data
	if job_accepted and selected_job_index >= 0 and selected_job_index < available_jobs.size():
		return available_jobs[selected_job_index].duplicate()
	return {}

func get_available_jobs() -> Array[Dictionary]:
	## Get all available jobs
	return available_jobs.duplicate()

## Sprint 12.2: Standardized step results for WorldPhaseController integration
func get_step_results() -> Dictionary:
	## Get step results for phase completion (standardized interface)
	return {
		"job_accepted": job_accepted,
		"accepted_job": get_accepted_job(),
		"available_jobs": available_jobs.duplicate(),
		"selected_job_index": selected_job_index,
		# Errata v1.06 outstanding commitments, so the World Phase checkpoint
		# carries them. They also live on campaign.progress_data and THAT is the
		# owner — this is the checkpoint copy, not a second home.
		"pending_commitments": _pending_commitments().duplicate(true),
	}

func restore_step_results(data: Dictionary) -> void:
	## Re-adopt the state `get_step_results()` produced. The inverse of that
	## function, and it must stay the inverse — the two are a pair.
	##
	## ⚠ WHY THIS EXISTS. The accepted job lived ONLY here, in memory. The World
	## Phase checkpoint (`WorldPhaseController.save_checkpoint()`) persists
	## `current_step` / `step_completed` / `world_phase_data` and nothing about the
	## job, so resuming a checkpoint rebuilt this component empty:
	## `get_accepted_job()` returned {} and `_refresh_mission_prep()` — which reads
	## the mission from exactly that call — rendered the briefing as
	## "Objective: Unknown / Enemy: Unknown / Pay: 0".
	##
	## MEASURED on the tablet Aug 13 2026: a save resumed at Step 6/6 showed that
	## blank briefing while `progress.world_phase_results.mission_data` still held
	## the full job (patron "Regional Contractor", "Move Through", enemy
	## "Gun Slingers", pay 6). Walking the same save cleanly from Step 1 rendered
	## the real briefing — so the data was never lost, only the live component's
	## copy of it.
	##
	## NOTE the fix is NOT "fall back to world_phase_results.mission_data": that
	## key is written at PHASE COMPLETION, so on a turn-3 resume it holds turn 2's
	## job. A stale mission presented as the current one is worse than a blank one.
	var restored: Array[Dictionary] = []
	for entry: Variant in data.get("available_jobs", []):
		if entry is Dictionary:
			restored.append(entry)
	available_jobs = restored
	selected_job_index = int(data.get("selected_job_index", -1))
	# Only meaningful with a job actually in range — a checkpoint written before
	# any offer was accepted must not resurrect one.
	job_accepted = bool(data.get("job_accepted", false)) \
		and selected_job_index >= 0 \
		and selected_job_index < available_jobs.size()
	if not job_accepted:
		selected_job_index = -1 if available_jobs.is_empty() else selected_job_index
	# Restore the errata commitments only when the campaign holds none: the
	# campaign is the owner, so a live value always wins over the checkpoint copy.
	# Guarded in the CALLEE so it cannot matter which of initialize_job_offers()
	# three callers ran first — the T9-50 lesson.
	var carried: Variant = data.get("pending_commitments", [])
	if carried is Array and not (carried as Array).is_empty():
		if _pending_commitments().is_empty():
			_store_commitments((carried as Array).duplicate(true))
	_update_ui_display()


func reset_job_phase() -> void:
	## Reset job phase for new turn
	job_accepted = false
	selected_job_index = -1
	available_jobs.clear()
	_update_ui_display()

## ── Compendium Introductory Campaign (DLC) ──

func _check_introductory_mission() -> Dictionary:
	## If introductory_campaign is enabled, return the guided mission for this turn.
	## Returns {} if not applicable (flag not set, DLC disabled, or turn past intro range).
	var game_state_node = get_node_or_null("/root/GameState")
	if not game_state_node:
		return {}
	var campaign = game_state_node.campaign if "campaign" in game_state_node else null
	if not campaign:
		return {}
	if not "progress_data" in campaign:
		return {}
	if not campaign.progress_data.get("introductory_campaign", false):
		return {}

	# `turns_played` is the SSOT for the turn counter; nothing has ever written
	# "current_turn", so this defaulted to 1 forever and the Introductory
	# Campaign served its turn-1 guided mission on every single turn. Same
	# convention as the dashboard/journal: turns_played counts COMPLETED turns,
	# so the turn being played is +1.
	var turn: int = int(campaign.progress_data.get("turns_played", 0)) + 1
	var intro: Dictionary = CompendiumMissionsExpanded.get_introductory_mission(turn)
	if intro.is_empty():
		return {}  # Past introductory range — fall through to normal generation

	# Convert introductory mission format to job offer format
	return {
		"id": "intro_turn_%d" % turn,
		"location": "Introductory Mission",
		"patron_type": "Tutorial",
		"patron_name": "Campaign Guide",
		# The Compendium intro entries carry exactly three fields — turn, title,
		# instruction. Reads for "name", "pay", "danger" and "enemy_type" matched
		# nothing, so the title never displayed and the defaults behind them
		# (pay 2, danger 1) were fabricated values standing in for book data that
		# does not exist. Per the data-integrity rule those are gone rather than
		# invented: the intro missions do not rate danger or promise a fee, and
		# payment is rolled normally after the battle (Core Rules p.120) on every
		# guided turn that runs the post-battle sequence.
		"objective": intro.get("title", "Introductory Mission"),
		"objective_description": intro.get("instruction", ""),
		"pay": 0,
		"double_roll_bonus": false,
		"time_frame": "This Turn",
		"benefits": [],
		"hazards": [],
		"conditions": [],
		# The opposition is scripted in the instruction text above and set up by
		# the player on the table — this is a companion app, not a simulator.
		"enemy_type": "See mission instructions",
		"source": "introductory",
		"mission_source": "introductory",
		"_introductory": true,
	}

## ── Compendium Expanded Missions (DLC, pp.118-125) ──

## Compendium p.112 Affiliated Patron jobs, verbatim: "Many Patron jobs will be
## affiliated with a Faction either directly or indirectly. Whenever you receive a
## job from a NEW Patron, roll a D6: 1-4 It is a normal job. 5-6 The patron is
## affiliated with a randomly selected Faction."
##
## `FactionSystem.check_affiliated_patron()` implemented this roll and had ZERO
## callers, so no job was ever flagged: `is_affiliated_patron_job` was permanently
## false at RivalPatronResolver:252, which meant the harder p.112 Loyalty branch
## ("a roll of a 6 earns +1 Loyalty") was unreachable and affiliated jobs — which
## the book makes LESS rewarding — silently used the easier direct-job odds.
##
## "A NEW Patron" is the trigger, so the answer is remembered per patron identity
## in progress_data. Re-rolling it every offer would let the same contact drift in
## and out of a Faction between turns, and would give a frequently-seen Patron a
## 1 - (2/3)^n chance of eventually being affiliated instead of the flat 1/3 the
## book prints. An empty string is stored for "not affiliated" precisely so the
## absence of a roll and a rolled 1-4 stay distinguishable.
func _stamp_patron_affiliation(job: Dictionary) -> void:
	if str(job.get("mission_source", "")) == "faction":
		return  # a direct Faction job is not an affiliated PATRON job
	var patron_id: String = str(job.get("patron_id", ""))
	var patron_name: String = str(job.get("patron_name", ""))
	if patron_id.is_empty() or patron_name == "Open Market":
		return  # the open market is not a Patron

	var campaign: Resource = _campaign()
	if campaign == null or not ("progress_data" in campaign):
		return
	var memory: Dictionary = campaign.progress_data.get("patron_faction_affiliation", {})

	var faction_id: String = ""
	if memory.has(patron_id):
		faction_id = str(memory[patron_id])
	else:
		var faction_sys: Node = get_node_or_null("/root/FactionSystem")
		if faction_sys == null or not faction_sys.has_method("check_affiliated_patron"):
			return
		faction_id = str(faction_sys.check_affiliated_patron(job))
		memory[patron_id] = faction_id
		campaign.progress_data["patron_faction_affiliation"] = memory

	if faction_id.is_empty():
		return
	job["faction_id"] = faction_id
	job["is_affiliated_patron_job"] = true
	# Display name for the offer summary, read off the real store. (`get_all_factions()`
	# returns active_factions; there is no by-id name accessor and inventing a
	# has_method() guard for one would be permanently false — the exact defect
	# shape this cluster is full of.)
	var fs: Node = get_node_or_null("/root/FactionSystem")
	if fs and fs.has_method("get_all_factions"):
		var all: Dictionary = fs.get_all_factions()
		if all.has(faction_id):
			job["faction_name"] = str((all[faction_id] as Dictionary).get("name", faction_id))


func _enhance_job_with_compendium(job: Dictionary) -> void:
	## Enhance a job offer with Compendium expanded mission data (pp.118-125).
	## Self-gated: methods return {} if EXPANDED_MISSIONS DLC disabled.
	_stamp_patron_affiliation(job)
	##
	## Stores `id` (a stable key for logic) and `instruction` (the book's own
	## self-labelled line, which is what the briefing renders). It used to store
	## .get("name", "") for the display half — a key the rows in
	## missions_expanded.json have NEVER had — so the briefing printed
	## "OVERVIEW: " with nothing after the colon on every Expanded Missions job.
	var objective_overview: Dictionary = CompendiumMissionsExpanded.roll_objective_overview()
	var objective_count: int = 1
	if not objective_overview.is_empty():
		job["dlc_objective_overview"] = objective_overview.get("id", "")
		job["dlc_objective_instruction"] = objective_overview.get("instruction", "")
		objective_count = maxi(1, int(objective_overview.get("count", 1)))

	## HOW MANY OBJECTIVES. Compendium p.74 rolls 61-85 and 86-100 both read
	## "Generate two objectives, EACH WITH THEIR OWN TIME CONSTRAINTS"; p.75 says
	## the specific-objective table is rolled "once for each objective"; p.76 says
	## "If you have two objectives, a constraint is determined SEPARATELY FOR EACH
	## OBJECTIVE."
	##
	## The overview row has carried `count: 2` since the table was extracted and
	## NOTHING read it, so 40% of Expanded Missions rolls told the player "Two
	## objectives, BOTH required" and then listed exactly one objective with one
	## time limit — a briefing that contradicted itself on the same card.
	##
	## Duplicates are NOT rerolled. The book says only "roll once for each
	## objective" and two of the same objective is a legal, playable outcome (two
	## Search markers, two Secure points); inventing a reroll would be inventing a
	## rule.
	var dlc_objectives: Array[Dictionary] = []
	for i in range(objective_count):
		var entry: Dictionary = {}
		var specific_obj: Dictionary = CompendiumMissionsExpanded.roll_specific_objective()
		if not specific_obj.is_empty():
			entry["id"] = specific_obj.get("id", "")
			entry["instruction"] = specific_obj.get("instruction", "")
		var time_constraint: Dictionary = CompendiumMissionsExpanded.roll_time_constraint()
		if not time_constraint.is_empty():
			entry["time_id"] = time_constraint.get("id", "")
			entry["time_instruction"] = time_constraint.get("instruction", "")
		if not entry.is_empty():
			dlc_objectives.append(entry)

	if not dlc_objectives.is_empty():
		job["dlc_objectives"] = dlc_objectives
		# The singular keys stay as objective 1 so every existing reader keeps
		# working; the briefing renders the full list from `dlc_objectives`.
		var first: Dictionary = dlc_objectives[0]
		job["dlc_specific_objective"] = first.get("id", "")
		job["dlc_specific_instruction"] = first.get("instruction", "")
		job["dlc_time_constraint"] = first.get("time_id", "")
		job["dlc_time_instruction"] = first.get("time_instruction", "")

	## PATRON JOBS ONLY. Compendium p.76 heads this table "Special Conditions:
	## Patron Jobs Only" and opens it "IF UNDERTAKING A PATRON JOB, roll D100 on
	## the table below to determine what special conditions apply."
	##
	## It was rolled for every offer, so an Open Market / Opportunity mission could
	## arrive carrying "No Psionics may be deployed", "No Armor may be deployed" or
	## "No more than 3 crew may fire a weapon each round" — restrictions the book
	## justifies as "employer parameters", from an employer that does not exist.
	##
	## Same gate as Danger Pay above (:633), and for the same reason: these are
	## both p.83/p.76 PATRON tables that the Open Market builder was running
	## anyway. Faction jobs count as patron work here — they are contracted by an
	## employer with parameters, which is exactly what the table models.
	var job_source: String = str(job.get("mission_source", job.get("source", "")))
	if job_source == "patron" or job_source == "faction":
		var patron_cond: Dictionary = CompendiumMissionsExpanded.roll_patron_condition()
		if not patron_cond.is_empty():
			job["dlc_patron_condition"] = patron_cond.get("id", "")
			job["dlc_patron_instruction"] = patron_cond.get("instruction", "")

	var extraction: Dictionary = CompendiumMissionsExpanded.roll_extraction()
	if not extraction.is_empty():
		job["dlc_extraction"] = extraction.get("id", "")
		job["dlc_extraction_instruction"] = extraction.get("instruction", "")
