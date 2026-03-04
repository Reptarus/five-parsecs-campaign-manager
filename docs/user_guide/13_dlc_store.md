# Chapter 13: DLC and Expansion Content

> **Quick Start** (for tabletop veterans)
> - 3 DLC packs: Trailblazer's Toolkit, Freelancer's Handbook, Fixer's Guidebook
> - 37 content flags across all packs (35 base + 2 Bug Hunt)
> - DLC content integrates seamlessly — gated features auto-enable when purchased
> - Purchase through the in-app Store (Steam/Android/iOS)
> - DLC corresponds to the physical Compendium supplement

## Overview

The Five Parsecs Campaign Manager supports three DLC packs that add content from the *Five Parsecs from Home Compendium* supplement. Each pack adds new species, mission types, game mechanics, and gameplay options.

DLC content is integrated throughout the app — when you purchase a pack, its features become available everywhere they're relevant (character creation, mission selection, battle mechanics, etc.).

## The Three DLC Packs

### Trailblazer's Toolkit

New exploration and faction content:

- **Krag Species** — Heavy fighters with high Toughness and Combat caps
- **Stealth Missions** — Infiltration-focused battle scenarios
- **Expanded World Generation** — More world traits and environments
- **Enhanced Faction System** — Deeper faction interactions and reputation mechanics
- **Expanded Terrain** — New battlefield terrain types

### Freelancer's Handbook

New mercenary and economic content:

- **Skulker Species** — Stealthy operatives with high Speed and Reaction
- **Street Fight Missions** — Urban combat scenarios
- **Expanded Patron System** — More patron types and job varieties
- **Loans System** — Borrow credits with interest (risky but useful)
- **Expanded Equipment** — Additional weapons and gear

### Fixer's Guidebook

New advanced mechanics and game modes:

- **Psionics System** — Psionic abilities for characters (legality varies by world)
- **Salvage Missions** — Scavenging-focused battle scenarios
- **Bug Hunt Mode** — Complete standalone military variant (see {{chapter:12}})
- **Prison Planet Campaigns** — Specialized campaign setting
- **No-Miniatures Combat** — Rules for playing without physical miniatures

## The DLC Store

### Accessing the Store

Open the Store from the Main Menu or Campaign Dashboard. The Store screen shows:

- Available DLC packs with descriptions
- What each pack contains
- Purchase buttons
- **Restore Purchases** button (for reinstalling on a new device)
- **Rate the App** button (optional review prompt)

### Purchasing DLC

The purchase flow depends on your platform:

**Steam**: Opens the Steam store overlay for DLC purchase. Ownership is verified via Steam DLC system.

**Android**: Uses Google Play in-app purchase. Purchase must be acknowledged within 3 days.

**iOS**: Uses StoreKit for in-app purchase. Products are loaded from the App Store.

**Offline/Editor**: DLC features can be toggled manually in developer mode.

### After Purchase

Once purchased, DLC content activates immediately:
- New species appear in character creation
- New mission types appear in mission selection
- New mechanics are available throughout gameplay
- No restart required — features activate in your current campaign

## How DLC Content Integrates

DLC content is gated using the `DLCManager` system. When a feature requires DLC:

- If you **own the DLC**: The feature works normally, fully integrated
- If you **don't own the DLC**: The feature is hidden or shows a "Requires [DLC Name]" message

### Examples of DLC Integration

- **Character Creation**: Krag and Skulker species only appear if their respective DLC is owned
- **Mission Selection**: Stealth, street fight, and salvage missions require their DLC packs
- **Battle Mechanics**: Escalating battles and psionic powers require specific DLC
- **Bug Hunt Mode**: The entire game mode requires Fixer's Guidebook DLC

## Content Flags

The DLC system uses 37 content flags to gate individual features. Each flag corresponds to a specific piece of content:

- Character species (Krag, Skulker)
- Mission types (stealth, street fight, salvage)
- Battle mechanics (escalating battles, dramatic combat)
- Equipment categories (compendium gear)
- Game modes (Bug Hunt)
- And more

This granular system ensures that only purchased content appears in the game, keeping the experience clean for players who haven't purchased DLC.

## What's Next?

- For Bug Hunt details: {{chapter:12}} — Bug Hunt Mode
- For character species info: {{chapter:09}} — Characters and Crew
