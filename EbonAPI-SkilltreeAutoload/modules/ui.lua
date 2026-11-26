local NS = SkillTreeAutoLoad
local FormatCost = function(sum) return (NS.Cost.Format(sum)) end
local function StackedCost(format, ...)
    local args = { ... }
    local last = #args
    local text, count = NS.Cost.Format(args[last], "\n")
    if count and count > 1 then text = "\n" .. text end
    args[last] = text
    return (string.format(format, unpack(args)):gsub(" \n", "\n"))
end
local L = NS.L

local UI = {}
NS.UI = UI

local NO_NODES = {}
local INFINITE_NEED = 1e12

local panel, saves, presets, tabs

local function ActiveList()
    return (tabs and tabs:Selected() == "presets" and presets) or saves
end

local function Status(text, kind)
    local list = ActiveList()
    if list then list:SetStatus(text, kind) end
end

local function GetAnySave(saveId)
    if NS.Presets and NS.Presets.IsPresetId(saveId) then return NS.Presets.GetSave(saveId) end
    return NS.Data.GetSave(saveId)
end

local savePlans = {}

local function Total(sum)
    local total = 0
    for _, amount in pairs(sum or NO_NODES) do total = total + amount end
    return total
end

local function BudgetKey(budgets)
    local parts = {}
    for i = 1, #NS.Cost.CURRENCIES do
        local key = NS.Cost.CURRENCIES[i].key
        parts[i] = tostring(budgets and budgets[key])
    end
    return table.concat(parts, ":")
end

local function Unreadable(sum, budgets)
    if not budgets then return true end
    for currency, amount in pairs(sum or NO_NODES) do
        if amount > 0 and budgets[currency] == nil then return true end
    end
    return false
end

local function GetSavePlan(saveId, save, snapshot)
    local stamp = NS.Core.GetSnapshotStamp()
    local plan = savePlans[saveId]
    if plan and plan.stamp == stamp then return plan end

    plan = plan or {}
    plan.totalCost, plan.pendingNodes, plan.needs = NS.Core.ComputeActivationPlan(save.nodeRanks, snapshot)
    plan.ownedCost, plan.saveCost, plan.ownedNodes, plan.totalNodes =
        NS.Plan.ComputeProgress(save.nodeRanks, snapshot)

    plan.stamp = plan.totalCost and stamp or nil
    plan.progStamp = nil
    savePlans[saveId] = plan
    return plan
end

local function GetProgressivePlan(plan, save, snapshot, budgets)
    local budgetKey = BudgetKey(budgets)
    if plan.stamp and plan.progStamp == plan.stamp and plan.progBudget == budgetKey then
        return plan.chosen, plan.spent, plan.count, plan.blocked
    end

    local chosen, spent, count, blocked =
        NS.Plan.ComputeProgressive(save.nodeRanks, snapshot, budgets or NO_NODES)
    if chosen then
        plan.chosen, plan.spent, plan.count, plan.blocked = chosen, spent, count, blocked
        plan.progStamp, plan.progBudget = plan.stamp, budgetKey
    end
    return chosen, spent, count, blocked
end

local function ActivationFailed(save, detail)
    NS.api:Report(NS.api:Problem("ACTIVATION.FAILED", { save = save.name, detail = tostring(detail) }))
end

local autoAttemptRan
local placedPrint, applySentAt
local APPLY_GUARD = 5

local function ApplyButtonEnabled()
    local button = NS.Dense.State.ApplyButton()
    if not button then return false end
    local enabled = button:IsEnabled()
    return enabled and enabled ~= 0 and true or false
end

local function TreeIsClean()
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return false end
    local tree = EbonAPI.Ebonhold.Service("ClassTree")
    if type(tree) == "table" and type(tree.HasPending) == "function" and tree.HasPending() then return false end
    return NS.Dense.State.ApplyButton() ~= nil and not ApplyButtonEnabled()
end

