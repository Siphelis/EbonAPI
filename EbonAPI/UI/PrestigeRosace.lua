local EbonAPI = _G.EbonAPI

local UNIT = 60 / 127
local BOX = { near = 280, far = 512 }
local RAY = { 0.866, -0.5 }
local SPOKE = 30
local CENTRE = 100
local Anim = EbonAPI.PrestigeShared
Anim.MS = 1000
Anim.SMOOTH = "IN_OUT"
Anim.KIND = { A = "Alpha", S = "Scale", R = "Rotation", T = "Translation" }
Anim.PHASES = { "open", "rest", "fall", "tour" }
local MS = Anim.MS
local SMOOTH = Anim.SMOOTH
local OPEN_MS = 2400
local SECOND_MS = 1500
local PRESTIGE_MS = 3400
local PRESTIGE_DUST_MS = 4900
local KIND = Anim.KIND
local PHASES = Anim.PHASES

local function A(ms, change) return { "A", ms, change } end
local function S(ms, x, y) return { "S", ms, x, y or x } end
local function R(ms, degrees) return { "R", ms, degrees } end
local function T(ms, d) return { "T", ms, d } end
local function P(ms) return A(ms, 0) end

local OPEN_SETTLE = { { A(0, -1), S(0, 0.92) }, { A(400, 1), S(400, 1 / 0.92) } }
local TURN_ROSACE = { { R(1400, -90) } }
local TURN_FAISCEAU = { { R(1400, 8) }, { R(2000, -8) } }
local DUST_REST = { { T(0, -30) }, { A(600, 1), T(600, 12) }, { T(1800, 36) }, { A(600, -1), T(600, 12) } }

local function blink(lead)
  return { { A(0, -1) }, { P(lead) }, { S(0, 1.4) }, { A(250, 1), S(250, 0.95 / 1.4) }, { S(150, 1 / 0.95) } }
end

local function dustFall(lead)
  return {
    { P(lead) }, { T(0, -30) }, { A(500, 1), T(500, 20) }, { A(1500, -1), T(1500, 120) }, { T(0, -140) },
    { A(600, 0.6), T(600, 12) }, { T(200, 36) }, { A(600, -0.6), T(600, 12) },
  }
end

local SEQ = {
  lueur = {
    open = { { A(0, -0.5) }, { A(400, 0.5) } },
    rest = { { A(750, 0.1) }, { A(750, -0.1) }, { A(750, -0.1) }, { A(750, 0.1) } },
    fall = { { A(600, 0.5) }, { P(800) }, { A(1000, -0.5) } },
  },
  oculus = { open = { { A(0, -1), S(0, 0.9) }, { P(200) }, { A(400, 1), S(400, 1 / 0.9) } } },
  pierre = { open = OPEN_SETTLE, tour = TURN_ROSACE },
  lancette = {
    open = function(k) return { { A(0, -1), S(0, 0.6) }, { P(400 + 100 * k) }, { A(300, 1), S(300, 1 / 0.6) } } end,
    tour = TURN_ROSACE,
  },
  ["eclat-verre"] = {
    rest = function(k)
      return { { P(180 * k) }, { A(450, 0.35) }, { A(450, -0.35) }, { P(2100) }, { A(450, 0.35) }, { A(450, -0.35) }, { P(2100 - 180 * k) } }
    end,
    fall = function(k)
      return { { P(60 * k) }, { A(250, 0.9) }, { A(250, -0.9) }, { P(800 - 60 * k) }, { A(200, 0.7) }, { A(400, -0.7) } }
    end,
    tour = TURN_ROSACE,
  },
  plombs = { open = OPEN_SETTLE, tour = TURN_ROSACE },
  ["gemmes-1"] = {
    open = { { A(0, -1) }, { P(1200) }, { A(400, 1) } },
    rest = { { A(500, -0.45) }, { A(500, 0.45) } },
    tour = TURN_ROSACE,
  },
  ["gemmes-2"] = {
    open = { { A(0, -0.55) }, { P(1200) }, { A(400, 0.55) } },
    rest = { { A(500, 0.45) }, { A(500, -0.45) } },
    fall = { { A(300, 0.45) }, { P(2600) }, { A(100, -0.45) } },
    tour = TURN_ROSACE,
  },
  rai = {
    open = { { A(0, -0.18) }, { P(1800) }, { A(600, 0.18) } },
    rest = { { A(3000, 0.08) }, { A(3000, -0.08) } },
    fall = { { A(500, 0.72) }, { P(1000) }, { A(1100, -0.6) }, { A(800, -0.12) } },
    tour = TURN_FAISCEAU,
  },
  ["poussiere-1"] = { rest = DUST_REST, fall = dustFall(0), tour = TURN_FAISCEAU },
  ["poussiere-2"] = { rest = DUST_REST, fall = dustFall(100), tour = TURN_FAISCEAU },
  eclat = {
    open = { { P(1500) }, { S(0, 0.5) }, { A(250, 1), S(250, 2.2), R(250, -10) }, { A(250, -1), S(250, 1.3 / 1.1), R(250, -10) } },
    fall = { { P(600) }, { R(0, -20), S(0, 0.6) }, { A(350, 1), S(350, 1.4 / 0.6), R(350, -25) }, { A(350, -1), S(350, 1.7 / 1.4), R(350, -25) } },
  },
  ["onde-1"] = {
    open = { { P(1600) }, { A(0, 0.7) }, { A(700, -0.7), S(700, 1.25) } },
    fall = { { P(1300) }, { A(0, 0.9) }, { A(700, -0.9), S(700, 1.25) } },
  },
  ["onde-2"] = { fall = { { P(1500) }, { A(0, 0.9) }, { A(700, -0.9), S(700, 1.25) } } },
  copie = { fall = { { P(900) }, { A(300, -1), S(300, 1.3) }, { P(2200) } } },
  chiffre = { open = blink(1500), fall = blink(1250) },
  gravure = {
    open = { { P(1500) }, { S(0, 1.4) }, { A(200, 1), S(200, 1.04 / 1.4) }, { S(50, 0.95 / 1.04) }, { A(150, -0.3), S(150, 1 / 0.95) }, { A(200, -0.7) } },
    fall = { { P(1250) }, { S(0, 1.4) }, { A(200, 1), S(200, 1.04 / 1.4) }, { S(50, 0.95 / 1.04) }, { A(150, -0.3), S(150, 1 / 0.95) }, { A(200, -0.7) } },
  },
}

