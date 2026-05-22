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
