-- src/states/examples/screen_shake.lua
-- Demonstrates: trauma-based screen shake with decay
-- Trauma model: shake intensity = trauma^2, decays over time

local Utils   = require("src.utils")
local Physics = require("src.systems.physics")
local Camera  = require("src.systems.camera")
local Shake   = require("src.systems.shake")
local Example = {}

local W, H
local cam
local shake
local player
local platforms
local particles = {}

local function spawnExplosion(x, y, amount)
    for i = 1, amount do
        local angle = math.random() * math.pi * 2
        local speed = math.random(80, 220)
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life    = 0.6 + math.random() * 0.4,
            maxLife = 1.0,
            r = 0.9 + math.random() * 0.1,
            g = 0.4 + math.random() * 0.4,
            b = 0.1,
        })
    end
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player    = Physics.newPlayer(100, 400)
    cam       = Camera.new(800, 600, W, H, 5)
    shake     = Shake.new()
    particles = {}

    platforms = {
        { x = 0,   y = 550, w = 800, h = 50 },
        { x = 100, y = 420, w = 150, h = 16 },
        { x = 320, y = 340, w = 120, h = 16 },
        { x = 500, y = 260, w = 150, h = 16 },
        { x = 600, y = 420, w = 120, h = 16 },
    }
end

function Example.exit() end

function Example.update(dt)
    Physics.update(player, platforms, dt)
    player.x = Utils.clamp(player.x, 0, W - player.w)

    if player.y > H + 100 then
        Gamestate.switch(States.gameover, Example)
    end

    -- Small shake on hard landing
    if player.onGround and math.abs(player.vy) > 200 then
        Shake.add(shake, 0.15)
    end

    Shake.update(shake, dt)
    Camera.follow(cam, player, dt)

    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.vy   = p.vy + 300 * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end
end

function Example.draw()
    Utils.drawBackground()

    -- Apply shake then camera
    Shake.apply(shake, W, H)
    love.graphics.scale(cam.zoom, cam.zoom)
    love.graphics.translate(-cam.x, -cam.y)

    Utils.drawObstacles(platforms)
    Physics.drawPlayer(player)

    -- Particles
    for _, p in ipairs(particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.r, p.g, p.b, alpha)
        love.graphics.circle("fill", p.x, p.y, 4 * alpha + 1)
    end

    Shake.clear()

    -- HUD
    Utils.drawHUD("SCREEN SHAKE",
        "SPACE jump    1 small    2 medium    3 big    4 MASSIVE    click anywhere    P pause    ESC back")

    -- Trauma bar
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 10, 50, 200, 12)
    local r = Utils.lerp(0.2, 1.0, shake.trauma)
    local g = Utils.lerp(0.8, 0.2, shake.trauma)
    love.graphics.setColor(r, g, 0.1)
    love.graphics.rectangle("fill", 10, 50, 200 * shake.trauma, 12)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("line", 10, 50, 200, 12)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("trauma", 215, 48)
end

function Example.keypressed(key)
    if key == "1" then
        Shake.add(shake, 0.2)
        spawnExplosion(player.x + player.w/2, player.y, 8)
    elseif key == "2" then
        Shake.add(shake, 0.4)
        spawnExplosion(player.x + player.w/2, player.y, 16)
    elseif key == "3" then
        Shake.add(shake, 0.7)
        spawnExplosion(player.x + player.w/2, player.y, 25)
    elseif key == "4" then
        Shake.add(shake, 1.0)
        spawnExplosion(player.x + player.w/2, player.y, 40)
    end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then
        Shake.add(shake, 0.5)
        spawnExplosion(x, y, 20)
    end
end

function Example.touchpressed(id, x, y)
    Shake.add(shake, 0.5)
    spawnExplosion(x, y, 20)
end

function Example.gamepadpressed(joystick, button)
    if button == "a" then Shake.add(shake, 0.5) end
end

return Example
