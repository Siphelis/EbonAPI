EbonBuilds.MinimapButton = {}

function EbonBuilds.MinimapButton.ToggleEchos()
    if type(SetCollectionsJournalShown) ~= "function" then
        return
    end
    if CollectionsJournal and CollectionsJournal:IsShown() and PanelTemplates_GetSelectedTab(CollectionsJournal) == 1 then
        HideUIPanel(CollectionsJournal)
    else
        SetCollectionsJournalShown(true, 1)
    end
end

function EbonBuilds.MinimapButton.Init()
    EbonBuilds.api:MinimapButton({
        angle  = EbonAPIEbonBuildsDB.minimapAngle,
        text   = EbonBuilds.NAME,
        tipKey = "MINIMAP_TIP",
        onClick = function(_, mouseButton)
            if mouseButton == "LeftButton" then
                EbonBuilds.MinimapButton.ToggleEchos()
            end
        end,
    })
end
