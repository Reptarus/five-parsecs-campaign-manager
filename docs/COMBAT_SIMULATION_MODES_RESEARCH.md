# Combat Simulation Modes: Rulebook Research

**Owner**: Elijah Rhyne
**Created**: 2026-05-26
**Purpose**: Books-first research into how 5PFH itself supports simulating battle gameplay without a physical tabletop, for the standalone / "play it out for me" direction. Guardrail: adhere to actual 5PFH rules; do not invent combat systems.
**Sources**: Five Parsecs From Home Compendium PDF (236 pages), extracted via PyPDF2; `data/RulesReference/Nominis.json` (pre-extracted No-Minis ruleset). Core Rulebook defines the baseline (miniatures + measured movement) that both variants modify.

---

## Finding in one line

5PFH already defines three rules-legal combat options that serve the standalone direction, all in the Compendium "Game Options" chapter: **No-Minis Combat** (fully abstract, p.66), **Grid-Based Movement** (on-screen positional, p.90), and **Dramatic Combat** (a cinematic modifier, p.87). A true standalone *narrative* resolution system is not in the Core Rulebook or Compendium (it lives in the separate Tactics book, out of scope); in-app, "narrative" means presenting one of these real resolutions as story.

---

## 1. No-Minis Combat (Compendium p.66; full ruleset in `data/RulesReference/Nominis.json`)

Verbatim intro (Compendium, PyPDF2 page index 67): *"This system allows you to resolve a battle in Five Parsecs without the use of miniatures. It is useful if you want to progress your campaign, but can't set up a tabletop battle due to space constraints or while traveling. It can be used at any time and can be mixed with conventional tabletop battles as you see fit."*

That description is almost word-for-word our standalone direction.

- **Battlefield**: open, abstract space; no position tracking. Combatants move fluidly; objectives are abstract "Locations" a character can move to.
- **Round phases**: (1) Battle flow events (optional, Compendium p.71), (2) Initiative, (3) Firefight.
- **Initiative** uses one die less than normal; 8 action choices with dice tests (Scout for Locations, Move Up, Carry Out Task, Charge, Optimal Shot, Support, Take Cover, Keep Distance).
- **Firefight**: randomly select 3 enemies (4 if 7+), resolve ranged / melee / mixed combat with cover rules.
- **Optional rules**: Hectic Combat, Faster Combat, Battle Flow Events table.
- **Mission-specific notes** for every mission type (access, acquire, defend, deliver, eliminate, fight off, move through, patrol, protect, secure, search).
- **Caveat**: "not easily usable with the Salvage mission type (see p.116)."

**App mapping**: this is the canonical engine for "randomise / play out my battle." It is the spine of the standalone direction. **ANSWERED (B0, 2026-05-27):** `BattleResolver.resolve_battle()` does NOT implement No-Minis — it is a separate attrition abstraction (real math, non-canonical structure). A faithful No-Minis *structure* already exists as instruction-text (`CompendiumNoMinisCombat`) but does not auto-resolve. Decision: build a new No-Minis auto-resolver alongside `BattleResolver`. See "B0 Fidelity Spike Findings" below + `docs/sop/decision-log.md`.

## 2. Grid-Based Movement (Compendium, p.90-93)

Verbatim (Compendium, PyPDF2 page index 91): *"Grid-based movement allows more freeform movement by dividing the battlefield into several Grid spaces, simplifying movement and positioning in combat while maintaining the normal movement system for close-quarters fighting. It offers a faster and more free-flowing experience in the opening stages of a battle."*

It is a **hybrid**: grid abstraction for the open/approach phase, core-rules measurement for the actual fighting.

- **The Battle Space**: grid of 3 or 4 squares per side (9 / 12 / 16 sectors for 3x3, 3x4, 4x4). Squares ~8-9" across.
- **Figure Status**: each square is Open (one side present) or Close Quarters (enemies present); determined at activation, can change mid-round.
- **Multi-squares**: interiors and height levels become sub-squares with designated entry points (ladders, doors).
- **Proximity / Ranged Combat / Brawling**: handled by **core rules** (range, Line of Sight, measurement). Positioning within a square still matters for shooting.
- **Unusual Movement** (Jump, Teleport): core rules.
- **Explicit balance caveat**: "a given character, weapon or ability may be slightly stronger or weaker than when using the normal movement system." Movement system can be switched per battle.

