local _, ns = ...

ns.LocaleTables.deDE = {
["Add bar"] = "Leiste hinzufügen",
["Action bars"] = "Aktionsleisten",
["%d / %d"] = "%d / %d",
["Remove bar"] = "Leiste entfernen",
["Scale"] = "Skalierung",
["Spacing"] = "Abstand",
["Columns"] = "Spalten",
["Shown buttons"] = "Angezeigte Schaltflächen",
["Button order"] = "Schaltflächenreihenfolge",
["Normal order"] = "Normale Reihenfolge",
["Reversed order"] = "Umgekehrte Reihenfolge",
["Show keybind text"] = "Tastenbelegung anzeigen",
["Visible"] = "Sichtbar",
["Action bar %d"] = "Aktionsleiste %d",
["Action bar %d, button %d"] = "Aktionsleiste %d, Schaltfläche %d",
}

if GetLocale() == "deDE" then
  local L = ns.LocaleTables.deDE
  for n = 1, 10 do
    _G["BINDING_HEADER_EBONAPIACTIONBARS_" .. n] = string.format(L["Action bar %d"], n)
    for i = 1, 12 do
      _G["BINDING_NAME_CLICK EbonAPIActionBars_" .. n .. "_" .. i .. ":LeftButton"] = string.format(L["Action bar %d, button %d"], n, i)
    end
  end
end
