-- src/systems/camera3d.lua
-- Projection camera for the 3D z-up character system.
-- Supports three views that can be cycled at runtime.
-- World axes: x=left/right, y=depth (into screen), z=height (up)
--
-- This is separate from src/systems/camera.lua (the 2D pan/zoom camera).
-- Use this one whenever you are rendering characters with the draw modules.
--
-- USAGE:
--   local Camera3D = require "src.characters.camera3d"
--   local cam = Camera3D.new(worldW, worldH)
--
--   -- each frame:
--   cam:follow(player.pos.x, player.pos.y, player.pos.z, dt)
--   -- draw calls:
--   cam:toScreen(worldX, worldY, worldZ)  → screenX, screenY
--   cam.view  → "sidescroll" | "threequarter" | "isometric"
--
--   -- cycle views (e.g. on V key):
--   cam:nextView()
--   cam:snapTo(player.pos.x, player.pos.y, player.pos.z)
--
-- VIEWS:
--   sidescroll    classic 2D side view   (y axis ignored)
--   threequarter  slight top-down angle  (y contributes 50% to screen Y)
--   isometric     true iso projection    (x and y symmetrical)

local Camera3D = {}
Camera3D.__index = Camera3D

local VIEWS = { "sidescroll", "threequarter", "isometric" }

-- worldW  : total width of the world in pixels
-- worldH  : unused by projection but stored for reference / boundary clamping
function Camera3D.new(worldW, worldH)
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    return setmetatable({
        x = 0, y = 0,    -- current camera offset (screen pixels)
        tx = 0, ty = 0,  -- target camera offset (smoothed toward each frame)
        worldW     = worldW,
        worldH     = worldH,
        sw         = sw,
        sh         = sh,
        viewIndex  = 1,
        view       = "sidescroll",
    }, Camera3D)
end

-- Cycle to the next view. Call snapTo() immediately after to avoid a pop.
function Camera3D:nextView()
    self.viewIndex = self.viewIndex % #VIEWS + 1
    self.view      = VIEWS[self.viewIndex]
end

-- Project a world position to 2D plane coordinates (no camera offset).
-- z = 0 is ground level; positive z = up.
function Camera3D:project(wx, wy, wz)
    if self.view == "sidescroll" then
        return wx, -wz
    elseif self.view == "threequarter" then
        return wx, wy * 0.5 - wz
    else  -- isometric
        return (wx - wy) * 0.866,
               (wx + wy) * 0.5 - wz
    end
end

-- Convert a world position directly to screen pixel coordinates.
-- This is what all draw modules call.
function Camera3D:toScreen(wx, wy, wz)
    local px, py = self:project(wx, wy, wz)
    return px - self.x, py - self.y
end

-- Smoothly follow a world position. Call once per frame in love.update().
-- The entity is held at ~64% from the top so floor is visible below.
function Camera3D:follow(wx, wy, wz, dt)
    local px, py = self:project(wx, wy, wz)
    self.tx = px - self.sw * 0.5
    self.ty = py - self.sh * 0.64
    self.x  = self.x + (self.tx - self.x) * math.min(1, dt * 6)
    self.y  = self.y + (self.ty - self.y) * math.min(1, dt * 3)
end

-- Snap camera instantly to a world position (no smoothing).
-- Use on spawn or immediately after nextView() to prevent a visual pop.
function Camera3D:snapTo(wx, wy, wz)
    local px, py = self:project(wx, wy, wz)
    self.x  = px - self.sw * 0.5
    self.y  = py - self.sh * 0.64
    self.tx = self.x
    self.ty = self.y
end

-- Convert a screen position back to world coordinates (sidescroll only).
-- Useful for mouse picking. Returns x, y=0, z.
function Camera3D:toWorld(sx, sy)
    return sx + self.x, 0, -(sy + self.y)
end

return Camera3D
