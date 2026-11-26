EbonAPI = EbonAPI or {}

local Replace = EbonAPI.Replace
local Skins = EbonAPI.Skins
local Palette = EbonAPI.Palette
local Common = EbonAPI.Common
local Bricks = EbonAPI.Bricks

local type, ipairs, pcall, unpack = type, ipairs, pcall, unpack
local max = math.max

local S = Skins.value
local saved = {}

local function named(name)
  local value = rawget(_G, name)

  return type(value) == "table" and value or nil
end

local function textures(frame)
  local found = {}

  if frame and frame.GetRegions then
    for _, region in ipairs({ frame:GetRegions() }) do
      if region.GetObjectType and region:GetObjectType() == "Texture" then
        found[#found + 1] = region
      end
    end
  end

  return found
end

local function pathOf(region)
  local path = region.GetTexture and region:GetTexture()

  return type(path) == "string" and path:lower() or ""
end

local function hook(object, method, fn)
  if type(hooksecurefunc) == "function" and object and type(object[method]) == "function" then
    pcall(hooksecurefunc, object, method, fn)
  end
end

local function mirror(native, piece, fade)
  local function sync()
    if piece.released then
      return
    end

    if native.IsShown and not native:IsShown() then
      piece:Hide()
    else
      piece:Show()
    end

    if fade and native.GetAlpha then
      piece:SetAlpha(native:GetAlpha())
    end
  end

  hook(native, "Show", sync)
  hook(native, "Hide", sync)

  if fade then
    hook(native, "SetAlpha", sync)
  end

  sync()
end

local function behind(native, kind, style, bg, border, opts)
  local piece = Replace.piece(native, kind, { style = style, bg = bg, border = Bricks.edge(border, bg), cover = opts and opts.cover })

  mirror(native, piece, native.GetFrameLevel ~= nil and not (opts and opts.solid))

  return piece
end

local function dressBar(bar)
  local piece = behind(bar, "frame", Replace.look("tree.bottom.frame"), S("tree.bottom.fill"), S("tree.bottom.border"))

  EbonAPI.DressTree.reach(piece, bar)

  Replace.hideChrome(bar)
end

local function dressGauge(tree)
  local gauge = tree.progressBar

  if not gauge then
    return
  end

  local fill = gauge.fillBar
  local keep = {}

  for _, owner in ipairs({ gauge, fill or gauge }) do
    local inked = owner.GetStatusBarTexture and owner:GetStatusBarTexture()

    if inked then
      keep[inked] = true
    end
  end

  local function sweep(frame, depth) -- R7f: every texture of the native frame and of every sub-frame, but the fill and the pieces of the addon
    for _, region in ipairs(textures(frame)) do
      if region ~= fill and not keep[region] then
        Replace.hide(region)
      end
    end

    if depth < Common.get("tree.gaugeDepth") then
      for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= fill and not child.replaceKind and not child.kitNative then
          sweep(child, depth + 1)
        end
      end
    end
  end

  sweep(gauge, 0)

  local native = (gauge.GetStatusBarTexture and gauge) or (fill and fill.GetStatusBarTexture and fill) or nil

  if native and EbonAPI.Kit and EbonAPI.Kit.create then
    local ok, bar = pcall(EbonAPI.Kit.create, EbonAPI.name or "EbonAPI", "progress", gauge:GetParent(), { bar = native })

    saved.gauge = native

    if ok and bar and bar.text and bar.text.Hide then
      bar.text:Hide()
    end
  end

  if fill and not native then
    local ink = S("kit.progress.color")
    local piece = Replace.piece(fill, "bar", { bg = ink, border = S("kit.progress.border"), cover = true })

    mirror(fill, piece, false)
  end

  local text = gauge.progressText

  if text and text.GetFont and text.SetFont then
    if not saved.gaugeText then
      local face, size, flags = text:GetFont()

      saved.gaugeText = { text = text, face = face, size = size, flags = flags }
    end

    local held = saved.gaugeText

    if held.face and held.size then
      pcall(text.SetFont, text, held.face, held.size, S("tree.gauge.outline"))
    end

    if text.SetShadowColor then
      local sr, sg, sb = Palette.unpackColor(S("tree.gauge.shadow"))

      text:SetShadowColor(sr, sg, sb, S("tree.gauge.shadowAlpha"))
      text:SetShadowOffset(S("tree.gauge.shadowX"), S("tree.gauge.shadowY"))
    end

    local tr, tg, tb = Palette.unpackColor(S("tree.gauge.text"))

    text:SetTextColor(tr, tg, tb, 1)

    if fill and fill.GetPoint and text.SetPoint then
      local _, _, _, _, fillY = fill:GetPoint(1)

      held.point = { text:GetPoint(1) }
      text:ClearAllPoints()
      text:SetPoint("CENTER", gauge, "CENTER", 0, fillY or 0)
    end
  end
end

local function dressButton(native)
  if not native then
    return
  end

  behind(native, "frame", Replace.look("tree.button.frame"), S("tree.button.fill"), S("tree.button.border"))

  Replace.hideChrome(native, { icon = true })
end

local function findApply(bar)
  for _, child in ipairs({ bar:GetChildren() }) do
    if child.__anchorToSearch and child.GetScript and child:GetScript("OnClick") then
      return child
    end
  end
end

local function dressSearch(search)
  if not search then
    return
  end

  local piece = Replace.piece(search, "input", { cover = true })
  local edit = piece.edit

  Replace.hideChrome(search)

  if not edit then
    return
  end

  edit:Show()
  edit:SetText(search:GetText() or "")

  saved.search = { native = search, mouse = search.IsMouseEnabled and search:IsMouseEnabled() }

  if search.EnableMouse then
    search:EnableMouse(false)
  end

  local relaying = false

  edit:HookScript("OnTextChanged", function(self)
    if relaying or piece.released then
      return
    end

    relaying = true
    search:SetText(self:GetText() or "")
    relaying = false
  end)

  hook(search, "SetText", function(_, text)
    if relaying or piece.released then
      return
    end

    relaying = true
    edit:SetText(text or "")
    relaying = false
  end)

  function piece.syncSearch()
    if piece.released then
      return
    end

    if EbonAPI.DressTree.searchShown() then
      piece:Show()
    else
      piece:Hide()
    end
  end

  local level = search.GetFrameLevel and search:GetFrameLevel()

  if level then
    piece:SetFrameLevel(max(0, level))
  end

  hook(search, "Show", piece.syncSearch)
  hook(search, "Hide", piece.syncSearch)

  local bar = search:GetParent()

  if bar and bar.HookScript then
    pcall(bar.HookScript, bar, "OnShow", piece.syncSearch)
  end

  EbonAPI.DressTree.searchPiece = piece
  piece.syncSearch()
end

local function dressBanner(bar)
  local banner = bar.levelRestrictionFrame

  if not banner then
    return
  end

  behind(banner, "panel", Replace.look("tree.banner.frame"), S("tree.banner.fill"), S("tree.banner.border"))

  if banner.SetBackdropColor and not saved.banner then
    saved.banner = { frame = banner }

    if banner.GetBackdropColor then
      saved.banner.fill = { banner:GetBackdropColor() }
    end

    if banner.GetBackdropBorderColor then
      saved.banner.edge = { banner:GetBackdropBorderColor() }
    end

    banner:SetBackdropColor(0, 0, 0, 0)

    if banner.SetBackdropBorderColor then
      banner:SetBackdropBorderColor(0, 0, 0, 0)
    end
  end
end

local function dressPaper()
  local inset = named("skillTreeInset")

  if not inset then
    return
  end

  if not S("windows.tile.content") then -- R7f: one fond per part, the tile fond of the journal page already surrounds the paper
    behind(inset, "panel", Replace.look("tree.paper.frame"), S("tree.paper.fill"), S("tree.paper.border"), { solid = true }) -- R7c: the paper keeps the skin opacity, never the native fade
  end

  Replace.hideChrome(inset)
end

local revertRetired = {}

local function retireRevert(native)
  if not native then
    return
  end

  native:Hide()

  if not revertRetired[native] and native.HookScript then
    revertRetired[native] = true
    pcall(native.HookScript, native, "OnShow", function(self) self:Hide() end)
  end
end

local function dress()
  local bar = named("skillTreeBottomBar")

  if not bar then
    return
  end

  local tree = bar:GetParent()

  dressPaper()
  dressBar(bar)
  dressGauge(tree)
  dressButton(findApply(bar))
  dressButton(named("skillTreeExportButton"))
  dressButton(named("skillTreeImportButton"))
  retireRevert(named("revertBtn"))
  dressSearch(named("skillTreeSearchBox"))
  dressBanner(bar)
end

local function undress()
  local gaugeBar = saved.gauge

  if gaugeBar and type(gaugeBar.Undress) == "function" then
    pcall(gaugeBar.Undress, gaugeBar)
  end

  local mouse = saved.search

  if mouse and mouse.native.EnableMouse then
    mouse.native:EnableMouse(mouse.mouse ~= false)
  end

  EbonAPI.DressTree.searchPiece = nil

  local held = saved.banner

  if held and held.frame.SetBackdropColor then
    if held.fill then
      held.frame:SetBackdropColor(unpack(held.fill))
    end

    if held.frame.SetBackdropBorderColor and held.edge then
      held.frame:SetBackdropBorderColor(unpack(held.edge))
    end
  end

  local gaugeText = saved.gaugeText

  if gaugeText and gaugeText.face and gaugeText.size then
    pcall(gaugeText.text.SetFont, gaugeText.text, gaugeText.face, gaugeText.size, gaugeText.flags or "")

    if gaugeText.point and gaugeText.point[1] then
      gaugeText.text:ClearAllPoints()
      gaugeText.text:SetPoint(unpack(gaugeText.point))
    end

    if gaugeText.text.SetShadowOffset then
      gaugeText.text:SetShadowOffset(0, 0)
    end
  end

  saved = {}
end

Replace.tab("SkillTree", { dress = dress, undress = undress })
