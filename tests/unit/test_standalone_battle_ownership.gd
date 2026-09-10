extends GdUnitTestSuite

## T11-49 — a battle that owns no campaign must SAY SO, and be believed.
##
## ── THE DEFECT ───────────────────────────────────────────────────────────────
## `TacticalBattleUI._is_standalone_battle()` decided ownership from two ABSENCES:
## an empty `_battle_mode_id`, or a null `GameState.current_campaign`. Battle
## Simulator sets no battle_mode (it is 5PFH-flavoured), and
## `GameState._try_auto_load_last_campaign()` puts a campaign in `current_campaign`
## at EVERY launch — gating only on `last_campaign` being non-empty, never on the
## `auto_load_last_campaign` setting, which has zero readers. So once the player owned
## any save at all, BOTH signals were false and a standalone battle was treated as the
## campaign's own.
##
## Measured on deploy #28, twice, from two different entry points:
##   • the standalone fight was checkpointed into `progress_data["active_battle"]`,
##     replacing the campaign's in-progress Rival Attack (81,221 -> 67,487 bytes)
##   • pressing **Return** ERASED `active_battle` outright (81,221 -> 63,641 bytes),
##     because `_clear_battle_checkpoint()` had no ownership test at all
## Both reached disk with no explicit save: `_write_battle_checkpoint()` and
## `_clear_battle_checkpoint()` each call `save_campaign()` on the same frame.
##
## ── WHAT THIS SUITE PINS ─────────────────────────────────────────────────────
## The INVARIANT, not the constant: a mission dict that declares itself standalone
## must make the screen answer "standalone" EVEN WHEN a campaign is loaded. That last
## clause is the whole point — a test run with no campaign present passes against the
## broken code too, because the old absence test would also return true. Each case
## therefore installs a campaign first.

const BattleSimulatorSetupScript := preload(
	"res://src/core/battle/BattleSimulatorSetup.gd")
const TacticalBattleScene := preload(
	"res://src/ui/screens/battle/TacticalBattleUI.tscn")


# ═══════════════════════════════ the producer

func test_battle_simulator_declares_itself_standalone() -> void:
	## Detection-proven: drop `mission["standalone"] = true` from
	## BattleSimulatorSetup.generate_battle_context() and this fails.
	var setup = BattleSimulatorSetupScript.new()
	var context: Dictionary = setup.generate_battle_context({
		"crew_size": 4, "difficulty": 2,
		"enemy_category": "", "enemy_type": "", "mission_type": "",
	})

	assert_that(context.get("mission_data")).is_not_null()
	var mission: Dictionary = context.get("mission_data", {})
	assert_bool(mission.get("standalone", false)).override_failure_message(
		"BattleSimulatorSetup did not declare `standalone` on its mission data. "
		+ "Without it TacticalBattleUI falls back to absence tests, both of which "
		+ "are false whenever a campaign is loaded — which is always, because "
		+ "GameState auto-loads one at launch."
	).is_true()


func test_the_declaration_does_not_ride_on_battle_mode() -> void:
	## `battle_mode` routes BattleResolverRouter.resolve() and vetoes the narrative
	## wrap (CampaignTurnController._should_present_narrative_wrap treats any
	## non-empty, non-"standard" value as another gamemode). Declaring ownership
	## through THAT field would change auto-resolve behaviour as a side effect of a
	## data-safety fix, so the ownership flag must be its own key.
	var setup = BattleSimulatorSetupScript.new()
	var mission: Dictionary = setup.generate_battle_context({
		"crew_size": 4, "difficulty": 2,
	}).get("mission_data", {})

	assert_str(str(mission.get("battle_mode", ""))).override_failure_message(
		"BattleSimulatorSetup stamped a `battle_mode`. That silently re-routes the "
		+ "auto-resolver and suppresses the narrative wrap; use `standalone`."
	).is_empty()


# ═══════════════════════════════ the consumer

