local _, ns = ...
local JOINTS = ns and ns.JOINTS
local B = EbonAPI and EbonAPI.Bricks
if not JOINTS or not (B and B.onDecorate and B.mosaic and B.decor) then return end

local abs, floor, ceil, sin, sqrt, min, max = math.abs, math.floor, math.ceil, math.sin, math.sqrt, math.min, math.max
local PI = math.pi
local TAU = 2 * math.pi

local GOUTTE_PIC = 1
local GOUTTE_TAILLE = 7
local GOUTTE_DECAL = { -6, -3, 0, 3, 6 }
local GOUTTE_POIDS = { 0.3, 0.6, 1, 0.6, 0.3 }
local VITESSE_MIN = 10.5
local VITESSE_MAX = 15
local PREMIERE_MIN = 1
local PREMIERE_MAX = 3
local GRAND_LARGEUR = 700
local GRAND_HAUTEUR = 400
local GRAND_MIN = 5
local GRAND_MAX = 10
local PETIT_MIN = 1
local PETIT_MAX = 5
local TPETIT_LARGEUR = 450
local TPETIT_HAUTEUR = 120
local TPETIT_MIN = 1
local TPETIT_MAX = 2
local MAX_PAR_CADRE = 10
local CIBLE_PERIODE_MIN = 4
local CIBLE_PERIODE_MAX = 9
local DEPART_MIN = 0.4
local DEPART_MAX = 2.5
local DEPART_RATTRAPAGE = 1
local ESSAIS = 8
local TIRAGES = 40
local ARETES_MAX = 40
local TOURNANT_MIN = -0.5
local MARGE_POINT = 8
local MARGE_CADRE = 6
local LONG_MIN = 36
local LONG_MAX = 134
local LONG_CIBLE = 77
local ESPACE = 1.5
local MAX_POINTS = 88
local SEUIL = 0.005
local GRAINE = 20261125
local TRAJET_ENTREE = 2.5
local TRAJET_SORTIE = 3.5
local TRAJET_NIVEAU_MIN = 0.30
local TRAJET_NIVEAU_MAX = 0.60
local TRAJET_PERIODE = 4
local TRAJET_EPAISSEUR = 4
local TRAJET_ESPACE = 3
local TRAJET_MAX_POINTS = 44
local TRAJET_BOUT = 4
local TRAJET_PLANCHER = 0.1
local TRAJET_SEUIL = 0.004
local SOMBRE = { 96, 22, 10 }
local BRAISE = { 194, 51, 26 }
local VIVE = { 255, 90, 31 }
local FOND = "fond-fenetre.tga"

local BS = string.char(92)
local TEXTURE = "Interface" .. BS .. "AddOns" .. BS .. "EbonAPI-Skin-Magmathar" .. BS .. "Media" .. BS .. "Coeur" .. BS .. "coeur-point.tga"

local WEAK = { __mode = "k" }
local connus = setmetatable({}, WEAK)
local crochets = setmetatable({}, WEAK)
local etats = setmetatable({}, WEAK)
local reserves = setmetatable({}, WEAK)
local couronnes = setmetatable({}, WEAK)

