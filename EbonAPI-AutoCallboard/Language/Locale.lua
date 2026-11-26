AutoCallboardLocales = AutoCallboardLocales or {}
AutoCallboardRuntime = AutoCallboardRuntime or {}
local RT = AutoCallboardRuntime

RT.api = EbonAPI:NewAddon("AutoCallboard", 2, 1, {
  icon = "Achievement_Quests_Completed_08",
  url = "https://github.com/Siphelis/EbonAPI/releases/latest",
})
AutoCallboardLocale = RT.api:Locale(AutoCallboardLocales)
