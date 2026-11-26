EbonAPI = EbonAPI or {}

local PE_SS = {
  SEND_ACKNOWLEDGEMENT                       = 0,
  SEND_SHOP_DATA                             = 1,
  SEND_ACCOUNT_DP                            = 2,
  SEND_LOADOUTS                              = 3,
  SEND_CREATED_LOADOUT                       = 4,
  SEND_UPDATED_LOADOUT                       = 5,
  SEND_SKILL_TREE_UPDATE_SPELL_CAST_RESULT   = 6,
  SEND_INSTANCE_ENTERED                      = 9,
  SEND_INSTANCE_ENCOUNTERS_COMPLETED         = 10,
  SEND_INSTANCE_ENCOUNTERS_HIDE              = 11,
  SEND_JUNK_SOLD                             = 12,
  SEND_PLAYER_RUN_DATA                       = 13,
  SEND_PLAYER_SOUL_POINTS_MULTIPLIER         = 14,
  SEND_PLAYER_UPDATED_COMMITTED_SOUL_POINTS  = 15,
  SEND_PLAYER_PERK_CHOICE                    = 16,
  SEND_PLAYER_PERK_SELECTION_RESULT          = 1000,
  SEND_PLAYER_PERK_GRANTED                   = 18,
  SEND_PLAYER_ITEMS_SAVED                    = 21,
  SEND_PLAYER_SPEC_INDEX                     = 32,
  SEND_WRONG_PATCH                           = 33,
  SEND_CONTENT_VOID_STORAGE                  = 100,
  SEND_BANISH_REPLACEMENT_PERK               = 103,
  SEND_FREEZE_PERK_RESULT                    = 104,
  SEND_PERK_BANISHED                         = 1224,
  SEND_HARDMODE_DATA                         = 500,
  SEND_HARDMODE_SET_RESULT                   = 501,
  SEND_HARDCORE_TIER_UNLOCKED                = 502,
  SEND_INSTANCE_TORMENT                      = 503,
  SEND_HARDMODE_GM_STATE                     = 504,
  SEND_AFFIX_EXTRACTION_RESULT               = 510,
  SEND_AFFIX_EXTRACTION_INFO                 = 511,
  SEND_AFFIX_APPLY_RESULT                    = 512,
  SEND_LEARNED_AFFIXES                       = 513,
  SEND_AFFIX_APPLY_INFO                      = 514,
  SEND_UNLEARN_SPELL_RESULT                  = 515,
  SEND_LEGENDARY_UPGRADE_INFO                = 516,
  SEND_LEGENDARY_UPGRADE_RESULT              = 517,
  SEND_GM_TICKET_CREATE_RESULT               = 520,
  SEND_ECHO_DISCOVERY                        = 530,
  SEND_ECHO_LOADOUTS_SHARED                  = 531,
  SEND_PERK_LOADOUTS                         = 540,
  SEND_PERK_LOADOUT_RESULT                   = 541,
  SEND_PERK_LOADOUT_ACTIVE                   = 542,
  SEND_ACTION_TRACKER_INFO                   = 700,
  SEND_CHECKPOINTS_DATA                      = 800,
  SEND_PLAYER_IS_BLOCKED                     = 900,
  SEND_RAID_BOSS_OVERFLOW_HEALTH             = 950,
  SEND_COLLECTED_MOUNTS                      = 1100,
  SEND_COLLECTED_PETS                        = 1101,
  SEND_COLLECTED_APPEARANCES                 = 1102,
  SEND_TRANSMOG_SLOTS                        = 1103,
  SEND_MOUNT_LEARNED                         = 1104,
  SEND_PET_LEARNED                           = 1105,
  SEND_APPEARANCE_LEARNED                    = 1106,
  SEND_TRANSMOG_SLOT_UPDATE                  = 1107,
  SEND_TRANSMOG_OUTFITS                      = 1108,
  SEND_FORM_LOOK_STATE                       = 1109,
  SEND_PRESTIGE_DATA                         = 1200,
  SEND_PRESTIGE_RESULT                       = 1201,
  SEND_XP_AURA_BONUS_STATE                   = 1210,
  SEND_ORB_CHARGES                           = 1220,
  SEND_CLASS_TREE_DATA                       = 1230,
  SEND_CLASS_NODE_RESULT                     = 1231,
  SEND_CLASS_LEVEL_UP                        = 1232,
  SEND_CLASS_TREE_PROGRESS                   = 1233,
  SEND_REAPER_STATE                          = 1235,
  SEND_CONTRACTS                             = 1237,
  SEND_CALLBOARD_DATA                        = 1240,
  SEND_CALLBOARD_RESULT                      = 1241,
  SEND_LFG_TORMENT_DATA                      = 1250,
  SEND_LFG_TORMENT_RESULT                    = 1251,
  SEND_LFG_QUEUE_STATE                       = 1252,
  SEND_RAID_FINDER_DATA                      = 1258,
  SEND_RAID_FINDER_STATE                     = 1259,
  SEND_RAID_FINDER_RESULT                    = 1265,
  SEND_LFG_TIER_COUNTS                       = 1268,
  SEND_TRIAL_STATE                           = 1260,
  SEND_TRIAL_RESULT                          = 1261,
  SEND_TRIAL_LEADERBOARD                     = 1262,
  SEND_TOOLBELT_STATE                        = 1270,
  SEND_TOOLBELT_RESULT                       = 1271,
  SEND_RAID_LOOT_LOCKOUTS                    = 1292,
  SEND_INSTANCE_TRACKER                      = 1293,
  SEND_TORMENT_PORTALS                       = 1294,
  SEND_TORMENT_PORTAL_STATE                  = 1295,
  SEND_TORMENT_PORTAL_SEEN                   = 1296,
  SEND_TORMENT_PORTAL_USED                   = 1297,
  SEND_SPEC_TALENTS                          = 1300,
  SEND_TALENT_PLAN_RESULT                    = 1301,
}

