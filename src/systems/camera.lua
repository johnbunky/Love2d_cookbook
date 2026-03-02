-- src/camera.lua
-- Reusable camera: smooth follow, world bounds, zoom.
--
-- Usage:
--   local Camera = require("src.systems.camera")
--   local cam = Camera.new(worldW, worldH, screenW, screenH)
--   Camera.follow(cam, player, dt)
--   Camera.apply(cam)
--     -- draw world here --
--   Camera.clear()
--   Camera.setZoom(cam, cam.zoom + 0.1)

local Utils  = require("src.utils")
local Camera = {}

-- -------------------------
-- Create a new camera
-- -------------------------
function Camera.new(worldW, worldH, screenW, screenH, speed)
    local minZoom = math.max(screenW / worldW, screenH / worldH)
    return {
        x       = 0,
        y       = 0,
        zoom    = 1,
        speed   = speed or 5,
        worldW  = worldW,
        worldH  = worldH,
        screenW = screenW,
        screenH = screenH,
        minZoom = minZoom,
    }
end

-- -------------------------
-- Smoothly follow a target rect { x, y, w, h }
-- -------------------------
function Camera.follow(cam, target, dt)
    local viewW   = cam.screenW / cam.zoom
    local viewH   = cam.screenH / cam.zoom
    local targetX = (target.x + target.w / 2) - viewW / 2
    local targetY = (target.y + target.h / 2) - viewH / 2
    cam.x = Utils.clamp(
        Utils.lerp(cam.x, targetX, cam.speed * dt),
        0, math.max(0, cam.worldW - viewW))
    cam.y = Utils.clamp(
        Utils.lerp(cam.y, targetY, cam.speed * dt),
        0, math.max(0, cam.worldH - viewH))
end

-- -------------------------
-- Apply camera transform — call before drawing world
-- -------------------------
function Camera.apply(cam)
    love.graphics.push()
    love.graphics.scale(cam.zoom, cam.zoom)
    love.graphics.translate(-cam.x, -cam.y)
end

-- -------------------------
-- Clear camera transform — call after drawing world
-- -------------------------
function Camera.clear()
    love.graphics.pop()
end

-- -------------------------
-- Snap camera instantly to center on target (no lerp)
-- Call this when zoom changes to avoid jerk
-- -------------------------
function Camera.snapTo(cam, target)
    local viewW = cam.screenW / cam.zoom
    local viewH = cam.screenH / cam.zoom
    cam.x = Utils.clamp(
        (target.x + target.w / 2) - viewW / 2,
        0, math.max(0, cam.worldW - viewW))
    cam.y = Utils.clamp(
        (target.y + target.h / 2) - viewH / 2,
        0, math.max(0, cam.worldH - viewH))
end

-- -------------------------
-- Set zoom, clamped to safe range
-- Optionally snap to a target so it stays centered
-- -------------------------
function Camera.setZoom(cam, z, snapTarget)
    cam.zoom = Utils.clamp(z, cam.minZoom, 2.0)
    if snapTarget then
        Camera.snapTo(cam, snapTarget)
    end
end

-- -------------------------
-- Convert screen coords to world coords
-- -------------------------
function Camera.screenToWorld(cam, sx, sy)
    return sx / cam.zoom + cam.x,
           sy / cam.zoom + cam.y
end

-- -------------------------
-- Get visible tile range for efficient rendering
-- Returns c1, r1, c2, r2 in tile coords
-- -------------------------
function Camera.visibleTiles(cam, tileSize)
    return math.max(1,   math.floor(cam.x / tileSize)),
           math.max(1,   math.floor(cam.y / tileSize)),
           math.ceil((cam.x + cam.screenW / cam.zoom) / tileSize) + 1,
           math.ceil((cam.y + cam.screenH / cam.zoom) / tileSize) + 1
end

return Camera
