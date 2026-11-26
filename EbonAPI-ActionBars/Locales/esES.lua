local _, ns = ...

ns.LocaleTables.esES = {
["Add bar"] = "Añadir barra",
["Action bars"] = "Barras de acción",
["%d / %d"] = "%d / %d",
["Remove bar"] = "Quitar barra",
["Scale"] = "Escala",
["Spacing"] = "Espaciado",
["Columns"] = "Columnas",
["Shown buttons"] = "Botones mostrados",
["Button order"] = "Orden de botones",
["Normal order"] = "Orden normal",
["Reversed order"] = "Orden inverso",
["Show keybind text"] = "Mostrar texto de tecla",
["Visible"] = "Visible",
["Action bar %d"] = "Barra de acción %d",
["Action bar %d, button %d"] = "Barra de acción %d, botón %d",
}

if GetLocale() == "esES" then
  local L = ns.LocaleTables.esES
  for n = 1, 10 do
    _G["BINDING_HEADER_EBONAPIACTIONBARS_" .. n] = string.format(L["Action bar %d"], n)
    for i = 1, 12 do
      _G["BINDING_NAME_CLICK EbonAPIActionBars_" .. n .. "_" .. i .. ":LeftButton"] = string.format(L["Action bar %d, button %d"], n, i)
    end
  end
end
