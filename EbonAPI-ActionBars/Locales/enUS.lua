local _, ns = ...

ns.LocaleTables.enUS = {
["Add bar"] = "Add bar",
["Action bars"] = "Action bars",
["%d / %d"] = "%d / %d",
["Remove bar"] = "Remove bar",
["Scale"] = "Scale",
["Spacing"] = "Spacing",
["Columns"] = "Columns",
["Shown buttons"] = "Shown buttons",
["Button order"] = "Button order",
["Normal order"] = "Normal order",
["Reversed order"] = "Reversed order",
["Show keybind text"] = "Show keybind text",
["Visible"] = "Visible",
["Action bar %d"] = "Action bar %d",
["Action bar %d, button %d"] = "Action bar %d, button %d",
}

local L = ns.LocaleTables.enUS
local locale = GetLocale()
if locale ~= "frFR" and locale ~= "deDE" and locale ~= "esES" then
  for n = 1, 10 do
    _G["BINDING_HEADER_EBONAPIACTIONBARS_" .. n] = string.format(L["Action bar %d"], n)
    for i = 1, 12 do
      _G["BINDING_NAME_CLICK EbonAPIActionBars_" .. n .. "_" .. i .. ":LeftButton"] = string.format(L["Action bar %d, button %d"], n, i)
    end
  end
end
