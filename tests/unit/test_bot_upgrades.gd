extends GdUnitTestSuite
## Bot upgrades: the Core Rules p.123 stat upgrades (character sheet) and the
## Compendium p.26 New Bot Upgrades (Trading, post-battle step 11).
##
## What was broken, each pinned below:
## - the sheet read credits from the GameState autoload, which has none, so every
##   Bot read 0 and every button was disabled; and it passed that Node to a
##   Resource-typed parameter, so install_bot_upgrade() was rejected before it ran;
## - `bot_upgraded_stats` was declared nowhere, so "each ability score can be
##   upgraded only once" was never recorded or saved;
## - the p.26 upgrades were sold in the Advancement phase (before Trading), applied
##   BEFORE they were paid for, the Built-in weapon cost 0, Bot technician and
##   Salvage never applied, and the once-per-turn flag reset with the panel;
## - none of the six upgrades did anything. Three now change a number the app
##   computes: the built-in save (5+ with the casing), that save against Piercing
##   (Deflection module) and Seize the Initiative (scanner);
## - separately, no auto-resolved battle ever gave a Bot its p.46 built-in save.

const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const Adv = preload("res://src/core/character/advancement/AdvancementSystem.gd")
const Effects = preload("res://src/core/character/BotUpgradeEffects.gd")
const Salvage = preload("res://src/core/campaign/SalvageLedger.gd")
const SaveDirGuard = preload("res://tests/fixtures/helpers/save_dir_guard.gd")
const ADVANCEMENT_PANEL := "res://src/ui/screens/campaign/phases/AdvancementPhasePanel.gd"
const TRADE_PANEL := "res://src/ui/screens/campaign/phases/TradePhasePanel.tscn"
const SHEET := "res://src/ui/screens/character/CharacterDetailsScreen.gd"

var _snap: Dictionary = {}
var _prev_campaign = null
var _dlc_owned: Dictionary = {}
var _dlc_flags: Dictionary = {}


func before_test() -> void:
	_snap = SaveDirGuard.snapshot()
	_prev_campaign = _gs().current_campaign
	var dlc := _dlc()
	_dlc_owned = dlc._owned_dlcs.duplicate()
	_dlc_flags = dlc._enabled_flags.duplicate()


func after_test() -> void:
	_gs().current_campaign = _prev_campaign
	var dlc := _dlc()
	dlc._owned_dlcs = _dlc_owned
	dlc._enabled_flags = _dlc_flags
	SaveDirGuard.restore(_snap)


func _gs() -> Node:
	return get_node("/root/GameState")


func _gsm() -> Node:
	return get_node("/root/GameStateManager")


func _dlc() -> Node:
	return get_node("/root/DLCManager")


## In memory only: set_dlc_owned() would write user://dlc_ownership.cfg.
func _enable_p26_content() -> void:
	var dlc := _dlc()
	for id: Variant in dlc.DLC_IDS:
		dlc._owned_dlcs[id] = true
	dlc._enabled_flags[dlc.ContentFlag.BOT_UPGRADES] = true
	dlc._enabled_flags[dlc.ContentFlag.NEW_TRAINING] = true


func _campaign(credits: int, crew: Array = [], turns: int = 3):
	var c = CampaignCore.new()
	c.credits = credits
	c.crew_data = {"members": crew}
	c.progress_data["turns_played"] = turns
	_gs().current_campaign = c
	return c


func _bot_character() -> Character:
	var bot := Character.new()
	bot.is_bot = true
	bot.character_name = "Unit 7"
	bot.combat = 0
	return bot


func _bot(extra: Dictionary = {}) -> Dictionary:
	var m := {"character_name": "Unit 7", "is_bot": true, "species_id": "bot",
		"equipment": ["Infantry Laser"], "bot_upgrades": []}
	m.merge(extra, true)
	return m


func _option(options: Array, upgrade_id: String) -> Dictionary:
	for o: Dictionary in options:
		if o["id"] == upgrade_id:
			return o
	return {}


# --- Core Rules p.123, the character sheet -----------------------------------

func test_a_stat_upgrade_from_the_sheet_charges_the_credits_owner() -> void:
	_campaign(20)
	var adv = Adv.new()
	var bot := _bot_character()
	var cost: int = adv.get_stat_cost("combat_skill")
	# Untyped on purpose: a typed Node here makes a Resource-typed parameter a
	# PARSE error in this file, so the suite loads no cases and exits 0 instead of
	# failing. The sheet's call is checked at run time, and so is this one.
	var credits_owner: Variant = _gsm()
	assert_bool(adv.install_bot_upgrade(bot, "combat_skill", credits_owner)).is_true()
	assert_int(_gsm().get_credits()).is_equal(20 - cost)
	assert_int(bot.combat).is_equal(1)
	assert_array(bot.bot_upgraded_stats).contains(["combat_skill"])
	# "Each ability score can be upgraded only once."
	assert_bool(adv.install_bot_upgrade(bot, "combat_skill", credits_owner)).is_false()
	assert_int(_gsm().get_credits()).is_equal(20 - cost)


