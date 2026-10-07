-- Turtle WoW Survival tree tracking extension.
pfDatabase.metaSkillRelations = pfDatabase.metaSkillRelations or {}
pfDatabase.metaSkillRelations["trees"] = true

pfDatabase.metaAutoSkills = pfDatabase.metaAutoSkills or {}
pfDatabase.metaAutoSkills["trees"] = 51

pfDatabase.metaTrackingIcons = pfDatabase.metaTrackingIcons or {}
pfDatabase.metaTrackingIcons["trees"] = "Interface\\AddOns\\pfQuest-turtle\\img\\tracking\\trees"

pfDatabase.metaSkillCaptions = pfDatabase.metaSkillCaptions or {}
pfDatabase.metaSkillCaptions["trees"] = "Survival"

local treeTextures = {
  ["Interface\\Icons\\simple_wood_1"] = { 2020267, 2020268, 2020269, 2020270, 2020271, 2020272, 2020273, 2020274,
    2020275, 2020276, 2020277, 2020278, 2020279, 2020280, 2020281, 2020301 }, -- Simple Wood
  ["Interface\\Icons\\oak_wood_1"] = { 2020282, 2020283, 2020284, 2020285, 2020286, 2020287 }, -- Bright Wood
  ["Interface\\Icons\\pine_wood_1"] = { 2020288, 2020289, 2020290, 2020291, 2020292, 2020293, 2020294, 2020295,
    2020296, 2020297, 2020309 }, -- Shade Wood
  ["Interface\\Icons\\tropical_logs_1"] = { 2020298 }, -- Tropical Wood
  ["Interface\\Icons\\INV_Misc_Herb_12"] = { 2020299, 2020300 }, -- Star and Dead Leaves
}

local function ResolveTreeIcons()
  -- The Lua core uses title icons; the HDB core also uses object-ID icons.
  pfDatabase.iconsByID = pfDatabase.iconsByID or {}
  for texture, objects in pairs(treeTextures) do
    for _, objectID in pairs(objects) do
      pfDatabase.iconsByID["O" .. objectID] = texture
      local title = pfDB.objects and pfDB.objects.loc and pfDB.objects.loc[objectID]
      if title then pfDatabase.icons[title] = texture end
    end
  end
end

local TrackMeta = pfDatabase.TrackMeta
function pfDatabase:TrackMeta(list, state)
  if list == "trees" then ResolveTreeIcons() end
  return TrackMeta(self, list, state)
end

if pfQuest.RegisterTrackingMenuEntry then
  pfQuest:RegisterTrackingMenuEntry({
    "trees",
    "Trees & Wood",
    pfDatabase.TrackMeta,
    true,
    "Interface\\AddOns\\pfQuest-turtle\\img\\tracking\\trees",
  }, "fish")
end
