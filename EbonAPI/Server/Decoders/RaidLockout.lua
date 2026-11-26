
EbonAPI.Decoders.register(1292, {
  name = "SEND_RAID_LOOT_LOCKOUTS", family = "RaidLockout",
  mode = "state",
  decode = function(body)
    if type(body) ~= "string" then return nil, "body is not a string" end

    local locks, remaining = {}, {}

    for e, s in string.gmatch(body, "(%d+):(%d+)") do
      local encounter, secs = tonumber(e), tonumber(s)

      locks[#locks + 1] = { encounter = encounter, seconds = secs }
      remaining[encounter] = secs
    end

    return { locks = locks, remaining = remaining }
  end,
})
