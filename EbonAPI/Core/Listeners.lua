EbonAPI = EbonAPI or {}
EbonAPI.Listeners = {}

local Listeners = EbonAPI.Listeners
local fanout = EbonAPI.fanout

local setmetatable = setmetatable

local List = {}
List.__index = List

function Listeners.new()
  return setmetatable({ n = 0, fns = {}, busy = 0 }, List)
end

function List:index(fn)
  local fns = self.fns

  for i = 1, self.n do
    if fns[i] == fn then
      return i
    end
  end

  return nil
end

local function mutable(self)
  if self.busy > 0 then
    local fns = {}
    local old = self.fns

    for i = 1, self.n do
      fns[i] = old[i]
    end

    self.fns = fns
  end
end

function List:add(fn)
  if self:index(fn) then
    return false
  end

  mutable(self)

  local n = self.n + 1

  self.n = n
  self.fns[n] = fn

  return true
end

function List:remove(fn)
  local found = self:index(fn)

  if not found then
    return false
  end

  mutable(self)

  local fns, n = self.fns, self.n

  for i = found, n - 1 do
    fns[i] = fns[i + 1]
  end

  fns[n] = nil
  self.n = n - 1

  return true
end

function List:fire(...)
  local n = self.n

  if n == 0 then
    return 0
  end

  self.busy = self.busy + 1
  fanout(self.fns, n, ...)
  self.busy = self.busy - 1

  return n
end
