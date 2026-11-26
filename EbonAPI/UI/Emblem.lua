local EbonAPI = _G.EbonAPI

local Kit = EbonAPI.Kit
local Bricks = EbonAPI.Bricks
local Skins = EbonAPI.Skins
local Stage = EbonAPI.PrestigeStage

local format = string.format
local type, tostring = type, tostring
local floor, abs, min, max, sin, cos, exp, sqrt = math.floor, math.abs, math.min, math.max, math.sin, math.cos, math.exp, math.sqrt
local atan2, deg, pi, random = math.atan2, math.deg, math.pi, math.random

local PI2 = pi * 2
local PRESS = 0.97
local STEP = 1 / 30
local MAXDT = 0.05
local UNIT = 0.009231
local HUBX = 0.0043
local HUBY = 0.0216
local VIGNETTE = 0.9231
local CAP = 60
local SPK = 24
local SPR = 1
local GLARE = 0.35
local RAYS = 0.6
local ART = "Interface\\AddOns\\EbonAPI\\Media\\Astrolabe\\"

local VS = { 3, -2.2, 4.6 }
local AS = { 150, -230, 330 }
local RINGS = { 43.95, 31.15, 21.9 }

local PROVIDERS = {}

local Emblem = {}
EbonAPI.Emblem = Emblem

function Emblem.available(name)
  local skins = PROVIDERS[name]

  return skins ~= nil and skins[Skins.active()] ~= nil
end

function Emblem.register(name, skinName, provider)
  if type(name) ~= "string" or name == "" then
    error(format("EbonAPI: Emblem.register: name expects a non-empty string, got %s", tostring(name)), 2)
  end

  if type(skinName) ~= "string" or skinName == "" then
    error(format("EbonAPI: Emblem.register: skinName expects a non-empty string, got %s", tostring(skinName)), 2)
  end

  if type(provider) ~= "table" or type(provider.build) ~= "function" then
    error("EbonAPI: Emblem.register: provider expects a table with a build function", 2)
  end

  local skins = PROVIDERS[name]

  if not skins then
    skins = {}
    PROVIDERS[name] = skins
  end

  skins[skinName] = provider
end

local function sm(x)
  if x < 0 then x = 0 elseif x > 1 then x = 1 end

  return x * x * (3 - 2 * x)
end

local function eo(x)
  if x < 0 then x = 0 elseif x > 1 then x = 1 end

  return 1 - (1 - x) ^ 3
end

local function wob(i, t)
  return 7 * sin(t * 0.21 + i * 2.1) + 3 * sin(t * 0.53 + i)
end

local function disp(a, i, t)
  return a.acc[i + 1] + a.wobW * wob(i, t)
end

local function setA(L, v, q)
  if v < 0 then v = 0 elseif v > 1 then v = 1 end

  v = floor(v * q + 0.5) / q

  if L.a ~= v then
    L.a = v
    L.t:SetAlpha(v)
  end
end

local function setAng(L, angle)
  angle = floor(angle * 50 + 0.5) / 50 % 360

  if L.g ~= angle then
    L.g = angle
    L.t:SetTexCoord(Stage.turned(angle))
  end
end

local function setSz(L, w)
  w = floor(w * 10 + 0.5) / 10

  if L.w ~= w then
    L.w = w
    L.t:SetSize(w, w)
  end
end

local function setPt(self, L, x, y)
  x = floor(x * 10 + 0.5) / 10
  y = floor(y * 10 + 0.5) / 10

  if L.x ~= x or L.y ~= y then
    L.x = x
    L.y = y
    L.t:SetPoint("CENTER", self.body, "CENTER", x, y)
  end
end

local function setShown(L, on)
  if L.s ~= on then
    L.s = on

    if on then
      L.t:Show()
    else
      L.t:Hide()
    end
  end
end

local function setPath(L, path)
  if L.p ~= path then
    L.p = path
    L.t:SetTexture(path)
  end
end

local function pos(a, r, u)
  local cx, cy, ex, ey

  if r >= 1 then
    cx, cy = 0, 0
    ex = a.hx + (r - 1) * a.U
    ey = a.hy + (r - 1) * a.U
  else
    cx = a.kx * (1 - r)
    cy = a.ky * (1 - r)
    ex = a.hx * r
    ey = a.hy * r
  end

  u = u - floor(u)

  local len = u * 4 * (ex + ey)
  local la, lc = 2 * ex, 2 * ey

  if len < la then
    return cx - ex + len, cy - ey
  end

  len = len - la

  if len < lc then
    return cx + ex, cy - ey + len
  end

  len = len - lc

  if len < la then
    return cx + ex - len, cy + ey
  end

  len = len - la

  return cx - ex, cy + ey - len
