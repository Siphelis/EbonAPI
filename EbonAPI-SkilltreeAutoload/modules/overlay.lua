local NS = SkillTreeAutoLoad

local Overlay = {}
NS.Overlay = Overlay

-- Plus bas sous-niveau de dessin du moteur (3.3.5) : le halo passe sous tout ce que le bouton dessine dans BACKGROUND.
local HALO_SUBLEVEL = EbonAPI.Common.get("stal.haloSublevel")

local function DenseToken(name) return EbonAPI.Skins.value("tree.dense." .. name) end

local HexToRGB = NS.HexToRGB

function Overlay.NodeHalo(btn, currency)
    local grow = DenseToken("nodeHaloGrow")
    local tex = btn.halo
    if not tex then
        tex = btn:CreateTexture(nil, "BACKGROUND")
        tex:SetDrawLayer("BACKGROUND", HALO_SUBLEVEL)
        btn.halo = tex
    end
    tex:SetTexture(DenseToken("nodeHaloTex"))
    tex:SetBlendMode("BLEND")
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", btn, "TOPLEFT", -grow, grow)
    tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", grow, -grow)

    local colors = NS.PresetsData and NS.PresetsData.currencyColor or {}
    local r, g, b = HexToRGB(colors[currency])
    if r then
        tex.paintKey = nil
        tex:SetVertexColor(r, g, b)
    else
        local key = DenseToken("hubKey")
        if tex.paintKey ~= key then
            tex.paintKey = key
            EbonAPI.Palette.paint(tex, "SetVertexColor", key)
        end
    end
    tex:SetAlpha(1)
    tex:Show()
end

function Overlay.HideNodeHalo(btn)
    if btn and btn.halo then btn.halo:Hide() end
end

function Overlay.ClassHalo(button, hub, own)
    local grow = DenseToken("haloGrow")
    local tex = button.halo
    if not tex then
        tex = button:CreateTexture(nil, "BACKGROUND")
        tex:SetDrawLayer("BACKGROUND", HALO_SUBLEVEL)
        button.halo = tex
    end
    tex:SetTexture(DenseToken("hubRing"))
    tex:SetBlendMode("BLEND")
    local r, g, b = HexToRGB(hub and hub.color)
    if r then
        tex:SetVertexColor(r, g, b)
    else
        EbonAPI.Palette.paint(tex, "SetVertexColor", DenseToken("hubKey"))
    end
    tex:SetAlpha(own and 1 or 0.7)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", -grow, grow)
    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", grow, -grow)
    tex:Show()
end

function Overlay.HideClassHalo(button)
    if button and button.halo then button.halo:Hide() end
end
