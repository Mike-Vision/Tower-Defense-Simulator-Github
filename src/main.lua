-- main.lua
return function(loadModule)
    local inventory = loadModule("inventory")
    
    local TDS = {}
    
    -- Method execution
    function TDS:Loadout(towersList)
        if type(towersList) ~= "table" then
            warn("[TDS] Invalid argument to Loadout. Expected table, got " .. type(towersList))
            return false
        end
        return inventory.equipLoadout(towersList)
    end
    
    -- Alias for lowercase method call
    function TDS:loadout(towersList)
        return self:Loadout(towersList)
    end
    
    -- Metatable to support direct property assignment, e.g. TDS.loadout = {"Scout", "Sniper"}
    setmetatable(TDS, {
        __newindex = function(tbl, key, value)
            if (key == "loadout" or key == "Loadout") and type(value) == "table" then
                inventory.equipLoadout(value)
            else
                rawset(tbl, key, value)
            end
        end
    })
    
    print("[TDS] Loadout Library loaded successfully!")
    return TDS
end
