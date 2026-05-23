# Story Event Art Assets — Spec & Folder Structure

**Created**: 2026-05-22
**Status**: Tier 1 manifest stubs shipped, awaiting PNG fill
**Owner**: ui-panel-developer (folder structure), Modiphius / future asset pass (PNG content)
**Companion docs**: [`narrative_system_design.md`](narrative_system_design.md), [`../assets/MODIPHIUS_ART_REFERENCE.md`](../assets/MODIPHIUS_ART_REFERENCE.md)

## Purpose

The 7 Story Track events are the first content surface wired to the
[`NarrativeScreen`](../../src/ui/screens/narrative/NarrativeScreen.gd)
(CanvasLayer L95, full-screen King-of-Dragon-Pass-style event window). Each
event currently renders with a gradient-fallback ColorRect because no
`SceneStage` manifest existed for the events' `art_tag` values. This document
specifies what art assets each event needs, how they slot into the existing
layer system, and what animation possibilities each scene supports.

## Architecture recap (read before extending)

### Manifest schema

Each scene lives at `data/scenes/<scene_id>.json` and is parsed by
[`SceneStage.gd`](../../src/ui/screens/narrative/SceneStage.gd). Schema (only
keys SceneStage actually reads):

```jsonc
{
  "id": "story_event_NN",
  "canvas_size": [width, height],   // ignored by SceneStage, informational
  "bg_layers": [                    // stacked back-to-front
    "res://path/to/bg.png",
    ...
  ],
  "actor_layers": [                 // toggleable via show_actor / hide_actor
    {
      "id": "actor_name",
      "path": "res://path/to/actor.png",
      "default_visible": true,
      "opacity": 255
    },
    ...
  ],
  "fx_layers": [                    // on top, with blend modes
    {
      "path": "res://path/to/fx.png",
      "default_visible": true,
      "opacity": 255,
      "blend_mode": "ADD" | "MULTIPLY" | "SCREEN" | "SUBTRACT" | "NORMAL"
    },
    ...
  ]
}
```

Unknown keys (e.g. our underscore-prefixed `_event_title`,
`_tier1_bg_source`, `_tier2_planned_actors`, `_animation_hints`) are ignored
at render time and serve as in-place documentation for the next maintainer.

### Layer semantics

| Layer | Render order | Mutability | Purpose |
|---|---|---|---|
| **bg** | Bottom, stacked | Static | Backdrops: sky → mid-ground → foreground terrain. All bg_layers always visible. |
| **actor** | Above bg | Show/hide individually (`SceneStage.show_actor(id, fade_in)`) | Foreground figures: crew, enemies, NPCs. Each can be faded in/out for scene variants. |
| **fx** | Above actors | Static visibility, animatable via tween on `modulate.a` | Atmosphere/lighting overlays. Blend modes supported by `CanvasItemMaterial`. |

### Asset folder convention

```
assets/scenes/<scene_id>/
├─ bg/         ← canvas-sized background PNGs (bg_00.png is bottom layer)
├─ actors/     ← canvas-sized actor PNGs (rest of canvas is transparent)
├─ fx/         ← canvas-sized FX overlay PNGs
└─ (props/)    ← see "Known gaps" below — currently unrendered
```

**All layer PNGs are canvas-sized**. Position is baked into transparent space,
not stored as an offset. This makes the composer dead-simple (stack same-sized
rects with shared anchors) and supports variant composition without
per-layer transform math. Trade-off: PNG file sizes are larger because each
layer carries the whole canvas including empty space — accept this for the
benefit of having show/hide actor toggles be trivially correct.

### `art_tag` → `scene_id` resolution

`NarrativeScreen._populate_illustration()` reads `art_tag` (and optionally
`scene_id`) from event data and passes the resolved id to
`SceneStage.set_scene(id)`. The 7 Story Track events have `art_tag` values
`story_event_01` through `story_event_07` (added in the May 22 Phase 1 retrofit).
A missing manifest = `push_warning` + gradient fallback (current state); a
present-but-PNG-missing manifest = silent skip + gradient fallback (Tier 1
stub state — no warning spam, ready for art fill).

## The 7 Story Track events

Each block summarizes the narrative, the recommended Tier 1 drop-in source
painting from the Modiphius delivery (`docs/assets/MODIPHIUS_ART_REFERENCE.md`),
and the Tier 2 layered composition once the scene is decomposed.

