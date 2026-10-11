-- Older base addons do not expose the changelog yet.
if not pfQuestChangelog then return end
-- Published history and explicitly labeled development notes.
pfQuestChangelog:Register("pfQuest-turtle", {
{ ["version"] = "1.0.36", ["date"] = "2026-10-10", ["notes"] = {
"Quest-category filters refresh when saved; tooltips explain the repeatable-quest requirement.",
"Party marker settings refresh cached party data and routing immediately.",
"Loot-panel settings refresh an already open panel."
} },
{ ["version"] = "1.0.35", ["date"] = "2026-10-08", ["notes"] = {
"Improved continent-map performance with dense objectives.",
"Made Purple Lotus continent markers sparser while preserving full zone-map and minimap coverage.",
"Added Q40141 delivery targets Karl and Samual with talk markers that clear after delivery.",
"Added Q5216 summoned key-source location."
} },
{ ["version"] = "1.0.34", ["date"] = "2026-10-06", ["notes"] = {
"Fixed Trees & Wood tracking errors in the non-HDB edition.",
"Use with pfQuest 8.0.47 for the login-stall fix; tracker progress and tree tracking confirmed in game."
} },
{ ["version"] = "1.0.33", ["date"] = "2026-10-06", ["notes"] = {
"Disabled nameplate icons now also disable objective scanning; enabled scans wait for the core login scan.",
"Skipped hidden city and continent projection work during quest updates.",
"Added the Survival225 display gate for Don't tell the Others.",
"Restored object starter/turn-in links for Q3844 and Jarkal Mossmeld turn-in for Q41734.",
"Added the Alliance restriction for Brangar's Journal (Q41873).",
"Login freeze resolution remains unconfirmed pending player testing."
} },
{ ["version"] = "1.0.32", ["date"] = "2026-10-04", ["notes"] = {
"Removed an incorrect prerequisite that hid Gahz'rilla (2770) from available quest markers.",
"Added Display Repeatable Quests [Beta] beneath the event/daily option, off by default. Known repeatable offers use blue exclamation marks and retain existing quest requirements. Coverage and accept/turn-in refresh are still being tested; please report missing quests with their name and ID.",
"Fixed map and minimap tooltips staying visible after leaving a marker.",
"Added profession skill requirements and corrected faction-specific Goldsmithing prerequisites.",
"Added this changelog and one update reminder per installed version."
} },
{ ["version"] = "1.0.31", ["date"] = "2026-10-02", ["notes"] = {
"Reduced party quest synchronization work to prevent group joins and quest turn-ins from stuttering.",
"Enabled automatic acceptance and turn-in for newer Turtle report quests with objective-free hand-ins.",
"Corrected More Silk for the Wounded to start from Hara'ne and added her verified Moonwhisper Coast location."
} },
{ ["version"] = "1.0.30", ["date"] = "2026-10-01", ["notes"] = {
"Reduced continent-map lag from items with very large source lists while preserving every precise zone-map location.",
"Added the final four Moonwhisper Coast settlement NPC locations and restored Needles Cougar and Pesterhide Hyena objectives for The Need to Survive."
} },
{ ["version"] = "1.0.29", ["date"] = "2026-09-30", ["notes"] = {
"Added Aliattan's Campfire as the event starter for The Black Waltz and corrected Spitecrest Decursions to level 47.",
"Added calibrated continent projections for Lapidis Isle, Gillijim's Isle, and Tel'Abim.",
"Replaced Moonwhisper Coast's rough continent placement with its client-derived projection."
} },
{ ["version"] = "1.0.28", ["date"] = "2026-09-29", ["notes"] = {
"Restored 64 missing prerequisite relationships that could expose later chain steps too early, including Vimes's Report.",
"Added missing routes and objective sources for Reports of Dustwallow, The Land of Kings, and The Missing Diplomat at Sentry Point.",
"Removed both obsolete Stinky's Escape variants and their removed quest NPC."
} },
{ ["version"] = "1.0.27", ["date"] = "2026-09-27", ["notes"] = {
"Linked A Letter From a Friend to the real Mysterious Glittering Object and added Kheyna Spinpistol at the verified Tanaris location.",
"Restored missing class restrictions across the Tauren priest introduction and Tainted Rune.",
"Removed Kex Blowmaster and his obsolete Southern Barrens quest chain."
} },
{ ["version"] = "1.0.26", ["date"] = "2026-09-26", ["notes"] = {
"Added Turtle-only Trees & Wood tracking for Survival gathering nodes, including automatic skill-range filtering.",
"Integrated Turtle settings into the new five-tab configuration window without removing existing options.",
"Defaulted new characters to the largest usable configuration-window size while preserving existing saved sizes."
} },
{ ["version"] = "1.0.25", ["date"] = "2026-09-26", ["notes"] = {
"Added an opt-in (Beta) party quest map pins feature: see party members' active quest objectives as map pins, with an optional nav-arrow route to them.",
"Fixed Current Zone Only briefly showing Desolace quests while in Stonetalon Mountains.",
"Fixed Sorrowguard Keep quests disappearing while inside the keep.",
"Corrected several Windhorn/Stonetalon quest issues: wrong item drop rates, incorrect NPC spawn positions, missing class restrictions, a missing kill objective, and a batch of scripted-completion quests that appeared finished immediately on acceptance."
} },
{ ["version"] = "1.0.24", ["date"] = "2026-09-24", ["notes"] = {
"Added calibrated Eastern Kingdoms projections for Balor, Grim Reaches, Northwind, and Gilneas.",
"Fixed Current Zone Only leaking quests from older zones into Grim Reaches and Northwind, with preventive coverage for Gilneas and Tel'Abim.",
"Removed duplicate Alah'Thalas and Thalassian Highlands continent quest pins.",
"Added verified quest objectives, starters, enders, item sources, object locations, NPC locations, and drop rates for newer Turtle content in Northwind, Balor, and Moonwhisper Coast."
} }
})
