-- Minimal OOP base class
-- Usage:
--   local MyClass = Class:extend()
--   function MyClass:new(x, y) self.x = x self.y = y end
--   function MyClass:update(dt) end
--   local obj = MyClass(10, 20)

local Class = {}
Class.__index = Class

function Class:extend()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, { __index = self, __call = function(c, ...)
        local instance = setmetatable({}, c)
        if instance.new then instance:new(...) end
        return instance
    end})
    return cls
end

return Class
