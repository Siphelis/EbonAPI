local _, ns = ...
local JOINTS = ns and ns.JOINTS
local PA = EbonAPI and EbonAPI.PrestigeAnimations
local original = PA and PA.coeur
if not JOINTS or type(original) ~= "function" then return end

local abs, floor, ceil, sin, cos, sqrt, min, max, atan2 = math.abs, math.floor, math.ceil, math.sin, math.cos, math.sqrt, math.min, math.max, math.atan2
local PI = math.pi
local TAU = PI * 2

local SOMBRE = { 96, 22, 10 }
local BRAISE = { 194, 51, 26 }
local VIVE = { 255, 90, 31 }

local DIAMETRE = 214
local PAS = 1 / 20
local VERIF = 5
local ATTENTE_MOSAIQUE = 0.5
local ESSAIS_MOSAIQUE = 20
local FONDU_SORTIE = 0.4
local FONDU_RETOUR = 1.2
local GRAINE = 20261124
local MAX_TRONCONS = 7
local CIBLE = 6
local PAR_TRONCON = 22
local EPAISSEUR = 3
local ESPACE = 2
local BOUT = 4
local PLANCHER_BOUT = 0.1
local LONG_MIN = 14
local LONG_MIN_REPLI = 11
local LONG_MAX = 42
local LONG_CIBLE = 26
local MARGE_ARETE = 3.5
local MARGE_ANNEAU = 1
local PAS_ECHANT = 0.5
local DOUBLON = 1.5
local DEGAGE = 1.2
local FENETRE = 0.5
local PERIODE = 4
local ALPHA_MIN = 0.4
local ALPHA_MAX = 0.85
local SEUIL = 0.005
local GOUTTE_PIC = 1
local GOUTTE_TAILLE = 7
local GOUTTE_DECAL = { -6, -3, 0, 3, 6 }
local GOUTTE_POIDS = { 0.3, 0.6, 1, 0.6, 0.3 }
local VITESSE_MIN = 10.5
local VITESSE_MAX = 15
local ATTENTE_MIN = 3.3
local ATTENTE_MAX = 5.7
local PREMIERE = 2

local BS = string.char(92)
local TEXTURE = "Interface" .. BS .. "AddOns" .. BS .. "EbonAPI-Skin-Magmathar" .. BS .. "Media" .. BS .. "Coeur" .. BS .. "coeur-point.tga"

local ETATS = setmetatable({}, { __mode = "k" })

local function alea(graine)
  local s = graine % 4294967296
  return function()
    s = (s * 1664525 + 1013904223) % 4294967296
    return s / 4294967296
  end
end

local function teinte(g)
  local a, b, h
  if g < 0.5 then
    a, b, h = SOMBRE, BRAISE, g * 2
  else
    a, b, h = BRAISE, VIVE, (g - 0.5) * 2
  end
  return (a[1] + (b[1] - a[1]) * h) / 255, (a[2] + (b[2] - a[2]) * h) / 255, (a[3] + (b[3] - a[3]) * h) / 255
end

local function echantillonner(e, ox, oy, m, ts)
  local p = JOINTS.aretes[e].p
  local tp = JOINTS.taille
  local X, Y, S = {}, {}, {}
  local n = 0
  local s = 0
  local px, py
  for k = 1, #p / 2 do
    local x = m.left + ts * (p[2 * k - 1] + tp * ox + 0.5)
    local y = m.top - ts * (p[2 * k] + tp * oy + 0.5)
    if px then
      local dx, dy = x - px, y - py
      local len = sqrt(dx * dx + dy * dy)
      local pieces = max(1, ceil(len / PAS_ECHANT))
      for i = 1, pieces do
        local u = i / pieces
        n = n + 1
        X[n], Y[n], S[n] = px + dx * u, py + dy * u, s + len * u
      end
      s = s + len
    else
      n = 1
      X[1], Y[1], S[1] = x, y, 0
    end
    px, py = x, y
  end
  return X, Y, S, n, s
end

local function meilleureSerie(X, Y, S, n, total, cx, cy, rin, rout)
  local best0, best1, bestLen
  local d0
  local function clore(i1)
    if d0 then
      local len = S[i1] - S[d0]
      if not bestLen or len > bestLen then best0, best1, bestLen = d0, i1, len end
      d0 = nil
    end
  end
  for i = 1, n do
    local dx, dy = X[i] - cx, Y[i] - cy
    local r = sqrt(dx * dx + dy * dy)
    local dedans = r >= rin and r <= rout and S[i] >= MARGE_ARETE and S[i] <= total - MARGE_ARETE
    if dedans then
      if not d0 then d0 = i end
    else
      clore(i - 1)
    end
  end
  clore(n)
  return best0, best1, bestLen
