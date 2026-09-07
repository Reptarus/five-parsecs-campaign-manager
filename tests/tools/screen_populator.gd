extends RefCounted
## SHARED per-screen data population for the windowed sweeps.
##
## Used by BOTH tests/tools/verify_layout.gd (fresh instance per size) and
## tests/tools/verify_rotation.gd (one instance walked through sizes). It lives in
## one file on purpose: two copies of a fixture builder is how they drift, and a
## screen added to one sweep's fixture set but not the other is a blind spot that
## reads as a pass. This is the same lesson CLAUDE.md records for the theme
## constants ("four copies of a number set is how a design system drifts").
##
## ── WHY THIS EXISTS — the sweeps measured the right SIZE and the wrong SCREEN ──
##
## T11-01 (PreBattleUI footer clipped to ~13px in tablet landscape, page will not
## scroll) reached real hardware while the geometry sweep was GREEN, and 1280x800
## was already in its SIZES list. The sweep did instantiate PreBattle.tscn and did
## measure it — but nothing ever handed it a mission, a crew or a battlefield, so
## all four of its panes were EMPTY. An empty pane is short. The overflow that
## pushes the footer off only exists once the panes carry content.
##
## Screens that build from GameState (CampaignDashboard) self-populate in _ready()
## and were always measured with real content. Screens whose data arrives from
## their NAVIGATOR were measured empty on every run, at every size. That asymmetry
## is what this closes: "a screen was instantiated" was being reported as "a screen
## was verified".
##
## The rotation sweep has the same gap and it bites harder there — its shape
## assertion is about an AdaptivePanelGroup's column count, and PreBattleUI's group
## is exactly the thing T11-01 overflowed.
##
## THREE MECHANISMS, because the app itself uses three:
##   1. SceneRouter.scene_contexts[key]     read in _ready()  -> populate BEFORE
##   2. GameStateManager.set_temp_data()    read in _ready()  -> populate BEFORE
##   3. a setup method the navigator calls after add_child()  -> populate AFTER
## populate_pre() covers 1 and 2; populate_post() covers 3.
##
## ⚠ THE FIXTURES INVENT NOTHING, and that is not a nicety here. A hand-typed
## mission literal would fabricate game values AND drift from the producer, and a
## fixture that skips a producer key hides the bug it was written to catch
## (CLAUDE.md: "a fixture that skips a producer key hides a live bug"). So:
##   crew        <- the LOADED CAMPAIGN's real crew_data["members"]
##   mission     <- BattleSimulatorSetup.generate_battle_context(), which reads the
##                  shipped data/mission_templates.json + data/enemy_types.json
##   setup_rules <- BattleSetupRules.compute() — the real pp.88/91-92 bundle
##   terrain     <- CampaignPhaseManager.generate_battlefield() (Compendium
##                  pp.94-98), the same autoload call the campaign path makes
##   result      <- BattleResultNormalizer.normalize(), the chokepoint EVERY real
##                  battle path crosses
##   category / legal doc <- enumerated live and the LARGEST one chosen, so a
##                  hardcoded id that stops existing cannot silently populate
##                  nothing and read as a pass
##
## A fixture builder that cannot resolve its source returns empty and the screen is
## measured exactly as before — never a fabricated stand-in.
##
## ⚠ NOTHING HERE MAY BE preload()ed BY A HARNESS. Several production scripts
## reference bare autoload identifiers, which are not registered as GDScript
## globals when a --script main loop is compiled. Both sweeps load() this file at
## runtime for that reason, and everything it touches is load()ed too.

## Screens whose data arrives from their NAVIGATOR, and the fixture that supplies
## it. A screen absent from this table either self-populates from GameState or
## genuinely has no caller-supplied data.
const POPULATE: Dictionary = {
	"res://src/ui/screens/battle/PreBattle.tscn": "pre_battle",
	"res://src/ui/screens/battle/TacticalBattleUI.tscn": "tactical_battle",
	"res://src/ui/screens/postbattle/PostBattleSequence.tscn": "post_battle",
	"res://src/ui/screens/character/CharacterDetailsScreen.tscn": "character_details",
	"res://src/ui/screens/compendium/CompendiumCategoryView.tscn": "compendium_category",
	"res://src/ui/screens/legal/LegalTextViewer.tscn": "legal_viewer",
	"res://src/ui/screens/equipment/EquipmentGenerationScene.tscn": "equipment_generation",
	# T11-40. Added 2026-09-06. This screen was in verify_layout's SCREENS list all
	# along and the sweep stayed green while the tablet clipped 27px off Next Step on
	# a TALL step - because every one of its six phase panes was measured EMPTY, and
	# an empty pane is short. Exactly the T11-01 shape, one screen along.
	"res://src/ui/screens/world/WorldPhaseController.tscn": "world_phase",
}

