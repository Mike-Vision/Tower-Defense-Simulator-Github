-- main.lua
-- Entry point for TDS Loadout Library hosted on Mike-vision/Tower-Defense-Simulator-Github

local sha = ... or "main"

local function loadModule(name)
    local url = string.format("https://raw.githubusercontent.com/Mike-vision/Tower-Defense-Simulator-Github/%s/src/%s.lua", sha, name)
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
local TDS = {
    PlacedTowers = {}
}

-- Private equip function
local function equip(towersList)
    if type(towersList) ~= "table" then
        warn("[TDS] Invalid argument to Loadout. Expected table, got " .. type(towersList))
        return false
    end
    return inventory.equipLoadout(towersList)
end

-- Helper to find the newest tower in workspace.Towers that matches the placed type and position
local function findNewestTower(towerTypeName, position, maxDistance)
    local bestTower = nil
    local bestDist = maxDistance or 1.0
    for _, tower in ipairs(workspace.Towers:GetChildren()) do
        -- Check if it matches the expected internal representation of the tower type
        if tower.PrimaryPart then
            local dist = (tower.PrimaryPart.Position - position).Magnitude
            if dist < bestDist then
                -- Verify this tower is not already registered in our indexes
                local alreadyRegistered = false
                for _, registeredTower in pairs(TDS.PlacedTowers) do
                    if registeredTower == tower then
                        alreadyRegistered = true
                        break
                    end
                end
                if not alreadyRegistered then
                    bestTower = tower
                    bestDist = dist
                end
            end
        end
    end
    return bestTower
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
    
    -- Check if there is already a tower close to this position to decide if we need to stack
    local needStack = false
    for _, tower in ipairs(workspace.Towers:GetChildren()) do
        if tower.PrimaryPart then
            local dist = (tower.PrimaryPart.Position - Vector3.new(targetX, tower.PrimaryPart.Position.Y, targetZ)).Magnitude
            if dist < 2.5 then
                needStack = true
                break
            end
        end
    end
    
    local finalX = targetX
    local finalY = targetY
    local finalZ = targetZ
    
    if needStack then
        -- Apply the golden stacking bypass parameters:
        -- Y is offset by +1.05 studs to skip the server's HEIGHT checks.
        -- X is shifted by +0.1 stud to slide the server's down-raycast around the existing hitbox.
        finalX = targetX + 0.1
        finalY = targetY + 1.05
    end
    
    local posVal = Vector3.new(finalX, finalY, finalZ)
    local rotVal = CFrame.new(0, 0, 0, 1, -0, 0, 0, 1, -0, 0, 0, 1)
    
    local result = rf:InvokeServer("Troops", "Place", { Rotation = rotVal, Position = posVal }, targetTower)
    
    if type(result) == "string" and result ~= "You cannot place here!" and result ~= "You do not have this tower equipped!" then
        -- Wait a short time for the model to replicate to workspace.Towers
        local placedTowerInstance = nil
        for i = 1, 10 do
            placedTowerInstance = findNewestTower(result, posVal, 2.0)
            if placedTowerInstance then break end
            task.wait(0.05)
        end
        
        -- Register to the next index
        local newIndex = #TDS.PlacedTowers + 1
        TDS.PlacedTowers[newIndex] = placedTowerInstance
        print(string.format("[TDS] Placed %s successfully. Registered to Index: %d", tostring(targetTower), newIndex))
    end
    
    return true, result
end

-- Private upgrade function with auto wait loop for cash
local function upgrade(self, index, path)
    local targetIndex, targetPath
    if type(self) == "table" then
        targetIndex = index
        targetPath = path or 1
    else
        targetIndex = self
        targetPath = index or 1
    end
    
    if type(targetIndex) ~= "number" then
        warn("[TDS] Invalid arguments to Upgrade. Expected (index, path)")
        return false, "Invalid arguments"
    end
    
    local towerInstance = TDS.PlacedTowers[targetIndex]
    if not towerInstance then
        warn(string.format("[TDS] Tower at Index %d not found or not placed yet!", targetIndex))
        return false, "Tower not found"
    end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local rf = ReplicatedStorage:FindFirstChild("RemoteFunction")
    if not rf then
        warn("[TDS] RemoteFunction not found in ReplicatedStorage")
        return false, "RemoteFunction not found"
    end
    
    print(string.format("[TDS] Attempting to upgrade Tower Index %d along Path %d...", targetIndex, targetPath))
    
    while true do
        -- Check if tower still exists in workspace
        if not towerInstance.Parent then
            warn(string.format("[TDS] Tower at Index %d was sold or destroyed. Exiting upgrade loop.", targetIndex))
            return false, "Tower destroyed"
        end
        
        local result = rf:InvokeServer("Troops", "Upgrade", "Set", { Troop = towerInstance, Path = targetPath })
        
        if result == true or result == "Max level reached" then
            print(string.format("[TDS] Successfully upgraded Tower Index %d to next level!", targetIndex))
            return true, result
        elseif type(result) == "string" and string.find(result:lower(), "enough money") then
            -- Not enough money, wait 0.5s and retry
            task.wait(0.5)
        else
            -- Other error (e.g. max level or target invalid), log and exit loop to prevent infinite hang
            warn(string.format("[TDS] Upgrade failed: %s. Exiting loop.", tostring(result)))
            return false, result
        end
    end
end

-- Metatable to support direct property assignment and method calls dynamically
setmetatable(TDS, {
    __index = function(tbl, key)
        if key == "loadout" or key == "Loadout" then
            return function(self, towersList)
                if type(self) == "table" and self ~= tbl then
                    return equip(self)
                end
                return equip(towersList)
            end
        elseif key == "place" or key == "Place" then
            return place
        elseif key == "upgrade" or key == "Upgrade" or key == "upg" or key == "Upg" then
            return upgrade
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
