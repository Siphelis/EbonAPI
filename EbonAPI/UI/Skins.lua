EbonAPI = EbonAPI or {}
EbonAPI.Skins = {}

local Skins = EbonAPI.Skins
local Catalog = EbonAPI.Catalog
local Lib = EbonAPI.Lib
local Log = EbonAPI.Log
local DB = EbonAPI.DB

local type, pairs, ipairs, tostring, error = type, pairs, ipairs, tostring, error
local format, concat, find = string.format, table.concat, string.find
local sort = table.sort

local DEFAULT = "Azeroth"
local FOLDER = "Interface\\AddOns\\EbonAPI\\Skins\\"
local MEDIA = { font = true, texture = true, sound = true }
local RESERVED = { parent = true, bricks = true }
local CHAT = {
  PREFIX = "chat.prefix", TEXT = "chat.text", ERROR = "chat.error", WARN = "chat.warn",
  SUCCESS = "chat.success", HIGHLIGHT = "chat.highlight", MUTED = "chat.muted",
  GOLD = "chat.gold", SILVER = "chat.silver", COPPER = "chat.copper",
}

Skins.DEFAULT = DEFAULT
Skins.FOLDER = FOLDER

local registered = {}
local names = {}
local resolved = nil
local origins = nil
local references = nil
local bricks = nil
local active = DEFAULT
local store = nil

local function account()
  if not DB.isAttached() then
    return nil
  end

  if not store then
    store = DB.store("EbonAPI", { account = {} })
  end

  return store.account
end

local function media(skin, kind, value)
  if value == "" or find(value, "[\\/]") or (kind == "font" and value == "game")
      or (kind == "sound" and not find(value, ".", 1, true)) then
    return value
  end

  return FOLDER .. skin .. "\\" .. value
end

