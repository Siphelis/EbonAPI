EbonAPI = EbonAPI or {}
local Replace = EbonAPI.Replace
if not Replace then return end

local Skins = EbonAPI.Skins
local ipairs, pcall, type = ipairs, pcall, type

local function frameOf(root, key)
    local f = root and root[key]
    if type(f) == "table" and f.GetObjectType then return f end
end

local function hideTextures(frame, keep)
    if not frame or not frame.GetRegions then return end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "Texture" and r ~= keep then
            Replace.hide(r)
        end
    end
end

local function piece(native, kind, opts)
    if not native or not native.GetPoint or not native:GetPoint(1) then return end
    local ok, p = pcall(Replace.piece, native, kind, opts)
    if ok then return p end
end

local function dress()
    local wc = _G.WardrobeCollectionFrame
    if not wc then return end
    local tab = frameOf(wc, "ItemsTab")
    if tab then
        hideTextures(tab)
        local p = piece(tab, "tab")
        local fs = tab.GetFontString and tab:GetFontString()
        if p and p.label and fs then
            p.label:SetText(tab:GetText() or "")
            Replace.hide(fs)
            if type(hooksecurefunc) == "function" then
                pcall(hooksecurefunc, tab, "SetText", function(self, text) if not p.released then p.label:SetText(text or "") end end)
            end
        end
    end
    local search = frameOf(wc, "searchBox")
    if search then hideTextures(search); piece(search, "input") end
    local bar = frameOf(wc, "progressBar")
    if bar then
        local keep = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil
        hideTextures(bar, keep)
        piece(bar, "bar", { border = Skins.value("tree.piece.barBorder") })
    end
    local filter = frameOf(wc, "FilterButton")
    if filter then hideTextures(filter); Replace.hide(filter.Icon); piece(filter, "button", { menu = true }); Replace.resetCross(filter, "transmog") end
    local items = frameOf(wc, "ItemsCollectionFrame")
    if not items then return end
    hideTextures(items)
    hideTextures(frameOf(items, "OverlayLayer"))
    for _, key in ipairs({ "BGCornerTopLeft", "BGCornerTopRight", "BGCornerBottomLeft", "BGCornerBottomRight" }) do
        if items[key] then Replace.hide(items[key]) end
    end
    piece(items, "panel")
    local weapon = frameOf(items, "WeaponDropDown") or frameOf(wc, "WeaponDropDown")
    if weapon then hideTextures(weapon); piece(weapon, "button") end
    for _, m in ipairs(items.Models or {}) do
        hideTextures(m)
        piece(m, "slot")
    end
    local paging = frameOf(items, "PagingFrame")
    if paging then
        local prev, nxt = frameOf(paging, "PrevPageButton"), frameOf(paging, "NextPageButton")
        if prev then hideTextures(prev); Replace.arrowLabel(piece(prev, "button"), true) end
        if nxt then hideTextures(nxt); Replace.arrowLabel(piece(nxt, "button"), false) end
    end
end

local function undress() end

Replace.tab("Transmog", { dress = dress, undress = undress })
