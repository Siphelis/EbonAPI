local Actions = EbonAPI.Actions

Actions.define({
  name = "RequestPrestigeData", cs = "REQUEST_PRESTIGE_DATA",
  service = { "PrestigeService", "RequestPrestigeData" },
})

Actions.define({
  name = "DoPrestige", cs = "REQUEST_DO_PRESTIGE",
  service = { "PrestigeService", "DoPrestige" },
})
