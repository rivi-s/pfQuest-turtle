# pfQuest Turtle patch notes

## 1.0.35 — 2026-10-08

- Improved continent-map performance with dense objectives.
- Made Purple Lotus continent markers sparser while preserving full zone-map and minimap coverage.
- Added Q40141 delivery targets Karl and Samual with talk markers that clear after delivery.
- Added Q5216 summoned key-source location.

## 1.0.34 — 2026-10-06

- Fixed Trees & Wood tracking errors in the non-HDB edition.
- Use with pfQuest 8.0.47 for the login-stall fix; tracker progress and tree tracking confirmed in game.

## 1.0.33 — 2026-10-06

- Disabled nameplate icons now also disable objective scanning; enabled scans wait for the core login scan.
- Skipped hidden city and continent projection work during quest updates.
- Added the Survival225 display gate for Don't tell the Others.
- Restored object starter/turn-in links for Q3844 and Jarkal Mossmeld turn-in for Q41734.
- Added the Alliance restriction for Brangar's Journal (Q41873).
- Login freeze resolution remains unconfirmed pending player testing.

## 1.0.32 — 2026-10-04

- Removed an incorrect prerequisite that hid Gahz'rilla (2770) from available quest markers.
- Added Display Repeatable Quests [Beta] beneath the event/daily option, off by default. Known repeatable offers use blue exclamation marks and retain existing quest requirements. Coverage and accept/turn-in refresh are still being tested; please report missing quests with their name and ID.
- Fixed map and minimap tooltips staying visible after leaving a marker.
- Added profession skill requirements and corrected faction-specific Goldsmithing prerequisites.
- Added this changelog and one update reminder per installed version.

## 1.0.31 — 2026-10-02

- Reduced party quest synchronization work to prevent group joins and quest turn-ins from stuttering.
- Enabled automatic acceptance and turn-in for newer Turtle report quests with objective-free hand-ins.
- Corrected More Silk for the Wounded to start from Hara'ne and added her verified Moonwhisper Coast location.

## 1.0.30 — 2026-10-01

- Reduced continent-map lag from items with very large source lists while preserving every precise zone-map location.
- Added the final four Moonwhisper Coast settlement NPC locations and restored Needles Cougar and Pesterhide Hyena objectives for The Need to Survive.

## 1.0.29 — 2026-09-30

- Added Aliattan's Campfire as the event starter for The Black Waltz and corrected Spitecrest Decursions to level 47.
- Added calibrated continent projections for Lapidis Isle, Gillijim's Isle, and Tel'Abim.
- Replaced Moonwhisper Coast's rough continent placement with its client-derived projection.

## 1.0.28 — 2026-09-29

- Restored 64 missing prerequisite relationships that could expose later chain steps too early, including Vimes's Report.
- Added missing routes and objective sources for Reports of Dustwallow, The Land of Kings, and The Missing Diplomat at Sentry Point.
- Removed both obsolete Stinky's Escape variants and their removed quest NPC.

## 1.0.27 — 2026-09-27

- Linked A Letter From a Friend to the real Mysterious Glittering Object and added Kheyna Spinpistol at the verified Tanaris location.
- Restored missing class restrictions across the Tauren priest introduction and Tainted Rune.
- Removed Kex Blowmaster and his obsolete Southern Barrens quest chain.

## 1.0.26 — 2026-09-26

- Added Turtle-only Trees & Wood tracking for Survival gathering nodes, including automatic skill-range filtering.
- Integrated Turtle settings into the new five-tab configuration window without removing existing options.
- Defaulted new characters to the largest usable configuration-window size while preserving existing saved sizes.

## 1.0.25 — 2026-09-26

- Added an opt-in (Beta) party quest map pins feature: see party members' active quest objectives as map pins, with an optional nav-arrow route to them.
- Fixed Current Zone Only briefly showing Desolace quests while in Stonetalon Mountains.
- Fixed Sorrowguard Keep quests disappearing while inside the keep.
- Corrected several Windhorn/Stonetalon quest issues: wrong item drop rates, incorrect NPC spawn positions, missing class restrictions, a missing kill objective, and a batch of scripted-completion quests that appeared finished immediately on acceptance.

## 1.0.24 — 2026-09-24

- Added calibrated Eastern Kingdoms projections for Balor, Grim Reaches, Northwind, and Gilneas.
- Fixed Current Zone Only leaking quests from older zones into Grim Reaches and Northwind, with preventive coverage for Gilneas and Tel'Abim.
- Removed duplicate Alah'Thalas and Thalassian Highlands continent quest pins.
- Added verified quest objectives, starters, enders, item sources, object locations, NPC locations, and drop rates for newer Turtle content in Northwind, Balor, and Moonwhisper Coast.

## 1.0.22 — 2026-09-17

- Restored quest icons across every simultaneously visible nameplate when ClassicAPI omits some lifecycle events.
- Kept nameplate quest icons working when pfUI or BlizzNameplatesPlus replaces or recycles the displayed name region.
- Hardened automatic quest-dialog handling and extended delayed greeting selection for slow-loading NPC dialogs.

## 1.0.21 — 2026-09-15

- Updated the base and Turtle version notices to their maintained repository download pages.
- Matched Turtle item-start quest filtering to the base Level Range direction, Red threshold, and high- and low-level settings.

## 1.0.20 — 2026-09-13

- Kept collapsed Quest Log categories closed when accepting quests while nameplate objectives are enabled.

## 1.0.19 — 2026-09-13

- Restored the correct 100% drop chance for Head of Geshgan.
- Removed unintended per-frame mouse polling from ordinary zone-map pins.

## 1.0.18 — 2026-09-13

- Made item-start quest pins follow the optional Level Range setting while preserving normal filtering when it is disabled.

## 1.0.17 — 2026-09-12

- Applied the new quest-difficulty filter to item-start quest pins.
- Clarified Ctrl-hold and Shift-click map controls.
- Kept rank labels on unit pins only and improved modifier hints.

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
