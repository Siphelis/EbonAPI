local _, ns = ...

local function buildAll()
  local bars = ns.Bars.GetData().bars

  for position = 1, #bars do
    local id = bars[position].id

    if ns.Buttons.Build(id) then
      ns.Buttons.Refresh(id)
    end
  end
end

local function sync()
  ns.Editor.Sync()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    buildAll()
    hooksecurefunc(ns.Bars, "Create", function()
      buildAll()
      sync()
    end)
    ns.Editor.Init()
  else
    ns.Bars.Flush()
    buildAll()
    sync()
  end
end)
