
local tonumber, type, floor = tonumber, type, math.floor

local split = EbonAPI.Decoders.split

EbonAPI.Decoders.register(1260, {
  name = "SEND_TRIAL_STATE", family = "Trials", mode = "event",
  decode = function(body)
    if type(body) ~= "string" then
      return nil, "not_string"
    end

    if body == "" then
      return { enabled = false }
    end

    local f = split(body, "|")

    if not tonumber(f[1]) then
      return nil, "bad_trial"
    end

    return {
      enabled = true,
      trial = tonumber(f[1]),
      phase = tonumber(f[2]) or 0,
      remainingMs = tonumber(f[3]) or 0,
      errors = tonumber(f[4]) or 0,
      maxErrors = tonumber(f[5]) or 0,
      score = tonumber(f[6]) or 0,
      elapsedMs = tonumber(f[7]) or 0,
      attempt = tonumber(f[8]) or 0,
      wave = tonumber(f[10]) or 0,
      wavesCleared = tonumber(f[11]) or 0,
      alive = tonumber(f[12]) or 0,
      teamSize = tonumber(f[13]) or 0,
      downed = (tonumber(f[14]) or 0) == 1,
      startWave = tonumber(f[15]) or 1,
    }
  end,
})

EbonAPI.Decoders.register(1261, {
  name = "SEND_TRIAL_RESULT", family = "Trials", mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "empty"
    end

    local f = split(body, "|")

    if not tonumber(f[1]) then
      return nil, "bad_trial"
    end

    local score = tonumber(f[2]) or 0

    return {
      trial = tonumber(f[1]),
      score = score,
      rank = tonumber(f[3]) or 0,
      total = tonumber(f[4]) or 0,
      topPct = (tonumber(f[5]) or 10000) / 100,
      personalBest = (tonumber(f[6]) or 0) == 1,
      previousBest = tonumber(f[7]) or 0,
      reason = tonumber(f[8]) or 0,
      elapsedMs = tonumber(f[9]) or 0,
      classId = tonumber(f[10]) or 0,
      wavesCleared = tonumber(f[11]) or floor(score / 1e8),
      teamSize = tonumber(f[12]) or 0,
      startWave = tonumber(f[13]) or 1,
    }
  end,
})

EbonAPI.Decoders.register(1262, {
  name = "SEND_TRIAL_LEADERBOARD", family = "Trials", mode = "event",
  decode = function(body)
    if type(body) ~= "string" or body == "" then
      return nil, "bad_trial"
    end

    local sections = split(body, ";")
    local h = split(sections[1], "|")
    local board

    if #h >= 7 then
      board = {
        trial = tonumber(h[1]), classFilter = tonumber(h[2]) or 0, season = tonumber(h[3]) or 0,
        seasonName = h[4] or "", myRank = tonumber(h[5]) or 0, myBest = tonumber(h[6]) or 0, total = tonumber(h[7]) or 0,
      }
    else
      board = {
        trial = tonumber(h[1]), classFilter = 0, season = tonumber(h[2]) or 0,
        seasonName = h[3] or "", myRank = tonumber(h[4]) or 0, myBest = tonumber(h[5]) or 0, total = tonumber(h[6]) or 0,
      }
    end

    if not board.trial then
      return nil, "bad_trial"
    end

    board.rows = {}

    for i = 2, #sections do
      local r = split(sections[i], "~")

      if #r >= 4 then
        board.rows[#board.rows + 1] = {
          rank = tonumber(r[1]) or 0, name = r[2] or "", class = tonumber(r[3]) or 0,
          score = tonumber(r[4]) or 0, teamSize = tonumber(r[5]) or 1,
        }
      end
    end

    return board
  end,
})
