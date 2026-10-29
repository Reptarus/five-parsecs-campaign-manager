extends GdUnitTestSuite

## The main menu's Co-op button (UX-3).
##
## Outside a review build the button keeps its old behaviour word for word -- and in the
## Alpha-1 menu it never reaches _on_coop_campaign_pressed() at all, because
## _apply_a1_scope() rebinds it to the coming-soon note (test_main_menu_coming_soon.gd
## holds that half). In a review build it offers the two co-op things the books contain:
## the Bug Hunt Co-op Campaign (Compendium pp.209-211), which opens the Bug Hunt wizard
## with co-op preselected, and the Expanded Co-op Battles rules (Compendium pp.39-41),
## shown from the same CheatSheetSections text the battle screen uses.
##
## The consent gate is stubbed in memory exactly as test_main_menu_coming_soon.gd does
## (never accept_eula(), which would persist a consent nobody gave). DLC entitlements are
## changed IN MEMORY ONLY and restored -- set_dlc_owned() would write a config file.
##
## gdUnit4 v6.0.3.

const MenuScene := preload("res://src/ui/screens/mainmenu/MainMenu.tscn")
const ReviewBuildRef := preload("res://src/core/systems/ReviewBuild.gd")
const CheatSheet := preload("res://src/ui/components/battle/CheatSheetSections.gd")

var _consent_backup := {}
var _dlc_backup := {}


class RouterStub extends Node:
	var calls: Array = []
	func navigate_to(scene_name: String, context: Dictionary = {}, _a: bool = true,
			_b: bool = true) -> void:
		calls.append([scene_name, context.duplicate(true)])


func before() -> void:
	var consent: Node = Engine.get_main_loop().root.get_node_or_null("/root/LegalConsentManager")
	if consent == null:
		return
	_consent_backup = {
		"eula_accepted": consent.eula_accepted,
		"eula_accepted_version": consent.eula_accepted_version,
		"privacy_accepted": consent.privacy_accepted,
		"privacy_accepted_version": consent.privacy_accepted_version,
	}
	consent.eula_accepted = true
	consent.eula_accepted_version = consent.EULA_VERSION
	consent.privacy_accepted = true
	consent.privacy_accepted_version = consent.PRIVACY_VERSION


func after() -> void:
	var consent: Node = Engine.get_main_loop().root.get_node_or_null("/root/LegalConsentManager")
	if consent == null or _consent_backup.is_empty():
		return
	for key: String in _consent_backup:
		consent.set(key, _consent_backup[key])


func before_test() -> void:
	var dlc: Node = get_tree().root.get_node_or_null("/root/DLCManager")
	if dlc:
		_dlc_backup = {"owned": (dlc._owned_dlcs as Dictionary).duplicate(true),
			"flags": (dlc._enabled_flags as Dictionary).duplicate(true)}


func after_test() -> void:
	var dlc: Node = get_tree().root.get_node_or_null("/root/DLCManager")
	if dlc and not _dlc_backup.is_empty():
		dlc._owned_dlcs = _dlc_backup["owned"]
		dlc._enabled_flags = _dlc_backup["flags"]


func _menu() -> Node:
	var m: Node = auto_free(MenuScene.instantiate())
	add_child(m)
	return m


func _newest_dialog(m: Node) -> Node:
	var dialogs: Array = m._active_dialogs
	return dialogs.back() if not dialogs.is_empty() else null


func test_without_the_review_flag_the_old_message_is_unchanged() -> void:
	# The premise: no test run is a review build, so the real handler takes this arm.
	assert_bool(ReviewBuildRef.is_active()).is_false()
	var m := _menu()
	m._on_coop_campaign_pressed()
	var dialog: Node = _newest_dialog(m)
	assert_bool(dialog is AcceptDialog).is_true()
	assert_str((dialog as AcceptDialog).dialog_text).is_equal("Co-op Campaign feature is coming soon!")
	assert_int(m.find_children("CoopChooser", "", true, false).size()).is_equal(0)


func test_the_review_build_offers_the_two_coop_choices() -> void:
	var m := _menu()
	m._route_coop_press(true)
	var dialog: Node = _newest_dialog(m)
	assert_str(str(dialog.name)).is_equal("CoopChooser")
	var campaign_btn: Button = dialog.find_child("BugHuntCoopCampaign", true, false)
	var rules_btn: Button = dialog.find_child("ExpandedCoopRules", true, false)
	assert_object(campaign_btn).is_not_null()
	assert_object(rules_btn).is_not_null()
	assert_str(campaign_btn.text).is_equal("Bug Hunt Co-op Campaign")
	assert_str(rules_btn.text).is_equal("Expanded Co-op rules (Compendium pp.39-41)")


func test_the_campaign_choice_opens_bug_hunt_creation_in_coop() -> void:
	var m := _menu()
	var stub := RouterStub.new()
	auto_free(stub)
	m._open_bug_hunt_coop_creation(stub)
	assert_array(stub.calls).is_equal([["bug_hunt_creation", {"coop": true}]])


func test_the_rules_choice_shows_the_chapter_the_battle_screen_shows() -> void:
	var dlc: Node = get_tree().root.get_node("/root/DLCManager")
	var flag: int = int(dlc.ContentFlag.COOP_BATTLES)
	var pack: String = dlc.get_dlc_for_feature(flag)
	assert_str(pack).is_not_empty()
	dlc._owned_dlcs[pack] = true
	dlc._enabled_flags[flag] = true
	var expected: String = CheatSheet.coop_battles()
	assert_str(expected).contains("Expanded Co-op Battles (Compendium pp.39-41)")
	var m := _menu()
	var host: Node = m._show_expanded_coop_rules()
	var rich: RichTextLabel = host.find_child("RulesText", true, false)
	assert_object(rich).is_not_null()
	assert_str(rich.text).is_equal(UIColors.bbcode(expected))


func test_the_rules_page_says_so_when_the_chapter_is_off() -> void:
	var dlc: Node = get_tree().root.get_node("/root/DLCManager")
	dlc._enabled_flags[int(dlc.ContentFlag.COOP_BATTLES)] = false
	assert_str(CheatSheet.coop_battles()).is_empty()
	var m := _menu()
	var host: Node = m._show_expanded_coop_rules()
	assert_object(host.find_child("RulesText", true, false)).is_null()
	var text := ""
	for n in host.find_children("*", "Label", true, false):
		text += (n as Label).text
	assert_str(text).contains("not enabled on this device")
