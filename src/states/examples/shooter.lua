-- src/states/examples/shooter.lua
-- Demonstrates: bullet spawning, lifetime, hit detection, enemy targets

local Utils   = require("src.utils")
local Shake   = require("src.systems.shake")
local Example = {}

local W, H
local player
local bullets   = {}
local enemies   = {}
local particles = {}
local shake
local score
local shootCooldown = 0
local SHOOT_RATE    = 0.18   -- seconds between shots
local BULLET_SPEED  = 520
local BULLET_LIFE   = 1.2

-- -------------------------
-- Helpers
-- -------------------------
local function spawnEnemy()
    local side = math.random(4)
    local x, y
    if side == 1 then x = math.random(W);  y = -20
    elseif side == 2 then x = W+20;        y = math.random(H)
    elseif side == 3 then x = math.random(W); y = H+20
    else x = -20; y = math.random(H) end

    table.insert(enemies, {
        x    = x,
        y    = y,
        w    = 24,
        h    = 24,
        hp   = 2,
        speed= math.random(55, 110),
        flash= 0,
    })
end

local function spawnParticles(x, y, r, g, b, count)
    for _ = 1, count do
        table.insert(particles, {
            x    = x, y = y,
            vx   = math.random(-120, 120),
            vy   = math.random(-120, 120),
            life = math.random(20, 45) / 100,
            maxLife = 0.45,
            r=r, g=g, b=b,
        })
    end
end

local function shoot(ox, oy, dirX, dirY)
    if shootCooldown > 0 then return end
    local len = math.sqrt(dirX*dirX + dirY*dirY)
    if len == 0 then return end
    dirX, dirY = dirX/len, dirY/len
    table.insert(bullets, {
        x    = ox,
        y    = oy,
        vx   = dirX * BULLET_SPEED,
        vy   = dirY * BULLET_SPEED,
        life = BULLET_LIFE,
    })
    shootCooldown = SHOOT_RATE
    Shake.add(shake, 0.08)
end

-- -------------------------
-- State
-- -------------------------
local mouseHeld = false  -- tracked via callbacks, more reliable than polling

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player    = { x=W/2-12, y=H/2-12, w=24, h=24, speed=180, angle=0 }
    bullets   = {}
    enemies   = {}
    particles = {}
    shake     = Shake.new({ decay=6 })
    score     = 0
    mouseHeld = false

    for _ = 1, 6 do spawnEnemy() end
end

function Example.exit() end

function Example.update(dt)
    -- Player movement
    local dx, dy = 0, 0
    if Input.isDown("left")  then dx = dx - 1 end
    if Input.isDown("right") then dx = dx + 1 end
    if Input.isDown("up")    then dy = dy - 1 end
    if Input.isDown("down")  then dy = dy + 1 end
    if dx ~= 0 and dy ~= 0 then dx=dx*0.7071; dy=dy*0.7071 end
    player.x = Utils.clamp(player.x + dx*player.speed*dt, 0, W-player.w)
    player.y = Utils.clamp(player.y + dy*player.speed*dt, 0, H-player.h)

    -- Aim toward mouse — only update angle if mouse has moved away from center
    local cx = player.x + player.w/2
    local cy = player.y + player.h/2
    local mdx = Input.mouseX - cx
    local mdy = Input.mouseY - cy
    if math.sqrt(mdx*mdx + mdy*mdy) > 10 then
        player.angle = math.atan2(mdy, mdx)
    end

    -- Shoot — raw mouse check (most reliable), or attack key (Z)
    shootCooldown = math.max(0, shootCooldown - dt)
    if love.mouse.isDown(1) or mouseHeld or Input.isDown("attack") then
        shoot(cx, cy, math.cos(player.angle), math.sin(player.angle))
    end

    -- Bullets
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x    = b.x + b.vx * dt
        b.y    = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 or b.x < 0 or b.x > W or b.y < 0 or b.y > H then
            table.remove(bullets, i)
        end
    end

    -- Enemies chase player
    for i = #enemies, 1, -1 do
        local e  = enemies[i]
        e.flash  = math.max(0, e.flash - dt)
        local tx = cx - (e.x + e.w/2)
        local ty = cy - (e.y + e.h/2)
        local dist = math.sqrt(tx*tx + ty*ty)
        if dist > 0 then
            e.x = e.x + (tx/dist) * e.speed * dt
            e.y = e.y + (ty/dist) * e.speed * dt
        end

        -- Bullet hits enemy
        for j = #bullets, 1, -1 do
            local b = bullets[j]
            if Utils.rectOverlap({x=b.x-4,y=b.y-4,w=8,h=8}, e) then
                e.hp   = e.hp - 1
                e.flash= 0.12
                table.remove(bullets, j)
                spawnParticles(b.x, b.y, 1, 0.6, 0.2, 5)
                if e.hp <= 0 then
                    spawnParticles(e.x+e.w/2, e.y+e.h/2, 0.9, 0.3, 0.2, 12)
                    Shake.add(shake, 0.15)
                    score = score + 10
                    table.remove(enemies, i)
                    spawnEnemy()
                end
                break
            end
        end

        -- Enemy touches player
        if Utils.rectOverlap(e, player) then
            Shake.add(shake, 0.5)
            spawnParticles(cx, cy, 0.9, 0.2, 0.2, 16)
            Gamestate.switch(States.gameover, Example)
            return
        end
    end

    -- Particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    Shake.update(shake, dt)

    -- Keyboard aim fallback (no mouse): shoot in movement direction
    if (dx ~= 0 or dy ~= 0) and Input.isDown("jump") then
        shoot(cx, cy, dx, dy)
    end
