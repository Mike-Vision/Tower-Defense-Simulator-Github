-- main.lua
-- Entry point for TDS Loadout Library hosted on Mike-Vision/Tower-Defense-Simulator-Github

local function loadModule(name)
    local url = string.format("https://raw.githubusercontent.com/Mike-Vision/Tower-Defense-Simulator-Github/main/src/%s.lua", name)
    local success, content = pcall(game.HttpGet, game, url)
    if not success or not content then
        error("[TDS] Failed to fetch module online: " .. name .. " from " .. url)
    end
    
    local fn, err = loadstring(content)
    if not fn then
        error("[TDS] Failed to parse module " .. name .. ": " .. tostring(err))
    end
    
    return fn()
end

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

-- Metatable to support direct property assignment
setmetatable(TDS, {
    __newindex = function(tbl, key, value)
        if (key == "loadout" or key == "Loadout") and type(value) == "table" then
            task.spawn(function()
                inventory.equipLoadout(value)
            end)
        else
            rawset(tbl, key, value)
        end
    end
})

print("[TDS] Loadout Library loaded successfully from GitHub!")
return TDS