local PE_CS = {
  SEND_HI                                    = 0,
  REQUEST_SHOP_DATA                          = 1,
  REQUEST_SHOP_PURCHASE                      = 2,
  REQUEST_ACCOUNT_DP                         = 3,
  REQUEST_SELL_JUNK_ITEMS                    = 4,
  REQUEST_LOADOUTS                           = 5,
  REQUEST_CREATE_LOADOUT                     = 7,
  REQUEST_LOADOUT_DELETE                     = 9,
  REQUEST_LOADOUT_SELECT                     = 10,
  REQUEST_AVOID_RESET_WITH_SOUL_POINTS       = 12,
  REQUEST_AVOID_RESET_WITH_SELF_REZ          = 13,
  REQUEST_PLAYER_RUN_DATA                    = 14,
  REQUEST_PLAYER_SOUL_POINTS_ADDITIONAL_PCT  = 15,
  REQUEST_PLAYER_PERK_CHOICE                 = 16,
  REQUEST_PLAYER_PERK_SELECTION              = 17,
  REQUEST_PLAYER_GRANTED_PERKS               = 18,
  REQUEST_PLAYER_ADD_ITEM_ITEM_SAVED         = 19,
  REQUEST_PLAYER_ITEMS_SAVED                 = 20,
  REQUEST_APPLY_SPECS                        = 23,
  REQUEST_CURRENT_SPEC                       = 24,
  REQUEST_RESET_TALENT_TREE                  = 25,
  REQUEST_ACCEPT_DEATH                       = 26,
  REQUEST_DEATH_SELL_ITEM                    = 11,
  REQUEST_REROLL                             = 27,
  REQUEST_LOADOUT_UPDATE                     = 28,
  REQUEST_VERSION_CHECK                      = 29,
  REQUEST_LOCK_PERK                          = 30,
  REQUEST_UNLOCK_PERK                        = 31,
  REQUEST_SET_USING_VOID_STORAGE             = 50,
  REQUEST_RETRIEVE_VOID_STORAGE_ITEM         = 51,
  REQUEST_RETRIEVE_ITEMS_FROM_TAB            = 52,
  REQUEST_UNLOCK_PLAYER                      = 202,
  REQUEST_BANISH_PERK                        = 203,
  REQUEST_DEV_ADD_PERK_STACK                 = 204,
  REQUEST_DEV_REMOVE_PERK_STACK              = 205,
  REQUEST_FREEZE_PERK                        = 207,
  REQUEST_HARDMODE_DATA                      = 300,
  REQUEST_HARDMODE_SET_DIFFICULTY            = 301,
  REQUEST_AFFIX_EXTRACTION                   = 310,
  REQUEST_AFFIX_EXTRACTION_INFO              = 311,
  REQUEST_AFFIX_APPLY                        = 312,
  REQUEST_LEARNED_AFFIXES                    = 313,
  REQUEST_AFFIX_APPLY_INFO                   = 314,
  REQUEST_UNLEARN_SPELL_ECHOES               = 315,
  REQUEST_LEGENDARY_UPGRADE_INFO             = 316,
  REQUEST_LEGENDARY_UPGRADE                  = 317,
  REQUEST_CREATE_GM_TICKET                   = 320,
  REQUEST_ECHO_DISCOVERY                     = 330,
  REQUEST_ECHO_LOADOUTS_SHARED               = 331,
  REQUEST_ECHO_LOADOUT_PUBLISH               = 332,
  REQUEST_ECHO_LOADOUT_UNPUBLISH             = 333,
  REQUEST_PERK_LOADOUTS                      = 340,
  REQUEST_PERK_LOADOUT_SAVE                  = 341,
  REQUEST_PERK_LOADOUT_RENAME                = 342,
  REQUEST_PERK_LOADOUT_DELETE                = 343,
  REQUEST_PERK_LOADOUT_ACTIVATE              = 344,
  REQUEST_PERK_LOADOUT_UNLOCK                = 345,
  REQUEST_PERK_LOADOUT_UPLOAD                = 346,
  REQUEST_TOME_TOGGLE                        = 347,
  REQUEST_PERK_LOADOUT_RECOVER               = 348,
  REQUEST_PERK_MEMORY_DRAW                   = 349,
  REQUEST_HIDDEN_VISUALS_SET                 = 350,
  REQUEST_ACTION_TRACKER_INFO                = 600,
  REQUEST_CHECKPOINTS_DATA                   = 800,
  REQUEST_USE_CHECKPOINT                     = 801,
  REQUEST_CANCEL_CHECKPOINT                  = 802,
  REQUEST_COLLECTIONS                        = 1100,
  REQUEST_SUMMON_MOUNT                       = 1110,
  REQUEST_SUMMON_PET                         = 1111,
  REQUEST_APPLY_TRANSMOG                     = 1112,
  REQUEST_CLEAR_TRANSMOG                     = 1113,
  REQUEST_APPLY_ILLUSION                     = 1114,
  REQUEST_FORM_LOOK_SET                      = 1115,
  REQUEST_UNLOCK_APPEARANCE                  = 1116,
  REQUEST_OUTFITS                            = 1120,
  REQUEST_OUTFIT_SAVE                        = 1121,
  REQUEST_OUTFIT_RENAME                      = 1122,
  REQUEST_OUTFIT_DELETE                      = 1123,
  REQUEST_OUTFIT_APPLY                       = 1124,
  REQUEST_CREATURE_CACHE                     = 1130,
  REQUEST_PRESTIGE_DATA                      = 1200,
  REQUEST_DO_PRESTIGE                        = 1201,
  REQUEST_XP_AURA_BONUS_STATE                = 1210,
  REQUEST_XP_AURA_BONUS_SET                  = 1211,
  REQUEST_ORB_CHARGES                        = 1220,
  REQUEST_ORB_CONSUME                        = 1221,
  REQUEST_ORB_REROLL                         = 1222,
  REQUEST_CLASS_TREE_DATA                    = 1230,
  REQUEST_CLASS_NODE_BUY                     = 1231,
  REQUEST_REAPER_STATE                       = 1235,
  REQUEST_SUMMON_REAPER                      = 1236,
  REQUEST_CONTRACTS                          = 1237,
  REQUEST_CONTRACT_ACTION                    = 1238,
  REQUEST_SOUL_BANK                          = 1239,
  REQUEST_CALLBOARD_DATA                     = 1240,
  REQUEST_CALLBOARD_ACCEPT                   = 1241,
  REQUEST_CALLBOARD_CLAIM                    = 1242,
  REQUEST_CALLBOARD_START_ZONE               = 1243,
  REQUEST_LFG_TORMENT_DATA                   = 1250,
  REQUEST_LFG_TORMENT_SET                    = 1251,
  REQUEST_LFG_MODE_SET                       = 1253,
  REQUEST_RAID_FINDER_DATA                   = 1254,
  REQUEST_RAID_FINDER_ROLES                  = 1255,
  REQUEST_RAID_FINDER_JOIN                   = 1256,
  REQUEST_RAID_FINDER_LEAVE                  = 1257,
  REQUEST_RAID_FINDER_ANSWER                 = 1266,
  REQUEST_RAID_FINDER_SEARCH                 = 1267,
  REQUEST_RAID_FINDER_TELEPORT               = 1269,
  REQUEST_TRIAL_STATE                        = 1260,
  REQUEST_TRIAL_START                        = 1261,
  REQUEST_TRIAL_RETRY                        = 1262,
  REQUEST_TRIAL_LEAVE                        = 1263,
  REQUEST_TRIAL_LEADERBOARD                  = 1264,
  REQUEST_TOOLBELT_STATE                     = 1270,
  REQUEST_TOOLBELT_OPEN_BANK                 = 1271,
  REQUEST_TOOLBELT_SELL                      = 1272,
  REQUEST_TOOLBELT_REPAIR                    = 1273,
  REQUEST_TOOLBELT_OPEN_MAIL                 = 1274,
  REQUEST_TOOLBELT_LOOT_SET                  = 1275,
  REQUEST_WAYSTONE_SET                       = 1276,
  REQUEST_WAYSTONE_USE                       = 1277,
  REQUEST_TOOLBELT_OPEN_AUCTION              = 1278,
  REQUEST_TOOLBELT_GUILD_BANK                = 1279,
  REQUEST_TOOLBELT_FORGE                     = 1281,
  REQUEST_TOOLBELT_OPEN_MERCHANT             = 1282,
  REQUEST_SOUL_ANCHOR                        = 1280,
  REQUEST_INSTANCE_TRACKER                   = 1293,
  REQUEST_TORMENT_PORTALS                    = 1294,
  REQUEST_SPEC_TALENTS                       = 1300,
  REQUEST_APPLY_TALENT_PLAN                  = 1301,
  REQUEST_OVERFLOW_HEALTH                    = 1310,
}

