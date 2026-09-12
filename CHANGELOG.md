# pfQuest Turtle patch notes

## 1.0.16 — 2026-09-11

- Fixed Rare Loot panels on enhanced world maps and corrected Ctrl modifier hints in map tooltips.

## 1.0.15 — 2026-09-11

- Updated map tooltip instructions to show Ctrl+Shift-click whenever Ctrl is required for continent-pin interaction.
- Prevented Party Progress errors during flight paths and other brief quest-log transitions where objective counts are unavailable.

## 1.0.14 — 2026-09-10

- Fixed active quest pins clearing after quest updates until the map filter was changed.
- Improved city and parent-zone pin placement, city visit filtering, and Blackstone Island continent pins.
- Made map rendering safer on clean 1.12 clients and reduced work during map changes on enhanced clients.
- Added an incremental ClassicAPI exploration cache: it warms in the background after login, persists per character, and filters both continents without a full map-open scan.
- Clean clients continue using the compatible viewed-map exploration cache.
- Restored the stable 250 ms coalesced continent redraw timing on every client.
- Made ordinary clicks pass through dense continent pins; hold Ctrl to interact with a pin.
- Added calibrated continent-map placement for Thalassian Highlands.
- Updated the mismatch notice to name and link both addons that need updating.


## 1.0.13 — 2026-09-09

- Applied Current Zone Only and unexplored-area filtering to continent pins, including parent-map exploration data for Alah'Thalas and Thalassian Highlands.
- Fixed stale config checkbox visuals after disabling a setting.
- Fixed the Turtle corpse-arrow handler continuing after the route arrow was disabled.
- On ClassicAPI clients, nameplate quest icons now use nameplate lifecycle events instead of recurring frame scans.
- Loot panels use ClassicAPI's item-ID icon lookup when available, with the existing client fallback preserved.

## 1.0.12 — 2026-09-09

- Removed expired auto-quest reward guards and completed item-query entries so they do not accumulate during long sessions.
- Cleared temporary loot item-query state when the World Map changes or closes.
- Updated the peer-update notice to link to the current release page.

## 1.0.11 — 2026-09-08

- Removed a global diagnostic error handler that failed on clients where debug is a function, masking the original error.

- Improved auto-quest handling to prevent repeated reward attempts and stale quest selection.
- Prioritize completed gossip quests and leave unfinished active quests alone.
- Defer post-reward map rebuilds while the world map is closed.
- Place nameplate quest icons below normal UI windows and menus.
- Hide nameplate quest icons while the world map is open and restore them when it closes.

## 1.0.10 — 2026-09-08

- Restored automatic quest nameplate icons on clean and modded Vanilla/Turtle clients.
- Fixed nameplate refresh, completed-objective cleanup, and configuration toggling.
- Fixed rare-loot panels and item tooltips appearing behind the world map.
- Added throttled requests for uncached loot items and support for old item-icon API layouts.
- Continent/world-map pins now respect objective spawn and cluster visibility settings.
- Improved compatibility and settings registration on older clients.

## 2026-09-07

- Added 1,329 missing Russian quest translations from the newer Turtle data while retaining the current Turtle database and feature set.
- Tooltip support now identifies creatures sharing a merged quest-item spawn marker.

## 2026-09-04

- Merged the newer Turtle database while retaining feature-branch quest compatibility records.
- Added a resizable, persistent four-column configuration window with a visible Resize button and hover help.
- Added continent-map support for Moonwhisper Coast and Alah'Thalas.
- Added the validated Alah'Thalas zone transform, allowing its quest pins to render on the zone map.
- Improved automatic quest handling: compatible quest-list loading, rapid-click protection, mixed completed/incomplete NPC quest lists, and post-reward pin refresh.
- Includes the existing Turtle QoL modules: continent pins and filters, rare loot panel, corpse arrow, nameplate icons, objective announcements, and party-progress tooltips.

Requires the accompanying patched `pfQuest` base addon. Do not include `db.pre-newdb` in releases; it is a local backup only.