local function spec(name, file, box, blend, alpha, angle, k)
  local centre = k and { CENTRE * UNIT * math.sin(math.rad(angle)), CENTRE * UNIT * math.cos(math.rad(angle)) } or { 0, 0 }
  return { name = name, file = file, box = box, blend = blend, alpha = alpha, angle = angle or 0, k = k or 0, ox = centre[1], oy = centre[2] }
end

local function stack()
  local list = {
    spec("lueur", "Lueur.tga", "near", "ADD", 0.5),
    spec("oculus", "Oculus.tga", "near", "BLEND", 1),
    spec("pierre", "Pierre.tga", "near", "BLEND", 1),
  }
  for k = 0, 11 do
    local item = spec("lancette", "Lancette" .. (k + 1) .. ".tga", "near", "BLEND", 1, SPOKE * k, k)
    item.angle = 0
    list[#list + 1] = item
  end
  for k = 0, 11 do list[#list + 1] = spec("eclat-verre", "EclatVerre.tga", "near", "ADD", 0, SPOKE * k, k) end
  list[#list + 1] = spec("plombs", "Plombs.tga", "near", "BLEND", 1)
  list[#list + 1] = spec("gemmes-1", "Gemmes.tga", "near", "BLEND", 1)
  list[#list + 1] = spec("gemmes-2", "Gemmes.tga", "near", "BLEND", 0.55, SPOKE)
  list[#list + 1] = spec("rai", "Rai.tga", "far", "ADD", 0.18)
  list[#list + 1] = spec("poussiere-1", "Poussiere1.tga", "far", "ADD", 0)
  list[#list + 1] = spec("poussiere-2", "Poussiere2.tga", "far", "ADD", 0)
  list[#list + 1] = spec("eclat", "Eclat.tga", "near", "ADD", 0)
  list[#list + 1] = spec("onde-1", "Onde.tga", "near", "ADD", 0)
  list[#list + 1] = spec("onde-2", "Onde.tga", "near", "ADD", 0)
  return list
end

local function animate(group, item, order, ox, oy)
  local kind, ms = item[1], item[2]
  local anim = group:CreateAnimation(KIND[kind])
  anim:SetDuration(ms / MS)
  anim:SetOrder(order)
  if type(anim.SetSmoothing) == "function" then anim:SetSmoothing(SMOOTH) end
  if kind == "A" then
    anim:SetChange(item[3])
  elseif kind == "S" then
    anim:SetScale(item[3], item[4])
    anim:SetOrigin("CENTER", ox, oy)
  elseif kind == "R" then
    anim:SetDegrees(item[3])
    anim:SetOrigin("CENTER", 0, 0)
  else
    anim:SetOffset(RAY[1] * item[3] * UNIT, RAY[2] * item[3] * UNIT)
  end
end

local function timeline(frame, steps, loop, ox, oy)
  local group = frame:CreateAnimationGroup()
  if loop then group:SetLooping("REPEAT") end
  for order, step in ipairs(steps) do
    for _, item in ipairs(step) do animate(group, item, order, ox, oy) end
  end
  return group
end

local function steps(name, key, k)
  local source = SEQ[name] and SEQ[name][key]
  if type(source) == "function" then return source(k) end
  return source
end

local function holder(frame, name, animated, ox, oy, k)
  local record = { name = name, frame = frame }
  if animated then
    for _, key in ipairs(PHASES) do
      local source = steps(name, key, k)
      if source then record[key] = timeline(frame, source, key == "rest", ox, oy) end
    end
  end
  return record
end

local function layer(ring, item, index, animated, path)
  local frame = CreateFrame("Frame", nil, ring)
  local side = BOX[item.box] * UNIT
  frame:SetSize(side, side)
  frame:SetPoint("CENTER", ring, "CENTER", 0, 0)
  frame:SetFrameLevel(ring:GetFrameLevel() + index)
  frame:SetAlpha(item.alpha)
  local texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints(frame)
  texture:SetTexture(path .. item.file)
  texture:SetBlendMode(item.blend)
  texture:SetTexCoord(EbonAPI.PrestigeStage.turned(item.angle))
  return holder(frame, item.name, animated, item.ox, item.oy, item.k)
end

local function build(ring, countText)
  if ring.ebonapiCarrier then
    countText:SetParent(ring.ebonapiCarrier)
    return
  end

  local animated = type(ring.CreateAnimationGroup) == "function"
  local path = EbonAPI.Skins.value("media.rosace")
  local list = stack()
  local records = {}

  for index, item in ipairs(list) do
    records[#records + 1] = layer(ring, item, index, animated, path)
  end

  EbonAPI.PrestigeStage.style(countText, { font = path .. "Chiffre.ttf", size = 38, color = { 250 / 255, 242 / 255, 217 / 255 }, outline = "OUTLINE" })

  local copyFrame = CreateFrame("Frame", nil, ring)
  copyFrame:SetAllPoints(ring)
  copyFrame:SetFrameLevel(ring:GetFrameLevel() + #list + 1)
  copyFrame:Hide()
  local copyText = copyFrame:CreateFontString(nil, "OVERLAY")
  copyText:SetFont(countText:GetFont())
  copyText:SetTextColor(countText:GetTextColor())
  copyText:SetPoint("CENTER", copyFrame, "CENTER", 0, 0)
  local copy = holder(copyFrame, "copie", animated, 0, 0)
  copy.text = copyText
  records[#records + 1] = copy

  local carrier = CreateFrame("Frame", nil, ring)
  carrier:SetAllPoints(ring)
  carrier:SetFrameLevel(ring:GetFrameLevel() + #list + 2)
  countText:SetParent(carrier)
  ring.ebonapiCarrier = carrier
  records[#records + 1] = holder(carrier, "chiffre", animated, 0, 0)

  local engraveFrame = CreateFrame("Frame", nil, ring)
  engraveFrame:SetAllPoints(ring)
  engraveFrame:SetFrameLevel(ring:GetFrameLevel() + #list + 3)
  engraveFrame:SetAlpha(0)
  local engraveText = engraveFrame:CreateFontString(nil, "OVERLAY")
  EbonAPI.PrestigeStage.style(engraveText, { font = path .. "Chiffre.ttf", size = 38, color = { 1, 209 / 255, 0 }, outline = "" })
  engraveText:SetPoint("CENTER", engraveFrame, "CENTER", 0, 0)
  engraveText:SetText(countText:GetText() or "")
  records[#records + 1] = holder(engraveFrame, "gravure", animated, 0, 0)

  if not animated then return end

  local state = "cache"
  local last
  local clocks = {}
  local openClock, secondClock, prestigeClock, prestigeDustClock

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
    local group = timeline(CreateFrame("Frame", nil, ring), { { P(ms) } }, false, 0, 0)
    group:SetScript("OnFinished", done)
    clocks[#clocks + 1] = group
    return group
  end

  local function notDust(record) return record.name ~= "poussiere-2" end
  local function isDust(record) return record.name == "poussiere-2" end

  local function opened()
    state = "repos"
    Anim.run(records, "rest", notDust)
    secondClock:Play()
  end

  local function second()
    if state == "repos" then Anim.run(records, "rest", isDust) end
  end

  local function settled()
    copy.frame:Hide()
    state = "repos"
    Anim.run(records, "rest", notDust)
  end

  local function prestige(previous)
    state = "prestige"
    for _, record in ipairs(records) do
      if record.rest then record.rest:Stop() end
    end
    copy.frame:Show()
    copy.text:SetText(tostring(previous))
    Anim.run(records, "fall")
    Anim.run(records, "tour")
    prestigeClock:Play()
    prestigeDustClock:Play()
  end

  openClock = clock(OPEN_MS, opened)
  secondClock = clock(SECOND_MS, second)
  prestigeClock = clock(PRESTIGE_MS, settled)
  prestigeDustClock = clock(PRESTIGE_DUST_MS, second)

  local function opening()
    state = "ouverture"
    Anim.run(records, "open")
    openClock:Play()
  end

  ring:SetScript("OnShow", opening)
  ring:SetScript("OnHide", halt)
  if ring:IsVisible() then opening() end

  hooksecurefunc(countText, "SetText", function(_, text)
    engraveText:SetText(countText:GetText() or "")
    local number = tonumber(text)
    if not number then return end
    local previous = last
    last = number
    if previous and number > previous and state == "repos" and ring:IsVisible() then prestige(previous) end
  end)
end

EbonAPI.PrestigeAnimations.rosace = build
