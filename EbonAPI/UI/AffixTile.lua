EbonAPI = EbonAPI or {}

local Bricks = EbonAPI.Bricks
local Kit = EbonAPI.Kit
local Palette = EbonAPI.Palette

local format, lower = string.format, string.lower
local type, tostring, pairs = type, tostring, pairs
local floor = math.floor

local WIDTH, HEIGHT = 62, 78
local SIZE = 38
local ICON = SIZE * 0.8
local RIM = 1
local ASSETS = "Interface\\AddOns\\ProjectEbonhold\\assets\\"
local SWIRL = "Interface\\Cooldown\\star4"
local NAME_GAP = 2
local NAME_HEIGHT = 18
local DIM = 0.4
local ROMAN = { "I", "II", "III", "IV", "V" }
local STATES = { equipped = true, learned = true, bag = true, bagged = true, unlearned = true }

local FALLBACK = {
  ["palette.muted"] = 0x9D9D9D,
  ["palette.title"] = 0xFFD100,
  ["palette.text"] = 0xFFFFFF,
  ["kit.category.offensive"] = 0xE05A4E,
  ["kit.category.defensive"] = 0x4A9BE0,
  ["kit.category.resource"] = 0x4CC26A,
  ["kit.category.utility"] = 0xF08A28,
  ["kit.category.mobility"] = 0xB06AE0,
}

local CATEGORIES = { offensive = true, defensive = true, resource = true, utility = true, mobility = true }

local peLoaded

local instances = setmetatable({}, { __mode = "k" })

local function rgb(key)
  local found = Bricks.value(key)

  if type(found) ~= "number" then
    found = FALLBACK[key]
  end

  return Palette.unpackColor(floor(found))
end

local function colorOf(category)
  if type(category) == "string" and CATEGORIES[lower(category)] then
    return rgb("kit.category." .. lower(category))
  end

  return rgb("palette.muted")
end

