-- src/states/examples/character_basics.lua
-- Demonstrates: procedural characters, IK leg stepping, spring physics,
--               finite state machine, 3-projection camera.
--
-- Controls:
--   A / D          move left / right
--   W / S          move in depth  (only in 3/4 and iso views)
--   Space          jump
--   Q              sit / stand
--   V              cycle view  (side-scroll → 3/4 → isometric)
--   1 – 8          switch character
--   P              pause    ESC  back to menu

local Character = require "src.characters.character"
local Camera3D  = require "src.systems.camera3d"
local Utils     = require "src.utils"

local Example = {}

-- ─── world ────────────────────────────────────────────────────────────────────
local WORLD_W = 2400
local WORLD_D = 300

-- Flat terrain — satisfies the floorAt interface the character system expects.
-- Swap this table for a grid/tilemap implementation to get slope tracking.
local terrain = {
    worldW  = WORLD_W,
    worldD  = WORLD_D,
    floorAt = function(self, x, y) return 0 end,
}

-- ─── state ────────────────────────────────────────────────────────────────────
local camera, player

local PROFILES = {
    "man", "woman", "child", "troll",
    "thief", "cat", "duck", "spider",
}

local VIEW_LABELS = {
    sidescroll   = "side-scroll",
    threequarter = "3/4",
    isometric    = "iso",
}

local function spawnPlayer(profileName)
    local c = Character.new(profileName, WORLD_W / 2)
    camera:snapTo(c.pos.x, c.pos.y, c.pos.z)
    return c
end

-- ─── gamestate callbacks ──────────────────────────────────────────────────────
function Example.enter()
    camera = Camera3D.new(WORLD_W, love.graphics.getHeight())
    player = spawnPlayer("man")
    love.graphics.setBackgroundColor(0.07, 0.07, 0.10)
end

function Example.exit()
    player = nil
    camera = nil
    love.graphics.setBackgroundColor(0.10, 0.10, 0.13)   -- cookbook default
end

function Example.update(dt)
    -- ── input → character fields ─────────────────────────────────────────────
    player.inputX = 0
    player.inputY = 0

    if love.keyboard.isDown("a") then player.inputX = -1 end
    if love.keyboard.isDown("d") then player.inputX =  1 end

    -- depth input only meaningful when not in side-scroll
    if camera.view ~= "sidescroll" then
        if love.keyboard.isDown("w") then player.inputY = -1 end
        if love.keyboard.isDown("s") then player.inputY =  1 end
    end

    -- sit is a held action (hold Q while seated to stay seated)
    player.inputSit = love.keyboard.isDown("q")

    -- ── update ───────────────────────────────────────────────────────────────
    player:update(dt, terrain)
    camera:follow(player.pos.x, player.pos.y, player.pos.z, dt)
end

function Example.draw()
    -- ── ground line ──────────────────────────────────────────────────────────
    love.graphics.setColor(0.25, 0.25, 0.30)
    love.graphics.setLineWidth(2)
    local gx1, gy1 = camera:toScreen(0,       0, 0)
    local gx2, gy2 = camera:toScreen(WORLD_W, 0, 0)
    love.graphics.line(gx1, gy1, gx2, gy2)

    -- ── shadow ───────────────────────────────────────────────────────────────
    local elev = player.pos.z - player.groundZ
    local ss   = math.max(0.05, 1 - elev / 300)
    local fsx, fsy = camera:toScreen(player.pos.x, player.pos.y, player.floorZ)
    love.graphics.setColor(0, 0, 0, 0.18 * ss)
    love.graphics.ellipse("fill", fsx, fsy, 24 * ss, 6 * ss)

    -- ── character ────────────────────────────────────────────────────────────
    player:drawSelf(camera)

    -- ── HUD ──────────────────────────────────────────────────────────────────
    Utils.drawHUD(
        "CHARACTERS  |  " .. player.profileName
        .. "  |  " .. (player.sm.name or "?")
        .. "  |  " .. (VIEW_LABELS[camera.view] or camera.view),
        "A/D move   W/S depth   Space jump   Q sit   V view   1-8 character   ESC back"
    )
end

function Example.keypressed(key)
    -- jump: triggered on keypress, not held
    if key == "space" then
        if player.sm:is("idle") or player.sm:is("walk") then
            player.sm:enter("jump")
        end
    end

    -- cycle projection view
    if key == "v" then
        camera:nextView()
        camera:snapTo(player.pos.x, player.pos.y, player.pos.z)
    end

    -- switch character  (keys 1–8)
    for i, name in ipairs(PROFILES) do
        if key == tostring(i) then
            player = spawnPlayer(name)
            break
        end
    end

    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y)     end
function Example.gamepadpressed(j, button)  end

return Example
