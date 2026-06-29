-- config.lua
local ConfigModule = {}

-- Parses .env-tower which looks like: .env-tower = {"Name 1", "Name 2", ...}
function ConfigModule.parseEnv(content)
    local towers = {}
    for name in content:gmatch('["\'](.-)["\']') do
        table.insert(towers, name)
    end
    return towers
end

-- Loads config file using readfile API
function ConfigModule.loadConfig()
    local success, content = pcall(readfile, ".env-tower")
    if not success or not content then
        return nil, "Could not read .env-tower"
    end
    
    local towers = ConfigModule.parseEnv(content)
    if #towers == 0 then
        return nil, "No towers found in config"
    end
    
    return towers
end

return ConfigModule
