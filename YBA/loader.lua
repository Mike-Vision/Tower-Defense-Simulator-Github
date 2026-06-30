-- loader.lua
-- Loader script for YBA Automation (Orion Hub)

local HttpService = game:GetService("HttpService")

-- Prevent duplicate script execution
if getgenv().YBALoaded then
    print("[YBA] Already loaded.")
    return
end
getgenv().YBALoaded = true

local sha = "main"
-- Attempts to get the latest commit SHA from GitHub for auto-updates (fallback to main)
local successSha, commitInfo = pcall(function()
    return game:HttpGet("https://api.github.com/repos/Mike-vision/Tower-Defense-Simulator-Github/commits/main")
end)

if successSha and commitInfo then
    local ok, data = pcall(HttpService.JSONDecode, HttpService, commitInfo)
    if ok and data and data.sha then
        sha = data.sha
    end
end

-- Load the main automation module
local loadFunc = loadstring or typeof(loadstring) == "function" and loadstring
if not loadFunc then
    getgenv().YBALoaded = nil
    error("[YBA] Loader: Executor does not support loadstring function!")
end

local success, result = pcall(function()
    local url = string.format("https://raw.githubusercontent.com/Mike-vision/Tower-Defense-Simulator-Github/%s/YBA/main.luau?t=%s", sha, tostring(tick()))
    local content = game:HttpGet(url)
    
    local f, err = loadFunc(content)
    if not f then
        error("Syntax error in main.luau: " .. tostring(err))
    end
    
    return f()
end)

if success then
    print("[YBA] Automation script loaded successfully!")
else
    getgenv().YBALoaded = nil
    warn("[YBA] Loader: Failed to load main script from GitHub: " .. tostring(result))
end
