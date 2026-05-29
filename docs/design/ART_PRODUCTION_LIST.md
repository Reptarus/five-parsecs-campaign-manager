# Art Production Master List

**Purpose**: every art asset needed across all narrative + combat sprints, in one place, so Photoshop work has a single source of truth.

**Companion docs**:
- [`STORY_TRACK_SCENE_ASSETS.md`](./STORY_TRACK_SCENE_ASSETS.md) — detailed per-scene layer specs for Story Track events 02-07
- [`../sop/narrative-scene-authoring.md`](../sop/narrative-scene-authoring.md) — full export/import pipeline (the layer contract, ambient motion, verification)
- [`../SPRINT_ROADMAP_NARRATIVE_COMBAT.md`](../SPRINT_ROADMAP_NARRATIVE_COMBAT.md) — sprint roadmap; this doc enumerates the art each sprint needs

## Status legend

- **[SHIPPED]**: final art on disk, registered, runtime-verified
- **[PLACEHOLDER]**: rough/iteration-stage art on disk and registered; pipeline unblocked, final-quality art still wanted
- **[IN-SOURCE]**: PNG exists in your art folder; needs copy/rename + registry
- **[NEEDED]**: must be produced (nothing exists yet)
- **[DEFERRED]**: sprint not started yet; art spec to be drafted when the sprint begins
- **[OUT OF SCOPE]**: rule-driven variant rendered through another species; no separate art required

## Canonical export rules (apply to all scene PNGs)

- Canvas `6000 × 3375` (16:9), every layer at full canvas, element in transparent space
- Photoshop **Export → Layers to Files**, "Trim Layers" **UNCHECKED**
- Folder `assets/scenes/<id>/` with subfolders `bg/`, `actors/`, `fx/`
- FX blend encoded in filename: `name@add.png`, `name@multiply.png`, `name@screen.png`
- After drop: `py scripts/scene_layers_to_manifest.py <id>` → **`--import`** (mandatory)

---

## Section 1 — Story Track scene art (events 02-07)

Detailed layer intents in [STORY_TRACK_SCENE_ASSETS.md](./STORY_TRACK_SCENE_ASSETS.md). Roll-up:

| Event | Scene | bg | actors | fx | Total PNGs | Status |
|---|---|---|---|---|---|---|
| 01 | Foiled! | 1 | 2 | 0 | 3 | [SHIPPED] |
| 02 | On the Trail | 1 | 4 | 1 | 6 | [NEEDED] |
| 03 | Disrupting the Plan | 1 | 5 | 2 | 8 | [NEEDED] |
| 04 | The Enemy Strikes Back | 1 | 4 | 2 | 7 | [NEEDED] |
| 05 | Kidnap | 1 | 5 | 1 | 7 | [NEEDED] |
| 06 | We're Coming! | 1 | 5 | 2 | 8 | [NEEDED] |
| 07 | Time to Settle This | 1 | 7 | 3 | 11 | [NEEDED] |

**Subtotal: ~47 NEEDED PNGs across 6 scenes.**

---

## Section 2 — Species crew figures

Scope is the **primary playable species** from Core Rules character creation. Strange Character types (De-converted, Unity Agent, Mystic, Empath, Psionics, Bots, etc.) are NOT in this backlog — they're rule-driven variants that sit on top of an underlying species, and the figure system renders them via the underlying species's portrait. If a specific Strange Character type ever needs its own visual treatment (e.g. a cybernetic overlay), that becomes a separate sprint, not part of the primary figure roll-up.

Format: full body, **feet at bottom edge, horizontally centered**, transparent bg, uniform humanoid silhouette, ~5000px tall. Path: `assets/figures/species/<species_id>_NN.png`.

| Species | Status | File(s) |
|---|---|---|
| precursor | [SHIPPED] | `precursor_01.png` |
| swift | [SHIPPED] | `swift_01.png` + `swift_02.png` |
| k_erin | [SHIPPED] | `k_erin_01.png` + `k_erin_02.png` |
| human | [SHIPPED] | `human_01.png` + `human_02.png` + `human_03.png` (May 28) |
| soulless | [SHIPPED] | `soulless_01.png` (May 28) |
| engineer | [PLACEHOLDER] (May 29) | `engineer_01.png` — final art still wanted |
| krag | [PLACEHOLDER] (May 29) | `krag_01.png` — final art still wanted |
| skulker | [PLACEHOLDER] (May 29) | `skulker_01.png` — final art still wanted |
| psionic | [PLACEHOLDER] (May 29) | `psionic_01.png` — Strange Character, lower-priority polish |
| unity_agent | [PLACEHOLDER] (May 29) | `unity_agent_01/02/03.png` (3 variants from Photoshop layers) — Strange Character, lower-priority polish |
| feral | [IN-SOURCE] | "Engineer twins" PNG (5152×3192) is wide; better as Tier 2 scene fragment |
| hulker | SKIP | Non-uniform silhouette balloons under height-scaling per SOP §4 |
| de_converted | [OUT OF SCOPE] | Strange Character type — rendered via underlying species figure; no separate art needed |

