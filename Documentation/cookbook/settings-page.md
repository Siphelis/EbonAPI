# Settings page

An addon that warns the player when their Soul Ashes reach a threshold. It has no window of its own: its settings live in the EbonAPI window, drawn by EbonAPI from one options table, in the player's language.

```lua title="AshAlert.lua"
local api = EbonAPI:NewAddon("AshAlert", 1, 0, { icon = "INV_Misc_Bell_01" })

if not api then
  return
end

local L = api:Locale({
  enUS = {
    ENABLED = "Enabled", ENABLED_DESC = "Show a notification when the threshold is reached.",
    THRESHOLD = "Threshold", SOUND = "Sound", NONE = "None", WARNING = "Raid warning", READY = "Ready check",
    MESSAGE = "Message", COLOR = "Color", TEST = "Test", RESET = "Reset",
    RESET_CONFIRM = "Put every setting of AshAlert back to its default?", DEFAULT_MESSAGE = "Soul Ashes ready!",
  },
  frFR = {
    ENABLED = "Activé", ENABLED_DESC = "Affiche une notification quand le seuil est atteint.",
    THRESHOLD = "Seuil", SOUND = "Son", NONE = "Aucun", WARNING = "Avertissement de raid", READY = "Appel",
    MESSAGE = "Message", COLOR = "Couleur", TEST = "Tester", RESET = "Réinitialiser",
    RESET_CONFIRM = "Remettre tous les réglages d'AshAlert par défaut ?", DEFAULT_MESSAGE = "Cendres d'âme prêtes !",
  },
})

local DEFAULTS = { enabled = true, threshold = 1000, sound = "none", message = "", color = { r = 1, g = 0.82, b = 0 } }
local db = api:DB({ account = DEFAULTS })

local function T(key)
  return function()
    return L[key]
  end
end

local function alert()
  local color = db.account.color
  local text = db.account.message ~= "" and db.account.message or L.DEFAULT_MESSAGE

  api:Notify(string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, text), {
    sound = db.account.sound ~= "none" and db.account.sound or nil,
  })
end

api:Options({
  type = "group",
  name = "AshAlert",
  get = function(info)
    return db.account[info[#info]]
  end,
  set = function(info, value)
    db.account[info[#info]] = value
  end,
  args = {
    enabled = { type = "toggle", order = 1, name = T("ENABLED"), desc = T("ENABLED_DESC") },
    threshold = {
      type = "range", order = 2, name = T("THRESHOLD"), min = 100, max = 5000, step = 50,
      disabled = function()
        return not db.account.enabled
      end,
    },
    sound = {
      type = "select", order = 3, name = T("SOUND"),
      values = function()
        return { none = L.NONE, RaidWarning = L.WARNING, ReadyCheck = L.READY }
      end,
    },
    message = { type = "input", order = 4, name = T("MESSAGE"), width = "full" },
    color = {
      type = "color", order = 5, name = T("COLOR"),
      get = function()
        local color = db.account.color

        return color.r, color.g, color.b
      end,
      set = function(info, r, g, b)
        db.account.color = { r = r, g = g, b = b }
      end,
    },
    test = { type = "execute", order = 6, name = T("TEST"), func = alert },
    reset = {
      type = "execute", order = 7, name = T("RESET"),
      func = function()
        api:Confirm(L.RESET_CONFIRM, function()
          for key, value in pairs(DEFAULTS) do
            db.account[key] = type(value) == "table" and { r = value.r, g = value.g, b = value.b } or value
          end

          api:RefreshOptions()
        end)
      end,
    },
  },
})

local warned = false

api:On("SERVER_RUN_DATA", function(event, run)
  if run.soulPoints < db.account.threshold then
    warned = false
  elseif db.account.enabled and not warned then
    warned = true
    alert()
  end
end)
```

## What happens

1. `api:Options` hands the whole settings page to EbonAPI. It appears as the **AshAlert** entry under **Addons** in the left column of the EbonAPI window, and the **Settings** button of the AshAlert card under **Connected addons** opens it.
2. One `get` and one `set` on the root serve every option: `info[#info]` is the key of the option, `enabled`, `threshold`, `sound` or `message`, which is also its key in `db.account`.
3. The color overrides `get` and `set`, because a color is three numbers (red, green, blue, each from 0 to 1), not one value: `get` returns the three, and `set` receives them after `info`.
4. Every option's `name` and `desc` is a function (through `T`), so the page changes language with the player. The root `name` is the addon's own name and stays a plain string. `values` is a function for the same reason.
5. **Threshold** turns grey while **Enabled** is off, through `disabled`.
6. **Reset** asks first with `api:Confirm`, which shows a dialog with **Yes** and **No** and runs your function on **Yes**. Its values change outside the page, so it calls `api:RefreshOptions()` to redraw it.
7. `SERVER_RUN_DATA` fires with each run update. The alert shows once when the ashes reach the threshold, and again only after they went back under it.

!!! tip "🎮 Try it"
    **Esc → EbonAPI → Addons → AshAlert**: set a low threshold, choose a sound, then click **Test**. Type `thr` in the **Search** box: it finds **Threshold** among the options of every addon.
