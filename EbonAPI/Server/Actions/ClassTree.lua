local Actions = EbonAPI.Actions

local type, tostring = type, tostring

Actions.define({
  name = "RequestClassTree", cs = "REQUEST_CLASS_TREE_DATA", service = { "ClassTree", "Request" },
})

Actions.define({
  name = "BuyClassNode", cs = "REQUEST_CLASS_NODE_BUY",
  check = function(nodeId)
    if type(nodeId) ~= "number" or nodeId ~= nodeId or nodeId % 1 ~= 0 or nodeId <= 0 then
      return "the node id must be a positive integer"
    end
  end,
  body = function(nodeId) return tostring(nodeId) end,
})