func test_the_once_per_score_record_survives_a_save() -> void:
	var bot := _bot_character()
	bot.bot_upgraded_stats.append("combat_skill")
	bot.builtin_weapon = "Infantry Laser"
	var copy := Character.new()
	copy.from_dictionary(bot.to_dictionary())
	assert_array(copy.bot_upgraded_stats).contains_exactly(["combat_skill"])
	assert_str(copy.builtin_weapon).is_equal("Infantry Laser")


func test_the_sheet_lists_installed_upgrades_without_aborting() -> void:
	_enable_p26_content()
	var bot := _bot_character()
	bot.bot_upgraded_stats.append("combat_skill")
	bot.bot_upgrades.append(Effects.IMPROVED_ARMOR)
	var sheet = load(SHEET).new()
	sheet.current_character = bot
	var section: Control = sheet._create_installed_upgrades_section()
	var text := ""
	for child in section.get_children():
		if child is Label:
			text += (child as Label).text + "\n"
	section.free()
	sheet.free()
	assert_str(text).contains("+1 Combat Skill (Core Rules p.123)")
	assert_str(text).contains("Improved Armor Casing")


# --- Prices ------------------------------------------------------------------

func test_bot_technician_takes_one_credit_off() -> void:
	var tech = _campaign(0, [{"character_name": "Ana", "acquired_training": ["bot_technician"]}])
	assert_int(Adv.bot_technician_price(5, tech)).is_equal(4)
	var legacy = _campaign(0, [{"character_name": "Ana", "acquired_training": ["bot_tech"]}])
	assert_int(Adv.bot_technician_price(5, legacy)).is_equal(4)
	var none = _campaign(0, [{"character_name": "Ana", "acquired_training": []}])
	assert_int(Adv.bot_technician_price(5, none)).is_equal(5)


func test_the_builtin_weapon_is_priced_from_the_weapon_profile() -> void:
	# p.26: "3 Credits per Shot on weapon profile +1 Credit per point of weapon
	# Damage." Core Rules p.50: Infantry Laser 1 shot / 0 damage, Hyper Blaster 3/1.
	assert_int(Effects.builtin_weapon_cost("Infantry Laser")).is_equal(3)
	assert_int(Effects.builtin_weapon_cost("Hyper Blaster")).is_equal(10)
	assert_int(Effects.builtin_weapon_cost("Not A Weapon")).is_equal(-1)


# --- What the upgrades do ----------------------------------------------------

func test_improved_armor_casing_gives_a_5_plus_save() -> void:
	assert_int(Effects.innate_save(_bot())).is_equal(6)
	assert_int(Effects.innate_save(_bot({"bot_upgrades": [Effects.IMPROVED_ARMOR]}))).is_equal(5)
	# "Soulless characters cannot use these upgrades."
	assert_int(Effects.innate_save({"is_soulless": true, "species_id": "soulless",
		"bot_upgrades": [Effects.IMPROVED_ARMOR]})).is_equal(6)
	assert_int(Effects.innate_save({"species_id": "human"})).is_equal(7)


func test_an_auto_resolved_bot_rolls_its_built_in_save() -> void:
	var state: Dictionary = BattleResolver.initialize_battle(
		[_bot({"equipment": []}), {"character_name": "Ana", "species_id": "human",
			"equipment": []}], [], {})
	var crew: Array = state["crew_units"]
	assert_int(int(crew[0].get("innate_save", 0))).is_equal(6)
	assert_int(int(crew[1].get("innate_save", 0))).is_equal(7)
	# p.46 Multiple Saving Throws: best save, improved by 1.
	assert_int(BattleCalculations.armor_threshold_with_innate("combat", 6)).is_equal(4)
	assert_int(BattleCalculations.armor_threshold_with_innate("none", 6)).is_equal(6)
	assert_int(BattleCalculations.armor_threshold_with_innate("combat", 7)).is_equal(5)


func test_the_deflection_module_saves_against_piercing() -> void:
	var state: Dictionary = BattleResolver.initialize_battle(
		[_bot({"equipment": [], "bot_upgrades": [Effects.DEFLECTION]})], [], {})
	assert_bool(bool(state["crew_units"][0].get("innate_is_screen", false))).is_true()


func test_the_multi_wave_scanner_adds_one_to_seize_once() -> void:
	var scanner := _bot({"bot_upgrades": [Effects.MULTI_SCANNER]})
	assert_int(Effects.seize_bonus([_bot()])).is_equal(0)
	assert_int(Effects.seize_bonus([scanner])).is_equal(1)
	assert_int(Effects.seize_bonus([scanner, scanner.duplicate(true)])).is_equal(1)
	assert_int(Effects.seize_bonus([{"is_soulless": true, "is_bot": true,
		"bot_upgrades": [Effects.MULTI_SCANNER]}])).is_equal(0)


func test_the_scanner_reaches_the_initiative_roll() -> void:
	var src := FileAccess.get_file_as_string(
		"res://src/ui/screens/campaign/CampaignTurnController.gd")
	# Anchored to a whole, uncommented statement: a bare contains() also matches
	# "# total_init_mod += ...", i.e. the call switched off.
	var live := RegEx.create_from_string(
		"(?m)^\\t+total_init_mod \\+= BotUpgradeEffectsRef\\.seize_bonus\\(active_crew\\)\\s*$")
	assert_object(live.search(src)).override_failure_message(
		"the Multi-wave scanner bonus is not added to the Seize the Initiative total").is_not_null()


