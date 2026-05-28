# Visual Runtime Verification SOP

**Headless compile clean is NOT sufficient. Visual runtime verification is
mandatory for anything that renders.**

This is the load-bearing lesson from the May 21 art-integration session: an
`Image.load()` call on a `res://` path passed headless compile, passed
script-level tests, passed dev-environment runtime — and would have *silently
broken in exported builds* because the `.pck` only ships imported `.ctex`, not
raw PNGs. Only the visual gallery overlay surfaced the warning at actual
texture-decode time.

## When visual verification is mandatory

Trigger a visual MCP run before declaring "done" if your change touches:

| Surface | Why |
|---|---|
| Anything loading a `Texture2D` | Export-safe `load()` vs editor-only `Image.load()` only matters at runtime |
| New UI component with `TextureRect` | Anchor/stretch/expand interactions don't show in compile |
| Animation tweens | Timing, easing, modulate states are not testable headless |
| Layout changes (anchors, size flags, responsive resize) | What looks right in code can overflow / clip at real viewport sizes |
| New autoload or initialization-order-sensitive code | `_ready()` timing races (e.g. the cover-swap import race) only surface live |
| Scene composition (SceneStage, layered overlays) | Z-order, blend modes, alpha cascades are visual-only checks |
| Looping / ambient motion (drift, breathe, Ken Burns, parallax) | A still screenshot CANNOT show motion — needs a transform-probe over time (see below) |
| Anything calling `get_portrait()`, `set_scene()`, or any renderer entry point | Cascading fallback chains need eyes-on |

When verification is *not* mandatory:

- Data-only changes (JSON edits, new entries to a loader, etc.) — script
  verification is enough
- Pure logic (math, state machines, persistence) — unit tests suffice
- Documentation changes
- Build-tool / CI changes (verify those separately on their own surface)

## The runtime injection pattern

When piloting a new visual component, **do not modify production scenes**.
Instead inject a test overlay at runtime via MCP. This was the pattern used
for both the portrait gallery and SceneStage proofs.

```
mcp__godot__launch_editor       # imports any new assets (one-time)
mcp__godot__run_project         # starts the game
mcp__godot__run_script          # injects a test panel onto the live scene
mcp__godot__take_screenshot     # capture the result
mcp__godot__stop_project        # done
```

The injection script lives only in the MCP call — never committed. Rollback
is automatic. If the pilot proves out, *then* commit the production-side
integration in a follow-up edit.

### Injection script skeleton

```gdscript
extends RefCounted

func execute(scene_tree: SceneTree) -> Variant:
    var menu = scene_tree.root.find_child("MainMenu", true, false)
    if not menu:
        return {"error": "menu missing"}
    # Hide anything that would compete for screen space
    var existing = menu.find_child("ModeShowcaseCard", true, false)
    if existing:
        existing.visible = false
    # Build the test overlay
    var overlay := PanelContainer.new()
    overlay.name = "MyTestOverlay"
    # ... anchors, theming, contents ...
    menu.add_child(overlay)
    # Populate the thing being tested
    var TargetScript = load("res://src/path/to/Component.gd")
    var instance = TargetScript.new()
    overlay.add_child(instance)
    instance.do_the_thing()
    await scene_tree.create_timer(0.5).timeout
    return {"ok": true, "details": "..."}
```

Key conventions:

- Use `find_child(name, true, false)` to locate the live root; the autoload
  `/root/...` accessors also work
- Hide competing UI so screenshots are unambiguous
- Always `await` after building so async tween/import work completes before
  the screenshot fires
- Return a result dict with non-screenshot evidence (counts, IDs resolved,
  state values) so we have both visual + structured proof

## GDScript injection gotchas

These have bitten in past sessions:

- **Variable hoisting**: `var card` declared inside two `for` loops in the
  same `execute()` function parses as a redeclaration error. Use unique
  names (`var loop_card`, `var preset_card`) or restructure.
- **Editor must be running for the bridge**: `launch_editor` first, then
  `run_project`. The MCP bridge listens on UDP 9900.
- **Script edits don't hot-reload during a running session**: if you edited
  a `.gd` file the project depends on, `stop_project` + `run_project` to
  pick up the new code.
- **The bridge times out at 30s by default**: pass `timeout: 60000` (60s)
  for scripts that build many nodes or wait for tween chains.

## Verifying motion (a screenshot CANNOT prove it)

Drift, breathe, Ken Burns, parallax — a still frame proves only that the scene
can render, never that it moves. Prove motion with a **transform probe**: a
headless `--script` SceneTree harness that instantiates the renderer, drives
it, and samples node transforms at two times. A non-zero delta proves motion
is live; re-sampling with the accessibility gate flipped proves it stops.

