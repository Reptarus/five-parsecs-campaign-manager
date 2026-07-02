extends GdUnitTestSuite

## Two-enum sync invariant (CLAUDE.md "Two Enum Systems"): every constant
## member shared by name between GlobalEnums (autoload) and GameEnums
## (class_name) MUST have the same value. 39 ordinal mismatches across 9
## enums (plus 6 PHASE_DESCRIPTIONS text drifts) were found and fixed
## 2026-07-02 — GlobalEnums is canonical for shared members; GameEnums-only
## extras carry explicit tail values. Two of those mismatches were LIVE
## bugs (TerrainRules fire-spread/extinguish never matching GlobalEnums
## terrain state; TerrainEffectType COVER/HAZARD key swap).
##
## This suite machine-checks the invariant across ALL shared Dictionary
## constants (enums and const-dict tables alike) so it cannot silently
## regress. QA Scenario 9 references this test.

## get_script_constant_map() is an instance method of Script — calling it on
## a preload CONST parses as a static class call and is rejected; go through
## Script-typed locals instead.
func _constant_map(path: String) -> Dictionary:
	var script: Script = load(path)
	return script.get_script_constant_map()


func test_shared_enum_members_have_identical_values() -> void:
	var gl: Dictionary = _constant_map("res://src/core/systems/GlobalEnums.gd")
	var ge: Dictionary = _constant_map("res://src/core/enums/GameEnums.gd")

	var mismatches: Array[String] = []
	var shared_members: int = 0

	for constant_name in gl:
		if not (gl[constant_name] is Dictionary):
			continue
		if not (ge.get(constant_name) is Dictionary):
			continue
		var gl_dict: Dictionary = gl[constant_name]
		var ge_dict: Dictionary = ge[constant_name]
		for member in gl_dict:
			if ge_dict.has(member):
				shared_members += 1
				if gl_dict[member] != ge_dict[member]:
					mismatches.append("%s.%s: GlobalEnums=%s GameEnums=%s" % [
						constant_name, str(member),
						str(gl_dict[member]), str(ge_dict[member])])

	# Sanity: the comparison must have seen real data (was ~700 shared
	# members at time of writing) — guards against a silent load failure
	# making this test vacuously green.
	assert_int(shared_members).is_greater(500)
	assert_array(mismatches).is_empty()


func test_dead_skill_and_ability_enums_stay_deleted() -> void:
	# Skill and Ability were divergent dead taxonomies deleted from BOTH
	# files 2026-07-02 — re-adding one side only would silently violate
	# the sync rule, so pin the deletion.
	var gl: Dictionary = _constant_map("res://src/core/systems/GlobalEnums.gd")
	var ge: Dictionary = _constant_map("res://src/core/enums/GameEnums.gd")
	assert_bool(gl.has("Skill")).is_false()
	assert_bool(gl.has("Ability")).is_false()
	assert_bool(ge.has("Skill")).is_false()
	assert_bool(ge.has("Ability")).is_false()