var _root: Node = null
var _fixture_cache: Dictionary = {}
var _device_mission_cache: Dictionary = {}


func _init(tree_root: Node) -> void:
	_root = tree_root


## `-- populate=off` turns the whole layer off, so the A/B that proves a finding is
## real differs in exactly ONE variable. Without it the only control is "the sweep
## before I edited it", which also differs in whatever else changed.
func enabled() -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg).strip_edges().to_lower() == "populate=off":
			return false
	return true


## One-line summary for the run header, beside "campaign state". Two runs must
## never be silently compared across this boundary either: a run whose fixture came
## back empty is measuring the same empty screens the old sweeps did.
func state_line() -> String:
	if not enabled():
		return "OFF (-- populate=off) — screens measured EMPTY, as before this layer"
	var f: Dictionary = battle_fixture()
	var dev: Dictionary = device_pre_battle_mission()
	return "%d screens hooked | fixture: crew=%d enemies=%d mission_keys=%d%s | PreBattle mission: %s" % [
		POPULATE.size(),
		(f.get("crew", []) as Array).size(),
		(f.get("enemies", []) as Array).size(),
		(f.get("mission", {}) as Dictionary).size(),
		"" if f.get("crew_is_real", false) else "  (crew GENERATED - no campaign)",
		("DEVICE (%d keys, %d-char briefing)" % [
			dev.size(), str(dev.get("description", "")).length()]
			if not dev.is_empty()
			else "GENERATED - the device fixture is missing, so the Mission pane "
				+ "measures ~440 px SHORT and cannot reproduce the landscape defect"),
	]


func populate_pre(path: String) -> void:
	if not enabled():
		return
	var key: String = str(POPULATE.get(path, ""))
	if key.is_empty():
		return
	var fn := "_pre_" + key
	if has_method(fn):
		call(fn)


## Call after add_child()+show() and BEFORE the first settle, so whatever the
## fixture builds is included in the settle loop's stability signature.
func populate_post(inst: Node, path: String) -> void:
	if not enabled():
		return
	var key: String = str(POPULATE.get(path, ""))
	if key.is_empty():
		return
	var fn := "_post_" + key
	if has_method(fn):
		call(fn, inst)


## WorldPhaseController is populated by its ORCHESTRATOR, not by _ready(): 
## CampaignTurnController SHOWS this controller each turn rather than re-creating
## it, and calls initialize_world_phase() afterwards. A sweep that only
## instantiate()s the scene therefore measures six empty step panes forever.
##
## ⚠ The three arguments are read off the loaded campaign EXACTLY as
## CampaignTurnController.gd:893-897 reads them - same keys, same fallbacks, same
## order. Nothing is fabricated: a hand-built ship/world dict would populate the
## screen with a shape the app never produces, which is the failure this whole
## fixture layer exists to avoid.
##
## With no campaign loaded this is a NO-OP rather than a stub, so the run reports
## an unpopulated screen instead of quietly measuring an invented one.
func _post_world_phase(inst: Node) -> void:
	if inst == null or not inst.has_method("initialize_world_phase"):
		return
	var gs := _root.get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("get_current_campaign"):
		return
	var c = gs.get_current_campaign()
	if c == null:
		return
	var ship_d: Dictionary = c.get("ship_data") if "ship_data" in c else {}
	var crew_d: Array = c.crew_data.get("members", []) if "crew_data" in c else []
	var world_d: Dictionary = c.get("world_data") if "world_data" in c else {}
	inst.initialize_world_phase(ship_d, crew_d, world_d)


func _set_scene_context(key: String, ctx: Dictionary) -> void:
	var router := _root.get_node_or_null("/root/SceneRouter")
	if router == null or not ("scene_contexts" in router):
		return
	router.scene_contexts[key] = ctx


## The loaded campaign's REAL crew. Empty when no campaign is loaded, which the
## caller reports rather than papering over.
func campaign_crew() -> Array:
	var gs := _root.get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("get_current_campaign"):
		return []
	var campaign = gs.get_current_campaign()
	if campaign == null or not ("crew_data" in campaign):
		return []
	var cd = campaign.crew_data
	if not (cd is Dictionary):
		return []
	var members = (cd as Dictionary).get("members", [])
	return members if members is Array else []