# --- Compendium p.26, Trading --------------------------------------------------

func test_trading_offers_the_p26_upgrades_to_bots_only() -> void:
	_enable_p26_content()
	var c = _campaign(0)
	var options: Array = Adv.bot_upgrade_options(_bot(), c)
	assert_str(str(_option(options, Effects.BUILTIN_WEAPON).get("name", ""))) \
		.is_equal("Built-in Weapon: Infantry Laser")
	assert_int(int(_option(options, Effects.BUILTIN_WEAPON).get("cost", -1))).is_equal(3)
	assert_int(int(_option(options, Effects.IMPROVED_ARMOR).get("cost", -1))).is_equal(5)
	assert_array(Adv.bot_upgrade_options({"is_bot": true, "is_soulless": true}, c)).is_empty()
	assert_array(Adv.bot_upgrade_options({"species_id": "human"}, c)).is_empty()


func test_buying_pays_then_installs_once_per_campaign_turn() -> void:
	_enable_p26_content()
	var bot := _bot()
	var c = _campaign(20, [bot])
	var options: Array = Adv.bot_upgrade_options(bot, c)
	assert_bool(Adv.buy_bot_upgrade(bot, _option(options, Effects.IMPROVED_ARMOR),
		_gsm(), c)).is_true()
	assert_int(_gsm().get_credits()).is_equal(15)
	assert_array(bot["bot_upgrades"]).contains([Effects.IMPROVED_ARMOR])
	# "Only one upgrade can be installed per campaign turn."
	assert_bool(Adv.buy_bot_upgrade(bot, _option(options, "jump_module"),
		_gsm(), c)).is_false()
	assert_int(_gsm().get_credits()).is_equal(15)
	# The record is on the campaign, so it holds whoever asks next.
	assert_bool(Adv.bot_upgrade_installed_this_turn(c)).is_true()
	c.progress_data["turns_played"] = 4
	assert_bool(Adv.buy_bot_upgrade(bot, _option(options, "jump_module"), _gsm(), c)).is_true()
	# "A Bot character can have one of each upgrade."
	c.progress_data["turns_played"] = 5
	assert_str(Adv.bot_upgrade_blocked_reason(bot, _option(options, Effects.IMPROVED_ARMOR),
		99, c)).contains("one of each")


func test_an_unaffordable_upgrade_spends_nothing() -> void:
	_enable_p26_content()
	var bot := _bot()
	var c = _campaign(2, [bot])
	var option: Dictionary = _option(Adv.bot_upgrade_options(bot, c), Effects.IMPROVED_ARMOR)
	assert_bool(Adv.buy_bot_upgrade(bot, option, _gsm(), c)).is_false()
	assert_int(_gsm().get_credits()).is_equal(2)
	assert_array(bot["bot_upgrades"]).is_empty()


func test_salvage_pays_toward_an_upgrade() -> void:
	# Compendium p.147: "1 unit of Salvage equals 1 Credit ONLY when purchasing ...
	# Bot upgrades."
	_enable_p26_content()
	var bot := _bot()
	var c = _campaign(1, [bot])
	Salvage.add_units(c, 4)
	var option: Dictionary = _option(Adv.bot_upgrade_options(bot, c), Effects.IMPROVED_ARMOR)
	assert_str(Adv.bot_upgrade_blocked_reason(bot, option, 1, c)).is_empty()
	assert_bool(Adv.buy_bot_upgrade(bot, option, _gsm(), c)).is_true()
	assert_int(Salvage.get_units(c)).is_equal(0)
	assert_int(_gsm().get_credits()).is_equal(0)


func test_the_advancement_panel_no_longer_sells_them() -> void:
	_enable_p26_content()
	var panel = load(ADVANCEMENT_PANEL).new()
	panel.selected_crew_member = _bot()
	var offered: Array = panel._get_available_advancements()
	panel.free()
	assert_array(offered).is_empty()


func test_the_trade_panel_sells_them() -> void:
	_enable_p26_content()
	var bot := _bot()
	_campaign(20, [bot])
	var panel: Control = (load(TRADE_PANEL) as PackedScene).instantiate()
	add_child(panel)
	auto_free(panel)
	panel.setup_phase()
	assert_bool(panel.bot_upgrade_card.visible).is_true()
	var index := -1
	for i in panel._bot_options.size():
		if panel._bot_options[i]["id"] == Effects.IMPROVED_ARMOR:
			index = i
	assert_int(index).is_greater_equal(0)
	panel.bot_upgrade_list.select(index)
	panel._update_bot_upgrade_state()
	assert_bool(panel.buy_bot_upgrade_button.disabled).is_false()
	panel._on_buy_bot_upgrade_pressed()
	assert_array(bot["bot_upgrades"]).contains([Effects.IMPROVED_ARMOR])
	assert_int(_gsm().get_credits()).is_equal(15)