```gdscript
extends SceneTree
func _initialize() -> void: _run()
func _run() -> void:
    var Stage = load("res://src/ui/screens/narrative/SceneStage.gd")
    var stage = Stage.new()
    stage.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(stage)
    stage.size = Vector2(1920, 1080)
    await process_frame
    stage.set_scene("story_event_01")
    await process_frame
    var t0 = stage._actor_layer.position          # underscore vars are accessible cross-script
    await create_timer(3.0).timeout               # advances tweens (main loop iterates even headless)
    var delta = (stage._actor_layer.position - t0).length()
    print("MOTION ", ("LIVE" if delta > 0.5 else "STATIC (FAIL)"), " delta=", delta)
    # Gate check: flip Reduced Motion, re-run set_scene, assert scale==1 / pos==0.
    quit()
```

Run it `--headless` (transforms advance without a framebuffer). This is the
canonical proof for the SceneStage ambient-motion system; see
[narrative-scene-authoring.md](./narrative-scene-authoring.md) §6.

## Full-screen overlay capture harness (no editor, real framebuffer)

For a publisher/one-pager screenshot of a full-screen `CanvasLayer` overlay
(e.g. `NarrativeScreen`), the MCP injection pattern is overkill — you don't
need a live game scene. Drive the overlay's entry point directly from a
**non-headless** `--script` SceneTree run and capture the window:

```gdscript
extends SceneTree
class CrewStub extends RefCounted:          # cheaper than building real Character resources
    const SPR = preload("res://src/core/character/SpeciesPortraitRegistry.gd")
    var character_id: String; var character_name: String
    var species_id: String;  var is_captain: bool = false
    func get_portrait() -> String:          # give stubs a real portrait so the shot matches gameplay
        for p in SPR.get_portraits_for(species_id):
            if ResourceLoader.exists(p): return p
        return ""
func _initialize() -> void: _run()
func _run() -> void:
    root.size = Vector2i(1920, 1080)
    var NS = load("res://src/ui/screens/narrative/NarrativeScreen.gd")
    var screen = NS.new(); root.add_child(screen)
    await process_frame
    screen.present(event_data, {"crew": [ ... ], "world_name": "..."})
    for i in 16: await process_frame
    await create_timer(0.5).timeout
    await RenderingServer.frame_post_draw     # deterministic: capture AFTER the draw
    root.get_texture().get_image().save_png("user://shot.png")
    quit()
```

Conventions:

- **Run WITHOUT `--headless`** — you need a real framebuffer. (The motion probe
  above is the opposite: headless, because it reads transforms, not pixels.)
- A `RefCounted` stub satisfies `AdvisorSystem` (which calls `has_method()` —
  a plain `Dictionary` would error there) and the `_cs_*` duck-typed helpers.
  Use real Core Rules text for the event body; only the crew/world are stand-ins.
- Capture after `await RenderingServer.frame_post_draw` (same rule SceneViewer
  uses) so you never grab a blank pre-draw frame.

## Screenshot evidence

For any user-facing change:

- Take a "before" screenshot (or use the most recent prior one as reference)
- Take an "after" screenshot showing the change rendered correctly
- Attach both to the integration log entry
- Screenshots live in `.mcp/screenshots/` (auto-saved) and can be referenced
  in commits / PR descriptions

For multi-state changes (e.g. mode-cover hover, scene composition variants),
take a screenshot per state and arrange them side-by-side in the same MCP
script before capturing — one screenshot showing 3 states proves a swap;
three separate screenshots prove only that each state can render in
isolation.

## When a visual bug surfaces during verification

1. **Don't skip it.** "I'll fix that later" is how regressions ship.
2. Capture the screenshot of the broken state for the integration log.
3. Fix the root cause if simple (e.g. one-line `load()` swap).
4. If the fix is non-trivial, file the bug in the integration log under
   "VISUAL BUGS - open" with a screenshot reference, AND mark the broader
   task as "blocked" until fixed.
5. Re-run the visual verification after the fix. Same MCP injection script,
   same screenshot comparison. If the screenshot doesn't change, the fix
   didn't take.

## What this SOP replaces

Before this rule, "headless compile clean + unit tests passing" was treated
as sufficient. That standard let `CharacterCard._update_portrait()` ship a
silent export-build bug for months. We don't get away with that anymore.

## Updating this SOP

Add to this doc when:
- A new trigger emerges for mandatory verification (e.g. shader changes,
  particle effects, audio cues)
- A new MCP injection pattern proves useful and reusable
- A new bug class is discovered that only surfaces at render time

Don't add transient debugging tips here — those go in CLAUDE.md "Gotchas".
