
local D = EbonAPI.Decoders

local function failResult(body)
  if body == "FAIL" then return { ok = false } end
  local head, reason = string.match(body, "^([^,]+),(.+)$")
  if head == "FAIL" then return { ok = false, reason = reason } end
  return nil, "corps ni OK ni FAIL[,raison]"
end

local function okFail(body)
  if type(body) ~= "string" then return nil, "corps non chaine" end
  if body == "OK" then return { ok = true } end
  return failResult(body)
end

local REASON_PATTERNS = {
  ["You need to be close to an Enchanted Anvil."] = "anvilTooFar",
}

local function normalizeReason(text)
  local t = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  t = string.gsub(t, "|r", "")
  t = string.gsub(t, "^%s+", "")
  return (string.gsub(t, "%s+$", ""))
end

local function applyResult(body)
  local result, err = okFail(body)
  if result and result.reason then
    result.pattern = REASON_PATTERNS[normalizeReason(result.reason)]
  end
  return result, err
end

local function cost(body)
  if type(body) ~= "string" then return nil, "corps non chaine" end
  local n = tonumber(body)
  if not n then return nil, "cout non numerique" end
  return { cost = n }
end

D.register(510, { name = "SEND_AFFIX_EXTRACTION_RESULT", family = "Extraction", mode = "event",
  decode = function(body) return okFail(body) end })

D.register(511, { name = "SEND_AFFIX_EXTRACTION_INFO", family = "Extraction", mode = "event",
  decode = function(body) return cost(body) end })

D.register(512, { name = "SEND_AFFIX_APPLY_RESULT", family = "Extraction", mode = "event",
  decode = function(body) return applyResult(body) end })

D.register(513, { name = "SEND_LEARNED_AFFIXES", family = "Extraction", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "corps non chaine" end
    if string.find(body, "[^%d,%s]") then return nil, "caractere inattendu dans la liste d'ids" end
    local ids = {}
    for id in string.gmatch(body, "(%d+)") do ids[#ids + 1] = tonumber(id) end
    return { spellIds = ids }
  end })

D.register(514, { name = "SEND_AFFIX_APPLY_INFO", family = "Extraction", mode = "event",
  decode = function(body) return cost(body) end })

D.register(516, { name = "SEND_LEGENDARY_UPGRADE_INFO", family = "Extraction", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "corps non chaine" end
    if body == "NONE" then return { none = true } end
    local t, n, h, e, label = string.match(body, "^(%d+),(%d+),(%d+),(%d+),(.+)$")
    if not t then return nil, "corps ni NONE ni tokenId,needed,held,nextEntry,label" end
    return { none = false, tokenId = tonumber(t), needed = tonumber(n), held = tonumber(h),
             nextEntry = tonumber(e), label = label, bracket = math.floor(tonumber(e) / 1000000) }
  end })

D.register(517, { name = "SEND_LEGENDARY_UPGRADE_RESULT", family = "Extraction", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then return nil, "corps non chaine" end
    local status, rest = string.match(body, "^([^,]+),?(.*)$")
    if status == "OK" then
      local n = tonumber(rest)
      if not n then return nil, "OK sans entree numerique" end
      return { ok = true, newEntry = n }
    elseif status == "FAIL" then
      if rest == "" then rest = nil end
      return { ok = false, reason = rest }
    end
    return nil, "statut inconnu"
  end })