## Built ONCE per sweep and reused, so every screen in a run sees the same battle —
## a mission that differed per screen would make two findings incomparable.
func battle_fixture() -> Dictionary:
	if not _fixture_cache.is_empty():
		return _fixture_cache
	var out: Dictionary = {
		"crew": [], "enemies": [], "mission": {}, "crew_is_real": false}

	var SetupCls = load("res://src/core/battle/BattleSimulatorSetup.gd")
	if SetupCls != null:
		var setup = SetupCls.new()
		var ctx: Dictionary = setup.generate_battle_context({
			"crew_size": 6, "difficulty": 3})
		out["enemies"] = ctx.get("enemies", [])
		out["mission"] = ctx.get("mission_data", {})
		out["crew"] = ctx.get("crew", [])

	# A real campaign's crew beats a generated one: real names are longer, real
	# members carry equipment and status effects, and those are what make a crew row
	# wrap. Generated crew is the fallback, and the header says which one ran.
	var real_crew: Array = campaign_crew()
	if not real_crew.is_empty():
		out["crew"] = real_crew
		out["crew_is_real"] = true

	var mission: Dictionary = out.get("mission", {})
	var crew_n: int = (out.get("crew", []) as Array).size()
	var enemy_n: int = (out.get("enemies", []) as Array).size()

	# The pp.88 / pp.91-92 setup checklist. This is the Mission pane's tallest block
	# and the one PreBattleUI._setup_scenario_rules() renders, so a fixture without
	# it under-measures the exact pane that overflows.
	var RulesCls = load("res://src/core/battle/BattleSetupRules.gd")
	if RulesCls != null and not mission.is_empty():
		mission["setup_rules"] = RulesCls.compute(mission, enemy_n, crew_n)

	# Compendium pp.94-98 battlefield, through the same autoload entry point
	# CampaignTurnController uses. Seeded so two runs generate the same table.
	var cpm := _root.get_node_or_null("/root/CampaignPhaseManager")
	if cpm != null and cpm.has_method("generate_battlefield"):
		var bf = cpm.generate_battlefield("", [], {}, 20260904, 3.0)
		if bf is Dictionary and not (bf as Dictionary).is_empty():
			mission["terrain"] = bf

	out["mission"] = mission
	_fixture_cache = out
	return _fixture_cache


# ── the per-screen hooks ────────────────────────────────────────────────────

## The mission a REAL device run produced, or {} when the file is absent.
##
## ⚠ WHY THIS EXISTS, and it is the sharpest lesson this file has learned twice:
## a POPULATED SCREEN CAN STILL BE UNDER-POPULATED. `battle_fixture()` builds its
## mission from BattleSimulatorSetup, which stamps none of the keys
## CampaignTurnController stamps on the way into a battle - no `initiative_context`,
## no `setup_rules` checklist, no `terrain_guide`, no `objective_details`, no
## deployment condition, and a one-line description instead of a p.85 Rival briefing.
## Measured 2026-09-07 on the tablet design space (2207x1379): with the generated
## mission PreBattleUI's Mission pane is 679 px tall and the shipped 3-column layout
## FITS; with the device mission it is 1042-1120 px and the Crew pane lands below the
## fold - which is exactly the defect the hardware reported and the sweep did not.
##
## The file is VERBATIM device output (see its own `_source` key), so it fabricates
## nothing. Absent, this returns {} and the caller falls back to the generated mission,
## measuring exactly what it measured before.
func device_pre_battle_mission() -> Dictionary:
	if not _device_mission_cache.is_empty():
		return _device_mission_cache
	var path := "res://tests/fixtures/device/prebattle_rival_attack_mission_2026-09-06.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var m = (parsed as Dictionary).get("mission", {})
	if not (m is Dictionary) or (m as Dictionary).is_empty():
		return {}
	_device_mission_cache = _restore_ints(m)
	return _device_mission_cache