end

local function nouvelle(init)
  return {
    r = 1.05 + random() * 0.75,
    u = random(),
    j = random(),
    s = 0.012 + random() * 0.026,
    age = init and random() * 2 or 0,
    tw = 2 + random() * 6,
    ph = random() * PI2,
    bl = random() < 0.18,
  }
end

local function gerbe(a)
  for n = 0, SPK - 1 do
    local v = (1.4 + random() * 2.6) * a.U
    local m = random()
    local x, y, ang

    if m < 0.55 then
      local sx = n % 2 == 1 and 1 or -1
      local sy = floor(n / 2) % 2 == 1 and 1 or -1

      x = sx * a.hx
      y = sy * a.hy
      ang = atan2(sy * a.hy, sx * a.hx) + (random() - 0.5) * 1.2
    elseif m < 0.82 then
      x, y = pos(a, 1, random())

      if abs(x) / a.hx > abs(y) / a.hy then
        ang = x > 0 and 0 or pi
      else
        ang = y > 0 and pi / 2 or -pi / 2
      end

      ang = ang + (random() - 0.5) * 0.9
      v = v * 0.8
    else
      x = a.kx
      y = a.ky
      ang = random() * PI2
      v = v * 0.6
    end

    a.sparks[#a.sparks + 1] = {
      x = x, y = y, vx = cos(ang) * v, vy = sin(ang) * v,
      l = 0, L = 0.45 + random() * 0.7, s = 0.02 + random() * 0.03, b = random() < 0.3,
    }
  end

  while #a.sparks > SPK do
    table.remove(a.sparks, 1)
  end
end

local function runDirector(a, target)
  local D = a.dir

  if target == D.to and (D.run or a.e == target) then
    return
  end

  D.from = a.e
  D.to = target
  D.t0 = a.t
  D.dur = 1.68 * max(0.18, abs(target - D.from))
  D.run = true
end

local function vers(a, state)
  if state == a.etat then
    return
  end

  local t = a.t

  if state == "actif" then
    for i = 0, 2 do
      local a0 = disp(a, i, t)

      a.acc[i + 1] = a0

      if AS[i + 1] > 0 then
        a.tgt[i + 1] = math.ceil((a0 + 12) / 360) * 360
      else
        a.tgt[i + 1] = floor((a0 - 12) / 360) * 360
      end
    end

    a.trans = { on = true, t0 = t, a0 = { a.acc[1], a.acc[2], a.acc[3] }, fired = false }
    a.wobW = 0
  else
    a.trans = { on = false, t0 = t, k0 = a.k, s0 = a.spd, w0 = a.wobW }
    a.imploT = t
  end

  a.etat = state
  runDirector(a, state == "actif" and 1 or 0)
end

