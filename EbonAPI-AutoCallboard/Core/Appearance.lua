local Core = AutoCallboardCore

local DEFAULT = { arrowScale = 1, arrowFont = 10, arrowSkin = "sheet" }
local LIMIT = { arrowScale = {0.25, 2} }
local ARROW_FONT_SIZES = { 8, 9, 10, 11, 12, 14, 16, 18, 20 }

Core.ARROW_FONT_SIZES = ARROW_FONT_SIZES

function Core.isArrowFontSize(size)
  for _, known in ipairs(ARROW_FONT_SIZES) do
    if size == known then return true end
  end
  return false
end

function Core.copyAppearance(source)
  local result = {}
  source = type(source) == 'table' and source or {}
  for key, default in pairs(DEFAULT) do
    local given = source[key]
    local value, limit = given, LIMIT[key]
    if type(value) ~= type(default) or (limit and (value ~= value or value < limit[1] or value > limit[2])) then value = default end
    if key == 'arrowSkin' then
      value = Core.sanitizeArrowSkin(value) or default
    elseif key == 'arrowFont' then
      if not Core.isArrowFontSize(value) then value = default end
    end
    if given ~= nil and value ~= given and not (key == 'arrowSkin' and type(given) == 'string') then
      Core.repaired("STATE.REPAIRED", { field = key, setting = key, value = tostring(given) }, given)
    end
    result[key] = value
  end
  return result
end

Core.TOOLBAR_ACTIONS = {"builds", "callboard", "start", "share", "eternals", "settings", "instance", "routes"}
local TOOLBAR_KNOWN = {}
for _, key in ipairs(Core.TOOLBAR_ACTIONS) do TOOLBAR_KNOWN[key] = true end

function Core.copyToolbar(source)
  if source ~= nil and type(source) ~= "table" then
    Core.repaired("STATE.REPAIRED", { field = "toolbar", setting = "toolbar", value = type(source) }, source)
  end
  local result, seen = {}, {}
  for _, key in ipairs(type(source) == "table" and source or {}) do
    if TOOLBAR_KNOWN[key] and not seen[key] then
      result[#result + 1], seen[key] = key, true
    end
  end
  if #result == 0 then return {"builds", "callboard", "start", "share"} end
  return result
end
