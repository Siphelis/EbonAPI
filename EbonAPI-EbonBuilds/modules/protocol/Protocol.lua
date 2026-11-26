EbonBuilds.Protocol = {}

local GRANTED = 18

local NONE = {}

local ownedSource = nil
local ownedEchoes = nil

function EbonBuilds.Protocol.GetOwnedEchoes()
    local state = EbonBuilds.api:ServerState(GRANTED)
    if not state then
        if EbonAPI.Ebonhold.HasNoGrantedPerk() == true then return NONE end
        return nil
    end
    if state ~= ownedSource then
        local owned = {}
        for i = 1, #state.perks do
            local p = state.perks[i]
            owned[p.spellId] = {
                stacks   = p.stack,
                maxStack = p.maxStack,
                quality  = p.quality,
                locked   = p.locked,
            }
        end
        ownedSource, ownedEchoes = state, owned
    end
    return ownedEchoes
end

local function OnGranted(state)
    local maxPermanent = state and state.maxSlots
    if maxPermanent and maxPermanent > 0 and EbonBuilds.Build then
        EbonBuilds.Build.LOCKED_SLOTS = maxPermanent
    end
end

function EbonBuilds.Protocol.Init()
    EbonBuilds.api:SubscribeServer(GRANTED, OnGranted)
    OnGranted(EbonBuilds.api:ServerState(GRANTED))
end
