local NS = SkillTreeAutoLoad
local L = NS.L

NS.Dense = NS.Dense or {}

local Chrome = {}
NS.Dense.Chrome = Chrome
local current

local function Dense(name) return EbonAPI.Skins.value("tree.dense." .. name) end
local Common = EbonAPI.Common
local CURRENCY_LABEL = "DENSE_CURRENCY_"

local NO_TEXT = ""

local Format = NS.Text

local function HubName(hub)
    if not hub then return "" end
    return (hub.token and L["CLASS_" .. hub.token]) or hub.name or tostring(hub.classId)
end

local function CurrencyName(currency)
    return L[CURRENCY_LABEL .. tostring(currency or Common.get("stal.defaultCurrency")):upper()]
end

local ICON_TOKEN = { ash = "currencyAsh", shard = "currencyShard", essence = "currencyEssence", artisan = "currencyArtisan" }

local function TokenOf(currency)
    for _, token in ipairs(EbonAPI.Counter.tokens) do
        if token == currency then return token end
    end
    return Common.get("stal.defaultCurrency")
end

local function ClassCoords(hub)
    local token = hub and hub.token
    if not token then return nil end
    return (_G.CLASS_BUTTONS and _G.CLASS_BUTTONS[token]) or (_G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[token])
end

local STATE_LABEL = {
    active = "DENSE_STATE_ACTIVE", ready = "DENSE_STATE_READY", nopoints = "DENSE_STATE_NOPOINTS",
    locked = "DENSE_STATE_LOCKED",
}
local STATE_UNKNOWN = "DENSE_STATE_UNKNOWN"
local PE_NO_DESCRIPTION = "Click for details"
local descriptions = {}

local function Describe(spell, stacks)
    local key = spell .. ":" .. stacks
    local text = descriptions[key]
    if text == nil then
        local pe = _G.utils
        text = pe and type(pe.GetSpellDescription) == "function" and pe.GetSpellDescription(spell, math.huge, stacks) or ""
        if text == PE_NO_DESCRIPTION then text = "" end
        descriptions[key] = text
    end
    return text ~= "" and text or nil
end

local function Channel(value)
    return math.max(0, math.min(255, math.floor((tonumber(value) or 1) * 255 + 0.5)))
end

local function Colored(text, r, g, b)
    if not text or text == NO_TEXT then return NO_TEXT end
    if string.find(text, "|c%x%x%x%x%x%x%x%x") then return text end
    return string.format("|cff%02x%02x%02x", Channel(r), Channel(g), Channel(b)) .. text .. "|r"
end