local function etape(a, t, dt)
  local trans = a.trans
  local align = false
  local nd = a.nd

  if trans and trans.on then
    local p = (t - trans.t0) / 0.95

    if p < 0.4 then
      local ee = (p / 0.4) ^ 3

      for i = 1, 3 do
        a.acc[i] = trans.a0[i] + (a.tgt[i] - trans.a0[i]) * ee
      end

      a.k = 0.08 + 0.3 * (p / 0.4)
      a.spd = 0
      align = true
    else
      if not trans.fired then
        trans.fired = true

        for i = 1, 3 do
          a.acc[i] = a.tgt[i]
        end

        a.flashT = t
        gerbe(a)
        a.flare = 1
      end

      a.k = 1
      a.spd = sm((p - 0.55) / 0.45)

      if p < 0.55 then
        align = true
      end
    end

    if p >= 1 then
      a.trans = nil
      a.spd = 1
      a.k = 1
    end
  elseif trans then
    local p2 = (t - trans.t0) / 1.1
    local e2 = eo(p2)

    a.spd = trans.s0 * (1 - e2)
    a.k = trans.k0 * (1 - e2)
    a.wobW = trans.w0 + (1 - trans.w0) * sm(p2)

    if p2 >= 1 then
      a.trans = nil
      a.spd = 0
      a.k = 0
      a.wobW = 1
    end
  elseif a.etat == "actif" then
    a.spd = 1
    a.k = 1
    a.wobW = 0
  else
    a.spd = 0
    a.k = 0
    a.wobW = 1
  end

  local k = a.k

  if not align then
    for r = 1, 3 do
      a.acc[r] = a.acc[r] + (VS[r] * (1 - a.spd) + AS[r] * a.spd * (1 + 0.22 * sin(t * (0.7 + (r - 1) * 0.31) + (r - 1) * 1.7))) * dt
    end

    if not a.trans then
      for r = 1, 3 do
        if a.acc[r] > 3600 or a.acc[r] < -3600 then
          a.acc[r] = a.acc[r] % 360
        end
      end
    end
  end

  local st, dm

  if k > 0.5 then
    st = 520
    dm = 16

    if t > nd.pnext then
      a.proie = random() * 300 - 150
      nd.pnext = t + 2.4 + random() * 1.8
      a.lock = 0
    end

    if t > nd.snext and a.lock == 0 then
      local rest = a.proie - nd.tg

      if abs(rest) < 4 then
        nd.tg = a.proie
        a.lock = 1
        a.flare = max(a.flare, 0.8)
      else
        nd.tg = nd.tg + rest * (0.45 + random() * 0.3) + (random() - 0.5) * min(30, abs(rest))
      end

      nd.snext = t + 0.18 + random() * 0.34
    end
  else
    st = 14
    dm = 5
    a.lock = 0
    nd.tg = 28 * sin(t * 0.37) + 12 * sin(t * 1.13 + 0.6) + 4 * sin(t * 2.9)
    a.proie = nd.tg
  end

  local ac = st * (nd.tg - nd.a) - dm * nd.v

  nd.v = nd.v + ac * dt
  nd.a = nd.a + nd.v * dt
  a.flare = a.flare * exp(-dt * 2.6)
  a.ph1 = a.ph1 + dt * (3 + 35 * k)
  a.ph3 = a.ph3 - dt * (2 + 24 * k)
  a.rotG = a.rotG + dt * 6 * a.spd

  if a.etat ~= "actif" then
    local cib = floor(a.rotG / 90 + 0.5) * 90
    local dg = (cib - a.rotG) * min(1, dt * 1.8)
    local lim = 30 * dt

    if dg > lim then
      dg = lim
    elseif dg < -lim then
      dg = -lim
    end

    a.rotG = a.rotG + dg

    if abs(cib - a.rotG) < 0.02 then
      a.rotG = cib % 360
    end
  end

  local D = a.dir

  if D.run then
    local raw = (t - D.t0) / D.dur

    if raw > 1 then
      raw = 1
    end

    a.e = D.from + (D.to - D.from) * sm(raw)

    if raw >= 1 then
      D.run = false
      a.e = D.to
    end
  end

  if a.e > 0.995 then
    a.awake = a.awake + dt * 20
  else
    a.awake = 0
  end
end