local function read(skin, source, prefix, problems)
  local keys = {}

  for key in pairs(source) do
    if type(key) == "string" then
      keys[#keys + 1] = key
    else
      problems[#problems + 1] = format('keys must be texts, got %s in "%s"', tostring(key),
        prefix == "" and "(root)" or prefix)
    end
  end

  sort(keys)

  for _, key in ipairs(keys) do
    if prefix ~= "" or not RESERVED[key] then
      local path = prefix == "" and key or prefix .. "." .. key
      local value = source[key]
      local entry = Catalog.entry(path)

      if entry then
        local reason = Catalog.problem(entry, value)

        if reason then
          problems[#problems + 1] = reason
        elseif skin.values[path] ~= nil then
          problems[#problems + 1] = format('parameter "%s" is given twice, flat and nested', path)
        else
          skin.values[path] = MEDIA[entry.kind] and media(skin.name, entry.kind, value) or value
        end
      elseif Catalog.isSection(path) then
        if type(value) == "table" then
          read(skin, value, path, problems)
        else
          problems[#problems + 1] = format('section "%s" expects a table, got %s', path, type(value))
        end
      else
        problems[#problems + 1] = format('unknown parameter "%s"', path)
      end
    end
  end
end

local function readBricks(skin, source, problems)
  if type(source) ~= "table" then
    problems[#problems + 1] = "bricks must be a table of slots, got " .. type(source)
    return
  end

  for _, slot in ipairs(Lib.sortedKeys(source)) do
    local list = source[slot]

    if not Catalog.slotKey(slot) then
      problems[#problems + 1] = format('unknown brick slot "%s" (known: %s)', tostring(slot),
        concat(Catalog.slotNames(), ", "))
    elseif type(list) ~= "table" then
      problems[#problems + 1] = format('brick slot "%s" expects a table of name = constructor, got %s',
        slot, type(list))
    else
      for _, name in ipairs(Lib.sortedKeys(list)) do
        local build = list[name]

        if type(name) ~= "string" or type(build) ~= "function" then
          problems[#problems + 1] = format('brick "%s.%s" must be a function, got %s', slot, tostring(name),
            type(build))
        else
          skin.bricks[slot] = skin.bricks[slot] or {}
          skin.bricks[slot][name] = build
        end
      end
    end
  end
end

local function paintChat(read)
  local COLOR = Log.COLOR

  for field, key in pairs(CHAT) do
    COLOR[field] = format("|cff%06x", read(key))
  end
end

function EbonAPI:RegisterSkin(name, spec)
  if type(name) ~= "string" or name == "" then
    error("EbonAPI: RegisterSkin expects a skin name, got " .. type(name), 2)
  end

  if type(spec) ~= "table" then
    error('EbonAPI: RegisterSkin: skin "' .. name .. '" expects a table, got ' .. type(spec), 2)
  end

  if Skins.isRegistered(name) then
    error('EbonAPI: RegisterSkin: skin "' .. name .. '" is already registered', 2)
  end

  local problems = {}
  local parent = spec.parent

  if name == DEFAULT then
    parent = nil
  elseif parent == nil then
    parent = DEFAULT
  elseif type(parent) ~= "string" then
    problems[#problems + 1] = "parent must be a skin name, got " .. type(parent)
    parent = DEFAULT
  end

  local skin = { name = name, parent = parent, values = {}, bricks = {} }

  read(skin, spec, "", problems)

  if spec.bricks ~= nil then
    readBricks(skin, spec.bricks, problems)
  end

  for _, problem in ipairs(problems) do
    Lib.report(format('EbonAPI: skin "%s": %s', name, problem))
  end

  if #problems > 0 then
    return false
  end

  registered[name] = skin
  names[#names + 1] = name

  if name == DEFAULT then
    paintChat(Skins.default)
  end

  if resolved and Skins.chosen() == name then
    Skins.resolve()
    EbonAPI.Bricks.apply()
  end

  return true
end

local function chainOf(name, loud)
  local chain, seen = {}, {}
  local at = registered[name] and name or DEFAULT

  while at do
    if seen[at] then
      if loud then
        Lib.report(format('EbonAPI: skin "%s": parent loop at "%s"', name, at))
      end

      break
    end

    local skin = registered[at]

    if not skin then
      if loud then
        Lib.report(format('EbonAPI: skin "%s": unknown parent "%s"', name, at))
      end

      break
    end

    seen[at] = true
    chain[#chain + 1] = skin
    at = skin.parent
  end

  if not seen[DEFAULT] then
    chain[#chain + 1] = registered[DEFAULT]
  end

  return chain
end

local function valueIn(chain, key)
  for _, skin in ipairs(chain) do
    local value = skin.values[key]

    if value ~= nil then
      return value, skin.name
    end
  end

  return nil
end

function Skins.resolve()
  local saved = account() and account().skin
  local name = DEFAULT

  if type(saved) == "string" and registered[saved] then
    name = saved
  elseif saved ~= nil then
    Log.trace("skin", "EbonAPI", "skin " .. tostring(saved) .. " is not installed, " .. DEFAULT .. " applies")
  end

  local chain = chainOf(name, true)

  resolved, origins, references, bricks = {}, {}, {}, {}

  for _, entry in ipairs(Catalog.LIST) do
    resolved[entry.key], origins[entry.key] = valueIn(chain, entry.key)
  end

  for _, key in ipairs(Catalog.PALETTE) do
    local path = "palette." .. key
    local source = chainOf(origins[path] or DEFAULT, false)

    references[path] = {
      background = valueIn(source, "background"),
      accent = valueIn(source, "accent"),
      opacity = valueIn(source, "opacity"),
    }
  end

  for index = #chain, 1, -1 do
    for slot, list in pairs(chain[index].bricks) do
      bricks[slot] = bricks[slot] or {}

      for brick, build in pairs(list) do
        bricks[slot][brick] = build
      end
    end
  end

  active = name
  paintChat(Skins.value)

  return name
end

local function applied()
  if not resolved then
    error("EbonAPI: the skin of the session is read before EbonAPI applies it", 3)
  end
end

function Skins.value(key)
  applied()

  return resolved[key]
end

function Skins.default(key)
  return registered[DEFAULT].values[key]
end

function Skins.defaultBrick(slot, name)
  local list = registered[DEFAULT].bricks[slot]

  return list and list[name]
end

function Skins.reference(key)
  applied()

  return references[key]
end

function Skins.brick(slot, name)
  applied()

  local list = bricks[slot]

  return list and list[name]
end

function Skins.isRegistered(name)
  return registered[name] ~= nil
end

function Skins.list()
  local out, others = { DEFAULT }, {}

  for _, name in ipairs(names) do
    if name ~= DEFAULT then
      others[#others + 1] = name
    end
  end

  sort(others)

  for _, name in ipairs(others) do
    out[#out + 1] = name
  end

  return out
end

function Skins.active()
  return active
end

function Skins.chosen()
  local saved = account() and account().skin

  if type(saved) == "string" and registered[saved] then
    return saved
  end

  return DEFAULT
end

function Skins.choose(name)
  if not registered[name] then
    error('EbonAPI: unknown skin "' .. tostring(name) .. '" (known: ' .. concat(Skins.list(), ", ") .. ")", 2)
  end

  local saved = account()

  if not saved then
    return false
  end

  saved.skin = name ~= DEFAULT and name or nil

  return true
end

function Skins.pending()
  return Skins.chosen() ~= active
end
