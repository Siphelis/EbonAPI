EbonAPI = EbonAPI or {}
EbonAPI.TormentSlider = {}

local TormentSlider = EbonAPI.TormentSlider
local DB = EbonAPI.DB
local Problems = EbonAPI.Problems
local Kit = EbonAPI.Kit

Problems.declare("EbonAPI", "EBONAPI", {
  ["TORMENT.SLIDER_SHAPE"] = { class = "rejet", key = "field" },
})

local store = nil

local function held()
  if not DB.isAttached() then
    return nil
  end

  if not store then
    store = DB.store("EbonAPI", { account = { tormentSlider = { on = true } } })
  end

  return store.account.tormentSlider
end

function TormentSlider.isOn()
  local values = held()

  if not values then
    return true
  end

  return values.on ~= false
end

function TormentSlider.setOn(on)
  local values = held()

  if values then
    values.on = on and true or false
  end

  if ProjectEbonhold and ProjectEbonhold.HardmodeUI and ProjectEbonhold.HardmodeUI.Refresh then
    ProjectEbonhold.HardmodeUI.Refresh()
  end
end

local function isTormentFrame(parent)
  if not parent or not parent.GetParent then
    return false
  end

  local canvas = parent:GetParent()

  return _G.HardmodeCanvas ~= nil and canvas == _G.HardmodeCanvas
end

local function shortLabel(v)
  local TS = ProjectEbonhold and ProjectEbonhold.TierSelector

  if TS and TS.ShortName then
    return TS.ShortName(v)
  end

  return tostring(v)
end

local function clampTier(cfg, v)
  return math.max(1, math.min(cfg.GetMax(), math.floor(v + 0.5)))
end

local function habillage(parent, cfg, frame)
  if not isTormentFrame(parent) then
    return
  end

  if not TormentSlider.isOn() then
    return
  end

  local ladder = frame.ladder

  if type(ladder) ~= "table" or type(ladder.GetPoint) ~= "function" or type(ladder.GetWidth) ~= "function" then
    Problems.reject("EbonAPI", "TORMENT.SLIDER_SHAPE", { field = "ladder" })
    return
  end

  if type(frame.SetValue) ~= "function" then
    Problems.reject("EbonAPI", "TORMENT.SLIDER_SHAPE", { field = "SetValue" })
    return
  end

  if type(cfg) ~= "table" or type(cfg.GetMax) ~= "function" or type(cfg.OnSelect) ~= "function" then
    Problems.reject("EbonAPI", "TORMENT.SLIDER_SHAPE", { field = "cfg" })
    return
  end

  local maxTier = cfg.GetMax()

  if type(maxTier) ~= "number" or maxTier < 2 then
    return
  end

  local point, relative, relPoint, x, y = ladder:GetPoint(1)

  local slider = Kit.create("EbonAPI", "range", frame, {
    min = 1,
    max = maxTier,
    step = 1,
    width = ladder:GetWidth(),
    inline = true,
    height = ladder:GetHeight(),
    value = frame.value,
    format = shortLabel,
    onChange = function(_, v)
      cfg.OnSelect(clampTier(cfg, v))
    end,
    bubble = function(v)
      local tier = clampTier(cfg, v)
      local name = shortLabel(tier)

      if type(cfg.GetName) == "function" then
        name = cfg.GetName(tier)
      end

      if type(cfg.GetColor) == "function" then
        local r, g, b = cfg.GetColor(tier)

        return name, r, g, b
      end

      return name
    end,
  })

  slider:SetPoint(point, relative, relPoint, x, y)
  ladder:Hide()
  frame.tormentSlider = slider

  local setValue = frame.SetValue

  frame.SetValue = function(self, tier)
    setValue(self, tier)
    slider:SetValue(self.value)
  end
end

local installed = false

function TormentSlider.install()
  if installed then
    return
  end

  local TS = ProjectEbonhold and ProjectEbonhold.TierSelector

  if type(TS) ~= "table" or type(TS.Create) ~= "function" then
    return
  end

  installed = true

  local create = TS.Create

  TS.Create = function(parent, cfg)
    local frame = create(parent, cfg)
    habillage(parent, cfg, frame)
    return frame
  end
end