## JSON hands every number back as a float; the dict a screen normally receives holds
## ints. Whole-number floats go back to int, everything else is left alone - without
## this a `%d`-formatted count renders as "4.0" and an `int()` cast silently truncates
## somewhere the screen never expected a float.
func _restore_ints(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if f == floorf(f) and absf(f) < 1e9:
			return int(f)
		return f
	if v is Dictionary:
		var out := {}
		for k in (v as Dictionary):
			out[k] = _restore_ints((v as Dictionary)[k])
		return out
	if v is Array:
		var arr := []
		for e in (v as Array):
			arr.append(_restore_ints(e))
		return arr
	return v


func _post_pre_battle(inst: Node) -> void:
	## Reproduces CampaignTurnController._launch_pre_battle_directly()
	## (CampaignTurnController.gd:1786-1820): setup_preview, then
	## setup_crew_selection with the p.63/p.85 deploy limit, then the deployment
	## condition. Same three calls, same order.
	var f: Dictionary = battle_fixture()
	var mission: Dictionary = device_pre_battle_mission()
	if mission.is_empty():
		mission = (f.get("mission", {}) as Dictionary).duplicate(true)
	else:
		mission = mission.duplicate(true)
	if inst.has_method("setup_preview") and not mission.is_empty():
		inst.setup_preview(mission)
	var crew: Array = f.get("crew", [])
	if inst.has_method("setup_crew_selection") and not crew.is_empty():
		var deploy_limit: int = crew.size()
		var gs := _root.get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("get_campaign_crew_size"):
			deploy_limit = maxi(1, int(gs.get_campaign_crew_size()))
		inst.setup_crew_selection(crew, deploy_limit)
	if inst.has_method("set_deployment_condition"):
		var cond = (mission.get("terrain", {}) as Dictionary).get(
			"deployment_condition", {})
		if cond is Dictionary and not (cond as Dictionary).is_empty():
			inst.set_deployment_condition(cond)


func _post_tactical_battle(inst: Node) -> void:
	var f: Dictionary = battle_fixture()
	var crew: Array = f.get("crew", [])
	var enemies: Array = f.get("enemies", [])
	if inst.has_method("initialize_battle") and not crew.is_empty():
		inst.initialize_battle(crew, enemies,
			(f.get("mission", {}) as Dictionary).duplicate(true))


func _pre_post_battle() -> void:
	## PostBattleSequence._load_battle_results() reads
	## GameState.get_battle_results() in _ready(), so this must land BEFORE
	## instantiate. The raw dict goes through BattleResultNormalizer — the
	## chokepoint every real battle path crosses — so the screen receives a shape
	## the app actually produces.
	var gs := _root.get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("set_battle_results"):
		return
	var f: Dictionary = battle_fixture()
	var crew: Array = f.get("crew", [])
	if crew.is_empty():
		return
	var raw: Dictionary = {
		"victory": true,
		"held_field": true,
		"crew_participants": crew.duplicate(),
		"defeated_enemies": (f.get("enemies", []) as Array).size(),
		"rounds_completed": 4,
	}
	var NormCls = load("res://src/core/battle/BattleResultNormalizer.gd")
	var results: Dictionary = raw
	if NormCls != null:
		results = NormCls.normalize(raw, f.get("mission", {}), 1)
	gs.set_battle_results(results)


func _pre_character_details() -> void:
	var crew: Array = campaign_crew()
	if crew.is_empty():
		crew = battle_fixture().get("crew", [])
	if crew.is_empty():
		return
	var gsm := _root.get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("set_temp_data"):
		return
	# The three keys CharacterDetailsScreen.load_character_data() reads
	# (CharacterDetailsScreen.gd:327-354). The swipe list is what gives the screen
	# its pager chrome, so omitting it would measure a different screen.
	gsm.set_temp_data("selected_character", crew[0])
	gsm.set_temp_data("crew_list_for_swipe", crew)
	gsm.set_temp_data("crew_index_for_swipe", 0)


func _pre_compendium_category() -> void:
	## Chosen LIVE, and the biggest category wins — a hardcoded id that stops
	## existing would populate nothing and pass, and the longest list is also the
	## hardest layout case.
	var ProvCls = load("res://src/core/compendium/CompendiumDataProvider.gd")
	if ProvCls == null:
		return
	var prov = ProvCls.new()
	if not prov.has_method("get_categories"):
		return
	var best := ""
	var best_n := -1
	for cat in prov.get_categories():
		if not (cat is Dictionary):
			continue
		var cid: String = str((cat as Dictionary).get("id", ""))
		if cid.is_empty():
			continue
		var n: int = (prov.get_items(cid) as Array).size()
		if n > best_n:
			best_n = n
			best = cid
	if not best.is_empty():
		_set_scene_context("compendium_category", {"category_id": best})


func _pre_legal_viewer() -> void:
	## Same discipline: enumerate what actually ships and take the LONGEST, which is
	## both drift-proof and the worst case for a scrolling text screen.
	var dir := DirAccess.open("res://data/legal")
	if dir == null:
		return
	var best := ""
	var best_n := -1
	for fname in dir.get_files():
		if not fname.ends_with(".md"):
			continue
		var p: String = "res://data/legal/" + fname
		var fa := FileAccess.open(p, FileAccess.READ)
		if fa == null:
			continue
		var n: int = int(fa.get_length())
		fa.close()
		if n > best_n:
			best_n = n
			best = p
	if best.is_empty():
		return
	_set_scene_context("legal_viewer", {
		"file": best,
		"title": best.get_file().get_basename().replace("_", " ").capitalize(),
	})


func _post_equipment_generation(inst: Node) -> void:
	var crew: Array = campaign_crew()
	if crew.is_empty():
		crew = battle_fixture().get("crew", [])
	if crew.is_empty():
		return
	if inst.has_method("set_crew_members"):
		inst.set_crew_members(crew)
