extends GdUnitTestSuite
## Wave 1b — pins the real APIs that the fixed has_method guards now point at.
## These guards were dead (the guarded method never existed), so the feature
## silently no-op'd. If any of these is renamed the guards die again — fail
## loudly here instead of silently in production.

const GS = preload("res://src/core/state/GameState.gd")
const EM = preload("res://src/core/equipment/EquipmentManager.gd")

func test_gamestate_save_api_exists() -> void:
	# WorldPhaseController quick-save guarded quick_save/save_game (neither exists);
	# the real API is save_campaign.
	assert_bool(auto_free(GS.new()).has_method("save_campaign")).is_true()

func test_gamestate_crew_apis_exist() -> void:
	# FactionSystem office-party + battle-crew paths depend on these.
	var gs = auto_free(GS.new())
	assert_bool(gs.has_method("get_active_crew")).is_true()

func test_equipment_manager_ship_stash_api() -> void:
	# 8 call sites (ShipStashPanel, UpkeepPhaseComponent, PurchaseItemsComponent,
	# PostBattleSequence) guard on these — they never existed until Wave 1b.
	var em = auto_free(EM.new())
	for m in ["get_ship_stash", "add_to_ship_stash", "get_ship_stash_count", "can_add_to_ship_stash"]:
		assert_bool(em.has_method(m)).is_true()

func test_ship_stash_add_and_read_roundtrip() -> void:
	var em = auto_free(EM.new())
	var before: int = em.get_ship_stash_count()
	var ok: bool = em.add_to_ship_stash({"name": "Test Blade", "type": "weapon"})
	assert_bool(ok).is_true()
	assert_int(em.get_ship_stash_count()).is_equal(before + 1)
	assert_bool(em.can_add_to_ship_stash()).is_true()

func test_notification_manager_toast_api_exists() -> void:
	# CampaignDashboard + WorldPhaseAutomationController guarded show_notification
	# (never existed); the real API is show_toast.
	var NM = load("res://src/autoload/NotificationManager.gd")
	assert_bool(auto_free(NM.new()).has_method("show_toast")).is_true()
