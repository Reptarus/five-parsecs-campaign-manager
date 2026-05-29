# Story Track Scene Assets — Layer Export Reference

**Purpose**: the per-scene PNG layer list to export (by hand, from Photoshop) for the 7 Story
Track narrative scenes. Keep this open beside Photoshop while exporting.

**Source of truth**: each `data/scenes/story_event_0N.json` stub already drafts the background
source, the planned actor layers, and the planned FX. This doc consolidates them. Companion:
[`docs/sop/narrative-scene-authoring.md`](../sop/narrative-scene-authoring.md) (full pipeline).

**Status**: `story_event_01` art is DONE (`bg_00` + `enemies_3` + `enemies_4`). Export 02-07.

---

## Global export rules (the #1 trap)

- **Every PNG = full canvas `6000 × 3375`.** Place the element in transparent space — position is
  baked into the alpha, NOT the file bounds.
- Export via **File → Export → Layers to Files** with **"Trim Layers" UNCHECKED**. (Photoshop
  "Quick Export"/"Export As" auto-trims to content → the layer stretches wrong in SceneStage.)
- Folder per scene: `assets/scenes/story_event_0N/` with subfolders **`bg/`**, **`actors/`**, **`fx/`**.
- **bg**: `bg_00.png`, `bg_01.png`… (stacked bottom-up by sorted name).
- **actors**: any names; array order = stack order; baked actors render **in front of** the crew.
- **fx**: encode the blend in the filename → `name@add.png`, `name@multiply.png`, `name@screen.png`.
- **Crew figures are NOT exported per scene** — they composite at runtime from
  `SpeciesFigureRegistry` into the manifest's `character_slots`. See the species backlog below.
- After dropping PNGs: `py scripts/scene_layers_to_manifest.py story_event_0N`, then **`--import`**
  (Godot headless) before runtime test, or SceneStage silently renders nothing.

---

## Per-scene export list

