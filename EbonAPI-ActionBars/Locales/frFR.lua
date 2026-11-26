local _, ns = ...

ns.LocaleTables.frFR = {
["Add bar"] = "Ajouter une barre",
["Action bars"] = "Barres d'action",
["%d / %d"] = "%d / %d",
["Remove bar"] = "Supprimer la barre",
["Scale"] = "Échelle",
["Spacing"] = "Espacement",
["Columns"] = "Colonnes",
["Shown buttons"] = "Boutons affichés",
["Button order"] = "Ordre des boutons",
["Normal order"] = "Ordre normal",
["Reversed order"] = "Ordre inversé",
["Show keybind text"] = "Afficher le texte du raccourci",
["Visible"] = "Visible",
["Action bar %d"] = "Barre d'action %d",
["Action bar %d, button %d"] = "Barre d'action %d, bouton %d",
}

if GetLocale() == "frFR" then
  local L = ns.LocaleTables.frFR
  for n = 1, 10 do
    _G["BINDING_HEADER_EBONAPIACTIONBARS_" .. n] = string.format(L["Action bar %d"], n)
    for i = 1, 12 do
      _G["BINDING_NAME_CLICK EbonAPIActionBars_" .. n .. "_" .. i .. ":LeftButton"] = string.format(L["Action bar %d, button %d"], n, i)
    end
  end
end