**Subtotal: 0 NEEDED, 5 PLACEHOLDER** (3 primary species + 2 Strange Character). Pipeline unblocked May 29; final art still wanted for the 3 primary species.

---

## Section 3 — Tier 2 scene fragments (already in source folder)

Source: `C:\Users\admin\Documents\5PFH\5PFH Art\Other Books\Planetfall\PNG\Characters\`

| File | Dimensions | Use case | Status |
|---|---|---|---|
| `STALKER.png` | 6000×3500 | Near-canvas-size bg/foreground for a stalker/wilderness scene | [IN-SOURCE] awaiting Tier 2 SOP (Sprint 3) |
| `The Engineer twins_Feral 84-1683-04.png` | 5152×3192 | Two figures interacting; scene moment | [IN-SOURCE] awaiting Tier 2 SOP |
| `HULKER 2.png` | 1920×1120 | Small wide foreground moment | [IN-SOURCE] awaiting Tier 2 SOP |

**Subtotal: 3 IN-SOURCE, 0 production work — just integration once Sprint 3 lands.**

---

## Section 4 — Atmosphere particle textures (Sprint 2, A5)

**Status: [OPTIONAL]** — procedural fallback ships in [`SceneAtmosphereLayer._resolve_texture()`](../../src/ui/screens/narrative/SceneAtmosphereLayer.gd) (radial-falloff soft circle generated at runtime, cached per-effect). Each effect tints the procedural circle via its `color_ramp` on `ParticleProcessMaterial`, so the same shape works for snow, dust, fog, ember, and smoke. Hand-authored PNGs are a polish upgrade, not a functional blocker.

If you want to upgrade an effect later, drop the PNG at the path below — the path-exists check in `_resolve_texture()` picks it up automatically, no code change needed. Path: `assets/atmosphere/`.

| File | Dimensions | Visual | Used by traits | Status |
|---|---|---|---|---|
| `snow.png` | 32-48px | White circle, soft falloff | `frozen`, `arctic_storm` | [OPTIONAL] |
| `dust_mote.png` | 32-48px | White soft blob, very low contrast | default interior, `reflective_dust` | [OPTIONAL] |
| `fog_blob.png` | 48-64px | Gray-white soft blob, high alpha falloff | `haze`, `fog`, `gloom` | [OPTIONAL] |
| `ember.png` | 32-40px | Bright orange-yellow dot | event-triggered (fire scenes) | [OPTIONAL] |
| `smoke_puff.png` | 48-64px | Medium gray-brown soft blob | event-triggered (wreckage), `warzone` | [OPTIONAL — modest visible upside vs procedural] |

**Subtotal: 0 NEEDED, 5 OPTIONAL.** A5 runs at functional parity on the procedural fallback today.

---

## Section 5 — Sub-category fallback scenes (Phase 3-5 wrapping)

15 reusable scenes, one bg PNG each (full 6000×3375 canvas), for the procedural-opener categories. Each is a category-level backdrop that the gradient fallback currently substitutes for. No actor/fx layers required for the fallback (atmosphere + opener text carries it); actors/fx optional for richer beats later.

| Category | Scene ID (must match opener art_tag) | Status |
|---|---|---|
| ship_interior | `ship_interior_crew` | [SHIPPED] (May 29) |
| ship_interior | `ship_interior_bridge` | [SHIPPED] (May 29) |
| ship_interior | `ship_interior_medbay` | [NEEDED] |
| ship_interior | `ship_interior_damaged` | [SHIPPED] (May 29) |
| starport | `starport_market` | [SHIPPED] (May 29) |
| starport | `starport_bar` | [SHIPPED] (May 29) |
| starport | `starport_docks` | [SHIPPED] (May 29) |
| wilderness | `wilderness_approach` | [SHIPPED] (May 29) |
| wilderness | `alien_ruins` | [SHIPPED] (May 29) |
| wilderness | `wasteland` | [NEEDED] (candidate: `Nov_23_Sunset2_.png` in `assets/backgrounds/`) |
| wilderness | `industrial_zone` | [NEEDED] (candidate: `Nov_15_cityatnight.jpg` in `assets/backgrounds/`, needs PNG conversion) |
| battle_aftermath | `battle_aftermath_victory` | [NEEDED] |
| battle_aftermath | `battle_aftermath_retreat` | [NEEDED] (candidate: `Dec_12_escape_.jpg` in `assets/backgrounds/`, needs PNG conversion) |
| space_travel | `space_travel` | [NEEDED] (covers both transit + incident — opener variants surface the distinction in text) |

Folder pattern: `assets/scenes/<scene_id>/bg/bg_00.png` + `data/scenes/<scene_id>.json` manifest. **Scene ID MUST match an existing `art_tag` row in [`data/narrative/atmosphere_openers.json`](../../data/narrative/atmosphere_openers.json)** — those rows already exist for every scene above.

Workflow per scene: drop the PNG, run `py scripts/scene_layers_to_manifest.py <scene_id>`, then headless `--import`. PNGs don't need to be exactly 6000×3375 — SceneStage `STRETCH_KEEP_ASPECT_CENTERED`s into the rect, so off-aspect art letterboxes against the gradient fallback (still reads correctly).

**Subtotal: 6 NEEDED bg PNGs** (was 15 — 8 shipped May 29, 1 consolidation: space_transit + space_incident merged into single `space_travel`).

---

## Section 6 — PostBattle scene art (Sprint 8, A4)

[DEFERRED]. To be specified when A4 starts. Anticipated: 1 bg scene per major outcome state (victory_held_field, defeat_retreated, mixed). Optionally per-step beat scenes (loot_found, casualty, payment) but more likely consolidated.

---

## Section 7 — Mode covers + Planetfall preset crew

[SHIPPED] per project memory (mode covers in `assets/covers/`, Planetfall preset crew art delivered May).

---

## Section 8 — Optional UI iconography

Lower priority polish. Small icons, 32-48px, white-on-transparent (modulate for color per the `game-icons.net` SOP).

| Use | Icons | Status |
|---|---|---|
| B3 Dramatic Combat actions | Adjusted Shooting, Duck Back, Lunge, Dramatic Weapons badge | [NEEDED] (optional, B3 polish) |
| A1 Settings checkbox | none (theme handles it) | n/a |

**Subtotal: 4 OPTIONAL icons.**

---

## Production summary

| Bucket | Needed PNGs | Notes |
|---|---|---|
| Story Track 02-07 | ~47 | Highest priority — currently in flight |
| Species figures (primary) | 0 strictly needed | 3 placeholders shipped May 29 (engineer, krag, skulker); final art still wanted |
| Sub-category scenes | 6 | 8 shipped May 29; remaining 6: medbay, wasteland, industrial_zone, 2× battle_aftermath, space_travel |
| **Total strictly NEEDED** | **~53** | Plus PostBattle TBD, 5 species placeholders awaiting final art, 9 optional (5 atmosphere + 4 icons) |
| Atmosphere textures | 0 needed (5 optional) | Procedural fallback ships; PNGs are polish upgrades |
| Tier 2 fragments | 0 production | 3 already in source, awaiting SOP |
| PostBattle | TBD | When A4 sprint starts |

## Recommended production order (by leverage per asset)

1. **Story Track 02-07** (currently in flight) — finishes the visual Story Track
2. **Sub-category fallback scenes** (15 bg PNGs) — every Phase 3-5 narrative wrap stops looking like a gradient
3. **Tier 2 SOP code work** (Sprint 3, SHIPPED) → unlocks the 3 wide compositions already in source (just copy PNGs to `assets/scenes/tier2/`)
4. **Species figures — final-art pass** (5 placeholders awaiting upgrade: engineer, krag, skulker primary; psionic, unity_agent Strange Character). Pipeline is unblocked; this is quality iteration, not gating
5. **PostBattle art** (deferred until Sprint 8 / A4)
6. **Atmosphere textures** (5 optional polish PNGs) — only if a specific scene needs richer texture than the procedural soft-circle (e.g. real smoke billows for a finale beat). Skip otherwise
7. **Dramatic Combat icons** (optional polish for Sprint 4 / B3)
