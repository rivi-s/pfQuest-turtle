# pfQuest Turtle patch notes

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
