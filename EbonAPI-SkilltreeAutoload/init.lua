SkillTreeAutoLoad = SkillTreeAutoLoad or {}
local NS = SkillTreeAutoLoad
local tonumber, tostring = tonumber, tostring

NS.api = EbonAPI and EbonAPI:NewAddon("SkillTreeAutoLoad", 0, 5, { icon = "Ability_Druid_ImprovedTreeForm" }) or nil

NS.SNAPSHOT_TTL = 0.2
NS.ASHES_POLL_INTERVAL = 0.5
-- Highest rank a save may hold (an infinite node); data, core and the share code all use it.
NS.MAX_RANK = 5000

NS.COLOR = {
    PREFIX = "|cff33ccff",
    ERROR = "|cffff4444",
    WARN = "|cffff9900",
    SUCCESS = "|cff40ff40",
    HIGHLIGHT = "|cffffd200",
    DIM = "|cff808080",
    RESET = "|r",
}

local COLOR = NS.COLOR

function NS.HexToRGB(hex)
    local r, g, b = tostring(hex or ""):match("^(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

function NS.Colorize(color, text)
    return color .. tostring(text) .. COLOR.RESET
end