EbonAPI.Opcodes = {}
local Opcodes = EbonAPI.Opcodes

Opcodes.ALIASES = {
  SS = {
    SKILL_TREE_UPDATE_SPELL_CAST_RESULT      = "SEND_SKILL_TREE_UPDATE_SPELL_CAST_RESULT",
    INSTANCE_ENTERED                         = "SEND_INSTANCE_ENTERED",
    INSTANCE_ENCOUNTERS_COMPLETED            = "SEND_INSTANCE_ENCOUNTERS_COMPLETED",
    JUNK_SOLD                                = "SEND_JUNK_SOLD",
    PLAYER_RUN_DATA                          = "SEND_PLAYER_RUN_DATA",
    SOUL_POINTS_MULTIPLIER                   = "SEND_PLAYER_SOUL_POINTS_MULTIPLIER",
    COMMITTED_SOUL_POINTS                    = "SEND_PLAYER_UPDATED_COMMITTED_SOUL_POINTS",
    PLAYER_PERK_CHOICE                       = "SEND_PLAYER_PERK_CHOICE",
    PLAYER_SPEC_INDEX                        = "SEND_PLAYER_SPEC_INDEX",
    FREEZE_PERK_RESULT                       = "SEND_FREEZE_PERK_RESULT",
    HARDMODE_DATA                            = "SEND_HARDMODE_DATA",
    BUILD_LIST                               = "SEND_PERK_LOADOUTS",
    BUILD_ACTIVE                             = "SEND_PERK_LOADOUT_ACTIVE",
    CHECKPOINTS_DATA                         = "SEND_CHECKPOINTS_DATA",
    PLAYER_PERK_SELECTION_RESULT             = "SEND_PLAYER_PERK_SELECTION_RESULT",
    PRESTIGE_RESULT                          = "SEND_PRESTIGE_RESULT",
    ORBS                                     = "SEND_ORB_CHARGES",
  },
  CS = {
    PERK_SELECT                              = "REQUEST_PLAYER_PERK_SELECTION",
    REFRESH_PERKS                            = "REQUEST_ECHO_DISCOVERY",
    REFRESH_BUILDS                           = "REQUEST_PERK_LOADOUTS",
    BUILD_SAVE                               = "REQUEST_PERK_LOADOUT_SAVE",
    BUILD_SELECT                             = "REQUEST_PERK_LOADOUT_ACTIVATE",
    ORBS                                     = "REQUEST_ORB_CHARGES",
    ORB_FORGET                               = "REQUEST_ORB_CONSUME",
  },
}

