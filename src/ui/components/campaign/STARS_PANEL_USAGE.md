# StarsOfTheStoryPanel Usage Guide

## Overview

The `StarsOfTheStoryPanel` displays the **five** emergency abilities from Core Rules p.67 as a vertical list of cards. It's the preview surface used on `FinalPanel` during campaign creation, showing each ability's name, description, remaining uses, and a (currently inert) "Use" button.

For actually USING a star at runtime, the panel is read-only — go through `StoryPointPopover` (dashboard) or the new TacticalBattleUI Stars HUD (in battle) instead.

## The 5 abilities (Core Rules p.67)

1. **"It's time to go!"** — End battle, all crew escape (battle-only)
2. **"Looked worse than it was!"** — Ignore an Injury Table roll (post-battle)
3. **"Did you ever meet my mate?"** — Add new crew mid-battle within 6" of any edge (battle-only)
4. **"Lucky shot!"** — Turn a missed shot into a hit, single shot only (battle-only)
5. **"Rainy day fund!"** — Immediately +1D6+5 credits (dashboard)

Use `StarsOfTheStorySystem.is_battle_only(ability)` (static) to determine which surface should expose a given ability.

## Files

- `src/ui/components/campaign/StarsOfTheStoryPanel.gd` — component logic (5 cards, single-column grid)
- `src/ui/components/campaign/StarsOfTheStoryPanel.tscn` — scene wrapper

## Quick Start

```gdscript
const StarsPanelScene = preload(
    "res://src/ui/components/campaign/StarsOfTheStoryPanel.tscn")
const StarsSystem = preload(
    "res://src/core/systems/StarsOfTheStorySystem.gd")

# 1. Build the system (new signature — difficulty only)
var stars := StarsSystem.new()
stars.initialize(campaign.difficulty)

# 2. Apply Elite Rank picks (campaign-setup only, NOT runtime)
#    Core Rules p.65: every 5 Elite Ranks = 1 pick to double one ability
if PlayerProfile.get_instance().elite_ranks >= 5:
    stars.apply_elite_rank_pick(StarsSystem.StarAbility.LUCKY_SHOT)

# 3. Instantiate panel and initialize with the system
var panel = StarsPanelScene.instantiate()
add_child(panel)
panel.initialize(stars)
```

## Important API changes (May 2026)

- `initialize(difficulty: int)` — was `initialize(elite_ranks: int, difficulty: int)`. Elite Rank picks are applied separately via `apply_elite_rank_pick()`.
- `update_elite_ranks()` and `_distribute_bonus_uses()` — **deleted**. Bonus picks are setup-time only per Core Rules p.65.
- `DRAMATIC_ESCAPE` enum value — **deleted** (was fabricated). Use `LOOKED_WORSE` for the post-battle injury star.
- `IT_WASNT_THAT_BAD` — renamed to `LOOKED_WORSE` with new semantics (ignore the roll, not remove the injury).
- New: `DID_YOU_EVER_MEET` and `LUCKY_SHOT` enum values for the previously-missing options.
- New: `apply_elite_rank_pick(ability)` — call once per pick at campaign setup.
- New: `is_battle_only(ability)` static — for callers that need to gate UI by context.
- New: `log_use_to_journal(ability, context, result, journal, turn, source)` static — single source of truth for star → CampaignJournal entries with source tag `"battle"`, `"post_battle"`, or `"dashboard"`.

## Persistence

Stars state is stored on `FiveParsecsCampaignCore.stars_of_the_story: Dictionary` (NOT `stars_of_story_data` — that was a typo). Serialize via `stars.serialize()` and write to the campaign field; deserialize via `stars.deserialize(campaign.stars_of_the_story)`.

Bug Hunt and Planetfall campaign cores do **NOT** have this field by design (Compendium p.214 forbids carry-over).

## Insanity mode

In Insanity difficulty, all 5 abilities are disabled (`get_uses_remaining` returns 0 for every ability, `is_active()` returns false). The system gates this via `DifficultyModifiers.are_stars_of_story_disabled()` reading `data/RulesReference/DifficultyOptions.json`.
