local EbonAPI = _G.EbonAPI

local HALF = 0.5
local Anim = EbonAPI.PrestigeShared
local KIND = Anim.KIND
local PHASES = Anim.PHASES
local MS = Anim.MS
local SMOOTH = Anim.SMOOTH

local Stage = {}
EbonAPI.PrestigeStage = Stage

function Stage.A(ms, change) return { "A", ms, change } end
function Stage.S(ms, x, y, ox, oy) return { "S", ms, x, y or x, ox, oy } end
function Stage.R(ms, degrees, ox, oy) return { "R", ms, degrees, ox, oy } end
function Stage.T(ms, dx, dy) return { "T", ms, dx, dy } end
function Stage.P(ms) return Stage.A(ms, 0) end

function Stage.turned(angle)
  local c, s = math.cos(math.rad(angle)), math.sin(math.rad(angle))
  local function corner(dx, dy) return HALF + dx * c + dy * s, HALF - dx * s + dy * c end
  local ulx, uly = corner(-HALF, -HALF)
  local llx, lly = corner(-HALF, HALF)
  local urx, ury = corner(HALF, -HALF)
  local lrx, lry = corner(HALF, HALF)
  return ulx, uly, llx, lly, urx, ury, lrx, lry
end

function Stage.style(fontString, style)
  local font, size, flags = fontString:GetFont()
  local ok = fontString:SetFont(style.font, style.size, style.outline)
  if not ok then fontString:SetFont(font, size, flags) end
  fontString:SetTextColor(style.color[1], style.color[2], style.color[3])
end

local function animate(group, item, order, ox, oy)
  local kind, ms = item[1], item[2]
  local anim = group:CreateAnimation(KIND[kind])
  anim:SetDuration(ms / MS)
  anim:SetOrder(order)
  if not item.linear and type(anim.SetSmoothing) == "function" then anim:SetSmoothing(SMOOTH) end
  if kind == "A" then
    anim:SetChange(item[3])
  elseif kind == "S" then
    anim:SetScale(item[3], item[4])
    anim:SetOrigin("CENTER", item[5] or ox, item[6] or oy)
  elseif kind == "R" then
    anim:SetDegrees(item[3])
    anim:SetOrigin("CENTER", item[4] or ox, item[5] or oy)
  else
    anim:SetOffset(item[3], item[4])
  end
end

local function timeline(frame, sequence, loop, ox, oy)
  local group = frame:CreateAnimationGroup()
  if loop then group:SetLooping("REPEAT") end
  for order, step in ipairs(sequence) do
    for _, item in ipairs(step) do animate(group, item, order, ox, oy) end
  end
  return group
end
Stage.timeline = timeline

local function holder(frame, name, spec, animated, ox, oy)
  local record = { name = name, frame = frame }
  if animated then
    for _, key in ipairs(PHASES) do
      if spec[key] then record[key] = timeline(frame, spec[key], key == "rest", ox, oy) end
    end
  end
  return record
end

local function layer(ring, couche, index, animated, path, unit, boxes)
  local frame = CreateFrame("Frame", nil, ring)
  local side = boxes[couche.box] * unit
  frame:SetSize(side, side)
  frame:SetPoint("CENTER", ring, "CENTER", couche.x or 0, couche.y or 0)
  frame:SetFrameLevel(ring:GetFrameLevel() + index)
  frame:SetAlpha(couche.alpha or 1)
  local texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(frame)
  texture:SetTexture(path .. couche.file)
  texture:SetBlendMode(couche.blend)
  texture:SetTexCoord(Stage.turned(couche.angle or 0))
  local record = holder(frame, couche.name, couche, animated, couche.ox or 0, couche.oy or 0)
  record.texture = texture
  record.index = index
  return record
end