EbonAPI.SS = EbonAPI.SS or {}
EbonAPI.CS = EbonAPI.CS or {}

local SS = EbonAPI.SS
local CS = EbonAPI.CS

local ssNames = {}
local csNames = {}
local ssNumbers = {}
local csNumbers = {}

local function rebuild()
  ssNames, csNames, ssNumbers, csNumbers = {}, {}, {}, {}

  for name, opcode in pairs(PE_SS) do
    ssNumbers[name] = opcode
    if not ssNames[opcode] or name < ssNames[opcode] then
      ssNames[opcode] = name
    end
  end

  for name, opcode in pairs(PE_CS) do
    csNumbers[name] = opcode
    if not csNames[opcode] or name < csNames[opcode] then
      csNames[opcode] = name
    end
  end

  for name in pairs(SS) do SS[name] = nil end
  for name in pairs(CS) do CS[name] = nil end

  for name, opcode in pairs(PE_SS) do SS[name] = opcode end
  for name, opcode in pairs(PE_CS) do CS[name] = opcode end

  for alias, target in pairs(Opcodes.ALIASES.SS) do
    if PE_SS[target] and SS[alias] == nil then SS[alias] = PE_SS[target] end
  end

  for alias, target in pairs(Opcodes.ALIASES.CS) do
    if PE_CS[target] and CS[alias] == nil then CS[alias] = PE_CS[target] end
  end
