EbonAPI = EbonAPI or {}
EbonAPI.Locale = {}

local Locale = EbonAPI.Locale
local Handle = EbonAPI.Handle

local type, pairs, error = type, pairs, error

local BASE_LANGUAGE = "enUS"

local ALIASES = {
  esMX = "esES",
}

Locale.BASE_LANGUAGE = BASE_LANGUAGE

local registries = {}
local tables = {}
local activeLanguage = BASE_LANGUAGE

local function fill(owner)
  local registry = registries[owner]
  local L = tables[owner]

  if not registry or not L then
    return
  end

  for key in pairs(L) do
    L[key] = nil
  end

  local base = registry[BASE_LANGUAGE]

  if type(base) == "table" then
    for key, value in pairs(base) do
      L[key] = value
    end
  end

  if activeLanguage ~= BASE_LANGUAGE then
    local chosen = registry[activeLanguage]

    if type(chosen) == "table" then
      for key, value in pairs(chosen) do
        L[key] = value
      end
    end
  end
end

local function fillAll()
  for owner in pairs(registries) do
    fill(owner)
  end
end
function Locale.register(owner, translations)
  if type(owner) ~= "string" then
    error("EbonAPI: Locale.register expects an addon name, got " .. type(owner), 2)
  end

  if type(translations) ~= "table" then
    error("EbonAPI: " .. owner .. ": api:Locale expects a table of translations, got "
      .. type(translations), 2)
  end

  local registry = registries[owner]

  if not registry then
    registry = {}
    registries[owner] = registry
    tables[owner] = {}
  end

  for code, entries in pairs(translations) do
    if type(entries) == "table" then
      local existing = registry[code]

      if type(existing) ~= "table" then
        existing = {}
        registry[code] = existing
      end

      for key, value in pairs(entries) do
        existing[key] = value
      end
    end
  end

  fill(owner)

  return tables[owner]
end

function Locale.get(owner)
  return tables[owner]
end

function Locale.current()
  return activeLanguage
end

local function isAvailable(code)
  for _, registry in pairs(registries) do
    if registry[code] then
      return true
    end
  end

  return false
end

local function canonical(code)
  if type(code) ~= "string" or isAvailable(code) then
    return code
  end

  return ALIASES[code] or code
end

function EbonAPI:GetLanguage()
  return activeLanguage
end

function Locale.bind(owner, widget, key)
  if type(key) ~= "string" then
    error("EbonAPI: " .. owner .. ": api:Localized expects a translation key, got " .. type(key), 2)
  end

  if type(widget) ~= "table" or type(widget.SetText) ~= "function" then
    error("EbonAPI: " .. owner .. ": api:Localized expects a widget with SetText for the key '" .. key
      .. "', got " .. type(widget), 2)
  end

  local L = tables[owner]
  widget:SetText((L and L[key]) or key)

  return widget
end

Locale.register("EbonAPI", EbonAPILocales or {})

local clientLanguage = canonical(GetLocale and GetLocale() or BASE_LANGUAGE)

if isAvailable(clientLanguage) then
  activeLanguage = clientLanguage
  fillAll()
end

EbonAPI.L = tables["EbonAPI"]

function Handle:Locale(translations)
  return Locale.register(self.addonName, translations)
end

function Handle:L()
  return Locale.get(self.addonName)
end

function Handle:Localized(widget, key)
  return Locale.bind(self.addonName, widget, key)
end

function Handle:GetLanguage()
  return activeLanguage
end
