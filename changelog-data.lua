-- Older base addons do not expose the changelog yet.
if not pfQuestChangelog then return end
-- Published history and explicitly labeled development notes.
pfQuestChangelog:Register("pfQuest-turtle", {
{ ["version"] = "Next update - testing", ["date"] = "2026-10-03", ["notes"] = {
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
