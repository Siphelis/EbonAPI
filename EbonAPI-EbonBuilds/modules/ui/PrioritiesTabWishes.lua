local _, ns = ...

local Tab = {}
ns.PrioritiesTabWishes = Tab

local tx = ns.PrioritiesState.Text
local W = ns.Widgets

local function stateOf()
  return ns.PrioritiesState.State() or {}
end

local function huntState()
  return ns.Reroll.HuntState()
end

local function cost()
  local value = huntState().cost
  if type(value) ~= "number" or value < 1 then return 1 end
  return value
end

local function nextFloor(row)
  local qualities = row.qualities or { row.floor }
  local following = qualities[1]
  for i = 1, #qualities do
    if qualities[i] == row.floor then following = qualities[i + 1] or qualities[1] end
  end
  return following
end

local function summary()
  local state = huntState()
  return string.format(tx("prio.wish.summary"), #ns.Wishlist.Armed(), state.drawsDone or 0, state.drawsPlanned or 0)
end

function Tab.Items()
  local items = {}
  for _, row in ipairs(ns.Wishlist.Armed()) do
    items[#items + 1] = {
      text = row.name,
      actions = {
        {
          text = ns.Reroll.QualityName(row.floor),
          tip = tx("prio.echo.minrarity"),
          onClick = function()
            ns.Wishlist.SetFloor(row.key, nextFloor(row))
            ns.PrioritiesState.Changed()
          end,
        },
        {
          text = tx("prio.remove"),
          onClick = function()
            ns.Wishlist.Remove(row.sample)
            ns.PrioritiesState.Changed()
          end,
        },
      },
    }
  end
  return items
end

function Tab.Build(page, width, height)
  local pad = EbonAPI.Skins.value("kit.padding") or 0
  local inner = math.max(1, width - pad * 2)
  local root = page:Add("bar", { layout = "VERTICAL", width = inner })

  root:Add("text", { text = summary, width = inner })

  root:Add("input", {
    text = tx("prio.wish.budget"),
    width = inner,
    get = function()
      return tostring(math.floor((huntState().budget or 0) / cost()))
    end,
    onChange = function(_, text)
      local number = tonumber(text)
      if not number then return end
      ns.Reroll.SetBudget(math.max(1, math.floor(number)) * cost())
      ns.PrioritiesState.Changed()
    end,
  })

  local actions = root:Add("bar", { layout = "VERTICAL", width = inner })

  actions:Add("button", {
    text = tx("prio.wish.add"),
    width = inner,
    disabled = function()
      local echoId = stateOf().echoId
      return echoId == nil or ns.Wishlist.Has(echoId)
    end,
    onClick = function()
      local echoId = stateOf().echoId
      if not echoId or ns.Wishlist.Has(echoId) then return end
      ns.Wishlist.Toggle(echoId)
      ns.PrioritiesState.Changed()
    end,
  })

  actions:Add("button", {
    text = tx("prio.wish.hunt"),
    width = inner,
    onClick = function() ns.HuntWindow.Open() end,
  })

  local wishes = W.Scroll(root, { width = inner, height = 1, layout = "VERTICAL" })
  local list = wishes._content:Add("list", {
    items = Tab.Items,
    width = inner,
    height = 1,
    frame = "FLAT",
  })

  local used = root:GetHeight() - 1
  W.ScrollSize(wishes, inner, math.max(1, height - used))
  list:SetHeight(math.max(1, height - used))
  EbonAPI.Kit.relayout(root, true)

  local function refresh() root:Refresh() end

  ns.PrioritiesState.Subscribe(function(changed)
    if changed == "echo" or changed == "tab" or changed == "build" or changed == "data" then
      if root:IsShown() then refresh() end
    end
  end)

  return root, refresh
end

function Tab.Refresh(element)
  if element and element.Refresh then element:Refresh() end
end
