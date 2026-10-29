extends GdUnitTestSuite
## Planetfall p.76 Armory delivery.
##
## p.76: a Tier weapon lists "both the research required to develop the item and the
## Item Tier it belongs to", so it needs its research application AND its Tier building
## (Tier 1 the Advanced Manufacturing Plant, Tier 2 the High-Tech one). Until 2026-10-27
## only the building was checked, so one plant handed out every Tier 1 weapon
## unresearched. A class also uses weapons carrying its own class title, which is how
## the Mind-link pistol's "Scientist" trait reaches scientists, and the Steady Rifle
## application's bonus is "Colony bot able to use Trooper weapons".

const ArmoryScript := preload("res://src/core/systems/PlanetfallArmorySystem.gd")
const CoreScript := preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const PanelScript := preload(
	"res://src/ui/screens/planetfall/panels/PlanetfallEquipmentPanel.gd")


func _core(buildings: Array, applications: Array) -> Resource:
	var core: Resource = CoreScript.new()
	core.buildings_data = {"constructed": buildings.duplicate()}
	core.research_data = {"unlocked_applications": applications.duplicate()}
	return core


func _ids(weapons: Array) -> Array:
	var out: Array = []
	for w in weapons:
		if w is Dictionary:
			out.append(str(w.get("id", "")))
	return out


func _tier_ids(armory: RefCounted) -> Array:
	var out: Array = []
	for w in armory.get_all_weapons():
		if w is Dictionary and str(w.get("tier", "standard")) != "standard":
			out.append(str(w.get("id", "")))
	return out


func test_a_tier_weapon_needs_its_research_and_its_building() -> void:
	var armory: RefCounted = ArmoryScript.new()
	var plant := ["advanced_manufacturing_plant"]
	assert_array(_ids(armory.get_available_weapons(_core(plant, [])))) \
		.override_failure_message("the plant alone must not issue an unresearched weapon") \
		.not_contains(["shard_pistol"])
	assert_array(_ids(armory.get_available_weapons(_core([], ["shard_pistol"])))) \
		.override_failure_message("research alone must not issue a Tier 1 weapon") \
		.not_contains(["shard_pistol"])
	assert_array(_ids(armory.get_available_weapons(_core(plant, ["shard_pistol"])))) \
		.contains(["shard_pistol"])


func test_every_tier_weapon_maps_to_a_research_application() -> void:
	# A Tier weapon with no application would stay locked forever and say nothing.
	var armory: RefCounted = ArmoryScript.new()
	var tiers: Array = _tier_ids(armory)
	assert_int(tiers.size()).is_equal(10)
	var everything := _core(
		["advanced_manufacturing_plant", "high_tech_manufacturing_plant"], tiers)
	assert_array(_ids(armory.get_available_weapons(everything))).contains(tiers)
	var no_research := _core(
		["advanced_manufacturing_plant", "high_tech_manufacturing_plant"], [])
	for id in tiers:
		assert_array(_ids(armory.get_available_weapons(no_research))).not_contains([id])


func test_scientists_carry_scientist_weapons() -> void:
	var armory: RefCounted = ArmoryScript.new()
	var core := _core(["high_tech_manufacturing_plant"], ["mind_link_pistol"])
	assert_array(_ids(armory.get_weapons_for_class(core, "scientist"))) \
		.override_failure_message("p.76: a class uses its own class-title weapons") \
		.contains(["mind_link_pistol", "handgun"])
	assert_array(_ids(armory.get_weapons_for_class(core, "trooper"))) \
		.not_contains(["mind_link_pistol"])


func test_the_steady_rifle_application_arms_bots_with_trooper_weapons() -> void:
	var armory: RefCounted = ArmoryScript.new()
	var trooper_weapons := ["trooper_rifle", "assault_gun", "flame_projector"]
	var before := _ids(armory.get_weapons_for_class(_core([], []), "bot"))
	for id in trooper_weapons:
		assert_array(before).not_contains([id])
	var after := _ids(armory.get_weapons_for_class(_core([], ["steady_rifle"]), "bot"))
	assert_array(after) \
		.override_failure_message("Steady Rifle: Colony bot able to use Trooper weapons") \
		.contains(trooper_weapons)
	assert_array(after).contains(["handgun"])
	assert_array(_ids(armory.get_weapons_for_class(_core([], ["steady_rifle"]), "civvy"))) \
		.not_contains(["trooper_rifle"])


func test_a_locked_weapon_names_what_it_needs() -> void:
	var armory: RefCounted = ArmoryScript.new()
	var both: String = armory.get_lock_reason(_core([], []), "shard_pistol")
	assert_str(both).contains("Shard Pistol application (Infantry Equipment)")
	assert_str(both).contains("Advanced Manufacturing Plant")
	var building_only: String = armory.get_lock_reason(
		_core([], ["shard_pistol"]), "shard_pistol")
	assert_str(building_only).not_contains("application")
	assert_str(building_only).contains("Advanced Manufacturing Plant")
	assert_str(armory.get_lock_reason(
		_core(["advanced_manufacturing_plant"], ["shard_pistol"]), "shard_pistol")) \
		.is_equal("")
	assert_str(armory.get_lock_reason(_core([], []), "handgun")).is_equal("")


func test_the_equipment_screen_prints_the_reason() -> void:
	var panel: Control = PanelScript.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(_core(["advanced_manufacturing_plant"], []))
	panel.refresh()
	var texts: Array = []
	for node in panel.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	var found := false
	for t in texts:
		if str(t).begins_with("LOCKED: Needs the Shard Pistol application"):
			found = true
	assert_bool(found) \
		.override_failure_message("a bare LOCKED cannot say what is missing: %s" % [texts]) \
		.is_true()


## p.78 Weapon Traits: the card says what a trait does, from the Armory's own table.
func test_the_equipment_screen_says_what_a_trait_does() -> void:
	var panel: Control = PanelScript.new()
	add_child(panel)
	auto_free(panel)
	panel.set_campaign(_core([], []))
	panel.refresh()
	var texts: Array = []
	for node in panel.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	var joined: String = "\n".join(PackedStringArray(texts))
	assert_str(joined).contains("Pistol: +1 weapon bonus when brawling.") \
		.contains("Civilian: Open to all classes except grunts.")
