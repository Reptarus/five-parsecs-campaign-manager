extends GdUnitTestSuite
## Campaign finalization must read crew members in BOTH shapes.
##
## Finalization is the one place that sees crew members before they are
## canonical. A freshly created campaign hands it Character RESOURCES; its own
## transform is what converts them to the Dictionary form every later consumer
## expects. Several bonus rules were gated on `if member is Dictionary`, so on a
## NEW campaign — the only kind finalization ever runs on — they were all dead.

const FinalizationService = preload(
	"res://src/core/campaign/creation/CampaignFinalizationService.gd")
const CharacterScript = preload("res://src/core/character/Character.gd")

func _svc():
	return FinalizationService.new()

func _resource_member(motivation: String, origin: String = "") -> Resource:
	var c: Resource = CharacterScript.new()
	c.character_name = "Vex"
	if motivation != "":
		c.motivation = motivation
	if origin != "":
		c.origin = origin
	return c

# ── The accessor the bonus rules now run through ─────────────────────────

func test_member_field_reads_a_dictionary_member() -> void:
	var svc = _svc()
	assert_str(str(svc._member_field({"motivation": "WEALTH"}, "motivation", ""))).is_equal("WEALTH")

func test_member_field_reads_a_resource_member() -> void:
	# The case that was returning the default for every fresh-campaign crew.
	var svc = _svc()
	var m: Resource = _resource_member("WEALTH")
	assert_str(str(svc._member_field(m, "motivation", ""))).override_failure_message(
		"a Character Resource's motivation must be readable — this is the fresh-campaign shape"
	).is_equal("WEALTH")

func test_member_field_falls_back_when_the_key_is_absent() -> void:
	var svc = _svc()
	assert_int(int(svc._member_field({}, "experience", 7))).is_equal(7)
	assert_int(int(svc._member_field(_resource_member(""), "no_such_field", 7))).is_equal(7)

func test_member_field_never_uses_the_two_arg_get_on_a_resource() -> void:
	# A 2-arg .get() on an Object is an invalid call that aborts the CALLER.
	# If that regressed, this test would abort before its assertion and fail.
	var svc = _svc()
	var m: Resource = _resource_member("FAME")
	var got: Variant = svc._member_field(m, "definitely_not_a_property", "fallback")
	assert_str(str(got)).is_equal("fallback")

# ── The write side ───────────────────────────────────────────────────────

func test_member_set_writes_a_dictionary_member() -> void:
	var svc = _svc()
	var d: Dictionary = {"experience": 1}
	svc._member_set(d, "experience", 4)
	assert_int(int(d["experience"])).is_equal(4)

func test_member_set_writes_a_resource_member() -> void:
	var svc = _svc()
	var m: Resource = _resource_member("")
	svc._member_set(m, "experience", 4)
	assert_int(int(m.experience)).override_failure_message(
		"Prison Planet's +3 XP has to land on the Resource shape too").is_equal(4)

func test_member_set_handles_a_typed_array_property() -> void:
	# Character.equipment is Array[String]; a plain `=` from an untyped Array is
	# a runtime error in Godot 4. Prison Planet strips equipment, so this path is
	# load-bearing.
	var svc = _svc()
	var m: Resource = _resource_member("")
	m.equipment.assign(["blade", "pistol"])
	svc._member_set(m, "equipment", [])
	assert_int((m.equipment as Array).size()).override_failure_message(
		"stripping equipment must work on a typed Array[String] property").is_equal(0)
