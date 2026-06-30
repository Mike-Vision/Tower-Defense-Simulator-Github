-- main.lua
-- Entry point for TDS Loadout Library hosted on Mike-Vision/Tower-Defense-Simulator-Github

local sha = ... or "main"

local function loadModule(name)
    local url = string.format("https://raw.githubusercontent.com/Mike-Vision/Tower-Defense-Simulator-Github/%s/src/%s.lua", sha, name)
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

-- Private place function
local function place(self, towerName, x, y, z)
    local targetTower, targetX, targetY, targetZ
    if type(self) == "table" then
        targetTower = towerName
        targetX = x
        targetY = y
        targetZ = z
    else
        targetTower = self
        targetX = towerName
        targetY = x
        targetZ = y
    end
    
    if type(targetTower) ~= "string" or type(targetX) ~= "number" or type(targetY) ~= "number" or type(targetZ) ~= "number" then
        warn("[TDS] Invalid arguments to Place. Expected (towerName, x, y, z)")
        return false, "Invalid arguments"
    end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local rf = ReplicatedStorage:FindFirstChild("RemoteFunction")
    if not rf then
        warn("[TDS] RemoteFunction not found in ReplicatedStorage")
        return false, "RemoteFunction not found"
    end
    
    local posStr = string.format("%f, %f, %f", targetX, targetY, targetZ)
    local rotStr = "0, 0, 0, 1, -0, 0, 0, 1, -0, 0, 0, 1"
    
    local success, result = pcall(function()
        return rf:InvokeServer("Troops", "Place", { Rotation = rotStr, Position = posStr }, targetTower)
    end)
    return success, result
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
        elseif key == "place" or key == "Place" then
            return place
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
