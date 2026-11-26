local _, ns = ...

ns.LocaleTables = ns.LocaleTables or {}
local tables = ns.LocaleTables

function ns.L(key)
  local t = tables[GetLocale()]
  local value = t and t[key]
  if value == nil then
    t = tables.enUS
    value = t and t[key]
  end
  if value == nil then
    return key
  end
  return value
end