local function paintLayers(self, a, t)
  local L = self.L
  local k, e, G = a.k, a.e, a.rotG
  local side, unit, U = a.side, a.unit, a.U
  local d = {}

  for i = 0, 2 do
    d[i + 1] = disp(a, i, t)
  end

  local na = a.nd.a

  if a.lock == 1 and k > 0.5 then
    na = na + 0.9 * sin(t * 47)
  end

  a.na = na

  local pul = 0.85 + 0.15 * sin(t * 3.1) + 0.05 * sin(t * 7.7)

  setA(L.Halo, 0.1 + 0.06 * sin(t * 0.8) + 0.84 * k * pul, 100)

  local lm = k * (0.72 + 0.2 * sin(t * 5.3 + sin(t * 1.7)) + 0.08 * sin(t * 13))

  setA(L.Lueurs, lm * 0.6, 100)
  setAng(L.Lueurs, G)

  local f = t - a.flashT
  local fb = 0

  if f >= 0 and f < 1.2 then
    fb = max(0, 1 - f / 0.6)
    setA(L.Eclat, max(0, 1 - f / 0.45) ^ 1.4, 100)
    setSz(L.Eclat, 2 * RINGS[1] * (0.3 + 1.2 * eo(f / 0.5)) * unit)
    setA(L.Faisceaux, f < 0.06 and f / 0.06 or max(0, 1 - (f - 0.06) / 0.5), 100)
    setA(L.Onde1, max(0, 1 - f / 0.75) * 0.95, 100)
    setSz(L.Onde1, side + 2 * U * 0.75 * eo(f / 0.75))

    local f2 = f - 0.09

    setA(L.Onde2, f2 > 0 and max(0, 1 - f2 / 0.7) * 0.6 or 0, 100)
    setSz(L.Onde2, side + 2 * U * 0.55 * eo(max(0, f2) / 0.7))
  else
    local g = t - a.imploT

    if g >= 0 and g < 0.8 then
      setA(L.Onde1, 0.55 * sin(pi * g / 0.8), 100)
      setSz(L.Onde1, side + 2 * U * 0.42 * (1 - eo(g / 0.8)))
    else
      setA(L.Onde1, 0, 100)
    end

    setA(L.Onde2, 0, 100)
    setA(L.Eclat, 0, 100)
    setA(L.Faisceaux, 0, 100)
  end

  setA(L.CadreLueur, k * (0.5 + 0.22 * sin(t * 2.3) + 0.08 * sin(t * 9)) + fb * 0.7, 100)

  local amp = 0.3 + 0.7 * k
  local base = 0.03 + 0.16 * k
  local ang1 = floor(a.ph1) * 6 + G

  setA(L.TraitsT, base + fb, 50)
  setAng(L.TraitsT, G)
  setA(L.TraitsU, base + fb, 50)
  setAng(L.TraitsU, G)
  setA(L.ChenilleT, amp, 50)
  setAng(L.ChenilleT, ang1)

  if k > 0.05 then
    setA(L.ChenilleT2, amp * k, 50)
    setAng(L.ChenilleT2, ang1 + 180)
  else
    setA(L.ChenilleT2, 0, 50)
  end

  setA(L.ChenilleU, amp, 50)
  setAng(L.ChenilleU, floor(a.ph3) * 10 + G)
  setA(L.Etoiles, 0.04 + 0.1 * k + fb, 50)
  setAng(L.Etoiles, G)
  setA(L.EtoilesVives, 0.25 + 0.75 * k, 50)
  setAng(L.EtoilesVives, floor(d[3] / 30 + 0.5) * 30 + G)

  for i = 1, 3 do
    local c = L["Comete" .. i]

    setA(c, (1 - k) * (0.12 + 0.06 * sin(t * 0.6 + (i - 1) * 2)) + k * (0.7 + 0.3 * sin(t * 2.3 + (i - 1) * 1.9)) + fb * 0.5, 50)
    setAng(c, d[i] - 90 + G)
  end

  local sq = (t * 0.9) % 4

  for j = 0, 3 do
    local dj = ((sq - j) % 4 + 4) % 4
    local pv = exp(-dj * 1.7)
    local br = (0.5 + 0.5 * sin(t * 0.8 + j * 1.5708)) ^ 4
    local gem = L["Gemme" .. (j + 1)]

    setA(gem, (1 - k) * (0.1 + 0.22 * br) + k * (0.35 + 0.65 * pv) + fb * 0.8 + a.flare * 0.25, 50)
    setAng(gem, j * 90 + G)
  end

  setA(L.Coeur, min(1, 0.1 + 0.06 * sin(t * 1.1) + 0.5 * k + 0.4 * a.flare), 100)
  setAng(L.Coeur, G)
  setAng(L.Aiguille, na + G)
  setA(L.Pointe, min(1, 0.15 * k + 0.85 * a.flare), 100)
  setAng(L.Pointe, na + G)
  setA(L.Gglow, GLARE * min(1, 0.28 + 0.1 * sin(t * 1.3) + 0.5 * k + 0.5 * a.flare), 100)

  local mech = a.e > 0.995 and a.awake or (t * 34 + e * 280)

  for i = 0, 2 do
    local ring = L["MecaAnneau" .. (i + 1)]
    local sign = i % 2 == 1 and -1 or 1

    setA(ring, (0.12 + 0.68 * e) * (i == 1 and 0.85 or 1), 100)
    setAng(ring, mech + sign * (t * (i + 1) * 12 + e * 80))
  end

  setA(L.MecaRais, RAYS * 0.82 * e * (0.7 + 0.3 * sin(t * 7)), 100)
  setAng(L.MecaRais, mech)
  setSz(L.Noyau, 2 * (1.2 + 5.5 * e) * unit)
  setA(L.Noyau, GLARE * e, 100)
  setSz(L.AnneauFin, (7 + 17 * e) / 0.46 * unit)
  setA(L.AnneauFin, 0.8 * e * (0.65 + 0.35 * sin(t * 5)), 100)

  local hubX, hubY = a.kx, -a.ky

  for i = 0, 13 do
    local slot = self.ds[i + 1]
    local phase = (i / 14 + t * 0.18) % 1
    local ang = (i * 2.3999632297) % PI2
    local radius = 8 + phase * 36
    local pulse = max(0, sin((phase * 2 + i * 0.17) * pi)) ^ 2

    setA(slot, e * (0.12 + 0.75 * pulse) * (1 - phase * 0.25), 100)

    if slot.a > 0 then
      setPt(self, slot, hubX + cos(ang) * radius * unit, hubY - sin(ang) * radius * unit)
    end
  end
