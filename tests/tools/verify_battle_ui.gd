extends SceneTree
## HEADLESS in-battle UI state verification harness (sibling of verify_post_battle.gd).
##
## Run:
##   godot --headless --path <root> --script res://tests/tools/verify_battle_ui.gd
##
## ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
## The battle-phase sprint fixed a family of defects with ONE shape: a component
## that is built and displayed but never SEEDED, so it silently reports nothing.
## Unit tests on the components pass (the components are fine); what was broken is
## the JOIN between TacticalBattleUI and them. So every assertion here reads the
## LIVE COMPONENT STATE back after driving the real UI entry points. Asserting on
## a label, a log line or a return value is forbidden — that is exactly what hid
## these defects in the first place.
##
## Harness constraints inherited from verify_post_battle.gd (do not "simplify"):
##   * All work runs in _process() on frame >= 2, never _initialize(): under
##     --script the autoloads exist but root.is_inside_tree() is false during
##     _initialize(), so every "/root/X" lookup errors.
##   * Nothing is preload()ed — bare autoload identifiers inside those scripts are
##     not registered as GDScript globals when a --script main loop compiles.

const TIER_ASSISTED := 1

var _frame := 0
var _pass := 0
var _fail := 0
var _ui: Node = null

func _ok(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, ("  -> " + detail) if detail != "" else ""])

func _crew() -> Array:
	# 5 crew. A fixture smaller than the bug proves nothing, so this is a real
	# campaign-sized squad rather than the 1-2 figures a minimal fixture would use.
	var out: Array = []
	for i in range(5):
		out.append({
			"character_id": "crew_%d" % i,
			"id": "crew_%d" % i,
			"character_name": "Crew %d" % i,
			"name": "Crew %d" % i,
			"combat": 1, "reaction": 2, "speed": 4, "toughness": 3,
			"savvy": 1, "luck": 0, "health": 3, "max_health": 3,
		})
	return out

func _enemies() -> Array:
	# Shaped EXACTLY as EnemyGenerator.generate_enemies_as_dicts() emits them:
	# the role vocabulary is `role` + `is_leader`, NOT `is_lieutenant`. A fixture
	# that modelled the contract the consumer *expected* is precisely what let the
	# lieutenant/specialist flags stay dead — so this one models the producer.
	var out: Array = []
	for i in range(6):
		var role: String = "standard"
		if i == 0:
			role = "lieutenant"
		elif i >= 5:
			role = "specialist"
		out.append({
			"id": "enemy_%d" % i,
			"type": "Gangers",
			"name": "Gangers Lieutenant" if role == "lieutenant" else "Gangers",
			"role": role,
			"is_leader": role == "lieutenant",
			"speed": 4, "combat_skill": 0, "toughness": 3,
			"reactions": 2 if role == "lieutenant" else 1,
			"panic": "1-2", "ai": "A",
			"special_rules": [],
		})
	return out

func _mission() -> Dictionary:
	# Mirrors the enemy_force block CampaignTurnController writes into mission_data.
	return {
		"title": "Harness Battle",
		"mission_source": "opportunity",
		"objective": "Fight Off",
		"enemy_force": {
			"type": "Gangers",
			"count": 6,
			"speed": 4, "combat_skill": 0, "toughness": 3,
			"ai": "A",
			"panic": "1-2",
			"special_rules": [],
			"units": _enemies(),
		},
		"deployment": {"condition_id": "NO_CONDITION"},
	}

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false

	print("\n=== verify_battle_ui ===\n")

	var packed: PackedScene = load("res://src/ui/screens/battle/TacticalBattleUI.tscn")
	if packed == null:
		print("  FAIL  could not load TacticalBattleUI.tscn")
		return _finish()
	_ui = packed.instantiate()
	root.add_child(_ui)

	# Drive the REAL entry points, in the real order.
	_ui.initialize_battle(_crew(), _enemies(), _mission())
	if _ui.has_method("_on_tier_selected"):
		_ui._on_tier_selected(TIER_ASSISTED)

	_check_morale_seeding()
	_check_enemy_role_flags()
	_check_casualty_bridge()
	_check_hud_wiring()
	_check_feed_strip()

	return _finish()

