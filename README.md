# Comfy Grid — Tile Inventory [B42]

Project Zomboid's list inventory, rebuilt as a grid of square tiles. Made for Build 42.

![Comfy Grid](ComfyGrid/poster.png)

## Features

- **Square-tile grid** — no more scrolling a text list; it reflows to your window width.
- **Auto-stacking** — identical items merge into one tile whatever their state (fresh and stale food, a full and a half-used roll of tape); weapons, tools and heavy items always keep a tile of their own. A colour bar shows each tile's status, and an option restores strict grouping by state.
- **Stack inspector** — click a stack to see every item's individual condition, and drag one member onto another to top it up.
- **Every container, one panel** — equipment, hotbar, pockets and every worn bag stack as sections; drag to equip or attach, no clicking through container tabs.
- **Ammo counters** — guns and magazines show their rounds right on the tile, mirrored on the vanilla hotbar.
- **Weight at a glance** — a scale-weight icon on every tile fades from faint green to blood red with the item's weight; stacks show the weight of the whole pile.
- **Read indicator** — books, magazines and maps show reading progress and get a tick once fully read.
- **Drag & drop** with positional swap, multi-select, quick-move and spring-loaded containers.
- **Drop to use** — rounds on a magazine load it, a magazine or attachment on its gun fits it, a bottle on another pours, and a part-used item (pills, tape, glue…) tops up another of its kind from any container; compatible targets light up while dragging, and everything returns to where it was afterwards.
- **Full controller support** — a cell cursor over every section, one button per action, button hints, controller stack splitting through the inspector. Steam Deck friendly.
- **Full multiplayer support**, plus configurable interface scale (0.1 steps; it also follows the game's font-size setting), grid density, stacking by type or by state, instant transfers, stacked loot containers and trimmed empty rows.
- **8 languages** — English, Español, Español (AR), Français, Deutsch, Русский, 简体中文, Português (BR).

Heads up: it replaces the vanilla inventory windows, so enable only one inventory-UI mod at a time (incompatible with Inventory Tetris).

## Install

Copy the [`ComfyGrid/`](ComfyGrid/) folder into `%USERPROFILE%\Zomboid\mods\` and enable it in-game, or subscribe on the Steam Workshop once the mod is published there.

## About this repository

This is the released source of the mod: one commit per published version, with the development tooling stripped out. The cards used on the Workshop page live in [`workshop/`](workshop/).

## License

All rights reserved — see [LICENSE](LICENSE). In short: read and learn from the code all you want, but don't reupload the mod or its assets. Ports, patches and translations are welcome — ask first and credit the original.

— [Darkeng](https://github.com/darkeng) · [Steam](https://steamcommunity.com/id/_darkeng_)
