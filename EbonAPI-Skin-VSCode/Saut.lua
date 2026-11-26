-- VSCode-5 « Saut de compilation » : animation du Prestige, bâtie sur EbonAPI.PrestigeStage.
-- Valeurs : .recall/travaux/20261109-prestige-cercle/specs-vscode-5.md (révision prime) et vscode-5/etat.js.
-- Écarts assumés (voir rapport) : pas de courbes d'accélération, pas de galaxie, comètes, épicycles,
-- secousses ni dédoublement du chiffre ; une échelle nulle est remplacée par 0,001 puis remise par ×1000.
local EbonAPI = _G.EbonAPI
local Stage = EbonAPI.PrestigeStage

local UNIT = 0.5
local PATH = "Interface\\AddOns\\EbonAPI-Skin-VSCode\\Media\\Saut\\"
local OPEN_MS = 2800
local PRESTIGE_MS = 4200
local REPOS_MS = 6000
local WARP_FROM, WARP_TO = 0.12, 2.8
local NUL = 0.001

-- Concatène des listes d'étapes.
local function cat(...)
  local out = {}
  for i = 1, select("#", ...) do
    for _, step in ipairs((select(i, ...))) do out[#out + 1] = step end
  end
  return out
end

local function rep(n, list)
  local out = {}
  for _ = 1, n do out = cat(out, list) end
  return out
end

local function pause(ms)
  return { { Stage.P(ms) } }
end

-- Clignotement : n allers-retours de 40 ms (alpha de base 0).
local function flicker(n)
  local out = {}
  for _ = 1, n do
    out[#out + 1] = { Stage.A(0, 1) }
    out[#out + 1] = { Stage.P(40) }
    out[#out + 1] = { Stage.A(0, -1) }
    out[#out + 1] = { Stage.P(40) }
  end
  return out
end

-- Passe de warp : échelle from -> to en quatre sous-étapes à raison constante, alpha pic puis retour,
-- rotation en degrés SVG (horaire positif, donc R négatif). Revient à l'échelle de base.
local function passe(d, peak, from, to, rotSvg)
  local q, sub, r = (to / from) ^ 0.25, d / 4, -rotSvg / 4
  return {
    { Stage.S(0, from) },
    { Stage.A(sub, peak), Stage.S(sub, q), Stage.R(sub, r) },
    { Stage.A(sub, 0), Stage.S(sub, q), Stage.R(sub, r) },
    { Stage.A(sub, 0), Stage.S(sub, q), Stage.R(sub, r) },
    { Stage.A(sub, -peak), Stage.S(sub, q), Stage.R(sub, r) },
    { Stage.S(0, 1 / to) },
  }
end

-- Warp (alpha de base 0) : ouverture en cycles de 600 ms, prestige en aspiration puis retombée.
local function warp(file, openDelay, openCycles, aspDelay, retDelay)
  local aspStart = 300 + aspDelay
  local aspEnd = aspStart + 500
  return {
    name = file, file = file .. ".tga", box = "far", blend = "ADD", alpha = 0,
    open = cat(pause(openDelay), rep(openCycles, passe(600, 1, WARP_FROM, WARP_TO, 8))),
    fall = cat(
      pause(aspStart), rep(2, passe(250, 0.9, WARP_TO, WARP_FROM, 0)),
      pause(1400 + retDelay - aspEnd),
      passe(500, 0.7, WARP_FROM, WARP_TO, 0),
      passe(900, 0.4, WARP_FROM, WARP_TO, 0),
      passe(1400, 0.18, WARP_FROM, WARP_TO, 0)),
  }
end

local function crochet(name, file, off, restDeg, restMs)
  return {
    name = name, file = file .. ".tga", box = "far", blend = "ADD", alpha = 1,
    open = {
      { Stage.A(0, -1), Stage.S(0, 0.3) },
      { Stage.P(1650 + off) },
      { Stage.A(50, 1) },
      { Stage.S(200, 3.7333) },
      { Stage.S(100, 0.8929) },
    },
    rest = { { Stage.R(restMs, restDeg) } },
    fall = {
      { Stage.P(300) },
      { Stage.S(260, 0.85) },
      { Stage.S(240, 1.5882) },
      { Stage.S(200, 0.7407) },
    },
  }
end

local function glitch(name, file, y, repos)
  local layer = {
    name = name, file = file .. ".tga", box = "near", blend = "ADD", alpha = 0, x = 0, y = (140 - y) * UNIT,
    open = cat(pause(1760), flicker(3)),
    fall = cat(pause(380), flicker(2)),
  }
  if repos then
    layer.rest = {
      { Stage.P(3000) }, { Stage.A(0, 1) }, { Stage.P(80) }, { Stage.A(0, -1) }, { Stage.P(REPOS_MS - 3080) },
    }
  end
  return layer
end

local function etincelle(name, file, t0, px, py)
  return {
    name = name, file = file .. ".tga", box = "spot", blend = "ADD", alpha = 0, x = px, y = py,
    rest = {
      { Stage.P(t0) },
      { Stage.S(0, NUL) },
      { Stage.A(250, 1), Stage.S(250, 1200), Stage.R(250, -45) },
      { Stage.A(250, -1), Stage.S(250, NUL / 1.2), Stage.R(250, -45) },
      { Stage.S(0, 1 / NUL) },
      { Stage.P(REPOS_MS - t0 - 500) },
    },
  }
end

local function couches()
  return {
    {
      name = "fond", file = "Fond.tga", box = "far", blend = "BLEND", alpha = 1,
      open = { { Stage.A(0, -1) }, { Stage.A(200, 1) } },
    },
    {
      name = "halo", file = "Halo.tga", box = "far", blend = "ADD", alpha = 0.35,
      open = { { Stage.A(0, -0.35) }, { Stage.P(420) }, { Stage.A(1230, 0.8) }, { Stage.A(200, -0.45) } },
      rest = { { Stage.A(1500, 0.15) }, { Stage.A(1500, -0.15) } },
      fall = { { Stage.P(300) }, { Stage.A(660, 0.65) }, { Stage.P(440) }, { Stage.A(2800, -0.65) } },
    },
    warp("WarpA", 420, 2, 0, 0),
    warp("WarpB", 620, 1, 83, 170),
    warp("WarpC", 820, 1, 166, 340),
    {
      name = "coeur", file = "Coeur.tga", box = "far", blend = "ADD", alpha = 0,
      open = {
        { Stage.S(0, 0.3) }, { Stage.P(260) },
        { Stage.A(160, 0.6), Stage.S(160, 2) },
        { Stage.A(1230, 0.4), Stage.S(1230, 2.3333) },
        { Stage.A(250, -1), Stage.S(250, 1.857) },
      },
      fall = {
        { Stage.S(0, 0.4) }, { Stage.P(300) },
        { Stage.A(660, 1), Stage.S(660, 3) },
        { Stage.A(300, -1), Stage.S(300, 2.5) },
      },
    },
    {
      name = "fente", file = "Fente.tga", box = "far", blend = "ADD", alpha = 0,
      open = {
        { Stage.S(0, 1, 0.05) }, { Stage.P(260) },
        { Stage.A(160, 1), Stage.S(160, 1, 20) },
        { Stage.A(180, -1), Stage.S(180, 6, 1) },
      },
    },
    {
      name = "flash", file = "Flash.tga", box = "far", blend = "ADD", alpha = 0,
      open = {
        { Stage.P(1650) }, { Stage.S(0, 0.6) },
        { Stage.A(40, 0.95), Stage.S(200, 2.1667) },
        { Stage.A(160, -0.95) },
      },
      fall = { { Stage.P(960) }, { Stage.A(30, 1) }, { Stage.A(770, -1) } },
    },
    {
      name = "onde1", file = "Onde1.tga", box = "far", blend = "ADD", alpha = 0,
      open = { { Stage.P(1650) }, { Stage.A(0, 0.9), Stage.S(0, 0.5) }, { Stage.A(600, -0.9), Stage.S(600, 4) } },
      fall = { { Stage.P(960) }, { Stage.A(0, 0.9), Stage.S(0, 0.5) }, { Stage.A(600, -0.9), Stage.S(600, 4.4) } },
    },
    {
      name = "onde2", file = "Onde2.tga", box = "far", blend = "ADD", alpha = 0,
      open = { { Stage.P(1720) }, { Stage.A(0, 0.9), Stage.S(0, 0.5) }, { Stage.A(600, -0.9), Stage.S(600, 4) } },
      fall = { { Stage.P(1080) }, { Stage.A(0, 0.9), Stage.S(0, 0.5) }, { Stage.A(600, -0.9), Stage.S(600, 4.4) } },
    },
    {
      name = "tics", file = "Tics.tga", box = "far", blend = "BLEND", alpha = 0.6,
      open = { { Stage.A(0, -0.6) }, { Stage.P(2200) }, { Stage.A(400, 0.6) } },
      rest = { { Stage.R(90000, 360) } },
    },
    {
      name = "anneauFin", file = "AnneauFin.tga", box = "far", blend = "ADD", alpha = 1,
      open = { { Stage.A(0, -1) }, { Stage.P(2000) }, { Stage.A(300, 1) } },
    },
    {
      name = "anneauCode", file = "AnneauCode.tga", box = "far", blend = "BLEND", alpha = 0.85,
      open = { { Stage.A(0, -0.85) }, { Stage.P(2100) }, { Stage.A(500, 0.85) } },
      rest = { { Stage.R(40000, -360) } },
      fall = { { Stage.P(300) }, { Stage.R(660, -360) } },
    },
    crochet("crochetOr", "CrochetOr", 0, -360, 18000),
    crochet("crochetOrchidee", "CrochetOrchidee", 70, 360, 24000),
    crochet("crochetBleu", "CrochetBleu", 140, -360, 30000),
    {
      name = "debris", file = "Debris.tga", box = "far", blend = "ADD", alpha = 0,
      open = {
        { Stage.S(0, 0.4) }, { Stage.P(1650) }, { Stage.A(0, 1) },
        { Stage.A(700, -1), Stage.S(700, 4.75), Stage.R(700, -35) },
      },
      fall = {
        { Stage.S(0, 0.4) }, { Stage.P(960) }, { Stage.A(0, 1) },
        { Stage.A(840, -1), Stage.S(840, 5.75), Stage.R(840, 45) },
      },
    },
    glitch("glitch1", "Glitch1", 132, true),
    glitch("glitch2", "Glitch2", 147, false),
    glitch("glitch3", "Glitch3", 158, true),
    {
      name = "curseur", file = "Curseur.tga", box = "spot", blend = "BLEND", alpha = 0,
      open = {
        { Stage.A(0, 1) }, { Stage.P(90) }, { Stage.A(0, -1) }, { Stage.P(60) },
        { Stage.A(0, 1) }, { Stage.P(110) }, { Stage.A(0, -1) },
      },
      rest = {
        { Stage.T(0, 32, 0) }, { Stage.A(0, 1) }, { Stage.P(530) },
        { Stage.A(0, -1) }, { Stage.P(530) }, { Stage.T(0, -32, 0) },
      },
    },
    {
      name = "souligne", file = "Souligne.tga", box = "near", blend = "ADD", alpha = 0,
      x = 0, y = (140 - 182) * UNIT, ox = (180 - 240) * UNIT, oy = 0,
      fall = {
        { Stage.P(1100) }, { Stage.S(0, NUL), Stage.A(0, 1) }, { Stage.S(250, 1 / NUL) },
        { Stage.P(150) }, { Stage.A(300, -1) },
      },
    },
    {
      name = "coche", file = "Coche.tga", box = "spot", blend = "ADD", alpha = 0,
      x = (318 - 240) * UNIT, y = (140 - 182) * UNIT,
      fall = {
        { Stage.P(1300) }, { Stage.S(0, NUL), Stage.A(0, 1) }, { Stage.S(100, 1200) }, { Stage.S(100, 1 / 1.2) },
        { Stage.P(100) }, { Stage.A(300, -1) },
      },
    },
    etincelle("etincelle1", "Etincelle1", 800, (317.14 - 240) * UNIT, (140 - 48.08) * UNIT),
    etincelle("etincelle2", "Etincelle2", 2800, (281.04 - 240) * UNIT, (140 - 252.77) * UNIT),
    etincelle("etincelle3", "Etincelle3", 4800, (124.1 - 240) * UNIT, (140 - 108.94) * UNIT),
  }
end

local function definition()
  return {
    unit = UNIT,
    path = PATH,
    boxes = { near = 280, far = 512, spot = 40 },
    openMs = OPEN_MS,
    prestigeMs = PRESTIGE_MS,
    layers = couches(),
    copy = {
      fall = { { Stage.P(780) }, { Stage.A(180, -1) } },
    },
    count = {
      style = { font = PATH .. "Chiffre.ttf", size = 40, color = { 0.8, 0.8, 0.8 }, outline = "OUTLINE" },
      open = {
        { Stage.A(0, -1), Stage.S(0, 1.6) }, { Stage.P(1700) }, { Stage.S(250, 0.625) }, { Stage.A(200, 1) },
      },
      fall = {
        { Stage.A(0, -1), Stage.S(0, 2.4) }, { Stage.P(1100) }, { Stage.S(300, 0.41667) }, { Stage.A(200, 1) },
      },
    },
  }
end

EbonAPI.PrestigeAnimations.saut = function(ring, countText)
  Stage.build(ring, countText, definition())
end
