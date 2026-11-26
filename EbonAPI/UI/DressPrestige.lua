local EbonAPI = _G.EbonAPI
EbonAPI.PrestigeAnimations = {}
EbonAPI.PrestigeShared = {}
EbonAPI.PrestigeShared.run = function(records, key, pick)
  for _, record in ipairs(records) do
    if record[key] and (not pick or pick(record)) then record[key]:Play() end
  end
end

local Replace = EbonAPI.Replace
local saved = {}
local tinted = {}
local dressed = false
local animated
local slots = {}
local placer = Replace.placer()
local lifted = {}
local max = math.max

local function value(token) return EbonAPI.Skins.value(token) end

local function look(token)
  return { style = Replace.look(token), bg = value("tree.prestige.fill"), border = value("tree.prestige.border") }
end

local function previewLook()
  local spec = look("tree.piece.panel")
  local key = value("tree.prestige.previewFill")

  if key ~= "" then spec.bg = key end

  return spec
end

local function texturePath(region)
  local ok, path = pcall(region.GetTexture, region)
  return ok and type(path) == "string" and path or ""
end

local function eachRegion(frame, fn)
  if not frame or not frame.GetRegions then return end
  for _, region in ipairs({ frame:GetRegions() }) do
    if region.GetObjectType and region:GetObjectType() == "Texture" then fn(region) end
  end
end

local function copyPoint(from, to)
  local p, rel, rp, x, y = from:GetPoint(1)

  if p then to:SetPoint(p, rel, rp, x, y) end
end

local function countOf(frame, circle)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region.GetObjectType and region:GetObjectType() == "FontString" then
      local _, relative = region:GetPoint(1)
      if relative == circle then return region end
    end
  end
end

local function laid(native, brick, parent, place)
  local piece = slots[native]

  if not piece then
    piece = EbonAPI.Kit.create("EbonAPI", brick, parent, { width = native:GetWidth(), height = native:GetHeight() })
    piece:ClearAllPoints()
    place(piece)
    piece:EnableMouse(false)
    slots[native] = piece
  end

  return piece
end

local function near(a, b) return math.abs((a or 0) - b) <= EbonAPI.Common.get("prestige.tolerance") end

local function sized(w, h, name)
  local size = EbonAPI.Common.get(name)

  return near(w, size[1]) and near(h, size[2])
end

