-- src/systems/serializer.lua
-- Pure Lua table serializer/deserializer — no LÖVE dependencies
-- Supports: numbers, booleans, strings, nested tables, arrays

local Serializer = {}

-- Serialize any Lua value to a string
function Serializer.serialize(val, indent)
    indent = indent or 0
    local t = type(val)
    if t == "number"  then return tostring(val) end
    if t == "boolean" then return tostring(val) end
    if t == "string"  then return string.format("%q", val) end
    if t == "nil"     then return "nil" end
    if t == "table" then
        local lines   = {}
        local pad     = string.rep("  ", indent + 1)
        local isArray = (#val > 0)
        for k, v in pairs(val) do
            local serialV = Serializer.serialize(v, indent + 1)
            if isArray then
                table.insert(lines, pad .. serialV)
            else
                local key = type(k) == "string"
                    and string.format("[%q]", k)
                    or  "["..tostring(k).."]"
                table.insert(lines, pad .. key .. " = " .. serialV)
            end
        end
        local inner = table.concat(lines, ",\n")
        return "{\n" .. inner .. "\n" .. string.rep("  ", indent) .. "}"
    end
    return "nil"
end

-- Deserialize a string back to a Lua value
-- Uses load() — only safe for trusted (self-generated) data
function Serializer.deserialize(str)
    if not str or str == "" then return nil, "empty string" end
    local fn, err = load("return " .. str)
    if not fn then return nil, err end
    local ok, val = pcall(fn)
    if not ok then return nil, val end
    return val
end

-- Convenience: write to love.filesystem
function Serializer.write(path, val)
    local str = Serializer.serialize(val)
    return love.filesystem.write(path, str)
end

-- Convenience: read from love.filesystem
function Serializer.read(path)
    local info = love.filesystem.getInfo(path)
    if not info then return nil, "file not found" end
    local str, err = love.filesystem.read(path)
    if not str then return nil, err end
    return Serializer.deserialize(str)
end

return Serializer
