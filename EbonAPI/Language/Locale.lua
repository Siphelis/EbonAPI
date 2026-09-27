EbonAPI = EbonAPI or {}
EbonAPI.Locale = {}

local Locale = EbonAPI.Locale
local Lib = EbonAPI.Lib
local Handle = EbonAPI.Handle

local type, pairs, setmetatable, error = type, pairs, setmetatable, error

local BASE_LANGUAGE = "enUS"

local ALIASES = {
  esMX = "esES",
}

Locale.BASE_LANGUAGE = BASE_LANGUAGE

local registries = {}
local tables = {}
local activeLanguage = BASE_LANGUAGE

local WEAK = { __mode = "k" }
local boundOwner = setmetatable({}, WEAK)
local boundKey = setmetatable({}, WEAK)

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
    error("EbonAPI: Locale.register expects an addon name, got " .. type(owner), 3)
  end

  if type(translations) ~= "table" then
    error("EbonAPI: the translations of '" .. owner .. "' must be a table, got "
      .. type(translations), 3)
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

function Locale.available()
  local seen = {}
  local list = {}

  for _, registry in pairs(registries) do
    for code, entries in pairs(registry) do
      if not seen[code] then
        seen[code] = true
        list[#list + 1] = {
          code = code,
          name = (type(entries) == "table" and entries.LOCALE_NAME) or code,
        }
      end
    end
  end

  table.sort(list, function(a, b)
    return a.name < b.name
  end)

  return list
end

function Locale.isAvailable(code)
  for _, registry in pairs(registries) do
    if registry[code] then
      return true
    end
  end

  return false
end

local function canonical(code)
  if type(code) ~= "string" or Locale.isAvailable(code) then
    return code
  end

  return ALIASES[code] or code
end

function Locale.refreshWidgets()
  for widget, key in pairs(boundKey) do
    local L = tables[boundOwner[widget]]

    widget:SetText((L and L[key]) or key)
  end
end

function EbonAPI:SetLanguage(code, persist)
  code = canonical(code)

  if type(code) ~= "string" or not Locale.isAvailable(code) then
    return false
  end

  if code == activeLanguage then
    return true
  end

  activeLanguage = code

  fillAll()
  Locale.refreshWidgets()

  if persist ~= false and EbonAPI.DB.isAttached() then
    EbonAPI.DB.shared().account.language = code
  end

  self:Emit("LANGUAGE_CHANGED", code)

  return true
end

function EbonAPI:GetLanguage()
  return activeLanguage
end

function EbonAPI:GetAvailableLanguages()
  return Locale.available()
end

function EbonAPI:IsLanguageChosen()
  return EbonAPI.DB.isAttached() and type(EbonAPI.DB.shared().account.language) == "string"
end

function Locale.applyPersisted()
  local saved = EbonAPI.DB.shared().account.language

  if type(saved) == "string" and Locale.isAvailable(saved) then
    if saved ~= activeLanguage then
      activeLanguage = saved
      fillAll()
      Locale.refreshWidgets()
      EbonAPI:Emit("LANGUAGE_CHANGED", saved)
    end

    return saved
  end

  return activeLanguage
end

function Locale.bind(owner, widget, key)
  if type(key) ~= "string" then
    error("EbonAPI: Localized expects a translation key, got " .. type(key), 3)
  end

  if not widget or not widget.SetText then
    error("EbonAPI: Localized expects a widget with SetText for the key '" .. key .. "'", 3)
  end

  boundOwner[widget] = owner
  boundKey[widget] = key

  local L = tables[owner]
  widget:SetText((L and L[key]) or key)

  return widget
end

Locale.register("EbonAPI", EbonAPILocales or {})

local clientLanguage = canonical((GetLocale and GetLocale()) or BASE_LANGUAGE)

if Locale.isAvailable(clientLanguage) then
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

function Handle:IsLanguageChosen()
  return EbonAPI:IsLanguageChosen()
end
