# Chapter 10: Equipment and Weapons

> **Quick Start** (for tabletop veterans)
> - Each crew member: 1 primary weapon, 1 secondary weapon, 1 armor, up to 3 accessories
> - Ship stash holds unequipped gear under `equipment_data["equipment"]`
> - Sell value: 50% good, 25% damaged; condition-aware pricing via EquipmentManager
> - Available marketplace stock varies by world tech level
> - Equipment comparison available in the inventory screen

## Overview

Equipment determines your crew's combat effectiveness. The right loadout can make the difference between a clean victory and a devastating defeat. This chapter covers weapon types, armor, gear management, and the marketplace.

## Equipment Slots

Each crew member has the following equipment slots:

| Slot | Count | Notes |
|------|-------|-------|
| Primary Weapon | 1 | Your main combat weapon |
| Secondary Weapon | 1 | Backup weapon or sidearm |
| Armor | 1 | Protective gear |
| Accessories | Up to 3 | Gadgets, tools, consumables |

Unequipped items are stored in your **ship stash** — a shared pool accessible during the World Phase and Trading Phase.

## Weapon Types

Weapons in Five Parsecs fall into several categories:

### Ranged Weapons

| Category | Range | Damage | Notes |
|----------|-------|--------|-------|
| Pistols | Short | Low-Medium | Can be used as secondary |
| Rifles | Medium-Long | Medium | Standard combat weapon |
| Shotguns | Short | High | Devastating up close |
| Heavy Weapons | Long | Very High | Expensive, slow |
| Energy Weapons | Medium | Medium-High | Ignore some armor |

### Melee Weapons

| Category | Damage | Notes |
|----------|--------|-------|
| Blade | Medium | Silent, no ammo |
| Power Weapon | High | Expensive, very effective |
| Improvised | Low | Always available |

### Special Weapons

Some weapons have unique properties:
- **Area effect** — Hits multiple targets
- **Stun** — Incapacitates without killing
- **Suppression** — Forces enemies into cover
- **Piercing** — Ignores armor

## Armor Types

| Armor | Protection | Notes |
|-------|-----------|-------|
| Light Armor | 1 point | Minimal movement penalty |
| Heavy Armor | 2 points | Reduces speed slightly |
| Powered Armor | 3 points | Expensive, very protective |
| Shields | 1 point | Can be combined with armor |

Armor reduces incoming damage by its protection value. A hit dealing 3 damage against 2 points of armor only deals 1 damage.

## Equipment Condition

Equipment degrades over use:

| Condition | Sell Value | Effect |
|-----------|-----------|--------|
| Good | 50% of full price | Full effectiveness |
| Damaged | 25% of full price | May have reduced stats |
| Heavily Damaged | 10% of full price | Significantly impaired |

Equipment can be damaged during battle (critical hits, special events) or through campaign events.

### Repairing Equipment

- Repair at the marketplace during the Trading Phase
- Cost varies by item type and damage severity
- The Mechanic crew skill reduces repair costs
- Sometimes it's cheaper to replace than repair

## Managing Equipment

### The Inventory Screen

Access from the Campaign Dashboard or during World Phase:

- **Crew loadouts** — See who has what equipped
- **Ship stash** — Browse unequipped items
- **Comparison view** — Compare two items side-by-side
- **Quick equip** — Drag items between crew members and stash

### Assignment Tips

- **Match weapons to roles.** Give rifles to your best shooters (high Combat), melee weapons to tough characters.
- **Always equip armor.** Even light armor makes a difference — 1 point of damage reduction adds up over many hits.
- **Carry a secondary weapon.** If your primary runs out of ammo or breaks, a sidearm keeps you in the fight.
- **Don't hoard.** Sell equipment you're not using — credits are more useful than unused gear.

### Loot and Implants

When you find loot after battles (see {{chapter:07}}):
- Standard items go to the ship stash
- **Implants are auto-installed** to eligible characters via the `LOOT_TO_IMPLANT_MAP` pipeline
- If no eligible character exists (all at max implants), the implant goes to stash

## The Marketplace

### Buying

- Available stock depends on **world tech level** (0-12)
- Higher tech level = better and more varied equipment
- Stock rotates each turn — check back if you don't find what you need
- Some items are rare and appear only on high-tech worlds

### Selling

Sell through the marketplace during the Trading Phase:
- Good condition: **50%** of full price
- Damaged: **25%** of full price
- The app calculates sell prices automatically

## What's Next?

- For stat upgrades and skill training: {{chapter:08}} — Advancement and Trading
- For character loadout strategies: {{chapter:09}} — Characters and Crew
