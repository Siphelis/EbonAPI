EbonAPI:RegisterSkin("Split", {
  parent = "AutoCallboard",

  windows = {
    detach = { nav = true, pages = true },
    snap = 16,
  },

  header = {
    controls = "LEFT",
  },

  widgets = {
    cells = { shape = "square" }, queue = { shape = "square" }, strip = { shape = "square" }, cards = { shape = "square" },
    -- Saves: like AutoCallboard, but the detail drawer docks at the bottom of the panel.
    saves = { view = "list", detail = "dock", row = { frame = "SMALL", fill = "card", border = "borderDim" } },
    choice = {
      segment = { frame = "FLAT", fill = "card", border = "border" },
      chips = { frame = "FLAT", fill = "card", border = "border" },
    },
    pill = { frame = "FLAT", fill = "card", border = "border", info = "focus" },
    tile = {
      frame = "FLAT", fill = "card", border = "border", accent = "selected",
      gauge = { back = "borderDim" },
    },
    map = { frame = "FLAT", border = "border", gray = { low = "borderDim", high = "border" } },
  },

  kit = {
    chart = { color = "checked", column = "bgSoft", label = "muted", value = "text", series = { s1 = 0xB048F8, s2 = 0xE879FF, s3 = 0x4855F8, s4 = 0x48ADF8, s5 = 0xD1D1F6 }, others = 0x4B2E83 },
    table = {
      bar = { fill = "selected", back = "borderDim" },
      group = { fill = "card", chevron = "focus" },
    },
  },
})