### Event 1 — *Foiled!*

> *Core Rules Appendix V pp.153-154*

Corporate-meeting ambush. Crew arrives at a rendezvous; hired guns are waiting.
Mid-range cover-to-cover firefight in an urban / industrial setting.

- **Tier 1 bg**: `Nov_16_Meeting.png` (5000×2917) — or composite of `Meeting.png` + `Ambush.png`
- **Tier 2 actors**: dead corp contact (foreground), hired gun L/R, big-gun
  flank, leader (silhouette center-back)
- **Tier 2 fx**: thin smoke drift (MULTIPLY), muzzle flash overlay (ADD, modulate-pulsed)
- **Best animation**: muzzle flash modulate pulse + atmospheric smoke particles

### Event 2 — *On the Trail*

> *Core Rules Appendix V pp.154-155*

Tracking Q'narr through hostile territory. Standard battle against Blood Storm
Mercs who initiate combat aggressively. Open terrain or starport outskirts.

- **Tier 1 bg**: `AttackFormation_Freestyle.png` (6000×3375) or `Field_Ambush.png`
- **Tier 2 actors**: Q'narr distant silhouette (top of frame, *out of reach*),
  3 Blood Storm mercs at varied depths
- **Tier 2 fx**: kicked-up dust (MULTIPLY)
- **Best animation**: actors fade in sequentially on first display (tension);
  Q'narr silhouette modulate pulse (he's *just* out of reach)

### Event 3 — *Disrupting the Plan*

> *Core Rules Appendix V pp.155-156*

Raid on Q'narr's contraband storage. Camp/factory compound with goons
scattered defensively; sabotage device at battlefield center is the win condition.

- **Tier 1 bg**: `Camp Building Up 2 Scene 5 F.png` (6000×3375)
- **Tier 2 actors**: goon cluster, 2 bruisers (L/R), leader in compound center,
  sabotage target marker
- **Tier 2 fx**: industrial smoke columns (MULTIPLY), red alarm glow (ADD, pulses when alarmed)
- **Best animation**: alarm glow conditional pulse based on scene state
  (alarmed vs unaware); industrial particulate atmosphere

### Event 4 — *The Enemy Strikes Back*

> *Core Rules Appendix V pp.156-157*

Direct attack on the crew's ship at the starport. Defensive battle amid crates,
machinery, vehicles. Second enemy wave arrives Round 3.

- **Tier 1 bg**: `Shipyard.png` (6000×3375). **Note**: `data/scenes/shipyard.json`
  already exists from prior PSD extraction — Event 4 *could* reuse this by
  setting `art_tag: "shipyard"` on `event_04_enemy_strikes_back.json` instead
  of fresh fill, saving disk space.
- **Tier 2 actors**: crew defending behind crates, wave 1 (visible default),
  wave 2 (`default_visible: false`, shown on Round 3 trigger), ship in
  background (the thing being defended)
- **Tier 2 fx**: explosion glow (ADD, modulate-pulsed), billowing smoke (MULTIPLY)
- **Best animation**: wave 2 actor fade-in on round trigger; chaotic explosion
  pulse intervals (irregular, not periodic)

### Event 5 — *Kidnap*

> *Core Rules Appendix V pp.157-158*

Investigation scene. Natural terrain with a central building. Six markers
around the field hide evidence, bodies, or concealed war bots. Mystery /
tension-building, not initial combat.

- **Tier 1 bg**: `Investigating Ruin Scene 8 F copy.png` or `Hacking Ruin V2.png` (6000×3375)
- **Tier 2 actors**: central building, 3 visible marker glows, hidden war bot
  (`default_visible: false`, faded in on reveal moment)
- **Tier 2 fx**: volumetric fog (SCREEN) — low-lying, drifts past markers
- **Best animation**: marker glow subtle breathe pulse; war bot reveal as a
  dramatic actor fade-in (this is the *bot reveal* moment — earn the polish)

### Event 6 — *We're Coming!*

> *Core Rules Appendix V pp.158-159*

Stealth rescue. Compound with central building holding the captive. Two
sentries patrol near center; main force in/near the building. Crew sneaks in
from the far edge.