local function fadeBackdrop(frame)
  if not (frame.GetBackdropColor and frame.SetBackdropColor and frame.GetBackdropBorderColor) then return end
  local r, g, b, a = frame:GetBackdropColor()
  local er, eg, eb, ea = frame:GetBackdropBorderColor()
  if not (r and g and b and a and er and eg and eb and ea) then return end
  saved[#saved + 1] = { frame = frame, c = { r, g, b, a }, e = { er, eg, eb, ea } }
  local fade = tonumber(value("tree.journal.fadeAlpha")) or 0
  frame:SetBackdropColor(r, g, b, fade)
  frame:SetBackdropBorderColor(er, eg, eb, fade)
end

local function restoreBackdrops()
  for _, s in ipairs(saved) do
    s.frame:SetBackdropColor(s.c[1], s.c[2], s.c[3], s.c[4])
    s.frame:SetBackdropBorderColor(s.e[1], s.e[2], s.e[3], s.e[4])
  end
  saved = {}

  for _, t in ipairs(tinted) do
    t.region:SetVertexColor(t.c[1], t.c[2], t.c[3], t.c[4])
    t.region:SetDesaturated(t.desaturated)
  end
  tinted = {}
end

local function tintFill(region)
  local theme = EbonAPI.Palette.THEME[value("tree.prestige.barFill")]
  if not (theme and region.GetVertexColor and region.SetVertexColor) then return end
  local r, g, b, a = region:GetVertexColor()
  local flag = region.IsDesaturated and region:IsDesaturated() or false
  tinted[#tinted + 1] = { region = region, c = { r or 1, g or 1, b or 1, a or 1 }, desaturated = flag and true or false }
  if region.SetDesaturated then region:SetDesaturated(value("tree.prestige.barDesaturate")) end
  region:SetVertexColor(theme[1], theme[2], theme[3], theme[4] or 1)
end

local function inkTexts(frame)
  local key = value("tree.prestige.text")

  if key == "" or not frame or not frame.GetRegions or not Replace.ink then return end

  for _, region in ipairs({ frame:GetRegions() }) do
    if region.GetObjectType and region:GetObjectType() == "FontString" then Replace.ink(region, key) end
  end

  for _, sub in ipairs({ frame:GetChildren() }) do inkTexts(sub) end
end

local function fillPreview(preview, piece)
  local margin = max(EbonAPI.Bricks.insetOf(piece), tonumber(value("border.size")) or 0)
  local holder = preview.ebonapiTextHolder

  if not holder then
    holder = CreateFrame("Frame", nil, preview)
    holder:SetAllPoints(preview)
    holder:EnableMouse(false)
    preview.ebonapiTextHolder = holder
  end

  local level = preview:GetFrameLevel()

  for _, sub in ipairs({ preview:GetChildren() }) do
    local kind = sub:GetObjectType()

    if kind == "PlayerModel" or kind == "DressUpModel" then
      placer.place(sub, {
        { "TOPLEFT", preview, "TOPLEFT", margin, -margin },
        { "BOTTOMRIGHT", preview, "BOTTOMRIGHT", -margin, margin },
      })
      level = max(level, sub:GetFrameLevel())
    end
  end

  holder:SetFrameLevel(level + 2)
  holder:Show()

  for _, name in ipairs({ "header", "title", "pagerText" }) do
    local text = preview[name]

    if text and text.SetParent then
      lifted[text] = lifted[text] or text:GetParent()
      text:SetParent(holder)
    end
  end
end

local function setRing(frame)
  local circle = frame.ebonapiCircle
  if not circle then return end
  local region, w, h = circle.region, circle.w, circle.h
  local animation = value("tree.prestige.animation")
  local build = animation ~= "" and EbonAPI.PrestigeAnimations[animation]
  local count = build and countOf(frame, region)
  local fixed = frame.ebonapiPrestigeFixed
  local ring = frame.ebonapiPrestigeRing

  if animated then
    animated:Hide()
    animated = nil
  end

  for text, parent in pairs(lifted) do
    text:SetParent(parent)
  end
  lifted = {}

  if count then
    if fixed then fixed:Hide() end
    if not ring then
      ring = CreateFrame("Frame", nil, frame)
      frame.ebonapiPrestigeRing = ring
    end
    ring:SetSize(w, h)
    ring:ClearAllPoints()
    copyPoint(region, ring)
    lifted[count] = lifted[count] or count:GetParent()
    build(ring, count)
    ring:Show()
    animated = ring

    if not ring.ebonapiStillHooked then
      ring.ebonapiStillHooked = true
      ring:HookScript("OnShow", function()
        if not EbonAPI.Parameters.prestigeAnimation() then
          EbonAPI.Freeze.hold(ring)
        end
      end)

      if hooksecurefunc then
        hooksecurefunc(count, "SetText", function()
          if ring.ebonapiFrozen and ring:IsVisible() then
            EbonAPI.Freeze.hold(ring)
          end
        end)
      end
    end

    if EbonAPI.Parameters.prestigeAnimation() then
      EbonAPI.Freeze.release(ring)
    else
      EbonAPI.Freeze.hold(ring)
    end
  else
    if ring then ring:Hide() end
    if not fixed then
      fixed = CreateFrame("Frame", nil, frame)
      frame.ebonapiPrestigeFixed = fixed
    end
    fixed:SetSize(w, h)
    fixed:ClearAllPoints()
    copyPoint(region, fixed)
    if not fixed.ebonapiDrawn then
      fixed.ebonapiDrawn = true
      Replace.piece(fixed, "frame", look("tree.prestige.circleFrame"))
    end
    fixed:Show()
  end
end

local function dress()
  local frame = _G.EbonholdPrestigeFrame
  if not frame or dressed then return end
  dressed = true
  inkTexts(frame)

  eachRegion(frame, function(region)
    local w, h = region:GetWidth(), region:GetHeight()
    if texturePath(region):find(EbonAPI.Common.get("prestige.circleTexture"), 1, true) then
      Replace.hide(region)
      frame.ebonapiCircle = { region = region, w = w, h = h }
      setRing(frame)
    elseif near(h, EbonAPI.Common.get("prestige.separator")[2]) and w > EbonAPI.Common.get("prestige.separator")[1] then
      Replace.hide(region)
    end
  end)

  for _, child in ipairs({ frame:GetChildren() }) do
    local w, h = child:GetWidth(), child:GetHeight()
    local kind = child:GetObjectType()
    if sized(w, h, "prestige.deal") then
      fadeBackdrop(child)
      Replace.piece(child, "panel", look("tree.piece.panel"))
      inkTexts(child)
    elseif sized(w, h, "prestige.preview") then
      inkTexts(child)
      fadeBackdrop(child)
      fillPreview(child, Replace.piece(child, "panel", previewLook()))
      for _, sub in ipairs({ child:GetChildren() }) do
        if sub:GetObjectType() == "Button" and sized(sub:GetWidth(), sub:GetHeight(), "prestige.previewButton") then
          Replace.piece(sub, "button")
        end
      end
    elseif sized(w, h, "prestige.button") and kind == "Button" then
      Replace.hideChrome(child)
      Replace.piece(child, "button")
    elseif sized(w, h, "prestige.bar") then
      if child:GetObjectType() == "StatusBar" then
        if not child.kitNative then
          EbonAPI.Kit.create("EbonAPI", "progress", child:GetParent(), { bar = child })
          child.kitDraw = function() end

          if child.text and child.text.Hide then
            child.text:Hide()
          end
        end
      else
        eachRegion(child, function(region)
          if texturePath(region):find(EbonAPI.Common.get("tree.progressTexture"), 1, true) then
            if region:GetDrawLayer() == "BACKGROUND" then
              Replace.hide(region)
            else
              tintFill(region)
            end
          end
        end)
        laid(child, "progress", child:GetParent(), function(overlay)
          copyPoint(child, overlay)
          overlay:SetFrameLevel(max(0, child:GetFrameLevel() - 1))
        end):Show()
      end

      for _, bubble in ipairs({ child:GetChildren() }) do
        if sized(bubble:GetWidth(), bubble:GetHeight(), "prestige.bubble") then
          laid(bubble, "slot", bubble, function(slot)
            slot:SetAllPoints(bubble)
          end):Show()
        end
      end
    end
  end
end

local function undress()
  dressed = false
  restoreBackdrops()

  if animated then
    animated:Hide()
    animated = nil
  end

  local fixed = _G.EbonholdPrestigeFrame and _G.EbonholdPrestigeFrame.ebonapiPrestigeFixed
  if fixed then
    fixed:Hide()
    fixed.ebonapiDrawn = nil
  end

  for text, parent in pairs(lifted) do
    text:SetParent(parent)
  end
  lifted = {}

  placer.giveBack()

  for _, slot in pairs(slots) do
    slot:Hide()
  end
end

Replace.tab("Prestige", { dress = dress, undress = undress })

EbonAPI:On("PARAMETER_CHANGED", function(_, name)
  if name == "prestigeAnimation" and dressed then
    setRing(_G.EbonholdPrestigeFrame)
  end
end)
