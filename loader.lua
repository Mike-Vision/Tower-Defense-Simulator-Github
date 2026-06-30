-- Host repository: Mike-vision/Tower-Defense-Simulator-Github

local HttpService = game:GetService("HttpService")

local sha = "main"
local successSha, commitInfo = pcall(function()
    return game:HttpGet("https://api.github.com/repos/Mike-vision/Tower-Defense-Simulator-Github/commits/main")
end)

if successSha and commitInfo then
    local ok, data = pcall(HttpService.JSONDecode, HttpService, commitInfo)
    if ok and data and data.sha then
        sha = data.sha
    end
end

local success, result = pcall(function()
    local url = string.format("https://raw.githubusercontent.com/Mike-vision/Tower-Defense-Simulator-Github/%s/src/main.lua", sha)
    local content = game:HttpGet(url)
    return loadstring(content)(sha)
end)

if success and result then
    getgenv().TDS = result
    print("[TDS] Loader: Library loaded successfully into getgenv().TDS!")
    
    -- Check if Gatling Gun GUI env variable is active
    if getgenv()[".env-gatling"] == true or getgenv().env_gatling == true then
        task.spawn(function()
            local gatlingUrl = string.format("https://raw.githubusercontent.com/Mike-vision/Tower-Defense-Simulator-Github/%s/gatling-gun/gui.lua", sha)
            local okGatling, contentGatling = pcall(game.HttpGet, game, gatlingUrl)
            if okGatling and contentGatling then
                loadstring(contentGatling)()
                print("[TDS] Loader: Gatling Gun GUI loaded successfully!")
            else
                warn("[TDS] Loader: Failed to download Gatling Gun GUI: " .. tostring(contentGatling))
            end
        end)
    end
    
    return result
else
    warn("[TDS] Loader: Failed to load library from GitHub: " .. tostring(result))
end
