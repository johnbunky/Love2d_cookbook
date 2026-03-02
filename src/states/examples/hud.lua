-- src/states/examples/hud.lua
-- Demonstrates all HUD components: bars, score, minimap, boss bar

local Utils   = require("src.utils")
local Physics = require("src.systems.physics")
local Camera  = require("src.systems.camera")
local Tilemap = require("src.systems.tilemap")
local HUD     = require("src.systems.hud")
local Example = {}

local MAP = {
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,4,0,0,0,0,0,0,0,4,0,0,0,0,0,4,0,0,0,4,0,0,1},
    {1,0,0,0,0,0,2,2,2,0,0,0,0,0,2,2,0,0,0,0,2,2,2,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,4,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,4,0,0,0,0,0,1},
    {1,1,1,1,1,0,0,0,0,1,1,1,1,0,0,0,1,1,1,1,0,0,0,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,2,2,0,0,0,2,2,2,0,0,0,2,2,2,2,0,0,0,2,2,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,3,3,0,0,0,0,3,3,3,0,0,0,3,3,0,0,0,3,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

local W, H
local tm, cam, player
local hp, mana, score, bossHp
local bossTimer   = 0
local manaTimer   = 0

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    tm     = Tilemap.new(MAP, 32)
    cam    = Camera.new(tm.worldW, tm.worldH, W, H, 5)
    player = Physics.newPlayer(2*tm.tileSize, 11*tm.tileSize)

    -- Health bar — red
    hp = HUD.newBar({ max=100, r=0.85, g=0.2, b=0.2 })

    -- Mana bar — blue, regens over time
    mana = HUD.newBar({ max=60, r=0.2, g=0.4, b=0.95,
                        ghostDelay=0, ghostSpeed=0 })

    -- Score
    score = HUD.newScore()

    -- Boss health bar
    bossHp = HUD.newBar({ max=500, r=0.8, g=0.15, b=0.15,
                          ghostDelay=0.8, ghostSpeed=0.5 })
end

function Example.exit() end

function Example.update(dt)
    Physics.update(player, platforms or {}, dt)

    -- Tilemap collision
    local p = player
    Physics.updateMovement(p, dt)
    p.x = p.x + p.vx * dt
    Physics.resolveCollision(p, Tilemap.getSolids(tm, p.x, p.y, p.w, p.h))
    local prevY = p.y
    p.y = p.y + p.vy * dt
    local solidsY = Tilemap.getSolids(tm, p.x, p.y, p.w, p.h, p.vy >= 0)
    local filtered = {}
    for _, s in ipairs(solidsY) do
        if s.oneway then
            if (prevY + p.h) <= s.y + 2 then table.insert(filtered, s) end
        else table.insert(filtered, s) end
    end
    Physics.resolveCollision(p, filtered)
    Physics.finalize(p)
    p.x = Utils.clamp(p.x, 0, tm.worldW - p.w)

    -- Collect coins ? score
    local got = Tilemap.collect(tm, p, Tilemap.T.COIN)
    if got > 0 then HUD.addScore(score, got * 50) end

    -- Hazard ? damage
    if Tilemap.checkType(tm, p, Tilemap.T.HAZARD) then
        HUD.setBar(hp, hp.current - 20 * dt)
    end

    -- Fall ? respawn
    if p.y > tm.worldH then
        HUD.setBar(hp, hp.current - 10)
        p.x, p.y, p.vx, p.vy = 2*tm.tileSize, 11*tm.tileSize, 0, 0
    end

    -- Mana regens slowly
    manaTimer = manaTimer + dt
    if manaTimer > 0.5 then
        manaTimer = 0
        HUD.setBar(mana, math.min(mana.max, mana.current + 2))
    end

    -- Boss bar slowly drains as demo
    bossTimer = bossTimer + dt
    if bossTimer > 1.5 then
        bossTimer = 0
        HUD.setBar(bossHp, math.max(0, bossHp.current - math.random(10,30)))
        if bossHp.current <= 0 then
            HUD.fillBar(bossHp)  -- reset
        end
    end

    -- Update all bars and score
    HUD.updateBar(hp,     dt)
    HUD.updateBar(mana,   dt)
    HUD.updateBar(bossHp, dt)
    HUD.updateScore(score, dt)

    Camera.follow(cam, p, dt)
end

function Example.draw()
    Utils.drawBackground()

    Camera.apply(cam)
    Tilemap.draw(tm, cam)
    Physics.drawPlayer(player)
    Camera.clear()

    -- ---- HUD (screen space) ----

    -- Health bar
    HUD.drawBar(hp,   14, 14, 180, 20, "HP")

    -- Mana bar
    HUD.drawBar(mana, 14, 40, 180, 14, "MP")

    -- Score
    HUD.drawScore(score, 14, 62)

    -- Minimap — top right
    HUD.drawMinimap(tm, player, W-134, 14, 120, 90)

    -- Boss bar — bottom center
    local bw = 500
    local bx = (W - bw) / 2
    HUD.drawBossBar(bossHp, bx, H-48, bw, 22, "DARK LORD ZARVOK")

    -- Controls legend
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print("Walk into red tiles for damage    Collect coins for score", 14, H-80)

    -- Key hints
    love.graphics.setColor(0.35, 0.35, 0.45)
    love.graphics.rectangle("fill", 14, H-100, 280, 18)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("H = -10hp    M = -10mp    R = reset bars", 18, H-100)

    Utils.drawHUD("HUD", "Arrows/WASD move    SPACE jump    H hurt    M cast    P pause    ESC back")
end

function Example.keypressed(key)
    if key == "h" then HUD.setBar(hp,   hp.current   - 10) end
    if key == "m" then HUD.setBar(mana, mana.current - 10) end
    if key == "r" then
        HUD.fillBar(hp)
        HUD.fillBar(mana)
        HUD.fillBar(bossHp)
    end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y) end
function Example.gamepadpressed(joystick, button) end

return Example
