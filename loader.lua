-- Host repository: Mike-Vision/Tower-Defense-Simulator-Github

local success, result = pcall(function()
    local url = "https://raw.githubusercontent.com/Mike-Vision/Tower-Defense-Simulator-Github/main/src/main.lua?t=" .. tostring(tick())
    return loadstring(game:HttpGet(url))()
end)

if success and result then
    getgenv().TDS = result
    print("[TDS] Loader: Library loaded successfully into getgenv().TDS!")
    
    -- Example of usage:
    -- getgenv().TDS.loadout = {"Shotgunner", "DJ Booth", "Warden"}
    return result
else
    warn("[TDS] Loader: Failed to load library from GitHub: " .. tostring(result))
end

