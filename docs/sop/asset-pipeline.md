# Asset Pipeline SOP

Covers the journey from "Modiphius sent us a Drive folder" to "this is
ingame". Three stages: catalog, extract, integrate.

## Directory conventions

```
Assets/BookImages/            # Gitignored. Source PSDs and editor-only
                              # reference material lives here.
assets/                       # Committed. Imported by Godot.
  covers/                     # Mode-select splash art (4 PNGs)
  portraits/
    species/                  # Species fallback via SpeciesPortraitRegistry
    planetfall/               # Preset crew named portraits
    {character_id}.png        # Per-character user-uploaded portraits (rare)
  scenes/                     # PSD-extracted scene layers (one dir per PSD)
    {psd_stem}/
      bg/bg_NN.png            # Background plates, z-stacked
      actors/actor_NN.png     # Figure layers, individually toggleable
      fx/fx_NN.png            # Effects layers (blend-mode aware)
      props/prop_NN.png       # Mid-area set decoration
      _raw/                   # Gitignored. Recovery cache of every layer.
      _layer_catalog.json     # Per-layer record (committed)
  icons/                      # game-icons.net library, see icon SOP
data/
  scenes/{psd_stem}.json      # Composition manifests, consumed by SceneStage
  planetfall/preset_crew.json # Mode-specific preset data
  mode_info.json              # MainMenu mode info card data
docs/assets/
  modiphius_art_inventory.csv # Per-file manifest, auto-regenerated
  MODIPHIUS_ART_REFERENCE.md  # Grep-friendly production reference
  ART_INTEGRATION_LOG.md      # Hand-edited integration history
```

## Stage 1: Catalog a Drive delivery

When new art arrives in `C:\Users\admin\Downloads\5PFH Art\` (or equivalent):

1. Update `SOURCE_ROOT` in `scripts/catalog_modiphius_art.py` if the path
   moved.
2. Run `py scripts/catalog_modiphius_art.py`. ~30 seconds for ~700 files.
3. Outputs land in `docs/assets/`:
   - `modiphius_art_inventory.csv` (737 rows, blank `status`/`art_tag`/
     `notes` columns ready for triage)
   - `MODIPHIUS_ART_REFERENCE.md` (1400+ lines, grep target during dev)
   - `modiphius_art_inventory.md` (executive summary)

**Warning**: re-running the cataloger overwrites the CSV destructively. If
you started annotating, export the CSV first.

## Stage 2: Extract a PSD into composable layers

Prerequisite: `py -m pip install psd-tools`. Already installed in this dev env.

```
py scripts/psd_extract.py "C:\path\to\Source.psd" [optional_stem]
```

What it does (all automatic):

1. Walks `psd.descendants()`, skips groups + hidden + text layers
2. For each remaining leaf: `psd.composite(layer_filter=lambda l, t=layer: l is t)`
   produces a canvas-sized PNG with position baked into alpha
3. Categorizes via bbox heuristics:
   - **bg**: width >= 70% canvas AND height >= 60% canvas (large plate)
   - **fx**: non-NORMAL blend AND opacity < 230 (lighting/glow/overlay)
   - **actor**: portrait-shaped (h > w * 1.2) AND 3-40% of canvas area
   - **prop**: other layers >= 1% canvas area
   - **skip**: < 1% canvas area or fully transparent
4. Writes everything to `_raw/`, copies keepers to category subdirs
5. Emits `_layer_catalog.json` (per-layer record) and `data/scenes/{stem}.json`
   (composition manifest for SceneStage)

### PSD extraction rules

- **Use `psd.composite(layer_filter=...)`, never `layer.composite()`.** The
  layer-level call crops to bbox; the PSD-level call preserves canvas
  position via alpha. Same-sized PNGs mean SceneStage just stacks rects
  without per-actor positioning logic.
- **Skip text layers (`layer.kind == 'type'`).** Render text in-engine, not
  as baked PNGs — it's smaller, scales, localizes, and you can change copy
  without re-extracting.
- **Trust `is_visible()` for cascading visibility.** It already checks
  parent groups; you don't need to walk up the tree yourself.
- **Heuristics are first-pass, not final.** The `auto_category: true` flag
  in `_layer_catalog.json` marks entries that should get a manual review
  pass when bandwidth permits. Use the per-PSD `_review.html` tool (next
  section) instead of editing JSON by hand.

### Reviewing extraction output (per-PSD `_review.html` tool)

Every extraction emits `assets/scenes/<stem>/_review.html` — a
self-contained browser tool with embedded thumbnails and click-to-
recategorize controls. Open it by double-clicking the file (or via a
local http server if your browser blocks data-URI images on the `file://`
protocol).

```
psd_extract.py     →  writes _layer_catalog.json + _review.html + initial files
↓ (open _review.html in browser, change categories, click Download)
↓ (save the downloaded _layer_catalog.json over the existing one)
psd_apply_review.py →  re-shuffles PNGs between subdirs, rewrites data/scenes/<stem>.json
```

Workflow:

1. Run `py scripts/psd_extract.py <path-to.psd>` once per PSD.
2. Open `assets/scenes/<stem>/_review.html` in a browser. The Deep Space
   theme matches the in-game UI; thumbnails composite onto a checkerboard
   so transparency is visible.
