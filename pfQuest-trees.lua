-- Turtle WoW Survival tree tracking extension.
pfDatabase.metaSkillRelations = pfDatabase.metaSkillRelations or {}
pfDatabase.metaSkillRelations["trees"] = true

pfDatabase.metaAutoSkills = pfDatabase.metaAutoSkills or {}
pfDatabase.metaAutoSkills["trees"] = 51

if pfQuest.RegisterTrackingMenuEntry then
  pfQuest:RegisterTrackingMenuEntry({
    "trees",
    "Trees & Wood",
    pfDatabase.TrackMeta,
    true,
    "Interface\\AddOns\\pfQuest-turtle\\img\\tracking\\trees",
  }, "fish")
end