**App mapping**: this is the model for an **on-screen tactical view without physical minis**. The app draws the 3x3/3x4/4x4 grid, figures occupy Open/Close-Quarters squares, and ranged/brawl use the existing core-rules resolution. This is the literal "gridded combat" requested. Builds on `BattlefieldMapView` + `TacticalBattleUI`.

## 3. Dramatic Combat (Compendium p.87-89): the system you were probably thinking of

This is the cinematic combat option, and it is almost certainly what "narrative combat" was pointing at. It is a real, distinct Compendium game option, turned on at campaign setup (step 10 of the updated setup sequence).

Verbatim (Compendium p.87): *"This section modifies combat to be more dramatic, particularly resulting in more movement during a firefight. It also addresses a slight imbalance between the rules for ranged and melee-only combatants."*

It is a **modifier on standard (and grid) combat**, not a separate representation mode. Key mechanics:

- **Adjusted Shooting**: target in the open 5+, in cover 6+ (replaces the standard shooting numbers).
- **Duck Back**: a figure shot at but not hit (by a firer more than 6" away, non-robot) tests to dive for better protection (open 3+, cover 4+). Bonus action; does not cost the activation.
- **Lunge**: a figure can move a full move toward a shooter to force a Brawl, ignoring up to 2" of movement reduction. Once per round, bonus action.
- **Dramatic Weapons** (p.88-89): a full retuned weapons table (pistols feel more like close-quarters weapons, melee buffed). Optional, pairs with Adjusted Shooting.

The net effect is exactly "dramatic": firefights become mobile and cinematic (figures duck, lunge, reposition) instead of static exchanges, which is the feel the standalone simulation wants.

**App mapping**: a campaign-level toggle that changes how battles resolve, layered on whichever representation mode is active (full minis, grid, or no-minis). It is the mechanical flavor that makes simulated battles feel like a story rather than a dice spreadsheet, while staying rules-legal.

**On "narrative" specifically**: a true standalone narrative-resolution system (resolve the whole fight as prose) is NOT in the Core Rulebook or Compendium; that lives in the separate Tactics book (out of scope). So in-app, "narrative" = presenting a real resolution (Dramatic Combat or No-Minis) through `NarrativeScreen` + `SceneStage`. Dramatic Combat supplies the cinematic mechanics; the narrative screen supplies the cinematic presentation.

---

## Proposed app model: a ladder of rules-faithful battle modes

All four use actual 5PFH rules; they differ only in how much the player "plays" vs. has resolved, and in fidelity:

1. **Full tabletop companion** (current): miniatures + measured movement, the existing assistant with LOG_ONLY / ASSISTED / FULL_ORACLE tiers. Highest fidelity. For players at a physical table.
2. **Grid-Based** (Compendium p.90-93): on-screen positional play without physical minis. Middle ground.
3. **No-Minis** (Compendium; Nominis.json): fully abstract, fastest hands-on resolution. The core of the standalone direction.
4. **Auto-resolve + Narrative**: No-Minis (or standard) resolved automatically and presented as story. The "I can't be bothered tonight but want to advance my campaign" mode Chris described.

Orthogonal to the representation ladder, **Dramatic Combat (p.87) is a campaign-level toggle** that can sit on top of the full-minis or grid modes, making firefights mobile and cinematic (Duck Back, Lunge, Adjusted Shooting, Dramatic Weapons). So the app really has two axes: a representation axis (full minis / grid / no-minis) and a flavor toggle (Dramatic Combat on or off), with narrative presentation wrapping any combination.

This is the honest, books-grounded answer to "simulate battle gameplay in the new direction": 5PFH hands us the abstraction (No-Minis), the positional-without-minis option (Grid), and the cinematic modifier (Dramatic Combat) directly; narrative is the wrapper.

---

## Open questions for tomorrow's design

- **Fidelity check** — **ANSWERED (B0, 2026-05-27)**: `BattleResolver.resolve_battle()` is a separate abstraction, NOT No-Minis (parity table in "B0 Fidelity Spike Findings" below). "Play it out for me" is therefore NOT yet rules-faithful; a new No-Minis auto-resolver is being built alongside (decision-log 2026-05).
- **Salvage limitation**: No-Minis "is not easily usable with the Salvage mission type (p.116)." Handle that mission type with a fallback.
- **Grid balance caveat**: the book itself flags grid mode can shift ability/weapon strength slightly. Decide whether the app notes this or compensates (do NOT silently rebalance; that would violate the canonical-rules rule).
- **Page citations (confirmed via Compendium TOC + setup sequence)**: No-Minis Combat Resolution p.66, Dramatic Combat p.87, Dramatic Weapons p.88-89, Grid-Based Movement p.90-93. No-Minis and Grid are per-mission options; Dramatic Combat is a campaign-setup toggle (setup sequence step 10).
- **Dramatic Combat integration status (VERIFIED 2026-05-26): PARTIAL SCAFFOLD, not fully integrated.**
  - *Works*: the `DRAMATIC_COMBAT` DLC flag + config-panel toggle (on/off); some Dramatic Weapons *trait* tweaks in `BattleCalculations.gd` Phase 11 (pistol +1 within 6", Heavy/Area interaction, Elegant excludes K'Erin, plus burn / shockwave / shrapnel trait effects). Caveat: not traced whether the `dramatic_combat` flag actually propagates into `attack_context` at runtime; verify.
  - *Missing or dead*: (a) `dramatic_effects` in `data/compendium/difficulty_toggles.json` is an EMPTY array, so `get_dramatic_effect()` always returns "" and the BattlePhase to TacticalBattleUI "DRAMATIC COMBAT" display never renders (dead feature); (b) **Adjusted Shooting** (open 5+, cover 6+) has NO code, only a prose note; (c) **Duck Back** is entirely absent (no code, no data); (d) **Lunge** has JSON data (`dramatic_combat_rules.lunging`) but `DRAMATIC_COMBAT_RULES` has no consumer, so no resolution logic and it is never surfaced; (e) the full **Dramatic Weapons stat table** (p.88-89) is not implemented as data.
  - *Citation drift to fix*: `ExpandedConfigPanel.gd` says "pp.89-95"; `BattlePhase.gd` / `BattleCalculations.gd` say p.91 / p.92. The actual section is Dramatic Combat p.87, Dramatic Weapons p.88-89.
  - Key files: `src/data/compendium_difficulty_toggles.gd`, `data/compendium/difficulty_toggles.json`, `src/core/battle/BattleCalculations.gd` (Phase 11), `src/core/campaign/phases/BattlePhase.gd` (~1955), `src/ui/screens/battle/TacticalBattleUI.gd` (~4114).
- **Doc discrepancy to fix**: `CLAUDE.md` lists `docs/rules/core_rulebook.txt`, `docs/rules/compendium_source.txt`, and `docs/rules/5PCompendium/` as available text extractions. None of these exist in `docs/rules/` (only Planetfall, Tactics, and a Bug Hunt/Compendium extract `.txt` are present, plus the PDFs). Update CLAUDE.md, or regenerate the missing extractions.

## B0 Fidelity Spike Findings (2026-05-27)

Traced `BattleResolver.resolve_battle()` against `data/compendium/no_minis_combat.json` (the richer of the two No-Minis extractions) and the Compendium. Full reads: `BattleResolver.gd`, `BattleCalculations.gd`, `compendium_no_minis.gd`, `NoMinisCombatPanel.gd`, `BattlePhase.gd`, `TacticalBattleUI.gd`.

### Three layers of "No-Minis" in the codebase

1. **`CompendiumNoMinisCombat`** (`src/data/compendium_no_minis.gd`) — book-faithful *structure* (round phases, one-die-less initiative, 3/4-enemy firefight, D100 flow table, mission notes, hectic/faster variants), DLC-gated, backed by `data/compendium/no_minis_combat.json`. Emits **instruction text only** — the player rolls. No automated resolution.
2. **`NoMinisCombatPanel`** (`src/ui/components/battle/NoMinisCombatPanel.gd`) — companion UI that displays those instructions. Wired in `TacticalBattleUI._setup_no_minis_panel()` and `BattlePhase` (combat_mode "no_minis" → appends setup text).
3. **`BattleResolver`** (`src/core/battle/BattleResolver.gd`) — automated dice resolution via `BattleCalculations`, but a non-canonical round structure. Used by the three generic auto-resolve callers (`CampaignTurnController.gd:909`, `BattlePhase.gd:1513`, `TacticalBattleUI.gd:3483`).

The two faithful halves — *structure* (1) and *automated math* (3) — never meet. The standalone "play it out for me" mode (B2) is exactly that bridge.

### Parity table — No-Minis (`no_minis_combat.json` / Compendium p.66) → `BattleResolver`

| No-Minis book rule | In `resolve_battle()`? |
|---|---|
| Round phases: Battle Flow → Initiative → Firefight | ✗ — round = initiative + side-A-all-attack + side-B-all-attack |
| Initiative: roll **one die less than normal**; Captain + (die ≤ Reactions) get Initiative Actions | ✗ — standard Seize-Initiative (2d6 + Savvy ≥ 10) as a binary who-goes-first |
| 8 Initiative Actions w/ 2D6 tests | ✗ — no action model; every unit just shoots |
| Firefight: randomly select **3 enemies (4 if 7+)**, player picks order | ✗ — *all* units on both sides act every round |
| Each selected enemy targets a **random** crew figure | ✗ — `_find_alive_target` returns the **first** alive (deterministic) |
| Ranged: longer range fires first → survivor returns fire; tie → crew first; both in Cover; max range; max Shots | ◐ — real to-hit/damage math, but order is initiative-side-based, range randomized, cover probabilistic, no return-fire model |
| Melee-only / mixed Brawl rules | ✗ — `resolve_brawl()` exists in `BattleCalculations` but `BattleResolver` never calls it; all combat is ranged |
| Taking Cover: shots hit **only on natural 6** | ✗ — standard to-hit with an `in_cover` flag |
| Locations / objectives | ✗ — not modeled; objectives don't affect resolution |
| Battle Flow Events (D100, 14 entries) | ✗ — absent |
| Morale (regulars first) / Retreat (1D6 ≤ Speed, max 2/round) | ✗ — battle ends only on full elimination or the 100-round safety cap |
| Mission-specific notes (11 types) | ✗ — mission type unused in resolution |
| Optional Hectic / Faster Combat; "Area & Terrifying ignored" | ✗ — absent; standard trait math applied |
| Salvage incompatibility (p.116) | ✗ — no mission-type awareness |

**Verdict:** `BattleResolver` is **✗ on structure, ◐ on math conventions**. The companion engine is **✓ on structure (as text), ✗ on resolution**.

### Decision (see `docs/sop/decision-log.md` 2026-05)

Build a **new No-Minis auto-resolver alongside** `BattleResolver`, reusing `no_minis_combat.json` structure + `BattleCalculations` math. B1 first cut implements the outcome-determining layer faithfully (Firefight + round structure + initiative count + morale/bail); the 8 Initiative Actions / Locations layer is a player-decision tier the auto-resolver abstracts (it already exists for player-driven play in the companion engine).

**Routing (live path, corrected 2026-05-27)**: `BattlePhase.gd` is DEPRECATED — the live auto-resolve is `CampaignTurnController._on_auto_resolve_completed()` (campaign choice) + `TacticalBattleUI._on_auto_resolve_battle()` (in-battle button). Both branch to `NoMinisResolver` on the `NO_MINIS_COMBAT` DLC flag (campaign path: Salvage fallback; TacticalBattleUI: `battle_mode == ""` standard-only guard for cross-mode safety).

### Secondary findings (fix during B1)

1. **Duplicate data source**: `data/RulesReference/Nominis.json` vs `data/compendium/no_minis_combat.json`. The compendium file is richer and is the one consumed → **declare it the SSOT**; `Nominis.json` is the thinner RulesReference extract (keep as reference only, do not consume in code).
2. **UI action drift**: `NoMinisCombatPanel` buttons (Fire / Engage / Cover / Sprint / Search / Aid) don't match the book's 8 actions (Scout / Move Up / Carry Out Task / Charge / Optimal Shot / Support / Take Cover / Keep Distance).
3. **Citation drift**: `compendium_no_minis.gd` "pp.68-75 (book pp.66-73)"; `BattlePhase.gd` "pp.68-75"; `TacticalBattleUI.gd` "pp.64-67"; this doc "p.66". Reconcile to one (verify the PDF-index vs printed-page offset).
4. **CLAUDE.md doc discrepancy**: `docs/rules/core_rulebook.txt`, `compendium_source.txt`, `5PCompendium/` listed as extractions but absent.

---

## Cross-references

- `data/RulesReference/Nominis.json`: complete No-Minis ruleset (the canonical extraction).
- Compendium PDF `docs/rules/Five Parsecs From Home-Compendium.pdf`: No-Minis Combat (p.66), Dramatic Combat + Dramatic Weapons (p.87-89), Grid-Based Movement (p.90-93).
- `src/core/battle/BattleResolver.gd`: current auto-resolve engine (fidelity check pending).
- `src/core/battle/BattleTierController.gd`: LOG_ONLY / ASSISTED / FULL_ORACLE tiers (the full-tabletop companion tiers).
- `src/ui/screens/narrative/NarrativeScreen.gd` + `SceneStage.gd`: the narrative presentation layer.