end

local function chercherCandidats(m, cx, cy, W)
  local tp = JOINTS.taille
  local ts = m.tile / tp
  local R = W / 2
  local rin, rout = R + MARGE_ANNEAU, 1.6 * R - MARGE_ANNEAU
  local reach = 1.6 * R + 10
  local ux, uy = (cx - m.left) / ts - 0.5, (m.top - cy) / ts - 0.5
  local rr = reach / ts
  local lox, hix = floor((ux - rr) / tp), floor((ux + rr) / tp)
  local loy, hiy = floor((uy - rr) / tp), floor((uy + rr) / tp)
  local liste, toutes = {}, {}
  for e = 1, #JOINTS.aretes do
    for ox = lox, hix do
      for oy = loy, hiy do
        local X, Y, S, n, total = echantillonner(e, ox, oy, m, ts)
        local i0, i1, len = meilleureSerie(X, Y, S, n, total, cx, cy, rin, rout)
        local copie
        local x0, x1, y0, y1 = X[1], X[1], Y[1], Y[1]
        for i = 2, n do
          if X[i] < x0 then x0 = X[i] elseif X[i] > x1 then x1 = X[i] end
          if Y[i] < y0 then y0 = Y[i] elseif Y[i] > y1 then y1 = Y[i] end
        end
        local dx0, dy0 = max(x0 - cx, cx - x1, 0), max(y0 - cy, cy - y1, 0)
        if sqrt(dx0 * dx0 + dy0 * dy0) <= reach then
          copie = { X = X, Y = Y, n = n, x0 = x0 - DEGAGE, x1 = x1 + DEGAGE, y0 = y0 - DEGAGE, y1 = y1 + DEGAGE }
          toutes[#toutes + 1] = copie
        end
        if i0 and len >= LONG_MIN_REPLI then
          local im = floor((i0 + i1) / 2)
          local mx, my = X[im], Y[im]
          local double = false
          for k = 1, #liste do
            local c = liste[k]
            if abs(c.mx - mx) < DOUBLON and abs(c.my - my) < DOUBLON and abs(c.len - len) < 2 then
              double = true
              c.double = true
              if c.copie then c.copie.double = true end
              break
            end
          end
          if double then
            if copie then copie.double = true end
          else
            liste[#liste + 1] = {
              copie = copie, e = e, ox = ox, oy = oy, X = X, Y = Y, S = S, n = n,
              i0 = i0, i1 = i1, len = len, mx = mx, my = my,
              ang = atan2(my - cy, mx - cx) % TAU,
            }
          end
        end
      end
    end
  end
  return liste, toutes
end

local function degage(toutes, propre, x, y)
  local best = 1e9
  for k = 1, #toutes do
    local c = toutes[k]
    if c ~= propre and not c.double and x >= c.x0 and x <= c.x1 and y >= c.y0 and y <= c.y1 then
      local X, Y = c.X, c.Y
      for i = 1, c.n do
        local dx, dy = X[i] - x, Y[i] - y
        local d = dx * dx + dy * dy
        if d < best then best = d end
      end
    end
  end
  return sqrt(best)
end

local function distAng(a, b)
  local d = abs(a - b) % TAU
  if d > PI then d = TAU - d end
  return d
end

local function net(c, q)
  c.P = c.P or {}
  if c.P[q] == nil then
    local x, y = c.X[q], c.Y[q]
    local best, bs = 1e18, 0
    for i = 1, c.n do
      local dx, dy = c.X[i] - x, c.Y[i] - y
      local d = dx * dx + dy * dy
      if d < best - 1e-6 then best, bs = d, c.S[i] end
      if d < 1 and abs(c.S[i] - c.S[q]) > 1.5 then best, bs = 0, 1e9 end
    end
    c.P[q] = abs(bs - c.S[q]) <= 0.3
  end
  return c.P[q]
end

local function batir(c, rnd, toutes)
  local lp = min(c.len, LONG_MAX, LONG_CIBLE + rnd() * (LONG_MAX - LONG_CIBLE))
  local debut = c.S[c.i0] + rnd() * (c.len - lp)
  local n = min(PAR_TRONCON, max(3, ceil(lp / ESPACE) + 1))
  local pts = {}
  for i = 1, n do
    local d = lp * (i - 1) / (n - 1)
    local cible = debut + d
    local jb, db
    for q = c.i0, c.i1 do
      local ds = abs(c.S[q] - cible)
      if ds <= FENETRE and (not db or ds < db) and net(c, q) and degage(toutes, c.copie, c.X[q], c.Y[q]) >= DEGAGE then
        jb, db = q, ds
      end
    end
    if not jb then return nil end
    local de = min(d, lp - d)
    local f = PLANCHER_BOUT + (1 - PLANCHER_BOUT) * min(1, de / BOUT)
    pts[i] = { x = c.X[jb], y = c.Y[jb], f = f }
  end
  return { n = n, pts = pts, e = c.e, ox = c.ox, oy = c.oy }
end

local function choisir(liste, toutes)
  local longues = {}
  for i = 1, #liste do
    if liste[i].len >= LONG_MIN and not liste[i].double then longues[#longues + 1] = liste[i] end
  end
  if #longues < 4 then longues = liste end
  table.sort(longues, function(a, b)
    if a.ang ~= b.ang then return a.ang < b.ang end
    if a.e ~= b.e then return a.e < b.e end
    if a.ox ~= b.ox then return a.ox < b.ox end
    return a.oy < b.oy
  end)
  local rnd = alea(GRAINE)
  local nb = min(CIBLE, #longues)
  local base = rnd() * TAU
  local pris, troncons = {}, {}
  for k = 0, nb - 1 do
    local cible = (base + TAU * k / nb) % TAU
    while true do
      local best, bd
      for i = 1, #longues do
        if not pris[i] then
          local d = distAng(longues[i].ang, cible)
          if not bd or d < bd then best, bd = i, d end
        end
      end
      if not best then break end
      pris[best] = true
      local tr = batir(longues[best], rnd, toutes)
      if tr then
        troncons[#troncons + 1] = tr
        break
      end
    end
  end
  for k = 1, #troncons do troncons[k].phase = (k - 1) * PERIODE / #troncons end
  return troncons
end

local function creerTextures(S)
  local f = S.f
  S.pool = {}
  for k = 1, MAX_TRONCONS do
    local ligne = {}
    for i = 1, PAR_TRONCON do
      local t = f:CreateTexture(nil, "ARTWORK")
      t:SetTexture(TEXTURE)
      t:SetBlendMode("BLEND")
      t:Hide()
      ligne[i] = { t = t, s = false, a = nil, x = nil, y = nil }
    end
    S.pool[k] = ligne
  end
end

local function creerGoutte(S)
  S.gt = {}
  for i = 1, #GOUTTE_DECAL do
    local t = S.f:CreateTexture(nil, "OVERLAY")
    t:SetTexture(TEXTURE)
    t:SetBlendMode("ADD")
    t:SetVertexColor(1, 179 / 255, 71 / 255)
    t:SetSize(GOUTTE_TAILLE, GOUTTE_TAILLE)
    t:SetAlpha(0)
    t:Hide()
    S.gt[i] = { t = t, s = false, a = nil, x = nil, y = nil, f = S.f }
  end
end

local function montrer(L, on)
  if L.s ~= on then
    L.s = on
    if on then L.t:Show() else L.t:Hide() end
  end
end

local function placer(L, x, y)
  if L.x == nil or abs(L.x - x) >= 0.01 or abs(L.y - y) >= 0.01 then
    L.x, L.y = x, y
    L.t:SetPoint("CENTER", L.f, "TOPLEFT", x, y)
  end
end

local function ecrireAlpha(L, a)
  if a < SEUIL then a = 0 end
  if L.a == nil or abs(L.a - a) >= SEUIL or (a == 0 and L.a ~= 0) then
    L.a = a
    L.t:SetAlpha(a)
  end
end

local function cumuler(tr)
  if not tr.cum then
    local cum = { 0 }
    for i = 2, tr.n do
      local a, b = tr.pts[i - 1], tr.pts[i]
      local dx, dy = b.x - a.x, b.y - a.y
      cum[i] = cum[i - 1] + sqrt(dx * dx + dy * dy)
    end
    tr.cum = cum
  end
  return tr.cum
end

local function positionAu(tr, d)
  local cum = cumuler(tr)
  local total = cum[tr.n]
  if d < 0 then d = 0 elseif d > total then d = total end
  local i = 2
  while i < tr.n and cum[i] < d do i = i + 1 end
  local a, b = tr.pts[i - 1], tr.pts[i]
  local seg = cum[i] - cum[i - 1]
  local u = seg > 0 and (d - cum[i - 1]) / seg or 0
  return a.x + (b.x - a.x) * u, a.y + (b.y - a.y) * u
end

local function cacherGoutte(S)
  S.g = nil
  for i = 1, #S.gt do
    montrer(S.gt[i], false)
    ecrireAlpha(S.gt[i], 0)
  end
end

local function choisirGoutte(S)
  local nt = #S.troncons
  if nt == 0 then return nil end
  local rnd = S.rg
  local prec = S.dernier
  local ok = {}
  for k = 1, nt do
    local tr = S.troncons[k]
    if not prec or (tr.e ~= prec.e or tr.ox ~= prec.ox or tr.oy ~= prec.oy) then ok[#ok + 1] = k end
  end
  if #ok == 0 then
    for k = 1, nt do
      if S.troncons[k] ~= prec then ok[#ok + 1] = k end
    end
  end
  if #ok == 0 then ok[1] = 1 end
  local k = ok[1 + floor(rnd() * #ok)]
  local tr = S.troncons[k]
  local v = VITESSE_MIN + rnd() * (VITESSE_MAX - VITESSE_MIN)
  local total = cumuler(tr)[tr.n]
  S.dernier = tr
  return { tr = tr, v = v, dur = max(0.2, total / v), t0 = S.tg, total = total }
end

local function pasGoutte(S)
  if S.goutteOn == false then
    if S.g then cacherGoutte(S) end
    return
  end
  S.tg = S.tg + PAS
  local g = S.g
  if not g then
    if S.tg >= S.suiv then
      g = choisirGoutte(S)
      if not g then
        S.suiv = S.tg + ATTENTE_MIN
        return
      end
      S.g = g
    else
      return
    end
  end
  local u = (S.tg - g.t0) / g.dur
  if u >= 1 then
    cacherGoutte(S)
    S.suiv = S.tg + ATTENTE_MIN + S.rg() * (ATTENTE_MAX - ATTENTE_MIN)
    return
  end
  local env = sin(PI * u)
  local d = u * g.total
  for i = 1, #S.gt do
    local L = S.gt[i]
    local x, y = positionAu(g.tr, d + GOUTTE_DECAL[i])
    placer(L, x - S.gx, y - S.gy)
    ecrireAlpha(L, GOUTTE_PIC * GOUTTE_POIDS[i] * env * S.fondu)
    montrer(L, L.a ~= nil and L.a > 0)
  end
end

local function disposer(S, cx, cy, W)
  local f = S.f
  if S.W == nil or abs(S.W - W) >= 0.01 then
    S.W = W
    f:SetSize(W, W)
  end
  local gauche, haut = cx - W / 2, cy + W / 2
  S.gx, S.gy = gauche, haut
  for k = 1, MAX_TRONCONS do
    local tr = S.troncons[k]
    local ligne = S.pool[k]
    for i = 1, PAR_TRONCON do
      local L = ligne[i]
      L.f = f
      if tr and i <= tr.n then
        local p = tr.pts[i]
        if L.w == nil then
          L.w = EPAISSEUR
          L.t:SetSize(EPAISSEUR, EPAISSEUR)
        end
        placer(L, p.x - gauche, p.y - haut)
        if L.cf == nil or abs(L.cf - p.f) >= 0.0039 then
          L.cf = p.f
          L.t:SetVertexColor(teinte(0.1 + 0.7 * p.f))
        end
        montrer(L, true)
      else
        montrer(L, false)
      end
    end
  end
  S.forcer = true
end

local function trouverMosaique(ring)
  local B = EbonAPI and EbonAPI.Bricks
  if not (B and B.mosaic) then return nil end
  local m = B.mosaic(ring)
  if m then return m end
  local cx, cy = ring:GetCenter()
  if not (cx and cy) then return nil end
  local es = ring:GetEffectiveScale() or 1
  return B.mosaic(cx * es, cy * es, es)
end

local function recalculer(S)
  local ring = S.ring
  local m = trouverMosaique(ring)
  local cx, cy = ring:GetCenter()
  local W = ring:GetWidth()
  if not (m and m.tile and m.tile > 0 and cx and cy and W and W > 0) then return end
  local cle = string.format("%d:%d:%d:%d", floor(cx - m.left + 0.5), floor(m.top - cy + 0.5), floor(m.tile + 0.5), floor(W + 0.5))
  if S.cle == cle then return end
  S.cle = cle
  local liste, toutes = chercherCandidats(m, cx, cy, W)
  S.troncons = choisir(liste, toutes)
  cacherGoutte(S)
  disposer(S, cx, cy, W)
end

local function rendre(S, t)
  local fondu = S.fondu
  for k = 1, #S.troncons do
    if S.forcer or (S.pas + k) % 2 == 0 then
      local tr = S.troncons[k]
      local niveau = ALPHA_MIN + (ALPHA_MAX - ALPHA_MIN) * (0.5 + 0.5 * sin(TAU * (t - tr.phase) / PERIODE))
      local ligne = S.pool[k]
      for i = 1, tr.n do
        ecrireAlpha(ligne[i], niveau * tr.pts[i].f * fondu)
      end
    end
  end
  S.forcer = false
end

local function suivreMode(S)
  local c = S.ring.ebonapiCoeur
  local seq = c and c.mode == "sequence"
  local fondu = S.fondu
  if seq then
    S.goutteOn = false
    if fondu > 0 then fondu = max(0, fondu - PAS / FONDU_SORTIE) end
  else
    S.goutteOn = true
    if fondu < 1 then fondu = min(1, fondu + PAS / FONDU_RETOUR) end
  end
  if fondu ~= S.fondu then
    S.fondu = fondu
    S.forcer = true
  end
end

local function equiper(S)
  S.equipe = true
  creerTextures(S)
  creerGoutte(S)
  S.acc = 0
  recalculer(S)
end

local function chercherEnRetard(S, elapsed)
  if not S.ring:IsVisible() then
    S.acc = 0
    return
  end
  S.acc = S.acc + elapsed
  if S.acc < ATTENTE_MOSAIQUE then return end
  S.acc = 0
  S.essais = S.essais + 1
  if trouverMosaique(S.ring) then
    equiper(S)
  elseif S.essais >= ESSAIS_MOSAIQUE then
    S.f:SetScript("OnUpdate", nil)
  end
end

local function pasDeTemps(S, elapsed)
  if not S.equipe then
    chercherEnRetard(S, elapsed)
    return
  end
  if not S.ring:IsVisible() then
    S.acc = 0
    return
  end
  S.acc = S.acc + elapsed
  if S.acc < PAS then return end
  S.acc = S.acc - PAS
  if S.acc > PAS then S.acc = 0 end
  S.pas = S.pas + 1
  suivreMode(S)
  if S.pas % VERIF == 0 then recalculer(S) end
  rendre(S, GetTime())
  pasGoutte(S)
end

local function construire(ring)
  local S = ETATS[ring]
  if S then
    if S.equipe then
      S.cle = nil
      recalculer(S)
    else
      S.essais = 0
      S.acc = 0
      S.f:SetScript("OnUpdate", function(_, elapsed) pasDeTemps(S, elapsed) end)
    end
    return
  end
  local B = EbonAPI and EbonAPI.Bricks
  if not (B and B.mosaic) then return end
  S = { ring = ring, acc = 0, pas = 0, fondu = 1, troncons = {}, forcer = true, tg = 0, goutteOn = true, essais = 0, rg = alea(GRAINE + 7) }
  S.suiv = PREMIERE + S.rg() * (ATTENTE_MAX - PREMIERE)
  local f = CreateFrame("Frame", nil, ring)
  f:SetSize(ring:GetWidth(), ring:GetWidth())
  f:SetPoint("CENTER", ring, "CENTER", 0, 0)
  f:SetFrameLevel(ring:GetFrameLevel())
  S.f = f
  f.ebonapiRest = function() cacherGoutte(S) end
  ETATS[ring] = S
  f:SetScript("OnUpdate", function(_, elapsed) pasDeTemps(S, elapsed) end)
  if trouverMosaique(ring) then equiper(S) end
end

EbonAPI.PrestigeAnimations.coeur = function(ring, countText)
  original(ring, countText)
  if ring then construire(ring) end
end
