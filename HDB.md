# Optional HearthDB backend

The standard GitHub Code download keeps the Lua database and its existing locale
load lists. The shared runtime includes an optional HDB adapter; no native calls
are made unless a provider companion and the HearthDB DLL APIs are available.
No DLL or companion is needed for standard pfQuest.

The optional provider source in `provider/` is not loaded by the pfQuest TOC.
HDB release bundles install it as `pfQuest-HearthDB` (vanilla) or
`pfQuest-HearthDB-turtle` (Turtle), with the matching generated SQLite database.
A provider folder nested inside pfQuest is not a separately installed addon.

Lean HDB bundles retain their existing English-only manifests, excluding the
large Lua entity/quest/item tables. They still require the compatible
`hearthdb.dll`; they cannot fall back to databases absent from that bundle.
Use the standard package if native support cannot be installed. Keep vanilla
and Turtle provider databases separate.

## Integration checkpoint

Shared gameplay/runtime files are synchronized across the standard and HDB
source trees and HDB install bundles. Standard TOCs, locale/database loading,
version numbers, update channels, and HDB lean load lists remain unchanged.
Provider source and builders are now also present in the standard trees, so
future HDB bundles can be built from these sources.

This is a local integration checkpoint, not a published beta release. In-game
verification is required on both backends: login, partial objective progress,
completion, accept/abandon/turn-in, duplicate-title chains, journal restoration,
map browsing, party joins, party pins, and auto quest dialogs.
