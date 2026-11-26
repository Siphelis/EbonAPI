local Actions = EbonAPI.Actions

local type = type

local function reaper()
  local pe = _G.ProjectEbonhold

  return type(pe) == "table" and type(pe.Reaper) == "table" and pe.Reaper or {}
end

Actions.define({
  name = "RequestReaperState", cs = "REQUEST_REAPER_STATE", service = { "Reaper", "Request" },
})

Actions.define({
  name = "SummonReaper", cs = "REQUEST_SUMMON_REAPER", service = { "Reaper", "Summon" },
  guard = function()
    local state = reaper()

    if not state.hasEye then
      return "the Eye of the Reaper is not held"
    end

    if state.reaperAlive then
      return "the Reaper already walks this layer"
    end
  end,
})
