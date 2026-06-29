-- inventory.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Modules.Network)
local Cache = require(ReplicatedStorage.Client.Modules.Cache)
local PlayerReplicator = require(ReplicatedStorage.Client.Modules.Replicators.PlayerReplicator)

local InventoryModule = {}

local invChannel = Network.Channel("Inventory")

-- Gets owned towers lookup table (yields if not loaded yet)
function InventoryModule.getOwnedTowers()
    local cache = Cache("Inventory.Troops")
    local owned = cache:GetValue()
    if not owned then
        pcall(function()
            owned = cache:Get():await()
        end)
    end
    return owned or {}
end

-- Gets currently equipped towers (returns pvp and normal tables)
function InventoryModule.getEquippedTowers()
    local localData = PlayerReplicator.GetLocalPlayerRaw() or PlayerReplicator.GetLocalPlayer()
    local pvpTowers = {}
    local normalTowers = {}
    
    if localData then
        for _, t in ipairs(localData.EquippedPVPTowers or {}) do
            table.insert(pvpTowers, t)
        end
        for _, t in ipairs(localData.EquippedTowers or {}) do
            table.insert(normalTowers, t)
        end
    end
    
    return pvpTowers, normalTowers
end

-- Swaps the loadout dynamically to match targetTowers
function InventoryModule.equipLoadout(targetTowers)
    local owned = InventoryModule.getOwnedTowers()
    local pvpCurrent, normalCurrent = InventoryModule.getEquippedTowers()
    
    -- Filter target towers by ownership. If not owned, skip it as requested.
    local verifiedTargets = {}
    for _, tower in ipairs(targetTowers) do
        if owned[tower] then
            table.insert(verifiedTargets, tower)
        else
            warn("[TDS] Player does not own tower: " .. tostring(tower))
        end
    end
    
    -- Helper to calculate swaps (what to unequip, what to equip)
    local function getDiff(current, target)
        local toUnequip = {}
        local toEquip = {}
        
        local currentLookup = {}
        for _, t in ipairs(current) do
            currentLookup[t] = true
        end
        
        local targetLookup = {}
        for _, t in ipairs(target) do
            targetLookup[t] = true
            if not currentLookup[t] then
                table.insert(toEquip, t)
            end
        end
        
        for _, t in ipairs(current) do
            if not targetLookup[t] then
                table.insert(toUnequip, t)
            end
        end
        
        return toUnequip, toEquip
    end
    
    -- 1. Swap PVP Loadout
    local pvpUnequip, pvpEquip = getDiff(pvpCurrent, verifiedTargets)
    for _, tower in ipairs(pvpUnequip) do
        pcall(function()
            invChannel:InvokeServer("Unequip", "pvptower", tower)
        end)
        task.wait(0.05)
    end
    for _, tower in ipairs(pvpEquip) do
        pcall(function()
            invChannel:InvokeServer("Equip", "pvptower", tower)
        end)
        task.wait(0.05)
    end
    
    -- 2. Swap Normal Loadout
    local normalUnequip, normalEquip = getDiff(normalCurrent, verifiedTargets)
    for _, tower in ipairs(normalUnequip) do
        pcall(function()
            invChannel:InvokeServer("Unequip", "tower", tower)
        end)
        task.wait(0.05)
    end
    for _, tower in ipairs(normalEquip) do
        pcall(function()
            invChannel:InvokeServer("Equip", "tower", tower)
        end)
        task.wait(0.05)
    end
    
    return true
end

return InventoryModule