func _check_morale_seeding() -> void:
	## P0.1 — set_enemy_count / setup_from_enemy_data had ZERO callers, so the
	## End-Phase Morale check could never remove a figure (Core Rules p.114).
	var mt: Variant = _ui.get("morale_tracker")
	if mt == null or not is_instance_valid(mt):
		_ok("morale tracker instanced at ASSISTED tier", false, "morale_tracker is null")
		return
	_ok("morale tracker instanced at ASSISTED tier", true)
	_ok("enemies_remaining seeded from the real force",
		int(mt.enemies_remaining) == 6,
		"got %d, expected 6" % int(mt.enemies_remaining))
	_ok("total_enemies seeded",
		int(mt.total_enemies) == 6, "got %d" % int(mt.total_enemies))
	_ok("panic range read from the enemy entry (1-2), not the default",
		int(mt.panic_range_max) == 2, "got %d" % int(mt.panic_range_max))
	_ok("enemy type name reached the panel",
		str(mt.enemy_type_name) == "Gangers", "got '%s'" % str(mt.enemy_type_name))
	_ok("lieutenant counted as Fearless (p.114)",
		int(mt.lieutenant_count) == 1, "got %d" % int(mt.lieutenant_count))

func _check_enemy_role_flags() -> void:
	## The generator marks roles with `role`/`is_leader`; TacticalUnit carried
	## neither, so every `"is_lieutenant" in unit` guard in this file was false and
	## the post-battle defeated-enemy list recorded type "" for every kill.
	var enemies: Array = _ui.get("enemy_units")
	if enemies == null or enemies.is_empty():
		return
	_ok("enemy type carried onto the figure",
		str(enemies[0].enemy_type) == "Gangers",
		"got '%s'" % str(enemies[0].enemy_type))
	_ok("lieutenant role carried onto the figure",
		bool(enemies[0].is_lieutenant), "figure 0 should be the Lieutenant")
	_ok("specialist role carried onto the figure",
		bool(enemies[5].is_specialist), "figure 5 should be the Specialist")
	_ok("rank-and-file figures are neither",
		not bool(enemies[2].is_lieutenant) and not bool(enemies[2].is_specialist))

func _check_casualty_bridge() -> void:
	## A killed enemy must feed BOTH the per-round morale count and the survivor
	## count, exactly once.
	var mt: Variant = _ui.get("morale_tracker")
	if mt == null or not is_instance_valid(mt):
		return
	var enemies: Array = _ui.get("enemy_units")
	if enemies == null or enemies.is_empty():
		_ok("enemy units built", false, "enemy_units empty")
		return
	var before_cas: int = int(mt.casualties_this_round)
	var before_rem: int = int(mt.enemies_remaining)

	_ui._mark_casualty(enemies[1], false, true)

	_ok("killed enemy feeds casualties_this_round",
		int(mt.casualties_this_round) == before_cas + 1,
		"%d -> %d" % [before_cas, int(mt.casualties_this_round)])
	_ok("killed enemy decrements enemies_remaining once",
		int(mt.enemies_remaining) == before_rem - 1,
		"%d -> %d" % [before_rem, int(mt.enemies_remaining)])

	# Re-marking the same figure is idempotent (the chokepoint returns early).
	_ui._mark_casualty(enemies[1], false, true)
	_ok("re-marking the same figure does not double-count",
		int(mt.enemies_remaining) == before_rem - 1,
		"got %d" % int(mt.enemies_remaining))

func _check_hud_wiring() -> void:
	## P0.8 — set_display_tier() and reset_round_tracking() had zero callers, so
	## the End-Phase auto-prompt was suppressed at EVERY tier and the per-round
	## casualty count accumulated across the whole battle.
	var hud: Variant = _ui.get("battle_round_hud")
	if hud == null or not is_instance_valid(hud):
		_ok("battle round HUD instanced", false, "battle_round_hud is null")
		return
	_ok("battle round HUD instanced", true)
	_ok("HUD display tier received from _apply_tier_visibility",
		int(hud.get("_display_tier")) == TIER_ASSISTED,
		"got %d, expected %d" % [int(hud.get("_display_tier")), TIER_ASSISTED])

	# Round rollover must clear the HUD's own per-round casualty tally.
	hud.report_casualty()
	var seeded: int = int(hud.get("_casualties_this_round"))
	_ui._on_round_started(2)
	_ok("round start clears the HUD per-round casualty count",
		seeded > 0 and int(hud.get("_casualties_this_round")) == 0,
		"seeded %d, after round start %d" % [seeded, int(hud.get("_casualties_this_round"))])

func _check_feed_strip() -> void:
	## P0.5 — a second UnifiedBattleLog used to overwrite the var, orphaning the
	## instance parented in the always-visible FeedStrip.
	var log_node: Variant = _ui.get("unified_log")
	if log_node == null or not is_instance_valid(log_node):
		_ok("unified log exists", false, "unified_log is null")
		return
	var host: Node = log_node.get_parent()
	_ok("the live battle log is the one inside the visible FeedStrip",
		host != null and host.name == "FeedHost",
		"parent is '%s'" % (host.name if host else "<none>"))

func _finish() -> bool:
	if _ui and is_instance_valid(_ui):
		_ui.queue_free()
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
	return true
