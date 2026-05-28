# Narrative Scene Authoring SOP

How to author a `SceneStage` layered scene for the `NarrativeScreen`: the
layer contract, the manifest schema (background/actors/fx + roster-aware
**character slots** + **ambient motion**), the hand-export pipeline, and how to
verify a scene — including motion, which a single screenshot cannot prove.

**Read this before**: touching `SceneStage.gd`, adding/editing a
`data/scenes/<id>.json` manifest, exporting scene art layers, wiring crew
figures into a scene, or tuning ambient ("living painting") motion.

Companion docs: [asset-pipeline.md](./asset-pipeline.md) (PSD/layer extraction
mechanics), [visual-runtime-verification.md](./visual-runtime-verification.md)
(how to verify a render or motion change), and the UI skill reference
`.claude/skills/ui-development/references/narrative-screen.md` (the
NarrativeScreen overlay itself).

---

## 1. The full-canvas layer contract (the #1 trap)

`SceneStage` anchors **every** layer `FULL_RECT` with
`STRETCH_KEEP_ASPECT_CENTERED` and **ignores any per-layer position/bbox**.
So every layer PNG MUST be the **full canvas size**, with the element placed
in transparent space — position is baked into the alpha, not into the file
bounds.

**The trap**: Photoshop "Export As" / "Quick Export PNG" on a single layer
**trims to content bounds**. A trimmed actor PNG (e.g. 678×1217 instead of the
6000×3375 canvas) gets stretched to fill the stage and lands wrong. The export
looks "uncropped" to the artist because they never cropped — Photoshop trims
automatically.

**Fix**: export via **File → Export → Layers to Files** with **"Trim Layers"
UNCHECKED**. Every exported PNG then matches the canvas. The generator
(below) warns on any mismatch.

---

## 2. Authoring pipeline (hand-export → manifest → import)

`scripts/scene_layers_to_manifest.py` builds the manifest from hand-exported
layers. (`scripts/` is gitignored — it is a local dev tool, not shipped.)

```
assets/scenes/<scene_id>/
  bg/      bg_00.png, bg_01.png, ...   (stack bottom-up by sorted name)
  actors/  <name>.png                  (baked foreground figures; array order = stack order)
  fx/      <name>@<mode>.png           (overlays; optional @add/@multiply/@screen blend hint)
```

```bash
py scripts/scene_layers_to_manifest.py <scene_id> --scaffold   # make the drop folders
# (artist drops full-canvas PNGs in)
py scripts/scene_layers_to_manifest.py <scene_id>              # (re)write data/scenes/<scene_id>.json
& "$GODOT_CONSOLE" --headless --import --quit --path "<proj>"  # MANDATORY before runtime test
```

The generator **preserves** human-authored keys: any `_underscore_` metadata,
`character_slots`, and `ambient_motion` survive a regen (it merges into the
existing manifest and only rewrites canvas_size + bg/actor/fx layer lists).

> **`--import` is mandatory after new PNGs land.** `.import` sidecars don't
> exist until Godot scans; `ResourceLoader.exists()` returns false until then,
> and SceneStage's silent-fallback (`if not ResourceLoader.exists(p): skip`)
> renders **nothing, with no error**. See
> [visual-runtime-verification.md](./visual-runtime-verification.md).

---

## 3. Manifest schema (`data/scenes/<id>.json`)

```jsonc
{
  "id": "story_event_01",
  "canvas_size": [6000, 3375],
  "bg_layers":    ["res://assets/scenes/story_event_01/bg/bg_00.png"],
  "actor_layers": [ { "id": "enemies_3", "path": "...", "default_visible": true, "opacity": 255 } ],
  "fx_layers":    [ { "id": "smoke", "path": "...", "blend_mode": "MULTIPLY", "opacity": 255 } ],

  "character_slots": [          // §4 — roster-aware crew figures (optional)
    { "id": "hero",       "anchor": [0.5, 0.66], "scale": 0.46, "z": 2, "role": "" },
    { "id": "crew_left",  "anchor": [0.38, 0.58], "scale": 0.36, "z": 1, "role": "fighter" },
    { "id": "crew_right", "anchor": [0.62, 0.58], "scale": 0.36, "z": 1, "role": "medic" }
  ],

  "ambient_motion": {           // §5 — "living painting" motion (optional; absent/{} = on w/ defaults)
    "enabled": true, "overscan": 1.04, "breathe": 0.012, "breathe_period": 24.0,
    "layers": {
      "bg":   { "drift": [2, 1.5], "period": 22.0 },
      "slot": { "drift": [4, 2.0], "period": 18.0 },
      "actor":{ "drift": [7, 3.0], "period": 15.0 },
      "fx":   { "drift": [6, 3.0], "period": 17.0 }
    }
  }
}
```

- `bg` < `slot` < `actor` < `fx` is the **tree (render) order**. Baked
  foreground actors (e.g. ambush enemies) render in FRONT of the crew slots.
- `fx_layers` honor `blend_mode` (NORMAL/ADD/MULTIPLY/SCREEN/SUBTRACT),
  best-effort via `CanvasItemMaterial`. `prop_layers` are NOT rendered.

---

## 4. Character slots (roster-aware composition)

A scene declares slot **geometry**; the caller maps the player's crew into the
slots; each figure is resolved from the crew member's `species_id`. Variance
comes from the crew's **species mix**, not per-character art.

**Separation of concerns**
- `SceneStage` owns geometry + placement + figure resolution. API:
  `get_character_slots() -> Array`, `set_character_slots(assignments)`. It
  stays decoupled from campaigns (so the dev viewer can drive it too).
