EbonAPI:RegisterSkin("Midnight", {
  parent = "AutoCallboard",

  background = 0x0B1020,
  accent = 0x3FA7F5,
  opacity = 0.55,
  shadow = 0.7,
  corners = 6,

  window = {
    glass = { enabled = true, tint = 0xB8D4FF, darken = 0.45, milk = 0.06, grain = 0.05, sheen = 0.1, edge = 0.14 },
    gradient = { orientation = "VERTICAL", color = "selected", to = 0.08 },
    fade = 0.15,
  },

  nav = {
    tab = { brick = "bar", align = "LEFT" },
  },

  widgets = {
    toggle = { brick = "switch" },
    group = { brick = "line" },
    heading = { lines = "AFTER" },
    range = { fill = true },
  },
})
