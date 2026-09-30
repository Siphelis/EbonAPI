EbonAPI = EbonAPI or {}
EbonAPI.Listeners = {}

local Listeners = EbonAPI.Listeners
local fanout = EbonAPI.fanout

local setmetatable = setmetatable

local List = {}
List.__index = List

function Listeners.new()
  return setmetatable({ n = 0, fns = {}, owners = {}, busy = 0 }, List)
end

function List:index(fn, owner)
  local fns, owners = self.fns, self.owners

  for i = 1, self.n do
    if fns[i] == fn and owners[i] == owner then
      return i
    end
  end

  return nil
end

local function mutable(self)
  if self.busy > 0 then
    local fns, owners = {}, {}
    local oldFns, oldOwners = self.fns, self.owners

    for i = 1, self.n do
      fns[i] = oldFns[i]
      owners[i] = oldOwners[i]
    end

    self.fns, self.owners = fns, owners
  end
end

function List:add(fn, owner)
  if self:index(fn, owner) then
    return false
  end

  mutable(self)

  local n = self.n + 1

  self.n = n
  self.fns[n] = fn
  self.owners[n] = owner

  return true
end

function List:remove(fn, owner)
  local found = self:index(fn, owner)

  if not found then
    return false
  end

  mutable(self)

  local fns, owners, n = self.fns, self.owners, self.n

  for i = found, n - 1 do
    fns[i] = fns[i + 1]
    owners[i] = owners[i + 1]
  end

  fns[n] = nil
  owners[n] = nil
  self.n = n - 1

  return true
end

function List:fire(...)
  local n = self.n

  if n == 0 then
    return 0
  end

  self.busy = self.busy + 1
  fanout(self.fns, self.owners, n, ...)
  self.busy = self.busy - 1

  return n
end