local function TreeFingerprint()
    NS.Core.InvalidateSnapshot()
    local snapshot = NS.Core.GetTreeSnapshot()
    if type(snapshot) ~= "table" then return nil end
    local ids = {}
    for nodeId, rank in pairs(snapshot) do
        if rank and rank ~= 0 then ids[#ids + 1] = nodeId end
    end
    table.sort(ids)
    for i = 1, #ids do ids[i] = ids[i] .. ":" .. snapshot[ids[i]] end
    return table.concat(ids, ",")
end

local function ApplyInFlight()
    return applySentAt ~= nil and GetTime() - applySentAt < APPLY_GUARD
end

local function ApplyPlacedNodes(save)
    if InCombatLockdown() then return end
    local db = rawget(_G, "ProjectEbonholdDB")
    if not (type(db) == "table" and db.seenSkillTreeSpendWarning) then return end
    if not ApplyButtonEnabled() then return end
    local ok, err = pcall(NS.Dense.State.Apply)
    if not ok then
        ActivationFailed(save, err)
        Status(tostring(err), "bad")
        return
    end
    applySentAt = GetTime()
    NS.api:After("apply-retry", APPLY_GUARD + 0.5, function() UI.RetryAutoAdd() end)
end

local function ActivateSave(saveId, auto)
    autoAttemptRan = false
    local save = GetAnySave(saveId)
    if not save then return false end

    NS.Core.InvalidateSnapshot()
    local snapshot = NS.Core.GetTreeSnapshot()
    local totalCost, pendingNodes = NS.Core.ComputeActivationPlan(save.nodeRanks, snapshot)
    if not pendingNodes then
        if auto then return false end
        NS.api:Report(NS.api:Problem("TREE.NOT_READY", { detail = L.ERR_READ_TREE }))
        Status(L.ROW_READ_FAILED, "bad")
        return false
    end
    if pendingNodes == 0 then
        if auto then autoAttemptRan = true return false end
        local message = string.format(L.MSG_ALREADY_ACTIVE, save.name)
        NS.api:Notify(message)
        Status(message, "ok")
        return false
    end

    local targets, touched, partial = save.nodeRanks, pendingNodes, false

    if save.progressive or auto then
        local budgets = NS.Core.GetBudgets()
        if Unreadable(totalCost, budgets) then
            if not auto then Status(L.ROW_READ_FAILED, "bad") end
            return false
        end
        autoAttemptRan = true
        local chosen, _, count, blocked =
            NS.Plan.ComputeProgressive(save.nodeRanks, snapshot, budgets)

        if not chosen then
            ActivationFailed(save, L.ERR_NO_GRAPH)
            Status(L.ERR_NO_GRAPH, "bad")
            return false
        end
        if count == 0 then
            if auto then return false end
            NS.api:Report(NS.api:Problem("PROGRESSIVE.NOTHING_AFFORDABLE",
                { save = save.name, balance = FormatCost(budgets), cost = blocked and FormatCost(blocked) or "?" }))
            local missing = blocked and NS.Cost.Shortfall(blocked, budgets)
            Status(missing and string.format(L.ROW_BLOCKED, FormatCost(missing)) or L.ROW_READ_FAILED, "bad")
            return false
        end

        targets, touched, partial = chosen, count, count < pendingNodes
    else
        local budgets = NS.Core.GetBudgets()
        local refusal = not Unreadable(totalCost, budgets) and NS.Cost.Refusal(totalCost, budgets)
        if refusal then
            Status(refusal, "bad")
            return false
        end
    end

    if auto and (select(2, NS.Bridge.GetServerBalance()) == nil or NS.Bridge.GetServerNodes() == nil) then
        autoAttemptRan = false
        return false
    end

    local clean = auto and TreeIsClean()
    local cost, err = NS.Core.ApplyBuild(targets)
    if not cost then
        if save.progressive or auto then
            local fresh = NS.Core.GetTreeSnapshot()
            local needed = fresh and NS.Core.ComputeActivationPlan(targets, fresh)
            local missing = needed and NS.Cost.Shortfall(needed, NS.Core.GetBudgets())
            if missing then
                Status(string.format(L.ROW_BLOCKED, FormatCost(missing)), "bad")
                UI.RefreshList()
                return false
            end
        end
        ActivationFailed(save, err)
        Status(tostring(err), "bad")
        UI.RefreshList()
        return false
    end

    local message
    if partial then
        message = string.format(L.MSG_APPLIED_PARTIAL, save.name, touched, FormatCost(cost), pendingNodes - touched)
    else
        message = string.format(L.MSG_APPLIED, save.name, touched, FormatCost(cost))
    end
    if not auto then
        NS.api:Notify(message)
        Status(message, "ok")
    end
    UI.RefreshList()
    if auto and clean and touched > 0 then
        placedPrint = TreeFingerprint()
        ApplyPlacedNodes(save)
    end
    return true
end

local function GetTreeWindow()
    local window = rawget(_G, "skillTreeFrame")
    local parent = window and window:GetParent()
    while parent and parent ~= UIParent do
        window, parent = parent, parent:GetParent()
    end
    return window
end
UI.GetTreeWindow = GetTreeWindow


local ApplyLayout
local panelShown = false
local refreshDriver, refreshQueued = nil, false
local affordables, seenSaves = {}, {}

local function Purge(cache, seen)
    for key in pairs(cache) do
        if not seen[key] then cache[key] = nil end
    end
end

local function MarkedSaves()
    local marked = {}
    for _, entry in ipairs(NS.api:ActiveProblems()) do
        local save = entry.facts and entry.facts.save
        if save then
            local ok, text = pcall(NS.api.ProblemText, NS.api, entry)
            marked[save] = (ok and type(text) == "string" and text ~= "") and text or entry.code or "?"
        end
    end
    return marked
end

local function RowTip(save, plan, affordable, budgets, classes)
    local lines = {}
    local totalCost, pendingNodes = plan.totalCost, plan.pendingNodes
    if not totalCost then
        lines[1] = L.TOOLTIP_READ_FAILED
    elseif pendingNodes == 0 then
        lines[1] = L.ROW_ACTIVE
    else
        if plan.ownedCost then
            lines[#lines + 1] = string.format(L.TOOLTIP_PROGRESS, plan.ownedNodes, plan.totalNodes,
                FormatCost(plan.ownedCost), FormatCost(plan.saveCost))
        end
        lines[#lines + 1] = string.format(L.TOOLTIP_COST, FormatCost(totalCost))
        local missing = budgets and NS.Cost.Shortfall(totalCost, budgets)
        if missing then
            lines[#lines + 1] = StackedCost(L.TOOLTIP_MISSING, missing)
        end
        if classes then
            lines[#lines + 1] = string.format(L.TOOLTIP_CLASS_LEVEL, classes)
        end
        if affordable then
            lines[#lines + 1] = L.TOOLTIP_LEGEND_NOW
            lines[#lines + 1] = L.TOOLTIP_LEGEND_LATER
        end
    end
    lines[#lines + 1] = save.progressive and L.TOOLTIP_MODE_PROGRESSIVE or L.TOOLTIP_MODE_STRICT
    return table.concat(lines, "\n")
end

local function Clamp(value)
    if type(value) ~= "number" or value ~= value then return 0 end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local dominantCurrency = {}

local function DominantCurrency(saveId, save)
    if save.currency then return save.currency end
    if dominantCurrency[saveId] == nil then
        local counts, best, bestCount = {}, false, 0
        if NS.Presets and NS.Presets.NodeCurrency then
            for nodeId in pairs(save.nodeRanks or NO_NODES) do
                local key = NS.Presets.NodeCurrency(nodeId)
                counts[key] = (counts[key] or 0) + 1
                if counts[key] > bestCount then best, bestCount = key, counts[key] end
            end
        end
        dominantCurrency[saveId] = best
    end
    return dominantCurrency[saveId] or nil
end

local function FillSaveItem(saveId, snapshot, budgets, marked)
    local save = GetAnySave(saveId)
    if not save then return end

    seenSaves[saveId] = true
    local progressive = save.progressive == true
    local plan = snapshot and GetSavePlan(saveId, save, snapshot)
    local totalCost, pendingNodes = plan and plan.totalCost, plan and plan.pendingNodes
    local item = {
        id = saveId, name = save.name, progressive = progressive, owned = 0, now = 0,
        marked = marked[save.name], canActivate = false,
    }
    if save.readonly then
        item.readonly, item.dot = true, save.color
        item.currency = DominantCurrency(saveId, save)
        item.currencyDot = item.currency and NS.PresetsData and NS.PresetsData.currencyColor[item.currency] or nil
    end
    local affordable
    local classes

    if not totalCost then
        item.state, item.text, item.need = "error", L.ROW_READ_FAILED, INFINITE_NEED
        item.why = L.TOOLTIP_READ_FAILED
    else
        item.nodes = { owned = plan.ownedNodes or 0, total = plan.totalNodes or 0 }
        item.owned = item.nodes.total > 0 and Clamp(item.nodes.owned / item.nodes.total) or 0
        local total = plan.totalNodes and plan.totalNodes > 0 and plan.totalNodes or nil

        if pendingNodes ~= 0 and plan.needs and not NS.Core.ClassFits(plan.needs, (NS.Core.ClassSlots())) then
            classes = NS.Core.ClassShortage(plan.needs, (NS.Core.ClassSlots()))
        end

        if pendingNodes == 0 then
            item.state, item.owned, item.need, item.text = "active", 1, 0, L.ROW_ACTIVE
            item.why = L.ROW_ACTIVE
        else
            item.remaining = Total(totalCost)
            item.text = StackedCost(L.ROW_COST, pendingNodes, totalCost)

            if progressive then
                local chosen, spent, count, blocked = GetProgressivePlan(plan, save, snapshot, budgets)
                if chosen and count > 0 then
                    affordable, item.canActivate, item.state = chosen, true, "step"
                    item.count, item.need = count, Total(spent)
                    item.now = total and Clamp(count / total) or 0
                    item.text = StackedCost(L.ROW_NEXT_STEP, count, spent)
                        .. "\n" .. StackedCost(L.ROW_PRESET_COST_LEFT, totalCost)
                else
                    affordable = chosen or NO_NODES
                    item.state, item.need = "blocked", Total(blocked or totalCost)
                    local short = blocked and NS.Cost.Shortfall(blocked, budgets or NO_NODES)
                    if short then
                        item.text = StackedCost(L.ROW_BLOCKED, short)
                    end
                    item.why = item.text
                end
            elseif not classes and NS.Cost.Fits(totalCost, budgets) and not Unreadable(totalCost, budgets) then
                item.state, item.canActivate, item.need = "ready", true, Total(totalCost)
                item.now = total and Clamp(pendingNodes / total) or 0
            else
                item.state, item.need = "short", Total(totalCost)
                local missing = not Unreadable(totalCost, budgets) and NS.Cost.Shortfall(totalCost, budgets)
                item.why = missing and StackedCost(L.TOOLTIP_MISSING, missing)
                    or classes and string.format(L.TOOLTIP_CLASS_LEVEL, classes)
                    or L.TOOLTIP_READ_FAILED
            end
        end
    end

    affordables[saveId] = affordable
    item.tip = plan and RowTip(save, plan, affordable, budgets, classes) or L.TOOLTIP_READ_FAILED
    return item
end

local function PanelPad()
    return EbonAPI.Skins.value("kit.padding") or 0
end

local function DenseChrome()
    local dense = NS.Dense and NS.Dense.Chrome
    return dense and dense.Current and dense.Current() or nil
end

local function IsTiling()
    return EbonAPI.Skins.value("widgets.saves.tiled") == true and EbonAPI.Windows ~= nil
end

local function InsideChrome()
    local chrome = DenseChrome()
    if chrome and NS.Data.IsCompact() and not IsTiling() then return chrome end
    return nil
end

local function PanelWidth()
    local default = InsideChrome() and EbonAPI.Skins.value("tree.dense.slotWidth") or EbonAPI.Skins.value("widgets.saves.width")
    return NS.Data.GetPanelWidth() or default
end

function UI.GetPanelWidth()
    return PanelWidth()
end

function UI.GetDetail()
    return NS.Data.GetDetail() or EbonAPI.Skins.value("widgets.saves.detail")
end

local function Lists()
    return { saves, presets or saves }
end

function UI.CloseOpen()
    for _, list in ipairs(Lists()) do
        if list:OpenId() then list:Select(nil) end
    end
end

function UI.HoldOpen()
    local list = ActiveList()
    if UI.Hold and list and list:OpenId() then UI.Hold() end
end

local function SizeTree()
    if not (saves and panel) then return end

    local bottom = panel:GetBottom()
    for _, list in ipairs(Lists()) do
        local top = list:GetTop()
        local margin = EbonAPI.Skins.value("widgets.saves.metric.listMargin")
        if top and bottom and top > bottom + margin then list:SetHeight(top - bottom - margin) end
    end
end

local function FitWidth()
    if not (saves and panel) then return end

    local width = PanelWidth()
    panel.spec.width = width
    for _, list in ipairs(Lists()) do
        list.spec.width = width - 2 * PanelPad()
        list:SetWidth(width - 2 * PanelPad())
    end
end

local function PresetsModel(snapshot, budgets, marked)
    local groups = {}
    local shipped = NS.Presets.Groups()
    for i = 1, #shipped do
        local group, items = shipped[i], {}
        for j = 1, #group.items do items[#items + 1] = FillSaveItem("preset:" .. group.items[j], snapshot, budgets, marked) end
        groups[#groups + 1] = { id = group.id, name = group.name, readonly = true, items = items }
    end
    return groups
end

function UI.RefreshList()
    if not saves then return end

    local snapshot = NS.Core.GetTreeSnapshot()
    local budgets = NS.Core.GetBudgets()
    local available = budgets and budgets.ash
    local marked = MarkedSaves()
    local groups = {}
    seenSaves = {}

    local function AddGroup(groupId, name, saveIds)
        local items = {}
        for i = 1, #saveIds do items[#items + 1] = FillSaveItem(saveIds[i], snapshot, budgets, marked) end
        groups[#groups + 1] = { id = groupId, name = name, items = items }
    end

    local groupIds = NS.Data.GetSortedGroupIds()
    for i = 1, #groupIds do
        local groupId = groupIds[i]
        AddGroup(groupId, NS.Data.GetGroup(groupId).name, NS.Data.GetSortedSaveIdsInGroup(groupId))
    end

    local ungrouped = NS.Data.GetSortedSaveIdsInGroup(nil)
    if #ungrouped > 0 then AddGroup("", L.UNGROUPED, ungrouped) end

    saves:SetModel({ balance = available, groups = groups })
    if presets then presets:SetModel({ balance = available, groups = PresetsModel(snapshot, budgets, marked) }) end
    Purge(affordables, seenSaves)
    Purge(savePlans, seenSaves)
    SizeTree()
    local list = ActiveList()
    if panelShown and UI.Hold and list and list:OpenId() then UI.Hold() end
end

function UI.SetDetail(detail)
    if not NS.Data.SetDetail(detail) then return end
    detail = detail or EbonAPI.Skins.value("widgets.saves.detail")
    if saves then saves:SetDetail(detail) end
    if presets then presets:SetDetail(detail) end
end

function UI.SetPanelWidth(width)
    if not NS.Data.SetPanelWidth(width) then return end
    FitWidth()
    if panel then
        panel:Refresh()
        ApplyLayout()
    end
    SizeTree()
end

local function CompactRoom(window)
    local windowTop, backgroundTop = window:GetTop(), window.Bg and window.Bg:GetTop()
    return (windowTop and backgroundTop) and (windowTop - backgroundTop) or 0
end

local TILE_ID = "stal.panel"

local function PaintPanel(tiled)
    local value = EbonAPI.Skins.value
    if tiled then
        EbonAPI.Bricks.frame(panel, EbonAPI.Replace.look("board.frame") or "large", value("board.color"), value("board.border"))
    elseif panel.stalTiled then
        EbonAPI.Bricks.frame(panel, "large", "bg", "border")
    end
    panel.stalTiled = tiled or nil
end

local function PlaceTile(tiled)
    if not tiled then
        EbonAPI.Windows.apply(TILE_ID, panel, "journal", false)
        return
    end
    local top, bottom = panel:GetTop(), panel:GetBottom()
    local height = (top and bottom and top - bottom > 0) and (top - bottom) or panel:GetHeight()
    if not (height and height > 0) then
        local window = GetTreeWindow()
        local room = (window:GetHeight() or 0) - CompactRoom(window)
        height = room > 0 and room or nil
    end
    local points = {}
    for i = 1, panel:GetNumPoints() do points[i] = { panel:GetPoint(i) } end
    EbonAPI.Windows.apply(TILE_ID, panel, "journal", true, function(self)
        local p = points[1]
        if p then self:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end)
    if height and height > 0 then panel:SetHeight(height) end
end

local function SyncNotice()
    local dressTree, problems = EbonAPI.DressTree, EbonAPI.Problems
    if not (dressTree and dressTree.setNotice) then return end

    local text = ""
    if problems then
        local summary = problems.summary("STAL")
        if summary.severe then
            text = string.format(L.NOTICE_ERRORS, summary.count)
        end
    end
    dressTree.setNotice(text)
end

ApplyLayout = function(noSync)
    if not (panel and _G.skillTreeFrame) then return end

    if not noSync then NS.Dense.Sync() end
    local tiled = IsTiling()
    local chrome = InsideChrome()
    if not tiled and EbonAPI.Windows then PlaceTile(false) end
    PaintPanel(tiled)
    local side = NS.Data.GetPanelSide()
    local window = GetTreeWindow()
    local chromeAny = DenseChrome()
    if chromeAny then
        -- the Journal slot follows the panel width, so a wide title never overflows it
        if chrome then chromeAny.slotWidth = PanelWidth() end
        chromeAny:Layout(side, chrome ~= nil)
    end
    local dressTree = EbonAPI.DressTree
    if dressTree and dressTree.setPanelSide then dressTree.setPanelSide((not tiled) and side or nil) end
    SyncNotice()

    local at
    if chrome then
        at = { frame = chrome.slot, side = side, inside = true, gap = 0, anchor = chrome.slot, ancestor = false, insets = {} }
    else
        at = { frame = window, side = side, inside = false, anchor = window, ancestor = (not tiled) and window or false, insets = {} }
    end

    local tipAnchor = chrome and EbonAPI.Skins.value("widgets.saves.denseTipAnchor") or nil
    for _, list in ipairs(Lists()) do
        list.tipAnchor = tipAnchor
    end
    FitWidth()
    panel:Attach(at)
    panel:Refresh()
    if tiled then PlaceTile(true) end
end

function UI.Dock()
    if not panel then return end
    local meant = panelShown and _G.skillTreeFrame and _G.skillTreeFrame:IsShown() and true or false
    if meant then panel.kitMeant = true end
    ApplyLayout(true)
    if meant and not panel:IsShown() then panel:Show() end
    SizeTree()
end

function UI.SetCompact(enabled)
    NS.Data.SetCompact(enabled)
    ApplyLayout()
    UI.RefreshList()
end

function UI.RefreshUpdateNotice()
    if panel then
        FitWidth()
        panel:Refresh()
    end
end

local function BuildPanel()
    if panel or not _G.skillTreeFrame then return end

    panel = NS.api:Window("panel", {
        text = "", escape = false, band = false, flushHead = true, close = false, width = PanelWidth(),
        attach = { frame = GetTreeWindow(), side = NS.Data.GetPanelSide() },
        buttons = {
            {
                key = "BTN_UPDATE",
                hidden = function() return not NS.Update.GetAvailable() end,
                tip = function() return string.format(L.TOOLTIP_UPDATE, NS.Update.GetAvailable() or "") end,
                onClick = function() NS.Menus.ShowUpdateLink() end,
            },
        },
    })
    _G.STAL_Panel = panel
    EbonAPI:On("PROBLEM", function(_, addon) if addon == "STAL" then SyncNotice() end end)
    EbonAPI:On("PROBLEM_CLOSED", function(_, addon) if addon == "STAL" then SyncNotice() end end)
    if EbonAPI.Windows and EbonAPI.Windows.onSkin then
        EbonAPI.Windows.onSkin(function() if panel and panelShown then ApplyLayout() end end)
    end
    NS.View.Attach(function()
        local list = ActiveList()
        return list and list.IsPointerNear and list:IsPointerNear() and true or false
    end)

    local width = PanelWidth() - 2 * PanelPad()
    tabs = panel:Add("tabs", { width = width, onSelect = function() SizeTree() if UI.Hold then UI.Hold() end end })

    local function ModeOf(saveId)
        local save = GetAnySave(saveId)
        if not save then return end
        if NS.Presets and NS.Presets.IsPresetId(saveId) then
            NS.Presets.SetProgressive(saveId, not save.progressive)
            UI.RefreshList()
        elseif NS.Data.SetSaveProgressive(saveId, not save.progressive) then
            UI.RefreshList()
        end
    end

    local function HoverOf(saveId)
        local save = GetAnySave(saveId)
        if not save then return end
        local nodes, affordable
        if save.preset then
            nodes = save.nodeRanks
        else
            local snapshot = NS.Core.GetTreeSnapshot()
            nodes = snapshot and NS.Plan.ComputeMissing(save.nodeRanks, snapshot) or save.nodeRanks
            affordable = affordables[saveId]
        end
        NS.View.Preview(saveId, nodes, affordable)
    end

    local function LeaveOf()
        local list = ActiveList()
        local openId = list and list:OpenId()
        if openId and GetAnySave(openId) then
            if NS.Nav.Previewing() then return end
            return HoverOf(openId)
        end
        NS.View.ClearMarks()
        NS.View.Release()
    end

    UI.Hold = LeaveOf

    local function ListSpec(grouped, extra)
        local spec = {
            width = width, empty = L.EMPTY_LIST,
            view = NS.Data.GetView(), detail = NS.Data.GetDetail(),
            sort = NS.Data.GetSort(), grouped = grouped,
            onActivate = function(saveId) return ActivateSave(saveId) end,
            onMode = ModeOf,
            onHover = HoverOf,
            onLeave = LeaveOf,
            onOpen = function(_, box) if box == ActiveList() then LeaveOf() end end,
            onView = function(view) NS.Data.SetView(view) end,
        }
        for key, handler in pairs(extra or NO_NODES) do spec[key] = handler end
        return spec
    end

    local savesPage = tabs:AddTab("saves", { text = L.TAB_SAVES })
    saves = savesPage:Add("saves", ListSpec(NS.Data.IsGrouped(), {
        onMenu = function(saveId, anchor) NS.Menus.ShowSaveMenu(saveId, anchor or panel) end,
        onGroupMenu = function(groupId, anchor) NS.Menus.ShowGroupMenu(groupId, anchor or panel) end,
        onNew = function() NS.Menus.NewSave() end,
        onSort = function(sort, grouped)
            NS.Data.SetSort(sort)
            NS.Data.SetGrouped(grouped)
        end,
    }))

    local presetsPage = tabs:AddTab("presets", { text = L.TAB_PRESETS })
    presets = presetsPage:Add("saves", ListSpec(true))
    panel:HookScript("OnSizeChanged", SizeTree)
end

local PREWARM_DELAY = 1

local prewarming, prewarmDone, prewarmDriver
local autoAddKey, autoAddPending, AutoAdd

local function FirePrewarm()
    prewarmDone = true

    local onShow = _G.skillTreeFrame:GetScript("OnShow")
    if not onShow then return end

    prewarming = true
    local ok, err = pcall(onShow, _G.skillTreeFrame)
    prewarming = false

    if not ok then NS.api:Report(NS.api:Problem("INIT.STEP_FAILED", { part = "Prewarm", detail = tostring(err) })) end
    if autoAddPending then AutoAdd() end
end

local function TickPrewarm(self, elapsed)
    if elapsed > 0.1 then elapsed = 0.1 end
    self.timer = self.timer + elapsed
    if self.timer < PREWARM_DELAY then return end

    self:Hide()

    if CollectionsJournal and CollectionsJournal:IsVisible() then
        prewarmDone = true
        return
    end

    FirePrewarm()
end

function UI.Prewarm()
    if prewarmDone or prewarming then return end
    if not _G.skillTreeFrame then return end

    if _G.skillTreeNode1 then
        prewarmDone = true
        if autoAddPending then AutoAdd() end
        return
    end

    if not prewarmDriver then
        prewarmDriver = CreateFrame("Frame")
        prewarmDriver:SetScript("OnUpdate", TickPrewarm)
    end

    prewarmDriver.timer = 0
    prewarmDriver:Show()
end


local function ShowPanel()
    if prewarming then return end

    BuildPanel()
    if not panel then return end

    panelShown = true
    NS.Core.InvalidateSnapshot()
    panel:Open()
    ApplyLayout()
    UI.RefreshList()
    UI.Hold()
    if autoAddPending then AutoAdd() end
end

local function HidePanel()
    if prewarming then return end

    NS.View.ClearMarks()
    NS.Dense.Disable("hide")
    panelShown = false
    if panel then panel:Close() end

    NS.View.Cancel()
end

local function FlushRefresh(self)
    self:Hide()
    refreshQueued = false
    NS.Core.InvalidateSnapshot()
    if panelShown then
        UI.RefreshList()
    end
end

local function QueueRefresh()
    if refreshQueued or not panelShown then return end
    refreshQueued = true
    refreshDriver:Show()
end

local function OnProblemChanged()
    if panelShown then UI.RefreshList() end
end

local function InstallWatch()
    if type(_G.refreshAccessibility) ~= "function" then return end

    refreshDriver = CreateFrame("Frame")
    refreshDriver:Hide()
    refreshDriver:SetScript("OnUpdate", FlushRefresh)
    hooksecurefunc("refreshAccessibility", QueueRefresh)
end

local function SpendableOf(entry)
    return type(entry) == "table" and tostring(entry.spendable) or "-"
end

local function SoulsKey()
    local state = EbonAPI and EbonAPI.State
    if not (state and state.GetAsh and state.GetPools) then return nil end
    local ash = state.GetAsh()
    local pools = state.GetPools()
    if type(ash) ~= "table" then ash = {} end
    if type(pools) ~= "table" then pools = {} end
    return table.concat({
        tostring(ash.spendable), tostring(ash.committed),
        SpendableOf(pools.shard), SpendableOf(pools.essence), SpendableOf(pools.artisan),
    }, "|")
end

local function ClassSlotsKey()
    local core = NS.Core
    local db = EbonAPI.Ebonhold.TalentDatabase()
    local hubs = type(db) == "table" and type(db[0]) == "table" and db[0].classHubs
    if not (core and core.ClassSlots and type(hubs) == "table") then return "-" end
    local token = select(2, UnitClass("player"))
    local slots = core.ClassSlots()
    for classId, hub in pairs(hubs) do
        if type(hub) == "table" and hub.token == token then return tostring(slots[classId]) end
    end
    return "-"
end

function AutoAdd()
    if not NS.Data.IsAutoAdd() then autoAddKey, autoAddPending, placedPrint, applySentAt = nil, nil, nil, nil return end
    if not _G.skillTreeFrame then return end
    if InCombatLockdown() or prewarming then autoAddPending = true return end

    if placedPrint then
        if TreeIsClean() then
            placedPrint, applySentAt = nil, nil
        elseif ApplyInFlight() then
            autoAddPending = true
            return
        elseif TreeFingerprint() ~= placedPrint then
            placedPrint, applySentAt = nil, nil
        else
            local token = select(2, UnitClass("player"))
            local save = NS.Presets and NS.Presets.GetSave("preset:classe_" .. token)
            local tree = EbonAPI.Ebonhold.SkillTree()
            if not ApplyButtonEnabled() and type(tree) == "table" and type(tree.MarkUnsavedChanges) == "function" then
                pcall(tree.MarkUnsavedChanges)
            end
            if save then ApplyPlacedNodes(save) end
            autoAddPending = true
            return
        end
    end

    local key = SoulsKey()
    if key then key = key .. "|" .. ClassSlotsKey() .. "|" .. tostring(NS.Core.SpecTab and NS.Core.SpecTab() or "-") end
    if key and key == autoAddKey then autoAddPending = nil return end

    local token = select(2, UnitClass("player"))
    local id = "preset:classe_" .. token
    if not (NS.Presets and NS.Presets.IsPresetId(id) and NS.Presets.GetSave(id)) then
        autoAddPending = nil
        return
    end

    ActivateSave(id, true)
    if autoAttemptRan then
        autoAddKey, autoAddPending = key, placedPrint and true or nil
    else
        autoAddPending = true
    end
end

function UI.RetryAutoAdd()
    if autoAddPending then AutoAdd() end
end

function UI.OnApplyResult(success)
    applySentAt = nil
    NS.api:CancelAfter("apply-retry")
    if success then
        if placedPrint then autoAddPending = true end
    else
        placedPrint, autoAddPending = nil, nil
    end
end

local function OnClassProgress(value)
    local tree = EbonAPI.Ebonhold.Service("ClassTree")
    if type(value) == "table" and value.ashes and type(tree) == "table" and type(tree.ashes) == "table"
        and tree.ashes[value.classId] ~= value.ashes then
        autoAddPending = true
        return
    end
    AutoAdd()
end

function UI.RegisterOptions()
    NS.api:Options({
        type = "group",
        name = "SkillTreeAutoLoad",
        args = {
            newGroup = {
                type = "execute", order = 1,
                name = function() return L.MENU_NEW_GROUP end,
                func = function() NS.Menus.NewGroup() end,
            },
            compact = {
                type = "toggle", order = 2,
                name = function() return L.MENU_COMPACT end,
                get = function() return NS.Data.IsCompact() end,
                set = function(_, value) NS.UI.SetCompact(value) end,
            },
            previewCamera = {
                type = "toggle", order = 3,
                name = function() return L.MENU_PREVIEW_CAMERA end,
                get = function() return NS.Data.IsPreviewCamera() end,
                set = function(_, value) NS.Data.SetPreviewCamera(value) end,
            },
            detailDock = {
                type = "toggle", order = 4,
                name = function() return L.MENU_DETAIL_DOCK end,
                get = function() return UI.GetDetail() == "dock" end,
                set = function(_, value) UI.SetDetail(value and "dock" or "inline") end,
            },
            panelWidth = {
                type = "range", order = 5, min = 200, max = 280, step = 40,
                name = function() return L.MENU_PANEL_WIDTH end,
                get = function() return UI.GetPanelWidth() end,
                set = function(_, value) UI.SetPanelWidth(value) end,
            },
            side = {
                type = "select", order = 6,
                name = function() return L.OPT_SIDE end,
                values = function() return { LEFT = L.OPT_SIDE_LEFT, RIGHT = L.OPT_SIDE_RIGHT } end,
                get = function() return NS.Data.GetPanelSide() end,
                set = function(_, value)
                    NS.Data.SetPanelSide(value)
                    if panel then ApplyLayout() end
                end,
            },
            autoAdd = {
                type = "toggle", order = 7,
                name = function() return L.OPT_AUTO_ADD end,
                desc = function() return L.OPT_AUTO_ADD_DESC end,
                get = function() return NS.Data.IsAutoAdd() end,
                set = function(_, value)
                    NS.Data.SetAutoAdd(value)
                    AutoAdd()
                end,
            },
            import = {
                type = "execute", order = 8,
                name = function() return L.MENU_IMPORT end,
                func = function() NS.Share.ShowImport() end,
            },
        },
    })
end

function UI.Init()
    UI.RegisterOptions()
    if not _G.skillTreeFrame then return end

    InstallWatch()
    NS.api:On("PROBLEM", OnProblemChanged)
    NS.api:On("PROBLEM_CLOSED", OnProblemChanged)
    NS.api:On("SERVER_ASH", AutoAdd)
    NS.api:On("SERVER_POOLS", AutoAdd)
    NS.api:On("SERVER_LOADOUT", UI.RetryAutoAdd)
    NS.api:SubscribeServer(1232, OnClassProgress)
    NS.api:SubscribeServer(1233, OnClassProgress)
    _G.skillTreeFrame:HookScript("OnShow", ShowPanel)
    _G.skillTreeFrame:HookScript("OnHide", HidePanel)
    NS.View.Init()

    if _G.skillTreeFrame:IsVisible() then ShowPanel() end
end
