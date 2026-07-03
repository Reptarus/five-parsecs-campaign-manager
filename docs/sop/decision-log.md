# Decision Log

Material "we picked X over Y because Z" records. Each entry has the
**decision**, the **alternatives considered**, and the **reasoning**.
Re-read before proposing to replace one of these — the answer might
already be here.

Append-only. Never silently delete an entry. If a decision is overturned,
add a new entry marking the old one **SUPERSEDED** and referencing the
new one.

---

## 2026-05: PSD layer extraction over flat composite delivery

**Decision**: Extract each PSD into per-layer PNGs categorized by
heuristic (bg / actor / fx / prop), then compose at runtime via
`SceneStage`.

**Alternatives considered**:
1. Use the delivered flat PNG of each scene as a single backdrop
2. Hand-author scene compositions in Godot scenes (one `.tscn` per
   variant)
3. Re-render scene variants in Photoshop and ship per-variant flats

**Reasoning**: ~50 PSDs at delivery; ~5-10 actor combinations per scene
is realistic. Option 1 collapses to ~50 scenes. Option 3 explodes to
~500 PNGs hand-curated, which doesn't scale to "scene reacts to which
patrons/rivals are present." Option 2 is per-variant content drift waiting
to happen. Layer extraction gives us a runtime composer that can mix any
subset of actors against the same backdrop, mirroring the Six Ages /
KoDP architecture without per-variant authoring. Storage cost (~5 GB at
50 PSDs) is acceptable; can be mitigated by VRAM compression overrides if
it becomes a problem.

**Validation**: Pilot on `Meeting.psd` produced 30 layers (1 bg, 5
actors, several props). Runtime composer renders any subset in <1 frame.
See `docs/assets/ART_INTEGRATION_LOG.md` for the pilot screenshots.

---

## 2026-05: Auto-extraction with heuristics, manual review later

**Decision**: `scripts/psd_extract.py` runs fully automatically using
bounding-box heuristics to categorize layers. Manual override is via
direct edits to `_layer_catalog.json`.

**Alternatives considered**:
1. Hand-label every layer up front (user said "no bandwidth")
2. Build an HTML contact-sheet triage tool with click-to-categorize
3. Ship a Godot in-editor tool for categorization

**Reasoning**: The user explicitly opted for "fully auto, I review later"
when surveyed. Manual labeling of ~50 PSDs * ~25 layers each = 1,250
categorization decisions is a multi-hour task that can wait until after
the pilot proves architecturally sound. The heuristics are first-pass —
the `auto_category: true` flag in the catalog marks every entry that
should be reviewed when bandwidth exists. False positives are visually
obvious in the rendered scene and trivially fixed by editing one JSON
field.

**Tradeoff accepted**: Some layers will land in the wrong subdirectory
on first pass. Recovery is fast (move file, edit JSON, no re-extraction
needed). The alternative — blocking on triage — would delay
SceneStage validation by weeks.

---

## 2026-05: `psd.composite(layer_filter=...)` over `layer.composite()`

**Decision**: Extract every layer at full canvas size (with position
baked into alpha), not at bbox size.

**Alternatives considered**:
1. `layer.composite()` returns the bbox-cropped image; record bbox in
   metadata and reconstruct position at runtime via TextureRect
   `position`/`offset`