function Stage.build(ring, countText, def)
  if ring.ebonapiCarrier then
    countText:SetParent(ring.ebonapiCarrier)
    return
  end

  local animated = type(ring.CreateAnimationGroup) == "function"
  local path = def.path
  local unit = def.unit
  local boxes = def.boxes
  local layers = def.layers
  local records = {}
  local specs = {}

  Stage.style(countText, def.count.style)

  for index, couche in ipairs(layers) do
    local record = layer(ring, couche, index, animated, path, unit, boxes)
    specs[record] = couche
    records[#records + 1] = record
  end

  local copyFrame = CreateFrame("Frame", nil, ring)
  copyFrame:SetAllPoints(ring)
  copyFrame:SetFrameLevel(ring:GetFrameLevel() + #layers + 1)
  copyFrame:Hide()
  local copyText = copyFrame:CreateFontString(nil, "OVERLAY")
  copyText:SetFont(countText:GetFont())
  copyText:SetTextColor(countText:GetTextColor())
  copyText:SetPoint("CENTER", copyFrame, "CENTER", 0, 0)
  local copy = holder(copyFrame, "copie", def.copy, animated, 0, 0)
  copy.text = copyText
  records[#records + 1] = copy

  local carrier = CreateFrame("Frame", nil, ring)
  carrier:SetAllPoints(ring)
  carrier:SetFrameLevel(ring:GetFrameLevel() + #layers + 2)
  countText:SetParent(carrier)
  ring.ebonapiCarrier = carrier
  records[#records + 1] = holder(carrier, "chiffre", def.count, animated, 0, 0)

  if not animated then return end

  local state = "cache"
  local last
  local clocks = {}
  local delayed = {}
  local openClock, prestigeClock
  local ctl = { ring = ring, path = path, unit = unit, records = records, byName = {} }

  local function setting(record) return specs[record] or {} end

  ctl.run = function(key, pick) Anim.run(records, key, pick) end

  for _, record in ipairs(records) do
    local current = ctl.byName[record.name]
    if current == nil then
      ctl.byName[record.name] = record
    elseif current[1] then
      current[#current + 1] = record
    else
      ctl.byName[record.name] = { current, record }
    end
  end

  local function halt()
    for _, record in ipairs(records) do
      for _, key in ipairs(PHASES) do
        if record[key] then record[key]:Stop() end
      end
    end
    for _, group in ipairs(clocks) do group:Stop() end
    copy.frame:Hide()
    state = "cache"
  end

  local function clock(ms, done)
    local group = timeline(CreateFrame("Frame", nil, ring), { { Stage.P(ms) } }, false, 0, 0)
    group:SetScript("OnFinished", done)
    clocks[#clocks + 1] = group
    return group
  end

  for _, record in ipairs(records) do
    local ms = setting(record).restAfter
    if ms then
      delayed[#delayed + 1] = clock(ms, function()
        if record.rest then record.rest:Play() end
      end)
    end
  end

  local function opened()
    state = "repos"
    Anim.run(records, "rest", function(record) return not setting(record).restAfter end)
    for _, group in ipairs(delayed) do group:Play() end
  end

  local function settled()
    copy.frame:Hide()
    state = "repos"
    if def.onSettle then def.onSettle(ctl) end
    Anim.run(records, "rest", function(record)
      local s = setting(record)
      return not s.hold and not s.restAfter
    end)
    for _, group in ipairs(delayed) do group:Play() end
  end

  local function prestige(previous)
    state = "prestige"
    for _, record in ipairs(records) do
      if record.rest and not setting(record).hold then record.rest:Stop() end
    end
    for _, group in ipairs(delayed) do group:Stop() end
    copy.frame:Show()
    copy.text:SetText(tostring(previous))
    if def.onPrestige then def.onPrestige(ctl, previous) end
    Anim.run(records, "fall")
    Anim.run(records, "tour")
    prestigeClock:Play()
  end

  openClock = clock(def.openMs, opened)
  prestigeClock = clock(def.prestigeMs, settled)

  local function opening()
    state = "ouverture"
    if def.onOpen then def.onOpen(ctl) end
    Anim.run(records, "open")
    openClock:Play()
  end

  ring:SetScript("OnShow", opening)
  ring:SetScript("OnHide", halt)
  ring.ebonapiRest = function()
    halt()
    state = "repos"
  end
  ring.ebonapiResume = function()
    if ring:IsVisible() then opening() end
  end
  if ring:IsVisible() then opening() end

  hooksecurefunc(countText, "SetText", function(_, text)
    local number = tonumber(text)
    if not number then return end
    local previous = last
    last = number
    if previous and number > previous and state == "repos" and ring:IsVisible() then prestige(previous) end
  end)
end
