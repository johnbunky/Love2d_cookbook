-- src/states/examples/character_basics.lua
-- Demonstrates: procedural characters, IK leg stepping, spring physics,
--               finite state machine, 3-projection camera, terrain grid.
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
local Grid      = require "src.systems.grid"
local GridMesh  = require "src.characters.grid_mesh"
local Utils     = require "src.utils"

local Example = {}

-- ─── world ────────────────────────────────────────────────────────────────────
local WORLD_W = 2400
local WORLD_D = 300

local PROFILES = {
    "man", "woman", "child", "troll",
    "thief", "cat", "duck", "spider",
}

local VIEW_LABELS = {
    sidescroll   = "side-scroll",
    threequarter = "3/4",
    isometric    = "iso",
}

-- ─── state ────────────────────────────────────────────────────────────────────
local camera, player, terrain, gridMesh

local function spawnPlayer(profileName)
    local c = Character.new(profileName, WORLD_W / 2)
    -- snap to actual terrain height at spawn position
    local fz = terrain:floorAt(c.pos.x, c.pos.y)
    if fz then
        c.floorZ  = fz
        c.groundZ = fz + c.leg_len * (c.profile.stance_height or 1.0)
        c.pos.z   = c.groundZ
        c.stepper:reset(c.pos.x, c.pos.y, fz)
    end
    camera:snapTo(c.pos.x, c.pos.y, c.pos.z)
    return c
end

-- ─── gamestate callbacks ──────────────────────────────────────────────────────
function Example.enter()
    camera = Camera3D.new(WORLD_W, love.graphics.getHeight())

    -- procedural terrain grid
    local g = Grid.new({
        x0         = 0,    y0 = -250,
        cols       = 30,   rows = 10,
        cell_w     = 80,   cell_h = 50,
        height_amp = 50,
        jitter     = 0.28,
        seed       = 137,
    })
    gridMesh = GridMesh.new(g, { show_edges = true })

    -- terrain adapter: wraps grid so characters use floorAt interface
    terrain = {
        worldW  = WORLD_W,
        worldD  = WORLD_D,
        floorAt = function(self, x, y) return g:floorAt(x, y) end,
    }

    player = spawnPlayer("man")
    love.graphics.setBackgroundColor(0.07, 0.07, 0.10)
end

function Example.exit()
    player   = nil
    camera   = nil
    terrain  = nil
    gridMesh = nil
    love.graphics.setBackgroundColor(0.10, 0.10, 0.13)
end

function Example.update(dt)
    -- ── input → character fields ─────────────────────────────────────────────
    player.inputX = 0
    player.inputY = 0

    if love.keyboard.isDown("a") then player.inputX = -1 end
    if love.keyboard.isDown("d") then player.inputX =  1 end

    if camera.view ~= "sidescroll" then
        if love.keyboard.isDown("w") then player.inputY = -1 end
        if love.keyboard.isDown("s") then player.inputY =  1 end
    end

    player.inputSit = love.keyboard.isDown("q")

    -- ── update ───────────────────────────────────────────────────────────────
    player:update(dt, terrain)
    camera:follow(player.pos.x, player.pos.y, player.pos.z, dt)
end

function Example.draw()
    -- ── terrain ──────────────────────────────────────────────────────────────
    gridMesh:draw(camera)

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
    if key == "space" then
        if player.sm:is("idle") or player.sm:is("walk") then
            player.sm:enter("jump")
        end
    end

    if key == "v" then
        camera:nextView()
        camera:snapTo(player.pos.x, player.pos.y, player.pos.z)
    end

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
