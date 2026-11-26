local _, ns = ...

local box
local boxLabel

local function T(key, fallback)
    local L = EbonBuilds.L
    local value = L and L[key]
    if type(value) == "string" and value ~= key then
        return value
    end
    return fallback
end

local function Managed()
    local automation = EbonBuilds.Automation
    local fn = automation and automation.ManagesSouvenirs
    return fn and fn()
end

local function OnClick(self)
    local build = EbonBuilds.Build.GetActive()
    if not build then return end
    local settings = {}
    for k, v in pairs(build.settings or {}) do
        settings[k] = v
    end
    settings.manageSouvenirs = self:GetChecked() and true or false
    EbonBuilds.Build.Save(build.id, { settings = settings })
end

local function Create(frame)
    box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    local label = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", box, "RIGHT", 2, 0)
    label:SetText(T("draw.souvenir.dontAsk", "Don't ask again"))
    boxLabel = label
    box:SetScript("OnClick", OnClick)
end

local function OnShow()
    local frame = EbonAPI.Ebonhold.PerkFrame()
    if not frame or not EbonAPI.Ebonhold.HasMemoryCard() or Managed() ~= false then
        if box then box:Hide() end
        return
    end
    if not box then Create(frame) end
    box:SetParent(frame)
    box:ClearAllPoints()
    local half = (box:GetWidth() + 2 + boxLabel:GetStringWidth()) / 2
    box:SetPoint("TOP", frame, "CENTER", 363 - half, -106)
    box:SetChecked(false)
    box:Show()
end

local function OnHide()
    if box then box:Hide() end
end

ns.DrawHook.After("Show", OnShow)
ns.DrawHook.After("Hide", OnHide)