- **Tier 1 bg**: `Halflong-Lurking-p5.6.png` (6000×3375, fits stealth theme) or `Dec_10_preparing_Ambush.png`
- **Tier 2 actors**: compound building (lit from within), 2 patrolling
  sentries (L/R), captive seen through window, main force (`default_visible: false` until alarm)
- **Tier 2 fx**: moonlight rays from above (ADD), searchlight cone (ADD, rotates via tween)
- **Best animation**: **searchlight cone rotation** — this is the single most
  KoDP-feeling animation in the whole set. Tween the searchlight texture's
  `rotation` or anchor offset to sweep the scene; pair with sentry breathe pulses.

### Event 7 — *Time to Settle This*

> *Core Rules Appendix V pp.159-160*

Final confrontation on a dead moon. Two zones: barren moonscape (two-thirds)
with surface sentries, then interior compound (one-third) holding Q'narr.
Crew in atmosphere suits. **The climactic scene.**

- **Tier 1 bg**: `Red Desert.png` or `Jan_10_Desert_explo.png` (6000×3375)
- **Tier 2 actors**: compound entrance (mid-bg, the goal), Q'narr silhouette
  in compound window, 4 surface sentries (atmosphere-suited), crew foreground
  (hero shot in suits)
- **Tier 2 fx**: heavy moondust drift (MULTIPLY), starfield above (SCREEN —
  airless world, no haze), compound windows glow (ADD — the only warm light)
- **Best animation**: this is THE climactic scene — allocate the most
  animation polish. Slow Ken Burns zoom toward compound entrance (building
  inevitability), compound lights breathe pulse (life inside the dead world),
  Q'narr silhouette menace pulse, heavy moondust atmosphere particles.

### Future: split Event 7 into two scenes?

Event 7 has *two distinct zones* (moonscape surface vs interior facility).
A future enhancement could split into `story_event_07_surface` and
`story_event_07_interior`, routing by mission phase. For Phase 1+2, a single
composite is fine — the surface dominates the visual frame and the interior
is a story beat handled by the narrative text.

## Animation catalog

What each layer supports and the cost/payoff of each animation type.

| Animation | Lives on | Cost | Payoff | When to use |
|---|---|---|---|---|
| **Actor fade-in/out** (KoDP signature) | actor | Already built — `SceneStage.show_actor(id, fade_in)` / `hide_actor(id, fade_out)` | High — direct narrative beat support | Reveal moments (Event 5 war bot, Event 4 wave 2), advisor cameos in future phases |
| **Atmosphere particles** (snow/dust/smoke/fog/embers) | GPUParticles2D **sibling** to SceneStage inside IllustrationFrame (see [`project_scene_stage_atmosphere_research.md`](../../../../.claude/projects/c--Users-admin-SynologyDrive-Godot-five-parsecs-campaign-manager/memory/project_scene_stage_atmosphere_research.md)) | Medium — `SceneAtmosphereLayer` design is unblocked | High — biggest "feels alive" win for the whole system | Every scene benefits; modulate density per scene type |
| **FX layer modulate tween** (pulse/flicker/breathe) | fx | Low — `Tween` on `modulate.a` | Medium — alarm lights, screen flicker, muzzle pulses | Alarms (Event 3), explosions (Event 4), compound lights (Event 7) |
| **Searchlight rotation** | fx (rotation tween) | Low | High — instantly screams "stealth scene" | Event 6 (uniquely well-suited) |
| **Ken Burns pan/zoom** | bg (SceneStage transform tween) | Low — `Tween` on position/scale | Low-medium — cinematic feel, subtle | Climactic scenes (Event 7); too distracting on combat-heavy events |
| **Parallax differential bg motion** | bg (multi-layer with differential offset) | Low (math) but requires layered bg | Low — barely noticeable on still frames | Skip until Tier 2 art has separated mid/foreground |
| **Animated FX textures** (AnimatedSprite2D) | replaces a fx layer | High — needs sprite sheets | High — fire, animated screens, water | Phase 3+ polish only; not Story Track |

## Tier 1 → Tier 2 → animation pipeline

```
Tier 1: drop one painting in       Tier 2: PSD-extracted layers       Animation polish
─────────────────────────────      ───────────────────────────         ─────────────────
bg/bg_00.png (single canvas)  →    bg/bg_00..09.png                 →  SceneAtmosphereLayer
                                   actors/actor_*.png (5-7)            FX modulate tweens
                                   fx/fx_*.png (1-3)                   Ken Burns where appropriate
                                                                       Searchlight rotation (Event 6)
```

