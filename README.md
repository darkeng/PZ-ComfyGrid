# Comfy Grid — Tile Inventory [B42]

Project Zomboid's list inventory, rebuilt as a grid of square tiles. Made for Build 42.

![Comfy Grid](ComfyGrid/poster.png)

## Features

- **Square-tile grid** — no more scrolling a text list; it reflows to your window width.
- **Auto-stacking** — identical items merge into one tile, grouped by state (fresh/rotten, cooked, uses left, condition) and re-grouped on their own as they change. A colour bar shows each tile's status.
- **Stack inspector** — click a stack to see every item's individual condition.
- **Every container, one panel** — equipment, hotbar, pockets and every worn bag stack as sections; drag to equip or attach, no clicking through container tabs.
- **Ammo counters** — guns and magazines show their rounds right on the tile, mirrored on the vanilla hotbar.
- **Read indicator** — books, magazines and maps show reading progress and get a tick once fully read.
- **Drag & drop** with positional swap, multi-select, quick-move and spring-loaded containers.
- **Full controller support** — a cell cursor over every section, one button per action, button hints, controller stack splitting through the inspector. Steam Deck friendly.
- **Full multiplayer support**, plus configurable interface scale, grid density and instant transfers.
- **8 languages** — English, Español, Español (AR), Français, Deutsch, Русский, 简体中文, Português (BR).

Heads up: it replaces the vanilla inventory windows, so enable only one inventory-UI mod at a time (incompatible with Inventory Tetris).

## Install

Copy the [`ComfyGrid/`](ComfyGrid/) folder into `%USERPROFILE%\Zomboid\mods\` and enable it in-game, or subscribe on the Steam Workshop once the mod is published there.

## About this repository

This is the released source of the mod: one commit per published version, with the development tooling stripped out. The cards used on the Workshop page live in [`workshop/`](workshop/).

## License

All rights reserved — see [LICENSE](LICENSE). In short: read and learn from the code all you want, but don't reupload the mod or its assets. Ports, patches and translations are welcome — ask first and credit the original.

— [Darkeng](https://github.com/darkeng) · [Steam](https://steamcommunity.com/id/_darkeng_)
