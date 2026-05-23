# QOL Feature Candidates — Product Backlog

**Last Updated**: 2026-05-22
**Origin**: May 22 runtime audit of fiveparsecs.online (recon for May 25 Modiphius call) surfaced 10 interaction-pattern QOL features that are product-category-neutral and worth adopting into 5PFH as alpha-1 / alpha-2 polish.
**Status**: **Sprint 1 ACTIVE (Shape A, 5 items)**. See [Sprint Status](#sprint-status) below for which items are in-flight.
**Recon source**: [internal-recon/may-25-call/recon-notes.md](internal-recon/may-25-call/recon-notes.md) §8-9
**Working plan workspace** (ephemeral): `C:\Users\admin\.claude\plans\i-guess-i-need-hashed-chipmunk.md`

This doc is the durable product backlog. The plan file is a workspace and may be deleted; this doc is the source of truth for future sessions evaluating "what QOL work remains?"

---

## Verified Infrastructure Summary

Read-only sweep performed 2026-05-22 to convert effort estimates from guesses into accurate sequencing.

| Component | Path | Status | Capability |
|---|---|---|---|
| `StepperControl` | `src/ui/components/common/StepperControl.gd` | EXISTS | Single-value stepper with `setup(initial, min, max, step)`. NO baseline-display mode. Has TweenFX punch animation on change. |
| `KeywordDB` autoload | `src/autoload/KeywordDB.gd` | EXISTS | `get_keyword(term)` returns dict (term/definition/related/rule_page/category); `parse_text_for_keywords(text)` wraps recognized terms in BBCode links. Loads from `data/keywords.json`. |
| `KeywordTooltip` widget | `src/ui/components/tooltips/KeywordTooltip.gd` | EXISTS | Responsive popover (mobile/tablet/desktop), debounced, static `format_equipment_with_keywords()` helper. |
| KeywordDB consumer surfaces | 17 files | PARTIAL COVERAGE | Used by CharacterDetailsScreen, CompendiumScreen, UnifiedBattleLog, BattleJournal, BasePhasePanel, EquipmentFormatter, StoryTextFormatter, more. Coverage gap on TacticalBattleUI enemy cards + PreBattleUI enemy roster (to be verified by Item 2 sweep). |
| `CampaignJournal` autoload | `src/core/campaign/CampaignJournal.gd` | EXISTS | Entries have `turn_number`, `type`, `auto_generated`, `mood`, `tags`, `stats`, `player_notes`. NO `get_turn_summary()` method yet (grep-verified). |
| `SceneRouter` | `src/ui/screens/SceneRouter.gd` | EXISTS | Const dict `SCENE_PATHS` keyed by string → scene path. Adding a route is trivial. |
| `CharacterCard` | `src/ui/components/character/CharacterCard.gd` | EXISTS | 3 variants (COMPACT/STANDARD/EXPANDED). Already has `card_tapped`, `view_details_pressed`, `edit_pressed`, `remove_pressed` signals. Print signal NOT yet present. |
| Draft autosave / `user://drafts/` | NOT FOUND | GREENFIELD | Grep returned no matches for `user://drafts`, `save_draft`, or `persist_draft`. Item 8 builds from scratch. |
| Enemy data | `data/RulesReference/Bestiary.json` + `EliteEnemies.json` + `data/enemy_types.json` + `data/elite_enemy_types.json` | EXISTS | 4 files reference Anarchists. Schema almost certainly includes full Core Rules profile fields. |
| `src/qol/` directory | 5 files | EXISTS | TurnPhaseChecklist, EquipmentComparisonTool, QOLUtilities, KeywordSystem, BattleSetupWizard. Useful prior art for staging. |

---

## Per-Item Analysis

Each item: WHAT (one-line) / WHY (player-experience benefit) / EXISTING INFRA / GAP / EFFORT / OWNER / LANDING SITES.

### Item 1 — Dual-column current/updated stepper display

- **WHAT**: Stat-edit screens show current value AND target value side-by-side
- **WHY**: Eliminates "what was it before?" mental load; delta visible at glance
- **EXISTING INFRA**: `StepperControl` at `src/ui/components/common/StepperControl.gd`
- **GAP**: Add optional `setup_with_baseline(current, target, min, max, step)` constructor mode + new `_baseline_label` node + conditional rendering. ~30-line addition.
- **EFFORT**: LOW (2-4 hours for widget; +1 day for 3 adopter surfaces in Sprint 1's expanded scope)
- **AGENT OWNER**: `ui-panel-developer`
- **LANDING SITES**:
  - Widget: `src/ui/components/common/StepperControl.gd` (extend)
  - Adopter 1: PostBattle XP-spend screen (path TBD during execution — likely in `src/ui/screens/postbattle/` or character sheet XP allocation)
  - Adopter 2: Advancement phase (`src/ui/screens/campaign/panels/AdvancementPhasePanel.gd` likely)
  - Adopter 3: Equipment trade screens (trading phase / sell-for-upkeep dialog)

### Item 2 — Inline rules popovers coverage sweep

- **WHAT**: Every weapon/trait/keyword name in battle UI is clickable for rules text
- **WHY**: Eliminates page-flipping during play; reinforces companion-app positioning
- **EXISTING INFRA**: `KeywordDB` + `KeywordTooltip` + `parse_text_for_keywords` all built. 17 surfaces already use it.
- **GAP**: Coverage audit + retrofit. Identify which battle surfaces don't use KeywordDB yet (TacticalBattleUI enemy cards, PreBattleUI enemy roster, CharacterCard trait chips). Wire them up.
- **EFFORT**: MEDIUM (1-2 days; audit + ~6-10 retrofit points)
- **AGENT OWNER**: `ui-panel-developer` primary; `battle-systems-engineer` reviews battle-UI touches
- **LANDING SITES**:
  - `src/ui/screens/battle/TacticalBattleUI.gd`
  - `src/ui/screens/battle/PreBattleUI.gd`
  - `src/ui/components/character/CharacterCard.gd`
  - Any other panel that displays weapon/trait names statically today (discovered during audit)

### Item 3 — Print Sheet view for character + encounter

- **WHAT**: Dedicated printable scene for character sheet (and later encounter card) for hybrid-play players
- **WHY**: T4 digital→physical bridge made concrete; reinforces companion-app positioning
- **EXISTING INFRA**: SceneRouter accepts new routes trivially. No existing print/export infrastructure.
- **GAP**: Build `CharacterPrintSheet.tscn` + `.gd` scene rendering a character at print-friendly proportions. Add SceneRouter route. Add "Print" button on CharacterCard / CharacterDetailsScreen. Optionally: encounter print sheet too.
- **EFFORT**: MEDIUM-HIGH (2-3 days for character; +1-2 days for encounter)
- **AGENT OWNER**: `ui-panel-developer` primary; `character-data-engineer` consulted on stat-layout authority
- **LANDING SITES**: New `src/ui/screens/print/CharacterPrintSheet.gd` + `.tscn`. New SceneRouter entry. Button additions in CharacterCard + CharacterDetailsScreen.

### Item 4 — Activity feed with per-turn change count summary

- **WHAT**: Dashboard surface showing "Turn N: X battles, Y character events, Z resource changes"
- **WHY**: Helps player orient when resuming a saved campaign
- **EXISTING INFRA**: `CampaignJournal` stores `turn_number` per entry; entries already typed (`battle`, `story`, `purchase`, `injury`, `milestone`, `custom`). NO existing aggregation method.
- **GAP**: Add `CampaignJournal.get_turn_summary(turn_number) -> Dictionary` returning counts per type. Add UI surface on `CampaignDashboard` showing summary chip per recent turn.
- **EFFORT**: LOW-MEDIUM (4-6 hours; aggregation is trivial, UI surface is a small new card)
- **AGENT OWNER**: `campaign-systems-engineer` for the journal method; `ui-panel-developer` for the dashboard surface
- **LANDING SITES**: `src/core/campaign/CampaignJournal.gd` (add method), `src/ui/screens/campaign/CampaignDashboard.gd` (add summary card)

### Item 5 — "Battle Note" carryback textbox

- **WHAT**: Persistent in-battle textbox where player captures observations
- **WHY**: Bridges physical-tabletop moment with digital record; small but loved
- **EXISTING INFRA**: TacticalBattleUI has unit info panel but no general-purpose note textbox (to verify during execution)
- **GAP**: Add small fixed-position textbox to TacticalBattleUI, persist to current battle context, fold into post-battle journal entry on battle end via `CampaignJournal.auto_create_battle_entry()` `player_notes` field
- **EFFORT**: LOW (3-5 hours)
- **AGENT OWNER**: `battle-systems-engineer` (TacticalBattleUI ownership)
- **LANDING SITES**: `src/ui/screens/battle/TacticalBattleUI.gd`, hand off to `CampaignJournal.auto_create_battle_entry()`

### Item 6 — Consistent Edit / Inspect / Print / Delete verb row

- **WHAT**: Standardized 4-button affordance row on entity cards (character, ship, equipment, world)
- **WHY**: UX consistency; predictable affordances reduce cognitive load
- **EXISTING INFRA**: `CharacterCard` already has `view_details_pressed`, `edit_pressed`, `remove_pressed` signals. Needs Print signal added + a shared row component.
- **GAP**: New `EntityCardActionsRow` component in `src/ui/components/common/` taking enum of supported verbs. Refactor CharacterCard to use it. Apply to ShipCard (if exists), EquipmentCard, WorldCard.
- **EFFORT**: MEDIUM (1-2 days; new component plus 3-5 card refactors)
- **AGENT OWNER**: `ui-panel-developer`
- **LANDING SITES**: New `src/ui/components/common/EntityCardActionsRow.gd`. Refactors in CharacterCard, any other entity cards.

### Item 7 — Friendly business-rule error banner copy pass

- **WHAT**: Replace generic validation strings ("Please fill all fields") with specific, conversational, actionable copy ("Crew needs a Captain — click 'Set Captain' on any crew member")
- **WHY**: Form UX feels less rule-bound and more guided
- **EXISTING INFRA**: Error display patterns vary across screens
- **GAP**: Audit + rewrite ~30-40 user-facing validation strings across `CampaignCreationCoordinator` panels, equipment-action validators, upkeep-failure flow, character-creation form validators
- **EFFORT**: MEDIUM (1-2 days; mostly copy work, some `_show_error()` infrastructure standardization)
- **AGENT OWNER**: `ui-panel-developer` primary; `campaign-systems-engineer` for campaign-creation validators
- **LANDING SITES**: All panels under `src/ui/screens/campaign/panels/`, equipment screens, upkeep flow, character creation

### Item 8 — Draft autosave with resume

- **WHAT**: Multi-step wizards (campaign creation, character creation, mission setup) auto-checkpoint to `user://drafts/` on every step transition. MainMenu shows "Resume Draft" button when a draft exists.
- **WHY**: Invisible until the user loses 10 minutes of work, then it's the most important feature in the app
- **EXISTING INFRA**: NONE (grep confirmed greenfield)
- **GAP**: Build `DraftPersistenceService` (new), wire into `CampaignCreationCoordinator` step transitions, add MainMenu "Resume Draft" affordance with deserialization
- **EFFORT**: HIGH (3-5 days; new system with serialization, edge cases for partial draft validity)
- **AGENT OWNER**: `campaign-systems-engineer` (creation flow ownership)
- **LANDING SITES**: New `src/core/services/DraftPersistenceService.gd`. Changes in `CampaignCreationCoordinator.gd`, `MainMenu.gd`. Possibly extend to CharacterCreator and battle-simulator setup.

### Item 9 — Schema-driven enemy auto-populate verification

- **WHAT**: Confirm PreBattleUI surfaces the full Core Rules enemy profile (panic / speed / combat / toughness / number / AI / weapons / traits) at the moment of mission generation
- **WHY**: Match the UX of seeing the full enemy stat block inline on one card
- **EXISTING INFRA**: Enemy data exists in 4 files. Schema almost certainly complete.
- **GAP**: Audit `PreBattleUI.gd` enemy-card rendering. If a field is missing, add it. Possibly polish layout for stat-block clarity.
- **EFFORT**: LOW (4-6 hours; mostly verification + minor adds)
- **AGENT OWNER**: `battle-systems-engineer`
- **LANDING SITES**: `src/ui/screens/battle/PreBattleUI.gd`, possibly `src/ui/components/battle/*` enemy-info widgets

### Item 10 — Breadcrumb-driven typed picker for nested change forms

- **WHAT**: A "GM override" dialog with breadcrumb-driven categorized picker
- **WHY**: Power-user manual override for procedural outcomes ("I don't like this generated mission, let me pick instead")
- **EXISTING INFRA**: None — this is a "if/when we add a GM override mode" feature
- **GAP**: **DEFERRED post-1.0**. Only relevant if we add a manual-override product mode, which is not aligned with current procedural-execution thesis.

---

## Sequencing Roadmap

| Rank | Item | Effort | Impact | Notes |
|---|---|---|---|---|
| 1 | Item 2 — Inline rules popovers coverage sweep | M | High | Lowest-friction big win; infrastructure exists |
| 2 | Item 7 — Friendly error banner copy | M | Med-high | Form UX feels less hostile; mostly copy work |
| 3 | Item 1 — Dual-column stepper | L | Med | Universal clarity win; small change with broad impact |
| 4 | Item 4 — Activity feed turn-summary | L-M | Med | Helps re-entry to saved campaigns |
| 5 | Item 5 — Battle Note carryback | L | Med | Small UX touch that bridges hybrid play |
| 6 | Item 8 — Draft autosave with resume | H | High | Largest single investment; pays off the first time a user loses work |
| 7 | Item 3 — Print Sheet view (character + encounter) | M-H | High strategically | T4 digital→physical mechanism made concrete |
| 8 | Item 6 — EntityCardActionsRow standardization | M | Med | Consistency win; touches many files |
| 9 | Item 9 — Schema-driven enemy populate verification | L | L-M | Likely already mostly done |
| 10 | Item 10 — Breadcrumb typed picker | DEFERRED | N/A | Post-1.0 only |

**Aggregate effort estimate**: items 1-9 combined ~12-18 working days for a single-developer sprint.

---

## Sprint Shapes (history-of-record)

### Shape A — Alpha-1 polish sprint (1 week) — **SHIPPED 2026-05-22**

Items 2, 7, 1, 4, 5 in that execution order. ~5-7 days. Shipped visible interaction-quality improvements in time for the A1 alpha build.

**Item 1 stepper adopters deferred** to a future stepper-introduction sprint (the named adopter surfaces use ItemList today, not steppers — no surface to opt in).

**Item 7 sweep extended via verification pass** from ~52 strings/15 files to ~77 strings/25 files. Lesson logged: don't use `head_limit` on Grep during coverage sweeps.

### Shape B — Alpha-2 cohesive polish sprint (2 weeks) — not chosen this round

Items 1-5 + 6 + 9. ~8-10 days. Adds verb-row standardization + enemy populate verification on top of Shape A. Reserved for a later sprint if alpha cohort prioritizes consistency over fresh polish.

### Shape C — Post-alpha refinement sprint (4 weeks) — reserved for Jul-Aug 2026

Items 1-9 minus 10. ~12-18 days. All items including Draft autosave (item 8) and Print Sheet (item 3) which are strategic but heavier. Maps to Phase C in the [workback](#cross-references).

### Sprint 2 candidates (prepped 2026-05-22, awaiting Elijah's pick)

Full scoping doc with per-item depth + risk analysis: `C:\Users\admin\.claude\plans\qol-sprint-2-scoping.md`.

| Shape | Scope | Effort | Best fit |
|---|---|---|---|
| **S2-A "Alpha-1 safety net"** (recommended) | F1 (dead temp_data) + F4 (MCP runtime verify) + Item 9 (enemy populate) + F2 (CharacterStatusCard) + F3 (kill `_get_trait_description`) + Item 6 (EntityCardActionsRow) | ~5-7 days | Tight low-risk consolidation before closed alpha kickoff May 25 |
| S2-B "Single big bet: Draft autosave" | Item 8 (greenfield service) + F1 + F4 | ~5-7 days | Highest-felt-impact win for alpha testers; mitigates "lost work" complaints |
| S2-C "Strategic: Print Sheet" | Item 3 (character + encounter print) + F1 + F4 | ~5-7 days | Concrete T4 digital→physical artifact for May 25 Modiphius call |
| S2-D "Validator DRY" | F5 (consolidate ~77 validation strings) + F1 + F3 | ~2-3 days | Pure codebase-quality refactor; no new player-facing surface |

**Carryover follow-ups (referenced above)**:
- **F1** — Retarget dead `GameState.temp_data` callers (`PreBattleUI`, `PostBattleSummarySheet`) to `GameStateManager` API
- **F2** — CharacterStatusCard keyword-link retrofit (deferred from Item 2, needs scene edit)
- **F3** — Kill `WeaponTableDisplay._get_trait_description()` hardcoded fallback (audit + extend KeywordDB first)
- **F4** — MCP runtime screenshots / scenario coverage for Sprint 1 items 1, 2, 5
- **F5** — Consolidate the ~77 duplicated validation strings into a shared module
- **F6** — Stepper baseline adopters (PostBattle XP / Advancement / equipment trade) — needs stepper introduction first, deferred to dedicated sprint

---

## Sprint Status

### Sprint 1 (active, started 2026-05-22)

| Item | Status | Notes |
|---|---|---|
| Item 2 — Inline rules popovers sweep | **done 2026-05-22** | New `KeywordLinker` helper. Retrofits: PreBattleUI enemy stat-table (weapons col + special_rules), WeaponTableDisplay row-level trait list. CharacterCard skipped (no trait surface). CharacterStatusCard deferred (typed Label in .tscn requires scene edit). 5 gdUnit4 tests pass. |
| Item 7 — Friendly error copy | **done 2026-05-22 (verified + extended)** | Initial sweep rewrote ~52 strings across 15 files. Verification pass found 25+ additional user-facing strings missed in 9 more files (gamemode Core resources, ship panels, story-quest validators, SecurityValidator) because the original grep had `head_limit: 80`. **Total after verification: ~77 strings across 25 files.** Style: specific, actionable, conversational. No em dashes. Headless compile clean. |
| Item 1 — Stepper baseline (widget + 3 adopters) | **widget done 2026-05-22, adopters deferred** | `setup_with_baseline()` shipped with delta-color (green/red/cyan) and "Was: N →" prefix. 6 gdUnit4 tests pass. **Adopter wiring deferred** — the named PostBattle XP / Advancement / equipment-trade surfaces use ItemList selection today, not steppers. Adopting baseline mode requires first introducing steppers to those flows (a bigger UX refactor than fits Sprint 1). Widget is ready; future sprint should introduce steppers to those surfaces and opt them into baseline mode. |
| Item 4 — Activity feed turn-summary | **done 2026-05-22** | `CampaignJournal.get_turn_summary(turn_number)` aggregates per-type counts. `CampaignDashboard._render_last_turn_recap()` shows "Last turn: N battles, M events, K purchases" line under the stat strip when turn > 1 and the previous turn has activity. 4 gdUnit4 tests pass. |
| Item 5 — Battle Note carryback | **done 2026-05-22** | Floating "Battle Notes" TextEdit added to TacticalBattleUI (top-right, CanvasLayer L30). Writes via `GameStateManager.set_temp_data("battle_player_notes", ...)`. `CampaignJournal.auto_create_battle_entry()` consumes + clears it, appending the note to the journal entry description with a `[Notes]` prefix. 3 gdUnit4 tests pass. |

**Sprint 1 totals**: 18 gdUnit4 tests added, 4 helper modules/methods, 1 new dashboard surface, ~52 user-facing strings rewritten, 5 of 5 Shape A items shipped (Item 1 widget done; adopters deferred to a future stepper-introduction sprint).

Update this section after each item ships (status → "done", add commit ref).

#### Follow-ups opened by Sprint 1

These were discovered during Sprint 1 execution and are worth tracking explicitly so they don't get lost.

1. **Dead `GameState.temp_data` accesses** — `PreBattleUI._store_terrain_for_passthrough` (line 388) and `PostBattleSummarySheet` (line 174) read/write `GameState.temp_data` but `GameState` has no such property. Guards always fail, making both code paths dead. The real `temp_data` lives on `GameStateManager` (with `_temp_data` storage and `set_temp_data()` / `get_temp_data()` / `has_temp_data()` / `clear_temp_data()` accessors). Either retarget those callers to use `GameStateManager`, or add a `temp_data` property to `GameState`. Item 5 chose the former path for the new write.
2. **CharacterStatusCard keyword-link retrofit** — Item 2 deferred the trait-keyword wire-up because `stats_label` is typed `Label` in `CharacterStatusCard.tscn` and would need a scene edit. Worth doing once the in-flight battle-UI redesign settles.
3. **Stepper baseline-mode adopters** — Item 1 widget shipped but the 3 named adopters (PostBattle XP-spend, Advancement, equipment trade) use `ItemList` selection today, not steppers. Introducing steppers to those surfaces is a UX refactor worth its own sprint slot.
4. **WeaponTableDisplay `_get_trait_description()` hardcoded table** — Item 2 left this in place. Once KeywordDB covers all Core Rules trait names (audit which are missing), the duplicate table can be deleted and the details panel can use `KeywordLinker` instead.

#### Item 2 — Audit findings (kept for follow-up reference)

**Inspected surfaces** (all 3 priority targets from sweep plan):

| Surface | Pre-sweep state | This sweep |
|---|---|---|
| `PreBattleUI._setup_enemy_info()` | All 8 grid-cells were plain Labels. Weapons col + special_rules block had keyword content but zero interactivity. | Weapons col → RichTextLabel + `KeywordLinker.wrap_known_keywords`. Special-rules entries → RichTextLabel + `wrap_known_keywords`. Shared `_keyword_tooltip` lazy-instantiated. |
| `WeaponTableDisplay._create_weapon_entry()` | Row-level `traits_label: Label` showed `", ".join(traits)` as plain gold text. | Converted to RichTextLabel + `KeywordLinker.build_traits_bbcode`. Empty-traits case kept as a "-" Label. |
| `WeaponTableDisplay._show_weapon_details()` | Already RichTextLabel. Had hardcoded `_get_trait_description()` table (lines 220-237) duplicating KeywordDB. | Left unchanged — already informative; killing the hardcoded fallback was out-of-scope. Flagged for follow-up. |
| `CharacterStatusCard._apply_tier_display()` | Typed `Label` weapon-name display at tier 1+. | **Deferred** — typed Label is in `.tscn`; conversion needs scene edit. Worth a follow-up. |
| `CharacterCard` equipment badges | Plain item-name Labels; never display trait keywords. | **N/A** — structural gap (badge doesn't carry trait data), not a wire-up gap. Revisit when battle-UI redesign extends card content. |

**Follow-up backlog opened by Item 2**:
- Convert `CharacterStatusCard.stats_label` to RichTextLabel (scene edit + tier-aware text rebuild)
- Kill `WeaponTableDisplay._get_trait_description()` once KeywordDB covers all Core Rules trait names (audit which are missing)
- Expand `CharacterCard` equipment badges to show traits, then wire keyword links

---

## Verification Quality Bar

Every shipped item must pass:

1. **Per-item gdUnit4 test** for any new methods (e.g. `CampaignJournal.get_turn_summary()`, `StepperControl.setup_with_baseline()`). Tests go in `tests/unit/`.
2. **Headless compile pass**: `& "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --quit --path "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager"`
3. **MCP runtime verification** via `mcp__godot__run_project` + `mcp__godot__take_screenshot` for surfaces with visible UX deltas (items 1, 2, 5).
4. **Cross-mode smoke test** for shared-surface items (2, 5): drive a Bug Hunt mission AND a Planetfall mission to confirm no regressions.
5. **Save/load round-trip test** for items that touch persistence (4 changes journal, 5 changes battle context handoff).

---

## Agent Routing

Per [agent-roster](../.claude/skills/fpcm-project-management/references/agent-roster.md) ownership rules:

- `ui-panel-developer`: items 1, 3, 6, 7 (UI components, theme, panels)
- `battle-systems-engineer`: items 2 (battle-UI portion), 5, 9 (battle surfaces)
- `campaign-systems-engineer`: items 4, 8 (journal + creation flow)
- `qa-specialist`: final verification pass for all items
- `fpcm-project-manager`: orchestrates sequencing + cross-domain coordination

**Cross-mode safety**: items 2 (battle UI) and 5 (battle UI) touch surfaces shared with Bug Hunt / Planetfall / Tactics. The relevant gamemode-specialist agent reviews for cross-mode regressions.

---

## Cross-references

- Recon source: [internal-recon/may-25-call/recon-notes.md](internal-recon/may-25-call/recon-notes.md) §8-9
- Partnership context: [PARTNERSHIP_TERM_POSITIONS.md](PARTNERSHIP_TERM_POSITIONS.md) (parallel workstream)
- Strategic theses (T1 player throughput, T4 digital→physical): see `MEETING_FOLLOWUPS_2026-04-29.md` §1.5
- Workback timing: [CLOSED_ALPHA_PLAN.md](CLOSED_ALPHA_PLAN.md) §8 (post-alpha refinement window for Shape C)
- Existing QOL roadmap: [gameplay/qol/](gameplay/qol/)