end

function Opcodes.nameSS(opcode) return ssNames[opcode] end
function Opcodes.nameCS(opcode) return csNames[opcode] end
function Opcodes.numberSS(name) return ssNumbers[name] end
function Opcodes.numberCS(name) return csNumbers[name] end

function Opcodes.sync()
  local pe = rawget(_G, "ProjectEbonhold")

  if type(pe) ~= "table" then
    return false
  end

  for _, pair in ipairs({ { pe.SS, PE_SS }, { pe.CS, PE_CS } }) do
    if type(pair[1]) == "table" then
      for name, opcode in pairs(pair[1]) do
        if type(name) == "string" and type(opcode) == "number" then
          pair[2][name] = opcode
        end
      end
    end
  end

  rebuild()
  return true
end

function Opcodes.describe(opcode)
  local name = ssNames[opcode] or csNames[opcode]

  if name then
    return name .. " (" .. tostring(opcode) .. ")"
  end

  return "opcode " .. tostring(opcode)
end

function Opcodes.list()
  local lines = {}
  local codes = {}

  for opcode in pairs(ssNames) do
    codes[#codes + 1] = opcode
  end

  table.sort(codes)

  for index = 1, #codes do
    lines[#lines + 1] = "  S>C  " .. codes[index] .. "  " .. ssNames[codes[index]]
  end

  codes = {}

  for opcode in pairs(csNames) do
    codes[#codes + 1] = opcode
  end

  table.sort(codes)

  for index = 1, #codes do
    lines[#lines + 1] = "  C>S  " .. codes[index] .. "  " .. csNames[codes[index]]
  end

  return table.concat(lines, "\n")
end

function Opcodes.counts()
  local ss, cs = 0, 0

  for _ in pairs(ssNames) do
    ss = ss + 1
  end

  for _ in pairs(csNames) do
    cs = cs + 1
  end

  return ss, cs
end

function Opcodes.rows()
  local rows = {}

  for _, entry in ipairs({ { "ss", ssNames }, { "cs", csNames } }) do
    local codes = {}

    for opcode in pairs(entry[2]) do
      codes[#codes + 1] = opcode
    end

    table.sort(codes)

    for index = 1, #codes do
      rows[#rows + 1] = { dir = entry[1], code = codes[index], name = entry[2][codes[index]] }
    end
  end

  return rows
end

rebuild()
Opcodes.sync()