2. Composite groups together (artist's intent), losing per-layer toggle
3. Always use the full canvas (chosen)

**Reasoning**: Same-sized PNGs mean the runtime composer is trivial —
just stack `TextureRect`s with `PRESET_FULL_RECT` anchors and the canvas
aspect with `STRETCH_KEEP_ASPECT_CENTERED`. No per-actor position math at
runtime. Storage overhead is real (a 5% actor takes the same disk space
as a full canvas) but psd-tools writes PNG, which compresses transparent
regions efficiently. The disk cost is ~2-3x larger files for ~10x
simpler runtime code. Cost we'll pay.

Context7 documentation review confirmed `psd.composite(layer_filter=...)`
is the canonical pattern for "render one layer at canvas position." The
layer-level method was a footgun.

---

## 2026-05: Verbatim book copy with `source` citation

**Decision**: Mode descriptions and other marketing copy come **verbatim**
from the Modiphius book PDFs. JSON entries include a `source` field
citing the exact page.

**Alternatives considered**:
1. Paraphrase to fit UI constraints
2. Write fresh marketing copy
3. Use book copy verbatim (chosen)

**Reasoning**: This is a Modiphius product. The book is the canonical
voice — paraphrasing creates a copy-fragmentation problem (which version
is right when they disagree?) and a partnership-trust problem (changing
copy without licensing review). Verbatim with citation makes
copy-update workflow trivial: if Modiphius edits the book, we re-extract
the same passage. The `source` field also lets a reader audit any copy
in the app back to its book origin.

**Tradeoff**: Some passages are too long for the UI. Rule: truncate
with ellipsis, preserve the source citation. Never edit the text.

---

## 2026-05: `load()` for `res://`, `Image.load()` for `user://` only

**Decision**: Branch on path prefix when loading images. Never use
`Image.load()` on a `res://` path.

**Alternatives considered**:
1. Always use `Image.load()` (the code was simpler) — broken in exports
2. Always use `load()` (requires the file to be Godot-imported) — fails
   for user-uploaded portraits
3. Branch on prefix (chosen)

**Reasoning**: `Image.load()` reads a raw PNG/JPG off disk. In exported
builds, the `.pck` only ships the imported `.ctex`, not the raw source.
The function fails silently — image loads as `null`, character card
falls back to a colored initial — and dev/editor builds never expose
the bug because the source PNG is still on disk next to the `.ctex`.

`CharacterCard._update_portrait()` shipped this bug for months. Godot
even printed the warning every time, but it was invisible in our usual
test logs. Only the visual gallery test surfaced it.

The branching pattern adds 3 lines per call site. The cost is trivial.
The bug class is "ships fine in dev, breaks every exported install" —
which is the worst possible bug class.

See also: `visual-runtime-verification.md` — the same root cause is why
visual verification is mandatory.

---

## 2026-05: MCP runtime injection over modifying production scenes for pilots

**Decision**: Visual pilots (portrait gallery, SceneStage proof, etc.)
inject test overlays at runtime via `mcp__godot__run_script`. They never
modify `MainMenu.tscn` or any committed scene.

**Alternatives considered**:
1. Add a "Test Gallery" button to MainMenu (gated by dev flag), commit
   it, remove later
2. Create a parallel `_test_` scene that piloted features (commit churn)
3. Runtime overlay via MCP, never committed (chosen)

**Reasoning**: Modifying production code during a pilot creates rollback
debt. If the pilot fails, the production code needs to be reverted —
often after other changes have already landed on top of it. Worse, "test
buttons" tend to ship if removal is the last item on the list. The MCP
injection approach has zero rollback cost: the script lives in the MCP
call only, not in git. If the pilot proves out, *then* the production
integration ships in a separate, clean commit.

The pattern is reusable: same harness for portrait gallery, SceneStage,
future battle-VFX pilots, etc.

---

## 2026-05: Browser HTML + downloadable JSON over Tkinter / Godot editor plugin / static markdown

**Decision**: The per-PSD layer review tool is a self-contained `_review.html`
generated per scene directory. Embedded base64 PNG thumbnails (composited
onto a checkerboard), inline JS state, click-to-recategorize dropdowns,
"Download updated catalog" button. Run `psd_apply_review.py` after
download to commit the changes to filesystem.

**Alternatives considered**:
1. Python + Tkinter standalone GUI (native window, direct file write) —
   focus-steals while QA is running in Godot editor, Tkinter is finicky
   on Windows
2. Godot `@tool` in-editor dock (lives inside the project, direct write)
   — competes with the Godot editor's screen real estate during QA work
3. Static markdown contact sheet only (auto-generated, read-only) —
   30 lines of Python, but no UI for bulk recategorization
4. Browser HTML + download (chosen)

**Reasoning**: The user is doing QA testing in parallel in the Godot
editor. The review tool needs to be async, low-friction, and not
compete with editor focus. A browser tab fits all three. Embedding
thumbnails as base64 data URIs makes the HTML a single file — no
local web server required (mostly; some browsers block data URIs on
`file://` and need a 1-line `py -m http.server` instead). The
"download JSON" pattern avoids needing write-capable browser APIs
or a CGI endpoint.

The two-stage workflow (download JSON → run `psd_apply_review.py`)
adds a step but keeps each tool single-purpose. The apply script is
also useful standalone for batch re-categorization (e.g. after
heuristic-threshold tuning, run apply across all scenes).

**Validation**: First-render test on Meeting.psd showed all 31
thumbnails in the Deep Space themed grid with correct
filter/category state. Misfires from the heuristic were immediately
visible (MULTIPLY/OVERLAY layers tagged BG should be FX). Screenshot
in `.mcp/screenshots/psd_review_tool_meeting.png`.

---

## 2026-05: Conservative-bias heuristics over aggressive-bias

**Decision**: PSD layer categorization heuristics intentionally err
toward false negatives (under-counting actors and fx, calling things
PROP when uncertain), with the `_review.html` tool as the safety net.

**Alternatives considered**:
1. Aggressive bias — call anything with non-NORMAL blend mode an FX
   layer; call anything portrait-shaped an actor
2. Conservative bias (chosen) — only call a layer FX if blend mode is
   non-NORMAL AND opacity < 230; only call it ACTOR if it's both tall
   AND in the 3-40% area range

**Reasoning**: Observed in the 4-PSD pilot batch (Meeting, Firefight,
Shipyard, 2Engineers):
- Conservative bias produces a few miscategorizations that are obvious
  in the review tool (a MULTIPLY shadow plate tagged as BG renders
  identically to a BG when not toggled, so the misfire is silent in
  the runtime composer)
- Aggressive bias would produce false FX classifications that affect
  blend mode and would show up as visual glitches in the runtime
  composer — harder to diagnose because the artifact only appears
  when the layer is *visible*

Asymmetry argument: a wrongly-tagged BG looks identical to a correctly-
tagged BG until you try to compose a variant that hides it. A wrongly-
tagged FX corrupts the visual immediately. The conservative bias makes
misfires *visible at review time*, not at runtime.

**Observed failure modes** (documented in `asset-pipeline.md`):
- MULTIPLY/OVERLAY/COLOR_DODGE plates at opacity 255 → tagged BG/PROP,
  should be FX. Affected: most of Meeting's lighting layers
- Wide landscape scenes with distant figures → tagged PROP or skipped,
  should be ACTOR. Affected: Shipyard (0 actors detected from 15
  layers despite visible figures)
- Layers wider than canvas → 70% width/60% height gate doesn't always
  fire cleanly when overlap is one-sided → tagged PROP, should be BG

**Tradeoff accepted**: Manual review is mandatory before any extracted
PSD ships to production. The `_review.html` tool exists for this. We
do not commit `data/scenes/<stem>.json` to git for production use
until the catalog has been reviewed.

---

## 2026-05: Single static loader over per-consumer JSON parsing

**Decision**: Each JSON data domain has one static loader (e.g.
`ModeInfoCatalog`, `DLCContentCatalog`). Consumers call the loader; they
don't `FileAccess.open` the JSON themselves.

**Alternatives considered**:
1. Each consumer parses the JSON on demand
2. A single `DataManager` autoload owns every JSON
3. Per-domain static loaders (chosen)

**Reasoning**: Option 1 means N consumers each pay parse cost and each
implement their own error handling — divergent fallback behavior is
inevitable. Option 2 centralizes too aggressively: when something breaks
you have to grep across all data domains to find the problem; also
mock/test isolation gets harder.

Per-domain loaders give you: single parse + cache per domain, single
error-handling code path, easy mocking (`SpeciesPortraitRegistry._cache
= {test_data}`), and clear file ownership.

This is the same pattern as `KeywordDB` (autoload variant) and
`SpeciesDataService` (RefCounted variant). The static RefCounted form is
preferred when no `_ready()` work is needed.

---

## 2026-05: New No-Minis auto-resolver alongside BattleResolver, not an in-place align

**Decision**: Build a distinct No-Minis auto-resolution path (a new resolver that drives the faithful `no_minis_combat.json` round structure through the existing `BattleCalculations` math), routed by the existing `combat_results["combat_mode"] == "no_minis"` flag. Leave `BattleResolver.resolve_battle()` unchanged as the generic quick-resolve used by the three standard auto-resolve callers.

**Alternatives considered**:
1. Align `BattleResolver.resolve_battle()` in place to the No-Minis structure (one auto-resolve path, fully book-faithful)
2. Keep `BattleResolver`'s abstraction + leave No-Minis as companion-text-only; document the divergence
3. New No-Minis resolver alongside (chosen)

**Reasoning**: The B0 fidelity spike (2026-05-27) found `BattleResolver.resolve_battle()` is NOT No-Minis — it is a separate attrition abstraction: real `BattleCalculations` math applied under *standard* conventions, inside an invented loop where each side's units all attack the first alive target. Separately, a faithful No-Minis *structure* already exists as `CompendiumNoMinisCombat` + `NoMinisCombatPanel`, but it only emits instruction text for the player to roll — it never resolves. The two faithful halves (structure vs automated math) live in different systems and never meet; the "play it out for me" standalone direction (B2) needs exactly that bridge.

Option 1 was rejected because No-Minis is, per the book (Compendium p.66), "a mode you choose and can mix with tabletop battles as you see fit" — not the universal resolver. Aligning in place would change behavior for all three existing `resolve_battle()` callers (`CampaignTurnController.gd:909`, `BattlePhase.gd:1513`, `TacticalBattleUI.gd:3483` auto-resolve) — the largest possible blast radius — for a path that should be opt-in. Option 2 leaves the strategic "play it out for me" pitch resolving battles with a non-canonical structure, undercutting both the standalone direction and the data-integrity spirit. Option 3 reuses both existing halves, has the smallest blast radius (`BattleResolver` untouched), matches the book's framing, hooks a routing flag that already exists, and keeps the output shape narrative-wrappable for B2.

**Scope boundary for the B1 first cut** (recorded so it is NOT a silent cut — see CLAUDE.md "No Deferring Rule"): the auto-resolver implements faithfully the parts of No-Minis that *determine outcomes* — round phases, one-die-less initiative count, the Firefight (select 3 enemies / 4 if 7+, random crew targeting, longer-range-fires-first + return fire, both-in-Cover, max range, max Shots, Take-Cover natural-6, melee/mixed Brawl via `resolve_brawl`, Area/Terrifying ignored), and end-of-round morale + retreat. The **8 Initiative Actions and the Locations/objectives layer are tactical *player decisions*** — they have no analog in an unattended auto-resolve and already exist for the player-driven path in the shipped companion engine. The auto-resolver abstracts that layer (it does not invent a tactical AI) and documents the gap. Auto-played tactical actions would be a separate future decision.

**Live-path correction (2026-05-27, found during routing verification)**: `src/core/campaign/phases/BattlePhase.gd` is DEPRECATED (Session 48c/50) and is NOT executed in the production battle flow. The live auto-resolve runs through `CampaignTurnController._on_auto_resolve_completed()` (the campaign "play it out for me" choice) and `TacticalBattleUI._on_auto_resolve_battle()` (the in-battle button). The No-Minis routing was therefore added to BOTH, gated on the `NO_MINIS_COMBAT` DLC flag: the campaign path also applies the Salvage fallback (mission type contains "salvage"); the shared TacticalBattleUI path is additionally guarded on `_battle_mode_id == ""` so Bug Hunt / Planetfall / Tactics (non-empty `battle_mode`) keep the generic resolver. BattlePhase was also routed for consistency (harmless dead code).

**Validation**: DONE (2026-05-27). `tests/unit/test_no_minis_resolver.gd` — 13/13 pass (book-rule parity on morale/melee/bail-range, BattleResolver-compatible result shape, index-stable arrays, termination, the panel's 8 actions, and a parse guard on both live routing files). Runtime MCP confirmation of the live routing pending.

---

## How to add a decision entry

Use this template:

```
## YYYY-MM: <short title — the decision itself, not the topic>

**Decision**: <one-sentence summary of what we picked>

**Alternatives considered**:
1. <option A>
2. <option B>
3. <chosen option> (chosen)

**Reasoning**: <2-4 paragraphs on why. Include any constraints,
incidents, or measurements that drove the call. Be specific —
"performance" is not a reason, "loaded 7s in dev because each consumer
re-parsed the 1.4MB JSON" is.>

**Tradeoff accepted** (optional): <what we gave up to get this>

**Validation** (optional): <how we know it worked>
```

If you find yourself wanting to delete or edit an existing entry: don't.
Add a new entry marking the old one SUPERSEDED, referencing it by date
and title. The history is the value.

## 2026-07: Battlefield = one seeded generation, persisted as full sectors, free for everyone, 4 book themes, square book tables, drawer-not-toolbar chrome

**Decision**: The battlefield is generated ONCE per battle (seeded, at
CampaignTurnController's MISSION step, AFTER the deployment-condition
roll), persisted as the full `active_battlefield` contract in
`campaign.progress_data` via the `GameState.set_battlefield_data()`
chokepoint, and consumed verbatim by PreBattleUI / TacticalBattleUI /
the recap. The theme set is the 4 Compendium tables only; the grid
models the three square book table sizes (p.108) at 1.5"/cell; and all
terrain chrome lives in the battlefield intel drawer with tap-a-sector
as the map's only interaction.

**Alternatives considered**:
1. Seed-only persistence (regenerate on load from the stored seed)
2. Keep the TERRAIN_THEMES DLC gate and the 3 synthesized themes
3. Dock a map toolbar (scatter/regenerate/legend) on the map surface
4. Full-sector persistence + free 4-theme terrain + drawer chrome (chosen)

**Reasoning**: This is a tabletop companion — the sectors describe a
physical table the player already built. Seed-only persistence breaks
the moment generator code changes between save and load (the re-derived
map silently diverges from the physical table), so the sectors
themselves are the SSOT and the seed is provenance + the base for
hash-derived per-sector re-roll seeds (the engine RNG has no avalanche
effect; Godot 4.6 docs). The DLC gate was checking a ContentFlag that
was never defined — it returned {} for everyone, so the campaign path
never generated a battlefield at all; two masking defects (the gate +
PreBattleUI's inability to parse the generator's Array sectors) hid a
completely dead preview. The 3 synthesized themes violated the
book-themes-only decision and the planet heuristics remap cleanly onto
the 4 real tables. Drawer-not-toolbar keeps the approved map-primary
redesign intact — the sprint's UX mandate was explicitly "less on
screen at once".

**Tradeoff accepted**: save files carry ~2-4KB of sector text per
in-progress battle; the preview/battle/recap can no longer diverge
(previously three independent generations — which was the bug, but it
did mean "free" variety on re-entry).

**Validation**: 50 gdUnit cases (8 suites) green, incl. a full
to_dictionary→JSON→from_dictionary round trip with byte-matched
sectors; 143-case battle regression suite green; editor-mode headless
scan zero script errors. Rules audit vs the extracted PDFs recorded in
QA_RULES_ACCURACY_AUDIT (F1-F8 fixes: industrial-only hill rule p.97,
toxic = note not terrain p.88, Beast/Defensive deployment p.110, haze
cadence p.72, labeled p.109 suggestions, Guardian = attach cluster).