**Generation path A — PSD extraction**: If Modiphius (or an artist) delivers a
layered PSD, `scripts/psd_extract.py` decomposes it into the four-folder
layout and writes the manifest. This is how the existing `firefight`,
`shipyard`, `meeting`, `2engineers` scenes were built. Same path for Story
Track events when layered art is available.

**Generation path B — manual composite**: Take a flat painting from the
Modiphius delivery; in Photoshop/Affinity, manually break out actor silhouettes
to separate canvas-sized layers; export each as a transparent PNG; update
the manifest's `actor_layers` and `fx_layers`. Higher art labor but works
when no PSD source exists.

**Generation path C — AI-assisted composite** (experimental): Use Modiphius
painting as base; AI-generate actor/fx variants matching the scene; manually
clean masks and export. Risk: style drift. Use only when neither path A nor
B is available.

## Tier 1 status (as of 2026-05-22)

| Event | Manifest | bg/bg_00.png | actors/ | fx/ |
|---|---|---|---|---|
| 01 Foiled! | ✓ stub | empty | empty | empty |
| 02 On the Trail | ✓ stub | empty | empty | empty |
| 03 Disrupting the Plan | ✓ stub | empty | empty | empty |
| 04 Enemy Strikes Back | ✓ stub | empty (or remap to `shipyard`) | empty | empty |
| 05 Kidnap | ✓ stub | empty | empty | empty |
| 06 We're Coming! | ✓ stub | empty | empty | empty |
| 07 Time to Settle This | ✓ stub | empty | empty | empty |

Folder skeleton in place. SceneStage will silently skip missing PNG paths
(no warning spam) and the gradient fallback stays visible — runtime
behavior identical to pre-stub. Once `bg_00.png` lands in any event's
folder, that event auto-renders the painting.

## Known gaps

- **`prop_layers` array is parsed by `psd_extract.py` and written into
  manifests (see `firefight.json`, 19 prop layers), but `SceneStage.gd`
  never iterates it.** Existing scenes silently lose all prop layers at
  render time. Story Track Tier 1 manifests do not declare `prop_layers`,
  so no regression here, but: when Tier 2 layered art lands, decide
  whether to (a) extend SceneStage with `_populate_props()`, (b) merge
  prop content into `bg_layers` at extraction time, or (c) accept the
  current loss. **Recommendation**: option (a) — three-line method
  mirroring `_populate_fx` — but flag separately, not blocking story
  art delivery.
- **No `SceneAtmosphereLayer` exists yet** (per the unblocked atmosphere
  research memory). Adding it is the next animation-system milestone.
  Story event manifests reference atmosphere in `_animation_hints` for
  when that layer arrives.
- **No way to remap `art_tag` to a different `scene_id` from the event
  JSON without code changes**. `NarrativeScreen._populate_illustration()`
  reads `event_data.get("scene_id", art_tag)` — so an event JSON could
  add a `scene_id` field separate from `art_tag` to reuse an existing
  scene (e.g. Event 4 reusing `shipyard`). Lightweight, but document
  intent if you do it.

## References

- [`narrative_system_design.md`](narrative_system_design.md) — overall narrative system architecture
- [`../assets/MODIPHIUS_ART_REFERENCE.md`](../assets/MODIPHIUS_ART_REFERENCE.md) — 737-file Modiphius delivery inventory
- [`../sop/component-patterns.md`](../sop/component-patterns.md) — path-loaded component pattern (SceneStage follows this)
- [`../../scripts/psd_extract.py`](../../scripts/psd_extract.py) — PSD → layer extraction pipeline (existing tool)
- [`../../src/ui/screens/narrative/SceneStage.gd`](../../src/ui/screens/narrative/SceneStage.gd) — the renderer
- [`../../src/ui/screens/narrative/NarrativeScreen.gd`](../../src/ui/screens/narrative/NarrativeScreen.gd) — the parent screen, `_populate_illustration()` for routing
- [`../../data/scenes/firefight.json`](../../data/scenes/firefight.json) — reference manifest from a real PSD extraction
- [`../../.claude/skills/ui-development/references/narrative-screen.md`](../../.claude/skills/ui-development/references/narrative-screen.md) — integration recipe for Phase 3+ phase panels