func _install_campaign() -> Node:
	## The discriminator. With no campaign loaded, `current_campaign == null` makes
	## the OLD code answer "standalone" correctly by accident, and every case below
	## would pass against the defect.
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return null
	if gs.get("current_campaign") == null:
		var CoreScript: GDScript = load(
			"res://src/game/campaign/FiveParsecsCampaignCore.gd")
		if CoreScript != null:
			gs.set("current_campaign", CoreScript.new())
	return gs


func test_declared_standalone_wins_even_with_a_campaign_loaded() -> void:
	var gs := _install_campaign()
	if gs == null or gs.get("current_campaign") == null:
		# Do not silently pass: a case that cannot install its own premise proves
		# nothing, and this one is ONLY meaningful with a campaign present.
		assert_bool(false).override_failure_message(
			"Could not install a campaign — this case cannot discriminate without "
			+ "one, so it is failed rather than passed vacuously."
		).is_true()
		return

	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame

	ui.initialize_battle([], [], {"standalone": true, "title": "Sim"})
	await get_tree().process_frame

	assert_bool(ui._is_standalone_battle()).override_failure_message(
		"A battle that declared `standalone` was reported as the campaign's own "
		+ "while a campaign was loaded. Every campaign write on this screen — the "
		+ "checkpoint, the checkpoint ERASE, the battlefield contract and Stars of "
		+ "the Story — keys off this answer."
	).is_true()


func test_a_campaign_battle_is_still_owned() -> void:
	## The other direction, and the reason this is an invariant rather than a
	## blanket "never write": a real campaign battle MUST still checkpoint. Without
	## this case, `return true` in _is_standalone_battle() would pass the suite and
	## silently disable crash recovery for every real fight.
	var gs := _install_campaign()
	if gs == null or gs.get("current_campaign") == null:
		assert_bool(false).override_failure_message(
			"Could not install a campaign; case cannot discriminate."
		).is_true()
		return

	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame

	ui.initialize_battle([], [], {"title": "Campaign battle"})
	await get_tree().process_frame

	assert_bool(ui._is_standalone_battle()).override_failure_message(
		"A campaign battle reported itself standalone — its checkpoint would never "
		+ "be written, losing the fight on force-stop."
	).is_false()


# ---------------------------------------------------------------------------
# the Battle Card — a SIXTH consumer of the same ownership confusion
# ---------------------------------------------------------------------------

func test_the_battle_card_does_not_announce_the_campaigns_battle() -> void:
	## MEASURED ON DEVICE (deploy #34), one screen apart: a Battle Simulator card
	## announced "Enemy: 7 x opponents", "Condition: Caught Off Guard", "Notable
	## Sight: Loot Cache" and "Battlefield: Your Table — 3x3 ft" — every one of them
	## the CAMPAIGN's turn-10 Rival Attack — while the same screen's enemy list showed
	## 5 Vent Crawlers and its map showed a fully generated table.
	##
	## _build_battle_card() called gs.get_battlefield_data(), which reads THROUGH to
	## campaign.progress_data["active_battlefield"] (the T11-17 recovery), so it
	## returned a contract for a different battle. The map was right because the
	## FALLBACK branch stores its own generated contract in _battlefield_data.
	##
	## ⭐ T11-49 found five consumers of this confusion; two of them WROTE, which is
	## why they were caught. This one only mis-displays, so nothing flagged it until a
	## card and an enemy list disagreed on screen.
	var ui: Control = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	# The campaign's contract, as get_battlefield_data() would hand it back.
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var saved_campaign: Variant = gs.current_campaign
	var campaign_contract := {
		"theme_name": "Your Table", "table_size_ft": 3.0, "enemy_count": 7,
		"enemy_ai": "T", "deployment_condition": {"name": "CAUGHT_OFF_GUARD"},
		"notable_sight": {"name": "Loot Cache"},
	}
	gs.set_battlefield_data(campaign_contract)

	# THIS battle is standalone and generated its own table.
	ui._standalone_declared = true
	ui._battlefield_data = {
		"theme_name": "Abandoned Facility", "table_size_ft": 2.0,
	}

	var card: Control = ui._build_battle_card()
	var text: String = ""
	if card != null:
		auto_free(card)
		var stack: Array[Node] = [card]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Label:
				text += str((n as Label).text) + "\n"
			for c: Node in n.get_children():
				stack.append(c)

	gs.current_campaign = saved_campaign

	assert_str(text).override_failure_message(
		"the standalone card announced the CAMPAIGN's table; rendered:\n%s" % text
		).not_contains("Your Table")
	assert_str(text).override_failure_message(
		"the standalone card announced the CAMPAIGN's deployment condition"
		).not_contains("CAUGHT_OFF_GUARD")
	assert_str(text).override_failure_message(
		"the standalone card announced the CAMPAIGN's Notable Sight"
		).not_contains("Loot Cache")
	# ...and it still says what IS true of this battle. Without this the case would
	# pass against a card that renders nothing at all.
	assert_str(text).override_failure_message(
		"the standalone card lost its OWN battlefield name; rendered:\n%s" % text
		).contains("Abandoned Facility")


