local Actions = EbonAPI.Actions

local type = type
local tostring = tostring

local function integer(value)
  return type(value) == "number" and value == value and value % 1 == 0
end

Actions.define({
  name = "SetVoidStorageTab", cs = "REQUEST_SET_USING_VOID_STORAGE",
  check = function(tabIndex)
    if not integer(tabIndex) or tabIndex < 0 then
      return "the tab index must be a non-negative integer (0 closes the storage)"
    end
  end,
  body = function(tabIndex)
    return tostring(tabIndex)
  end,
})

Actions.define({
  name = "RetrieveVoidItem", cs = "REQUEST_RETRIEVE_VOID_STORAGE_ITEM",
  check = function(slotIndex)
    if not integer(slotIndex) or slotIndex < 1 then
      return "the slot index must be a positive integer"
    end
  end,
  body = function(slotIndex)
    return tostring(slotIndex)
  end,
})

Actions.define({
  name = "RequestVoidTab", cs = "REQUEST_RETRIEVE_ITEMS_FROM_TAB",
  check = function(tabIndex)
    if not integer(tabIndex) or tabIndex < 1 then
      return "the tab index must be a positive integer"
    end
  end,
  body = function(tabIndex)
    return tostring(tabIndex)
  end,
})
