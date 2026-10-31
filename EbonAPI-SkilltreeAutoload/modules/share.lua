local NS = SkillTreeAutoLoad
local L = NS.L

-- Export and import of saves between accounts.
-- Code = "STAL1:" .. base64(body) .. checksum, where the checksum is the EbonAPI.Hash digest of the base64 text.
-- Body, as bytes: varint saveCount, then per save: name, progressive (0/1), group name (empty = none),
-- varint nodeCount, then per node: varint id, varint rank. A name is a varint length and its bytes.
-- A varint is 7 bits per byte, low bytes first, the high bit set when more follow.

local Share = {}
NS.Share = Share

local byte, char, sub, gsub, concat, floor = string.byte, string.char, string.sub, string.gsub, table.concat, math.floor

local PREFIX = "STAL1:"
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local MAX_SAVES, MAX_NODES, MAX_NAME = 500, 5000, 255

-- The bit reader and writer share these: bits not yet used or not yet written, and how many there are.
local acc, bits = 0, 0

--------------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------------

local out

local function PutByte(value)
    acc, bits = acc * 256 + value, bits + 8
    while bits >= 6 do
        bits = bits - 6
        local unit = 2 ^ bits
        local digit = floor(acc / unit)
        acc = acc - digit * unit
        out[#out + 1] = sub(ALPHABET, digit + 1, digit + 1)
    end
end

local function PutVarint(value)
    while value >= 128 do
        PutByte(value % 128 + 128)
        value = floor(value / 128)
    end
    PutByte(value)
end

local function PutString(text)
    PutVarint(#text)
    for i = 1, #text do PutByte(byte(text, i)) end
end

local function Encode(saveIds)
    out, acc, bits = {}, 0, 0

    PutVarint(#saveIds)
    for _, saveId in ipairs(saveIds) do
        local save = NS.Data.GetSave(saveId)
        local group = save.groupId and NS.Data.GetGroup(save.groupId)
        local count = 0
        for _ in pairs(save.nodeRanks) do count = count + 1 end

        PutString(save.name)
        PutByte(save.progressive and 1 or 0)
        PutString(group and group.name or "")
        PutVarint(count)
        for nodeId, rank in pairs(save.nodeRanks) do
            PutVarint(nodeId)
            PutVarint(rank)
        end
    end
    if bits > 0 then
        local digit = acc * 2 ^ (6 - bits)
        out[#out + 1] = sub(ALPHABET, digit + 1, digit + 1)
    end

    local body = concat(out)
    out = nil
    return PREFIX .. body .. EbonAPI.Hash.digest(body)
end

--------------------------------------------------------------------------------
-- Reading: one pass over the text, every check on the way. A refusal is raised as { code, facts }.
--------------------------------------------------------------------------------

local digitOf
local text, position

local function Refuse(code, facts)
    error({ code = code, facts = facts }, 0)
end

local function NextByte()
    while bits < 8 do
        local digit = digitOf[byte(text, position)]
        if position > #text then Refuse("IMPORT.CODE_INVALID", { what = "truncated" }) end
        if not digit then Refuse("IMPORT.CODE_UNREADABLE") end
        acc, bits, position = acc * 64 + digit, bits + 6, position + 1
    end
    bits = bits - 8
    local unit = 2 ^ bits
    local value = floor(acc / unit)
    acc = acc - value * unit
    return value
end

local function NextVarint(what)
    local value, scale = 0, 1
    for _ = 1, 5 do
        local b = NextByte()
        value = value + b % 128 * scale
        if b < 128 then return value end
        scale = scale * 128
    end
    Refuse("IMPORT.CODE_INVALID", { what = what })
end

local function NextName(what)
    local length = NextVarint(what)
    if length > MAX_NAME then Refuse("IMPORT.CODE_TOO_MANY", { what = what, count = length, max = MAX_NAME }) end
    local chars = {}
    for i = 1, length do chars[i] = char(NextByte()) end
    return (gsub(gsub(concat(chars), "[%c|]", " "), "^%s*(.-)%s*$", "%1"))
end

local function NextCount(what, max)
    local count = NextVarint(what)
    if count > max then Refuse("IMPORT.CODE_TOO_MANY", { what = what, count = count, max = max }) end
    return count
end

local function NextSave()
    local save = { name = NextName("save name") }
    if save.name == "" then Refuse("IMPORT.CODE_INVALID", { what = "empty save name" }) end

    local flag = NextByte()
    if flag > 1 then Refuse("IMPORT.CODE_INVALID", { what = "progressive flag" }) end
    save.progressive = flag == 1

    local group = NextName("group name")
    save.group = group ~= "" and group or nil

    local ranks = {}
    for _ = 1, NextCount("nodes", MAX_NODES) do
        local nodeId, rank = NextVarint("node"), NextVarint("rank")
        if nodeId == 0 or ranks[nodeId] then Refuse("IMPORT.CODE_INVALID", { what = "node " .. nodeId }) end
        if rank == 0 then Refuse("IMPORT.CODE_INVALID", { what = "rank 0 on node " .. nodeId }) end
        if rank > NS.MAX_RANK then
            Refuse("IMPORT.CODE_RANK_TOO_HIGH", { save = save.name, rank = rank, max = NS.MAX_RANK })
        end
        ranks[nodeId] = rank
    end
    save.ranks = ranks
    return save
end

local function Read()
    local saves = {}
    for i = 1, NextCount("saves", MAX_SAVES) do saves[i] = NextSave() end
    if #saves == 0 or position <= #text then Refuse("IMPORT.CODE_INVALID", { what = "saves" }) end
    return saves
end

-- Returns the saves held by a code, or nil and the problem that refuses it. Nothing is created here.
local function Decode(code)
    code = gsub(code, "%s", "")
    if code == "" then return nil, "IMPORT.CODE_EMPTY" end
    if sub(code, 1, #PREFIX) ~= PREFIX then
        local version = code:match("^STAL(%d+):")
        if version then return nil, "IMPORT.CODE_VERSION", { version = version } end
        return nil, "IMPORT.CODE_UNREADABLE"
    end

    local length = #code - #PREFIX - EbonAPI.Hash.LENGTH
    text = sub(code, #PREFIX + 1, #PREFIX + length)
    if length < 0 or EbonAPI.Hash.digest(text) ~= sub(code, -EbonAPI.Hash.LENGTH) then
        return nil, "IMPORT.CODE_DAMAGED"
    end

    if not digitOf then
        digitOf = {}
        for i = 1, #ALPHABET do digitOf[byte(ALPHABET, i)] = i - 1 end
    end
    acc, bits, position = 0, 0, 1

    local ok, saves = pcall(Read)
    text = nil
    if ok then return saves end
    if type(saves) ~= "table" then error(saves, 0) end
    return nil, saves.code, saves.facts
end

--------------------------------------------------------------------------------
-- Dialogs
--------------------------------------------------------------------------------

local function Import(code)
    local saves, problem, facts = Decode(code)
    if not saves then return NS.api:ProblemText(NS.api:Problem(problem, facts)) end

    for _, save in ipairs(saves) do
        NS.Data.ImportSave(save.name, save.progressive, save.group, save.ranks)
    end
    NS.UI.RefreshList()
    NS.api:Notify(string.format(L.MSG_IMPORTED, #saves))
end

local function ShowExport(saveIds)
    if #saveIds == 0 then
        NS.api:Notify(L.MSG_EXPORT_NONE)
        return
    end
    NS.api:Dialog({
        title = L.EXPORT_TITLE,
        text = L.EXPORT_HELP,
        copy = Encode(saveIds),
        copyButton = L.EXPORT_COPY,
        accept = L.EXPORT_CLOSE,
    })
end

function Share.ShowExportSave(saveId)
    ShowExport(NS.Data.GetSave(saveId) and { saveId } or {})
end

function Share.ShowExportAll()
    local ids = {}
    for _, saveId in ipairs(NS.Data.GetSortedSaveIdsInGroup(nil)) do ids[#ids + 1] = saveId end
    for _, groupId in ipairs(NS.Data.GetSortedGroupIds()) do
        for _, saveId in ipairs(NS.Data.GetSortedSaveIdsInGroup(groupId)) do ids[#ids + 1] = saveId end
    end
    ShowExport(ids)
end

function Share.ShowImport()
    NS.api:Dialog({
        title = L.IMPORT_TITLE,
        input = "",
        lines = 8,
        placeholder = L.IMPORT_PLACEHOLDER,
        accept = L.IMPORT_ACCEPT,
        cancel = L.POPUP_CANCEL,
        onSubmit = Import,
    })
end
