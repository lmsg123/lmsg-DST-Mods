# Void Bag

By **lmsg** · Version **1.0.6** · Don't Starve Together

[Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3817351469) · [中文](README.md)

A backpack with 14 exterior slots and a foldable dimension of 50, 100, 150 or 200 internal slots. Configuration and UI use Chinese for Chinese game locales and English for other locales.

## Controls

- **X:** open/close the dimension while the bag is equipped and open.
- **J:** sort internal items; exterior slots stay untouched.
- **N:** transfer matching item types from your inventory and the 14 exterior slots into the dimension. The type must already exist inside. Unstackable eggs are included; unstackable tools, weapons, armor and equipment are excluded.
- **Shift + left-click:** transfer inventory/exterior items directly into the open dimension.
- **Right-drag the top border:** move the panel. Position is remembered within the current world session and resets on reconnect or surface/cave transitions.

Keys and the sort modifier (None/Shift/Ctrl) are configurable. Panel buttons provide sorting, matching-item transfer and closing.

## Storage options

Each block contains 25 slots. Optional categories: Tools, Weapons/Armor, Clothing, Food, General. Matching specialized blocks are preferred; General accepts all types and overflow. Blocks are numbered left to right, then top to bottom.

Sorting groups items by type, with descending durability/freshness and fixed gem color order. Food merging is off by default to preserve freshness groups. Normal pickups use inventory and exterior slots rather than automatically filling the hidden dimension.

Stack limits can remain original or increase to 999 inside the bag. Oversized stacks are withdrawn in original-sized portions; the remainder stays inside. Direct swaps with other cursor items are blocked for oversized stacks.

Preservation choices: 2x (Ice Box), 6x, or no spoilage. Applies to perishable items, mushroom hats and live fish inside the bag. These are base decay factors; temperature and other environmental effects still matter. Equipped items and ordinary equipment durability are unaffected.

Single-player auto-pause uses the official mechanism and requires auto-pause enabled in game settings. Multiplayer follows the game's pause rules.

## Crafting

Default station: Alchemy Engine, in the Containers crafting filter. Station and ingredient recipe are independent settings.

| Recipe | Ingredients |
| --- | --- |
| Scientific Creation | 10 Boards, 10 Cut Stone, 10 Rope, 10 Gold Nuggets |
| Arcane Cache | 1 Bundling Wrap, 2 each of Yellow/Green/Orange Moonlens |
| Ancient Relic | 3 Iridescent Gems, 9 Dark Tatters, 9 Brightshade Husks, 3 Enlightened Shards |

Station options: Alchemy Engine, Shadow Manipulator, Ancient Pseudoscience Station, Celestial Altar. Ancient/celestial recipes require being near the station.

## Multiplayer and support

This is a server mod required by all clients. Use the same version on the server and clients. Mods that change stacks, inventory/container actions or shared hotkeys may conflict; compatibility with every mod combination is not guaranteed. Show Me may refresh preservation text later than the actual effect.

Back up your world before changing capacity. Avoid reducing capacity in an existing save. If changed category settings cannot fit existing contents, the bag temporarily uses free storage until you make room and sort again.

For bug reports include the mod version, settings, other mods, reproduction steps and client/server logs. Developer information is in `Tellme.txt`; `developer/` contains optional artwork and rebuild tools, not runtime dependencies.

Tools are classified by their primary use: canes, hoes, oars, pitchforks, fishing rods, watering cans, brushes, lighting tools and utility staves are not treated as weapons merely because they can attack.

With the integrated backpack layout enabled, the exterior 14 slots merge into the player inventory bar; the Dimension opens separately. With integration disabled, the exterior uses the sidebar. Closing or dropping the bag clears its UI. Load order preserves the stack adapter after Lag Remover; mods that overwrite the same constructor later may still conflict.
