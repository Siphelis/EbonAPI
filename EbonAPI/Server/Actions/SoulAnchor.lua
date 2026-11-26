local Actions = EbonAPI.Actions

local type = type

local function contracts()
  local pe = _G.ProjectEbonhold

  return type(pe) == "table" and type(pe.Contracts) == "table" and pe.Contracts or {}
end

Actions.define({
  name = "AnchorSoul", cs = "REQUEST_SOUL_ANCHOR", service = { "Contracts", "Anchor" },
  check = function(release)
    if release ~= nil and type(release) ~= "boolean" then
      return "release must be true (release the anchor) or false/nil (anchor here)"
    end
  end,
  body = function(release) return release and "clear" or "" end,
  guard = function(release)
    local pe = _G.ProjectEbonhold

    if type(pe) ~= "table" or type(pe.sendToServer) ~= "function" then
      return "ProjectEbonhold cannot send to the server (no sendToServer): Contracts.Anchor would do nothing"
    end

    local state = contracts().anchorState

    if release and state ~= 1 then
      return "the soul is not anchored here: nothing to release"
    end

    if not release and state == 1 then
      return "the soul is already anchored here: pass release = true to release it"
    end
  end,
})
