local Actions = EbonAPI.Actions

local type, tostring = type, tostring

Actions.define({
  name = "PurchaseShopItem", cs = "REQUEST_SHOP_PURCHASE",
  check = function(itemId)
    if type(itemId) ~= "number" or itemId ~= itemId or itemId % 1 ~= 0 or itemId <= 0 then
      return "the shop entry id must be a positive integer"
    end
  end,
  body = function(itemId)
    return tostring(itemId)
  end,
})

Actions.define({ name = "RequestShopDp", cs = "REQUEST_ACCOUNT_DP" })