### `story_event_02` — On the Trail · *starport outskirts, aggressive mercs*
- **bg/** `bg_00.png` ← `AttackFormation_Freestyle.png` or `Field_Ambush.png`
- **actors/** (4): `qnarr_silhouette` (distant, top-of-frame, hinted) · `merc_1` (charging fg-left) · `merc_2` (covering mid-right) · `merc_3` (rear, just visible)
- **fx/** (1): `dust@multiply` (low-lying sprint dust)

### `story_event_03` — Disrupting the Plan · *factory/compound, sabotage center*
- **bg/** `bg_00.png` ← `Camp Building Up 2 Scene 5 F.png`
- **actors/** (5): `goon_cluster` (5 goons scattered mid-dist) · `bruiser_L` (shotgun, left mid) · `bruiser_R` (right mid) · `leader_center` (blast pistol, center) · `sabotage_target` (glowing device marker, center)
- **fx/** (2): `smoke_columns@multiply` (stack smoke) · `alarm_red_glow@add` (pulses if alarmed)

### `story_event_04` — The Enemy Strikes Back · *starport ship-defense, wave 2 on Round 3*
- **bg/** `bg_00.png` ← `Shipyard.png` — ⚠ `shipyard/` is **already exported** (7 bg layers); you can remap this event's `art_tag` to `shipyard` instead of re-exporting a bg.
- **actors/** (4): `crew_defending` (silhouettes behind crates) · `hired_muscle_wave1` (line at 18") · `hired_muscle_wave2` (**default_visible: false** until R3) · `ship_background` (the docked ship being defended)
- **fx/** (2): `explosion_glow@add` · `smoke_billowing@multiply`

### `story_event_05` — Kidnap · *investigation, 6 markers, hidden war bot*
- **bg/** `bg_00.png` ← `Investigating Ruin Scene 8 F copy.png` or `Hacking Ruin V2.png`
- **actors/** (5): `central_building` (mid-bg, foreboding) · `marker_glow_1` (fg-left) · `marker_glow_2` (fg-center) · `marker_glow_3` (fg-right) · `war_bot_revealed` (**default_visible: false**, reveal moment)
- **fx/** (1): `volumetric_fog@screen` (low fog around markers)

### `story_event_06` — We're Coming! · *night stealth rescue*
- **bg/** `bg_00.png` ← `Halflong-Lurking-p5.6.png` or `Dec_10_preparing_Ambush.png`
- **actors/** (5): `compound_building` (lit from within) · `sentry_L` · `sentry_R` · `captive_bound` (dim through window) · `main_force` (**default_visible: false** until alarm)
- **fx/** (2): `moonlight_rays@add` · `searchlight_cone@add` (rotates via tween — the most KoDP-feeling FX in the set)

### `story_event_07` — Time to Settle This · *dead-moon finale, the showpiece*
- **bg/** `bg_00.png` ← `Red Desert.png` or `Jan_10_Desert_explo.png` (wasteland/dead-moon)
- **actors/** (7): `compound_entrance` (the goal, mid-bg) · `qnarr_nemesis` (silhouette in window) · `surface_sentry_1`–`4` (atmosphere-suited, L→R) · `crew_in_suits` (fg hero shot)
- **fx/** (3): `dust_atmospheric@multiply` · `void_stars@screen` (airless starfield) · `compound_lights@add` (only warm light)
- *Future option (not now): split the two zones into `story_event_07_surface` + `_interior`.*

---

## Separate one-time export — species crew figures

Fill the runtime `character_slots` across **all** scenes; export each once, not per scene.
Contract (SOP §4): one figure per PNG, full body, **feet at bottom edge, horizontally centered**,
transparent bg, uniform humanoid → `assets/figures/species/<id>_NN.png` (ids are the lowercase
`SpeciesPortraitRegistry`/`SpeciesFigureRegistry` keys).

- **Have art (5 species, 9 PNGs)**: `precursor` (×1), `swift` (×2), `k_erin` (×2), `human` (×3), `soulless` (×1) — the Planetfall preset crew portraits filled `human`, `soulless`, plus `swift_02` and `k_erin_02` variants on May 28.
- **Still needed (3 primary species)**: `engineer`, `krag`, `skulker`. (Note: `feral` registry path is shipped via the Planetfall "Engineer twins" PNG (5152×3192 wide) — better used as a Tier 2 scene fragment than a single feet-anchored slot.)
- **Skip**: `hulker` — non-uniform silhouette balloons sideways under height-scaling; the PoC deliberately avoided it. The wide `HULKER 2.png` in the Planetfall source folder is also a Tier 2 scene-fragment candidate, not a figure-slot fit.
- **Out of scope (Strange Character types)**: `de_converted`, `unity_agent`, `psionic`, and similar rule-driven variants are rendered through their underlying species figure (a De-converted Human still renders as a Human). No separate figure art needed. If a future sprint adds visual overlays (cybernetic seams for De-converted, etc.) it becomes its own asset list.

### Tier 2 scene-fragment candidates (still in `C:\Users\admin\Documents\5PFH\5PFH Art\Other Books\Planetfall\PNG\Characters\`)

Three wide compositions are NOT figure-slot material but would shine as per-scene foreground elements once the SOP gains an "image slot" generalization of `character_slots` (anchor + scale + `anchor_mode`, honors real PNG aspect):
- `STALKER.png` (6000×3500) — near-canvas-size; drop-in bg/actor for a stalker/wilderness scene.
- `The Engineer twins_Feral 84-1683-04.png` (5152×3192) — two figures interacting; scene moment.
- `HULKER 2.png` (1920×1120) — small wide foreground moment.

---

## Existing art pool (reference)

Four layered scenes are already exported but not yet mapped to a trigger — usable as a pool for
Workstream A travel/crew-task beats, or as drop-in alternatives:
`meeting/` (13 bg + 5 actors + 12 props, from `Meeting.psd`), `shipyard/` (7 bg),
`firefight/` (10 bg), `2engineers/` (6 bg).