local function ReadLines(tip, rows)
    if not (tip and tip.IsShown and tip:IsShown() and tip.NumLines and tip.GetName) then return end
    local name = tip:GetName()
    if not name then return end
    for i = 1, tip:NumLines() or 0 do
        local left, right = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
        local lt = left and left:GetText() or NO_TEXT
        local rt = right and right:GetText() or NO_TEXT
        local lr, lg, lb = 1, 1, 1
        local rr, rg, rb = 1, 1, 1
        if left then lr, lg, lb = left:GetTextColor() end
        if right then rr, rg, rb = right:GetTextColor() end
        rows[#rows + 1] = { Colored(lt, lr, lg, lb), Colored(rt, rr, rg, rb) }
    end
end

local function Blank(row)
    return row[1] == NO_TEXT and row[2] == NO_TEXT
end

local function Arrange(rows)
    local first, last
    for index, row in ipairs(rows) do
        if not Blank(row) then
            first = first or index
            last = index
        end
    end
    if not first then return nil end
    local out, gap = {}, false
    for index = first, last do
        local row = rows[index]
        if Blank(row) then
            gap = true
        else
            if gap then out[#out + 1] = { NO_TEXT, NO_TEXT } end
            gap = false
            out[#out + 1] = row
        end
    end
    return out
end

function Chrome.Create(parent, bottom)
    local frame = parent
    local chrome = { frame = frame, bottom = bottom, classButtons = {}, counters = {}, balanceTexts = {}, callbacks = {},
        kit = {}, bottomItems = {} }

    local function Make(kind, owner, spec)
        local element = NS.api:Create(kind, owner, spec)
        chrome.kit[#chrome.kit + 1] = element
        if owner == bottom then chrome.bottomItems[#chrome.bottomItems + 1] = element end
        return element
    end

    local function Emit(name, ...)
        local fn = chrome.callbacks[name]
        if not fn then return end
        local ok, err = pcall(fn, ...)
        if not ok then chrome.lastError = err end
    end

    local function Action(text, flag, event)
        return Make("button", bottom, {
            text = text,
            disabled = function() return not chrome[flag] end,
            onClick = function()
                if chrome[flag] then Emit(event) end
            end,
        })
    end

    local roundSize = EbonAPI.Skins.value(Common.get("stal.roundSizeKey"))
    local PAD, GAP = Dense("pad"), Dense("gap")
    local bar = Make("bare", frame, { width = roundSize + 2 * PAD })
    chrome.bar = bar

    local function Coords(button)
        local coords = ClassCoords(button.hub)
        if coords and button.icon then button.icon:SetTexCoord(unpack(coords)) end
    end
    local function PaintHalo(button)
        local on = (chrome.activeClass ~= nil and button.classId == chrome.activeClass)
        if not (on or button.hovered) then NS.Overlay.HideClassHalo(button) return end
        NS.Overlay.ClassHalo(button, button.hub, on)
    end
    local function PaintClass(button)
        local on = (chrome.activeClass ~= nil and button.classId == chrome.activeClass)
        button:SetActive(on)
        Coords(button)
        PaintHalo(button)
    end

    local hubs = (NS.Dense.Data and NS.Dense.Data.Hubs) or {}
    local centerRank = math.floor(#hubs / 2) + 1
    local function PlaceRound(button, rank)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bar, "TOPLEFT", PAD, -(PAD + (rank - 1) * (roundSize + GAP)))
        button:SetSize(roundSize, roundSize)
    end
    -- Icones de classe : pas de carre de fond ni de bordure du skin (survol, coche, pressé) ; seul le halo de classe reste.
    -- Le bouton centre garde sa brique.
    local function Unframed(button)
        local base = button.Paint
        button.Paint = function(self)
            base(self)
            EbonAPI.Bricks.unframe(self)
        end
        button:Paint()
    end
    for index, hub in ipairs(hubs) do
        local button = Make("round", bar, {
            icon = Dense("hubIcon"),
            label = Format("DENSE_GOTO_CLASS", { name = HubName(hub) }),
            onClick = function() Emit("class", hub.classId) end,
        })
        button.classId, button.hub = hub.classId, hub
        Unframed(button)
        PlaceRound(button, index < centerRank and index or index + 1)
        Coords(button)
        button:HookScript("OnEnter", function()
            button.hovered = true
            NS.Nav.ClassTip(button, button.hub, chrome.activeClass ~= nil and button.classId == chrome.activeClass)
            NS.Nav.PreviewClass(button.classId)
        end)
        button:HookScript("OnLeave", function()
            button.hovered = false
            GameTooltip:Hide()
            NS.Nav.EndPreview()
            NS.Overlay.HideClassHalo(button)
            PaintHalo(button)
        end)
        chrome.classButtons[index] = button
    end
    local center = Make("round", bar, {
        icon = Dense("centerIcon"),
        portrait = true,
        label = L.NAV_CENTER,
        onClick = function() Emit("center") end,
    })
    PlaceRound(center, centerRank)
    chrome.center = center
    center:HookScript("OnEnter", function() NS.Nav.CenterTip(center) end)
    center:HookScript("OnLeave", function()
        GameTooltip:Hide()
        NS.Overlay.HideClassHalo(center)
    end)


    local slot = Make("bare", frame, { width = Dense("slotWidth") })
    chrome.slot = slot
    chrome.slotWidth = Dense("slotWidth")
    chrome.rightInset = 0
    chrome.leftInset = 0
    local window = NS.UI.GetTreeWindow()
    local roof = window and window.Bg or frame

    local notice = Make("bare", frame, { height = Dense("noticeHeight") })
    chrome.notice = notice
    chrome.noticeValue = ""
    local noticeText = Make("status", notice, {
        text = function() return chrome.noticeValue end,
        color = Dense("noticeKey"),
    })
    notice:SetScript("OnSizeChanged", function(_, width)
        noticeText.spec.width = math.max(width - 2 * PAD, 1)
        noticeText:Refresh()
    end)
    noticeText:SetPoint("LEFT", notice, "LEFT", PAD, 0)
    chrome.noticeText = noticeText.text
    notice:Hide()

    local order = NS.Cost and NS.Cost.CURRENCIES or {}
    local previous
    for index = 1, #order do
        local key = order[index] and order[index].key
        local counter = Make("counter", bottom, {
            token = TokenOf(key),
            icon = ICON_TOKEN[key] and Dense(ICON_TOKEN[key]) or nil,
            value = NO_TEXT,
        })
        counter:ClearAllPoints()
        if previous then
            counter:SetPoint("LEFT", previous, "RIGHT", GAP, 0)
        else
            counter:SetPoint("LEFT", bottom, "LEFT", PAD, 0)
        end
        previous = counter
        chrome.counters[index] = counter
        chrome.balanceTexts[index] = counter.text
    end

    local apply = Action(L.DENSE_APPLY, "applyEnabled", "apply")
    chrome.applyButton = apply
    apply:ClearAllPoints()
    apply:SetPoint("LEFT", previous, "RIGHT", GAP, 0)

    local dress = EbonAPI.DressTree
    if dress and type(dress.setSearchAfter) == "function" then pcall(dress.setSearchAfter, apply) end

    local tip = Make("tipcard", frame, {})
    chrome.tip = tip

    function chrome:SetBalances(list)
        for index = 1, #self.counters do
            local counter, item = self.counters[index], list and list[index]
            if item then
                counter.currency = item.currency
                counter:SetToken(TokenOf(item.currency))
                counter:SetTip(CurrencyName(item.currency), item.source == "server" and L.DENSE_BALANCE_SERVER or nil)
                counter:SetValue(EbonAPI.Format.number(item.amount))
            else
                counter.currency = nil
                counter:SetValue(NO_TEXT)
            end
        end
    end

    function chrome:SetActiveClass(classId)
        self.activeClass = classId
        for _, button in ipairs(self.classButtons) do PaintClass(button) end
    end

    local function PeTip() return rawget(_G, "skillTreeCurrentRankTooltip") end
    local function PeNextTip() return rawget(_G, "skillTreeNextRankTooltip") end

    local function ReadPeTips()
        local rows = {}
        ReadLines(PeTip(), rows)
        ReadLines(PeNextTip(), rows)
        return rows
    end

    local function HidePeTips()
        local tip, nextTip = PeTip(), PeNextTip()
        if tip and tip.Hide then tip:Hide() end
        if nextTip and nextTip.Hide then nextTip:Hide() end
    end

    function chrome:HideTip()
        local btn = self.peButton
        self.peButton = nil
        if btn then
            local onLeave = btn:GetScript("OnLeave")
            if onLeave then pcall(onLeave, btn) end
        end
        HidePeTips()
        if self.tipShown then self.tip:Hide() end
        self.tipShown = false
    end

    function chrome:ShowTip(id, snapshot, anchor)
        if not id then return end
        self:HideTip()
        snapshot = snapshot or {}
        local data = NS.Dense.Data
        local node = data and data.ById and data.ById[id]
        local rank = snapshot.rank and snapshot.rank[id] or 0
        local max = snapshot.max and snapshot.max[id]
        local state = snapshot.state and snapshot.state[id]

        local btn = NS.Core and NS.Core.NodeButton and NS.Core.NodeButton(id)
        local onEnter = btn and btn.GetScript and btn:GetScript("OnEnter")
        local choice = btn and btn.isMultipleChoice and btn.spells and #btn.spells > 1 and not btn.classId
        local rows = {}
        if onEnter and not choice then
            self.peButton = btn
            if pcall(onEnter, btn) then
                local okRead, read = pcall(ReadPeTips)
                if okRead and read then rows = Arrange(read) or {} end
            end
            HidePeTips()
        end

        local icon = data and data.IconOf and data.IconOf(id)
        local function Iconed(text)
            if icon then return "|T" .. icon .. ":" .. Dense("tipIcon") .. "|t " .. text end
            return text
        end

        local title, body, lines
        if #rows > 0 then
            local head = table.remove(rows, 1)
            if head[1] ~= NO_TEXT then
                title = Iconed(head[1])
                if head[2] ~= nil and head[2] ~= NO_TEXT and head[2] ~= "" then
                    table.insert(rows, 1, { NO_TEXT, head[2] })
                end
            else
                title = Iconed(head[2])
            end
            lines = rows
        else
            lines = {}
            title = Iconed((data and data.NameOf and data.NameOf(id)) or tostring(id))
            local spells = node and node.spells
            if spells and spells[1] then
                local stacks = math.max(rank, 1)
                body = Describe(spells[math.min(#spells, stacks)], stacks)
            end
            if max then lines[#lines + 1] = { Format("DENSE_RANK", { rank = rank, max = max }), NO_TEXT } end
            local cost = node and node.soulPointsCosts and node.soulPointsCosts[rank + 1]
            if cost and (not max or rank < max) then
                lines[#lines + 1] = { Format("DENSE_COST", { cost = EbonAPI.Format.number(cost) .. " " .. CurrencyName(node.currency) }), NO_TEXT }
            end
        end
        lines[#lines + 1] = { L[STATE_LABEL[state] or STATE_UNKNOWN], NO_TEXT }
        if snapshot.pending and snapshot.pending[id] then lines[#lines + 1] = { L.DENSE_PENDING, NO_TEXT } end
        if snapshot.preset and snapshot.preset[id] then lines[#lines + 1] = { L.DENSE_PRESET_MARK, NO_TEXT } end

        self.tip:Show(anchor or self.bar, { title = title, body = body, lines = lines })
        self.tipShown = true
    end

    function chrome:OnClass(fn) self.callbacks.class = fn end
    function chrome:OnCenter(fn) self.callbacks.center = fn end
    function chrome:OnApply(fn) self.callbacks.apply = fn end

    function chrome:SetApplyEnabled(enabled)
        self.applyEnabled = enabled and true or false
        apply:Refresh()
    end

    function chrome:SetNotice(text)
        local shown = text and text ~= ""
        self.noticeValue = shown and text or ""
        noticeText:Refresh()
        if shown then notice:Show() else notice:Hide() end
    end

    function chrome:Restyle()
        EbonAPI.Palette.repaint()
        for _, element in ipairs(self.kit) do element:Refresh() end
        for _, button in ipairs(self.classButtons) do PaintClass(button) end
    end

    local function Dock(on)
        for _, element in ipairs(chrome.bottomItems) do
            if on then element:Show() else element:Hide() end
        end
        if NS.UI and NS.UI.Dock then pcall(NS.UI.Dock) end
    end
    frame:HookScript("OnShow", function() Dock(true) end)
    frame:HookScript("OnHide", function() Dock(false) end)
    for _, element in ipairs(chrome.bottomItems) do element:Hide() end
    current = chrome

    function chrome:Layout(side, shown)
        local left = side == "LEFT"
        local width = shown and self.slotWidth or 0
        self.leftInset = (shown and left) and width or 0
        self.rightInset = (shown and not left) and width or 0
        slot:ClearAllPoints()
        slot:SetWidth(width)
        if left then
            slot:SetPoint("TOPLEFT", roof, "TOPLEFT", 0, 0)
            slot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        else
            slot:SetPoint("TOPRIGHT", roof, "TOPRIGHT", 0, 0)
            slot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        end
        if shown then slot:Show() else slot:Hide() end
        -- La barre des classes est du côté opposé au panneau : à droite si le panneau est à gauche, à gauche sinon.
        bar:ClearAllPoints()
        if left then
            bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        else
            bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        end
        notice:ClearAllPoints()
        if left then
            notice:SetPoint("TOPLEFT", frame, "TOPLEFT", self.leftInset, 0)
            notice:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
        else
            notice:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
            notice:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -self.rightInset, 0)
        end
        if self.onLayout then self.onLayout() end
    end
    chrome:Layout("RIGHT", false)

    chrome:SetApplyEnabled(false)
    chrome:SetActiveClass(nil)
    chrome:SetBalances(nil)
    return chrome
end

function Chrome.Current()
    if current and current.frame and current.frame:IsVisible() then return current end
    return nil
end
