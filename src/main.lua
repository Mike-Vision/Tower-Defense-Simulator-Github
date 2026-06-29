-- main.lua
-- Entry point for TDS Loadout Library hosted on Mike-Vision/Tower-Defense-Simulator-Github

local function loadModule(name)
    local url = string.format("https://raw.githubusercontent.com/Mike-Vision/Tower-Defense-Simulator-Github/main/src/%s.lua?t=%s", name, tostring(os.time()))
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

-- Private equip function
local function equip(towersList)
    if type(towersList) ~= "table" then
        warn("[TDS] Invalid argument to Loadout. Expected table, got " .. type(towersList))
        return false
    end
    return inventory.equipLoadout(towersList)
end

-- Metatable to support direct property assignment and method calls dynamically
setmetatable(TDS, {
    __index = function(tbl, key)
        if key == "loadout" or key == "Loadout" then
            return function(self, towersList)
                -- Handle both TDS:loadout({...}) and TDS.loadout({...})
                if type(self) == "table" and self ~= tbl then
                    return equip(self)
                end
                return equip(towersList)
            end
        end
        return nil
    end,
    __newindex = function(tbl, key, value)
        if (key == "loadout" or key == "Loadout") and type(value) == "table" then
            task.spawn(function()
                equip(value)
            end)
        else
            rawset(tbl, key, value)
        end
    end
})

print("[TDS] Loadout Library loaded successfully from GitHub!")
return TDS