- The **caller** owns "who appears". `NarrativeScreen._populate_character_slots()`
  is the reference: captain → the `hero` slot (`is_captain`); other slots
  filled by `AdvisorSystem.select_advisor(slot.role, crew)` (training > class
  > species), deduped, roster-order fallback. Assignments are
  `{slot_id, species_id, character_id}`.

**Figure resolution** — `src/core/character/SpeciesFigureRegistry.gd` (mirrors
`SpeciesPortraitRegistry`): `species_id -> [paths]`, deterministic per
`character_id`, and **existence-aware** (filters the pool to files that exist
before the hash pick, so a not-yet-shipped variant never blanks a slot — this
exact bug was caught in verification).

**Depth uses TREE ORDER, never `z_index`.** A dedicated `SlotLayer` is inserted
in the node tree BETWEEN the bg layer and the actor layer, so crew always
render behind baked foreground actors. `z_index` would override tree order
across parents and let a figure jump in front of the enemies. Intra-slot
order = figures added in ascending slot `z`.

**Feet-anchored placement** — a figure's `anchor` is its FEET (bottom-center),
normalized to the stage. Height = `scale * stage_height`; width follows the
PNG aspect. "Further back" = feet higher up the frame AND smaller scale
(perspective). Recomputed on `resized`.

**Art contract**: one figure per PNG, full body, **feet at the bottom edge,
horizontally centered**, transparent bg, consistent framing.
`assets/figures/species/<species_id>_NN.png`; ids are the lowercase
`SpeciesPortraitRegistry` keys (`precursor`, `swift`, `k_erin`, ...).
**Uniform humanoid shapes only** — placement scales by HEIGHT, so a
wide/asymmetric figure (Hulker) balloons sideways and collides with neighbors
(Precursor was chosen over Hulker in the PoC for this reason).

---

## 5. Ambient motion ("living painting")

A TINY amount of scene-wide movement so a static illustration feels alive. NOT
pronounced depth parallax — subtle life. Two stacked motions per layer:

- **Drift** — a slow looping sine on the layer's `position`. Foreground layers
  drift more than the backdrop (`bg < slot < actor`) = subtle parallax depth.
- **Breathe** — a slow sine on `scale` (Ken Burns), default ±1.2% over 24s.

**Apply motion to the LAYER CONTAINERS, never to individual rects.** This is
the load-bearing decision: `_layout_character_slots()` owns each figure's
`rect.position`, so drifting a figure rect would fight the layout on every
resize. Drifting the *container* leaves child positions untouched — the
container transform composes on top. One mechanism, zero conflict.

**Overscan** (default `1.04`) is the trick that makes scene-wide drift safe:
shifting a full-frame backdrop would expose the letterbox edge, but a 4%-larger
painting is imperceptible and buys ~20–38px of drift headroom. The breathe
*floor* stays AT overscan so headroom never collapses mid-swing.

`_start_ambient_motion()` runs at the end of `set_scene()`; `clear()` kills the
tweens and resets layer transforms to identity. Pivot (`size/2`) is refreshed
on resize.

**Gated by Reduced Motion** —
`get_node_or_null("/root/ThemeManager").is_reduced_animation_enabled()`. When
on: layers stay at scale 1 / pos 0, perfectly static. Any new scene-wide motion
MUST honor this gate.

**Config is data-driven**: tune the `ambient_motion` numbers in the manifest,
no code. An absent or `{}` block = "on with defaults". `"enabled": false`
stops it for one scene. Want it subtler? Halve the `drift` values.

---

## 6. Verification (a screenshot cannot prove motion)

Three complementary checks — see
[visual-runtime-verification.md](./visual-runtime-verification.md) for the
reusable harness skeletons.

1. **Static composition** — `src/ui/screens/dev/SceneViewer.tscn` renders a
   manifest in isolation. `test_crew=<species,...>` fills slots directly (no
   campaign / AdvisorSystem). `autoshot` saves a PNG then quits. Confirms
   layers, slots, depth, and that overscan didn't crop/misalign.
   ```
   <godot> --path <proj> res://src/ui/screens/dev/SceneViewer.tscn -- scene_id=story_event_01 test_crew=precursor,swift,k_erin autoshot
   ```
2. **Motion probe** — a headless `--script` SceneTree harness instantiates
   `SceneStage`, `set_scene` + `set_character_slots`, then samples
   `_bg_layer`/`_actor_layer` `.position`/`.scale` at t0 vs t+3s. A non-zero,
   depth-differentiated delta proves motion is live; flip Reduced Motion and
   re-sample to prove the gate (scale→1, pos→0). A single screenshot can't
   show drift — this is the only honest motion proof.
3. **In-game capture** — drive the real `NarrativeScreen.present()` (lightweight
   `RefCounted` crew stubs suffice; give them `get_portrait()` to show real
   species portraits) and capture the full window for one-pagers / promo.

---

## 7. Decision matrix

| You want to… | Do this |
|---|---|
| Add a new scene | Scaffold + drop full-canvas layers + run the generator + `--import` (§2) |
| Put the player's crew in a scene | Add `character_slots` to the manifest (§4); the caller maps crew |
| Make a scene feel alive | It already does (ambient default-on); tune `ambient_motion` numbers (§5) |
| Stop motion on one scene | `"ambient_motion": {"enabled": false}` |
| New baked foreground figure | `actor_layers` (renders in front of crew slots) |
| Verify the change | §6 — static shot AND a motion probe; never claim motion from a screenshot |