local actifs = {}
local nbActifs = 0
local compteur = 0
local moteur
local moteurOn = false
local BX1, BX2, BY1, BY2 = 0, 0, 0, 0
local stamp = 0
local marque = {}
local JUMELLES = JOINTS.jumelles or {}
local NA = {}
do
  local ares = JOINTS.aretes
  for i = 1, #ares do
    local liste = { ares[i].a, ares[i].b, JUMELLES[ares[i].a], JUMELLES[ares[i].b] }
    for q = 1, 4 do
      local n = liste[q]
      if n then
        local lst = NA[n]
        if not lst then
          lst = {}
          NA[n] = lst
        end
        if lst[#lst] ~= i then lst[#lst + 1] = i end
      end
    end
  end
end

local function nouveauTampon()
  return { X = {}, Y = {}, S = {}, E = {}, ES = {}, n = 0, ne = 0, len = 0 }
end
local TA, TB = nouveauTampon(), nouveauTampon()

local function alea(graine)
  local s = graine % 4294967296
  return function()
    s = (s * 1664525 + 1013904223) % 4294967296
    return s / 4294967296
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

local function ecrireAlpha(L, a, seuil)
  if L.a == nil or abs(L.a - a) >= (seuil or SEUIL) or (a == 0 and L.a ~= 0) then
    L.a = a
    L.t:SetAlpha(a)
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

local function lisse(x)
  if x <= 0 then return 0 elseif x >= 1 then return 1 end
  return x * x * (3 - 2 * x)
end

local function creerReserve(frame)
  local R = { n = 0, occ = {} }
  reserves[frame] = R
  return R
end

local function creerPlace(frame, R)
  local lignes = {}
  for i = 1, #GOUTTE_DECAL do
    local t = frame:CreateTexture(nil, "ARTWORK")
    t:SetTexture(TEXTURE)
    t:SetBlendMode("ADD")
    t:SetVertexColor(1, 179 / 255, 71 / 255)
    t:SetSize(GOUTTE_TAILLE, GOUTTE_TAILLE)
    t:SetAlpha(0)
    t:Hide()
    lignes[i] = { t = t, s = false, a = nil, x = nil, y = nil, f = frame }
  end
  R.n = R.n + 1
  local trajet = {}
  for i = 1, TRAJET_MAX_POINTS do
    local t = frame:CreateTexture(nil, "ARTWORK")
    t:SetDrawLayer("ARTWORK", -1)
    t:SetTexture(TEXTURE)
    t:SetBlendMode("BLEND")
    t:SetSize(TRAJET_EPAISSEUR, TRAJET_EPAISSEUR)
    t:SetAlpha(0)
    t:Hide()
    trajet[i] = { t = t, s = false, a = nil, x = nil, y = nil, f = frame, p = 1, cf = nil }
  end
  local place = {
    lignes = lignes, trajet = trajet, nt = 0, occupee = false, R = R, par = R.n % 2,
    tr = { X = {}, Y = {}, cum = {}, n = 0 }, edges = {}, ne = 0,
  }
  R[R.n] = place
  return place
end

local function prendrePlace(frame)
  local R = reserves[frame] or creerReserve(frame)
  for i = 1, R.n do
    if not R[i].occupee then
      R[i].occupee = true
      return R[i]
    end
  end
  if R.n < MAX_PAR_CADRE then
    local place = creerPlace(frame, R)
    place.occupee = true
    return place
  end
  return nil
end

local function finir(r)
  local place = r.place
  if place then
    for i = 1, #place.lignes do
      montrer(place.lignes[i], false)
      ecrireAlpha(place.lignes[i], 0)
    end
    for i = 1, TRAJET_MAX_POINTS do
      montrer(place.trajet[i], false)
      ecrireAlpha(place.trajet[i], 0)
    end
    local occ = place.R.occ
    for i = 1, place.ne do occ[place.edges[i]] = nil end
    place.ne = 0
    place.occupee = false
  end
  r.place = nil
  r.tr = nil
  r.on = false
end

local function positionAu(tr, d)
  local cum = tr.cum
  local n = tr.n
  local total = cum[n]
  if d < 0 then d = 0 elseif d > total then d = total end
  local i = 2
  while i < n and cum[i] < d do i = i + 1 end
  local seg = cum[i] - cum[i - 1]
  local u = seg > 0 and (d - cum[i - 1]) / seg or 0
  local X, Y = tr.X, tr.Y
  return X[i - 1] + (X[i] - X[i - 1]) * u, Y[i - 1] + (Y[i] - Y[i - 1]) * u
end

local function poserTrajet(place, tr, total)
  local trajet = place.trajet
  local nt = min(TRAJET_MAX_POINTS, max(2, ceil(total / TRAJET_ESPACE) + 1))
  place.nt = nt
  for i = 1, TRAJET_MAX_POINTS do
    local L = trajet[i]
    if i <= nt then
      local d = total * (i - 1) / (nt - 1)
      local x, y = positionAu(tr, d)
      placer(L, x, y)
      L.p = TRAJET_PLANCHER + (1 - TRAJET_PLANCHER) * min(1, min(d, total - d) / TRAJET_BOUT)
      L.t:SetVertexColor(teinte(0.1 + 0.7 * L.p))
    else
      L.p = 0
      montrer(L, false)
      ecrireAlpha(L, 0)
    end
  end
end

local function descend(frame, racine)
  local f = frame
  while f do
    if f == racine then return true end
    f = f.GetParent and f:GetParent() or nil
  end
  return false
end

local function trouverMosaique(ring)
  local m = B.mosaic(ring)
  if m then return m end
  local cx, cy = ring:GetCenter()
  if not (cx and cy) then return nil end
  local es = ring:GetEffectiveScale() or 1
  return B.mosaic(cx * es, cy * es, es)
end

local function couronneSur(cadre)
  for ring in pairs(couronnes) do
    if ring:IsVisible() then
      local m = trouverMosaique(ring)
      if m and m.frame == cadre then return true end
    end
  end
  return false
end

local function fondValide(m)
  if not m or type(m.image) ~= "string" or not m.tile or m.tile <= 0 then return false end
  local image = string.lower(m.image)
  return #image >= #FOND and string.sub(image, -#FOND) == FOND
end

local function sensDe(c, node)
  local a = JOINTS.aretes[c].a
  if a == node or a == JUMELLES[node] then return 1 end
  return -1
end

local function virageOk(T, c, sens)
  local n = T.n
  if n < 2 then return true end
  local b = n > 7 and n - 6 or 1
  local ix, iy = T.X[n] - T.X[b], T.Y[n] - T.Y[b]
  local p = JOINTS.aretes[c].p
  local np = #p / 2
  local k1, k2 = 1, min(np, 7)
  if sens < 0 then k1, k2 = np, max(1, np - 6) end
  local jx, jy = p[2 * k2 - 1] - p[2 * k1 - 1], -(p[2 * k2] - p[2 * k1])
  local li, lo = sqrt(ix * ix + iy * iy), sqrt(jx * jx + jy * jy)
  if li < 0.001 or lo < 0.001 then return true end
  return (ix * jx + iy * jy) / (li * lo) > TOURNANT_MIN
end

local function marcher(T, m, ts, tp, ox, oy, e, k0, sens, cible, rnd, occ)
  stamp = stamp + 1
  local ares, noeuds = JOINTS.aretes, JOINTS.noeuds
  local X, Y, S, E, ES = T.X, T.Y, T.S, T.E, T.ES
  local n, ne, len = 0, 0, 0
  local sx, sy = ox * tp, oy * tp
  local left, top = m.left, m.top
  local premier = true
  local fini = false
  while not fini do
    marque[e] = stamp
    ne = ne + 1
    E[ne] = e
    ES[ne] = len
    local p = ares[e].p
    local np = #p / 2
    local ka, kb, st
    if sens > 0 then
      ka, kb, st = premier and k0 or 1, np, 1
    else
      ka, kb, st = premier and k0 or np, 1, -1
    end
    premier = false
    for k = ka, kb, st do
      local px = left + ts * (p[2 * k - 1] + sx + 0.5)
      local py = top - ts * (p[2 * k] + sy + 0.5)
      if px < BX1 or px > BX2 or py < BY1 or py > BY2 then
        fini = true
        break
      end
      if n > 0 then
        local dx, dy = px - X[n], py - Y[n]
        len = len + sqrt(dx * dx + dy * dy)
      end
      n = n + 1
      X[n], Y[n], S[n] = px, py, len
      if len >= cible then
        fini = true
        break
      end
    end
    if fini or ne >= ARETES_MAX then break end
    local node = sens > 0 and ares[e].b or ares[e].a
    local lst = NA[node]
    if not lst then break end
    T.n = n
    local cnt = 0
    for i = 1, #lst do
      local c = lst[i]
      if marque[c] ~= stamp and not occ[c] and virageOk(T, c, sensDe(c, node)) then cnt = cnt + 1 end
    end
    if cnt == 0 then break end
    local pick = 1 + floor(rnd() * cnt)
    local choisie, csens
    for i = 1, #lst do
      local c = lst[i]
      if marque[c] ~= stamp and not occ[c] then
        local cs = sensDe(c, node)
        if virageOk(T, c, cs) then
          pick = pick - 1
          if pick == 0 then
            choisie, csens = c, cs
            break
          end
        end
      end
    end
    local depart = csens > 0 and ares[choisie].a or ares[choisie].b
    sx = sx + noeuds[node][1] - noeuds[depart][1]
    sy = sy + noeuds[node][2] - noeuds[depart][2]
    e, sens = choisie, csens
  end
  T.n, T.ne, T.len = n, ne, len
end

local function lancer(S, r)
  local frame = S.frame
  local largeur, hauteur = frame:GetWidth(), frame:GetHeight()
  local gauche, haut = frame:GetLeft(), frame:GetTop()
  if not (largeur and hauteur and gauche and haut) or largeur <= 2 * MARGE_POINT or hauteur <= 2 * MARGE_POINT then
    return false
  end
  local es = frame:GetEffectiveScale() or 1
  local rnd = S.rnd
  local ares = JOINTS.aretes
  local tp = JOINTS.taille
  local cur, best = TA, TB
  cur.len, best.len = 0, 0
  local bm, bgauche, bhaut, bratio, bcible, bR
  for _ = 1, ESSAIS do
    local x = gauche + MARGE_POINT + rnd() * (largeur - 2 * MARGE_POINT)
    local y = haut - MARGE_POINT - rnd() * (hauteur - 2 * MARGE_POINT)
    local m = B.mosaic(x * es, y * es, es)
    if fondValide(m) and descend(m.frame, frame) then
      if couronneSur(m.frame) then return false end
      local cadre = m.frame
      local ratio = m.scale / es
      local cg, ch = cadre:GetLeft(), cadre:GetTop()
      local cl, chh = cadre:GetWidth(), cadre:GetHeight()
      if cg and ch and cl and chh and ratio > 0 then
        BX1, BX2 = cg * ratio + MARGE_CADRE, (cg + cl) * ratio - MARGE_CADRE
        BY2, BY1 = ch * ratio - MARGE_CADRE, (ch - chh) * ratio + MARGE_CADRE
        local R = reserves[cadre] or creerReserve(cadre)
        local ts = m.tile / tp
        local cible = LONG_CIBLE + rnd() * (LONG_MAX - LONG_CIBLE)
        local e, k, ox, oy
        for _ = 1, TIRAGES do
          local ee = 1 + floor(rnd() * #ares)
          if not R.occ[ee] then
            local p = ares[ee].p
            local kk = 1 + floor(rnd() * (#p / 2))
            local qx, qy = p[2 * kk - 1], p[2 * kk]
            local o1 = floor(((x - m.left) / ts - 0.5 - qx) / tp + 0.5)
            local o2 = floor(((m.top - y) / ts - 0.5 - qy) / tp + 0.5)
            local px = m.left + ts * (qx + tp * o1 + 0.5)
            local py = m.top - ts * (qy + tp * o2 + 0.5)
            if px >= BX1 and px <= BX2 and py >= BY1 and py <= BY2 then
              e, k, ox, oy = ee, kk, o1, o2
              break
            end
          end
        end
        if e then
          marcher(cur, m, ts, tp, ox, oy, e, k, rnd() < 0.5 and 1 or -1, cible, rnd, R.occ)
          if cur.len > best.len then
            cur, best = best, cur
            bm, bgauche, bhaut, bratio, bcible, bR = m, cg, ch, ratio, cible, R
          end
          if best.len >= LONG_CIBLE then break end
        end
      end
    end
  end
  if not bm or best.len < LONG_MIN then return false end
  local place = prendrePlace(bm.frame)
  if not place then return false end
  local lp = min(best.len, bcible)
  local n = min(MAX_POINTS, max(3, ceil(lp / ESPACE) + 1))
  local tr = place.tr
  local TX, TY, TC = tr.X, tr.Y, tr.cum
  local BXs, BYs, BSs = best.X, best.Y, best.S
  local np = best.n
  local j = 2
  for i = 1, n do
    local s = lp * (i - 1) / (n - 1)
    while j < np and BSs[j] < s do j = j + 1 end
    local seg = BSs[j] - BSs[j - 1]
    local u = seg > 0 and (s - BSs[j - 1]) / seg or 0
    if u < 0 then u = 0 elseif u > 1 then u = 1 end
    TX[i] = (BXs[j - 1] + (BXs[j] - BXs[j - 1]) * u) / bratio - bgauche
    TY[i] = (BYs[j - 1] + (BYs[j] - BYs[j - 1]) * u) / bratio - bhaut
    if i == 1 then
      TC[1] = 0
    else
      local dx, dy = TX[i] - TX[i - 1], TY[i] - TY[i - 1]
      TC[i] = TC[i - 1] + sqrt(dx * dx + dy * dy)
    end
  end
  tr.n = n
  local occ = bR.occ
  local ne = 0
  for i = 1, best.ne do
    if best.ES[i] < lp then
      ne = ne + 1
      place.edges[ne] = best.E[i]
      occ[best.E[i]] = true
    end
  end
  place.ne = ne
  local v = VITESSE_MIN + rnd() * (VITESSE_MAX - VITESSE_MIN)
  r.place = place
  r.tr = tr
  r.k = 1 / bratio
  r.total = TC[n]
  r.dur = max(0.2, lp / v)
  r.t0 = S.t
  r.fin = TRAJET_ENTREE + r.dur + TRAJET_SORTIE
  poserTrajet(place, tr, r.total)
  r.on = true
  return true
end

local function pasGoutte(S, r)
  local e = S.t - r.t0
  if e >= r.fin then
    finir(r)
    return
  end
  local place = r.place
  local lignes = place.lignes
  local u = (e - TRAJET_ENTREE) / r.dur
  if u >= 0 and u < 1 then
    local env = sin(PI * u)
    local d = u * r.total
    local tr = r.tr
    for i = 1, #lignes do
      local L = lignes[i]
      local x, y = positionAu(tr, d + GOUTTE_DECAL[i] * r.k)
      placer(L, x, y)
      ecrireAlpha(L, GOUTTE_PIC * GOUTTE_POIDS[i] * env)
      montrer(L, L.a ~= nil and L.a > 0)
    end
  else
    for i = 1, #lignes do
      ecrireAlpha(lignes[i], 0)
      montrer(lignes[i], false)
    end
  end
  local fondu
  if e < TRAJET_ENTREE then
    fondu = lisse(e / TRAJET_ENTREE)
  elseif e > r.fin - TRAJET_SORTIE then
    fondu = lisse((r.fin - e) / TRAJET_SORTIE)
  else
    fondu = 1
    if (S.cnt + place.par) % 2 == 1 then return end
  end
  local niveau = TRAJET_NIVEAU_MIN + (TRAJET_NIVEAU_MAX - TRAJET_NIVEAU_MIN) * (0.5 + 0.5 * sin(TAU * e / TRAJET_PERIODE))
  local trajet = place.trajet
  for i = 1, place.nt do
    local L = trajet[i]
    ecrireAlpha(L, niveau * L.p * fondu, TRAJET_SEUIL)
    montrer(L, L.a ~= nil and L.a > 0)
  end
end

local function bornes(frame)
  local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
  if w < TPETIT_LARGEUR or h < TPETIT_HAUTEUR then return TPETIT_MIN, TPETIT_MAX end
  if w >= GRAND_LARGEUR and h >= GRAND_HAUTEUR then return GRAND_MIN, GRAND_MAX end
  return PETIT_MIN, PETIT_MAX
end

local function avancer(S, elapsed)
  S.t = S.t + elapsed
  S.cnt = S.cnt + 1
  local t = S.t
  local rnd = S.rnd
  local recs = S.recs
  local nb = 0
  for i = 1, MAX_PAR_CADRE do
    local r = recs[i]
    if r.on then
      pasGoutte(S, r)
      if r.on then nb = nb + 1 end
    end
  end
  if t >= S.tcible then
    local mn, mx = bornes(S.frame)
    S.mn = mn
    S.cible = mn + floor(rnd() * (mx - mn + 1))
    S.tcible = t + CIBLE_PERIODE_MIN + rnd() * (CIBLE_PERIODE_MAX - CIBLE_PERIODE_MIN)
  end
  if nb < S.cible and (t >= S.suiv or (nb < S.mn and t >= S.dep + DEPART_MIN)) then
    local libre
    for i = 1, MAX_PAR_CADRE do
      if not recs[i].on then
        libre = recs[i]
        break
      end
    end
    if libre then lancer(S, libre) end
    local fin = nb < S.mn and DEPART_RATTRAPAGE or DEPART_MAX
    S.dep = t
    S.suiv = t + DEPART_MIN + rnd() * (fin - DEPART_MIN)
  end
end

local function creerEtat(frame)
  compteur = compteur + 1
  local S = {
    frame = frame, rnd = alea(GRAINE + compteur * 7919), t = 0, cnt = 0, suiv = 0, dep = 0, tcible = 0,
    cible = 0, mn = 0, recs = {}, actif = false,
  }
  for i = 1, MAX_PAR_CADRE do S.recs[i] = { on = false } end
  etats[frame] = S
  return S
end

local function desactiver(S)
  for i = 1, MAX_PAR_CADRE do
    if S.recs[i].on then finir(S.recs[i]) end
  end
  S.actif = false
end

local function estRacine(frame)
  local p = frame.GetParent and frame:GetParent() or nil
  while p do
    if B.decor(p) then return false end
    p = p.GetParent and p:GetParent() or nil
  end
  return true
end

local function racineActive(frame)
  if not frame:IsVisible() then return false end
  local m = B.mosaic(frame)
  return fondValide(m)
end

local evaluerTout
local PAS = 1 / 20
local cumul = 0

local function pas(_, ecoule)
  cumul = cumul + ecoule
  if cumul < PAS then return end
  local elapsed = cumul
  cumul = 0
  local stale = false
  for i = 1, nbActifs do
    local S = actifs[i]
    if S.frame:IsVisible() then
      avancer(S, elapsed)
    else
      stale = true
    end
  end
  if stale then evaluerTout() end
end

local function reglageActif()
  local lire = EbonAPI and EbonAPI.GetBackgroundAnimations
  if type(lire) ~= "function" then return true end
  return lire(EbonAPI) ~= false
end

evaluerTout = function()
  local permis = reglageActif()
  for frame in pairs(connus) do
    local S = etats[frame]
    local actif = permis and estRacine(frame) and racineActive(frame)
    if actif then
      if not S then S = creerEtat(frame) end
      if not S.actif then
        S.actif = true
        S.t = 0
        S.tcible = 0
        S.suiv = PREMIERE_MIN + S.rnd() * (PREMIERE_MAX - PREMIERE_MIN)
      end
    elseif S and S.actif then
      desactiver(S)
    end
  end
  local n = 0
  for frame in pairs(connus) do
    local S = etats[frame]
    if S and S.actif then
      n = n + 1
      actifs[n] = S
    end
  end
  for i = n + 1, nbActifs do actifs[i] = nil end
  nbActifs = n
  if not moteur then
    moteur = CreateFrame("Frame", nil, UIParent)
    moteur:SetScript("OnUpdate", pas)
    moteur:Hide()
  end
  local veut = n > 0
  if veut ~= moteurOn then
    moteurOn = veut
    if veut then moteur:Show() else moteur:Hide() end
  end
end

B.onDecorate(function(frame)
  if not frame or not frame.HookScript then return end
  if not crochets[frame] then
    crochets[frame] = true
    connus[frame] = true
    frame:HookScript("OnShow", evaluerTout)
    frame:HookScript("OnHide", evaluerTout)
    frame:HookScript("OnSizeChanged", function(self)
      local S = etats[self]
      if not (S and S.actif) then evaluerTout() end
    end)
  end
  evaluerTout()
end)

if EbonAPI and EbonAPI.On then
  EbonAPI:On("PARAMETER_CHANGED", function(_, name)
    if name == "backgroundAnimations" then evaluerTout() end
  end)
end

if type(B.apply) == "function" then
  hooksecurefunc(B, "apply", evaluerTout)
end

local PA = EbonAPI.PrestigeAnimations
local original = PA and PA.coeur
if type(original) == "function" then
  PA.coeur = function(ring, countText)
    original(ring, countText)
    if ring then couronnes[ring] = true end
  end
end