3. Use the filter bar (ALL / BG / ACTOR / FX / PROP / SKIP) to scan one
   category at a time.
4. Change the dropdown on any miscategorized card. The "auto" badge flips
   to "manual" (green) and the card border turns warning-orange. The
   footer tracks unsaved changes and enables the Download button.
5. Click "Download updated catalog" → save the file as
   `_layer_catalog.json` over the existing one in
   `assets/scenes/<stem>/`.
6. Run `py scripts/psd_apply_review.py assets/scenes/<stem>/_layer_catalog.json`.
   This moves PNGs between `bg/`, `actors/`, `fx/`, `props/`, renumbers
   them, rewrites `data/scenes/<stem>.json`, and regenerates the
   `_review.html` with the new state.

The apply step is idempotent — running it twice with no JSON edits
between is a no-op. Safe to re-run any time.

### Known heuristic failure modes (where review is mandatory)

These are observed real-world misfires across the pilot PSDs. The
`_review.html` tool catches all of them at a glance:

| Symptom | Cause | Fix in review tool |
|---|---|---|
| MULTIPLY / OVERLAY / COLOR_DODGE plates at opacity 255 categorized as BG or PROP | `fx` heuristic requires `opacity < 230`; full-opacity blend modes don't trigger it | Reassign to FX |
| Wide landscape scene reports 0 actors despite visible figures | `actor` heuristic requires bbox area >= 3% canvas; distant figures fall under floor | Reassign to ACTOR |
| Layers wider than canvas (bbox extends past edges) categorized as PROP | `bg` heuristic measures width/height as % of canvas; layers with bbox > canvas may not trigger the 70%/60% gate cleanly when overlap is on one side | Reassign to BG if the layer is a backdrop element |
| Adjustment layers (`Brightness/Contrast`, `Levels`, gradient fills) extracted with 0x0 bbox | psd-tools cannot composite these without scipy installed | Already auto-categorized as SKIP; safe to ignore. If you need them, `pip install 'psd-tools[composite]'` |

The heuristics intentionally err on the side of false negatives (calling
something a PROP when it might be ACTOR/FX) rather than false positives
— a wrong category is easier to spot in the review tool than a missing
file in the production composer.

### When to re-extract vs review

| Situation | Action |
|---|---|
| Source PSD changed (Modiphius redelivery) | Re-extract — overwrites everything |
| You changed `categorize()` heuristics in `psd_extract.py` | Re-extract — fresh categories from the new logic |
| You want to manually re-tag layers | Edit via `_review.html` + run `psd_apply_review.py`. Do NOT re-extract — that would overwrite your manual edits |
| You added a new category to the extractor | Re-extract |
| `_review.html` is missing on an older PSD | Run `py scripts/psd_review_html.py <catalog>` standalone — no re-extraction needed |

### Scale considerations

One PSD (Meeting.psd) produced 30 PNGs totaling ~104 MB raw, ~104 MB
committed (87 MB bg + 4 MB actors + 13 MB props). At 50 PSDs this scales to
~5 GB of committed art. Mitigations available before the project gets there:

- Flatten redundant bg layers in the extractor (the artist often stacks
  several lighting/haze passes that could be one combined plate)
- Add `.import` VRAM compression overrides for `assets/scenes/`
- Cull layers that the visual review pass marks as redundant

## Stage 3: Integration patterns

### Drop-in portraits (no code)

Files in `assets/portraits/species/{species_id}_NN.png` are automatically
picked up by `SpeciesPortraitRegistry`. No code change required to add a new
species portrait — copy the file with the right name and it works on next
character render.

### New mode-cover

1. Drop PNG in `assets/covers/cover_{mode_id}.png`
2. Add an entry to `data/mode_info.json` with the cover path, verbatim book
   description, DLC requirement
3. If new DLC pack, add the pack ID to `DLCManager.DLC_IDS`
4. MainMenu's ModeShowcaseCard picks it up automatically

### New SceneStage composition

1. Run `psd_extract.py` on the source PSD (or hand-author the manifest if
   the source isn't a PSD)
2. Verify `data/scenes/{stem}.json` has at least one `bg_layers` entry and
   the expected actor count
3. In the consuming code: `stage.set_scene("{stem}")`, then
   `stage.show_actor(actor_id)` / `hide_actor(actor_id)` per event

### Verbatim copy rule

When marketing/description text comes from a Modiphius book:

- Pull from the PDF via `py -c "from PyPDF2 import PdfReader..."`. PyPDF2 is
  the only PDF library used (CLAUDE.md data integrity rule).
- Store the text in the JSON with a `source` field citing the page:
  `"source": "Compendium p.166 'Bug Hunt Introduction'"`
- Never paraphrase or "improve" the text. If it's too long, truncate with
  ellipsis. The book is the canonical voice.

## Updating this SOP

Add to this doc when:
- A new asset category emerges (e.g. animated sprite sheets, audio packs)
- A heuristic rule changes
- The directory layout changes
- A new tool joins the pipeline

Don't add transient stuff here (specific PSD findings, one-off bug fixes) —
those go in `docs/assets/ART_INTEGRATION_LOG.md`.