end

function Example.draw()
    Shake.apply(shake, W, H)

    -- Background
    love.graphics.setColor(0.08, 0.10, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Grid
    love.graphics.setColor(0.12, 0.14, 0.18)
    for x = 0, W, 40 do love.graphics.line(x, 0, x, H) end
    for y = 0, H, 40 do love.graphics.line(0, y, W, y) end

    -- Particles
    for _, p in ipairs(particles) do
        local a = p.life / p.maxLife
        love.graphics.setColor(p.r, p.g, p.b, a)
        love.graphics.circle("fill", p.x, p.y, 3 * a)
    end

    -- Bullets
    for _, b in ipairs(bullets) do
        local a = b.life / BULLET_LIFE
        love.graphics.setColor(1, 0.9, 0.3, a)
        love.graphics.circle("fill", b.x, b.y, 4)
        love.graphics.setColor(1, 0.7, 0.1, a * 0.4)
        love.graphics.circle("fill", b.x - b.vx*0.012, b.y - b.vy*0.012, 2.5)
    end

    -- Enemies
    for _, e in ipairs(enemies) do
        local r = e.flash > 0 and 1   or 0.85
        local g = e.flash > 0 and 0.4 or 0.25
        local b = e.flash > 0 and 0.4 or 0.25
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", e.x, e.y, e.w, e.h, 4, 4)
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.rectangle("line", e.x, e.y, e.w, e.h, 4, 4)
        -- hp pips
        for pip = 1, e.hp do
            love.graphics.setColor(1, 0.3, 0.3)
            love.graphics.rectangle("fill", e.x + (pip-1)*10, e.y-6, 8, 4)
        end
    end

    -- Player body
    love.graphics.setColor(0.3, 0.8, 1.0)
    love.graphics.rectangle("fill", player.x, player.y, player.w, player.h, 4, 4)
    -- Aim barrel
    local cx = player.x + player.w/2
    local cy = player.y + player.h/2
    love.graphics.setColor(1, 1, 1)
    love.graphics.line(cx, cy,
        cx + math.cos(player.angle) * 18,
        cy + math.sin(player.angle) * 18)

    Shake.clear()

    -- HUD
    love.graphics.setColor(1, 0.9, 0.2)
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.print("Enemies: " .. #enemies, 10, 30)

    Utils.drawHUD("SHOOTER",
        "WASD move    Mouse aim    Hold LMB / Z shoot    P pause    ESC back")
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then mouseHeld = true end
end

function Example.mousereleased(x, y, button)
    if button == 1 then mouseHeld = false end
end

function Example.touchpressed(id, x, y)
    mouseHeld = true
end

function Example.touchreleased(id, x, y)
    mouseHeld = false
end

return Example