local function checkAffixTile(owner, spec, level)
  if spec.category ~= nil and type(spec.category) ~= "string" then
    error(format("EbonAPI: %s: affixTile category expects a text, got %s", owner, tostring(spec.category)), level + 1)
  end

  if spec.state ~= nil and not STATES[spec.state] then
    error(format("EbonAPI: %s: affixTile state expects equipped, learned, bag or unlearned, got %s", owner,
      tostring(spec.state)), level + 1)
  end

  for _, name in pairs({ "equipped", "bagged" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "boolean" then
      error(format("EbonAPI: %s: affixTile %s expects a boolean, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.rank ~= nil and type(spec.rank) ~= "number" then
    error(format("EbonAPI: %s: affixTile rank expects a number, got %s", owner, tostring(spec.rank)), level + 1)
  end

  for _, name in pairs({ "text", "label", "icon" }) do
    if spec[name] ~= nil and type(spec[name]) ~= "string" then
      error(format("EbonAPI: %s: affixTile %s expects a text, got %s", owner, name, tostring(spec[name])), level + 1)
    end
  end

  if spec.iconSize ~= nil and type(spec.iconSize) ~= "number" then
    error(format("EbonAPI: %s: affixTile iconSize expects a number, got %s", owner, tostring(spec.iconSize)), level + 1)
  end
end

local function setAnimations(tile, on)
  if not tile.animations then
    return
  end

  for _, group in pairs(tile.animations) do
    if on then
      group:Play()
    else
      group:Stop()
    end
  end
end

local function addSwirl(tile, texture, duration, degrees)
  local group = texture:CreateAnimationGroup()
  local rotation = group:CreateAnimation("Rotation")

  group:SetLooping("REPEAT")
  rotation:SetDuration(duration)
  rotation:SetDegrees(degrees)
  rotation:SetOrigin("CENTER", 0, 0)
  tile.animations[#tile.animations + 1] = group
end

local function layer(tile, level, sub, path, size)
  local texture = tile:CreateTexture(nil, level, nil, sub)

  texture:SetTexture(path)
  texture:SetWidth(size * tile.scale)
  texture:SetHeight(size * tile.scale)
  texture:SetPoint("CENTER", tile, "TOP", 0, -tile.centerTop)

  return texture
end

local function buildAnimated(tile)
  tile.animations = {}

  tile.back = layer(tile, "BACKGROUND", 0, ASSETS .. "perm_background_texture", SIZE * 1.6)

  tile.swirl = layer(tile, "BACKGROUND", 1, SWIRL, SIZE * 2)
  tile.swirl:SetBlendMode("ADD")
  addSwirl(tile, tile.swirl, 4, 360)

  tile:SetScript("OnShow", function(self)
    setAnimations(self, self.live)
  end)
  tile:SetScript("OnHide", function(self)
    setAnimations(self, false)
  end)
end

local function render(tile)
  local spec = tile.spec
  local state = spec.state
  local rank = spec.rank
  local equipped = spec.equipped
  local learned = type(rank) == "number" and ROMAN[rank] ~= nil

  if state ~= nil then
    learned = state ~= "unlearned"

    if equipped == nil then
      equipped = state == "equipped"
    end
  end

  local cr, cg, cb = colorOf(spec.category)
  local nr, ng, nb = rgb("palette.muted")
  local tr, tg, tb = rgb("palette.text")
  local shade = learned and 1 or DIM

  tile.ring:SetVertexColor(cr * shade, cg * shade, cb * shade, 1)

  if type(spec.icon) == "string" then
    tile.picture:Show()

    if tile.picture.path ~= spec.icon then
      tile.picture.path = spec.icon
      SetPortraitToTexture(tile.picture, spec.icon)
    end

    tile.picture:SetDesaturated(not learned)
    tile.picture:SetVertexColor(shade, shade, shade, 1)
    tile.rank:ClearAllPoints()
    tile.rank:SetPoint("BOTTOM", tile.ring, "BOTTOM", 0, -2)
  else
    tile.picture:SetTexture(Bricks.media("circle"))
    tile.picture:SetTexCoord(0, 1, 0, 1)
    tile.picture:SetDesaturated(false)
    tile.picture:SetVertexColor(0, 0, 0, 1)
    tile.picture:Show()
    tile.picture.path = nil
    tile.rank:ClearAllPoints()
    tile.rank:SetPoint("CENTER", tile.ring, "CENTER", 0, 0)
  end

  if learned and ROMAN[rank] then
    tile.rank:SetText(ROMAN[rank])
    tile.rank:SetTextColor(tr, tg, tb, 1)
  else
    tile.rank:SetText("")
  end

  if tile.animations then
    tile.swirl:SetVertexColor(cr, cg, cb, 0.55)
    tile.live = learned
    setAnimations(tile, learned and tile:IsShown())

    for _, texture in pairs({ tile.back, tile.swirl }) do
      if learned then
        texture:Show()
      else
        texture:Hide()
      end
    end
  end

  tile.name:SetText(spec.text or spec.label or "")

  if equipped then
    tile.name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
  elseif learned then
    tile.name:SetTextColor(cr, cg, cb, 1)
  else
    tile.name:SetTextColor(nr * DIM, ng * DIM, nb * DIM, 1)
  end

end

local function newAffixTile(owner, parent, spec)
  local tile = CreateFrame("Frame", nil, parent)

  tile.owner, tile.spec = owner, spec
  tile:SetWidth(WIDTH)
  tile:SetHeight(HEIGHT)

  local icon = spec.iconSize or ICON
  tile.scale = icon / ICON
  tile.centerTop = icon / 2 + RIM
  tile.nameTop = tile.centerTop + icon / 2 + RIM + NAME_GAP

  if peLoaded == nil then
    peLoaded = type(ProjectEbonhold) == "table"
  end

  if peLoaded then
    buildAnimated(tile)
  end

  tile.picture = tile:CreateTexture(nil, "ARTWORK")
  tile.picture:SetWidth(icon)
  tile.picture:SetHeight(icon)
  tile.picture:SetPoint("CENTER", tile, "TOP", 0, -tile.centerTop)

  tile.ring = tile:CreateTexture(nil, "BORDER")
  tile.ring:SetTexture(Bricks.media("circle"))
  tile.ring:SetWidth(icon + 2 * RIM)
  tile.ring:SetHeight(icon + 2 * RIM)
  tile.ring:SetPoint("CENTER", tile, "TOP", 0, -tile.centerTop)

  tile.rank = Bricks.text(tile, "small", "text")

  tile.name = Bricks.text(tile, "small", "text")
  tile.name:SetWidth(WIDTH)
  tile.name:SetHeight(NAME_HEIGHT)
  tile.name:SetPoint("TOP", tile, "TOP", 0, -tile.nameTop)
  tile.name:SetJustifyH("CENTER")
  tile.name:SetJustifyV("TOP")

  function tile:SetState(state)
    self.spec.state = state
    self.spec.equipped, self.spec.bagged = nil, nil
    render(self)
  end

  function tile:SetCarried(equipped, bagged)
    self.spec.state = nil
    self.spec.equipped, self.spec.bagged = equipped and true or false, bagged and true or false
    render(self)
  end

  function tile:SetRank(rank)
    self.spec.rank = rank
    render(self)
  end

  function tile:SetCategory(category)
    self.spec.category = category
    render(self)
  end

  function tile:SetName(text)
    self.spec.text = text
    render(self)
  end

  function tile:Refresh()
    render(self)
  end

  instances[tile] = true
  render(tile)

  return tile
end

if type(hooksecurefunc) == "function" then
  hooksecurefunc(EbonAPI.Bricks, "apply", function()
    for tile in pairs(instances) do
      render(tile)
    end
  end)
end

Kit.addKind("affixTile", newAffixTile, checkAffixTile)