end

local PATH_SPR = ART .. "Etincelle.tga"
local PATH_SPB = ART .. "EtincelleBleue.tga"
local PATH_TR = ART .. "Trait.tga"
local PATH_TRB = ART .. "TraitBleu.tga"

local function dot(self, slot, bl, x, y, z, al)
  setPath(slot, bl and PATH_SPB or PATH_SPR)
  setSz(slot, z * 2)
  setPt(self, slot, x, -y)
  setA(slot, al, 100)
  setShown(slot, true)
end

local function streak(self, slot, bl, x0, y0, x1, y1, z, al)
  local dx, dy = x1 - x0, y1 - y0
  local len = sqrt(dx * dx + dy * dy)

  if len < 2 * z then
    len = 2 * z
  end

  setPath(slot, bl and PATH_TRB or PATH_TR)
  setSz(slot, len)
  setPt(self, slot, (x0 + x1) / 2, -(y0 + y1) / 2)
  setAng(slot, deg(atan2(dx, -dy)) - 90)
  setA(slot, al, 100)
  setShown(slot, true)
end

local function paintParticles(self, a, t, dt)
  local k = a.k
  local cible = floor(CAP * (0.14 + 0.86 * k) + 0.5)
  local base = a.U * SPR
  local parts = a.parts
  local added = 0

  while #parts < cible and added < 6 do
    parts[#parts + 1] = nouvelle(false)
    added = added + 1
  end

  local keep = {}
  local total = #parts
  local used = 0

  for i = 1, total do
    local p = parts[i]
    local skip = false

    p.age = p.age + dt

    local rr = max(p.r, 0.18)
    local dr = -(0.05 + 0.85 * k) * (0.6 + p.j) * (0.45 + 0.55 / rr) * dt
    local du = (0.22 + 3.1 * k) * (0.5 + p.j) / rr ^ 1.1 * dt / PI2

    p.r = p.r + dr
    p.u = p.u + du

    if p.u > 1 then
      p.u = p.u - 1
    end

    if p.r < 0.09 then
      if k > 0.3 then
        a.hubFlare = min(1, a.hubFlare + 0.035)
      end

      if #keep + (total - i) >= cible then
        skip = true
      else
        p = nouvelle(false)
      end
    end

    if not skip then
      keep[#keep + 1] = p

      local x, y = pos(a, p.r, p.u)
      local al = min(1, p.age / 0.35) * sm((p.r - 0.08) / 0.3) * (0.3 + 0.7 * k) * (0.55 + 0.45 * sin(t * p.tw + p.ph))

      if p.r > 1.5 then
        al = al * max(0, (1.8 - p.r) / 0.3)
      end

      if al > 0.01 and used < CAP then
        used = used + 1

        local slot = self.pp[used]
        local sz = p.s * base * (1 + 0.6 * k) * (p.r < 0.5 and 0.7 + p.r * 0.6 or 1)

        if k > 0.12 then
          local x1, y1 = pos(a, p.r - dr * 6, p.u - du * 6)

          streak(self, slot, p.bl, x1, y1, x, y, sz, al)
        else
          dot(self, slot, p.bl, x, y, sz, al)
        end
      end
    end
  end

  for i = used + 1, a.pUsed do
    setShown(self.pp[i], false)
  end

  a.pUsed = used
  a.parts = keep

  local ks = {}
  local gu = 0

  for s = 1, #a.sparks do
    local q = a.sparks[s]

    q.l = q.l + dt

    if q.l <= q.L then
      local dg = exp(-dt * 2.4)

      q.vx = q.vx * dg
      q.vy = q.vy * dg
      q.x = q.x + q.vx * dt
      q.y = q.y + q.vy * dt
      ks[#ks + 1] = q

      local lf = 1 - q.l / q.L
      local z = q.s * base * (0.6 + lf)

      if gu < SPK and lf > 0.01 then
        gu = gu + 1

        local slot = self.gp[gu]

        if k > 0.12 then
          streak(self, slot, q.b, q.x - q.vx * 0.06, q.y - q.vy * 0.06, q.x, q.y, z, lf)
        else
          dot(self, slot, q.b, q.x, q.y, z, lf)
        end
      end
    end
  end

  for i = gu + 1, a.gUsed do
    setShown(self.gp[i], false)
  end

  a.gUsed = gu
  a.sparks = ks
  a.hubFlare = a.hubFlare * exp(-dt * 3)

  local fl = min(1, a.hubFlare * 0.6 + a.flare * 0.8)
  local L = self.L.EclatMoyeu

  if fl > 0.02 then
    local z2 = a.V * (0.2 + 0.33 * fl) * sqrt(11.9 / 24)

    setSz(L, z2 * 2)
    setA(L, GLARE * fl, 100)
  else
    setA(L, 0, 100)
  end
end

local function render(self, a, dt)
  paintLayers(self, a, a.t)
  paintParticles(self, a, a.t, dt)
end

local function onUpdate(self, elapsed)
  local a = self.astro

  a.pend = a.pend + elapsed

  if a.pend < STEP - 0.000001 then
    return
  end

  local dt = a.pend

  if dt > MAXDT then
    dt = MAXDT
  end

  a.pend = 0
  a.t = a.t + dt
  etape(a, a.t, dt)
  render(self, a, dt)
end

local function newState(side, on)
  local a = {
    side = side,
    U = side / 2,
    hx = side / 2,
    hy = side / 2,
    kx = HUBX * side,
    ky = -HUBY * side,
    V = side * VIGNETTE / 2,
    unit = UNIT * side,
    t = 0,
    pend = 0,
    etat = on and "actif" or "veille",
    k = on and 1 or 0,
    spd = on and 1 or 0,
    e = on and 1 or 0,
    wobW = on and 0 or 1,
    acc = { 17, -34, 52 },
    tgt = { 0, 0, 0 },
    nd = { a = 0, v = 0, tg = 0, pnext = 0, snext = 0 },
    na = 0,
    proie = 40,
    lock = 0,
    flare = 0,
    hubFlare = 0,
    flashT = -9,
    imploT = -9,
    ph1 = 0,
    ph3 = 0,
    rotG = 0,
    awake = 0,
    parts = {},
    sparks = {},
    pUsed = 0,
    gUsed = 0,
    dir = { run = false, from = on and 1 or 0, to = on and 1 or 0, t0 = 0, dur = 1 },
  }

  local count = floor(CAP * (0.14 + 0.86 * a.k) + 0.5)

  for _ = 1, count do
    a.parts[#a.parts + 1] = nouvelle(true)
  end

  return a
end

local function make(self, file, blend, size, x, y, plan)
  local texture = self.plans[plan]:CreateTexture(nil, "ARTWORK")

  texture:SetTexture(ART .. file .. ".tga")
  texture:SetBlendMode(blend)
  texture:SetSize(size, size)
  texture:SetPoint("CENTER", self.body, "CENTER", x, y)

  return { t = texture, w = size, x = x, y = y, p = ART .. file .. ".tga" }
end

local function free(layer)
  layer.w = nil
  layer.x = nil
  layer.y = nil

  return layer
end

local function bare(self, file, x, y, plan)
  return free(make(self, file, "ADD", 1, x, y, plan))
end

local function pool(self, count, plan)
  local list = {}

  for i = 1, count do
    local slot = bare(self, "Etincelle", 0, 0, plan)

    slot.t:Hide()
    slot.s = false
    list[i] = slot
  end

  return list
end

local function planes(self, side)
  local body = CreateFrame("Frame", nil, self)

  body:SetSize(side, side)
  body:SetPoint("CENTER", self, "CENTER", 0, 0)
  body:SetFrameLevel(self:GetFrameLevel() + 1)

  self.body = body

  self.plans = {}

  for i = 1, 7 do
    local plan = CreateFrame("Frame", nil, body)

    plan:SetAllPoints(body)
    plan:SetFrameLevel(body:GetFrameLevel() + i)
    self.plans[i] = plan
  end
end

local function build(self, side)
  planes(self, side)

  local a = self.astro
  local hx, hy = HUBX * side, HUBY * side
  local L = {}

  self.L = L

  L.Halo = make(self, "Halo", "ADD", side * 2, 0, 0, 1)
  L.Disque = make(self, "Disque", "BLEND", side, 0, 0, 2)
  L.Lueurs = make(self, "Lueurs", "ADD", side, hx, hy, 3)
  L.TraitsT = make(self, "TraitsT", "ADD", side, hx, hy, 3)
  L.ChenilleT = make(self, "ChenilleT", "ADD", side, hx, hy, 3)
  L.ChenilleT2 = make(self, "ChenilleT", "ADD", side, hx, hy, 3)
  L.TraitsU = make(self, "TraitsU", "ADD", side, hx, hy, 3)
  L.ChenilleU = make(self, "ChenilleU", "ADD", side, hx, hy, 3)
  L.Etoiles = make(self, "Etoiles", "ADD", side, hx, hy, 3)
  L.EtoilesVives = make(self, "EtoilesVives", "ADD", side, hx, hy, 3)

  for i = 1, 3 do
    L["Comete" .. i] = make(self, "Comete" .. i, "ADD", side, hx, hy, 3)
  end

  for i = 1, 4 do
    L["Gemme" .. i] = make(self, "Gemme", "ADD", side, hx, hy, 3)
  end

  L.Coeur = make(self, "Coeur", "ADD", side, hx, hy, 3)
  L.Aiguille = make(self, "Aiguille", "BLEND", side, hx, hy, 4)
  L.Pointe = make(self, "Pointe", "ADD", side, hx, hy, 5)
  L.Gglow = make(self, "Lueur", "ADD", 2 * 0.75 * 9.1 * a.unit, hx, hy, 5)
  L.Eclat = bare(self, "Lueur", hx, hy, 5)
  L.Eclat.x, L.Eclat.y = hx, hy

  for i = 1, 3 do
    L["MecaAnneau" .. i] = make(self, "MecaAnneau" .. i, "ADD", side, hx, hy, 5)
  end

  L.MecaRais = make(self, "MecaRais", "ADD", side, hx, hy, 5)
  L.Noyau = bare(self, "Lueur", hx, hy, 5)
  L.AnneauFin = bare(self, "AnneauFin", hx, hy, 5)

  self.ds = {}

  for i = 1, 14 do
    local slot = bare(self, "Etincelle", hx, hy, 5)

    setSz(slot, (i % 3 ~= 1 and 0.55 or 0.85) * 5 * a.unit)
    self.ds[i] = slot
  end

  L.CadreLueur = make(self, "CadreLueur", "ADD", side, 0, 0, 7)
  L.Cadre = make(self, "Cadre", "BLEND", side, 0, 0, 6)
  L.CadreLueur.t:Hide()
  L.Cadre.t:Hide()
  L.Onde1 = bare(self, "Onde", 0, 0, 7)
  L.Onde1.t:SetVertexColor(1, 0.957, 0.784)
  L.Onde2 = bare(self, "Onde", 0, 0, 7)
  L.Onde2.t:SetVertexColor(1, 0.604, 0.165)
  L.Faisceaux = make(self, "Faisceaux", "ADD", side * 2, 0, 0, 7)

  self.pp = pool(self, CAP, 7)
  self.gp = pool(self, SPK, 7)
  L.EclatMoyeu = bare(self, "Lueur", hx, hy, 7)
  L.EclatMoyeu.x, L.EclatMoyeu.y = hx, hy
  L.Eclat.x, L.Eclat.y = nil, nil
  L.Noyau.x, L.Noyau.y = nil, nil
  L.AnneauFin.x, L.AnneauFin.y = nil, nil
end

local function checkEmblem(owner, spec, level)
  if type(spec.name) ~= "string" then
    error(format("EbonAPI: %s: emblem name expects a string, got %s", owner, tostring(spec.name)), level + 1)
  end

  if type(spec.size) ~= "number" or spec.size <= 0 then
    error(format("EbonAPI: %s: emblem size expects a number above 0, got %s", owner, tostring(spec.size)), level + 1)
  end

  if type(spec.get) ~= "function" then
    error(format("EbonAPI: %s: emblem get expects a function, got %s", owner, type(spec.get)), level + 1)
  end
end

local function showTip(self)
  local tip = self.spec.tip

  if type(tip) == "string" then
    Bricks.tip(self, tip)
  elseif type(tip) == "function" and GameTooltip then
    Bricks.tip(self, "", nil)
    tip(Kit.lines(GameTooltip), self)
    GameTooltip:Show()
  end
end

local function stepEngine(button, elapsed)
  button.engine.step(elapsed)
end

local SETTLE_STEPS = 120
local SETTLE_DT = 0.03
local live = setmetatable({}, { __mode = "k" })

local function animating()
  return EbonAPI.Parameters.huntAnimation()
end

local function settle(button)
  for _ = 1, SETTLE_STEPS do
    button.engine.step(SETTLE_DT)
  end

  if button.engine.rest then
    button.engine.rest()
  end
end

local function applyMode(button)
  if animating() then
    if button:IsVisible() then
      button:SetScript("OnUpdate", stepEngine)
    end
  else
    button:SetScript("OnUpdate", nil)
    settle(button)
  end
end

EbonAPI:On("PARAMETER_CHANGED", function(_, name)
  if name ~= "huntAnimation" then
    return
  end

  for button in pairs(live) do
    applyMode(button)
  end
end)

local function newEmblem(owner, parent, spec)
  local self = CreateFrame("Button", nil, parent)

  self.owner = owner
  self.kind = "emblem"
  self.spec = spec
  self.kitOwnTip = true
  self:SetSize(spec.size, spec.size)

  local skins = PROVIDERS[spec.name]
  local provider = skins and skins[Skins.active()]

  if not provider then
    error(format("EbonAPI: %s: no emblem provider for %s on the active skin", tostring(owner), tostring(spec.name)), 2)
  end

  self.on = Kit.evaluate(self, spec.get) and true or false
  self.engine = provider.build(self, spec.size, self.on)

  function self:SetActive(value)
    value = value and true or false

    if value == self.on then
      return
    end

    self.on = value
    self.engine.set(value)

    if not animating() then
      settle(self)
    end
  end

  function self:Refresh()
    self:SetActive(Kit.evaluate(self, spec.get))
  end

  self.kitRefresh = self.Refresh

  self:SetScript("OnClick", function()
    if spec.onClick then
      spec.onClick()
    end
  end)
  self:SetScript("OnMouseDown", function(button)
    button.body:SetScale(PRESS)
  end)
  self:SetScript("OnMouseUp", function(button)
    button.body:SetScale(1)
  end)
  self:SetScript("OnEnter", showTip)
  self:SetScript("OnLeave", function()
    if Bricks.hideTip then
      Bricks.hideTip()
    end
  end)
  self:SetScript("OnHide", function(button)
    button:SetScript("OnUpdate", nil)
  end)
  self:SetScript("OnShow", function(button)
    local engine = button.engine

    if engine.show then
      engine.show()
    end

    if animating() then
      button:SetScript("OnUpdate", stepEngine)
    end
  end)

  live[self] = true

  if self:IsVisible() and animating() then
    self:SetScript("OnUpdate", stepEngine)
  end

  return self
end

Emblem.register("hunt", "Azeroth", {
  build = function(button, side, on)
    button.astro = newState(side, on)
    build(button, side)
    render(button, button.astro, 0)

    return {
      step = function(elapsed)
        onUpdate(button, elapsed)
      end,
      set = function(value)
        vers(button.astro, value and "actif" or "veille")
      end,
      show = function()
        button.astro.pend = 0
      end,
    }
  end,
})

Emblem.tools = {
  setA = setA,
  setAng = setAng,
  setSz = setSz,
  setPt = setPt,
  setShown = setShown,
  setPath = setPath,
  make = make,
  bare = bare,
  pool = pool,
  planes = planes,
}

Kit.addKind("emblem", newEmblem, checkEmblem)