# ═════════════════════ the FOURTH notion of ownership: variant cores

func test_stars_refuse_a_campaign_that_has_no_stars_field() -> void:
	## ⚠ `_setup_stars_battle_ui()`'s own docblock says Stars are "Disabled in non-5PFH
	## battle modes (Bug Hunt / Planetfall / **Tactics**)" — and the guard checks
	## `_is_bug_hunt_mode`, `_is_planetfall_mode` and `_is_standalone_battle()`. There
	## is no Tactics flag, so the comment named an exclusion the code never had.
	##
	## Bug Hunt / Planetfall / Tactics cores omit `stars_of_the_story` deliberately
	## (Compendium p.214 forbids carry-over), so reading it off one is `Invalid access
	## to property` — which ABORTS the enclosing function silently and takes the rest
	## of the setup with it. Measured in a full run on 2026-09-10: six cases of
	## test_terrain_generation_gate.gd errored with
	## `'stars_of_the_story' on a base object of type 'Resource (TacticsCampaignCore)'`
	## while passing 8/8 in isolation, because GameState auto-loads whatever campaign
	## the previous batch last saved.
	##
	## Detection proof: restore `_get_campaign_for_stars()` to returning
	## `gs.get_current_campaign()` unguarded -> this case FAILS.
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var saved_campaign = gs.current_campaign

	var TacticsCore = load("res://src/game/campaign/TacticsCampaignCore.gd")
	gs.current_campaign = TacticsCore.new()

	var ui: Node = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await await_idle_frame()

	# The accessor is the single chokepoint: all seven reads and writes of
	# `stars_of_the_story` route through it or through a value it returned.
	var got = ui._get_campaign_for_stars()
	gs.current_campaign = saved_campaign

	assert_object(got).override_failure_message(
		"A TacticsCampaignCore was handed to the Stars path. Every read of "
		+ "`stars_of_the_story` from here is an Invalid access that silently unwinds "
		+ "its caller — and the write sites would create the field on a core the book "
		+ "says must not carry Stars (Compendium p.214)."
	).is_null()


func test_stars_still_accept_a_real_5pfh_campaign() -> void:
	## THE PREMISE ARM. Without it, the case above passes against an accessor that
	## returns null for everything — which would disable Stars entirely.
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
	if gs == null:
		return
	var saved_campaign = gs.current_campaign

	var Core = load("res://src/game/campaign/FiveParsecsCampaignCore.gd")
	gs.current_campaign = Core.new()

	var ui: Node = auto_free(TacticalBattleScene.instantiate())
	add_child(ui)
	await await_idle_frame()

	var got = ui._get_campaign_for_stars()
	gs.current_campaign = saved_campaign

	assert_object(got).override_failure_message(
		"A 5PFH campaign was refused by the Stars path — the guard is too strict and "
		+ "Stars of the Story (Core Rules p.67) would never be offered in any battle."
	).is_not_null()
